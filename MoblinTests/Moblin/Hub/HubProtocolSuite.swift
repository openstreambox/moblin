import Foundation
@testable import Moblin
import Testing

// Written by the hub's own joinLink() (server/hub/tickets.ts) for the
// transcript's hub key.
private let sampleLink = "osb-hub://join#v=1&h=ws%3A%2F%2F192.0.2.10%3A7840%2Fhub%2Fv1"
    + "&h=wss%3A%2F%2Fhub.example.org%2Fhub%2Fv1&t=ABEiM0RVZneImaq7zN3u_w"
    + "&fp=GutExPD1wgwE4-X9a6juTfKMUfAitOFU-7m7OqcTU7A&n=Rig+hub+%26+co"

private func state(live: String = "ready",
                   output: String = "off",
                   program: String? = nil,
                   hidden: Bool = false,
                   generation: Int = 0,
                   feeds: [HubFeed] = [],
                   devices: [HubDevice] = []) -> HubState
{
    HubState(session: HubSession(id: "s1",
                                 live: live,
                                 program: program,
                                 privacy: HubPrivacy(hidden: hidden, generation: generation),
                                 output: HubOutput(state: output)),
             feeds: feeds,
             devices: devices)
}

private let phone = HubDevice(id: "dev-phone", name: "iPhone 12", kind: "phone", role: "member",
                              allowed: true, online: true, feed: true)
private let pc = HubDevice(id: "dev-pc", name: "Mac", kind: "pc", role: "admin", allowed: true,
                           online: true, feed: true)

private func feed(_ device: String, _ state: String, links: Int? = nil, black: Bool? = false) -> HubFeed {
    HubFeed(device: device, state: state, picture: nil, black: black, sound: nil, srtlaLinks: links)
}

