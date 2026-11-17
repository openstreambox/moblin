import Foundation
@testable import Moblin
import Testing

private struct Vector: Decodable {
    struct Message: Decodable {
        let payload: String
        let ciphertext: String
    }

    let protocol_name: String
    let init_prologue: String
    let init_static: String?
    let init_ephemeral: String
    let init_remote_static: String?
    let init_psks: [String]?
    let resp_prologue: String
    let resp_static: String?
    let resp_ephemeral: String?
    let resp_remote_static: String?
    let resp_psks: [String]?
    let handshake_hash: String?
    let messages: [Message]
}

private struct Vectors: Decodable {
    let vectors: [Vector]
}

private struct Transcript: Decodable {
    struct Message: Decodable {
        let payload: String
        let ciphertext: String
    }

    struct Xx: Decodable {
        let ticket: String
        let psk: String
        let hub_public: String
        let device_public: String
        let handshake_hash: String
        let messages: [Message]
    }

    struct Ik: Decodable {
        let handshake_hash: String
        let messages: [Message]
    }

    let keys: [String: String]
    let xxpsk0: Xx
    let ik: Ik
}

private func hex(_ text: String) -> Data {
    var data = Data()
    var index = text.startIndex
    while index < text.endIndex {
        let next = text.index(index, offsetBy: 2)
        data.append(UInt8(text[index ..< next], radix: 16)!)
        index = next
    }
    return data
}

private func hex(_ data: Data) -> String {
    data.map { String(format: "%02x", $0) }.joined()
}

private func pair(_ text: String?) throws -> HubKeyPair? {
    try text.map { try HubKeyPair(privateKey: hex($0)) }
}

private let vectors = try! JSONDecoder().decode(Vectors.self, from: Data(hubNoiseVectorsJson.utf8)).vectors
private let transcript = try! JSONDecoder().decode(Transcript.self, from: Data(hubTranscriptJson.utf8))

struct HubNoiseSuite {
    @Test(arguments: vectors.map(\.protocol_name))
    func matchesThePublishedVector(name: String) throws {
        let vector = vectors.first { $0.protocol_name == name }!
        let pattern = String(name.split(separator: "_")[1])
        let initiator = try HubNoiseHandshake(pattern: pattern,
                                              initiator: true,
                                              prologue: hex(vector.init_prologue),
                                              s: pair(vector.init_static),
                                              rs: vector.init_remote_static.map(hex),
                                              psks: (vector.init_psks ?? []).map(hex),
                                              e: pair(vector.init_ephemeral))
        let responder = try HubNoiseHandshake(pattern: pattern,
                                              initiator: false,
                                              prologue: hex(vector.resp_prologue),
                                              s: pair(vector.resp_static),
                                              rs: vector.resp_remote_static.map(hex),
                                              psks: (vector.resp_psks ?? []).map(hex),
                                              e: pair(vector.resp_ephemeral))
        let length = try HubNoisePattern.named(pattern).messages.count
        var a: HubNoiseTransport?
        var b: HubNoiseTransport?
        for (index, message) in vector.messages.enumerated() {
            let fromInitiator = index % 2 == 0
            let payload = hex(message.payload)
            if index < length {
                let (writer, reader) = fromInitiator ? (initiator, responder) : (responder, initiator)
                let wire = try writer.writeMessage(payload)
                #expect(hex(wire) == message.ciphertext, "message \(index)")
                #expect(try reader.readMessage(wire) == payload)
                if index == length - 1 {
                    a = try initiator.split()
                    b = try responder.split()
                    if let hash = vector.handshake_hash {
                        #expect(hex(a!.handshakeHash) == hash)
                    }
                }
                continue
            }
            let (writer, reader) = fromInitiator ? (a!, b!) : (b!, a!)
            let wire = try writer.seal(payload)
            #expect(hex(wire) == message.ciphertext, "message \(index)")
            #expect(try reader.open(wire) == payload)
        }
    }

