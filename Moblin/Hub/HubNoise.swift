import CryptoKit
import Foundation

// The Noise Protocol Framework (revision 34) with 25519, ChaChaPoly and
// SHA-256, on CryptoKit alone. A generic token engine, so it can be checked
// against the published test vectors of several patterns; the hub protocol
// (osb-hub/1) uses two of them:
//
// - XXpsk0 to join with a one-time ticket: the ticket is the pre-shared key,
//   the hub's static key arrives encrypted and is checked against the
//   fingerprint the ticket carried, and this device's static key goes out in
//   the third message.
// - IK to reconnect: the device knows the hub's key and proves its own.
//
// It mirrors the hub's reference engine (server/hub/noise.ts of the
// reference hub) token for token.

let hubNoiseDhLength = 32
private let hubNoiseHashLength = 32
private let hubNoiseTagLength = 16

enum HubNoiseError: Error, Equatable {
    case unknownPattern(String)
    case missingKey(String)
    case badPreSharedKey
    case wrongTurn
    case tooShort
    case decryptFailed
    case notFinished
    case badKey
}

struct HubKeyPair {
    let privateKey: Data
    let publicKey: Data

    init(privateKey: Data) throws {
        guard let key = try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: privateKey) else {
            throw HubNoiseError.badKey
        }
        self.privateKey = Data(privateKey)
        publicKey = key.publicKey.rawRepresentation
    }

    static func generate() -> HubKeyPair {
        let key = Curve25519.KeyAgreement.PrivateKey()
        // A fresh CryptoKit key always round-trips.
        return try! HubKeyPair(privateKey: key.rawRepresentation)
    }
}

func hubNoiseDh(_ pair: HubKeyPair, _ remote: Data) throws -> Data {
    guard let privateKey = try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: pair.privateKey),
          let publicKey = try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: remote),
          let secret = try? privateKey.sharedSecretFromKeyAgreement(with: publicKey)
    else {
        throw HubNoiseError.badKey
    }
    return secret.withUnsafeBytes { Data($0) }
}

func hubSha256(_ data: Data) -> Data {
    Data(SHA256.hash(data: data))
}

private func hmac(_ key: Data, _ data: Data) -> Data {
    Data(HMAC<SHA256>.authenticationCode(for: data, using: SymmetricKey(data: key)))
}

private func hkdf(_ chainingKey: Data, _ inputKeyMaterial: Data, outputs: Int) -> [Data] {
    let temp = hmac(chainingKey, inputKeyMaterial)
    let one = hmac(temp, Data([1]))
    let two = hmac(temp, one + Data([2]))
    if outputs == 2 {
        return [one, two]
    }
    return [one, two, hmac(temp, two + Data([3]))]
}

private func noiseNonce(_ counter: UInt64) -> Data {
    var out = Data(count: 4)
    var little = counter.littleEndian
    withUnsafeBytes(of: &little) { out.append(contentsOf: $0) }
    return out
}

final class HubCipherState {
    private var key: Data?
    private(set) var nonce: UInt64 = 0

    func initializeKey(_ key: Data?) {
        self.key = key
        nonce = 0
    }

    func hasKey() -> Bool {
        key != nil
    }

    func encrypt(ad: Data, plaintext: Data) throws -> Data {
        guard let key else {
            return plaintext
        }
        let box = try ChaChaPoly.seal(plaintext,
                                      using: SymmetricKey(data: key),
                                      nonce: ChaChaPoly.Nonce(data: noiseNonce(nonce)),
                                      authenticating: ad)
        nonce += 1
        return box.ciphertext + box.tag
    }

    func decrypt(ad: Data, ciphertext: Data) throws -> Data {
        guard let key else {
            return ciphertext
        }
        let bytes = Data(ciphertext)
        guard bytes.count >= hubNoiseTagLength else {
            throw HubNoiseError.tooShort
        }
        do {
            let box = try ChaChaPoly.SealedBox(nonce: ChaChaPoly.Nonce(data: noiseNonce(nonce)),
                                               ciphertext: bytes.prefix(bytes.count - hubNoiseTagLength),
                                               tag: bytes.suffix(hubNoiseTagLength))
            let out = try ChaChaPoly.open(box, using: SymmetricKey(data: key), authenticating: ad)
            nonce += 1
            return out
        } catch {
            throw HubNoiseError.decryptFailed
        }
    }
}

private final class HubSymmetricState {
    let cipher = HubCipherState()
    var chainingKey: Data
    var hash: Data

