import Foundation

// Who has access (osb-hub/1, sections 9 and 11): everything that can reach
// the stream as one kind of record, and the hub's record of what happened.
// Only an owner device gets these from the hub. This file reads them and
// puts them in words; what each role allows is built from the requests the
// hub says that role may make, so a screen can't drift from what is true.
// Who did something, or whom it was done to.
struct HubParty: Codable, Equatable {
    // device | mod | invite | hub
    var kind: String?
    var id: String
    var name: String
    var role: String?
    var web: Bool?
    // The stream's session owner did it.
    var session: Bool?
}

// An owner of the setup, as a grant or a trail line names them. No id yet
// for a co-owner whose first device still waits.
struct HubPersonRef: Codable, Equatable {
    var id: String?
    var name: String?
}

struct HubPerson: Codable, Equatable {
    var id: String
    var name: String?
    var you: Bool?
}

// How many of what a session owner let in.
struct HubGave: Codable, Equatable {
    var helpers: Int?
    var mods: Int?
    var invites: Int?
}

// Who runs the stream: handed over to a device, or the owner who went live.
struct HubRunBy: Codable, Equatable {
    // handed | went_live
    var kind: String
    var device: HubPersonRef?
    var forName: String?
    var person: HubPersonRef?
    var givenBy: HubPersonRef?
    var givenAt: String?
    // When the handover ends if nothing changes, and why (as in the state).
    var endsAt: String?
    var gave: HubGave?
    var endsWhy: String?
    var endTime: String?
    var stoppedAt: String?
    var askedAt: String?
    var answeredAt: String?
    var waitUntil: String?

    enum CodingKeys: String, CodingKey {
        case kind
        case device
        case forName = "for"
        case person
        case givenBy = "given_by"
        case givenAt = "given_at"
        case endsAt = "ends_at"
        case gave
        case endsWhy = "ends_why"
        case endTime = "end_time"
        case stoppedAt = "stopped_at"
        case askedAt = "asked_at"
        case answeredAt = "answered_at"
        case waitUntil = "wait_until"
    }
}

// An open invite, as every device in the setup sees it. No ticket: a link
// is shown once, to the owner device that made it.
struct HubInvite: Codable, Equatable {
    var id: String
    var role: String
    var via: String?
    var by: String?
    var closesAt: String?
    var rotates: Bool?
    var endsWithStream: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case role
        case via
        case by
        case closesAt = "closes_at"
        case rotates
        case endsWithStream = "ends_with_stream"
    }
}

// A mod link that still works.
struct HubMod: Codable, Equatable {
    var id: String
    var name: String
    // open | joined
    var state: String?
    var expiresAt: String?
    var joinedAt: String?
    var online: Bool?
    var endsWithStream: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case state
        case expiresAt = "expires_at"
        case joinedAt = "joined_at"
        case online
        case endsWithStream = "ends_with_stream"
    }
}

struct HubGrant: Codable, Equatable, Identifiable {
    var id: String
    // device | mod | invite
    var kind: String
    var name: String
    var forName: String?
    var deviceKind: String?
    var role: String
    var allows: [String]
    // active | waiting | open
    var state: String
    var online: Bool?
    // scan | link | web_link
    var how: String?
    var givenBy: HubParty?
    var givenAt: String?
    var allowedBy: HubParty?
    var allowedAt: String?
    var joinedAt: String?
    var endsAt: String?
    var accessMs: Int?
    var endsWithStream: Bool?
    var carriesStream: Bool?
    var isSelf: Bool?
    // allow | change | end | hand | take_back: what this owner may do to
    // the record now.
    var can: [String]
    // The owner this device belongs to, or will make.
    var person: HubPersonRef?
    var newOwner: Bool?
    var runsStream: Bool?
    var handsStream: Bool?
    var givenBySession: Bool?
    // Requests that reach less far for this record (a session owner).
    var limits: [String: String]?

    enum CodingKeys: String, CodingKey {
        case id
        case kind
        case name
        case forName = "for"
        case deviceKind = "device_kind"
        case role
        case allows
        case state
        case online
        case how
        case givenBy = "given_by"
        case givenAt = "given_at"
        case allowedBy = "allowed_by"
        case allowedAt = "allowed_at"
        case joinedAt = "joined_at"
        case endsAt = "ends_at"
        case accessMs = "access_ms"
        case endsWithStream = "ends_with_stream"
        case carriesStream = "carries_stream"
        case isSelf = "self"
        case can
        case person
        case newOwner = "new_owner"
        case runsStream = "runs_stream"
        case handsStream = "hands_stream"
        case givenBySession = "given_by_session"
        case limits
    }
}

struct HubOwnerLink: Codable, Equatable, Identifiable {
    var id: String
    var device: HubPersonRef?
    var state: String
    var online: Bool?
    var madeAt: String?
    var openedAt: String?
    var endsAt: String?
    var can: [String]?

    enum CodingKeys: String, CodingKey {
        case id
        case device
        case state
        case online
        case madeAt = "made_at"
        case openedAt = "opened_at"
        case endsAt = "ends_at"
        case can
    }
}

struct HubAccessAs: Codable, Equatable {
    var id: String?
    var name: String?
    var role: String?
    var runsStream: Bool?
    var person: HubPersonRef?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case role
        case runsStream = "runs_stream"
        case person
    }
}

struct HubTrailDetail: Codable, Equatable {
    var via: String?
    var waiting: Bool?
    var carriedStream: Bool?
    var why: String?
    var endsAt: String?
    // "ends_at": null was sent: only when removed.
    var endsAtCleared = false
    var endsWithStream: Bool?
    var person: HubPersonRef?
    var newOwner: Bool?
    var personLeft: Bool?
    var handStream: Bool?
    var renewed: Bool?
    var forName: String?
    var ended: HubGave?
    var was: String?
    var name: String?
    var lines: Int?
    // stream.kept: the end time an owner set with the answer.
    var endTime: String?

