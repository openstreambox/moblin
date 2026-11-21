import AVFoundation
import Foundation

private let measureInterval = 0.25
private let captureMarginFrames: Int64 = 4800
private let trendMeasurements = 4
private let trendThreshold: Float = 3

enum FindMicTrend {
    case hotter
    case colder
    case steady
}

struct FindMicCandidate: Identifiable {
    let id: String
    let name: String
}

@MainActor
class FindMic: ObservableObject {
    @Published var micId: String?
    @Published var isFinding = false
    @Published var isPinging = false
    @Published var level: AudioChirpLevel?
    @Published var trend: FindMicTrend = .steady
    @Published var message: String?
    var player: AudioPlayer?
    var timer: Timer?
    var isMeasuring = false
    var levels: [Float] = []
    var numberOfMeasurements = 0
}

private func makeFindMicPlayer() -> AudioPlayer? {
    let player = try? AudioPlayer(data: makeAudioSyncWav(samples: makeAudioChirpMeterSignal(periods: 8)))
    player?.setNumberOfLoops(-1)
    return player
}

extension Model {
    func findMicCandidates() -> [FindMicCandidate] {
        ([mic.current] + mic.mixed)
            .map { getMicById(id: $0.id) ?? $0 }
            .filter { !$0.isScreenCapture() && !isMediaPlayerMic(mic: $0) }
            .map { FindMicCandidate(id: $0.id, name: $0.name) }
    }

    func startFindMic() {
        stopFindMic()
        guard let micId = findMic.micId ?? findMicCandidates().first?.id else {
            findMic.message = String(localized: "Select a mic first.")
            return
        }
        let session = AVAudioSession.sharedInstance()
        if let output = session.currentRoute.outputs.first, output.portType != .builtInSpeaker {
            let name = output.portName
            findMic.message = String(localized: "Sound plays on \(name), so the mic cannot hear it.")
            return
        }
        guard let player = makeFindMicPlayer() else {
            findMic.message = String(localized: "Failed to play the sound.")
            return
        }
        findMic.message = nil
        findMic.micId = micId
        findMic.level = nil
        findMic.trend = .steady
        findMic.levels = []
        findMic.numberOfMeasurements = 0
        findMic.player = player
        findMic.isFinding = true
        player.play()
        let name = getMicById(id: micId)?.name ?? micId
        logger.info("find-mic: Finding \(name) at volume \(session.outputVolume)")
        findMic.timer = Timer.scheduledTimer(withTimeInterval: measureInterval, repeats: true) { _ in
            DispatchQueue.main.async {
                self.measureFindMic(id: micId)
            }
        }
    }

    func pingFindMic() {
        stopFindMic()
        guard let player = makeFindMicPlayer() else {
            findMic.message = String(localized: "Failed to play the sound.")
            return
        }
        let output = AVAudioSession.sharedInstance().currentRoute.outputs.first
        if let output, output.portType != .builtInSpeaker {
            let name = output.portName
            findMic.message = String(localized: "Playing on \(name).")
        } else {
            findMic.message = String(localized: "No headphones or speaker connected. Playing on the phone.")
        }
        logger.info("find-mic: Ping on \(output?.portName ?? "-")")
        findMic.player = player
        findMic.isPinging = true
        player.play()
    }

    func stopFindMic() {
        findMic.timer?.invalidate()
        findMic.timer = nil
        findMic.player?.stop()
        findMic.player = nil
        findMic.isFinding = false
        findMic.isPinging = false
    }

    private func measureFindMic(id: String) {
        guard findMic.isFinding, !findMic.isMeasuring else {
            return
        }
        findMic.isMeasuring = true
        let count = Int64(audioChirpMeterFrames)
        let start = makeAudioMixerIndex(currentPresentationTimeStamp()) - count - captureMarginFrames
        media.captureMixedAudio(ids: [id], start: start, count: Int(count)) { captures in
            guard case let .success(samples) = captures[id] else {
                DispatchQueue.main.async {
                    self.findMic.isMeasuring = false
                    if case .failure(.missing) = captures[id] ?? .failure(.missing) {
                        self.findMic.message = String(localized: "No audio.")
                    }
                }
                return
            }
            DispatchQueue.global(qos: .userInitiated).async {
                let level = AudioChirpMeter().measure(samples)
                DispatchQueue.main.async {
                    self.findMic.isMeasuring = false
                    self.updateFindMic(id: id, level: level)
                }
            }
        }
    }

    private func updateFindMic(id: String, level: AudioChirpLevel) {
        guard findMic.isFinding, findMic.micId == id else {
            return
        }
        findMic.message = nil
        findMic.level = level
        findMic.numberOfMeasurements += 1
        if level.isHeard {
            findMic.levels.append(level.level)
            if findMic.levels.count > 2 * trendMeasurements {
                findMic.levels.removeFirst()
            }
        }
        if findMic.levels.count == 2 * trendMeasurements {
            let older = findMic.levels.prefix(trendMeasurements).reduce(0, +) / Float(trendMeasurements)
            let newer = findMic.levels.suffix(trendMeasurements).reduce(0, +) / Float(trendMeasurements)
            if newer - older > trendThreshold {
                findMic.trend = .hotter
            } else if older - newer > trendThreshold {
                findMic.trend = .colder
            } else {
                findMic.trend = .steady
            }
        }
        if findMic.numberOfMeasurements % 4 == 0 {
            logger.info("""
            find-mic: \(getMicById(id: id)?.name ?? id) level \(level.level) dB, snr \(level.snr) dB, \
            rms \(level.rms) dBFS, heard \(level.isHeard)
            """)
        }
    }
}
