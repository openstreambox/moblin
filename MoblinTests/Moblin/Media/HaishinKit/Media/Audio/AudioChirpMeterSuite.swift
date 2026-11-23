import Foundation
@testable import Moblin
import Testing

private struct ChirpMeterNoise {
    private var state: UInt64 = 7

    private mutating func next() -> Double {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return (Double(state >> 11) + 0.5) / Double(1 << 53)
    }

    mutating func gaussian() -> Float {
        Float(sqrt(-2 * log(next())) * cos(2 * .pi * next()))
    }
}

// A window of the chirp meter signal starting at offset in the signal, scaled by gain.
private func createWindow(offset: Int, gain: Float, noise: Float = 0) -> [Float] {
    let signal = makeAudioChirpMeterSignal(periods: 4)
    var generator = ChirpMeterNoise()
    return (0 ..< audioChirpMeterFrames).map {
        gain * signal[offset + $0] + noise * generator.gaussian()
    }
}

// The meter signal plays its chirp at 0.9 of full scale.
private let signalLevel = 20 * log10(Float(0.9))

struct AudioChirpMeterSuite {
    @Test(arguments: [0, 1234, 6000, 20000])
    func measuresChirpLevel(offset: Int) {
        let level = AudioChirpMeter().measure(createWindow(offset: offset, gain: 0.5))
        #expect(level.isHeard)
        #expect(abs(level.level - (signalLevel - 6.02)) < 0.3)
    }

    @Test
    func levelFollowsGain() {
        let meter = AudioChirpMeter()
        let loud = meter.measure(createWindow(offset: 3000, gain: 0.5))
        let quiet = meter.measure(createWindow(offset: 3000, gain: 0.005))
        #expect(quiet.isHeard)
        #expect(abs(loud.level - quiet.level - 40) < 0.3)
    }

    @Test
    func measuresChirpInNoise() {
        // Chirp at about -21 dBFS in white noise at -30 dBFS RMS.
        let level = AudioChirpMeter().measure(createWindow(offset: 9000, gain: 0.1, noise: 0.0316))
        #expect(level.isHeard)
        #expect(abs(level.level - (signalLevel - 20)) < 1)
    }

    @Test
    func doesNotHearNoise() {
        let level = AudioChirpMeter().measure(createWindow(offset: 0, gain: 0, noise: 0.1))
        #expect(!level.isHeard)
        #expect(abs(level.rms + 20) < 0.5)
    }

    @Test
    func doesNotHearSilence() {
        let level = AudioChirpMeter().measure([Float](repeating: 0, count: audioChirpMeterFrames))
        #expect(!level.isHeard)
        #expect(level.snr == 0)
    }

    @Test
    func doesNotHearTone() {
        let samples = (0 ..< audioChirpMeterFrames)
            .map { Float(0.5 * sin(2 * .pi * 2000 * Double($0) / 48000)) }
        #expect(!AudioChirpMeter().measure(samples).isHeard)
    }
}
