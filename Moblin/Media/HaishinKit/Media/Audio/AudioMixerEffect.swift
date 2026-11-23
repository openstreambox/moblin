import AudioToolbox
import CoreAudio

private func renderAudioMixerEffectInput(
    _ refCon: UnsafeMutableRawPointer,
    _: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
    _: UnsafePointer<AudioTimeStamp>,
    _: UInt32,
    _ frameCount: UInt32,
    _ data: UnsafeMutablePointer<AudioBufferList>?
) -> OSStatus {
    guard let data else {
        return kAudio_ParamError
    }
    let effect = Unmanaged<AudioMixerEffectUnit>.fromOpaque(refCon).takeUnretainedValue()
    effect.provideInput(UnsafeMutableAudioBufferListPointer(data), frameCount)
    return noErr
}

protocol AudioMixerEffectStage: AnyObject {
    var latency: Int64 { get }
    func reset()
    func process(_ left: UnsafeMutablePointer<Float>, _ right: UnsafeMutablePointer<Float>) -> Bool
}

final class AudioMixerEffectChain {
    private final class Stages: @unchecked Sendable {
        let values: [any AudioMixerEffectStage]

        init(_ values: [any AudioMixerEffectStage]) {
            self.values = values
        }
    }

    let latency: Int64
    private let stages: Unmanaged<Stages>?
    private let retirement: AudioMixerReport?

    init(_ stages: [any AudioMixerEffectStage]) {
        latency = stages.reduce(0) { $0 + $1.latency }
        if stages.isEmpty {
            self.stages = nil
            retirement = nil
        } else {
            let storage = Stages(stages)
            self.stages = .passUnretained(storage)
            retirement = AudioMixerReport(retaining: storage)
        }
    }

    var isEmpty: Bool {
        stages == nil
    }

    func reset() {
        for stage in stages?.takeUnretainedValue().values ?? [] {
            stage.reset()
        }
    }

    @discardableResult
    func process(_ left: UnsafeMutablePointer<Float>, _ right: UnsafeMutablePointer<Float>) -> Bool {
        for stage in stages?.takeUnretainedValue().values ?? [] {
            guard stage.process(left, right) else {
                return false
            }
        }
        return true
    }
}

struct AudioMixerEqualizer: Equatable {
    var frequency: Float = 1000
    var gain: Float = 0
    var bandwidth: Float = 1
}

struct AudioMixerCompressor: Equatable {
    var threshold: Float = -24
    var headroom: Float = 6
    var attack: Float = 0.003
    var release: Float = 0.12
    var makeupGain: Float = 0
}

struct AudioMixerExpander: Equatable {
    var threshold: Float = -40
    var ratio: Float = 4
    var attack: Float = 0.003
    var release: Float = 0.12
}

struct AudioMixerDeEsserSettings: Equatable {
    var frequency: Float = 6000
    var bandwidth: Float = 1
    var threshold: Float = -24
    var maximumReduction: Float = 9
}

enum AudioMixerEffectSettings: Equatable {
    case equalizer(AudioMixerEqualizer)
    case compressor(AudioMixerCompressor)
    case expander(AudioMixerExpander)
    case deEsser(AudioMixerDeEsserSettings)

    var canUseOnMaster: Bool {
        switch self {
        case .equalizer, .deEsser:
            true
        case .compressor, .expander:
            false
        }
    }

    func makeStage() -> (any AudioMixerEffectStage)? {
        switch self {
        case let .equalizer(settings):
            makeAudioMixerEqualizer(frequency: settings.frequency.clamped(to: 20 ... 20000),
                                    bandwidth: settings.bandwidth,
                                    gain: settings.gain.clamped(to: -24 ... 24),
                                    filterType: kAUNBandEQFilterType_Parametric)
        case let .compressor(settings):
            makeAudioMixerDynamics(threshold: settings.threshold,
                                   headroom: settings.headroom,
                                   expansionThreshold: -60,
                                   expansionRatio: 1,
                                   attack: settings.attack,
                                   release: settings.release,
                                   makeupGain: settings.makeupGain)
        case let .expander(settings):
            makeAudioMixerDynamics(threshold: 0,
                                   headroom: 40,
                                   expansionThreshold: settings.threshold,
                                   expansionRatio: settings.ratio,
                                   attack: settings.attack,
                                   release: settings.release,
                                   makeupGain: 0)
        case let .deEsser(settings):
            AudioMixerDeEsser(settings)
        }
    }
}

