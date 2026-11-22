import Foundation
@testable import Moblin
import Network
import Testing

private final class TestSrtlaConnection: RemoteConnection, @unchecked Sendable {
    var delivery = false
    var rank = 1
    var sent = 0

    override var hasDeliveredData: Bool {
        delivery
    }

    override func score() -> Int {
        rank
    }

    override func sendSrtPacket(packet _: Data) {
        sent += 1
    }
}

private final class TestSrtlaSocket: RemoteConnection, @unchecked Sendable {
    var starts = 0

    override func startInternal() {
        starts += 1
    }
}

private final class TestSrtlaTimer: SrtlaConnectTimer {
    var timeout: Double?
    var handler: (@Sendable () -> Void)?

    func startSingleShot(timeout: Double, handler: @escaping @Sendable () -> Void) {
        self.timeout = timeout
        self.handler = handler
    }

    func stop() {
        timeout = nil
        handler = nil
    }
}

private final class TestSrtlaDelegate: SrtlaDelegate {
    var restartedRelays: [UUID] = []

    func srtlaReady(port _: UInt16) {}
    func srtlaError(message _: String) {}
    func srtlaReceivedPacket(packet _: Data) {}
    func moblinkStreamerDestinationAddress(address _: String, port _: UInt16) {}
    func moblinkStreamerRestartTunnel(relayId: UUID) {
        restartedRelays.append(relayId)
    }
}

struct SrtlaLinkRecoverySuite {
    @Test
    func repeatedNoDataStopsBackOffAcrossSockets() {
        var recovery = SrtlaLinkRecovery()
        for delay in [0.0, 10, 20, 40, 60, 60] {
            recovery.startSocket()
            recovery.acknowledge()
            #expect(!recovery.hasDelivered)
            recovery.sent()
            let actualDelay = recovery.retryDelay()
            #expect(actualDelay == delay)
        }
    }

    @Test
    func deliveryResetsBackoffAndProbeBudget() {
        var recovery = SrtlaLinkRecovery(noDataStops: 2)
        recovery.sent()
        recovery.acknowledge()
        #expect(recovery.hasDelivered)
        let probe = recovery.takeProbe(now: .now)
        #expect(!probe)
        recovery.startSocket()
        recovery.acknowledge()
        #expect(!recovery.hasDelivered)
        recovery.sent()
        let delay = recovery.retryDelay()
        #expect(delay == 0)
    }

    @Test
    func selectsDeliveringLinkAndPacesProbesUntilItDisappears() {
        let proven = makeConnection()
        proven.delivery = true
        let fresh = makeConnection()
        fresh.rank = 100
        let disabled = makeConnection()
        disabled.rank = -1
        let now = ContinuousClock.now
        let packet = Data(count: 16)
        for offset in [0, 19, 20] {
            let routed = SrtlaClient.routeLocalPacket(
                packet: packet,
                now: now + .milliseconds(offset),
                connections: [fresh, proven, disabled]
            )
            #expect(routed)
        }
        #expect(proven.sent == 3)
        #expect(fresh.sent == 2)
        #expect(disabled.sent == 0)
        let control = createSrtlaPacket(type: .keepalive, length: 10)
        let routed = SrtlaClient.routeLocalPacket(
            packet: control,
            now: now + .milliseconds(40),
            connections: [fresh, proven]
        )
        #expect(routed)
        #expect(proven.sent == 4)
        #expect(fresh.sent == 2)
        proven.rank = -1
        let sibling = makeConnection()
        let routedAfterFailover = SrtlaClient.routeLocalPacket(
            packet: packet,
            now: now + .milliseconds(40),
            connections: [fresh, sibling, proven]
        )
        #expect(routedAfterFailover)
        #expect(fresh.sent == 3)
        #expect(sibling.sent == 0)
    }

