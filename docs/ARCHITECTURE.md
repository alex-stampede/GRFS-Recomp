# Architecture and patch map

GRFS-Recomp executes statically translated Xbox 360 PowerPC game code on ARM64 through ReXGlue. The Xenos backend translates guest GPU work to Vulkan; MoltenVK maps Vulkan to Metal. The launcher is native AppKit. This is not a native Metal renderer and the Steam/PC executable is not used.

| Layer | Source entry points | Responsibility |
| --- | --- | --- |
| Installer / launcher | `launcher/Launcher.swift`, `main.swift`, `LauncherTheme.swift` | Local ISO validation/extraction, launch arguments, cache paths, UI |
| Updates / restart | `launcher/Updater.swift`, `UpdateHelper.swift`, `RestartRequest.swift` | Signed download verification, app replacement, explicit restart tokens |
| Host game integration | `game-src/grfs_app.h`, `grfs_pc_options.h`, `grfs_frame_counter.h`, `grfs_output_size.h` | F5 options, keyboard/mouse, preferences, guest swap measurement |
| Presentation adapters | `launcher/GameTitle.m`, `FullscreenDiagnostics.m`, `PerformanceHUD.mm`, `ShaderPreparation.swift` | macOS title/icon/fullscreen integration, HUD and preparation panel |
| ReXGlue runtime | Release SDK source archives and `patches/` | Kernel/filesystem/input shims, SDL window and Vulkan presentation |
| Xenos graphics | Release SDK `src/graphics/` plus patches below | Texture fetch translation, shader modules, EDRAM, render targets, pipelines |
| Game implementation | Generated locally; excluded from Git | Translated default image and AICLASS module, derived from the user's game |

## Graphics modifications

This is a navigation map, not an automatically applicable patch series. Consult the release source archive and [BUILDING.md](BUILDING.md) before rebuilding.

| Patch / helper | Area and behavior |
| --- | --- |
| `macos-texture-exp-adjust.patch` | Corrects texture result exponent decoding in SPIR-V fetch translation |
| `macos-spirv-optimizer.patch` | Runs SPIRV-Tools optimization with structural validation and original-module fallback; validation does not prove visual equivalence |
| `macos-three-shader-flow.patch` | Simplifies control flow for three exact pixel-shader hash/modification pairs; not a global material replacement |
| `macos-independent-clear-pair.patch`, `ClearPairGuard.h` | Groups eligible independent depth/color clears while retaining fallback and dependency checks |
| `macos-vulkan-persistent-cache.patch` | Persistent shader/pipeline storage handling |
| `macos-pipeline-preload-bypass.patch` | Earlier on-demand pipeline route; superseded by the catalog implementation for v12 |
| `macos-catalog-prewarm.patch` | v12 local catalog merge, startup preparation and compatible private driver cache |
| `macos-metal-swapchain.patch` | macOS swapchain replacement ordering for native fullscreen |
| `macos-output-resolution.patch` | Presentation output cap; not internal Xenos render-target scaling |
| `macos-presentation-limit-*.patch`, `PresentLimit.h` | Host presentation pacing; does not unlock game logic |
| `macos-eager-drawable.patch` | Experimental presentation path; presence in the tree does not mean it is enabled by the launcher |
| `xgetlanguage-user-preference.patch`, `grfs-native-options.patch` | Runtime language selection and game-side options hook |

Mip0 is a sampler workaround that avoids observed seams; correct dynamic mipmaps remain unresolved. Unclipped vertex processing on the CPU is used for draw extent estimation, reducing oversized EDRAM transfers. It is not a general software renderer. Shader compilation and queue submission remain synchronous in the published setup.

## Data and measurement boundaries

Persistent user data lives outside the app at `~/Library/Application Support/GRFS Recompiled/`. `Game/` contains extracted assets and `UserData/` contains saves/settings. Cache namespaces vary by release: v11 uses `CacheCombinedFlowV1`; v12 uses `Diagnostics/CacheCatalogV1`. Preserve old namespaces when comparing versions.

XSH storage contains guest shader programs; pipeline descriptions contain combinations of shaders and render state. A native driver cache is hardware/driver dependent. Neither a shader inventory nor a completed startup progress bar proves that every pipeline needed by every mission is prepared. Do not distribute these game-derived caches in contribution reports.

Metal HUD reports host presentations and GPU timing. The custom counter reports guest swap submissions. Repeated presentation of an old image can produce a high Metal FPS reading during a game stall. Neither counter alone proves unique completed game frames. See [TESTING.md](TESTING.md).
