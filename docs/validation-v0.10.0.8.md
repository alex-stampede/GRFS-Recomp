# v0.10.0.8 validation

- Owner confirmed F5 resolution and Fullscreen / Windowed selection, Save and restart, and application of both settings after the corrected restart path.
- Development log: restart requested at 09:35:28, window close processed, next launch created a 1600×900 swapchain at 09:35:29. Native fullscreen retained the 1600×900 cap.
- Initial candidate bypassed window close and waited in ReXApp::OnDestroy joining guest threads. This candidate was not published. The final version requests window close on the UI thread, using the established title termination path.
- One-use restart token tests cover requested restart, ordinary exit, crash, stale/wrong request and repeated consumption. Fullscreen preference parsing/fallback tests pass.
- Output cap tests cover 720p/900p/1080p, native, invalid value, zero-size/minimized, smaller window and aspect ratio preservation.
- Package checks pass: nested identity/Game Mode keys, bundled Vulkan paths, deep/strict ad-hoc signature, expected code sections and untouched GPU/guest module.
- Updater tests pass: signature, tampering, repository/HTTPS bounds, monotonic version, replacement/rollback backup and savedata preservation.
- Production update manifest verified against the existing pinned Ed25519 public key and ZIP digest/size.
- No new quantified M3 performance result is claimed. The cap changes presentation output, not Xbox internal target size. Mip0 and synchronous shader compilation remain.
