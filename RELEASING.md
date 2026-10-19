# Publishing a release

1. Test changes while preserving the previous playable baseline. Update `version`, `build` (a strictly increasing integer), `tag`, and the actual minimum macOS version in `launcher/version.json`.
2. Point `GRFS_RUNTIME_DIR` at the tested runtime and optionally set `GRFS_ICON_FILE`. Run `python3 launcher/build.py`.
3. Compile `launcher/release-tools/SignUpdate.swift`. Keep the private maintenance key **outside the repository**, with permissions `600`. Do not regenerate it for each release: installed apps pin the existing public key. Keep a secure backup outside GitHub.
4. For a new project only, initialize a key with `SignUpdate init /private/path/update.key launcher/update-public-key.txt`. This distribution already has a pinned public key: use its existing private key.
5. Sign the manifest with `SignUpdate sign /private/path/update.key launcher/dist/update-payload.json launcher/dist/update.json`.
6. Create a public Release with a tag matching `version.json`. Attach `GRFS-Recompiled-macOS-arm64.zip`, `SHA256SUMS.txt`, `update.json`, and the corresponding SDK source/license archive. Publish only after all assets finish uploading.
7. Verify the public download, signed manifest, and upgrade from the previous version. Drafts and prereleases are not selected by the updater's `releases/latest` endpoint.

Never publish `.release-secrets`, private keys, tokens, ISOs, original XEX files, saves, or extracted game data. Compiled archives belong in Releases, not source history.

The replacement helper restores the old app if moving the staged replacement fails. If the new app launches but has a functional regression, close the game and recover `~/Library/Application Support/GRFS Recompiled/Backups/Previous.app.backup` by copying it to Applications with an `.app` extension. Only one previous version is kept outside Applications; redundant legacy backup apps are moved to recoverable Trash. The helper does not automatically detect gameplay regressions.

Documentation-only updates do not require rebuilding or resigning the current Release assets.
