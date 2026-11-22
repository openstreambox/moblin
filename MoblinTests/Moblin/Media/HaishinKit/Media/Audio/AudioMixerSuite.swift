import AVFoundation
@testable import Moblin
import Testing

private let startIndex: Int64 = 480_000
private let cameraId = UUID()
private let limiterLatency = makeAudioMixerLimiter()!.latency
private let sqrt2 = Float(2).squareRoot()

struct AudioMixerSuite {
    struct FormatCase: CustomTestStringConvertible {
        let buffered: Bool
        let commonFormat: AVAudioCommonFormat
        let numberOfChannels: Int
        let interleaved: Bool

        var testDescription: String {
            let sampleFormat = commonFormat == .pcmFormatInt16 ? "Int16" : "Float32"
            return "\(buffered ? "buffered" : "builtin") \(sampleFormat), \(numberOfChannels) channels"
        }
    }

    struct GainCase: CustomTestStringConvertible {
        let sourceGain: Float
        let masterGain: Float
        let masterMuted: Bool
        let sends: (stream: Float, recording: Float)

        var testDescription: String {
            "gain \(sourceGain), master gain \(masterGain), muted \(masterMuted), sends \(sends)"
        }
    }

    struct DelayCase: CustomTestStringConvertible {
        let delay: Double
        let frame: Int
        let latency: Int64

        var testDescription: String {
            "\(delay) s"
        }
    }

    struct BuiltinDelayCase: CustomTestStringConvertible {
        let builtinDelay: Double
        let frame: Int

        var testDescription: String {
            "\(builtinDelay) s"
        }
    }

    struct DelayChangeCase: CustomTestStringConvertible {
        let testDescription: String
        let delays: [Int: Double]
    }

    struct DelayedCase: CustomTestStringConvertible {
        let testDescription: String
        let ahead: Int64
        let lateTicks: Range<Int>
    }

    struct ChannelCase: CustomTestStringConvertible {
        let testDescription: String
        let channelsMap: [Int: Int]
        var channel: Int?
        let left: Int
        let right: Int
    }

    struct PanCase: CustomTestStringConvertible {
        let pan: Float
        let left: Float
        let right: Float

        var testDescription: String {
            "pan \(pan)"
        }
    }

    struct SendsCase: CustomTestStringConvertible {
        let testDescription: String
        let sends: (stream: Float, recording: Float)
        let recordingBuffer: Bool
        let stream: [Int]
        let recording: [Int]
    }

    @Test(arguments: [
        FormatCase(buffered: false, commonFormat: .pcmFormatFloat32, numberOfChannels: 2, interleaved: false),
        FormatCase(buffered: true, commonFormat: .pcmFormatInt16, numberOfChannels: 2, interleaved: true),
        FormatCase(buffered: true, commonFormat: .pcmFormatInt16, numberOfChannels: 1, interleaved: true),
    ])
    func passesThrough(_ testCase: FormatCase) {
        let mixer = TestAudioMixer()
        let format = createFormat(testCase.commonFormat, testCase.numberOfChannels, testCase.interleaved)
        mixer.setSources([createSettings(bufferedAudio: testCase.buffered ? cameraId : nil)])
        let output = Output()
        for tick in 0 ..< 60 {
            if testCase.buffered {
                mixer.appendBuffered(cameraId: cameraId, createSampleBuffer(format, tick))
            } else {
                mixer.appendBuiltin(createSampleBuffer(format, tick), createTime(tick))
            }
            while let block = mixer.renderNextBlock(now: createTime(tick + 1)) {
                output.append(block)
            }
        }
        let frames = 256 ..< output.end
        #expect(output.isContinuous)
        #expect(output.presentationTimeStamps.first == startIndex - 2400 - limiterLatency)
        #expect(output.samples(0, -2400 ..< 0) == [Float](repeating: 0, count: 2400))
        #expect(output.samples(0, frames) == createNoise(0, frames))
        #expect(output.samples(1, frames) == createNoise(testCase.numberOfChannels - 1, frames))
    }

    @Test
    func mixerKeepsRenderingWhilePreparationIsBlocked() throws {
        let preparation = AudioMixerPreparation()
        let format = createFormat(.pcmFormatFloat32, 2, false)
        AudioMixerMaintenance.shared.queue.sync {
            preparation.submit(sources: [], master: [])
            preparation.submit(sources: [createSettings()], master: [])
        }
        try #require(waitForMixerUpdate(preparation))
        let output = Output()
        func render(ticks: Range<Int>) {
            processorPipelineQueue.sync {
                for tick in ticks {
                    guard let mixer = preparation.mixer else {
                        Issue.record("The active mixer disappeared")
                        return
                    }
                    mixer.appendBuiltin(createSampleBuffer(format, tick), createTime(tick))
                    while let block = mixer.renderNextBlock(now: createTime(tick + 1)) {
                        output.append(block)
                    }
                    mixer.reportStats()
                    preparation.finishTransition()
                }
            }
        }
        render(ticks: 0 ..< 8)

        let entered = DispatchSemaphore(value: 0)
        let unblock = DispatchSemaphore(value: 0)
        AudioMixerMaintenance.shared.queue.async {
            entered.signal()
            _ = unblock.wait(timeout: .now() + .seconds(10))
        }
        defer { unblock.signal() }
        try #require(entered.wait(timeout: .now() + .seconds(5)) == .success)
        preparation.submit(sources: [createSettings(gain: 0.5)], master: [])
        #expect(!processorPipelineQueue.sync { preparation.adopt() })
        render(ticks: 8 ..< 24)
        let dry = 8 * 1024 ..< 18 * 1024
        #expect(output.samples(0, dry) == createNoise(0, dry))

        unblock.signal()
        try #require(waitForMixerUpdate(preparation))
        render(ticks: 24 ..< 40)
        let changed = 30 * 1024 ..< 36 * 1024
        #expect(output.samples(0, changed) == createNoise(0, changed).map { 0.5 * $0 })
        #expect(output.isContinuous)
    }

    @Test
    func disableCanFollowAnEffectEditWithoutEnoughInputForTheNewLookahead() throws {
        let preparation = AudioMixerPreparation()
        let format = createFormat(.pcmFormatFloat32, 2, false)
        let dry = createSettings()
        var wet = dry
        wet.effects = Array(repeating: .compressor(.init()), count: 3)
        let stages = wet.effects.compactMap { $0.makeStage() }
        try #require(stages.count == wet.effects.count)
        let latency = stages.reduce(Int64(0)) { $0 + $1.latency }
        try #require(latency > 352 && latency <= 1024)

        preparation.submit(sources: [dry], master: [])
        try #require(waitForMixerUpdate(preparation))
        let output = Output()
        func render(tick: Int, inputTick: Int?, extraLatency: Int64) {
            processorPipelineQueue.sync {
                guard let mixer = preparation.mixer else {
                    Issue.record("The mixer disappeared before disable was adopted")
                    return
                }
                if let inputTick {
                    let buffer = createSampleBuffer(format, inputTick) { _, _ in 0.5 }
                    mixer.appendBuiltin(buffer, createTime(inputTick))
                }
                let now = createTime(tick + 1) + CMTime(value: extraLatency, timescale: 48000)
                while let block = mixer.renderNextBlock(now: now) {
                    output.append(block)
                }
                preparation.finishTransition()
            }
        }
        for tick in 0 ..< 8 {
            render(tick: tick, inputTick: tick == 7 ? nil : tick, extraLatency: 0)
        }

        preparation.submit(sources: [wet], master: [])
        try #require(waitForMixerUpdate(preparation))
        render(tick: 8, inputTick: nil, extraLatency: latency)
        #expect(processorPipelineQueue.sync { preparation.mixer?.isTransitioning == true })
        let firstWait = 8 * 1024 - 2400
        #expect(output.samples(0, firstWait ..< firstWait + 256).allSatisfy { $0 == 0.5 })

        preparation.submit(sources: nil, master: [])
        #expect(!processorPipelineQueue.sync { preparation.adopt() })
        for tick in 9 ... 11 {
            render(tick: tick, inputTick: tick - 2, extraLatency: latency)
        }
        #expect(processorPipelineQueue.sync { preparation.mixer?.isTransitioning == false })
        for tick in 12 ..< 16 {
            render(tick: tick, inputTick: tick - 2, extraLatency: latency)
        }
        #expect(output.isContinuous)
        #expect(calcMaximumStep(output.samples(0, firstWait ..< output.end)) < 0.004)
        #expect(output.samples(0, output.end - 1024 ..< output.end).allSatisfy { $0 == 0 })
        try #require(waitForMixerUpdate(preparation))
        #expect(processorPipelineQueue.sync { preparation.mixer == nil })
    }

