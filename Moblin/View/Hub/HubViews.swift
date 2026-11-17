import SwiftUI

// The rig on the phone: one status line in the stream overlay, a panel with
// HIDE, Connect and Move stream to phone, and the join sheet. Wording rule:
// "live" only for the hub's platform output, and nothing reads as if the
// stream had stopped while the platform still shows it.

struct HubStatusRowView: View {
    let model: Model
    @ObservedObject var hub: HubProvider
    let textPlacement: StreamOverlayIconAndTextPlacement

    var body: some View {
        let line = model.hubLine()
        StreamOverlayIconAndTextView(
            icon: "point.3.filled.connected.trianglepath.dotted",
            text: line.text,
            // The one line that always reads in words, even with compact statuses.
            textPlacement: textPlacement == .beforeIcon ? .beforeIcon : .afterIcon,
            color: model.hubLineColor()
        )
        .onTapGesture {
            model.toggleShowingPanel(type: .rig, panel: .rig)
        }
    }
}

private struct HubActionButton: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let image: String
    let role: ButtonRole?
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            HStack(spacing: 12) {
                Image(systemName: image)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct HubFeedDetailsView: View {
    let feed: HubFeed?

    private func picture() -> String {
        guard let picture = feed?.picture else {
            return String(localized: "can't say")
        }
        return "\(picture.width)×\(picture.height) · \(Int(picture.fps.rounded())) fps"
    }

    private func sound() -> String {
        switch feed?.sound {
        case "yes":
            String(localized: "yes")
        case "silent":
            String(localized: "silent")
        case "none":
            String(localized: "none")
        default:
            String(localized: "can't say")
        }
    }

    var body: some View {
        DisclosureGroup("What the hub measures") {
            LabeledContent("Picture", value: picture())
            LabeledContent("Sound", value: sound())
            LabeledContent("Links at the hub", value: feed?.srtlaLinks.map { "\($0)" } ?? String(localized: "can't say"))
        }
    }
}

struct HubPanelView: View {
    let model: Model
    @ObservedObject var hub: HubProvider
    @ObservedObject var settings: SettingsHub
    @State private var presentingLeave = false

    var body: some View {
        Form {
            if settings.isJoined() {
                let line = model.hubLine()
                Section {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Circle()
                            .fill(model.hubLineDotColor())
                            .frame(width: 10, height: 10)
                        Text(line.text)
                            .font(.headline)
                    }
                    if let working = hub.working {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text(working)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text(settings.name)
                }
                Section {
                    ForEach(Array(model.hubActionList().enumerated()), id: \.offset) { _, action in
                        switch action {
                        case .hide:
                            HubActionButton(title: "HIDE",
                                            subtitle: "Privacy screen on at once. Viewers don't see or hear you.",
                                            image: "eye.slash.fill",
                                            role: .destructive)
                            {
                                model.hubHide()
                            }
                        case let .showPicture(generation):
                            HubActionButton(title: "Show the picture",
                                            subtitle: "Viewers see and hear you again.",
                                            image: "eye",
                                            role: nil)
                            {
                                model.hubShowPicture(generation: generation)
                            }
                        case .connect:
                            HubActionButton(title: "Connect",
                                            subtitle: "The hub checks this phone's picture. Viewers see nothing new.",
                                            image: "link",
                                            role: nil)
                            {
                                model.hubConnect()
                            }
                        case .moveHere:
                            HubActionButton(title: "Move stream to phone",
                                            subtitle: "Viewers see this phone from the next frame.",
                                            image: "arrow.right.circle.fill",
                                            role: nil)
                            {
                                model.hubMoveHere()
                            }
                        }
                    }
                    if !hub.connected {
                        Text("Reconnecting to the hub…")
                            .foregroundStyle(.secondary)
                    }
                }
                if let me = hub.state?.feed(settings.deviceId) {
                    Section {
                        HubFeedDetailsView(feed: me)
                    }
                }
                Section {
                    if let streamId = settings.streamId, let stream = model.findStream(id: streamId) {
                        LabeledContent("Stream", value: stream.name)
                        Text(stream.url.hasPrefix("srtla") ? "Sends to the hub, bonded over SRTLA. Set by your rig."
                            : "Sends to the hub over SRT. Set by your rig.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if settings.remoteControlSet {
                        Text("Remote control: set by your rig.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Set by your rig")
                }
                Section {
                    Button("Leave this rig", role: .destructive) {
                        presentingLeave = true
                    }
                    .confirmationDialog("Leave \(settings.name)?", isPresented: $presentingLeave,
                                        titleVisibility: .visible)
                    {
                        Button("Leave", role: .destructive) {
                            model.leaveHub()
                        }
                    } message: {
                        Text("The stream settings from the rig are removed from this phone.")
                    }
                }
            } else {
                Section {
                    Text("Scan the rig's code with the Camera app, or open the link someone sent you.")
                    Text("Nothing to type: the code carries a one-time ticket, and the rig fills in this phone's stream settings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Join a rig")
                }
            }
        }
        .navigationTitle("Rig")
    }
}

struct HubJoinView: View {
    let model: Model
    @ObservedObject var hub: HubProvider

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                    .font(.system(size: 48))
                    .foregroundStyle(.tint)
                switch hub.joinState {
                case .none:
                    EmptyView()
                case let .joining(name):
                    Text(name)
                        .font(.title2.bold())
                    ProgressView()
                    Text("Joining the rig…")
                        .foregroundStyle(.secondary)
                case let .pending(name):
                    Text(name)
                        .font(.title2.bold())
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Waiting for an admin to tap Allow")
                    }
                    .foregroundStyle(.secondary)
                    Text("The link was sent rather than scanned, so someone in the rig confirms it's you.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                case let .joined(name, filled):
                    Text(name)
                        .font(.title2.bold())
                    Label("Joined", systemImage: "checkmark.circle.fill")
                        .font(.title3.bold())
                        .foregroundStyle(.green)
                    if filled.isEmpty {
                        Text("Nothing to set up on this phone.")
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Set by your rig:")
                                .font(.headline)
                            ForEach(filled, id: \.self) { item in
                                Label(item, systemImage: "checkmark")
                            }
                        }
                    }
                    Text("Ready to connect. Viewers see nothing from this phone until you move the stream here.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    Button {
                        model.closeHubJoin()
                    } label: {
                        Text("Done")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                case let .failed(message):
                    Label(message, systemImage: "xmark.octagon.fill")
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                    Button("Close") {
                        model.closeHubJoin()
                    }
                }
                Spacer()
            }
            .padding(24)
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
