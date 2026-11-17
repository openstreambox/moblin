import Foundation


enum HubCrewAdd: Equatable {
    case helper
    case mod
    case coOwner

    var label: String {
        switch self {
        case .helper:
            HubWords.Crew.addHelper
        case .mod:
            HubWords.Crew.addMod
        case .coOwner:
            HubWords.Crew.addCoOwner
        }
    }
}

struct HubCrewRow: Equatable, Identifiable {
    let id: String
    let kind: String
    let name: String
    let aside: String?
    let tag: String?
    let status: String
    let here: Bool
    let line: String?
    let end: HubAccessRow.End?

    var title: String {
        aside.map { "\(name) · \($0)" } ?? name
    }

    var statusLine: String {
        tag.map { "\(status) · \($0)" } ?? status
    }

    var spoken: String {
        [title, statusLine, line].compactMap { $0 }.joined(separator: ". ")
    }
}

struct HubCrewGroup: Equatable, Identifiable {
    let id: String
    let title: String
    let tag: String?
    let empty: String?
    let add: HubCrewAdd?
    var yours = false
    let rows: [HubCrewRow]
}

struct HubWaiting: Equatable, Identifiable {
    let id: String
    let name: String
    let title: String
    let line: String
    let allow: Bool
    let confirm: HubAccessRow.End?
    let allows: String
}

struct HubCrewStream: Equatable {
    let line: String
    let detail: String?
    let device: String?
    let takeBack: HubAccessRow.End?
}

struct HubSessionOwner: Equatable {
    let role: String
    let line: String
    let allows: String
    let ends: String?
    let giveBack: HubAccessRow.End
}

struct HubCrewPage: Equatable {
    let manages: Bool
    let owner: Bool
    let runs: Bool
    let line: String
    let waiting: [HubWaiting]
    let groups: [HubCrewGroup]
    let stream: HubCrewStream?
    let session: HubSessionOwner?
    let summary: String
    let ownName: String?
    let others: [HubPerson]
}

private func roleTag(_ role: String, shared: Bool) -> String {
    switch role {
    case "member":
        HubWords.Access.role(shared ? "shared" : "member")
    case "admin", "helper":
        HubWords.Access.role(role)
    default:
        HubWords.Access.role("mod")
    }
}

func hubCrewSpan(since: String?, endsAt: String?, endsWithStream: Bool, when: HubWhen) -> String? {
    var parts: [String] = []
    if since != nil {
        parts.append(HubWords.Crew.sinceAt(when.calm(since)))
    }
    if endsWithStream {
        parts.append(endsAt == nil ? HubWords.Crew.endsStream : HubWords.Crew.endsStreamOr(when.text(endsAt)))
    } else if endsAt != nil {
        parts.append(HubWords.Crew.endsAt(when.text(endsAt)))
    }
    return parts.isEmpty ? nil : parts.joined(separator: " · ")
}

private func plural(_ number: Int, _ one: String, _ many: String) -> String {
    "\(number) \(number == 1 ? one : many)"
}

func hubSessionAllows(_ role: String) -> [String] {
    Array(Set(hubRoleAllows(role) + ["stream.go_live", "stream.move", "stream.end", "privacy.hide",
                                     "privacy.show", "invite.open"]))
}

let hubSessionLimits = ["invite.open": "stream"]

func hubSessionOwner(state: HubState?,
                     access: HubAccess?,
                     me: String?,
                     role: String,
                     told: (allows: [String], limits: [String: String])? = nil,
                     when: HubWhen) -> HubSessionOwner?
{
    guard let state, role != "admin", state.runsStream(me) else {
        return nil
    }
    let mine = access?.grants.first { $0.isSelf == true && $0.runsStream == true }
    let allows = mine?.allows ?? told?.allows ?? hubSessionAllows(role)
    let limits = mine?.limits ?? told?.limits ?? hubSessionLimits
    return HubSessionOwner(role: HubWords.Access.role("session"),
                           line: HubWords.Crew.youRun,
                           allows: hubAllowsLine(allows, limits: limits),
                           ends: state.session.runBy?.endsAt.map { HubWords.Crew.streamUntil(when.text($0)) },
                           giveBack: hubGiveBackConfirm())
}

