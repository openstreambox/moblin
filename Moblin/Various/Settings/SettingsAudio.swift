import Foundation

enum SettingsMic: String, Codable, CaseIterable {
    case bottom = "Bottom"
    case front = "Front"
    case back = "Back"
    case top = "Top"

    init(from decoder: any Decoder) throws {
        self = try SettingsMic(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ??
            getDefaultMic()
    }
}

enum SettingsMicsMicProcessing: String, Codable, CaseIterable {
    case none = "None"
    case voice = "Voice"

    func toString() -> String {
        switch self {
        case .none:
            String(localized: "None")
        case .voice:
            String(localized: "Voice")
        }
    }
}

enum SettingsMicsMicOutput: String, Codable, CaseIterable {
    case streamAndRecording = "Stream and recording"
    case stream = "Stream"
    case recording = "Recording"

    func toString() -> String {
        switch self {
        case .streamAndRecording:
            String(localized: "Stream and recording")
        case .stream:
            String(localized: "Stream only")
        case .recording:
            String(localized: "Recording only")
        }
    }
}

struct SettingsAudioMixerEqualizer: Codable, Equatable, Identifiable {
    var id = UUID()
    var enabled = false
    var frequency: Float = 1000
    var gain: Float = 0
    var bandwidth: Float = 1

    enum CodingKeys: CodingKey {
        case id
        case enabled
        case frequency
        case gain
        case bandwidth
    }

    init() {}

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        enabled = container.decode(.enabled, Bool.self, false)
        frequency = container.decode(.frequency, Float.self, 1000)
        gain = container.decode(.gain, Float.self, 0)
        bandwidth = container.decode(.bandwidth, Float.self, 1)
    }
}

struct SettingsAudioMixerCompressor: Codable, Equatable {
    var enabled = false
    var threshold: Float = -24
    var headroom: Float = 6
    var attack: Float = 0.003
    var release: Float = 0.12
    var makeupGain: Float = 0

    enum CodingKeys: CodingKey {
        case enabled
        case threshold
        case headroom
        case attack
        case release
        case makeupGain
    }

    init() {}

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = container.decode(.enabled, Bool.self, false)
        threshold = container.decode(.threshold, Float.self, -24)
        headroom = container.decode(.headroom, Float.self, 6)
        attack = container.decode(.attack, Float.self, 0.003)
        release = container.decode(.release, Float.self, 0.12)
        makeupGain = container.decode(.makeupGain, Float.self, 0)
    }
}

struct SettingsAudioMixerExpander: Codable, Equatable {
    var enabled = false
    var threshold: Float = -40
    var ratio: Float = 4
    var attack: Float = 0.003
    var release: Float = 0.12

    enum CodingKeys: CodingKey {
        case enabled
        case threshold
        case ratio
        case attack
        case release
    }

    init() {}

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = container.decode(.enabled, Bool.self, false)
        threshold = container.decode(.threshold, Float.self, -40)
        ratio = container.decode(.ratio, Float.self, 4)
        attack = container.decode(.attack, Float.self, 0.003)
        release = container.decode(.release, Float.self, 0.12)
    }
}

struct SettingsAudioMixerDeEsser: Codable, Equatable {
    var enabled = false
    var frequency: Float = 6000
    var bandwidth: Float = 1
    var threshold: Float = -24
    var maximumReduction: Float = 9

    enum CodingKeys: CodingKey {
        case enabled
        case frequency
        case bandwidth
        case threshold
        case maximumReduction
    }

    init() {}

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = container.decode(.enabled, Bool.self, false)
        frequency = container.decode(.frequency, Float.self, 6000)
        bandwidth = container.decode(.bandwidth, Float.self, 1)
        threshold = container.decode(.threshold, Float.self, -24)
        maximumReduction = container.decode(.maximumReduction, Float.self, 9)
    }
}

class SettingsMicsMicEffects: Codable, ObservableObject {
    @Published var expander: SettingsAudioMixerExpander = .init()
    @Published var equalizer: SettingsAudioMixerEqualizer = .init()
    @Published var compressor: SettingsAudioMixerCompressor = .init()
    @Published var deEsser: SettingsAudioMixerDeEsser = .init()

    var isEnabled: Bool {
        expander.enabled || equalizer.enabled || compressor.enabled || deEsser.enabled
    }

