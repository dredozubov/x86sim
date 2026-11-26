// Signal masks vs. the translator's own faults. A thread that blocks every signal (pthread_sigmask / sigprocmask: GCD
// work inside such a section; a thread started by a creator that had all blocked) still loads through a top-byte-tagged
// pointer (TBI: arm64 ignores the top byte; Swift Foundation's Data tags bit 62), and reads its own mask back as set.
// x86Sim: the tagged access is a host #GP fixed up in the SIGSEGV handler: blocked, it killed the process silently.
//   tests/arm64/run.sh tests/arm64/sigmaskprobe.sim   (X86SIM_A64_INTERP=0: translated code from the start)
//   Apple: xcrun simctl spawn <dev> sigmaskprobe.sim
// Expected: "blocked: SEGV 1 BUS 1", "inherited child sum 6000", "blocked thread sum 6000", exit 0.
#include <pthread.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>

__attribute__((noinline)) static long rd(long *p) { return p[2]; }
static long buf[4] = {1, 2, 3, 4};
static long tagged_sum(void) {
    long s = 0, *t = (long *)((uintptr_t)buf | (0x40ull << 56));
    for (int i = 0; i < 2000; i++) s += rd(t);
    return s;
}
static void *child(void *a) {
    printf("inherited child sum %ld\n", tagged_sum());
    return a;
}
static void *blocked(void *a) {
    sigset_t all, cur;
    sigfillset(&all);
    pthread_sigmask(SIG_BLOCK, &all, NULL);
    pthread_sigmask(SIG_BLOCK, NULL, &cur);
    printf("blocked: SEGV %d BUS %d\n", sigismember(&cur, SIGSEGV), sigismember(&cur, SIGBUS));
    // a thread created from here starts with this mask
    pthread_t t;
    pthread_create(&t, NULL, child, NULL);
    pthread_join(t, NULL);
    printf("blocked thread sum %ld\n", tagged_sum());
    return a;
}
int main(void) {
    pthread_t t;
    pthread_create(&t, NULL, blocked, NULL);
    pthread_join(t, NULL);
    return 0;
}
