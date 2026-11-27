# TU3 integration for Xbox 360 media 2DF41A75

This worktree is based on v3.1.1. The title-specific ReXGlue manifest records TU3 entry points and the module registry for Default and AICLASS. Apply the firing-range guard after code generation using apply-guard.py alongside the generated directory.

The private build and test workspace is the parent of this worktree. There, prepare-tu3.py validates an original disc and update package, stages the verified sibling XEXP files for ReXGlue, and retains the non-executable files on update:. No game files, generated title code, title update files or save data belong in this worktree.

## Standard launcher package

Use the verified 3.1.1 app, the recompiled TU3 game app, the extracted update
matching `update-assets.sha256`, and the ReXGlue SDK used by the runtime.

```sh
zsh tu3/launcher/package-stable.sh "$STABLE_APP" "$TU3_GAME_APP" "$TU3_ASSETS" "$REXGLUE_SDK" "$OUTPUT_DIR"
```

The packaging script retains the reference launcher identity, Metal and runtime
binaries, and pinned updater key. It replaces the two recompiled game modules and
bundles the verified TU3 payload. It writes the app, ZIP and unsigned update
manifest. See [release maintenance](../RELEASING.md) for the signing step.

At runtime the launcher prepares an APFS clone of the compatible game, places the
three XEXP files alongside their matching originals, and mounts the bundled
update assets at `update:\`. The DLC installer stages verification and extraction
outside the live content directory and publishes the verified content and its
metadata together.
