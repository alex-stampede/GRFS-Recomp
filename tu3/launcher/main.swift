import AppKit
import CryptoKit
import Darwin

let fm = FileManager.default
let packageName = "TU_1AL621J_0000008000000.00000000000O2"
let supportedPackage = "e736f475812e32a92823a06cc3ae2d63517222bcec3ca27347fe6bf46dccc724"
let modules = [
    "Default.xex": "605c666b3286d909996652e4291daab51129238d6db698f86cbcefb4de37a34f",
    "AICLASS_X360_F.xex": "92241e6d2b1e11f21b3f0476a56ddf3e2e2efd3c1c7a62212d4d6715c28221a3",
    "UplayBrowser.xex": "49a616000fc08c16272113e9695f63e3d0f12ad4e9904433b663d403543ab603",
]

struct SetupError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

func hash(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

func run(_ executable: URL, _ arguments: [String], output: FileHandle? = nil) throws {
    let process = Process()
    process.executableURL = executable
    process.arguments = arguments
    process.standardOutput = output ?? FileHandle.standardOutput
    process.standardError = FileHandle.standardError
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        throw SetupError("\(executable.lastPathComponent) exited with code \(process.terminationStatus).")
    }
}

struct Installation {
    let source: URL
    let target: URL
    let runtime: URL
    var game: URL { target.appendingPathComponent("Game") }
    var update: URL { target.appendingPathComponent("UpdateAssets") }
    var profile: URL { target.appendingPathComponent("UserData") }

    func validate() throws {
        guard fm.fileExists(atPath: update.appendingPathComponent("TU3/tu3.big").path),
              fm.fileExists(atPath: profile.appendingPathComponent("0000000000000000/55530833/00000002").path),
              modules.keys.allSatisfy({ name in
                  fm.fileExists(atPath: game.appendingPathComponent(name).path) &&
                  fm.fileExists(atPath: game.appendingPathComponent(name + "p").path)
              }) else { throw SetupError("The TU3 preview installation is incomplete.") }
    }

