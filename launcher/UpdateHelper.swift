import AppKit
import Darwin
let fm = FileManager.default
func apply(source: URL,target: URL, parent: Int32, backups: URL, reopen: Bool) throws {
    let deadline = Date().addingTimeInterval(60)
    while kill(parent,0) == 0 {
        guard Date() < deadline else { throw NSError(domain:"Updater: launcher did not exit",code:1) }
        Thread.sleep(forTimeInterval:0.1)
    }
    let folder = target.deletingLastPathComponent()
    let staged = folder.appendingPathComponent(".GRFS-update-"+UUID().uuidString+".app")
    try fm.createDirectory(at:backups,withIntermediateDirectories:true)
    let backup = backups.appendingPathComponent("Previous.app.backup")
    let incoming = backups.appendingPathComponent("incoming-"+UUID().uuidString+".backup")
    try fm.copyItem(at:source,to:staged)
    do { try fm.moveItem(at:target,to:incoming) }
    catch { try? fm.removeItem(at:staged); throw error }
    do { try fm.moveItem(at:staged,to:target) }
    catch { try? fm.moveItem(at:incoming,to:target); try? fm.removeItem(at:staged); throw error }
    // Retain one previous version outside Applications; never touch game data.
    do {
        if fm.fileExists(atPath:backup.path) { try fm.removeItem(at:backup) }
        try fm.moveItem(at:incoming,to:backup)
    } catch { fputs("Backup retained at \(incoming.path): \(error)\n",stderr) }
    print("Updated; previous app: \(backup.path)")
    fflush(stdout)
    if reopen {
        let config = NSWorkspace.OpenConfiguration(); config.activates = true
        NSWorkspace.shared.openApplication(at:target,configuration:config) { app,error in
            if let error = error { fputs("Reopen failed: \(error)\n",stderr); exit(1) }
            exit(0)
        }
        RunLoop.main.run()
    }
}
do {
    let args = CommandLine.arguments
    guard args.count == 5 || (args.count == 6 && args[5] == "--test-no-reopen"),let pid = Int32(args[3]),pid > 0 else { exit(2) }
    try apply(source:URL(fileURLWithPath:args[1]),target:URL(fileURLWithPath:args[2]),parent:pid,backups:URL(fileURLWithPath:args[4]),reopen:args.count == 5)
} catch { fputs("Update failed: \(error)\n",stderr); exit(1) }