    enum CodingKeys: String, CodingKey {
        case via
        case waiting
        case carriedStream = "carried_stream"
        case why
        case endsAt = "ends_at"
        case endsWithStream = "ends_with_stream"
        case person
        case newOwner = "new_owner"
        case personLeft = "person_left"
        case handStream = "hand_stream"
        case renewed
        case forName = "for"
        case ended
        case was
        case name
        case lines
        case endTime = "end_time"
    }

    init(via: String? = nil,
         waiting: Bool? = nil,
         carriedStream: Bool? = nil,
         why: String? = nil,
         endsAt: String? = nil,
         endsAtCleared: Bool = false,
         endsWithStream: Bool? = nil)
    {
        self.via = via
        self.waiting = waiting
        self.carriedStream = carriedStream
        self.why = why
        self.endsAt = endsAt
        self.endsAtCleared = endsAtCleared
        self.endsWithStream = endsWithStream
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        via = try? container.decodeIfPresent(String.self, forKey: .via)
        waiting = try? container.decodeIfPresent(Bool.self, forKey: .waiting)
        carriedStream = try? container.decodeIfPresent(Bool.self, forKey: .carriedStream)
        why = try? container.decodeIfPresent(String.self, forKey: .why)
        endsAt = try? container.decodeIfPresent(String.self, forKey: .endsAt)
        endsAtCleared = container.contains(.endsAt) && ((try? container.decodeNil(forKey: .endsAt)) ?? false)
        endsWithStream = try? container.decodeIfPresent(Bool.self, forKey: .endsWithStream)
        person = try? container.decodeIfPresent(HubPersonRef.self, forKey: .person)
        newOwner = try? container.decodeIfPresent(Bool.self, forKey: .newOwner)
        personLeft = try? container.decodeIfPresent(Bool.self, forKey: .personLeft)
        handStream = try? container.decodeIfPresent(Bool.self, forKey: .handStream)
        renewed = try? container.decodeIfPresent(Bool.self, forKey: .renewed)
        forName = try? container.decodeIfPresent(String.self, forKey: .forName)
        ended = try? container.decodeIfPresent(HubGave.self, forKey: .ended)
        was = try? container.decodeIfPresent(String.self, forKey: .was)
        name = try? container.decodeIfPresent(String.self, forKey: .name)
        lines = try? container.decodeIfPresent(Int.self, forKey: .lines)
        endTime = try? container.decodeIfPresent(String.self, forKey: .endTime)
    }
}

struct HubTrailEntry: Codable, Equatable, Identifiable {
    var seq: Int
    var at: String
    var type: String
    var by: HubParty?
    var subject: HubParty?
    var detail: HubTrailDetail?

    var id: Int {
        seq
    }
}

struct HubAccess: Codable, Equatable {
    struct Stream: Codable, Equatable {
        // ready | live | ended
        var live: String
        var hidden: Bool
        var runBy: HubRunBy?

        enum CodingKeys: String, CodingKey {
            case live
            case hidden
            case runBy = "run_by"
        }
    }

    var hub: String
    var stream: Stream
    var grants: [HubGrant]
    var trail: [HubTrailEntry]
    var trailMore: Bool?
    // The setup's owners. Absent from a hub that doesn't know co-owners.
    var people: [HubPerson]?
    // What this owner may do to the list as a whole: clear_trail.
    var can: [String]?
    var ownerLinks: [HubOwnerLink]?
    var asWho: HubAccessAs?

    enum CodingKeys: String, CodingKey {
        case hub
        case stream
        case grants
        case trail
        case trailMore = "trail_more"
        case people
        case can
        case ownerLinks = "owner_links"
        case asWho = "as"
    }
}

// A link the hub just made. It is shown once.
struct HubMadeLink: Equatable {
    enum Kind: Equatable {
        case helper
        case mod
        case coOwner(known: Bool)
    }

    let kind: Kind
    let name: String
    let link: String
    // When the link stops opening anything.
    let closesAt: String?
}

// The clock and calendar the wording uses, passed in so tests don't depend
// on the device.
struct HubWhen {
    var now: Date
    var calendar: Calendar = .current
    var locale: Locale = .current

    static func date(_ iso: String?) -> Date? {
        guard let iso else {
            return nil
        }
        return (try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(iso))
            ?? (try? Date.ISO8601FormatStyle().parse(iso))
    }

    private func formatter(_ template: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter
    }

    func calm(_ iso: String?) -> String {
        guard let date = HubWhen.date(iso), calendar.isDate(date, inSameDayAs: now) else {
            return text(iso)
        }
        return formatter("jmm").string(from: date)
    }

    // "today at 18:40", "tomorrow at 09:00", "Thursday 19 Nov at 18:40".
    func text(_ iso: String?) -> String {
        guard let date = HubWhen.date(iso) else {
            return String(localized: "at a time the hub didn't say")
        }
        let time = formatter("jmm").string(from: date)
        let days = calendar.dateComponents([.day],
                                           from: calendar.startOfDay(for: now),
                                           to: calendar.startOfDay(for: date)).day ?? 0
        switch days {
        case 0:
            return String(localized: "today at \(time)")
        case 1:
            return String(localized: "tomorrow at \(time)")
        case -1:
            return String(localized: "yesterday at \(time)")
        default:
            let day = formatter("EEEEdMMM").string(from: date).replacingOccurrences(of: ",", with: "")
            return String(localized: "\(day) at \(time)")
        }
    }
}

func hubListAnd(_ items: [String]) -> String {
    listAnd(items)
}

private func listAnd(_ items: [String]) -> String {
    guard items.count > 1 else {
        return items.joined()
    }
    return String(localized: "\(items.dropLast().joined(separator: ", ")) and \(items[items.count - 1])")
}

private func listOr(_ items: [String]) -> String {
    guard items.count > 1 else {
        return items.joined()
    }
    return String(localized: "\(items.dropLast().joined(separator: ", ")) or \(items[items.count - 1])")
}

