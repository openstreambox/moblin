import Foundation

struct SrtlaLinkRecovery {
    private var noDataStops = 0
    private var pending: Set<UInt32> = []
    private var nextProbe: ContinuousClock.Instant?
    private(set) var hasDelivered = false
    private(set) var sentData = false

    mutating func startSocket() {
        hasDelivered = false
        sentData = false
        pending.removeAll(keepingCapacity: true)
        nextProbe = nil
    }

    mutating func sent(sequence: UInt32) {
        guard !hasDelivered else {
            return
        }
        sentData = true
        if pending.count >= 128 {
            pending.removeAll(keepingCapacity: true)
        }
        pending.insert(sequence)
    }

    mutating func acknowledge(sequence: UInt32) {
        guard pending.contains(sequence) else {
            return
        }
        hasDelivered = true
        noDataStops = 0
        pending.removeAll(keepingCapacity: true)
    }

    mutating func takeProbe(now: ContinuousClock.Instant) -> Bool {
        guard !hasDelivered, nextProbe.map({ now >= $0 }) ?? true else {
            return false
        }
        nextProbe = now + .milliseconds(200)
        return true
    }

    mutating func retryDelay() -> Double {
        guard sentData, !hasDelivered else {
            return 0
        }
        noDataStops = min(noDataStops + 1, 5)
        switch noDataStops {
        case 2: return 10
        case 3: return 20
        case 4: return 40
        case 5: return 60
        default: return 0
        }
    }
}