private func makeAudioMixerEqualizer(frequency: Float,
                                     bandwidth: Float,
                                     gain: Float,
                                     filterType: Int) -> AudioMixerEffect?
{
    AudioMixerEffect(subType: kAudioUnitSubType_NBandEQ, parameters: [
        kAUNBandEQParam_FilterType: Float(filterType),
        kAUNBandEQParam_Frequency: frequency,
        kAUNBandEQParam_Gain: gain,
        kAUNBandEQParam_Bandwidth: bandwidth.clamped(to: 0.05 ... 5),
        kAUNBandEQParam_BypassBand: 0,
    ], numberOfBands: 1, bypassOnFailure: true)
}

private func makeAudioMixerDynamics(threshold: Float,
                                    headroom: Float,
                                    expansionThreshold: Float,
                                    expansionRatio: Float,
                                    attack: Float,
                                    release: Float,
                                    makeupGain: Float) -> AudioMixerEffect?
{
    AudioMixerEffect(subType: kAudioUnitSubType_DynamicsProcessor, parameters: [
        kDynamicsProcessorParam_Threshold: threshold.clamped(to: -40 ... 20),
        kDynamicsProcessorParam_HeadRoom: headroom.clamped(to: 0.1 ... 40),
        kDynamicsProcessorParam_ExpansionThreshold: expansionThreshold.clamped(to: -80 ... 0),
        kDynamicsProcessorParam_ExpansionRatio: expansionRatio.clamped(to: 1 ... 50),
        kDynamicsProcessorParam_AttackTime: attack.clamped(to: 0.0001 ... 0.2),
        kDynamicsProcessorParam_ReleaseTime: release.clamped(to: 0.01 ... 3),
        kDynamicsProcessorParam_OverallGain: makeupGain.clamped(to: -40 ... 40),
    ], bypassOnFailure: true)
}

final class AudioMixerEffectBuffer {
    let left = makeAudioMixerSamples(count: audioMixerFramesPerBlock)
    let right = makeAudioMixerSamples(count: audioMixerFramesPerBlock)

    deinit {
        left.deallocate()
        right.deallocate()
    }

    func copy(_ left: UnsafePointer<Float>, _ right: UnsafePointer<Float>) {
        self.left.update(from: left, count: audioMixerFramesPerBlock)
        self.right.update(from: right, count: audioMixerFramesPerBlock)
    }

    func crossfade(into left: UnsafeMutablePointer<Float>, _ right: UnsafeMutablePointer<Float>?) {
        crossfade(self.left, into: left)
        if let right {
            crossfade(self.right, into: right)
        }
    }

    private func crossfade(_ next: UnsafePointer<Float>, into current: UnsafeMutablePointer<Float>) {
        for index in 0 ..< audioMixerFramesPerBlock {
            let weight = Float(index) / Float(audioMixerFramesPerBlock - 1)
            current[index] += (next[index] - current[index]) * weight
        }
    }
}

private final class AudioMixerDeEsser: AudioMixerEffectStage {
    let latency: Int64 = 0
    private let notch: AudioMixerEffect
    private let filtered = AudioMixerEffectBuffer()
    private let threshold: Float
    private let maximumCut: Float
    private let attack = Float(exp(-1 / (0.00015 * audioMixerSampleRate)))
    private let release = Float(exp(-1 / (0.035 * audioMixerSampleRate)))
    private var envelope: Float = 0

    init?(_ settings: AudioMixerDeEsserSettings) {
        guard let notch = makeAudioMixerEqualizer(frequency: settings.frequency.clamped(to: 2000 ... 15000),
                                                  bandwidth: settings.bandwidth,
                                                  gain: 0,
                                                  filterType: kAUNBandEQFilterType_BandStop),
            notch.latency == 0
        else {
            return nil
        }
        self.notch = notch
        threshold = pow(10, settings.threshold.clamped(to: -60 ... 0) / 20)
        maximumCut = 1 - pow(10, -settings.maximumReduction.clamped(to: 0 ... 24) / 20)
    }