// What a role allows, from the requests the hub lets it make.
// limits names the requests that reach less far (the stream's session owner).
func hubAllowsLine(_ allows: [String], limits: [String: String] = [:]) -> String {
    let has = Set(allows)
    let can = HubWords.Access.can.filter { has.contains($0.0) }.map {
        $0.0 == "invite.open" && limits[$0.0] == "stream" ? HubWords.Access.canForStream : $0.1
    }
    var cant = HubWords.Access.can.filter { !has.contains($0.0) }.map {
        $0.0 == "invite.open" ? HubWords.Access.cantManage : $0.1
    }
    if has.contains("invite.open") {
        cant += HubWords.Access.cantOwner.filter { !has.contains($0.0) }.map(\.1)
    }
    if cant.isEmpty {
        return HubWords.Access.canAll
    }
    if can.count <= 1 {
        return HubWords.Access.canOnly(can.first ?? String(localized: "nothing else"))
    }
    return HubWords.Access.canSome(listAnd(can), listOr(cant))
}

// What a role may ask the hub for (section 4.1), for a device that waits
// for Allow: the list isn't there yet when the panel has to word it. The
// hub checks every request against its own table whatever a screen says.
func hubRoleAllows(_ role: String) -> [String] {
    switch role {
    case "admin":
        ["stream.go_live", "stream.move", "stream.end", "privacy.hide", "privacy.show", "invite.open"]
    case "member":
        ["stream.go_live", "stream.move", "stream.end", "privacy.hide", "privacy.show"]
    case "helper":
        ["stream.move", "privacy.hide"]
    default:
        ["privacy.hide"]
    }
}

enum HubAccessChange: String, CaseIterable, Identifiable {
    case stream
    case hour
    case halfDay
    case day
    case never

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .stream:
            HubWords.Access.changeStream
        case .hour:
            HubWords.Access.changeHour
        case .halfDay:
            HubWords.Access.changeHalfDay
        case .day:
            HubWords.Access.changeDay
        case .never:
            HubWords.Access.changeNever
        }
    }

    // What the choice asks the hub for (access.change).
    func request(now: Date) -> [String: Any] {
        func at(_ hours: Double) -> [String: Any] {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return ["ends_at": formatter.string(from: now.addingTimeInterval(hours * 3600)),
                    "ends_with_stream": false]
        }
        switch self {
        case .stream:
            return ["ends_with_stream": true]
        case .never:
            return ["ends_at": NSNull(), "ends_with_stream": false]
        case .hour:
            return at(1)
        case .halfDay:
            return at(12)
        case .day:
            return at(24)
        }
    }
}

// One row of the list, in words.
struct HubAccessRow: Equatable, Identifiable {
    // A button that asks once before it does anything.
    struct End: Equatable {
        let label: String
        let confirm: String
    }

    let id: String
    let kind: String
    let name: String
    // The owner's own label, when the device named itself differently.
    let forName: String?
    let role: String
    let presence: String?
    let here: Bool
    let allows: String
    let how: String
    let ends: String
    let notes: [String]
    let allow: Bool
    // Set when Allow makes someone a co-owner: it asks first.
    let allowConfirm: End?
    let hand: End?
    let change: [HubAccessChange]?
    let end: End?
    // Hand over also asks how long it may wait for Go live: the stream
    // isn't live.
    var handWaits = false

    // Read by VoiceOver as one sentence group.
    var spoken: String {
        ([name, role, presence, allows, how, ends] + notes).compactMap { $0 }.filter { !$0.isEmpty }
            .joined(separator: ". ")
    }
}

private func partyName(_ party: HubParty?) -> String {
    guard let name = party?.name, !name.isEmpty else {
        return HubWords.Access.anOwnerDevice
    }
    return name
}

private func howLine(_ grant: HubGrant, _ when: HubWhen) -> String {
    let by = partyName(grant.givenBy)
    if grant.kind == "invite" {
        let made = grant.how == "link" ? HubWords.Access.howInviteLink(by) : HubWords.Access.howInviteScan(by)
        return grant.givenAt == nil ? made : "\(made) · \(when.text(grant.givenAt))"
    }
    if grant.kind == "mod" {
        return "\(HubWords.Access.howWebLink(by)) · \(when.text(grant.givenAt))"
    }
    let how: String
    if grant.givenBy?.id == "hub" {
        how = HubWords.Access.howFirstLink
    } else if grant.how == "scan" {
        how = HubWords.Access.howScan(by)
    } else if grant.how == "link" {
        how = grant.allowedBy == nil
            ? HubWords.Access.howLink(by)
            : HubWords.Access.howLinkAllowed(by, partyName(grant.allowedBy))
    } else {
        how = HubWords.Access.howUnknown
    }
    return grant.joinedAt == nil ? how : "\(how) · \(when.text(grant.joinedAt))"
}

private func endsLine(_ grant: HubGrant, _ when: HubWhen) -> String {
    if grant.kind == "invite" {
        return HubWords.Access.inviteAt(when.text(grant.endsAt))
    }
    if grant.endsWithStream == true {
        return grant.endsAt == nil ? HubWords.Access.endsStream
            : HubWords.Access.endsStreamOrAt(when.text(grant.endsAt))
    }
    return grant.endsAt == nil ? HubWords.Access.endsNever : HubWords.Access.endsAt(when.text(grant.endsAt))
}

// What an unused invite will give, when that isn't "until removed".
private func inviteGives(_ grant: HubGrant) -> [String] {
    var parts: [String] = []
    if let access = grant.accessMs, access > 0 {
        if access >= 3_600_000 {
            let hours = (Double(access) / 360_000).rounded() / 10
            let text = hours == hours.rounded() ? String(Int(hours)) : String(hours)
            parts.append(HubWords.Access.inviteHours(text))
        } else {
            parts.append(HubWords.Access.inviteMinutes(String(Int((Double(access) / 60000).rounded()))))
        }
    }
    if grant.endsWithStream == true {
        parts.append(HubWords.Access.inviteStream)
    }
    return parts.isEmpty ? [] : [HubWords.Access.inviteGives(listOr(parts))]
}

func hubGaveList(_ gave: HubGave?) -> String {
    gaveList(gave)
}

private func gaveList(_ gave: HubGave?) -> String {
    listAnd([
        (gave?.helpers ?? 0, String(localized: "helper"), String(localized: "helpers")),
        (gave?.mods ?? 0, String(localized: "mod"), String(localized: "mods")),
        (gave?.invites ?? 0, String(localized: "unused invite"), String(localized: "unused invites")),
    ].filter { $0.0 > 0 }.map { count($0.0, $0.1, $0.2) })
}

