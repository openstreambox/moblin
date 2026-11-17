import SwiftUI
import UserNotifications

// The owner's side of the hub on this phone: helper and mod links, Allow,
// and "Who has access" with its trail. Everything goes over the phone's own
// encrypted hub connection (access.get and the access.trail event); nothing
// here opens a web page. The hub decides who may do what: only an owner
// device is offered these, and a refusal is shown, never hidden.

enum HubScreen: Hashable {
    case crew
    case access
    case makeHelper
    case makeMod
    case makeCoOwner
    case ownerName
}

// What a row's button asks about once before the hub is asked.
enum HubAccessAction: Equatable {
    case end
    case coOwner
    case hand
    case takeBack
    case giveBack
    case clear
}

struct HubAccessConfirm: Equatable {
    let grant: String
    let action: HubAccessAction
}

// The id the trail's own requests are filed under.
let hubTrailGrant = "trail"
let hubGiveBackGrant = "stream#give-back"
let hubAllowAllGrant = "waiting#allow-all"

// The handed stream's own requests (Take back, Keep, an end time) are filed
// under this id, apart from the same device's row.
func hubStreamGrant(_ device: String) -> String {
    "\(device)#stream"
}

// What an owner's last answer to the hub's ask did, said on that stream.
struct HubHandoverAnswer: Equatable {
    let grant: String
    let line: String
}

private let hubAskNotice = "osb.hub.stream.ask"

// When a helper's access ends, chosen while making the link.
enum HubHelperAccessEnds: Hashable {
    case stream
    case after(HubLinkDuration)
    case never
}

extension Model {
    // Only an owner device makes links, allows, removes and reads the trail.
    func hubIsOwner() -> Bool {
        isHubJoined() && database.hub.role == "admin" && !hub.pending
    }

    func hubRunsStream() -> Bool {
        isHubJoined() && database.hub.role != "admin" && !hub.pending
            && hub.state?.runsStream(database.hub.deviceId, now: hub.now()) == true
    }

    func hubManages() -> Bool {
        hubIsOwner() || hubRunsStream()
    }

    func hubCrewPageNow() -> HubCrewPage {
        hubCrewPage(state: hub.pending ? nil : hub.state,
                    access: hub.access,
                    me: database.hub.deviceId,
                    role: database.hub.role,
                    told: hub.sessionTold,
                    ending: hub.ending,
                    when: hubWhen())
    }

    func hubWhen() -> HubWhen {
        HubWhen(now: hub.now())
    }

    func hubAccessPageNow() -> HubAccessPage? {
        hubAccessPage(hub.access,
                      state: hub.pending ? nil : hub.state,
                      connected: hub.connected,
                      older: hub.accessOlder,
                      more: hub.accessMore,
                      seen: hub.seen,
                      when: hubWhen())
    }

    func hubOpen(_ screen: HubScreen) {
        if screen == .makeHelper || screen == .makeMod || screen == .makeCoOwner {
            hub.madeLink = nil
        }
        hub.path.append(screen)
    }

    // Back to the crew list once a link has been shared.
    func hubCloseMadeLink() {
        hub.madeLink = nil
        if !hub.path.isEmpty {
            hub.path.removeLast()
        }
    }

    // MARK: - Reading
    // Asks the hub for the list again. Calls while one is under way are
    // folded into one more.
    func hubRefreshAccess() {
        #if DEBUG
        if hub.showcase {
            return
        }
        #endif
        guard hubManages(), let connection = hub.connection else {
            return
        }
        guard hub.accessRefreshTask == nil else {
            hub.accessRefreshAgain = true
            return
        }
        hub.accessLoadFailed = false
        hub.accessRefreshTask = Task { @MainActor in
            if let reply = try? await connection.request("access.get", ["trail_limit": 50]),
               let access = reply.decodeAll(as: HubAccess.self)
            {
                hub.access = access
            } else {
                hub.access = nil
                hub.accessLoadFailed = true
            }
            hub.accessRefreshTask = nil
            if hub.accessRefreshAgain {
                hub.accessRefreshAgain = false
                hubRefreshAccess()
            }
        }
    }

