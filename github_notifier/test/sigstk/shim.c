#define _GNU_SOURCE
#include <signal.h>
#include <errno.h>
#include <dlfcn.h>

/*
 * Hardware-independent reproduction of the musl/Alpine BEAM startup abort
 * (erlang/otp#11248, PR erlang/otp#11249).
 *
 * On musl, SIGSTKSZ is a static 8192. The JIT sizes its alternate signal
 * stack with that constant. On CPUs whose kernel reports AT_MINSIGSTKSZ
 * > 8192 (AVX-512 / AMX, e.g. GKE c3 / Sapphire Rapids), sigaltstack()
 * returns ENOMEM and the emulator aborts at startup. glibc made SIGSTKSZ
 * dynamic to avoid exactly this; musl did not.
 *
 * LD_PRELOAD this shim to force the failing condition on any CPU: reject
 * any alternate-stack install smaller than 16384, mimicking such a kernel.
 * A vulnerable JIT build (requests 8192) aborts; a fixed build (requests
 * max(SIGSTKSZ, AT_MINSIGSTKSZ) >= 16384) or an interpreter build is let
 * through and boots.
 */
int sigaltstack(const stack_t *ss, stack_t *old) {
  static int (*real)(const stack_t *, stack_t *);
  if (!real) real = dlsym(RTLD_NEXT, "sigaltstack");
  if (ss && ss->ss_size && ss->ss_size < 16384) {
    errno = ENOMEM;
    return -1;
  }
  return real(ss, old);
}