    @Test
    func sourceEqualizerCanBeReplacedAndBypassedWithoutADrop() throws {
        let mixer = TestAudioMixer()
        let format = createFormat(.pcmFormatFloat32, 2, false)
        let dry = createSettings()
        var wet = dry
        wet.effects = [.equalizer(.init(gain: -12))]
        mixer.setSources([dry])
        let source = try #require(mixer.sources.first)
        let output = Output()
        for tick in 0 ..< 24 {
            if tick == 8 {
                mixer.setSources([wet])
            } else if tick == 16 {
                mixer.setSources([dry])
            }
            mixer.appendBuiltin(createSampleBuffer(format, tick) { createSine($0, $1) }, createTime(tick))
            while let block = mixer.renderNextBlock(now: createTime(tick + 1)) {
                output.append(block)
            }
        }
        #expect(mixer.sources.first === source)
        #expect(mixer.numberOfSkips == 0)
        #expect(output.isContinuous)
        #expect(calcMaximumStep(output.samples(0, 1024 ..< 20 * 1024)) < 0.067)
        #expect(output.samples(0, 12 * 1024 ..< 13 * 1024).map { abs($0) }.max() ?? 1 < 0.15)
        #expect(output.samples(0, 18 * 1024 ..< 19 * 1024) == createSine(18 * 1024 ..< 19 * 1024))
    }

