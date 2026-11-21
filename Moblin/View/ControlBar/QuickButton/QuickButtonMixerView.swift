import SwiftUI

private let mixerIconSize: CGFloat = 34

private func mixerSourceImage(mic: SettingsMicsMic) -> String {
    if mic.isScreenCapture() {
        "rectangle.on.rectangle"
    } else if mic.isMediaPlayer() {
        "play.rectangle"
    } else if mic.isNetwork() {
        "dot.radiowaves.left.and.right"
    } else {
        "mic"
    }
}

private func mixerMeterFraction(_ level: Float) -> CGFloat {
    CGFloat((level - zeroThresholdDb).clamped(to: 0 ... -zeroThresholdDb) / -zeroThresholdDb)
}

private struct MixerMeterView: View {
    @ObservedObject var level: AudioLevel
    var dimmed = false

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let green = mixerMeterFraction(min(level.level, yellowThresholdDb))
            let yellow = mixerMeterFraction(min(level.level, redThresholdDb))
            let red = mixerMeterFraction(level.level)
            HStack(spacing: 0) {
                if level.level > clippingThresholdDb {
                    Rectangle()
                        .foregroundStyle(.red)
                } else {
                    Rectangle()
                        .frame(width: green * width)
                        .foregroundStyle(.green)
                    Rectangle()
                        .frame(width: (yellow - green) * width)
                        .foregroundStyle(.yellow)
                    Rectangle()
                        .frame(width: (red - yellow) * width)
                        .foregroundStyle(.red)
                    Spacer(minLength: 0)
                }
            }
            .background(Color(UIColor.tertiarySystemFill))
        }
        .frame(height: 5)
        .opacity(dimmed ? 0.5 : 1)
    }
}

private struct MixerTagView: View {
    let text: Text

    var body: some View {
        text
            .font(.caption)
            .bold()
            .padding(.horizontal, 4)
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(.secondary)
            }
    }
}

private struct MixerMuteImageView: View {
    let muted: Bool
    let image: String
    var main = false

    var body: some View {
        Image(systemName: muted ? "speaker.slash.fill" : image)
            .frame(width: mixerIconSize, height: mixerIconSize)
            .foregroundStyle(muted ? .white : main ? Color(UIColor.systemBackground) : .primary)
            .background {
                Circle()
                    .foregroundStyle(muted ? .red : main ? .primary : Color(UIColor.tertiarySystemFill))
            }
    }
}

private struct MixerSourceHeaderView: View {
    let model: Model
    @ObservedObject var mic: SettingsMicsMic
    let main: Bool
    var expanded: Bool?

    var body: some View {
        HStack {
            MixerMuteImageView(muted: mic.muted, image: mixerSourceImage(mic: mic), main: main)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(mic.name)
                        .lineLimit(1)
                    Spacer()
                    if mic.muted {
                        Text("Muted")
                            .foregroundStyle(.red)
                    } else {
                        Text("\(formatOneDecimal(mic.gainDb)) dB")
                            .foregroundStyle(.secondary)
                    }
                    if let expanded {
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                HStack {
                    MixerMeterView(level: model.audioMixerMeters.source(id: mic.id), dimmed: mic.muted)
                    if main {
                        MixerTagView(text: Text("Main"))
                    }
                    if mic.output != .streamAndRecording {
                        MixerTagView(text: Text(mic.output.toString()))
                    }
                }
            }
        }
    }
}

private struct MixerSourceView: View {
    let model: Model
    @ObservedObject var mic: SettingsMicsMic
    let main: Bool
    let expanded: Bool
    let toggleExpanded: () -> Void
    let showSettings: () -> Void

    var body: some View {
        MixerSourceHeaderView(model: model, mic: mic, main: main, expanded: expanded)
            .contentShape(Rectangle())
            .onTapGesture {
                toggleExpanded()
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button {
                    showSettings()
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                .tint(.gray)
                Button {
                    model.setMicMuted(mic: mic, muted: !mic.muted)
                } label: {
                    if mic.muted {
                        Label("Unmute", systemImage: "speaker.wave.2")
                    } else {
                        Label("Mute", systemImage: "speaker.slash")
                    }
                }
                .tint(.red)
            }
    }
}

private struct MixerSourceGainView: View {
    let model: Model
    @ObservedObject var mic: SettingsMicsMic
    let showSettings: () -> Void

