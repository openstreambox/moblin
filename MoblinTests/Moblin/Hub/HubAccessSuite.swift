import Foundation
@testable import Moblin
import Testing

// "Who has access" in words: the sentences come from the requests the hub
// says a role may make, and the rows from what the hub reported.

private let admin = ["state.get", "stream.go_live", "stream.move", "stream.end", "privacy.hide", "privacy.show",
                     "invite.open", "device.remove", "hub.recovery.get"]
private let member = ["state.get", "stream.go_live", "stream.move", "stream.end", "privacy.hide", "privacy.show"]
private let helper = ["state.get", "stream.move", "privacy.hide"]
private let mod = ["mod.state", "privacy.hide"]

private func when() -> HubWhen {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return HubWhen(now: HubWhen.date("2026-11-17T10:00:00Z")!, calendar: calendar, locale: Locale(identifier: "en_GB"))
}

private func grant(_ id: String,
                   kind: String = "device",
                   name: String,
                   role: String,
                   allows: [String],
                   state: String = "active",
                   can: [String] = ["change", "end"]) -> HubGrant
{
    HubGrant(id: id, kind: kind, name: name, role: role, allows: allows, state: state, can: can)
}

private func access(_ grants: [HubGrant], trail: [HubTrailEntry] = [], people: [HubPerson]? = nil) -> HubAccess {
    HubAccess(hub: "Studio hub",
              stream: .init(live: "live", hidden: false),
              grants: grants,
              trail: trail,
              trailMore: false,
              people: people)
}

private func party(_ name: String, _ role: String, kind: String = "device") -> HubParty {
    HubParty(kind: kind, id: "id-\(name)", name: name, role: role)
}

