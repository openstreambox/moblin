import CryptoKit
import Foundation

let dashboardUrlScheme = "openstreambox"

struct DashboardJoinLink {
    let url: URL
    let invite: String
    let name: String
    let fingerprint: String

    init?(url: URL) {
        guard url.scheme == dashboardUrlScheme,
              url.host() == "join",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else {
            return nil
        }
        let items = components.queryItems ?? []
        guard let address = items.first(where: { $0.name == "d" })?.value,
              let deviceUrl = URL(string: address),
              let invite = items.first(where: { $0.name == "i" })?.value,
              !invite.isEmpty
        else {
            return nil
        }
        self.url = deviceUrl
        self.invite = invite
        name = items.first(where: { $0.name == "n" })?.value ?? String(localized: "Dashboard")
        fingerprint = items.first(where: { $0.name == "f" })?.value ?? ""
    }
}

struct DashboardProfile: Decodable {
    struct Stream: Decodable {
        var bitrateKbps: Int?
    }

    struct Buttons: Decodable {
        var streaming: [String: Bool]?
        var companion: [String: Bool]?
    }

    var version: Int
    var stream: Stream?
    var buttons: Buttons?
    var readAloud: Bool?
}

struct DashboardMessage: Decodable {
    var type: String
    var request: String?
    var nonce: String?
    var dashboard: String?
    var fingerprint: String?
    var device: String?
    var token: String?
    var role: String?
    var profile: DashboardProfile?
    var reason: String?
}

func dashboardMatchingCode(invite: String, deviceNonce: String, dashboardNonce: String) -> String {
    let key = SymmetricKey(data: Data(invite.utf8))
    let mac = HMAC<SHA256>.authenticationCode(for: Data("\(deviceNonce):\(dashboardNonce)".utf8), using: key)
    let value = Data(mac).prefix(4).reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
    return String(format: "%06u", value % 1_000_000)
}

func dashboardNonce() -> String {
    (0 ..< 16).map { _ in String(format: "%02x", UInt8.random(in: 0 ... 255)) }.joined()
}

@MainActor
protocol DashboardClientDelegate: AnyObject {
    func dashboardClientConnected()
    func dashboardClientDisconnected()
    func dashboardClientMessage(message: DashboardMessage)
}

@MainActor
final class DashboardClient {
    private let webSocket: WebSocketClient
    private weak var delegate: (any DashboardClientDelegate)?
    private let decoder = JSONDecoder()

    init(url: URL, delegate: any DashboardClientDelegate) {
        self.delegate = delegate
        webSocket = WebSocketClient(url: url, cellular: false)
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        webSocket.delegate = self
    }

    func start() {
        webSocket.start()
    }

    func stop() {
        webSocket.stop()
    }

    func send(message: [String: String]) {
        guard let data = try? JSONSerialization.data(withJSONObject: message, options: [.sortedKeys]),
              let text = String(data: data, encoding: .utf8)
        else {
            return
        }
        webSocket.send(string: text)
    }
}

extension DashboardClient: WebSocketClientDelegate {
    func webSocketClientConnected(_: WebSocketClient) {
        delegate?.dashboardClientConnected()
    }

    func webSocketClientDisconnected(_: WebSocketClient) {
        delegate?.dashboardClientDisconnected()
    }

    func webSocketClientReceiveMessage(_: WebSocketClient, string: String) {
        do {
            let message = try decoder.decode(DashboardMessage.self, from: Data(string.utf8))
            delegate?.dashboardClientMessage(message: message)
        } catch {
            logger.info("dashboard: Failed to decode message: \(error)")
        }
    }
}
