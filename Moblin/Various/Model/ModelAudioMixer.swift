import Foundation
import SwiftUI

func isAudioMicMixable(mic: SettingsMicsMic, current: SettingsMicsMic) -> Bool {
    guard mic != current else {
        return false
    }
    guard mic.isAudioSession() else {
        return true
    }
    return mic.channel != nil && current.channel != nil && mic.inputUid == current.inputUid
}

func makeAudioChannelMicNames(portName: String, channelNames: [String?]) -> [String] {
    let names = channelNames.enumerated().map { channel, channelName in
        guard let channelName, !channelName.isEmpty, channelName != portName else {
            return "\(portName) \(channel + 1)"
        }
        if channelName.hasPrefix(portName) {
            return channelName
        }
        return "\(portName): \(channelName)"
    }
    guard Set(names).count == names.count else {
        return channelNames.indices.map { "\(portName) \($0 + 1)" }
    }
    return names
}

func makeAudioMixerMixedMics(mics: [SettingsMicsMic], current: SettingsMicsMic) -> [SettingsMicsMic] {
    mics.filter { $0.mixed && $0.connected && isAudioMicMixable(mic: $0, current: current) }
}

func isAudioMicSwitchNeeded(current: SettingsMicsMic?,
                            highestPriority: SettingsMicsMic,
                            mixed: [SettingsMicsMic]) -> Bool
{
    guard let current else {
        return true
    }
    if mixed.contains(highestPriority) {
        return false
    }
    return !(current.channel != nil
        && highestPriority.channel == nil
        && current.inputUid == highestPriority.inputUid)
}

func isAudioChannelMicConnected(mic: SettingsMicsMic,
                                found: [SettingsMicsMic],
                                inputUid: String?,
                                numberOfChannels: Int) -> Bool
{
    guard let channel = mic.channel, found.contains(where: { $0.inputUid == mic.inputUid }) else {
        return false
    }
    return mic.inputUid != inputUid || channel < numberOfChannels
}

let audioMixerAppAudioGainDb: Float = -10

func makeMixedMicGainDb(mic: SettingsMicsMic) -> Float {
    if mic.isScreenCapture(), mic.gainDb == 0 {
        audioMixerAppAudioGainDb
    } else {
        mic.gainDb
    }
}

func makeMicDelayRange(audioMixer: Bool) -> ClosedRange<Double> {
    audioMixer ? -0.5 ... 2.0 : -0.5 ... 0.5
}

func makeAudioMixerSourceGain(mic: SettingsMicsMic) -> Float {
    mic.muted ? 0 : pow(10, mic.gainDb / 20)
}

private func makeAudioMixerSends(output: SettingsMicsMicOutput) -> (stream: Float, recording: Float) {
    switch output {
    case .streamAndRecording:
        (1, 1)
    case .stream:
        (1, 0)
    case .recording:
        (0, 1)
    }
}

@MainActor
class AudioMixerLimiter: ObservableObject {
    @Published var reduction: Float = 0
}

@MainActor
class AudioMixerMeters {
    let left = AudioLevel()
    let right = AudioLevel()
    let limiter = AudioMixerLimiter()
    private var sources: [String: AudioLevel] = [:]

    func source(id: String) -> AudioLevel {
        if let level = sources[id] {
            return level
        }
        let level = AudioLevel()
        sources[id] = level
        return level
    }

    func update(levels: AudioMixerLevels) {
        for (id, level) in sources {
            setLevel(level, peak: levels.sources[id] ?? 0)
        }
        for (id, peak) in levels.sources where sources[id] == nil {
            setLevel(source(id: id), peak: peak)
        }
        setLevel(left, peak: levels.left)
        setLevel(right, peak: levels.right)
    }

    private func setLevel(_ level: AudioLevel, peak: Float) {
        let newLevel = peak > 0 ? 20 * log10(peak) : defaultAudioLevel
        if level.level != newLevel {
            level.level = newLevel
        }
    }
}

extension Model {
    func updateAudioMixer() {
        setAudioChannelsMap(channelsMap: makeAudioEncoderChannelsMap())
        updateAudioGain()
        updateMicDelay()
        if !database.debug.audioMixer {
            media.setMixedAudio(sources: nil, stereo: false)
            mic.mixed = []
            if mic.current.channel != nil,
               let deviceMic = database.mics.mics.first(where: {
                   $0.inputUid == mic.current.inputUid && $0.channel == nil
               })
            {
                manualSelectMicById(id: deviceMic.id)
            }
        }
    }

    func setMicMixed(mic: SettingsMicsMic, mixed: Bool) {
        if mixed {
            mic.gainDb = makeMixedMicGainDb(mic: mic)
        }
        mic.mixed = mixed
        updateMixedMics()
    }

    func updateStereoMix() {
        updateMixedMics()
        if isRecorderRecording {
            stopRecorderIfNeeded(forceStop: true)
            startRecorderIfNeeded()
        }
    }

    func setMicMuted(mic: SettingsMicsMic, muted: Bool) {
        mic.muted = muted
        updateMixedMics()
    }

    func updateMixedMics() {
        guard database.debug.audioMixer else {
            return
        }
        let current = getMicById(id: mic.current.id) ?? mic.current
        var mixedMics: [SettingsMicsMic] = []
        if !isChatPhone() {
            mixedMics = makeAudioMixerMixedMics(mics: database.mics.mics, current: current)
        }
        if mixedMics != mic.mixed {
            mic.mixed = mixedMics
        }
        let sources = ([current] + mixedMics).compactMap { makeAudioMixerSourceSettings(mic: $0) }
        media.setMixedAudio(sources: sources, stereo: database.audio.stereoMix)
    }

    private func makeAudioMixerSourceSettings(mic: SettingsMicsMic) -> AudioMixerSourceSettings? {
        let bufferedAudio = getMicCameraId(mic: mic)
        guard bufferedAudio != nil || mic.isAudioSession() else {
            return nil
        }
        return AudioMixerSourceSettings(id: mic.id,
                                        bufferedAudio: bufferedAudio,
                                        channelsMap: makeAudioInputChannelsMap(),
                                        channel: mic.channel,
                                        gain: makeAudioMixerSourceGain(mic: mic),
                                        delay: mic.delay.clamped(to: makeMicDelayRange(audioMixer: true)),
                                        voice: mic.processing == .voice,
                                        sends: makeAudioMixerSends(output: mic.output),
                                        pan: mic.pan)
    }

    private func makeAudioEncoderChannelsMap() -> [Int: Int] {
        if database.debug.audioMixer {
            [0: 0, 1: 1]
        } else {
            makeAudioInputChannelsMap()
        }
    }

    private func makeAudioInputChannelsMap() -> [Int: Int] {
        [
            0: database.audio.outputToInputChannelsMap.channel1,
            1: database.audio.outputToInputChannelsMap.channel2,
        ]
    }
}