private func waitingRows(_ access: HubAccess, shared: Bool) -> [HubWaiting] {
    access.grants.filter { $0.kind == "device" && $0.state == "waiting" }.map { grant in
        let person = grant.person?.name?.isEmpty == false ? grant.person!.name! : HubWords.Access.unnamedLower
        let allow = grant.can.contains("allow")
        let title: String
        if grant.newOwner == true {
            title = HubWords.Crew.coOwnerWants(grant.name)
        } else if grant.role == "admin" {
            title = HubWords.Crew.coOwnerWantsOwn(grant.name, person)
        } else {
            title = HubWords.Crew.wants(grant.name, roleTag(grant.role, shared: shared).lowercased())
        }
        let line: String
        if !allow {
            line = HubWords.Access.theirs(person)
        } else if grant.newOwner == true {
            line = HubWords.Access.noteNewOwner(person)
        } else if grant.handsStream == true {
            line = HubWords.Crew.wantsHand
        } else if grant.how == "link" {
            line = HubWords.Crew.wantsLine
        } else {
            line = HubWords.Access.noteOtherOwner(person)
        }
        return HubWaiting(id: grant.id,
                          name: grant.name,
                          title: title,
                          line: line,
                          allow: allow,
                          confirm: allow && grant.newOwner == true
                              ? hubCoOwnerConfirm(person: grant.person?.name, device: grant.name) : nil,
                          allows: hubAllowsLine(grant.allows, limits: grant.limits ?? [:]))
    }
}

private func endOf(_ grant: HubGrant, _ name: String) -> HubAccessRow.End? {
    guard grant.can.contains("end") else {
        return nil
    }
    switch grant.kind {
    case "device":
        return .init(label: HubWords.Access.remove,
                     confirm: grant.carriesStream == true ? HubWords.Access.confirmRemoveCarrier(name)
                         : HubWords.Access.confirmRemove(name))
    case "mod":
        return .init(label: HubWords.Access.endNow, confirm: HubWords.Access.confirmEndMod(name))
    default:
        return .init(label: HubWords.Crew.endLink, confirm: HubWords.Access.confirmEndInvite)
    }
}

private func deviceRow(_ grant: HubGrant, me: String?, shared: Bool, when: HubWhen) -> HubCrewRow {
    let helper = grant.role == "helper"
    let isMe = grant.id == me || grant.isSelf == true
    let aside: String?
    if isMe {
        aside = HubWords.Crew.thisPhone
    } else if let forName = grant.forName, !forName.isEmpty, forName != grant.name {
        aside = String(localized: "for \(forName)")
    } else {
        aside = nil
    }
    let line = helper || grant.endsAt != nil || grant.endsWithStream == true
        ? hubCrewSpan(since: helper ? grant.joinedAt : nil,
                      endsAt: grant.endsAt,
                      endsWithStream: grant.endsWithStream == true,
                      when: when)
        : nil
    return HubCrewRow(id: grant.id,
                      kind: "device",
                      name: grant.name,
                      aside: aside,
                      tag: grant.runsStream == true ? HubWords.Crew.runs : roleTag(grant.role, shared: shared),
                      status: grant.online == true ? HubWords.Crew.present : HubWords.Crew.away,
                      here: grant.online == true,
                      line: line,
                      end: isMe ? nil : endOf(grant, grant.name))
}

private func inviteRow(_ grant: HubGrant, shared: Bool, when: HubWhen) -> HubCrewRow {
    let name: String
    if !grant.name.isEmpty {
        name = HubWords.Crew.linkFor(grant.name)
    } else if grant.role == "helper" {
        name = HubWords.Crew.linkPlain
    } else {
        name = String(localized: "\(roleTag(grant.role, shared: shared)) invite")
    }
    return HubCrewRow(id: grant.id,
                      kind: "invite",
                      name: name,
                      aside: nil,
                      tag: nil,
                      status: HubWords.Crew.notOpened,
                      here: false,
                      line: grant.endsAt.map { HubWords.Crew.closesAt(when.text($0)) },
                      end: endOf(grant, name))
}

private func modRow(_ grant: HubGrant, when: HubWhen) -> HubCrewRow {
    let open = grant.state == "open"
    return HubCrewRow(id: grant.id,
                      kind: "mod",
                      name: grant.name,
                      aside: nil,
                      tag: nil,
                      status: open ? HubWords.Crew.notOpened
                          : grant.online == true ? HubWords.Access.pageOpen : HubWords.Access.pageClosed,
                      here: !open && grant.online == true,
                      line: hubCrewSpan(since: open ? nil : grant.joinedAt ?? grant.givenAt,
                                        endsAt: grant.endsAt,
                                        endsWithStream: grant.endsWithStream == true,
                                        when: when),
                      end: endOf(grant, grant.name))
}

