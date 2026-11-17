import Foundation

// One control connection to the hub (osb-hub/1 protocol,
// section 3): a WebSocket carrying Noise. Join with a one-time ticket over
// XXpsk0, then reconnect over IK with this device's own key. Every frame
// is one Noise message; after the handshake each frame holds one JSON
// object, and the hub's first one is always the welcome.

enum HubConnectionError: Error, Equatable {
    // The hub refused the handshake: no live ticket matched, the ticket was
    // used or expired, or (IK) the hub doesn't know this device's key.
    case refused
    // The hub's key doesn't match the fingerprint in the code.
    case wrongHub
    case closed(code: Int)
    case timeout
    case invalid(String)
}

private let hubHandshakeTimeout: TimeInterval = 10
private let hubMaxPlaintext = 65519

@MainActor
final class HubConnection {
    private let session: URLSession
    private let task: URLSessionWebSocketTask
    private var transport: HubNoiseTransport?
    private var nextId = 1
    private var pending: [Int: CheckedContinuation<HubMessage, any Error>] = [:]
    private var closed = false
    private var handshakeTimedOut = false
    private(set) var welcome = HubMessage(object: [:])
    private(set) var hubKey = Data()
    let url: URL
    var onMessage: ((HubMessage) -> Void)?
    var onClose: ((Int?) -> Void)?

    private init(url: URL) {
        self.url = url
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = hubHandshakeTimeout
        session = URLSession(configuration: configuration)
        task = session.webSocketTask(with: url)
        task.maximumMessageSize = 1 << 17
    }

    // Join with a scanned code or an opened link. The hub's key is checked
    // against the code's fingerprint before this device says anything about
    // itself.
    static func join(link: HubJoinLink, key: HubKeyPair, name: String, kind: String,
                     validateWelcome: (HubMessage, Data) throws -> Void = { _, _ in }) async throws
        -> HubConnection
    {
        var lastError: any Error = HubConnectionError.invalid("no hub address")
        for url in link.hub {
            let connection = HubConnection(url: url)
            do {
                try await connection.runJoin(link: link, key: key, name: name, kind: kind)
                guard connection.welcome.type == "welcome" else {
                    throw HubConnectionError.invalid("missing welcome")
                }
                try validateWelcome(connection.welcome, connection.hubKey)
                return connection
            } catch let error as HubConnectionError where error == .refused || error == .wrongHub {
                connection.close()
                throw error
            } catch {
                connection.close()
                lastError = error
            }
        }
        throw lastError
    }

    // Reconnect with this device's own key, against the pinned hub key.
    static func connect(urls: [URL],
                        key: HubKeyPair,
                        hubKey: Data,
                        hello: [String: Any] = ["v": 1],
                        validateWelcome: (HubMessage) throws -> Void = { _ in },
                        refusalCounts: (URL) -> Bool = { _ in true }) async throws -> HubConnection
    {
        var lastError: any Error = HubConnectionError.invalid("no hub address")
        for url in urls {
            let connection = HubConnection(url: url)
            do {
                try await connection.runConnect(key: key, hubKey: hubKey, hello: hello)
                if let highest = ((hello["seen"] as? [String: Any])?["access_seq"] as? Int),
                   let state = connection.welcome.object["state"] as? [String: Any],
                   let hub = state["hub"] as? [String: Any],
                   let access = hub["access"] as? [String: Any],
                   (access["seq"] as? Int ?? -1) < highest
                {
                    throw HubConnectionError.invalid("stale access evidence")
                }
                guard connection.welcome.type == "welcome" else {
                    throw HubConnectionError.invalid("missing welcome")
                }
                try validateWelcome(connection.welcome)
                connection.startReceiving()
                return connection
            } catch let error as HubConnectionError where error == .refused {
                connection.close()
                if refusalCounts(url) {
                    throw error
                }
                lastError = HubConnectionError.closed(code: 4401)
            } catch {
                connection.close()
                lastError = error
            }
        }
        throw lastError
    }

    private func runJoin(link: HubJoinLink, key: HubKeyPair, name: String, kind: String) async throws {
        let handshake = try HubNoiseHandshake(pattern: "XXpsk0",
                                              initiator: true,
                                              prologue: hubPrologue,
                                              s: key,
                                              psks: [link.psk])
        try await withHandshakeTimeout {
            self.task.resume()
            let first = try handshake.writeMessage(self.json(["v": 1]))
            try await self.task.send(.data(Data([hubModeJoin]) + first))
            _ = try await handshake.readMessage(self.receiveFrame())
            guard let hubKey = handshake.rs, hubFingerprint(hubKey) == link.fingerprint else {
                throw HubConnectionError.wrongHub
            }
            try await self.task.send(.data(handshake.writeMessage(self.json([
                "v": 1,
                "name": name,
                "kind": kind,
            ]))))
            self.hubKey = hubKey
            self.transport = try handshake.split()
            self.welcome = try await self.decrypt(self.receiveFrame())
        }
        startReceiving()
    }

