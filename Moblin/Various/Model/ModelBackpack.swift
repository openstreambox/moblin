import AVFoundation
import NaturalLanguage
import SwiftUI

enum BackpackConnection {
    case off
    case searching
    case connecting
    case connected
}

@MainActor
class BackpackProvider: ObservableObject {
    @Published var connection: BackpackConnection = .off
    @Published var status: BackpackStatus?
    @Published var name = ""
    @Published var suggestedAppMode: SettingsAppMode?
    var client: BackpackClient?
    var scanner: BackpackScanner?
    var announcedAlerts: [String: Int] = [:]
    var announcedName = ""
    let synthesizer = AVSpeechSynthesizer()

    func statusLine() -> String {
        switch connection {
        case .off:
            String(localized: "Backpack off")
        case .searching:
            String(localized: "Looking for a backpack…")
        case .connecting:
            String(localized: "Connecting to \(name)…")
        case .connected:
            status?.verdict.line ?? String(localized: "Backpack connected")
        }
    }

    func statusColor() -> Color {
        guard connection == .connected, let status else {
            return .white
        }
        return backpackLevelColor(level: status.verdict.level)
    }
}

func backpackLevelColor(level: String) -> Color {
    switch level {
    case "great":
        .green
    case "ok":
        .yellow
    case "struggling", "brb":
        .red
    case "private":
        .purple
    case "handover":
        .blue
    default:
        .gray
    }
}

func backpackMbps(kbps: Int) -> String {
    String(format: "%.1f", Double(kbps) / 1000)
}

extension Model {
    func reloadBackpack() {
        stopBackpack()
        let settings = database.backpack
        guard settings.enabled else {
            return
        }
        #if DEBUG
        if let override = UserDefaults.standard.string(forKey: "BackpackUrl"), let url = URL(string: override) {
            connectBackpack(url: url, name: String(localized: "Backpack (test)"))
            return
        }
        #endif
        if !settings.url.isEmpty, let url = URL(string: settings.url) {
            connectBackpack(url: url, name: url.host() ?? String(localized: "Backpack"))
        } else {
            backpack.connection = .searching
            backpack.scanner = BackpackScanner(delegate: self)
            backpack.scanner?.start()
        }
    }

    func stopBackpack() {
        backpack.scanner?.stop()
        backpack.scanner = nil
        backpack.client?.stop()
        backpack.client = nil
        backpack.status = nil
        backpack.connection = .off
    }

    private func connectBackpack(url: URL, name: String) {
        backpack.client?.stop()
        backpack.name = name
        backpack.connection = .connecting
        backpack.client = BackpackClient(url: url, delegate: self)
        backpack.client?.start()
    }

    func setBackpackAppMode(mode: SettingsAppMode) {
        backpack.suggestedAppMode = nil
        guard database.appMode != mode, !isLive, !isRecording else {
            return
        }
        database.appMode = mode
        appModeChanged()
    }

    func backpackWake() {
        sendBackpackCommand(command: "wake")
    }

    func backpackHandover(to: String) {
        sendBackpackCommand(command: "handover", arguments: ["to": to])
    }

    func backpackPrivacy(mode: String) {
        sendBackpackCommand(command: "privacy", arguments: ["mode": mode])
    }

    func backpackReply(message: String, reply: String) {
        backpack.synthesizer.stopSpeaking(at: .word)
        sendBackpackCommand(command: "reply", arguments: ["message": message, "reply": reply])
    }

    func backpackAction(finding: String, action: String) {
        sendBackpackCommand(command: "action", arguments: ["finding": finding, "action": action])
    }

    func backpackLessonRead(lesson: String) {
        sendBackpackCommand(command: "lesson_read", arguments: ["lesson": lesson])
    }

    private func sendBackpackCommand(command: String, arguments: [String: String] = [:]) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        backpack.client?.send(command: command, arguments: arguments)
    }

    private func handleBackpackStatus(status: BackpackStatus) {
        let previous = backpack.status
        backpack.status = status
        for message in status.messages where !message.seen {
            if message.alerts > backpack.announcedAlerts[message.id] ?? 0 {
                backpack.announcedAlerts[message.id] = message.alerts
                announceBackpackMessage(message: message)
            }
        }
        guard let previous else {
            return
        }
        if previous.show.onAir != status.show.onAir {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            if status.show.onAir == "box" {
                makeToast(title: String(localized: "Live on the backpack"),
                          subTitle: String(localized: "Your phone is now an extra link and your remote"))
                backpack.suggestedAppMode = isCompanion() ? nil : .companion
            } else {
                makeToast(title: String(localized: "Live on your phone"))
                backpack.suggestedAppMode = isCompanion() ? .streaming : nil
            }
        }
        if let finding = status.finding, previous.finding?.id != finding.id {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
        if status.lessons.filter({ !$0.read }).count > previous.lessons.filter({ !$0.read }).count {
            makeToast(title: String(localized: "Something to learn after the stream"),
                      subTitle: status.lessons.last?.title)
        }
    }

    private func announceBackpackMessage(message: BackpackStatus.Message) {
        UINotificationFeedbackGenerator().notificationOccurred(message.level == "urgent" ? .error : .warning)
        guard database.backpack.readAloud else {
            return
        }
        let language = NLLanguageRecognizer.dominantLanguage(for: message.text)
        var text = "\(message.from): \(message.text)"
        if language == .english || language == nil {
            text = message.level == "urgent" ? "Urgent from \(text)" : "Message from \(text)"
        }
        let utterance = AVSpeechUtterance(string: text)
        if let language {
            utterance.voice = AVSpeechSynthesisVoice(language: language.rawValue)
        }
        backpack.synthesizer.stopSpeaking(at: .immediate)
        backpack.synthesizer.speak(utterance)
    }
}

extension Model: BackpackClientDelegate {
    func backpackClientConnected() {
        backpack.connection = .connected
        if backpack.announcedName != backpack.name {
            backpack.announcedName = backpack.name
            makeToast(title: String(localized: "Backpack connected"), subTitle: backpack.name)
        }
    }

    func backpackClientDisconnected() {
        backpack.status = nil
        backpack.connection = .connecting
    }

    func backpackClientStatus(status: BackpackStatus) {
        backpack.connection = .connected
        handleBackpackStatus(status: status)
    }
}

extension Model: BackpackScannerDelegate {
    func backpackScannerFound(name: String, url: URL) {
        guard backpack.client == nil else {
            return
        }
        backpack.scanner?.stop()
        backpack.scanner = nil
        connectBackpack(url: url, name: name)
    }
}
