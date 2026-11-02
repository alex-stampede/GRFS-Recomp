# Development status — November 2, 2026

This page distinguishes published software, historical validation and current reports. It is not a claim that all scenes work correctly.

## Published vs experimental

- **Latest published app: v0.10.0.12.** See its [release](https://github.com/alex-stampede/GRFS-Recomp/releases/tag/v0.10.0.12), signed update manifest and corresponding sources. This contributor-preparation change does not replace the binary or issue an update.
- Campaign, Gunsmith and Guerrilla have been playable. Saving/continuation, keyboard/mouse, F5, restart and native fullscreen have been exercised. These are observed features, not complete mission coverage.
- **Known visual problems remain**, including incorrect weapon/accessory materials, stretched geometry in some scenes/NVG and corruption after scene transitions. Historical reports of a clean run do not establish repeat-session stability.
- ISO shader-bank extraction and the recent cache/material comparison apps are **local experiments, not a new public release**. Their files and private reports are not part of `main`.
- Development machine: Mac mini M4 Pro, 24 GB. Additional owner testing: MacBook Air M3, 8 GB. No guaranteed 30 FPS; performance varies by scene and session.

## Investigation results available to contributors

These are owner-reported observations and inspected diagnostic metadata, not an independently reproduced clean-room benchmark:

| Observation | What it establishes / does not establish |
| --- | --- |
| Slow M3 scenes become faster in NVG than in normal vision | The rendering workload changes; it does not identify texture bandwidth, a particular shader or CPU/GPU synchronization as the sole cause |
| Corruption reproduced with a fresh empty diagnostic cache, zero stored pipeline preload and private driver-cache reuse disabled | Inherited cache contents and startup prewarm are not necessary to reproduce the issue; repeated cache deletion is not a demonstrated fix |
| Returning to the October 28 combined GPU binary still left incorrect weapon materials | The newer GPU binary alone does not explain all reported corruption; this was not a full runtime rollback |
| A subsequent fresh-cache run disabled general SPIRV-Tools optimization; incorrect accessories and NVG geometry still appeared | Disabling the general optimizer is not sufficient to fix the issue. Three targeted flow simplifications and paired clears were still enabled |
| Mip0 remained active in these reports | The failures cannot be attributed merely to accidentally enabling automatic mip selection |
| No shader-module creation error in the inspected last comparison | Successful module/pipeline creation does not establish correct pixels or vertex data |

The root cause of the remaining material/geometry corruption is **unconfirmed**. Do not report the latest comparison as a fixed release, or assign all corruption to shader caches, the optimizer or mipmaps without new evidence.

## Useful work now

1. Reproduce a material failure quickly in Gunsmith (PP19 accessories or PP2000), record the exact release/runtime/settings and identify the affected draw, texture fetches, shader variant and resource lifetime. Avoid making testers replay early campaign missions unnecessarily.
2. Separate targeted shader-flow transforms, paired clears, texture decoding/binding and runtime/resource synchronization with controlled changes. Keep reference imagery and preserve all effects.
3. Make the full ISO-to-runtime build reproducible from public inputs plus the user's own ISO.
4. Reduce sustained frame cost and first-use pipeline hitches separately; report honest counters and frame times.
5. Improve preparation feedback and measurement without changing rendering correctness.

Older release-specific validation remains in this directory for provenance. It must be read with the later regressions above in mind.
