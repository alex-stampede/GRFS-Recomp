# Building and developer setup

## What can be built today

| Goal | Public workflow |
| --- | --- |
| Run host tests without the game or SDK | `python3 scripts/check_contributor.py` on macOS with Xcode command-line tools and Python 3 |
| Rebuild the launcher and package it with the release runtime | Supported below; the runtime is reused, not rebuilt |
| Inspect and modify SDK graphics patches | Public patches and corresponding release source archives are available |
| Recreate the exact complete game/runtime from an ISO | Not yet a verified clean-checkout workflow; see the open reproducibility task |

Do not interpret a successful launcher build as a successful recompilation of the game. Published binaries currently require Apple Silicon and macOS 27.0 or later. The host-only CI suite uses macOS 15; this does not establish gameplay compatibility with macOS 15.

## 1. Host tooling and tests

Install Xcode command-line tools if needed (`xcode-select --install`) and Python 3. Clone your fork, then run from its root:

```sh
python3 scripts/check_contributor.py
```

The script builds the public Swift host sources and runs synthetic ISO extraction, update signature/replacement, restart-token and output-size tests. It uses a temporary directory, does not launch the game and does not access your real save directory. No private signing key, SDK checkout, ISO or game assets are needed.

## 2. Rebuild the launcher with a release runtime

Download and unzip the [v0.10.0.12 app](https://github.com/alex-stampede/GRFS-Recomp/releases/tag/v0.10.0.12). Keep the downloaded app separate from the output directory. On an Apple Silicon Mac, from the repository root:

```sh
export GRFS_RUNTIME_DIR="/absolute/path/to/GRFS Recompiled.app/Contents/Resources/Game.app/Contents/MacOS"
export GRFS_OUTPUT_DIR="$PWD/.build/dev"
python3 launcher/build.py
python3 launcher/test_package.py
```

Replace the absolute path with your unzipped app location. The input directory must contain `grfs`, `librexruntime.dylib`, `librexgpu-xenos.dylib`, `libgrfs_AICLASS_X360_F.dylib`, `libTracyClient.dylib` and `vulkan/`. Keep these from one release; mixing runtime/GPU revisions is not a supported baseline. `GRFS_GPU_FILE` is an optional explicit override for a GPU library you have rebuilt and are testing.

The output is `.build/dev/GRFS Recompiled.app` and a ZIP. The build script recreates that output app, compiles the launcher, title/HUD shim and update helper, and signs locally with an ad-hoc signature. It does not install or publish it, and creates no production-signed update manifest. No production key is needed.

Opening a development app uses the same `~/Library/Application Support/GRFS Recompiled/` data as the normal launcher. Back up `UserData/` before gameplay testing, keep other GRFS instances closed, and retain your working release. The published launcher can offer official updates; decline those while inspecting a local candidate. Host-only tests avoid this shared-data path entirely.

## 3. Work on the SDK or generated game

The release's `SDK-SOURCE.txt` identifies its SDK source baseline and corresponding patch archive:

- [Original development SDK snapshot](https://github.com/alex-stampede/GRFS-Recomp/releases/download/v0.10.0.1/ReXGlue-SDK-source.tar.gz)
- [v0.10.0.12 sources and patches](https://github.com/alex-stampede/GRFS-Recomp/releases/download/v0.10.0.12/GRFS-v0.10.0.12-source-patches.tar.gz)
- [Public patch map](ARCHITECTURE.md)
- [Game host integration notes](../game-src/README.md)

Use the matching source archive rather than treating upstream `main` as the release baseline. Some patches are incremental against earlier development states; they are not a universally applicable ordered series. For v12, the catalog-prewarm implementation replaces the earlier pipeline-preload-bypass implementation. Do not apply both blindly. Preserve helper headers such as `ClearPairGuard.h` and `PresentLimit.h` beside their consuming SDK sources. Archives include corresponding modified source where the patch alone is insufficient.

Still needed for a verified full build: a portable project/bootstrap configuration, complete code-generation inputs and overrides, pinned dependency/toolchain information, a checked patch application sequence, and a clean build that produces both game modules with the host hooks. These steps must be validated against a contributor-owned compatible ISO. Generated game implementations and original assets must remain local. We welcome PRs that remove these build barriers; do not fill missing steps with guessed commands.
