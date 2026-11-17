import SwiftUI

// "Who has access": every device, helper, mod and unused invite as one kind
// of row, with what it may do in plain words, how it came in, who gave it
// and when it ends; then what happened. Read over the phone's own hub
// connection and drawn with the system's list. Only an owner device gets
// it; a row shows only the buttons the hub says this owner has.

// The shared list look: the system's grouped list on the paper background.
extension View {
    func hubListStyle() -> some View {
        scrollContentBackground(.hidden)
            .background(HubLook.background)
    }
}

// A small outlined control inside a row.
struct HubRowButtonStyle: ButtonStyle {
    var filled = false
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .hubRowControl(filled: filled, pressed: configuration.isPressed)
            .opacity(enabled ? 1 : 0.4)
    }
}

extension View {
    func hubRowControl(filled: Bool = false, pressed: Bool = false) -> some View {
        font(.subheadline.weight(.semibold))
            .multilineTextAlignment(.center)
            .foregroundStyle(filled ? HubLook.onDecision : HubLook.text)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .frame(minHeight: HubLook.minTouchTarget)
            .background(filled ? HubLook.decision : (pressed ? HubLook.surfaceMuted : HubLook.surface),
                        in: RoundedRectangle(cornerRadius: HubLook.radiusControl))
            .overlay(
                RoundedRectangle(cornerRadius: HubLook.radiusControl)
                    .strokeBorder(filled ? HubLook.decision : HubLook.borderStrong, lineWidth: HubLook.hairline)
            )
            .opacity(pressed && filled ? 0.75 : 1)
            .contentShape(Rectangle())
    }
}

// Allow, Change when it ends, and Remove or End now with its one confirm.
struct HubGrantActionsView: View {
    let model: Model
    @ObservedObject var hub: HubProvider
    let row: HubAccessRow
    // The crew list offers only ending; changing lives in Who has access.
    var offersChange = true
    var endLabel: String?

    private func ask(_ action: HubAccessAction) {
        hub.accessFailed = nil
        hub.accessConfirming = HubAccessConfirm(grant: row.id, action: action)
    }

    @ViewBuilder
    private func buttons() -> some View {
        if row.allow {
            Button(HubWords.Access.allow) {
                if row.allowConfirm != nil {
                    ask(.coOwner)
                } else {
                    model.hubAllow(row.id)
                }
            }
            .buttonStyle(HubRowButtonStyle(filled: true))
            .accessibilityHint(row.allows)
        }
        if offersChange, let hand = row.hand {
            Button(hand.label) {
                ask(.hand)
            }
            .buttonStyle(HubRowButtonStyle())
            .accessibilityLabel("\(hand.label): \(row.name)")
        }
        if offersChange, let change = row.change {
            Menu {
                ForEach(change) { choice in
                    Button(choice.label) {
                        model.hubChangeAccess(row.id, choice)
                    }
                }
            } label: {
                Text(HubWords.Access.change)
                    .hubRowControl()
            }
            .accessibilityLabel("\(HubWords.Access.change): \(row.name)")
        }
        if let end = row.end {
            Button(endLabel ?? end.label) {
                ask(.end)
            }
            .buttonStyle(HubRowButtonStyle())
            .accessibilityLabel("\(endLabel ?? end.label): \(row.name)")
        }
    }

    var body: some View {
        if row.allow || row.end != nil || (offersChange && (row.change != nil || row.hand != nil)) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    buttons()
                }
                VStack(alignment: .leading, spacing: 8) {
                    buttons()
                }
            }
            .disabled(!hub.connected || hub.accessBusy.contains(row.id))
            .padding(.top, 4)
            .hubAccessConfirm(model: model,
                              hub: hub,
                              grant: row.id,
                              end: row.end.map { .init(label: endLabel ?? $0.label, confirm: $0.confirm) },
                              coOwner: row.allowConfirm
                                  ?? hubCoOwnerConfirm(person: nil, device: row.name),
                              hand: row.hand)
        }
        HubAccessFailureView(hub: hub, grant: row.id)
    }
}

// What went wrong with one row's last request, said on that row.
struct HubAccessFailureView: View {
    @ObservedObject var hub: HubProvider
    let grant: String

    var body: some View {
        if hub.accessFailed == grant {
            Label {
                Text(hub.accessFailedLine)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                HubStatusMarkView(kind: .caution)
            }
            .font(.footnote)
            .foregroundStyle(HubLook.text)
        }
    }
}

// The one confirm a row's button asks for, as the system's own sheet. Each
// says what happens; the way out is always there and changes nothing.
private struct HubAccessConfirmModifier: ViewModifier {
    let model: Model
    @ObservedObject var hub: HubProvider
    let grant: String
    var end: HubAccessRow.End?
    var coOwner: HubAccessRow.End?
    var hand: HubAccessRow.End?
    var takeBack: HubAccessRow.End?
    var clear: HubAccessRow.End?

