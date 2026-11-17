import SwiftUI

// The rig's hub (osb-hub/1): a passwordless join with a one-time ticket,
// then this phone fills in its own stream (and remote control, when the
// hub offers one) and keeps one encrypted control connection open for the
// status line, HIDE, Connect and Move stream to phone.

enum HubJoinState: Equatable {
    case none
    case joining(hub: String)
    case pending(hub: String)
    case joined(hub: String, filled: [String])
    case failed(HubJoinFailure)
}

// Why a join didn't work, each with one true line and what to do next.
enum HubJoinFailure: Equatable {
    case expired
    case unreachable
    case timeout
    case wrongHub
    case noKey

    var title: String {
        switch self {
        case .expired:
            String(localized: "This code has expired")
        case .unreachable:
            String(localized: "Can't reach the hub")
        case .timeout:
            String(localized: "The hub didn't answer in time")
        case .wrongHub:
            String(localized: "This isn't the hub the code came from")
        case .noKey:
            String(localized: "Couldn't keep this phone's key")
        }
    }

    var line: String {
        switch self {
        case .expired:
            String(localized: "A code works once, for a short time. Scan the one that's on screen now.")
        case .unreachable, .timeout:
            String(
                localized: "Nothing was changed on this phone. Check that it's online, then scan a fresh code."
            )
        case .wrongHub:
            String(localized: "Nothing was sent from this phone. Scan the code on your own dashboard.")
        case .noKey:
            String(localized: "Nothing was changed. Unlock this phone, then scan a fresh code.")
        }
    }
}

// Why this phone is no longer in a rig, kept on the panel until the next join.
enum HubNotice: Equatable {
    case removed(hub: String)
    case unknownToHub(hub: String)
}

@MainActor
class HubProvider: ObservableObject {
    @Published var connected = false
    @Published var pending = false
    @Published var state: HubState?
    @Published var joinState: HubJoinState = .none
    @Published var requested: Set<HubRequestKind> = []
    @Published var notice: HubNotice?
    var requestTimers: [HubRequestKind: Task<Void, Never>] = [:]
    #if DEBUG
    // Fixture states for screenshots and UI checks; never connects.
    var showcase = false
    var debugActionsStarted = false
    var showcaseSending = false
    var showcaseDraft: String?
    var showcaseSection: String?
    var showcaseFailure: String?
    var showcaseHand = false
    var showcaseOwnName: String?
    #endif
    var provision: HubProvision?
    var connection: HubConnection?
    var reconnectTask: Task<Void, Never>?
    var reconnectDelay: Double = 1
    var debugJoinOpened = false
    // Who has access, for an owner device: the hub's last list and trail,
    // older trail lines fetched with "Show older", the row whose Remove
    // waits for its confirm, and the row whose last request failed.
    @Published var access: HubAccess?
    @Published var accessLoadFailed = false
    @Published var accessOlder: [HubTrailEntry] = []
    @Published var accessMore: Bool?
    @Published var accessConfirming: HubAccessConfirm?
    @Published var accessFailed: String?
    var accessFailedLine = ""
    @Published var accessBusy: Set<String> = []
    @Published var allowAllSaid: [String] = []
    // The link the hub just made. Shown once, then forgotten.
    @Published var madeLink: HubMadeLink?
    // The screens pushed on top of the panel.
    @Published var path: [HubScreen] = []
    @Published var said: String?
    var sessionTold: (allows: [String], limits: [String: String])?
    // The clock a handover's end is checked against.
    var now: () -> Date = { Date() }
    // Wakes the panel when this phone's handover reaches its end.
    var handoverTimer: Task<Void, Never>?
    // The handover already said to have run out, so a late state naming
    // it again says nothing new.
    var handoverRanOut: HubSessionRunBy?
    // The hub's warning that this phone's handover ends soon.
    @Published var ending: HubEnding?
    // On an owner device: the handed stream whose end time is being chosen,
    // and what the last answer to the hub's ask did.
    @Published var choosingEndTime: String?
    @Published var handoverAnswer: HubHandoverAnswer?
    // A notification about the hub's ask is in the list until it is answered.
    var askNoticed = false
    // Handing over while not live: how long it may wait for Go live, kept
    // while the dialog is open.
    @Published var handWait: HubWait = .halfHour
    var accessRefreshTask: Task<Void, Never>?
    var accessRefreshAgain = false
    var seen: HubSeen? = HubSeenStore.load()
    var seenSavedAt: Int64 = 0
    @Published var recheck = false
    @Published var stayedLine: String?
    var stayedTimer: Task<Void, Never>?

