import Foundation
@testable import Moblin
import Network
import Testing

struct SrtlaProbeAccountingSuite {
    @Test
    func probeAckLeavesOriginalInFlightAndRetiredSocketCannotProveReplacement() throws {
        try srtlaClientQueue.sync {
            let delegate = TestSrtlaDelegate()
            let client = SrtlaClient(
                delegate: delegate,
                passThrough: false,
                mpegtsPacketsPerPacket: 7,
                packetPadding: false,
                networkInterfaceNames: [],
                connectionPriorities: SettingsStreamSrtConnectionPriorities(),
                srtImplementation: .moblin
            )
            let primary = makeConnection()
            let fresh = makeConnection()
            let now = ContinuousClock.now
            client.addMoblink(connection: primary, host: "127.0.0.1", port: 9000, now: now)
            client.addMoblink(connection: fresh, host: "127.0.0.1", port: 9000, now: now)
            defer {
                client.removeMoblink(connection: primary)
                client.removeMoblink(connection: fresh)
            }
            let reg3 = createSrtlaPacket(type: .reg3, length: 2)
            let primarySocket = try #require(primary.connection)
            let oldSocket = try #require(fresh.connection)
            for (connection, socket) in [(primary, primarySocket), (fresh, oldSocket)] {
                connection.register(groupId: Data(count: 256))
                connection.handleStateUpdate(to: .ready)
                let registered = connection.handleReceivedMessage(packet: reg3, from: socket)
                #expect(registered)
            }

            var data = Data(count: 16)
            data.setUInt32Be(value: 42)
            var ack = createSrtlaPacket(type: .ack, length: 8)
            ack.setUInt32Be(value: 42, offset: 4)
            primary.sendSrtPacket(packet: data)
            let originalScore = primary.score()
            let probeScore = fresh.score()
            fresh.sendProbationProbe(packet: data, now: now)
            #expect(fresh.score() == probeScore)
            let admittedOldSocket = fresh.handleReceivedMessage(packet: ack, from: oldSocket)
            #expect(admittedOldSocket)
            #expect(fresh.hasDeliveredData)
            #expect(primary.score() == originalScore)

            fresh.stop(reason: "replace test socket")
            fresh.start(host: "127.0.0.1", port: 9000)
            let replacement = try #require(fresh.connection)
            fresh.handleStateUpdate(to: .ready)
            let registeredReplacement = fresh.handleReceivedMessage(packet: reg3, from: replacement)
            #expect(registeredReplacement)
            fresh.sendProbationProbe(packet: data, now: now)
            let acceptedRetiredAck = fresh.handleReceivedMessage(packet: ack, from: oldSocket)
            #expect(!acceptedRetiredAck)
            #expect(!fresh.hasDeliveredData)
            let acceptedCurrentAck = fresh.handleReceivedMessage(packet: ack, from: replacement)
            #expect(acceptedCurrentAck)
            #expect(fresh.hasDeliveredData)
            #expect(primary.score() == originalScore)

            data.setUInt32Be(value: 43)
            let idleScore = fresh.score()
            fresh.sendSrtPacket(packet: data)
            #expect(fresh.score() < idleScore)
            var cumulativeAck = Data(count: 20)
            cumulativeAck.setUInt16Be(value: SrtPacketType.ack.rawValue | srtControlPacketTypeBit)
            cumulativeAck.setUInt32Be(value: 44, offset: 16)
            let acceptedCumulativeAck = fresh.handleReceivedMessage(packet: cumulativeAck, from: replacement)
            #expect(acceptedCumulativeAck)
            #expect(fresh.score() == idleScore)

            let acceptedDuplicateProbeAck = fresh.handleReceivedMessage(packet: ack, from: replacement)
            #expect(acceptedDuplicateProbeAck)
            #expect(fresh.score() == idleScore)
            ack.setUInt32Be(value: 43, offset: 4)
            let acceptedOriginalAck = fresh.handleReceivedMessage(packet: ack, from: replacement)
            #expect(acceptedOriginalAck)
            #expect(fresh.score() == idleScore + 1)
        }
    }

    private func makeConnection() -> RemoteConnection {
        RemoteConnection(
            type: .wifi,
            mpegtsPacketsPerPacket: 7,
            packetPadding: false,
            interface: nil,
            networkInterfaces: SrtlaNetworkInterfaces(),
            priority: 1.0
        )
    }
}
