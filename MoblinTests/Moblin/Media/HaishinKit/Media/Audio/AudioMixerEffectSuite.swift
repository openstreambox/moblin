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
}

private func peak(_ samples: ArraySlice<Float>) -> Float {
    samples.map { abs($0) }.max() ?? 0
}

private func createBlock(_ index: Int, _ value: (Int) -> Float) -> [Float] {
    (0 ..< audioMixerFramesPerBlock).map { value(index * audioMixerFramesPerBlock + $0) }
}