    var isJoining: Bool {
        if case .joining = joinState {
            return true
        }
        return false
    }

    func status(me: String) -> HubStatus {
        var status = hubStatus(state: state, me: me, connected: connected, pending: pending, recheck: recheck)
        if connected, !pending {
            status.note = stayedLine
        }
        return status
    }
}

// How long a request may stay unconfirmed before the panel stops saying
// "requested" and says the hub didn't confirm it.
private let hubRequestPatience: Double = 12

extension Model {
    func isHubJoined() -> Bool {
        database.hub.isJoined()
    }

    func hubStatus() -> HubStatus {
        hub.status(me: database.hub.deviceId)
    }

    // Whether this phone is sending to the rig's hub right now.
    func hubIsSending() -> Bool {
        #if DEBUG
        if hub.showcase {
            return hub.showcaseSending
        }
        #endif
        return streaming && isCurrentStreamHub()
    }

    func isHubStream(_ stream: SettingsStream) -> Bool {
        #if DEBUG
        if hub.showcase {
            return isHubJoined()
        }
        #endif
        return database.hub.isJoined() && database.hub.streamId == stream.id
    }

    // The stream the rig set up on this phone, for the "Set by your rig" row.
    func hubRigStream() -> SettingsStream? {
        #if DEBUG
        if hub.showcase {
            return isHubJoined() ? hubShowcaseStream() : nil
        }
        #endif
        return database.hub.streamId.flatMap { findStream(id: $0) }
    }

    func isCurrentStreamHub() -> Bool {
        isHubStream(stream)
    }

    func hubControlList() -> HubControls {
        guard hub.connected, !hub.pending else {
            return .none
        }
        return hubControls(state: hub.state,
                           me: database.hub.deviceId,
                           role: database.hub.role,
                           sending: hubIsSending(),
                           requested: hub.requested,
                           now: hub.now())
    }

    func hubHideNow() -> HubHideControl? {
        guard !hub.pending else {
            return nil
        }
        let privacy = hubControls(state: hub.state,
                                  me: database.hub.deviceId,
                                  role: database.hub.role,
                                  sending: hubIsSending(),
                                  requested: hub.connected ? hub.requested : [],
                                  now: hub.now()).privacy
        return hubHideControl(privacy, reachable: hub.connected)
    }

