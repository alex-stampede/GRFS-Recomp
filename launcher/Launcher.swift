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
    var profile: URL { home.appendingPathComponent("UserData") }
    var titleUpdate: TitleUpdate { TitleUpdate(assets: Bundle.main.resourceURL!.appendingPathComponent("TU3")) }
    var updatedGame: URL?
    var expected: [String: Expected] = [:]
    var required: [String: UInt64] = [:]
    var window: NSWindow!
    let status = NSTextField(wrappingLabelWithString: "Choose your ISO to install the game on this Mac.")
    let percent = NSTextField(labelWithString: "0%")
    let bar = GRFSProgressIndicator()
    let button = GRFSActionButton(title: "Choose ISO…", target: nil, action: nil)
    let dlcButton = GRFSActionButton(title: "Install DLC…", target: nil, action: nil)
    var busy = false
    var child: Process?
    var experimentalGraphics: ExperimentalGraphicsWindow?
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
        if Bundle.main.object(forInfoDictionaryKey:"GRFSExperimentalGraphics") as? Bool == true {
            experimentalGraphics = ExperimentalGraphicsWindow(launcher:self)
            experimentalGraphics?.show(); return
        }
        if CommandLine.arguments.contains("--preview-launcher") || Bundle.main.object(forInfoDictionaryKey:"GRFSPreview") as? Bool == true { return }
        checkUpdates { self.continueStartup() }
    }
    func continueStartup() {
        status.stringValue = "Choose your ISO to install the game on this Mac."
        if fm.fileExists(atPath: state.path) {
            busy = true; button.isEnabled = false
            status.stringValue = "Verifying installation…"
            DispatchQueue.global().async {
                do {
                    try self.validateInstalled()
                    let ready = try self.titleUpdate.prepare(base: self.game, under: self.home)
                    DispatchQueue.main.async { self.showReady(ready) }
                }
                catch { DispatchQueue.main.async { self.busy = false; self.button.isEnabled = true; self.status.stringValue = "The installation needs repair. Your saves are preserved."; self.button.title = "Reinstall from ISO…"; self.alert(error) } }
            }
        }
    }
    func showReady(_ directory: URL) {
        updatedGame = directory
        busy = false
        button.title = "Play Game"
        button.isEnabled = true
        dlcButton.isEnabled = true
        update(100, "Ready to play · Title Update 3")
    }

    @objc func selectDLC() {
        guard let updatedGame, !busy, child == nil else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.title = "Install DLC"
        panel.prompt = "Choose Folder"
        panel.message = "Select your 55530833 folder or its 00000002 subfolder."
        guard panel.runModal() == .OK, let folder = panel.url,
              let resources = Bundle.main.resourceURL else { return }

        busy = true
        button.isEnabled = false
        dlcButton.isEnabled = false
        update(0, "Preparing DLC installation…")
        let installer = DLCInstallation(
            helper: resources.appendingPathComponent("Game.app/Contents/MacOS/InstallDLC"),
            game: updatedGame,
            profile: profile)
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let count = try installer.install(from: folder, progress: self.update)
                DispatchQueue.main.async {
                    self.showReady(updatedGame)
                    self.update(100, count == 1 ? "1 DLC package installed." : "\(count) DLC packages installed.")
                }
            } catch {
                DispatchQueue.main.async {
                    self.showReady(updatedGame)
                    self.update(0, "DLC installation did not complete.")
                    self.alert(error)
                }
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
        guard !busy, child == nil else { return }
        if updatedGame != nil { startGame(); return }
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
                self.update(98,"Preparing Title Update 3…")
                if fm.fileExists(atPath:self.game.path) {
                    let backup = self.home.appendingPathComponent("Game-backup-"+UUID().uuidString)
                    try fm.moveItem(at:self.game,to:backup)
                    do { try fm.moveItem(at:stage,to:self.game) }
                    catch { try? fm.moveItem(at:backup,to:self.game); throw error }
                } else { try fm.moveItem(at:stage,to:self.game) }
                let info: [String:Any] = ["schema":1,"installedAt":ISO8601DateFormatter().string(from:Date()),"version":"GRFS-55530833-2DF41A75","files":iso.files.count]
                try JSONSerialization.data(withJSONObject:info,options:.prettyPrinted).write(to:self.state,options:.atomic)
                let ready = try self.titleUpdate.prepare(base: self.game, under: self.home)
                DispatchQueue.main.async { self.showReady(ready) }
            } catch {
                try? fm.removeItem(at:stage)
                DispatchQueue.main.async { self.busy = false; self.button.isEnabled = true; self.status.stringValue = "Installation was not completed."; self.alert(error) }
            }
        }
    }
    let shaderPreparation = ShaderPreparation()
    var extractingShaderCatalog=false
    func startGame() {
        guard child == nil else { return }
        startPreparedGame(extractedCatalog:nil)
    }
    func startPreparedGame(extractedCatalog:URL?) {
        guard child == nil, !busy, let updatedGame else { return }
        do {
            let runtime = Bundle.main.resourceURL!.appendingPathComponent("Game.app/Contents/MacOS")
            let user = profile, cache = home.appendingPathComponent("CacheTU3"), logs = home.appendingPathComponent("Logs")
            let safetyMode=Bundle.main.object(forInfoDictionaryKey:"GRFSSafetyMode")as? String ?? ""
            let freshOnly=safetyMode=="fresh-on-demand"
            let captureOnly=safetyMode=="on-demand" || freshOnly
            let activeCache=captureOnly ? home.appendingPathComponent(freshOnly ? "Diagnostics/CacheFreshGuestV1-"+UUID().uuidString : "Diagnostics/CacheCatalogSafetyV1-record"):cache
            if captureOnly {
                let destination=activeCache.appendingPathComponent("shaders/shareable")
                try fm.createDirectory(at:destination,withIntermediateDirectories:true)
                let seed=destination.appendingPathComponent("seeded")
                if !freshOnly && !fm.fileExists(atPath:seed.path){
                    for source in [cache.appendingPathComponent("shaders/shareable"),home.appendingPathComponent("CacheCombinedFlowV1/shaders/shareable"),home.appendingPathComponent("CachePersistent/shaders/shareable")] {
                        let xsh=source.appendingPathComponent("55530833.xsh")
                        if fm.fileExists(atPath:xsh.path){
                            for name in ["55530833.xsh","55530833.fbo.vk.xpso"] {
                                let file=source.appendingPathComponent(name),target=destination.appendingPathComponent(name)
                                if fm.fileExists(atPath:file.path),!fm.fileExists(atPath:target.path){try fm.copyItem(at:file,to:target)}
                            };break
                        }
                    }
                    try Data().write(to:seed,options:.atomic)
                }
            }
            let preparationLogs=logs.appendingPathComponent("Preparation-"+UUID().uuidString)
            for path in [user,cache,logs,preparationLogs] { try fm.createDirectory(at:path,withIntermediateDirectories:true) }
            // Prepare known portable records using the tested catalog path.
            let p = Process(); p.executableURL = runtime.appendingPathComponent("grfs"); p.currentDirectoryURL = runtime
            // Match the M3-tested path: on-demand pipelines, bounded draw extents.
            // Keep synchronous gameplay compilation and persistent shader storage.
            p.arguments = ["--game_data_root="+updatedGame.path,"--update_data_root="+titleUpdate.assets.path,"--user_data_root="+user.path,"--cache_root="+activeCache.path,"--log_file="+preparationLogs.appendingPathComponent("game.log").path,"--gpu_plugin=metal","--grfs_output_resolution=native","--grfs_present_limit=0","--mnk_mode",fullscreenArgument(config: user.appendingPathComponent("grfs.toml")),"--readback_resolve=fast","--readback_memexport=true","--allow_game_relative_writes=false","--gpu_allow_invalid_fetch_constants=true","--async_shader_compilation=false","--execute_unclipped_draw_vs_on_cpu=true","--log_level=info"]
            let restart = RestartRequest(directory: logs)
            var env = ProcessInfo.processInfo.environment
            env.merge(restart.environment) { _, new in new }
            env["GRFS_SAFE_PREWARM"]="0"
            let candidates=["CacheCombinedFlowV1","CacheTextureExponentV1","CachePersistent","CachePersistentTest","Cache","Diagnostics/CachePrewarmV1","Diagnostics/CacheVisionPassMapV1"]
            var catalogFolders=Set(candidates.map{home.appendingPathComponent($0+"/shaders/shareable").path})
            if let extracted=extractedCatalog{catalogFolders.insert(extracted.path)}
            // Previous diagnostic sessions also contain portable records. The SDK validates
            // title, record hashes and versions; no native pipeline binaries are imported.
            if let entries=fm.enumerator(at:home.appendingPathComponent("Performance"),includingPropertiesForKeys:nil,options:[.skipsHiddenFiles]) {
                for case let file as URL in entries where file.lastPathComponent=="55530833.fbo.vk.xpso" {
                    catalogFolders.insert(file.deletingLastPathComponent().path)
                }
            }
            env["GRFS_CATALOG_SOURCES"]=catalogFolders.sorted().joined(separator:"\n")
            try catalogFolders.sorted().joined(separator:"\n").write(to:preparationLogs.appendingPathComponent("catalog-sources.txt"),atomically:true,encoding:.utf8)
            env["GRFS_PREWARM_AUDIT"]=preparationLogs.appendingPathComponent("pipeline-audit.jsonl").path
            let ipcDir=home.appendingPathComponent("Diagnostics/PreparationIPC")
            try fm.createDirectory(at:ipcDir,withIntermediateDirectories:true)
            let ipc=ipcDir.appendingPathComponent(UUID().uuidString+".json");shaderPreparation.preparationIPC=ipc
            env["GRFS_PREWARM_PROGRESS"]=ipc.path
            try ipc.path.write(to:preparationLogs.appendingPathComponent("preparation-ipc-path.txt"),atomically:true,encoding:.utf8)
            // macOS Game Mode requires native fullscreen Spaces, not a borderless window.
            env["SDL_VIDEO_MAC_FULLSCREEN_SPACES"] = "1"
            env["REX_GRFS_VERIFY_PROBE"] = "1"; env["REX_GRFS_ENUM_EMPTY_ERROR"] = "1"; env["REX_GRFS_SAMPLER_PROBE"] = "mip0"
            // Optimize translated modules; avoid the problematic stored-pipeline preload.
            if env["GRFS_SPIRV_OPTIMIZE"] == nil { env["GRFS_SPIRV_OPTIMIZE"] = "0" }
            env["GRFS_SKIP_PIPELINE_PRELOAD"] = "1"
            env["GRFS_FORWARD_FLOW"] = "1"
            env["GRFS_CLEAR_PAIR"] = "1"
            // Production package omits diagnostic file writes and GPU stage probes.
            env.removeValue(forKey: "GRFS_CLEAR_STATS")
            // Presence enables eager acquisition, even for a value of "0".
            env.removeValue(forKey: "GRFS_EAGER_DRAWABLE")
            env["MVK_CONFIG_SYNCHRONOUS_QUEUE_SUBMITS"] = "1"
            env["GRFS_WINDOW_TITLE"] = (Bundle.main.object(forInfoDictionaryKey:"GRFSExtractionTrial")as? Bool == true) ? "Ghost Recon Future Soldier — ISO Shader Extraction Test" : "Ghost Recon Future Soldier Recomp v0.10.0.12"
            // Enable the Metal HUD facility; the F5 callback controls each layer
            // live. These are presentation statistics, not unique game frames.
            env["MTL_HUD_ENABLED"] = "1"
            env["MTL_HUD_ALIGNMENT"] = "topright"
            env["MTL_HUD_SHOW_ZERO_METRICS"] = "0"
            env["DYLD_INSERT_LIBRARIES"] = runtime.appendingPathComponent("libGRFSWindowTitle.dylib").path
            if Bundle.main.object(forInfoDictionaryKey:"GRFSFullscreenTrace") as? Bool == true { env["GRFS_FULLSCREEN_TRACE"] = "1" }
            if captureOnly {
                env["GRFS_SAFE_PREWARM"]="0";env["GRFS_RECORD_CATALOG"]="1"
                env["REX_GRFS_DIAGNOSTICS"]="1"
                env["GRFS_WINDOW_TITLE"]=freshOnly ? "Ghost Recon Future Soldier — Fresh Guest Shaders" : "Ghost Recon Future Soldier — Catalog Safety / On-demand"
                try "mode=\(safetyMode)\nseeded_cache=\(!freshOnly)\nstartup_preload=off\ncollect_pipeline_descriptions=on\nprivate_native_cache_reuse=off\ncache=\(activeCache.path)\n".write(to:preparationLogs.appendingPathComponent("test.txt"),atomically:true,encoding:.utf8)
            }
            env["GRFS_METAL_UNIFORM_PAGES"]="64"
            env["MTL_DEBUG_LAYER"]="0"
            env["GRFS_WINDOW_TITLE"]="Ghost Recon Future Soldier Recomp 2.1 — Native Metal"
            env.removeValue(forKey:"GRFS_METAL_PROFILE")
            env.removeValue(forKey: "GRFS_METAL_BLACK_PROBE")
            env["GRFS_WINDOW_TITLE"]="Ghost Recon Future Soldier Recomp — Title Update 3"
            for key in ["GRFS_METAL_FSI_PROBE", "GRFS_METAL_FSI_REPLAY", "GRFS_METAL_FSI_LIVE",
                        "GRFS_METAL_NATIVE_BIAS_PROBE"] {
                env.removeValue(forKey: key)
            }
            env["GRFS_METAL_NATIVE_ABSOLUTE_BIAS"] = "1"
            env["GRFS_METAL_QUEUE_SHADER_DONE"] = "1"
            env.removeValue(forKey: "GRFS_METAL_SHD_WAIT_REQUEST")
            env.removeValue(forKey:"GRFS_METAL_CPU_VISIBILITY_TEST")
            env.removeValue(forKey:"GRFS_METAL_PROFILE")
            env.removeValue(forKey:"GRFS_METAL_BLACK_PROBE")
            env.removeValue(forKey:"GRFS_METAL_SCANOUT_MEMORY_PROBE")
            env.removeValue(forKey:"GRFS_METAL_EDRAM_DUMP_BARRIER")
            for key in ["REX_GRFS_SAMPLER_PROBE", "REX_GRFS_COLOR_MIP0",
                        "GRFS_METAL_BASE_MIP_TEST", "GRFS_METAL_ORDERED_TEXTURE_UPLOADS"] {
                env.removeValue(forKey: key)
            }
            let modeDirectory = preparationLogs.appendingPathComponent("Metal")
            try fm.createDirectory(at:modeDirectory,withIntermediateDirectories:true)
            try "1\n".write(to:modeDirectory.appendingPathComponent("order.request"),
                            atomically:true,encoding:.utf8)
            env["GRFS_METAL_FORENSICS"]=modeDirectory.path
            env["GRFS_METAL_COMPACT"]="1"
            env["MTL_CAPTURE_ENABLED"]="0"
            p.environment = env
            let output = logs.appendingPathComponent("console.log"); fm.createFile(atPath:output.path,contents:nil)
            let file = try FileHandle(forWritingTo:output); p.standardOutput = file; p.standardError = file
            p.terminationHandler = { process in
                try? file.close()
                if captureOnly {
                    try? fm.copyItem(at:output,to:preparationLogs.appendingPathComponent("console.log"))
                    let archive=fm.homeDirectoryForCurrentUser.appendingPathComponent("Desktop/GRFS-Catalog-Safety-"+preparationLogs.lastPathComponent+".zip")
                    let zip=Process();zip.executableURL=URL(fileURLWithPath:"/usr/bin/ditto");zip.arguments=["-c","-k","--keepParent",preparationLogs.path,archive.path]
                    do{try zip.run();zip.waitUntilExit()}catch{}
                }
                let shouldRestart = restart.consume(exitStatus: process.terminationStatus)
                DispatchQueue.main.async {
                    self.shaderPreparation.stop()
                    self.child = nil
                    if shouldRestart { self.startGame(); return }
                    self.status.stringValue = process.terminationStatus == 0 ? "Game closed. Saves and shader storage preserved." : "The game exited with code \(process.terminationStatus). Check the Logs folder."
                    self.button.isEnabled = true
                    self.dlcButton.isEnabled = true
                    if process.terminationStatus == 0 { NSApp.terminate(nil) }
                    else { NSApp.setActivationPolicy(.regular); self.window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps:true) }
                }
            }
            status.stringValue = "Starting game and loading known shaders…"
            try p.run(); child = p; button.isEnabled = false; dlcButton.isEnabled = false
            window.orderOut(nil); NSApp.setActivationPolicy(.accessory)
            shaderPreparation.process=p
        } catch { shaderPreparation.stop();alert(error) }
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if child != nil {
            // AppKit may request termination when the launcher hides at game startup.
            // Keep the supervisor alive without interrupting the game with a modal.
            return .terminateCancel
        }
        if busy || extractingShaderCatalog {
            let a = NSAlert(); a.messageText = "Installation or shader preparation is in progress."; a.runModal(); return .terminateCancel
        }
        return .terminateNow
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { !busy && child == nil }
}

