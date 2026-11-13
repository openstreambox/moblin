import Foundation

class SettingsBackpack: Codable, ObservableObject {
    static let defaultCompanionButtons: [SettingsQuickButtonType] = [
        .chat,
        .obs,
        .remote,
        .djiDevices,
        .streamMarker,
        .lockScreen,
    ]
    @Published var enabled: Bool = true
    @Published var url: String = ""
    @Published var readAloud: Bool = true
    var quickButtonsTrimmed: Bool = false
    var companionButtons: [SettingsQuickButtonType] = defaultCompanionButtons
    var dashboardUrl: String = ""
    @Published var dashboardName: String = ""
    var dashboardDeviceId: String = ""
    @Published var dashboardToken: String = ""

    init() {}

    enum CodingKeys: CodingKey {
        case enabled
        case url
        case readAloud
        case quickButtonsTrimmed
        case companionButtons
        case dashboardUrl
        case dashboardName
        case dashboardDeviceId
        case dashboardToken
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.enabled, enabled)
        try container.encode(.url, url)
        try container.encode(.readAloud, readAloud)
        try container.encode(.quickButtonsTrimmed, quickButtonsTrimmed)
        try container.encode(.companionButtons, companionButtons)
        try container.encode(.dashboardUrl, dashboardUrl)
        try container.encode(.dashboardName, dashboardName)
        try container.encode(.dashboardDeviceId, dashboardDeviceId)
        try container.encode(.dashboardToken, dashboardToken)
    }

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = container.decode(.enabled, Bool.self, true)
        url = container.decode(.url, String.self, "")
        readAloud = container.decode(.readAloud, Bool.self, true)
        quickButtonsTrimmed = container.decode(.quickButtonsTrimmed, Bool.self, false)
        companionButtons = container.decode(.companionButtons,
                                            [SettingsQuickButtonType].self,
                                            SettingsBackpack.defaultCompanionButtons)
        dashboardUrl = container.decode(.dashboardUrl, String.self, "")
        dashboardName = container.decode(.dashboardName, String.self, "")
        dashboardDeviceId = container.decode(.dashboardDeviceId, String.self, "")
        dashboardToken = container.decode(.dashboardToken, String.self, "")
    }
}
