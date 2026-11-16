import SwiftUI

enum DashboardJoinState: Equatable {
    case none
    case connecting
    // buttonUntil: until then, a double-press on the box's power button
    // also finishes connecting.
    case waiting(code: String, buttonUntil: Date?)
    case joined
    case failed(message: String)
}

@MainActor
class DashboardProvider: ObservableObject {
    @Published var joinState: DashboardJoinState = .none
    @Published var joinName = ""
    @Published var connected = false
    var client: DashboardClient?
    var joinLink: DashboardJoinLink?
    var joinNonce = ""
    var debugJoinOpened = false
}

extension Model {
    func isDashboardJoined() -> Bool {
        !database.backpack.dashboardToken.isEmpty
    }

    func handleDashboardUrl(url: URL) {
        guard let link = DashboardJoinLink(url: url) else {
            makeErrorToast(title: String(localized: "This code isn't from an OpenStreamBox dashboard"))
            return
        }
        stopDashboard()
        dashboard.joinLink = link
        dashboard.joinName = link.name
        dashboard.joinNonce = dashboardNonce()
        dashboard.joinState = .connecting
        presentingDashboardJoin = true
        dashboard.client = DashboardClient(url: link.url, delegate: self)
        dashboard.client?.start()
    }

    func closeDashboardJoin() {
        presentingDashboardJoin = false
        guard dashboard.joinLink != nil else {
            return
        }
        dashboard.joinLink = nil
        dashboard.joinState = .none
        reloadDashboard()
    }

    func reloadDashboard() {
        stopDashboard()
        let settings = database.backpack
        guard !settings.dashboardToken.isEmpty, let url = URL(string: settings.dashboardUrl) else {
            return
        }
        dashboard.client = DashboardClient(url: url, delegate: self)
        dashboard.client?.start()
    }

    func stopDashboard() {
        dashboard.client?.stop()
        dashboard.client = nil
        dashboard.connected = false
    }

    func leaveDashboard() {
        dashboard.client?.send(message: ["type": "leave"])
        let name = database.backpack.dashboardName
        forgetDashboard()
        makeToast(title: String(localized: "Disconnected from \(name)"))
    }

    private func forgetDashboard() {
        stopDashboard()
        database.backpack.dashboardToken = ""
        database.backpack.dashboardDeviceId = ""
        database.backpack.dashboardName = ""
        database.backpack.dashboardUrl = ""
        storeSettings()
    }

    func reportDashboardState() {
        guard dashboard.connected, dashboard.joinLink == nil else {
            return
        }
        dashboard.client?.send(message: ["type": "state", "role": database.appMode.rawValue])
    }

    private func applyDashboardProfile(profile: DashboardProfile, role: String?, announce: Bool) {
        var changes: [String] = []
        if let kbps = profile.stream?.bitrateKbps {
            let bitrate = UInt32(max(kbps, 300)) * 1000
            if stream.bitrate != bitrate {
                stream.bitrate = bitrate
                setStreamBitrate(stream: stream)
                changes.append(String(localized: "Bitrate \(backpackMbps(kbps: kbps)) Mbps"))
            }
        }
        var buttonsChanged = false
        if let buttons = profile.buttons?.streaming {
            for button in database.quickButtons {
                if let enabled = buttons[button.type.rawValue], button.enabled != enabled {
                    button.enabled = enabled
                    buttonsChanged = true
                }
            }
        }
        if let buttons = profile.buttons?.companion {
            let types = SettingsQuickButtonType.allCases.filter { buttons[$0.rawValue] == true }
            if Set(types) != Set(database.backpack.companionButtons) {
                database.backpack.companionButtons = types
                buttonsChanged = true
            }
        }
        if buttonsChanged {
            updateQuickButtonPairs()
            changes.append(String(localized: "quick buttons"))
        }
        if let readAloud = profile.readAloud, database.backpack.readAloud != readAloud {
            database.backpack.readAloud = readAloud
            changes.append(readAloud ? String(localized: "read aloud on") : String(localized: "read aloud off"))
        }
        if let role, let mode = SettingsAppMode(rawValue: role), mode != .chatPhone, mode != database.appMode {
            if isLive || isRecording {
                changes.append(String(localized: "\(mode.toString()) after you stop"))
            } else {
                setBackpackAppMode(mode: mode)
                changes.append(mode.toString())
            }
        }
        storeSettings()
        if announce, !changes.isEmpty {
            makeToast(title: String(localized: "Updated by \(database.backpack.dashboardName)"),
                      subTitle: changes.joined(separator: " · "))
        }
    }
}

extension Model: DashboardClientDelegate {
    func dashboardClientConnected() {
        dashboard.connected = true
        let role = database.appMode == .companion ? "companion" : "streaming"
        if let link = dashboard.joinLink {
            dashboard.client?.send(message: [
                "type": "join",
                "invite": link.invite,
                "nonce": dashboard.joinNonce,
                "name": UIDevice.current.name,
                "model": UIDevice.current.model,
                "role": role,
                "app": "Moblin \(appVersion())",
            ])
        } else {
            dashboard.client?.send(message: [
                "type": "hello",
                "device": database.backpack.dashboardDeviceId,
                "token": database.backpack.dashboardToken,
                "role": role,
                "app": "Moblin \(appVersion())",
            ])
        }
    }

    func dashboardClientDisconnected() {
        dashboard.connected = false
        if dashboard.joinLink != nil {
            dashboard.joinState = .connecting
        }
    }

    func dashboardClientMessage(message: DashboardMessage) {
        switch message.type {
        case "join_pending":
            guard let link = dashboard.joinLink, let nonce = message.nonce else {
                return
            }
            guard link.fingerprint.isEmpty || message.fingerprint == link.fingerprint else {
                dashboard.joinState = .failed(message: String(localized: "This isn't the dashboard the code came from. Nothing was connected."))
                dashboard.joinLink = nil
                stopDashboard()
                return
            }
            dashboard.joinState = .waiting(
                code: dashboardMatchingCode(invite: link.invite,
                                            deviceNonce: dashboard.joinNonce,
                                            dashboardNonce: nonce),
                buttonUntil: message.buttonSeconds.map { Date().addingTimeInterval(Double($0)) }
            )
        case "joined":
            guard let link = dashboard.joinLink, let token = message.token, let device = message.device else {
                return
            }
            database.backpack.dashboardUrl = link.url.absoluteString
            database.backpack.dashboardName = message.dashboard ?? link.name
            database.backpack.dashboardToken = token
            database.backpack.dashboardDeviceId = device
            dashboard.joinLink = nil
            dashboard.joinState = .joined
            hapticNotification(.success)
            if let profile = message.profile {
                applyDashboardProfile(profile: profile, role: message.role, announce: false)
            }
            storeSettings()
        case "join_rejected":
            dashboard.joinState = .failed(message: message.reason ?? String(localized: "The dashboard didn't connect this phone."))
            dashboard.joinLink = nil
            stopDashboard()
        case "profile":
            if let profile = message.profile {
                applyDashboardProfile(profile: profile, role: message.role, announce: true)
            }
        case "revoked", "hello_rejected":
            let name = database.backpack.dashboardName
            forgetDashboard()
            makeWarningToast(title: String(localized: "This phone was disconnected from \(name)"))
        default:
            break
        }
    }
}