    private func current() -> (HubAccessAction, HubAccessRow.End)? {
        guard let confirming = hub.accessConfirming, confirming.grant == grant else {
            return nil
        }
        let found: HubAccessRow.End? = switch confirming.action {
        case .end:
            end
        case .coOwner:
            coOwner
        case .hand:
            hand
        case .takeBack:
            takeBack
        case .clear:
            clear
        }
        return found.map { (confirming.action, $0) }
    }

    private func presented() -> Binding<Bool> {
        Binding(get: {
            current() != nil
        }, set: { presented in
            if !presented, hub.accessConfirming?.grant == grant {
                hub.accessConfirming = nil
            }
        })
    }

    private func run(_ action: HubAccessAction) {
        switch action {
        case .end:
            model.hubEndAccess(grant)
        case .coOwner:
            model.hubAllow(grant, coOwner: true)
        case .hand:
            model.hubHandStream(grant)
        case .takeBack:
            model.hubTakeBackStream(grant)
        case .clear:
            model.hubClearTrail()
        }
    }

    func body(content: Content) -> some View {
        let now = current()
        content.confirmationDialog(now?.1.confirm ?? "", isPresented: presented(), titleVisibility: .visible) {
            if let now {
                Button(now.1.label, role: now.0 == .end || now.0 == .clear ? .destructive : nil) {
                    run(now.0)
                }
                Button(now.0 == .end ? HubWords.Access.keep : HubWords.Access.cancel, role: .cancel) {}
            }
        }
    }
}

extension View {
    func hubAccessConfirm(model: Model,
                          hub: HubProvider,
                          grant: String,
                          end: HubAccessRow.End? = nil,
                          coOwner: HubAccessRow.End? = nil,
                          hand: HubAccessRow.End? = nil,
                          takeBack: HubAccessRow.End? = nil,
                          clear: HubAccessRow.End? = nil) -> some View
    {
        modifier(HubAccessConfirmModifier(model: model,
                                          hub: hub,
                                          grant: grant,
                                          end: end,
                                          coOwner: coOwner,
                                          hand: hand,
                                          takeBack: takeBack,
                                          clear: clear))
    }
}

struct HubPresenceView: View {
    let text: String
    let here: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            if here {
                HubStatusMarkView(kind: .connected)
                    .scaleEffect(0.75)
            }
            Text(text)
                .font(.subheadline)
                .foregroundStyle(here ? HubLook.text : HubLook.textMuted)
        }
    }
}

private struct HubGrantRowView: View {
    let model: Model
    @ObservedObject var hub: HubProvider
    let row: HubAccessRow

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            VStack(alignment: .leading, spacing: 4) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        name()
                        Spacer(minLength: 8)
                        role()
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        name()
                        role()
                    }
                }
                if let presence = row.presence {
                    HubPresenceView(text: presence, here: row.here)
                }
                Text(row.allows)
                    .font(.body)
                    .foregroundStyle(HubLook.text)
                    .fixedSize(horizontal: false, vertical: true)
                Text(row.how)
                    .font(.footnote)
                    .foregroundStyle(HubLook.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
                Text(row.ends)
                    .font(.footnote)
                    .foregroundStyle(HubLook.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(row.notes, id: \.self) { note in
                    Text(note)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(HubLook.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(row.spoken)
            HubGrantActionsView(model: model, hub: hub, row: row)
        }
        .padding(.vertical, 4)
        .listRowBackground(HubLook.surface)
    }

    private func name() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(row.name)
                .font(.headline)
                .foregroundStyle(HubLook.text)
                .fixedSize(horizontal: false, vertical: true)
            if let forName = row.forName {
                Text("for \(forName)")
                    .font(.subheadline)
                    .foregroundStyle(HubLook.textMuted)
            }
        }
    }

    private func role() -> some View {
        Text(row.role)
            .font(HubLook.label)
            .textCase(.uppercase)
            .tracking(0.8)
            .foregroundStyle(HubLook.textMuted)
    }
}

struct HubListHeader: View {
    let text: String

    var body: some View {
        HubSectionLabel(text: text)
            .textCase(nil)
    }
}

