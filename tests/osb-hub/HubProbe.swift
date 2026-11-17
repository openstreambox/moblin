import Foundation

// A command-line client built from the fork's own hub files
// (Moblin/Hub/*.swift), to check the Swift side against a running hub:
//
//   hub-probe join LINK IDENTITY   join with a one-time ticket (XXpsk0), save the identity
//   hub-probe connect IDENTITY     reconnect (IK) and run a few requests
//   hub-probe refused IDENTITY     expect the hub to refuse this identity (removed)
//   hub-probe wrong-hub LINK       expect a refusal before sending anything (bad fingerprint)
//
// Prints one JSON line per step; exits non-zero on the first failure.

struct Identity: Codable {
    var key: String
    var hubKey: String
    var urls: [String]
    var device: String
}

@MainActor
func say(_ object: [String: Any]) {
    let data = try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    print(String(decoding: data, as: UTF8.self))
}

@MainActor
func fail(_ step: String, _ error: Any) -> Never {
    say(["step": step, "ok": false, "error": "\(error)"])
    exit(1)
}

@MainActor
func load(_ path: String) -> (Identity, HubKeyPair) {
    guard let data = FileManager.default.contents(atPath: path),
          let identity = try? JSONDecoder().decode(Identity.self, from: data),
          let raw = hubBase64UrlDecode(identity.key),
          let key = try? HubKeyPair(privateKey: raw)
    else {
        fail("load", "no identity at \(path)")
    }
    return (identity, key)
}

@MainActor
func summary(_ welcome: HubMessage) -> [String: Any] {
    let device = welcome.object["device"] as? [String: Any]
    let provision = welcome.decode("provision", as: HubProvision.self)
    let state = welcome.decode("state", as: HubState.self)
    return [
        "type": welcome.type,
        "device": device?["id"] as? String ?? "",
        "role": device?["role"] as? String ?? "",
        "pending": welcome.bool("pending") ?? false,
        "provision_srt": provision.map { "\($0.srt.host):\($0.srt.port)" } ?? "none",
        "provision_has_passphrase": provision?.srt.url.contains("passphrase=") ?? false,
        "provision_srtla": provision?.srtla.map { "\($0.host):\($0.port)" } ?? "none",
        "session": state?.session.live ?? "none",
        "line": hubStatus(state: state,
                          me: device?["id"] as? String,
                          connected: true,
                          pending: welcome.bool("pending") ?? false).text,
    ]
}

@MainActor
func requests(_ connection: HubConnection, device: String) async {
    do {
        let reply = try await connection.request("state.get")
        let state = reply.decode("state", as: HubState.self)
        say(["step": "state.get", "ok": state != nil, "devices": state?.devices.count ?? -1])
        let hidden = try await connection.request("privacy.hide")
        let generation = hidden.int("generation") ?? -1
        say(["step": "privacy.hide", "ok": generation > 0, "generation": generation])
        do {
            _ = try await connection.request("privacy.show", ["generation": generation - 1])
            fail("privacy.show stale", "accepted a stale generation")
        } catch let error as HubRequestError {
            say(["step": "privacy.show stale", "ok": error.code == "stale_show", "code": error.code])
        }
        let shown = try await connection.request("privacy.show", ["generation": generation])
        say(["step": "privacy.show", "ok": shown.int("generation") == generation])
        let connect = try await connection.request("feed.connect", ["wait_ms": 0])
        say(["step": "feed.connect", "ok": connect.string("device") == device,
             "checked": connect.bool("checked") ?? false])
        do {
            _ = try await connection.request("stream.move", ["to": device])
            fail("stream.move", "moved before go live")
        } catch let error as HubRequestError {
            say(["step": "stream.move before live", "ok": error.code == "not_live", "code": error.code])
        }
        do {
            _ = try await connection.request("no.such.request")
        } catch let error as HubRequestError {
            say(["step": "unknown request", "ok": error.code == "unknown_request", "code": error.code])
        }
    } catch {
        fail("requests", error)
    }
}

@main
struct HubProbe {
    @MainActor
    static func main() async {
        let args = CommandLine.arguments
        guard args.count >= 3 else {
            print("usage: hub-probe join LINK IDENTITY | connect IDENTITY | refused IDENTITY | wrong-hub LINK")
            exit(2)
        }
        switch args[1] {
        case "join":
            guard args.count >= 4 else {
                exit(2)
            }
            let link: HubJoinLink
            do {
                link = try HubJoinLink(text: args[2])
            } catch {
                fail("parse", error)
            }
            let key = HubKeyPair.generate()
            let started = Date()
            do {
                let connection = try await HubConnection.join(link: link, key: key, name: "Probe", kind: "phone")
                var out = summary(connection.welcome)
                out["step"] = "join (XXpsk0)"
                out["ok"] = connection.welcome.type == "welcome"
                out["ms"] = Int(Date().timeIntervalSince(started) * 1000)
                out["fingerprint_checked"] = hubFingerprint(connection.hubKey) == link.fingerprint
                say(out)
                let device = out["device"] as? String ?? ""
                let identity = Identity(key: hubBase64UrlEncode(key.privateKey),
                                        hubKey: hubBase64UrlEncode(connection.hubKey),
                                        urls: link.hub.map(\.absoluteString),
                                        device: device)
                try JSONEncoder().encode(identity).write(to: URL(fileURLWithPath: args[3]))
                connection.close()
            } catch {
                fail("join (XXpsk0)", error)
            }
            // The same ticket must not work twice.
            do {
                let again = try await HubConnection.join(link: link, key: HubKeyPair.generate(),
                                                         name: "Probe 2", kind: "phone")
                again.close()
                fail("ticket reuse", "the hub accepted a used ticket")
            } catch {
                say(["step": "ticket reuse refused", "ok": (error as? HubConnectionError) == .refused,
                     "error": "\(error)"])
            }
        case "connect":
            let (identity, key) = load(args[2])
            let started = Date()
            do {
                let connection = try await HubConnection.connect(
                    urls: identity.urls.compactMap { URL(string: $0) },
                    key: key,
                    hubKey: hubBase64UrlDecode(identity.hubKey) ?? Data()
                )
                var out = summary(connection.welcome)
                out["step"] = "connect (IK)"
                out["ok"] = connection.welcome.type == "welcome" && out["device"] as? String == identity.device
                out["ms"] = Int(Date().timeIntervalSince(started) * 1000)
                say(out)
                await requests(connection, device: identity.device)
                connection.close()
            } catch {
                fail("connect (IK)", error)
            }
        case "refused":
            let (identity, key) = load(args[2])
            do {
                let connection = try await HubConnection.connect(
                    urls: identity.urls.compactMap { URL(string: $0) },
                    key: key,
                    hubKey: hubBase64UrlDecode(identity.hubKey) ?? Data()
                )
                connection.close()
                fail("refused", "the hub accepted a removed device")
            } catch {
                say(["step": "removed device refused", "ok": (error as? HubConnectionError) == .refused,
                     "error": "\(error)"])
            }
        case "wrong-hub":
            do {
                let link = try HubJoinLink(text: args[2])
                let connection = try await HubConnection.join(link: link, key: HubKeyPair.generate(),
                                                              name: "Probe", kind: "phone")
                connection.close()
                fail("wrong hub", "joined a hub whose key doesn't match")
            } catch {
                say(["step": "wrong fingerprint refused", "ok": (error as? HubConnectionError) == .wrongHub,
                     "error": "\(error)"])
            }
        default:
            exit(2)
        }
        exit(0)
    }
}