    init(protocolName: String) {
        let name = Data(protocolName.utf8)
        if name.count <= hubNoiseHashLength {
            hash = name + Data(count: hubNoiseHashLength - name.count)
        } else {
            hash = hubSha256(name)
        }
        chainingKey = hash
    }

    func mixKey(_ inputKeyMaterial: Data) {
        let out = hkdf(chainingKey, inputKeyMaterial, outputs: 2)
        chainingKey = out[0]
        cipher.initializeKey(out[1])
    }

    func mixHash(_ data: Data) {
        hash = hubSha256(hash + data)
    }

    func mixKeyAndHash(_ inputKeyMaterial: Data) {
        let out = hkdf(chainingKey, inputKeyMaterial, outputs: 3)
        chainingKey = out[0]
        mixHash(out[1])
        cipher.initializeKey(out[2])
    }

    func encryptAndHash(_ plaintext: Data) throws -> Data {
        let out = try cipher.encrypt(ad: hash, plaintext: plaintext)
        mixHash(out)
        return out
    }

    func decryptAndHash(_ ciphertext: Data) throws -> Data {
        let out = try cipher.decrypt(ad: hash, ciphertext: ciphertext)
        mixHash(ciphertext)
        return out
    }

    func split() -> (HubCipherState, HubCipherState) {
        let out = hkdf(chainingKey, Data(), outputs: 2)
        let one = HubCipherState()
        let two = HubCipherState()
        one.initializeKey(out[0])
        two.initializeKey(out[1])
        return (one, two)
    }
}

enum HubNoiseToken: String {
    case e
    case s
    case ee
    case es
    case se
    case ss
    case psk
}

struct HubNoisePattern {
    // Pre-messages: which side's static key is known beforehand.
    let initiatorPre: [HubNoiseToken]
    let responderPre: [HubNoiseToken]
    let messages: [[HubNoiseToken]]

    private static let base: [String: HubNoisePattern] = [
        "NN": .init(initiatorPre: [], responderPre: [], messages: [[.e], [.e, .ee]]),
        "NK": .init(initiatorPre: [], responderPre: [.s], messages: [[.e, .es], [.e, .ee]]),
        "KK": .init(initiatorPre: [.s], responderPre: [.s], messages: [[.e, .es, .ss], [.e, .ee, .se]]),
        "XX": .init(initiatorPre: [], responderPre: [], messages: [[.e], [.e, .ee, .s, .es], [.s, .se]]),
        "IK": .init(initiatorPre: [], responderPre: [.s], messages: [[.e, .es, .s, .ss], [.e, .ee, .se]]),
    ]

    // "XXpsk0", "KKpsk2", "IK": a base pattern and its psk modifiers, as in
    // section 9 of the specification.
    static func named(_ name: String) throws -> HubNoisePattern {
        guard name.count >= 2, let base = base[String(name.prefix(2))] else {
            throw HubNoiseError.unknownPattern(name)
        }
        var rest = name.dropFirst(2)
        var messages = base.messages
        while !rest.isEmpty {
            guard rest.hasPrefix("psk"), let digit = rest.dropFirst(3).first, let at = Int(String(digit)),
                  at <= messages.count
            else {
                throw HubNoiseError.unknownPattern(name)
            }
            if at == 0 {
                messages[0].insert(.psk, at: 0)
            } else {
                messages[at - 1].append(.psk)
            }
            rest = rest.dropFirst(4)
        }
        return .init(initiatorPre: base.initiatorPre, responderPre: base.responderPre, messages: messages)
    }
}

final class HubNoiseTransport {
    let send: HubCipherState
    let receive: HubCipherState
    let handshakeHash: Data
    let remoteStatic: Data?

    init(send: HubCipherState, receive: HubCipherState, handshakeHash: Data, remoteStatic: Data?) {
        self.send = send
        self.receive = receive
        self.handshakeHash = handshakeHash
        self.remoteStatic = remoteStatic
    }

    // Transport messages: the AEAD with empty associated data.
    func seal(_ plaintext: Data) throws -> Data {
        try send.encrypt(ad: Data(), plaintext: plaintext)
    }

    func open(_ ciphertext: Data) throws -> Data {
        try receive.decrypt(ad: Data(), ciphertext: ciphertext)
    }
}

final class HubNoiseHandshake {
    private let symmetric: HubSymmetricState
    private let messages: [[HubNoiseToken]]
    private let initiator: Bool
    private var psks: [Data]
    private let isPsk: Bool
    private var step = 0
    private let s: HubKeyPair?
    private var e: HubKeyPair?
    private var presetE: HubKeyPair?
    private(set) var rs: Data?
    private var re: Data?

