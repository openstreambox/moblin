import Accelerate
import AVFoundation

let audioMixerFramesPerBlock = 1024
private let minimumLatency: Int64 = 2400

enum AudioMixerCaptureError: Error {
    case missing
    case notReady
    case discontinuity
}

struct AudioMixerSourceSettings {
    let id: String
    let bufferedAudio: UUID?
    let channelsMap: [Int: Int]
    let channel: Int?
    let gain: Float
    let delay: Double
    let voice: Bool
    let sends: (stream: Float, recording: Float)
    var pan: Float = 0
    var effects: [AudioMixerEffectSettings] = []

    func hasSameInput(as other: Self) -> Bool {
        id == other.id && bufferedAudio == other.bufferedAudio && channelsMap == other.channelsMap
            && channel == other.channel && voice == other.voice
    }
}

func makeAudioMixerPanGains(pan: Float) -> (left: Float, right: Float) {
    guard pan != 0 else {
        return (1, 1)
    }
    let angle = (pan.clamped(to: -1 ... 1) + 1) * .pi / 4
    let scale = Float(2).squareRoot()
    return (scale * cos(angle), scale * sin(angle))
}

final class AudioMixerSource {
    let id: String
    let bufferedAudio: UUID?
    private(set) var delay: Int64 = 0
    private(set) var isRemoved = false
    private let startIndex: Int64
    private let channelsMap: [Int: Int]
    private let channel: Int?
    let voice: AudioMixerEffectChain
    private var effects: AudioMixerEffectChain
    private var pendingEffects: AudioMixerEffectChain?
    private let effectTransition = AudioMixerEffectBuffer()
    private let effectHistory: AudioMixerEffectBuffer?
    private let diagnostics: AudioMixerReport
    private var gain: Float = 0
    private var currentGain: Float = 0
    private var pan: (left: Float, right: Float) = (1, 1)
    private var currentPan: (left: Float, right: Float) = (1, 1)
    private var sends: (stream: Float, recording: Float) = (0, 0)
    private var currentSends: (stream: Float, recording: Float) = (0, 0)
    private var currentDelay: Int64 = 0
    private var numberOfInputChannels = -1
    private var leftChannel = -1
    private var rightChannel = -1
    private var isStereoMix = true
    private var isSilent = true
    private let left = makeAudioMixerSamples(count: audioMixerFramesPerBlock)
    private let right = makeAudioMixerSamples(count: audioMixerFramesPerBlock)
    private let previousLeft = makeAudioMixerSamples(count: audioMixerFadeFrames)
    private let previousRight = makeAudioMixerSamples(count: audioMixerFadeFrames)

    init(_ prepared: AudioMixerPreparedSource, startIndex: Int64) {
        let settings = prepared.settings
        id = settings.id
        bufferedAudio = settings.bufferedAudio
        self.startIndex = startIndex
        channelsMap = settings.channelsMap
        channel = settings.channel
        voice = prepared.voice
        effectHistory = prepared.voice.isEmpty ? nil : AudioMixerEffectBuffer()
        effects = prepared.effects
        diagnostics = AudioMixerReport { [id = settings.id] reason in
            logger.debug("audio-mixer: Source \(id) \(reason == 0 ? "input overwritten" : "stalled")")
        }
        update(prepared)
        currentDelay = delay
        currentSends = sends
        currentPan = pan
    }

    deinit {
        left.deallocate()
        right.deallocate()
        previousLeft.deallocate()
        previousRight.deallocate()
    }

    private var isStereo: Bool {
        leftChannel != rightChannel
    }

    var hasDifferentSends: Bool {
        sends.stream != sends.recording || currentSends.stream != currentSends.recording
    }

    var effectsLatency: Int64 {
        voice.latency + max(effects.latency, pendingEffects?.latency ?? 0)
    }

    func update(_ prepared: AudioMixerPreparedSource) {
        let settings = prepared.settings
        gain = settings.gain
        delay = Int64((settings.delay * audioMixerSampleRate).rounded())
        sends = settings.sends
        pan = makeAudioMixerPanGains(pan: settings.pan)
        pendingEffects = effects === prepared.effects ? nil : prepared.effects
    }

