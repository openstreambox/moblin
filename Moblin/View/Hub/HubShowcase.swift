import notify
import SwiftUI

#if DEBUG

// Fixture states of the rig panel and the join sheet, for screenshots and
// UI checks without a hub: launch with -HubShowcase <name>. Nothing here
// connects anywhere or is stored.

private let showcaseMe = "dev-phone"
private let showcaseDesk = "dev-desk"
private let showcaseHub = "Studio hub"

private func showcaseState(live: Bool = false,
                           program: String? = nil,
                           hidden: Bool = false,
                           feed: String = "listening",
                           links: Int? = nil,
                           deskFeed: String = "checked") -> HubState
{
    let measured = feed == "checked"
    return HubState(
        session: HubSession(id: "showcase",
                            live: live ? "live" : "ready",
                            program: program,
                            privacy: HubPrivacy(hidden: hidden, generation: hidden ? 3 : 2),
                            output: HubOutput(state: live ? "live" : "off")),
        feeds: [
            HubFeed(device: showcaseMe,
                    state: feed,
                    picture: measured ? HubPicture(width: 1920, height: 1080, fps: 30) : nil,
                    black: measured || feed == "receiving" ? false : nil,
                    sound: measured ? "yes" : nil,
                    srtlaLinks: links),
            HubFeed(device: showcaseDesk, state: deskFeed, picture: nil, black: false, sound: nil, srtlaLinks: nil),
        ],
        devices: [
            HubDevice(id: showcaseMe, name: "iPhone", kind: "phone", role: "member", allowed: true, online: true,
                      feed: true),
            HubDevice(id: showcaseDesk, name: "Mac", kind: "pc", role: "admin", allowed: true, online: true,
                      feed: true),
        ]
    )
}

private func iso(_ minutes: Double) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: Date().addingTimeInterval(minutes * 60))
}

