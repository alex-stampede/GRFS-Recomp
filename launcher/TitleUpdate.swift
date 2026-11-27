import Foundation

struct TitleUpdate {
    let assets: URL
    static let patches = ["Default.xexp", "AICLASS_X360_F.xexp", "UplayBrowser.xexp"]

    func prepare(base: URL, under home: URL) throws -> URL {
        for name in Self.patches + ["TU3/tu3.big"] {
            guard fm.isReadableFile(atPath: assets.appendingPathComponent(name).path) else {
                throw Failure("The bundled Title Update 3 is incomplete. Reinstall the app.")
            }
        }
        let destination = home.appendingPathComponent("Game-TU3")
        let stage = home.appendingPathComponent(".game-tu3-" + UUID().uuidString)
        defer { try? fm.removeItem(at: stage) }
        try Updates.run("/bin/cp", ["-cR", base.path, stage.path])
        for file in try fm.contentsOfDirectory(at: stage, includingPropertiesForKeys: nil)
            where Self.patches.contains(where: { $0.caseInsensitiveCompare(file.lastPathComponent) == .orderedSame }) {
            try fm.removeItem(at: file)
        }
        for name in Self.patches {
            try fm.copyItem(at: assets.appendingPathComponent(name), to: stage.appendingPathComponent(name))
        }
        try publishDirectory(stage, at: destination)
        return destination
    }
}

// Publish an existing staging directory on the same volume in one rename.
func publishDirectory(_ stage: URL, at destination: URL) throws {
    if !fm.fileExists(atPath: destination.path) {
        try fm.moveItem(at: stage, to: destination)
        return
    }
    let result = stage.path.withCString { source in
        destination.path.withCString { target in
            renameatx_np(AT_FDCWD, source, AT_FDCWD, target, UInt32(RENAME_SWAP))
        }
    }
    if result != 0 { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
}
