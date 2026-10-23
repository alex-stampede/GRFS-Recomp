import AppKit
import CryptoKit
import UniformTypeIdentifiers

struct Failure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
    init(_ message: String) { self.message = message }
}
struct Entry { let path: String; let offset: UInt64; let size: UInt64 }
struct Expected: Codable { let sha256: String; let size: UInt64 }
let fm = FileManager.default
func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }

// Read-only XDVDFS reader. Partition and all directory/file extents are bounded.
final class ISO {
    let handle: FileHandle
    let size: UInt64
    var partition: UInt64 = 0
    var files: [Entry] = []
    var directoryIDs = Set<UInt64>()
    var names = Set<String>()
    init(_ url: URL) throws {
        handle = try FileHandle(forReadingFrom: url)
        size = try handle.seekToEnd()
        var descriptor: Data?
        for offset: UInt64 in [0xFD90000, 0x18300000, 0x2080000, 0] {
            guard offset + 32 * 2048 + 2048 <= size else { continue }
            let d = try read(offset + 32 * 2048, 2048)
            if String(data: d.prefix(20), encoding: .ascii) == "MICROSOFT*XBOX*MEDIA" {
                partition = offset; descriptor = d; break
            }
        }
        guard let d = descriptor else { throw Failure("No compatible Xbox partition was found in this ISO.") }
        try directory(sector: u32(d, 20), length: u32(d, 24), prefix: "", depth: 0)
        guard !files.isEmpty else { throw Failure("The ISO contains no files.") }
    }
    deinit { try? handle.close() }
    func read(_ offset: UInt64, _ count: Int) throws -> Data {
        guard count >= 0, offset <= size, UInt64(count) <= size - offset else { throw Failure("A file extends beyond the bounds of the ISO.") }
        try handle.seek(toOffset: offset)
        guard let d = try handle.read(upToCount: count), d.count == count else { throw Failure("The ISO could not be read completely.") }
        return d
    }
    func u16(_ d: Data, _ p: Int) -> UInt32 { UInt32(d[p]) | UInt32(d[p+1]) << 8 }
    func u32(_ d: Data, _ p: Int) -> UInt32 { u16(d,p) | u16(d,p+2) << 16 }
    func directory(sector: UInt32, length: UInt32, prefix: String, depth: Int) throws {
        if length == 0 { return }
        let offset = partition + UInt64(sector) * 2048
        guard depth <= 32, length <= 64 * 1024 * 1024, directoryIDs.insert(offset).inserted else { throw Failure("Invalid or circular directory in the ISO.") }
        let d = try read(offset, Int(length))
        var stack = [0], visited = Set<Int>()
        while let p = stack.popLast() {
            guard p >= 0, p + 14 <= d.count, visited.insert(p).inserted else { throw Failure("Invalid ISO directory table.") }
            let left = u16(d,p), right = u16(d,p+2)
            if left == 0xFFFF { continue }
            let count = Int(d[p+13])
            guard count > 0, p + 14 + count <= d.count,
                  let name = String(data: d[(p+14)..<(p+14+count)], encoding: .utf8),
                  name != ".", name != "..", !name.contains("/"), !name.contains("\\"), !name.contains(":"), !name.contains("\0") else { throw Failure("Invalid file name in the ISO.") }
            let path = prefix + name
            guard names.insert(path.lowercased()).inserted, names.count <= 200000 else { throw Failure("Duplicate files or too many entries in the ISO.") }
            let start = u32(d,p+4), size = u32(d,p+8)
            if d[p+12] & 0x10 != 0 {
                try directory(sector: start, length: size, prefix: path + "/", depth: depth+1)
            } else {
                let location = partition + UInt64(start) * 2048
                guard location <= self.size, UInt64(size) <= self.size - location else { throw Failure("Truncated file in the ISO: \(path)") }
                files.append(Entry(path: path, offset: location, size: UInt64(size)))
            }
            if right != 0 { stack.append(Int(right)*4) }
            if left != 0 { stack.append(Int(left)*4) }
        }
    }
    func validate(_ expected: [String: Expected]) throws {
        for (name, value) in expected {
            guard let e = files.first(where: { $0.path.lowercased() == name }), e.size == value.size,
                  digest(try read(e.offset, Int(e.size))) == value.sha256 else {
                throw Failure("This edition does not match the compatible build (\(name)). Use the supported edition of GRFS.")
            }
        }
    }
    func extract(to destination: URL, progress: (Double, String) -> Void) throws {
        let total = files.reduce(UInt64(0)) { $0 + $1.size }
        var done: UInt64 = 0
        try fm.createDirectory(at: destination, withIntermediateDirectories: true)
        for e in files {
            let output = destination.appendingPathComponent(e.path)
            try fm.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
            guard fm.createFile(atPath: output.path, contents: nil) else { throw Failure("Could not create \(e.path).") }
            let writer = try FileHandle(forWritingTo: output)
            do {
                var copied: UInt64 = 0
                while copied < e.size {
                    let n = Int(min(UInt64(1024*1024), e.size-copied))
                    try writer.write(contentsOf: read(e.offset+copied, n))
                    copied += UInt64(n); done += UInt64(n)
                    progress(Double(done)/Double(max(total,1)), e.path)
                }
                try writer.close()
            } catch { try? writer.close(); throw error }
        }
    }
}