    var body: some View {
        HStack {
            Button {
                model.setMicMuted(mic: mic, muted: !mic.muted)
            } label: {
                MixerMuteImageView(muted: mic.muted, image: "speaker.wave.2.fill")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(mic.muted ? Text("Unmute") : Text("Mute"))
            Slider(value: $mic.gainDb, in: -24.0 ... 24.0, step: 1.0)
                .onChange(of: mic.gainDb) { _ in
                    model.updateAudioGain()
                }
            Button {
                showSettings()
            } label: {
                Image(systemName: "gearshape")
                    .frame(width: mixerIconSize, height: mixerIconSize)
                    .foregroundStyle(.primary)
                    .background {
                        Circle()
                            .foregroundStyle(Color(UIColor.tertiarySystemFill))
                    }
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Settings")
        }
    }
}

private struct MixerSourceDelayView: View {
    let model: Model
    @ObservedObject var mic: SettingsMicsMic

    var body: some View {
        let range = makeMicDelayRange(audioMixer: true)
        HStack {
            Text("Delay")
            Slider(
                value: Binding(get: { mic.delay.clamped(to: range) }, set: { mic.delay = $0 }),
                in: range,
                step: 0.01,
                onEditingChanged: { begin in
                    guard !begin else {
                        return
                    }
                    model.updateMicDelay()
                }
            )
            Text("\(formatThreeDecimals(mic.delay.clamped(to: range))) s")
                .frame(width: 70)
        }
    }
}

private struct MixerSyncView: View {
    let model: Model

    var body: some View {
        Form {
            AudioSyncView(model: model, audioSync: model.audioSync)
        }
        .navigationTitle("Sync mixed mics")
    }
}

private struct MixerSyncLinkView: View {
    let model: Model

    var body: some View {
        NavigationLink {
            MixerSyncView(model: model)
        } label: {
            Label("Sync mixed mics", systemImage: "waveform")
        }
    }
}

private struct MixerSourceSettingsView: View {
    let model: Model
    @ObservedObject var mic: SettingsMicsMic
    @ObservedObject var modelMic: Mic
    @Environment(\.dismiss) var dismiss

    var body: some View {
        let main = mic == modelMic.current
        Form {
            Section {
                MixerSourceHeaderView(model: model, mic: mic, main: main)
            }
            Section {
                Picker("Processing", selection: $mic.processing) {
                    ForEach(SettingsMicsMicProcessing.allCases, id: \.self) {
                        Text($0.toString())
                    }
                }
                .onChange(of: mic.processing) { _ in
                    model.updateMixedMics()
                }
            } footer: {
                Text("Voice removes rumble and evens out the level of speech.")
            }
            Section {
                HStack {
                    Text("Pan")
                    Slider(value: $mic.pan, in: -1.0 ... 1.0, step: 0.05)
                        .onChange(of: mic.pan) { _ in
                            model.updateMixedMics()
                        }
                    Text(formatPan(mic.pan))
                        .frame(width: 65)
                }
            }
            Section {
                MixerSourceDelayView(model: model, mic: mic)
                MixerSyncLinkView(model: model)
            } footer: {
                Text("A positive delay makes the audio later, a negative delay earlier.")
            }
            Section {
                Picker("Output", selection: $mic.output) {
                    ForEach(SettingsMicsMicOutput.allCases, id: \.self) {
                        Text($0.toString())
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
                .onChange(of: mic.output) { _ in
                    model.updateMixedMics()
                }
            } header: {
                Text("Output")
            }
            if !main {
                Section {
                    Button(role: .destructive) {
                        model.setMicMixed(mic: mic, mixed: false)
                        dismiss()
                    } label: {
                        HCenter {
                            Text("Remove from mix")
                        }
                    }
                }
            }
        }
        .navigationTitle(mic.name)
    }
}

private struct MixerAddSourceButtonView: View {
    let model: Model
    @ObservedObject var mic: SettingsMicsMic
    let current: SettingsMicsMic

    var body: some View {
        if mic.connected, !mic.mixed, isAudioMicMixable(mic: mic, current: current) {
            Button(mic.name) {
                model.setMicMixed(mic: mic, mixed: true)
            }
        }
    }
}

private struct MixerAddSourceView: View {
    let model: Model
    @ObservedObject var mics: SettingsMics
    let current: SettingsMicsMic

    var body: some View {
        Menu {
            ForEach(mics.mics) { mic in
                MixerAddSourceButtonView(model: model, mic: mic, current: current)
            }
        } label: {
            Label("Add source", systemImage: "plus")
        }
    }
}

private struct MixerOutputView: View {
    let meters: AudioMixerMeters
    @ObservedObject var audio: SettingsAudio
    @ObservedObject var limiter: AudioMixerLimiter
    let expanded: Bool
    let toggleExpanded: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Output gain")
                if limiter.reduction > 0 {
                    HStack(spacing: 3) {
                        Text("Limiter")
                        Text("\(formatOneDecimal(-limiter.reduction)) dB")
                    }
                    .font(.caption)
                    .bold()
                    .foregroundStyle(.orange)
                }
                Spacer()
                Text("\(formatOneDecimal(audio.gainDb)) dB")
                    .foregroundStyle(.secondary)
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            MixerMeterView(level: meters.left)
            MixerMeterView(level: meters.right)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            toggleExpanded()
        }
    }
}

private struct MixerOutputGainView: View {
    let model: Model
    @ObservedObject var audio: SettingsAudio

    var body: some View {
        Slider(value: $audio.gainDb, in: 0.0 ... 24.0, step: 1.0)
            .onChange(of: audio.gainDb) { _ in
                model.updateAudioGain()
            }
    }
}

struct QuickButtonMixerView: View {
    let model: Model
    @ObservedObject var mics: SettingsMics
    @ObservedObject var modelMic: Mic
    @State private var expandedId: String?
    @State private var outputExpanded = false
    @State private var settingsMic: SettingsMicsMic?
    @State private var presentingSettings = false

    private func toggleExpanded(id: String) {
        expandedId = expandedId == id ? nil : id
    }

    private func showSettings(mic: SettingsMicsMic) {
        settingsMic = mic
        presentingSettings = true
    }

    var body: some View {
        let current = model.getMicById(id: modelMic.current.id) ?? modelMic.current
        Form {
            Section {
                ForEach([current] + modelMic.mixed) { mic in
                    MixerSourceView(model: model,
                                    mic: mic,
                                    main: mic == current,
                                    expanded: expandedId == mic.id,
                                    toggleExpanded: { toggleExpanded(id: mic.id) },
                                    showSettings: { showSettings(mic: mic) })
                    if expandedId == mic.id {
                        MixerSourceGainView(model: model, mic: mic) {
                            showSettings(mic: mic)
                        }
                    }
                }
                MixerAddSourceView(model: model, mics: mics, current: current)
                MixerSyncLinkView(model: model)
            } footer: {
                Text("Tap for gain. Swipe for mute or settings.")
            }
            Section {
                MixerOutputView(meters: model.audioMixerMeters,
                                audio: model.database.audio,
                                limiter: model.audioMixerMeters.limiter,
                                expanded: outputExpanded)
                {
                    outputExpanded.toggle()
                }
                if outputExpanded {
                    MixerOutputGainView(model: model, audio: model.database.audio)
                }
            }
        }
        .navigationTitle("Mixer")
        .navigationDestination(isPresented: $presentingSettings) {
            if let settingsMic {
                MixerSourceSettingsView(model: model, mic: settingsMic, modelMic: modelMic)
            }
        }
    }
}
