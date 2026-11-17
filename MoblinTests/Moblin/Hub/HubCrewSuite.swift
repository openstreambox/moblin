import Foundation
@testable import Moblin
import Testing


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
                   can: [String] = ["change", "end"],
                   person: String? = nil) -> HubGrant
{
    var grant = HubGrant(id: id, kind: kind, name: name, role: role, allows: allows, state: state, can: can)
    grant.online = true
    if let person {
        grant.person = HubPersonRef(id: person, name: person == "per-1" ? "Alex" : "Kim")
    }
    return grant
}

private func state(runBy: String? = nil) -> HubState {
    HubState(session: HubSession(id: "s1",
                                 live: "live",
                                 program: "dev-desk",
                                 privacy: HubPrivacy(hidden: false, generation: 1),
                                 output: HubOutput(state: "live"),
                                 runBy: runBy.map {
                                     HubSessionRunBy(device: $0, since: "2026-11-17T09:30:00Z",
                                                     endsAt: "2026-11-18T09:30:00Z")
                                 }),
             feeds: [],
             devices: [])
}

private func list(_ grants: [HubGrant], people: [HubPerson]) -> HubAccess {
    HubAccess(hub: "Studio hub",
              stream: .init(live: "live", hidden: false),
              grants: grants,
              trail: [],
              trailMore: false,
              people: people,
              asWho: HubAccessAs(id: "dev-phone", name: "iPhone", role: "admin", runsStream: false,
                                 person: HubPersonRef(id: "per-1", name: people.first?.name)))
}

struct HubCrewSuite {
    @Test
    func waitsForTheAccessListBeforeOfferingAllowOnAnOwnerDevice() {
        var pending = state()
        pending.devices = [HubDevice(id: "dev-kim", name: "Kim's iPad", kind: "phone", role: "admin",
                                     allowed: false)]
        let page = hubCrewPage(state: pending, access: nil, me: "dev-phone", role: "admin", when: when())
        #expect(page.waiting.isEmpty)
    }