// The confirmation an owner reads before a new co-owner's device is let in.
func hubCoOwnerConfirm(person: String?, device: String) -> HubAccessRow.End {
    let who = person?.isEmpty == false ? person! : HubWords.Access.unnamedLower
    return .init(label: HubWords.Access.makeCoOwner, confirm: HubWords.Access.confirmCoOwner(who, device))
}

func hubAccessRow(_ grant: HubGrant, when: HubWhen, shared: Bool = false, live: Bool = true) -> HubAccessRow {
    let can = Set(grant.can)
    let role = HubWords.Access.role(grant.role)
    let person = grant.person?.name?.isEmpty == false ? grant.person!.name! : HubWords.Access.unnamedLower
    let named: String
    if grant.kind == "invite" {
        named = grant.name.isEmpty ? String(localized: "\(role) invite")
            : String(localized: "\(role) invite for \(grant.name)")
    } else {
        named = grant.name
    }
    let presence: String?
    switch grant.kind {
    case "invite":
        presence = nil
    case "mod":
        presence = grant.state == "open" ? HubWords.Access.notOpened
            : grant.online == true ? HubWords.Access.pageOpen : HubWords.Access.pageClosed
    default:
        presence = grant.online == true ? HubWords.Access.here : HubWords.Access.away
    }
    var end: HubAccessRow.End?
    if can.contains("end") {
        switch grant.kind {
        case "device":
            end = .init(label: HubWords.Access.remove,
                        confirm: grant.carriesStream == true
                            ? HubWords.Access.confirmRemoveCarrier(named)
                            : HubWords.Access.confirmRemove(named))
        case "mod":
            end = .init(label: HubWords.Access.endNow, confirm: HubWords.Access.confirmEndMod(named))
        default:
            end = .init(label: HubWords.Access.endNow, confirm: HubWords.Access.confirmEndInvite)
        }
    }
    var notes = grant.kind == "invite" ? inviteGives(grant) : []
    if grant.kind == "invite", grant.person != nil {
        notes.append(HubWords.Access.noteInviteOwner(person))
    }
    if grant.kind == "invite", grant.handsStream == true {
        notes.append(HubWords.Access.noteInviteHand)
    }
    if grant.state == "waiting" {
        if grant.newOwner == true {
            notes.append(HubWords.Access.noteNewOwner(person))
        } else if grant.role == "admin" {
            notes.append(HubWords.Access.noteOtherOwner(person))
        }
        if grant.handsStream == true {
            notes.append(HubWords.Access.noteHandsStream)
        }
        if grant.role == "admin", grant.newOwner != true, !can.contains("allow") {
            notes.append(HubWords.Access.theirs(person))
        }
    }
    if grant.runsStream == true {
        notes.append(HubWords.Access.noteRuns)
    }
    if grant.givenBySession == true {
        notes.append(HubWords.Access.noteBySession)
    }
    let card = grant.kind != "invite" && grant.can.isEmpty && grant.givenBy == nil && grant.joinedAt == nil
        && grant.givenAt == nil && grant.isSelf != true
    if grant.carriesStream == true, !card {
        notes.append(HubWords.Access.carries)
    }
    if grant.isSelf == true {
        notes.append(HubWords.Access.thisPhone)
    }
    if grant.kind == "device", grant.role == "admin", grant.state == "active", !can.contains("end"), !card {
        notes.append(HubWords.Access.lastOwner)
    }
    var hand: HubAccessRow.End?
    if can.contains("hand") {
        let to = grant.forName != nil && grant.forName != named ? "\(grant.forName!) (\(named))" : named
        hand = .init(label: HubWords.Access.handOver, confirm: HubWords.Access.confirmHandOver(to))
    }
    let shownRole = grant.runsStream == true ? HubWords.Access.role("session")
        : shared && grant.role == "member" ? HubWords.Access.role("shared") : role
    var change: [HubAccessChange]?
    if can.contains("change") {
        change = grant.kind == "device" ? HubAccessChange.allCases
            : HubAccessChange.allCases.filter { $0 != .never }
    }
    let forName = grant.kind == "device" && grant.forName != nil && grant.forName != grant.name
        ? grant.forName : nil
    return HubAccessRow(id: grant.id,
                        kind: grant.kind,
                        name: named,
                        forName: forName,
                        role: shownRole,
                        presence: presence,
                        here: grant.online == true,
                        allows: hubAllowsLine(grant.allows, limits: grant.limits ?? [:]),
                        how: card ? "" : howLine(grant, when),
                        ends: card ? "" : endsLine(grant, when),
                        notes: notes,
                        allow: can.contains("allow"),
                        allowConfirm: can.contains("allow") && grant.newOwner == true
                            ? hubCoOwnerConfirm(person: grant.person?.name, device: named) : nil,
                        hand: hand,
                        change: change,
                        end: end,
                        handWaits: hand != nil && !live)
}

private func who(_ party: HubParty?) -> String {
    guard let party else {
        return String(localized: "Someone")
    }
    if party.kind == "hub" {
        return String(localized: "The hub")
    }
    var text = party.name.isEmpty ? String(localized: "Someone") : party.name
    if party.session == true {
        text += String(localized: " (session owner)")
    } else if party.role == "helper" {
        text += String(localized: " (helper)")
    } else if party.role == "mod" {
        text += String(localized: " (mod)")
    }
    if party.web == true {
        text += String(localized: ", from the web view")
    }
    return text
}

private func article(_ role: String) -> String {
    switch role {
    case "admin":
        String(localized: "an owner device")
    case "helper":
        String(localized: "a helper")
    case "mod":
        String(localized: "a mod")
    default:
        String(localized: "a device")
    }
}

private func roleWord(_ role: String?) -> String {
    switch role {
    case "admin":
        String(localized: "owner device")
    case "member":
        String(localized: "your device")
    case "helper":
        String(localized: "helper")
    case "mod":
        String(localized: "mod")
    default:
        String(localized: "device")
    }
}

