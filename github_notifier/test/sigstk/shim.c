#define _GNU_SOURCE
#include <signal.h>
#include <errno.h>
#include <dlfcn.h>
#include <sys/auxv.h>

#ifndef AT_MINSIGSTKSZ
#define AT_MINSIGSTKSZ 51
#endif

/* Simulated kernel minimum signal-stack size. Overridden at compile time
 * (-DSIGSTK_KERNEL_MIN=...) by the Makefile; the default matches the
 * value measured on the production GKE c3-standard-8 nodes (amx_tile). */
#ifndef SIGSTK_KERNEL_MIN
#define SIGSTK_KERNEL_MIN 11952
#endif

/*
 * Hardware-independent reproduction of the musl/Alpine BEAM signal-stack
 * bug (erlang/otp#11248, fixed by erlang/otp#11249).
 *
 * On musl, SIGSTKSZ is a static 8192. OTP >= 27's JIT registers a
 * SIGSTKSZ-sized alternate signal stack per scheduler thread. On CPUs
 * whose kernel reports AT_MINSIGSTKSZ > 8192 (AVX-512 / AMX), that stack
 * is undersized: a strict kernel rejects it and BEAM aborts at startup;
 * a lenient kernel accepts it and signal delivery may silently overflow
 * the stack. glibc made SIGSTKSZ dynamic to avoid this; musl did not.
 *
 * LD_PRELOAD this shim to fake a strict kernel with
 * AT_MINSIGSTKSZ = SIGSTK_KERNEL_MIN on any CPU. Both halves of the
 * condition are simulated so the gate is faithful in both directions:
 *
 *   - getauxval(AT_MINSIGSTKSZ) returns SIGSTK_KERNEL_MIN, so a FIXED
 *     runtime (erlang/otp#11249 sizes with max(SIGSTKSZ, AT_MINSIGSTKSZ))
 *     requests enough and is let through -> boots -> guard green.
 *   - sigaltstack() rejects sizes < SIGSTK_KERNEL_MIN, so a VULNERABLE
 *     runtime (requests the bare 8192) fails -> aborts -> guard red.
 *
 * Runtimes that never register (OTP <= 26 on musl, interpreter builds)
 * pass trivially.
 */
unsigned long getauxval(unsigned long type) {
  static unsigned long (*real)(unsigned long);
  if (!real) real = dlsym(RTLD_NEXT, "getauxval");
  if (type == AT_MINSIGSTKSZ) return SIGSTK_KERNEL_MIN;
  return real(type);
}

int sigaltstack(const stack_t *ss, stack_t *old) {
  static int (*real)(const stack_t *, stack_t *);
  if (!real) real = dlsym(RTLD_NEXT, "sigaltstack");
  if (ss && ss->ss_size && ss->ss_size < SIGSTK_KERNEL_MIN) {
    errno = ENOMEM;
    return -1;
  }
  return real(ss, old);
}