// The owner's list as the hub sends it (access.get), with times around now.
// variant: plain | coowner | handed | asked (handed, and the hub asks
// whether it goes on)
private func showcaseAccess(variant: String = "plain", live: Bool = true, hidden: Bool = false) -> HubAccess? {
    let admin = "[\"state.get\",\"stream.go_live\",\"stream.move\",\"stream.end\",\"privacy.hide\","
        + "\"privacy.show\",\"invite.open\",\"device.remove\",\"hub.recovery.get\"]"
    let member = "[\"state.get\",\"stream.go_live\",\"stream.move\",\"stream.end\",\"privacy.hide\",\"privacy.show\"]"
    let helper = "[\"state.get\",\"stream.move\",\"privacy.hide\"]"
    let session = "[\"state.get\",\"stream.go_live\",\"stream.move\",\"stream.end\",\"privacy.hide\","
        + "\"privacy.show\",\"invite.open\"]"
    let mod = "[\"mod.state\",\"privacy.hide\"]"
    let asked = variant == "asked"
    let handed = variant == "handed" || asked
    let coowner = variant == "coowner" || variant == "theirs"
    var grants = [
        """
        {"id":"dev-phone","kind":"device","name":"iPhone","for":null,"device_kind":"phone","role":"admin",
        "allows":\(admin),"state":"active","online":true,"how":"scan","given_by":{"id":"dev-desk","name":"Mac"},
        "joined_at":"\(iso(-190))","ends_at":null,"ends_with_stream":false,"carries_stream":\(live),"self":true,
        "person":{"id":"per-1","name":"\(coowner ? "Alex" : "")"},"can":["end"]}
        """,
        """
        {"id":"dev-desk","kind":"device","name":"Mac","for":null,"device_kind":"pc","role":"admin",
        "allows":\(admin),"state":"active","online":true,"how":"link","given_by":{"id":"hub","name":"Studio hub"},
        "joined_at":"\(iso(-1500))","ends_at":null,"ends_with_stream":false,"carries_stream":false,"self":false,
        "person":{"id":"per-1","name":"\(coowner ? "Alex" : "")"},"can":["end"]}
        """,
        """
        {"id":"dev-box","kind":"device","name":"Backpack","for":null,"device_kind":"box","role":"member",
        "allows":\(member),"state":"active","online":false,"how":"scan","given_by":{"id":"dev-desk","name":"Mac"},
        "joined_at":"\(iso(-1400))","ends_at":null,"ends_with_stream":false,"carries_stream":false,"self":false,
        "person":{"id":"per-1","name":""},"can":["change","end","hand"]}
        """,
        """
        {"id":"dev-kim","kind":"device","name":"Kim's laptop","for":"Kim","device_kind":"helper","role":"helper",
        "allows":\(handed ? session : helper),"state":"active","online":true,"how":"link",
        "given_by":{"id":"dev-phone","name":"iPhone"},"allowed_by":{"id":"dev-phone","name":"iPhone"},
        "allowed_at":"\(iso(-48))","joined_at":"\(iso(-50))","ends_at":null,"ends_with_stream":true,
        "carries_stream":false,"self":false,"runs_stream":\(handed),
        \(handed ? "\"limits\":{\"invite.open\":\"stream\"}," : "")
        "can":\(handed ? "[\"change\",\"end\",\"take_back\"]" : "[\"change\",\"end\",\"hand\"]")}
        """,
        """
        {"id":"mod-sam","kind":"mod","name":"Sam","for":"Sam","device_kind":null,"role":"mod","allows":\(mod),
        "state":"active","online":true,"how":"web_link","given_by":{"id":"dev-phone","name":"iPhone"},
        "given_at":"\(iso(-30))","joined_at":"\(iso(-28))","ends_at":"\(iso(690))","ends_with_stream":true,
        "carries_stream":false,"self":false,"given_by_session":false,"can":["change","end"]}
        """,
        """
        {"id":"inv-1","kind":"invite","name":"Jo","for":"Jo","device_kind":null,"role":"helper","allows":\(helper),
        "state":"open","online":false,"how":"link","given_by":{"id":"dev-phone","name":"iPhone"},
        "given_at":"\(iso(-5))","joined_at":null,"ends_at":"\(iso(115))","access_ms":null,"ends_with_stream":true,
        "carries_stream":false,"self":false,"can":["end"]}
        """,
    ]
    if variant == "theirs" {
        grants.insert("""
        {"id":"dev-wait","kind":"device","name":"Kim's iPad","for":null,"device_kind":"phone","role":"admin",
        "allows":\(admin),"state":"waiting","online":true,"how":"link","given_by":{"id":"dev-phone","name":"iPhone"},
        "joined_at":"\(iso(-1))","ends_at":null,"ends_with_stream":false,"carries_stream":false,"self":false,
        "person":{"id":"per-2","name":"Kim"},"new_owner":false,"can":["end"]}
        """, at: 0)
        grants.append("""
        {"id":"dev-kimphone","kind":"device","name":"Kim's phone","for":null,"device_kind":"phone","role":"admin",
        "allows":\(admin),"state":"active","online":true,"how":"scan","given_by":{"id":"dev-phone","name":"iPhone"},
        "joined_at":"\(iso(-900))","ends_at":null,"ends_with_stream":false,"carries_stream":false,"self":false,
        "person":{"id":"per-2","name":"Kim"},"can":["end"]}
        """)
    } else if coowner {
        grants.insert("""
        {"id":"dev-wait","kind":"device","name":"Robin's phone","for":null,"device_kind":"phone","role":"admin",
        "allows":\(admin),"state":"waiting","online":true,"how":"scan","given_by":{"id":"dev-phone","name":"iPhone"},
        "joined_at":"\(iso(-1))","ends_at":null,"ends_with_stream":false,"carries_stream":false,"self":false,
        "person":{"id":null,"name":"Robin"},"new_owner":true,"can":["allow","end"]}
        """, at: 0)
        grants.append("""
        {"id":"dev-kimphone","kind":"device","name":"Kim's phone","for":null,"device_kind":"phone","role":"admin",
        "allows":\(admin),"state":"active","online":true,"how":"scan","given_by":{"id":"dev-phone","name":"iPhone"},
        "joined_at":"\(iso(-900))","ends_at":null,"ends_with_stream":false,"carries_stream":false,"self":false,
        "person":{"id":"per-2","name":"Kim"},"can":["end"]}
        """)
    } else if !handed {
        grants.insert("""
        {"id":"dev-wait","kind":"device","name":"Robin's laptop","for":"Robin","device_kind":"helper","role":"helper",
        "allows":\(helper),"state":"waiting","online":true,"how":"link","given_by":{"id":"dev-phone","name":"iPhone"},
        "joined_at":"\(iso(-1))","ends_at":null,"ends_with_stream":true,"carries_stream":false,"self":false,
        "can":["allow","change","end"]}
        """, at: 0)
    }
    func party(_ id: String, _ name: String, _ role: String, _ kind: String = "device") -> String {
        "{\"kind\":\"\(kind)\",\"id\":\"\(id)\",\"name\":\"\(name)\",\"role\":\"\(role)\"}"
    }
    let phone = party("dev-phone", "iPhone", "admin")
    let trail = [
        hidden ? "{\"seq\":12,\"at\":\"\(iso(-1))\",\"type\":\"privacy.hide\",\"by\":\(party("mod-sam", "Sam", "mod", "mod"))}" : nil,
        handed ? "{\"seq\":11,\"at\":\"\(iso(-3))\",\"type\":\"stream.handed\",\"by\":\(phone),"
            + "\"subject\":\(party("dev-kim", "Kim's laptop", "helper")),\"detail\":{\"for\":\"Kim\"}}" : nil,
        "{\"seq\":10,\"at\":\"\(iso(-5))\",\"type\":\"invite.opened\",\"by\":\(phone),"
            + "\"subject\":\(party("inv-1", "Jo", "helper", "invite")),\"detail\":{\"via\":\"link\"}}",
        "{\"seq\":9,\"at\":\"\(iso(-20))\",\"type\":\"privacy.show\",\"by\":\(phone)}",
        "{\"seq\":8,\"at\":\"\(iso(-22))\",\"type\":\"privacy.hide\",\"by\":\(party("mod-sam", "Sam", "mod", "mod"))}",
        "{\"seq\":7,\"at\":\"\(iso(-28))\",\"type\":\"mod.joined\",\"subject\":\(party("mod-sam", "Sam", "mod", "mod"))}",
        "{\"seq\":6,\"at\":\"\(iso(-30))\",\"type\":\"mod.made\",\"by\":\(phone),"
            + "\"subject\":\(party("mod-sam", "Sam", "mod", "mod"))}",
        "{\"seq\":5,\"at\":\"\(iso(-40))\",\"type\":\"stream.move\",\"by\":\(party("dev-kim", "Kim's laptop", "helper")),"
            + "\"subject\":\(phone)}",
        "{\"seq\":4,\"at\":\"\(iso(-48))\",\"type\":\"device.allowed\",\"by\":\(phone),"
            + "\"subject\":\(party("dev-kim", "Kim's laptop", "helper"))}",
        "{\"seq\":3,\"at\":\"\(iso(-50))\",\"type\":\"device.joined\",\"by\":\(phone),"
            + "\"subject\":\(party("dev-kim", "Kim's laptop", "helper")),\"detail\":{\"via\":\"link\",\"waiting\":true}}",
        "{\"seq\":2,\"at\":\"\(iso(-55))\",\"type\":\"invite.opened\",\"by\":\(phone),"
            + "\"subject\":\(party("inv-0", "Kim", "helper", "invite")),\"detail\":{\"via\":\"link\"}}",
        "{\"seq\":1,\"at\":\"\(iso(-60))\",\"type\":\"stream.go_live\",\"by\":\(party("dev-desk", "Mac", "admin")),"
            + "\"subject\":\(party("dev-desk", "Mac", "admin"))}",
    ].compactMap { $0 }
    let people = coowner
        ? "[{\"id\":\"per-1\",\"name\":\"Alex\",\"you\":true},{\"id\":\"per-2\",\"name\":\"Kim\",\"you\":false}]"
        : "[{\"id\":\"per-1\",\"name\":\"\",\"you\":true}]"
    // A live handover ends 48 hours after the last owner's answer; an ask
    // comes after 2 hours without one.
    let runBy = handed
        ? "{\"kind\":\"handed\",\"device\":{\"id\":\"dev-kim\",\"name\":\"Kim's laptop\"},\"for\":\"Kim\","
        + "\"given_by\":{\"id\":\"dev-phone\",\"name\":\"iPhone\"},"
        + "\"given_at\":\"\(iso(asked ? -125 : -3))\",\"ends_at\":\"\(iso(asked ? 2755 : 2877))\","
        + "\"ends_why\":\"unanswered\",\"end_time\":null,\"stopped_at\":null,"
        + "\"asked_at\":\(asked ? "\"\(iso(-5))\"" : "null"),\"answered_at\":null,"
        + "\"gave\":{\"helpers\":0,\"mods\":1,\"invites\":0}}"
        : "null"
    let links = """
    [{"id":"own-1","device":{"id":"dev-desk","name":"Mac"},"state":"active","online":true,
    "made_at":"\(iso(-42))","opened_at":"\(iso(-41))","ends_at":"\(iso(18))","can":["end"]},
    {"id":"own-2","device":{"id":"dev-phone","name":"iPhone"},"state":"open","online":false,
    "made_at":"\(iso(-4))","opened_at":null,"ends_at":"\(iso(56))","can":["end"]},
    {"id":"own-3","device":{"id":"dev-desk","name":"Mac"},"state":"active","online":false,
    "made_at":"\(iso(-60))","opened_at":"\(iso(-59))","ends_at":"\(iso(30))","can":["end"]}]
    """
    let json = """
    {"hub":"Studio hub","as":{"id":"dev-phone","name":"iPhone","role":"admin","runs_stream":false,
    "person":{"id":"per-1","name":"\(coowner ? "Alex" : "")"}},
    "stream":{"session":"showcase","live":"\(live ? "live" : "ready")","hidden":\(hidden),"run_by":\(runBy)},
    "people":\(people),"can":["clear_trail"\(handed ? ",\"keep_stream\"" : "")],"owner_links":\(links),
    "grants":[\(grants.joined(separator: ","))],"trail":[\(trail.joined(separator: ","))],"trail_more":true}
    """
    return try? JSONDecoder().decode(HubAccess.self, from: Data(json.utf8))
}

