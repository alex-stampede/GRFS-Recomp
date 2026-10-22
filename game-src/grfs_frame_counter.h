#pragma once
#if REX_PLATFORM_MAC
#include <dlfcn.h>
#include <cstdlib>
#include <rex/ppc/function.h>

// Forward the original kernel implementation without touching any guest
// register, argument, clock or return value. This counts CPU-side swap requests,
// not completed GPU frames or unique images shown on the display.
extern "C" REX_FUNC(__imp__VdSwap) {
  static auto original = reinterpret_cast<PPCFunc*>(dlsym(RTLD_NEXT, "__imp__VdSwap"));
  using Record = void (*)();
  static auto record = reinterpret_cast<Record>(dlsym(RTLD_DEFAULT, "GRFSRecordGuestSwap"));
  if (!original) {
    std::fputs("GRFS: original VdSwap implementation unavailable\n", stderr);
    std::abort();
  }
  original(ctx, base);
  if (record) record();
}
#endif
