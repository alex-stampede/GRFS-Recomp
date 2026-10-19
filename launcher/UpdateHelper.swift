import AppKit
import Darwin
let fm = FileManager.default
func apply(source: URL,target: URL, parent: Int32, reopen: Bool) throws {
    let deadline = Date().addingTimeInterval(60)
    while kill(parent,0) == 0 {
        guard Date() < deadline else { throw NSError(domain:"Updater: launcher did not exit",code:1) }
        Thread.sleep(forTimeInterval:0.1)
    }
    let folder = target.deletingLastPathComponent()
    let staged = folder.appendingPathComponent(".GRFS-update-"+UUID().uuidString+".app")
    let backup = folder.appendingPathComponent("GRFS Previous-"+UUID().uuidString+".app")
    try fm.copyItem(at:source,to:staged)
    do { try fm.moveItem(at:target,to:backup) }
    catch { try? fm.removeItem(at:staged); throw error }
    do { try fm.moveItem(at:staged,to:target) }
    catch { try? fm.moveItem(at:backup,to:target); try? fm.removeItem(at:staged); throw error }
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
    guard args.count == 4 || (args.count == 5 && args[4] == "--test-no-reopen"),let pid = Int32(args[3]),pid > 0 else { exit(2) }
    try apply(source:URL(fileURLWithPath:args[1]),target:URL(fileURLWithPath:args[2]),parent:pid,reopen:args.count == 4)
} catch { fputs("Update failed: \(error)\n",stderr); exit(1) }
