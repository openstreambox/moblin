import Foundation


extension Model {
    func hubLearn(_ message: HubMessage) {
        let state = message.object["state"] as? [String: Any]
        let stateHub = state?["hub"] as? [String: Any]
        var changed = false
        if let epoch = hubEpoch(message) ?? hubWholeNumber(stateHub?["epoch"]), epoch != database.hub.epoch {
            database.hub.epoch = epoch
            changed = true
        }
        if let urls = stateHub?["urls"] as? [String], urls != database.hub.hubUrls {
            database.hub.hubUrls = urls
            changed = true
        }
        if let urls = stateHub?["standby_urls"] as? [String], urls != database.hub.standbyUrls {
            database.hub.standbyUrls = urls
            changed = true
        }
        if changed, message.type == "state" {
            storeSettings()
        }
        guard let state, database.hub.role == "admin", message.bool("pending") != true else {
            return
        }
        let now = hubNowMs()
        hubKeepSeen(changed: HubSeen.note(&hub.seen, state: state, now: now), now: now)
    }

    func hubHeard() {
        guard database.hub.role == "admin", hub.seen != nil else {
            return
        }
        let now = hubNowMs()
        HubSeen.heard(&hub.seen, now: now)
        hubKeepSeen(changed: false, now: now)
    }

    private func hubKeepSeen(changed: Bool, now: Int64) {
        guard changed || now - hub.seenSavedAt >= 5000 else {
            return
        }
        hub.seenSavedAt = now
        HubSeenStore.save(hub.seen)
    }

    func hubAskedRemoval(_ device: String) {
        guard database.hub.role == "admin",
              HubSeen.askedRemoval(&hub.seen, device: device, now: hubNowMs())
        else {
            return
        }
        hubKeepSeen(changed: true, now: hubNowMs())
    }

    func hubRefusedRemoval(_ device: String) {
        let before = hub.seen
        HubSeen.refusedRemoval(&hub.seen, device: device)
        if hub.seen != before {
            hubKeepSeen(changed: true, now: hubNowMs())
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