    @Test
    func joinMatchesTheHubsEngineByteForByte() throws {
        let keys = transcript.keys
        let device = try HubNoiseHandshake(pattern: "XXpsk0",
                                           initiator: true,
                                           prologue: hubPrologue,
                                           s: pair(keys["device_static"]),
                                           psks: [hubTicketPsk(hex(transcript.xxpsk0.ticket))],
                                           e: pair(keys["device_ephemeral"]))
        let hub = try HubNoiseHandshake(pattern: "XXpsk0",
                                        initiator: false,
                                        prologue: hubPrologue,
                                        s: pair(keys["hub_static"]),
                                        psks: [hex(transcript.xxpsk0.psk)],
                                        e: pair(keys["hub_ephemeral"]))
        #expect(hex(hubTicketPsk(hex(transcript.xxpsk0.ticket))) == transcript.xxpsk0.psk)
        let messages = transcript.xxpsk0.messages
        var wire = try device.writeMessage(hex(messages[0].payload))
        #expect(hex(wire) == messages[0].ciphertext)
        #expect(try hub.readMessage(wire) == hex(messages[0].payload))
        wire = try hub.writeMessage(hex(messages[1].payload))
        #expect(hex(wire) == messages[1].ciphertext)
        #expect(try device.readMessage(wire) == hex(messages[1].payload))
        // After message 2 the device knows the hub's key, before saying anything about itself.
        #expect(hex(device.rs!) == transcript.xxpsk0.hub_public)
        wire = try device.writeMessage(hex(messages[2].payload))
        #expect(hex(wire) == messages[2].ciphertext)
        #expect(try hub.readMessage(wire) == hex(messages[2].payload))
        #expect(hex(hub.rs!) == transcript.xxpsk0.device_public)
        let deviceTransport = try device.split()
        let hubTransport = try hub.split()
        #expect(hex(deviceTransport.handshakeHash) == transcript.xxpsk0.handshake_hash)
        let welcome = try hubTransport.seal(hex(messages[3].payload))
        #expect(hex(welcome) == messages[3].ciphertext)
        #expect(try deviceTransport.open(welcome) == hex(messages[3].payload))
        let request = try deviceTransport.seal(hex(messages[4].payload))
        #expect(hex(request) == messages[4].ciphertext)
    }

    @Test
    func reconnectMatchesTheHubsEngineByteForByte() throws {
        let keys = transcript.keys
        let hubKey = try pair(keys["hub_static"])!
        let device = try HubNoiseHandshake(pattern: "IK",
                                           initiator: true,
                                           prologue: hubPrologue,
                                           s: pair(keys["device_static"]),
                                           rs: hubKey.publicKey,
                                           e: pair(keys["device_ephemeral2"]))
        let hub = try HubNoiseHandshake(pattern: "IK",
                                        initiator: false,
                                        prologue: hubPrologue,
                                        s: hubKey,
                                        e: pair(keys["hub_ephemeral2"]))
        let messages = transcript.ik.messages
        var wire = try device.writeMessage(hex(messages[0].payload))
        #expect(hex(wire) == messages[0].ciphertext)
        _ = try hub.readMessage(wire)
        wire = try hub.writeMessage(hex(messages[1].payload))
        #expect(hex(wire) == messages[1].ciphertext)
        _ = try device.readMessage(wire)
        #expect(hex(try device.split().handshakeHash) == transcript.ik.handshake_hash)
    }

    @Test
    func joinFailsWithTheWrongTicket() throws {
        let device = try HubNoiseHandshake(pattern: "XXpsk0", initiator: true, prologue: hubPrologue,
                                           s: HubKeyPair.generate(), psks: [hubTicketPsk(Data(count: 16))])
        let hub = try HubNoiseHandshake(pattern: "XXpsk0", initiator: false, prologue: hubPrologue,
                                        s: HubKeyPair.generate(),
                                        psks: [hubTicketPsk(Data(repeating: 1, count: 16))])
        let first = try device.writeMessage(Data("{\"v\":1}".utf8))
        #expect(throws: HubNoiseError.decryptFailed) {
            try hub.readMessage(first)
        }
    }

    @Test
    func tamperedHandshakeIsRefused() throws {
        let hubKey = HubKeyPair.generate()
        let device = try HubNoiseHandshake(pattern: "IK", initiator: true, s: HubKeyPair.generate(),
                                           rs: hubKey.publicKey)
        let hub = try HubNoiseHandshake(pattern: "IK", initiator: false, s: hubKey)
        var wire = try device.writeMessage(Data("payload".utf8))
        wire[wire.count - 1] ^= 1
        #expect(throws: HubNoiseError.decryptFailed) {
            try hub.readMessage(wire)
        }
    }

    @Test
    func transportNoncesCountUpAndRefuseReplays() throws {
        let hubKey = HubKeyPair.generate()
        let device = try HubNoiseHandshake(pattern: "IK", initiator: true, s: HubKeyPair.generate(),
                                           rs: hubKey.publicKey)
        let hub = try HubNoiseHandshake(pattern: "IK", initiator: false, s: hubKey)
        _ = try hub.readMessage(device.writeMessage())
        _ = try device.readMessage(hub.writeMessage())
        let a = try device.split()
        let b = try hub.split()
        let one = try a.seal(Data("one".utf8))
        let two = try a.seal(Data("two".utf8))
        #expect(try b.open(one) == Data("one".utf8))
        #expect(throws: HubNoiseError.decryptFailed) {
            try b.open(one)
        }
        #expect(try b.open(two) == Data("two".utf8))
    }

    @Test
    func patternNamesFollowThePskModifiers() throws {
        #expect(try HubNoisePattern.named("XXpsk0").messages[0] == [.psk, .e])
        #expect(try HubNoisePattern.named("KKpsk2").messages[1] == [.e, .ee, .se, .psk])
        #expect(throws: HubNoiseError.unknownPattern("ZZ")) {
            try HubNoisePattern.named("ZZ")
        }
    }
}
