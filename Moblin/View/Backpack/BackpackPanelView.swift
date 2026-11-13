import SwiftUI

private struct BackpackPrivacyMode: Identifiable {
    let id: String
    let label: String
    let image: String
}

private let backpackPrivacyModes: [BackpackPrivacyMode] = [
    .init(id: "hide", label: "Hide", image: "eye.slash"),
    .init(id: "blur", label: "Blur", image: "drop.halffull"),
    .init(id: "mute", label: "Mute", image: "mic.slash"),
    .init(id: "blur_mute", label: "Both", image: "eye.trianglebadge.exclamationmark"),
]

private func backpackLinkImage(kind: String) -> String {
    switch kind {
    case "cellular":
        "antenna.radiowaves.left.and.right"
    case "wifi":
        "wifi"
    case "phone":
        "iphone"
    default:
        "cable.connector"
    }
}

private func backpackLinkColor(state: String) -> Color {
    switch state {
    case "up":
        .green
    case "weak":
        .orange
    case "down":
        .red
    default:
        .gray
    }
}

private func backpackHeatColor(heat: String) -> Color {
    switch heat {
    case "hot":
        .red
    case "warm":
        .orange
    default:
        .primary
    }
}

private struct BackpackVerdictView: View {
    let backpack: BackpackProvider
    let status: BackpackStatus

    var body: some View {
        Section {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Circle()
                    .fill(backpackLevelColor(level: status.verdict.level))
                    .frame(width: 10, height: 10)
                Text(status.verdict.line)
                    .font(.headline)
            }
            HStack {
                Image(systemName: "backpack.fill")
                Text(backpack.name)
                Spacer()
                if status.simulated {
                    Text("Simulated")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.3))
                        .cornerRadius(5)
                }
            }
            .foregroundStyle(.secondary)
        }
    }
}

private struct BackpackFindingRowView: View {
    let title: LocalizedStringKey
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
        }
    }
}

private struct BackpackFindingView: View {
    let model: Model
    let finding: BackpackStatus.Finding