private func showcaseSessionAccess() -> HubAccess? {
    let admin = "[\"state.get\",\"stream.go_live\",\"stream.move\",\"stream.end\",\"privacy.hide\","
        + "\"privacy.show\",\"invite.open\",\"device.remove\",\"hub.recovery.get\"]"
    let member = "[\"state.get\",\"stream.go_live\",\"stream.move\",\"stream.end\",\"privacy.hide\",\"privacy.show\"]"
    let helper = "[\"state.get\",\"stream.move\",\"privacy.hide\"]"
    let session = "[\"state.get\",\"stream.go_live\",\"stream.move\",\"stream.end\",\"privacy.hide\","
        + "\"privacy.show\",\"invite.open\"]"
    let mod = "[\"mod.state\",\"privacy.hide\"]"
    func card(_ id: String, _ name: String, _ kind: String, _ role: String, _ allows: String,
              carries: Bool = false) -> String
    {
        """
        {"id":"\(id)","kind":"device","name":"\(name)","for":null,"device_kind":"\(kind)","role":"\(role)",
        "allows":\(allows),"state":"active","online":true,"how":null,"given_by":null,"joined_at":null,
        "ends_at":null,"ends_with_stream":false,"carries_stream":\(carries),"self":false,"can":[]}
        """
    }
    let json = """
    {"hub":"Studio hub","as":{"id":"dev-phone","name":"Jo's iPhone","role":"helper","runs_stream":true,"person":null},
    "stream":{"session":"showcase","live":"live","hidden":false,"run_by":{"kind":"handed",
    "device":{"id":"dev-phone","name":"Jo's iPhone"},"for":"Jo","given_by":{"id":"dev-desk","name":"Mac"},
    "given_at":"\(iso(-25))","ends_at":"\(iso(1415))","gave":{"helpers":1,"mods":1,"invites":0}}},
    "people":[],"can":[],"owner_links":[],
    "grants":[\(card("dev-desk", "Mac", "pc", "admin", admin, carries: true)),
    \(card("dev-box", "Backpack", "box", "member", member)),
    {"id":"dev-phone","kind":"device","name":"Jo's iPhone","for":"Jo","device_kind":"phone","role":"helper",
    "allows":\(session),"limits":{"invite.open":"stream"},"state":"active","online":true,"how":"link",
    "given_by":{"id":"dev-desk","name":"Mac"},"allowed_by":{"id":"dev-desk","name":"Mac"},
    "joined_at":"\(iso(-26))","ends_at":null,"ends_with_stream":true,"carries_stream":false,"self":true,
    "runs_stream":true,"can":["take_back"]},
    {"id":"dev-robin","kind":"device","name":"Robin's laptop","for":"Robin","device_kind":"helper","role":"helper",
    "allows":\(helper),"state":"active","online":true,"how":"link",
    "given_by":{"id":"dev-phone","name":"Jo's iPhone"},"allowed_by":{"id":"dev-phone","name":"Jo's iPhone"},
    "joined_at":"\(iso(-12))","ends_at":null,"ends_with_stream":true,"carries_stream":false,"self":false,
    "given_by_session":true,"can":["change","end"]},
    {"id":"mod-sam","kind":"mod","name":"Sam","for":"Sam","device_kind":null,"role":"mod","allows":\(mod),
    "state":"active","online":true,"how":null,"given_by":null,"given_at":null,"joined_at":null,"ends_at":null,
    "ends_with_stream":true,"carries_stream":false,"self":false,"can":[]},
    {"id":"mod-lee","kind":"mod","name":"Lee","for":"Lee","device_kind":null,"role":"mod","allows":\(mod),
    "state":"open","online":false,"how":"web_link","given_by":{"id":"dev-phone","name":"Jo's iPhone"},
    "given_at":"\(iso(-6))","joined_at":null,"ends_at":"\(iso(714))","ends_with_stream":true,
    "carries_stream":false,"self":false,"given_by_session":true,"can":["change","end"]}],
    "trail":[
    {"seq":16,"at":"\(iso(-6))","type":"mod.made","by":{"kind":"device","id":"dev-phone","name":"Jo's iPhone",
    "role":"helper","session":true},"subject":{"kind":"mod","id":"mod-lee","name":"Lee","role":"mod"}},
    {"seq":15,"at":"\(iso(-12))","type":"device.allowed","by":{"kind":"device","id":"dev-phone",
    "name":"Jo's iPhone","role":"helper","session":true},
    "subject":{"kind":"device","id":"dev-robin","name":"Robin's laptop","role":"helper"}},
    {"seq":14,"at":"\(iso(-25))","type":"stream.handed","by":{"kind":"device","id":"dev-desk","name":"Mac",
    "role":"admin"},"subject":{"kind":"device","id":"dev-phone","name":"Jo's iPhone","role":"helper"},
    "detail":{"for":"Jo"}}],"trail_more":false}
    """
    return try? JSONDecoder().decode(HubAccess.self, from: Data(json.utf8))
}

