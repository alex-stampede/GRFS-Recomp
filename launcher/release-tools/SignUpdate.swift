import Foundation
import CryptoKit
let args = CommandLine.arguments
func fail() -> Never { fputs("Usage: SignUpdate init key public | sign key payload output\n",stderr); exit(2) }
guard args.count >= 2 else { fail() }
do {
    if args[1] == "init" && args.count == 4 {
        let keyURL = URL(fileURLWithPath:args[2])
        let key: Curve25519.Signing.PrivateKey
        if FileManager.default.fileExists(atPath:keyURL.path) { key = try .init(rawRepresentation:Data(contentsOf:keyURL)) }
        else { key = .init(); try key.rawRepresentation.write(to:keyURL,options:.atomic); try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:keyURL.path) }
        try (key.publicKey.rawRepresentation.base64EncodedString()+"\n").write(toFile:args[3],atomically:true,encoding:.utf8)
    } else if args[1] == "sign" && args.count == 5 {
        let key = try Curve25519.Signing.PrivateKey(rawRepresentation:Data(contentsOf:URL(fileURLWithPath:args[2])))
        let payload = try Data(contentsOf:URL(fileURLWithPath:args[3]))
        let envelope = ["payload":payload.base64EncodedString(),"signature":try key.signature(for:payload).base64EncodedString()]
        try JSONSerialization.data(withJSONObject:envelope,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:args[4]),options:.atomic)
    } else { fail() }
} catch { fputs("Signing failed: \(error)\n",stderr); exit(1) }
