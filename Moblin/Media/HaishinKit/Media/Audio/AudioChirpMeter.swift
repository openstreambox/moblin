import Accelerate
import Foundation

let audioChirpMeterFrames = 1 << 15
let audioChirpMeterPeriodFrames = 24000
private let log2Frames = vDSP_Length(15)
private let chirpLowFrequency = 1000.0
private let chirpHighFrequency = 6000.0
private let signalLevel: Float = 0.9
private let binsPerHertz = Double(audioChirpMeterFrames) / audioMixerSampleRate
private let lowBin = Int(chirpLowFrequency * binsPerHertz) + 1
private let numberOfBins = Int(chirpHighFrequency * binsPerHertz) - lowBin + 1
private let medianStride = 16
private let minimumSnr: Float = 15

struct AudioChirpLevel {
    // Received chirp amplitude in dB relative to a full scale chirp.
    let level: Float
    // Chirp peak over the median of the matched filter output.
    let snr: Float
    // Level of the whole window in dBFS.
    let rms: Float

    var isHeard: Bool {
        snr >= minimumSnr
    }
}

// One up chirp from the audio sync signal every audioChirpMeterPeriodFrames frames.
func makeAudioChirpMeterSignal(periods: Int) -> [Float] {
    let chirp = makeAudioSyncChirp(up: true)
    var signal = [Float](repeating: 0, count: periods * audioChirpMeterPeriodFrames)
    for period in 0 ..< periods {
        for (frame, sample) in chirp.enumerated() {
            signal[period * audioChirpMeterPeriodFrames + frame] = signalLevel * sample
        }
    }
    return signal
}

private func makeSplitComplex(_ count: Int) -> DSPSplitComplex {
    DSPSplitComplex(realp: makeAudioMixerSamples(count: count), imagp: makeAudioMixerSamples(count: count))
}

// Measures how loud the audio sync chirp is in a window of audioChirpMeterFrames frames with the
// same band limited matched filter as AudioSyncDetector. The window always holds at least one
// whole chirp, as it is longer than a period plus a chirp.
final class AudioChirpMeter {
    private let setup = vDSP_create_fftsetup(log2Frames, FFTRadix(kFFTRadix2))!
    private var spectrum = makeSplitComplex(audioChirpMeterFrames)
    private var product = makeSplitComplex(audioChirpMeterFrames)
    private var reference = makeSplitComplex(numberOfBins)
    private let envelope = makeAudioMixerSamples(count: audioChirpMeterFrames)
    private let sorted = makeAudioMixerSamples(count: audioChirpMeterFrames / medianStride)
    private let chirpFrames: Int
    private var unitPeak: Float = 1

    init() {
        let chirp = makeAudioSyncChirp(up: true)
        chirpFrames = chirp.count
        let weights = (0 ..< numberOfBins).map {
            Float(0.54 - 0.46 * cos(2 * .pi * Double($0) / Double(numberOfBins - 1)))
        }
        transform(chirp)
        vDSP_vmul(spectrum.realp + lowBin, 1, weights, 1, reference.realp, 1, vDSP_Length(numberOfBins))
        vDSP_vmul(spectrum.imagp + lowBin, 1, weights, 1, reference.imagp, 1, vDSP_Length(numberOfBins))
        var unit = [Float](repeating: 0, count: audioChirpMeterFrames)
        unit.replaceSubrange(0 ..< chirpFrames, with: chirp)
        transform(unit)
        unitPeak = correlate().peak
    }

    deinit {
        vDSP_destroy_fftsetup(setup)
        for splitComplex in [spectrum, product, reference] {
            splitComplex.realp.deallocate()
            splitComplex.imagp.deallocate()
        }
        envelope.deallocate()
        sorted.deallocate()
    }

    func measure(_ samples: [Float]) -> AudioChirpLevel {
        precondition(samples.count == audioChirpMeterFrames)
        var meanSquare: Float = 0
        vDSP_measqv(samples, 1, &meanSquare, vDSP_Length(audioChirpMeterFrames))
        transform(samples)
        let (peak, median) = correlate()
        let level = 20 * log10(max(peak / unitPeak, 1e-6))
        let floor = max(median, peak / 1000)
        let snr = floor > 0 ? 20 * log10(peak / floor) : 0
        return AudioChirpLevel(level: level, snr: snr, rms: 10 * log10(max(meanSquare, 1e-12)))
    }

    private func transform(_ samples: [Float]) {
        let frames = vDSP_Length(audioChirpMeterFrames)
        vDSP_vclr(spectrum.realp, 1, frames)
        vDSP_vclr(spectrum.imagp, 1, frames)
        spectrum.realp.update(from: samples, count: min(samples.count, audioChirpMeterFrames))
        vDSP_fft_zip(setup, &spectrum, 1, log2Frames, FFTDirection(kFFTDirection_Forward))
    }

    // The peak is searched only where a whole chirp fits, so a chirp cut at either end of the
    // window does not count.
    private func correlate() -> (peak: Float, median: Float) {
        let frames = vDSP_Length(audioChirpMeterFrames)
        vDSP_vclr(product.realp, 1, frames)
        vDSP_vclr(product.imagp, 1, frames)
        var input = DSPSplitComplex(realp: spectrum.realp + lowBin, imagp: spectrum.imagp + lowBin)
        var output = DSPSplitComplex(realp: product.realp + lowBin, imagp: product.imagp + lowBin)
        vDSP_zvmul(&reference, 1, &input, 1, &output, 1, vDSP_Length(numberOfBins), -1)
        vDSP_fft_zip(setup, &product, 1, log2Frames, FFTDirection(kFFTDirection_Inverse))
        vDSP_zvabs(&product, 1, envelope, 1, frames)
        let searchFrames = vDSP_Length(audioChirpMeterFrames - chirpFrames + 1)
        var peak: Float = 0
        vDSP_maxv(envelope, 1, &peak, searchFrames)
        let count = searchFrames / vDSP_Length(medianStride)
        var one: Float = 1
        vDSP_vsmul(envelope, medianStride, &one, sorted, 1, count)
        vDSP_vsort(sorted, count, 1)
        return (peak, sorted[Int(count) / 2])
    }
}