// One line of the trail, in words.
func hubTrailLine(_ entry: HubTrailEntry, when: HubWhen) -> String {
    let by = who(entry.by)
    let subject = entry.subject
    let name = subject?.name ?? ""
    let detail = entry.detail ?? HubTrailDetail()
    let role = roleWord(subject?.role)
    let forName = name.isEmpty ? "" : String(localized: " for \(name)")
    var owner = ""
    if let person = detail.person {
        if detail.newOwner == true {
            owner = String(localized: " for \(person.name?.isEmpty == false ? person.name! : "someone"), a new co-owner")
        } else if person.name?.isEmpty == false {
            owner = String(localized: " for \(person.name!)")
        }
    }
    let ended = gaveList(detail.ended)
    let lost = ended.isEmpty ? "" : String(localized: ". What they let in lost access: \(ended)")
    switch entry.type {
    case "invite.opened":
        let hand = detail.handStream == true ? String(localized: ", to run the stream") : ""
        if detail.via == "link" {
            return String(localized: "\(by) made a \(role) link\(forName)\(owner)\(hand)")
        }
        return subject?.role == "helper"
            ? String(localized: "\(by) showed a code to add a helper\(forName)\(owner)\(hand)")
            : String(localized: "\(by) showed a code to add \(article(subject?.role ?? ""))\(forName)\(owner)\(hand)")
    case "invite.closed":
        return String(localized: "\(by) closed the \(role) invite\(forName)")
    case "invite.ended":
        return String(localized: "The \(role) link\(forName) ended unused")
    case "device.joined":
        let from: String
        if entry.by?.kind == "hub" {
            from = String(localized: "with the hub's first link")
        } else if detail.via == "link" {
            from = String(localized: "with a link from \(entry.by == nil ? HubWords.Access.anOwnerDevice : by)")
        } else {
            from = String(localized: "by scanning a code on \(entry.by == nil ? HubWords.Access.anOwnerDevice : by)")
        }
        let asRole = article(subject?.role ?? "")
        return detail.waiting == true
            ? String(localized: "\(name) asked to join as \(asRole)\(owner) \(from)")
            : String(localized: "\(name) joined as \(asRole)\(owner) \(from)")
    case "device.allowed":
        if detail.newOwner == true {
            let person = detail.person?.name?.isEmpty == false ? detail.person!.name! : "someone"
            return String(localized: "\(by) made \(person) a co-owner: allowed \(name) as an owner device")
        }
        return owner.isEmpty ? String(localized: "\(by) allowed \(name)")
            : String(localized: "\(by) allowed \(name) as an owner device\(owner)")
    case "device.removed":
        var line = String(localized: "\(by) removed \(name)")
        if !owner.isEmpty {
            line += String(localized: ", an owner device\(owner)")
        }
        if detail.carriedStream == true {
            line += String(localized: " while viewers saw it")
        }
        if detail.personLeft == true {
            let person = detail.person?.name?.isEmpty == false ? detail.person!.name! : "That co-owner"
            line += String(localized: ". \(person) is no longer an owner")
        }
        return line
    case "device.ended":
        return detail.why == "stream"
            ? String(localized: "\(name)'s access ended with the stream")
            : detail.why == "handover"
            ? String(localized: "\(name)'s access ended with the handover")
            : String(localized: "\(name)'s access ended at its set time")
    case "mod.made":
        return String(localized: "\(by) made a mod link for \(name)")
    case "mod.joined":
        return String(localized: "\(name) opened their mod link")
    case "mod.removed":
        return String(localized: "\(by) ended \(name)'s mod link")
    case "mod.ended":
        return detail.why == "stream"
            ? String(localized: "\(name)'s mod link ended with the stream")
            : detail.why == "handover"
            ? String(localized: "\(name)'s mod link ended with the handover")
            : String(localized: "\(name)'s mod link ended at its set time")
    case "access.changed":
        var parts: [String] = []
        if detail.endsWithStream == true {
            parts.append(String(localized: "when the stream ends"))
        }
        if detail.endsAt != nil {
            parts.append(when.text(detail.endsAt))
        } else if detail.endsAtCleared, detail.endsWithStream != true {
            parts.append(String(localized: "only when removed"))
        }
        let ends = parts.isEmpty ? String(localized: "not with the stream") : parts.joined(separator: ", or ")
        return String(localized: "\(by) changed when \(name)'s access ends: \(ends)")
    case "access.link.made":
        return String(localized: "\(by) made a link to the web view of this list")
    case "access.link.ended":
        if let subject, !subject.id.isEmpty, subject.id == entry.by?.id {
            return String(localized: "\(by) ended its link to the web view of this list")
        }
        return String(localized: "\(by) ended the link to the web view of this list that \(name.isEmpty ? HubWords.Access.anOwnerDevice : name) made")
    case "access.link.opened":
        let device = entry.by?.name.isEmpty == false ? entry.by!.name : HubWords.Access.anOwnerDevice
        return String(localized: "The link made on \(device) was opened in a browser")
    case "privacy.hide":
        return String(localized: "\(by) hid the picture")
    case "privacy.show":
        return String(localized: "\(by) showed the picture again")
    case "stream.go_live":
        if let subject, subject.id != entry.by?.id {
            return String(localized: "\(by) went live from \(name)")
        }
        return String(localized: "\(by) went live")
    case "stream.move":
        return String(localized: "\(by) moved the stream to \(name)")
    case "stream.end":
        return detail.why == "restart" ? String(localized: "The hub restarted. The stream ended with it")
            : String(localized: "\(by) ended the stream")
    case "stream.handed":
        let to = detail.forName != nil && detail.forName != name ? "\(detail.forName!) (\(name))" : name
        return detail.renewed == true
            ? String(localized: "\(by) renewed the handover of the stream to \(to)")
            : String(localized: "\(by) handed the stream to \(to)")
    case "stream.kept":
        if let end = detail.endTime {
            return String(localized: "\(by) kept \(name)'s handover, until \(when.text(end))")
        }
        return String(localized: "\(by) kept \(name)'s handover")
    case "stream.taken_back":
        switch detail.why {
        case "taken_back":
            return String(localized: "\(by) took the stream back from \(name)\(lost)")
        case "returned":
            return String(localized: "\(name) gave the stream back\(lost)")
        case "stream":
            return String(localized: "\(name)'s handover ended: the stream stayed stopped\(lost)")
        case "time":
            return String(localized: "\(name)'s handover ended at its end time\(lost)")
        case "unanswered":
            return String(localized: "\(name)'s handover ended: no owner kept it\(lost)")
        case "not_live":
            return String(localized: "\(name)'s handover ended: the stream didn't go live in time\(lost)")
        case "removed":
            return String(localized: "\(name)'s handover ended when the device was removed\(lost)")
        case "restart":
            return String(localized: "The hub restarted. \(name)'s handover ended with it\(lost)")
        default:
            return String(localized: "\(name)'s handover ended: the stream was handed on\(lost)")
        }
    case "owner.named":
        let named = detail.name ?? ""
        if let was = detail.was, !was.isEmpty {
            return String(localized: "\(by) changed its owner's name from \(was) to \(named)")
        }
        return String(localized: "\(by) named its owner \(named)")
    case "trail.cleared":
        let lines = count(detail.lines ?? 0, String(localized: "line"), String(localized: "lines"))
        return String(localized: "\(by) cleared what happened (\(lines))")
    case "hub.moved":
        return String(localized: "The hub moved to another host. Older lines stayed on the first one.")
    default:
        return entry.type
    }
}