    var body: some View {
        Section {
            Text(finding.headline)
                .font(.headline)
            if !finding.known {
                BackpackFindingRowView(title: "What viewers notice", value: finding.viewers)
            }
            BackpackFindingRowView(title: "Done for you", value: finding.done)
            ForEach(finding.actions) { action in
                Button {
                    model.backpackAction(finding: finding.id, action: action.id)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(action.label)
                        Text(action.cost)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            DisclosureGroup("Details") {
                BackpackFindingRowView(title: "Where", value: finding.place)
                BackpackFindingRowView(title: "How sure", value: finding.sure)
                BackpackFindingRowView(title: "Checked and fine", value: finding.fine)
            }
        } header: {
            Text(finding.known ? "Seen this before" : "What's wrong")
        }
    }
}

private struct BackpackOnAirView: View {
    let model: Model
    let status: BackpackStatus

    var body: some View {
        Section {
            if status.handover.isRunning() {
                VStack(alignment: .leading, spacing: 6) {
                    Text(status.verdict.line)
                    ProgressView(value: status.handover.progress)
                }
            } else if status.show.onAir == "box" {
                LabeledContent("On air", value: String(localized: "Backpack"))
                LabeledContent("Picture", value: status.show.video)
                LabeledContent(
                    "Bitrate",
                    value: "\(backpackMbps(kbps: status.show.actualKbps)) / " +
                        "\(backpackMbps(kbps: status.show.targetKbps)) Mbps"
                )
                if status.box.state != "lost" {
                    Button {
                        model.backpackHandover(to: "phone")
                    } label: {
                        Label("Move the stream back to my phone", systemImage: "iphone")
                    }
                }
            } else {
                LabeledContent("On air", value: String(localized: "Your phone"))
                switch status.box.state {
                case "asleep":
                    Button {
                        model.backpackWake()
                    } label: {
                        Label("Wake the backpack", systemImage: "power")
                    }
                case "waking":
                    HStack {
                        ProgressView()
                        Text("The backpack is waking up…")
                    }
                case "ready":
                    Button {
                        model.backpackHandover(to: "box")
                    } label: {
                        Label("Move the stream to the backpack", systemImage: "backpack.fill")
                            .font(.headline)
                    }
                default:
                    Text("Can't reach the backpack")
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("On air")
        } footer: {
            if status.show.onAir == "box", !status.handover.isRunning() {
                Text("Your phone is now an extra link and your remote. Its camera is free.")
            } else if status.box.state == "ready", !status.handover.isRunning() {
                Text("The backpack lends its links to your phone until you move the stream. " +
                    "Viewers stay on the current stream until the new one is ready.")
            }
        }
    }
}

private struct BackpackPrivacyView: View {
    let model: Model
    let privacy: BackpackStatus.Privacy

    var body: some View {
        Section {
            HStack(spacing: 6) {
                ForEach(backpackPrivacyModes) { mode in
                    Button {
                        model.backpackPrivacy(mode: mode.id)
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: mode.image)
                            Text(verbatim: mode.label)
                                .font(.caption)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(privacy.mode == mode.id ? .purple : .gray)
                }
            }
            if privacy.isPrivate() {
                if let seconds = privacy.returningIn {
                    Button {
                        model.backpackPrivacy(mode: privacy.mode)
                    } label: {
                        Label("Showing you in \(seconds)… Stay private", systemImage: "timer")
                    }
                } else {
                    Button {
                        model.backpackPrivacy(mode: "off")
                    } label: {
                        Label("Show me again", systemImage: "eye")
                    }
                }
            }
        } header: {
            Text("Privacy")
        } footer: {
            Text("Applied on the backpack, so it holds even if your phone disconnects. " +
                "Going back live takes a deliberate tap and a short countdown.")
        }
    }
}

private struct BackpackLinksView: View {
    let status: BackpackStatus

    var body: some View {
        Section {
            ForEach(status.links) { link in
                HStack(spacing: 10) {
                    Image(systemName: backpackLinkImage(kind: link.kind))
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(link.name)
                        Text(link.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        if link.isUp() {
                            Text("\(backpackMbps(kbps: link.upKbps)) Mbps")
                                .monospacedDigit()
                            Text("\(link.rttMs) ms · \(String(format: "%.1f", link.lossPct))% loss")
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        } else {
                            Text(link.state == "down" ? "Lost" : "Off")
                                .foregroundStyle(.secondary)
                        }
                    }
                    Image(systemName: "cellularbars", variableValue: Double(link.bars) / 4)
                        .foregroundStyle(backpackLinkColor(state: link.state))
                }
            }
        } header: {
            Text("Links")
        }
    }
}

private struct BackpackPowerView: View {
    let status: BackpackStatus

    var body: some View {
        Section {
            LabeledContent("Battery") {
                Text("\(status.box.batteryPct)% · \(formatShortDuration(seconds: status.box.minutesLeft * 60)) left")
                    .monospacedDigit()
            }
            LabeledContent("Temperature") {
                Text("\(status.box.celsius) °C")
                    .monospacedDigit()
                    .foregroundStyle(backpackHeatColor(heat: status.box.heat))
            }
        } header: {
            Text("Power and heat")
        }
    }
}

private struct BackpackMessagesView: View {
    let model: Model
    let messages: [BackpackStatus.Message]

    var body: some View {
        Section {
            ForEach(messages.reversed()) { message in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(message.from)
                            .bold()
                        Text(message.role)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if message.level == "urgent" {
                            Text("Urgent")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    Text(message.text)
                    if let reply = message.reply {
                        Text("You replied: \(backpackReplyLabel(reply: reply))")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else if message.seen {
                        Text("Seen")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        BackpackQuickRepliesView(model: model, message: message)
                    }
                }
            }
        } header: {
            Text("Helpers")
        }
    }
}

private struct BackpackLessonsView: View {
    let model: Model
    let lessons: [BackpackStatus.Lesson]

    var body: some View {
        Section {
            ForEach(lessons) { lesson in
                DisclosureGroup {
                    Text(lesson.body)
                    if !lesson.read {
                        Button("Got it") {
                            model.backpackLessonRead(lesson: lesson.id)
                        }
                    }
                } label: {
                    HStack {
                        Text(lesson.title)
                        if !lesson.read {
                            Circle()
                                .fill(.blue)
                                .frame(width: 8, height: 8)
                        }
                    }
                }
            }
        } header: {
            Text("After the stream")
        } footer: {
            Text("Explanations wait until you have time. Once you have read one, the backpack uses it as " +
                "a shorthand next time.")
        }
    }
}

private struct BackpackNotConnectedView: View {
    @ObservedObject var backpack: BackpackProvider

    var body: some View {
        Section {
            switch backpack.connection {
            case .off:
                Text("The backpack is turned off in settings.")
            case .searching:
                HStack {
                    ProgressView()
                    Text("Looking for a backpack on this network…")
                }
            case .connecting, .connected:
                HStack {
                    ProgressView()
                    Text("Connecting to \(backpack.name)…")
                }
            }
        } footer: {
            Text("No backpack at hand? Run the OpenStreamBox demo dashboard on a computer on the same Wi-Fi.")
        }
    }
}

private func backpackLevelName(level: String) -> String {
    switch level {
    case "great":
        String(localized: "Great")
    case "ok":
        String(localized: "OK")
    case "struggling":
        String(localized: "Struggling")
    case "brb":
        String(localized: "BRB")
    case "private":
        String(localized: "Private")
    case "handover":
        String(localized: "Moving")
    case "offline":
        String(localized: "Offline")
    default:
        String(localized: "Backpack")
    }
}

private func backpackLiveTime(seconds: Int) -> String {
    let hours = seconds / 3600
    let minutes = (seconds % 3600) / 60
    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, seconds % 60)
    }
    return String(format: "%d:%02d", minutes, seconds % 60)
}

private struct BackpackSectionsView: View {
    let model: Model
    let status: BackpackStatus

    var body: some View {
        if let finding = status.finding {
            BackpackFindingView(model: model, finding: finding)
        }
        if let message = status.messages.last(where: { !$0.seen }) {
            Section {
                Text("\(message.from): \(message.text)")
                BackpackQuickRepliesView(model: model, message: message)
            } header: {
                Text("Needs a reply")
            }
        }
        BackpackOnAirView(model: model, status: status)
        BackpackPrivacyView(model: model, privacy: status.privacy)
        if !status.links.isEmpty {
            BackpackLinksView(status: status)
        }
        if status.box.state != "asleep", status.box.state != "lost" {
            BackpackPowerView(status: status)
        }
        if !status.lessons.isEmpty {
            BackpackLessonsView(model: model, lessons: status.lessons)
        }
        if !status.messages.isEmpty {
            BackpackMessagesView(model: model, messages: status.messages)
        }
    }
}

private struct BackpackSettingsShortcutView: View {
    let model: Model

    var body: some View {
        ShortcutSectionView {
            NavigationLink {
                BackpackSettingsView(model: model, backpack: model.database.backpack)
            } label: {
                Label("Backpack", systemImage: "gear")
            }
        }
    }
}

struct BackpackPhoneModeView: View {
    let model: Model
    @ObservedObject var database: Database

    private var mode: Binding<SettingsAppMode> {
        Binding(
            get: { database.appMode == .companion ? .companion : .streaming },
            set: { model.setBackpackAppMode(mode: $0) }
        )
    }

    var body: some View {
        Section {
            Picker("This phone", selection: mode) {
                Text("Stream phone")
                    .tag(SettingsAppMode.streaming)
                Text("Companion")
                    .tag(SettingsAppMode.companion)
            }
            .pickerStyle(.segmented)
            .disabled(model.isLive || model.isRecording)
        } footer: {
            if database.appMode == .companion {
                Text("Camera and mic are off. This phone is your remote and shows what the backpack is doing.")
            } else {
                Text("This phone's camera and mic make the stream.")
            }
        }
    }
}

private struct BackpackHeroView: View {
    let status: BackpackStatus

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Circle()
                        .fill(backpackLevelColor(level: status.verdict.level))
                        .frame(width: 12, height: 12)
                    Text(backpackLevelName(level: status.verdict.level))
                        .font(.subheadline.bold())
                        .textCase(.uppercase)
                        .foregroundStyle(backpackLevelColor(level: status.verdict.level))
                    Spacer()
                    if status.simulated {
                        Text("Simulated")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.3))
                            .cornerRadius(5)
                    }
                    Text(backpackLiveTime(seconds: status.show.liveSeconds))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Text(status.verdict.line)
                    .font(.title2.bold())
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 18) {
                    Label("\(status.links.filter { $0.isUp() }.count)", systemImage: "antenna.radiowaves.left.and.right")
                    Label("\(status.box.batteryPct)%", systemImage: "battery.75percent")
                    Label("\(status.box.celsius) °C", systemImage: "thermometer.medium")
                        .foregroundStyle(backpackHeatColor(heat: status.box.heat))
                }
                .lineLimit(1)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 6)
        }
    }
}

struct BackpackPanelView: View {
    let model: Model
    @ObservedObject var backpack: BackpackProvider

    var body: some View {
        Form {
            BackpackPhoneModeView(model: model, database: model.database)
            if let status = backpack.status {
                BackpackVerdictView(backpack: backpack, status: status)
                BackpackSectionsView(model: model, status: status)
            } else {
                BackpackNotConnectedView(backpack: backpack)
            }
            BackpackSettingsShortcutView(model: model)
        }
        .navigationTitle("Backpack")
    }
}

struct BackpackCompanionView: View {
    let model: Model
    @ObservedObject var backpack: BackpackProvider

    var body: some View {
        NavigationStack {
            Form {
                BackpackPhoneModeView(model: model, database: model.database)
                if let status = backpack.status {
                    BackpackHeroView(status: status)
                    BackpackSectionsView(model: model, status: status)
                } else {
                    BackpackNotConnectedView(backpack: backpack)
                }
                BackpackSettingsShortcutView(model: model)
            }
            .navigationTitle(backpack.status == nil ? String(localized: "Companion") : backpack.name)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