    func hubForgetAccess() {
        hub.accessRefreshTask?.cancel()
        hub.accessRefreshTask = nil
        hub.accessRefreshAgain = false
        hub.access = nil
        hub.accessLoadFailed = false
        hub.accessOlder = []
        hub.accessMore = nil
        hub.accessConfirming = nil
        hub.accessFailed = nil
        hub.accessBusy = []
        hub.allowAllSaid = []
        hub.madeLink = nil
        hub.choosingEndTime = nil
        hub.handoverAnswer = nil
        hub.path = []
    }

    func hubOlderTrail() {
        guard let connection = hub.connection, let access = hub.access else {
            return
        }
        guard let before = (access.trail + hub.accessOlder).map(\.seq).min() else {
            return
        }
        Task { @MainActor in
            guard let reply = try? await connection.request("access.get",
                                                            ["trail_limit": 50, "trail_before": before]),
                let older = reply.decodeAll(as: HubAccess.self)
            else {
                return
            }
            hub.accessOlder += older.trail
            hub.accessMore = older.trailMore ?? false
        }
    }

    // The hub's state changed: say who hid, and read the list again.
    func hubCrewStateChanged(from before: HubState?, to state: HubState) {
        let privacy = state.session.privacy
        if privacy.hidden, let by = privacy.hiddenBy, by.id != database.hub.deviceId, !by.name.isEmpty,
           let before, before.session.privacy.generation != privacy.generation
        {
            makeToast(title: HubWords.Crew.hid(by.name),
                      subTitle: String(localized: "Your privacy screen is on. Viewers don't see you."))
        }
        let me = database.hub.deviceId
        let now = hub.now()
        if before?.runsStream(me, now: now) == true, !state.runsStream(me, now: now), database.hub.role != "admin" {
            hubForgetAccess()
        }
        if state.session.runBy?.device != me {
            hub.ending = nil
        }
        if state.session.runBy?.askedAt == nil, hub.askNoticed || before == nil {
            hubWithdrawAskNotice()
        }
        hubWatchHandover()
        if before?.devices != state.devices || before?.invites != state.invites || before?.mods != state.mods
            || before?.session != state.session
        {
            hubRefreshAccess()
        }
    }

    // A handover with a set end is over on this phone at that time, even
    // when the hub's next state comes late: what it gave goes, and the
    // panel says so once.
    func hubWatchHandover() {
        hub.handoverTimer?.cancel()
        hub.handoverTimer = nil
        let now = hub.now()
        switch hubHandoverWatch(hub.state, me: database.hub.deviceId, role: database.hub.role, now: now) {
        case .none:
            break
        case let .endsAt(end):
            let delay = hubHandoverWakeDelay(end, now: now)
            hub.handoverTimer = Task { @MainActor in
                try? await Task.sleep(nanoseconds: delay)
                guard !Task.isCancelled else {
                    return
                }
                hub.handoverTimer = nil
                hubWatchHandover()
            }
        case .ranOut:
            guard let run = hub.state?.session.runBy, hub.handoverRanOut != run else {
                return
            }
            hub.handoverRanOut = run
            hub.sessionTold = nil
            hub.ending = nil
            hubForgetAccess()
            let line = HubWords.Crew.takenBack(run.endsWhy ?? "time", role: database.hub.role)
            hub.said = line
            makeToast(title: line)
            hub.objectWillChange.send()
        }
    }

    func hubOwnerChangedLine(_ message: HubMessage) -> String? {
        guard let device = message.decode("device", as: HubPersonRef.self)?.name, !device.isEmpty else {
            return nil
        }
        let named = message.decode("person", as: HubPersonRef.self)?.name ?? ""
        let person = named.isEmpty ? HubWords.Access.unnamedLower : named
        let by = message.decode("by", as: HubParty.self)?.name ?? database.hub.name
        if message.string("change") == "removed" {
            return message.bool("person_left") == true ? HubWords.Crew.ownerRemovedLeft(by, device, person)
                : HubWords.Crew.ownerRemoved(by, device, person)
        }
        return message.bool("new_person") == true ? HubWords.Crew.ownerAddedNew(person, device)
            : HubWords.Crew.ownerAdded(device, person)
    }