    func remove() {
        isRemoved = true
    }

    func reset() {
        isSilent = true
    }

    func render(_ input: AudioMixerInput,
                _ blockStart: Int64,
                _ streamBus: AudioMixerBus,
                _ recordingBus: AudioMixerBus?)
    {
        let startGain = currentGain
        let startSends = currentSends
        let startPan = currentPan
        let previousDelay = currentDelay
        if streamBus.isStereo != isStereoMix {
            isStereoMix = streamBus.isStereo
            numberOfInputChannels = -1
        }
        currentGain = isRemoved ? 0 : gain
        currentSends = sends
        currentPan = isStereoMix ? pan : (1, 1)
        guard startGain != 0 || currentGain != 0 else {
            isSilent = true
            return
        }
        if input.numberOfChannels != numberOfInputChannels {
            configure(input.numberOfChannels)
        }
        let lookahead = requiredFrames(effects)
        var delay = delay
        if !isSilent, input.writeIndex - (blockStart - delay) < Int64(lookahead) {
            delay = previousDelay
        }
        currentDelay = delay
        let index = blockStart - delay
        let end = Int(min(max(input.writeIndex - index, 0), Int64(lookahead)))
        let isOverwritten = index < input.oldestIndex
        if isOverwritten, !isSilent {
            diagnostics.record(0)
            isSilent = true
        }
        if isSilent {
            if let pendingEffects, input.writeIndex - index >= Int64(requiredFrames(pendingEffects)) {
                activateEffects(pendingEffects)
            }
            guard input.writeIndex - index >= Int64(requiredFrames(effects)),
                  !isOverwritten, index >= startIndex, start(input, index)
            else {
                return
            }
            if startGain != 0 {
                fadeIn()
            }
            isSilent = false
        } else {
            let latency = voice.latency + effects.latency
            read(input, index + latency, audioMixerFramesPerBlock, left, right)
            if previousDelay != delay {
                seek(input, blockStart - previousDelay + latency)
            }
            let canTransition = end >= lookahead && previousDelay == delay
            processEffects(input, index, canTransition: canTransition)
            if end < lookahead {
                diagnostics.record(1)
                fadeOut(min(end, audioMixerFramesPerBlock))
                isSilent = true
            }
        }
        send(to: streamBus, startPan, startGain * startSends.stream, currentGain * sends.stream)
        if let recordingBus {
            send(to: recordingBus, startPan, startGain * startSends.recording, currentGain * sends.recording)
        }
    }

    func captureChannel(_ input: AudioMixerInput) -> Int {
        pickChannel(0, input.numberOfChannels)
    }

    private func configure(_ numberOfInputChannels: Int) {
        self.numberOfInputChannels = numberOfInputChannels
        leftChannel = pickChannel(0, numberOfInputChannels)
        rightChannel = isStereoMix ? pickChannel(1, numberOfInputChannels) : leftChannel
        isSilent = true
    }

    private func pickChannel(_ outputChannel: Int, _ numberOfInputChannels: Int) -> Int {
        if let channel {
            channel
        } else if let inputChannel = channelsMap[outputChannel], inputChannel < numberOfInputChannels {
            inputChannel
        } else {
            min(outputChannel, numberOfInputChannels - 1)
        }
    }

    private func start(_ input: AudioMixerInput, _ index: Int64) -> Bool {
        start(effects, input, index, left, right)
    }

    private func start(_ chain: AudioMixerEffectChain,
                       _ input: AudioMixerInput,
                       _ index: Int64,
                       _ left: UnsafeMutablePointer<Float>,
                       _ right: UnsafeMutablePointer<Float>) -> Bool
    {
        let inputIndex = index + voice.latency + chain.latency
        voice.reset()
        chain.reset()
        if !voice.isEmpty || !chain.isEmpty {
            read(input, inputIndex - Int64(audioMixerFramesPerBlock), audioMixerFramesPerBlock, left, right)
            processVoice(left, right, hasEffects: true)
            guard chain.process(left, right) else {
                return false
            }
        }
        read(input, inputIndex, audioMixerFramesPerBlock, left, right)
        processVoice(left, right, hasEffects: !chain.isEmpty)
        effectHistory?.copy(left, right)
        return chain.process(left, right)
    }

