import Foundation

final class HubSeenBook {
    let url: URL?
    var seen: HubSeen?
    private(set) var unreadable = false
    private(set) var setAside: URL?
    private var savedAt: Int64 = 0

    init(url: URL? = HubSeenStore.url, now: Int64 = hubNowMs(), mono: HubMono? = hubMonoNow()) {
        self.url = url
        reload(now: now, mono: mono)
    }

    func reload(now: Int64, mono: HubMono?) {
        switch HubSeenStore.read(from: url, now: now, mono: mono) {
        case .missing:
            unreadable = false
        case let .kept(kept):
            unreadable = false
            seen = HubSeen.merged(kept, seen, now: now, mono: mono)
        case .unreadable:
            unreadable = true
            logger.info("hub: what this device saw can't be read yet, keeping it")
        case .corrupt:
            setAside = url.flatMap { HubSeenStore.setAside($0) }
            unreadable = setAside == nil
            logger.info("hub: what this device saw was damaged, setting it aside")
        }
    }

    func keep(changed: Bool, now: Int64, mono: HubMono?) {
        guard changed || now - savedAt >= 5000 || now < savedAt else {
            return
        }
        if unreadable {
            reload(now: now, mono: mono)
            guard !unreadable else {
                return
            }
        }
        savedAt = now
        HubSeenStore.save(seen, to: url, now: now, mono: mono)
    }

    func forget() {
        seen = nil
        unreadable = false
        savedAt = 0
        if let url {
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(
                at: url.deletingPathExtension().appendingPathExtension("unreadable.json")
            )
        }
        setAside = nil
    }
}

struct HubLearned: Equatable {
    var settings: Bool
    var seen: Bool?
}

extension SettingsHub {
    var setup: String {
        hubKey + ":" + deviceId
    }

    func accessFloor(seen: HubSeen?) -> HubAccessFloor? {
        let kept = HubSeen.scoped(seen, setup: setup).map {
            HubAccessFloor(seq: $0.accessSeq, lineage: $0.lineage ?? ownership?.counterLineage ?? 1)
        }
        return HubAccessFloor.strongest(accessFloor, kept)
    }

    func check(_ message: HubMessage, seen: HubSeen?) throws -> HubOwnership? {
        try hubValidateEvidence(message,
                                hubKey: hubKey,
                                ownership: ownership,
                                epoch: epoch,
                                floor: accessFloor(seen: seen))
    }

    func hello(seen: HubSeen?, now: Int64, mono: HubMono?) -> [String: Any] {
        guard role == "admin" else {
            return ["v": 1]
        }
        var shown = HubSeen.scoped(seen, setup: setup)
        if let floor = accessFloor(seen: shown) {
            var known = shown ?? HubSeen(accessSeq: floor.seq, heardAt: now)
            known.accessSeq = floor.seq
            known.lineage = floor.lineage
            shown = known
        }
        return HubSeen.hello(shown, now: now, mono: mono)
    }

    func learn(_ message: HubMessage, book: HubSeenBook, now: Int64, mono: HubMono?) -> HubLearned? {
        let accepted: HubOwnership?
        do {
            accepted = try check(message, seen: book.seen)
        } catch {
            return nil
        }
        let held = ownership
        var changed = accepted != ownership
        ownership = accepted
        let state = message.object["state"] as? [String: Any]
        let stateHub = state?["hub"] as? [String: Any]
        if let next = hubEpoch(message) ?? hubWholeNumber(stateHub?["epoch"]),
           next >= (epoch ?? 0), next != epoch
        {
            epoch = next
            changed = true
        }
        if let urls = stateHub?["urls"] as? [String], urls != hubUrls {
            hubUrls = urls
            changed = true
        }
        if let urls = stateHub?["standby_urls"] as? [String], urls != standbyUrls {
            standbyUrls = urls
            changed = true
        }
        guard let state, role == "admin", message.bool("pending") != true else {
            return HubLearned(settings: changed, seen: nil)
        }
        var seen = HubSeen.scoped(book.seen, setup: setup)
        if seen != nil, seen?.lineage == nil {
            seen?.lineage = held?.counterLineage ?? 1
        }
        let noted = HubSeen.note(&seen,
                                 state: state,
                                 lineage: accepted?.counterLineage ?? 1,
                                 now: now,
                                 mono: mono)
        book.seen = HubSeen.scoped(seen, setup: setup)
        if let kept = book.seen {
            let floor = HubAccessFloor.strongest(accessFloor,
                                                 HubAccessFloor(
                                                     seq: kept.accessSeq,
                                                     lineage: kept.lineage ?? 1
                                                 ))
            if floor != accessFloor {
                accessFloor = floor
                changed = true
            }
        }
        return HubLearned(settings: changed, seen: noted)
    }
}
