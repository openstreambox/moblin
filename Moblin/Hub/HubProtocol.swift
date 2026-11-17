import Foundation

// The messages of the osb-hub/1 protocol (section 4) that this
// phone reads, and the status and controls it shows. Only fields the hub
// reports are shown; a missing measurement is left out or reads "can't say".

struct HubPicture: Codable, Equatable {
    var width: Int
    var height: Int
    var fps: Double
}

struct HubFeed: Codable, Equatable {
    var device: String
    // idle | listening | receiving | checked | lost
    var state: String
    var picture: HubPicture?
    var black: Bool?
    // yes | silent | none
    var sound: String?
    var srtlaLinks: Int?

    enum CodingKeys: String, CodingKey {
        case device
        case state
        case picture
        case black
        case sound
        case srtlaLinks = "srtla_links"
    }
}

struct HubDevice: Codable, Equatable {
    var id: String
    var name: String
    var kind: String
    var role: String
    var allowed: Bool
    var online: Bool?
    var feed: Bool?
}

struct HubPrivacy: Codable, Equatable {
    var hidden: Bool
    var generation: Int
    // Who asked for HIDE, while it is on. The name is the one at the time.
    var hiddenBy: HubParty?

    enum CodingKeys: String, CodingKey {
        case hidden
        case generation
        case hiddenBy = "hidden_by"
    }
}

struct HubOutput: Codable, Equatable {
    // off | starting | live | failed
    var state: String
}

struct HubSession: Codable, Equatable {
    var id: String
    // ready | live | ended
    var live: String
    var program: String?
    var privacy: HubPrivacy
    var output: HubOutput?
}

struct HubState: Codable, Equatable {
    var session: HubSession
    var feeds: [HubFeed]
    var devices: [HubDevice]
    // Open invites and mod links, without their tickets.
    var invites: [HubInvite]?
    var mods: [HubMod]?

    func feed(_ device: String) -> HubFeed? {
        feeds.first { $0.device == device }
    }

    func device(_ id: String) -> HubDevice? {
        devices.first { $0.id == id }
    }

    // Live means the hub's output is live: the platform shows the stream.
    var isLive: Bool {
        session.output?.state == "live" || (session.output == nil && session.live == "live")
    }
}

struct HubProvision: Codable, Equatable {
    struct Srt: Codable, Equatable {
        var host: String
        var port: Int
        var url: String
    }

    // Not sent by the reference hub yet: a Moblin remote-control assistant
    // the hub (or a device behind it) runs for this phone.
    struct RemoteControl: Codable, Equatable {
        var url: String
        var password: String
    }

    var srt: Srt
    var srtla: Srt?
    var remoteControl: RemoteControl?

    enum CodingKeys: String, CodingKey {
        case srt
        case srtla
        case remoteControl = "remote_control"
    }
}

struct HubInfo: Codable, Equatable {
    var name: String
    var fingerprint: String
}

struct HubRequestError: Error, Equatable {
    let code: String
    let message: String
}

// A decoded transport message: the raw object, with typed views of the
// fields this client reads.
struct HubMessage {
    let object: [String: Any]

    init(object: [String: Any]) {
        self.object = object
    }

