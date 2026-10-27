# v0.10.0.10 validation

Build 2026102701. The owner tested the packaged app on M3, reported that it works very well, and explicitly approved GitHub publication.

Configuration matches owner-tested extentOn trial: corrected texture exponent word3 field, SPIR-V enabled, cached pipeline preload and pipeline-record append bypassed, extent estimation enabled, eager drawable absent, synchronous compilation and MoltenVK queue submission, Mip0/MSAA retained. CacheTextureExponentV1 is a separate production namespace; no old-cache import or deletion. UserData, installed Game, F5 and restart protocol unchanged.

Evidence: docs/validation-texture-edram-20261027.md, including two successful extentOn sessions and owner extentOn → extentOff → extentOn visual confirmation. No percentage/FPS improvement claimed. Exact root cause of geometry corruption remains unproven; this is the empirically validated mitigation configuration.

Checks passed:
- C++ exponent field fixture: all 65536 exponent/LOD pairs against SDK struct.
- Runtime trial smoke on M4 Pro: GPU initialization, optimizer and bypass active, clean requested stop.
- Production launcher and nested package compile/signature verification, icon identity, Vulkan driver paths and Mach-O code comparison with intended runtime.
- Existing restart tests: one-use tokens, normal exit/crash/stale behavior and fullscreen preference.
- Existing updater tests: signatures/tampering/keys/allowed origins/version monotonicity; app replacement, one previous-app backup, save preservation and failure behavior.
- Existing ISO tests against packaged launcher: exact extraction and rejection of traversal/out-of-bounds/truncated images.
- ZIP integrity; signed candidate update envelope verified using pinned public key and ZIP hash/size/version.

Archive SHA256: b9be5403ff42384dbbbff9c3a020d0355e648f5b7bed41e185dc632d5f6fc177.

Final package acceptance: owner reported the app works very well and approved publication. This does not constitute an instrumented FPS benchmark or a detailed per-feature test transcript. Release publication/public-download verification follow separately. The signed manifest targets the v0.10.0.10 release.
