import Foundation

private final class AudioMixerMailbox<Value: AnyObject>: @unchecked Sendable {
    private let slot = makeAudioMixerAtomic(0)

    deinit {
        _ = exchange(nil)
        free(slot)
    }

    func exchange(_ value: Value?) -> Value? {
        let pointer = value.map { Unmanaged.passRetained($0).toOpaque() }
        let address = exchangeAudioMixerAtomic(slot, Int(bitPattern: pointer))
        guard let previous = UnsafeRawPointer(bitPattern: address) else {
            return nil
        }
        return Unmanaged<Value>.fromOpaque(previous).takeRetainedValue()
    }
}

final class AudioMixerMaintenance: @unchecked Sendable {
    static let shared = AudioMixerMaintenance()
    let queue = DispatchQueue(label: "audio-mixer-effects", qos: .userInitiated)
    private var retiredEffects: [() -> Bool] = []
    private var timer: DispatchSourceTimer?

    private init() {}

    func register(_ poll: @escaping @Sendable () -> Bool) {
        queue.async { [self] in
            retiredEffects.append(poll)
            guard self.timer == nil else {
                return
            }
            let timer = DispatchSource.makeTimerSource(queue: queue)
            timer.schedule(deadline: .now() + .milliseconds(50), repeating: .milliseconds(50),
                           leeway: .milliseconds(10))
            timer.setEventHandler { [weak self] in
                self?.collect()
            }
            self.timer = timer
            timer.resume()
        }
    }

    private func collect() {
        retiredEffects.removeAll { $0() }
        if retiredEffects.isEmpty {
            timer?.cancel()
            timer = nil
        }
    }
}

final class AudioMixerReport: Sendable {
    private final class Record: @unchecked Sendable {
        let value = makeAudioMixerAtomic(Int.min)
        let retired = makeAudioMixerAtomic(0)

        deinit {
            free(value)
            free(retired)
        }
    }

    private let record = Record()

    init(retaining resource: (any Sendable)? = nil, _ report: @escaping @Sendable (Int) -> Void = { _ in }) {
        AudioMixerMaintenance.shared.register { [record] in
            withExtendedLifetime(resource) {
                let retired = loadAudioMixerAtomic(record.retired) != 0
                let value = exchangeAudioMixerAtomic(record.value, Int.min)
                if value != Int.min {
                    report(value)
                }
                return retired
            }
        }
    }

    deinit {
        storeAudioMixerAtomic(record.retired, 1)
    }

    func record(_ value: Int) {
        storeAudioMixerAtomic(record.value, value)
    }
}

final class AudioMixerPreparedSource {
    let settings: AudioMixerSourceSettings
    let voice: AudioMixerEffectChain
    let effects: AudioMixerEffectChain

    init(_ settings: AudioMixerSourceSettings, previous: AudioMixerPreparedSource?) {
        self.settings = settings
        let voice = previous?.voice
            ?? AudioMixerEffectChain(settings.voice ? makeAudioMixerVoiceEffects() : [])
        self.voice = voice
        if let previous, previous.settings.effects == settings.effects {
            effects = previous.effects
        } else {
            var stages: [any AudioMixerEffectStage] = []
            var latency = voice.latency
            for setting in settings.effects {
                guard let stage = setting.makeStage() else {
                    continue
                }
                guard latency + stage.latency <= audioMixerFramesPerBlock else {
                    logger.info("audio-mixer: Source \(settings.id) dropped effect (\(stage.latency) frames)")
                    continue
                }
                latency += stage.latency
                stages.append(stage)
            }
            effects = AudioMixerEffectChain(stages)
        }
    }
}

final class AudioMixerConfiguration {
    let sources: [AudioMixerPreparedSource]
    let streamLimiter: AudioMixerEffect?
    let recordingLimiter: AudioMixerEffect?
    let session: AudioMixerSession
    let masterSettings: [AudioMixerEffectSettings]
    let streamEffects: AudioMixerEffectChain
    let recordingEffects: AudioMixerEffectChain

    init(sources: [AudioMixerSourceSettings], master: [AudioMixerEffectSettings],
         previous: AudioMixerConfiguration?)
    {
        var available = previous?.sources ?? []
        self.sources = sources.map { settings in
            let index = available.firstIndex { $0.settings.hasSameInput(as: settings) }
            return AudioMixerPreparedSource(settings, previous: index.map { available.remove(at: $0) })
        }
        if let previous {
            session = previous.session
            streamLimiter = previous.streamLimiter
            recordingLimiter = previous.recordingLimiter
        } else {
            session = AudioMixerSession()
            streamLimiter = makeAudioMixerLimiter()
            recordingLimiter = makeAudioMixerLimiter()
        }
        masterSettings = master
        if let previous, previous.masterSettings == master {
            streamEffects = previous.streamEffects
            recordingEffects = previous.recordingEffects
        } else {
            var stream: [any AudioMixerEffectStage] = []
            var recording: [any AudioMixerEffectStage] = []
            for effect in master {
                guard effect.canUseOnMaster,
                      let streamStage = effect.makeStage(),
                      let recordingStage = effect.makeStage()
                else {
                    continue
                }
                guard streamStage.latency == 0, recordingStage.latency == 0 else {
                    logger.info("audio-mixer: Master effect requires lookahead")
                    continue
                }
                stream.append(streamStage)
                recording.append(recordingStage)
            }
            streamEffects = AudioMixerEffectChain(stream)
            recordingEffects = AudioMixerEffectChain(recording)
        }
    }
}

final class AudioMixerSession {}

final class AudioMixerPreparation: @unchecked Sendable {
    private typealias Apply = @Sendable (AudioMixerConfiguration?) -> Void

    private final class Request {
        let sources: [AudioMixerSourceSettings]?
        let master: [AudioMixerEffectSettings]
        let apply: Apply

        init(
            sources: [AudioMixerSourceSettings]?,
            master: [AudioMixerEffectSettings],
            apply: @escaping Apply
        ) {
            self.sources = sources
            self.master = master
            self.apply = apply
        }
    }

    private final class Update {
        let configuration: AudioMixerConfiguration?
        let apply: Apply

        init(_ configuration: AudioMixerConfiguration?, _ apply: @escaping Apply) {
            self.configuration = configuration
            self.apply = apply
        }
    }

    private let requests = AudioMixerMailbox<Request>()
    private let updates = AudioMixerMailbox<Update>()
    private var configuration: AudioMixerConfiguration?

    func submit(sources: [AudioMixerSourceSettings]?, master: [AudioMixerEffectSettings],
                apply: @escaping @Sendable (AudioMixerConfiguration?) -> Void)
    {
        let next = Request(sources: sources, master: master, apply: apply)
        guard requests.exchange(next) == nil else {
            return
        }
        AudioMixerMaintenance.shared.queue.async {
            guard let request = self.requests.exchange(nil) else {
                return
            }
            self.configuration = request.sources.map {
                AudioMixerConfiguration(sources: $0, master: request.master, previous: self.configuration)
            }
            if self.updates.exchange(Update(self.configuration, request.apply)) == nil {
                processorPipelineQueue.async {
                    if let update = self.updates.exchange(nil) {
                        update.apply(update.configuration)
                    }
                }
            }
        }
    }
}