private func crewFromState(_ state: HubState?, me: String?, role: String, manages: Bool) -> [HubCrewGroup] {
    let devices = (state?.devices ?? []).filter(\.allowed)
    func row(_ device: HubDevice) -> HubCrewRow {
        HubCrewRow(id: device.id,
                   kind: "device",
                   name: device.name,
                   aside: device.id == me ? HubWords.Crew.thisPhone : nil,
                   tag: state?.runsStream(device.id) == true ? HubWords.Crew.runs
                       : roleTag(device.role, shared: role == "helper"),
                   status: device.online == true ? HubWords.Crew.present : HubWords.Crew.away,
                   here: device.online == true,
                   line: nil,
                   end: nil)
    }
    let mods = (state?.mods ?? []).map { mod in
        HubCrewRow(id: mod.id,
                   kind: "mod",
                   name: mod.name,
                   aside: nil,
                   tag: nil,
                   status: mod.state != "joined" ? HubWords.Crew.notOpened
                       : mod.online == true ? HubWords.Access.pageOpen : HubWords.Access.pageClosed,
                   here: mod.state == "joined" && mod.online == true,
                   line: nil,
                   end: nil)
    }
    return [
        HubCrewGroup(id: "devices",
                     title: HubWords.Crew.groupDevices,
                     tag: nil,
                     empty: nil,
                     add: nil,
                     rows: devices.filter { $0.role != "helper" }.map(row)),
        HubCrewGroup(id: "helpers",
                     title: HubWords.Crew.groupHelpers,
                     tag: nil,
                     empty: manages ? HubWords.Crew.emptyHelpers : nil,
                     add: manages ? .helper : nil,
                     rows: devices.filter { $0.role == "helper" }.map(row)),
        HubCrewGroup(id: "mods",
                     title: HubWords.Crew.groupMods,
                     tag: nil,
                     empty: manages ? HubWords.Crew.emptyMods : nil,
                     add: manages ? .mod : nil,
                     rows: mods),
    ].filter { !$0.rows.isEmpty || $0.add != nil }
}

