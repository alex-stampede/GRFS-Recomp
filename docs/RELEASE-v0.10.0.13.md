## Rendering stability and readback reuse

- Keeps GPU shader memory writes synchronized with CPU reads, fixing the corruption observed in recent tests.
- Reuses the synchronous readback staging buffer rather than allocating and destroying it for every operation.
- Keeps fast resolve readback, Mip0 and simplified shader control flow.
- Removes the modal launcher quit warning while the game is running.

The M3 tester reported steadier and better performance, with no graphical errors observed in Gunsmith, campaign and Guerrilla. No controlled percentage improvement or universal 30 FPS guarantee is claimed.

### Known limitations

Creating an additional campaign while retaining unlocks is still unresolved. This release does not add the experimental campaign-folder selector or guest cache mount. Shader caches are isolated per launch to avoid reusing problematic stored state; startup and first-use compilation hitches can remain. The v12 startup catalog preparation is disabled in this release.

Use your own Xbox 360 ISO. Existing installation and UserData are retained. Download `GRFS-Recompiled-macOS-arm64.zip`, or update through the launcher. The update manifest is signed with the existing pinned key.
