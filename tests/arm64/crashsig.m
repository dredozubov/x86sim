// In-app crash reporters (PLCrashReporter, KSCrash, Sentry, Crashlytics): sigaction(SIGABRT/SEGV/BUS/ILL/TRAP/FPE)
// with SA_SIGINFO | SA_ONSTACK on a sigaltstack; the handler reads siginfo + the Darwin ucontext, writes a report and
// re-raises with SIG_DFL. Each case runs in a child (posix_spawn of this binary) and prints one line:
//   ran / on the alt stack / si_signo / si_code / si_addr / pc (exact = the labeled faulting instruction, else the
//   symbol) / sp, fp, x10 marker (guest registers at the fault) / lr / far, then the child's wait status.
// Modes: exit (handler _exits 42), skip (the handler moves the pc past a faulting instruction: RETURNED), reraise
// (SIG_DFL + re-raise / return to re-fault: dies with that signal), none (no handler: x86Sim's own diagnostics),
// redirect (.NET NativeAOT's: SA_SIGINFO | SA_RESTART, no altstack; the handler sends the pc to a throw helper with
// x0 = code, x1 = faulting pc: REDIRECTED, exit 0).
// Usage: crashsig.sim [exit|skip|reraise|none|redirect] [case...]
//   tests/arm64/run.sh tests/arm64/crashsig.sim                       (Apple: xcrun simctl spawn <dev> crashsig.sim)
#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <pthread.h>
#include <signal.h>
#include <spawn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/ucontext.h>
#include <sys/wait.h>
#include <unistd.h>

extern char **environ;
extern char pc_null[], pc_unmapped[], pc_prot[], pc_ro[], pc_align[], pc_brk[], pc_udf[];

static char *alt_lo, *alt_hi;
static const char *g_case = "?", *g_mode = "exit";
static void *g_addr;          // the address the case faults on
static char *g_exact;         // the labeled faulting instruction (0: abort-like cases)
static unsigned long g_sp, g_fp;  // sp / fp at the fault (set by the case's asm)

static void sym(unsigned long a, char *out, size_t n) {
    Dl_info di;
    if (dladdr((void *)a, &di) && di.dli_sname) snprintf(out, n, "%s+%#lx", di.dli_sname, a - (unsigned long)di.dli_saddr);
    else snprintf(out, n, "%#lx", a);
}

// where mode redirect sends a fault (NativeAOT: RhpThrowHwEx), on the thread's own stack
static void redirected(unsigned long code, unsigned long ip) {
    volatile char here;
    printf("case %-10s REDIRECTED code=%#lx ip=%s onalt=%d\n", g_case, code, ip == (unsigned long)g_exact ? "exact" : "WRONG",
           (char *)&here >= alt_lo && (char *)&here < alt_hi);
    fflush(stdout);
    _exit(0);
}