private let showcaseHelperLink = "osb-hub://join#v=1&h=wss%3A%2F%2Fhub.example.org%2Fhub%2Fv1"
    + "&t=ABEiM0RVZneImaq7zN3u_w&fp=GutExPD1wgwE4-X9a6juTfKMUfAitOFU-7m7OqcTU7A&n=Studio+hub"

extension Model {
    // An owner device in a setup with a crew: the panel, the crew list, the
    // link forms and "Who has access".
    private func hubShowcaseOwner(_ name: String) -> Bool {
        hubShowcaseJoined()
        database.hub.role = "admin"
        hub.showcaseSending = true
        var state = showcaseState(live: true, program: showcaseMe, feed: "checked", links: 3)
        state.devices[0].role = "admin"
        state.devices.append(HubDevice(id: "dev-kim", name: "Kim's laptop", kind: "helper", role: "helper",
                                       allowed: true, online: true, feed: false))
        state.mods = [HubMod(id: "mod-sam", name: "Sam", state: "joined", expiresAt: iso(690), joinedAt: iso(-28),
                             online: true, endsWithStream: true)]
        state.invites = [HubInvite(id: "inv-1", role: "helper", via: "link", by: showcaseMe, closesAt: iso(115),
                                   rotates: false, endsWithStream: true)]
        let waiting = HubDevice(id: "dev-wait", name: "Robin's laptop", kind: "helper", role: "helper",
                                allowed: false, online: true, feed: false)
        var variant = "plain"
        var screens: [HubScreen] = []
        switch name {
        case "owner":
            hub.access = showcaseAccess(variant: "handed")
        case "owner-waiting":
            state.devices.append(waiting)
        case "owner-coowner-confirm":
            variant = "coowner"
            state.devices.append(HubDevice(id: "dev-wait", name: "Robin's phone", kind: "phone", role: "admin",
                                           allowed: false, online: true, feed: false))
            hub.accessConfirming = HubAccessConfirm(grant: "dev-wait", action: .coOwner)
        case "owner-hidden-by":
            state.session.privacy = HubPrivacy(hidden: true,
                                               generation: 4,
                                               hiddenBy: HubParty(kind: "mod", id: "mod-sam", name: "Sam", role: "mod"))
        case "member-crew":
            database.hub.role = "member"
            state.devices[0].role = "member"
        case "crew":
            state.devices.append(waiting)
            screens = [.crew]
        case "crew-coowners":
            variant = "coowner"
            state.devices.append(HubDevice(id: "dev-wait", name: "Robin's phone", kind: "phone", role: "admin",
                                           allowed: false, online: true, feed: false))
            screens = [.crew]
        case "crew-coowner-confirm":
            variant = "coowner"
            screens = [.crew]
            hub.accessConfirming = HubAccessConfirm(grant: "dev-wait", action: .coOwner)
        case "crew-handed":
            variant = "handed"
            screens = [.crew]
        case "crew-take-back":
            variant = "handed"
            screens = [.crew]
            hub.accessConfirming = HubAccessConfirm(grant: "dev-kim#stream", action: .takeBack)
        case "owner-ask":
            variant = "asked"
        case "crew-ask":
            variant = "asked"
            screens = [.crew]
        case "crew-end-time":
            variant = "handed"
            screens = [.crew]
            hub.choosingEndTime = hubStreamGrant("dev-kim")
        case "crew-kept":
            variant = "handed"
            screens = [.crew]
            hub.handoverAnswer = HubHandoverAnswer(grant: hubStreamGrant("dev-kim"), line: HubWords.Access.Ask.kept)
        case "access-ask":
            variant = "asked"
            screens = [.access]
        case "access-hand-wait", "access-hand-live":
            // Hand over on the Backpack's row: before Go live it asks how
            // long the handover may wait.
            let before = name == "access-hand-wait"
            if before {
                state.session.live = "ready"
                state.session.output = HubOutput(state: "off")
                state.session.program = nil
            }
            hub.access = showcaseAccess(variant: "plain", live: !before)
            // First in its section, so its dialog is on screen.
            if let index = hub.access?.grants.firstIndex(where: { $0.id == "dev-box" }),
               let box = hub.access?.grants.remove(at: index)
            {
                hub.access?.grants.insert(box, at: 0)
            }
            hub.handWait = .halfHour
            hub.accessConfirming = HubAccessConfirm(grant: "dev-box", action: .hand)
            screens = [.access]
        case "owner-theirs":
            variant = "theirs"
        case "crew-theirs":
            variant = "theirs"
            screens = [.crew]
        case "access-theirs":
            variant = "theirs"
            screens = [.access]
        case "make-coowner":
            hub.showcaseDraft = "Kim"
            hub.showcaseOwnName = "Alex"
            screens = [.crew, .makeCoOwner]
        case "make-coowner-known":
            variant = "coowner"
            screens = [.crew, .makeCoOwner]
        case "coowner-link":
            hub.madeLink = HubMadeLink(kind: .coOwner(known: false), name: "Kim", link: showcaseHelperLink,
                                       closesAt: iso(5))
            screens = [.crew, .makeCoOwner]
        case "owner-name":
            hub.showcaseOwnName = "Alex"
            screens = [.crew, .ownerName]
        case "make-helper-hand":
            hub.showcaseDraft = "Jo"
            hub.showcaseHand = true
            screens = [.crew, .makeHelper]
        case "helper-too-many":
            hub.showcaseDraft = "Jo"
            hub.showcaseFailure = HubWords.Crew.refused("too_many")
            screens = [.crew, .makeHelper]
        case "access-links":
            screens = [.access]
        case "access-link-end":
            screens = [.access]
            hub.accessConfirming = HubAccessConfirm(grant: "own-1", action: .end)
        case "owner-changed":
            hub.said = HubWords.Crew.ownerAddedNew("Kim", "Kim's phone")
            variant = "coowner"
        case "owner-already-hidden":
            state.session.privacy = HubPrivacy(hidden: true, generation: 4)
            makeToast(title: HubWords.Crew.alreadyHidden,
                      subTitle: String(localized: "Your privacy screen is on. Viewers don't see you."))
        case "crew-empty":
            state.devices.removeAll { $0.id == "dev-kim" }
            state.mods = []
            state.invites = []
            variant = "empty"
            screens = [.crew]
        case "crew-end-link":
            screens = [.crew]
            hub.accessConfirming = HubAccessConfirm(grant: "inv-1", action: .end)
        case "make-helper":
            hub.showcaseDraft = "Jo"
            screens = [.crew, .makeHelper]
        case "helper-link":
            hub.madeLink = HubMadeLink(kind: .helper, name: "Jo", link: showcaseHelperLink, closesAt: iso(120))
            screens = [.crew, .makeHelper]
        case "make-mod":
            hub.showcaseDraft = "Sam"
            screens = [.crew, .makeMod]
        case "mod-link":
            hub.madeLink = HubMadeLink(kind: .mod,
                                       name: "Sam",
                                       link: "https://hub.example.org/mod#v=1&t=ABEiM0RVZneImaq7zN3u_w",
                                       closesAt: iso(720))
            screens = [.crew, .makeMod]
        case "mod-refused":
            hub.showcaseDraft = "Sam"
            hub.showcaseFailure = HubWords.Crew.refused("unavailable")
            screens = [.crew, .makeMod]
        case "access":
            state.devices.append(waiting)
            screens = [.access]
        case "access-remove":
            screens = [.access]
            variant = "carrier"
            hub.accessConfirming = HubAccessConfirm(grant: "dev-desk", action: .end)
        case "access-failed":
            screens = [.access]
            variant = "handed"
            hub.accessFailedLine = HubWords.Access.failed
            hub.accessFailed = "dev-phone"
        case "access-coowner":
            variant = "coowner"
            screens = [.access]
        case "access-handed":
            variant = "handed"
            screens = [.access]
        case "access-take-back":
            variant = "handed"
            screens = [.access]
            hub.accessConfirming = HubAccessConfirm(grant: "dev-kim#stream", action: .takeBack)
        case "access-trail":
            screens = [.access]
        case "access-hidden":
            state.session.privacy = HubPrivacy(hidden: true,
                                               generation: 4,
                                               hiddenBy: HubParty(kind: "mod", id: "mod-sam", name: "Sam", role: "mod"))
            screens = [.access]
        case "access-unreachable":
            hub.connected = false
            screens = [.access]
        default:
            return false
        }
        hub.state = state
        if hub.access == nil {
            switch variant {
            case "empty":
                if var access = showcaseAccess(variant: "handed") {
                    access.grants.removeAll { $0.id != "dev-phone" && $0.id != "dev-desk" && $0.id != "dev-box" }
                    access.stream.runBy = nil
                    hub.access = access
                }
            case "carrier":
                // Viewers see the Mac here, so removing it warns first.
                if var access = showcaseAccess(variant: "handed") {
                    for index in access.grants.indices {
                        access.grants[index].carriesStream = access.grants[index].id == "dev-desk"
                    }
                    access.stream.runBy = nil
                    hub.access = access
                }
                state.session.program = showcaseDesk
                hub.state = state
            default:
                hub.access = showcaseAccess(variant: variant, hidden: state.session.privacy.hidden)
            }
        }
        // The state names the handover the list names; the screens take
        // whether it is on from the state.
        if let run = hub.access?.stream.runBy, run.kind == "handed", let device = run.device?.id {
            state.session.runBy = HubSessionRunBy(device: device,
                                                  since: run.givenAt,
                                                  endsAt: run.endsAt,
                                                  endsWhy: run.endsWhy,
                                                  endTime: run.endTime,
                                                  askedAt: run.askedAt)
            if let index = state.devices.firstIndex(where: { $0.id == device }) {
                state.devices[index].runsStream = true
            }
            hub.state = state
        }
        if showingPanel != .rig {
            toggleShowingPanel(type: .rig, panel: .rig)
        }
        hub.path = screens
        return true
    }