struct HubAccessSection: Equatable, Identifiable {
    let id: String
    let title: String
    // "Owner" or "Co-owner", on a person's section.
    var tag: String?
    let rows: [HubAccessRow]
}

// "This stream": who runs it.
struct HubAccessRunning: Equatable {
    let line: String
    let facts: [String]
    // The device it was handed to, and the confirm for taking it back.
    let device: String?
    let takeBack: HubAccessRow.End?
    var giveBack: HubAccessRow.End?
    // The hub's open question to owner devices, and the end times an owner
    // may set (nil when this device may not answer).
    var ask: HubHandoverAsk?
    var endTimes: [HubEndTime]?
}

// The hub asks owner devices whether a handover goes on (stream.ask, and
// asked_at while nobody answered). Keep, Set an end time and Take back now
// answer it; ignoring it is safe, the handover then ends on its own.
struct HubHandoverAsk: Equatable {
    let title: String
    let since: String?
    let line: String
    // Keep is the view's filled button unless an Allow is on the same view.
    let filled: Bool
}

// Handing over while the stream isn't live: how long it may wait for Go
// live (wait_ms on stream.hand). The first is the hub's default, so it is
// the one picked until the owner picks another; the hub takes one minute to
// seven days.
enum HubWait: String, CaseIterable, Identifiable {
    case halfHour
    case hour
    case threeHours
    case halfDay
    case day
    case week

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .halfHour:
            HubWords.Access.Wait.halfHour
        case .hour:
            HubWords.Access.Wait.hour
        case .threeHours:
            HubWords.Access.Wait.threeHours
        case .halfDay:
            HubWords.Access.Wait.halfDay
        case .day:
            HubWords.Access.Wait.day
        case .week:
            HubWords.Access.Wait.week
        }
    }

    var milliseconds: Int {
        switch self {
        case .halfHour:
            30 * 60000
        case .hour:
            3_600_000
        case .threeHours:
            3 * 3_600_000
        case .halfDay:
            12 * 3_600_000
        case .day:
            24 * 3_600_000
        case .week:
            7 * 24 * 3_600_000
        }
    }
}

// What Hand over asks the hub for: with a wait only while not live.
func hubHandRequest(_ device: String, wait: HubWait?) -> [String: Any] {
    guard let wait else {
        return ["device": device]
    }
    return ["device": device, "wait_ms": wait.milliseconds]
}

// When the handover should end, from now: one choice sends stream.keep with
// that end time. The hub takes one minute to seven days ahead.
enum HubEndTime: String, CaseIterable, Identifiable {
    case hour
    case threeHours
    case halfDay
    case day
    case week
    case noEnd

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .hour:
            HubWords.Access.EndTime.hour
        case .threeHours:
            HubWords.Access.EndTime.threeHours
        case .halfDay:
            HubWords.Access.EndTime.halfDay
        case .day:
            HubWords.Access.EndTime.day
        case .week:
            HubWords.Access.EndTime.week
        case .noEnd:
            HubWords.Access.EndTime.none
        }
    }

    var seconds: TimeInterval? {
        switch self {
        case .hour:
            3600
        case .threeHours:
            3 * 3600
        case .halfDay:
            12 * 3600
        case .day:
            24 * 3600
        case .week:
            7 * 24 * 3600
        case .noEnd:
            nil
        }
    }

    // What the choice asks the hub for (stream.keep).
    func request(now: Date) -> [String: Any] {
        guard let seconds else {
            return ["end_time": NSNull()]
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return ["end_time": formatter.string(from: now.addingTimeInterval(seconds))]
    }

    // The five, and No end time while one is set.
    static func choices(endTime: String?) -> [HubEndTime] {
        allCases.filter { $0 != .noEnd || endTime != nil }
    }
}

// The times of a handover the list names, from the newest state when that
// names the same device: an answer or Go live moves them before the list
// is read again.
func hubHandoverTimes(_ run: HubRunBy, state: HubState?) -> HubRunBy {
    guard let state else {
        return run
    }
    var times = run
    if let newest = state.session.runBy, newest.device == run.device?.id {
        times.endsAt = newest.endsAt
        times.endsWhy = newest.endsWhy
        times.endTime = newest.endTime
        times.stoppedAt = newest.stoppedAt
        times.askedAt = newest.askedAt
        times.waitUntil = newest.waitUntil
    }
    return times
}

// When a handover ends, as facts: by why it would end, and the owner's end
// time when that isn't already the reason.
func hubHandoverEnds(_ run: HubRunBy, live: Bool, when: HubWhen) -> [String] {
    var facts: [String] = []
    if let endsAt = run.endsAt {
        facts.append(HubWords.Access.runEnds(run.endsWhy, live: live, when.text(endsAt)))
    }
    if let endTime = run.endTime, run.endsWhy != "time" {
        facts.append(HubWords.Access.runEndTime(when.text(endTime)))
    }
    return facts
}

