import AudioToolbox
@testable import Moblin
import Testing

struct AudioMixerEffectSuite {
    @Test
    func equalizerAttenuatesItsCenterFrequency() throws {
        let equalizer = try #require(AudioMixerEffectSettings.equalizer(.init(gain: -12)).makeStage())
        #expect(equalizer.latency == 0)
        var left = createBlock(0) { createSine(0, $0) }
        var right = createBlock(0) { 0.25 * sin(Float($0) * .pi / 3) }
        #expect(equalizer.process(&left, &right))
        #expect(abs(peak(left.suffix(256)) - 0.5 * pow(10, -12.0 / 20)) < 0.005)
        #expect(peak(right.suffix(256)) > 0.2)
    }

    @Test
    func failedEqualizerPassesDryAudioAndResets() throws {
        let equalizer = try #require(AudioMixerEffectSettings.equalizer(.init(gain: -12))
            .makeStage() as? AudioMixerEffect)
        let dry = createBlock(0) { createSine(0, $0) }
        var left = dry
        var right = dry
        AudioUnitUninitialize(equalizer.audioUnit)
        #expect(equalizer.process(&left, &right))
        #expect(left == dry && right == dry)
        try #require(AudioUnitInitialize(equalizer.audioUnit) == noErr)
        equalizer.reset()
        #expect(equalizer.process(&left, &right))
        #expect(peak(left.suffix(256)) < 0.2)
    }

    @Test
    func compressorAttenuatesOnlyTheLouderSignal() throws {
        let compressor = try #require(AudioMixerEffectSettings.compressor(.init()).makeStage())
        let quiet = try #require(AudioMixerEffectSettings.compressor(.init()).makeStage())
        var loudPeak: Float = 0
        var quietPeak: Float = 0
        for block in 0 ..< 20 {
            var left = createBlock(block) { createSine(0, $0) }
            var right = left
            var quietLeft = left.map { $0 * 0.04 }
            var quietRight = quietLeft
            try #require(compressor.process(&left, &right))
            try #require(quiet.process(&quietLeft, &quietRight))
            loudPeak = peak(left.suffix(256))
            quietPeak = peak(quietLeft.suffix(256))
        }
        #expect(loudPeak > 0.04 && loudPeak < 0.25)
        #expect(abs(quietPeak - 0.02) < 0.001)
    }

    @Test
    func failedCompressorRetainsDrySignalTiming() throws {
        let compressor = try #require(AudioMixerEffectSettings.compressor(.init())
            .makeStage() as? AudioMixerEffect)
        let latency = Int(compressor.latency)
        try #require(latency > 0 && latency < audioMixerFramesPerBlock)
        let previous = createBlock(0) { createNoise(0, $0) }
        var left = previous
        var right = previous
        try #require(compressor.process(&left, &right))
        AudioUnitUninitialize(compressor.audioUnit)
        let next = createBlock(1) { createNoise(0, $0) }
        left = next
        right = next
        #expect(compressor.process(&left, &right))
        let dry = Array(previous.suffix(latency)) + Array(next.dropLast(latency))
        #expect(left == dry && right == dry)
    }

    @Test
    func latencyIsImpulseDelay() throws {
        let limiter = try #require(makeAudioMixerLimiter())
        var output: [Float] = []
        for block in 0 ..< 4 {
            var left = createBlock(block) { $0 == 1000 ? 0.25 : 0 }
            var right = left
            limiter.process(&left, &right)
            output += left
        }
        #expect(output.indices.filter { output[$0] != 0 } == [1000 + Int(limiter.latency)])
    }

    @Test
    func limiterKeepsLoudSineBelowFullScale() throws {
        let limiter = try #require(makeAudioMixerLimiter())
        var peak: Float = 0
        for block in 0 ..< 100 {
            var left = createBlock(block) { 4 * createSine(0, $0) }
            var right = left
            limiter.process(&left, &right)
            if block >= 25 {
                peak = max(peak, left.map { abs($0) }.max() ?? 0)
            }
        }
        #expect(peak > 0.5)
        #expect(peak < 1)
    }

    @Test
    func failedRenderIsSilence() throws {
        let limiter = try #require(makeAudioMixerLimiter())
        var left = createBlock(0) { _ in 0.5 }
        var right = left
        limiter.process(&left, &right)
        AudioUnitUninitialize(limiter.audioUnit)
        left = createBlock(1) { _ in 0.5 }
        right = left
        limiter.process(&left, &right)
        let failed = left + right
        AudioUnitInitialize(limiter.audioUnit)
        left = createBlock(2) { _ in 0 }
        right = left
        limiter.process(&left, &right)
        let silence = [Float](repeating: 0, count: 2 * audioMixerFramesPerBlock)
        #expect(failed == silence)
        #expect(left + right == silence)
    }
}

private func peak(_ samples: ArraySlice<Float>) -> Float {
    samples.map { abs($0) }.max() ?? 0
}

private func createBlock(_ index: Int, _ value: (Int) -> Float) -> [Float] {
    (0 ..< audioMixerFramesPerBlock).map { value(index * audioMixerFramesPerBlock + $0) }
}