    private func hubShowcaseSession(_ fixture: String) -> Bool {
        // "<fixture>-crew": the same, on the crew list.
        let onCrew = fixture != "session-crew" && fixture.hasSuffix("-crew")
        let name = onCrew ? String(fixture.dropLast(5)) : fixture
        hubShowcaseJoined()
        database.hub.role = "helper"
        var state = showcaseState(live: true, program: showcaseDesk, feed: "checked", links: 2)
        state.devices[0] = HubDevice(id: showcaseMe, name: "Jo's iPhone", kind: "phone", role: "helper",
                                     allowed: true, online: true, feed: true, runsStream: true)
        state.devices.append(HubDevice(id: "dev-robin", name: "Robin's laptop", kind: "helper", role: "helper",
                                       allowed: true, online: true, feed: false))
        state.session.runBy = HubSessionRunBy(device: showcaseMe, since: iso(-25), endsAt: iso(2855),
                                              endsWhy: "unanswered")
        hub.showcaseSending = true
        var screens: [HubScreen] = []
        switch name {
        case "session-panel":
            break
        case "session-grace":
            // End stream was pressed 3 minutes ago: the grace period runs.
            state.session.live = "ended"
            state.session.output = HubOutput(state: "off")
            state.session.program = nil
            state.session.runBy = HubSessionRunBy(device: showcaseMe, since: iso(-25), endsAt: iso(12),
                                                  endsWhy: "stream", stoppedAt: iso(-3))
            hub.ending = HubEnding(endsAt: state.session.runBy!.endsAt!, why: "stream", live: false)
        case "session-ending":
            // Live, and no owner answered for nearly 48 hours.
            state.session.runBy = HubSessionRunBy(device: showcaseMe, since: iso(-2870), endsAt: iso(10),
                                                  endsWhy: "unanswered", askedAt: iso(-60))
        case "session-waiting":
            // Handed over before Go live, with 3 hours to go live.
            state.session.live = "ready"
            state.session.output = HubOutput(state: "off")
            state.session.program = nil
            state.session.runBy = HubSessionRunBy(device: showcaseMe, since: iso(-5), endsAt: iso(175),
                                                  endsWhy: "not_live", waitUntil: iso(175))
        case "session-ended-unanswered":
            state.devices[0].runsStream = false
            state.session.runBy = nil
            hub.said = HubWords.Crew.takenBack("unanswered", role: "helper")
        case "session-handed":
            hub.said = HubWords.Crew.handed("Mac")
        case "session-hidden":
            state.session.privacy = HubPrivacy(hidden: true, generation: 4)
        case "session-give-back":
            hub.accessConfirming = HubAccessConfirm(grant: hubGiveBackGrant, action: .giveBack)
        case "session-crew":
            screens = [.crew]
        case "session-make-helper":
            hub.showcaseDraft = "Robin"
            screens = [.crew, .makeHelper]
        case "session-make-mod":
            hub.showcaseDraft = "Lee"
            screens = [.crew, .makeMod]
        case "session-access":
            screens = [.access]
        case "session-taken-back":
            state.devices[0].runsStream = false
            state.session.runBy = nil
            hub.said = HubWords.Crew.takenBack("taken_back", role: "helper")
        default:
            return false
        }
        hub.state = state
        hub.access = name == "session-taken-back" || name == "session-ended-unanswered" ? nil
            : showcaseSessionAccess()
        if onCrew {
            screens = [.crew]
        }
        if showingPanel != .rig {
            toggleShowingPanel(type: .rig, panel: .rig)
        }
        hub.path = screens
        return true
    }