    // e: a fixed ephemeral key, for the test vectors only.
    init(pattern name: String,
         initiator: Bool,
         prologue: Data = Data(),
         s: HubKeyPair? = nil,
         rs: Data? = nil,
         psks: [Data] = [],
         e: HubKeyPair? = nil) throws
    {
        let pattern = try HubNoisePattern.named(name)
        symmetric = HubSymmetricState(protocolName: "Noise_\(name)_25519_ChaChaPoly_SHA256")
        messages = pattern.messages
        self.initiator = initiator
        self.psks = psks
        isPsk = name.contains("psk")
        self.s = s
        presetE = e
        self.rs = rs
        symmetric.mixHash(prologue)
        for (tokens, ours) in [(pattern.initiatorPre, initiator), (pattern.responderPre, !initiator)] {
            for token in tokens {
                guard token == .s else {
                    throw HubNoiseError.unknownPattern(name)
                }
                guard let key = ours ? s?.publicKey : rs else {
                    throw HubNoiseError.missingKey("pre-message")
                }
                symmetric.mixHash(key)
            }
        }
    }

    var done: Bool {
        step >= messages.count
    }

    // Whose turn it is: true when this side writes the next message.
    var writing: Bool {
        step % 2 == 0 ? initiator : !initiator
    }

    private func dhFor(_ token: HubNoiseToken) throws -> Data {
        // es: the initiator's ephemeral with the responder's static, and so on.
        let name = token.rawValue
        let initiatorKey = name.first!
        let responderKey = name.last!
        let (mine, theirs) = initiator ? (initiatorKey, responderKey) : (responderKey, initiatorKey)
        guard let pair = mine == "e" ? e : s, let remote = theirs == "e" ? re : rs else {
            throw HubNoiseError.missingKey(name)
        }
        return try hubNoiseDh(pair, remote)
    }

    private func nextPsk() throws -> Data {
        guard !psks.isEmpty else {
            throw HubNoiseError.badPreSharedKey
        }
        let psk = psks.removeFirst()
        guard psk.count == 32 else {
            throw HubNoiseError.badPreSharedKey
        }
        return psk
    }

    func writeMessage(_ payload: Data = Data()) throws -> Data {
        guard !done, writing else {
            throw HubNoiseError.wrongTurn
        }
        var out = Data()
        for token in messages[step] {
            switch token {
            case .e:
                let pair = presetE ?? HubKeyPair.generate()
                presetE = nil
                e = pair
                out += pair.publicKey
                symmetric.mixHash(pair.publicKey)
                if isPsk {
                    symmetric.mixKey(pair.publicKey)
                }
            case .s:
                guard let s else {
                    throw HubNoiseError.missingKey("s")
                }
                out += try symmetric.encryptAndHash(s.publicKey)
            case .psk:
                try symmetric.mixKeyAndHash(nextPsk())
            default:
                try symmetric.mixKey(dhFor(token))
            }
        }
        out += try symmetric.encryptAndHash(payload)
        step += 1
        return out
    }

    func readMessage(_ message: Data) throws -> Data {
        guard !done, !writing else {
            throw HubNoiseError.wrongTurn
        }
        let bytes = Data(message)
        var at = 0
        func take(_ length: Int) throws -> Data {
            guard at + length <= bytes.count else {
                throw HubNoiseError.tooShort
            }
            let out = Data(bytes[at ..< at + length])
            at += length
            return out
        }
        for token in messages[step] {
            switch token {
            case .e:
                let key = try take(hubNoiseDhLength)
                re = key
                symmetric.mixHash(key)
                if isPsk {
                    symmetric.mixKey(key)
                }
            case .s:
                let length = symmetric.cipher.hasKey() ? hubNoiseDhLength + hubNoiseTagLength : hubNoiseDhLength
                rs = try symmetric.decryptAndHash(take(length))
            case .psk:
                try symmetric.mixKeyAndHash(nextPsk())
            default:
                try symmetric.mixKey(dhFor(token))
            }
        }
        let payload = try symmetric.decryptAndHash(Data(bytes[at...]))
        step += 1
        return payload
    }

    func split() throws -> HubNoiseTransport {
        guard done else {
            throw HubNoiseError.notFinished
        }
        let (one, two) = symmetric.split()
        return HubNoiseTransport(send: initiator ? one : two,
                                 receive: initiator ? two : one,
                                 handshakeHash: symmetric.hash,
                                 remoteStatic: rs)
    }
}
