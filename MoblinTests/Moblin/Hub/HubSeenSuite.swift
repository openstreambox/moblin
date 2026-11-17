import Foundation
@testable import Moblin
import Testing

private func state(_ seq: Int, _ devices: [String], standby: String = "current") -> [String: Any] {
    [
        "hub": [
            "access": ["seq": seq],
            "standbys": [["id": "desk", "state": standby, "access_seq": seq, "answering": true]],
        ],
        "devices": devices.map { ["id": $0, "name": $0.uppercased()] },
    ]
}

private func json(_ text: String) -> Any {
    (try? JSONSerialization.jsonObject(with: Data(text.utf8))) ?? NSNull()
}

private func welcome(_ object: [String: Any]) -> HubMessage {
    var all = object
    all["type"] = "welcome"
    return HubMessage(object: all)
}

private func hub(epoch: Int, kind: String?, host: String? = nil) -> [String: Any] {
    var hub: [String: Any] = ["epoch": epoch, "ownership": [
        "epoch": epoch,
        "chain": kind.map { [["v": 2, "epoch": epoch, "kind": $0]] } ?? [],
    ]]
    if let host {
        hub["host"] = ["id": "desk", "name": host]
    }
    return hub
}

private let when = HubWhen(now: Date(timeIntervalSince1970: 1_800_000_000))

private func iso(_ minutes: Double) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: when.now.addingTimeInterval(minutes * 60))
}

private func grant(_ id: String, _ name: String, wasIn: Bool, newOwner: Bool = false) -> String {
    """
    {"id":"\(id)","kind":"device","name":"\(name)","device_kind":"phone","role":"member","allows":[],
    "state":"waiting","online":true,"can":["allow","end"],"was_in":\(wasIn),"new_owner":\(newOwner)
    \(newOwner ? ",\"person\":{\"id\":null,\"name\":\"Robin\"}" : "")}
    """
}

private func access(_ grants: [String], trail: [String] = []) throws -> HubAccess {
    let text = """
    {"hub":"Studio hub","stream":{"live":"live","hidden":true},"grants":[\(grants.joined(separator: ","))],
    "trail":[\(trail.joined(separator: ","))]}
    """
    return try JSONDecoder().decode(HubAccess.self, from: Data(text.utf8))
}

private let takeoverLine = """
{"seq":21,"at":"\(iso(-2))","type":"hub.moved","detail":{"epoch":1000,"takeover":true,"agreed":false,"gap_ms":40000}}
"""

private func removedLine(_ name: String, minutes: Double) -> String {
    """
    {"seq":20,"at":"\(iso(-minutes))","type":"device.removed","by":{"id":"dev-desk","name":"Mac"},
    "subject":{"kind":"device","id":"dev-\(name)","name":"\(name)","role":"helper"}}
    """
}

struct HubSeenSuite {
    @Test
    func noticesRemovalsAndKeepsTheNewestReport() {
        var seen: HubSeen?
        #expect(HubSeen.note(&seen, state: state(3, ["a", "b", "c"]), now: 1000))
        #expect(HubSeen.note(&seen, state: state(4, ["a", "c"], standby: "behind"), now: 2000))
        #expect(seen?.accessSeq == 4)
        #expect(seen?.removed == [HubSeenRemoval(device: "b", name: "B", accessSeq: 4, at: 2000)])
        #expect(seen?.standbys["desk"] == HubSeenStandby(state: "behind", accessSeq: 4, answering: true))
        #expect(!HubSeen.note(&seen, state: state(4, ["a", "c"], standby: "behind"), now: 3000))
        #expect(seen?.heardAt == 3000)
        HubSeen.heard(&seen, now: 4000)
        #expect(seen?.heardAt == 4000)
        #expect(!HubSeen.note(&seen, state: ["devices": []], now: 5000))
        #expect(seen?.devices.count == 2)
    }

    @Test
    func aRemovalAskedForCountsUntilTheHubSaysOtherwise() {
        var seen: HubSeen?
        #expect(!HubSeen.askedRemoval(&seen, device: "b", now: 500))
        HubSeen.note(&seen, state: state(3, ["a", "b"]), now: 1000)
        #expect(HubSeen.askedRemoval(&seen, device: "b", now: 1500))
        #expect(seen?.removed.first?.accessSeq == nil)
        #expect(!HubSeen.askedRemoval(&seen, device: "mod-sam", now: 1500))
        HubSeen.note(&seen, state: state(4, ["a"]), now: 2000)
        #expect(seen?.removed == [HubSeenRemoval(device: "b", name: "B", accessSeq: 4, at: 1500)])
        #expect(HubSeen.askedRemoval(&seen, device: "a", now: 2500))
        HubSeen.refusedRemoval(&seen, device: "a")
        #expect(seen?.removed.count == 1)
    }

