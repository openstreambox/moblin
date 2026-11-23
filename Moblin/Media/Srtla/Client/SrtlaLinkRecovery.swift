import Foundation

struct SrtlaLinkRecovery {
    private(set) var noDataStops: Int
    private var nextProbe: ContinuousClock.Instant?
    private(set) var hasDelivered = false
    private(set) var sentData = false

    init(noDataStops: Int = 0) {
        self.noDataStops = noDataStops
    }

    mutating func startSocket() {
        hasDelivered = false
        sentData = false
        nextProbe = nil
    }

    mutating func sent() {
        sentData = true
    }

    mutating func acknowledge() {
        guard sentData else {
            return
        }
        hasDelivered = true
        noDataStops = 0
    }

    mutating func takeProbe(now: ContinuousClock.Instant) -> Bool {
        guard !hasDelivered, nextProbe.map({ now >= $0 }) ?? true else {
            return false
        }
        nextProbe = now + .milliseconds(20)
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
