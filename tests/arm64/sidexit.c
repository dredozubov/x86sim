// tests/arm64/sidexit.c: branch-heavy checksums for side exits (dynarmic TranslationOptions::max_side_exits).
// Every kind of conditional branch (b.cond on each condition, cbz/cbnz, tbz/tbnz on 32- and 64-bit registers), registers
// written before a conditional branch and again after it, flags from adds/subs/ands/ccmp, loops, recursion and a jump
// table. The printed sums must be the same with X86SIM_A64_SIDE_EXITS=0 (every conditional branch ends its block) and
// any N > 0. Build: build/linux-arm64-test.sh sidexit (or Xcode clang -arch arm64 -mios-simulator-version-min=17.0 -O2).
#include <stdint.h>
#include <stdio.h>

static uint64_t s = 0x9E3779B97F4A7C15ull;
static inline uint64_t rnd(void) {
    s ^= s << 13; s ^= s >> 7; s ^= s << 17;
    return s;
}

// b.cond on every condition, through inline asm so the compiler cannot fold them
#define COND_CASE(cc)                                                                                               \
    static __attribute__((noinline)) uint64_t c_##cc(uint64_t a, uint64_t b) {                                       \
        uint64_t r;                                                                                                   \
        __asm__ volatile("mov %0, #1\n cmp %1, %2\n b." #cc " 1f\n mov %0, #2\n add %0, %0, %1\n1: add %0, %0, #3\n"   \
                         : "=&r"(r) : "r"(a), "r"(b) : "cc");                                                         \
        return r;                                                                                                     \
    }
COND_CASE(eq) COND_CASE(ne) COND_CASE(cs) COND_CASE(cc) COND_CASE(mi) COND_CASE(pl) COND_CASE(vs) COND_CASE(vc)
COND_CASE(hi) COND_CASE(ls) COND_CASE(ge) COND_CASE(lt) COND_CASE(gt) COND_CASE(le)

// flags from adds (overflow / carry), then two conditional branches on the same flags, a register set before the
// branch and overwritten after it
static __attribute__((noinline)) uint64_t flags2(uint64_t a, uint64_t b) {
    uint64_t r, t;
    __asm__ volatile("mov %1, #7\n adds %0, %2, %3\n b.vs 1f\n mov %1, #11\n b.cs 2f\n add %0, %0, %1\n b 3f\n"
                     "1: eor %0, %0, %1\n b 3f\n2: sub %0, %0, %1\n3: add %0, %0, %1\n"
                     : "=&r"(r), "=&r"(t) : "r"(a), "r"(b) : "cc");
    return r;
}

// cbz/cbnz/tbz/tbnz, 32- and 64-bit
static __attribute__((noinline)) uint64_t bits(uint64_t a, unsigned k) {
    uint64_t r = 0;
    __asm__ volatile("mov %0, #0\n"
                     "cbz %w1, 1f\n add %0, %0, #1\n1:"
                     "cbnz %1, 2f\n add %0, %0, #2\n2:"
                     "tbz %1, #63, 3f\n add %0, %0, #4\n3:"
                     "tbnz %w1, #5, 4f\n add %0, %0, #8\n4:"
                     "tbz %w1, #0, 5f\n add %0, %0, #16\n5:"
                     "tbnz %1, #40, 6f\n add %0, %0, #32\n6:"
                     : "=&r"(r) : "r"(a) : "cc");
    return r * 131 + k;
}

// a register written before a cbz and again after it (the exit must see the first value)
static __attribute__((noinline)) uint64_t setset(uint64_t a, uint64_t b) {
    uint64_t r;
    __asm__ volatile("mov x9, %1\n cbz %2, 1f\n mov x9, %2\n add x9, x9, #5\n mov %0, x9\n b 2f\n"
                     "1: mov %0, x9\n2:\n"
                     : "=&r"(r) : "r"(a), "r"(b) : "x9", "cc");
    return r;
}

static __attribute__((noinline)) uint64_t collatz(uint64_t n) {
    uint64_t steps = 0;
    while (n != 1 && steps < 1000) {
        n = (n & 1) ? 3 * n + 1 : n >> 1;
        steps++;
    }
    return steps;
}

static __attribute__((noinline)) int64_t fib(int n) { return n < 2 ? n : fib(n - 1) + fib(n - 2); }

static __attribute__((noinline)) uint64_t sw(uint64_t x) {
    switch (x % 11) {
    case 0: return x * 3;
    case 1: return x ^ 0x55;
    case 2: return x + 17;
    case 3: return x >> 3;
    case 4: return ~x;
    case 5: return x * x;
    case 6: return x - 99;
    case 7: return x | 0x100;
    case 8: return x & 0xff;
    case 9: return x << 2;
    default: return x;
    }
}

static __attribute__((noinline)) uint64_t ccmp(int64_t a, int64_t b, int64_t c) {
    uint64_t r = 0;
    if (a > b && b != c) r += 1;
    if (a < 0 || c < 0) r += 2;
    if ((uint64_t)a >= (uint64_t)c && b <= 0) r += 4;
    if (a == c || (b > a && c > b)) r += 8;
    return r;
}

static __attribute__((noinline)) uint64_t search(const uint32_t* v, int n, uint32_t key) {
    int lo = 0, hi = n - 1;
    while (lo <= hi) {
        int mid = (lo + hi) / 2;
        if (v[mid] == key) return (uint64_t)mid;
        if (v[mid] < key) lo = mid + 1; else hi = mid - 1;
    }
    return 0xffffffffull;
}

int main(void) {
    uint64_t sum[8] = {0};
    static uint32_t v[4096];
    for (int i = 0; i < 4096; i++) v[i] = (uint32_t)(i * 7 + 3);
    for (int i = 0; i < 400000; i++) {
        const uint64_t a = rnd(), b = (i & 3) ? rnd() : a, c = rnd() >> (i & 63);
        sum[0] += c_eq(a, b) + c_ne(a, b) * 3 + c_cs(a, c) * 5 + c_cc(c, a) * 7 + c_mi(a, b) * 11 + c_pl(b, a) * 13 +
                  c_vs(a, b) * 17 + c_vc(a, c) * 19 + c_hi(a, c) * 23 + c_ls(c, b) * 29 + c_ge(a, b) * 31 +
                  c_lt(b, c) * 37 + c_gt(a, a) * 41 + c_le(c, c) * 43;
        sum[1] = sum[1] * 31 + flags2(a, b) + flags2(a >> 1, ~a) + flags2(0x7fffffffffffffffull, a & 7);
        sum[2] += bits(a, i & 7) + bits(c, 1) + bits(0, 2) + bits(~0ull, 3);
        sum[3] = sum[3] * 17 + setset(a, (i % 3) ? 0 : b);
        sum[4] += collatz((a & 0xffff) + 1);
        sum[5] = sum[5] * 7 + sw(a) + ccmp((int64_t)a, (int64_t)b, (int64_t)c);
        sum[6] += search(v, 4096, (uint32_t)(a % 28700));
    }
    sum[7] = (uint64_t)fib(27);
    for (int k = 0; k < 8; k++) printf("sum%d %016llx\n", k, (unsigned long long)sum[k]);
    return 0;
}