    @Test
    func removalsAreKeptADayTheNewest32() {
        var seen: HubSeen?
        let ids = (0 ..< 40).map { "d\($0)" }
        HubSeen.note(&seen, state: state(1, ids), now: 0)
        for index in 0 ..< 40 {
            HubSeen.note(&seen, state: state(2 + index, Array(ids.dropFirst(index + 1))), now: Int64(index))
        }
        #expect(seen?.removed.count == 32)
        #expect(seen?.removed.first?.device == "d8")
        HubSeen.note(&seen, state: state(50, []), now: 86_400_000 + 20)
        #expect(seen?.removed.map(\.device) == (21 ..< 40).map { "d\($0)" })
    }

    @Test
    func saysWhatItSawInTheHandshake() throws {
        #expect(NSDictionary(dictionary: HubSeen.hello(nil, now: 0)) == NSDictionary(dictionary: ["v": 1]))
        var seen: HubSeen?
        HubSeen.note(&seen, state: state(3, ["a", "b"]), now: 1000)
        HubSeen.note(&seen, state: state(4, ["a"]), now: 2000)
        HubSeen.askedRemoval(&seen, device: "a", now: 2500)
        let hello = HubSeen.hello(seen, now: 5000)
        let data = try JSONSerialization.data(withJSONObject: hello, options: [.sortedKeys])
        #expect(String(decoding: data, as: UTF8.self) == """
        {"removed":[{"access_seq":4,"ago_ms":3000,"device":"b","name":"B"},\
        {"access_seq":null,"ago_ms":2500,"device":"a","name":"A"}],"seen":{"access_seq":4},"v":1}
        """)
        let decoded = try JSONDecoder().decode(HubSeen.self, from: JSONEncoder().encode(seen))
        #expect(decoded == seen)
    }

    @Test
    func buildsTheReferenceHelloFromWhatTheHubSent() throws {
        let states = try #require(json(hubSeenStates) as? [[String: Any]])
        var seen: HubSeen?
        for (index, state) in states.enumerated() {
            HubSeen.note(&seen, state: state, now: hubSeenTimes[index])
        }
        let reference = try #require(json(hubSeenHello) as? [String: Any])
        #expect(NSDictionary(dictionary: HubSeen.hello(seen, now: hubSeenNow)) == NSDictionary(dictionary: reference))
        #expect(seen?.standbys["desk"] == HubSeenStandby(state: "behind", accessSeq: 8, answering: false))
    }

    @Test
    func dialsTheProvenAddressFirstAndTrustsOnlyItsRefusal() {
        let list = hubDialList(proven: "ws://b", join: ["ws://a", "ws://b"], hub: ["ws://b", "ws://c"],
                               standby: ["ws://d", ""])
        #expect(list == ["ws://b", "ws://a", "ws://c", "ws://d"])
        #expect(hubDialList(proven: "", join: ["ws://a"], hub: [], standby: []) == ["ws://a"])
        #expect(hubRefusalCounts("ws://b", proven: "ws://b", join: ["ws://a"]))
        #expect(!hubRefusalCounts("ws://a", proven: "ws://b", join: ["ws://a"]))
        #expect(!hubRefusalCounts("ws://d", proven: "ws://b", join: ["ws://a"]))
        #expect(hubRefusalCounts("ws://a", proven: "", join: ["ws://a"]))
        #expect(!hubRefusalCounts("ws://d", proven: "", join: ["ws://a"]))
    }

    @Test
    func stayedInOnlyAfterATakeoverThatDidNotMakeItWait() {
        let takeover = welcome(["hub": hub(epoch: 1000, kind: "takeover")])
        #expect(hubTakeoverStayed(before: 3, welcome: takeover))
        #expect(!hubTakeoverStayed(before: nil, welcome: takeover))
        #expect(!hubTakeoverStayed(before: 1000, welcome: takeover))
        var pending = takeover.object
        pending["pending"] = true
        #expect(!hubTakeoverStayed(before: 3, welcome: HubMessage(object: pending)))
        #expect(!hubTakeoverStayed(before: 3, welcome: welcome(["hub": hub(epoch: 4, kind: "transfer")])))
        #expect(!hubTakeoverStayed(before: 3, welcome: welcome(["hub": hub(epoch: 4, kind: nil)])))
        let text = welcome(["hub": ["epoch": 1000, "ownership": ["chain": [#"{"v":2,"kind":"takeover"}"#]]]])
        #expect(hubTakeoverStayed(before: 3, welcome: text))
    }

    @Test
    func theCalmLineNamesTheHostWhenTheHubDoes() {
        let named = welcome(["hub": hub(epoch: 1000, kind: "takeover"),
                             "state": ["hub": hub(epoch: 1000, kind: "takeover", host: "Desk PC")]])
        #expect(hubTakeoverStayedLine(named) == "Your hub now runs on Desk PC. This device is still in.")
        #expect(hubTakeoverStayedLine(welcome(["hub": hub(epoch: 1000, kind: "takeover")]))
            == "Your hub now runs on another computer. This device is still in.")
    }

    @Test
    func aDeviceThatWaitsAfterATakeoverSaysWhy() {
        let waiting = hubStatus(state: nil, me: "me", connected: true, pending: true, recheck: true)
        #expect(waiting.title == "Waiting for Allow")
        #expect(waiting.line == "An owner started the hub somewhere else. They have to allow this device again.")
        let joined = hubStatus(state: nil, me: "me", connected: true, pending: true)
        #expect(joined.line == HubWords.Setup.waitingLine)
        var status = HubStatus(kind: .live, title: "LIVE", line: "Viewers see this phone.")
        status.note = HubWords.Takeover.stayed("Desk PC")
        #expect(status.spoken.hasPrefix("LIVE. Viewers see this phone."))
        #expect(status.spoken.hasSuffix("Your hub now runs on Desk PC. This device is still in."))
        #expect(status.text == "LIVE")
    }

    @Test
    func agesAndGapsInTheDesktopsWords() {
        #expect(HubWords.Takeover.age(4000) == "a moment")
        #expect(HubWords.Takeover.age(40000) == "40 seconds")
        #expect(HubWords.Takeover.age(180_000) == "3 minutes")
        #expect(HubWords.Takeover.age(3 * 3_600_000) == "3 hours")
        #expect(HubWords.Takeover.age(72 * 3_600_000) == "3 days")
        #expect(HubWords.Takeover.gapLine(nil) == "Some changes may be missing from it.")
        #expect(HubWords.Takeover.gapLine(2000)
            == "Changes from the last few seconds before your hub went silent may be missing from it.")
        #expect(HubWords.Takeover.gapLine(40000)
            == "Changes from up to 40 seconds before your hub went silent may be missing from it.")
    }

    @Test
    func allowAllForTheDevicesThatWereIn() throws {
        let list = try access([grant("dev-box", "Backpack", wasIn: true),
                               grant("dev-kim", "Kim's laptop", wasIn: true),
                               grant("dev-new", "Robin's laptop", wasIn: false)],
                              trail: [takeoverLine, removedLine("Lee's phone", minutes: 12)])
        let page = try #require(hubAccessPage(list, connected: true, when: when))
        let takeover = try #require(page.takeover)
        #expect(takeover.lines == [
            "Changes from up to 40 seconds before your hub went silent may be missing from it.",
            "Lee's phone was removed 12 minutes ago. It stays out.",
        ])
        #expect(takeover.allowAll == [HubWaitingName(id: "dev-box", name: "Backpack"),
                                      HubWaitingName(id: "dev-kim", name: "Kim's laptop")])
        #expect(page.primaryAllow == nil)
    }

    @Test
    func oneDeviceThatWasInGetsTheFirstAllow() throws {
        let list = try access([grant("dev-own", "Robin's phone", wasIn: true, newOwner: true),
                               grant("dev-box", "Backpack", wasIn: true)],
                              trail: [takeoverLine, removedLine("Old phone", minutes: 90)])
        let page = try #require(hubAccessPage(list, connected: true, when: when))
        #expect(page.takeover?.allowAll == [])
        #expect(page.takeover?.lines.last == "No device was removed in the last hour.")
        #expect(page.primaryAllow == "dev-own")
    }

    @Test
    func thisPhonesOwnRemovalsCountAndNothingWithoutATakeover() throws {
        var seen: HubSeen?
        let nowMs = Int64(when.now.timeIntervalSince1970 * 1000)
        HubSeen.note(&seen, state: state(3, ["dev-x", "a"]), now: nowMs - 300_000)
        HubSeen.note(&seen, state: state(4, ["a"]), now: nowMs - 180_000)
        let list = try access([grant("dev-box", "Backpack", wasIn: true), grant("dev-kim", "Kim", wasIn: true)])
        let page = try #require(hubAccessPage(list, connected: true, seen: seen, when: when))
        #expect(page.takeover?.lines == ["DEV-X was removed 3 minutes ago. It stays out."])
        let plain = try access([grant("dev-new", "Robin's laptop", wasIn: false)])
        let ordinary = try #require(hubAccessPage(plain, connected: true, when: when))
        #expect(ordinary.takeover == nil)
        #expect(ordinary.primaryAllow == "dev-new")
    }

    @Test
    func readsTheTakeoverLineOfTheTrail() throws {
        let list = try access([], trail: [takeoverLine])
        let detail = try #require(list.trail.first?.detail)
        #expect(detail.takeover == true)
        #expect(detail.agreed == false)
        #expect(detail.gapMs == 40000)
    }
}
