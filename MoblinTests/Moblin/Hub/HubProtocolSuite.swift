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
        ]
        for one in cases {
            let line = hubStatusLine(state: one, me: "dev-phone", connected: true, pending: false)
            #expect(line.text.hasPrefix("LIVE"), "\(line.text)")
            #expect(!line.text.lowercased().contains("not live"))
            #expect(!line.text.lowercased().contains("offline"))
            #expect(line.level == .live)
        }
    }

    @Test
    func saysWhatViewersSee() {
        let onPc = state(live: "live", output: "live", program: "dev-pc",
                         feeds: [feed("dev-phone", "checked", links: 2)], devices: [pc, phone])
        #expect(hubStatusLine(state: onPc, me: "dev-phone", connected: true, pending: false).text
            == "LIVE · viewers see Mac · Phone connected · 2 links · picture checked")
        let onPhone = state(live: "live", output: "live", program: "dev-phone",
                            feeds: [feed("dev-phone", "checked", links: 3)], devices: [pc, phone])
        #expect(hubStatusLine(state: onPhone, me: "dev-phone", connected: true, pending: false).text
            == "LIVE · viewers see this phone · 3 links")
        let hidden = state(live: "live", output: "live", program: "dev-phone", hidden: true, generation: 1,
                           feeds: [feed("dev-phone", "checked")], devices: [pc, phone])
        #expect(hubStatusLine(state: hidden, me: "dev-phone", connected: true, pending: false).text
            == "LIVE · privacy screen on · viewers don't see you")
    }

    @Test
    func beforeGoLiveTheLineIsAboutConnecting() {
        let ready = state(feeds: [feed("dev-phone", "listening")], devices: [phone])
        #expect(hubStatusLine(state: ready, me: "dev-phone", connected: true, pending: false).text
            == "Ready to connect")
        let checking = state(feeds: [feed("dev-phone", "receiving", links: nil, black: nil)], devices: [phone])
        #expect(hubStatusLine(state: checking, me: "dev-phone", connected: true, pending: false).text
            == "Connecting to the hub · checking the picture")
        let dark = state(feeds: [feed("dev-phone", "receiving", links: nil, black: true)], devices: [phone])
        #expect(hubStatusLine(state: dark, me: "dev-phone", connected: true, pending: false).text
            == "Connecting to the hub · the hub sees a black picture")
        let checked = state(feeds: [feed("dev-phone", "checked", links: 1)], devices: [phone])
        let line = hubStatusLine(state: checked, me: "dev-phone", connected: true, pending: false)
        #expect(line.text == "Phone connected · 1 link · picture checked")
        #expect(!line.text.contains("LIVE"))
        #expect(line.level == .good)
    }

    @Test
    func aLostConnectionSaysCantSay() {
        let live = state(live: "live", output: "live", program: "dev-phone", devices: [phone])
        let line = hubStatusLine(state: live, me: "dev-phone", connected: false, pending: false)
        #expect(line.text.contains("can't say"))
        #expect(!line.text.lowercased().contains("not live"))
        #expect(hubStatusLine(state: nil, me: nil, connected: true, pending: true).text
            == "Waiting for an admin to allow this phone")
    }

    @Test
    func offersOnlyWhatTheHubAllows() {
        let ready = state(feeds: [feed("dev-phone", "listening")], devices: [phone])
        #expect(hubActions(state: ready, me: "dev-phone", role: "member") == [.hide, .connect])
        let checkedNotLive = state(feeds: [feed("dev-phone", "checked")], devices: [phone])
        #expect(hubActions(state: checkedNotLive, me: "dev-phone", role: "member") == [.hide])
        let live = state(live: "live", output: "live", program: "dev-pc",
                         feeds: [feed("dev-phone", "checked")], devices: [pc, phone])
        #expect(hubActions(state: live, me: "dev-phone", role: "member") == [.hide, .moveHere])
        let hidden = state(live: "live", output: "live", program: "dev-phone", hidden: true, generation: 4,
                           feeds: [feed("dev-phone", "checked")], devices: [phone])
        #expect(hubActions(state: hidden, me: "dev-phone", role: "member") == [.showPicture(generation: 4)])
        #expect(hubActions(state: hidden, me: "dev-phone", role: "helper") == [])
    }
}
