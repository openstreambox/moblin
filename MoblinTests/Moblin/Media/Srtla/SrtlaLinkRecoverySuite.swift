import Foundation
@testable import Moblin
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

struct SrtlaLinkRecoverySuite {
    @Test
    func repeatedNoDataStopsBackOffAcrossSockets() {
        var recovery = SrtlaLinkRecovery()
        for delay in [0.0, 10, 20, 40, 60, 60] {
            recovery.startSocket()
            recovery.acknowledge()
            #expect(!recovery.hasDelivered)
            recovery.sent()
            #expect(recovery.retryDelay() == delay)
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
        #expect(recovery.retryDelay() == 0)
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
            #expect(SrtlaClient.routeLocalPacket(
                packet: packet,
                now: now + .milliseconds(offset),
                connections: [fresh, proven, disabled]
            ))
        }
        #expect(proven.sent == 3)
        #expect(fresh.sent == 2)
        #expect(disabled.sent == 0)
        proven.rank = -1
        #expect(SrtlaClient.routeLocalPacket(packet: packet, now: now, connections: [fresh, proven]))
        #expect(fresh.sent == 3)
    }

    @Test
    func reconnectTimerFiresOrResumesWhenTheDeliveringLinkDisappears() {
        let timer = TestSrtlaTimer()
        let link = makeConnection(timer: timer)
        link.rank = -1
        link.reconnect(reason: "test", delay: 10)
        #expect(link.waitingToReconnect)
        #expect(timer.timeout == 10)
        timer.handler?()
        #expect(!link.waitingToReconnect)
        #expect(timer.handler == nil)

        let proven = makeConnection()
        proven.delivery = true
        link.reconnect(reason: "test", delay: 20)
        let packet = Data(count: 16)
        #expect(SrtlaClient.routeLocalPacket(packet: packet, now: .now, connections: [link, proven]))
        #expect(link.waitingToReconnect)
        #expect(timer.timeout == 20)
        proven.rank = -1
        #expect(!SrtlaClient.routeLocalPacket(packet: packet, now: .now, connections: [link, proven]))
        #expect(!link.waitingToReconnect)
        #expect(timer.handler == nil)
    }

    private func makeConnection(timer: TestSrtlaTimer = TestSrtlaTimer()) -> TestSrtlaConnection {
        TestSrtlaConnection(
            type: .wifi,
            mpegtsPacketsPerPacket: 7,
            packetPadding: false,
            interface: nil,
            networkInterfaces: SrtlaNetworkInterfaces(),
            priority: 1.0,
            connectTimer: timer
        )
    }
}
