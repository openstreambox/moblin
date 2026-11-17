import Foundation

@main struct HubNoiseResponder {
    static func main() throws {
        let key = try HubKeyPair(privateKey: Data(repeating: 7, count: 32))
        let handshake = try HubNoiseHandshake(pattern: "IK", initiator: false, prologue: hubPrologue, s: key)
        guard let line = readLine(), let frame = Data(base64Encoded: line) else { exit(1) }
        let hello = try handshake.readMessage(Data(frame.dropFirst()))
        let reply = try handshake.writeMessage(Data())
        let transport = try handshake.split()
        let welcome = try transport.seal(Data(CommandLine.arguments[1].utf8))
        let result: [String: Any] = try [
            "hello": JSONSerialization.jsonObject(with: hello),
            "reply": reply.base64EncodedString(),
            "welcome": welcome.base64EncodedString(),
        ]
        try print(String(decoding: JSONSerialization.data(withJSONObject: result), as: UTF8.self))
    }
}
