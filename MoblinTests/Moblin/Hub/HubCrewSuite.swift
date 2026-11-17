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

private func state(runBy: String? = nil, endsAt: String? = "2026-11-18T09:30:00Z") -> HubState {
    HubState(session: HubSession(id: "s1",
                                 live: "live",
                                 program: "dev-desk",
                                 privacy: HubPrivacy(hidden: false, generation: 1),
                                 output: HubOutput(state: "live"),
                                 runBy: runBy.map {
                                     HubSessionRunBy(device: $0, since: "2026-11-17T09:30:00Z", endsAt: endsAt)
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
        #expect(page.line == HubWords.Setup.crewLine)
        #expect(page.groups.map(\.title) == ["You", "Co-owners", "Helpers", "Mods"])
        #expect(page.groups.map(\.add) == [nil, .coOwner, .helper, .mod])
        #expect(page.groups.map(\.add?.label) == [nil, "Add a co-owner", "Add a helper", "Add a mod"])
        #expect(page.groups[0].yours)
        #expect(page.groups[0].rows.map(\.title) == ["iPhone · this phone", "Backpack"])
        #expect(page.groups[0].rows[0].end == nil)
        #expect(page.groups[0].rows[1].end?.label == HubWords.Access.remove)
        #expect(page.groups[1].empty == HubWords.Setup.emptyCoOwners)
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
        #expect(session.line == "You run this stream.")
        #expect(session.allows ==
            "Can go live, move the stream, end the stream, hide the picture, show the picture again and "
            + "let helpers and mods in for this stream only. Can't remove devices or owners or see keys or passwords.")
        #expect(session.ends == "Runs while the stream is live, and ends tomorrow at 09:30 if nothing changes.")
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
        #expect(hubControls(state: hidden, me: "dev-phone", role: "helper", sending: false, requested: [],
                            now: when().now).privacy == .hidden(generation: 2, canShow: true))
        #expect(hubControls(state: hidden, me: "dev-other", role: "helper", sending: false, requested: [],
                            now: when().now).privacy == .hidden(generation: 2, canShow: false))
        let other = hubCrewPage(state: state(runBy: "dev-phone"), access: nil, me: "dev-other", role: "helper",
                                when: when())
        #expect(!other.manages)
        #expect(other.session == nil)
        #expect(other.line == HubWords.Setup.crewLineHelper)
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
            "Runs while the stream is live. Without an owner's answer it ends tomorrow at 09:30. · Let in for this "
            + "stream: 1 helper and 2 mods. They end with it.")
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
        #expect(state.runsStream("dev-2", now: when().now))
        #expect(!state.runsStream("dev-1", now: when().now))
        #expect(!state.runsStream(nil, now: when().now))
        #expect(state.devices[0].runsStream == true)
        #expect(HubWords.Crew.refused("too_many") ==
            "That's as many open links as one device can have. End one first.")
        #expect(HubWords.Crew.refused("second_owner_needed") == "That needs a second owner's yes.")
        #expect(HubWords.Crew.refused("last_admin") == "The last owner device can't be removed.")
        #expect(HubWords.Crew.refused("unavailable") ==
            "This hub can't make that link: its web address isn't https.")
        #expect(HubWords.Crew.refused("not_allowed") == nil)
        #expect(HubWords.Crew.takenBack("returned", role: "helper") == "You gave the stream back.")
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

    private func at(_ iso: String) -> HubWhen {
        var clock = when()
        clock.now = HubWhen.date(iso)!
        return clock
    }

    private func handedAccess(endsAt: String?) -> HubAccess {
        var me = grant("dev-phone", name: "Jo's iPhone", role: "helper", allows: member + ["invite.open"],
                       can: ["take_back"])
        me.isSelf = true
        me.runsStream = true
        me.limits = ["invite.open": "stream"]
        var access = list([grant("dev-desk", name: "Mac", role: "admin", allows: admin, can: []), me], people: [])
        access.asWho = HubAccessAs(id: "dev-phone", name: "Jo's iPhone", role: "helper", runsStream: true)
        access.stream.runBy = HubRunBy(kind: "handed",
                                       device: HubPersonRef(id: "dev-phone", name: "Jo's iPhone"),
                                       forName: "Jo",
                                       givenAt: "2026-11-17T08:00:00Z",
                                       endsAt: endsAt)
        return access
    }

    private func canShow(_ state: HubState, at clock: HubWhen) -> Bool {
        var hidden = state
        hidden.session.privacy = HubPrivacy(hidden: true, generation: 2)
        return hubControls(state: hidden, me: "dev-phone", role: "helper", sending: false, requested: [],
                           now: clock.now).privacy == .hidden(generation: 2, canShow: true)
    }

    @Test
    func aHandoverPastItsEndOffersNothingMoreEvenBeforeTheHubSaysSo() throws {
        // Handed until 09:00; the hub's next state hasn't come at 10:00.
        let expired = state(runBy: "dev-phone", endsAt: "2026-11-17T09:00:00Z")
        let access = handedAccess(endsAt: "2026-11-17T09:00:00Z")
        #expect(!expired.runsStream("dev-phone", now: when().now))
        #expect(hubHandoverWatch(expired, me: "dev-phone", role: "helper", now: when().now) == .ranOut)
        #expect(!canShow(expired, at: when()))
        for list in [nil, access] {
            let page = hubCrewPage(state: expired, access: list, me: "dev-phone", role: "helper", when: when())
            #expect(!page.manages)
            #expect(!page.runs)
            #expect(page.session == nil)
            #expect(page.groups.allSatisfy { $0.add == nil })
            #expect(page.line == HubWords.Setup.crewLineHelper)
            #expect(!page.groups.flatMap(\.rows).contains { $0.tag == HubWords.Crew.runs })
        }
        let accessPage = try #require(hubAccessPage(access, connected: true, when: when()))
        #expect(accessPage.running?.giveBack == nil)
        // The same state, read before its end, still offers it all.
        let before = at("2026-11-17T08:59:00Z")
        #expect(expired.runsStream("dev-phone", now: before.now))
        #expect(hubHandoverWatch(expired, me: "dev-phone", role: "helper", now: before.now)
            == .endsAt(HubWhen.date("2026-11-17T09:00:00Z")!))
        #expect(canShow(expired, at: before))
        let early = hubCrewPage(state: expired, access: access, me: "dev-phone", role: "helper", when: before)
        #expect(early.manages)
        #expect(early.session != nil)
        #expect(early.groups.map(\.add).contains(.helper))
        #expect(try #require(hubAccessPage(access, connected: true, when: before)).running?.giveBack != nil)
        // At its end exactly, it's over.
        #expect(!expired.runsStream("dev-phone", now: at("2026-11-17T09:00:00Z").now))
    }

    @Test
    func aStateThatArrivesLateDoesNotBringBackAnEndedHandover() {
        // Sent at 08:50, ending 09:00, but delivered at 09:30.
        let late = state(runBy: "dev-phone", endsAt: "2026-11-17T09:00:00Z")
        let delivered = at("2026-11-17T09:30:00Z")
        #expect(hubHandoverWatch(late, me: "dev-phone", role: "helper", now: delivered.now) == .ranOut)
        #expect(!hubCrewPage(state: late, access: nil, me: "dev-phone", role: "helper", when: delivered).manages)
        #expect(!canShow(late, at: delivered))
        // Base roles keep what they had: a member still shows the picture,
        // an owner device is never watched.
        var hidden = late
        hidden.session.privacy = HubPrivacy(hidden: true, generation: 2)
        #expect(hubControls(state: hidden, me: "dev-phone", role: "member", sending: false, requested: [],
                            now: delivered.now).privacy == .hidden(generation: 2, canShow: true))
        #expect(hubHandoverWatch(late, me: "dev-phone", role: "admin", now: delivered.now) == .none)
        #expect(hubCrewPage(state: late, access: nil, me: "dev-phone", role: "admin", when: delivered).manages)
        // Another device's handover is not this phone's.
        #expect(hubHandoverWatch(late, me: "dev-other", role: "helper", now: delivered.now) == .none)
    }

    @Test
    func aHandoverWithoutAnEndLastsUntilTheStreamEnds() {
        let open = state(runBy: "dev-phone", endsAt: nil)
        let much = at("2026-12-31T23:00:00Z")
        #expect(open.runsStream("dev-phone", now: much.now))
        #expect(hubHandoverWatch(open, me: "dev-phone", role: "helper", now: much.now) == .none)
        let page = hubCrewPage(state: open, access: handedAccess(endsAt: nil), me: "dev-phone", role: "helper",
                               when: much)
        #expect(page.manages)
        #expect(page.session?.ends == nil)
        #expect(canShow(open, at: much))
        // Who has access says nothing about an end it doesn't have.
        let facts = hubAccessPage(handedAccess(endsAt: nil), state: open, connected: true, when: much)?.running?.facts
        #expect(facts == ["Handed over by an owner device · Tuesday 17 Nov at 08:00"])
        #expect(hubAccessPage(handedAccess(endsAt: nil), connected: true, when: much)?.running?.facts == facts)
        let owner = hubCrewPage(state: state(runBy: "dev-jo", endsAt: nil), access: ownerAccess(endsAt: nil),
                                me: "dev-phone", role: "admin", when: much)
        #expect(owner.stream?.line == "Jo's laptop runs it.")
        #expect(owner.stream?.detail == nil)
        // An end the phone can't read counts as passed.
        let garbled = state(runBy: "dev-phone", endsAt: "soon")
        #expect(!garbled.runsStream("dev-phone", now: when().now))
        #expect(hubHandoverWatch(garbled, me: "dev-phone", role: "helper", now: when().now) == .ranOut)
        #expect(!hubCrewPage(state: garbled, access: nil, me: "dev-phone", role: "helper", when: when()).manages)
    }

    @Test
    func aRenewedHandoverOffersTheControlsAgainUntilItsNewEnd() {
        let ended = state(runBy: "dev-phone", endsAt: "2026-11-17T09:00:00Z")
        #expect(hubHandoverWatch(ended, me: "dev-phone", role: "helper", now: when().now) == .ranOut)
        let renewed = state(runBy: "dev-phone", endsAt: "2026-11-17T12:00:00Z")
        #expect(renewed.session.runBy != ended.session.runBy)
        #expect(hubHandoverWatch(renewed, me: "dev-phone", role: "helper", now: when().now)
            == .endsAt(HubWhen.date("2026-11-17T12:00:00Z")!))
        let page = hubCrewPage(state: renewed, access: handedAccess(endsAt: "2026-11-17T12:00:00Z"),
                               me: "dev-phone", role: "helper", when: when())
        #expect(page.manages)
        #expect(page.session?.ends == "Runs while the stream is live, and ends today at 12:00 if nothing changes.")
        #expect(canShow(renewed, at: when()))
        let noon = at("2026-11-17T12:00:00Z")
        #expect(hubHandoverWatch(renewed, me: "dev-phone", role: "helper", now: noon.now) == .ranOut)
        #expect(!hubCrewPage(state: renewed, access: nil, me: "dev-phone", role: "helper", when: noon).manages)
    }

    private func ownerAccess(endsAt: String?) -> HubAccess {
        let phone = grant("dev-phone", name: "iPhone", role: "admin", allows: admin, can: [], person: "per-1")
        var jo = grant("dev-jo", name: "Jo's laptop", role: "helper", allows: member + ["invite.open"],
                       can: ["change", "end", "take_back"])
        jo.runsStream = true
        var access = list([phone, jo], people: [HubPerson(id: "per-1", name: "Alex", you: true)])
        access.stream.runBy = HubRunBy(kind: "handed",
                                       device: HubPersonRef(id: "dev-jo", name: "Jo's laptop"),
                                       endsAt: endsAt)
        return access
    }

    @Test
    func theNewestStateDecidesWhetherTheHandoverIsStillOnWhereverItIsShown() throws {
        // The list was read when the stream had stopped: the handover would
        // end at 10:15. At 10:14:59 the stream went live again, and the
        // newest state moved the end to 19 Nov. The list is read again only
        // a moment later.
        let clock = at("2026-11-17T10:30:00Z")
        let older = "2026-11-17T10:15:00Z"
        let newer = state(runBy: "dev-phone", endsAt: "2026-11-19T10:20:00Z")
        let page = try #require(hubAccessPage(handedAccess(endsAt: older), state: newer, connected: true,
                                              when: clock))
        #expect(page.running?.giveBack != nil)
        #expect(page.running?.line == "Jo runs it, on Jo's iPhone.")
        let crew = hubCrewPage(state: newer, access: handedAccess(endsAt: older), me: "dev-phone", role: "helper",
                               when: clock)
        #expect(crew.manages)
        #expect(crew.groups.flatMap(\.rows).first { $0.id == "dev-phone" }?.tag == HubWords.Crew.runs)
        let owner = hubCrewPage(state: state(runBy: "dev-jo", endsAt: "2026-11-19T10:20:00Z"),
                                access: ownerAccess(endsAt: older), me: "dev-phone", role: "admin", when: clock)
        #expect(owner.stream?.takeBack?.label == HubWords.Access.takeBack)
        #expect(owner.groups.flatMap(\.rows).first { $0.id == "dev-jo" }?.tag == HubWords.Crew.runs)
        // And the other way: the stream stopped and the newest state ends the
        // handover at 10:15, while the list still holds the later end.
        let ended = state(runBy: "dev-phone", endsAt: older)
        let stale = try #require(hubAccessPage(handedAccess(endsAt: "2026-11-19T10:20:00Z"), state: ended,
                                               connected: true, when: clock))
        #expect(stale.running?.giveBack == nil)
        #expect(stale.running?.line == HubWords.Access.runOwners)
        let staleCrew = hubCrewPage(state: ended, access: handedAccess(endsAt: "2026-11-19T10:20:00Z"),
                                    me: "dev-phone", role: "helper", when: clock)
        #expect(!staleCrew.manages)
        let staleOwner = hubCrewPage(state: state(runBy: "dev-jo", endsAt: older),
                                     access: ownerAccess(endsAt: "2026-11-19T10:20:00Z"),
                                     me: "dev-phone", role: "admin", when: clock)
        #expect(staleOwner.stream == nil)
        #expect(!staleOwner.groups.flatMap(\.rows).contains { $0.tag == HubWords.Crew.runs })
        // A state that names nobody ends it everywhere, whatever the list says.
        let nobody = state()
        #expect(hubAccessPage(handedAccess(endsAt: nil), state: nobody, connected: true, when: clock)?.running?.line
            == HubWords.Access.runOwners)
        #expect(hubCrewPage(state: nobody, access: ownerAccess(endsAt: nil), me: "dev-phone", role: "admin",
                            when: clock).stream == nil)
    }

    @Test
    func anEndFarAheadWakesThePanelADayLaterAtMost() throws {
        let now = when().now
        let far = try #require(HubWhen.date("2700-01-01T00:00:00Z"))
        #expect(hubHandoverWakeDelay(far, now: now) == 86_400_000_000_000)
        #expect(hubHandoverWakeDelay(.distantFuture, now: now) == 86_400_000_000_000)
        #expect(hubHandoverWakeDelay(now.addingTimeInterval(7 * 86400), now: now) == 86_400_000_000_000)
        #expect(hubHandoverWakeDelay(now.addingTimeInterval(600), now: now) == 600_200_000_000)
        #expect(hubHandoverWakeDelay(now.addingTimeInterval(-600), now: now) == 200_000_000)
        let distant = state(runBy: "dev-phone", endsAt: "2700-01-01T00:00:00Z")
        #expect(hubHandoverWatch(distant, me: "dev-phone", role: "helper", now: now) == .endsAt(far))
    }

    @Test
    func anOwnerDeviceNoLongerShowsAHandoverPastItsEnd() {
        let phone = grant("dev-phone", name: "iPhone", role: "admin", allows: admin, can: [], person: "per-1")
        var jo = grant("dev-jo", name: "Jo's laptop", role: "helper", allows: member + ["invite.open"],
                       can: ["change", "end", "take_back"])
        jo.runsStream = true
        var access = list([phone, jo], people: [HubPerson(id: "per-1", name: "Alex", you: true)])
        access.stream.runBy = HubRunBy(kind: "handed",
                                       device: HubPersonRef(id: "dev-jo", name: "Jo's laptop"),
                                       endsAt: "2026-11-17T09:00:00Z")
        let page = hubCrewPage(state: state(runBy: "dev-jo", endsAt: "2026-11-17T09:00:00Z"), access: access,
                               me: "dev-phone", role: "admin", when: when())
        #expect(page.manages)
        #expect(page.stream == nil)
        #expect(!page.groups.flatMap(\.rows).contains { $0.tag == HubWords.Crew.runs })
    }

    @Test
    func takingTheStreamBackSaysWhatTheDeviceIsAgain() {
        #expect(HubWords.Crew.takenBack("taken_back", role: "helper") ==
            "The stream was taken back. You are a helper again.")
        #expect(HubWords.Crew.takenBack("taken_back", role: "member") ==
            "The stream was taken back. This device keeps what it could do before.")
        #expect(HubWords.Crew.takenBack("time", role: "member") ==
            "Your handover ran out at the end time an owner set.")
        #expect(HubWords.Crew.takenBack(nil, role: "member") == "Your handover ended.")
    }

    // The hub's handover rules as the phone shows them.

    private func run(_ device: String,
                     endsAt: String,
                     why: String,
                     endTime: String? = nil,
                     stoppedAt: String? = nil,
                     askedAt: String? = nil,
                     live: Bool = true) -> HubState
    {
        var state = state()
        state.session.live = live ? "live" : "ended"
        state.session.output = HubOutput(state: live ? "live" : "off")
        state.session.runBy = HubSessionRunBy(device: device, since: "2026-11-17T08:00:00Z", endsAt: endsAt,
                                              endsWhy: why, endTime: endTime, stoppedAt: stoppedAt,
                                              askedAt: askedAt)
        return state
    }

    private func askedAccess(askedAt: String?, endTime: String? = nil, why: String = "unanswered",
                             waiting: Bool = false) -> HubAccess
    {
        var access = ownerAccess(endsAt: "2026-11-19T08:00:00Z")
        access.can = ["clear_trail", "keep_stream"]
        access.stream.runBy?.forName = "Jo"
        access.stream.runBy?.givenAt = "2026-11-17T08:00:00Z"
        access.stream.runBy?.endsWhy = why
        access.stream.runBy?.endTime = endTime
        access.stream.runBy?.askedAt = askedAt
        if waiting {
            access.grants.insert(grant("dev-wait", name: "Robin's laptop", role: "helper", allows: helper,
                                       state: "waiting", can: ["allow", "end"]), at: 0)
        }
        return access
    }

    @Test
    func readsTheHandoverTimesTheHubSends() throws {
        let json = """
        {"session":{"id":"s1","live":"ended","program":null,"privacy":{"hidden":false,"generation":0},
        "output":{"state":"off"},"run_by":{"device":"dev-2","since":"2026-11-17T08:00:00.000Z",
        "ends_at":"2026-11-17T10:12:00.000Z","ends_why":"stream","end_time":null,
        "stopped_at":"2026-11-17T09:57:00.000Z","asked_at":null}},"feeds":[],"devices":[]}
        """
        let state = try JSONDecoder().decode(HubState.self, from: Data(json.utf8))
        let run = try #require(state.session.runBy)
        #expect(run.endsWhy == "stream")
        #expect(run.endTime == nil)
        #expect(run.stoppedAt == "2026-11-17T09:57:00.000Z")
        #expect(run.askedAt == nil)
        #expect(state.runsStream("dev-2", now: when().now))
        let kept: [String: Any] = ["kind": "handed",
                                   "device": ["id": "dev-2", "name": "Jo's iPhone"],
                                   "ends_at": "2026-11-19T10:00:00.000Z",
                                   "ends_why": "time",
                                   "end_time": "2026-11-17T13:00:00.000Z",
                                   "asked_at": NSNull(),
                                   "answered_at": "2026-11-17T10:00:00.000Z"]
        let reply = HubMessage(object: ["run_by": kept])
        let decoded = try #require(reply.decode("run_by", as: HubRunBy.self))
        #expect(decoded.endTime == "2026-11-17T13:00:00.000Z")
        #expect(decoded.answeredAt == "2026-11-17T10:00:00.000Z")
        #expect(decoded.askedAt == nil)
    }

    @Test
    func anOwnerDeviceAnswersTheHubsAskWithKeepAnEndTimeOrTakeBack() throws {
        let asked = "2026-11-17T09:55:00Z"
        let newest = run("dev-jo", endsAt: "2026-11-19T08:00:00Z", why: "unanswered", askedAt: asked)
        let page = hubCrewPage(state: newest, access: askedAccess(askedAt: asked), me: "dev-phone", role: "admin",
                               when: when())
        let stream = try #require(page.stream)
        #expect(stream.ask == HubHandoverAsk(
            title: "Jo still runs your stream",
            since: "Handed over today at 08:00.",
            line: "The stream is live. If nobody answers, it keeps running, and the handover ends Thursday 19 Nov "
                + "at 08:00 at the latest.",
            filled: true
        ))
        #expect(stream.detail == "Runs while the stream is live. Without an owner's answer it ends Thursday 19 Nov "
            + "at 08:00.")
        #expect(stream.takeBack?.label == "Take back now")
        #expect(stream.endTimes == [.hour, .threeHours, .halfDay, .day, .week])
        let full = try #require(hubAccessPage(askedAccess(askedAt: asked), state: newest, connected: true,
                                              when: when())?.running)
        #expect(full.ask == stream.ask)
        #expect(full.endTimes == stream.endTimes)
        #expect(full.takeBack?.label == "Take back now")
        #expect(full.facts.contains(stream.detail!))
        // Allow is the one filled button while someone waits.
        let busy = hubCrewPage(state: newest, access: askedAccess(askedAt: asked, waiting: true), me: "dev-phone",
                               role: "admin", when: when())
        #expect(busy.stream?.ask?.filled == false)
        #expect(hubAccessPage(askedAccess(askedAt: asked, waiting: true), state: newest, connected: true,
                              when: when())?.running?.ask?.filled == false)
        // Not live: the handover ends 15 minutes after an unanswered ask.
        let idle = run("dev-jo", endsAt: "2026-11-17T10:10:00Z", why: "unanswered", askedAt: asked, live: false)
        let quiet = hubCrewPage(state: idle, access: askedAccess(askedAt: asked), me: "dev-phone", role: "admin",
                                when: when())
        #expect(quiet.stream?.ask?.line == "The stream isn't live. If nobody answers, the handover ends today at 10:10.")
        #expect(quiet.stream?.detail ==
            "The stream isn't live. Ends today at 10:10 unless it goes live or an owner keeps it.")
        // Answered on another owner device: the newest state has no ask any
        // more, even before the list is read again.
        let answered = run("dev-jo", endsAt: "2026-11-19T10:00:00Z", why: "unanswered")
        let after = hubCrewPage(state: answered, access: askedAccess(askedAt: asked), me: "dev-phone", role: "admin",
                                when: when())
        #expect(after.stream?.ask == nil)
        #expect(after.stream?.takeBack?.label == "Take back")
        #expect(after.stream?.endTimes != nil)
        #expect(after.stream?.detail?.contains("Thursday 19 Nov at 10:00") == true)
        // A device that may not answer gets neither the ask nor end times.
        var noKeep = askedAccess(askedAt: asked)
        noKeep.can = ["clear_trail"]
        let plain = hubCrewPage(state: newest, access: noKeep, me: "dev-phone", role: "admin", when: when())
        #expect(plain.stream?.ask == nil)
        #expect(plain.stream?.endTimes == nil)
        #expect(plain.stream?.takeBack?.label == "Take back")
    }

    @Test
    func anEndTimeIsChosenFromNowAndCanBeRemoved() throws {
        let now = when().now
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        #expect(HubEndTime.hour.request(now: now)["end_time"] as? String == "2026-11-17T11:00:00.000Z")
        #expect(HubEndTime.threeHours.request(now: now)["end_time"] as? String == "2026-11-17T13:00:00.000Z")
        #expect(HubEndTime.week.request(now: now)["end_time"] as? String == "2026-11-24T09:59:00.000Z")
        #expect(HubEndTime.noEnd.request(now: now)["end_time"] is NSNull)
        #expect(HubEndTime.allCases.compactMap(\.seconds).allSatisfy { $0 >= 60 && $0 <= 7 * 86400 })
        #expect(HubEndTime.allCases.map(\.label) ==
            ["In 1 hour", "In 3 hours", "In 12 hours", "In 24 hours", "In 7 days", "No end time"])
        #expect(HubEndTime.choices(endTime: nil) == [.hour, .threeHours, .halfDay, .day, .week])
        #expect(HubEndTime.choices(endTime: "2026-11-17T13:00:00Z").last == HubEndTime.noEnd)
        // With an end time set, the facts say when, and why it ends.
        let set = run("dev-jo", endsAt: "2026-11-19T08:00:00Z", why: "unanswered", endTime: "2026-11-20T09:00:00Z")
        let page = hubCrewPage(state: set, access: askedAccess(askedAt: nil), me: "dev-phone", role: "admin",
                               when: when())
        #expect(page.stream?.detail == "Runs while the stream is live. Without an owner's answer it ends Thursday "
            + "19 Nov at 08:00. · End time: Friday 20 Nov at 09:00")
        #expect(page.stream?.endTimes?.last == HubEndTime.noEnd)
        let soon = run("dev-jo", endsAt: "2026-11-17T13:00:00Z", why: "time", endTime: "2026-11-17T13:00:00Z")
        #expect(hubCrewPage(state: soon, access: askedAccess(askedAt: nil), me: "dev-phone", role: "admin",
                            when: when()).stream?.detail == "Ends today at 13:00, the end time set for it.")
        #expect(HubWords.Access.Ask.endSet("today at 13:00") == "Ends today at 13:00.")
        #expect(HubWords.Access.Ask.kept == "Kept. You'll be asked again later.")
        #expect(HubWords.Access.EndTime.title == "When should the handover end?")
    }

    @Test
    func thePhoneThatRunsTheStreamReadsWhyAndByWhenItsHandoverEnds() {
        func line(_ state: HubState, ending: HubEnding? = nil, at clock: HubWhen? = nil) -> String? {
            hubCrewPage(state: state, access: nil, me: "dev-phone", role: "helper", ending: ending,
                        when: clock ?? when()).session?.ends
        }
        let live = run("dev-phone", endsAt: "2026-11-19T10:00:00Z", why: "unanswered")
        #expect(HubWords.Crew.youRun == "You run this stream.")
        #expect(line(live) == "Runs while the stream is live, and ends Thursday 19 Nov at 10:00 if nothing changes.")
        // The last 15 minutes: why and by when.
        #expect(line(run("dev-phone", endsAt: "2026-11-17T10:15:00Z", why: "unanswered")) ==
            "Your handover ends today at 10:15 unless an owner keeps it.")
        #expect(line(run("dev-phone", endsAt: "2026-11-17T10:15:00Z", why: "unanswered", live: false)) ==
            "Your handover ends today at 10:15 unless you go live or an owner keeps it.")
        #expect(line(run("dev-phone", endsAt: "2026-11-17T10:16:00Z", why: "unanswered")) ==
            "Runs while the stream is live, and ends today at 10:16 if nothing changes.")
        // An owner's end time is said whenever it is the reason.
        #expect(line(run("dev-phone", endsAt: "2026-11-17T18:00:00Z", why: "time")) ==
            "Your handover ends today at 18:00, the end time an owner set.")
        // The grace period after End stream.
        let stopped = run("dev-phone", endsAt: "2026-11-17T10:12:00Z", why: "stream",
                          stoppedAt: "2026-11-17T09:57:00Z", live: false)
        #expect(line(stopped) == "The stream stopped. Go live again by today at 10:12 to keep running it.")
        // The hub's warning counts while it is about the same end.
        let warned = HubEnding(endsAt: "2026-11-19T10:00:00Z", why: "unanswered", live: false)
        #expect(line(live, ending: warned) ==
            "Your handover ends Thursday 19 Nov at 10:00 unless you go live or an owner keeps it.")
        let old = HubEnding(endsAt: "2026-11-17T10:12:00Z", why: "stream", live: false)
        #expect(line(live, ending: old) ==
            "Runs while the stream is live, and ends Thursday 19 Nov at 10:00 if nothing changes.")
        // Another device's handover, or none, says nothing here.
        #expect(line(run("dev-other", endsAt: "2026-11-17T10:12:00Z", why: "stream")) == nil)
    }

    @Test
    func theGracePeriodKeepsTheControlsUntilItsEndAndGoingLiveAgainKeepsThem() {
        // End stream at 09:57; the grace period runs to 10:12.
        let stopped = run("dev-phone", endsAt: "2026-11-17T10:12:00Z", why: "stream",
                          stoppedAt: "2026-11-17T09:57:00Z", live: false)
        #expect(hubCrewPage(state: stopped, access: nil, me: "dev-phone", role: "helper", when: when()).manages)
        #expect(canShow(stopped, at: when()))
        #expect(hubHandoverWatch(stopped, me: "dev-phone", role: "helper", now: when().now)
            == .endsAt(HubWhen.date("2026-11-17T10:12:00Z")!))
        let late = at("2026-11-17T10:12:00Z")
        #expect(hubHandoverWatch(stopped, me: "dev-phone", role: "helper", now: late.now) == .ranOut)
        #expect(!hubCrewPage(state: stopped, access: nil, me: "dev-phone", role: "helper", when: late).manages)
        // Live again at 10:11: the newest state moves the end 48 hours on.
        let again = run("dev-phone", endsAt: "2026-11-19T10:11:00Z", why: "unanswered")
        #expect(hubCrewPage(state: again, access: nil, me: "dev-phone", role: "helper", when: late).manages)
        #expect(hubHandoverWatch(again, me: "dev-phone", role: "helper", now: late.now)
            == .endsAt(HubWhen.date("2026-11-19T10:11:00Z")!))
        // And every move of the end, later or earlier, is the one that holds.
        let moves = [("2026-11-17T10:12:00Z", "stream"), ("2026-11-19T10:20:00Z", "unanswered"),
                     ("2026-11-19T10:29:00Z", "unanswered"), ("2026-11-17T10:45:00Z", "stream")]
        for (endsAt, why) in moves {
            let state = run("dev-phone", endsAt: endsAt, why: why)
            #expect(hubHandoverWatch(state, me: "dev-phone", role: "helper", now: when().now)
                == .endsAt(HubWhen.date(endsAt)!))
            #expect(canShow(state, at: when()))
        }
    }

    @Test
    func theWordsForAHandoverThatEndedFollowTheHub() {
        #expect(HubWords.Crew.takenBack("stream", role: "helper") ==
            "The stream stayed stopped, so your handover ended. What you let in has ended too.")
        #expect(HubWords.Crew.takenBack("time", role: "helper") == "Your handover ran out at the end time an owner set.")
        #expect(HubWords.Crew.takenBack("unanswered", role: "member") ==
            "No owner kept your handover, so it ended. What you let in has ended too.")
        #expect(HubWords.Access.noteRuns ==
            "Runs this stream. That ends soon after the stream stops, and so does everything they let in.")
        #expect(HubWords.Crew.handStreamHint.hasSuffix("It ends soon after the stream stops, or when you take it back."))
        #expect(HubWords.Access.confirmHandOver("Jo").hasSuffix(
            "It ends soon after the stream stops, or when you take it back."))
        let mac = HubParty(kind: "device", id: "dev-mac", name: "Mac", role: "admin")
        let jo = HubParty(kind: "device", id: "dev-jo", name: "Jo's laptop", role: "helper")
        func line(_ type: String, _ detail: HubTrailDetail) -> String {
            hubTrailLine(HubTrailEntry(seq: 1, at: "2026-11-17T09:00:00Z", type: type, by: mac, subject: jo,
                                       detail: detail),
                         when: when())
        }
        var kept = HubTrailDetail()
        #expect(line("stream.kept", kept) == "Mac kept Jo's laptop's handover")
        kept.endTime = "2026-11-17T13:00:00Z"
        #expect(line("stream.kept", kept) == "Mac kept Jo's laptop's handover, until today at 13:00")
        #expect(line("stream.taken_back", HubTrailDetail(why: "unanswered")) ==
            "Jo's laptop's handover ended: no owner kept it")
        #expect(line("stream.taken_back", HubTrailDetail(why: "stream")) ==
            "Jo's laptop's handover ended: the stream stayed stopped")
        #expect(line("stream.taken_back", HubTrailDetail(why: "time")) == "Jo's laptop's handover ended at its end time")
    }

    // What the reference hub sent through one handover, recorded on a
    // loopback hub with a test clock: handed at 18:00 and live, asked at
    // 20:01, kept with an end time, End stream, and the grace period ran out.
    private func hubState(_ runBy: String, live: String = "live") -> HubState {
        let json = #"{"session":{"id":"s1","live":"\#(live)","program":"dev-phone","privacy":{"hidden":false,"#
            + #""generation":0,"hidden_by":null},"output":{"state":"\#(live == "live" ? "live" : "off")"},"#
            + #""run_by":\#(runBy)},"feeds":[],"devices":[]}"#
        return try! JSONDecoder().decode(HubState.self, from: Data(json.utf8))
    }

    @Test
    func followsWhatTheReferenceHubSendsThroughAHandover() throws {
        let asked = hubState(#"{"device":"dev-jo","since":"2026-11-17T18:00:00.000Z","ends_at":"2026-11-19T18:00:00.000Z","ends_why":"unanswered","end_time":null,"stopped_at":null,"asked_at":"2026-11-17T20:01:00.000Z"}"#)
        let access = try JSONDecoder().decode(HubAccess.self, from: Data(
            #"""
            {"hub":"Test hub","as":{"id":"dev-mac","name":"Mac","role":"admin","runs_stream":false,"person":{"id":"per-dfab31e712d4",
            "name":""}},"people":[{"id":"per-dfab31e712d4","name":"","you":true}],"stream":{"session":"s1",
            "live":"live","hidden":false,"run_by":{"kind":"handed","device":{"id":"dev-jo","name":"Jo's laptop"},
            "for":null,"given_by":{"id":"dev-mac","name":"Mac"},"given_at":"2026-11-17T18:00:00.000Z","ends_at":"2026-11-19T18:00:00.000Z",
            "ends_why":"unanswered","end_time":null,"stopped_at":null,"asked_at":"2026-11-17T20:01:00.000Z",
            "answered_at":"2026-11-17T18:00:00.000Z","gave":{"helpers":0,"mods":0,"invites":0}}},"owner_links":[],
            "can":["clear_trail","keep_stream"],"grants":[{"id":"dev-mac","kind":"device","name":"Mac","for":null,
            "device_kind":"pc","role":"admin","person":{"id":"per-dfab31e712d4","name":""},"new_owner":false,
            "runs_stream":false,"hands_stream":false,"given_by_session":false,"allows":["hub.move","hub.host.pair",
            "hub.host.unpair","hub.owner.get","hub.owner.set","hub.takeover","hub.recovery.get","relay.report",
            "state.get","invite.open","invite.close","device.name","device.allow","device.remove","feed.connect",
            "stream.go_live","stream.move","stream.end","stream.hand","stream.keep","stream.take_back","privacy.hide",
            "privacy.show","status.publish","remote.control","message.send","mod.open","mod.remove","owner.name",
            "access.get","access.end","access.change","access.link","access.trail.clear"],"limits":{},"state":"active",
            "online":true,"how":"scan","given_by":{"id":"hub","name":"The hub"},"given_at":null,"allowed_by":null,
            "allowed_at":null,"joined_at":"2026-11-17T14:39:46.812Z","ends_at":null,"ends_with_stream":false,
            "carries_stream":false,"self":true,"can":[]},{"id":"dev-phone","kind":"device","name":"iPhone",
            "for":null,"device_kind":"phone","role":"member","person":{"id":"per-dfab31e712d4","name":""},
            "new_owner":false,"runs_stream":false,"hands_stream":false,"given_by_session":false,"allows":["relay.report",
            "state.get","device.name","feed.connect","stream.go_live","stream.move","stream.end","privacy.hide",
            "privacy.show","status.publish","remote.control","message.send"],"limits":{},"state":"active",
            "online":true,"how":"scan","given_by":{"id":"dev-mac","name":"Mac"},"given_at":null,"allowed_by":null,
            "allowed_at":null,"joined_at":"2026-11-17T14:39:46.820Z","ends_at":null,"ends_with_stream":false,
            "carries_stream":true,"self":false,"can":["change","end","hand"]},{"id":"dev-jo","kind":"device",
            "name":"Jo's laptop","for":null,"device_kind":"pc","role":"helper","person":null,"new_owner":false,
            "runs_stream":true,"hands_stream":false,"given_by_session":false,"allows":["state.get","invite.open",
            "invite.close","device.name","device.allow","feed.connect","stream.go_live","stream.move","stream.end",
            "stream.take_back","privacy.hide","privacy.show","status.publish","message.send","mod.open",
            "mod.remove","access.get","access.end","access.change"],"limits":{"invite.open":"stream","mod.open":"stream",
            "invite.close":"own","device.allow":"own","mod.remove":"own","access.get":"stream","access.end":"own",
            "access.change":"own"},"state":"active","online":true,"how":"scan","given_by":{"id":"dev-mac",
            "name":"Mac"},"given_at":null,"allowed_by":null,"allowed_at":null,"joined_at":"2026-11-17T14:39:46.826Z",
            "ends_at":null,"ends_with_stream":false,"carries_stream":false,"self":false,"can":["change",
            "end","take_back"]}],"reads_trail":true,"trail":[{"seq":7,"at":"2026-11-17T18:00:00.000Z","session":"s1",
            "type":"stream.go_live","by":{"kind":"device","id":"dev-jo","name":"Jo's laptop","role":"helper",
            "session":true,"giver":"dev-mac"},"subject":{"kind":"device","id":"dev-phone","name":"iPhone",
            "role":"member","giver":"dev-mac"}},{"seq":6,"at":"2026-11-17T18:00:00.000Z","session":"s1",
            "type":"stream.handed","by":{"kind":"device","id":"dev-mac","name":"Mac","role":"admin"},"subject":{"kind":"device",
            "id":"dev-jo","name":"Jo's laptop","role":"helper","session":true,"giver":"dev-mac"},"detail":{"ends_at":"2026-11-17T20:15:00.000Z",
            "end_time":null}}],"trail_more":true}
            """#.utf8))
        let clock = at("2026-11-17T20:01:30Z")
        let owner = hubCrewPage(state: asked, access: access, me: "dev-mac", role: "admin", when: clock)
        #expect(owner.stream?.ask?.title == "Jo's laptop still runs your stream")
        #expect(owner.stream?.ask?.line ==
            "The stream is live. If nobody answers, it keeps running, and the handover ends Thursday 19 Nov at "
            + "18:00 at the latest.")
        #expect(owner.stream?.endTimes == [.hour, .threeHours, .halfDay, .day, .week])
        #expect(hubAccessPage(access, state: asked, connected: true, when: clock)?.running?.ask == owner.stream?.ask)
        let ask = HubMessage(object: try #require(try JSONSerialization.jsonObject(with: Data(
            #"{"type":"stream.ask","device":{"id":"dev-jo","name":"Jo's laptop"},"for":null,"given_at":"2026-11-17T18:00:00.000Z","live":true,"asks":1,"ends_at":"2026-11-19T18:00:00.000Z","ends_why":"unanswered","end_time":null}"#.utf8)) as? [String: Any]))
        #expect(ask.decode("device", as: HubPersonRef.self)?.name == "Jo's laptop")
        #expect(ask.bool("live") == true)
        // Keep with an end time: the reply and the next state.
        let kept = HubMessage(object: try #require(try JSONSerialization.jsonObject(with: Data(
            #"{"run_by":{"kind":"handed","device":{"id":"dev-jo","name":"Jo's laptop"},"for":null,"given_by":{"id":"dev-mac","name":"Mac"},"given_at":"2026-11-17T18:00:00.000Z","ends_at":"2026-11-17T23:01:00.000Z","ends_why":"time","end_time":"2026-11-17T23:01:00.000Z","stopped_at":null,"asked_at":null,"answered_at":"2026-11-17T20:01:00.000Z","gave":{"helpers":0,"mods":0,"invites":0}}}"#.utf8)) as? [String: Any]))
        #expect(kept.decode("run_by", as: HubRunBy.self)?.endTime == "2026-11-17T23:01:00.000Z")
        let endTime = hubState(#"{"device":"dev-jo","since":"2026-11-17T18:00:00.000Z","ends_at":"2026-11-17T23:01:00.000Z","ends_why":"time","end_time":"2026-11-17T23:01:00.000Z","stopped_at":null,"asked_at":null}"#)
        #expect(hubCrewPage(state: endTime, access: nil, me: "dev-jo", role: "helper", when: clock).session?.ends ==
            "Your handover ends today at 23:01, the end time an owner set.")
        // End stream: the grace period, and the hub's warning at once.
        let stopped = hubState(#"{"device":"dev-jo","since":"2026-11-17T18:00:00.000Z","ends_at":"2026-11-17T20:16:00.000Z","ends_why":"stream","end_time":null,"stopped_at":"2026-11-17T20:01:00.000Z","asked_at":null}"#, live: "ended")
        let warning = try #require(try JSONSerialization.jsonObject(with: Data(
            #"{"type":"stream.ending","ends_at":"2026-11-17T20:16:00.000Z","why":"stream","live":false}"#.utf8)) as? [String: Any])
        let ending = HubEnding(endsAt: try #require(warning["ends_at"] as? String), why: warning["why"] as? String,
                               live: warning["live"] as? Bool == true)
        let grace = at("2026-11-17T20:02:00Z")
        let session = hubCrewPage(state: stopped, access: nil, me: "dev-jo", role: "helper", ending: ending,
                                  when: grace)
        #expect(session.manages)
        #expect(session.session?.ends == "The stream stopped. Go live again by today at 20:16 to keep running it.")
        #expect(hubHandoverWatch(stopped, me: "dev-jo", role: "helper", now: at("2026-11-17T20:16:00Z").now)
            == .ranOut)
        let taken = try #require(try JSONSerialization.jsonObject(with: Data(#"{"type":"stream.taken_back","why":"stream"}"#.utf8)) as? [String: Any])
        #expect(HubWords.Crew.takenBack(taken["why"] as? String, role: "helper")
            == "The stream stayed stopped, so your handover ended. What you let in has ended too.")
        // The owners' trail words every line the hub wrote about it.
        let trail = try JSONDecoder().decode([HubTrailEntry].self, from: Data(
            #"""
            [{"seq":12,"at":"2026-11-17T20:18:00.000Z","session":"s1","type":"stream.taken_back","by":{"kind":"hub",
            "id":"hub","name":"The hub"},"subject":{"kind":"device","id":"dev-jo","name":"Jo's laptop","role":"helper",
            "giver":"dev-mac"},"detail":{"why":"stream","ended":{"helpers":0,"mods":0,"invites":0}}},{"seq":11,
            "at":"2026-11-17T20:01:00.000Z","session":"s1","type":"stream.end","by":{"kind":"device","id":"dev-jo",
            "name":"Jo's laptop","role":"helper","session":true,"giver":"dev-mac"},"subject":null},{"seq":10,
            "at":"2026-11-17T20:01:00.000Z","session":"s1","type":"stream.kept","by":{"kind":"device","id":"dev-mac",
            "name":"Mac","role":"admin"},"subject":{"kind":"device","id":"dev-jo","name":"Jo's laptop","role":"helper",
            "session":true,"giver":"dev-mac"},"detail":{"end_time":null,"asks":1}},{"seq":9,"at":"2026-11-17T20:01:00.000Z",
            "session":"s1","type":"stream.kept","by":{"kind":"device","id":"dev-mac","name":"Mac","role":"admin"},
            "subject":{"kind":"device","id":"dev-jo","name":"Jo's laptop","role":"helper","session":true,
            "giver":"dev-mac"},"detail":{"end_time":"2026-11-17T23:01:00.000Z","asks":1}},{"seq":8,"at":"2026-11-17T20:01:00.000Z",
            "session":"s1","type":"stream.kept","by":{"kind":"device","id":"dev-mac","name":"Mac","role":"admin"},
            "subject":{"kind":"device","id":"dev-jo","name":"Jo's laptop","role":"helper","session":true,
            "giver":"dev-mac"},"detail":{"end_time":null,"asks":1}}]
            """#.utf8))
        #expect(trail.map { hubTrailLine($0, when: clock) } == [
            "Jo's laptop's handover ended: the stream stayed stopped",
            "Jo's laptop (session owner) ended the stream",
            "Mac kept Jo's laptop's handover",
            "Mac kept Jo's laptop's handover, until today at 23:01",
            "Mac kept Jo's laptop's handover",
        ])
    }

    // Handed over while not live, the handover waits for Go live as
    // long as the owner chose (30 minutes unless another time is picked).
    // The states are what the reference hub sent: handed at 18:00, 3 hours
    // picked.

    @Test
    func handingOverBeforeGoLiveAsksHowLongItMayWaitThirtyMinutesFirst() throws {
        #expect(HubWait.allCases.first == .halfHour)
        #expect(HubWait.allCases.map(\.milliseconds) ==
            [1_800_000, 3_600_000, 10_800_000, 43_200_000, 86_400_000, 604_800_000])
        #expect(HubWait.allCases.map(\.label) ==
            ["30 minutes", "1 hour", "3 hours", "12 hours", "24 hours", "7 days"])
        #expect(HubWait.allCases.allSatisfy { $0.milliseconds >= 60000 && $0.milliseconds <= 7 * 86_400_000 })
        #expect(hubHandRequest("dev-box", wait: nil) as NSDictionary == ["device": "dev-box"] as NSDictionary)
        #expect(hubHandRequest("dev-box", wait: .halfHour) as NSDictionary
            == ["device": "dev-box", "wait_ms": 1_800_000] as NSDictionary)
        #expect(hubHandRequest("dev-box", wait: .threeHours) as NSDictionary
            == ["device": "dev-box", "wait_ms": 10_800_000] as NSDictionary)
        #expect(HubWords.Access.Wait.title == "How long may it wait for the stream to go live?")
        // Hand over asks for the wait only while the stream isn't live, as the
        // newest state says.
        var box = grant("dev-box", name: "Backpack", role: "member", allows: member, can: ["change", "end", "hand"])
        box.person = HubPersonRef(id: "per-1", name: "Alex")
        let phone = grant("dev-phone", name: "iPhone", role: "admin", allows: admin, can: [], person: "per-1")
        var ready = list([phone, box], people: [HubPerson(id: "per-1", name: "Alex", you: true)])
        ready.stream.live = "ready"
        func handRow(_ access: HubAccess, _ state: HubState?) throws -> HubAccessRow {
            try #require(hubAccessPage(access, state: state, connected: true, when: when())?.sections
                .flatMap(\.rows).first { $0.hand != nil })
        }
        var idle = state()
        idle.session.live = "ready"
        idle.session.output = HubOutput(state: "off")
        #expect(try handRow(ready, idle).handWaits)
        #expect(try handRow(ready, nil).handWaits)
        #expect(try !handRow(ready, state()).handWaits)
        var live = ready
        live.stream.live = "live"
        #expect(try !handRow(live, nil).handWaits)
    }

    @Test
    func aHandoverWaitingForGoLiveSaysByWhenToEveryone() throws {
        let waiting = hubState(#"{"device":"dev-jo","since":"2026-11-17T18:00:00.000Z","ends_at":"2026-11-17T21:00:00.000Z","ends_why":"not_live","end_time":null,"stopped_at":null,"wait_until":"2026-11-17T21:00:00.000Z","asked_at":null}"#,
                               live: "ready")
        #expect(waiting.session.runBy?.waitUntil == "2026-11-17T21:00:00.000Z")
        let clock = at("2026-11-17T18:01:00Z")
        // The person it was handed to: the whole wait says by when.
        let session = hubCrewPage(state: waiting, access: nil, me: "dev-jo", role: "helper", when: clock)
        #expect(session.manages)
        #expect(session.session?.line == "You run this stream.")
        #expect(session.session?.ends == "Go live by today at 21:00 to keep running this stream.")
        let warned = HubEnding(endsAt: "2026-11-17T21:00:00.000Z", why: "not_live", live: false)
        #expect(hubCrewPage(state: waiting, access: nil, me: "dev-jo", role: "helper", ending: warned,
                            when: at("2026-11-17T20:46:00Z")).session?.ends
            == "Go live by today at 21:00 to keep running this stream.")
        #expect(hubHandoverWatch(waiting, me: "dev-jo", role: "helper", now: clock.now)
            == .endsAt(HubWhen.date("2026-11-17T21:00:00.000Z")!))
        #expect(hubHandoverWatch(waiting, me: "dev-jo", role: "helper", now: at("2026-11-17T21:00:00Z").now)
            == .ranOut)
        #expect(HubWords.Crew.takenBack("not_live", role: "helper") ==
            "The stream didn't go live in time, so your handover ended. What you let in has ended too.")
        // An owner device: why and until when, and nobody is asked.
        var access = ownerAccess(endsAt: "2026-11-17T21:00:00.000Z")
        access.can = ["clear_trail", "keep_stream"]
        access.stream.live = "ready"
        access.stream.runBy?.endsWhy = "not_live"
        access.stream.runBy?.waitUntil = "2026-11-17T21:00:00.000Z"
        let owner = hubCrewPage(state: hubState(#"{"device":"dev-jo","since":"2026-11-17T18:00:00.000Z","ends_at":"2026-11-17T21:00:00.000Z","ends_why":"not_live","end_time":null,"stopped_at":null,"wait_until":"2026-11-17T21:00:00.000Z","asked_at":null}"#,
                                                live: "ready"),
                                access: access, me: "dev-phone", role: "admin", when: clock)
        #expect(owner.stream?.detail == "Waiting for the stream to go live. Ends today at 21:00 if it doesn't.")
        #expect(owner.stream?.ask == nil)
        #expect(owner.stream?.endTimes != nil)
        let jo = HubParty(kind: "device", id: "dev-jo", name: "Jo's laptop", role: "helper")
        #expect(hubTrailLine(HubTrailEntry(seq: 1, at: "2026-11-17T21:00:00Z", type: "stream.taken_back",
                                           by: HubParty(kind: "hub", id: "hub", name: "The hub"), subject: jo,
                                           detail: HubTrailDetail(why: "not_live")),
                             when: clock) == "Jo's laptop's handover ended: the stream didn't go live in time")
        // Live in time: the next state has no wait, and the usual rules hold.
        let liveNow = hubState(#"{"device":"dev-jo","since":"2026-11-17T18:00:00.000Z","ends_at":"2026-11-19T18:40:00.000Z","ends_why":"unanswered","end_time":null,"stopped_at":null,"wait_until":null,"asked_at":null}"#)
        #expect(hubCrewPage(state: liveNow, access: nil, me: "dev-jo", role: "helper",
                            when: at("2026-11-17T18:40:00Z")).session?.ends
            == "Runs while the stream is live, and ends Thursday 19 Nov at 18:40 if nothing changes.")
    }

    @Test
    func onlyTheBrandBuildSaysSetup() {
        let words = [
            HubWords.Setup.panelTitle,
            SettingsQuickButtonType.rig.toString(),
            HubWords.Setup.yours,
            HubWords.Setup.joinTitle,
            HubWords.Setup.waitingLine,
            HubWords.Setup.setBy,
            HubWords.Setup.leave,
            HubWords.Setup.leaveLine,
            HubWords.Setup.leaveHint,
            HubWords.Setup.settingsGone,
            HubWords.Setup.notASetupCode,
            HubWords.Setup.cantJoinWhileStreaming,
            HubWords.Setup.sentLink,
            HubWords.Setup.joinHint,
            HubWords.Setup.pendingHint,
            HubWords.Setup.opensPanel,
            HubWords.Setup.streamName("Studio hub"),
            HubWords.Setup.statusLabel("Connected"),
            HubWords.Setup.crewLine,
            HubWords.Setup.crewLineHelper,
            HubWords.Setup.emptyCoOwners,
            HubWords.Setup.coOwnerLine,
        ]
        if HubWords.Setup.brand {
            #expect(words == [
                "Setup",
                "Setup",
                "Your setup",
                "Join your setup",
                "Someone in the setup has to allow this device.",
                "Set by your setup",
                "Leave this setup",
                "The stream settings from the setup are removed from this phone.",
                "Nothing to type or change. Leaving the setup removes it from this phone.",
                "Its stream settings from the setup are gone.",
                "This code isn't from a setup's hub",
                "Can't join a setup while streaming or recording",
                "Or tap the link in the message someone in the setup sent you.",
                "Nothing to type. The code is a one-time ticket, and your setup fills in this phone's stream settings.",
                "The link was sent, not scanned off the setup's own screen, so someone in the setup confirms it's "
                    + "you. You can close this; the setup panel shows when you're in.",
                "Opens the setup panel",
                "Setup: Studio hub",
                "Setup: Connected",
                "Everyone and everything in your streaming setup. Each device has its own key.",
                "Everyone in the streamer's setup.",
                "Nobody else owns this setup.",
                "For someone who shares this setup for good, like a housemate. A co-owner can do everything you "
                    + "can, including removing your devices.",
            ])
        } else {
            // The stock build keeps the words it had before.
            #expect(words == [
                "Rig",
                "Rig",
                "Your rig",
                "Join your rig",
                "Someone on the rig has to allow this device.",
                "Set by your rig",
                "Leave this rig",
                "The stream settings from the rig are removed from this phone.",
                "Nothing to type or change. Leaving the rig removes it from this phone.",
                "Its stream settings from the rig are gone.",
                "This code isn't from a rig hub",
                "Can't join a rig while streaming or recording",
                "Or tap the link in the message someone on the rig sent you.",
                "Nothing to type. The code is a one-time ticket, and your rig fills in this phone's stream settings.",
                "The link was sent, not scanned off the rig's own screen, so someone on the rig confirms it's you. "
                    + "You can close this; the rig panel shows when you're in.",
                "Opens the rig panel",
                "Rig: Studio hub",
                "Rig: Connected",
                "Everyone and everything on your rig. Each device has its own key.",
                "Everyone on the streamer's rig.",
                "Nobody else owns this rig.",
                "For someone who shares this rig for good, like a housemate. A co-owner can do everything you "
                    + "can, including removing your devices.",
            ])
        }
    }

    @Test
    func anOwnersEndTimeWhileWaitingIsNotTheWait() {
        let state = hubState(#"{"device":"dev-jo","since":"2026-11-17T18:00:00.000Z","ends_at":"2026-11-17T19:05:00.000Z","ends_why":"time","end_time":"2026-11-17T19:05:00.000Z","stopped_at":null,"wait_until":"2026-11-24T18:00:00.000Z","asked_at":null}"#,
                             live: "ready")
        let page = hubCrewPage(state: state, access: nil, me: "dev-jo", role: "helper", when: at("2026-11-17T18:06:00Z"))
        #expect(page.session?.ends == "Your handover ends today at 19:05, the end time an owner set.")
    }

    @Test
    func anAskWithoutAnEndSaysNone() {
        let clock = at("2026-11-17T18:06:00Z")
        #expect(HubWords.Access.Ask.line(live: true, endsAt: nil, when: clock)
            == "The stream is live. If nobody answers, it keeps running.")
        #expect(HubWords.Access.Ask.line(live: false, endsAt: nil, when: clock) == "The stream isn't live.")
        #expect(HubWords.Access.Ask.line(live: false, endsAt: "2026-11-17T21:00:00.000Z", when: clock)
            == "The stream isn't live. If nobody answers, the handover ends today at 21:00.")
    }
}