    private func processVoice(_ left: UnsafeMutablePointer<Float>, _ right: UnsafeMutablePointer<Float>,
                              hasEffects: Bool)
    {
        if !isStereo, hasEffects || !voice.isEmpty {
            right.update(from: left, count: audioMixerFramesPerBlock)
        }
        voice.process(left, right)
    }

    private func requiredFrames(_ chain: AudioMixerEffectChain) -> Int {
        audioMixerFramesPerBlock + max(audioMixerFadeFrames, Int(voice.latency + chain.latency))
    }

    private func activateEffects(_ chain: AudioMixerEffectChain) {
        effects = chain
        pendingEffects = nil
    }

    private func processEffects(_ input: AudioMixerInput, _ index: Int64, canTransition: Bool) {
        processVoice(left, right, hasEffects: !effects.isEmpty)
        if canTransition, let pendingEffects, let effectHistory, pendingEffects.latency == effects.latency {
            effectTransition.copy(effectHistory.left, effectHistory.right)
            pendingEffects.reset()
            pendingEffects.process(effectTransition.left, effectTransition.right)
            effectTransition.copy(left, right)
            pendingEffects.process(effectTransition.left, effectTransition.right)
            effectHistory.copy(left, right)
            effects.process(left, right)
            effectTransition.crossfade(into: left, isStereo ? right : nil)
            activateEffects(pendingEffects)
        } else {
            effectHistory?.copy(left, right)
            effects.process(left, right)
            if canTransition, let pendingEffects,
               input.writeIndex - index >= Int64(requiredFrames(pendingEffects)),
               start(pendingEffects, input, index, effectTransition.left, effectTransition.right)
            {
                effectTransition.crossfade(into: left, isStereo ? right : nil)
                activateEffects(pendingEffects)
            }
        }
    }

    private func read(_ input: AudioMixerInput,
                      _ index: Int64,
                      _ count: Int,
                      _ left: UnsafeMutablePointer<Float>,
                      _ right: UnsafeMutablePointer<Float>)
    {
        input.read(channel: leftChannel, at: index, count: count, into: left)
        if isStereo {
            input.read(channel: rightChannel, at: index, count: count, into: right)
        }
    }

    private func seek(_ input: AudioMixerInput, _ previousIndex: Int64) {
        read(input, previousIndex, audioMixerFadeFrames, previousLeft, previousRight)
        crossfadeAudioMixerSamples(from: previousLeft, to: left, output: previousLeft)
        left.update(from: previousLeft, count: audioMixerFadeFrames)
        if isStereo {
            crossfadeAudioMixerSamples(from: previousRight, to: right, output: previousRight)
            right.update(from: previousRight, count: audioMixerFadeFrames)
        }
    }

    private func fadeIn() {
        fadeInAudioMixerSamples(samples: left, position: 0, count: audioMixerFadeFrames)
        if isStereo {
            fadeInAudioMixerSamples(samples: right, position: 0, count: audioMixerFadeFrames)
        }
    }

    private func fadeOut(_ end: Int) {
        fadeOutBlock(left, end)
        if isStereo {
            fadeOutBlock(right, end)
        }
    }

    private func fadeOutBlock(_ samples: UnsafeMutablePointer<Float>, _ end: Int) {
        guard end >= audioMixerFadeFrames else {
            samples.update(repeating: 0, count: audioMixerFramesPerBlock)
            return
        }
        let fadeStart = end - audioMixerFadeFrames
        fadeOutAudioMixerSamples(samples: samples + fadeStart, position: 0, count: audioMixerFadeFrames)
        (samples + end).update(repeating: 0, count: audioMixerFramesPerBlock - end)
    }

