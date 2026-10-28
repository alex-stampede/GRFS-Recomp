## 0.10.0.11 — October 28, 2026

- Simplify control flow in three exact pixel shader variants (C8B7, FBF5 and D204), retaining texture operations, precision and shader interfaces.
- Group compatible independent depth/stencil and color resolve clears with explicit dynamic-rendering attachment views, including guest 10-bit color. Keep the original fallback when transfers, host-depth stores, overlap or unsupported layouts are involved.
- Preserve the original clear rectangle and format conversion; no global rendering-mode or synchronization change.
- Use a separate CacheCombinedFlowV1 namespace; retain earlier caches, saves and installed game data.
- Owner tested the combined build on MacBook Air M3 and reported no visual bugs. Two captures confirmed 777 grouped clears. Guest cadence remained 12.91–13.11 requests/s (76.3–77.5 ms mean) in the tested slow scene; these are not displayed FPS and no controlled uplift or guaranteed 30 FPS is claimed.
- Dynamic-rendering GPU equivalence checks passed 48 rectangle/value cases. No diagnostic F8/F9 selector or GPU stage instrumentation is included in the normal launcher.


## Validation scope

The M3 owner reported clean visuals in the combined test. Its two F8 captures recorded 384 and 393 grouped clears, respectively, with 12.909/13.111 guest requests/s, mean intervals77.463/76.272 ms and p95 91.579/89.062 ms. Shader identities confirm all three exact variants were exercised. The second capture's longest interval was145.514 ms, with none over200 ms; the first had a402.465 ms maximum. Previous sessions are reference measurements, not a same-session controlled baseline.

A real Vulkan/MoltenVK fixture on M4 Pro compared separate vs combined dynamic clears:48 varied rectangle/normalized10-bit input cases, 7,077,888 bytes identical across both MSAA2 samples of color/depth/stencil, including267,274 outside-rectangle sample pixels. It uses the SDK-equivalent A8B8G8R8 host color and D32Float/S8. This checks the API operation, not every gameplay scene or format. The guard passed20,000 randomized footprint cases.

The normal release preserves the tested GPU text sections and switches both changes on without the experimental selection dialog or GPU stage capture injection. Mip0, synchronous compilation/queue submission and one pipeline worker remain. No game assets, saves, capture logs or signing keys are distributed.
