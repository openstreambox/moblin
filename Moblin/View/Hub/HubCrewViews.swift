import SwiftUI

// The crew: people the streamer lets in for a stream. An owner device makes
// a helper link (the helper still waits for Allow) or a mod link (a web
// page with the status and HIDE only), shares it with the system's share
// sheet or as a code to scan, sees the links that are still open and ends
// one. A link is shown once, on the screen that made it.

private struct HubCrewRowView: View {
    let model: Model
    @ObservedObject var hub: HubProvider
    let row: HubAccessRow
    var endLabel: String?
    var extra: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            VStack(alignment: .leading, spacing: 4) {
                Text(row.name)
                    .font(.headline)
                    .foregroundStyle(HubLook.text)
                    .fixedSize(horizontal: false, vertical: true)
                if let presence = row.presence {
                    HubPresenceView(text: presence, here: row.here)
                }
                if let extra {
                    Text(extra)
                        .font(.footnote)
                        .foregroundStyle(HubLook.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(row.ends)
                    .font(.footnote)
                    .foregroundStyle(HubLook.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            HubGrantActionsView(model: model, hub: hub, row: row, offersChange: false, endLabel: endLabel)
        }
        .padding(.vertical, 4)
        .listRowBackground(HubLook.surface)
    }
}

private struct HubEmptyRowView: View {
    let text: String

    var body: some View {
        Text(text)
            .foregroundStyle(HubLook.textMuted)
            .listRowBackground(HubLook.surface)
    }
}

struct HubCrewView: View {
    let model: Model
    @ObservedObject var hub: HubProvider

    private func rows(_ page: HubAccessPage?, _ section: String) -> [HubAccessRow] {
        page?.sections.first { $0.id == section }?.rows ?? []
    }

    var body: some View {
        let page = model.hubAccessPageNow()
        let helpers = rows(page, "waiting").filter { $0.role == HubWords.Access.role("helper") }
            + rows(page, "helpers")
        let links = rows(page, "invites").filter { $0.role == HubWords.Access.role("helper") }
        let mods = rows(page, "mods")
        ScrollViewReader { reader in
            list(helpers: helpers, links: links, mods: mods)
            #if DEBUG
                .hubShowcaseSection(hub, reader)
            #endif
        }
        .hubListStyle()
        .navigationTitle(HubWords.Crew.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            model.hubRefreshAccess()
        }
    }

    private func list(helpers: [HubAccessRow], links: [HubAccessRow], mods: [HubAccessRow]) -> some View {
        List {
            Section {
                NavigationLink(value: HubScreen.makeHelper) {
                    Label(HubWords.Crew.makeHelper, systemImage: "person.badge.plus")
                }
                NavigationLink(value: HubScreen.makeMod) {
                    Label(HubWords.Crew.makeMod, systemImage: "link.badge.plus")
                }
            } footer: {
                if !hub.connected {
                    Text(HubWords.Access.unknownLine)
                }
            }
            .foregroundStyle(HubLook.text)
            .listRowBackground(HubLook.surface)
            .disabled(!hub.connected)
            Section {
                if helpers.isEmpty {
                    HubEmptyRowView(text: HubWords.Crew.emptyHelpers)
                }
                ForEach(helpers) { row in
                    HubCrewRowView(model: model, hub: hub, row: row)
                }
            } header: {
                HubListHeader(text: HubWords.Crew.helpers)
            }
            Section {
                if links.isEmpty {
                    HubEmptyRowView(text: HubWords.Crew.emptyLinks)
                }
                ForEach(links) { row in
                    HubCrewRowView(model: model,
                                   hub: hub,
                                   row: row,
                                   endLabel: HubWords.Crew.endLink,
                                   extra: row.notes.first)
                }
            } header: {
                HubListHeader(text: HubWords.Crew.links)
                    .id("links")
            }
            Section {
                if mods.isEmpty {
                    HubEmptyRowView(text: HubWords.Crew.emptyMods)
                }
                ForEach(mods) { row in
                    HubCrewRowView(model: model, hub: hub, row: row)
                }
            } header: {
                HubListHeader(text: HubWords.Crew.mods)
                    .id("mods")
            }
            Section {
                NavigationLink(value: HubScreen.access) {
                    Label(HubWords.Access.title, systemImage: "person.2.badge.key")
                }
                .foregroundStyle(HubLook.text)
                .listRowBackground(HubLook.surface)
            }
        }
    }
}

// The link the hub just made: a code to scan, the share sheet, and copy.
private struct HubMadeLinkView: View {
    let model: Model
    let made: HubMadeLink
    @State private var copied = false
    @ScaledMetric(relativeTo: .body) private var codeSize: CGFloat = 190

    private func title() -> String {
        switch made.kind {
        case .helper:
            made.name.isEmpty ? HubWords.Crew.helperLink
                : String(localized: "\(HubWords.Crew.helperLink) for \(made.name)")
        case .mod:
            String(localized: "Mod link for \(made.name)")
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title())
                        .font(.title2.weight(.bold))
                        .foregroundStyle(HubLook.text)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text(made.kind == .helper ? HubWords.Crew.helperHint : HubWords.Crew.modHint)
                        .font(.body)
                        .foregroundStyle(HubLook.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                    if made.closesAt != nil {
                        Text(HubWords.Access.inviteAt(model.hubWhen().text(made.closesAt)))
                            .font(.footnote)
                            .foregroundStyle(HubLook.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if let image = generateQrCode(from: made.link) {
                    // A code is dark on white in both themes, or cameras don't read it.
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: min(codeSize, 260), height: min(codeSize, 260))
                        .padding(10)
                        .background(.white, in: RoundedRectangle(cornerRadius: HubLook.radiusCard))
                        .overlay(
                            RoundedRectangle(cornerRadius: HubLook.radiusCard)
                                .strokeBorder(HubLook.border, lineWidth: HubLook.hairline)
                        )
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel(HubWords.Crew.qrLabel)
                }
                ShareLink(item: made.link) {
                    Text(HubWords.Crew.share)
                }
                .buttonStyle(HubDecisionButtonStyle())
                Button {
                    UIPasteboard.general.string = made.link
                    copied = true
                } label: {
                    Text(copied ? HubWords.Crew.copied : HubWords.Crew.copy)
                }
                .buttonStyle(HubOutlineButtonStyle())
                HubHintView(text: HubWords.Crew.shownOnce)
                    .accessibilityHidden(false)
                Button {
                    model.hubCloseMadeLink()
                } label: {
                    Text(HubWords.Crew.done)
                }
                .buttonStyle(HubOutlineButtonStyle())
            }
            .padding(.horizontal, HubLook.screenEdge)
            .padding(.vertical, 16)
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(HubLook.background)
        .navigationBarBackButtonHidden(true)
    }
}

private struct HubMakeButtonRow: View {
    let making: Bool
    let failure: String?
    let action: () -> Void

    var body: some View {
        Section {
            Button(action: action) {
                if making {
                    ProgressView()
                        .tint(HubLook.onDecision)
                } else {
                    Text(HubWords.Crew.makeLink)
                }
            }
            .buttonStyle(HubDecisionButtonStyle())
            .disabled(making)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        } footer: {
            if let failure {
                Label {
                    Text(failure)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    HubStatusMarkView(kind: .caution)
                }
                .foregroundStyle(HubLook.text)
            }
        }
    }
}

private struct HubDurationPicker: View {
    let title: String
    @Binding var selection: HubLinkDuration

    var body: some View {
        Picker(title, selection: $selection) {
            ForEach(HubLinkDuration.allCases) { duration in
                Text(HubWords.duration(duration))
                    .tag(duration)
            }
        }
    }
}

private enum HelperEnds: Hashable {
    case stream
    case after
    case never
}

struct HubMakeHelperLinkView: View {
    let model: Model
    @ObservedObject var hub: HubProvider
    @State private var name = ""
    @State private var linkLasts: HubLinkDuration = .twoHours
    @State private var ends: HelperEnds = .stream
    @State private var after: HubLinkDuration = .halfDay
    @State private var making = false
    @State private var failure: String?

    private func make() {
        making = true
        failure = nil
        let access: HubHelperAccessEnds = switch ends {
        case .stream:
            .stream
        case .after:
            .after(after)
        case .never:
            .never
        }
        Task { @MainActor in
            failure = await model.hubMakeHelperLink(name: name, linkLasts: linkLasts, ends: access)
            making = false
        }
    }

    var body: some View {
        if let made = hub.madeLink, made.kind == .helper {
            HubMadeLinkView(model: model, made: made)
                .navigationTitle(HubWords.Crew.helperLink)
                .navigationBarTitleDisplayMode(.inline)
        } else {
            Form {
                Section {
                    TextField(HubWords.Crew.personName, text: $name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                    HubDurationPicker(title: HubWords.Crew.expiry, selection: $linkLasts)
                } footer: {
                    Text(HubWords.Crew.helperHint)
                }
                .listRowBackground(HubLook.surface)
                Section {
                    Picker(HubWords.Crew.accessEnds, selection: $ends) {
                        Text(HubWords.Crew.tonight)
                            .tag(HelperEnds.stream)
                        Text(HubWords.Crew.accessDuration)
                            .tag(HelperEnds.after)
                        Text(HubWords.Access.endsNever)
                            .tag(HelperEnds.never)
                    }
                    if ends == .after {
                        HubDurationPicker(title: HubWords.Crew.accessDuration, selection: $after)
                    }
                } footer: {
                    Text(hubAllowsLine(hubRoleAllows("helper")))
                }
                .listRowBackground(HubLook.surface)
                HubMakeButtonRow(making: making, failure: failure, action: make)
            }
            .tint(HubLook.text)
            .hubListStyle()
            .navigationTitle(HubWords.Crew.makeHelper)
            .navigationBarTitleDisplayMode(.inline)
            #if DEBUG
                .onAppear {
                    if let draft = hub.showcaseDraft {
                        name = draft
                    }
                }
            #endif
        }
    }
}

struct HubMakeModLinkView: View {
    let model: Model
    @ObservedObject var hub: HubProvider
    @State private var name = ""
    @State private var linkLasts: HubLinkDuration = .halfDay
    @State private var untilStream = true
    @State private var making = false
    @State private var failure: String?

    private func make() {
        making = true
        failure = nil
        Task { @MainActor in
            failure = await model.hubMakeModLink(name: name, linkLasts: linkLasts, untilStream: untilStream)
            making = false
        }
    }

    var body: some View {
        if let made = hub.madeLink, made.kind == .mod {
            HubMadeLinkView(model: model, made: made)
                .navigationTitle(HubWords.Crew.makeMod)
                .navigationBarTitleDisplayMode(.inline)
        } else {
            Form {
                Section {
                    TextField(HubWords.Crew.name, text: $name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                    HubDurationPicker(title: HubWords.Crew.expiry, selection: $linkLasts)
                    Toggle(HubWords.Access.endsStream, isOn: $untilStream)
                        .tint(HubLook.steady)
                } footer: {
                    Text(HubWords.Crew.modHint)
                }
                .listRowBackground(HubLook.surface)
                HubMakeButtonRow(making: making, failure: failure, action: make)
            }
            .tint(HubLook.text)
            .hubListStyle()
            .navigationTitle(HubWords.Crew.makeMod)
            .navigationBarTitleDisplayMode(.inline)
            #if DEBUG
                .onAppear {
                    if let draft = hub.showcaseDraft {
                        name = draft
                    }
                    if let failure = hub.showcaseFailure {
                        self.failure = failure
                    }
                }
            #endif
        }
    }
}

// The panel with the screens that open from it.
struct HubPanelStackView: View {
    let model: Model
    @ObservedObject var hub: HubProvider

    var body: some View {
        NavigationStack(path: $hub.path) {
            HubPanelView(model: model, hub: hub)
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(for: HubScreen.self) { screen in
                    switch screen {
                    case .crew:
                        HubCrewView(model: model, hub: hub)
                    case .access:
                        HubAccessView(model: model, hub: hub)
                    case .makeHelper:
                        HubMakeHelperLinkView(model: model, hub: hub)
                    case .makeMod:
                        HubMakeModLinkView(model: model, hub: hub)
                    }
                }
        }
        .onDisappear {
            hub.path = []
            hub.madeLink = nil
            hub.accessConfirming = nil
            hub.accessFailed = nil
        }
    }
}