// The open ask, for an owner device that may answer it.
func hubHandoverAsk(_ run: HubRunBy,
                    live: Bool,
                    answers: Bool,
                    filled: Bool,
                    when: HubWhen) -> HubHandoverAsk?
{
    guard answers, run.askedAt != nil else {
        return nil
    }
    let device = run.device?.name ?? ""
    return HubHandoverAsk(title: run.forName?.isEmpty == false ? HubWords.Access.Ask.title(run.forName!)
                              : HubWords.Access.Ask.titleDevice(device),
                          since: run.givenAt.map { HubWords.Access.Ask.since(when.text($0)) },
                          line: live ? HubWords.Access.Ask.live(when.text(run.endsAt))
                              : HubWords.Access.Ask.idle(when.text(run.endsAt)),
                          filled: filled)
}

struct HubAccessLinkRow: Equatable, Identifiable {
    let id: String
    let name: String
    let presence: String
    let here: Bool
    let facts: [String]
    let end: HubAccessRow.End?

    var spoken: String {
        ([name, presence] + facts).joined(separator: ". ")
    }
}

func hubGiveBackConfirm() -> HubAccessRow.End {
    .init(label: HubWords.Crew.giveBack, confirm: HubWords.Crew.giveBackConfirm)
}

func hubAccessLinks(_ access: HubAccess, when: HubWhen) -> [HubAccessLinkRow] {
    (access.ownerLinks ?? []).map { link in
        let device = link.device?.name?.isEmpty == false ? link.device!.name! : HubWords.Access.anOwnerDevice
        let opened = link.state != "open"
        return HubAccessLinkRow(
            id: link.id,
            name: HubWords.Access.linkName(device),
            presence: !opened ? HubWords.Access.linkNotOpened
                : link.online == true ? HubWords.Access.linkOpen : HubWords.Access.linkClosed,
            here: opened && link.online == true,
            facts: [link.openedAt != nil
                ? HubWords.Access.linkOpened(when.text(link.madeAt), when.text(link.openedAt))
                : HubWords.Access.linkMade(when.text(link.madeAt)),
                HubWords.Access.linkEnds(when.text(link.endsAt))],
            end: link.can?.contains("end") == true
                ? .init(label: HubWords.Access.endNow, confirm: HubWords.Access.linkConfirm) : nil
        )
    }
}

struct HubTrailLine: Equatable, Identifiable {
    let id: Int
    let text: String
    let at: String
}

// The whole screen as a pure function of what the hub reported.
struct HubAccessPage: Equatable {
    let kind: HubStatusKind
    // "<hub> · LIVE"
    let label: String
    // "2 devices, 1 helper and 1 mod. 1 is waiting for Allow."
    let line: String
    let running: HubAccessRunning?
    let sections: [HubAccessSection]
    let links: [HubAccessLinkRow]
    let trail: [HubTrailLine]
    let more: Bool
    // An owner may clear the trail.
    let clear: Bool
    // False while the hub is out of reach: the list is the last one seen,
    // and nothing on it can be pressed.
    let current: Bool
}

private func count(_ number: Int, _ one: String, _ many: String) -> String {
    "\(number) \(number == 1 ? one : many)"
}

