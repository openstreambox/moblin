import Foundation

let hubSeenRemovedKeepMs: Int64 = 86_400_000
let hubSeenRemovedMax = 32

struct HubSeenStandby: Codable, Equatable {
    var state: String
    var accessSeq: Int?
    var answering: Bool

    enum CodingKeys: String, CodingKey {
        case state
        case accessSeq = "access_seq"
        case answering
    }
}

struct HubSeenRemoval: Codable, Equatable {
    var device: String
    var name: String?
    var accessSeq: Int?
    var at: Int64

    enum CodingKeys: String, CodingKey {
        case device
        case name
        case accessSeq = "access_seq"
        case at
    }
}

struct HubSeen: Codable, Equatable {
    var setup: String?
    var accessSeq: Int
    var heardAt: Int64
    var standbys: [String: HubSeenStandby] = [:]
    var devices: [String: String] = [:]
    var removed: [HubSeenRemoval] = []

    enum CodingKeys: String, CodingKey {
        case setup
        case accessSeq = "access_seq"
        case heardAt = "heard_at"
        case standbys
        case devices
        case removed
    }
}

func hubNowMs() -> Int64 {
    Int64((Date().timeIntervalSince1970 * 1000).rounded())
}

func hubWholeNumber(_ value: Any?) -> Int? {
    guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else {
        return nil
    }
    let double = number.doubleValue
    guard double.rounded() == double, double >= 0, double < 9_007_199_254_740_992 else {
        return nil
    }
    return number.intValue
}

extension HubSeen {
    static func scoped(_ seen: HubSeen?, setup: String) -> HubSeen? {
        guard var seen, seen.setup == nil || seen.setup == setup else { return nil }
        seen.setup = setup
        return seen
    }

    @discardableResult
    static func note(_ seen: inout HubSeen?, state: [String: Any], now: Int64) -> Bool {
        let hub = state["hub"] as? [String: Any]
        guard let seq = hubWholeNumber((hub?["access"] as? [String: Any])?["seq"]),
              seen == nil || seq >= seen!.accessSeq else { return false }
        let before = seen
        var current = seen ?? HubSeen(accessSeq: seq, heardAt: now)
        var devices: [String: String] = [:]
        for device in state["devices"] as? [[String: Any]] ?? [] {
            if let id = device["id"] as? String {
                devices[id] = device["name"] as? String ?? ""
            }
        }
        for (id, name) in current.devices.sorted(by: { $0.key < $1.key }) where devices[id] == nil {
            if let asked = current.removed.firstIndex(where: { $0.device == id && $0.accessSeq == nil }) {
                current.removed[asked].accessSeq = seq
            } else {
                current.removed.append(HubSeenRemoval(device: id, name: name, accessSeq: seq, at: now))
            }
        }
        current.removed = Array(current.removed.filter { now >= $0.at && now - $0.at < hubSeenRemovedKeepMs }
            .suffix(hubSeenRemovedMax))
        current.devices = devices
        current.accessSeq = seq
        current.heardAt = now
        var standbys: [String: HubSeenStandby] = [:]
        for one in hub?["standbys"] as? [[String: Any]] ?? [] {
            if let id = one["id"] as? String, let state = one["state"] as? String {
                standbys[id] = HubSeenStandby(state: state,
                                              accessSeq: hubWholeNumber(one["access_seq"]),
                                              answering: one["answering"] as? Bool == true)
            }
        }
        current.standbys = standbys
        seen = current
        var withoutTime = current
        withoutTime.heardAt = before?.heardAt ?? 0
        return before != withoutTime
    }

    static func heard(_ seen: inout HubSeen?, now: Int64) {
        seen?.heardAt = now
    }

    @discardableResult
    static func askedRemoval(_ seen: inout HubSeen?, device: String, now: Int64) -> Bool {
        guard var current = seen, let name = current.devices[device] else {
            return false
        }
        current.removed.append(HubSeenRemoval(device: device, name: name, accessSeq: nil, at: now))
        current.removed = Array(current.removed.suffix(hubSeenRemovedMax))
        seen = current
        return true
    }

