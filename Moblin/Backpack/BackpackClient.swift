import Foundation
import Network

let backpackBonjourType = "_osb-backpack._tcp"
let backpackBonjourDomain = "local"

struct BackpackStatus: Decodable {
    struct Verdict: Decodable {
        var level: String
        var line: String
    }

    struct Box: Decodable {
        var name: String
        var state: String
        var batteryPct: Int
        var minutesLeft: Int
        var charging: Bool
        var celsius: Int
        var heat: String
    }

    struct Show: Decodable {
        var state: String
        var onAir: String
        var scene: String
        var liveSeconds: Int
        var video: String
        var targetKbps: Int
        var actualKbps: Int
    }

    struct Handover: Decodable {
        var phase: String
        var to: String
        var progress: Double

        func isRunning() -> Bool {
            phase == "preparing" || phase == "switching"
        }
    }

    struct Privacy: Decodable {
        var mode: String
        var returningIn: Int?

        func isPrivate() -> Bool {
            mode != "off"
        }
    }

    struct Phone: Decodable {
        var camera: Bool
        var link: Bool
        var remote: Bool
    }

    struct Link: Decodable, Identifiable {
        var id: String
        var kind: String
        var name: String
        var detail: String
        var state: String
        var bars: Int
        var upKbps: Int
        var rttMs: Int
        var lossPct: Double
        var usedMb: Int

        func isUp() -> Bool {
            state == "up" || state == "weak"
        }
    }

    struct Action: Decodable, Identifiable {
        var id: String
        var label: String
        var cost: String
    }

    struct Finding: Decodable, Identifiable {
        var id: String
        var headline: String
        var place: String
        var sure: String
        var viewers: String
        var done: String
        var actions: [Action]
        var fine: String
        var known: Bool

        enum CodingKeys: String, CodingKey {
            case id
            case headline
            case place = "where"
            case sure
            case viewers
            case done
            case actions
            case fine
            case known
        }
    }

    struct Lesson: Decodable, Identifiable {
        var id: String
        var title: String
        var body: String
        var read: Bool
    }

    struct Message: Decodable, Identifiable {
        var id: String
        var from: String
        var role: String
        var level: String
        var text: String
        var seen: Bool
        var reply: String?
        var alerts: Int
    }

    var seq: Int
    var simulated: Bool
    var verdict: Verdict
    var box: Box
    var show: Show
    var handover: Handover
    var privacy: Privacy
    var phone: Phone
    var links: [Link]
    var finding: Finding?
    var lessons: [Lesson]
    var messages: [Message]
}

@MainActor
protocol BackpackClientDelegate: AnyObject {
    func backpackClientConnected()
    func backpackClientDisconnected()
    func backpackClientStatus(status: BackpackStatus)
}

@MainActor
final class BackpackClient {
    private let webSocket: WebSocketClient
    private weak var delegate: (any BackpackClientDelegate)?
    private let decoder = JSONDecoder()
    let url: URL

    init(url: URL, delegate: any BackpackClientDelegate) {
        self.url = url
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

    func send(command: String, arguments: [String: String] = [:]) {
        var message = arguments
        message["type"] = "command"
        message["command"] = command
        send(message: message)
    }

    private func send(message: [String: String]) {
        guard let data = try? JSONSerialization.data(withJSONObject: message, options: [.sortedKeys]),
              let text = String(data: data, encoding: .utf8)
        else {
            return
        }
        webSocket.send(string: text)
    }
}

extension BackpackClient: WebSocketClientDelegate {
    func webSocketClientConnected(_: WebSocketClient) {
        send(message: ["type": "hello", "app": appDisplayName(), "version": appVersion()])
        delegate?.backpackClientConnected()
    }

    func webSocketClientDisconnected(_: WebSocketClient) {
        delegate?.backpackClientDisconnected()
    }

