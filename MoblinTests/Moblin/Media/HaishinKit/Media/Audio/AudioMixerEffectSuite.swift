import AudioToolbox
@testable import Moblin
import Testing

struct AudioMixerEffectSuite {
    @Test
    func latencyIsImpulseDelay() throws {
        let limiter = try #require(makeAudioMixerLimiter())
        var output: [Float] = []
        for block in 0 ..< 4 {
            var samples = createBlock(block) { $0 == 1000 ? 0.25 : 0 }
            limiter.process(&samples)
            output += samples
        }
        #expect(output.indices.filter { output[$0] != 0 } == [1000 + Int(limiter.latency)])
    }

    @Test
    func limiterKeepsLoudSineBelowFullScale() throws {
        let limiter = try #require(makeAudioMixerLimiter())
        var peak: Float = 0
        for block in 0 ..< 100 {
            var samples = createBlock(block) { 4 * createSine(0, $0) }
            limiter.process(&samples)
            if block >= 25 {
                peak = max(peak, samples.map { abs($0) }.max() ?? 0)
            }
        }
        #expect(peak > 0.5)
        #expect(peak < 1)
    }

    @Test
    func failedRenderIsSilence() throws {
        let limiter = try #require(makeAudioMixerLimiter())
        var samples = createBlock(0) { _ in 0.5 }
        limiter.process(&samples)
        AudioUnitUninitialize(limiter.audioUnit)
        samples = createBlock(1) { _ in 0.5 }
        limiter.process(&samples)
        let failed = samples
        AudioUnitInitialize(limiter.audioUnit)
        samples = createBlock(2) { _ in 0 }
        limiter.process(&samples)
        let silence = [Float](repeating: 0, count: audioMixerFramesPerBlock)
        #expect(failed == silence)
        #expect(samples == silence)
    }
}

private func createBlock(_ index: Int, _ value: (Int) -> Float) -> [Float] {
    (0 ..< audioMixerFramesPerBlock).map { value(index * audioMixerFramesPerBlock + $0) }
}
