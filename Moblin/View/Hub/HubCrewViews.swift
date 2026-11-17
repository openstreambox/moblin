import SwiftUI

struct HubWaitingView: View {
    let model: Model
    @ObservedObject var hub: HubProvider
    let waiting: HubWaiting

    private func ask(_ action: HubAccessAction) {
        hub.accessFailed = nil
        hub.accessConfirming = HubAccessConfirm(grant: waiting.id, action: action)
    }

    @ViewBuilder
    private func buttons() -> some View {
        if waiting.allow {
            Button {
                if waiting.confirm != nil {
                    ask(.coOwner)
                } else {
                    model.hubAllow(waiting.id)
                }
            } label: {
                Text(HubWords.Access.allow)
            }
            .buttonStyle(HubDecisionButtonStyle())
            .accessibilityLabel("\(HubWords.Access.allow): \(waiting.name)")
            .accessibilityHint(waiting.allows)
        }
        Button {
            ask(.end)
        } label: {
            Text(HubWords.Access.remove)
        }
        .buttonStyle(HubOutlineButtonStyle())
        .accessibilityLabel("\(HubWords.Access.remove): \(waiting.name)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(waiting.title)
                    .font(.headline)
                    .foregroundStyle(HubLook.text)
                    .fixedSize(horizontal: false, vertical: true)
                Text(waiting.line)
                    .font(.subheadline)
                    .foregroundStyle(HubLook.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    buttons()
                }
                VStack(spacing: 8) {
                    buttons()
                }
            }
            if waiting.allow {
                Text(waiting.allows)
                    .font(.footnote)
                    .foregroundStyle(HubLook.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HubAccessFailureView(hub: hub, grant: waiting.id)
        }
        .disabled(!hub.connected || hub.accessBusy.contains(waiting.id))
        .hubAccessConfirm(model: model,
                          hub: hub,
                          grant: waiting.id,
                          end: .init(label: HubWords.Access.remove,
                                     confirm: HubWords.Access.confirmRemove(waiting.name)),
                          coOwner: waiting.confirm ?? hubCoOwnerConfirm(person: nil, device: waiting.name))
    }
}

struct HubGiveBackView: View {
    let model: Model
    @ObservedObject var hub: HubProvider
    let session: HubSessionOwner
    var full = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.line)
                    .font(.headline)
                    .foregroundStyle(HubLook.text)
                    .fixedSize(horizontal: false, vertical: true)
                if full {
                    Text(session.allows)
                        .font(.subheadline)
                        .foregroundStyle(HubLook.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let ends = session.ends {
                    Text(ends)
                        .font(.footnote)
                        .foregroundStyle(HubLook.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)
            Button(session.giveBack.label) {
                hub.accessFailed = nil
                hub.accessConfirming = HubAccessConfirm(grant: hubGiveBackGrant, action: .giveBack)
            }
            .buttonStyle(HubRowButtonStyle())
            .disabled(!hub.connected || hub.accessBusy.contains(hubGiveBackGrant))
            HubAccessFailureView(hub: hub, grant: hubGiveBackGrant)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .hubAccessConfirm(model: model, hub: hub, grant: hubGiveBackGrant, giveBack: session.giveBack)
    }
}

private struct HubCrewRowView: View {
    let model: Model
    @ObservedObject var hub: HubProvider
    let row: HubCrewRow

    private func text() -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(row.title)
                .font(.headline)
                .foregroundStyle(HubLook.text)
                .fixedSize(horizontal: false, vertical: true)
            HubPresenceView(text: row.statusLine, here: row.here)
            if let line = row.line {
                Text(line)
                    .font(.footnote)
                    .foregroundStyle(HubLook.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.spoken)
    }

    private func button(_ end: HubAccessRow.End) -> some View {
        Button(end.label) {
            hub.accessFailed = nil
            hub.accessConfirming = HubAccessConfirm(grant: row.id, action: .end)
        }
        .buttonStyle(HubRowButtonStyle())
        .accessibilityLabel("\(end.label): \(row.name)")
        .disabled(!hub.connected || hub.accessBusy.contains(row.id))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let end = row.end {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: 12) {
                        text()
                        Spacer(minLength: 8)
                        button(end)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        text()
                        button(end)
                    }
                }
            } else {
                text()
            }
            HubAccessFailureView(hub: hub, grant: row.id)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .hubAccessConfirm(model: model, hub: hub, grant: row.id, end: row.end)
        .padding(.vertical, 4)
        .listRowBackground(HubLook.surface)
    }
}

