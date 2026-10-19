import AppKit
import CryptoKit

struct UpdateManifest: Codable {
    let version: String
    let build: Int
    let url: String
    let sha256: String
    let size: Int
    let minimumSystem: String
    let notes: String
}
struct SignedUpdate: Codable { let payload: String; let signature: String }
struct ReleaseResponse: Decodable {
    struct Asset: Decodable { let name: String; let browser_download_url: String }
    let assets: [Asset]
}
enum Updates {
    static let repository = "alex-stampede/GRFS-Recomp"
    static let api = URL(string:"https://api.github.com/repos/\(repository)/releases/latest")!
    static func newer(_ build: Int, than current: String) -> Bool { build > (Int(current) ?? 0) }
    static func verified(_ data: Data, publicKey: Data) throws -> UpdateManifest {
        let signed = try JSONDecoder().decode(SignedUpdate.self,from:data)
        guard let payload = Data(base64Encoded:signed.payload), let signature = Data(base64Encoded:signed.signature),
              try Curve25519.Signing.PublicKey(rawRepresentation:publicKey).isValidSignature(signature,for:payload) else { throw Failure("La firma de la actualización no es válida.") }
        let m = try JSONDecoder().decode(UpdateManifest.self,from:payload)
        guard let url = URL(string:m.url), url.scheme == "https", url.host == "github.com",
              url.path.hasPrefix("/\(repository)/releases/download/"), m.sha256.count == 64,
              m.sha256.allSatisfy({ $0.isHexDigit }), m.size > 0, m.size <= 1024*1024*1024 else { throw Failure("Manifiesto de actualización inválido.") }
        return m
    }
    static func fetch(_ url: URL, limit: Int) async throws -> Data {
        var request = URLRequest(url:url); request.timeoutInterval = 12
        request.setValue("GRFS-Recomp-Launcher",forHTTPHeaderField:"User-Agent")
        let (data,response) = try await URLSession.shared.data(for:request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200, data.count <= limit else { throw Failure("GitHub no pudo entregar la actualización.") }
        return data
    }
    static func latest() async throws -> UpdateManifest? {
        let bytes = try await fetch(api,limit:1024*1024)
        let release = try JSONDecoder().decode(ReleaseResponse.self,from:bytes)
        guard let asset = release.assets.first(where:{$0.name == "update.json"}),
              let url = URL(string:asset.browser_download_url), url.scheme == "https",url.host == "github.com",
              url.path.hasPrefix("/\(repository)/releases/download/") else { return nil }
        let data = try await fetch(url,limit:128*1024)
        guard let keyURL = Bundle.main.url(forResource:"update-public-key",withExtension:"txt"),
              let key = Data(base64Encoded:try String(contentsOf:keyURL,encoding:.utf8).trimmingCharacters(in:.whitespacesAndNewlines)) else { throw Failure("Falta la clave de actualizaciones.") }
        return try verified(data,publicKey:key)
    }
    static func run(_ executable: String, _ arguments: [String]) throws {
        let p = Process(); p.executableURL = URL(fileURLWithPath:executable); p.arguments = arguments
        let output = Pipe(); p.standardOutput = output; p.standardError = output
        try p.run()
        let result = output.fileHandleForReading.readDataToEndOfFile(); p.waitUntilExit()
        guard p.terminationStatus == 0 else { throw Failure(String(data:result,encoding:.utf8) ?? "Error preparando actualización.") }
    }
    static func stage(_ m: UpdateManifest, progress: @escaping (Double,String)->Void) async throws -> URL {
        let root = fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/GRFS Recompiled/Updates/"+UUID().uuidString)
        try fm.createDirectory(at:root,withIntermediateDirectories:true)
        do {
            progress(0,"Descargando versión \(m.version)…")
            var request = URLRequest(url:URL(string:m.url)!); request.timeoutInterval = 120
            let (temporary,response) = try await URLSession.shared.download(for:request)
            defer { try? fm.removeItem(at:temporary) }
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  try temporary.resourceValues(forKeys:[.fileSizeKey]).fileSize == m.size else { throw Failure("Descarga incompleta.") }
            progress(75,"Verificando firma y descarga…")
            let data = try Data(contentsOf:temporary,options:.mappedIfSafe)
            guard digest(data) == m.sha256 else { throw Failure("La descarga no coincide con la firma publicada.") }
            let zip = root.appendingPathComponent("update.zip"); try fm.moveItem(at:temporary,to:zip)
            let extracted = root.appendingPathComponent("Extracted")
            // Only a release signed by the pinned maintainer key can reach extraction.
            try run("/usr/bin/ditto",["-x","-k",zip.path,extracted.path])
            let app = extracted.appendingPathComponent("GRFS Recompiled.app")
            guard let bundle = Bundle(url:app),bundle.bundleIdentifier == Bundle.main.bundleIdentifier,
                  (bundle.object(forInfoDictionaryKey:"CFBundleVersion") as? String) == String(m.build) else { throw Failure("La app descargada no corresponde a esta actualización.") }
            try run("/usr/bin/codesign",["--verify","--deep","--strict",app.path])
            progress(100,"Actualización verificada. Preparando reinicio…")
            return app
        } catch { try? fm.removeItem(at:root); throw error }
    }
}
extension Launcher {
    func checkUpdates(then continuation: @escaping ()->Void) {
        busy = true; button.isEnabled = false; status.stringValue = "Comprobando actualizaciones…"
        Task {
            let candidate = try? await Updates.latest()
            await MainActor.run {
                guard let m = candidate, Updates.newer(m.build,than:Bundle.main.object(forInfoDictionaryKey:"CFBundleVersion") as? String ?? "0") else {
                    self.busy = false; self.button.isEnabled = true; continuation(); return
                }
                let alert = NSAlert(); alert.messageText = "Nueva versión \(m.version)"
                alert.informativeText = m.notes + "\n\nSe conservarán el juego instalado, tus partidas y la caché."
                alert.addButton(withTitle:"Descargar y actualizar"); alert.addButton(withTitle:"Ahora no")
                guard alert.runModal() == .alertFirstButtonReturn else { self.busy = false; self.button.isEnabled = true; continuation(); return }
                let os = ProcessInfo.processInfo.operatingSystemVersion
                let current = "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
                guard current.compare(m.minimumSystem,options:.numeric) != .orderedAscending else {
                    self.alert(Failure("Esta versión requiere macOS \(m.minimumSystem).")); self.busy = false; self.button.isEnabled = true; continuation(); return
                }
                self.downloadUpdate(m,then:continuation)
            }
        }
    }
    func downloadUpdate(_ m: UpdateManifest, then continuation: @escaping ()->Void) {
        Task {
            do {
                let app = try await Updates.stage(m) { value,text in self.update(value,text) }
                try await MainActor.run {
                    let target = Bundle.main.bundleURL
                    guard fm.isWritableFile(atPath:target.deletingLastPathComponent().path) else {
                        NSWorkspace.shared.activateFileViewerSelecting([app])
                        throw Failure("No se puede reemplazar esta app. Mueve la versión descargada a Aplicaciones manualmente.")
                    }
                    // Run a separate copy so replacing the app never invalidates the helper.
                    let helper = app.deletingLastPathComponent().appendingPathComponent("ApplyUpdate")
                    try fm.copyItem(at:Bundle.main.resourceURL!.appendingPathComponent("ApplyUpdate"),to:helper)
                    let process = Process(); process.executableURL = helper
                    process.arguments = [app.path,target.path,String(ProcessInfo.processInfo.processIdentifier)]
                    let log = self.home.appendingPathComponent("update.log"); fm.createFile(atPath:log.path,contents:nil)
                    let output = try FileHandle(forWritingTo:log); process.standardOutput = output; process.standardError = output
                    try process.run(); try? output.close()
                    self.busy = false; NSApp.terminate(nil)
                }
            } catch {
                await MainActor.run { self.busy = false; self.button.isEnabled = true; self.alert(error); continuation() }
            }
        }
    }
}
