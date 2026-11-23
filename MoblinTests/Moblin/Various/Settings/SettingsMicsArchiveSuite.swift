import Foundation
@testable import Moblin
import Testing

private let day: TimeInterval = 24 * 60 * 60
private let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

private func makeMic(_ name: String,
                     _ inputUid: String,
                     connected: Bool = false,
                     lastSeen: Date? = nil) -> SettingsMicsMic
{
    let mic = SettingsMicsMic(name: name, inputUid: inputUid, connected: connected)
    mic.lastSeen = lastSeen
    return mic
}

private func makeMics(_ mics: [SettingsMicsMic], since: Date = start) -> SettingsMics {
    let settings = SettingsMics()
    settings.mics = mics
    settings.lastSeenSince = since
    return settings
}

private func decode(_ json: String) throws -> SettingsMics {
    try JSONDecoder().decode(SettingsMics.self, from: Data(json.utf8))
}

private func roundTrip(_ mics: SettingsMics) throws -> SettingsMics {
    try JSONDecoder().decode(SettingsMics.self, from: JSONEncoder().encode(mics))
}

private func ids(_ mics: [SettingsMicsMic]) -> [String] {
    mics.map(\.inputUid)
}

struct SettingsMicsArchiveSuite {
    @Test
    func oldSettingsHaveUnknownAgeAndAgeFromMigration() throws {
        let before = Date.now
        let mics = try decode("""
        {"all": [{"name": "Wireless microphone", "inputUid": "usb-1", "gainDb": -3, "mixed": true}],
         "autoSwitch": true, "defaultMic": "usb-1 0"}
        """)
        let mic = try #require(mics.mics.first)
        #expect(mic.lastSeen == nil)
        #expect(mic.archive == .automatic)
        #expect(mic.gainDb == -3)
        #expect(mic.mixed)
        #expect(mics.archiveAfterDays == 30)
        #expect(mics.lastSeenSince >= before)
        #expect(mics.lastSeenSinceIsNew)
        #expect(formatMicLastSeen(mic.lastSeen) == String(localized: "Last seen unknown"))
        #expect(!mics.isArchived(mic: mic, current: noMic, now: mics.lastSeenSince + 29 * day))
        #expect(mics.isArchived(mic: mic, current: noMic, now: mics.lastSeenSince + 30 * day))
        #expect(mics.defaultMic == "usb-1 0")
    }

    @Test
    func archiveAgeMustBeAPickerChoice() throws {
        #expect(try decode(#"{"all": [], "archiveAfterDays": -1}"#).archiveAfterDays == 30)
        #expect(try decode(#"{"all": [], "archiveAfterDays": 14}"#).archiveAfterDays == 30)
        #expect(try decode(#"{"all": [], "archiveAfterDays": 7}"#).archiveAfterDays == 7)
        #expect(try decode(#"{"all": [], "archiveAfterDays": 0}"#).archiveAfterDays == 0)
    }

    @Test
    func restartKeepsArchiveStateAndDates() throws {
        let hidden = makeMic("AirPods Pro", "bt-old", lastSeen: start + day)
        hidden.archive = .hidden
        hidden.gainDb = -6
        hidden.pan = 0.25
        hidden.delay = 0.09
        hidden.mixed = true
        hidden.processing = .voice
        hidden.output = .recording
        let shown = makeMic("Lark M2 RX", "usb-lark", lastSeen: start)
        shown.archive = .shown
        let settings = makeMics([makeMic("Bottom", "builtin", connected: true, lastSeen: start + 2 * day),
                                 hidden,
                                 shown])
        settings.archiveAfterDays = 7
        let restored = try roundTrip(settings)
        #expect(ids(restored.mics) == ["builtin", "bt-old", "usb-lark"])
        #expect(restored.mics.allSatisfy { !$0.connected })
        #expect(restored.mics[0].lastSeen == start + 2 * day)
        #expect(restored.mics[1].archive == .hidden)
        #expect(restored.mics[1].gainDb == -6)
        #expect(restored.mics[1].pan == 0.25)
        #expect(restored.mics[1].delay == 0.09)
        #expect(restored.mics[1].mixed)
        #expect(restored.mics[1].processing == .voice)
        #expect(restored.mics[1].output == .recording)
        #expect(restored.mics[2].archive == .shown)
        #expect(restored.archiveAfterDays == 7)
        #expect(restored.lastSeenSince == start)
        #expect(!restored.lastSeenSinceIsNew)
        let now = start + 3 * day
        #expect(ids(restored.visibleMics(current: noMic, now: now)) == ["builtin", "usb-lark"])
        let found = [
            makeMic("Bottom", "builtin", connected: true),
            makeMic("AirPods Pro", "bt-old", connected: true),
        ]
        restored.mics = syncMicsList(mics: restored.mics,
                                     found: found,
                                     isKind: { _ in true },
                                     removeMissing: false,
                                     now: now)
        #expect(ids(restored.visibleMics(current: noMic, now: now)) == ["builtin", "bt-old", "usb-lark"])
        #expect(restored.mics[1].archive == .automatic)
        #expect(restored.mics[1].lastSeen == now)
        #expect(restored.mics[2].lastSeen == start)
    }