static void handler(int sig, siginfo_t *si, void *ctx) {
    volatile char here;
    ucontext_t *uc = ctx;
    stack_t cur;
    sigaltstack(NULL, &cur);
    char line[1024], pcs[160], lrs[160];
    unsigned long pc = uc->uc_mcontext->__ss.__pc, lr = uc->uc_mcontext->__ss.__lr;
    unsigned long sp = uc->uc_mcontext->__ss.__sp, fp = uc->uc_mcontext->__ss.__fp;
    sym(pc, pcs, sizeof pcs); sym(lr, lrs, sizeof lrs);
    const int onalt = (char *)&here >= alt_lo && (char *)&here < alt_hi;
    int n = snprintf(line, sizeof line,
        "case %-10s ran sig=%d onalt=%d ss_onstack=%d signo=%d code=%d addr=%s pc=%s%s sp=%s fp=%s x10=%s lr=%s far=%s\n",
        g_case, sig, onalt, !!(cur.ss_flags & SS_ONSTACK), si->si_signo, si->si_code,
        !g_addr ? (si->si_addr ? "set" : "0") : si->si_addr == g_addr ? "ok" : "WRONG",
        g_exact ? (pc == (unsigned long)g_exact ? "exact" : "WRONG:") : "", g_exact && pc == (unsigned long)g_exact ? "" : pcs,
        !g_sp ? "-" : sp == g_sp ? "ok" : "WRONG", !g_fp ? "-" : fp == g_fp ? "ok" : "WRONG",
        !g_exact ? "-" : uc->uc_mcontext->__ss.__x[10] == 0x5a5a1234 ? "ok" : "WRONG", lrs,
        !g_addr ? "-" : uc->uc_mcontext->__es.__far == (unsigned long)g_addr ? "ok" : "WRONG");
    write(1, line, n);
    if (!strcmp(g_mode, "skip") && g_exact) {  // resume after the faulting instruction (a changed ucontext)
        uc->uc_mcontext->__ss.__pc += 4;
        return;
    }
    if (!strcmp(g_mode, "redirect") && g_exact) {  // as NativeAOT's RedirectNativeContext: pc, x0, x1
        uc->uc_mcontext->__ss.__x[0] = 0xc0000005;
        uc->uc_mcontext->__ss.__x[1] = pc;
        uc->uc_mcontext->__ss.__pc = (unsigned long)redirected;
        return;
    }
    if (!strcmp(g_mode, "reraise")) {
        signal(sig, SIG_DFL);
        if (!g_exact) raise(sig);   // abort-like: re-raise; a fault re-executes the instruction on return
        return;
    }
    _exit(42);
}

static void install(void) {
    static char *alt;
    if (!alt) alt = malloc(256 << 10);
    alt_lo = alt; alt_hi = alt + (256 << 10);
    stack_t ss = {.ss_sp = alt, .ss_size = 256 << 10, .ss_flags = 0};
    sigaltstack(&ss, NULL);
    if (!strcmp(g_mode, "none")) return;
    struct sigaction sa;
    memset(&sa, 0, sizeof sa);
    sa.sa_sigaction = handler;
    sa.sa_flags = !strcmp(g_mode, "redirect") ? SA_SIGINFO | SA_RESTART : SA_SIGINFO | SA_ONSTACK;
    sigemptyset(&sa.sa_mask);
    int sigs[] = {SIGABRT, SIGSEGV, SIGBUS, SIGILL, SIGTRAP, SIGFPE};
    for (unsigned i = 0; i < sizeof sigs / sizeof *sigs; i++) sigaction(sigs[i], &sa, NULL);
}

// x9 = the address, x10 = a marker; g_sp / g_fp = this frame's sp / fp at the faulting instruction
#define FAULT(label, insn, addr)                                                                    \
    __asm__ volatile("mov x9, %0\n mov x10, #0x1234\n movk x10, #0x5a5a, lsl #16\n"                 \
                     "mov x11, sp\n str x11, [%1]\n str x29, [%2]\n"                                \
                     ".globl _" #label "\n_" #label ":\n" insn "\n"                                 \
                     :: "r"(addr), "r"(&g_sp), "r"(&g_fp) : "x9", "x10", "x11", "memory")

