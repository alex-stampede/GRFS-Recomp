# Testing and performance evidence

## Host changes

Run `python3 scripts/check_contributor.py` on macOS. It exercises synthetic ISO validation/extraction, signed update verification and replacement in temporary fake bundles, restart tokens and output-size calculations. It launches no game and requires no ISO. For a packaged launcher, run `python3 launcher/test_package.py` with the same `GRFS_RUNTIME_DIR`, optional `GRFS_GPU_FILE` and `GRFS_OUTPUT_DIR` used to build it.

CI covers host tooling only. It does not exercise the GPU, actual ISO installation, original game code, hardware controllers or save compatibility. Do not claim those from a green check.

## Renderer/performance comparison

Record Mac model/chip, RAM, macOS, power/Low Power Mode, display refresh, app tag/commit, SDK/runtime origin and all changed arguments/environment settings. Compare the same mission checkpoint, camera, output cap and window/fullscreen mode. Keep background workload and thermal conditions comparable. Native fullscreen/Game Mode already work; do not treat re-enabling them as a new renderer optimization.

Separate these three measurements:

- Startup preparation duration and number of known variants.
- First-use/compilation hitches, with duration/count and pipeline events when available.
- Sustained frame cost after stabilization, using comparable 60-second captures where practical. Repeat A/B or A/B/A to distinguish warm-cache and thermal effects.

Report which counter you used. Metal HUD measures host presentations and GPU timing; guest swap requests measure CPU submissions. Neither necessarily counts unique completed game images. Report mean frame interval and p95/p99 from raw samples when available, plus hitch durations. State sample duration/count and whether loading was included. Do not average FPS values or label request rates as displayed FPS. Do not fabricate percentiles from screenshots.

Example report:

| Build / setting | Scene and cache state | Counter | Mean interval | p95 | Hitches | Visual changes |
| --- | --- | --- | --- | --- | --- | --- |
| Baseline | Same checkpoint, warmed | Name the counter | measured ms | measured ms or unavailable | count/duration | observed |
| Candidate | Same checkpoint, warmed | Same counter | measured ms | measured ms or unavailable | count/duration | observed |

A cold candidate compared with a warmed baseline is not a valid sustained-speed comparison. Low resolution, Mip0/Mip1, disabled effects or different vision modes change the workload; keep them fixed unless that variable is the explicit subject of the comparison. Output resolution is not internal render-target resolution.

## Visual and functional checks

For rendering changes, inspect Gunsmith weapons/accessories, normal and NVG campaign views, Guerrilla, transparency/particles, shadows, cinematics, and returning to the menu. Repeat after closing/reopening the same app; some failures appeared only on later sessions. A fast frame with missing effects or corrupted geometry is a regression.

For runtime/launcher changes, also check F5, mouse capture/F6, keyboard mappings, window/fullscreen transitions, explicit save/restart (one relaunch), normal exit (no relaunch), campaign continuation and Guerrilla transitions. Test controllers only if hardware is available and report that limitation otherwise. Back up your own saves; do not upload them or require their deletion.

## Reports and privacy

Logs normally live under `~/Library/Application Support/GRFS Recompiled/Logs/`; preparation runs may use `Preparation-…` subfolders. Diagnostic apps can export ZIPs, but those are not universal release features. F8/F9/F7 bindings from private trials are not a public diagnostic protocol.

Review archives before attaching anything. Share relevant redacted text, screenshots and timing summaries. Remove usernames/home paths, tokens and unrelated app contents. Do not upload ISOs, XEX files, game assets, generated game code, XSH/XPSO/native shader caches or saves. If an expected log/counter is missing, report it as unavailable rather than assuming it recorded successfully.
