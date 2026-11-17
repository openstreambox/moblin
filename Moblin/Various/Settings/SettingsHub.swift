import Foundation

// What this phone remembers about the rig's hub. Nothing secret: the
// device's own key is in the Keychain, and the stream credentials the hub
// provisioned live in the stream it set up ("Set by your rig").
class SettingsHub: Codable, ObservableObject {
    @Published var name: String = ""
    var urls: [String] = []
    // The hub's static key, pinned at the join (base64url).
    var hubKey: String = ""
    @Published var deviceId: String = ""
    var role: String = ""
    // The Moblin stream the hub's provision went into.
    var streamId: UUID?
    var remoteControlSet: Bool = false
    var hubUrls: [String] = []
    var standbyUrls: [String] = []
    var provenUrl: String = ""
    var ownership: HubOwnership?
    var epoch: Int?
    var accessFloor: HubAccessFloor?

    init() {}

    enum CodingKeys: CodingKey {
        case name
        case urls
        case hubKey
        case deviceId
        case role
        case streamId
        case remoteControlSet
        case hubUrls
        case standbyUrls
        case provenUrl
        case ownership
        case epoch
        case accessFloor
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.name, name)
        try container.encode(.urls, urls)
        try container.encode(.hubKey, hubKey)
        try container.encode(.deviceId, deviceId)
        try container.encode(.role, role)
        try container.encode(.streamId, streamId)
        try container.encode(.remoteControlSet, remoteControlSet)
        try container.encode(.hubUrls, hubUrls)
        try container.encode(.standbyUrls, standbyUrls)
        try container.encode(.provenUrl, provenUrl)
        try container.encode(.ownership, ownership)
        try container.encode(.epoch, epoch)
        try container.encode(.accessFloor, accessFloor)
    }

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = container.decode(.name, String.self, "")
        urls = container.decode(.urls, [String].self, [])
        hubKey = container.decode(.hubKey, String.self, "")
        deviceId = container.decode(.deviceId, String.self, "")
        role = container.decode(.role, String.self, "")
        streamId = container.decode(.streamId, UUID?.self, nil)
        remoteControlSet = container.decode(.remoteControlSet, Bool.self, false)
        hubUrls = container.decode(.hubUrls, [String].self, [])
        standbyUrls = container.decode(.standbyUrls, [String].self, [])
        provenUrl = container.decode(.provenUrl, String.self, "")
        ownership = container.decode(.ownership, HubOwnership?.self, nil)
        epoch = container.decode(.epoch, Int?.self, nil)
        accessFloor = container.decode(.accessFloor, HubAccessFloor?.self, nil)
    }

    func isJoined() -> Bool {
        !hubKey.isEmpty && !deviceId.isEmpty
    }
}
