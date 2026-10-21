# Changelog

## 0.10.0.5 — October 21, 2026

- Apply the transparent GRFS skull directly to the running launcher and game Dock icons.
- Declare macOS Game Mode support and the Games application category for both app bundles.
- Start the game in native macOS fullscreen, where the system can activate Game Mode. A previously disabled per-game preference is respected.
- Preserve the v0.10.0.4 game/runtime/GPU code and graphics configuration. No performance or geometry experiments are included.

## 0.10.0.4 — October 19, 2026

- Added PC Settings in Extras → Options, opened with F5 or a click.
- Added opt-in mouse controls, sensitivity, editable bindings, and middle-click right-stick press.
- Added English, Spanish, and French menu language selection with persistent preferences.
- Preserved the playable baseline and fullscreen fix; original Xbox prompts remain.
- Cinematic and scene-reload graphical artifacts remain unresolved.

## 0.10.0.3 — October 19, 2026

- Redesigned the launcher around the supplied GRFS background, dark colors, and teal accents.
- Translated launcher messages, installer actions, and update dialogs to English.
- Keep one rollback copy outside Applications and migrate legacy backup apps; redundant copies go to recoverable Trash.
- Documented current keyboard mappings, the Mac mini M4 Pro 24 GB development system, and owner-reported successful testing on MacBook Air M3 8 GB.
- Added a packaged Vulkan driver-manifest check and a macOS swapchain recreation fix. The owner confirmed working fullscreen entry and return to windowed mode on the development Mac.

## 0.10.0.2 — October 19, 2026

### Fixed

- Package the game process as a nested macOS application with its own bundle identity and the same icon as the launcher. This replaces the generic black `exec` Dock icon during gameplay.
- Keep runtime libraries beside the game executable so the playable baseline and renderer settings remain unchanged.
- Preserve the existing installation, save data, shader storage, and hidden installer behavior.
- Verified the signed public update from v0.10.0.1 to v0.10.0.2 on the development Mac, including previous-version backup and game relaunch.

## 0.10.0.1 — October 19, 2026

### Added

- Native macOS launcher with local Xbox 360 ISO selection and XDVDFS extraction.
- Installation progress and compatibility checks for game executables and expected file sizes.
- Direct launch after installation, with a hidden installer window during gameplay.
- GitHub Release checks and optional updates using a pinned Ed25519 public key and SHA-256 verification.
- A separate update helper with previous-version backup and app relaunch.
- Persistent game files, save data, logs, and shader storage outside the application bundle.
- Packaging scripts, updater and ISO tests, and third-party license notices.

### Playable baseline

- Campaign creation, gameplay into the second mission, saving, continuation, and Guerrilla observed working on the development Mac.
- Preserves the FBO renderer path, mip0 workaround, and campaign content-enumeration correction.

### Known limitations

- Cinematic flicker and corruption after some scene reloads remain.
- Shader compilation can still cause pauses.
- Apple Silicon and macOS 27.0+ only in the current package; another Mac has not yet been validated.
- Ad-hoc signing only; no Apple notarization.
- Upgrading between two public Releases still needs validation.

## Project page refresh

- English documentation, a custom banner, download badges, feature and compatibility tables, and clearer installation/support instructions.
- Documentation changes do not change the published runtime or require reinstalling the game.
