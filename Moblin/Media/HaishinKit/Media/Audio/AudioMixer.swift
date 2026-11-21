import Accelerate
import AVFoundation

let audioMixerFramesPerBlock = 1024
let audioMixerMinimumLatency: Int64 = 2400

enum AudioMixerCaptureError: Error {
    case missing
    case notReady
    case discontinuity
}

struct AudioMixerLevels {
    let sources: [String: Float]
    let left: Float
    let right: Float
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
    private(set) var delay: Int64 = 0
    private var isRemoved = false
    var startIndex: Int64 = .min
    private let channelsMap: [Int: Int]
    private let channel: Int?
    let voice: AudioMixerEffectChain
    private var effectAddress: Unmanaged<AudioMixerEffectChain>
    private var pendingEffectAddress: Unmanaged<AudioMixerEffectChain>?
    private var effectTransitionBlocksRemaining = 0

    private var effects: AudioMixerEffectChain {
        effectAddress.takeUnretainedValue()
    }

    private var pendingEffects: AudioMixerEffectChain? {
        pendingEffectAddress?.takeUnretainedValue()
    }

    var hasPendingEffects: Bool {
        pendingEffectAddress != nil
    }

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
    private var peak: Float = 0
    private let left = makeAudioMixerSamples(count: audioMixerFramesPerBlock)
    private let right = makeAudioMixerSamples(count: audioMixerFramesPerBlock)
    private let previousLeft = makeAudioMixerSamples(count: audioMixerFadeFrames)
    private let previousRight = makeAudioMixerSamples(count: audioMixerFadeFrames)

