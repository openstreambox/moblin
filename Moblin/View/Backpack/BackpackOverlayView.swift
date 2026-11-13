import SwiftUI

struct BackpackQuickReply: Identifiable {
    let id: String
    let label: String
}

let backpackQuickReplies: [BackpackQuickReply] = [
    .init(id: "seen", label: "Seen"),
    .init(id: "on_it", label: "On it"),
    .init(id: "later", label: "Later"),
    .init(id: "yes", label: "Yes"),
    .init(id: "no", label: "No"),
    .init(id: "idc", label: "Don't care"),
]

func backpackReplyLabel(reply: String) -> String {
    backpackQuickReplies.first(where: { $0.id == reply })?.label ?? reply
}

struct BackpackStatusRowView: View {
    let model: Model
    @ObservedObject var backpack: BackpackProvider
    let textPlacement: StreamOverlayIconAndTextPlacement

    var body: some View {
        StreamOverlayIconAndTextView(
            icon: "backpack.fill",
            text: backpack.statusLine(),
            textPlacement: textPlacement,
            color: backpack.statusColor()
        )
        .onTapGesture {
            model.toggleShowingPanel(type: .backpack, panel: .backpack)
        }
    }
}

struct BackpackQuickRepliesView: View {
    let model: Model
    let message: BackpackStatus.Message

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(backpackQuickReplies) { reply in
                    Button {
                        model.backpackReply(message: message.id, reply: reply.id)
                    } label: {
                        Text(verbatim: reply.label)
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
}

private struct BackpackBannerView<Content: View>: View {
    let systemImage: String
    let tint: Color
    let title: String
    var detail: String?
    var emphasized = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                Spacer(minLength: 0)
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            if emphasized {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(tint.opacity(0.8), lineWidth: 1.5)
            }
        }
    }
}

private struct BackpackMessageBannerView: View {
    let model: Model
    let message: BackpackStatus.Message

    var body: some View {
        let urgent = message.level == "urgent"
        BackpackBannerView(
            systemImage: urgent ? "exclamationmark.bubble.fill" : "bubble.left.fill",
            tint: urgent ? .red : .orange,
            title: urgent ? "\(message.from) · Urgent" : "\(message.from) · \(message.role)",
            detail: message.alerts > 1 ? String(localized: "Alerted \(message.alerts)×") : nil,
            emphasized: urgent
        ) {
            Text(message.text)
            BackpackQuickRepliesView(model: model, message: message)
                .controlSize(.small)
        }
    }
}

private struct BackpackModeSuggestionView: View {
    let model: Model
    let backpack: BackpackProvider
    let mode: SettingsAppMode

    var body: some View {
        let companion = mode == .companion
        BackpackBannerView(
            systemImage: companion ? "backpack" : "camera",
            tint: .primary,
            title: companion
                ? String(localized: "The backpack carries the show")
                : String(localized: "The stream is back on your phone")
        ) {
            Text(companion
                ? "Use this phone as its companion? Camera and mic switch off."
                : "Switch to stream phone to turn the camera and mic back on.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack {
                Button {
                    model.setBackpackAppMode(mode: mode)
                } label: {
                    Text(companion ? "Use as companion" : "Use as stream phone")
                        .foregroundStyle(.black)
                }
                .buttonStyle(.borderedProminent)
                Button("Not now") {
                    backpack.suggestedAppMode = nil
                }
                .buttonStyle(.bordered)
            }
            .controlSize(.small)
        }
    }
}

private struct BackpackPrivacyBannerView: View {
    let model: Model
    let status: BackpackStatus

    var body: some View {
        BackpackBannerView(systemImage: "eye.slash.fill", tint: .purple, title: String(localized: "Private")) {
            HStack {
                Text(status.verdict.line)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                if status.privacy.returningIn != nil {
                    Button("Stay private") {
                        model.backpackPrivacy(mode: status.privacy.mode)
                    }
                } else {
                    Button("Go back live") {
                        model.backpackPrivacy(mode: "off")
                    }
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
}

private struct BackpackHandoverBannerView: View {
    let status: BackpackStatus

    var body: some View {
        BackpackBannerView(
            systemImage: status.handover.to == "box" ? "backpack.fill" : "iphone",
            tint: .primary,
            title: status.verdict.line
        ) {
            ProgressView(value: status.handover.progress)
            Text("Viewers stay on the current stream until the new one is ready.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct BackpackFindingBannerView: View {
    let model: Model
    let status: BackpackStatus
    let finding: BackpackStatus.Finding

    var body: some View {
        BackpackBannerView(systemImage: "exclamationmark.triangle.fill", tint: .yellow, title: status.verdict.line) {
            HStack {
                if let action = finding.actions.first {
                    Button(action.label) {
                        model.backpackAction(finding: finding.id, action: action.id)
                    }
                    .buttonStyle(.bordered)
                }
                Button("Details") {
                    model.toggleShowingPanel(type: .backpack, panel: .backpack)
                }
                .buttonStyle(.borderless)
            }
            .controlSize(.small)
        }
    }
}

struct BackpackOverlayView: View {
    let model: Model
    @ObservedObject var backpack: BackpackProvider
    @ObservedObject var show: Show

    var body: some View {
        if let status = backpack.status {
            VStack {
                banner(status: status)
                Spacer()
            }
            .environment(\.colorScheme, .dark)
            .tint(.primary)
            .frame(maxWidth: 420)
            .padding(.top, show.companion ? 8 : 36)
            .padding(.horizontal, 12)
        }
    }

    @ViewBuilder
    private func banner(status: BackpackStatus) -> some View {
        if let message = status.messages.last(where: { !$0.seen }) {
            BackpackMessageBannerView(model: model, message: message)
        } else if let mode = backpack.suggestedAppMode {
            BackpackModeSuggestionView(model: model, backpack: backpack, mode: mode)
        } else if !show.companion {
            if status.privacy.isPrivate() {
                BackpackPrivacyBannerView(model: model, status: status)
            } else if status.handover.isRunning() {
                BackpackHandoverBannerView(status: status)
            } else if let finding = status.finding, model.showingPanel != .backpack {
                BackpackFindingBannerView(model: model, status: status, finding: finding)
            }
        }
    }
}

struct CompanionAreaView: View {
    let model: Model
    @ObservedObject var show: Show

    var body: some View {
        if show.companion {
            BackpackCompanionView(model: model, backpack: model.backpack)
        }
    }
}
