import Foundation

@MainActor
final class RegressionPhone {
    let key: HubKeyPair
    let hubKey: Data
    let file: URL
    var settings = SettingsHub()
    var book: HubSeenBook
    var now: Int64 = 1000
    var closed = false

    init(fixture: [String: Any], file: URL) throws {
        key = try HubKeyPair(privateKey: hubBase64UrlDecode(fixture["deviceKey"] as! String)!)
        hubKey = hubBase64UrlDecode(fixture["hubKey"] as! String)!
        self.file = file
        try? FileManager.default.removeItem(at: file)
        settings.hubKey = fixture["hubKey"] as! String
        settings.deviceId = "phone"
        settings.role = "admin"
        book = HubSeenBook(url: file, now: now, mono: nil)
    }

    func learn(_ message: HubMessage) -> Bool {
        now += 1000
        guard let learned = settings.learn(message, book: book, now: now, mono: nil) else {
            return false
        }
        if let noted = learned.seen {
            book.keep(changed: noted, now: now, mono: nil)
        }
        return true
    }

    func connect(_ urls: [String]) async throws -> HubConnection {
        let connection = try await HubConnection.connect(urls: urls.map { URL(string: $0)! },
                                                         key: key,
                                                         hubKey: hubKey,
                                                         hello: settings.hello(
                                                             seen: book.seen,
                                                             now: now,
                                                             mono: nil
                                                         ),
                                                         validateWelcome: { message in
                                                             _ = try self.settings.check(
                                                                 message,
                                                                 seen: self.book.seen
                                                             )
                                                         })
        closed = false
        connection.onMessage = { [weak self, weak connection] message in
            guard let self else {
                return
            }
            if message.type == "welcome" || message.type == "state" {
                guard (try? settings.check(message, seen: book.seen)) != nil else {
                    connection?.close()
                    closed = true
                    return
                }
                _ = learn(message)
            }
        }
        _ = learn(connection.welcome)
        return connection
    }

    func restart() throws {
        settings = try JSONDecoder().decode(SettingsHub.self, from: JSONEncoder().encode(settings))
        now += 60000
        book = HubSeenBook(url: file, now: now, mono: nil)
    }

    var helloSeq: Int? {
        (settings
            .hello(seen: book.seen, now: now, mono: nil)["seen"] as? [String: Any])?["access_seq"] as? Int
    }
}

@MainActor
func report(_ object: [String: Any]) {
    let data = try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    print(String(decoding: data, as: UTF8.self))
}

@main struct ReconnectRegression {
    @MainActor static func main() async throws {
        let fixture = try JSONSerialization
            .jsonObject(with: Data(contentsOf: URL(fileURLWithPath: CommandLine
                    .arguments[1]))) as! [String: Any]
        let urls = fixture["urls"] as! [String: String]
        let hubs = fixture["hubs"] as! [String: [String: Any]]
        let saved = URL(fileURLWithPath: CommandLine.arguments[2])
        var failed = false
        func check(_ name: String, _ ok: Bool, _ detail: [String: Any] = [:]) {
            report(detail.merging(["check": name, "ok": ok]) { $1 })
            failed = failed || !ok
        }
        func welcome(_ hub: String, _ seq: Int, _ devices: [String]) -> HubMessage {
            var view = hubs[hub]!
            view["access"] = ["seq": seq]
            return HubMessage(object: ["type": "welcome", "hub": view,
                                       "state": [
                                           "hub": view,
                                           "devices": devices.map { ["id": $0, "name": $0] },
                                       ]])
        }

        let same = try RegressionPhone(fixture: fixture, file: saved)
        check("pinned same lineage at 50", same.learn(welcome("lone", 50, ["owner", "new-device"])))
        let connection = try await same.connect([urls["staleEpoch"]!, urls["staleCounter"]!, urls["fresh"]!])
        connection.close()
        try same.restart()
        check("skips stale epoch and lower counter in the same lineage",
              connection.url.absoluteString == urls["fresh"]! && same.helloSeq == 50
                  && same.book.seen?.removed.isEmpty == true,
              ["url": connection.url.absoluteString, "hello": same.helloSeq ?? -1])

        let before = try RegressionPhone(fixture: fixture, file: saved)
        check("saw 50 before the takeover", before.learn(welcome("before", 50, ["owner", "phone", "helper"])))
        try before.restart()
        let tookOver = try await before.connect([urls["tookOver"]!])
        tookOver.close()
        try before.restart()
        check("accepts an agreed takeover it did not witness", before.helloSeq == 46
            && before.settings.accessFloor == HubAccessFloor(seq: 46, lineage: 1000)
            && before.book.seen?.removed.isEmpty == true,
            ["hello": before.helloSeq ?? -1])

        let waiting = try RegressionPhone(fixture: fixture, file: saved)
        check(
            "saw 50 before the takeover",
            waiting.learn(welcome("before", 50, ["owner", "phone", "helper"]))
        )
        try waiting.restart()
        let pending = try await waiting.connect([urls["stalePending"]!, urls["waiting"]!])
        check(
            "skips a stale waiting host and waits on the new one",
            pending.url.absoluteString == urls["waiting"]!,
            ["url": pending.url.absoluteString]
        )
        try await Task.sleep(nanoseconds: 1_500_000_000)
        pending.close()
        check("stays connected when an owner allows it", !waiting.closed
            && waiting.settings.accessFloor == HubAccessFloor(seq: 47, lineage: 1000))
        try waiting.restart()
        check("keeps the allowed counter across a restart", waiting.helloSeq == 47
            && waiting.book.seen?.removed.isEmpty == true,
            ["hello": waiting.helloSeq ?? -1])
        let after = try await waiting.connect([urls["behindAllow"]!, urls["allowed"]!])
        after.close()
        check("refuses a lower counter in the new lineage", after.url.absoluteString == urls["allowed"]!,
              ["url": after.url.absoluteString])
        if failed {
            exit(1)
        }
    }
}