    func reset() {
        envelope = 0
        notch.reset()
    }

    func process(_ left: UnsafeMutablePointer<Float>, _ right: UnsafeMutablePointer<Float>) -> Bool {
        filtered.copy(left, right)
        notch.process(filtered.left, filtered.right)
        var envelope = envelope
        for index in 0 ..< audioMixerFramesPerBlock {
            let bandLeft = left[index] - filtered.left[index]
            let bandRight = right[index] - filtered.right[index]
            let peak = max(abs(bandLeft), abs(bandRight))
            let smoothing = peak > envelope ? attack : release
            envelope = peak + smoothing * (envelope - peak)
            if envelope > threshold {
                let cut = min(maximumCut, 1 - threshold / envelope)
                left[index] -= bandLeft * cut
                right[index] -= bandRight * cut
            }
        }
        self.envelope = envelope < 1e-12 ? 0 : envelope
        return true
    }
}

private final class AudioMixerEffectDelay {
    private let count: Int
    private let left: UnsafeMutablePointer<Float>
    private let right: UnsafeMutablePointer<Float>
    private let scratch: UnsafeMutablePointer<Float>

    init(count: Int) {
        self.count = count
        left = makeAudioMixerSamples(count: count)
        right = makeAudioMixerSamples(count: count)
        scratch = makeAudioMixerSamples(count: count)
    }

    deinit {
        left.deallocate()
        right.deallocate()
        scratch.deallocate()
    }

    func reset() {
        left.update(repeating: 0, count: count)
        right.update(repeating: 0, count: count)
    }

    func update(_ left: UnsafeMutablePointer<Float>, _ right: UnsafeMutablePointer<Float>, delay: Bool) {
        update(left, history: self.left, delay: delay)
        update(right, history: self.right, delay: delay)
    }

    private func update(_ samples: UnsafeMutablePointer<Float>,
                        history: UnsafeMutablePointer<Float>,
                        delay: Bool)
    {
        let remaining = audioMixerFramesPerBlock - count
        if delay {
            scratch.update(from: samples + remaining, count: count)
            memmove(samples + count, samples, remaining * MemoryLayout<Float>.size)
            samples.update(from: history, count: count)
            history.update(from: scratch, count: count)
        } else {
            history.update(from: samples + remaining, count: count)
        }
    }
}

private final class AudioMixerEffectUnit: @unchecked Sendable {
    let audioUnit: AudioComponentInstance
    var left: UnsafeMutablePointer<Float>?
    var right: UnsafeMutablePointer<Float>?

    init(_ audioUnit: AudioComponentInstance) {
        self.audioUnit = audioUnit
    }

    deinit {
        AudioUnitUninitialize(audioUnit)
        AudioComponentInstanceDispose(audioUnit)
    }

    func provideInput(_ data: UnsafeMutableAudioBufferListPointer, _ frameCount: UInt32) {
        let byteSize = frameCount * UInt32(MemoryLayout<Float>.size)
        for channel in 0 ..< data.count {
            data[channel].mData = UnsafeMutableRawPointer(channel == 0 ? left : right)
            data[channel].mDataByteSize = byteSize
        }
    }
}

final class AudioMixerEffect: AudioMixerEffectStage {
    private(set) var latency: Int64 = 0
    private let storage: Unmanaged<AudioMixerEffectUnit>
    private let diagnostics: AudioMixerReport
    private let output: UnsafeMutableAudioBufferListPointer
    private let outputLeft: UnsafeMutablePointer<Float>
    private let outputRight: UnsafeMutablePointer<Float>
    private let dryInput: AudioMixerEffectBuffer?
    private var timeStamp = AudioTimeStamp()
    private var renderStatus = noErr
    private let bypassOnFailure: Bool
    private var bypassed = false
    private var dryDelay: AudioMixerEffectDelay?
    private var lastWet: (left: Float, right: Float)?

    private var unit: AudioMixerEffectUnit {
        storage.takeUnretainedValue()
    }

    var audioUnit: AudioComponentInstance {
        unit.audioUnit
    }