    func hubShowcaseStream() -> SettingsStream {
        let stream = SettingsStream(name: HubWords.Setup.streamName(showcaseHub))
        stream.url = "srtla://hub.example.org:5001"
        return stream
    }

    private func hubShowcaseJoined(connected: Bool = true) {
        let settings = SettingsHub()
        settings.name = showcaseHub
        settings.hubKey = "showcase"
        settings.deviceId = showcaseMe
        settings.role = "member"
        database.hub = settings
        hub.connected = connected
    }

    // Returns false for an unknown name.
    @discardableResult
    func hubShowcase(_ name: String) -> Bool {
        hub.showcase = true
        hub.showcaseSending = false
        hub.requested = []
        hub.pending = false
        hub.notice = nil
        hub.joinState = .none
        hub.access = nil
        hub.accessConfirming = nil
        hub.accessFailed = nil
        hub.madeLink = nil
        hub.showcaseDraft = nil
        hub.showcaseFailure = nil
        hub.showcaseHand = false
        hub.showcaseOwnName = nil
        hub.sessionTold = nil
        hub.said = nil
        hub.ending = nil
        hub.choosingEndTime = nil
        hub.handoverAnswer = nil
        hub.handWait = .halfHour
        hub.showcaseSection = nil
        hub.path = []
        database.hub = SettingsHub()
        let filled = [String(localized: "Stream to the hub, bonded"), String(localized: "Selected as your stream")]
        switch name {
        case "empty":
            break
        case "removed":
            hub.notice = .removed(hub: showcaseHub)
        case "waiting-allow":
            hubShowcaseJoined()
            hub.pending = true
        case "ready":
            hubShowcaseJoined()
            hub.state = showcaseState()
        case "connecting":
            hubShowcaseJoined()
            hub.showcaseSending = true
            hub.requested = [.connect]
            hub.state = showcaseState(feed: "receiving")
        case "connected":
            hubShowcaseJoined()
            hub.showcaseSending = true
            hub.state = showcaseState(feed: "checked", links: 2)
        case "live-desk":
            hubShowcaseJoined()
            hub.state = showcaseState(live: true, program: showcaseDesk)
        case "live-desk-connected":
            hubShowcaseJoined()
            hub.showcaseSending = true
            hub.state = showcaseState(live: true, program: showcaseDesk, feed: "checked", links: 2)
        case "move-requested":
            hubShowcaseJoined()
            hub.showcaseSending = true
            hub.requested = [.move]
            hub.state = showcaseState(live: true, program: showcaseDesk, feed: "checked", links: 2)
        case "live-phone":
            hubShowcaseJoined()
            hub.showcaseSending = true
            hub.state = showcaseState(live: true, program: showcaseMe, feed: "checked", links: 3)
        case "hide-requested":
            hubShowcaseJoined()
            hub.showcaseSending = true
            hub.requested = [.hide]
            hub.state = showcaseState(live: true, program: showcaseMe, feed: "checked", links: 3)
        case "hidden":
            hubShowcaseJoined()
            hub.showcaseSending = true
            hub.state = showcaseState(live: true, program: showcaseMe, hidden: true, feed: "checked", links: 3)
        case "show-requested":
            hubShowcaseJoined()
            hub.showcaseSending = true
            hub.requested = [.show]
            hub.state = showcaseState(live: true, program: showcaseMe, hidden: true, feed: "checked", links: 3)
        case "disconnect-requested":
            hubShowcaseJoined()
            hub.requested = [.disconnect]
            hub.state = showcaseState(live: true, program: showcaseDesk, feed: "checked", links: 2)
        case "standby":
            hubShowcaseJoined()
            hub.state = showcaseState(live: true, program: showcaseDesk, deskFeed: "lost")
        case "unreachable":
            hubShowcaseJoined(connected: false)
            hub.state = showcaseState(live: true, program: showcaseMe, feed: "checked", links: 3)
        case "join-joining":
            hub.joinState = .joining(hub: showcaseHub)
        case "join-waiting-allow":
            hub.joinState = .pending(hub: showcaseHub)
        case "join-joined":
            hubShowcaseJoined()
            hub.state = showcaseState()
            hub.joinState = .joined(hub: showcaseHub, filled: filled)
        case "join-expired":
            hub.joinState = .failed(.expired)
        case "join-unreachable":
            hub.joinState = .failed(.unreachable)
        case "join-wrong-hub":
            hub.joinState = .failed(.wrongHub)
        default:
            if hubShowcaseOwner(name) || hubShowcaseSession(name) {
                return true
            }
            hub.showcase = false
            return false
        }
        if name.hasPrefix("join-") {
            presentingHubJoin = true
        } else if showingPanel != .rig {
            toggleShowingPanel(type: .rig, panel: .rig)
        }
        return true
    }