// state is the newest state the hub sent. It decides whether the handover
// the list names is still on; the list itself can be one request older.
func hubAccessPage(_ access: HubAccess?,
                   state: HubState? = nil,
                   connected: Bool,
                   older: [HubTrailEntry] = [],
                   more: Bool? = nil,
                   when: HubWhen) -> HubAccessPage?
{
    guard let access else {
        return nil
    }
    let people = access.people ?? []
    // Whether a device runs the stream now: from the newest state, and a
    // handover past its end is over here even before the hub says so.
    func runsNow(_ device: String?) -> Bool {
        if let state {
            return state.runsStream(device, now: when.now)
        }
        guard let run = access.stream.runBy, run.kind == "handed", run.device?.id == device else {
            return false
        }
        return hubHandoverOn(run.endsAt, now: when.now)
    }
    let me = access.asWho?.id
    let guest = access.asWho?.role != "admin" && runsNow(me)
    let shared = people.count > 1 || guest
    // Live as the newest state says, else as the list says.
    let live = state.map { $0.session.live == "live" } ?? (access.stream.live == "live")
    func rows(_ test: (HubGrant) -> Bool) -> [HubAccessRow] {
        access.grants.filter(test).map { hubAccessRow($0, when: when, shared: shared, live: live) }
    }
    func owner(_ grant: HubGrant) -> HubPerson? {
        people.first { $0.id == grant.person?.id } ?? (people.count == 1 ? people[0] : nil)
    }
    func device(_ grant: HubGrant) -> Bool {
        grant.kind == "device" && grant.state == "active"
    }
    let waiting = rows { $0.kind == "device" && $0.state == "waiting" }
    let yours = rows { device($0) && $0.role != "helper" }
    let unowned = rows { device($0) && $0.role != "helper" && owner($0) == nil }
    let owned = people.map { person in
        let title: String
        if person.you == true {
            title = person.name?.isEmpty == false ? HubWords.Access.youNamed(person.name!) : HubWords.Access.you
        } else {
            title = person.name?.isEmpty == false ? person.name! : HubWords.Access.unnamed
        }
        return HubAccessSection(id: "owner-\(person.id)",
                                title: title,
                                tag: people.count > 1 ? HubWords.Access.coOwner : HubWords.Access.owner,
                                rows: rows { device($0) && $0.role != "helper" && owner($0) == person })
    }
    let helpers = rows { device($0) && $0.role == "helper" }
    let mods = rows { $0.kind == "mod" }
    let invites = rows { $0.kind == "invite" }
    let sections = ([
        HubAccessSection(id: "waiting", title: HubWords.Access.waiting, rows: waiting),
    ] + owned + [
        HubAccessSection(id: "yours",
                         title: guest ? HubWords.Crew.groupDevices
                             : people.isEmpty ? HubWords.Access.yours : HubWords.Access.others,
                         rows: unowned),
        HubAccessSection(id: "helpers", title: HubWords.Access.helpers, rows: helpers),
        HubAccessSection(id: "mods", title: HubWords.Access.mods, rows: mods),
        HubAccessSection(id: "invites", title: HubWords.Access.invites, rows: invites),
    ]).filter { !$0.rows.isEmpty }
    var running: HubAccessRunning?
    if let listed = access.stream.runBy, listed.kind == "handed", runsNow(listed.device?.id) {
        let run = hubHandoverTimes(listed, state: state)
        let answers = access.can?.contains("keep_stream") == true
        let device = run.device?.name ?? ""
        let gave = gaveList(run.gave)
        var facts = [HubWords.Access.runBy(run.givenBy?.name?.isEmpty == false ? run.givenBy!.name!
                : HubWords.Access.anOwnerDevice,
            when.text(run.givenAt))]
        facts += hubHandoverEnds(run, live: live, when: when)
        if !gave.isEmpty {
            facts.append(HubWords.Access.runGave(gave))
        }
        let name = run.forName?.isEmpty == false ? run.forName! : device
        let canTakeBack = access.grants.first { $0.id == run.device?.id }?.can.contains("take_back") == true
        let mine = guest && me == run.device?.id
        let ask = hubHandoverAsk(run, live: live, answers: answers, filled: !waiting.contains { $0.allow },
                                 when: when)
        running = HubAccessRunning(
            line: run.forName?.isEmpty == false ? HubWords.Access.runHanded(run.forName!, device)
                : HubWords.Access.runHandedDevice(device),
            facts: facts,
            device: run.device?.id,
            takeBack: canTakeBack && !mine
                ? .init(label: ask == nil ? HubWords.Access.takeBack : HubWords.Access.Ask.takeBack,
                        confirm: gave.isEmpty ? HubWords.Access.confirmTakeBack(name)
                            : HubWords.Access.confirmTakeBackGave(name, gave)) : nil,
            giveBack: mine ? hubGiveBackConfirm() : nil,
            ask: ask,
            endTimes: answers && !mine ? HubEndTime.choices(endTime: run.endTime) : nil
        )
    } else if access.people != nil {
        let line: String
        if let run = access.stream.runBy, run.kind == "went_live" {
            let device = run.device?.name ?? ""
            line = run.person?.name?.isEmpty == false ? HubWords.Access.runWentLive(run.person!.name!, device)
                : HubWords.Access.runWentLiveDevice(device)
        } else {
            line = HubWords.Access.runOwners
        }
        running = HubAccessRunning(line: line, facts: [], device: nil, takeBack: nil)
    }
    let counts = [
        (people.count > 1 ? people.count : 0, String(localized: "owner"), String(localized: "owners")),
        (yours.count, String(localized: "device"), String(localized: "devices")),
        (helpers.count, String(localized: "helper"), String(localized: "helpers")),
        (mods.count, String(localized: "mod"), String(localized: "mods")),
    ].filter { $0.0 > 0 }.map { count($0.0, $0.1, $0.2) }
    var parts = counts.isEmpty ? [] : [listAnd(counts)]
    if !waiting.isEmpty {
        parts.append(waiting.count == 1 ? String(localized: "1 is waiting for Allow")
            : String(localized: "\(waiting.count) are waiting for Allow"))
    }
    let line = parts.isEmpty ? "" : parts.joined(separator: ". ") + "."
    let kind: HubStatusKind
    let word: String
    if access.stream.live == "live" {
        kind = access.stream.hidden ? .hidden : .live
        word = access.stream.hidden ? HubWords.Access.streamHidden : HubWords.Access.streamLive
    } else if access.stream.live == "ended" {
        kind = .ready
        word = HubWords.Access.streamEnded
    } else {
        kind = .ready
        word = HubWords.Access.streamReady
    }
    var seen = Set<Int>()
    let entries = (access.trail + older).filter { seen.insert($0.seq).inserted }
    return HubAccessPage(kind: connected ? kind : .unknown,
                         label: connected ? "\(access.hub) · \(word)"
                             : "\(access.hub) · \(HubWords.Access.unknownTitle)",
                         line: connected ? line : HubWords.Access.unknownLine,
                         running: running,
                         sections: sections,
                         links: hubAccessLinks(access, when: when),
                         trail: entries.map {
                             HubTrailLine(id: $0.seq, text: hubTrailLine($0, when: when), at: when.text($0.at))
                         },
                         more: more ?? access.trailMore ?? false,
                         clear: access.can?.contains("clear_trail") == true && !entries.isEmpty,
                         current: connected)
}

// A device that joined by link and waits for an owner's Allow, from the
// state every device gets.
func hubWaitingDevices(_ state: HubState?) -> [HubDevice] {
    state?.devices.filter { !$0.allowed } ?? []
}

// The crew as every device in the setup sees it: helpers and mod links by
// name, no links and no controls.
struct HubCrewSummary: Equatable {
    var helpers: [HubDevice] = []
    var mods: [HubMod] = []
    var openHelperLinks = 0

    var isEmpty: Bool {
        helpers.isEmpty && mods.isEmpty && openHelperLinks == 0
    }

    // "1 helper · 1 mod link · 1 open link"
    var line: String? {
        var parts: [String] = []
        if !helpers.isEmpty {
            parts.append(count(helpers.count, String(localized: "helper"), String(localized: "helpers")))
        }
        if !mods.isEmpty {
            parts.append(count(mods.count, String(localized: "mod link"), String(localized: "mod links")))
        }
        if openHelperLinks > 0 {
            parts.append(count(openHelperLinks,
                               String(localized: "open helper link"),
                               String(localized: "open helper links")))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

func hubCrewSummary(_ state: HubState?) -> HubCrewSummary {
    guard let state else {
        return HubCrewSummary()
    }
    return HubCrewSummary(helpers: state.devices.filter { $0.role == "helper" && $0.allowed },
                          mods: state.mods ?? [],
                          openHelperLinks: (state.invites ?? []).filter { $0.role == "helper" }.count)
}
