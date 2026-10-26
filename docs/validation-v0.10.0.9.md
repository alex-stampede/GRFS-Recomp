# v0.10.0.9 validation

The normal/NVG M3 report measured13.216/75.668ms versus21.673/46.140ms, with98–99%device GPUutilization and guest GPUfence waits. Native pipeline labels subsequently mapped the modes to different guest shader workloads. This does not prove one texture or mip0 caused the difference.

Rejected trials: disabling anisotropy17.896→17.495requests/s; alpha specialization17.766→17.829; bounded render areas17.207 in a separate run despite actual smaller areas. None is included.

SPIR-V trial report607790: scene1original17.676/56.574ms; scene2cold optimized14.861/67.289ms including12.656s pause. Apple compiler counters increased during that pause. Scene3warm optimized24.237/41.258ms/p9544.181; scene4original22.263/44.919ms/p9547.681. F9console markers determine actual variant; alternating runner mode labels for captures3/4 are incorrect. Sampling-tool lifetimes are excluded. Owner kept camera fixed and confirmed image preservation. Compare warm3/4, not cold2, for steady throughput. These are guest requests/intervals, not unique displayed FPS. No M3 optimization gain is claimed yet.

1030reference SPIR-V modules validated with the device's scalar-block-layout capability.343original module byte sequences matched their diagnostic high-bit-key counterparts exactly. The release optimizes the same original module bytes without diagnostic key changes. Optimized output is validated; failure retains original SPIR-V. Stage interfaces, bindings and specialization constants are preserved; no relaxed-math passes are enabled.

Final startup prepared896optimized modules from cached shader/pipeline records before gameplay. Thus the runtime integration applies to preloading as well as new modules. New/unseen pipelines may still compile during play. Eager drawable code retains fence/semaphore/queue ordering and synchronous MoltenVK submissions; no deferred-queue experiment is included.

Package checks passed: nested app identity,matching transparent icons,Vulkan manifest,code sections,deep strict ad-hoc signature. Game/guest-module code unchanged. Owner confirmed the final candidate image, smoother gameplay and working controls after the requested fullscreen,F5 and Guerrilla checks. Final candidate capture: 19.439requests/s,51.444ms,p95 66.439ms.
