import Foundation
@testable import Moblin
import Testing

struct SrtlaLinkRecoverySuite {
    @Test
    func repeatedNoDataStopsBackOffAcrossSockets() {
        var recovery = SrtlaLinkRecovery()
        for delay in [0.0, 10, 20, 40, 60, 60] {
            recovery.startSocket()
            recovery.sent(sequence: 10)
            recovery.acknowledge(sequence: 9)
            #expect(!recovery.hasDelivered)
            #expect(recovery.retryDelay() == delay)
        }
    }

    @Test
    func matchingDeliveryResetsBackoff() {
        var recovery = SrtlaLinkRecovery()
        recovery.sent(sequence: 10)
        #expect(recovery.retryDelay() == 0)
        recovery.startSocket()
        recovery.sent(sequence: 12)
        #expect(recovery.retryDelay() == 10)
        recovery.acknowledge(sequence: 12)
        #expect(recovery.hasDelivered)
        #expect(recovery.retryDelay() == 0)
        recovery.startSocket()
        recovery.acknowledge(sequence: 12)
        #expect(!recovery.hasDelivered)
        #expect(recovery.retryDelay() == 0)
        recovery.sent(sequence: 13)
        #expect(recovery.retryDelay() == 0)
    }

    @Test
    func probationProbesArePacedAndStopOnDelivery() {
        let now = ContinuousClock.now
        var recovery = SrtlaLinkRecovery()
        let initialProbe = recovery.takeProbe(now: now)
        #expect(initialProbe)
        let earlyProbe = recovery.takeProbe(now: now + .milliseconds(199))
        #expect(!earlyProbe)
        let nextProbe = recovery.takeProbe(now: now + .milliseconds(200))
        #expect(nextProbe)
        recovery.sent(sequence: 10)
        recovery.acknowledge(sequence: 10)
        let probeAfterDelivery = recovery.takeProbe(now: now + .seconds(1))
        #expect(!probeAfterDelivery)
    }
}