struct HubAccessSuite {
    @Test
    func saysWhatEachRoleAllowsFromTheHubsTable() {
        #expect(hubAllowsLine(admin) == "Can do everything, and let people in and remove them.")
        #expect(hubAllowsLine(member) ==
            "Can go live, move the stream, end the stream, hide the picture and show the picture again. "
            + "Can't let people in or remove them.")
        #expect(hubAllowsLine(helper) ==
            "Can move the stream and hide the picture. "
            + "Can't go live, end the stream, show the picture again or let people in or remove them.")
        #expect(hubAllowsLine(mod) == "Can see the status and hide the picture. Nothing else.")
        // The stream's session owner: from allows and limits, not from a role's name.
        #expect(hubAllowsLine(member + ["invite.open"], limits: ["invite.open": "stream"]) ==
            "Can go live, move the stream, end the stream, hide the picture, show the picture again and "
            + "let helpers and mods in for this stream only. Can't remove devices or owners or see keys or passwords.")
        // What the panel says about a waiting device matches the table.
        #expect(hubAllowsLine(hubRoleAllows("helper")) == hubAllowsLine(helper))
        #expect(hubAllowsLine(hubRoleAllows("member")) == hubAllowsLine(member))
    }

    @Test
    func saysWhenInTheSameWordsAsTheOtherApps() {
        #expect(when().text("2026-11-17T18:40:00.000Z") == "today at 18:40")
        #expect(when().text("2026-11-18T09:00:00Z") == "tomorrow at 09:00")
        #expect(when().text("2026-11-16T23:59:00Z") == "yesterday at 23:59")
        #expect(when().text("2026-11-19T18:40:00Z") == "Thursday 19 Nov at 18:40")
    }

    @Test
    func readsTheHubsList() throws {
        let json = """
        {"hub":"Studio hub","as":{"id":"dev-1","name":"iPhone"},
        "stream":{"session":"s1","live":"live","hidden":false},
        "grants":[{"id":"dev-2","kind":"device","name":"Kim's laptop","for":"Kim","device_kind":"helper",
        "role":"helper","allows":["state.get","stream.move","privacy.hide"],"state":"waiting","online":true,
        "how":"link","given_by":{"id":"dev-1","name":"iPhone"},"given_at":null,"allowed_by":null,"allowed_at":null,
        "joined_at":"2026-11-17T09:58:00.000Z","ends_at":null,"ends_with_stream":true,"carries_stream":false,
        "self":false,"can":["allow","change","end"]},
        {"id":"inv-1","kind":"invite","name":"","for":null,"device_kind":null,"role":"helper",
        "allows":["state.get","stream.move","privacy.hide"],"state":"open","online":false,"how":"link",
        "given_by":{"id":"dev-1","name":"iPhone"},"given_at":"2026-11-17T09:55:00.000Z","joined_at":null,
        "ends_at":"2026-11-17T11:55:00.000Z","access_ms":7200000,"ends_with_stream":true,"carries_stream":false,
        "self":false,"can":["end"],"a_field_from_later":1}],
        "trail":[{"seq":4,"at":"2026-11-17T09:59:00.000Z","session":"s1","type":"access.changed",
        "by":{"kind":"device","id":"dev-1","name":"iPhone","role":"admin"},
        "subject":{"kind":"device","id":"dev-2","name":"Kim's laptop","role":"helper"},
        "detail":{"ends_at":null,"ends_with_stream":false}}],"trail_more":false}
        """
        let access = try #require(HubMessage(data: Data(json.utf8)).decodeAll(as: HubAccess.self))
        let page = try #require(hubAccessPage(access, connected: true, when: when()))
        #expect(page.label == "Studio hub · LIVE")
        #expect(page.line == "1 is waiting for Allow.")
        #expect(page.sections.map(\.title) == ["Waiting for Allow", "Invites not used yet"])
        let waiting = page.sections[0].rows[0]
        #expect(waiting.allow)
        #expect(waiting.allowConfirm == nil)
        #expect(waiting.forName == "Kim")
        #expect(waiting.how == "Opened a link from iPhone · today at 09:58")
        #expect(waiting.ends == "Ends when the stream ends")
        let invite = page.sections[1].rows[0]
        #expect(invite.name == "Helper invite")
        #expect(invite.how == "Link made on iPhone · today at 09:55")
        #expect(invite.ends == "Closes today at 11:55 if nobody uses it")
        #expect(invite.notes == ["Whoever joins with it stays for 2 hours or until the stream ends."])
        #expect(invite.end == .init(label: "End now", confirm: "Close this invite? The code or link stops working."))
        #expect(invite.change == nil)
        #expect(page.trail.map(\.text) == ["iPhone changed when Kim's laptop's access ends: only when removed"])
    }

    @Test
    func warnsBeforeRemovingWhatViewersSeeAndKeepsTheLastOwnerDevice() {
        var carrier = grant("dev-1", name: "Mac", role: "admin", allows: admin, can: ["end"])
        carrier.carriesStream = true
        carrier.online = true
        var phone = grant("dev-2", name: "iPhone", role: "admin", allows: admin, can: [])
        phone.isSelf = true
        var sam = grant("mod-1", kind: "mod", name: "Sam", role: "mod", allows: mod)
        sam.state = "open"
        sam.endsAt = "2026-11-17T22:00:00Z"
        sam.endsWithStream = true
        let rows = [carrier, phone, sam].map { hubAccessRow($0, when: when()) }
        #expect(rows[0].end == .init(label: "Remove",
                                     confirm: "Remove Mac? Viewers see it right now, so the standby picture goes on."))
        #expect(rows[0].notes == ["Viewers see this device. Removing it puts the standby picture on."])
        #expect(rows[0].presence == "Here now")
        #expect(rows[0].change == nil)
        // No dead button: the last owner device has no Remove at all.
        #expect(rows[1].end == nil)
        #expect(rows[1].notes == ["This phone.", "The last owner device can't be removed."])
        #expect(rows[1].presence == HubWords.Access.away)
        #expect(rows[2].presence == "Link not opened yet")
        #expect(rows[2].ends == "Ends when the stream ends, or today at 22:00")
        #expect(rows[2].end == .init(label: "End now", confirm: "End Sam's mod link? Their page closes at once."))
        // A mod link always ends: "Until you remove it" isn't offered.
        #expect(rows[2].change == [.stream, .hour, .halfDay, .day])
    }

    @Test
    func asksTheHubForTheChosenEnd() {
        let now = HubWhen.date("2026-11-17T10:00:00Z")!
        #expect(HubAccessChange.stream.request(now: now) as NSDictionary == ["ends_with_stream": true])
        #expect(HubAccessChange.never.request(now: now) as NSDictionary ==
            ["ends_at": NSNull(), "ends_with_stream": false])
        #expect(HubAccessChange.hour.request(now: now) as NSDictionary ==
            ["ends_at": "2026-11-17T11:00:00.000Z", "ends_with_stream": false])
    }

    @Test
    func aCoOwnerIsLetInOnlyAfterTheOwnerConfirms() {
        var waiting = grant("dev-9", name: "Robin's phone", role: "admin", allows: admin, state: "waiting",
                            can: ["allow", "end"])
        waiting.person = HubPersonRef(id: nil, name: "Robin")
        waiting.newOwner = true
        let row = hubAccessRow(waiting, when: when())
        #expect(row.notes == ["Allowing makes Robin a co-owner."])
        #expect(row.allowConfirm == .init(
            label: "Make co-owner",
            confirm: "Make Robin a co-owner with Robin's phone? A co-owner can do everything you can, "
                + "including removing your devices."
        ))
        // An owner's own second device: a plain Allow, said as what it is.
        waiting.newOwner = false
        waiting.person = HubPersonRef(id: "per-1", name: "Alex")
        let second = hubAccessRow(waiting, when: when())
        #expect(second.allowConfirm == nil)
        #expect(second.notes == ["Allowing adds an owner device for Alex."])
    }

    @Test
    func groupsOwnerDevicesByPersonAndSaysWhoRunsTheStream() throws {
        var phone = grant("dev-1", name: "iPhone", role: "admin", allows: admin, can: [])
        phone.person = HubPersonRef(id: "per-1", name: "Alex")
        var box = grant("dev-2", name: "Backpack", role: "member", allows: member, can: ["change", "end", "hand"])
        box.person = HubPersonRef(id: "per-1", name: "Alex")
        var kims = grant("dev-3", name: "Kim's phone", role: "admin", allows: admin, can: ["end"])
        kims.person = HubPersonRef(id: "per-2", name: "Kim")
        var jo = grant("dev-4", name: "Jo's laptop", role: "helper", allows: member + ["invite.open"],
                       can: ["change", "end", "take_back"])
        jo.runsStream = true
        jo.limits = ["invite.open": "stream"]
        var list = access([phone, box, kims, jo],
                          people: [HubPerson(id: "per-1", name: "Alex", you: true),
                                   HubPerson(id: "per-2", name: "Kim", you: false)])
        list.stream.runBy = HubRunBy(kind: "handed",
                                     device: HubPersonRef(id: "dev-4", name: "Jo's laptop"),
                                     forName: "Jo",
                                     givenBy: HubPersonRef(id: "dev-1", name: "iPhone"),
                                     givenAt: "2026-11-17T09:30:00Z",
                                     endsAt: "2026-11-18T09:30:00Z",
                                     gave: HubGave(helpers: 0, mods: 1, invites: 0))
        list.can = ["clear_trail"]
        let page = try #require(hubAccessPage(list, connected: true, when: when()))
        #expect(page.sections.map(\.title) == ["Alex (you)", "Kim", "Helpers"])
        #expect(page.sections.map(\.tag) == ["Co-owner", "Co-owner", nil])
        // Words Moblin already translates follow the device's language.
        #expect(page.sections[0].rows.map(\.role) == ["Owner device", HubWords.Access.role("shared")])
        #expect(page.sections[0].rows[1].hand?.label == "Hand over this stream")
        #expect(page.sections[2].rows[0].role == "Stream session owner")
        #expect(page.line == "2 owners, 3 devices and 1 helper.")
        let running = try #require(page.running)
        #expect(running.line == "Jo runs it, on Jo's laptop.")
        #expect(running.facts == ["Handed over by iPhone · today at 09:30",
                                  "Runs while the stream is live. Without an owner's answer it ends tomorrow at 09:30.",
                                  "Let in for this stream: 1 mod. They end with it."])
        #expect(running.takeBack?.confirm ==
            "Take this stream back from Jo? What they let in (1 mod) loses access at once. The stream keeps running.")
        // Nothing to clear yet, so no Clear.
        #expect(!page.clear)
        // One owner and nobody handed anything: the plain line, no button.
        list.stream.runBy = nil
        list.people = [HubPerson(id: "per-1", name: "", you: true)]
        let alone = try #require(hubAccessPage(list, connected: true, when: when()))
        #expect(alone.sections.map(\.title) == ["You", "Helpers"])
        #expect(alone.sections[0].tag == HubWords.Access.owner)
        #expect(alone.running?.takeBack == nil)
    }

    @Test
    func tellsTheTrailInWords() {
        func line(_ type: String, by: HubParty? = nil, subject: HubParty? = nil,
                  detail: HubTrailDetail? = nil) -> String
        {
            hubTrailLine(HubTrailEntry(seq: 1, at: "2026-11-17T09:00:00Z", type: type, by: by, subject: subject,
                                       detail: detail),
                         when: when())
        }
        let mac = party("Mac", "admin")
        let kim = party("Kim's laptop", "helper")
        let sam = party("Sam", "mod", kind: "mod")
        #expect(line("device.joined", by: HubParty(kind: "hub", id: "hub", name: "Hub"),
                     subject: party("Owner phone", "admin")) ==
            "Owner phone joined as an owner device with the hub's first link")
        #expect(line("invite.opened", by: mac, subject: party("Kim", "helper", kind: "invite"),
                     detail: HubTrailDetail(via: "link")) == "Mac made a helper link for Kim")
        #expect(line("device.joined", by: mac, subject: kim, detail: HubTrailDetail(via: "link", waiting: true)) ==
            "Kim's laptop asked to join as a helper with a link from Mac")
        #expect(line("device.allowed", by: mac, subject: kim) == "Mac allowed Kim's laptop")
        #expect(line("mod.made", by: mac, subject: sam) == "Mac made a mod link for Sam")
        #expect(line("privacy.hide", by: sam) == "Sam (mod) hid the picture")
        #expect(line("stream.move", by: kim, subject: mac) == "Kim's laptop (helper) moved the stream to Mac")
        #expect(line("device.removed", by: mac, subject: kim, detail: HubTrailDetail(carriedStream: true)) ==
            "Mac removed Kim's laptop while viewers saw it")
        #expect(line("mod.ended", subject: sam, detail: HubTrailDetail(why: "stream")) ==
            "Sam's mod link ended with the stream")
        var web = mac
        web.web = true
        #expect(line("mod.removed", by: web, subject: sam) == "Mac, from the web view ended Sam's mod link")
        var cleared = HubTrailDetail()
        cleared.lines = 31
        #expect(line("trail.cleared", by: mac, detail: cleared) == "Mac cleared what happened (31 lines)")
        var handed = HubTrailDetail()
        handed.forName = "Kim"
        #expect(line("stream.handed", by: mac, subject: kim, detail: handed) ==
            "Mac handed the stream to Kim (Kim's laptop)")
    }

    @Test
    func keepsTheLastListButSaysCantSayWhileTheHubIsOutOfReach() throws {
        let list = access([grant("dev-1", name: "Mac", role: "admin", allows: admin, can: [])])
        let page = try #require(hubAccessPage(list, connected: false, when: when()))
        #expect(page.kind == .unknown)
        #expect(page.label == "Studio hub · Can't say right now")
        #expect(page.line == "Lost the connection to your hub. Reconnecting…")
        #expect(!page.current)
        #expect(hubAccessPage(nil, connected: true, when: when()) == nil)
    }

    @Test
    func saysWhoHidOnlyWhenItWasSomeoneElse() {
        let sam = HubParty(kind: "mod", id: "mod-1", name: "Sam", role: "mod")
        let hidden = HubPrivacy(hidden: true, generation: 3, hiddenBy: sam)
        #expect(hubHiddenByLine(hidden, me: "dev-phone") == "Hidden by Sam · Mod")
        #expect(hubHiddenByLine(hidden, me: "mod-1") == nil)
        #expect(hubHiddenByLine(HubPrivacy(hidden: false, generation: 3, hiddenBy: sam), me: "dev-phone") == nil)
        #expect(hubHiddenByLine(HubPrivacy(hidden: true, generation: 3), me: "dev-phone") == nil)
        let state = HubState(session: HubSession(id: "s1", live: "live", program: "dev-phone", privacy: hidden,
                                                 output: HubOutput(state: "live")),
                             feeds: [],
                             devices: [])
        let status = hubStatus(state: state, me: "dev-phone", connected: true, pending: false)
        #expect(status.title == "LIVE · privacy screen on")
        #expect(status.phone == "Hidden by Sam · Mod")
        #expect(status.text == "LIVE · privacy screen on · Hidden by Sam")
    }

    @Test
    func readsWhoHidAndTheCrewFromTheState() throws {
        let json = """
        {"session":{"id":"s1","live":"live","program":"dev-1",
        "privacy":{"hidden":true,"generation":2,"hidden_by":{"id":"dev-2","name":"Kim's laptop","role":"helper"}},
        "output":{"state":"live"}},"feeds":[],
        "devices":[{"id":"dev-2","name":"Kim's laptop","kind":"helper","role":"helper","allowed":true,"online":true,
        "feed":false},{"id":"dev-3","name":"Jo's laptop","kind":"helper","role":"helper","allowed":false,
        "online":true,"feed":false}],
        "invites":[{"id":"i1","role":"helper","via":"link","by":"dev-1","closes_at":"2026-11-17T12:00:00Z",
        "rotates":false,"ends_with_stream":true}],
        "mods":[{"id":"mod-1","name":"Sam","state":"open","by":"dev-1","expires_at":"2026-11-17T22:00:00Z",
        "joined_at":null,"online":false}]}
        """
        let state = try JSONDecoder().decode(HubState.self, from: Data(json.utf8))
        #expect(state.session.privacy.hiddenBy?.name == "Kim's laptop")
        #expect(hubWaitingDevices(state).map(\.name) == ["Jo's laptop"])
        let crew = hubCrewSummary(state)
        #expect(crew.helpers.map(\.name) == ["Kim's laptop"])
        #expect(crew.line == "1 helper · 1 mod link · 1 open helper link")
        // A hub from before any of this: nothing listed, nothing invented.
        let old = try JSONDecoder().decode(HubState.self, from: Data("""
        {"session":{"id":"s1","live":"ready","privacy":{"hidden":false,"generation":0}},"feeds":[],"devices":[]}
        """.utf8))
        #expect(old.session.privacy.hiddenBy == nil)
        #expect(hubCrewSummary(old).isEmpty)
    }
}