    private func send(to bus: AudioMixerBus,
                      _ startPan: (left: Float, right: Float),
                      _ startGain: Float,
                      _ endGain: Float)
    {
        send(left, bus.left, startGain * startPan.left, endGain * currentPan.left)
        send(isStereo ? right : left, bus.right, startGain * startPan.right, endGain * currentPan.right)
    }

    private func send(_ samples: UnsafeMutablePointer<Float>,
                      _ output: UnsafeMutablePointer<Float>,
                      _ startGain: Float,
                      _ endGain: Float)
    {
        var gain = startGain
        var step = (endGain - startGain) / Float(audioMixerFramesPerBlock)
        vDSP_vrampmuladd(samples, 1, &gain, &step, output, 1, vDSP_Length(audioMixerFramesPerBlock))
    }
}

final class AudioMixerBus {
    let left: UnsafeMutablePointer<Float>
    let right: UnsafeMutablePointer<Float>
    var isStereo = true
    private let stereoBuffer: AVAudioPCMBuffer
    private let monoBuffer: AVAudioPCMBuffer
    private var gain: Float = 1
    private var targetGain: Float = 1
    private var isMuted = false
    private var effects: AudioMixerEffectChain?
    private var pendingEffects: AudioMixerEffectChain?
    private let effectTransition = AudioMixerEffectBuffer()
    private let effectHistory = AudioMixerEffectBuffer()
    private var hasHistory = false
    private let limiter: AudioMixerEffect?

    init(limiter: AudioMixerEffect?) {
        self.limiter = limiter
        stereoBuffer = makeAudioMixerBuffer(numberOfChannels: 2)
        monoBuffer = makeAudioMixerBuffer(numberOfChannels: 1)
        left = stereoBuffer.floatChannelData![0]
        right = stereoBuffer.floatChannelData![1]
    }

    var buffer: AVAudioPCMBuffer {
        isStereo ? stereoBuffer : monoBuffer
    }

    var latency: Int64 {
        limiter?.latency ?? 0
    }

    func setGain(_ gain: Float) {
        targetGain = gain
    }

    func setMuted(_ muted: Bool) {
        isMuted = muted
    }

    func setEffects(_ effects: AudioMixerEffectChain) {
        pendingEffects = self.effects === effects || (self.effects == nil && effects.isEmpty) ? nil : effects
    }

    func clear() {
        vDSP_vclr(left, 1, vDSP_Length(audioMixerFramesPerBlock))
        vDSP_vclr(right, 1, vDSP_Length(audioMixerFramesPerBlock))
    }

    func reset() {
        effects?.reset()
        limiter?.reset()
        hasHistory = false
    }

    func skip() {
        gain = isMuted ? 0 : targetGain
        hasHistory = false
    }

    func resumeHistory(from bus: AudioMixerBus) {
        hasHistory = bus.hasHistory
        if hasHistory {
            effectHistory.copy(bus.effectHistory.left, bus.effectHistory.right)
        }
    }

    func finish() {
        processEffects()
        let endGain = isMuted ? 0 : targetGain
        var step = (endGain - gain) / Float(audioMixerFramesPerBlock)
        let frames = vDSP_Length(audioMixerFramesPerBlock)
        vDSP_vrampmul2(left, right, 1, &gain, &step, left, right, 1, frames)
        gain = endGain
        limiter?.process(left, right)
        var low: Float = -1
        var high: Float = 1
        vDSP_vclip(left, 1, &low, &high, left, 1, frames)
        vDSP_vclip(right, 1, &low, &high, right, 1, frames)
        if !isStereo {
            monoBuffer.floatChannelData![0].update(from: left, count: audioMixerFramesPerBlock)
        }
    }

    private func processEffects() {
        if let pendingEffects {
            if hasHistory {
                effectTransition.copy(effectHistory.left, effectHistory.right)
                pendingEffects.process(effectTransition.left, effectTransition.right)
            }
            effectTransition.copy(left, right)
        }
        effectHistory.copy(left, right)
        hasHistory = true
        effects?.process(left, right)
        if let pendingEffects {
            pendingEffects.process(effectTransition.left, effectTransition.right)
            effectTransition.crossfade(into: left, right, frames: audioMixerFramesPerBlock)
            effects = pendingEffects.isEmpty ? nil : pendingEffects
            self.pendingEffects = nil
        }
    }

