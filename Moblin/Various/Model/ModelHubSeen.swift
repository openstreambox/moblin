import Foundation

extension Model {
    func hubLearn(_ message: HubMessage) {
        let now = hubNowMs()
        let mono = hubMonoNow()
        guard let learned = database.hub.learn(message, book: hub.seenBook, now: now, mono: mono) else {
            return
        }
        if learned.settings, message.type == "state" {
            storeSettings()
        }
        if let noted = learned.seen {
            hub.seenBook.keep(changed: noted, now: now, mono: mono)
        }
    }

    func hubHeard() {
        guard database.hub.role == "admin", hub.seen != nil else {
            return
        }
        let now = hubNowMs()
        HubSeen.heard(&hub.seen, now: now)
        hub.seenBook.keep(changed: false, now: now, mono: hubMonoNow())
    }

    func hubAskedRemoval(_ device: String) {
        let now = hubNowMs()
        let mono = hubMonoNow()
        guard database.hub.role == "admin",
              HubSeen.askedRemoval(&hub.seen, device: device, now: now, mono: mono)
        else {
            return
        }
        hub.seenBook.keep(changed: true, now: now, mono: mono)
    }

    func hubRefusedRemoval(_ device: String) {
        let before = hub.seen
        HubSeen.refusedRemoval(&hub.seen, device: device)
        if hub.seen != before {
            hub.seenBook.keep(changed: true, now: hubNowMs(), mono: hubMonoNow())
        }
    }

    func hubShowStayed(_ line: String) {
        hub.stayedLine = line
        hub.stayedTimer?.cancel()
        hub.stayedTimer = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(hubStayedShown * 1_000_000_000))
            guard !Task.isCancelled else {
                return
            }
            hub.stayedLine = nil
        }
    }

    func hubClearStayed() {
        hub.stayedTimer?.cancel()
        hub.stayedTimer = nil
        hub.stayedLine = nil
    }
}
