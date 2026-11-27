// Exercises the real cvar command bridge without launching a guest or GPU.
#include "grfs_pc_options.h"
#include <cassert>

int main() {
  using namespace grfs::options;
  using rex::input::mnk::SetMouseLookActive;
  using rex::input::mnk::IsMouseLookActive;
  SetMouseLookActive(true);
  int visibility_events = 0;
  visibility_changed = [&] { ++visibility_events; };
  assert(rex::cvar::InvokeCommand("grfs_notify_options_open", ""));
  assert(native_open && !IsMouseLookActive());
  // Repeated open notifications must not overwrite the saved capture state.
  assert(rex::cvar::InvokeCommand("grfs_notify_options_open", ""));
  panel_open = true;
  assert(visibility_events == 1); // repeated open must not enqueue another attach
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
  assert(visibility_events == 6); // three genuine open/close pairs, no stale close
  visibility_changed = {};

  const auto binds = rex::cvar::ListFlagsByCategory("Input/Keybinds/Controller");
  assert(!binds.empty());
  for (const auto& name : binds) assert(rex::cvar::SetFlagByName(name, "LMB"));
  assert(rex::cvar::SetFlagByName("mnk_mouse", "true"));
  assert(rex::cvar::SetFlagByName("mnk_sensitivity", "2.5"));
  SetMouseLookActive(true);
  NotifyOpen();
  RestoreKeyboardControls();
  NotifyClose();
  for (const auto& name : binds) assert(!rex::cvar::HasNonDefaultValue(name));
  assert(rex::cvar::GetFlagByName("keybind_left_trigger") == "Q,I");
  assert(rex::cvar::GetFlagByName("keybind_right_trigger") == "E,O");
  assert(rex::cvar::GetFlagByName("keybind_rstick_up") == "Up");
  assert(rex::cvar::GetFlagByName("mnk_mode") == "true");
  assert(rex::cvar::GetFlagByName("mnk_mouse") == "false");
  assert(!IsMouseLookActive());
  assert(rex::cvar::Query<double>("mnk_sensitivity") == 2.5);
}
