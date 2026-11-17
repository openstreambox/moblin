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

struct HubMono: Codable, Equatable {
    var boot: String
    var ms: Int64
}

struct HubSeenRemoval: Codable, Equatable {
    var device: String
    var name: String?
    var accessSeq: Int?
    var at: Int64
    var mono: HubMono?

    enum CodingKeys: String, CodingKey {
        case device
        case name
        case accessSeq = "access_seq"
        case at
        case mono
    }
}

struct HubSeen: Codable, Equatable {
    var setup: String?
    var accessSeq: Int
    var heardAt: Int64
    var standbys: [String: HubSeenStandby] = [:]
    var devices: [String: String] = [:]
    var removed: [HubSeenRemoval] = []
    var lineage: Int?

    enum CodingKeys: String, CodingKey {
        case setup
        case accessSeq = "access_seq"
        case heardAt = "heard_at"
        case standbys
        case devices
        case removed
        case lineage
    }
}

func hubNowMs() -> Int64 {
    Int64((Date().timeIntervalSince1970 * 1000).rounded())
}

func hubMonoNow() -> HubMono? {
    var size = 0
    guard sysctlbyname("kern.bootsessionuuid", nil, &size, nil, 0) == 0, size > 1 else {
        return nil
    }
    var bytes = [UInt8](repeating: 0, count: size)
    guard sysctlbyname("kern.bootsessionuuid", &bytes, &size, nil, 0) == 0 else {
        return nil
    }
    let boot = String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
    guard !boot.isEmpty else {
        return nil
    }
    return HubMono(boot: boot, ms: Int64(clock_gettime_nsec_np(CLOCK_MONOTONIC) / 1_000_000))
}

func hubRemovalAge(_ removal: HubSeenRemoval, now: Int64, mono: HubMono?) -> Int64? {
    if let then = removal.mono, let mono, then.boot == mono.boot, mono.ms >= then.ms {
        return mono.ms - then.ms
    }
    let ago = now - removal.at
    if ago >= 0 {
        return ago
    }
    return -ago < hubSeenRemovedKeepMs ? 0 : nil
}

