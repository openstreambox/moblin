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

extension Model {
    func hubShowcaseStream() -> SettingsStream {
        let stream = SettingsStream(name: "Rig: \(showcaseHub)")
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
        for action in ["join", "done", "panel", "connect", "disconnect", "move", "hide", "show"] {
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
            break
        }
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
    }
}

#endif