    func hubHandleCrewMessage(_ message: HubMessage) {
        switch message.type {
        case "access.trail":
            if let entry = message.decode("entry", as: HubTrailEntry.self), var access = hub.access,
               !access.trail.contains(where: { $0.seq == entry.seq })
            {
                access.trail.insert(entry, at: 0)
                hub.access = access
            }
            hubRefreshAccess()
        case "device.pending":
            guard hubManages(), let device = message.decode("device", as: HubDevice.self) else {
                return
            }
            makeToast(title: device.role == "admin" ? HubWords.Crew.wantsOwner(device.name)
                : HubWords.Crew.wants(device.name, HubWords.Access.role(device.role).lowercased()),
                subTitle: HubWords.Access.waiting)
            hubRefreshAccess()
        case "invite.closed", "invite.ticket":
            hubRefreshAccess()
        case "owner.changed":
            guard hubIsOwner(), let line = hubOwnerChangedLine(message) else {
                return
            }
            hub.said = line
            makeToast(title: line)
            hubRefreshAccess()
        case "stream.handed":
            hub.ending = nil
            let by = message.decode("by", as: HubPersonRef.self)?.name ?? ""
            if let allows = message.object["allows"] as? [String] {
                hub.sessionTold = (allows, message.object["limits"] as? [String: String] ?? [:])
            }
            hub.said = HubWords.Crew.handed(by.isEmpty ? HubWords.Access.anOwnerDevice : by)
            makeToast(title: String(localized: "\(by.isEmpty ? HubWords.Access.anOwnerDevice : by) handed you this stream"))
            hubRefreshAccess()
        case "stream.taken_back":
            hub.sessionTold = nil
            hub.ending = nil
            let line = HubWords.Crew.takenBack(message.string("why"), role: database.hub.role)
            // A handover that ran out here first was already said.
            if hub.said != line {
                hub.said = line
                makeToast(title: line)
            }
            if !hubIsOwner() {
                hubForgetAccess()
            }
        case "stream.ending":
            // Only the phone that runs the stream is warned. The line is
            // worded here, with the time in this phone's clock.
            guard !hubIsOwner(), let endsAt = message.string("ends_at") else {
                return
            }
            let ending = HubEnding(endsAt: endsAt, why: message.string("why"), live: message.bool("live") == true)
            hub.ending = ending
            makeToast(title: HubWords.Crew.ending(ending.why, live: ending.live, hubWhen().text(endsAt)))
        case "stream.ask":
            // On an owner device: a quiet question, never a sheet. The
            // answers are on the handed stream; ignoring it is safe.
            guard hubIsOwner() else {
                return
            }
            let device = message.decode("device", as: HubPersonRef.self)?.name ?? ""
            let who = message.string("for") ?? ""
            let title = who.isEmpty ? HubWords.Access.Ask.titleDevice(device) : HubWords.Access.Ask.title(who)
            let endsAt = message.string("ends_at")
            let line = HubWords.Access.Ask.line(live: message.bool("live") == true, endsAt: endsAt, when: hubWhen())
            makeToast(title: title, subTitle: line)
            hubPostAskNotice(title: title, line: line)
            hubRefreshAccess()
        default:
            break
        }
    }