    @Test
    func reconnectRestoresSameRowInItsPlace() {
        let usb = makeMic("Wireless GO II RX", "usb-go", connected: true, lastSeen: start)
        let lark = makeMic("Lark M2 RX", "usb-lark", connected: true, lastSeen: start)
        lark.gainDb = 4
        lark.mixed = true
        let builtin = makeMic("Bottom", "builtin", connected: true, lastSeen: start)
        let settings = makeMics([usb, lark, builtin])
        var now = start + day
        settings.mics = syncMicsList(mics: settings.mics,
                                     found: [makeMic("Wireless GO II RX", "usb-go", connected: true),
                                             makeMic("Bottom", "builtin", connected: true)],
                                     isKind: { _ in true },
                                     removeMissing: false,
                                     now: now)
        #expect(!lark.connected)
        #expect(lark.lastSeen == now)
        settings.hideAllDisconnected(current: usb, now: now)
        #expect(ids(settings.archivedMics(current: usb, now: now)) == ["usb-lark"])
        now = start + 40 * day
        settings.mics = syncMicsList(mics: settings.mics,
                                     found: [makeMic("Wireless GO II RX", "usb-go", connected: true),
                                             makeMic("Lark M2 RX (renamed)", "usb-lark", connected: true),
                                             makeMic("Bottom", "builtin", connected: true)],
                                     isKind: { _ in true },
                                     removeMissing: false,
                                     now: now)
        #expect(settings.mics[1] === lark)
        #expect(ids(settings.visibleMics(current: usb, now: now)) == ["usb-go", "usb-lark", "builtin"])
        #expect(lark.archive == .automatic)
        #expect(lark.name == "Lark M2 RX (renamed)")
        #expect(lark.gainDb == 4)
        #expect(lark.mixed)
        #expect(lark.lastSeen == now)
    }

    @Test
    func markedConnectedAndDisconnectedUpdateLastSeen() {
        let mic = makeMic("Guest laptop (SRT(LA))", UUID().uuidString)
        mic.setConnected(false, now: start)
        #expect(mic.lastSeen == nil)
        mic.archive = .hidden
        mic.setConnected(true, now: start + day)
        #expect(mic.connected)
        #expect(mic.archive == .automatic)
        #expect(mic.lastSeen == start + day)
        mic.setConnected(false, now: start + 2 * day)
        #expect(!mic.connected)
        #expect(mic.lastSeen == start + 2 * day)
        mic.setConnected(false, now: start + 3 * day)
        #expect(mic.lastSeen == start + 2 * day)
    }

    @Test
    func bluetoothDeviceWithNewUidGetsNewRowAndOldRowIsArchived() {
        let current = makeMic("Wireless GO II RX", "usb-go", connected: true, lastSeen: start)
        let old = makeMic("AirPods Pro", "bt-1", connected: true, lastSeen: start)
        old.gainDb = -2
        let settings = makeMics([current, old])
        let now = start + day
        settings.mics = syncMicsList(mics: settings.mics,
                                     found: [makeMic("Wireless GO II RX", "usb-go", connected: true),
                                             makeMic("AirPods Pro", "bt-2", connected: true)],
                                     isKind: { _ in true },
                                     removeMissing: false,
                                     now: now)
        #expect(ids(settings.mics) == ["bt-2", "usb-go", "bt-1"])
        let new = settings.mics[0]
        #expect(new !== old)
        #expect(new.connected)
        #expect(new.lastSeen == now)
        #expect(new.gainDb == 0)
        #expect(!old.connected)
        #expect(old.gainDb == -2)
        settings.hideAllDisconnected(current: current, now: now)
        #expect(ids(settings.visibleMics(current: current, now: now)) == ["bt-2", "usb-go"])
        #expect(ids(settings.archivedMics(current: current, now: now)) == ["bt-1"])
    }

