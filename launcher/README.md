# Launcher development

Native AppKit XDVDFS installer and signed updater. See the root [README](../README.md) for player instructions and [RELEASING.md](../RELEASING.md) for release maintenance.

| File | Responsibility |
| :--- | :--- |
| `main.swift` | App entry point and ISO inspection/extraction CLI |
| `Launcher.swift` | ISO selection, validation, progress, game launch, persistent data |
| `Updater.swift` | GitHub Release lookup, user consent, Ed25519 verification, staged download |
| `UpdateHelper.swift` | App replacement, previous-version backup, and relaunch |
| `LauncherTheme.swift` | GRFS artwork, dark AppKit theme, progress and action button |
| `Resources/Background.jpg` | User-provided launcher background; game artwork retains its owners' rights |
| `GameTitle.m` | Window-title adapter that leaves the validated runtime unchanged |
| `compatible-game.json` | Compatible executable hashes; no executable content |
| `required-files.json` | Expected file names and sizes |
| `build.py` | Packaging, ad-hoc signing, ZIP, checksum, and unsigned update payload |

## Verification

Compile `main.swift`, `Launcher.swift`, `Updater.swift`, `LauncherTheme.swift`, and `LegacyBackups.swift` with AppKit and CryptoKit to `/private/tmp/grfs-launcher-build`, then run `python3 launcher/test_iso.py`.

Compile `UpdateHelper.swift` with AppKit to `/private/tmp/grfs-update-helper`, then run `python3 launcher/test_updates.py`.

Tests cover extraction, malformed images, signature validation, tampering, incorrect keys, allowed download origin, build comparisons, app replacement, previous-version backup, and preservation of external save data. The published Release's lookup, manifest verification, download checksum, app identity/build, and code signature have also been exercised through the updater against GitHub.

The private signing key is not included. A build signed with another key will be rejected by apps that pin this project's current public key.

## Application identity

The packaged game lives in `Contents/Resources/Game.app`, with bundle identifier `local.grfs.game`. Its executable and runtime libraries remain together in `Game.app/Contents/MacOS`, preserving executable-relative library loading. Both the launcher and nested game bundle use the same `GRFS.icns`.

`test_package.py` checks both bundle identities, matching icons, Foundation main-bundle resolution, code signatures, and unchanged runtime code sections. Set `GRFS_RUNTIME_DIR` to the tested baseline before running it. The actual public upgrade from v0.10.0.1 to v0.10.0.2 was also applied through the installed launcher and relaunched the game on the development Mac.

## Fullscreen patch

`../patches/macos-metal-swapchain.patch` changes only macOS swapchain replacement ordering in the SDK presenter: destroy the previous swapchain before constructing its replacement, avoiding MoltenVK resetting the replacement’s CAMetalLayer to 1×1 while completing older presents. The compiled runtime must include this patch. The owner confirmed visible fullscreen and windowed output in the instrumented test.

The package test also checks that the bundled Vulkan ICD manifest exists and resolves to the bundled MoltenVK library.

### v0.10.0.6 packaging

The release GPU includes `patches/macos-vulkan-persistent-cache.patch` against
the previously distributed SDK sources. Build a compatible SDK with that patch,
then set `GRFS_GPU_FILE` to its `librexgpu-xenos.dylib` when using a preserved
`GRFS_RUNTIME_DIR`. `build.py` generates the transparent ICNS from DockIcon.png.
`GRFS_OUTPUT_DIR` optionally selects a separate packaging directory. The release
uses synchronous shaders and a rollback-safe CachePersistent directory.

### v0.10.0.7 packaging

Compile the game with all three `game-src` headers. The new macOS VdSwap wrapper
must be in the executable; the SDK runtime/GPU remain the protected v0.10.0.6
versions. `build.py` compiles the title shim and `PerformanceHUD.mm` as Objective-C++.
Keep its exported HUD bridge symbols; the game resolves them at runtime. The HUD
is disabled by default, opt-in in F5, and persists via `UserData/grfs.toml`.

### v0.10.0.10 packaging

Apply macos-texture-exp-adjust.patch and macos-pipeline-preload-bypass.patch in addition to the retained v9 optimizer patch. Pass the resulting GPU via GRFS_GPU_FILE and preserve the other v9 runtime files. Launcher enables execute_unclipped_draw_vs_on_cpu, disables eager drawable acquisition, and bypasses stored pipeline preload. CacheTextureExponentV1 is separate from old caches; no legacy shader/pipeline import occurs. Saves and installed Game are unchanged. Owner checks are recorded in docs/validation-texture-edram-20261027.md; the owner accepted the final package on M3 and approved publication.

### v0.10.0.11 packaging

Apply macos-three-shader-flow.patch and macos-independent-clear-pair.patch after the retained v10 patches; copy patches/ClearPairGuard.h alongside render_target_cache.cpp. The explicit dynamic-rendering helper adds a method but no class fields. Rebuild both command_processor.cpp and render_target_cache.cpp. Package the tested GPU library with GRFS_GPU_FILE. Launcher enables GRFS_FORWARD_FLOW=1 and GRFS_CLEAR_PAIR=1 with separate CacheCombinedFlowV1. Original fallback, saves and installer remain. See docs/validation-combined-flow-20261028.md.