    func finish(continuing bus: AudioMixerBus) {
        limiter?.reset()
        finish()
        let count = Int(min(latency, Int64(audioMixerFramesPerBlock)))
        left.update(from: bus.left, count: count)
        right.update(from: bus.right, count: count)
        if !isStereo {
            monoBuffer.floatChannelData![0].update(from: left, count: count)
        }
    }
}

private func makeAudioMixerBuffer(numberOfChannels: AVAudioChannelCount) -> AVAudioPCMBuffer {
    let format = AVAudioFormat(standardFormatWithSampleRate: audioMixerSampleRate,
                               channels: numberOfChannels)!
    let frames = AVAudioFrameCount(audioMixerFramesPerBlock)
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
    buffer.frameLength = buffer.frameCapacity
    return buffer
}

final class AudioMixer {
    private(set) var sources: [AudioMixerSource] = []
    private(set) var builtinInput: AudioMixerInput?
    private(set) var bufferedInputs: [UUID: AudioMixerInput] = [:]
    private(set) var latency = minimumLatency
    private(set) var numberOfSkips = 0
    private let streamBus: AudioMixerBus
    private let recordingBus: AudioMixerBus
    private var recordingBlocks = 0
    private var nextBlockStart: Int64?
    private let latencyReport = AudioMixerReport { logger.debug("audio-mixer: Latency \($0) frames") }
    private let skipReport = AudioMixerReport { logger.info("audio-mixer: Skipping \($0) frames") }
    private(set) var configuration: AudioMixerConfiguration

    init(_ configuration: AudioMixerConfiguration) {
        self.configuration = configuration
        streamBus = AudioMixerBus(limiter: configuration.streamLimiter)
        recordingBus = AudioMixerBus(limiter: configuration.recordingLimiter)
        apply(configuration)
    }

    func apply(_ configuration: AudioMixerConfiguration) {
        for source in sources where !configuration.sources.contains(where: { $0.voice === source.voice }) {
            source.remove()
        }
        for prepared in configuration.sources {
            if let source = sources.first(where: { $0.voice === prepared.voice && !$0.isRemoved }) {
                source.update(prepared)
            } else {
                let startIndex = makeStartIndex(prepared.settings.bufferedAudio)
                sources.append(AudioMixerSource(prepared, startIndex: startIndex))
            }
        }
        if !self.configuration.streamEffects.isEmpty,
           self.configuration.streamEffects !== configuration.streamEffects
        {
            recordingBlocks = 2
        }
        self.configuration = configuration
        streamBus.setEffects(configuration.streamEffects)
        recordingBus.setEffects(configuration.recordingEffects)
        updateInputs()
    }

    func setStereo(_ stereo: Bool) {
        streamBus.isStereo = stereo
        recordingBus.isStereo = stereo
    }

    func setMasterGain(_ gain: Float) {
        streamBus.setGain(gain)
        recordingBus.setGain(gain)
    }

    func setMasterMuted(_ muted: Bool) {
        streamBus.setMuted(muted)
        recordingBus.setMuted(muted)
    }

    func appendBuiltin(_ sampleBuffer: CMSampleBuffer, _ presentationTimeStamp: CMTime, delay: Double = 0) {
        builtinInput?.append(sampleBuffer, presentationTimeStamp + CMTime(seconds: delay))
    }

    func appendBuffered(cameraId: UUID, _ sampleBuffer: CMSampleBuffer) {
        bufferedInputs[cameraId]?.append(sampleBuffer, sampleBuffer.presentationTimeStamp)
    }

    // Copies the source's input as written, before its delay, gain and effects.
    func capture(id: String, start: Int64, count: Int) -> Result<[Float], AudioMixerCaptureError> {
        guard let source = sources.first(where: { $0.id == id && !$0.isRemoved }),
              let input = input(source.bufferedAudio),
              input.numberOfChannels > 0
        else {
            return .failure(.missing)
        }
        guard input.writeIndex >= start + Int64(count) else {
            return .failure(.notReady)
        }
        guard input.oldestIndex <= start, input.latestDiscontinuityIndex <= start else {
            return .failure(.discontinuity)
        }
        var samples = [Float](repeating: 0, count: count)
        samples.withUnsafeMutableBufferPointer {
            input.read(channel: source.captureChannel(input), at: start, count: count, into: $0.baseAddress!)
        }
        return .success(samples)
    }