    @Test
    func currentAndConnectedMicsStayVisible() {
        let current = makeMic("Wireless GO II RX", "usb-go", lastSeen: start)
        current.archive = .hidden
        let connected = makeMic("Bottom", "builtin", connected: true)
        connected.archive = .hidden
        let stale = makeMic("USB Audio CODEC", "usb-codec", lastSeen: start)
        let settings = makeMics([current, connected, stale])
        let now = start + 100 * day
        #expect(ids(settings.visibleMics(current: current, now: now)) == ["usb-go", "builtin"])
        #expect(ids(settings.archivedMics(current: current, now: now)) == ["usb-codec"])
        current.archive = .automatic
        #expect(settings.hideableMics(current: current, now: now).isEmpty)
        settings.hideAllDisconnected(current: current, now: now)
        #expect(current.archive == .automatic)
        #expect(ids(settings.visibleMics(current: current, now: now)) == ["usb-go", "builtin"])
    }

    @Test
    func mediaPlayersAreAlwaysVisible() throws {
        let player = SettingsMediaPlayer()
        let settings = makeMics([])
        let now = start + 100 * day
        settings.mics = syncMicsList(mics: [],
                                     found: makeMediaPlayerMics(players: [player]),
                                     isKind: { $0.isMediaPlayer() },
                                     removeMissing: true,
                                     now: now)
        let mic = try #require(settings.mics.first)
        #expect(mic.connected)
        settings.hideAllDisconnected(current: noMic, now: now + 100 * day)
        #expect(mic.archive == .automatic)
        #expect(settings.visibleMics(current: noMic, now: now + 100 * day).count == 1)
    }

    @Test
    func newRowsThatNeverConnectedAreDatedAndVisible() {
        let settings = makeMics([], since: start)
        let now = start + 60 * day
        let id = UUID().uuidString
        settings.mics = syncMicsList(mics: [],
                                     found: [makeMic(srtlaCamera(name: "Guest laptop"), id)],
                                     isKind: { $0.isSrtla() },
                                     removeMissing: true,
                                     now: now)
        let mic = settings.mics[0]
        #expect(!mic.connected)
        #expect(mic.lastSeen == now)
        #expect(ids(settings.visibleMics(current: noMic, now: now + day)) == [id])
        #expect(settings.isArchived(mic: mic, current: noMic, now: now + 30 * day))
    }

    @Test
    func savingStampsOnlyMicsSeenConnected() {
        let usb = makeMic("Wireless GO II RX", "usb-go", connected: true, lastSeen: start)
        let otherDeviceChannel = makeMic("Interface 3", "usb-interface", lastSeen: start)
        otherDeviceChannel.channel = 2
        otherDeviceChannel.setConnected(true, seen: false, now: start + day)
        let disconnected = makeMic("Lark M2 RX", "usb-lark", lastSeen: start)
        let settings = makeMics([usb, otherDeviceChannel, disconnected])
        settings.stampSeenMics(now: start + 2 * day)
        #expect(usb.lastSeen == start + 2 * day)
        #expect(otherDeviceChannel.connected)
        #expect(otherDeviceChannel.lastSeen == start)
        #expect(disconnected.lastSeen == start)
        otherDeviceChannel.setConnected(false, now: start + 3 * day)
        #expect(otherDeviceChannel.lastSeen == start)
        otherDeviceChannel.setConnected(true, seen: true, now: start + 4 * day)
        #expect(otherDeviceChannel.lastSeen == start + 4 * day)
    }