func hubRemovalKept(_ removal: HubSeenRemoval, now: Int64, mono: HubMono?) -> Bool {
    guard let age = hubRemovalAge(removal, now: now, mono: mono) else {
        return false
    }
    return age < hubSeenRemovedKeepMs
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
    static func note(_ seen: inout HubSeen?,
                     state: [String: Any],
                     lineage: Int = 1,
                     now: Int64,
                     mono: HubMono? = nil) -> Bool
    {
        let hub = state["hub"] as? [String: Any]
        guard let seq = hubWholeNumber((hub?["access"] as? [String: Any])?["seq"]) else {
            return false
        }
        let rebase = seen.map { lineage > ($0.lineage ?? lineage) } ?? false
        guard seen == nil || rebase || seq >= seen!.accessSeq else {
            return false
        }
        let before = seen
        var current = seen ?? HubSeen(accessSeq: seq, heardAt: now)
        var devices: [String: String] = [:]
        for device in state["devices"] as? [[String: Any]] ?? [] {
            if let id = device["id"] as? String {
                devices[id] = device["name"] as? String ?? ""
            }
        }
        for (id, name) in current.devices.sorted(by: { $0.key < $1.key })
            where !rebase && devices[id] == nil
        {
            if let asked = current.removed.firstIndex(where: { $0.device == id && $0.accessSeq == nil }) {
                current.removed[asked].accessSeq = seq
            } else {
                current.removed.append(HubSeenRemoval(
                    device: id,
                    name: name,
                    accessSeq: seq,
                    at: now,
                    mono: mono
                ))
            }
        }
        current.removed = Array(current.removed.filter { hubRemovalKept($0, now: now, mono: mono) }
            .suffix(hubSeenRemovedMax))
        current.devices = devices
        current.accessSeq = seq
        current.lineage = lineage
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
    static func askedRemoval(_ seen: inout HubSeen?, device: String, now: Int64,
                             mono: HubMono? = nil) -> Bool
    {
        guard var current = seen, let name = current.devices[device] else {
            return false
        }
        current.removed.append(HubSeenRemoval(
            device: device,
            name: name,
            accessSeq: nil,
            at: now,
            mono: mono
        ))
        current.removed = Array(current.removed.suffix(hubSeenRemovedMax))
        seen = current
        return true
    }

    static func refusedRemoval(_ seen: inout HubSeen?, device: String) {
        seen?.removed.removeAll { $0.device == device && $0.accessSeq == nil }
    }

    static func hello(_ seen: HubSeen?, now: Int64, mono: HubMono? = nil) -> [String: Any] {
        guard let seen else {
            return ["v": 1]
        }
        let removed: [[String: Any]] = seen.removed
            .filter { hubRemovalKept($0, now: now, mono: mono) }
            .suffix(hubSeenRemovedMax).map { removal in
                var one: [String: Any] = [
                    "device": removal.device,
                    "access_seq": removal.accessSeq.map { $0 as Any } ?? NSNull(),
                    "ago_ms": hubRemovalAge(removal, now: now, mono: mono) ?? 0,
                ]
                if let name = removal.name {
                    one["name"] = name
                }
                return one
            }
        return ["v": 1, "seen": ["access_seq": seen.accessSeq], "removed": removed]
    }

    static func merged(_ kept: HubSeen, _ memory: HubSeen?, now: Int64, mono: HubMono?) -> HubSeen {
        guard let memory else {
            return kept
        }
        if let one = kept.setup, let other = memory.setup, one != other {
            return memory
        }
        let memoryNewer = (memory.lineage ?? 1, memory.accessSeq) >= (kept.lineage ?? 1, kept.accessSeq)
        var out = memoryNewer ? memory : kept
        let other = memoryNewer ? kept : memory
        out.setup = out.setup ?? other.setup
        for removal in other.removed where !out.removed.contains(where: {
            $0.device == removal.device && $0.accessSeq == removal.accessSeq
        }) {
            out.removed.append(removal)
        }
        if memoryNewer, (kept.lineage ?? 1) == (out.lineage ?? 1) {
            for (id, name) in kept.devices.sorted(by: { $0.key < $1.key }) where out.devices[id] == nil {
                if let asked = out.removed.firstIndex(where: { $0.device == id && $0.accessSeq == nil }) {
                    out.removed[asked].accessSeq = out.accessSeq
                } else if !out.removed.contains(where: { $0.device == id && $0.accessSeq == out.accessSeq }) {
                    out.removed.append(HubSeenRemoval(
                        device: id,
                        name: name,
                        accessSeq: out.accessSeq,
                        at: now,
                        mono: mono
                    ))
                }
            }
        }
        out.removed = Array(out.removed.sorted { $0.at < $1.at }.suffix(hubSeenRemovedMax))
        return out
    }
}

enum HubSeenFile: Equatable {
    case missing
    case kept(HubSeen)
    case unreadable
    case corrupt
}

enum HubSeenStore {
    static var url: URL? {
        guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first
        else {
            return nil
        }
        return support.appendingPathComponent("hub-seen.json")
    }

    static func read(from source: URL?, now: Int64, mono: HubMono?) -> HubSeenFile {
        guard let url = source, FileManager.default.fileExists(atPath: url.path) else {
            return .missing
        }
        guard let data = try? Data(contentsOf: url) else {
            return .unreadable
        }
        guard var seen = try? JSONDecoder().decode(HubSeen.self, from: data) else {
            return .corrupt
        }
        seen.removed.removeAll { !hubRemovalKept($0, now: now, mono: mono) }
        return .kept(seen)
    }

    static func setAside(_ source: URL) -> URL? {
        let aside = source.deletingPathExtension().appendingPathExtension("unreadable.json")
        try? FileManager.default.removeItem(at: aside)
        guard (try? FileManager.default.moveItem(at: source, to: aside)) != nil else {
            return nil
        }
        return aside
    }

    static func save(
        _ seen: HubSeen?,
        to destination: URL? = nil,
        now: Int64 = hubNowMs(),
        mono: HubMono? = nil
    ) {
        guard var url = destination ?? url else {
            return
        }
        guard var seen else {
            try? FileManager.default.removeItem(at: url)
            return
        }
        seen.removed.removeAll { !hubRemovalKept($0, now: now, mono: mono) }
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
