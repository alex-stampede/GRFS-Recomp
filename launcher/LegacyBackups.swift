import AppKit

// Upgrade from early launchers that left backup .app bundles in Applications.
// Keep one rollback copy in app data; send redundant old copies to recoverable Trash.
func migrateLegacyBackups(home: URL, applicationFolders: [URL]? = nil) throws {
    let manager = FileManager.default
    let folders = applicationFolders ?? [URL(fileURLWithPath:"/Applications"),manager.homeDirectoryForCurrentUser.appendingPathComponent("Applications")]
    var copies: [URL] = []
    for folder in folders {
        let entries = (try? manager.contentsOfDirectory(at:folder,includingPropertiesForKeys:[.contentModificationDateKey])) ?? []
        copies += entries.filter { url in
            let name = url.lastPathComponent
            let legacy = name.hasPrefix("GRFS Previous-") || name.hasPrefix("GRFS Recomp Previous-") || name.hasPrefix("Ghost Recon Future Soldier Recomp.backup-")
            return legacy && url.pathExtension == "app" && url != Bundle.main.bundleURL && Bundle(url:url)?.bundleIdentifier == "local.grfs.launcher"
        }
    }
    if copies.isEmpty { return }
    func build(_ app: URL) -> String {
        guard let data=try? Data(contentsOf:app.appendingPathComponent("Contents/Info.plist")),let plist=try? PropertyListSerialization.propertyList(from:data,format:nil) as? [String:Any] else { return "0" }
        return plist["CFBundleVersion"] as? String ?? "0"
    }
    copies.sort { a,b in
        let order=build(a).compare(build(b),options:.numeric)
        if order != .orderedSame { return order == .orderedDescending }
        let left = (try? a.resourceValues(forKeys:[.contentModificationDateKey]).contentModificationDate) ?? .distantPast
        let right = (try? b.resourceValues(forKeys:[.contentModificationDateKey]).contentModificationDate) ?? .distantPast
        return left > right
    }
    let backups = home.appendingPathComponent("Backups")
    try manager.createDirectory(at:backups,withIntermediateDirectories:true)
    let previous = backups.appendingPathComponent("Previous.app.backup")
    for copy in copies {
        if !manager.fileExists(atPath:previous.path) { try manager.moveItem(at:copy,to:previous) }
        else if build(copy).compare(build(previous),options:.numeric) == .orderedDescending {
            try manager.trashItem(at:previous,resultingItemURL:nil)
            try manager.moveItem(at:copy,to:previous)
        } else { try manager.trashItem(at:copy,resultingItemURL:nil) }
    }
}
