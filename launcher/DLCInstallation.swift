import CryptoKit
import Foundation

struct DLCInstallation {
    let helper: URL
    let game: URL
    let profile: URL

    // Verified marketplace variants for Xbox 360 title 55530833.
    private static let packages = [
        "308382732020E811FC3B6B74E4D0CA2AC52D865955": "19dc5b60ae8c6156e003fe88da1aa58eeb465e50949c4341567285c112dc7e2b",
        "B546785D4392E5589EF5BE0F39DE7D9C62516F0D55": "62ea9bb048bee1980e7684e6f3204f6edcb679d25180f648ca1941f7ecbfb6e3",
        "CDD04B2890E387122E622DF13F88718CFDCB4F9755": "ca9c359a5bcd0d8b52b264aa880c907383fc38769fecc3871c11e7c23859aec4"
    ]

    func install(from folder: URL, progress: (Double, String) -> Void) throws -> Int {
        let marketplace = folder.appendingPathComponent("00000002")
        let input = fm.fileExists(atPath: marketplace.path) ? marketplace : folder
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]
        let entries = try fm.contentsOfDirectory(at: input, includingPropertiesForKeys: Array(keys), options: .skipsHiddenFiles)
        let candidates = try entries.compactMap { url -> (URL, Int, String)? in
            guard let expected = Self.packages[url.lastPathComponent.uppercased()] else { return nil }
            let info = try url.resourceValues(forKeys: keys)
            guard info.isRegularFile == true, info.isSymbolicLink == false, let size = info.fileSize, size > 0 else {
                throw Failure("A selected DLC package is incomplete.")
            }
            return (url, size, expected)
        }.sorted { $0.0.lastPathComponent < $1.0.lastPathComponent }
        guard !candidates.isEmpty else {
            throw Failure("No supported DLC packages found. Choose the 55530833 or 00000002 folder.")
        }
        let total = candidates.reduce(0) { $0 + $1.1 }
        let stage = profile.appendingPathComponent(".dlc-import-" + UUID().uuidString)
        let inputs = stage.appendingPathComponent("Packages")
        let stageProfile = stage.appendingPathComponent("Profile")
        let path = "0000000000000000/55530833"
        let stagedTitle = stageProfile.appendingPathComponent(path)
        let liveTitle = profile.appendingPathComponent(path)
        try fm.createDirectory(at: inputs, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: stage) }
        try fm.createDirectory(at: stagedTitle.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fm.fileExists(atPath: liveTitle.path) {
            try Updates.run("/bin/cp", ["-cR", liveTitle.path, stagedTitle.path])
        }

        var verifiedBytes = 0
        var imports: [URL] = []
        for (url, _, expected) in candidates {
            let name = url.lastPathComponent.uppercased()
            let copy = inputs.appendingPathComponent(name)
            try Updates.run("/bin/cp", ["-c", url.path, copy.path])
            let handle = try FileHandle(forReadingFrom: copy)
            defer { try? handle.close() }
            var hash = SHA256()
            while let chunk = try handle.read(upToCount: 8 * 1024 * 1024), !chunk.isEmpty {
                hash.update(data: chunk)
                verifiedBytes += chunk.count
                progress(min(40, 40 * Double(verifiedBytes) / Double(total)), "Verifying DLC packages…")
            }
            guard hash.finalize().map({ String(format: "%02x", $0) }).joined() == expected else {
                throw Failure("A DLC package failed verification. Choose a clean copy of the package.")
            }
            let oldFiles = stagedTitle.appendingPathComponent("00000002/" + name)
            let oldHeader = stagedTitle.appendingPathComponent("Headers/00000002/" + name + ".header")
            for old in [oldFiles, oldHeader] where fm.fileExists(atPath: old.path) { try fm.removeItem(at: old) }
            imports.append(copy)
        }

        progress(41, "Installing DLC packages…")
        let process = Process()
        let pipe = Pipe()
        process.executableURL = helper
        process.arguments = [game.path, stageProfile.path] + imports.map(\.path)
        process.standardOutput = pipe
        process.standardError = FileHandle.standardError
        try process.run()
        var buffer = Data()
        while let chunk = try pipe.fileHandleForReading.read(upToCount: 16_384), !chunk.isEmpty {
            buffer.append(chunk)
            while let end = buffer.firstIndex(of: 10) {
                let line = String(decoding: buffer[..<end], as: UTF8.self)
                if line.hasPrefix("DLC_PROGRESS "), let count = Int(line.dropFirst("DLC_PROGRESS ".count)),
                   (1...imports.count).contains(count) {
                    progress(41 + 52 * Double(count) / Double(imports.count), "Installed \(count) of \(imports.count) DLC packages…")
                }
                buffer.removeSubrange(...end)
            }
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw Failure("DLC installation failed (code \(process.terminationStatus)).")
        }
        progress(96, "Saving installed DLC…")
        try fm.createDirectory(at: liveTitle.deletingLastPathComponent(), withIntermediateDirectories: true)
        try publishDirectory(stagedTitle, at: liveTitle)
        progress(100, "DLC installation complete.")
        return imports.count
    }
}
