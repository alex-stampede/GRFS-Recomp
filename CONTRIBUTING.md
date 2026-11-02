# Contributing to GRFS-Recomp

Welcome! Help with graphics correctness, frame pacing, Apple Silicon performance, build reproducibility, testing and documentation is appreciated. This is an experimental, heavily AI-assisted project. Small, understandable changes with evidence are especially useful.

You do not need write access. Fork the repository, create a branch from `main`, and open a pull request. Please discuss broad renderer rewrites in an issue before investing substantial time.

## Start here

- [Developer setup and build boundaries](docs/BUILDING.md)
- [Architecture and patch map](docs/ARCHITECTURE.md)
- [Current status and investigation results](docs/DEVELOPMENT_STATUS.md)
- [Performance and visual validation](docs/TESTING.md)
- [Open contributor tasks](https://github.com/alex-stampede/GRFS-Recomp/issues)

The public tree supports rebuilding the launcher around a compatible release runtime. A complete, verified ISO-to-runtime build is **not yet available**. SDK snapshots and source patches are public, but reconstructing the exact generated-game build remains an explicit contributor task. Do not assume a new upstream SDK checkout is binary-compatible with a release.

## Workflow

1. Fork and clone your fork. Create a focused branch, for example `fix/material-fetch`.
2. Read the relevant source and patch notes. Record the release/commit and SDK source you use.
3. Keep a working release and your own save backup. Use a separate cache for renderer experiments; never require deletion of `Game/` or `UserData/`.
4. Make one explainable change. Describe why it should preserve behavior and how to disable or revert it.
5. Run `python3 scripts/check_contributor.py`. Follow the additional checks in [TESTING.md](docs/TESTING.md) for the area changed.
6. Open a PR describing the problem, behavior after the change, checks run and remaining limitations. Draft PRs and incomplete investigations are welcome when clearly marked.

AI-assisted contributions are welcome. Contributors must review their changes, understand the affected behavior and report actual validation. Generated explanations, compilation success and SPIR-V validation alone are not evidence of visual correctness or faster gameplay.

## What to include

For performance changes, compare the same scene, camera, resolution, display mode and cache state. Report frame times as well as the exact frame-rate counter used. Separate startup compilation, first-use hitches and sustained performance. Preserve normal vision, NVG, transparency, shadows, particles, controls, saves and restart behavior. Record failures as well as improvements.

For SDK changes, include the source baseline and patch, affected files, required dependencies and rebuild instructions. Do not submit only a replacement dylib. Preserve upstream copyright and license notices; SDK-derived changes retain their applicable upstream license, not the launcher's MIT license.

For launcher changes, use the game-free test suite and package checks. A documentation-only PR does not need a gameplay run. If hardware or game access is unavailable, say so; do not claim those checks passed.

## Files that must stay local

Do not commit or attach ISOs, original executables, extracted assets, generated game implementations, shader microcode, pipeline/native cache binaries, saves, signing keys or tokens. Only source, configuration, patches, synthetic fixtures and appropriately redacted reports belong here. Check logs for user names, home paths and personal information before uploading them. Do not upload an entire diagnostic ZIP without reviewing its contents.

Original launcher/release tooling is covered by [LICENSE](LICENSE); dependencies and SDK-derived work retain their own terms in [THIRD_PARTY_LICENSES](THIRD_PARTY_LICENSES/). This project grants no rights to the game or its artwork. No CLA or special account access is required by this contribution workflow.

## Review and releases

Maintainers review PRs before merging. Keep unrelated refactors separate. Do not change the update public key, release version or signed update files as part of an ordinary contribution. Public releases and update signing remain maintainer tasks; contributors never need the private signing key. Passing CI checks the host tooling only, not campaign or renderer correctness.