    func prepare(archive: URL, dlcFolder: URL) throws {
        let sourceGame = source.appendingPathComponent("Game")
        for (name, expected) in modules.sorted(by: { $0.key < $1.key }) {
            let file = sourceGame.appendingPathComponent(name)
            guard let data = try? Data(contentsOf: file), hash(data) == expected,
                  !fm.fileExists(atPath: file.path + "p") else {
                throw SetupError("Install the clean Xbox 360 Media ID 2DF41A75 game in GRFS Recompiled 3.1.1 first. The base file \(name) did not match.")
            }
        }
        let child = dlcFolder.appendingPathComponent("00000002")
        let packages = fm.fileExists(atPath: child.path) ? child : dlcFolder
        let paths = try fm.contentsOfDirectory(at: packages, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey], options: .skipsHiddenFiles).sorted { $0.lastPathComponent < $1.lastPathComponent }
        let inputs = try paths.filter {
            let props = try $0.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            return props.isRegularFile == true && props.isSymbolicLink != true &&
                $0.lastPathComponent.range(of: "^[0-9A-F]{42}$", options: .regularExpression) != nil
        }
        guard inputs.count == 3 else {
            throw SetupError("Choose the 55530833 folder containing the three 00000002 DLC packages.")
        }
        guard !fm.fileExists(atPath: target.path) else { throw SetupError("The preview already has an installation.") }
        let stage = target.deletingLastPathComponent().appendingPathComponent(".GRFS-TU3-" + UUID().uuidString)
        defer { try? fm.removeItem(at: stage) }
        try fm.createDirectory(at: stage, withIntermediateDirectories: true)
        let archiveSize = try archive.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard archiveSize > 0 && archiveSize <= 12_000_000 else { throw SetupError("The selected TU3 archive size is unexpected.") }
        let stfs = stage.appendingPathComponent("TU3.stfs")
        if archive.pathExtension.lowercased() == "zip" {
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            process.arguments = ["-p", archive.path, "*/" + packageName, packageName]
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            try process.run()
            var bytes = Data()
            while let chunk = try pipe.fileHandleForReading.read(upToCount: 131_072), !chunk.isEmpty {
                bytes.append(chunk)
                if bytes.count > 3_444_736 {
                    try? pipe.fileHandleForReading.close()
                    process.terminate()
                    process.waitUntilExit()
                    throw SetupError("The TU3 ZIP contains an unexpected update entry.")
                }
            }
            process.waitUntilExit()
            // unzip can return 11 when one of the two alternative member patterns is absent.
            guard process.terminationStatus == 0 || process.terminationStatus == 11 else {
                throw SetupError("Could not read the Media ID 2DF41A75 package from the ZIP.")
            }
            try bytes.write(to: stfs)
        } else {
            try fm.copyItem(at: archive, to: stfs)
        }
        guard hash(try Data(contentsOf: stfs)) == supportedPackage else {
            throw SetupError("This is not the verified TU3 update for Media ID 2DF41A75.")
        }
        let staged = Installation(source: source, target: stage, runtime: runtime)
        try run(runtime.appendingPathComponent("ExtractTU"), [stfs.path, staged.update.path])
        try run(URL(fileURLWithPath: "/bin/cp"), ["-cR", sourceGame.path, staged.game.path])
        for name in modules.keys {
            try fm.moveItem(at: staged.update.appendingPathComponent(name + "p"), to: staged.game.appendingPathComponent(name + "p"))
        }
        try fm.removeItem(at: stfs)
        try fm.createDirectory(at: staged.profile, withIntermediateDirectories: true)
        for name in ["55530833", "B13EBABEBABEBABE", "achievements", "grfs.toml"] {
            let file = source.appendingPathComponent("UserData/" + name)
            if fm.fileExists(atPath: file.path) {
                try fm.copyItem(at: file, to: staged.profile.appendingPathComponent(name))
            }
        }
        try run(runtime.appendingPathComponent("InstallDLC"), [staged.game.path, staged.profile.path] + inputs.map(\.path))
        try staged.validate()
        try fm.moveItem(at: stage, to: target)
    }

    func play() throws {
        try validate()
        let directory = target.appendingPathComponent("Logs/" + UUID().uuidString)
        let metal = directory.appendingPathComponent("Metal")
        try fm.createDirectory(at: metal, withIntermediateDirectories: true)
        try Data("1\n".utf8).write(to: metal.appendingPathComponent("order.request"))
        let console = directory.appendingPathComponent("console.log")
        fm.createFile(atPath: console.path, contents: nil)
        let output = try FileHandle(forWritingTo: console)
        defer { try? output.close() }

        while true {
            let process = Process()
            let restart = RestartRequest(directory: directory)
            process.executableURL = runtime.appendingPathComponent("grfs")
            process.currentDirectoryURL = runtime
            process.arguments = ["--gpu_plugin=metal", "--grfs_output_resolution=native", "--grfs_present_limit=0", "--mnk_mode",
                                 fullscreenArgument(config: profile.appendingPathComponent("grfs.toml")),
                                 "--readback_resolve=fast", "--readback_memexport=true", "--allow_game_relative_writes=false",
                                 "--gpu_allow_invalid_fetch_constants=true", "--async_shader_compilation=false", "--execute_unclipped_draw_vs_on_cpu=true",
                                 "--game_data_root=" + game.path, "--user_data_root=" + profile.path, "--update_data_root=" + update.path,
                                 "--cache_root=" + target.appendingPathComponent("Cache").path, "--log_file=" + directory.appendingPathComponent("game.log").path]
            var env = ProcessInfo.processInfo.environment.filter { key, _ in
                !["GRFS_", "REX_GRFS_", "DYLD_", "MTL_"].contains(where: key.hasPrefix)
            }
            env.merge(["GRFS_FORWARD_FLOW": "1", "GRFS_CLEAR_PAIR": "1", "GRFS_SPIRV_OPTIMIZE": "0", "GRFS_SAFE_PREWARM": "0",
                       "GRFS_SKIP_PIPELINE_PRELOAD": "1", "GRFS_METAL_NATIVE_ABSOLUTE_BIAS": "1", "GRFS_METAL_QUEUE_SHADER_DONE": "1",
                       "GRFS_METAL_UNIFORM_PAGES": "64", "GRFS_METAL_FORENSICS": metal.path, "GRFS_METAL_COMPACT": "1",
                       "GRFS_WINDOW_TITLE": "GRFS Recompiled 3.1.2 · TU3 + DLC", "SDL_VIDEO_MAC_FULLSCREEN_SPACES": "1",
                       "MTL_DEBUG_LAYER": "0", "MTL_HUD_ENABLED": "1", "MTL_HUD_ALIGNMENT": "topright", "MTL_HUD_SHOW_ZERO_METRICS": "0",
                       "MTL_CAPTURE_ENABLED": "0", "REX_GRFS_VERIFY_PROBE": "1", "REX_GRFS_ENUM_EMPTY_ERROR": "1",
                       "DYLD_INSERT_LIBRARIES": runtime.appendingPathComponent("libGRFSWindowTitle.dylib").path]) { _, new in new }
            env.merge(restart.environment) { _, new in new }
            process.environment = env
            process.standardOutput = output
            process.standardError = output
            try process.run()
            process.waitUntilExit()
            if restart.consume(exitStatus: process.terminationStatus) { continue }
            guard process.terminationStatus == 0 else {
                throw SetupError("The game exited with code \(process.terminationStatus). Log: \(console.path)")
            }
            return
        }
    }
}