    @Test
    func onlyChannelsOfTheCurrentRouteCountAsSeen() {
        let channel = makeMic("Interface 3", "usb-interface")
        channel.channel = 2
        #expect(isAudioChannelMicSeen(mic: channel, connected: true, inputUid: "usb-interface"))
        #expect(!isAudioChannelMicSeen(mic: channel, connected: true, inputUid: "usb-other"))
        #expect(!isAudioChannelMicSeen(mic: channel, connected: true, inputUid: nil))
        #expect(!isAudioChannelMicSeen(mic: channel, connected: false, inputUid: "usb-interface"))
    }

    @Test
    func rowsWithTheSameUidStaySeparatePerDataSourceAndChannel() {
        let front = makeMic("Front", "BuiltInMicrophoneDevice", connected: true, lastSeen: start)
        front.dataSourceId = 1
        front.gainDb = -3
        let back = makeMic("Back", "BuiltInMicrophoneDevice", connected: true, lastSeen: start)
        back.dataSourceId = 2
        let channel1 = makeMic("Interface 1", "usb-interface", connected: true, lastSeen: start)
        channel1.channel = 0
        let settings = makeMics([front, back, channel1])
        let now = start + day
        let foundBack = makeMic("Back", "BuiltInMicrophoneDevice", connected: true)
        foundBack.dataSourceId = 2
        let foundChannel2 = makeMic("Interface 1", "usb-interface", connected: true)
        foundChannel2.channel = 1
        settings.mics = syncMicsList(mics: settings.mics,
                                     found: [foundBack, foundChannel2],
                                     isKind: { _ in true },
                                     removeMissing: false,
                                     now: now)
        #expect(settings.mics.count == 4)
        #expect(settings.mics[0] === foundChannel2)
        #expect(Array(settings.mics[1...]) == [front, back, channel1])
        #expect(!front.connected)
        #expect(front.gainDb == -3)
        #expect(back.connected)
        #expect(!channel1.connected)
        #expect(foundChannel2.lastSeen == now)
        settings.hideAllDisconnected(current: back, now: now)
        let archived = settings.archivedMics(current: back, now: now)
        #expect(ids(archived) == ["BuiltInMicrophoneDevice", "usb-interface"])
        #expect(Set(archived.map(\.id)) == [channel1.id, front.id])
    }

    @Test
    func ageThresholdIsReversible() {
        let recent = makeMic("My stream (SRT(LA))", "srt", lastSeen: start + 25 * day)
        let old = makeMic("Lark M2 RX", "usb-lark", lastSeen: start + 2 * day)
        let unknown = makeMic("Wireless microphone", "usb-old")
        let hidden = makeMic("AirPods Pro", "bt-1", lastSeen: start + 29 * day)
        hidden.archive = .hidden
        let settings = makeMics([recent, old, unknown, hidden])
        let now = start + 33 * day
        #expect(ids(settings.visibleMics(current: noMic, now: now)) == ["srt"])
        #expect(ids(settings.archivedMics(current: noMic, now: now)) == ["bt-1", "usb-lark", "usb-old"])
        settings.archiveAfterDays = 7
        #expect(settings.visibleMics(current: noMic, now: now).isEmpty)
        settings.archiveAfterDays = 0
        #expect(ids(settings.visibleMics(current: noMic, now: now)) == ["srt", "usb-lark", "usb-old"])
        #expect(ids(settings.archivedMics(current: noMic, now: now)) == ["bt-1"])
        settings.archiveAfterDays = 90
        #expect(ids(settings.visibleMics(current: noMic, now: now)) == ["srt", "usb-lark", "usb-old"])
    }

    @Test
    func hideAllLeavesAgeArchivedMicsToTheThreshold() {
        let recent = makeMic("My stream (SRT(LA))", "srt", lastSeen: start + 25 * day)
        let old = makeMic("Lark M2 RX", "usb-lark", lastSeen: start)
        let settings = makeMics([recent, old])
        let now = start + 33 * day
        settings.hideAllDisconnected(current: noMic, now: now)
        #expect(recent.archive == .hidden)
        #expect(old.archive == .automatic)
        settings.archiveAfterDays = 0
        #expect(ids(settings.visibleMics(current: noMic, now: now)) == ["usb-lark"])
    }

