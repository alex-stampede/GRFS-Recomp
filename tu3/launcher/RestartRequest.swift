import Foundation

// Each child gets its own one-use request. A crash or stale file cannot restart it.
struct RestartRequest {
    let url: URL
    let token: String
    init(directory: URL) {
        token = UUID().uuidString
        url = directory.appendingPathComponent("restart-" + token + ".request")
    }
    var environment: [String: String] {
        ["GRFS_RESTART_REQUEST": url.path, "GRFS_RESTART_TOKEN": token]
    }
    func consume(exitStatus: Int32) -> Bool {
        defer {
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(atPath: url.path + ".tmp")
        }
        guard exitStatus == 0,
              let data = try? Data(contentsOf: url),
              data == Data(token.utf8) else { return false }
        return true
    }
}

// Read only the root fullscreen boolean emitted by the SDK's TOML serializer.
// Other preferences are still parsed by the runtime; no desktop mode switch.
func fullscreenArgument(config: URL) -> String {
    guard let text = try? String(contentsOf: config, encoding: .utf8) else { return "--fullscreen" }
    for raw in text.split(separator: "\n") {
        let line = raw.trimmingCharacters(in: .whitespaces)
        if line.hasPrefix("[") { break }
        let parts = line.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
        if parts.count == 2 && parts[0] == "fullscreen" {
            let value = parts[1].split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)[0].trimmingCharacters(in: .whitespaces)
            if value == "false" { return "--no-fullscreen" }
            if value == "true" { return "--fullscreen" }
        }
    }
    return "--fullscreen"
}