    @Test
    func groupsTheCrewByPersonWithAWayInPerGroup() {
        var phone = grant("dev-phone", name: "iPhone", role: "admin", allows: admin, can: [], person: "per-1")
        phone.isSelf = true
        let box = grant("dev-box", name: "Backpack", role: "member", allows: member, person: "per-1")
        var kim = grant("dev-kim", name: "Kim's laptop", role: "helper", allows: helper)
        kim.forName = "Kim"
        kim.joinedAt = "2026-11-17T09:10:00Z"
        kim.endsWithStream = true
        var sam = grant("mod-sam", kind: "mod", name: "Sam", role: "mod", allows: mod)
        sam.joinedAt = "2026-11-17T09:32:00Z"
        sam.endsAt = "2026-11-17T21:30:00Z"
        sam.endsWithStream = true
        var link = grant("inv-1", kind: "invite", name: "Jo", role: "helper", allows: helper, state: "open",
                         can: ["end"])
        link.how = "link"
        link.endsAt = "2026-11-17T11:55:00Z"
        var code = grant("inv-2", kind: "invite", name: "", role: "member", allows: member, state: "open",
                         can: ["end"])
        code.how = "scan"
        let access = list([phone, box, kim, sam, link, code], people: [HubPerson(id: "per-1", name: "", you: true)])
        let page = hubCrewPage(state: state(), access: access, me: "dev-phone", role: "admin", when: when())
        #expect(page.manages)
        #expect(page.line == "Everyone and everything in your streaming setup. Each device has its own key.")
        #expect(page.groups.map(\.title) == ["You", "Co-owners", "Helpers", "Mods"])
        #expect(page.groups.map(\.add) == [nil, .coOwner, .helper, .mod])
        #expect(page.groups.map(\.add?.label) == [nil, "Add a co-owner", "Add a helper", "Add a mod"])
        #expect(page.groups[0].yours)
        #expect(page.groups[0].rows.map(\.title) == ["iPhone · this phone", "Backpack"])
        #expect(page.groups[0].rows[0].end == nil)
        #expect(page.groups[0].rows[1].end?.label == HubWords.Access.remove)
        #expect(page.groups[1].empty == "Nobody else owns this setup.")
        let helpers = page.groups[2].rows
        #expect(helpers.map(\.title) == ["Kim's laptop · for Kim", "Link for Jo"])
        #expect(helpers[0].line == "since 09:10 · ends with the stream")
        #expect(helpers[1].status == "Not opened yet")
        #expect(helpers[1].line == "closes today at 11:55")
        #expect(helpers[1].end == .init(label: "End link",
                                        confirm: "Close this invite? The code or link stops working."))
        #expect(page.groups[3].rows[0].line == "since 09:32 · ends with the stream, or today at 21:30")
        #expect(page.groups[3].rows[0].status == "Page open")
        #expect(page.summary == "2 devices, 1 helper and 1 mod")
        #expect(page.ownName == "")
        #expect(page.session == nil)
    }

    @Test
    func anotherOwnersDeviceIsTheirsToAllow() {
        let phone = grant("dev-phone", name: "iPhone", role: "admin", allows: admin, can: [], person: "per-1")
        let kims = grant("dev-kims", name: "Kim's phone", role: "admin", allows: admin, can: ["end"],
                         person: "per-2")
        var pad = grant("dev-pad", name: "Kim's iPad", role: "admin", allows: admin, state: "waiting",
                        can: ["end"], person: "per-2")
        pad.how = "link"
        var robin = grant("dev-robin", name: "Robin's phone", role: "admin", allows: admin, state: "waiting",
                          can: ["allow", "end"])
        robin.person = HubPersonRef(id: nil, name: "Robin")
        robin.newOwner = true
        var jo = grant("dev-jo", name: "Jo's laptop", role: "helper", allows: helper, state: "waiting",
                       can: ["allow", "end"])
        jo.how = "link"
        jo.handsStream = true
        let access = list([phone, kims, pad, robin, jo],
                          people: [HubPerson(id: "per-1", name: "Alex", you: true),
                                   HubPerson(id: "per-2", name: "Kim", you: false)])
        let page = hubCrewPage(state: state(), access: access, me: "dev-phone", role: "admin", when: when())
        #expect(page.groups.map(\.title) == ["Alex (you)", "Kim", "Co-owners", "Helpers", "Mods"])
        #expect(page.groups[0].tag == HubWords.Access.coOwner)
        #expect(page.others.map(\.name) == ["Kim"])
        let waiting = page.waiting
        #expect(waiting.map(\.title) == [
            "“Kim's iPad” wants to join as an owner device for Kim",
            "“Robin's phone” wants to join as a co-owner’s device",
            "“Jo's laptop” wants to join as a helper",
        ])
        #expect(!waiting[0].allow)
        #expect(waiting[0].line == "Kim allows this on one of their own devices.")
        #expect(waiting[0].confirm == nil)
        #expect(waiting[1].allow)
        #expect(waiting[1].line == "Allowing makes Robin a co-owner.")
        #expect(waiting[1].confirm?.label == "Make co-owner")
        #expect(waiting[2].line == "Allowing hands this stream to them.")
        let row = hubAccessRow(pad, when: when())
        #expect(!row.allow)
        #expect(row.notes == ["Allowing adds an owner device for Kim.",
                              "Kim allows this on one of their own devices."])
    }

    @Test
    func listsTheLinksToTheOwnersPageWithEndNow() throws {
        let json = """
        {"hub":"Studio hub","as":{"id":"dev-1","name":"iPhone","role":"admin","runs_stream":false,
        "person":{"id":"per-1","name":""}},"stream":{"session":"s1","live":"ready","hidden":false},
        "grants":[],"trail":[],"trail_more":false,
        "owner_links":[{"id":"own-1","device":{"id":"dev-2","name":"Mac"},"state":"active","online":true,
        "made_at":"2026-11-17T09:18:00.000Z","opened_at":"2026-11-17T09:19:00.000Z",
        "ends_at":"2026-11-17T10:18:00.000Z","can":["end"]},
        {"id":"own-2","device":{"id":"dev-1","name":"iPhone"},"state":"open","online":false,
        "made_at":"2026-11-17T09:56:00.000Z","opened_at":null,"ends_at":"2026-11-17T10:56:00.000Z","can":[]},
        {"id":"own-3","device":{"id":"dev-2","name":"Mac"},"state":"active","online":false,
        "made_at":"2026-11-16T21:00:00.000Z","opened_at":"2026-11-16T21:01:00.000Z",
        "ends_at":"2026-11-17T10:30:00.000Z","can":["end"]}]}
        """
        let access = try #require(HubMessage(data: Data(json.utf8)).decodeAll(as: HubAccess.self))
        let page = try #require(hubAccessPage(access, connected: true, when: when()))
        #expect(page.links.map(\.id) == ["own-1", "own-2", "own-3"])
        #expect(page.links.map(\.name) == ["Made on Mac", "Made on iPhone", "Made on Mac"])
        #expect(page.links.map(\.presence) == ["Page open", "Not opened yet", "Page closed"])
        #expect(page.links[0].facts == ["Made today at 09:18 · opened today at 09:19",
                                        HubWords.Access.linkEnds("today at 10:18")])
        #expect(page.links[1].facts == ["Made today at 09:56", HubWords.Access.linkEnds("today at 10:56")])
        #expect(page.links[0].end == .init(label: "End now",
                                           confirm: "End this link? The page it opened closes at once."))
        #expect(page.links[1].end == nil)
        #expect(HubWords.Access.links == "Links to this page")
        #expect(HubWords.Access.linkCan == "Whoever holds it sees this list and can remove people and devices.")
        var old = access
        old.ownerLinks = nil
        #expect(try #require(hubAccessPage(old, connected: true, when: when())).links.isEmpty)
    }

    @Test
    func showsThePhoneThatWasHandedTheStreamWhatItMayDo() throws {
        var mac = grant("dev-desk", name: "Mac", role: "admin", allows: admin, can: [])
        mac.carriesStream = true
        var me = grant("dev-phone", name: "Jo's iPhone", role: "helper", allows: member + ["invite.open"],
                       can: ["take_back"])
        me.isSelf = true
        me.runsStream = true
        me.limits = ["invite.open": "stream"]
        me.givenBy = HubParty(id: "dev-desk", name: "Mac")
        var robin = grant("dev-robin", name: "Robin's laptop", role: "helper", allows: helper)
        robin.givenBySession = true
        robin.givenBy = HubParty(id: "dev-phone", name: "Jo's iPhone")
        robin.joinedAt = "2026-11-17T09:48:00Z"
        robin.endsWithStream = true
        var access = list([mac, me, robin], people: [])
        access.asWho = HubAccessAs(id: "dev-phone", name: "Jo's iPhone", role: "helper", runsStream: true)
        access.stream.runBy = HubRunBy(kind: "handed",
                                       device: HubPersonRef(id: "dev-phone", name: "Jo's iPhone"),
                                       forName: "Jo",
                                       givenBy: HubPersonRef(id: "dev-desk", name: "Mac"),
                                       givenAt: "2026-11-17T09:30:00Z",
                                       endsAt: "2026-11-18T09:30:00Z",
                                       gave: HubGave(helpers: 1, mods: 0, invites: 0))
        let page = hubCrewPage(state: state(runBy: "dev-phone"), access: access, me: "dev-phone", role: "helper",
                               when: when())
        #expect(page.manages)
        #expect(!page.owner)
        #expect(page.runs)
        #expect(page.groups.map(\.title) == [HubWords.Crew.groupDevices, "Helpers", "Mods"])
        #expect(page.groups.map(\.add) == [nil, .helper, .mod])
        #expect(!page.groups.contains { $0.yours })
        #expect(page.groups[0].rows[0].end == nil)
        #expect(page.groups[1].rows.map(\.title) == ["Jo's iPhone · this phone", "Robin's laptop"])
        #expect(page.groups[1].rows[0].tag == "Runs this stream")
        #expect(page.groups[1].rows[1].end?.label == HubWords.Access.remove)
        #expect(page.stream == nil)
        let session = try #require(page.session)
        #expect(session.role == "Stream session owner")
        #expect(session.line == "You run this stream until it ends.")
        #expect(session.allows ==
            "Can go live, move the stream, end the stream, hide the picture, show the picture again and "
            + "let helpers and mods in for this stream only. Can't remove devices or owners or see keys or passwords.")
        #expect(session.ends == "Until the stream ends, or tomorrow at 09:30.")
        #expect(session.giveBack == .init(
            label: "Give the stream back",
            confirm: "Give this stream back to the owners? What you let in loses access at once. "
                + "The stream keeps running."
        ))
        let early = hubCrewPage(state: state(runBy: "dev-phone"), access: nil, me: "dev-phone", role: "helper",
                                when: when())
        #expect(early.session?.allows == session.allows)
        #expect(early.groups.map(\.add) == [.helper, .mod])
        let long = try #require(hubAccessPage(access, connected: true, when: when()))
        #expect(long.running?.line == "Jo runs it, on Jo's iPhone.")
        #expect(long.running?.takeBack == nil)
        #expect(long.running?.giveBack?.label == "Give the stream back")
        let card = try #require(long.sections.first { $0.id == "yours" }?.rows.first)
        #expect(card.name == "Mac")
        #expect(card.how.isEmpty)
        #expect(card.ends.isEmpty)
        #expect(card.end == nil)
        #expect(long.sections.first { $0.id == "helpers" }?.rows[1].notes ==
            ["Let in by the stream's session owner. Ends when they stop running it."])
        var hidden = state(runBy: "dev-phone")
        hidden.session.privacy = HubPrivacy(hidden: true, generation: 2)
        #expect(hubControls(state: hidden, me: "dev-phone", role: "helper", sending: false, requested: [])
            .privacy == .hidden(generation: 2, canShow: true))
        #expect(hubControls(state: hidden, me: "dev-other", role: "helper", sending: false, requested: [])
            .privacy == .hidden(generation: 2, canShow: false))
        let other = hubCrewPage(state: state(runBy: "dev-phone"), access: nil, me: "dev-other", role: "helper",
                                when: when())
        #expect(!other.manages)
        #expect(other.session == nil)
        #expect(other.line == "Everyone in the streamer's setup.")
    }

    @Test
    func saysOnAnOwnerDeviceWhoRunsTheStreamAndWhatTakingBackEnds() {
        let phone = grant("dev-phone", name: "iPhone", role: "admin", allows: admin, can: [], person: "per-1")
        var jo = grant("dev-jo", name: "Jo's laptop", role: "helper", allows: member + ["invite.open"],
                       can: ["change", "end", "take_back"])
        jo.runsStream = true
        var access = list([phone, jo], people: [HubPerson(id: "per-1", name: "Alex", you: true)])
        access.stream.runBy = HubRunBy(kind: "handed",
                                       device: HubPersonRef(id: "dev-jo", name: "Jo's laptop"),
                                       forName: "Jo",
                                       endsAt: "2026-11-18T09:30:00Z",
                                       gave: HubGave(helpers: 1, mods: 2, invites: 0))
        let page = hubCrewPage(state: state(runBy: "dev-jo"), access: access, me: "dev-phone", role: "admin",
                               when: when())
        #expect(page.stream?.line == "Jo runs it, on Jo's laptop.")
        #expect(page.stream?.detail ==
            "Ends when the stream ends, or tomorrow at 09:30 · Let in for this stream: 1 helper and 2 mods. "
            + "They end with it.")
        #expect(page.stream?.takeBack?.confirm ==
            "Take this stream back from Jo? What they let in (1 helper and 2 mods) loses access at once. "
            + "The stream keeps running.")
        #expect(page.session == nil)
        #expect(page.ownName == "Alex")
    }

    @Test
    func readsTheHandoverFromTheStateAndWordsRefusals() throws {
        let json = """
        {"session":{"id":"s1","live":"live","program":"dev-1","privacy":{"hidden":false,"generation":0},
        "output":{"state":"live"},"run_by":{"device":"dev-2","since":"2026-11-17T09:30:00.000Z",
        "ends_at":"2026-11-18T09:30:00.000Z"}},"feeds":[],
        "devices":[{"id":"dev-2","name":"Jo's iPhone","kind":"phone","role":"helper","allowed":true,
        "online":true,"feed":true,"runs_stream":true}]}
        """
        let state = try JSONDecoder().decode(HubState.self, from: Data(json.utf8))
        #expect(state.runsStream("dev-2"))
        #expect(!state.runsStream("dev-1"))
        #expect(!state.runsStream(nil))
        #expect(state.devices[0].runsStream == true)
        #expect(HubWords.Crew.refused("too_many") ==
            "That's as many open links as one device can have. End one first.")
        #expect(HubWords.Crew.refused("second_owner_needed") == "That needs a second owner's yes.")
        #expect(HubWords.Crew.refused("last_admin") == "The last owner device can't be removed.")
        #expect(HubWords.Crew.refused("unavailable") ==
            "This hub can't make that link: its web address isn't https.")
        #expect(HubWords.Crew.refused("not_allowed") == nil)
        #expect(HubWords.Crew.takenBack("taken_back") == "The stream was taken back. You are a helper again.")
        #expect(HubWords.Crew.takenBack("returned") == "You gave the stream back.")
        #expect(HubWords.Crew.ownerAddedNew("Kim", "Kim's phone") == "Kim is now a co-owner, with Kim's phone.")
        #expect(HubWords.Crew.ownerRemovedLeft("Mac", "Kim's phone", "Kim") ==
            "Mac removed Kim's phone. Kim is no longer an owner.")
        let mac = HubParty(kind: "device", id: "dev-mac", name: "Mac", role: "admin")
        func line(_ type: String, subject: HubParty?, why: String? = nil) -> String {
            hubTrailLine(HubTrailEntry(seq: 1, at: "2026-11-17T09:00:00Z", type: type, by: mac, subject: subject,
                                       detail: HubTrailDetail(why: why)),
                         when: when())
        }
        #expect(line("access.link.ended", subject: mac) == "Mac ended its link to the web view of this list")
        #expect(line("access.link.ended", subject: HubParty(kind: "device", id: "dev-2", name: "iPhone")) ==
            "Mac ended the link to the web view of this list that iPhone made")
        #expect(line("stream.end", subject: nil, why: "restart") == "The hub restarted. The stream ended with it")
    }
}
