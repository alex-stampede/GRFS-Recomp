// Exercises the real cvar command bridge without launching a guest or GPU.
#include "grfs_pc_options.h"
#include <cassert>

int main() {
  using namespace grfs::options;
  using rex::input::mnk::SetMouseLookActive;
  using rex::input::mnk::IsMouseLookActive;
  SetMouseLookActive(true);
  assert(rex::cvar::InvokeCommand("grfs_notify_options_open", ""));
  assert(native_open && !IsMouseLookActive());
  // Repeated open notifications must not overwrite the saved capture state.
  assert(rex::cvar::InvokeCommand("grfs_notify_options_open", ""));
  panel_open = true;
  assert(rex::cvar::InvokeCommand("grfs_notify_options_close", ""));
  assert(!native_open && !panel_open && IsMouseLookActive());
  SetMouseLookActive(false);
  NotifyOpen();
  NotifyClose();
  assert(!IsMouseLookActive());
  // A stale close event cannot enable capture that was manually disabled.
  NotifyClose();
  assert(!IsMouseLookActive());
  assert(rex::cvar::InvokeCommand("grfs_notify_screen", "Options.feu"));
  assert(native_open);
  panel_open = true;
  assert(rex::cvar::InvokeCommand("grfs_notify_screen", "Extras.feu"));
  assert(!native_open && !panel_open);
  assert(!IsMouseLookActive());
}