    private func runConnect(key: HubKeyPair, hubKey: Data, hello: [String: Any]) async throws {
        let handshake = try HubNoiseHandshake(pattern: "IK",
                                              initiator: true,
                                              prologue: hubPrologue,
                                              s: key,
                                              rs: hubKey)
        try await withHandshakeTimeout {
            self.task.resume()
            let first = try handshake.writeMessage(self.json(hello))
            try await self.task.send(.data(Data([hubModeConnect]) + first))
            _ = try await handshake.readMessage(self.receiveFrame())
            self.hubKey = hubKey
            self.transport = try handshake.split()
            self.welcome = try await self.decrypt(self.receiveFrame())
        }
        if welcome.type == "hub.redirect" {
            throw HubConnectionError.closed(code: 4410)
        }
    }

    private func withHandshakeTimeout(_ body: @escaping @MainActor () async throws -> Void) async throws {
        let timer = Task { @MainActor in
            try await Task.sleep(nanoseconds: UInt64(hubHandshakeTimeout * 1_000_000_000))
            self.handshakeTimedOut = true
            self.task.cancel(with: .goingAway, reason: nil)
        }
        defer {
            timer.cancel()
        }
        do {
            try await body()
        } catch let error as HubConnectionError {
            throw error
        } catch is HubNoiseError {
            throw HubConnectionError.invalid("the hub's handshake didn't check out")
        } catch {
            if handshakeTimedOut {
                throw HubConnectionError.timeout
            }
            throw closeError()
        }
    }

    private func closeCode() -> Int? {
        let code = task.closeCode.rawValue
        return code == URLSessionWebSocketTask.CloseCode.invalid.rawValue ? nil : code
    }

    private func closeError() -> HubConnectionError {
        guard let code = closeCode() else {
            return .closed(code: 0)
        }
        return code == 4401 ? .refused : .closed(code: code)
    }

    private func receiveFrame() async throws -> Data {
        switch try await task.receive() {
        case let .data(data):
            data
        case .string:
            throw HubConnectionError.invalid("text frame")
        @unknown default:
            throw HubConnectionError.invalid("unknown frame")
        }
    }

    private func json(_ object: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    private func decrypt(_ frame: Data) throws -> HubMessage {
        guard let transport else {
            throw HubConnectionError.invalid("no transport")
        }
        return try HubMessage(data: transport.open(frame))
    }

    private func startReceiving() {
        Task { @MainActor in
            while !self.closed {
                let frame: Data
                do {
                    frame = try await self.receiveFrame()
                } catch {
                    self.finish(code: self.closeCode())
                    return
                }
                guard let message = try? self.decrypt(frame) else {
                    // A frame that doesn't decrypt breaks the nonce order.
                    self.task.cancel(with: .protocolError, reason: nil)
                    self.finish(code: 4400)
                    return
                }
                self.dispatch(message)
            }
        }
    }

    private func dispatch(_ message: HubMessage) {
        if message.type == "reply", let id = message.id, let waiting = pending.removeValue(forKey: id) {
            if message.ok {
                waiting.resume(returning: message)
            } else {
                waiting.resume(throwing: message.error)
            }
            return
        }
        onMessage?(message)
    }

    private func finish(code: Int?) {
        guard !closed else {
            return
        }
        closed = true
        for waiting in pending.values {
            waiting.resume(throwing: HubConnectionError.closed(code: code ?? 0))
        }
        pending.removeAll()
        session.invalidateAndCancel()
        onClose?(code)
    }

    func request(_ type: String, _ params: [String: Any] = [:]) async throws -> HubMessage {
        guard !closed, let transport else {
            throw HubConnectionError.closed(code: 0)
        }
        let id = nextId
        nextId += 1
        let body = try hubEncodeRequest(id: id, type: type, params: params)
        guard body.count <= hubMaxPlaintext else {
            throw HubRequestError(code: "too_large", message: "request too large")
        }
        let frame = try transport.seal(body)
        return try await withCheckedThrowingContinuation { continuation in
            pending[id] = continuation
            task.send(.data(frame)) { error in
                guard error != nil else {
                    return
                }
                Task { @MainActor in
                    self.pending.removeValue(forKey: id)?
                        .resume(throwing: HubConnectionError.closed(code: 0))
                }
            }
        }
    }

    func close() {
        task.cancel(with: .normalClosure, reason: nil)
        finish(code: 1000)
    }
}

extension HubMessage: @unchecked Sendable {}