    @Test
    func sourceDynamicsChangesCompensateLookaheadWithoutRepeatingSamples() throws {
        let mixer = TestAudioMixer()
        let format = createFormat(.pcmFormatFloat32, 2, false)
        let dry = createSettings(sends: (1, 0))
        var wet = dry
        wet.effects = [.compressor(.init()), .expander(.init(ratio: 1))]
        mixer.setSources([dry])
        let output = Output()
        let recording = Output()
        let dynamics = wet.effects.compactMap { $0.makeStage() }
        try #require(dynamics.count == 2)
        let latency = dynamics.reduce(0) { $0 + $1.latency }
        #expect(latency > 0)
        for tick in 0 ..< 24 {
            if tick == 8 {
                mixer.setSources([wet])
                #expect(mixer.latency == 2400 + latency)
            } else if tick == 16 {
                mixer.setSources([dry])
            }
            mixer.appendBuiltin(createSampleBuffer(format, tick) { _, frame in
                dynamicsFixture(frame)
            }, createTime(tick))
            while let block = mixer.renderNextBlock(now: createTime(tick + 1)) {
                output.append(block)
                recording.append(block, recording: true)
            }
        }
        #expect(mixer.latency == 2400)
        #expect(mixer.numberOfSkips == 0)
        #expect(output.isContinuous && recording.isContinuous)
        #expect(output.presentationTimeStamps == recording.presentationTimeStamps)
        let active = 10 * 1024 ..< 14 * 1024
        let processed = output.samples(0, active)
        let meanLevel = processed.reduce(Float(0)) { $0 + abs($1) } / Float(processed.count)
        #expect(meanLevel < 0.4)
        let frames = 1024 ..< 20 * 1024
        #expect(zip(output.samples(0, frames), frames).allSatisfy {
            abs($0) > 0.01 && $0.sign == dynamicsFixture($1).sign
        })
        let bypassed = 18 * 1024 ..< 20 * 1024
        #expect(output.samples(0, bypassed) == bypassed.map(dynamicsFixture))
        #expect(recording.samples(0, frames).allSatisfy { $0 == 0 })
    }

    @Test
    func neutralEqualizerEditPreservesVoiceRelease() {
        let edited = TestAudioMixer()
        let reference = TestAudioMixer()
        let format = createFormat(.pcmFormatFloat32, 2, false)
        let voice = createSettings(voice: true)
        edited.setSources([voice])
        reference.setSources([voice])
        let output = Output()
        let expected = Output()
        for tick in 0 ..< 28 {
            if tick == 12 {
                var wet = voice
                wet.effects = [.equalizer(.init(gain: 0))]
                edited.setSources([wet])
            }
            let buffer = createSampleBuffer(format, tick) { channel, frame in
                createSine(channel, frame) * (frame < 10 * 1024 ? 1 : 0.12)
            }
            edited.appendBuiltin(buffer, createTime(tick))
            reference.appendBuiltin(buffer, createTime(tick))
            while let block = edited.renderNextBlock(now: createTime(tick + 1)) {
                output.append(block)
            }
            while let block = reference.renderNextBlock(now: createTime(tick + 1)) {
                expected.append(block)
            }
        }
        #expect(output.isContinuous)
        let release = 10 * 1024 ..< 20 * 1024
        #expect(zip(output.samples(0, release), expected.samples(0, release)).allSatisfy {
            abs($0 - $1) < 0.00001
        })
    }

    @Test
    func masterEqualizerProcessesBothRoutesWithoutMovingTheirTimestamps() {
        let mixer = TestAudioMixer()
        let format = createFormat(.pcmFormatFloat32, 2, false)
        mixer.setSources([
            createSettings(id: "stream", channel: 0, sends: (1, 0)),
            createSettings(id: "recording", channel: 1, sends: (0, 1)),
        ])
        let stream = Output()
        let recording = Output()
        for tick in 0 ..< 24 {
            if tick == 8 {
                mixer.setMasterEffects([.equalizer(.init(gain: -12))])
            } else if tick == 16 {
                mixer.setMasterEffects([])
            }
            mixer.appendBuiltin(createSampleBuffer(format, tick) {
                $0 == 0 ? createSine($0, $1) : -0.5 * createSine($0, $1)
            }, createTime(tick))
            while let block = mixer.renderNextBlock(now: createTime(tick + 1)) {
                stream.append(block)
                recording.append(block, recording: true)
            }
        }
        #expect(stream.isContinuous && recording.isContinuous)
        #expect(recording.presentationTimeStamps == stream.presentationTimeStamps)
        let frames = 1024 ..< 20 * 1024
        #expect(recording.samples(0, frames) == stream.samples(0, frames).map { -0.5 * $0 })
        #expect(calcMaximumStep(stream.samples(0, frames)) < 0.067)
        #expect(stream.samples(0, 12 * 1024 ..< 13 * 1024).map { abs($0) }.max() ?? 1 < 0.15)
        #expect(stream.samples(0, 18 * 1024 ..< 19 * 1024) == createSine(18 * 1024 ..< 19 * 1024))
    }

    @Test(arguments: [true, false])
    func equalizerPrimesANarrowLowBandBeforeTheFade(onMaster: Bool) throws {
        let frequency: Float = 80
        let band = AudioMixerEqualizer(frequency: frequency, gain: 18, bandwidth: 0.05)
        let equalizer = try #require(AudioMixerEffectSettings.equalizer(band).makeStage())
        let mixer = TestAudioMixer()
        let format = createFormat(.pcmFormatFloat32, 2, false)
        let drySource = createSettings(sends: (1, 0.5))
        mixer.setSources([drySource])
        let output = Output()
        let recording = Output()
        func sample(_ frame: Int) -> Float {
            0.1 * sin(Float(frame) * 2 * .pi * frequency / 48000)
        }
        for tick in 0 ..< 28 {
            if tick == 12 {
                if onMaster {
                    mixer.setMasterEffects([.equalizer(band)])
                } else {
                    var source = drySource
                    source.effects = [.equalizer(band)]
                    mixer.setSources([source])
                }
            }
            mixer.appendBuiltin(
                createSampleBuffer(format, tick) { _, frame in sample(frame) },
                createTime(tick)
            )
            while let block = mixer.renderNextBlock(now: createTime(tick + 1)) {
                try #require(block.recordingBuffer != nil)
                output.append(block)
                recording.append(block, recording: true)
            }
        }
        let fadeStart = 12 * 1024 - 2400
        let previous = (fadeStart - 1024 ..< fadeStart).map(sample)
        var left = previous
        var right = previous
        #expect(equalizer.process(&left, &right))
        let frames = fadeStart ..< fadeStart + 1024
        let dry = frames.map(sample)
        left = dry
        right = dry
        #expect(equalizer.process(&left, &right))
        let actual = output.samples(0, frames)
        let primed = left.indices.map { dry[$0] + (left[$0] - dry[$0]) * Float($0) / 1023 }
        let maximumError = zip(actual, primed).map { abs($0 - $1) }.max()
        #expect((maximumError ?? 1) < 0.0001)
        #expect(calcMaximumStep(output.samples(0, fadeStart - 1 ..< fadeStart + 4096)) < 0.008)
        let recorded = recording.samples(0, frames)
        let recordingError = zip(recorded, primed).map { abs($0 - 0.5 * $1) }.max()
        #expect((recordingError ?? 1) < 0.0001)
        #expect(calcMaximumStep(recording.samples(0, fadeStart - 1 ..< fadeStart + 4096)) < 0.004)
        #expect(output.isContinuous && recording.isContinuous)
        #expect(output.presentationTimeStamps == recording.presentationTimeStamps)
    }

    @Test
    func masterEqualizerAttenuatesBeforeTheLimiter() {
        let mixer = TestAudioMixer()
        let format = createFormat(.pcmFormatFloat32, 2, false)
        mixer.setSources([createSettings()])
        mixer.setMasterEffects([.equalizer(.init(gain: -24))])
        let stream = Output()
        let recording = Output()
        for tick in 0 ..< 16 {
            mixer.appendBuiltin(createSampleBuffer(format, tick) { 4 * createSine($0, $1) }, createTime(tick))
            while let block = mixer.renderNextBlock(now: createTime(tick + 1)) {
                stream.append(block)
                recording.append(block, recording: true)
            }
        }
        let frames = 8 * 1024 ..< 10 * 1024
        let samples = stream.samples(0, frames)
        let peak = samples.map { abs($0) }.max() ?? 0
        #expect(peak > 0.12 && peak < 0.14)
        #expect(recording.samples(0, frames) == samples)
    }

    @Test
    func sumsSources() {
        let mixer = TestAudioMixer()
        let builtinFormat = createFormat(.pcmFormatFloat32, 2, false)
        let bufferedFormat = createFormat(.pcmFormatInt16, 2, true)
        mixer.setSources([
            createSettings(id: "builtin"),
            createSettings(id: "buffered", bufferedAudio: cameraId, gain: 0.25),
        ])
        let output = Output()
        for tick in 0 ..< 40 {
            mixer.appendBuiltin(createSampleBuffer(builtinFormat, tick), createTime(tick))
            mixer.appendBuffered(
                cameraId: cameraId,
                createSampleBuffer(bufferedFormat, tick) { createNoise($0 + 2, $1) }
            )
            while let block = mixer.renderNextBlock(now: createTime(tick + 1)) {
                output.append(block)
            }
        }
        let frames = 256 ..< output.end
        let left = zip(createNoise(0, frames), createNoise(2, frames)).map { $0 + 0.25 * $1 }
        let right = zip(createNoise(1, frames), createNoise(3, frames)).map { $0 + 0.25 * $1 }
        #expect(output.isContinuous)
        #expect(output.samples(0, frames) == left)
        #expect(output.samples(1, frames) == right)
    }

    @Test(arguments: [
        GainCase(sourceGain: 0.25, masterGain: 1, masterMuted: false, sends: (1, 1)),
        GainCase(sourceGain: 1, masterGain: 0.25, masterMuted: false, sends: (1, 0)),
        GainCase(sourceGain: 1, masterGain: 1, masterMuted: true, sends: (1, 1)),
        GainCase(sourceGain: 1, masterGain: 1, masterMuted: false, sends: (1, 0)),
        GainCase(sourceGain: 1, masterGain: 1, masterMuted: false, sends: (0, 1)),
    ], [false, true])
    func rampsGainChanges(_ testCase: GainCase, _ recording: Bool) {
        let mixer = TestAudioMixer()
        let format = createFormat(.pcmFormatFloat32, 1, false)
        mixer.setSources([createSettings()])
        let output = Output()
        for tick in 0 ..< 40 {
            if tick == 10 {
                mixer.setMasterGain(testCase.masterGain)
                mixer.setMasterMuted(testCase.masterMuted)
            } else if tick == 20 {
                mixer.setSources([createSettings(gain: testCase.sourceGain, sends: testCase.sends)])
            }
            mixer.appendBuiltin(createSampleBuffer(format, tick) { _, _ in 0.5 }, createTime(tick))
            while let block = mixer.renderNextBlock(now: createTime(tick + 1)) {
                output.append(block, recording: recording)
            }
        }
        let send = recording ? testCase.sends.recording : testCase.sends.stream
        let gain = testCase.masterMuted ? 0 : 0.5 * testCase.sourceGain * testCase.masterGain * send
        let samples = output.samples(1, 4096 ..< output.end)
        #expect(output.isContinuous)
        #expect(output.presentationTimeStamps.count == 40)
        #expect(samples.first == 0.5)
        #expect(samples.last == gain)
        #expect(calcMaximumStep(samples) < (0.5 - gain) / 1024 + 1e-6)
    }

    @Test(arguments: [
        DelayCase(delay: 0, frame: 30000, latency: 2400),
        DelayCase(delay: 0.0001, frame: 30005, latency: 2400),
        DelayCase(delay: 2, frame: 126_000, latency: 2400),
        DelayCase(delay: -0.2, frame: 20400, latency: 12000),
        DelayCase(delay: -0.5, frame: 6000, latency: 26400),
    ])
    func delaysContent(_ testCase: DelayCase) {
        let mixer = TestAudioMixer()
        let format = createFormat(.pcmFormatFloat32, 1, false)
        mixer.setSources([createSettings(delay: testCase.delay)])
        let output = Output()
        for tick in 0 ..< 130 {
            mixer.appendBuiltin(createSampleBuffer(format, tick) { _, frame in frame == 30000 ? 0.5 : 0 },
                                createTime(tick))
            while let block = mixer.renderNextBlock(now: createTime(tick + 1)) {
                output.append(block)
            }
        }
        #expect(mixer.latency == testCase.latency)
        #expect(output.isContinuous)
        #expect(output.presentationTimeStamps.first == startIndex - testCase.latency - limiterLatency)
        #expect(output.frames { $0 != 0 } == [testCase.frame])
        #expect(output.samples(0, testCase.frame ..< testCase.frame + 1) == [0.5])
        #expect(output.samples(1, testCase.frame ..< testCase.frame + 1) == [0.5])
    }

    @Test(arguments: [
        BuiltinDelayCase(builtinDelay: 0, frame: 30000),
        BuiltinDelayCase(builtinDelay: 0.07, frame: 33360),
    ])
    func builtinDelayMovesContentOnce(_ testCase: BuiltinDelayCase) {
        let mixer = TestAudioMixer()
        let format = createFormat(.pcmFormatFloat32, 1, false)
        mixer.setSources([createSettings()])
        let output = Output()
        for tick in 0 ..< 60 {
            mixer.appendBuiltin(createSampleBuffer(format, tick) { _, frame in frame == 30000 ? 0.5 : 0 },
                                createTime(tick),
                                delay: testCase.builtinDelay)
            while let block = mixer.renderNextBlock(now: createTime(tick + 1)) {
                output.append(block)
            }
        }
        #expect(output.isContinuous)
        #expect(output.presentationTimeStamps.first == startIndex - 2400 - limiterLatency)
        #expect(output.frames { $0 != 0 } == [testCase.frame])
    }

    @Test
    func negativeDelayPausesDelivery() {
        let mixer = TestAudioMixer()
        let format = createFormat(.pcmFormatFloat32, 2, false)
        mixer.setSources([createSettings()])
        let output = Output()
        var blocksPerTick: [Int] = []
        for tick in 0 ..< 60 {
            if tick == 20 {
                mixer.setSources([createSettings(delay: -0.2)])
            } else if tick == 40 {
                mixer.setSources([createSettings()])
            }
            mixer.appendBuiltin(createSampleBuffer(format, tick), createTime(tick))
            var blocks = 0
            while let block = mixer.renderNextBlock(now: createTime(tick + 1)) {
                output.append(block)
                blocks += 1
            }
            blocksPerTick.append(blocks)
        }
        let early = 20 * 1024 - 2400 + 256 ..< 30 * 1024 - 2400
        let late = 30 * 1024 - 2400 + 256 ..< output.end
        let earlyContent = createNoise(0, early.lowerBound + 9600 ..< early.upperBound + 9600)
        #expect(mixer.latency == 2400)
        #expect(output.isContinuous)
        #expect(output.presentationTimeStamps.count == 60)
        #expect(blocksPerTick[20 ..< 30].allSatisfy { $0 == 0 })
        #expect(output.samples(0, early) == earlyContent)
        #expect(output.samples(1, late) == createNoise(1, late))
    }

    @Test(arguments: [
        DelayChangeCase(testDescription: "half a period", delays: [20: 0.0105]),
        DelayChangeCase(
            testDescription: "slider drag",
            delays: Dictionary(uniqueKeysWithValues: (20 ..< 40).map { ($0, Double($0 - 19) * 0.0123) })
        ),
    ], [false, true])
    func delayChangesCrossfade(_ testCase: DelayChangeCase, _ voice: Bool) throws {
        let mixer = TestAudioMixer()
        let format = createFormat(.pcmFormatFloat32, 1, false)
        mixer.setSources([createSettings(voice: voice)])
        let output = Output()
        for tick in 0 ..< 80 {
            if let delay = testCase.delays[tick] {
                mixer.setSources([createSettings(delay: delay, voice: voice)])
            }
            mixer.appendBuiltin(createSampleBuffer(format, tick, createSine), createTime(tick))
            while let block = mixer.renderNextBlock(now: createTime(tick + 1)) {
                output.append(block)
            }
        }
        let samples = output.samples(0, 2048 ..< output.end)
        let peak = try #require(samples.map { abs($0) }.max())
        #expect(output.isContinuous)
        #expect(voice || peak <= 0.5)
        #expect(calcMaximumStep(samples) < peak * (2 * maximumSineStep + 2 * Float.pi / 512))
    }

    @Test
    func delayChangesSeekOnceToNewest() {
        let mixer = TestAudioMixer()
        let format = createFormat(.pcmFormatFloat32, 1, false)
        mixer.setSources([createSettings()])
        let output = Output()
        for tick in 0 ..< 40 {
            if tick == 20 {
                mixer.setSources([createSettings(delay: 0.0123)])
                mixer.setSources([createSettings(delay: 0.0246)])
                mixer.setSources([createSettings(delay: 0.0369)])
            }
            mixer.appendBuiltin(createSampleBuffer(format, tick, createSine), createTime(tick))
            while let block = mixer.renderNextBlock(now: createTime(tick + 1)) {
                output.append(block)
            }
        }
        let seek = 20 * 1024 - 2400
        let frames = seek + 256 ..< output.end
        let crossfade = output.samples(0, seek - 1 ..< seek + 257)
        let delayed = createSine(frames.lowerBound - 1771 ..< frames.upperBound - 1771)
        #expect(output.isContinuous)
        #expect(output.samples(0, 256 ..< seek) == createSine(256 ..< seek))
        #expect(output.samples(0, frames) == delayed)
        #expect(calcMaximumStep(crossfade) < maximumSineStep + Float.pi / 512)
    }

    @Test
    func delayChangeToUnwrittenInputFadesOut() {
        let mixer = TestAudioMixer()
        let format = createFormat(.pcmFormatFloat32, 1, false)
        mixer.setSources([createSettings()])
        let output = Output()
        for tick in 0 ..< 60 {
            if tick < 20 {
                mixer.appendBuiltin(createSampleBuffer(format, tick) { _, _ in 0.5 }, createTime(tick))
            }
            if tick == 20 {
                mixer.setSources([createSettings(delay: -0.2)])
            }
            while let block = mixer.renderNextBlock(now: createTime(tick + 1)) {
                output.append(block)
            }
        }
        let end = 20 * 1024
        #expect(output.isContinuous)
        #expect(output.samples(0, 4096 ..< end - 256).allSatisfy { $0 == 0.5 })
        #expect(output.samples(0, end - 256 ..< end) == createFallingFade().map { 0.5 * $0 })
        #expect(output.samples(0, end ..< output.end).allSatisfy { $0 == 0 })
    }

    @Test
    func channelsMapChangeCrossfades() {
        let mixer = TestAudioMixer()
        let format = createFormat(.pcmFormatFloat32, 2, false)
        mixer.setSources([createSettings(channelsMap: [0: 0, 1: 0])])
        let output = Output()
        for tick in 0 ..< 40 {
            if tick == 20 {
                mixer.setSources([createSettings(channelsMap: [0: 1, 1: 1])])
            }
            mixer.appendBuiltin(createSampleBuffer(format, tick) { channel, _ in channel == 0 ? 0.5 : 0.25 },
                                createTime(tick))
            while let block = mixer.renderNextBlock(now: createTime(tick + 1)) {
                output.append(block)
            }
        }
        let samples = output.samples(1, 4096 ..< output.end)
        #expect(output.isContinuous)
        #expect(samples.first == 0.5)
        #expect(samples.last == 0.25)
        #expect(calcMaximumStep(samples) < 0.25 / 1024 + 1e-6)
        #expect(mixer.sources.count == 1)
    }

    @Test
    func removedSourcesFadeOut() {
        let mixer = TestAudioMixer()
        let format = createFormat(.pcmFormatFloat32, 1, false)
        mixer.setSources([
            createSettings(id: "builtin"),
            createSettings(id: "buffered", bufferedAudio: cameraId),
        ])
        let output = Output()
        for tick in 0 ..< 50 {
            if tick == 20 {
                mixer.setSources([createSettings(id: "builtin")])
            } else if tick == 30 {
                mixer.setSources([])
            }
            mixer.appendBuiltin(createSampleBuffer(format, tick) { _, _ in 0.25 }, createTime(tick))
            mixer.appendBuffered(cameraId: cameraId, createSampleBuffer(format, tick) { _, _ in 0.5 })
            while let block = mixer.renderNextBlock(now: createTime(tick + 1)) {
                output.append(block)
            }
        }
        let samples = output.samples(0, 4096 ..< output.end)
        #expect(output.isContinuous)
        #expect(output.presentationTimeStamps.count == 50)
        #expect(samples.first == 0.75)
        #expect(output.samples(0, 20 * 1024 ..< 27 * 1024).allSatisfy { $0 == 0.25 })
        #expect(samples.suffix(15 * 1024).allSatisfy { $0 == 0 })
        #expect(calcMaximumStep(samples) < 0.5 / 1024 + 1e-6)
        #expect(mixer.sources.isEmpty)
        #expect(mixer.builtinInput == nil)
        #expect(mixer.bufferedInputs.isEmpty)
    }

    @Test
    func replacedSourceDoesNotReplay() {
        let mixer = TestAudioMixer()
        let format = createFormat(.pcmFormatFloat32, 1, false)
        mixer.setSources([createSettings(id: "usb")])
        let output = Output()
        for tick in 0 ..< 160 {
            if tick == 60 {
                mixer.setSources([createSettings(id: "builtin", delay: 1.5)])
            }
            mixer.appendBuiltin(createSampleBuffer(format, tick) { _, frame in
                frame == 30000 || frame == 70000 ? 0.5 : 0
            }, createTime(tick))
            while let block = mixer.renderNextBlock(now: createTime(tick + 1)) {
                output.append(block)
            }
        }
        #expect(output.isContinuous)
        #expect(output.frames { $0 != 0 } == [30000, 142_000])
        #expect(output.samples(0, 142_000 ..< 142_001) == [0.5])
    }

    @Test(arguments: [600, 672, 928])
    func stalledSourceFadesOut(_ lastFrameLength: Int) {
        let mixer = TestAudioMixer()
        let format = createFormat(.pcmFormatFloat32, 2, false)
        mixer.setSources([createSettings()])
        let output = Output()
        for tick in 0 ..< 40 {
            if tick < 20 {
                let frameLength = tick == 19 ? lastFrameLength : 1024
                let sampleBuffer = createSampleBuffer(format, tick, frameLength: frameLength) { _, _ in 0.5 }
                mixer.appendBuiltin(sampleBuffer, createTime(tick))
            }
            while let block = mixer.renderNextBlock(now: createTime(tick + 1)) {
                output.append(block)
            }
        }
        let end = 19 * 1024 + lastFrameLength
        #expect(output.isContinuous)
        #expect(output.presentationTimeStamps.count == 40)
        #expect(output.samples(0, 4096 ..< end - 256).allSatisfy { $0 == 0.5 })
        #expect(output.samples(0, end - 256 ..< end) == createFallingFade().map { 0.5 * $0 })
        #expect(output.samples(1, end ..< output.end).allSatisfy { $0 == 0 })
    }

    @Test
    func backwardResyncSilencesSource() {
        let mixer = TestAudioMixer()
        let format = createFormat(.pcmFormatFloat32, 1, false)
        mixer.setSources([createSettings()])
        let output = Output()
        for tick in 0 ..< 40 {
            let early = CMTime(value: tick == 20 ? 3300 : 0, timescale: 48000)
            mixer.appendBuiltin(createSampleBuffer(format, tick) { _, _ in 0.5 }, createTime(tick) - early)
            while let block = mixer.renderNextBlock(now: createTime(tick + 1)) {
                output.append(block)
            }
        }
        let cut = 20 * 1024 - 2400
        let resync = 21 * 1024
        #expect(output.isContinuous)
        #expect(output.samples(0, 4096 ..< cut).allSatisfy { $0 == 0.5 })
        #expect(output.samples(0, cut ..< resync).allSatisfy { $0 == 0 })
        #expect(output.samples(0, resync ..< resync + 256) == createRisingFade().map { 0.5 * $0 })
        #expect(output.samples(0, resync + 256 ..< output.end).allSatisfy { $0 == 0.5 })
    }

    @Test(arguments: [false, true])
    func stalledSourceFadesBackIn(_ lateInput: Bool) {
        let mixer = TestAudioMixer()
        let format = createFormat(.pcmFormatFloat32, 1, false)
        mixer.setSources([createSettings()])
        let output = Output()
        for tick in 0 ..< 50 {
            if tick < 20 || tick >= 30 {
                mixer.appendBuiltin(createSampleBuffer(format, tick) { _, _ in 0.5 }, createTime(tick))
            } else if lateInput, tick == 29 {
                for lateTick in 20 ..< 30 {
                    mixer.appendBuiltin(createSampleBuffer(format, lateTick) { _, _ in 0.5 },
                                        createTime(lateTick))
                }
            }
            while let block = mixer.renderNextBlock(now: createTime(tick + 1)) {
                output.append(block)
            }
        }
        let samples = output.samples(0, 4096 ..< output.end)
        #expect(output.isContinuous)
        #expect(samples.contains(0))
        #expect(samples.suffix(5 * 1024).allSatisfy { $0 == 0.5 })
        #expect(calcMaximumStep(samples) < 0.5 * Float.pi / 512 + 1e-6)
    }

    @Test
    func skipsForwardWhenOneSecondBehind() {
        let mixer = TestAudioMixer()
        let format = createFormat(.pcmFormatFloat32, 1, false)
        mixer.setSources([createSettings()])
        let output = Output()
        var blocksPerTick: [Int] = []
        for tick in 0 ..< 100 {
            mixer.appendBuiltin(createSampleBuffer(format, tick, createSine), createTime(tick))
            guard tick < 20 || tick >= 90 else {
                continue
            }
            var blocks = 0
            while let block = mixer.renderNextBlock(now: createTime(tick + 1)) {
                output.append(block)
                blocks += 1
            }
            blocksPerTick.append(blocks)
        }
        let steps = zip(output.presentationTimeStamps, output.presentationTimeStamps.dropFirst())
            .map { $1 - $0 }
        let skipped = 91 * 1024 - 3424
        let latency = Int(limiterLatency)
        let samples = Array(output.left.suffix(10 * 1024))
        let fade = skipped ..< skipped + 256
        let frames = skipped + 256 ..< skipped + 10 * 1024 - latency
        #expect(blocksPerTick.allSatisfy { $0 == 1 })
        #expect(steps.filter { $0 != 1024 } == [Int64(71 * 1024)])
        #expect(output.presentationTimeStamps[20] == startIndex + Int64(skipped) - limiterLatency)
        #expect(mixer.numberOfSkips == 1)
        #expect(samples.prefix(latency).allSatisfy { $0 == 0 })
        #expect(Array(samples[latency ..< latency + 256]) == zip(createSine(fade), createRisingFade()).map(*))
        #expect(samples.suffix(frames.count) == createSine(frames))
    }

    @Test(arguments: [
        DelayedCase(testDescription: "across a late tick", ahead: 0, lateTicks: 150 ..< 160),
        DelayedCase(testDescription: "written 4 s ahead", ahead: 192_000, lateTicks: 0 ..< 0),
    ])
    func delayedInputIsKept(_ testCase: DelayedCase) {
        let mixer = TestAudioMixer()
        let format = createFormat(.pcmFormatFloat32, 1, false)
        mixer.setSources([
            createSettings(id: "delayed", bufferedAudio: cameraId, delay: 2),
            createSettings(id: "early", delay: -0.5),
        ])
        let output = Output()
        for tick in 0 ..< 320 {
            let presentationTimeStamp = createTime(tick) + CMTime(value: testCase.ahead, timescale: 48000)
            let sampleBuffer = createSampleBuffer(format, 1024 * tick, presentationTimeStamp) { _, _ in 0.5 }
            mixer.appendBuffered(cameraId: cameraId, sampleBuffer)
            mixer.appendBuiltin(createSampleBuffer(format, tick) { _, _ in 0 }, createTime(tick))
            guard !testCase.lateTicks.contains(tick) else {
                continue
            }
            while let block = mixer.renderNextBlock(now: createTime(tick + 1)) {
                output.append(block)
            }
        }
        let start = 96000 + Int(testCase.ahead)
        #expect(mixer.latency == 26400)
        #expect(output.isContinuous)
        #expect(output.samples(0, -26400 ..< start).allSatisfy { $0 == 0 })
        #expect(output.samples(0, start + 256 ..< output.end).allSatisfy { $0 == 0.5 })
        #expect(mixer.numberOfSkips == 0)
    }

    @Test
    func overwrittenInputIsSilent() {
        let mixer = TestAudioMixer()
        let format = createFormat(.pcmFormatFloat32, 1, false)
        mixer.setSources([createSettings(delay: 2)])
        let output = Output()
        for tick in 0 ..< 250 {
            let ahead = CMTime(value: tick < 150 ? 0 : 432_000, timescale: 48000)
            mixer.appendBuiltin(createSampleBuffer(format, tick) { _, _ in 0.5 }, createTime(tick) + ahead)
            while let block = mixer.renderNextBlock(now: createTime(tick + 1)) {
                output.append(block)
            }
        }
        let overwritten = 150 * 1024 - 2400
        #expect(output.isContinuous)
        #expect(output.samples(0, 96256 ..< overwritten).allSatisfy { $0 == 0.5 })
        #expect(output.samples(0, overwritten ..< output.end).allSatisfy { $0 == 0 })
    }

    @Test(arguments: [
        ChannelCase(testDescription: "channels 3 and 4", channelsMap: [0: 2, 1: 3], left: 2, right: 3),
        ChannelCase(testDescription: "channel 2 on both sides", channelsMap: [0: 1, 1: 1], left: 1, right: 1),
        ChannelCase(testDescription: "silent left", channelsMap: [0: -1, 1: 2], left: -1, right: 2),
        ChannelCase(testDescription: "missing device channels", channelsMap: [0: 4, 1: 7], left: 0, right: 1),
        ChannelCase(testDescription: "channel mic 3", channelsMap: [:], channel: 2, left: 2, right: 2),
        ChannelCase(testDescription: "missing channel 5", channelsMap: [:], channel: 4, left: -1, right: -1),
    ])
    func picksChannels(_ testCase: ChannelCase) {
        let mixer = TestAudioMixer()
        let format = createFormat(.pcmFormatFloat32, 4, false)
        mixer.setSources([createSettings(channelsMap: testCase.channelsMap, channel: testCase.channel)])
        let output = Output()
        for tick in 0 ..< 20 {
            mixer.appendBuiltin(createSampleBuffer(format, tick), createTime(tick))
            while let block = mixer.renderNextBlock(now: createTime(tick + 1)) {
                output.append(block)
            }
        }
        let frames = 256 ..< output.end
        #expect(output.samples(0, frames) == createNoise(testCase.left, frames))
        #expect(output.samples(1, frames) == createNoise(testCase.right, frames))
    }

    @Test(arguments: [[0: 0, 1: 1], [0: 5, 1: 6]])
    func mixesInMono(_ channelsMap: [Int: Int]) {
        let mixer = TestAudioMixer()
        mixer.setStereo(false)
        let format = createFormat(.pcmFormatFloat32, 2, false)
        mixer.setSources([createSettings(channelsMap: channelsMap, sends: (1, 0.5), pan: 1)])
        let output = Output()
        let recording = Output()
        for tick in 0 ..< 20 {
            mixer.appendBuiltin(createSampleBuffer(format, tick), createTime(tick))
            while let block = mixer.renderNextBlock(now: createTime(tick + 1)) {
                output.append(block)
                recording.append(block, recording: true)
            }
        }
        let frames = 256 ..< output.end
        let half = createNoise(0, frames).map { 0.5 * $0 }
        #expect(output.numbersOfChannels == [1])
        #expect(recording.numbersOfChannels == [1])
        #expect(output.samples(0, frames) == createNoise(0, frames))
        #expect(zip(recording.samples(0, frames), half).allSatisfy { abs($0 - $1) < 1e-6 })
    }

    @Test
    func switchesBetweenMonoAndStereo() {
        let mixer = TestAudioMixer()
        let format = createFormat(.pcmFormatFloat32, 2, false)
        mixer.setSources([createSettings(pan: 0.5)])
        let output = Output()
        for tick in 0 ..< 36 {
            if tick == 12 || tick == 24 {
                mixer.setStereo(tick == 24)
            }
            if tick == 16 {
                mixer.setSources([createSettings(pan: -0.5)])
            }
            mixer.appendBuiltin(
                createSampleBuffer(format, tick) { 0.5 * createNoise($0, $1) },
                createTime(tick)
            )
            while let block = mixer.renderNextBlock(now: createTime(tick + 1)) {
                output.append(block)
            }
        }
        let gains = makeAudioMixerPanGains(pan: 0.5)
        let gainsAgain = makeAudioMixerPanGains(pan: -0.5)
        let stereo = 4096 ..< 8192
        let mono = 13312 ..< 20480
        let stereoAgain = 26624 ..< 30720
        #expect(output.numbersOfChannels == [1, 2])
        #expect(zip(output.samples(0, stereo), createNoise(0, stereo))
            .allSatisfy { abs($0 - 0.5 * $1 * gains.left) < 1e-6 })
        #expect(zip(output.samples(1, stereo), createNoise(1, stereo))
            .allSatisfy { abs($0 - 0.5 * $1 * gains.right) < 1e-6 })
        #expect(output.samples(0, mono) == createNoise(0, mono).map { 0.5 * $0 })
        #expect(output.samples(1, mono).allSatisfy { $0.isNaN })
        #expect(zip(output.samples(1, stereoAgain), createNoise(1, stereoAgain))
            .allSatisfy { abs($0 - 0.5 * $1 * gainsAgain.right) < 1e-6 })
    }

    @Test(arguments: [
        PanCase(pan: 0, left: 1, right: 1),
        PanCase(pan: -1, left: sqrt2, right: 0),
        PanCase(pan: 1, left: 0, right: sqrt2),
        PanCase(pan: -0.5, left: 0.92387953 * sqrt2, right: 0.38268343 * sqrt2),
        PanCase(pan: 0.5, left: 0.38268343 * sqrt2, right: 0.92387953 * sqrt2),
        PanCase(pan: -3, left: sqrt2, right: 0),
    ])
    func panKeepsPower(_ testCase: PanCase) {
        let gains = makeAudioMixerPanGains(pan: testCase.pan)
        #expect(abs(gains.left - testCase.left) < 1e-6)
        #expect(abs(gains.right - testCase.right) < 1e-6)
        #expect(abs(gains.left * gains.left + gains.right * gains.right - 2) < 1e-5)
    }

    @Test(arguments: [1, 2], [-1, -0.5, 0, 0.5, 1] as [Float])
    func pansSources(_ numberOfChannels: Int, _ pan: Float) {
        let mixer = TestAudioMixer()
        let format = createFormat(.pcmFormatFloat32, numberOfChannels, false)
        mixer.setSources([createSettings(pan: pan)])
        let output = Output()
        for tick in 0 ..< 20 {
            mixer.appendBuiltin(
                createSampleBuffer(format, tick) { 0.5 * createNoise($0, $1) },
                createTime(tick)
            )
            while let block = mixer.renderNextBlock(now: createTime(tick + 1)) {
                output.append(block)
            }
        }
        let gains = makeAudioMixerPanGains(pan: pan)
        let frames = 256 ..< output.end
        let left = createNoise(0, frames).map { 0.5 * $0 * gains.left }
        let right = createNoise(numberOfChannels - 1, frames).map { 0.5 * $0 * gains.right }
        #expect(output.isContinuous)
        #expect(zip(output.samples(0, frames), left).allSatisfy { abs($0 - $1) < 1e-6 })
        #expect(zip(output.samples(1, frames), right).allSatisfy { abs($0 - $1) < 1e-6 })
    }

    @Test(arguments: [false, true])
    func panChangesRamp(_ recording: Bool) throws {
        let mixer = TestAudioMixer()
        let format = createFormat(.pcmFormatFloat32, 1, false)
        mixer.setSources([createSettings(sends: (1, recording ? 0.5 : 1))])
        let output = Output()
        for tick in 0 ..< 40 {
            if tick == 20 {
                mixer.setSources([createSettings(sends: (1, recording ? 0.5 : 1), pan: -1)])
            }
            mixer.appendBuiltin(createSampleBuffer(format, tick) { _, _ in 0.25 }, createTime(tick))
            while let block = mixer.renderNextBlock(now: createTime(tick + 1)) {
                output.append(block, recording: recording)
            }
        }
        let level: Float = recording ? 0.125 : 0.25
        let left = output.samples(0, 4096 ..< output.end)
        let right = output.samples(1, 4096 ..< output.end)
        let last = try #require(left.last)
        #expect(output.isContinuous)
        #expect(left.first == level)
        #expect(right.first == level)
        #expect(abs(last - level * sqrt2) < 1e-6)
        #expect(right.last == 0)
        #expect(calcMaximumStep(left) < level * (sqrt2 - 1) / 1024 + 1e-6)
        #expect(calcMaximumStep(right) < level / 1024 + 1e-6)
    }

    @Test
    func sharesOneInputPerDevice() {
        let mixer = TestAudioMixer()
        mixer.setSources([
            createSettings(id: "1", channelsMap: [0: 0, 1: 0]),
            createSettings(id: "2", channelsMap: [0: 1, 1: 1]),
            createSettings(id: "3", bufferedAudio: cameraId, channelsMap: [0: 0, 1: 0]),
            createSettings(id: "4", bufferedAudio: cameraId, channelsMap: [0: 1, 1: 1]),
        ])
        #expect(mixer.sources.count == 4)
        #expect(mixer.builtinInput != nil)
        #expect(Array(mixer.bufferedInputs.keys) == [cameraId])
    }

    @Test
    func voiceLatencyIsCompensated() throws {
        let effects = makeAudioMixerVoiceEffects()
        try #require(effects.count == 2)
        let mixer = TestAudioMixer()
        let format = createFormat(.pcmFormatFloat32, 1, false)
        mixer.setSources([
            createSettings(id: "dry"),
            createSettings(id: "voice", bufferedAudio: cameraId, delay: -0.1, voice: true),
        ])
        let output = Output()
        for tick in 0 ..< 60 {
            mixer.appendBuiltin(createSampleBuffer(format, tick) { _, frame in frame == 30000 ? 0.5 : 0 },
                                createTime(tick))
            mixer.appendBuffered(
                cameraId: cameraId,
                createSampleBuffer(format, tick) { _, frame in frame == 44800 ? 0.5 : 0 }
            )
            while let block = mixer.renderNextBlock(now: createTime(tick + 1)) {
                output.append(block)
            }
        }
        let voice = output.samples(0, 35000 ..< 45000).map { abs($0) }
        #expect(mixer.latency == 2400 + 4800 + effects.reduce(0) { $0 + $1.latency })
        #expect(output.isContinuous)
        #expect(output.frames { $0 != 0 }.filter { $0 < 35000 } == [30000])
        #expect(output.samples(0, 30000 ..< 30001) == [0.5])
        #expect(try voice.firstIndex(of: #require(voice.max())) == 5000)
    }

    @Test
    func voiceStartsWithoutClick() throws {
        let mixer = TestAudioMixer()
        let format = createFormat(.pcmFormatFloat32, 1, false)
        mixer.setSources([createSettings()])
        let output = Output()
        for tick in 0 ..< 80 {
            if tick == 20 {
                mixer.setSources([createSettings(voice: true)])
            }
            if tick < 40 || tick >= 50 {
                mixer.appendBuiltin(createSampleBuffer(format, tick, createSine), createTime(tick))
            } else if tick == 49 {
                for lateTick in 40 ..< 50 {
                    mixer.appendBuiltin(
                        createSampleBuffer(format, lateTick, createSine),
                        createTime(lateTick)
                    )
                }
            }
            while let block = mixer.renderNextBlock(now: createTime(tick + 1)) {
                output.append(block)
            }
        }
        let samples = output.samples(0, 4096 ..< output.end)
        let peak = try #require(samples.map { abs($0) }.max())
        #expect(output.isContinuous)
        #expect(samples.contains(0))
        #expect(try #require(output.samples(0, 60 * 1024 ..< output.end).map { abs($0) }.max()) > 0.1)
        #expect(calcMaximumStep(samples) < peak * (2 * maximumSineStep + Float.pi / 512))
        #expect(mixer.sources.count == 1)
    }

    @Test(arguments: [
        SendsCase(testDescription: "stream and recording",
                  sends: (1, 1),
                  recordingBuffer: false,
                  stream: [30000, 31000],
                  recording: [30000, 31000]),
        SendsCase(testDescription: "stream",
                  sends: (1, 0),
                  recordingBuffer: true,
                  stream: [30000, 31000],
                  recording: [30000]),
        SendsCase(testDescription: "recording",
                  sends: (0, 1),
                  recordingBuffer: true,
                  stream: [30000],
                  recording: [30000, 31000]),
    ])
    func sendsToBuses(_ testCase: SendsCase) {
        let mixer = TestAudioMixer()
        let format = createFormat(.pcmFormatFloat32, 1, false)
        mixer.setSources([
            createSettings(id: "voice"),
            createSettings(id: "music", bufferedAudio: cameraId, sends: testCase.sends),
        ])
        let stream = Output()
        let recording = Output()
        var recordingTimeStamps: [Int64] = []
        for tick in 0 ..< 40 {
            mixer.appendBuiltin(createSampleBuffer(format, tick) { _, frame in frame == 30000 ? 0.5 : 0 },
                                createTime(tick))
            mixer.appendBuffered(
                cameraId: cameraId,
                createSampleBuffer(format, tick) { _, frame in frame == 31000 ? 0.5 : 0 }
            )
            while let block = mixer.renderNextBlock(now: createTime(tick + 1)) {
                stream.append(block)
                recording.append(block, recording: true)
                if block.recordingBuffer != nil {
                    recordingTimeStamps.append(block.presentationTimeStamp.value)
                }
            }
        }
        #expect(stream.frames { $0 != 0 } == testCase.stream)
        #expect(recording.frames { $0 != 0 } == testCase.recording)
        #expect(recordingTimeStamps == (testCase.recordingBuffer ? stream.presentationTimeStamps : []))
    }

    @Test
    func sendsChangeBackWithoutClick() {
        let mixer = TestAudioMixer()
        let format = createFormat(.pcmFormatFloat32, 1, false)
        mixer.setSources([createSettings(sends: (1, 0))])
        let output = Output()
        var numberOfRecordingBuffers = 0
        for tick in 0 ..< 40 {
            if tick == 20 {
                mixer.setSources([createSettings()])
            }
            mixer.appendBuiltin(createSampleBuffer(format, tick) { _, _ in 0.5 }, createTime(tick))
            while let block = mixer.renderNextBlock(now: createTime(tick + 1)) {
                output.append(block, recording: true)
                if block.recordingBuffer != nil {
                    numberOfRecordingBuffers += 1
                }
            }
        }
        let samples = output.samples(0, 4096 ..< output.end)
        #expect(samples.first == 0)
        #expect(samples.last == 0.5)
        #expect(calcMaximumStep(samples) < 0.5 / 1024 + 1e-6)
        #expect(numberOfRecordingBuffers == 22)
    }

    @Test
    func capturesInputBeforeDelayAndGain() throws {
        let mixer = TestAudioMixer()
        let format = createFormat(.pcmFormatFloat32, 2, false)
        mixer.setSources([createSettings(id: "channel 2", channel: 1, gain: 0.25, delay: 0.5)])
        for tick in 0 ..< 20 {
            mixer.appendBuiltin(createSampleBuffer(format, tick), createTime(tick))
            while mixer.renderNextBlock(now: createTime(tick + 1)) != nil {}
        }
        let samples = try mixer.capture(id: "channel 2", start: startIndex + 1000, count: 4096).get()
        #expect(samples == createNoise(1, 1000 ..< 5096))
    }

    @Test
    func captureRefusesIncompleteWindows() {
        let mixer = TestAudioMixer()
        let format = createFormat(.pcmFormatInt16, 1, true)
        mixer.setSources([
            createSettings(id: "builtin"),
            createSettings(id: "buffered", bufferedAudio: cameraId),
        ])
        for tick in 0 ..< 20 where tick != 10 {
            mixer.appendBuiltin(createSampleBuffer(format, tick), createTime(tick + (tick > 10 ? 3 : 0)))
            mixer.appendBuffered(cameraId: cameraId, createSampleBuffer(format, tick))
        }
        let end = startIndex + 20 * 1024
        #expect(isCaptureFailure(mixer.capture(id: "other", start: startIndex, count: 1024), .missing))
        #expect(isCaptureFailure(mixer.capture(id: "buffered", start: end - 1000, count: 1024), .notReady))
        #expect(isCaptureFailure(
            mixer.capture(id: "buffered", start: startIndex, count: 4096),
            .discontinuity
        ))
        #expect(isCaptureFailure(
            mixer.capture(id: "builtin", start: startIndex, count: 4096),
            .discontinuity
        ))
        #expect((try? mixer.capture(id: "buffered", start: startIndex + 11 * 1024, count: 4096).get()) != nil)
        #expect((try? mixer.capture(id: "builtin", start: startIndex + 14 * 1024, count: 4096).get()) != nil)
    }

    @Test
    func syncAlignsSources() throws {
        let otherCameraId = UUID()
        let format = createFormat(.pcmFormatFloat32, 1, false)
        let signal = makeAudioSyncSignal()
        let offset = 59256
        let secondBurst = 400_000
        let burst = { (frame: Int) -> Float in
            for start in [30000, secondBurst] where frame >= start && frame < start + signal.count {
                return signal[frame - start]
            }
            return 0
        }
        let mixer = TestAudioMixer()
        mixer.setSources([
            createSettings(id: "early", bufferedAudio: cameraId, gain: 0.5),
            createSettings(id: "late", bufferedAudio: otherCameraId, gain: 0.5, delay: 0.1),
        ])
        let output = Output()
        let detector = AudioSyncDetector()
        for tick in 0 ..< 560 {
            mixer.appendBuffered(cameraId: cameraId, createSampleBuffer(format, tick) { burst($1) })
            mixer.appendBuffered(
                cameraId: otherCameraId,
                createSampleBuffer(format, tick) { burst($1 - offset) }
            )
            while let block = mixer.renderNextBlock(now: createTime(tick + 1)) {
                output.append(block)
            }
            guard tick == 300 else {
                continue
            }
            var arrivals: [String: Double] = [:]
            for id in ["early", "late"] {
                let samples = try mixer.capture(id: id, start: startIndex, count: audioSyncFrames).get()
                arrivals[id] = try detector.detect(samples).get().frame
            }
            let delays = makeAudioSyncDelays(arrivals: arrivals,
                                             delays: ["early": 0, "late": 0.1],
                                             anchor: "late")
            #expect(delays["late"] == 0.1)
            let earlyDelay = try #require(delays["early"])
            #expect(abs(earlyDelay - 0.1 - Double(offset) / 48000) < 0.1 / 48000)
            mixer.setSources([
                createSettings(id: "early", bufferedAudio: cameraId, gain: 0.5, delay: earlyDelay),
                createSettings(id: "late", bufferedAudio: otherCameraId, gain: 0.5, delay: 0.1),
            ])
        }
        let burstStart = secondBurst + offset + 4800
        let frames = burstStart ..< burstStart + signal.count
        let expected = frames.map { signal[$0 - burstStart] }
        try #require(output.end >= frames.upperBound)
        #expect(zip(output.samples(0, frames), expected).allSatisfy { abs($0 - $1) < 1e-4 })
    }
}

