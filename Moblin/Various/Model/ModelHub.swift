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
    case failed(message: String)
}

@MainActor
class HubProvider: ObservableObject {
    @Published var connected = false
    @Published var pending = false
    @Published var state: HubState?
    @Published var joinState: HubJoinState = .none
    @Published var working: String?
    @Published var note: String?
    var provision: HubProvision?
    var connection: HubConnection?
    var reconnectTask: Task<Void, Never>?
    var reconnectDelay: Double = 1
    var debugJoinOpened = false

    var isJoining: Bool {
        if case .joining = joinState {
            return true
        }
        return false
    }

    func line(me: String) -> HubLine {
        hubStatusLine(state: state, me: me, connected: connected, pending: pending)
    }
}

private func hubLevelColor(_ level: HubLineLevel) -> Color {
    switch level {
    case .live:
        .red
    case .good:
        .green
    case .waiting:
        .white
    case .warning:
        .orange
    case .unknown:
        .gray
    }
}

extension Model {
    func isHubJoined() -> Bool {
        database.hub.isJoined()
    }

    func hubLine() -> HubLine {
        hub.line(me: database.hub.deviceId)
    }

    func hubLineColor() -> Color {
        hubLevelColor(hubLine().level)
    }

    // On the panel's light background.
    func hubLineDotColor() -> Color {
        switch hubLine().level {
        case .waiting, .unknown:
            .gray
        default:
            hubLineColor()
        }
    }

    func isHubStream(_ stream: SettingsStream) -> Bool {
        database.hub.isJoined() && database.hub.streamId == stream.id
    }

    func isCurrentStreamHub() -> Bool {
        isHubStream(stream)
    }

    func hubActionList() -> [HubAction] {
        guard hub.connected, !hub.pending else {
            return []
        }
        return hubActions(state: hub.state, me: database.hub.deviceId, role: database.hub.role)
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
            makeErrorToast(title: String(localized: "This code isn't from a rig hub"))
            return
        }
        guard !streaming, !isRecording else {
            makeErrorToast(title: String(localized: "Can't join a rig while streaming or recording"),
                           subTitle: String(localized: "Disconnect first, then scan the code again."))
            return
        }
        let name = link.name ?? String(localized: "Hub")
        stopHub()
        hub.joinState = .joining(hub: name)
        presentingHubJoin = true
        let key = HubKeyPair.generate()
        Task { @MainActor in
            do {
                let connection = try await HubConnection.join(link: link,
                                                              key: key,
                                                              name: UIDevice.current.name,
                                                              kind: "phone")
                guard HubKeychain.saveDeviceKey(key) else {
                    connection.close()
                    hub.joinState = .failed(message: String(localized: "Couldn't keep this phone's key."))
                    return
                }
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
                hub.joinState = .failed(message: hubJoinFailure(error))
            } catch {
                hub.joinState = .failed(message: String(localized: "Couldn't reach the hub."))
            }
        }
    }

    private func hubJoinFailure(_ error: HubConnectionError) -> String {
        switch error {
        case .refused:
            String(localized: "The code has expired or was already used. Scan the code that's on screen now.")
        case .wrongHub:
            String(localized: "This isn't the hub the code came from. Nothing was sent.")
        case .timeout:
            String(localized: "The hub didn't answer in time.")
        case .closed, .invalid:
            String(localized: "Couldn't reach the hub.")
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
    }

    private func connectHub() {
        guard let key = HubKeychain.loadDeviceKey(),
              let hubKey = hubBase64UrlDecode(database.hub.hubKey)
        else {
            logger.info("hub: no device key, forgetting the rig")
            forgetHub()
            return
        }
        let urls = database.hub.urls.compactMap { URL(string: $0) }
        Task { @MainActor in
            do {
                let connection = try await HubConnection.connect(urls: urls, key: key, hubKey: hubKey)
                guard isHubJoined() else {
                    connection.close()
                    return
                }
                adoptHubConnection(connection)
                _ = handleHubWelcome(connection.welcome)
            } catch HubConnectionError.refused {
                let name = database.hub.name
                forgetHub()
                makeWarningToast(title: String(localized: "\(name) doesn't know this phone anymore"),
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
        if let state = welcome.decode("state", as: HubState.self) {
            hub.state = state
        }
        var filled: [String] = []
        if let provision = welcome.decode("provision", as: HubProvision.self) {
            filled = applyHubProvision(provision)
        }
        storeSettings()
        return filled
    }

    private func handleHubMessage(_ message: HubMessage) {
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
            if let state = message.decode("state", as: HubState.self) {
                hub.state = state
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
            makeWarningToast(title: String(localized: "This phone was removed from \(name)"),
                             subTitle: String(localized: "Its stream settings from the rig are gone."))
        case "message":
            if let body = message.object["body"] as? [String: Any], let text = body["text"] as? String {
                let from = message.string("from").flatMap { hub.state?.device($0)?.name } ?? database.hub.name
                makeToast(title: from, subTitle: text)
            }
        default:
            break
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
            target = SettingsStream(name: String(localized: "Rig: \(database.hub.name)"))
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
        hub.state = nil
        hub.provision = nil
        hub.pending = false
        storeSettings()
    }

    // MARK: - Controls

    // Connect: send this phone's picture to the hub and let it check it.
    // Viewers see nothing new.
    func hubConnect() {
        startHubFeed()
    }

    private func startHubFeed() {
        guard let connection = hub.connection, let rigStreamId = database.hub.streamId else {
            return
        }
        if !streaming {
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
        hub.working = String(localized: "The hub is checking the picture")
        Task { @MainActor in
            defer {
                hub.working = nil
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
        hubRequest("stream.move", ["to": database.hub.deviceId]) { model, _ in
            model.makeToast(title: String(localized: "Viewers see this phone now"))
        }
    }

    func hubHide() {
        hubRequest("privacy.hide") { model, _ in
            model.makeToast(title: String(localized: "Your privacy screen is on. Viewers don't see you."))
        }
    }

    func hubShowPicture(generation: Int) {
        hubRequest("privacy.show", ["generation": generation]) { model, _ in
            model.makeToast(title: String(localized: "Viewers see the picture again"))
        }
    }

    private func hubRequest(_ type: String,
                            _ params: [String: Any] = [:],
                            done: @escaping @MainActor (Model, HubMessage) -> Void)
    {
        guard let connection = hub.connection else {
            makeErrorToast(title: String(localized: "Not connected to the hub right now"))
            return
        }
        Task { @MainActor in
            do {
                let reply = try await connection.request(type, params)
                done(self, reply)
            } catch let error as HubRequestError {
                switch error.code {
                case "stale_show":
                    makeWarningToast(title: String(localized: "Someone hid the picture again since"),
                                     subTitle: String(localized: "The privacy screen stays on."))
                case "feed_not_checked":
                    makeWarningToast(title: String(localized: "Connect this phone first"))
                default:
                    makeErrorToast(title: String(localized: "The hub said no"), subTitle: error.message)
                }
            } catch {
                makeErrorToast(title: String(localized: "Lost the hub; nothing was changed"))
            }
        }
    }

    #if DEBUG
    // For test runs, which can't scan a code: -HubJoinUrl 'osb-hub://join#…'.
    func handleDebugHubJoinUrl() {
        guard !hub.debugJoinOpened,
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