    init(data: Data) throws {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw HubRequestError(code: "invalid", message: "not a JSON object")
        }
        self.object = object
    }

    var type: String {
        object["type"] as? String ?? ""
    }

    var id: Int? {
        (object["id"] as? NSNumber)?.intValue
    }

    var ok: Bool {
        object["ok"] as? Bool ?? false
    }

    var error: HubRequestError {
        let error = object["error"] as? [String: Any]
        return HubRequestError(code: error?["code"] as? String ?? "failed",
                               message: error?["message"] as? String ?? "")
    }

    func string(_ key: String) -> String? {
        object[key] as? String
    }

    func bool(_ key: String) -> Bool? {
        object[key] as? Bool
    }

    func int(_ key: String) -> Int? {
        (object[key] as? NSNumber)?.intValue
    }

    func decode<T: Decodable>(_ key: String, as _: T.Type) -> T? {
        guard let value = object[key], !(value is NSNull),
              let data = try? JSONSerialization.data(withJSONObject: value)
        else {
            return nil
        }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    // The whole message as one value, for replies that are a record themselves.
    func decodeAll<T: Decodable>(as _: T.Type) -> T? {
        guard let data = try? JSONSerialization.data(withJSONObject: object) else {
            return nil
        }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}

func hubEncodeRequest(id: Int, type: String, params: [String: Any]) throws -> Data {
    var body = params
    body["id"] = id
    body["type"] = type
    return try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
}

// The eight statuses of the shared look. Each is drawn as a shape, a word
// and a colour together, never colour alone.
enum HubStatusKind: Equatable {
    case live
    case connected
    case connecting
    case hidden
    case caution
    case problem
    case unknown
    case ready
}

// What the rig says right now: one true headline, one line under it, and
// this phone's own feed in words when the headline is about something else.
// Only fields the hub reported go in; a missing one is left out or reads
// "can't say".
struct HubStatus: Equatable {
    let kind: HubStatusKind
    let title: String
    let line: String?
    var phone: String?
    // The same, short, for the one line over the camera.
    var phoneBrief: String?

    // The one line over the camera.
    var text: String {
        [title, phoneBrief ?? phone].compactMap { $0 }.joined(separator: " · ")
    }

    // Read by VoiceOver as one sentence group.
    var spoken: String {
        [title, line, phone].compactMap { $0 }.joined(separator: ". ")
    }
}

private func linksText(_ feed: HubFeed?) -> String? {
    guard let links = feed?.srtlaLinks else {
        return nil
    }
    return links == 1 ? String(localized: "1 link") : String(localized: "\(links) links")
}

private func joined(_ parts: [String?]) -> String {
    parts.compactMap { $0 }.joined(separator: " · ")
}

// A feed in the shared words.
func hubFeedWord(_ feed: HubFeed?) -> String {
    switch feed?.state {
    case "checked":
        joined([String(localized: "Connected · picture checked"), linksText(feed)])
    case "receiving":
        String(localized: "Arriving · being checked")
    case "listening":
        String(localized: "Not sending yet")
    case "lost":
        String(localized: "Stopped sending")
    default:
        String(localized: "Not connected")
    }
}

private func phoneBriefWhileLive(_ feed: HubFeed?) -> String? {
    switch feed?.state {
    case "checked":
        joined([String(localized: "this phone connected"), linksText(feed)])
    case "receiving":
        String(localized: "this phone connecting")
    case "lost":
        String(localized: "this phone stopped sending")
    default:
        nil
    }
}

// This phone's feed while the headline is about the stream.
private func phoneWhileLive(_ feed: HubFeed?, carrier: String?) -> String? {
    switch feed?.state {
    case "checked":
        if let carrier {
            return joined([String(localized: "This phone connected · picture checked"), linksText(feed),
                           String(localized: "viewers still see \(carrier)")])
        }
        return joined([String(localized: "This phone connected · picture checked"), linksText(feed)])
    case "receiving":
        if feed?.black == true {
            return String(localized: "This phone: the hub sees a black picture")
        }
        return String(localized: "This phone: connecting to the hub")
    case "lost":
        return String(localized: "This phone stopped sending")
    default:
        return nil
    }
}

// This phone's feed when nothing is live.
private func phoneStatus(_ feed: HubFeed?) -> HubStatus {
    switch feed?.state {
    case "checked":
        if feed?.black == true {
            return HubStatus(kind: .caution,
                             title: String(localized: "Connected · picture is black"),
                             line: String(localized: "The hub sees a black picture from this phone."))
        }
        return HubStatus(kind: .connected,
                         title: joined([String(localized: "Connected · picture checked"), linksText(feed)]),
                         line: String(localized: "Viewers see nothing new."))
    case "receiving":
        return HubStatus(kind: .connecting,
                         title: joined([String(localized: "Connecting to the hub"), linksText(feed)]),
                         line: feed?.black == true
                             ? String(localized: "The hub sees a black picture.")
                             : String(localized: "Checking the picture."))
    case "lost":
        return HubStatus(kind: .caution,
                         title: String(localized: "Stopped sending"),
                         line: String(localized: "The hub lost this phone's picture."))
    default:
        return HubStatus(kind: .ready,
                         title: String(localized: "Ready to connect"),
                         line: String(localized: "Viewers see nothing from this phone until you move the stream here."))
    }
}

// Who asked for HIDE, when it wasn't this phone: "Hidden by Sam · Mod".
func hubHiddenByLine(_ privacy: HubPrivacy, me: String?) -> String? {
    guard privacy.hidden, let by = privacy.hiddenBy, by.id != me, !by.name.isEmpty else {
        return nil
    }
    let line = HubWords.Crew.hiddenBy(by.name)
    switch by.role {
    case "helper", "mod":
        return "\(line) · \(HubWords.Access.role(by.role ?? ""))"
    default:
        return line
    }
}

// The status. "Live" is only ever said for the hub's platform output; while
// it is live, nothing here reads as if it weren't.
func hubStatus(state: HubState?, me: String?, connected: Bool, pending: Bool) -> HubStatus {
    if pending {
        return HubStatus(kind: .ready,
                         title: String(localized: "Waiting for Allow"),
                         line: String(localized: "Someone on the rig has to allow this device."))
    }
    guard connected, let state else {
        return HubStatus(kind: .unknown,
                         title: String(localized: "Can't say right now"),
                         line: String(localized: "Lost the connection to your hub. Reconnecting…"))
    }
    let mine = me.flatMap { state.feed($0) }
    let session = state.session
    if state.isLive {
        if session.privacy.hidden {
            return HubStatus(kind: .hidden,
                             title: String(localized: "LIVE · privacy screen on"),
                             line: String(localized: "Your privacy screen is on. Viewers don't see you."),
                             phone: hubHiddenByLine(session.privacy, me: me),
                             // Short over the camera: the name, without the role.
                             phoneBrief: hubHiddenByLine(session.privacy, me: me) == nil ? nil
                                 : HubWords.Crew.hiddenBy(session.privacy.hiddenBy?.name ?? ""))
        }
        guard let program = session.program else {
            return HubStatus(kind: .live,
                             title: String(localized: "LIVE"),
                             line: String(localized: "The hub didn't say what viewers see."),
                             phone: phoneWhileLive(mine, carrier: nil),
                             phoneBrief: phoneBriefWhileLive(mine))
        }
        if program == me {
            return HubStatus(kind: .live,
                             title: joined([String(localized: "LIVE on this phone"), linksText(mine)]),
                             line: String(localized: "Viewers see this phone."))
        }
        let carrier = state.device(program)?.name ?? String(localized: "another device")
        if state.feed(program)?.state == "lost" {
            return HubStatus(kind: .caution,
                             title: String(localized: "LIVE · standby picture"),
                             line: String(localized: "The feed from \(carrier) stalled. Viewers see the standby picture."),
                             phone: phoneWhileLive(mine, carrier: nil),
                             phoneBrief: phoneBriefWhileLive(mine))
        }
        return HubStatus(kind: .live,
                         title: String(localized: "LIVE on \(carrier)"),
                         line: String(localized: "Viewers see \(carrier)."),
                         phone: phoneWhileLive(mine, carrier: carrier),
                         phoneBrief: phoneBriefWhileLive(mine))
    }
    switch session.output?.state {
    case "starting":
        return HubStatus(kind: .connecting,
                         title: String(localized: "The hub is starting the stream"),
                         line: nil,
                         phone: mine == nil ? nil : hubFeedWord(mine))
    case "failed":
        if session.live == "live" {
            return HubStatus(kind: .problem,
                             title: String(localized: "LIVE · can't say what viewers see"),
                             line: String(localized: "The hub's output reports a failure."))
        }
        return HubStatus(kind: .problem,
                         title: String(localized: "The hub's output reports a failure"),
                         line: String(localized: "Nothing from this phone was changed."))
    default:
        break
    }
    if session.live == "ended" {
        return HubStatus(kind: .ready,
                         title: String(localized: "Stream ended"),
                         line: nil,
                         phone: mine == nil ? nil : hubFeedWord(mine))
    }
    return phoneStatus(mine)
}

// One reported measurement. Unreported ones are not listed at all.
struct HubFact: Equatable {
    let label: String
    let value: String
}

func hubFacts(_ feed: HubFeed?) -> [HubFact] {
    guard let feed else {
        return []
    }
    var facts: [HubFact] = []
    if let picture = feed.picture {
        facts.append(HubFact(label: String(localized: "Picture"),
                             value: "\(picture.width)×\(picture.height) · \(Int(picture.fps.rounded())) fps"))
    }
    switch feed.sound {
    case "yes":
        facts.append(HubFact(label: String(localized: "Sound"), value: String(localized: "Heard")))
    case "silent":
        facts.append(HubFact(label: String(localized: "Sound"), value: String(localized: "Silent")))
    case "none":
        facts.append(HubFact(label: String(localized: "Sound"), value: String(localized: "No sound track")))
    default:
        break
    }
    if let links = feed.srtlaLinks {
        facts.append(HubFact(label: String(localized: "Links at the hub"), value: "\(links)"))
    }
    return facts
}

// What this phone asked the hub for and hasn't seen confirmed yet.
enum HubRequestKind: Hashable {
    case connect
    case disconnect
    case move
    case hide
    case show
}

// The hub's state is the only confirmation: a request stays open until the
// state shows what was asked for.
func hubOpenRequests(_ requested: Set<HubRequestKind>, state: HubState?, me: String?) -> Set<HubRequestKind> {
    guard let state, let me else {
        return requested
    }
    let feed = state.feed(me)?.state
    return requested.filter { kind in
        switch kind {
        case .connect:
            feed != "checked"
        case .disconnect:
            feed == "checked" || feed == "receiving"
        case .move:
            state.session.program != me
        case .hide:
            !state.session.privacy.hidden
        case .show:
            state.session.privacy.hidden
        }
    }
}

enum HubFeedControl: Equatable {
    // Offer Connect.
    case connect
    // Asked; the hub is checking the picture.
    case connecting
    // The hub confirmed the picture; offer Disconnect.
    case connected
    // Asked to stop; the hub still reports the feed.
    case disconnecting
}

enum HubMoveControl: Equatable {
    case offer
    case requested
    // The hub reports this phone as what viewers see.
    case onAir
}

enum HubPrivacyControl: Equatable {
    case hide
    case hideRequested
    // The hub confirmed the privacy screen. Only members and admins can
    // show the picture again, and only with the generation they saw.
    case hidden(generation: Int, canShow: Bool)
    case showRequested
}

// Which controls the panel shows, each in its confirmed or unconfirmed
// state. Nil means the control has no place right now.
struct HubControls: Equatable {
    var feed: HubFeedControl?
    var move: HubMoveControl?
    var privacy: HubPrivacyControl?

    static let none = HubControls()
}

func hubControls(state: HubState?,
                 me: String?,
                 role: String?,
                 sending: Bool,
                 requested: Set<HubRequestKind>) -> HubControls
{
    guard let state, let me else {
        return .none
    }
    var controls = HubControls()
    let session = state.session
    let feed = state.feed(me)
    if feed != nil {
        switch feed?.state {
        case "checked":
            controls.feed = requested.contains(.disconnect) ? .disconnecting : .connected
        case "receiving":
            controls.feed = requested.contains(.disconnect) ? .disconnecting : .connecting
        default:
            controls.feed = requested.contains(.connect) || sending ? .connecting : .connect
        }
    }
    if state.isLive {
        if session.program == me {
            controls.move = .onAir
        } else if feed?.state == "checked" {
            controls.move = requested.contains(.move) ? .requested : .offer
        }
    }
    if session.privacy.hidden {
        if requested.contains(.show) {
            controls.privacy = .showRequested
        } else {
            controls.privacy = .hidden(generation: session.privacy.generation,
                                       canShow: role == "admin" || role == "member")
        }
    } else {
        controls.privacy = requested.contains(.hide) ? .hideRequested : .hide
    }
    return controls
}