private final class Output {
    private(set) var presentationTimeStamps: [Int64] = []
    private(set) var left: [Float] = []
    private(set) var right: [Float] = []
    private(set) var numbersOfChannels: Set<AVAudioChannelCount> = []
    private var timescales: Set<CMTimeScale> = []

    var isContinuous: Bool {
        timescales == [48000]
            && zip(presentationTimeStamps, presentationTimeStamps.dropFirst()).allSatisfy { $1 - $0 == 1024 }
    }

    var end: Int {
        left.count - offset
    }

    private var offset: Int {
        Int(startIndex - (presentationTimeStamps.first ?? startIndex))
    }

    func append(
        _ block: (
            presentationTimeStamp: CMTime,
            buffer: AVAudioPCMBuffer,
            recordingBuffer: AVAudioPCMBuffer?
        ),
        recording: Bool = false
    ) {
        presentationTimeStamps.append(block.presentationTimeStamp.value)
        timescales.insert(block.presentationTimeStamp.timescale)
        let buffer = recording ? block.recordingBuffer ?? block.buffer : block.buffer
        let count = Int(buffer.frameLength)
        let numberOfChannels = buffer.format.channelCount
        numbersOfChannels.insert(numberOfChannels)
        left += UnsafeBufferPointer(start: buffer.floatChannelData![0], count: count)
        if numberOfChannels > 1 {
            right += UnsafeBufferPointer(start: buffer.floatChannelData![1], count: count)
        } else {
            right += [Float](repeating: .nan, count: count)
        }
    }

