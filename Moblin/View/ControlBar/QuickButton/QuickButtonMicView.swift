import Foundation
import SwiftUI

struct QuickButtonMicMicView: View {
    let model: Model
    @ObservedObject var mic: SettingsMicsMic
    @ObservedObject var modelMic: Mic

    var body: some View {
        HStack {
            DraggableItemPrefixView()
            Image(systemName: mic.connected ? "cable.connector" : "cable.connector.slash")
            VStack(alignment: .leading) {
                Text(mic.name)
                    .lineLimit(1)
                if !mic.connected {
                    Text(formatMicLastSeen(mic.lastSeen))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if model.database.debug.audioMixer {
                MixerEffectsMarkView(effects: mic.effects)
            }
            Image(systemName: "checkmark")
                .foregroundStyle(mic == modelMic.current ? .blue : .clear)
                .bold()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if mic.connected {
                model.manualSelectMicById(id: mic.id)
            }
        }
    }
}

private struct QuickButtonMicArchivedMicView: View {
    let model: Model
    @ObservedObject var mic: SettingsMicsMic

    var body: some View {
        HStack {
            Image(systemName: "cable.connector.slash")
            VStack(alignment: .leading) {
                Text(mic.name)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(formatMicLastSeen(mic.lastSeen))
                    ForEach(model.getMicUses(mic: mic), id: \.self) { use in
                        Text(use)
                            .font(.caption2)
                            .bold()
                            .padding(.horizontal, 4)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            .foregroundStyle(.secondary)
        }
    }
}

private func formatArchiveAfter(days: Int) -> String {
    if days == 0 {
        String(localized: "Never")
    } else {
        String(localized: "\(days) days")
    }
}

struct QuickButtonMicView: View {
    let model: Model
    @ObservedObject var mics: SettingsMics
    @ObservedObject var modelMic: Mic
    @State private var archiveExpanded = false

    var body: some View {
        let visible = mics.visibleMics(current: modelMic.current)
        let archived = mics.archivedMics(current: modelMic.current)
        Form {
            Section {
                List {
                    ForEach(visible) { mic in
                        QuickButtonMicMicView(model: model, mic: mic, modelMic: modelMic)
                            .deleteDisabled(mic == modelMic.current)
                            .contextMenuDeleteButton(disabled: mic == modelMic.current) {
                                mics.mics.removeAll { $0.id == mic.id }
                            }
                    }
                    .onDelete { offsets in
                        mics.removeMics(visible, atOffsets: offsets)
                    }
                    .onMove { froms, to in
                        mics.moveVisibleMics(visible, fromOffsets: froms, toOffset: to)
                    }
                }
                .onChange(of: mics.mics) { _ in
                    model.updateMixedMics()
                }
                if !mics.hideableMics(current: modelMic.current).isEmpty {
                    Button {
                        mics.hideAllDisconnected(current: modelMic.current)
                    } label: {
                        Label("Hide all disconnected", systemImage: "archivebox")
                    }
                }
            } footer: {
                VStack(alignment: .leading) {
                    Text("Highest priority mic at the top of the list.")
                    Text("")
                    if model.database.debug.audioMixer {
                        Text("Tap a mic to make it the main mic. Mix more sources in Audio.")
                        Text("")
                    }
                    SwipeLeftToDeleteHelpView(kind: String(localized: "a mic"))
                }
            }
            Section {
                DisclosureGroup(isExpanded: $archiveExpanded) {
                    ForEach(archived) { mic in
                        QuickButtonMicArchivedMicView(model: model, mic: mic)
                            .swipeActions(edge: .leading) {
                                Button {
                                    mics.restore(mic: mic)
                                } label: {
                                    Label("Restore", systemImage: "tray.and.arrow.up")
                                }
                                .tint(.blue)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    mics.removeMic(mic)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .contextMenu {
                                Button {
                                    mics.restore(mic: mic)
                                } label: {
                                    Label("Restore", systemImage: "tray.and.arrow.up")
                                }
                                Button(role: .destructive) {
                                    mics.removeMic(mic)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                    Picker("Archive after", selection: $mics.archiveAfterDays) {
                        ForEach(micArchiveAfterDaysChoices, id: \.self) { days in
                            Text(formatArchiveAfter(days: days))
                                .tag(days)
                        }
                    }
                } label: {
                    HStack {
                        Label("Archive", systemImage: "archivebox")
                        Spacer()
                        Text(String(archived.count))
                            .foregroundStyle(.secondary)
                    }
                }
            } footer: {
                Text("""
                Disconnected mics not seen for the archive time move here, or all at once with \
                Hide all disconnected. A mic goes back to its place in the list when it reconnects, \
                with its settings.
                """)
            }
            if model.database.debug.audioMixer {
                ShortcutSectionView {
                    NavigationLink {
                        QuickButtonMixerView(model: model, mics: mics, modelMic: modelMic)
                    } label: {
                        Label("Audio", systemImage: "slider.vertical.3")
                    }
                }
            }
            if false {
                Section {
                    Toggle("Auto switch", isOn: $mics.autoSwitch)
                } footer: {
                    Text("Automatically switch to highest priority mic when plugged in.")
                }
            }
        }
        .navigationTitle("Mic")
    }
}
