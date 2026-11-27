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

Use the [v3.1.1 reference app](https://github.com/alex-stampede/GRFS-Recomp/releases/tag/v3.1.1), the recompiled TU3 game app, the verified title update files, and their corresponding ReXGlue SDK. See the [TU3 build notes](../tu3/README.md) for the input inventory.

```sh
export GRFS_STABLE_APP="/absolute/path/to/GRFS Recompiled.app"
export GRFS_TU3_GAME_APP="/absolute/path/to/TU3 game.app"
export GRFS_TU3_ASSETS="/absolute/path/to/extracted TU3"
export GRFS_SDK_DIR="/absolute/path/to/rexglue-sdk"
export GRFS_OUTPUT_DIR="$PWD/.build/dev"
python3 launcher/build.py
```

Use a fresh output directory. The build produces an ad-hoc signed app, a ZIP, and an unsigned updater payload. It retains the renderer and updater from the reference app. No production key is needed.

Opening a development app uses the same `~/Library/Application Support/GRFS Recompiled/` data as the normal launcher. Back up `UserData/` before gameplay testing, keep other GRFS instances closed, and retain your working release. The published launcher can offer official updates; decline those while inspecting a local candidate. Host-only tests avoid this shared-data path entirely.

## 3. Work on the SDK or generated game

The release's `SDK-SOURCE.txt` identifies its SDK source baseline and corresponding patch archive:

- [Original development SDK snapshot](https://github.com/alex-stampede/GRFS-Recomp/releases/download/v0.10.0.1/ReXGlue-SDK-source.tar.gz)
- [v0.10.0.12 sources and patches](https://github.com/alex-stampede/GRFS-Recomp/releases/download/v0.10.0.12/GRFS-v0.10.0.12-source-patches.tar.gz)
- [Public patch map](ARCHITECTURE.md)
- [Game host integration notes](../game-src/README.md)

Use the matching source archive rather than treating upstream `main` as the release baseline. Some patches are incremental against earlier development states; they are not a universally applicable ordered series. For v12, the catalog-prewarm implementation replaces the earlier pipeline-preload-bypass implementation. Do not apply both blindly. Preserve helper headers such as `ClearPairGuard.h` and `PresentLimit.h` beside their consuming SDK sources. Archives include corresponding modified source where the patch alone is insufficient.

Still needed for a verified full build: a portable project/bootstrap configuration, complete code-generation inputs and overrides, pinned dependency/toolchain information, a checked patch application sequence, and a clean build that produces both game modules with the host hooks. These steps must be validated against a contributor-owned compatible ISO. Generated game implementations and original assets must remain local. We welcome PRs that remove these build barriers; do not fill missing steps with guessed commands.