    enum CodingKeys: CodingKey {
        case expander
        case equalizer
        case compressor
        case deEsser
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.expander, expander)
        try container.encode(.equalizer, equalizer)
        try container.encode(.compressor, compressor)
        try container.encode(.deEsser, deEsser)
    }

    init() {}

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        expander = container.decode(.expander, SettingsAudioMixerExpander.self, .init())
        equalizer = container.decode(.equalizer, SettingsAudioMixerEqualizer.self, .init())
        compressor = container.decode(.compressor, SettingsAudioMixerCompressor.self, .init())
        deEsser = container.decode(.deEsser, SettingsAudioMixerDeEsser.self, .init())
    }
}

let audioMixerMaximumOutputEqualizers = 3

class SettingsAudioOutputEffects: Codable, ObservableObject {
    @Published var equalizers: [SettingsAudioMixerEqualizer] = []
    @Published var deEsser: SettingsAudioMixerDeEsser = .init()

    var isEnabled: Bool {
        equalizers.contains(where: \.enabled) || deEsser.enabled
    }

    enum CodingKeys: CodingKey {
        case equalizers
        case deEsser
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.equalizers, equalizers)
        try container.encode(.deEsser, deEsser)
    }

    init() {}

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        equalizers = container.decode(.equalizers, [SettingsAudioMixerEqualizer].self, [])
        deEsser = container.decode(.deEsser, SettingsAudioMixerDeEsser.self, .init())
    }
}

class SettingsMicsMic: Codable, Identifiable, Equatable, ObservableObject, @unchecked Sendable {
    static func == (lhs: SettingsMicsMic, rhs: SettingsMicsMic) -> Bool {
        lhs.inputUid == rhs.inputUid && lhs.dataSourceId == rhs.dataSourceId && lhs.channel == rhs.channel
    }

    var id: String {
        if let channel {
            "\(inputUid) \(dataSourceId ?? 0) \(channel)"
        } else {
            "\(inputUid) \(dataSourceId ?? 0)"
        }
    }

    var name: String = ""
    var inputUid: String = ""
    var dataSourceId: Int?
    var channel: Int?
    var builtInOrientation: SettingsMic?
    @Published var delay: Double = 0.0
    @Published var gainDb: Float = 0.0
    @Published var pan: Float = 0.0
    @Published var connected: Bool = false
    @Published var mixed: Bool = false
    @Published var processing: SettingsMicsMicProcessing = .none
    @Published var output: SettingsMicsMicOutput = .streamAndRecording
    @Published var muted: Bool = false
    var effects: SettingsMicsMicEffects = .init()

    func isAudioSession() -> Bool {
        isBuiltin() || isExternal()
    }

    func isBuiltin() -> Bool {
        builtInOrientation != nil
    }

    func isExternal() -> Bool {
        if isBuiltin() {
            return false
        }
        if isRtmpCameraOrMic(camera: name) {
            return false
        }
        if isSrtlaCameraOrMic(camera: name) {
            return false
        }
        if isSrtClientCameraOrMic(camera: name) {
            return false
        }
        if isRistCameraOrMic(camera: name) {
            return false
        }
        if isRtspCameraOrMic(camera: name) {
            return false
        }
        if isWhipCameraOrMic(camera: name) {
            return false
        }
        if isWhepCameraOrMic(camera: name) {
            return false
        }
        if isMediaPlayerCameraOrMic(camera: name) {
            return false
        }
        if isScreenCapture() {
            return false
        }
        return true
    }

    func isRtmp() -> Bool {
        isRtmpCameraOrMic(camera: name)
    }

    func isSrtla() -> Bool {
        isSrtlaCameraOrMic(camera: name)
    }

    func isSrtClient() -> Bool {
        isSrtClientCameraOrMic(camera: name)
    }

    func isRist() -> Bool {
        isRistCameraOrMic(camera: name)
    }

    func isRtsp() -> Bool {
        isRtspCameraOrMic(camera: name)
    }

    func isWhip() -> Bool {
        isWhipCameraOrMic(camera: name)
    }

    func isWhep() -> Bool {
        isWhepCameraOrMic(camera: name)
    }

    func isNetwork() -> Bool {
        isRtmp() || isSrtla() || isSrtClient() || isRist() || isRtsp() || isWhip() || isWhep()
    }