    // The ask as a quiet notification: delivered to the notification list
    // without a sound, and without asking for permission first.
    private func hubPostAskNotice(title: String, line: String) {
        #if DEBUG
        if hub.showcase {
            return
        }
        #endif
        hub.askNoticed = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.provisional, .alert]) { granted, _ in
            guard granted else {
                return
            }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = line
            content.interruptionLevel = .passive
            UNUserNotificationCenter.current()
                .add(UNNotificationRequest(identifier: hubAskNotice, content: content, trigger: nil),
                     withCompletionHandler: nil)
        }
    }

    func hubWithdrawAskNotice() {
        hub.askNoticed = false
        let center = UNUserNotificationCenter.current()
        center.removeDeliveredNotifications(withIdentifiers: [hubAskNotice])
        center.removePendingNotificationRequests(withIdentifiers: [hubAskNotice])
    }

    // MARK: - One request for one row
    // A refusal, or a request that didn't reach the hub, is shown on that
    // row. The list itself only changes when the hub reports it.
    private func hubAccessRequest(_ grant: String,
                                  _ type: String,
                                  _ params: [String: Any],
                                  done: ((HubMessage) -> Void)? = nil,
                                  refused: (() -> Void)? = nil)
    {
        hub.accessConfirming = nil
        hub.accessFailed = nil
        hub.accessFailedLine = HubWords.Access.failed
        hub.handoverAnswer = nil
        guard let connection = hub.connection else {
            refused?()
            hub.accessFailed = grant
            return
        }
        hub.accessBusy.insert(grant)
        Task { @MainActor in
            do {
                let reply = try await connection.request(type, params)
                done?(reply)
            } catch let error as HubRequestError {
                refused?()
                switch error.code {
                case "confirm_needed":
                    // A new co-owner's device: the hub wants the owner's
                    // explicit yes. Ask for it; never send it unasked.
                    hub.accessConfirming = HubAccessConfirm(grant: grant, action: .coOwner)
                default:
                    hub.accessFailedLine = HubWords.Crew.refused(error.code)
                        ?? (error.message.isEmpty ? HubWords.Access.failed
                            : String(localized: "The hub didn't do that: \(error.message)."))
                    hub.accessFailed = grant
                }
            } catch {
                hub.accessFailed = grant
            }
            hub.accessBusy.remove(grant)
            hubRefreshAccess()
        }
    }

    // coOwner is sent only after the owner has read and confirmed what
    // making someone a co-owner means.
    func hubAllow(_ device: String, coOwner: Bool = false) {
        hubAccessRequest(device, "device.allow", coOwner ? ["device": device, "co_owner": true] : ["device": device])
    }

    func hubAllowAll(_ devices: [HubWaitingName]) {
        guard let connection = hub.connection else {
            hub.accessFailed = hubAllowAllGrant
            hub.accessFailedLine = HubWords.Access.failed
            return
        }
        hub.accessFailed = nil
        hub.allowAllSaid = []
        hub.accessBusy.insert(hubAllowAllGrant)
        Task { @MainActor in
            var allowed = 0
            var own: [String] = []
            for device in devices {
                do {
                    _ = try await connection.request("device.allow", ["device": device.id])
                    allowed += 1
                } catch {
                    own.append(device.name)
                }
            }
            hub.allowAllSaid = (allowed > 0 ? [HubWords.Takeover.allowed(allowed)] : [])
                + own.map { HubWords.Takeover.ownYes($0) }
            hub.accessBusy.remove(hubAllowAllGrant)
            hubRefreshAccess()
        }
    }

    // The person a waiting device would make a co-owner, when the list says so.
    func hubCoOwnerConfirmFor(device: HubDevice) -> HubAccessRow.End {
        let grant = hub.access?.grants.first { $0.id == device.id }
        return hubCoOwnerConfirm(person: grant?.person?.name, device: device.name)
    }

    func hubNeedsCoOwnerConfirm(device: String) -> Bool {
        hub.access?.grants.first { $0.id == device }?.newOwner == true
    }

    // wait: how long a handover given while not live may wait for Go live.
    func hubHandStream(_ device: String, wait: HubWait? = nil) {
        hubAccessRequest(device, "stream.hand", hubHandRequest(device, wait: wait))
    }

    func hubTakeBackStream(_ grant: String) {
        hubAccessRequest(grant, "stream.take_back", [:])
    }

    // An owner's answer to the hub's ask, or a new end time (or none):
    // stream.keep. The hub's next state carries the handover's new end.
    func hubKeepStream(_ device: String, endTime: HubEndTime? = nil) {
        let grant = hubStreamGrant(device)
        hub.choosingEndTime = nil
        hubAccessRequest(grant, "stream.keep", endTime?.request(now: hub.now()) ?? [:]) { [weak self] reply in
            guard let self else {
                return
            }
            let line: String?
            if endTime == nil {
                line = HubWords.Access.Ask.kept
            } else {
                line = reply.decode("run_by", as: HubRunBy.self)?.endTime
                    .map { HubWords.Access.Ask.endSet(self.hubWhen().text($0)) }
            }
            hub.handoverAnswer = line.map { HubHandoverAnswer(grant: grant, line: $0) }
        }
    }

    func hubGiveBackStream() {
        hubAccessRequest(hubGiveBackGrant, "stream.take_back", [:])
    }

    func hubClearTrail() {
        hub.accessOlder = []
        hub.accessMore = nil
        hubAccessRequest(hubTrailGrant, "access.trail.clear", [:])
    }

    // Removes a device, ends a mod link or closes an invite.
    func hubEndAccess(_ grant: String) {
        hubAskedRemoval(grant)
        hubAccessRequest(grant, "access.end", ["grant": grant], refused: { [weak self] in
            self?.hubRefusedRemoval(grant)
        })
    }

    func hubChangeAccess(_ grant: String, _ change: HubAccessChange) {
        var params = change.request(now: Date())
        params["grant"] = grant
        hubAccessRequest(grant, "access.change", params)
    }

    // MARK: - Making links

    private func hubMakeLink(_ type: String,
                             _ params: [String: Any],
                             _ made: (HubMessage) -> HubMadeLink?) async -> String?
    {
        guard let connection = hub.connection else {
            return HubWords.Access.failed
        }
        do {
            let reply = try await connection.request(type, params)
            guard let link = made(reply) else {
                return HubWords.Access.failed
            }
            hub.madeLink = link
            hubRefreshAccess()
            return nil
        } catch let error as HubRequestError {
            if error.code == "not_allowed" {
                return HubWords.Crew.notOwner
            }
            return HubWords.Crew.refused(error.code)
                ?? (error.message.isEmpty ? HubWords.Access.failed : error.message)
        } catch {
            return HubWords.Access.failed
        }
    }

    func hubMakeHelperLink(name: String,
                           linkLasts: HubLinkDuration,
                           ends: HubHelperAccessEnds,
                           handStream: Bool = false) async -> String?
    {
        let label = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var params: [String: Any] = ["role": "helper", "via": "link", "expires_ms": linkLasts.milliseconds]
        if !label.isEmpty {
            params["for"] = String(label.prefix(64))
        }
        switch handStream || !hubIsOwner() ? .stream : ends {
        case .stream:
            params["until_stream"] = true
        case let .after(duration):
            params["access_ms"] = duration.milliseconds
        case .never:
            break
        }
        if handStream {
            params["hand_stream"] = true
        }
        return await hubMakeLink("invite.open", params) { reply in
            guard let link = reply.string("link") else {
                return nil
            }
            return HubMadeLink(kind: .helper, name: label, link: link, closesAt: reply.string("closes_at"))
        }
    }

    // A mod's web link: works once, status and HIDE only, no Allow.
    func hubMakeModLink(name: String, linkLasts: HubLinkDuration, untilStream: Bool) async -> String? {
        let label = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var params: [String: Any] = ["expires_ms": linkLasts.milliseconds]
        if !label.isEmpty {
            params["name"] = String(label.prefix(64))
        }
        if untilStream {
            params["until_stream"] = true
        }
        return await hubMakeLink("mod.open", params) { reply in
            guard let link = reply.string("link") else {
                return nil
            }
            return HubMadeLink(kind: .mod,
                               name: label.isEmpty ? HubWords.Crew.modName : label,
                               link: link,
                               closesAt: reply.string("expires_at"))
        }
    }

    func hubNameOwner(_ name: String) async -> String? {
        let label = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty else {
            return nil
        }
        guard let connection = hub.connection else {
            return HubWords.Access.failed
        }
        do {
            _ = try await connection.request("owner.name", ["name": String(label.prefix(64))])
            hubRefreshAccess()
            return nil
        } catch let error as HubRequestError {
            return error.message.isEmpty ? HubWords.Access.failed : error.message
        } catch {
            return HubWords.Access.failed
        }
    }

    func hubMakeCoOwnerLink(name: String, person: HubPerson?, ownName: String) async -> String? {
        if let failure = await hubNameOwner(ownName) {
            return failure
        }
        let label = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var params: [String: Any] = ["role": "admin", "via": "link"]
        if let person {
            params["person"] = person.id
        } else {
            guard !label.isEmpty else {
                return nil
            }
            params["co_owner"] = String(label.prefix(64))
        }
        let shown = person.map { $0.name?.isEmpty == false ? $0.name! : HubWords.Access.unnamed } ?? label
        return await hubMakeLink("invite.open", params) { reply in
            guard let link = reply.string("link") else {
                return nil
            }
            return HubMadeLink(kind: .coOwner(known: person != nil),
                               name: shown,
                               link: link,
                               closesAt: reply.string("closes_at") ?? reply.string("expires_at"))
        }
    }
}