    func samples(_ channel: Int, _ frames: Range<Int>) -> [Float] {
        Array((channel == 0 ? left : right)[frames.lowerBound + offset ..< frames.upperBound + offset])
    }

    func frames(where predicate: (Float) -> Bool) -> [Int] {
        left.indices.filter { predicate(left[$0]) }.map { $0 - offset }
    }
}

private func createSettings(id: String = "mic",
                            bufferedAudio: UUID? = nil,
                            channelsMap: [Int: Int] = [0: 0, 1: 1],
                            channel: Int? = nil,
                            gain: Float = 1,
                            delay: Double = 0,
                            voice: Bool = false,
                            sends: (stream: Float, recording: Float) = (1, 1),
                            pan: Float = 0) -> AudioMixerSourceSettings
{
    AudioMixerSourceSettings(id: id,
                             bufferedAudio: bufferedAudio,
                             channelsMap: channelsMap,
                             channel: channel,
                             gain: gain,
                             delay: delay,
                             voice: voice,
                             sends: sends,
                             pan: pan)
}

private func createTime(_ tick: Int) -> CMTime {
    CMTime(value: startIndex + Int64(1024 * tick), timescale: 48000)
}

private func createSampleBuffer(_ format: AVAudioFormat,
                                _ tick: Int,
                                frameLength: Int = 1024,
                                _ value: (Int, Int) -> Float = createNoise) -> CMSampleBuffer
{
    createSampleBuffer(format, 1024 * tick, createTime(tick), frameLength: frameLength, value)
}

