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

private struct MixerSourceView: View {
    let model: Model
    @ObservedObject var mic: SettingsMicsMic
    let main: Bool
    let expanded: Bool
    let toggleExpanded: () -> Void

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
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
        .contentShape(Rectangle())
        .onTapGesture {
            toggleExpanded()
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
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
        }
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

    private func toggleExpanded(id: String) {
        expandedId = expandedId == id ? nil : id
    }

    var body: some View {
        let current = model.getMicById(id: modelMic.current.id) ?? modelMic.current
        Form {
            Section {
                ForEach([current] + modelMic.mixed) { mic in
                    MixerSourceView(model: model,
                                    mic: mic,
                                    main: mic == current,
                                    expanded: expandedId == mic.id)
                    {
                        toggleExpanded(id: mic.id)
                    }
                    if expandedId == mic.id {
                        MixerSourceGainView(model: model, mic: mic)
                    }
                }
                MixerAddSourceView(model: model, mics: mics, current: current)
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
    }
}