    func webSocketClientReceiveMessage(_: WebSocketClient, string: String) {
        do {
            let status = try decoder.decode(BackpackStatus.self, from: Data(string.utf8))
            delegate?.backpackClientStatus(status: status)
        } catch {
            logger.info("backpack: Failed to decode status: \(error)")
        }
    }
}

@MainActor
protocol BackpackScannerDelegate: AnyObject {
    func backpackScannerFound(name: String, url: URL)
}

@MainActor
final class BackpackScanner: NSObject {
    private var browser: NetServiceBrowser?
    private var services: [NetService] = []
    private weak var delegate: (any BackpackScannerDelegate)?

    init(delegate: any BackpackScannerDelegate) {
        self.delegate = delegate
    }

    func start() {
        browser = NetServiceBrowser()
        browser?.delegate = self
        browser?.searchForServices(ofType: backpackBonjourType, inDomain: backpackBonjourDomain)
    }

    func stop() {
        browser?.stop()
        browser = nil
        for service in services {
            service.stop()
        }
        services.removeAll()
    }

    private func ipv4Address(address: Data) -> (host: String, value: UInt32)? {
        guard address.count >= MemoryLayout<sockaddr_in>.size else {
            return nil
        }
        return address.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) -> (String, UInt32)? in
            guard let base = pointer.baseAddress else {
                return nil
            }
            guard base.assumingMemoryBound(to: sockaddr.self).pointee.sa_family == sa_family_t(AF_INET) else {
                return nil
            }
            var inAddress = base.assumingMemoryBound(to: sockaddr_in.self).pointee.sin_addr
            var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            guard inet_ntop(AF_INET, &inAddress, &buffer, socklen_t(INET_ADDRSTRLEN)) != nil else {
                return nil
            }
            return (String(cArray: buffer), UInt32(bigEndian: inAddress.s_addr))
        }
    }

    private func localNetworks() -> [(network: UInt32, mask: UInt32)] {
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0, let first = interfaces else {
            return []
        }
        defer {
            freeifaddrs(interfaces)
        }
        var networks: [(UInt32, UInt32)] = []
        for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let interface = pointer.pointee
            guard let address = interface.ifa_addr,
                  let netmask = interface.ifa_netmask,
                  address.pointee.sa_family == sa_family_t(AF_INET),
                  interface.ifa_flags & UInt32(IFF_LOOPBACK) == 0
            else {
                continue
            }
            let value = address.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
                UInt32(bigEndian: $0.pointee.sin_addr.s_addr)
            }
            let mask = netmask.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
                UInt32(bigEndian: $0.pointee.sin_addr.s_addr)
            }
            networks.append((value & mask, mask))
        }
        return networks
    }

    fileprivate func preferredHost(addresses: [Data]) -> String? {
        let candidates = addresses.compactMap { ipv4Address(address: $0) }
        let networks = localNetworks()
        let local = candidates.first { candidate in
            networks.contains { candidate.value & $0.mask == $0.network }
        }
        return (local ?? candidates.first)?.host
    }
}

extension BackpackScanner: @MainActor NetServiceBrowserDelegate {
    func netServiceBrowser(_: NetServiceBrowser, didFind service: NetService, moreComing _: Bool) {
        guard !services.contains(service) else {
            return
        }
        services.append(service)
        service.delegate = self
        service.resolve(withTimeout: 5.0)
    }

    func netServiceBrowser(_: NetServiceBrowser, didRemove service: NetService, moreComing _: Bool) {
        services.removeAll(where: { $0 == service })
    }
}

extension BackpackScanner: @MainActor NetServiceDelegate {
    func netServiceDidResolveAddress(_ service: NetService) {
        var path = "/ws"
        if let data = service.txtRecordData(),
           let value = NetService.dictionary(fromTXTRecord: data)["path"],
           let text = String(data: value, encoding: .utf8)
        {
            path = text
        }
        guard let host = preferredHost(addresses: service.addresses ?? []),
              let url = URL(string: "ws://\(host):\(service.port)\(path)")
        else {
            return
        }
        delegate?.backpackScannerFound(name: service.name, url: url)
    }
}