    func isMediaPlayer() -> Bool {
        isMediaPlayerCameraOrMic(camera: name)
    }

    func isScreenCapture() -> Bool {
        inputUid == screenCaptureCameraId.uuidString
    }

    enum CodingKeys: CodingKey {
        case name
        case inputUid
        case dataSourceID
        case builtInOrientation
        case delay
        case gainDb
        case mixed
        case channel
        case processing
        case output
        case pan
        case muted
        case effects
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.name, name)
        try container.encode(.inputUid, inputUid)
        try container.encode(.dataSourceID, dataSourceId)
        try container.encode(.builtInOrientation, builtInOrientation)
        try container.encode(.delay, delay)
        try container.encode(.gainDb, gainDb)
        try container.encode(.mixed, mixed)
        try container.encode(.channel, channel)
        try container.encode(.processing, processing)
        try container.encode(.output, output)
        try container.encode(.pan, pan)
        try container.encode(.muted, muted)
        try container.encode(.effects, effects)
    }

    init() {}

    init(name: String, inputUid: String, connected: Bool) {
        self.name = name
        self.inputUid = inputUid
        self.connected = connected
    }

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = container.decode(.name, String.self, "")
        inputUid = container.decode(.inputUid, String.self, "")
        dataSourceId = container.decode(.dataSourceID, Int?.self, nil)
        builtInOrientation = container.decode(.builtInOrientation, SettingsMic?.self, nil)
        delay = container.decode(.delay, Double.self, 0.0)
        gainDb = container.decode(.gainDb, Float.self, 0.0)
        mixed = container.decode(.mixed, Bool.self, false)
        channel = container.decode(.channel, Int?.self, nil)
        processing = container.decode(.processing, SettingsMicsMicProcessing.self, .none)
        output = container.decode(.output, SettingsMicsMicOutput.self, .streamAndRecording)
        pan = container.decode(.pan, Float.self, 0.0)
        muted = container.decode(.muted, Bool.self, false)
        effects = container.decode(.effects, SettingsMicsMicEffects.self, .init())
    }
}

class SettingsMics: Codable, ObservableObject {
    @Published var mics: [SettingsMicsMic] = []
    @Published var autoSwitch: Bool = true
    var defaultMic: String = ""

    enum CodingKeys: CodingKey {
        case all
        case autoSwitch
        case defaultMic
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.all, mics)
        try container.encode(.autoSwitch, autoSwitch)
        try container.encode(.defaultMic, defaultMic)
    }

    init() {}

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mics = container.decode(.all, [SettingsMicsMic].self, [])
        autoSwitch = container.decode(.autoSwitch, Bool.self, true)
        defaultMic = container.decode(.defaultMic, String.self, "")
    }
}

class SettingsAudioOutputToInputChannelsMap: Codable {
    var channel1: Int = 0
    var channel2: Int = 1
}

class SettingsAudio: Codable, ObservableObject {
    var outputToInputChannelsMap: SettingsAudioOutputToInputChannelsMap = .init()
    @Published var gainDb: Float = 0.0
    @Published var preferStereoMic: Bool = false
    @Published var stereoMix: Bool = false
    var outputEffects: SettingsAudioOutputEffects = .init()

    init() {}

    enum CodingKeys: CodingKey {
        case audioOutputToInputChannelsMap
        case gainDb
        case preferStereoMic
        case stereoMix
        case outputEffects
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.audioOutputToInputChannelsMap, outputToInputChannelsMap)
        try container.encode(.gainDb, gainDb)
        try container.encode(.preferStereoMic, preferStereoMic)
        try container.encode(.stereoMix, stereoMix)
        try container.encode(.outputEffects, outputEffects)
    }

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        outputToInputChannelsMap = container.decode(.audioOutputToInputChannelsMap,
                                                    SettingsAudioOutputToInputChannelsMap.self,
                                                    .init())
        gainDb = container.decode(.gainDb, Float.self, 0.0)
        preferStereoMic = container.decode(.preferStereoMic, Bool.self, false)
        stereoMix = container.decode(.stereoMix, Bool.self, false)
        outputEffects = container.decode(.outputEffects, SettingsAudioOutputEffects.self, .init())
    }
}