func choose(_ message: String, directory: Bool = false) -> URL? {
    let panel = NSOpenPanel()
    panel.message = message
    panel.canChooseFiles = !directory
    panel.canChooseDirectories = directory
    return panel.runModal() == .OK ? panel.url : nil
}

let support = fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
guard let runtime = Bundle.main.resourceURL?.appendingPathComponent("Game.app/Contents/MacOS") else { exit(1) }
let cli = CommandLine.arguments
let prepareOnly = cli.count == 6 && cli[1] == "--prepare-only"
let playPrepared = cli.count == 3 && cli[1] == "--play-prepared"
let installation = Installation(
    source: prepareOnly ? URL(fileURLWithPath: cli[4]) : support.appendingPathComponent("GRFS Recompiled"),
    target: prepareOnly ? URL(fileURLWithPath: cli[5]) : playPrepared ? URL(fileURLWithPath: cli[2])
        : support.appendingPathComponent("GRFS Recompiled TU3 Preview"),
    runtime: runtime)

if prepareOnly || playPrepared {
    do {
        if prepareOnly {
            try installation.prepare(archive: URL(fileURLWithPath: cli[2]), dlcFolder: URL(fileURLWithPath: cli[3]))
        } else {
            try installation.play()
        }
    } catch {
        FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8))
        exit(1)
    }
} else {
    let app = NSApplication.shared
    app.setActivationPolicy(.regular)
    app.activate(ignoringOtherApps: true)
    let lock = installation.target.deletingLastPathComponent().appendingPathComponent(".grfs-tu3-preview.lock")
    let fd = open(lock.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
    guard fd >= 0 else { exit(1) }
    defer { close(fd) }
    do {
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else { throw SetupError("The TU3 preview is already running.") }
        if !fm.fileExists(atPath: installation.target.path) {
            guard let archive = choose("Choose the TU3 ZIP or the extracted Media ID 2DF41A75 update."),
                  let dlc = choose("Choose your 55530833 DLC folder.", directory: true) else { exit(0) }
            try installation.prepare(archive: archive, dlcFolder: dlc)
        }
        app.setActivationPolicy(.accessory)
        try installation.play()
    } catch {
        app.setActivationPolicy(.regular)
        let alert = NSAlert(error: error)
        alert.runModal()
        exit(1)
    }
}
