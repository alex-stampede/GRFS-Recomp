import Foundation
let root = FileManager.default.temporaryDirectory.appendingPathComponent("grfs-restart-" + UUID().uuidString)
try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: root) }
let normal = RestartRequest(directory: root)
assert(!normal.consume(exitStatus: 0))
let valid = RestartRequest(directory: root)
try Data(valid.token.utf8).write(to: valid.url, options: .atomic)
assert(valid.consume(exitStatus: 0))
assert(!valid.consume(exitStatus: 0))
let crashed = RestartRequest(directory: root)
try Data(crashed.token.utf8).write(to: crashed.url)
assert(!crashed.consume(exitStatus: 1))
assert(!FileManager.default.fileExists(atPath: crashed.url.path))
let stale = RestartRequest(directory: root)
try Data(valid.token.utf8).write(to: stale.url)
assert(!stale.consume(exitStatus: 0))
assert(stale.environment["GRFS_RESTART_REQUEST"] == stale.url.path)
assert(stale.environment["GRFS_RESTART_TOKEN"] == stale.token)
print("PASS restart: explicit one-use token only; normal close, crash and stale request do not relaunch")

let config = root.appendingPathComponent("grfs.toml")
assert(fullscreenArgument(config: config) == "--fullscreen")
for (text, expected) in [("fullscreen = false\n", "--no-fullscreen"), ("fullscreen = true # saved\n", "--fullscreen"), ("# fullscreen = false\n", "--fullscreen"), ("[other]\nfullscreen = false\n", "--fullscreen")] {
    try text.write(to: config, atomically: true, encoding: .utf8)
    assert(fullscreenArgument(config: config) == expected)
}
print("PASS fullscreen startup preference and fallback")
