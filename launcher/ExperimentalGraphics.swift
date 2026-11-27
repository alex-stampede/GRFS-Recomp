import AppKit
import CryptoKit

// Local development entry point. Never labels a Vulkan launch as native Metal.
enum MetalLab {
    static let gameplayAvailable = false
    static func verifyResources(_ root: URL) throws {
        let manifest = try JSONDecoder().decode([String: Expected].self,
            from: Data(contentsOf: root.appendingPathComponent("integrity.json")))
        guard !manifest.isEmpty else { throw Failure("The Metal validation manifest is empty.") }
        for (name, expected) in manifest {
            guard !name.contains("/"), !name.contains("..") else { throw Failure("Invalid Metal resource name.") }
            let data = try Data(contentsOf: root.appendingPathComponent("Capture/" + name))
            guard UInt64(data.count) == expected.size, digest(data) == expected.sha256 else {
                throw Failure("Metal capture integrity check failed: " + name)
            }
        }
    }
    static func validate() throws -> URL {
        guard let resources = Bundle.main.resourceURL else { throw Failure("Missing bundle resources.") }
        let root = resources.appendingPathComponent("MetalLab")
        try verifyResources(root)
        let output = fm.temporaryDirectory.appendingPathComponent("GRFS-Metal-Validation-" + UUID().uuidString)
        try fm.createDirectory(at: output, withIntermediateDirectories: true)
        let log = output.appendingPathComponent("run.log")
        guard fm.createFile(atPath:log.path, contents:nil) else { throw Failure("Could not create validation log.") }
        let handle = try FileHandle(forWritingTo:log); defer { try? handle.close() }
        let p = Process(); p.executableURL = root.appendingPathComponent("replay-texture")
        p.arguments = [root.appendingPathComponent("Capture").path, output.path]
        var environment = ProcessInfo.processInfo.environment.filter {
            !$0.key.hasPrefix("GRFS_") && !$0.key.hasPrefix("REX_GRFS_") && !$0.key.hasPrefix("DYLD_")
        }
        environment["MTL_DEBUG_LAYER"] = "1"; environment["MVK_CONFIG_LOG_LEVEL"] = "1"
        p.environment = environment; p.standardOutput = handle; p.standardError = handle
        try p.run()
        let deadline = Date().addingTimeInterval(90)
        while p.isRunning && Date() < deadline { Thread.sleep(forTimeInterval:0.1) }
        if p.isRunning { p.terminate(); throw Failure("Metal validation timed out. Log: " + log.path) }
        guard p.terminationStatus == 0 else { throw Failure("Metal validation failed. Log: " + log.path) }
        let data = try Data(contentsOf:output.appendingPathComponent("report.json"))
        guard let report = try JSONSerialization.jsonObject(with:data) as? [String:Any],
              report["real_textured_draw"] as? Bool == true,
              report["full_game_backend"] as? Bool == false,
              report["sequence_shared_target"] as? Bool == true,
              report["sequence_single_command_buffer"] as? Bool == true,
              report["compared_channels"] as? Int == 2496000,
              report["mismatched_channels"] as? Int == 0,
              report["sequence_mismatched_channels"] as? Int == 0,
              (report["reordered_sequence_mismatched_channels"] as? Int ?? 0) > 0
        else { throw Failure("Metal validation did not produce a passing report.") }
        return output
    }
}

final class ExperimentalGraphicsWindow: NSObject {
    private let launcher: Launcher
    private var window: NSWindow!
    private let selector = NSPopUpButton()
    private let action = GRFSActionButton(title:"Play using Vulkan", target:nil, action:nil)
    private let detail = NSTextField(wrappingLabelWithString:"")
    private let status = NSTextField(wrappingLabelWithString:"")
    private var running = false
    init(launcher:Launcher) { self.launcher = launcher; super.init() }
    func show() {
        window = NSWindow(contentRect:NSRect(x:0,y:0,width:820,height:530),
            styleMask:[.titled,.closable,.miniaturizable],backing:.buffered,defer:false)
        window.title = "GRFS — Experimental Graphics"; window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named:.darkAqua); window.center()
        let background = GRFSBackdrop(); window.contentView = background
        let title = NSTextField(labelWithString:"GRFS // GRAPHICS LAB")
        title.font = .monospacedSystemFont(ofSize:25,weight:.bold)
        title.textColor = NSColor(srgbRed:0.49,green:0.91,blue:0.85,alpha:1)
        selector.addItems(withTitles:["Vulkan / MoltenVK — gameplay", "Native Metal — experimental validation"])
        selector.target = self; selector.action = #selector(selectionChanged)
        detail.font = .systemFont(ofSize:16); detail.textColor = .white
        status.font = .monospacedSystemFont(ofSize:12,weight:.medium); status.textColor = title.textColor
        action.target = self; action.action = #selector(performAction); action.isBordered = false
        for view in [title,selector,detail,status,action] { view.translatesAutoresizingMaskIntoConstraints = false; background.addSubview(view) }
        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo:background.leadingAnchor,constant:48),title.topAnchor.constraint(equalTo:background.topAnchor,constant:48),
            selector.leadingAnchor.constraint(equalTo:title.leadingAnchor),selector.topAnchor.constraint(equalTo:title.bottomAnchor,constant:28),selector.widthAnchor.constraint(equalToConstant:630),
            detail.leadingAnchor.constraint(equalTo:title.leadingAnchor),detail.trailingAnchor.constraint(equalTo:background.trailingAnchor,constant:-48),detail.topAnchor.constraint(equalTo:selector.bottomAnchor,constant:24),
            status.leadingAnchor.constraint(equalTo:title.leadingAnchor),status.trailingAnchor.constraint(equalTo:detail.trailingAnchor),status.bottomAnchor.constraint(equalTo:action.topAnchor,constant:-20),
            action.trailingAnchor.constraint(equalTo:detail.trailingAnchor),action.bottomAnchor.constraint(equalTo:background.bottomAnchor,constant:-48),action.widthAnchor.constraint(equalToConstant:235),action.heightAnchor.constraint(equalToConstant:42)
        ])
        selectionChanged(); launcher.window.orderOut(nil); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps:true)
    }
    @objc private func selectionChanged() {
        guard !running else { return }
        if selector.indexOfSelectedItem == 0 {
            detail.stringValue = "Launch the playable GRFS runtime using Vulkan through MoltenVK. Existing controls and saves are preserved."
            action.title = "Play using Vulkan"
        } else {
            detail.stringValue = "Native Metal gameplay is not implemented yet. This runs the captured GRFS texture and three-draw validation on Metal, compared with a Vulkan reference. It does not launch a playable Metal backend."
            action.title = "Run Metal validation"
        }
        status.stringValue = "LOCAL EXPERIMENT // NOT A RELEASE UPDATE"
    }
    @objc private func performAction() {
        guard !running else { return }
        if selector.indexOfSelectedItem == 0 { window.orderOut(nil); launcher.window.makeKeyAndOrderFront(nil); launcher.continueStartup(); return }
        running = true; action.isEnabled = false; selector.isEnabled = false
        status.stringValue = "Validating captured resources and native Metal rendering…"
        DispatchQueue.global(qos:.userInitiated).async {
            let result = Result { try MetalLab.validate() }
            DispatchQueue.main.async {
                self.running = false; self.action.isEnabled = true; self.selector.isEnabled = true
                switch result {
                case .success(let output):
                    self.status.stringValue = "PASS // Exact image match and correct draw ordering. Gameplay port still pending."
                    NSWorkspace.shared.open(output)
                case .failure(let error): self.status.stringValue = error.localizedDescription
                }
            }
        }
    }
}
