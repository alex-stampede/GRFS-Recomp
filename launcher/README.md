# Launcher development

Native AppKit XDVDFS installer and signed updater. See the root [README](../README.md) for player instructions and [RELEASING.md](../RELEASING.md) for release maintenance.

| File | Responsibility |
| :--- | :--- |
| `main.swift` | App entry point and ISO inspection/extraction CLI |
| `Launcher.swift` | ISO selection, validation, progress, game launch, persistent data |
| `Updater.swift` | GitHub Release lookup, user consent, Ed25519 verification, staged download |
| `UpdateHelper.swift` | App replacement, previous-version backup, and relaunch |
| `GameTitle.m` | Window-title adapter that leaves the validated runtime unchanged |
| `compatible-game.json` | Compatible executable hashes; no executable content |
| `required-files.json` | Expected file names and sizes |
| `build.py` | Packaging, ad-hoc signing, ZIP, checksum, and unsigned update payload |

## Verification

Compile `main.swift`, `Launcher.swift`, and `Updater.swift` with AppKit and CryptoKit to `/private/tmp/grfs-launcher-build`, then run `python3 launcher/test_iso.py`.

Compile `UpdateHelper.swift` with AppKit to `/private/tmp/grfs-update-helper`, then run `python3 launcher/test_updates.py`.

Tests cover extraction, malformed images, signature validation, tampering, incorrect keys, allowed download origin, build comparisons, app replacement, previous-version backup, and preservation of external save data. The published Release's lookup, manifest verification, download checksum, app identity/build, and code signature have also been exercised through the updater against GitHub.

The private signing key is not included. A build signed with another key will be rejected by apps that pin this project's current public key.