private func isCaptureFailure(_ result: Result<[Float], AudioMixerCaptureError>,
                              _ error: AudioMixerCaptureError) -> Bool
{
    if case let .failure(actual) = result {
        return actual == error
    }
    return false
}

@dynamicMemberLookup
private final class TestAudioMixer {
    private let mixer: AudioMixer
    private var graph: AudioMixerGraph
    private var retained: [AudioMixerGraph] = []

    init() {
        let configuration = AudioMixerConfiguration(sources: [], master: [], previous: nil)
        graph = AudioMixerGraph(configuration, previous: nil)
        mixer = AudioMixer(configuration)
        mixer.install(graph)
    }

    subscript<Value>(dynamicMember keyPath: KeyPath<AudioMixer, Value>) -> Value {
        mixer[keyPath: keyPath]
    }

    var sources: [AudioMixerSource] {
        graph.entries.map(\.source)
    }

    var bufferedInputs: [UUID: AudioMixerInput] {
        graph.bufferedInputs.mapValues(\.audio)
    }

    var builtinInput: AudioMixerInput? {
        graph.builtinInput?.audio
    }

    func setSources(_ sources: [AudioMixerSourceSettings]) {
        apply(sources: sources, master: graph.configuration.masterSettings)
    }

    func setStereo(_ stereo: Bool) {
        mixer.setStereo(stereo)
    }