    @Test
    func restoredMicStaysUntilItReconnects() {
        let mic = makeMic("Lark M2 RX", "usb-lark", lastSeen: start)
        let settings = makeMics([mic])
        let now = start + 60 * day
        #expect(settings.isArchived(mic: mic, current: noMic, now: now))
        settings.restore(mic: mic)
        #expect(mic.archive == .shown)
        #expect(!settings.isArchived(mic: mic, current: noMic, now: now + 365 * day))
        mic.setConnected(true, now: now)
        mic.setConnected(false, now: now + day)
        #expect(mic.archive == .automatic)
        #expect(!settings.isArchived(mic: mic, current: noMic, now: now + 2 * day))
        #expect(settings.isArchived(mic: mic, current: noMic, now: now + 31 * day))
    }

    @Test
    func moveAmongVisibleMicsKeepsArchivedPriorities() {
        let settings = makeMics([makeMic("A", "a", connected: true),
                                 makeMic("Old 1", "x", lastSeen: start),
                                 makeMic("B", "b", connected: true),
                                 makeMic("C", "c", connected: true),
                                 makeMic("Old 2", "y", lastSeen: start)])
        let now = start + 40 * day
        let visible = settings.visibleMics(current: noMic, now: now)
        #expect(ids(visible) == ["a", "b", "c"])
        settings.moveVisibleMics(visible, fromOffsets: IndexSet(integer: 2), toOffset: 0)
        #expect(ids(settings.mics) == ["c", "x", "a", "b", "y"])
        let visible2 = settings.visibleMics(current: noMic, now: now)
        settings.moveVisibleMics(visible2, fromOffsets: IndexSet(integer: 0), toOffset: 3)
        #expect(ids(settings.mics) == ["a", "x", "b", "c", "y"])
    }

    @Test
    func deleteVisibleAndArchivedRows() {
        let settings = makeMics([makeMic("A", "a", connected: true),
                                 makeMic("Old 1", "x", lastSeen: start),
                                 makeMic("B", "b", connected: true),
                                 makeMic("Old 2", "y", lastSeen: start + day)])
        let now = start + 40 * day
        settings.removeMics(settings.visibleMics(current: noMic, now: now), atOffsets: IndexSet(integer: 1))
        #expect(ids(settings.mics) == ["a", "x", "y"])
        let archived = settings.archivedMics(current: noMic, now: now)
        #expect(ids(archived) == ["y", "x"])
        settings.removeMic(archived[0])
        #expect(ids(settings.mics) == ["a", "x"])
    }

    @Test
    func archivedMicsAreNewestFirstAndUnknownLastInPriorityOrder() {
        let settings = makeMics([makeMic("U1", "u1"),
                                 makeMic("Old", "old", lastSeen: start),
                                 makeMic("U2", "u2"),
                                 makeMic("New", "new", lastSeen: start + day)],
                                since: start)
        let now = start + 60 * day
        #expect(ids(settings.archivedMics(current: noMic, now: now)) == ["new", "old", "u1", "u2"])
    }

    @Test
    func networkRowsFollowTheirConfiguredStreams() {
        let id = UUID().uuidString
        let rtmp = makeMic(rtmpCamera(name: "Guest phone"), id, connected: true, lastSeen: start)
        rtmp.mixed = true
        rtmp.archive = .hidden
        var mics = syncMicsList(mics: [rtmp],
                                found: [makeMic(rtmpCamera(name: "Guest phone"), id, connected: true)],
                                isKind: { $0.isRtmp() },
                                removeMissing: true,
                                now: start + day)
        #expect(mics.count == 1)
        #expect(mics[0] === rtmp)
        #expect(rtmp.archive == .automatic)
        #expect(rtmp.mixed)
        mics = syncMicsList(
            mics: mics,
            found: [],
            isKind: { $0.isRtmp() },
            removeMissing: true,
            now: start + day
        )
        #expect(mics.isEmpty)
    }

    @Test
    func lastSeenText() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let unknown = String(localized: "Last seen unknown")
        #expect(formatMicLastSeen(nil) == unknown)
        let now = Date.now
        let today = formatMicLastSeen(now, now: now, calendar: calendar)
        #expect(today != unknown)
        #expect(today.contains(now.formatted(date: .omitted, time: .shortened)))
        let old = now - 400 * day
        #expect(formatMicLastSeen(old, now: now, calendar: calendar)
            .contains(old.formatted(date: .abbreviated, time: .omitted)))
    }
}