    @Test
    func reconnectTimerFiresOrResumesWhenTheDeliveringLinkDisappears() {
        let timer = TestSrtlaTimer()
        let link = makeSocket(timer: timer)
        let packet = Data(count: 16)
        let timeout = ContinuousClock.now + .seconds(6)
        link.start(host: "localhost", port: 9000)
        link.sendSrtPacket(packet: packet)
        link.handleKeepalive(now: timeout)
        #expect(link.starts == 2)
        link.sendSrtPacket(packet: packet)
        link.handleKeepalive(now: timeout + .seconds(6))
        #expect(link.waitingToReconnect)
        #expect(timer.timeout == 10)
        timer.handler?()
        #expect(!link.waitingToReconnect)
        #expect(timer.handler == nil)
        #expect(link.starts == 3)

        let proven = makeConnection()
        proven.delivery = true
        link.sendSrtPacket(packet: packet)
        link.handleKeepalive(now: timeout + .seconds(22))
        let routedWithProvenLink = SrtlaClient.routeLocalPacket(
            packet: packet,
            now: .now,
            connections: [link, proven]
        )
        #expect(routedWithProvenLink)
        #expect(link.waitingToReconnect)
        #expect(timer.timeout == 20)
        proven.rank = -1
        let routedWithoutProvenLink = SrtlaClient.routeLocalPacket(
            packet: packet,
            now: .now,
            connections: [link, proven]
        )
        #expect(!routedWithoutProvenLink)
        #expect(!link.waitingToReconnect)
        #expect(timer.handler == nil)
        #expect(link.starts == 4)
    }

    @Test
    func replacingMoblinkTunnelPreservesPendingDeadlineAndStreak() {
        srtlaClientQueue.sync {
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
            let relayId = UUID()
            let now = ContinuousClock.now
            let packet = Data(count: 16)
            let timer = TestSrtlaTimer()
            let first = makeSocket(timer: timer, relayId: relayId)
            client.addMoblink(connection: first, host: "localhost", port: 9000, now: now)
            first.sendSrtPacket(packet: packet)
            first.handleKeepalive(now: now + .seconds(6))
            #expect(!first.waitingToReconnect)
            #expect(delegate.restartedRelays == [relayId])
            client.removeMoblink(connection: first)

            let second = makeSocket(timer: timer, relayId: relayId)
            client.addMoblink(connection: second, host: "localhost", port: 9001, now: now + .seconds(6))
            #expect(second.starts == 1)
            second.sendSrtPacket(packet: packet)
            second.handleKeepalive(now: now + .seconds(12))
            #expect(second.waitingToReconnect)
            #expect(timer.timeout == 10)
            client.removeMoblink(connection: second)
            #expect(timer.handler == nil)

            let third = makeSocket(timer: timer, relayId: relayId)
            client.addMoblink(connection: third, host: "localhost", port: 9002, now: now + .seconds(15))
            #expect(third.starts == 0)
            #expect(third.waitingToReconnect)
            #expect(timer.timeout == 7)
            client.removeMoblink(connection: third)

            let fourth = makeSocket(timer: timer, relayId: relayId)
            client.addMoblink(connection: fourth, host: "localhost", port: 9003, now: now + .seconds(20))
            #expect(fourth.starts == 0)
            #expect(timer.timeout == 2)
            timer.handler?()
            #expect(fourth.starts == 1)
            fourth.sendSrtPacket(packet: packet)
            fourth.handleKeepalive(now: now + .seconds(28))
            #expect(timer.timeout == 20)
            client.removeMoblink(connection: fourth)

            let fifth = makeSocket(timer: timer, relayId: relayId)
            client.addMoblink(connection: fifth, host: "localhost", port: 9004, now: now + .seconds(30))
            #expect(timer.timeout == 18)
            let routed = SrtlaClient.routeLocalPacket(
                packet: packet,
                now: now + .seconds(31),
                connections: [fifth]
            )
            #expect(!routed)
            #expect(fifth.starts == 1)
            #expect(timer.handler == nil)
            #expect(delegate.restartedRelays == [relayId])
            client.removeMoblink(connection: fifth)
        }
    }

    private func makeSocket(timer: TestSrtlaTimer, relayId: UUID? = nil) -> TestSrtlaSocket {
        TestSrtlaSocket(
            type: .wifi,
            mpegtsPacketsPerPacket: 7,
            packetPadding: false,
            interface: nil,
            networkInterfaces: SrtlaNetworkInterfaces(),
            priority: 1.0,
            relayId: relayId,
            connectTimer: timer
        )
    }

    private func makeConnection() -> TestSrtlaConnection {
        TestSrtlaConnection(
            type: .wifi,
            mpegtsPacketsPerPacket: 7,
            packetPadding: false,
            interface: nil,
            networkInterfaces: SrtlaNetworkInterfaces(),
            priority: 1.0
        )
    }
}