    // The panel's own actions as Darwin notifications, for test runs on a
    // Simulator, which a script can't tap and where opening a link asks first:
    //   xcrun simctl spawn booted notifyutil -p osb.hub.debug.connect
    // "join" reads the link from Documents/hub-debug-join.txt.
    func startDebugHubActions() {
        guard !hub.debugActionsStarted else {
            return
        }
        hub.debugActionsStarted = true
        for action in ["join", "done", "panel", "connect", "disconnect", "move", "hide", "show",
                       "crew", "access", "back", "allow", "helper-form", "helper-make", "mod-form", "mod-make",
                       "link-done", "mod-end", "confirm", "showcase", "coowner-form", "coowner-make",
                       "helper-hand-form", "helper-hand-make", "take-back", "give-back", "leave"]
        {
            var token: Int32 = 0
            notify_register_dispatch("osb.hub.debug.\(action)", &token, DispatchQueue.main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.debugHubAction(action)
                }
            }
        }
    }

    private func debugHubAction(_ action: String) {
        switch action {
        case "join":
            let file = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("hub-debug-join.txt")
            if let text = try? String(contentsOf: file, encoding: .utf8),
               let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines))
            {
                handleHubUrl(url: url)
            }
        case "done":
            closeHubJoin()
        case "panel":
            toggleShowingPanel(type: .rig, panel: .rig)
        case "connect":
            hubConnect()
        case "disconnect":
            hubDisconnect()
        case "move":
            hubMoveHere()
        case "hide":
            hubHide()
        case "show":
            if case let .hidden(generation, true) = hubControlList().privacy {
                hubShowPicture(generation: generation)
            }
        default:
            debugHubCrewAction(action)
        }
    }

    // The crew's and the list's actions, for the same test runs.
    private func debugHubCrewAction(_ action: String) {
        switch action {
        case "crew":
            hub.showcaseSection = nil
            hub.path = [.crew]
        case "access":
            hub.path = [.access]
        case "back":
            hub.path = []
        case "allow":
            if let waiting = hubCrewPageNow().waiting.first(where: \.allow) {
                if waiting.confirm != nil {
                    hub.accessConfirming = HubAccessConfirm(grant: waiting.id, action: .coOwner)
                } else {
                    hubAllow(waiting.id)
                }
            }
        case "coowner-form":
            hub.showcaseDraft = "Kim"
            hub.showcaseOwnName = "Alex"
            hub.madeLink = nil
            hub.path = [.crew, .makeCoOwner]
        case "coowner-make":
            Task { @MainActor in
                _ = await hubMakeCoOwnerLink(name: "Kim", person: nil, ownName: "Alex")
                debugHubWriteLink()
            }
        case "helper-hand-form":
            hub.showcaseDraft = "Jo"
            hub.showcaseHand = true
            hub.madeLink = nil
            hub.path = [.crew, .makeHelper]
        case "helper-hand-make":
            Task { @MainActor in
                _ = await hubMakeHelperLink(name: "Jo", linkLasts: .twoHours, ends: .stream, handStream: true)
                debugHubWriteLink()
            }
        case "take-back":
            hub.showcaseSection = nil
            hub.path = [.crew]
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                if let device = self.hubCrewPageNow().stream?.device {
                    self.hub.accessConfirming = HubAccessConfirm(grant: "\(device)#stream", action: .takeBack)
                }
            }
        case "give-back":
            hub.accessConfirming = HubAccessConfirm(grant: hubGiveBackGrant, action: .giveBack)
        case "leave":
            leaveHub()
        case "helper-form":
            hub.showcaseDraft = "Kim"
            hub.madeLink = nil
            hub.path = [.crew, .makeHelper]
        case "helper-make":
            Task { @MainActor in
                _ = await hubMakeHelperLink(name: "Kim", linkLasts: .twoHours, ends: .stream)
                debugHubWriteLink()
            }
        case "mod-form":
            hub.showcaseDraft = "Sam"
            hub.madeLink = nil
            hub.path = [.crew, .makeMod]
        case "mod-make":
            Task { @MainActor in
                _ = await hubMakeModLink(name: "Sam", linkLasts: .halfDay, untilStream: true)
                debugHubWriteLink()
            }
        case "link-done":
            hubCloseMadeLink()
        case "mod-end":
            // The crew list at its Mods section, then End now on the first mod.
            hub.showcaseSection = "mods"
            hub.path = [.crew]
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if let mod = self.hub.access?.grants.first(where: { $0.kind == "mod" }) {
                    self.hub.accessConfirming = HubAccessConfirm(grant: mod.id, action: .end)
                }
            }
        case "confirm":
            if let confirming = hub.accessConfirming {
                switch confirming.action {
                case .end:
                    hubEndAccess(confirming.grant)
                case .coOwner:
                    hubAllow(confirming.grant, coOwner: true)
                case .hand:
                    hubHandStream(confirming.grant)
                case .takeBack:
                    hubTakeBackStream(confirming.grant)
                case .giveBack:
                    hubGiveBackStream()
                case .clear:
                    hubClearTrail()
                }
            }
        case "showcase":
            // Another fixture without a relaunch: "<name> [section] [YES]"
            // in Documents/hub-debug-showcase.txt.
            let file = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("hub-debug-showcase.txt")
            guard let text = try? String(contentsOf: file, encoding: .utf8) else {
                return
            }
            let words = text.split(whereSeparator: \.isWhitespace).map(String.init)
            guard let name = words.first else {
                return
            }
            // A confirm that is still up goes first, then the screens.
            hub.accessConfirming = nil
            presentingHubJoin = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                if self.showingPanel == .rig {
                    self.toggleShowingPanel(type: .rig, panel: .rig)
                }
                self.hub.path = []
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                UserDefaults.standard.set(words.count > 2 && words[2] == "YES", forKey: "HubShowcaseScroll")
                self.hubShowcase(name)
                self.hub.showcaseSection = words.count > 1 && words[1] != "none" ? words[1] : nil
            }
        default:
            break
        }
    }

    // With -HubDebugLinkFile YES the link just made is also written to
    // Documents/hub-debug-link.txt, so a test run can hand it to the
    // helper or mod it plays. Never in a release build.
    private func debugHubWriteLink() {
        guard UserDefaults.standard.bool(forKey: "HubDebugLinkFile"), let made = hub.madeLink else {
            return
        }
        let file = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("hub-debug-link.txt")
        try? made.link.write(to: file, atomically: true, encoding: .utf8)
    }

    // -HubShowcaseScroll YES opens the panel scrolled to its end.
    func hubShowcaseScrollsToEnd() -> Bool {
        hub.showcase && UserDefaults.standard.bool(forKey: "HubShowcaseScroll")
    }

    func handleDebugHubShowcase() {
        startDebugHubActions()
        guard !hub.showcase, let name = UserDefaults.standard.string(forKey: "HubShowcase") else {
            return
        }
        hubShowcase(name)
        // -HubShowcaseSection <id> opens a list at that section.
        hub.showcaseSection = UserDefaults.standard.string(forKey: "HubShowcaseSection")
    }
}

#endif