__attribute__((noinline)) static void c_null(void) { g_addr = 0; g_exact = pc_null; FAULT(pc_null, "str x10, [x9]", (void *)0); }
__attribute__((noinline)) static void c_unmapped(void) {
    char *p = mmap(0, 0x4000, PROT_READ | PROT_WRITE, MAP_ANON | MAP_PRIVATE, -1, 0);
    munmap(p, 0x4000);
    g_addr = p + 0x10; g_exact = pc_unmapped; FAULT(pc_unmapped, "ldr x11, [x9]", p + 0x10);
}
__attribute__((noinline)) static void c_prot(void) {
    char *p = mmap(0, 0x4000, PROT_NONE, MAP_ANON | MAP_PRIVATE, -1, 0);
    g_addr = p + 0x20; g_exact = pc_prot; FAULT(pc_prot, "ldr x11, [x9]", p + 0x20);
}
__attribute__((noinline)) static void c_ro(void) {
    char *p = mmap(0, 0x4000, PROT_READ, MAP_ANON | MAP_PRIVATE, -1, 0);
    g_addr = p + 0x30; g_exact = pc_ro; FAULT(pc_ro, "str x10, [x9]", p + 0x30);
}
__attribute__((noinline)) static void c_align(void) {
    static char buf[64] __attribute__((aligned(16)));
    g_addr = buf + 1; g_exact = pc_align; FAULT(pc_align, "ldxr x11, [x9]", buf + 1);
}
__attribute__((noinline)) static void c_brk(void) { g_exact = pc_brk; FAULT(pc_brk, "brk #1", (void *)0); }
__attribute__((noinline)) static void c_udf(void) { g_exact = pc_udf; FAULT(pc_udf, "udf #0", (void *)0); }
__attribute__((noinline)) static void c_trap(void) { __builtin_trap(); }
// a NULL function pointer: pc 0, lr the call's return address
__attribute__((noinline)) static void c_callnull(void) {
    void (*volatile fn)(void) = 0;
    g_addr = 0; fn();
}
// a fault inside libsystem (x86Sim: Darling's native strlen, reached through a thunk)
__attribute__((noinline)) static void c_strlen(void) {
    g_addr = (void *)0x10;
    printf("%zu\n", strlen(*(const char *volatile *)&g_addr));
}
static void c_abort(void) { abort(); }
static void c_raise(void) { raise(SIGABRT); }
static void c_fpe(void) { raise(SIGFPE); }
static void c_nsexc(void) {
    @autoreleasepool { @throw [NSException exceptionWithName:@"CrashSigProbe" reason:@"uncaught on purpose" userInfo:nil]; }
}
__attribute__((noinline)) static unsigned long recurse(unsigned long n, volatile unsigned char *up) {
    volatile unsigned char pad[1024];
    pad[0] = (unsigned char)n; pad[1023] = (unsigned char)(n >> 8);
    unsigned long r = n ? recurse(n - 1, pad) : 0;
    return r + pad[0] + pad[1023] + (up ? up[0] : 0);
}
static void *ovf_thread(void *a) {
    install();  // sigaltstack is per thread
    printf("recursion returned %lu\n", recurse(1 << 20, NULL));
    return a;
}
static void c_stackovf(void) {
    pthread_t t;
    pthread_create(&t, NULL, ovf_thread, NULL);
    pthread_join(t, NULL);
}

static const struct { const char *name; void (*fn)(void); } cases[] = {
    {"abort", c_abort}, {"raise", c_raise}, {"null", c_null}, {"unmapped", c_unmapped}, {"prot", c_prot},
    {"ro", c_ro}, {"align", c_align}, {"trap", c_trap}, {"brk", c_brk}, {"udf", c_udf}, {"fpe", c_fpe},
    {"nsexc", c_nsexc}, {"stackovf", c_stackovf}, {"callnull", c_callnull}, {"strlen", c_strlen},
};

int main(int argc, char **argv) {
    if (argc >= 4 && !strcmp(argv[1], "-child")) {
        g_mode = argv[2]; g_case = argv[3];
        install();
        for (unsigned i = 0; i < sizeof cases / sizeof *cases; i++)
            if (!strcmp(cases[i].name, g_case)) { cases[i].fn(); break; }
        printf("case %-10s RETURNED (no signal)\n", g_case);
        return 3;
    }
    const char *mode = argc > 1 ? argv[1] : "exit";
    for (unsigned i = 0; i < sizeof cases / sizeof *cases; i++) {
        int sel = argc <= 2;
        for (int k = 2; k < argc; k++) sel |= !strcmp(argv[k], cases[i].name);
        if (!sel) continue;
        char *av[] = {argv[0], "-child", (char *)mode, (char *)cases[i].name, NULL};
        pid_t pid;
        fflush(stdout);
        if (posix_spawn(&pid, argv[0], NULL, NULL, av, environ)) { printf("case %s: spawn failed\n", cases[i].name); continue; }
        int st = 0;
        waitpid(pid, &st, 0);
        if (WIFSIGNALED(st)) printf("case %-10s %s: killed by signal %d\n", cases[i].name, mode, WTERMSIG(st));
        else printf("case %-10s %s: exit %d\n", cases[i].name, mode, WEXITSTATUS(st));
        fflush(stdout);
    }
    return 0;
}