struct HubProtocolSuite {
    @Test
    func parsesTheHubsJoinLink() throws {
        let link = try HubJoinLink(text: sampleLink)
        #expect(link.hub.map(\.absoluteString) == ["ws://192.0.2.10:7840/hub/v1", "wss://hub.example.org/hub/v1"])
        #expect(link.ticket == Data([0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77,
                                     0x88, 0x99, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF]))
        #expect(link.name == "Rig hub & co")
        let hubKey = try HubKeyPair(privateKey: Data((0x10 ... 0x2F).map { UInt8($0) }))
        #expect(hubFingerprint(hubKey.publicKey) == link.fingerprint)
    }

    @Test
    func refusesLinksThatAreNotHubTickets() {
        #expect(throws: HubJoinLinkError.notAJoinLink) {
            try HubJoinLink(text: "moblin://?{}")
        }
        #expect(throws: HubJoinLinkError.unsupportedVersion) {
            try HubJoinLink(text: sampleLink.replacingOccurrences(of: "v=1", with: "v=2"))
        }
        #expect(throws: HubJoinLinkError.badTicket) {
            try HubJoinLink(text: sampleLink.replacingOccurrences(of: "ABEiM0RVZneImaq7zN3u_w", with: "ABEi"))
        }
        #expect(throws: HubJoinLinkError.noHubAddress) {
            try HubJoinLink(text: "osb-hub://join#v=1&h=http%3A%2F%2Fexample.org&t=ABEiM0RVZneImaq7zN3u_w"
                + "&fp=GutExPD1wgwE4-X9a6juTfKMUfAitOFU-7m7OqcTU7A")
        }
    }

    @Test
    func base64UrlRoundTrips() {
        for length in 0 ..< 40 {
            let data = Data((0 ..< length).map { UInt8(($0 * 37 + 11) & 0xFF) })
            #expect(hubBase64UrlDecode(hubBase64UrlEncode(data)) == data)
        }
    }

    @Test
    func readsTheWelcome() throws {
        let json = """
        {"type":"welcome","device":{"id":"dev-phone","name":"iPhone 12","kind":"phone","role":"member",
        "allowed":true,"joined_at":"2026-11-16T10:00:00Z","online":true,"feed":true},
        "hub":{"name":"Hub","fingerprint":"x","protocol":"osb-hub/1"},
        "provision":{"srt":{"host":"192.0.2.10","port":7850,"stream_id":"#!::r=dev-phone,m=publish",
        "passphrase":"secretsecret","latency_ms":2000,
        "url":"srt://192.0.2.10:7850?streamid=%23!%3A%3Ar%3Ddev-phone%2Cm%3Dpublish&passphrase=secretsecret&latency=2000"},
        "srtla":{"host":"192.0.2.10","port":7851,"url":"srtla://192.0.2.10:7851?streamid=x&passphrase=y&latency=2000"}},
        "state":{"session":{"id":"s1","live":"ready","since":"","program":null,"program_since":null,
        "privacy":{"hidden":false,"generation":0},"output":{"state":"off","target":"test-sink","since":0,"frames":0},
        "mixer":"builtin"},"feeds":[{"device":"dev-phone","state":"listening","since":0,"picture":null,
        "black":null,"sound":null}],"devices":[]}}
        """
        let message = try HubMessage(data: Data(json.utf8))
        #expect(message.type == "welcome")
        let provision = try #require(message.decode("provision", as: HubProvision.self))
        #expect(provision.srt.port == 7850)
        #expect(provision.srtla?.port == 7851)
        #expect(provision.remoteControl == nil)
        let state = try #require(message.decode("state", as: HubState.self))
        #expect(state.feed("dev-phone")?.state == "listening")
        #expect(state.feed("dev-phone")?.picture == nil)
        #expect(!state.isLive)
    }

    @Test
    func encodesRequests() throws {
        let data = try hubEncodeRequest(id: 3, type: "privacy.show", params: ["generation": 2])
        #expect(String(decoding: data, as: UTF8.self) == "{\"generation\":2,\"id\":3,\"type\":\"privacy.show\"}")
    }

    private func status(_ state: HubState?, connected: Bool = true, pending: Bool = false) -> HubStatus {
        hubStatus(state: state, me: "dev-phone", connected: connected, pending: pending)
    }

    @Test
    func neverSaysNotLiveWhileTheOutputIsLive() {
        let cases: [HubState] = [
            state(live: "live", output: "live", program: "dev-pc", feeds: [feed("dev-phone", "listening")],
                  devices: [pc, phone]),
            state(live: "live", output: "live", program: "dev-phone", feeds: [feed("dev-phone", "checked", links: 2)],
                  devices: [pc, phone]),
            state(live: "live", output: "live", program: "dev-pc", hidden: true, generation: 3,
                  feeds: [feed("dev-phone", "lost")], devices: [pc, phone]),
            state(live: "live", output: "live", program: "dev-pc", feeds: [feed("dev-phone", "lost")],
                  devices: [pc, phone]),
            state(live: "live", output: "live", program: "dev-pc",
                  feeds: [feed("dev-pc", "lost"), feed("dev-phone", "checked")], devices: [pc, phone]),
            state(live: "live", output: "live", program: nil, feeds: [], devices: [pc, phone]),
        ]
        for one in cases {
            let status = status(one)
            #expect(status.title.hasPrefix("LIVE"), "\(status.title)")
            for text in [status.text, status.spoken] {
                #expect(!text.lowercased().contains("not live"))
                #expect(!text.lowercased().contains("offline"))
                #expect(!text.lowercased().contains("ended"))
            }
        }
    }

    @Test
    func saysWhatViewersSee() {
        let onPc = state(live: "live", output: "live", program: "dev-pc",
                         feeds: [feed("dev-phone", "checked", links: 2)], devices: [pc, phone])
        #expect(status(onPc).kind == .live)
        #expect(status(onPc).title == "LIVE on Mac")
        #expect(status(onPc).line == "Viewers see Mac.")
        #expect(status(onPc).phone == "This phone connected · picture checked · 2 links · viewers still see Mac")
        #expect(status(onPc).text == "LIVE on Mac · this phone connected · 2 links")
        let onPhone = state(live: "live", output: "live", program: "dev-phone",
                            feeds: [feed("dev-phone", "checked", links: 3)], devices: [pc, phone])
        #expect(status(onPhone).text == "LIVE on this phone · 3 links")
        #expect(status(onPhone).line == "Viewers see this phone.")
        let hidden = state(live: "live", output: "live", program: "dev-phone", hidden: true, generation: 1,
                           feeds: [feed("dev-phone", "checked")], devices: [pc, phone])
        #expect(status(hidden).kind == .hidden)
        #expect(status(hidden).title == "LIVE · privacy screen on")
        #expect(status(hidden).line == "Your privacy screen is on. Viewers don't see you.")
        let standby = state(live: "live", output: "live", program: "dev-pc",
                            feeds: [feed("dev-pc", "lost"), feed("dev-phone", "checked")], devices: [pc, phone])
        #expect(status(standby).kind == .caution)
        #expect(status(standby).title == "LIVE · standby picture")
        #expect(status(standby).line == "The feed from Mac stalled. Viewers see the standby picture.")
    }

    @Test
    func beforeGoLiveTheStatusIsAboutConnecting() {
        let ready = state(feeds: [feed("dev-phone", "listening")], devices: [phone])
        #expect(status(ready).text == "Ready to connect")
        #expect(status(ready).kind == .ready)
        let checking = state(feeds: [feed("dev-phone", "receiving", links: nil, black: nil)], devices: [phone])
        #expect(status(checking).title == "Connecting to the hub")
        #expect(status(checking).line == "Checking the picture.")
        let dark = state(feeds: [feed("dev-phone", "receiving", links: nil, black: true)], devices: [phone])
        #expect(status(dark).line == "The hub sees a black picture.")
        let checked = state(feeds: [feed("dev-phone", "checked", links: 1)], devices: [phone])
        #expect(status(checked).text == "Connected · picture checked · 1 link")
        #expect(!status(checked).spoken.contains("LIVE"))
        #expect(!status(checked).spoken.lowercased().contains("live"))
        #expect(status(checked).kind == .connected)
    }

    @Test
    func aLostConnectionSaysCantSay() {
        let live = state(live: "live", output: "live", program: "dev-phone", devices: [phone])
        let lost = status(live, connected: false)
        #expect(lost.kind == .unknown)
        #expect(lost.title == "Can't say right now")
        #expect(!lost.spoken.lowercased().contains("not live"))
        #expect(status(nil, pending: true).title == "Waiting for Allow")
    }

    @Test
    func streamEndedOnlyAfterEnd() {
        let ended = state(live: "ended", feeds: [feed("dev-phone", "listening")], devices: [phone])
        #expect(status(ended).text == "Stream ended · Not sending yet")
        let ready = state(feeds: [feed("dev-phone", "listening")], devices: [phone])
        #expect(!status(ready).spoken.contains("ended"))
    }

    @Test
    func listsOnlyReportedMeasurements() {
        #expect(hubFacts(nil) == [])
        #expect(hubFacts(feed("dev-phone", "receiving")) == [])
        let measured = HubFeed(device: "dev-phone", state: "checked",
                               picture: HubPicture(width: 1280, height: 720, fps: 29.97),
                               black: false, sound: "silent", srtlaLinks: nil)
        // Labels and words follow the app's language; the values don't.
        let facts = hubFacts(measured)
        #expect(facts.count == 2)
        #expect(facts.first?.value == "1280×720 · 30 fps")
        #expect(hubFacts(feed("dev-phone", "checked", links: 2)).map(\.value) == ["2"])
    }

    private func controls(_ state: HubState,
                          role: String = "member",
                          sending: Bool = false,
                          requested: Set<HubRequestKind> = []) -> HubControls
    {
        hubControls(state: state, me: "dev-phone", role: role, sending: sending, requested: requested, now: Date())
    }

    @Test
    func offersOnlyWhatTheHubAllows() {
        let ready = state(feeds: [feed("dev-phone", "listening")], devices: [phone])
        #expect(controls(ready) == HubControls(feed: .connect, move: nil, privacy: .hide))
        let checkedNotLive = state(feeds: [feed("dev-phone", "checked")], devices: [phone])
        #expect(controls(checkedNotLive) == HubControls(feed: .connected, move: nil, privacy: .hide))
        let live = state(live: "live", output: "live", program: "dev-pc",
                         feeds: [feed("dev-phone", "checked")], devices: [pc, phone])
        #expect(controls(live) == HubControls(feed: .connected, move: .offer, privacy: .hide))
        let liveNotConnected = state(live: "live", output: "live", program: "dev-pc",
                                     feeds: [feed("dev-phone", "listening")], devices: [pc, phone])
        #expect(controls(liveNotConnected).move == nil)
        let hidden = state(live: "live", output: "live", program: "dev-phone", hidden: true, generation: 4,
                           feeds: [feed("dev-phone", "checked")], devices: [phone])
        #expect(controls(hidden).privacy == .hidden(generation: 4, canShow: true))
        #expect(controls(hidden, role: "helper").privacy == .hidden(generation: 4, canShow: false))
        #expect(controls(hidden).move == .onAir)
        #expect(hubControls(state: nil, me: "dev-phone", role: "member", sending: false, requested: [], now: Date())
            == .none)
    }

    @Test
    func aRequestReadsAsUnconfirmedUntilTheHubShowsIt() {
        let live = state(live: "live", output: "live", program: "dev-pc",
                         feeds: [feed("dev-phone", "checked")], devices: [pc, phone])
        let all: Set<HubRequestKind> = [.move, .hide]
        #expect(controls(live, requested: all).move == .requested)
        #expect(controls(live, requested: all).privacy == .hideRequested)
        #expect(hubOpenRequests(all, state: live, me: "dev-phone") == all)
        let moved = state(live: "live", output: "live", program: "dev-phone",
                          feeds: [feed("dev-phone", "checked")], devices: [pc, phone])
        #expect(hubOpenRequests(all, state: moved, me: "dev-phone") == [.hide])
        #expect(controls(moved, requested: [.hide]).move == .onAir)
        let hidden = state(live: "live", output: "live", program: "dev-phone", hidden: true, generation: 5,
                           feeds: [feed("dev-phone", "checked")], devices: [pc, phone])
        #expect(hubOpenRequests([.hide], state: hidden, me: "dev-phone") == [])
        #expect(controls(hidden, requested: [.show]).privacy == .showRequested)
        #expect(hubOpenRequests([.show], state: hidden, me: "dev-phone") == [.show])
        #expect(hubOpenRequests([.show], state: moved, me: "dev-phone") == [])
        // Without a state nothing is taken as confirmed.
        #expect(hubOpenRequests(all, state: nil, me: "dev-phone") == all)
    }

    @Test
    func connectAndDisconnectFollowTheHubsFeedReport() {
        let listening = state(feeds: [feed("dev-phone", "listening")], devices: [phone])
        #expect(controls(listening, sending: true).feed == .connecting)
        #expect(controls(listening, requested: [.connect]).feed == .connecting)
        let receiving = state(feeds: [feed("dev-phone", "receiving")], devices: [phone])
        #expect(controls(receiving, sending: true).feed == .connecting)
        #expect(hubOpenRequests([.connect], state: receiving, me: "dev-phone") == [.connect])
        let checked = state(feeds: [feed("dev-phone", "checked")], devices: [phone])
        #expect(hubOpenRequests([.connect], state: checked, me: "dev-phone") == [])
        #expect(controls(checked, requested: [.disconnect]).feed == .disconnecting)
        #expect(hubOpenRequests([.disconnect], state: checked, me: "dev-phone") == [.disconnect])
        #expect(hubOpenRequests([.disconnect], state: listening, me: "dev-phone") == [])
    }

    @Test
    func hideShowsTheActionOrTheState() {
        let unreachable = "Can't reach your hub right now. HIDE works again once it answers."
        let action = hubHideControl(.hide, reachable: true)
        #expect(action == HubHideControl(face: .action, pressable: true, disabled: false))
        #expect(action?.word == "HIDE")
        #expect(hubHideControl(.hideRequested, reachable: true)
            == HubHideControl(face: .action, pressable: false, disabled: false, requested: true))
        #expect(hubHideControl(.hide, reachable: false)
            == HubHideControl(face: .action, pressable: false, disabled: true, reason: unreachable))
        let state = hubHideControl(.hidden(generation: 4, canShow: true), reachable: true)
        #expect(state == HubHideControl(face: .state, pressable: false, disabled: false,
                                        show: .offer(generation: 4)))
        #expect(state?.word == "Privacy screen on")
        #expect(hubHideControl(.hidden(generation: 4, canShow: true), reachable: false)
            == HubHideControl(face: .state, pressable: false, disabled: true, reason: unreachable,
                              show: .unreachable))
        let helper = HubHideControl(face: .state, pressable: false, disabled: true,
                                    reason: "Only the streamer can show the picture again.")
        #expect(hubHideControl(.hidden(generation: 4, canShow: false), reachable: true) == helper)
        #expect(hubHideControl(.hidden(generation: 4, canShow: false), reachable: false) == helper)
        #expect(hubHideControl(.showRequested, reachable: true)
            == HubHideControl(face: .state, pressable: false, disabled: false, show: .requested))
        #expect(hubHideControl(nil, reachable: true) == nil)
    }

    @Test
    func connectIsFilledOnlyWhileItIsTheNextStep() {
        let ready = state(feeds: [feed("dev-phone", "listening")], devices: [phone])
        #expect(hubConnectIsPrimary(ready, allowWaits: false))
        #expect(!hubConnectIsPrimary(ready, allowWaits: true))
        let live = state(live: "live", output: "live", program: "dev-pc",
                         feeds: [feed("dev-phone", "listening")], devices: [pc, phone])
        #expect(!hubConnectIsPrimary(live, allowWaits: false))
        let ended = state(live: "ended", feeds: [feed("dev-phone", "listening")], devices: [phone])
        #expect(!hubConnectIsPrimary(ended, allowWaits: false))
        #expect(!hubConnectIsPrimary(nil, allowWaits: false))
    }
}
