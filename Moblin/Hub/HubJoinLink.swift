import Foundation

// The hub's one-time join link (osb-hub/1 protocol, section 2):
//
//   osb-hub://join#v=1&h=<ws url>&t=<ticket>&fp=<fingerprint>&n=<hub name>
//
// Everything is in the fragment. It carries no password: only where to dial,
// a 16-byte ticket that works once and dies 30 seconds after it was issued,
// and the SHA-256 fingerprint of the hub's static key.

let hubJoinScheme = "osb-hub"
let hubProtocolName = "osb-hub/1"
let hubPrologue = Data(hubProtocolName.utf8)
let hubModeJoin: UInt8 = 0x01
let hubModeConnect: UInt8 = 0x02
private let hubTicketLabel = Data("osb-hub/1 ticket".utf8)
let hubTicketBytes = 16

enum HubJoinLinkError: Error, Equatable {
    case notAJoinLink
    case unsupportedVersion
    case noHubAddress
    case badTicket
    case badFingerprint
}

struct HubJoinLink: Equatable {
    // Where to dial: one or more WebSocket URLs of the hub, tried in order.
    let hub: [URL]
    let ticket: Data
    // SHA-256 of the hub's static key, base64url without padding.
    let fingerprint: String
    let name: String?

    init(hub: [URL], ticket: Data, fingerprint: String, name: String?) {
        self.hub = hub
        self.ticket = ticket
        self.fingerprint = fingerprint
        self.name = name
    }

    init(text: String) throws {
        let prefix = "\(hubJoinScheme)://join#"
        guard text.hasPrefix(prefix) else {
            throw HubJoinLinkError.notAJoinLink
        }
        let fields = hubFormDecode(String(text.dropFirst(prefix.count)))
        guard fields.first(where: { $0.0 == "v" })?.1 == "1" else {
            throw HubJoinLinkError.unsupportedVersion
        }
        let hub = fields.filter { $0.0 == "h" }.compactMap { URL(string: $0.1) }.filter {
            $0.scheme == "ws" || $0.scheme == "wss"
        }
        guard !hub.isEmpty else {
            throw HubJoinLinkError.noHubAddress
        }
        guard let ticket = hubBase64UrlDecode(fields.first(where: { $0.0 == "t" })?.1 ?? ""),
              ticket.count == hubTicketBytes
        else {
            throw HubJoinLinkError.badTicket
        }
        let fingerprint = fields.first(where: { $0.0 == "fp" })?.1 ?? ""
        guard hubBase64UrlDecode(fingerprint)?.count == 32 else {
            throw HubJoinLinkError.badFingerprint
        }
        self.hub = hub
        self.ticket = ticket
        self.fingerprint = fingerprint
        let name = fields.first(where: { $0.0 == "n" })?.1
        self.name = name?.isEmpty == false ? name : nil
    }

    init(url: URL) throws {
        try self.init(text: url.absoluteString)
    }

    // The pre-shared key for XXpsk0: SHA-256 over a label and the ticket.
    var psk: Data {
        hubTicketPsk(ticket)
    }
}

func hubTicketPsk(_ ticket: Data) -> Data {
    hubSha256(hubTicketLabel + ticket)
}

func hubFingerprint(_ publicKey: Data) -> String {
    hubBase64UrlEncode(hubSha256(publicKey))
}

func hubBase64UrlEncode(_ data: Data) -> String {
    data.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

func hubBase64UrlDecode(_ text: String) -> Data? {
    var base64 = text
        .replacingOccurrences(of: "-", with: "+")
        .replacingOccurrences(of: "_", with: "/")
    guard !base64.contains("=") else {
        return nil
    }
    while base64.count % 4 != 0 {
        base64 += "="
    }
    return Data(base64Encoded: base64)
}

// application/x-www-form-urlencoded, as URLSearchParams writes it: "+" is a
// space, everything else percent-encoded. Keeps repeated keys in order.
func hubFormDecode(_ text: String) -> [(String, String)] {
    text.split(separator: "&", omittingEmptySubsequences: true).map { pair in
        let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
        let decode = { (part: Substring) in
            String(part).replacingOccurrences(of: "+", with: " ").removingPercentEncoding ?? String(part)
        }
        return (decode(parts[0]), parts.count > 1 ? decode(parts[1]) : "")
    }
}
