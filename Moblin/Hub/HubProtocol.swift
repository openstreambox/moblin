import Foundation

// The messages of the osb-hub/1 protocol (section 4) that this
// phone reads, and the one status line it shows. Only fields the hub
// reports go into the line; a missing measurement reads "can't say".

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
}

func hubEncodeRequest(id: Int, type: String, params: [String: Any]) throws -> Data {
    var body = params
    body["id"] = id
    body["type"] = type
    return try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
}

enum HubLineLevel: Equatable {
    case live
    case good
    case waiting
    case warning
    case unknown
}

struct HubLine: Equatable {
    let text: String
    let level: HubLineLevel
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

// This phone's own feed, in words, from the hub's measurements only.
func hubFeedText(_ feed: HubFeed?) -> String {
    guard let feed else {
        return String(localized: "Ready to connect")
    }
    switch feed.state {
    case "checked":
        if feed.black == true {
            return String(localized: "Phone connected · picture is black")
        }
        return joined([String(localized: "Phone connected"), linksText(feed), String(localized: "picture checked")])
    case "receiving":
        if feed.black == true {
            return joined([String(localized: "Connecting to the hub"), linksText(feed),
                           String(localized: "the hub sees a black picture")])
        }
        return joined([String(localized: "Connecting to the hub"), linksText(feed), String(localized: "checking the picture")])
    case "lost":
        return String(localized: "The hub lost this phone's picture")
    default:
        return String(localized: "Ready to connect")
    }
}

// The one status line. "Live" is only ever said for the hub's platform
// output; while it is live, nothing here reads as if it weren't.
func hubStatusLine(state: HubState?, me: String?, connected: Bool, pending: Bool) -> HubLine {
    if pending {
        return HubLine(text: String(localized: "Waiting for an admin to allow this phone"), level: .waiting)
    }
    guard connected, let state else {
        return HubLine(text: String(localized: "Rig: can't say right now · reconnecting"), level: .unknown)
    }
    let mine = me.flatMap { state.feed($0) }
    let session = state.session
    if state.isLive {
        if session.privacy.hidden {
            return HubLine(text: String(localized: "LIVE · privacy screen on · viewers don't see you"), level: .live)
        }
        if let program = session.program, program == me {
            return HubLine(text: joined([String(localized: "LIVE · viewers see this phone"), linksText(mine)]),
                           level: .live)
        }
        let source = session.program.flatMap { state.device($0)?.name }
        let showing = source.map { String(localized: "LIVE · viewers see \($0)") } ?? String(localized: "LIVE")
        return HubLine(text: "\(showing) · \(hubFeedText(mine))", level: .live)
    }
    switch session.output?.state {
    case "starting":
        return HubLine(text: joined([String(localized: "The hub is starting the stream"), hubFeedText(mine)]),
                       level: .waiting)
    case "failed":
        return HubLine(text: String(localized: "The hub reports its stream output failed"), level: .warning)
    default:
        break
    }
    if session.live == "ended" {
        return HubLine(text: joined([String(localized: "Stream ended"), hubFeedText(mine)]), level: .waiting)
    }
    let level: HubLineLevel = mine?.state == "checked" ? .good : .waiting
    return HubLine(text: hubFeedText(mine), level: level)
}

enum HubAction: Equatable {
    case hide
    case showPicture(generation: Int)
    case connect
    case moveHere
}

// Which controls this phone offers right now.
func hubActions(state: HubState?, me: String?, role: String?) -> [HubAction] {
    guard let state, let me else {
        return []
    }
    var actions: [HubAction] = []
    let session = state.session
    if session.privacy.hidden {
        if role == "admin" || role == "member" {
            actions.append(.showPicture(generation: session.privacy.generation))
        }
    } else {
        actions.append(.hide)
    }
    let feed = state.feed(me)
    if feed != nil, feed?.state != "checked", feed?.state != "receiving" {
        actions.append(.connect)
    }
    if state.isLive, session.program != me, feed?.state == "checked" {
        actions.append(.moveHere)
    }
    return actions
}