final class Launcher: NSObject, NSApplicationDelegate {
    let home = fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/GRFS Recompiled")
    var game: URL { home.appendingPathComponent("Game") }
    var state: URL { home.appendingPathComponent("installation.json") }
    var expected: [String: Expected] = [:]
    var required: [String: UInt64] = [:]
    var window: NSWindow!
    let status = NSTextField(wrappingLabelWithString: "Choose your ISO to install the game on this Mac.")
    let percent = NSTextField(labelWithString: "0%")
    let bar = GRFSProgressIndicator()
    let button = GRFSActionButton(title: "Choose ISO…", target: nil, action: nil)
    var busy = false
    var child: Process?
    var launched = false
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let url = Bundle.main.url(forResource: "DockIcon", withExtension: "png"),
           let icon = NSImage(contentsOf: url) { NSApp.applicationIconImage = icon }
        do {
            guard let manifest = Bundle.main.url(forResource: "compatible-game", withExtension: "json") else { throw Failure("The compatibility manifest is missing.") }
            expected = try JSONDecoder().decode([String:Expected].self, from: Data(contentsOf: manifest))
            required = try JSONDecoder().decode([String:UInt64].self, from: Data(contentsOf: Bundle.main.url(forResource:"required-files",withExtension:"json")!))
            try fm.createDirectory(at: home, withIntermediateDirectories: true)
        } catch { alert(error); return }
        do { try migrateLegacyBackups(home:home) }
        catch { NSLog("Legacy backup cleanup deferred: %@",error.localizedDescription) }
        buildWindow()
        if CommandLine.arguments.contains("--preview-launcher") || Bundle.main.object(forInfoDictionaryKey:"GRFSPreview") as? Bool == true { return }
        checkUpdates { self.continueStartup() }
    }
    func continueStartup() {
        status.stringValue = "Choose your ISO to install the game on this Mac."
        if fm.fileExists(atPath: state.path) {
            busy = true; button.isEnabled = false
            status.stringValue = "Verifying installation…"
            DispatchQueue.global().async {
                do { try self.validateInstalled(); DispatchQueue.main.async { self.busy = false; self.button.isEnabled = true; self.startGame() } }
                catch { DispatchQueue.main.async { self.busy = false; self.button.isEnabled = true; self.status.stringValue = "The installation needs repair. Your saves are preserved."; self.button.title = "Reinstall from ISO…"; self.alert(error) } }
            }
        }
    }
    func alert(_ error: Error) {
        let a = NSAlert(); a.messageText = "GRFS Recompiled"; a.informativeText = error.localizedDescription; a.runModal()
    }
    func update(_ value: Double, _ text: String) {
        DispatchQueue.main.async { self.bar.doubleValue = value; self.bar.needsDisplay = true; self.percent.stringValue = "\(Int(value))%"; self.status.stringValue = text }
    }
    func validateInstalled(at directory: URL? = nil) throws {
        let location = directory ?? game
        let children = try fm.contentsOfDirectory(at: location, includingPropertiesForKeys:nil)
        guard let enumeration = fm.enumerator(at:location,includingPropertiesForKeys:[.fileSizeKey,.isRegularFileKey]) else { throw Failure("Could not read the installation.") }
        var inventory: [String:UInt64] = [:]
        for case let file as URL in enumeration {
            let values = try file.resourceValues(forKeys:[.fileSizeKey,.isRegularFileKey])
            if values.isRegularFile == true { inventory[String(file.path.dropFirst(location.path.count+1)).lowercased()] = UInt64(values.fileSize ?? 0) }
        }
        for (path,size) in required { guard inventory[path] == size else { throw Failure("Missing or incomplete file: \(path)") } }
        for (name,value) in expected {
            guard let file = children.first(where: { $0.lastPathComponent.lowercased() == name }),
                  let size = try file.resourceValues(forKeys:[.fileSizeKey]).fileSize, UInt64(size) == value.size,
                  digest(try Data(contentsOf:file)) == value.sha256 else { throw Failure("A compatible executable is missing: \(name).") }
        }
    }
    @objc func selectISO() {
        if child != nil { return }
        if launched { startGame(); return }
        guard !busy else { return }
        let panel = NSOpenPanel(); panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
        panel.title = "Install Ghost Recon Future Soldier"; panel.prompt = "Choose ISO"; panel.message = "Select your compatible Xbox 360 disc image. Files are installed locally."
        panel.allowedContentTypes = [UTType(filenameExtension:"iso") ?? .data]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        busy = true; button.isEnabled = false
        DispatchQueue.global(qos:.userInitiated).async {
            let stage = self.home.appendingPathComponent("install-" + UUID().uuidString)
            do {
                self.update(1,"Reading ISO structure…")
                let iso = try ISO(url)
                self.update(4,"Checking game version and executables…")
                try iso.validate(self.expected)
                let inventory = Dictionary(uniqueKeysWithValues: iso.files.map { ($0.path.lowercased(), $0.size) })
                for (path, size) in self.required {
                    guard inventory[path] == size else { throw Failure("A compatible file is missing from the ISO: \(path)") }
                }
                let bytes = iso.files.reduce(UInt64(0)) { $0 + $1.size }
                let free = try self.home.resourceValues(forKeys:[.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage ?? 0
                guard free > 0, UInt64(free) > bytes + 512*1024*1024 else { throw Failure("There is not enough free space to install the game.") }
                var lastUpdate = Date.distantPast
                try iso.extract(to:stage) { fraction,path in
                    if Date().timeIntervalSince(lastUpdate) > 0.1 || fraction == 1 {
                        lastUpdate = Date(); self.update(5+fraction*90,"Extracting: \(path)")
                    }
                }
                self.update(96,"Verifying installed files…")
                try self.validateInstalled(at:stage)
                self.update(98,"Preparing installation and persistent shader storage…")
                if fm.fileExists(atPath:self.game.path) {
                    let backup = self.home.appendingPathComponent("Game-backup-"+UUID().uuidString)
                    try fm.moveItem(at:self.game,to:backup)
                    do { try fm.moveItem(at:stage,to:self.game) }
                    catch { try? fm.moveItem(at:backup,to:self.game); throw error }
                } else { try fm.moveItem(at:stage,to:self.game) }
                let info: [String:Any] = ["schema":1,"installedAt":ISO8601DateFormatter().string(from:Date()),"version":"GRFS-55530833-2DF41A75","files":iso.files.count]
                try JSONSerialization.data(withJSONObject:info,options:.prettyPrinted).write(to:self.state,options:.atomic)
                self.update(100,"Installation complete. Starting the game…")
                DispatchQueue.main.async { self.busy = false; self.button.isEnabled = true; self.startGame() }
            } catch {
                try? fm.removeItem(at:stage)
                DispatchQueue.main.async { self.busy = false; self.button.isEnabled = true; self.status.stringValue = "Installation was not completed."; self.alert(error) }
            }
        }
    }
    func startGame() {
        guard child == nil else { return }
        do {
            let runtime = Bundle.main.resourceURL!.appendingPathComponent("Game.app/Contents/MacOS")
            let user = home.appendingPathComponent("UserData"), cache = home.appendingPathComponent("CachePersistent"), logs = home.appendingPathComponent("Logs")
            for path in [user,cache,logs] { try fm.createDirectory(at:path,withIntermediateDirectories:true) }
            // Keep the fixed cache away from older releases that can truncate storage.
            let shaders = cache.appendingPathComponent("shaders")
            if !fm.fileExists(atPath:shaders.path) {
                let candidates = ["CacheGameModeTest", "Cache"].map { home.appendingPathComponent($0+"/shaders") }
                if let source = candidates.first(where: { fm.fileExists(atPath:$0.path) }) {
                    let stage = cache.appendingPathComponent(".shaders-import-"+UUID().uuidString)
                    do { try fm.copyItem(at:source,to:stage); try fm.moveItem(at:stage,to:shaders) }
                    catch { try? fm.removeItem(at:stage); throw error }
                }
            }
            let p = Process(); p.executableURL = runtime.appendingPathComponent("grfs"); p.currentDirectoryURL = runtime
            p.arguments = ["--game_data_root="+game.path,"--user_data_root="+user.path,"--cache_root="+cache.path,"--log_file="+logs.appendingPathComponent("game.log").path,"--gpu_plugin=xenos","--mnk_mode",fullscreenArgument(config: user.appendingPathComponent("grfs.toml")),"--window_width=1280","--window_height=720","--render_target_path_vulkan=fbo","--readback_resolve=fast","--gpu_allow_invalid_fetch_constants=true","--async_shader_compilation=false","--log_level=info"]
            let restart = RestartRequest(directory: logs)
            var env = ProcessInfo.processInfo.environment
            env.merge(restart.environment) { _, new in new }
            // macOS Game Mode requires native fullscreen Spaces, not a borderless window.
            env["SDL_VIDEO_MAC_FULLSCREEN_SPACES"] = "1"
            env["REX_GRFS_VERIFY_PROBE"] = "1"; env["REX_GRFS_ENUM_EMPTY_ERROR"] = "1"; env["REX_GRFS_SAMPLER_PROBE"] = "mip0"
            env["GRFS_WINDOW_TITLE"] = "Ghost Recon Future Soldier Recomp v0.10.0.0"
            // The GRFS HUD is opt-in in F5 and counts guest swap requests.
            // Do not inherit Apple's presentation/UI FPS HUD as game FPS.
            env["MTL_HUD_ENABLED"] = "0"
            env["DYLD_INSERT_LIBRARIES"] = runtime.appendingPathComponent("libGRFSWindowTitle.dylib").path
            if Bundle.main.object(forInfoDictionaryKey:"GRFSFullscreenTrace") as? Bool == true { env["GRFS_FULLSCREEN_TRACE"] = "1" }
            p.environment = env
            let output = logs.appendingPathComponent("console.log"); fm.createFile(atPath:output.path,contents:nil)
            let file = try FileHandle(forWritingTo:output); p.standardOutput = file; p.standardError = file
            p.terminationHandler = { process in
                try? file.close()
                let shouldRestart = restart.consume(exitStatus: process.terminationStatus)
                DispatchQueue.main.async {
                    self.child = nil
                    if shouldRestart { self.startGame(); return }
                    self.status.stringValue = process.terminationStatus == 0 ? "Game closed. Saves and shader storage preserved." : "The game exited with code \(process.terminationStatus). Check the Logs folder."
                    self.button.title = "Play game"; self.button.isEnabled = true
                    if process.terminationStatus == 0 { NSApp.terminate(nil) }
                    else { NSApp.setActivationPolicy(.regular); self.window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps:true) }
                }
            }
            status.stringValue = "Starting game and loading known shaders…"
            try p.run(); child = p; launched = true; button.isEnabled = false
            window.orderOut(nil); NSApp.setActivationPolicy(.accessory)
        } catch { alert(error) }
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if busy || child != nil {
            let a = NSAlert(); a.messageText = busy ? "Installation is in progress." : "Close the game before quitting the launcher."; a.runModal(); return .terminateCancel
        }
        return .terminateNow
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { !busy && child == nil }
}

