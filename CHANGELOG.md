# Changelog

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
