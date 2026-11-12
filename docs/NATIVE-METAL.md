# Native Metal 2.1 (experimental)

[Download the native Metal release](https://github.com/alex-stampede/GRFS-Recomp/releases/tag/v2.1.0-metal).

This is a real Xenos-to-Metal gameplay backend adapted from XeniOS commit `5290a3d5538d0121fcf0951a1a50d079ab2f9796`. The release includes the macOS ARM64 launcher, ISO installer, source overlay and third-party licenses. No game assets or saves are distributed. Requires macOS 27+ and your compatible Xbox 360 ISO.

The 64 constant-buffer slots preserve GPU completion fences and reduce forced command submissions. In the same-scene M4 Pro comparison, guest submissions changed from 23.66 to 29.97/s, mean interval from 42.26 to 33.36 ms, and p95 from 53.63 to 34.60 ms. These are guest submission measurements, not independently measured displayed FPS. Campaign gameplay was confirmed with no observed visual defects in that test. M3 and extended gameplay validation remain pending.

Extract the app into Applications. Existing Game and UserData folders are reused. Back up UserData before switching builds. The additional campaign slot issue is not resolved. First-use shader compilation can still hitch; this experimental release uses a separate fresh Metal cache per launch. Exhaustive precompilation is not implemented.

Version 0.10.0.13 remains on the stable updater channel; Metal is a manual prerelease download. The attached source overlay contains the port, helper MSL, launcher and measurement summary; its build script requires adapting the developer SDK paths and is not yet a standalone clean build.
