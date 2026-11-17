import SwiftUI

// The join sheet, shown when a rig's code is scanned or its link opened.
// It never asks for anything: it says what is happening, then what the rig
// set on this phone, and closes with one button.

private struct HubJoinProgressView: View {
    let title: String
    let line: String

    var body: some View {
        VStack(alignment: .leading, spacing: HubLook.stack) {
            Text(title)
                .font(.title2.weight(.bold))
                .foregroundStyle(HubLook.text)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            HStack(alignment: .center, spacing: 10) {
                ProgressView()
                    .tint(HubLook.textMuted)
                Text(line)
                    .font(.body)
                    .foregroundStyle(HubLook.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
        }
    }
}

private struct HubJoinedView: View {
    let model: Model
    let name: String
    let filled: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Joined your streaming setup")
                .font(.title2.weight(.bold))
                .foregroundStyle(HubLook.text)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(name)
                .font(.body)
                .foregroundStyle(HubLook.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        if !filled.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HubSectionLabel(text: HubWords.Setup.setBy)
                HubCard {
                    ForEach(filled, id: \.self) { item in
                        Label {
                            Text(item)
                                .fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: "checkmark")
                        }
                        .foregroundStyle(HubLook.text)
                    }
                }
            }
        }
        HubCard {
            HubStatusView(status: HubStatus(
                kind: .ready,
                title: String(localized: "Ready to connect"),
                line: String(localized: "Viewers see nothing from this phone until you move the stream here.")
            ))
        }
        Text("Nothing to type and no settings to open.")
            .font(.footnote)
            .foregroundStyle(HubLook.textMuted)
            .fixedSize(horizontal: false, vertical: true)
        Button {
            model.closeHubJoin()
        } label: {
            Text("Done")
        }
        .buttonStyle(HubDecisionButtonStyle())
    }
}

private struct HubJoinFailedView: View {
    let model: Model
    let failure: HubJoinFailure

    var body: some View {
        HubCard {
            HubStatusView(status: HubStatus(kind: failure == .wrongHub ? .problem : .caution,
                                            title: failure.title,
                                            line: failure.line))
        }
        Button {
            model.closeHubJoin()
        } label: {
            Text("Close")
        }
        .buttonStyle(HubOutlineButtonStyle())
    }
}

struct HubJoinView: View {
    let model: Model
    @ObservedObject var hub: HubProvider
    @ScaledMetric(relativeTo: .title) private var markSize: CGFloat = 56

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HubMarkView(size: markSize)
                    switch hub.joinState {
                    case .none:
                        EmptyView()
                    case let .joining(name):
                        HubJoinProgressView(title: String(localized: "Joining \(name)"),
                                            line: String(localized: "Checking that it's your hub. Nothing to type."))
                    case let .pending(name):
                        HubJoinProgressView(title: String(localized: "Waiting for Allow"),
                                            line: String(localized: "Someone on \(name) has to allow this phone."))
                        Text(HubWords.Setup.pendingHint)
                            .font(.footnote)
                            .foregroundStyle(HubLook.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                        Button {
                            model.closeHubJoin()
                        } label: {
                            Text("Close")
                        }
                        .buttonStyle(HubOutlineButtonStyle())
                    case let .joined(name, filled):
                        HubJoinedView(model: model, name: name, filled: filled)
                    case let .failed(failure):
                        HubJoinFailedView(model: model, failure: failure)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
                .frame(maxWidth: 560, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(HubLook.background)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if hub.isJoining {
                        Button("Cancel") {
                            model.closeHubJoin()
                        }
                    }
                }
            }
        }
    }
}