    // A request is open until the hub's state shows it, or the hub stays
    // quiet too long. Nothing is assumed in between.
    private func hubMarkRequested(_ kind: HubRequestKind) {
        hub.requested.insert(kind)
        hub.requestTimers[kind]?.cancel()
        hub.requestTimers[kind] = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(hubRequestPatience * 1_000_000_000))
            guard !Task.isCancelled, hub.requested.contains(kind) else {
                return
            }
            hubClearRequested(kind)
            makeWarningToast(title: String(localized: "The hub hasn't confirmed that"),
                             subTitle: String(
                                 localized: "Nothing is assumed. The status line shows what the hub reports."
                             ))
        }
    }

    private func hubClearRequested(_ kind: HubRequestKind) {
        hub.requestTimers[kind]?.cancel()
        hub.requestTimers[kind] = nil
        hub.requested.remove(kind)
    }

    private func hubClearAllRequested() {
        for kind in hub.requested {
            hubClearRequested(kind)
        }
    }

    private func hubSetState(_ state: HubState) {
        let before = hub.state
        hub.state = state
        hubCrewStateChanged(from: before, to: state)
        let open = hubOpenRequests(hub.requested, state: state, me: database.hub.deviceId)
        for kind in hub.requested.subtracting(open) {
            hubClearRequested(kind)
        }
    }

    func hubProgramIsThisPhone() -> Bool {
        hub.state?.isLive == true && hub.state?.session.program == database.hub.deviceId
    }

    // MARK: - Joining

    func handleHubUrl(url: URL) {
        let link: HubJoinLink
        do {
            link = try HubJoinLink(url: url)
        } catch {
            makeErrorToast(title: HubWords.Setup.notASetupCode)
            return
        }
        guard !streaming, !isRecording else {
            makeErrorToast(title: HubWords.Setup.cantJoinWhileStreaming,
                           subTitle: String(localized: "Disconnect first, then scan the code again."))
            return
        }
        let name = link.name ?? String(localized: "Hub")
        stopHub()
        hub.notice = nil
        hub.joinState = .joining(hub: name)
        presentingHubJoin = true
        let key = HubKeyPair.generate()
        Task { @MainActor in
            do {
                let connection = try await HubConnection.join(link: link,
                                                              key: key,
                                                              name: UIDevice.current.name,
                                                              kind: "phone",
                                                              validateWelcome: { message, hubKey in
                                                                  _ = try hubValidateEvidence(
                                                                      message,
                                                                      hubKey: hubBase64UrlEncode(hubKey),
                                                                      ownership: nil,
                                                                      epoch: nil,
                                                                      seen: nil
                                                                  )
                                                              })
                guard HubKeychain.saveDeviceKey(key) else {
                    connection.close()
                    hub.joinState = .failed(.noKey)
                    return
                }
                database.hub = SettingsHub()
                hub.seen = nil
                HubSeenStore.delete()
                database.hub.name = name
                database.hub.urls = link.hub.map(\.absoluteString)
                database.hub.hubKey = hubBase64UrlEncode(connection.hubKey)
                logger.info("hub: joined \(name)")
                adoptHubConnection(connection)
                let filled = handleHubWelcome(connection.welcome)
                if hub.pending {
                    hub.joinState = .pending(hub: name)
                } else {
                    hub.joinState = .joined(hub: name, filled: filled)
                }
                hapticNotification(.success)
            } catch let error as HubConnectionError {
                hub.joinState = .failed(hubJoinFailure(error))
            } catch {
                hub.joinState = .failed(.unreachable)
            }
        }
    }

    private func hubJoinFailure(_ error: HubConnectionError) -> HubJoinFailure {
        switch error {
        case .refused:
            .expired
        case .wrongHub:
            .wrongHub
        case .timeout:
            .timeout
        case .closed, .invalid:
            .unreachable
        }
    }

    func closeHubJoin() {
        presentingHubJoin = false
        if case .joining = hub.joinState {
            return
        }
        hub.joinState = .none
    }

    // MARK: - Connection

    func reloadHub() {
        #if DEBUG
        if hub.showcase {
            return
        }
        #endif
        guard isHubJoined(), hub.connection == nil, !hub.isJoining, hub.reconnectTask == nil else {
            return
        }
        connectHub()
    }

    func stopHub() {
        hub.reconnectTask?.cancel()
        hub.reconnectTask = nil
        if let connection = hub.connection {
            connection.onClose = nil
            connection.onMessage = nil
            connection.close()
        }
        hub.connection = nil
        hub.connected = false
        hubClearAllRequested()
    }

    // Try the hub again now instead of waiting for the next attempt.
    func hubReconnectNow() {
        guard isHubJoined(), hub.connection == nil, !hub.isJoining else {
            return
        }
        hub.reconnectTask?.cancel()
        hub.reconnectTask = nil
        hub.reconnectDelay = 1
        connectHub()
    }

    private func connectHub() {
        guard let key = HubKeychain.loadDeviceKey(),
              let hubKey = hubBase64UrlDecode(database.hub.hubKey)
        else {
            logger.info("hub: no device key, forgetting the setup")
            forgetHub()
            return
        }
        let settings = database.hub
        let setup = settings.hubKey + ":" + settings.deviceId
        hub.seen = HubSeen.scoped(hub.seen, setup: setup)
        let urls = hubDialList(proven: settings.provenUrl,
                               join: settings.urls,
                               hub: settings.hubUrls,
                               standby: settings.standbyUrls).compactMap { URL(string: $0) }
        let hello = settings.role == "admin" ? HubSeen.hello(hub.seen, now: hubNowMs()) : ["v": 1]
        let proven = settings.provenUrl
        let join = settings.urls
        Task { @MainActor in
            do {
                let connection = try await HubConnection.connect(
                    urls: urls,
                    key: key,
                    hubKey: hubKey,
                    hello: hello,
                    validateWelcome: { message in
                        _ = try hubValidateEvidence(message, hubKey: settings.hubKey,
                                                    ownership: settings.ownership, epoch: settings.epoch,
                                                    seen: self.hub.seen)
                    },
                    refusalCounts: { hubRefusalCounts($0.absoluteString, proven: proven, join: join) }
                )
                guard isHubJoined(), database.hub.hubKey + ":" + database.hub.deviceId == setup else {
                    connection.close()
                    return
                }
                adoptHubConnection(connection)
                _ = handleHubWelcome(connection.welcome)
            } catch HubConnectionError.refused {
                let name = database.hub.name
                forgetHub()
                hub.notice = .unknownToHub(hub: name)
                makeWarningToast(title: String(localized: "\(name) doesn't know this phone any more"),
                                 subTitle: String(localized: "Scan a new code to join again."))
            } catch {
                scheduleHubReconnect()
            }
        }
    }

    private func adoptHubConnection(_ connection: HubConnection) {
        hub.connection = connection
        hub.connected = true
        hub.reconnectDelay = 1
        connection.onMessage = { [weak self] message in
            self?.handleHubMessage(message)
        }
        connection.onClose = { [weak self] code in
            self?.hubClosed(code: code)
        }
    }

    private func hubClosed(code: Int?) {
        hub.connection = nil
        hub.connected = false
        hubClearAllRequested()
        if code == 4403 {
            return
        }
        scheduleHubReconnect()
    }

    private func scheduleHubReconnect() {
        guard isHubJoined() else {
            return
        }
        hub.reconnectTask?.cancel()
        let delay = hub.reconnectDelay
        hub.reconnectDelay = min(hub.reconnectDelay * 2, 15)
        hub.reconnectTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled, hub.connection == nil else {
                return
            }
            connectHub()
        }
    }

    // MARK: - Messages

    @discardableResult
    private func handleHubWelcome(_ welcome: HubMessage) -> [String] {
        let device = welcome.decode("device", as: HubDevice.self)
        if let device {
            database.hub.deviceId = device.id
            database.hub.role = device.role
        }
        hub.pending = welcome.bool("pending") ?? false
        hub.recheck = hub.pending && device?.recheck == true
        if hubTakeoverStayed(before: database.hub.epoch, welcome: welcome) {
            hubShowStayed(hubTakeoverStayedLine(welcome))
        }
        if let url = hub.connection?.url.absoluteString {
            database.hub.provenUrl = url
        }
        hubLearn(welcome)
        if let state = welcome.decode("state", as: HubState.self) {
            hubSetState(state)
        }
        var filled: [String] = []
        if let provision = welcome.decode("provision", as: HubProvision.self) {
            filled = applyHubProvision(provision)
        }
        storeSettings()
        hubRefreshAccess()
        return filled
    }

    private func handleHubMessage(_ message: HubMessage) {
        if message.type == "welcome" || message.type == "state" {
            do {
                _ = try hubValidateEvidence(message, hubKey: database.hub.hubKey,
                                            ownership: database.hub.ownership, epoch: database.hub.epoch,
                                            seen: hub.seen)
            } catch {
                hub.connection?.close()
                return
            }
        }
        if message.type != "welcome", message.type != "state" {
            hubHeard()
        }
        if message.type == "hub.moving" || message.type == "hub.moved" {
            hubClearStayed()
        }
        switch message.type {
        case "welcome":
            // Sent again once an admin allows a phone that joined by link.
            let filled = handleHubWelcome(message)
            if case let .pending(name) = hub.joinState {
                hub.joinState = .joined(hub: name, filled: filled)
            } else if !hub.pending {
                makeToast(title: String(localized: "\(database.hub.name) allowed this phone"))
            }
        case "state":
            hubLearn(message)
            if let state = message.decode("state", as: HubState.self) {
                hubSetState(state)
            }
        case "feed.start":
            if let provision = message.decode("provision", as: HubProvision.self) {
                _ = applyHubProvision(provision)
            }
            let by = message.string("by").flatMap { hub.state?.device($0)?.name } ?? database.hub.name
            makeToast(title: String(localized: "\(by) asked to connect this phone"))
            startHubFeed()
        case "removed":
            let name = database.hub.name
            stopHub()
            forgetHub()
            hub.notice = .removed(hub: name)
            makeWarningToast(title: String(localized: "This phone was removed from \(name)"),
                             subTitle: HubWords.Setup.settingsGone)
        case "message":
            if let body = message.object["body"] as? [String: Any], let text = body["text"] as? String {
                let from = message.string("from").flatMap { hub.state?.device($0)?.name } ?? database.hub.name
                makeToast(title: from, subTitle: text)
            }
        default:
            hubHandleCrewMessage(message)
        }
    }

    // MARK: - Settings the rig fills in

    // Writes the provisioned stream (SRT, or SRTLA when Moblink bonding is
    // on) into one Moblin stream marked as the rig's, selects it, and sets
    // remote control when the hub offers it. Nothing is shown to copy.
    private func applyHubProvision(_ provision: HubProvision) -> [String] {
        hub.provision = provision
        var filled: [String] = []
        let url = hubStreamUrl(provision)
        let target: SettingsStream
        if let id = database.hub.streamId, let existing = findStream(id: id) {
            target = existing
        } else {
            target = SettingsStream(name: HubWords.Setup.streamName(database.hub.name))
            database.streams.append(target)
            database.hub.streamId = target.id
        }
        if streaming, target.id == stream.id {
            // Never swap the destination under a running stream; it applies
            // at the next Connect.
            return filled
        }
        var changed = false
        // Only libsrt ("Official") sends the passphrase the hub checks;
        // Moblin's own SRT implementation has no encryption.
        if target.srt.implementation != .official {
            target.srt.implementation = .official
            changed = true
        }
        if target.url != url {
            target.url = url
            changed = true
            filled.append(url.hasPrefix("srtla") ? String(localized: "Stream to the hub, bonded")
                : String(localized: "Stream to the hub"))
        }
        if !target.enabled, !isLive, !isRecording {
            setCurrentStream(stream: target)
            reloadStreamIfEnabled(stream: target)
            filled.append(String(localized: "Selected as your stream"))
        } else if changed, target.enabled, !isLive, !isRecording {
            reloadStreamIfEnabled(stream: target)
        }
        if let remoteControl = provision.remoteControl {
            let streamer = database.remoteControl.streamer
            if streamer.url != remoteControl.url || database.remoteControl.password != remoteControl.password
                || !streamer.enabled
            {
                streamer.url = remoteControl.url
                database.remoteControl.password = remoteControl.password
                streamer.enabled = true
                database.hub.remoteControlSet = true
                reloadRemoteControlStreamer()
                filled.append(String(localized: "Remote control"))
            }
        }
        storeSettings()
        return filled
    }

    private func hubStreamUrl(_ provision: HubProvision) -> String {
        if database.moblink.streamer.enabled, let srtla = provision.srtla {
            return srtla.url
        }
        return provision.srt.url
    }

    func leaveHub() {
        stopHub()
        let name = database.hub.name
        forgetHub()
        makeToast(title: String(localized: "This phone left \(name)"))
    }

    // Forget the rig: its key, the stream it set up and any remote control
    // it filled in.
    private func forgetHub() {
        HubKeychain.deleteDeviceKey()
        if let id = database.hub.streamId, let rigStream = findStream(id: id) {
            if rigStream.id == stream.id {
                if streaming {
                    _ = stopStream()
                }
                rigStream.url = defaultStreamUrl
                reloadStream()
            } else {
                database.streams.removeAll { $0.id == id }
            }
        }
        if database.hub.remoteControlSet {
            database.remoteControl.streamer.enabled = false
            database.remoteControl.streamer.url = ""
            reloadRemoteControlStreamer()
        }
        database.hub = SettingsHub()
        hub.seen = nil
        HubSeenStore.delete()
        hub.recheck = false
        hubClearStayed()
        hub.state = nil
        hub.provision = nil
        hub.pending = false
        hub.sessionTold = nil
        hub.said = nil
        hub.handoverTimer?.cancel()
        hub.handoverTimer = nil
        hub.handoverRanOut = nil
        hub.ending = nil
        hubWithdrawAskNotice()
        hubForgetAccess()
        storeSettings()
    }

    // MARK: - Controls

    // Connect: send this phone's picture to the hub and let it check it.
    // Viewers see nothing new.
    func hubConnect() {
        startHubFeed()
    }

    // Disconnect: stop sending to the hub. The hub keeps the platform
    // output; if viewers were seeing this phone they get its standby picture.
    func hubDisconnect() {
        guard hubIsSending() else {
            return
        }
        hubMarkRequested(.disconnect)
        _ = stopStream()
    }

    // A Simulator has no camera to send. With -HubDebugNoSend YES a debug
    // build only asks the hub to check this phone's feed, so a test picture
    // sent to the phone's slot from elsewhere can stand in.
    private func hubDebugNoSend() -> Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: "HubDebugNoSend")
        #else
        false
        #endif
    }

    private func startHubFeed() {
        guard let connection = hub.connection, let rigStreamId = database.hub.streamId else {
            return
        }
        if !streaming, !hubDebugNoSend() {
            if stream.id != rigStreamId, let target = findStream(id: rigStreamId), !isRecording {
                setCurrentStream(stream: target)
                reloadStreamIfEnabled(stream: target)
            }
            guard stream.id == rigStreamId else {
                makeErrorToast(title: String(localized: "Stop recording first"))
                return
            }
            startStream()
        }
        hubMarkRequested(.connect)
        Task { @MainActor in
            defer {
                hubClearRequested(.connect)
            }
            do {
                let reply = try await connection.request("feed.connect", ["wait_ms": 20000])
                if reply.bool("checked") == true {
                    let program = hub.state?.session.program.flatMap { hub.state?.device($0)?.name }
                    if let program, hub.state?.isLive == true, !hubProgramIsThisPhone() {
                        makeToast(title: String(localized: "Picture checked"),
                                  subTitle: String(localized: "Viewers still see \(program)"))
                    } else {
                        makeToast(title: String(localized: "Picture checked"))
                    }
                } else {
                    makeWarningToast(title: String(localized: "The hub hasn't seen a steady picture yet"),
                                     subTitle: String(localized: "Viewers see nothing new."))
                }
            } catch let error as HubRequestError {
                makeErrorToast(title: String(localized: "The hub didn't connect this phone"),
                               subTitle: error.message)
            } catch {
                makeErrorToast(title: String(localized: "Lost the hub while connecting"))
            }
        }
    }

    func hubMoveHere() {
        hubRequest(.move, "stream.move", ["to": database.hub.deviceId]) { model, _ in
            model.makeToast(title: String(localized: "Viewers see this phone now"))
        }
    }

    func hubHide() {
        hubRequest(.hide, "privacy.hide") { model, _ in
            model.makeToast(title: String(localized: "Your privacy screen is on. Viewers don't see you."))
        }
    }

    func hubShowPicture(generation: Int) {
        hubRequest(.show, "privacy.show", ["generation": generation]) { model, _ in
            model.makeToast(title: String(localized: "Viewers see the picture again"))
        }
    }

    private func hubRequest(_ kind: HubRequestKind,
                            _ type: String,
                            _ params: [String: Any] = [:],
                            done: @escaping @MainActor (Model, HubMessage) -> Void)
    {
        guard let connection = hub.connection else {
            makeErrorToast(title: String(localized: "Can't reach the hub right now"),
                           subTitle: String(localized: "Nothing was changed."))
            return
        }
        hubMarkRequested(kind)
        Task { @MainActor in
            do {
                let reply = try await connection.request(type, params)
                // The reply only says the hub took the request; the control
                // reads as confirmed once the hub's state shows it.
                done(self, reply)
            } catch let error as HubRequestError {
                hubClearRequested(kind)
                switch error.code {
                case "stale_show":
                    makeWarningToast(title: String(localized: "Someone hid the picture again since"),
                                     subTitle: String(localized: "The privacy screen stays on."))
                case "slow_down" where kind == .hide:
                    makeToast(title: HubWords.Crew.alreadyHidden,
                              subTitle: String(
                                  localized: "Your privacy screen is on. Viewers don't see you."
                              ))
                case "feed_not_checked":
                    makeWarningToast(title: String(localized: "Connect this phone first"))
                default:
                    makeErrorToast(
                        title: String(localized: "The hub didn't do that"),
                        subTitle: error.message
                    )
                }
            } catch {
                hubClearRequested(kind)
                makeErrorToast(title: String(localized: "Lost the hub; nothing was changed"))
            }
        }
    }

    #if DEBUG
    // For test runs, which can't scan a code: -HubJoinUrl 'osb-hub://join#…'.
    func handleDebugHubJoinUrl() {
        guard !hub.showcase, !hub.debugJoinOpened,
              let text = UserDefaults.standard.string(forKey: "HubJoinUrl"),
              let url = URL(string: text)
        else {
            return
        }
        hub.debugJoinOpened = true
        handleHubUrl(url: url)
    }
    #endif
}
