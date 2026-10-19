import AppKit

if CommandLine.arguments.count == 3 && CommandLine.arguments[1] == "--inspect-iso" {
    do { let iso = try ISO(URL(fileURLWithPath:CommandLine.arguments[2])); print("files=\(iso.files.count)"); for e in iso.files { print(e.path) } }
    catch { fputs(error.localizedDescription+"\n",stderr); exit(1) }
} else if CommandLine.arguments.count == 4 && CommandLine.arguments[1] == "--extract-iso" {
    do { let iso = try ISO(URL(fileURLWithPath:CommandLine.arguments[2])); let target = URL(fileURLWithPath:CommandLine.arguments[3]); guard !fm.fileExists(atPath:target.path) else { throw Failure("The destination already exists.") }; try iso.extract(to:target) { _,_ in }; print("extracted=\(iso.files.count)") }
    catch { fputs(error.localizedDescription+"\n",stderr); exit(1) }
} else {
    let app = NSApplication.shared
    app.setActivationPolicy(.regular)
    let delegate = Launcher(); app.delegate = delegate
    let menu = NSMenu(); let item = NSMenuItem(); let sub = NSMenu(); sub.addItem(withTitle:"Quit GRFS",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q"); item.submenu = sub; menu.addItem(item); app.mainMenu = menu
    app.run()
}
