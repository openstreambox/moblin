import SwiftUI

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
}

// What a row's button asks about once before the hub is asked.
enum HubAccessAction: Equatable {
    case end
    case coOwner
    case hand
    case takeBack
    case clear
}

struct HubAccessConfirm: Equatable {
    let grant: String
    let action: HubAccessAction
}

// The id the trail's own requests are filed under.
let hubTrailGrant = "trail"

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

    func hubWhen() -> HubWhen {
        HubWhen(now: Date())
    }

    func hubAccessPageNow() -> HubAccessPage? {
        hubAccessPage(hub.access,
                      connected: hub.connected,
                      older: hub.accessOlder,
                      more: hub.accessMore,
                      when: hubWhen())
    }

    func hubOpen(_ screen: HubScreen) {
        if screen == .makeHelper || screen == .makeMod {
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
        guard hubIsOwner(), let connection = hub.connection else {
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
        hub.madeLink = nil
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
        if before?.devices != state.devices || before?.invites != state.invites || before?.mods != state.mods
            || before?.session != state.session
        {
            hubRefreshAccess()
        }
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
            guard hubIsOwner(), let device = message.decode("device", as: HubDevice.self) else {
                return
            }
            makeToast(title: device.role == "helper" ? HubWords.Crew.wantsToHelp(device.name)
                : HubWords.Crew.wantsToJoin(device.name),
                subTitle: HubWords.Access.waiting)
            hubRefreshAccess()
        case "invite.closed", "invite.ticket":
            hubRefreshAccess()
        case "owner.changed":
            // Every owner device hears when an owner device is added or removed.
            guard hubIsOwner(), let device = message.decode("device", as: HubPersonRef.self)?.name else {
                return
            }
            let person = message.decode("person", as: HubPersonRef.self)?.name ?? ""
            let by = message.decode("by", as: HubParty.self)?.name ?? database.hub.name
            if message.string("change") == "removed" {
                makeToast(title: String(localized: "\(by) removed \(device)"))
            } else if person.isEmpty {
                makeToast(title: String(localized: "\(device) is now an owner device"))
            } else {
                makeToast(title: String(localized: "\(device) is now an owner device for \(person)"))
            }
            hubRefreshAccess()
        default:
            break
        }
    }

    // MARK: - One request for one row

    // A refusal, or a request that didn't reach the hub, is shown on that
    // row. The list itself only changes when the hub reports it.
    private func hubAccessRequest(_ grant: String, _ type: String, _ params: [String: Any]) {
        hub.accessConfirming = nil
        hub.accessFailed = nil
        hub.accessFailedLine = HubWords.Access.failed
        guard let connection = hub.connection else {
            hub.accessFailed = grant
            return
        }
        hub.accessBusy.insert(grant)
        Task { @MainActor in
            do {
                _ = try await connection.request(type, params)
            } catch let error as HubRequestError {
                switch error.code {
                case "confirm_needed":
                    // A new co-owner's device: the hub wants the owner's
                    // explicit yes. Ask for it; never send it unasked.
                    hub.accessConfirming = HubAccessConfirm(grant: grant, action: .coOwner)
                case "second_owner_needed":
                    hub.accessFailedLine = HubWords.Access.secondOwner
                    hub.accessFailed = grant
                default:
                    hub.accessFailedLine = error.message.isEmpty ? HubWords.Access.failed
                        : String(localized: "The hub didn't do that: \(error.message).")
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

    // The person a waiting device would make a co-owner, when the list says so.
    func hubCoOwnerConfirmFor(device: HubDevice) -> HubAccessRow.End {
        let grant = hub.access?.grants.first { $0.id == device.id }
        return hubCoOwnerConfirm(person: grant?.person?.name, device: device.name)
    }

    func hubNeedsCoOwnerConfirm(device: String) -> Bool {
        hub.access?.grants.first { $0.id == device }?.newOwner == true
    }

    func hubHandStream(_ device: String) {
        hubAccessRequest(device, "stream.hand", ["device": device])
    }

    func hubTakeBackStream(_ device: String) {
        hubAccessRequest(device, "stream.take_back", [:])
    }

    func hubClearTrail() {
        hub.accessOlder = []
        hub.accessMore = nil
        hubAccessRequest(hubTrailGrant, "access.trail.clear", [:])
    }

    // Removes a device, ends a mod link or closes an invite.
    func hubEndAccess(_ grant: String) {
        hubAccessRequest(grant, "access.end", ["grant": grant])
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
            switch error.code {
            case "unavailable":
                return HubWords.Crew.noModLinks
            case "not_allowed":
                return String(localized: "Only an owner device can make links.")
            default:
                return error.message.isEmpty ? HubWords.Access.failed : error.message
            }
        } catch {
            return HubWords.Access.failed
        }
    }

    // A helper's link: works once, stays open for linkLasts, and the helper
    // still waits for Allow. Returns what went wrong, or nil.
    func hubMakeHelperLink(name: String, linkLasts: HubLinkDuration, ends: HubHelperAccessEnds) async -> String? {
        let label = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var params: [String: Any] = ["role": "helper", "via": "link", "expires_ms": linkLasts.milliseconds]
        if !label.isEmpty {
            params["for"] = String(label.prefix(64))
        }
        switch ends {
        case .stream:
            params["until_stream"] = true
        case let .after(duration):
            params["access_ms"] = duration.milliseconds
        case .never:
            break
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
}
