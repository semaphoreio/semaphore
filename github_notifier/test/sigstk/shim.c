#define _GNU_SOURCE
#include <signal.h>
#include <errno.h>
#include <dlfcn.h>
#include <sys/auxv.h>

#ifndef AT_MINSIGSTKSZ
#define AT_MINSIGSTKSZ 51
#endif

/*
 * Hardware-independent reproduction of the musl/Alpine BEAM startup abort
 * (erlang/otp#11248, fixed by erlang/otp#11249).
 *
 * On musl, SIGSTKSZ is a static 8192. OTP >= 27's JIT registers a
 * SIGSTKSZ-sized alternate signal stack per scheduler thread and treats
 * sigaltstack() failure as fatal. On CPUs whose kernel reports
 * AT_MINSIGSTKSZ > 8192 (AVX-512 / AMX, e.g. GKE c3 / Sapphire Rapids)
 * the registration fails with ENOMEM and the emulator aborts at startup.
 * glibc made SIGSTKSZ dynamic to avoid exactly this; musl did not.
 *
 * LD_PRELOAD this shim to fake such a kernel on any CPU. Both halves of
 * the condition are simulated so the gate is faithful in both directions:
 *
 *   - getauxval(AT_MINSIGSTKSZ) returns 16384, so a FIXED runtime
 *     (erlang/otp#11249 sizes with max(SIGSTKSZ, AT_MINSIGSTKSZ))
 *     requests 16384 and is let through -> boots -> guard green.
 *   - sigaltstack() rejects sizes < 16384, so a VULNERABLE runtime
 *     (requests the bare 8192) fails -> aborts -> guard red.
 *
 * Runtimes that never register (OTP <= 26 on musl, interpreter builds)
 * pass trivially.
 */
unsigned long getauxval(unsigned long type) {
  static unsigned long (*real)(unsigned long);
  if (!real) real = dlsym(RTLD_NEXT, "getauxval");
  if (type == AT_MINSIGSTKSZ) return 16384;
  return real(type);
}

int sigaltstack(const stack_t *ss, stack_t *old) {
  static int (*real)(const stack_t *, stack_t *);
  if (!real) real = dlsym(RTLD_NEXT, "sigaltstack");
  if (ss && ss->ss_size && ss->ss_size < 16384) {
    errno = ENOMEM;
    return -1;
  }
  return real(ss, old);
}