    init?(subType: OSType,
          parameters: [AudioUnitParameterID: AudioUnitParameterValue] = [:],
          numberOfBands: UInt32? = nil,
          bypassOnFailure: Bool = false)
    {
        var description = AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: subType,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )
        var audioUnit: AudioComponentInstance?
        guard let component = AudioComponentFindNext(nil, &description),
              AudioComponentInstanceNew(component, &audioUnit) == noErr,
              let audioUnit
        else {
            logger.info("audio-mixer: Effect \(subType) not found")
            return nil
        }
        let unit = AudioMixerEffectUnit(audioUnit)
        storage = .passUnretained(unit)
        diagnostics = AudioMixerReport(retaining: unit) { status in
            logger.info("audio-mixer: Effect \(subType) render status \(status)")
        }
        self.bypassOnFailure = bypassOnFailure
        dryInput = bypassOnFailure ? AudioMixerEffectBuffer() : nil
        output = AudioBufferList.allocate(maximumBuffers: 2)
        outputLeft = makeAudioMixerSamples(count: audioMixerFramesPerBlock)
        outputRight = makeAudioMixerSamples(count: audioMixerFramesPerBlock)
        timeStamp.mFlags = .sampleTimeValid
        guard initialize(parameters, numberOfBands: numberOfBands) else {
            logger.info("audio-mixer: Failed to initialize effect \(subType)")
            return nil
        }
        if bypassOnFailure, latency > 0 {
            guard latency <= audioMixerFramesPerBlock else {
                logger
                    .info(
                        "audio-mixer: Effect \(subType) requires \(latency) frames of lookahead and was dropped"
                    )
                return nil
            }
            dryDelay = AudioMixerEffectDelay(count: Int(latency))
        }
    }

    deinit {
        free(output.unsafeMutablePointer)
        outputLeft.deallocate()
        outputRight.deallocate()
    }

    func reset() {
        bypassed = false
        lastWet = nil
        dryDelay?.reset()
        resetUnit()
    }

    private func resetUnit() {
        AudioUnitReset(audioUnit, kAudioUnitScope_Global, 0)
    }

    @discardableResult
    func process(_ left: UnsafeMutablePointer<Float>, _ right: UnsafeMutablePointer<Float>) -> Bool {
        guard !bypassed else {
            dryDelay?.update(left, right, delay: true)
            return true
        }
        let unit = unit
        if let dryInput {
            dryInput.copy(left, right)
            unit.left = dryInput.left
            unit.right = dryInput.right
        } else {
            unit.left = left
            unit.right = right
        }
        let byteSize = UInt32(audioMixerFramesPerBlock * MemoryLayout<Float>.size)
        output[0] = AudioBuffer(mNumberChannels: 1, mDataByteSize: byteSize, mData: outputLeft)
        output[1] = AudioBuffer(mNumberChannels: 1, mDataByteSize: byteSize, mData: outputRight)
        var flags = AudioUnitRenderActionFlags()
        let status = AudioUnitRender(
            audioUnit,
            &flags,
            &timeStamp,
            0,
            UInt32(audioMixerFramesPerBlock),
            output.unsafeMutablePointer
        )
        unit.left = nil
        unit.right = nil
        timeStamp.mSampleTime += Float64(audioMixerFramesPerBlock)
        if status != renderStatus {
            diagnostics.record(Int(status))
            renderStatus = status
        }
        guard status == noErr else {
            if bypassOnFailure {
                bypassed = true
                dryDelay?.update(left, right, delay: true)
                if let lastWet {
                    fadeToDry(left, lastWet.left)
                    fadeToDry(right, lastWet.right)
                }
                return true
            }
            left.update(repeating: 0, count: audioMixerFramesPerBlock)
            right.update(repeating: 0, count: audioMixerFramesPerBlock)
            resetUnit()
            return false
        }
        dryDelay?.update(left, right, delay: false)
        copyOutput(0, left)
        copyOutput(1, right)
        lastWet = (left[audioMixerFramesPerBlock - 1], right[audioMixerFramesPerBlock - 1])
        return true
    }

    private func fadeToDry(_ samples: UnsafeMutablePointer<Float>, _ previous: Float) {
        for index in 0 ..< audioMixerFadeFrames {
            let weight = Float(index) / Float(audioMixerFadeFrames - 1)
            samples[index] = previous + (samples[index] - previous) * weight
        }
    }

    private func copyOutput(_ channel: Int, _ samples: UnsafeMutablePointer<Float>) {
        if let data = output[channel].mData {
            samples.update(from: data.assumingMemoryBound(to: Float.self), count: audioMixerFramesPerBlock)
        }
    }

    private func initialize(_ parameters: [AudioUnitParameterID: AudioUnitParameterValue],
                            numberOfBands: UInt32?) -> Bool
    {
        var format = AudioStreamBasicDescription(
            mSampleRate: audioMixerSampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagsNativeFloatPacked | kAudioFormatFlagIsNonInterleaved,
            mBytesPerPacket: 4,
            mFramesPerPacket: 1,
            mBytesPerFrame: 4,
            mChannelsPerFrame: 2,
            mBitsPerChannel: 32,
            mReserved: 0
        )
        let formatSize = MemoryLayout<AudioStreamBasicDescription>.size
        var maximumFrames = UInt32(audioMixerFramesPerBlock)
        var callback = AURenderCallbackStruct(
            inputProc: renderAudioMixerEffectInput,
            inputProcRefCon: Unmanaged.passUnretained(unit).toOpaque()
        )
        var latency: Float64 = 0
        var latencySize = UInt32(MemoryLayout<Float64>.size)
        guard setProperty(kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, &format, formatSize),
              setProperty(kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, &format, formatSize),
              setProperty(kAudioUnitProperty_MaximumFramesPerSlice,
                          kAudioUnitScope_Global,
                          &maximumFrames,
                          MemoryLayout<UInt32>.size),
              setProperty(kAudioUnitProperty_SetRenderCallback,
                          kAudioUnitScope_Input,
                          &callback,
                          MemoryLayout<AURenderCallbackStruct>.size)
        else {
            return false
        }
        if var numberOfBands,
           !setProperty(kAUNBandEQProperty_NumberOfBands,
                        kAudioUnitScope_Global,
                        &numberOfBands,
                        MemoryLayout<UInt32>.size)
        {
            return false
        }
        guard AudioUnitInitialize(audioUnit) == noErr else {
            return false
        }
        for (id, value) in parameters {
            guard AudioUnitSetParameter(audioUnit, id, kAudioUnitScope_Global, 0, value, 0) == noErr else {
                return false
            }
        }
        guard AudioUnitGetProperty(audioUnit,
                                   kAudioUnitProperty_Latency,
                                   kAudioUnitScope_Global,
                                   0,
                                   &latency,
                                   &latencySize) == noErr
        else {
            return false
        }
        let frames = (latency * audioMixerSampleRate).rounded()
        guard frames.isFinite, frames >= 0, frames <= Double(Int32.max) else {
            return false
        }
        self.latency = Int64(frames)
        return true
    }

    private func setProperty(_ property: AudioUnitPropertyID,
                             _ scope: AudioUnitScope,
                             _ value: UnsafeRawPointer,
                             _ size: Int) -> Bool
    {
        AudioUnitSetProperty(audioUnit, property, scope, 0, value, UInt32(size)) == noErr
    }
}

func makeAudioMixerVoiceEffects() -> [AudioMixerEffect] {
    let highPass = AudioMixerEffect(subType: kAudioUnitSubType_HighPassFilter, parameters: [
        kHipassParam_CutoffFrequency: 90,
    ], bypassOnFailure: true)
    let dynamics = AudioMixerEffect(subType: kAudioUnitSubType_DynamicsProcessor, parameters: [
        kDynamicsProcessorParam_Threshold: -24,
        kDynamicsProcessorParam_HeadRoom: 6,
        kDynamicsProcessorParam_ExpansionThreshold: -50,
        kDynamicsProcessorParam_ExpansionRatio: 2,
        kDynamicsProcessorParam_AttackTime: 0.003,
        kDynamicsProcessorParam_ReleaseTime: 0.12,
        kDynamicsProcessorParam_OverallGain: 0,
    ], bypassOnFailure: true)
    guard let highPass, let dynamics else {
        return []
    }
    return [highPass, dynamics]
}