private struct HubCrewStreamView: View {
    let model: Model
    @ObservedObject var hub: HubProvider
    let stream: HubCrewStream

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            VStack(alignment: .leading, spacing: 4) {
                Text(stream.line)
                    .font(.headline)
                    .foregroundStyle(HubLook.text)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail = stream.detail {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(HubLook.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)
            if let takeBack = stream.takeBack, let device = stream.device {
                let grant = "\(device)#stream"
                Button(takeBack.label) {
                    hub.accessFailed = nil
                    hub.accessConfirming = HubAccessConfirm(grant: grant, action: .takeBack)
                }
                .buttonStyle(HubRowButtonStyle())
                .disabled(!hub.connected || hub.accessBusy.contains(grant))
                .padding(.top, 4)
                HubAccessFailureView(hub: hub, grant: grant)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .hubAccessConfirm(model: model,
                          hub: hub,
                          grant: "\(stream.device ?? "")#stream",
                          takeBack: stream.takeBack)
        .padding(.vertical, 4)
        .listRowBackground(HubLook.surface)
    }
}

private struct HubAddRow: View {
    let add: HubCrewAdd

    private var screen: HubScreen {
        switch add {
        case .helper:
            .makeHelper
        case .mod:
            .makeMod
        case .coOwner:
            .makeCoOwner
        }
    }

    var body: some View {
        NavigationLink(value: screen) {
            Label(add.label, systemImage: "plus")
                .font(.body.weight(.semibold))
        }
        .foregroundStyle(HubLook.text)
        .listRowBackground(HubLook.surface)
    }
}

struct HubCrewView: View {
    let model: Model
    @ObservedObject var hub: HubProvider

    var body: some View {
        let page = model.hubCrewPageNow()
        ScrollViewReader { reader in
            list(page)
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

    private func header(_ group: HubCrewGroup) -> String {
        group.tag.map { "\(group.title) · \($0)" } ?? group.title
    }

    private func list(_ page: HubCrewPage) -> some View {
        List {
            Section {
                Text(hub.connected ? page.line : HubWords.Access.unknownLine)
                    .font(.subheadline)
                    .foregroundStyle(HubLook.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
                if hub.accessLoadFailed {
                    Text("This hub couldn’t list the crew.")
                        .listRowBackground(HubLook.surface)
                    Button("Try again") {
                        model.hubRefreshAccess()
                    }
                    .listRowBackground(HubLook.surface)
                }
            }
            if !page.waiting.isEmpty {
                Section {
                    ForEach(page.waiting) { waiting in
                        HubWaitingView(model: model, hub: hub, waiting: waiting)
                            .padding(.vertical, 4)
                            .listRowBackground(HubLook.surface)
                    }
                } header: {
                    HubListHeader(text: HubWords.Access.waiting)
                        .id("waiting")
                }
            }
            if page.stream != nil || page.session != nil {
                Section {
                    if let stream = page.stream {
                        HubCrewStreamView(model: model, hub: hub, stream: stream)
                    }
                    if let session = page.session {
                        HubGiveBackView(model: model, hub: hub, session: session)
                            .padding(.vertical, 4)
                            .listRowBackground(HubLook.surface)
                    }
                } header: {
                    HubListHeader(text: HubWords.Crew.thisStream)
                        .id("stream")
                }
            }
            ForEach(page.groups) { group in
                Section {
                    ForEach(group.rows) { row in
                        HubCrewRowView(model: model, hub: hub, row: row)
                    }
                    if group.rows.isEmpty, let empty = group.empty {
                        Text(empty)
                            .foregroundStyle(HubLook.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                            .listRowBackground(HubLook.surface)
                    }
                    if group.yours {
                        NavigationLink(value: HubScreen.ownerName) {
                            LabeledContent(HubWords.Crew.yourNameTitle, value: page.ownName ?? "")
                        }
                        .foregroundStyle(HubLook.text)
                        .listRowBackground(HubLook.surface)
                        .disabled(!hub.connected)
                    }
                    if let add = group.add {
                        HubAddRow(add: add)
                            .disabled(!hub.connected)
                    }
                } header: {
                    HubListHeader(text: header(group))
                        .id(group.id)
                }
            }
            if page.manages {
                Section {
                    NavigationLink(value: HubScreen.access) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(HubWords.Access.title)
                                .font(.headline)
                                .foregroundStyle(HubLook.text)
                            Text(page.summary.isEmpty ? HubWords.Crew.accessLine
                                : "\(page.summary). \(HubWords.Crew.accessLine)")
                                .font(.subheadline)
                                .foregroundStyle(HubLook.textMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .listRowBackground(HubLook.surface)
                    .id("access")
                }
            } else {
                Section {} footer: {
                    Text(HubWords.Crew.notOwner)
                }
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
            made.name.isEmpty ? HubWords.Crew.linkPlain : HubWords.Crew.linkFor(made.name)
        case .mod:
            HubWords.Crew.modLinkLabel(made.name)
        case .coOwner:
            HubWords.Crew.addCoOwner
        }
    }

    private func line() -> String {
        let closes = model.hubWhen().text(made.closesAt)
        switch made.kind {
        case .helper:
            return HubWords.Crew.helperReady(made.name)
        case .mod:
            return HubWords.Crew.modReady(made.name)
        case .coOwner:
            return HubWords.Crew.coOwnerLink(made.name, closes)
        }
    }

    private func next() -> String {
        switch made.kind {
        case .helper:
            HubWords.Crew.helperNext
        case .mod:
            HubWords.Crew.modNext
        case let .coOwner(known):
            known ? HubWords.Crew.coOwnerNextKnown : HubWords.Crew.coOwnerNext
        }
    }

    private func closes() -> String? {
        guard made.closesAt != nil else {
            return nil
        }
        let when = model.hubWhen().text(made.closesAt)
        switch made.kind {
        case .helper:
            return HubWords.Crew.helperCloses(when)
        case .mod:
            return HubWords.Crew.modCloses(when)
        case .coOwner:
            return nil
        }
    }

    var body: some View {
        ScrollViewReader { reader in
            content()
            #if DEBUG
                .hubShowcaseSection(model.hub, reader)
            #endif
        }
    }

    private func content() -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title())
                        .font(.title2.weight(.bold))
                        .foregroundStyle(HubLook.text)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text(line())
                        .font(.body)
                        .foregroundStyle(HubLook.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(next())
                        .font(.body)
                        .foregroundStyle(HubLook.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                    if let closes = closes() {
                        Text(closes)
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
                .id("share")
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
    var label = HubWords.Crew.makeLink
    let making: Bool
    let failure: String?
    var disabled = false
    let action: () -> Void

    var body: some View {
        Section {
            Button(action: action) {
                if making {
                    ProgressView()
                        .tint(HubLook.onDecision)
                } else {
                    Text(label)
                }
            }
            .buttonStyle(HubDecisionButtonStyle())
            .disabled(making || disabled)
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
                .id("failure")
            }
        }
    }
}

private struct HubNameField: View {
    let label: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.footnote)
                .foregroundStyle(HubLook.textMuted)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)
            TextField("", text: $text)
                .font(.body)
                .foregroundStyle(HubLook.text)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .accessibilityLabel(label)
        }
    }
}

private struct HubDurationPicker: View {
    let title: String
    @Binding var selection: HubLinkDuration

    var body: some View {
        Picker(title, selection: $selection) {
            ForEach(HubLinkDuration.linkChoices) { duration in
                Text(HubWords.duration(duration))
                    .tag(duration)
            }
        }
    }
}

private enum HelperEnds: Hashable {
    case stream
    case hour
    case halfDay
    case day
    case never

    var access: HubHelperAccessEnds {
        switch self {
        case .stream:
            .stream
        case .hour:
            .after(.hour)
        case .halfDay:
            .after(.halfDay)
        case .day:
            .after(.day)
        case .never:
            .never
        }
    }
}

struct HubMakeHelperLinkView: View {
    let model: Model
    @ObservedObject var hub: HubProvider
    @State private var name = ""
    @State private var linkLasts: HubLinkDuration = .twoHours
    @State private var ends: HelperEnds = .stream
    @State private var handStream = false
    @State private var making = false
    @State private var failure: String?

    private func make() {
        making = true
        failure = nil
        Task { @MainActor in
            failure = await model.hubMakeHelperLink(name: name,
                                                    linkLasts: linkLasts,
                                                    ends: ends.access,
                                                    handStream: handStream)
            making = false
        }
    }

    var body: some View {
        if let made = hub.madeLink, made.kind == .helper {
            HubMadeLinkView(model: model, made: made)
                .navigationTitle(HubWords.Crew.addHelper)
                .navigationBarTitleDisplayMode(.inline)
        } else {
            let owner = model.hubIsOwner()
            ScrollViewReader { reader in
            Form {
                Section {
                    HubNameField(label: HubWords.Crew.personName, text: $name)
                } footer: {
                    Text(HubWords.Crew.helperLine)
                }
                .listRowBackground(HubLook.surface)
                Section {
                    if owner, !handStream {
                        Picker(HubWords.Crew.accessEnds, selection: $ends) {
                            Text(HubWords.Crew.tonight)
                                .tag(HelperEnds.stream)
                            Text(HubWords.Crew.afterHour)
                                .tag(HelperEnds.hour)
                            Text(HubWords.Crew.afterHalfDay)
                                .tag(HelperEnds.halfDay)
                            Text(HubWords.Crew.afterDay)
                                .tag(HelperEnds.day)
                            Text(HubWords.Crew.untilRemoved)
                                .tag(HelperEnds.never)
                        }
                    } else {
                        LabeledContent(HubWords.Crew.accessEnds, value: HubWords.Crew.tonight)
                    }
                    HubDurationPicker(title: HubWords.Crew.expiry, selection: $linkLasts)
                } footer: {
                    if !handStream {
                        Text(hubAllowsLine(hubRoleAllows("helper")))
                    }
                }
                .listRowBackground(HubLook.surface)
                if owner {
                    Section {
                        Toggle(HubWords.Crew.handStream, isOn: $handStream)
                            .tint(HubLook.steady)
                    } footer: {
                        Text(HubWords.Crew.handStreamHint)
                            .id("hand")
                    }
                    .listRowBackground(HubLook.surface)
                }
                HubMakeButtonRow(making: making, failure: failure, action: make)
            }
            #if DEBUG
            .hubShowcaseSection(hub, reader)
            #endif
            }
            .tint(HubLook.text)
            .hubListStyle()
            .navigationTitle(HubWords.Crew.addHelper)
            .navigationBarTitleDisplayMode(.inline)
            #if DEBUG
                .onAppear {
                    if let draft = hub.showcaseDraft {
                        name = draft
                    }
                    handStream = hub.showcaseHand
                    if let failure = hub.showcaseFailure {
                        self.failure = failure
                    }
                }
            #endif
        }
    }
}

private enum ModEnds: Hashable {
    case stream
    case hour
    case halfDay
    case day

    var linkLasts: HubLinkDuration {
        switch self {
        case .hour:
            .hour
        case .day:
            .day
        case .stream, .halfDay:
            .halfDay
        }
    }
}

struct HubMakeModLinkView: View {
    let model: Model
    @ObservedObject var hub: HubProvider
    @State private var name = ""
    @State private var ends: ModEnds = .stream
    @State private var making = false
    @State private var failure: String?

    private func make() {
        making = true
        failure = nil
        let stream = ends == .stream || !model.hubIsOwner()
        Task { @MainActor in
            failure = await model.hubMakeModLink(name: name,
                                                 linkLasts: stream ? .halfDay : ends.linkLasts,
                                                 untilStream: stream)
            making = false
        }
    }

    var body: some View {
        if let made = hub.madeLink, made.kind == .mod {
            HubMadeLinkView(model: model, made: made)
                .navigationTitle(HubWords.Crew.addMod)
                .navigationBarTitleDisplayMode(.inline)
        } else {
            let owner = model.hubIsOwner()
            ScrollViewReader { reader in
            Form {
                Section {
                    HubNameField(label: HubWords.Crew.personName, text: $name)
                } footer: {
                    Text(HubWords.Crew.modLine)
                }
                .listRowBackground(HubLook.surface)
                Section {
                    if owner {
                        Picker(HubWords.Crew.modEnds, selection: $ends) {
                            Text(HubWords.Crew.tonight)
                                .tag(ModEnds.stream)
                            Text(HubWords.Access.changeHour)
                                .tag(ModEnds.hour)
                            Text(HubWords.Access.changeHalfDay)
                                .tag(ModEnds.halfDay)
                            Text(HubWords.Access.changeDay)
                                .tag(ModEnds.day)
                        }
                    } else {
                        LabeledContent(HubWords.Crew.modEnds, value: HubWords.Crew.tonight)
                    }
                } footer: {
                    if ends == .stream || !owner {
                        Text(HubWords.Crew.modTonightHint)
                    }
                }
                .listRowBackground(HubLook.surface)
                HubMakeButtonRow(making: making, failure: failure, action: make)
            }
            #if DEBUG
            .hubShowcaseSection(hub, reader)
            #endif
            }
            .tint(HubLook.text)
            .hubListStyle()
            .navigationTitle(HubWords.Crew.addMod)
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

struct HubMakeCoOwnerLinkView: View {
    let model: Model
    @ObservedObject var hub: HubProvider
    @State private var who = ""
    @State private var name = ""
    @State private var ownName = ""
    @State private var making = false
    @State private var failure: String?

    private func make(_ known: HubPerson?) {
        making = true
        failure = nil
        Task { @MainActor in
            failure = await model.hubMakeCoOwnerLink(name: name, person: known, ownName: ownName)
            making = false
        }
    }

    var body: some View {
        if let made = hub.madeLink, case .coOwner = made.kind {
            HubMadeLinkView(model: model, made: made)
                .navigationTitle(HubWords.Crew.addCoOwner)
                .navigationBarTitleDisplayMode(.inline)
        } else {
            let page = model.hubCrewPageNow()
            let known = page.others.first { $0.id == who }
            let typed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            ScrollViewReader { reader in
            Form {
                Section {
                    if !page.others.isEmpty {
                        Picker(HubWords.Crew.coOwnerWho, selection: $who) {
                            Text(HubWords.Crew.someoneNew)
                                .tag("")
                            ForEach(page.others, id: \.id) { person in
                                Text(HubWords.Crew.coOwnerAnother(person.name?.isEmpty == false ? person.name!
                                        : HubWords.Access.unnamed))
                                    .tag(person.id)
                            }
                        }
                    }
                    if known == nil {
                        HubNameField(label: HubWords.Crew.coOwnerName, text: $name)
                    }
                } footer: {
                    Text(HubWords.Setup.coOwnerLine)
                }
                .listRowBackground(HubLook.surface)
                if page.ownName?.isEmpty == true {
                    Section {
                        HubNameField(label: HubWords.Crew.yourName, text: $ownName)
                    } footer: {
                        Text(HubWords.Crew.yourNameHint)
                    }
                    .listRowBackground(HubLook.surface)
                }
                HubMakeButtonRow(label: HubWords.Crew.coOwnerShow,
                                 making: making,
                                 failure: failure,
                                 disabled: known == nil && typed.isEmpty)
                {
                    make(known)
                }
            }
            #if DEBUG
            .hubShowcaseSection(hub, reader)
            #endif
            }
            .tint(HubLook.text)
            .hubListStyle()
            .navigationTitle(HubWords.Crew.addCoOwner)
            .navigationBarTitleDisplayMode(.inline)
            #if DEBUG
                .onAppear {
                    if let draft = hub.showcaseDraft {
                        name = draft
                    }
                    if let own = hub.showcaseOwnName {
                        ownName = own
                    }
                }
            #endif
        }
    }
}

struct HubOwnerNameView: View {
    let model: Model
    @ObservedObject var hub: HubProvider
    @State private var name = ""
    @State private var saving = false
    @State private var failure: String?

    private func save() {
        saving = true
        failure = nil
        Task { @MainActor in
            failure = await model.hubNameOwner(name)
            saving = false
            if failure == nil, hub.path.last == .ownerName {
                hub.path.removeLast()
            }
        }
    }

    var body: some View {
        Form {
            Section {
                HubNameField(label: HubWords.Crew.yourName, text: $name)
            } footer: {
                Text(HubWords.Crew.yourNameHint)
            }
            .listRowBackground(HubLook.surface)
            HubMakeButtonRow(label: HubWords.Crew.save,
                             making: saving,
                             failure: failure,
                             disabled: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                             action: save)
        }
        .tint(HubLook.text)
        .hubListStyle()
        .navigationTitle(HubWords.Crew.yourNameTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            name = model.hubCrewPageNow().ownName ?? ""
            #if DEBUG
            if let own = hub.showcaseOwnName {
                name = own
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
                    case .makeCoOwner:
                        HubMakeCoOwnerLinkView(model: model, hub: hub)
                    case .ownerName:
                        HubOwnerNameView(model: model, hub: hub)
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