    init(_ prepared: AudioMixerPreparedSource) {
        let settings = prepared.settings
        id = settings.id
        channelsMap = settings.channelsMap
        channel = settings.channel
        voice = prepared.voice
        effectHistory = prepared.voice.isEmpty ? nil : AudioMixerEffectBuffer()
        effectAddress = .passUnretained(prepared.effects)
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

    func hasDifferentSends(_ target: (stream: Float, recording: Float)) -> Bool {
        target.stream != target.recording || currentSends.stream != currentSends.recording
    }

    var effectsLatency: Int64 {
        voice.latency + max(effects.latency, pendingEffects?.latency ?? 0)
    }

    func update(_ prepared: AudioMixerPreparedSource) {
        gain = prepared.settings.gain
        delay = prepared.delay
        sends = prepared.settings.sends
        pan = prepared.pan
        pendingEffectAddress = effects === prepared.effects ? nil : .passUnretained(prepared.effects)
        effectTransitionBlocksRemaining = 4
    }

    func remove() {
        isRemoved = true
    }

    func reset() {
        isSilent = true
    }

    func takePeak() -> Float {
        defer {
            peak = 0
        }
        return peak
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
        if input.numberOfChannels != numberOfInputChannels {
            configure(input.numberOfChannels)
        }
        guard startGain != 0 || currentGain != 0 else {
            isSilent = true
            if let pendingEffects {
                activateEffects(pendingEffects)
            }
            readBlock(input, blockStart - delay + voice.latency + effects.latency)
            return
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
            if let pendingEffects {
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
            readBlock(input, index + latency)
            if previousDelay != delay {
                seek(input, blockStart - previousDelay + latency)
            }
            let canTransition = end >= lookahead && previousDelay == delay
            processEffects(input, index, canTransition: canTransition)
            if end < lookahead {
                diagnostics.record(1)
                fadeOut(min(end, audioMixerFramesPerBlock))
                isSilent = true
                if let pendingEffects {
                    activateEffects(pendingEffects)
                }
            } else if let pendingEffects {
                effectTransitionBlocksRemaining -= 1
                if effectTransitionBlocksRemaining == 0 {
                    fadeOut(audioMixerFramesPerBlock)
                    activateEffects(pendingEffects)
                    isSilent = true
                }
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
                       _ right: UnsafeMutablePointer<Float>,
                       resetChain: Bool = true) -> Bool
    {
        let inputIndex = index + voice.latency + chain.latency
        voice.reset()
        if resetChain {
            chain.reset()
        }
        if !voice.isEmpty || !chain.isEmpty {
            read(input, inputIndex - Int64(audioMixerFramesPerBlock), audioMixerFramesPerBlock, left, right)
            processVoice(left, right, hasEffects: true)
            guard chain.process(left, right) else {
                return false
            }
        }
        read(input, inputIndex, audioMixerFramesPerBlock, left, right)
        if left == self.left {
            measurePeak()
        }
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
        effectAddress = .passUnretained(chain)
        pendingEffectAddress = nil
    }

    private func processEffects(_ input: AudioMixerInput, _ index: Int64, canTransition: Bool) {
        processVoice(left, right, hasEffects: !effects.isEmpty)
        if canTransition, let pendingEffects, let effectHistory, pendingEffects.latency == effects.latency {
            effectTransition.copy(effectHistory.left, effectHistory.right)
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
               start(
                   pendingEffects,
                   input,
                   index,
                   effectTransition.left,
                   effectTransition.right,
                   resetChain: false
               )
            {
                effectTransition.crossfade(into: left, isStereo ? right : nil)
                activateEffects(pendingEffects)
            }
        }
    }

    private func readBlock(_ input: AudioMixerInput, _ index: Int64) {
        read(input, index, audioMixerFramesPerBlock, left, right)
        measurePeak()
    }

    private func measurePeak() {
        let frames = vDSP_Length(audioMixerFramesPerBlock)
        var leftPeak: Float = 0
        vDSP_maxmgv(left, 1, &leftPeak, frames)
        peak = max(peak, leftPeak)
        if isStereo {
            var rightPeak: Float = 0
            vDSP_maxmgv(right, 1, &rightPeak, frames)
            peak = max(peak, rightPeak)
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
    private var effectAddress: Unmanaged<AudioMixerEffectChain>?
    private var pendingEffectAddress: Unmanaged<AudioMixerEffectChain>?

    private var effects: AudioMixerEffectChain? {
        effectAddress?.takeUnretainedValue()
    }

    private var pendingEffects: AudioMixerEffectChain? {
        pendingEffectAddress?.takeUnretainedValue()
    }

    private let effectTransition = AudioMixerEffectBuffer()
    private let effectHistory = AudioMixerEffectBuffer()
    private var hasHistory = false
    private var leftPeak: Float = 0
    private var rightPeak: Float = 0

    init() {
        stereoBuffer = makeAudioMixerBuffer(numberOfChannels: 2)
        monoBuffer = makeAudioMixerBuffer(numberOfChannels: 1)
        left = stereoBuffer.floatChannelData![0]
        right = stereoBuffer.floatChannelData![1]
    }

    var buffer: AVAudioPCMBuffer {
        isStereo ? stereoBuffer : monoBuffer
    }

    func setGain(_ gain: Float) {
        targetGain = gain
    }

    func setMuted(_ muted: Bool) {
        isMuted = muted
    }

    func setEffects(_ effects: AudioMixerEffectChain) {
        pendingEffectAddress = self.effects === effects || (self.effects == nil && effects.isEmpty)
            ? nil : .passUnretained(effects)
    }

    func clear() {
        vDSP_vclr(left, 1, vDSP_Length(audioMixerFramesPerBlock))
        vDSP_vclr(right, 1, vDSP_Length(audioMixerFramesPerBlock))
    }

    func reset() {
        effects?.reset()
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
        var low: Float = -1
        var high: Float = 1
        vDSP_vclip(left, 1, &low, &high, left, 1, frames)
        vDSP_vclip(right, 1, &low, &high, right, 1, frames)
        if !isStereo {
            monoBuffer.floatChannelData![0].update(from: left, count: audioMixerFramesPerBlock)
        }
        leftPeak = max(leftPeak, calcPeak(left))
        rightPeak = max(rightPeak, calcPeak(right))
    }

    func takeLevels() -> (left: Float, right: Float) {
        defer {
            leftPeak = 0
            rightPeak = 0
        }
        return (leftPeak, rightPeak)
    }

    private func calcPeak(_ samples: UnsafeMutablePointer<Float>) -> Float {
        var peak: Float = 0
        vDSP_maxmgv(samples, 1, &peak, vDSP_Length(audioMixerFramesPerBlock))
        return peak
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
            effectTransition.crossfade(into: left, right)
            effectAddress = pendingEffects.isEmpty ? nil : .passUnretained(pendingEffects)
            pendingEffectAddress = nil
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
    private var renderedLatency = audioMixerMinimumLatency
    private(set) var numberOfSkips = 0
    private let streamBus: AudioMixerBus
    private let recordingBus: AudioMixerBus
    private var recordingBlocks = 0
    private var nextBlockStart: Int64?
    private let latencyReport = AudioMixerReport { logger.debug("audio-mixer: Latency \($0) frames") }
    private let skipReport = AudioMixerReport { logger.info("audio-mixer: Skipping \($0) frames") }
    private let stats = AudioMixerReport { logger.debug("audio-mixer: \($0) skips") }
    private var graphAddress: Unmanaged<AudioMixerGraph>?
    private var previousAddress: Unmanaged<AudioMixerGraph>?
    private var needsGraphUpdate = false
    private(set) var isTransitioning = false

    private var graph: AudioMixerGraph? {
        graphAddress?.takeUnretainedValue()
    }

    private var previousGraph: AudioMixerGraph? {
        previousAddress?.takeUnretainedValue()
    }

    var latency: Int64 {
        if needsGraphUpdate, let graph {
            return max(renderedLatency, graph.targetLatency)
        }
        return renderedLatency
    }

    init() {
        prepareAudioMixerFades()
        streamBus = AudioMixerBus()
        recordingBus = AudioMixerBus()
    }

    func install(_ graph: AudioMixerGraph) {
        if !needsGraphUpdate {
            previousAddress = graphAddress
        }
        graphAddress = .passUnretained(graph)
        needsGraphUpdate = true
        isTransitioning = true
    }

    func reportStats() {
        stats.record(numberOfSkips)
        graph?.builtinInput?.audio.reportStats()
        if let graph {
            for input in graph.bufferedInputs.values {
                input.audio.reportStats()
            }
        }
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

    func takeLevels() -> AudioMixerLevels {
        var peaks: [String: Float] = [:]
        for entry in graph?.entries ?? [] {
            peaks[entry.source.id] = entry.source.takePeak()
        }
        let output = streamBus.takeLevels()
        return AudioMixerLevels(sources: peaks, left: output.left, right: output.right)
    }

    func appendBuiltin(_ sampleBuffer: CMSampleBuffer, _ presentationTimeStamp: CMTime, delay: Double = 0) {
        let input = graph?.builtinInput ?? previousGraph?.builtinInput
        input?.append(sampleBuffer, presentationTimeStamp + CMTime(seconds: delay))
    }

    func appendBuffered(cameraId: UUID, _ sampleBuffer: CMSampleBuffer) {
        (graph?.bufferedInputs[cameraId] ?? previousGraph?.bufferedInputs[cameraId])?
            .append(sampleBuffer, sampleBuffer.presentationTimeStamp)
    }

    func capture(id: String, start: Int64, count: Int) -> Result<[Float], AudioMixerCaptureError> {
        guard let entry = graph?.entries.first(where: { $0.source.id == id }),
              entry.input.audio.numberOfChannels > 0
        else {
            return .failure(.missing)
        }
        let input = entry.input.audio
        guard input.writeIndex >= start + Int64(count) else {
            return .failure(.notReady)
        }
        guard input.oldestIndex <= start, input.latestDiscontinuityIndex <= start else {
            return .failure(.discontinuity)
        }
        var samples = [Float](repeating: 0, count: count)
        samples.withUnsafeMutableBufferPointer {
            input.read(
                channel: entry.source.captureChannel(input),
                at: start,
                count: count,
                into: $0.baseAddress!
            )
        }
        return .success(samples)
    }

    func renderNextBlock(now: CMTime) -> (
        presentationTimeStamp: CMTime,
        buffer: AVAudioPCMBuffer,
        recordingBuffer: AVAudioPCMBuffer?
    )? {
        guard let graph else {
            return nil
        }
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
            for entry in graph.entries {
                entry.source.reset()
            }
        }
        let recordingBuffer = render(graph, blockStart)
        nextBlockStart = blockStart + frames
        let presentationTimeStamp = blockStart
        return (
            CMTime(value: presentationTimeStamp, timescale: CMTimeScale(audioMixerSampleRate)),
            streamBus.buffer,
            recordingBuffer
        )
    }

    private func render(_ graph: AudioMixerGraph, _ blockStart: Int64) -> AVAudioPCMBuffer? {
        let previous = needsGraphUpdate ? previousGraph : nil
        if needsGraphUpdate {
            let config = graph.configuration
            if let old = previous?.configuration.streamEffects, !old.isEmpty, old !== config.streamEffects {
                recordingBlocks = 2
            }
            streamBus.setEffects(config.streamEffects)
            recordingBus.setEffects(config.recordingEffects)
        }
        let wasRecordingRendered = recordingBlocks > 0
        if !graph.configuration.streamEffects.isEmpty {
            recordingBlocks = 2
        }
        for entry in graph.entries where entry.source.hasDifferentSends(entry.prepared.settings.sends) {
            recordingBlocks = 2
            break
        }
        if let previous {
            for index in graph.removed {
                let entry = previous.entries[index]
                if entry.source.hasDifferentSends(entry.prepared.settings.sends) {
                    recordingBlocks = 2
                    break
                }
            }
        }
        let isRecordingRendered = recordingBlocks > 0
        let recording = isRecordingRendered ? recordingBus : nil
        streamBus.clear()
        recording?.clear()
        if let previous {
            for index in graph.removed {
                let entry = previous.entries[index]
                entry.source.remove()
                entry.source.render(entry.input.audio, blockStart, streamBus, recording)
            }
        }
        var latency = graph.targetLatency
        var pending = false
        for entry in graph.entries {
            let source = entry.source
            if needsGraphUpdate {
                source.update(entry.prepared)
                if entry.isNew, entry.isSharedInput, let nextBlockStart {
                    if let delay = entry.replacedDelay {
                        source.startIndex = nextBlockStart - delay
                    } else {
                        source.startIndex = entry.input.startIndex
                    }
                }
            }
            source.render(entry.input.audio, blockStart, streamBus, recording)
            latency = max(latency, audioMixerMinimumLatency + source.effectsLatency - source.delay)
            pending = pending || source.hasPendingEffects
        }
        if isRecordingRendered, !wasRecordingRendered {
            recordingBus.resumeHistory(from: streamBus)
        }
        streamBus.finish()
        if isRecordingRendered {
            recordingBus.finish()
        } else {
            recordingBus.skip()
        }
        recordingBlocks = max(recordingBlocks - 1, 0)
        needsGraphUpdate = false
        previousAddress = nil
        isTransitioning = pending
        if latency != renderedLatency {
            latencyReport.record(Int(latency))
            renderedLatency = latency
        }
        return isRecordingRendered ? recordingBus.buffer : nil
    }
}