    func setMasterEffects(_ effects: [AudioMixerEffectSettings]) {
        apply(sources: graph.configuration.sources.map(\.settings), master: effects)
    }

    private func apply(sources: [AudioMixerSourceSettings], master: [AudioMixerEffectSettings]) {
        let configuration = AudioMixerConfiguration(sources: sources, master: master,
                                                    previous: graph.configuration)
        retained.append(graph)
        graph = AudioMixerGraph(configuration, previous: graph)
        mixer.install(graph)
    }

    func setMasterGain(_ gain: Float) {
        mixer.setMasterGain(gain)
    }

    func setMasterMuted(_ muted: Bool) {
        mixer.setMasterMuted(muted)
    }

    func appendBuiltin(_ sampleBuffer: CMSampleBuffer, _ time: CMTime, delay: Double = 0) {
        mixer.appendBuiltin(sampleBuffer, time, delay: delay)
    }

    func appendBuffered(cameraId: UUID, _ sampleBuffer: CMSampleBuffer) {
        mixer.appendBuffered(cameraId: cameraId, sampleBuffer)
    }

    func capture(id: String, start: Int64, count: Int) -> Result<[Float], AudioMixerCaptureError> {
        mixer.capture(id: id, start: start, count: count)
    }

    func renderNextBlock(now: CMTime) -> (
        presentationTimeStamp: CMTime,
        buffer: AVAudioPCMBuffer,
        recordingBuffer: AVAudioPCMBuffer?
    )? {
        defer {
            if !mixer.isTransitioning {
                retained.removeAll()
            }
        }
        return mixer.renderNextBlock(now: now)
    }
}

private func waitForMixerUpdate(_ preparation: AudioMixerPreparation) -> Bool {
    let deadline = ContinuousClock.now + .seconds(5)
    while deadline > .now {
        if processorPipelineQueue.sync(execute: { preparation.adopt() }) {
            return true
        }
        Thread.sleep(forTimeInterval: 0.01)
    }
    return false
}

private func dynamicsFixture(_ frame: Int) -> Float {
    let time = Double(frame) / 48000
    let cycles = time * (650 + 750 * time)
    return sin(2 * .pi * cycles) < 0 ? -0.5 : 0.5
}
