from pathlib import Path
import tempfile,subprocess,shutil
root=Path(__file__).resolve().parent
with tempfile.TemporaryDirectory() as tmp:
    t=Path(tmp)
    (t/'main.swift').write_text('''import Foundation
import CryptoKit
func expectFailure(_ operation: () throws -> Void) { do { try operation(); fatalError("Expected rejection") } catch {} }
let key = Curve25519.Signing.PrivateKey()
func envelope(_ url: String, _ size: Int = 123) throws -> Data {
 let m = UpdateManifest(version:"0.10.0.2",build:2026101905,url:url,sha256:String(repeating:"a",count:64),size:size,minimumSystem:"27.0",notes:"test")
 let payload = try JSONEncoder().encode(m)
 return try JSONEncoder().encode(SignedUpdate(payload:payload.base64EncodedString(),signature:key.signature(for:payload).base64EncodedString()))
}
let good = try envelope("https://github.com/alex-stampede/GRFS-Recomp/releases/download/v0.10.0.2/GRFS-Recompiled-macOS-arm64.zip")
assert(try Updates.verified(good,publicKey:key.publicKey.rawRepresentation).build == 2026101905)
expectFailure { _ = try Updates.verified(good,publicKey:Curve25519.Signing.PrivateKey().publicKey.rawRepresentation) }
let e = try JSONDecoder().decode(SignedUpdate.self,from:good)
let tampered = try JSONEncoder().encode(SignedUpdate(payload:Data("bad".utf8).base64EncodedString(),signature:e.signature))
expectFailure { _ = try Updates.verified(tampered,publicKey:key.publicKey.rawRepresentation) }
for url in ["http://github.com/alex-stampede/GRFS-Recomp/releases/download/a/b", "https://evil.example/release.zip", "https://github.com/other/repo/releases/download/a/b"] {
 expectFailure { _ = try Updates.verified(envelope(url),publicKey:key.publicKey.rawRepresentation) }
}
assert(Updates.newer(2026101905,than:"2026101904"))
assert(!Updates.newer(2026101904,than:"2026101904"))
assert(!Updates.newer(2026101903,than:"2026101904"))
print("PASS: signed manifest, wrong key, tampering, host/repository/HTTPS and version checks")
'''.replace('assert(try Updates.verified(good,publicKey:key.publicKey.rawRepresentation).build == 2026101905)','let verified = try Updates.verified(good,publicKey:key.publicKey.rawRepresentation); assert(verified.build == 2026101905)'))
    subprocess.run(['swiftc',str(t/'main.swift'),str(root/'Launcher.swift'),str(root/'Updater.swift'),str(root/'LauncherTheme.swift'),str(root/'LegacyBackups.swift'),'-framework','AppKit','-framework','CryptoKit','-module-cache-path','/private/tmp/grfs-swift-cache','-o',str(t/'tests')],check=True)
    subprocess.run([str(t/'tests')],check=True)
    for name,content in [('old.app','old'),('new.app','new')]:
        (t/name).mkdir();(t/name/'version').write_text(content)
    (t/'UserData').mkdir();(t/'UserData/save').write_text('preserve')
    subprocess.run(['/private/tmp/grfs-update-helper',str(t/'new.app'),str(t/'old.app'),'999999',str(t/'Backups'),'--test-no-reopen'],check=True)
    assert (t/'old.app/version').read_text()=='new'
    assert (t/'Backups/Previous.app.backup/version').read_text()=='old'
    assert (t/'UserData/save').read_text()=='preserve'
    (t/'new.app/version').write_text('newer')
    subprocess.run(['/private/tmp/grfs-update-helper',str(t/'new.app'),str(t/'old.app'),'999999',str(t/'Backups'),'--test-no-reopen'],check=True)
    assert (t/'old.app/version').read_text()=='newer'
    assert (t/'Backups/Previous.app.backup/version').read_text()=='new'
    assert len(list((t/'Backups').iterdir()))==1
    assert len(list(t.glob('*.app')))==2
    result=subprocess.run(['/private/tmp/grfs-update-helper',str(t/'missing.app'),str(t/'old.app'),'999999',str(t/'Backups'),'--test-no-reopen'],capture_output=True)
    assert result.returncode!=0 and (t/'old.app/version').read_text()=='newer'
print('PASS: app replacement, previous-version backup, savedata preservation and missing-download failure')
