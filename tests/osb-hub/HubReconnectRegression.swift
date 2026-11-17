import Foundation

@main struct ReconnectRegression {
    @MainActor static func main() async throws {
        let fixture = try JSONSerialization
            .jsonObject(with: Data(contentsOf: URL(fileURLWithPath: CommandLine
                    .arguments[1]))) as! [String: Any]
        let key = try HubKeyPair(privateKey: hubBase64UrlDecode(fixture["deviceKey"] as! String)!)
        let hubKey = hubBase64UrlDecode(fixture["hubKey"] as! String)!
        var seen: HubSeen?
        func state(_ seq: Int, _ devices: [String]) -> [String: Any] {
            [
                "hub": ["epoch": 1000, "access": ["seq": seq]],
                "devices": devices.map { ["id": $0, "name": $0] },
            ]
        }
        HubSeen.note(&seen, state: state(50, ["owner", "new-device"]), now: 1000)
        let urls = (fixture["urls"] as! [String]).map { URL(string: $0)! }
        let pinned = try HubOwnership.read(fixture["ownershipHub"] as! [String: Any],
                                           hubKey: hubBase64UrlEncode(hubKey), held: nil, epoch: nil)
        let connection = try await HubConnection.connect(urls: urls, key: key, hubKey: hubKey,
                                                         hello: HubSeen.hello(seen, now: 2000),
                                                         validateWelcome: { message in
                                                             _ = try hubValidateEvidence(
                                                                 message,
                                                                 hubKey: hubBase64UrlEncode(hubKey),
                                                                 ownership: pinned,
                                                                 epoch: 1000,
                                                                 seen: seen
                                                             )
                                                         })
        HubSeen.note(&seen, state: connection.welcome.object["state"] as! [String: Any], now: 3000)
        let saved = URL(fileURLWithPath: CommandLine.arguments[2])
        HubSeenStore.save(seen, to: saved, now: 3000)
        seen = HubSeenStore.load(from: saved, now: 4000)
        let hello = HubSeen.hello(seen, now: 4000)
        let output: [String: Any] = ["url": connection.url.absoluteString, "hello": hello,
                                     "inventedRemoval": seen!.removed.contains { $0.device == "new-device" }]
        let data = try JSONSerialization.data(withJSONObject: output, options: [.sortedKeys])
        print(String(decoding: data, as: UTF8.self))
        connection.close()
        if seen!.accessSeq != 50 || !seen!.removed.isEmpty || connection.url != urls.last {
            exit(1)
        }
    }
}
