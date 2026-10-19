# GRFS PC options — v0.10.0.4

This directory contains the original host-side UI additions for the options
candidate. It does not contain a game executable, assets, or the generated
PowerPC implementation.

The development build adds a **PC Settings** button to **Extras → Options**.
The button also has an F5 shortcut while that screen is open. This is a host
overlay tied to the original screen lifecycle; it does not rewrite the game's
menu assets. The original audio and subtitle controls stay accessible.

Features:

- English, Spanish, and French menu language selection, applied after saving
  and restarting. Spanish was confirmed by the owner in the earlier candidate.
- Opt-in mouse camera, sensitivity adjustment, and editable keyboard and
  mouse-button assignments.
- PC preset with left-click fire, right-click aim, R reload, and middle-click
  right-stick press. F6 releases/captures the mouse during gameplay.
- Preferences in `UserData/grfs.toml`, outside the signed application.
- A cyan and dark-blue theme that reads Arial from macOS rather than bundling
  a third-party font.

## Build integration

Copy `grfs_app.h` and `grfs_pc_options.h` into the game's `src/` directory.
Keep the existing `main.cpp` that includes the generated default image config
before `grfs_app.h`. Apply `patches/grfs-native-options.patch` at the game
project root **after** generating the code; regeneration may remove this hook.
Apply `patches/xgetlanguage-user-preference.patch` at the SDK root.

The game target needs the existing ImGui include path. Build `grfs`, then
package its executable, the rebuilt `libgrfs_AICLASS_X360_F.dylib`, and the
SDK's rebuilt `librexruntime.dylib` together with the established runtime and
Vulkan resources. Do not replace the GPU library with an unrelated build.

The observer calls a host cvar command only after the native `ScreenLoaded`
event is matched. `Options.feu` activates the button; another screen name
removes it. UI work stays on the UI thread, and the event callback publishes
atomic state. Input polling is gated while the PC panel is open.

## Validation and limitations

Compilation and app signature checks passed. The owner confirmed the first
working integrated button and opened the panel. The redesigned panel was
visually checked, and its saved sensitivity value was verified on disk.
The command bridge test covers repeated opens, capture restoration, and
Options → Extras transitions. The original gameplay mouse input and Spanish
menus were confirmed by the owner before the menu integration.

Mouse look still emulates the right stick and retains the game's turn-speed
limit. Key capture supports letters, digits, common navigation keys, mouse
buttons, and modifier chords; standalone modifiers are not supported by the
current driver. F4, F5, and F6 remain reserved. In-game prompts still use Xbox
button names. Cinematic graphical artifacts remain unresolved.

Included in the v0.10.0.4 release.


Menu-footer experiments were withdrawn at the owner’s request and are not part of this candidate. Original game button prompts remain.
