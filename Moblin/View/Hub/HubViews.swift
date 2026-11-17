import SwiftUI

// The rig on the phone: one status line in the stream overlay and a panel
// with the status, Connect and Disconnect, Move stream to phone, HIDE and
// Show the picture. Wording rule: "live" only for the hub's platform
// output, and nothing reads as if the stream had stopped while the platform
// still shows it. A control reads as done only once the hub's state shows
// it; until then it says what was asked for.

struct HubStatusRowView: View {
    let model: Model
    @ObservedObject var hub: HubProvider
    let textPlacement: StreamOverlayIconAndTextPlacement

    var body: some View {
        let status = model.hubStatus()
        StreamOverlayIconAndTextView(
            icon: "point.3.filled.connected.trianglepath.dotted",
            text: status.text,
            // The one line that always reads in words, even with compact statuses.
            textPlacement: textPlacement == .beforeIcon ? .beforeIcon : .afterIcon,
            color: HubLook.colorOnVideo(status.kind)
        )
        .onTapGesture {
            model.toggleShowingPanel(type: .rig, panel: .rig)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Rig: \(status.spoken)"))
        .accessibilityHint(String(localized: "Opens the rig panel"))
        .accessibilityAddTraits([.isButton, .updatesFrequently])
    }
}

private struct HubRigHeaderView: View {
    let name: String
    @ScaledMetric(relativeTo: .title3) private var markSize: CGFloat = 28

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            HubMarkView(size: markSize)
            VStack(alignment: .leading, spacing: 0) {
                HubSectionLabel(text: String(localized: "Your rig"))
                Text(name)
                    .font(.headline)
                    .foregroundStyle(HubLook.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct HubFactsView: View {
    let facts: [HubFact]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HubSectionLabel(text: String(localized: "Reported by the hub"))
            HubCard {
                ForEach(Array(facts.enumerated()), id: \.offset) { index, fact in
                    if index > 0 {
                        Rectangle()
                            .fill(HubLook.border)
                            .frame(height: HubLook.hairline)
                    }
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(fact.label)
                                .foregroundStyle(HubLook.textMuted)
                            Spacer(minLength: 12)
                            Text(fact.value)
                                .font(HubLook.number)
                                .foregroundStyle(HubLook.text)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(fact.label)
                                .foregroundStyle(HubLook.textMuted)
                            Text(fact.value)
                                .font(HubLook.number)
                                .foregroundStyle(HubLook.text)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

private struct HubMoveControlView: View {
    let model: Model
    let control: HubMoveControl

    var body: some View {
        switch control {
        case .offer:
            VStack(alignment: .leading, spacing: 6) {
                Button {
                    model.hubMoveHere()
                } label: {
                    Text("Move stream to phone")
                }
                // A move is offered, not waited for: outlined, as in every
                // app of the shared look. Filled is for Connect and Allow.
                .buttonStyle(HubOutlineButtonStyle())
                .accessibilityHint(String(localized: "Viewers see this phone from the next frame."))
                HubHintView(text: String(localized: "Viewers see this phone from the next frame."))
            }
        case .requested:
            HubCard {
                HubUnconfirmedView(title: String(localized: "Move requested, not confirmed yet"),
                                   line: String(localized: "Viewers see what the status says until the hub confirms."))
            }
        case .onAir:
            // Confirmed: the heading says LIVE on this phone.
            EmptyView()
        }
    }
}

private struct HubFeedControlView: View {
    let model: Model
    let control: HubFeedControl
    // Connect is the screen's decision only when no bigger one is waiting.
    let isDecision: Bool
    let onAir: Bool
    @State private var presentingDisconnect = false

    private func disconnectButton() -> some View {
        Button {
            if onAir {
                presentingDisconnect = true
            } else {
                model.hubDisconnect()
            }
        } label: {
            Text("Disconnect")
        }
        .buttonStyle(HubOutlineButtonStyle())
        .accessibilityHint(String(localized: "This phone stops sending to the hub."))
        .confirmationDialog(
            String(localized: "Viewers see this phone right now. If it disconnects, the hub shows its standby picture and stays live."),
            isPresented: $presentingDisconnect,
            titleVisibility: .visible
        ) {
            Button("Disconnect this phone", role: .destructive) {
                model.hubDisconnect()
            }
        }
    }

    var body: some View {
        switch control {
        case .connect:
            VStack(alignment: .leading, spacing: 6) {
                if isDecision {
                    Button {
                        model.hubConnect()
                    } label: {
                        Text("Connect")
                    }
                    .buttonStyle(HubDecisionButtonStyle())
                    .accessibilityHint(String(localized: "The hub checks this phone's picture. Viewers see nothing new."))
                } else {
                    Button {
                        model.hubConnect()
                    } label: {
                        Text("Connect")
                    }
                    .buttonStyle(HubOutlineButtonStyle())
                    .accessibilityHint(String(localized: "The hub checks this phone's picture. Viewers see nothing new."))
                }
                HubHintView(text: String(localized: "The hub checks this phone's picture. Viewers see nothing new."))
            }
        case .connecting:
            VStack(alignment: .leading, spacing: HubLook.stack) {
                HubCard {
                    HubUnconfirmedView(title: String(localized: "Connecting, not confirmed yet"),
                                       line: String(localized: "The hub is checking this phone's picture. Viewers see nothing new."))
                }
                if model.hubIsSending() {
                    disconnectButton()
                }
            }
        case .connected:
            // Confirmed: the status above says connected, picture checked.
            VStack(alignment: .leading, spacing: 6) {
                disconnectButton()
                HubHintView(text: String(localized: "This phone stops sending to the hub."))
            }
        case .disconnecting:
            HubCard {
                HubUnconfirmedView(title: String(localized: "Disconnect requested, not confirmed yet"),
                                   line: String(localized: "The hub still reports this phone's picture."))
            }
        }
    }
}

// HIDE and the way back. The line under it follows the state: what it
// does, that it was asked for, then that the privacy screen is on.
private struct HubPrivacyControlView: View {
    let model: Model
    let control: HubPrivacyControl
    let live: Bool
    // "Hidden by Sam · Mod", when someone else asked for it.
    let hiddenBy: String?

    private func idleLine() -> String {
        live ? String(localized: "Covers the picture and the sound for viewers. The stream stays live.")
            : String(localized: "Covers the picture and the sound for viewers.")
    }

    var body: some View {
        switch control {
        case .hide:
            VStack(alignment: .leading, spacing: 6) {
                Button {
                    model.hubHide()
                } label: {
                    Text("HIDE")
                        .tracking(1)
                }
                .buttonStyle(HubOutlineButtonStyle(heavy: true))
                .accessibilityLabel(String(localized: "Hide"))
                .accessibilityHint(idleLine())
                HubHintView(text: idleLine())
            }
        case .hideRequested:
            HubCard(muted: true, heavy: true) {
                HubUnconfirmedView(title: String(localized: "Hide requested, not confirmed yet"))
            }
        case let .hidden(generation, canShow):
            VStack(alignment: .leading, spacing: HubLook.stack) {
                HubCard(muted: true, heavy: true) {
                    HubConfirmedView(kind: .hidden,
                                     title: String(localized: "Your privacy screen is on. Viewers don't see you."),
                                     line: hiddenBy)
                }
                if canShow {
                    Button {
                        model.hubShowPicture(generation: generation)
                    } label: {
                        Text("Show the picture")
                    }
                    .buttonStyle(HubOutlineButtonStyle())
                    .accessibilityHint(String(localized: "Viewers see and hear you again."))
                    HubHintView(text: String(localized: "Viewers see and hear you again."))
                } else {
                    HubHintView(text: String(localized: "Only the streamer can show the picture again."))
                        .accessibilityHidden(false)
                }
            }
        case .showRequested:
            HubCard(muted: true, heavy: true) {
                HubUnconfirmedView(title: String(localized: "Show requested, not confirmed yet"),
                                   line: String(localized: "The privacy screen stays on until the hub confirms."))
            }
        }
    }
}

private struct HubRigStreamView: View {
    let name: String
    let bonded: Bool
    let remoteControl: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HubSectionLabel(text: String(localized: "Set by your rig"))
            HubCard {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(systemName: "lock")
                        .foregroundStyle(HubLook.textMuted)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name)
                            .font(.headline)
                            .foregroundStyle(HubLook.text)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(bonded ? String(localized: "Stream to the hub, bonded over this phone's links")
                            : String(localized: "Stream to the hub"))
                            .font(.subheadline)
                            .foregroundStyle(HubLook.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                        if remoteControl {
                            Text("Remote control")
                                .font(.subheadline)
                                .foregroundStyle(HubLook.textMuted)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
            }
            HubHintView(text: String(localized: "Nothing to type or change. Leaving the rig removes it from this phone."))
                .accessibilityHidden(false)
        }
    }
}

// Someone joined by a sent link and waits: the owner's one decision.
private struct HubWaitingDeviceView: View {
    let model: Model
    @ObservedObject var hub: HubProvider
    let device: HubDevice

    @ViewBuilder
    private func buttons() -> some View {
        Button {
            // A new co-owner's device asks first; any other is let in.
            if model.hubNeedsCoOwnerConfirm(device: device.id) {
                hub.accessFailed = nil
                hub.accessConfirming = HubAccessConfirm(grant: device.id, action: .coOwner)
            } else {
                model.hubAllow(device.id)
            }
        } label: {
            Text(HubWords.Access.allow)
        }
        .buttonStyle(HubDecisionButtonStyle())
        .accessibilityLabel("\(HubWords.Access.allow): \(device.name)")
        .accessibilityHint(hubAllowsLine(hubRoleAllows(device.role)))
        Button {
            hub.accessFailed = nil
            hub.accessConfirming = HubAccessConfirm(grant: device.id, action: .end)
        } label: {
            Text(HubWords.Access.remove)
        }
        .buttonStyle(HubOutlineButtonStyle())
        .accessibilityLabel("\(HubWords.Access.remove): \(device.name)")
    }

    var body: some View {
        let role = HubWords.Access.role(device.role)
        VStack(alignment: .leading, spacing: 8) {
            HubSectionLabel(text: HubWords.Access.waiting)
            HubCard {
                Text(device.role == "helper" ? HubWords.Crew.wantsToHelp(device.name)
                    : HubWords.Crew.wantsToJoin(device.name))
                    .font(.headline)
                    .foregroundStyle(HubLook.text)
                    .fixedSize(horizontal: false, vertical: true)
                // Allow first, within reach without scrolling; what it
                // gives is said right under it.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        buttons()
                    }
                    VStack(spacing: 8) {
                        buttons()
                    }
                }
                Text("\(role) · \(hubAllowsLine(hubRoleAllows(device.role)))")
                    .font(.footnote)
                    .foregroundStyle(HubLook.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
                HubAccessFailureView(hub: hub, grant: device.id)
            }
            .disabled(hub.accessBusy.contains(device.id))
            .hubAccessConfirm(model: model,
                              hub: hub,
                              grant: device.id,
                              end: .init(label: HubWords.Access.remove,
                                         confirm: HubWords.Access.confirmRemove(device.name)),
                              coOwner: model.hubCoOwnerConfirmFor(device: device))
        }
    }
}

private struct HubPanelLinkRow: View {
    let title: String
    let line: String?
    let screen: HubScreen

    var body: some View {
        NavigationLink(value: screen) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(HubLook.text)
                        .fixedSize(horizontal: false, vertical: true)
                    if let line {
                        Text(line)
                            .font(.subheadline)
                            .foregroundStyle(HubLook.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(HubLook.textMuted)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: HubLook.minTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// An owner device: the way to the crew and to "Who has access".
private struct HubCrewLinksView: View {
    let summary: HubCrewSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HubSectionLabel(text: String(localized: "People"))
            HubCard {
                HubPanelLinkRow(title: HubWords.Crew.title,
                                line: summary.line ?? String(localized: "Helper and mod links"),
                                screen: .crew)
                Rectangle()
                    .fill(HubLook.border)
                    .frame(height: HubLook.hairline)
                HubPanelLinkRow(title: HubWords.Access.title,
                                line: String(localized: "Devices, helpers, mods, and what happened"),
                                screen: .access)
            }
        }
    }
}

// Any other device: who helps, by name. No links and nothing to press,
// because the hub lets only an owner device let people in or remove them.
private struct HubCrewReadOnlyView: View {
    let summary: HubCrewSummary

    var body: some View {
        if !summary.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HubSectionLabel(text: HubWords.Crew.title)
                HubCard {
                    ForEach(summary.helpers, id: \.id) { helper in
                        row(helper.name,
                            HubWords.Access.role("helper"),
                            helper.online == true ? HubWords.Access.here : HubWords.Access.away)
                    }
                    ForEach(summary.mods, id: \.id) { mod in
                        row(mod.name,
                            HubWords.Access.role("mod"),
                            mod.state == "joined" ? HubWords.Crew.joined : HubWords.Crew.waiting)
                    }
                }
                HubHintView(text: String(localized: "Only an owner device can let people in or remove them."))
                    .accessibilityHidden(false)
            }
        }
    }

    private func row(_ name: String, _ role: String, _ state: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name)
                .font(.headline)
                .foregroundStyle(HubLook.text)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(role) · \(state)")
                .font(.subheadline)
                .foregroundStyle(HubLook.textMuted)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct HubJoinedPanelView: View {
    let model: Model
    @ObservedObject var hub: HubProvider
    let settings: SettingsHub
    @State private var presentingLeave = false

    var body: some View {
        let status = model.hubStatus()
        let controls = model.hubControlList()
        HubRigHeaderView(name: settings.name)
        HubCard {
            // While hidden, the privacy card below says it and who asked.
            HubStatusView(status: status, showLine: status.kind != .hidden, showPhone: status.kind != .hidden)
            if !hub.connected, !hub.pending {
                Button {
                    model.hubReconnectNow()
                } label: {
                    Text("Try now")
                }
                .buttonStyle(HubOutlineButtonStyle())
                .padding(.top, 6)
                .accessibilityHint(String(localized: "Tries to reach the hub again right away."))
            }
        }
        let owner = model.hubIsOwner()
        let waiting = owner && hub.connected ? hubWaitingDevices(hub.state) : []
        ForEach(waiting, id: \.id) { device in
            HubWaitingDeviceView(model: model, hub: hub, device: device)
        }
        if hub.connected, !hub.pending {
            if let move = controls.move {
                HubMoveControlView(model: model, control: move)
            }
            // Connect comes first while it is the next step; once connected,
            // HIDE sits above Disconnect so it stays within reach.
            if let feed = controls.feed, feed == .connect || feed == .connecting {
                // Allow, when someone waits, is the screen's one decision.
                HubFeedControlView(model: model,
                                   control: feed,
                                   isDecision: waiting.isEmpty,
                                   onAir: controls.move == .onAir)
            }
            if let privacy = controls.privacy {
                HubPrivacyControlView(model: model,
                                      control: privacy,
                                      live: hub.state?.isLive == true,
                                      hiddenBy: hub.state.flatMap {
                                          hubHiddenByLine($0.session.privacy, me: settings.deviceId)
                                      })
            }
            if let feed = controls.feed, feed == .connected || feed == .disconnecting {
                HubFeedControlView(model: model,
                                   control: feed,
                                   isDecision: false,
                                   onAir: controls.move == .onAir)
            }
            let facts = hubFacts(hub.state?.feed(settings.deviceId))
            if !facts.isEmpty {
                HubFactsView(facts: facts)
            }
        } else if !hub.pending {
            HubHintView(text: String(localized: "The controls come back when the hub answers. Until then nothing is assumed about the stream."))
                .accessibilityHidden(false)
        }
        if owner {
            HubCrewLinksView(summary: hubCrewSummary(hub.state))
        } else if !hub.pending {
            HubCrewReadOnlyView(summary: hubCrewSummary(hub.state))
        }
        if let stream = model.hubRigStream() {
            HubRigStreamView(name: stream.name,
                             bonded: stream.url.hasPrefix("srtla"),
                             remoteControl: settings.remoteControlSet)
        }
        Button(role: .destructive) {
            presentingLeave = true
        } label: {
            Text("Leave this rig")
                .font(.body)
                .foregroundStyle(HubLook.urgent)
                .frame(maxWidth: .infinity, minHeight: HubLook.minTouchTarget)
        }
        .buttonStyle(.plain)
        .confirmationDialog("Leave \(settings.name)?", isPresented: $presentingLeave, titleVisibility: .visible) {
            Button("Leave", role: .destructive) {
                model.leaveHub()
            }
        } message: {
            Text("The stream settings from the rig are removed from this phone.")
        }
    }
}

private struct HubEmptyPanelView: View {
    let notice: HubNotice?
    @ScaledMetric(relativeTo: .title) private var markSize: CGFloat = 56

    private func noticeStatus(_ notice: HubNotice) -> HubStatus {
        switch notice {
        case let .removed(name):
            HubStatus(kind: .unknown,
                      title: String(localized: "Can't say right now"),
                      line: String(localized: "This phone isn't in \(name) any more. Its stream settings from the rig are gone."))
        case let .unknownToHub(name):
            HubStatus(kind: .unknown,
                      title: String(localized: "Can't say right now"),
                      line: String(localized: "\(name) doesn't know this phone any more. Its stream settings from the rig are gone."))
        }
    }

    var body: some View {
        if let notice {
            HubCard {
                HubStatusView(status: noticeStatus(notice))
            }
        }
        VStack(alignment: .leading, spacing: HubLook.stack) {
            HubMarkView(size: markSize)
            Text(notice == nil ? "Join your rig" : "Join again")
                .font(.title2.weight(.bold))
                .foregroundStyle(HubLook.text)
                .accessibilityAddTraits(.isHeader)
            Text("Scan the code on your dashboard, or open the link you were sent.")
                .font(.body)
                .foregroundStyle(HubLook.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
        HubCard {
            Label {
                Text("Point the Camera app at the code, then tap the link it shows.")
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "qrcode.viewfinder")
            }
            .foregroundStyle(HubLook.text)
            Rectangle()
                .fill(HubLook.border)
                .frame(height: HubLook.hairline)
            Label {
                Text("Or tap the link in the message someone on the rig sent you.")
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "link")
            }
            .foregroundStyle(HubLook.text)
        }
        HubHintView(text: String(localized: "Nothing to type. The code is a one-time ticket, and your rig fills in this phone's stream settings."))
            .accessibilityHidden(false)
    }
}

private let hubPanelEnd = "end"

struct HubPanelView: View {
    let model: Model
    @ObservedObject var hub: HubProvider

    var body: some View {
        // Read on every pass: leaving or being removed replaces it.
        let settings = model.database.hub
        ScrollViewReader { reader in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if settings.isJoined() {
                        HubJoinedPanelView(model: model, hub: hub, settings: settings)
                    } else {
                        HubEmptyPanelView(notice: hub.notice)
                    }
                    Color.clear
                        .frame(height: 1)
                        .id(hubPanelEnd)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, HubLook.screenEdge)
                .padding(.vertical, 16)
                .frame(maxWidth: 560, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            #if DEBUG
            .onAppear {
                if model.hubShowcaseScrollsToEnd() {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        reader.scrollTo(hubPanelEnd, anchor: .bottom)
                    }
                }
            }
            #endif
        }
        .background(HubLook.background)
        .navigationTitle("Rig")
    }
}