    static func refusedRemoval(_ seen: inout HubSeen?, device: String) {
        seen?.removed.removeAll { $0.device == device && $0.accessSeq == nil }
    }

    static func hello(_ seen: HubSeen?, now: Int64) -> [String: Any] {
        guard let seen else {
            return ["v": 1]
        }
        let removed: [[String: Any]] = seen.removed
            .filter { $0.at <= now && now - $0.at < hubSeenRemovedKeepMs }
            .suffix(hubSeenRemovedMax).map { removal in
                var one: [String: Any] = [
                    "device": removal.device,
                    "access_seq": removal.accessSeq.map { $0 as Any } ?? NSNull(),
                    "ago_ms": max(0, now - removal.at),
                ]
                if let name = removal.name {
                    one["name"] = name
                }
                return one
            }
        return ["v": 1, "seen": ["access_seq": seen.accessSeq], "removed": removed]
    }
}

enum HubSeenStore {
    private static var url: URL? {
        guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first
        else {
            return nil
        }
        return support.appendingPathComponent("hub-seen.json")
    }

    static func load(from source: URL? = nil, now: Int64 = hubNowMs()) -> HubSeen? {
        guard let url = source ?? url, let data = try? Data(contentsOf: url),
              var seen = try? JSONDecoder().decode(
                  HubSeen.self,
                  from: data
              ) else { return nil }
        seen.removed.removeAll { $0.at > now || now - $0.at >= hubSeenRemovedKeepMs }
        return seen
    }

    static func save(_ seen: HubSeen?, to destination: URL? = nil, now: Int64 = hubNowMs()) {
        guard var url = destination ?? url else {
            return
        }
        guard var seen else {
            try? FileManager.default.removeItem(at: url)
            return
        }
        seen.removed.removeAll { $0.at > now || now - $0.at >= hubSeenRemovedKeepMs }
        guard let data = try? JSONEncoder().encode(seen) else {
            return
        }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        do {
            try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try url.setResourceValues(values)
        } catch {
            logger.info("hub: couldn't keep what this device saw: \(error)")
        }
    }

    static func delete() {
        guard let url else {
            return
        }
        try? FileManager.default.removeItem(at: url)
    }
}

func hubDialList(proven: String, join: [String], hub: [String], standby: [String]) -> [String] {
    var seen = Set<String>()
    return ([proven] + join + hub + standby).filter { !$0.isEmpty && seen.insert($0).inserted }
}

func hubRefusalCounts(_ url: String, proven: String, join: [String]) -> Bool {
    proven.isEmpty ? join.contains(url) : url == proven
}

let hubStayedShown: TimeInterval = 120

func hubEpoch(_ welcome: HubMessage) -> Int? {
    hubWholeNumber((welcome.object["hub"] as? [String: Any])?["epoch"])
}

func hubTakeoverStayed(before: Int?, welcome: HubMessage) -> Bool {
    guard welcome.type == "welcome", welcome.bool("pending") != true,
          let before, let now = hubEpoch(welcome), now > before
    else {
        return false
    }
    let ownership = (welcome.object["hub"] as? [String: Any])?["ownership"] as? [String: Any]
    var last = (ownership?["chain"] as? [Any])?.last
    if let text = last as? String {
        last = try? JSONSerialization.jsonObject(with: Data(text.utf8))
    }
    return (last as? [String: Any])?["kind"] as? String == "takeover"
}

func hubTakeoverStayedLine(_ welcome: HubMessage) -> String {
    let state = welcome.object["state"] as? [String: Any]
    let hub = (state?["hub"] ?? welcome.object["hub"]) as? [String: Any]
    let host = (hub?["host"] as? [String: Any])?["name"] as? String ?? ""
    return host.isEmpty ? HubWords.Takeover.stayedElsewhere : HubWords.Takeover.stayed(host)
}