// The line at the top: "<hub> · LIVE", then how many of what.
struct HubAccessSummaryView: View {
    let page: HubAccessPage

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                HubStatusMarkView(kind: page.kind)
                Text(page.label)
                    .font(.headline)
                    .foregroundStyle(HubLook.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(page.line)
                .font(.body)
                .foregroundStyle(HubLook.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .listRowBackground(HubLook.surface)
    }
}

// "This stream": who runs it, and Take back when it was handed over.
private struct HubAccessRunningView: View {
    let model: Model
    @ObservedObject var hub: HubProvider
    let running: HubAccessRunning

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            VStack(alignment: .leading, spacing: 4) {
                Text(running.line)
                    .font(.body)
                    .foregroundStyle(HubLook.text)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(running.facts, id: \.self) { fact in
                    Text(fact)
                        .font(.footnote)
                        .foregroundStyle(HubLook.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)
            if let takeBack = running.takeBack, let device = running.device {
                // Filed under its own id, apart from the same device's row.
                let grant = "\(device)#stream"
                Button(takeBack.label) {
                    hub.accessFailed = nil
                    hub.accessConfirming = HubAccessConfirm(grant: grant, action: .takeBack)
                }
                .buttonStyle(HubRowButtonStyle())
                .disabled(!hub.connected || hub.accessBusy.contains(grant))
                .padding(.top, 4)
                .hubAccessConfirm(model: model, hub: hub, grant: grant, takeBack: takeBack)
                HubAccessFailureView(hub: hub, grant: grant)
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(HubLook.surface)
    }
}

struct HubAccessView: View {
    let model: Model
    @ObservedObject var hub: HubProvider

    var body: some View {
        // Read on every pass, so "today at" stays true.
        let page = model.hubAccessPageNow()
        ScrollViewReader { reader in
            list(page)
            #if DEBUG
                .hubShowcaseSection(hub, reader)
            #endif
        }
        .hubListStyle()
        .navigationTitle(HubWords.Access.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            model.hubRefreshAccess()
        }
    }

    private func list(_ page: HubAccessPage?) -> some View {
        List {
            if let page {
                Section {
                    HubAccessSummaryView(page: page)
                }
                if let running = page.running {
                    Section {
                        HubAccessRunningView(model: model, hub: hub, running: running)
                    } header: {
                        HubListHeader(text: HubWords.Access.thisStream)
                    }
                }
                ForEach(page.sections) { section in
                    Section {
                        ForEach(section.rows) { row in
                            HubGrantRowView(model: model, hub: hub, row: row)
                        }
                    } header: {
                        HubListHeader(text: section.tag.map { "\(section.title) · \($0)" } ?? section.title)
                            .id(section.id)
                    }
                }
                Section {
                    if page.trail.isEmpty {
                        Text(HubWords.Access.emptyTrail)
                            .foregroundStyle(HubLook.textMuted)
                            .listRowBackground(HubLook.surface)
                    }
                    ForEach(page.trail) { line in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(line.text)
                                .font(.body)
                                .foregroundStyle(HubLook.text)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(line.at)
                                .font(.footnote)
                                .foregroundStyle(HubLook.textMuted)
                        }
                        .accessibilityElement(children: .combine)
                        .listRowBackground(HubLook.surface)
                    }
                    if page.more {
                        Button(HubWords.Access.older) {
                            model.hubOlderTrail()
                        }
                        .foregroundStyle(HubLook.text)
                        .disabled(!hub.connected)
                        .listRowBackground(HubLook.surface)
                    }
                    if page.clear {
                        VStack(alignment: .leading, spacing: 4) {
                            Button(HubWords.Access.clear) {
                                hub.accessFailed = nil
                                hub.accessConfirming = HubAccessConfirm(grant: hubTrailGrant, action: .clear)
                            }
                            .buttonStyle(HubRowButtonStyle())
                            .disabled(!hub.connected || hub.accessBusy.contains(hubTrailGrant))
                            .hubAccessConfirm(model: model,
                                              hub: hub,
                                              grant: hubTrailGrant,
                                              clear: .init(label: HubWords.Access.clear,
                                                           confirm: HubWords.Access.confirmClear))
                            HubAccessFailureView(hub: hub, grant: hubTrailGrant)
                        }
                        .listRowBackground(HubLook.surface)
                    }
                } header: {
                    HubListHeader(text: HubWords.Access.trail)
                        .id(hubAccessTrailId)
                }
            } else {
                Section {
                    HubStatusView(status: HubStatus(kind: .unknown,
                                                    title: HubWords.Access.unknownTitle,
                                                    line: hub.connected
                                                        ? (hub.accessLoadFailed
                                                            ? String(localized: "This hub couldn’t list who has access.")
                                                            : String(localized: "Asking the hub who has access…"))
                                                        : HubWords.Access.unknownLine))
                        .listRowBackground(HubLook.surface)
                    if hub.accessLoadFailed {
                        Button("Try again") {
                            model.hubRefreshAccess()
                        }
                        .listRowBackground(HubLook.surface)
                    }
                }
            }
        }
    }
}

let hubAccessTrailId = "trail"

#if DEBUG
extension View {
    // For pictures of a long list: open it at one section.
    func hubShowcaseSection(_ hub: HubProvider, _ reader: ScrollViewProxy) -> some View {
        onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if let section = hub.showcaseSection {
                    reader.scrollTo(section, anchor: .top)
                }
            }
        }
    }
}
#endif
