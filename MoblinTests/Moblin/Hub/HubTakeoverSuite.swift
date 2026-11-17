import Foundation
@testable import Moblin
import Testing

private struct Takeover {
    let fixture: [String: Any]

    init() throws {
        fixture = try JSONSerialization.jsonObject(with: Data(hubTakeoverTranscript.utf8)) as! [String: Any]
    }

    var hubKey: String {
        fixture["hubKey"] as! String
    }

    func number(_ key: String) -> Int {
        fixture[key] as! Int
    }

    func devices(_ key: String) -> [[String: Any]] {
        if key == "before" {
            return (fixture["before"] as! [String: Any])["devices"] as! [[String: Any]]
        }
        return fixture[key] as! [[String: Any]]
    }

    func view(_ name: String, seq: Int?) -> [String: Any] {
        var hub = (fixture["hubs"] as! [String: Any])[name] as! [String: Any]
        if let seq {
            hub["access"] = ["seq": seq]
        }
        return hub
    }

    func welcome(_ name: String, seq: Int?, devices: [[String: Any]] = [],
                 pending: Bool = false) -> HubMessage
    {
        var object: [String: Any] = [
            "type": "welcome",
            "device": ["id": "dev-phone-b", "role": "admin"],
            "hub": view(name, seq: seq),
        ]
        if pending {
            object["pending"] = true
        } else {
            object["state"] = ["hub": view(name, seq: seq), "devices": devices]
        }
        return HubMessage(object: object)
    }

    func state(_ name: String, seq: Int, devices: [[String: Any]]) -> HubMessage {
        HubMessage(object: ["type": "state", "state": ["hub": view(name, seq: seq), "devices": devices]])
    }
}

private final class Phone {
    let file: URL
    var settings = SettingsHub()
    var book: HubSeenBook
    var now: Int64 = 1_000_000
    var mono = HubMono(boot: "boot-a", ms: 50000)

    init(_ takeover: Takeover) {
        file = FileManager.default.temporaryDirectory
            .appendingPathComponent("hub-seen-\(UUID().uuidString).json")
        settings.hubKey = takeover.hubKey
        settings.deviceId = "dev-phone-b"
        settings.role = "admin"
        book = HubSeenBook(url: file, now: now, mono: mono)
    }

    deinit {
        try? FileManager.default.removeItem(at: file)
        try? FileManager.default
            .removeItem(at: file.deletingPathExtension().appendingPathExtension("unreadable.json"))
    }

    func tick(_ ms: Int64 = 1000) {
        now += ms
        mono.ms += ms
    }

    @discardableResult
    func receive(_ message: HubMessage) -> Bool {
        tick()
        guard (try? settings.check(message, seen: book.seen)) != nil,
              let learned = settings.learn(message, book: book, now: now, mono: mono)
        else {
            return false
        }
        if let noted = learned.seen {
            book.keep(changed: noted, now: now, mono: mono)
        }
        return true
    }

    func accepts(_ message: HubMessage) -> Bool {
        (try? settings.check(message, seen: book.seen)) != nil
    }

    func restart() throws {
        settings = try JSONDecoder().decode(SettingsHub.self, from: JSONEncoder().encode(settings))
        tick(60000)
        book = HubSeenBook(url: file, now: now, mono: mono)
        book.seen = HubSeen.scoped(book.seen, setup: settings.setup)
    }

    var helloSeq: Int? {
        (settings
            .hello(seen: book.seen, now: now, mono: mono)["seen"] as? [String: Any])?["access_seq"] as? Int
    }

    var helloRemoved: [String] {
        (settings.hello(seen: book.seen, now: now, mono: mono)["removed"] as? [[String: Any]] ?? [])
            .compactMap { $0["device"] as? String }
    }
}

private func sawFifty(_ takeover: Takeover) throws -> Phone {
    let phone = Phone(takeover)
    #expect(phone.receive(takeover.welcome("h3", seq: 50, devices: takeover.devices("before"))))
    #expect(phone.settings.accessFloor == HubAccessFloor(seq: 50, lineage: 1))
    try phone.restart()
    #expect(phone.helloSeq == 50)
    return phone
}