    func renderNextBlock(now: CMTime) -> (
        presentationTimeStamp: CMTime,
        buffer: AVAudioPCMBuffer,
        recordingBuffer: AVAudioPCMBuffer?
    )? {
        let frames = Int64(audioMixerFramesPerBlock)
        let due = makeAudioMixerIndex(now) - latency - frames
        var blockStart = nextBlockStart ?? due
        guard blockStart <= due else {
            return nil
        }
        if due - blockStart > Int64(audioMixerSampleRate) {
            skipReport.record(Int(due - blockStart))
            numberOfSkips += 1
            blockStart = due
            streamBus.reset()
            recordingBus.reset()
            for source in sources {
                source.reset()
            }
        }
        let recordingBuffer = render(blockStart)
        nextBlockStart = blockStart + frames
        let presentationTimeStamp = blockStart - streamBus.latency
        return (
            CMTime(value: presentationTimeStamp, timescale: CMTimeScale(audioMixerSampleRate)),
            streamBus.buffer,
            recordingBuffer
        )
    }

    private func render(_ blockStart: Int64) -> AVAudioPCMBuffer? {
        let wasRecordingRendered = recordingBlocks > 0
        if !configuration.streamEffects.isEmpty || sources.contains(where: \.hasDifferentSends) {
            recordingBlocks = 2
        }
        let isRecordingRendered = recordingBlocks > 0
        streamBus.clear()
        if isRecordingRendered {
            recordingBus.clear()
        }
        for source in sources {
            if let input = input(source.bufferedAudio) {
                source.render(input, blockStart, streamBus, isRecordingRendered ? recordingBus : nil)
            }
        }
        updateLatency()
        if isRecordingRendered, !wasRecordingRendered {
            recordingBus.resumeHistory(from: streamBus)
        }
        streamBus.finish()
        if !isRecordingRendered {
            recordingBus.skip()
        } else if wasRecordingRendered {
            recordingBus.finish()
        } else {
            recordingBus.finish(continuing: streamBus)
        }
        recordingBlocks = max(recordingBlocks - 1, 0)
        if sources.contains(where: \.isRemoved) {
            sources.removeAll { $0.isRemoved }
            updateInputs()
        }
        return isRecordingRendered ? recordingBus.buffer : nil
    }

    private func makeStartIndex(_ bufferedAudio: UUID?) -> Int64 {
        guard let nextBlockStart, let input = input(bufferedAudio) else {
            return .min
        }
        return sources
            .filter { $0.isRemoved && $0.bufferedAudio == bufferedAudio }
            .map { nextBlockStart - $0.delay }
            .max() ?? input.writeIndex
    }

    private func input(_ bufferedAudio: UUID?) -> AudioMixerInput? {
        if let bufferedAudio {
            bufferedInputs[bufferedAudio]
        } else {
            builtinInput
        }
    }

    private func updateInputs() {
        if !sources.contains(where: { $0.bufferedAudio == nil }) {
            builtinInput = nil
        } else if builtinInput == nil {
            builtinInput = AudioMixerInput(kind: .builtin)
        }
        bufferedInputs = bufferedInputs.filter { cameraId, _ in
            sources.contains { $0.bufferedAudio == cameraId }
        }
        for case let cameraId? in sources.map(\.bufferedAudio) where bufferedInputs[cameraId] == nil {
            bufferedInputs[cameraId] = AudioMixerInput(kind: .buffered)
        }
        updateLatency()
    }

    private func updateLatency() {
        let latency = minimumLatency + sources.reduce(0) { max($0, $1.effectsLatency - $1.delay) }
        if latency != self.latency {
            latencyReport.record(Int(latency))
            self.latency = latency
        }
    }
}