func hubCrewPage(state: HubState?,
                 access: HubAccess?,
                 me: String?,
                 role: String,
                 told: (allows: [String], limits: [String: String])? = nil,
                 when: HubWhen) -> HubCrewPage
{
    let owner = role == "admin"
    let runs = !owner && state?.runsStream(me) == true
    let manages = owner || runs
    let line = role == "helper" && !runs ? HubWords.Setup.crewLineHelper : HubWords.Setup.crewLine
    let session = hubSessionOwner(state: state, access: access, me: me, role: role, told: told, when: when)
    guard let access, manages else {
        let waiting = owner ? hubWaitingDevices(state).filter { $0.role != "admin" }.map { device in
            HubWaiting(id: device.id,
                       name: device.name,
                       title: HubWords.Crew.wants(device.name, roleTag(device.role, shared: false).lowercased()),
                       line: HubWords.Crew.wantsLine,
                       allow: true,
                       confirm: nil,
                       allows: hubAllowsLine(hubRoleAllows(device.role)))
        } : []
        return HubCrewPage(manages: manages,
                           owner: owner,
                           runs: runs,
                           line: line,
                           waiting: waiting,
                           groups: crewFromState(state, me: me, role: role, manages: manages),
                           stream: nil,
                           session: session,
                           summary: "",
                           ownName: nil,
                           others: [])
    }
    let people = access.people ?? []
    let several = people.count > 1
    let shared = several || !owner
    func active(_ grant: HubGrant) -> Bool {
        grant.kind == "device" && grant.state == "active"
    }
    func mine(_ grant: HubGrant) -> Bool {
        active(grant) && grant.role != "helper"
    }
    func of(_ grant: HubGrant) -> HubPerson? {
        people.first { $0.id == grant.person?.id } ?? (people.count == 1 ? people[0] : nil)
    }
    func rows(_ test: (HubGrant) -> Bool) -> [HubCrewRow] {
        access.grants.filter(test).map { deviceRow($0, me: me, shared: shared, when: when) }
    }
    func sent(_ grant: HubGrant) -> Bool {
        grant.kind == "invite" && grant.how == "link"
    }
    var groups = people.map { person in
        let title: String
        if person.you == true {
            title = person.name?.isEmpty == false ? HubWords.Access.youNamed(person.name!) : HubWords.Access.you
        } else {
            title = person.name?.isEmpty == false ? person.name! : HubWords.Access.unnamed
        }
        return HubCrewGroup(id: "owner-\(person.id)",
                            title: title,
                            tag: several ? HubWords.Access.coOwner : HubWords.Access.owner,
                            empty: nil,
                            add: nil,
                            yours: owner && person.you == true,
                            rows: rows { mine($0) && of($0) == person })
    }
    groups.append(HubCrewGroup(id: "devices",
                               title: people.isEmpty ? HubWords.Crew.groupDevices : HubWords.Access.others,
                               tag: nil,
                               empty: nil,
                               add: nil,
                               rows: rows { mine($0) && of($0) == nil }))
    if owner {
        groups.append(HubCrewGroup(id: "coOwners",
                                   title: HubWords.Crew.groupCoOwners,
                                   tag: nil,
                                   empty: several ? nil : HubWords.Crew.emptyCoOwners,
                                   add: .coOwner,
                                   rows: access.grants.filter { sent($0) && $0.role == "admin" }
                                       .map { inviteRow($0, shared: shared, when: when) }))
    }
    groups.append(HubCrewGroup(id: "helpers",
                               title: HubWords.Crew.groupHelpers,
                               tag: nil,
                               empty: HubWords.Crew.emptyHelpers,
                               add: .helper,
                               rows: rows { active($0) && $0.role == "helper" }
                                   + access.grants.filter { sent($0) && $0.role == "helper" }
                                   .map { inviteRow($0, shared: shared, when: when) }))
    groups.append(HubCrewGroup(id: "mods",
                               title: HubWords.Crew.groupMods,
                               tag: nil,
                               empty: HubWords.Crew.emptyMods,
                               add: .mod,
                               rows: access.grants.filter { $0.kind == "mod" }.map { modRow($0, when: when) }))
    groups = groups.filter { !$0.rows.isEmpty || $0.add != nil || $0.yours }

    var stream: HubCrewStream?
    if owner, let run = access.stream.runBy, run.kind == "handed" {
        let gave = hubGaveList(run.gave)
        let device = run.device?.name ?? ""
        let name = run.forName?.isEmpty == false ? run.forName! : device
        let handed = access.grants.first { $0.id == run.device?.id }
        let detail = [run.endsAt.map { HubWords.Access.runEnds(when.text($0)) },
                      gave.isEmpty ? nil : HubWords.Access.runGave(gave)].compactMap { $0 }
        stream = HubCrewStream(
            line: run.forName?.isEmpty == false ? HubWords.Access.runHanded(run.forName!, device)
                : HubWords.Access.runHandedDevice(device),
            detail: detail.isEmpty ? nil : detail.joined(separator: " · "),
            device: run.device?.id,
            takeBack: handed?.can.contains("take_back") == true
                ? .init(label: HubWords.Access.takeBack,
                        confirm: gave.isEmpty ? HubWords.Access.confirmTakeBack(name)
                            : HubWords.Access.confirmTakeBackGave(name, gave)) : nil
        )
    }
    let counts = [
        (several ? people.count : 0, String(localized: "owner"), String(localized: "owners")),
        (access.grants.filter(mine).count, String(localized: "device"), String(localized: "devices")),
        (access.grants.filter { active($0) && $0.role == "helper" }.count,
         String(localized: "helper"), String(localized: "helpers")),
        (access.grants.filter { $0.kind == "mod" }.count, String(localized: "mod"), String(localized: "mods")),
    ].filter { $0.0 > 0 }.map { plural($0.0, $0.1, $0.2) }
    return HubCrewPage(manages: manages,
                       owner: owner,
                       runs: runs,
                       line: line,
                       waiting: waitingRows(access, shared: shared),
                       groups: groups,
                       stream: stream,
                       session: session,
                       summary: hubListAnd(counts),
                       ownName: access.asWho?.person?.name ?? people.first { $0.you == true }?.name,
                       others: owner ? people.filter { $0.you != true } : [])
}