struct HubTakeoverSuite {
    @Test
    func unwitnessedAgreedTakeoverIsAcceptedAndRebasesTheCounter() throws {
        let takeover = try Takeover()
        let phone = try sawFifty(takeover)
        let seq = takeover.number("agreedSeq")
        #expect(seq < 50)
        #expect(phone.receive(takeover.welcome(
            "h1000",
            seq: seq,
            devices: takeover.devices("agreedDevices")
        )))
        #expect(phone.settings.epoch == 1000)
        #expect(phone.settings.accessFloor == HubAccessFloor(seq: seq, lineage: 1000))
        #expect(phone.book.seen?.removed.isEmpty == true)
        try phone.restart()
        #expect(phone.helloSeq == seq)
        #expect(phone.helloRemoved.isEmpty)
        #expect(!phone.accepts(takeover.state(
            "h1000",
            seq: seq - 1,
            devices: takeover.devices("agreedDevices")
        )))
        #expect(phone.receive(takeover.state(
            "h1000",
            seq: seq + 1,
            devices: takeover.devices("agreedDevices")
        )))
        try phone.restart()
        #expect(phone.helloSeq == seq + 1)
    }

    @Test
    func waitingTakeoverStaysConnectedThroughAllowAndRestart() throws {
        let takeover = try Takeover()
        let phone = try sawFifty(takeover)
        let seq = takeover.number("waitingSeq")
        #expect(phone.receive(takeover.welcome("h1000", seq: seq, pending: true)))
        #expect(phone.settings.epoch == 1000)
        #expect(phone.settings.accessFloor == HubAccessFloor(seq: 50, lineage: 1))
        try phone.restart()
        #expect(phone.helloSeq == 50)
        #expect(phone.receive(takeover.welcome("h1000", seq: seq, pending: true)))
        var devices = takeover.devices("waitingDevices")
        devices.append(["id": "dev-phone-b", "name": "Phone B"])
        #expect(phone.receive(takeover.welcome("h1000", seq: seq + 1, devices: devices)))
        #expect(phone.settings.accessFloor == HubAccessFloor(seq: seq + 1, lineage: 1000))
        #expect(phone.book.seen?.removed.isEmpty == true)
        try phone.restart()
        #expect(phone.helloSeq == seq + 1)
        #expect(phone.helloRemoved.isEmpty)
        #expect(phone.accepts(takeover.welcome("h1000", seq: seq + 1, devices: devices)))
        #expect(!phone.accepts(takeover.welcome("h1000", seq: seq, devices: devices)))
    }

    @Test
    func staleHostAtTheSameEpochIsRejectedEvenWhenWaiting() throws {
        let takeover = try Takeover()
        let phone = try sawFifty(takeover)
        #expect(!phone.accepts(takeover.welcome("h3", seq: 40, devices: takeover.devices("before"))))
        #expect(!phone.accepts(takeover.welcome("h3", seq: 40, pending: true)))
        #expect(!phone.accepts(takeover.welcome("h3", seq: nil, pending: true)))
        #expect(phone.accepts(takeover.welcome("h3", seq: 50, pending: true)))
        #expect(phone.accepts(takeover.welcome("h3", seq: 51, devices: takeover.devices("before"))))
    }

    @Test
    func plannedMovesKeepTheCounterLineage() throws {
        let takeover = try Takeover()
        let phone = try sawFifty(takeover)
        #expect(!phone.accepts(takeover.welcome("h4", seq: 40, devices: takeover.devices("before"))))
        #expect(phone.accepts(takeover.welcome("h4", seq: 50, devices: takeover.devices("before"))))
        let seq = takeover.number("agreedSeq")
        #expect(phone.receive(takeover.welcome(
            "h1000",
            seq: seq + 1,
            devices: takeover.devices("agreedDevices")
        )))
        try phone.restart()
        for name in ["h1001", "h1001base"] {
            #expect(!phone.accepts(takeover.welcome(
                name,
                seq: seq,
                devices: takeover.devices("agreedDevices")
            )))
            #expect(phone.accepts(takeover.welcome(
                name,
                seq: seq + 1,
                devices: takeover.devices("agreedDevices")
            )))
        }
        #expect(!phone.accepts(takeover.welcome("h3", seq: 60, devices: takeover.devices("before"))))
    }

    @Test
    func forgedOrForkedChainsNeverRebaseTheCounter() throws {
        let takeover = try Takeover()
        let phone = try sawFifty(takeover)
        let seq = takeover.number("agreedSeq")
        #expect(!phone.accepts(takeover.welcome(
            "tampered",
            seq: seq,
            devices: takeover.devices("agreedDevices")
        )))
        #expect(!phone.accepts(takeover.welcome(
            "forkedTransfer",
            seq: 60,
            devices: takeover.devices("before")
        )))
        #expect(phone.settings.accessFloor == HubAccessFloor(seq: 50, lineage: 1))
        #expect(phone.receive(takeover.welcome(
            "h1000",
            seq: seq,
            devices: takeover.devices("agreedDevices")
        )))
        #expect(!phone.accepts(takeover.welcome(
            "forkedTakeover",
            seq: 99,
            devices: takeover.devices("agreedDevices")
        )))
    }

    @Test
    func historyHiddenBehindANewerBaseIsTakenAsANewLineage() throws {
        let takeover = try Takeover()
        let phone = try sawFifty(takeover)
        let seq = takeover.number("agreedSeq")
        #expect(phone.receive(takeover.welcome(
            "h1001base",
            seq: seq,
            devices: takeover.devices("agreedDevices")
        )))
        #expect(phone.settings.accessFloor == HubAccessFloor(seq: seq, lineage: 1000))
        #expect(!phone.accepts(takeover.welcome(
            "h1001base",
            seq: seq - 1,
            devices: takeover.devices("agreedDevices")
        )))
    }

    @Test
    func newSetupStartsWithoutTheOldEvidence() throws {
        let takeover = try Takeover()
        let old = try sawFifty(takeover)
        let phone = Phone(takeover)
        phone.settings.deviceId = "dev-phone-new"
        phone.book = HubSeenBook(url: old.file, now: phone.now, mono: phone.mono)
        #expect(phone.settings.accessFloor(seen: phone.book.seen) == nil)
        #expect(phone.accepts(takeover.welcome("h3", seq: 1, devices: takeover.devices("before"))))
        phone.book.forget()
        #expect(!FileManager.default.fileExists(atPath: old.file.path))
    }

    @Test
    func damagedEvidenceIsSetAsideAndTheCounterFloorStays() throws {
        let takeover = try Takeover()
        let phone = try sawFifty(takeover)
        let damaged = Data("{\"access_seq\":".utf8)
        try damaged.write(to: phone.file)
        try phone.restart()
        #expect(phone.book.seen == nil)
        let aside = try #require(phone.book.setAside)
        #expect(try Data(contentsOf: aside) == damaged)
        #expect(phone.helloSeq == 50)
        #expect(!phone.accepts(takeover.welcome("h3", seq: 40, devices: takeover.devices("before"))))
        #expect(phone.receive(takeover.welcome("h3", seq: 51, devices: takeover.devices("before"))))
        try phone.restart()
        #expect(phone.book.seen?.accessSeq == 51)
        #expect(try Data(contentsOf: aside) == damaged)
    }

    @Test
    func unreadableEvidenceIsNeitherIgnoredNorOverwritten() throws {
        let takeover = try Takeover()
        let phone = try sawFifty(takeover)
        var devices = takeover.devices("before")
        devices.removeLast()
        #expect(phone.receive(takeover.state("h3", seq: 51, devices: devices)))
        let kept = try Data(contentsOf: phone.file)
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: phone.file.path)
        defer { try? FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: phone.file.path
        ) }
        try phone.restart()
        #expect(phone.book.unreadable)
        #expect(phone.helloSeq == 51)
        #expect(!phone.accepts(takeover.state("h3", seq: 40, devices: devices)))
        #expect(phone.receive(takeover.state("h3", seq: 52, devices: devices)))
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: phone.file.path)
        #expect(try Data(contentsOf: phone.file) == kept)
        phone.book.keep(changed: true, now: phone.now, mono: phone.mono)
        #expect(!phone.book.unreadable)
        try phone.restart()
        #expect(phone.book.seen?.accessSeq == 52)
        #expect(phone.helloRemoved == ["dev-helper"])
    }

    @Test
    func unreadableEvidenceRecoveryRecordsTheMissingDevice() throws {
        let takeover = try Takeover()
        let phone = try sawFifty(takeover)
        let kept = try Data(contentsOf: phone.file)
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: phone.file.path)
        defer { try? FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: phone.file.path
        ) }
        try phone.restart()
        #expect(phone.book.unreadable)
        var devices = takeover.devices("before")
        devices.removeLast()
        #expect(phone.receive(takeover.state("h3", seq: 52, devices: devices)))
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: phone.file.path)
        #expect(try Data(contentsOf: phone.file) == kept)
        phone.book.keep(changed: true, now: phone.now, mono: phone.mono)
        #expect(phone.helloRemoved == ["dev-helper"])
        #expect(phone.book.seen?.removed.first?.accessSeq == 52)
        phone.book.reload(now: phone.now, mono: phone.mono)
        #expect(phone.book.seen?.removed.count == 1)
        try phone.restart()
        #expect(phone.helloSeq == 52)
        #expect(phone.helloRemoved == ["dev-helper"])
    }

    @Test
    func forgettingTheHubDeletesDamagedEvidenceAcrossRestarts() throws {
        let takeover = try Takeover()
        let phone = try sawFifty(takeover)
        try Data("{\"access_seq\":".utf8).write(to: phone.file)
        try phone.restart()
        let aside = try #require(phone.book.setAside)
        #expect(FileManager.default.fileExists(atPath: aside.path))
        #expect(phone.receive(takeover.state("h3", seq: 51, devices: takeover.devices("before"))))
        try phone.restart()
        #expect(phone.book.setAside == nil)
        phone.book.forget()
        #expect(!FileManager.default.fileExists(atPath: phone.file.path))
        #expect(!FileManager.default.fileExists(atPath: aside.path))
        #expect(phone.book.setAside == nil)
        #expect(phone.book.seen == nil)
    }

    @Test
    func olderEvidenceFileDoesNotOverrideTheRebasedFloor() throws {
        let takeover = try Takeover()
        let phone = try sawFifty(takeover)
        let older = try Data(contentsOf: phone.file)
        let seq = takeover.number("agreedSeq")
        #expect(phone.receive(takeover.welcome(
            "h1000",
            seq: seq,
            devices: takeover.devices("agreedDevices")
        )))
        try older.write(to: phone.file)
        try phone.restart()
        #expect(phone.helloSeq == seq)
        #expect(phone.helloRemoved.isEmpty)
        #expect(phone.accepts(takeover.state("h1000", seq: seq, devices: takeover.devices("agreedDevices"))))
        #expect(!phone.accepts(takeover.state(
            "h1000",
            seq: seq - 1,
            devices: takeover.devices("agreedDevices")
        )))
    }

    @Test
    func profileWithoutASavedFloorUsesTheEvidenceFile() throws {
        let takeover = try Takeover()
        let phone = try sawFifty(takeover)
        phone.settings.accessFloor = nil
        try phone.restart()
        #expect(!phone.accepts(takeover.welcome("h3", seq: 40, devices: takeover.devices("before"))))
        #expect(phone.receive(takeover.welcome("h3", seq: 50, devices: takeover.devices("before"))))
        #expect(phone.settings.accessFloor == HubAccessFloor(seq: 50, lineage: 1))
    }

    @Test
    func clockStepsKeepRecentRemovalsAndStillExpireOldOnes() throws {
        let takeover = try Takeover()
        let phone = try sawFifty(takeover)
        var devices = takeover.devices("before")
        devices.removeLast()
        #expect(phone.receive(takeover.state("h3", seq: 51, devices: devices)))
        let removedAt = phone.now
        phone.now -= 2000
        phone.mono.ms += 500
        phone.book.keep(changed: true, now: phone.now, mono: phone.mono)
        try phone.restart()
        #expect(phone.helloRemoved == ["dev-helper"])
        phone.now = removedAt - 2000
        phone.mono = HubMono(boot: "boot-b", ms: 1000)
        try phone.restart()
        #expect(phone.helloRemoved == ["dev-helper"])
        phone.now = removedAt + 3 * hubSeenRemovedKeepMs
        let removal = try #require(phone.book.seen?.removed.first)
        let sameBoot = try HubMono(boot: "boot-a", ms: #require(removal.mono).ms + 60000)
        #expect(hubRemovalKept(removal, now: phone.now, mono: sameBoot))
        let laterBoot = HubMono(boot: "boot-c", ms: 1000)
        #expect(!hubRemovalKept(removal, now: phone.now, mono: laterBoot))
        #expect(try !hubRemovalKept(removal, now: removedAt + 1000, mono: HubMono(
            boot: "boot-a",
            ms: #require(removal.mono).ms + hubSeenRemovedKeepMs
        )))
        #expect(hubRemovalKept(removal, now: removedAt - 2000, mono: nil))
        #expect(hubRemovalAge(removal, now: removedAt - 2000, mono: nil) == 0)
        #expect(!hubRemovalKept(removal, now: removedAt - hubSeenRemovedKeepMs - 1, mono: nil))
    }
}
