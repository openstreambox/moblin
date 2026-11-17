import CryptoKit
import Foundation

struct HubOwnership: Codable, Equatable {
    var root: String
    var epoch: Int
    var points: [Point]
    var lineage: Int?

    struct Point: Codable, Equatable {
        var epoch: Int
        var hash: String
        var takeover: Bool
    }

    var counterLineage: Int {
        lineage ?? points.last(where: \.takeover)?.epoch ?? points.first?.epoch ?? 1
    }

    private static func recordData(_ record: [String: Any], signature: Bool) throws -> Data {
        let fields = record["kind"] as? String == "base"
            ? ["v", "kind", "epoch", "owner", "hubKey", "previous"]
            : [
                "v",
                "epoch",
                "from",
                "to",
                "urls",
                "hubKey",
                "previous",
                "checkpoint",
                "kind",
                "fenced",
                "signer",
            ]
        let keys = fields + (signature ? ["signature"] : [])
        let parts = try keys.compactMap { key -> String? in
            guard let value = record[key] else { return nil }
            let data = try JSONSerialization.data(withJSONObject: value,
                                                  options: [.fragmentsAllowed, .withoutEscapingSlashes])
            return "\"\(key)\":" + String(decoding: data, as: UTF8.self)
        }
        return Data(("{" + parts.joined(separator: ",") + "}").utf8)
    }

    private static func verify(_ record: [String: Any], key: String) throws {
        guard let der = hubBase64UrlDecode(key), der.count == 44,
              der.prefix(12) == Data([
                  0x30,
                  0x2A,
                  0x30,
                  0x05,
                  0x06,
                  0x03,
                  0x2B,
                  0x65,
                  0x70,
                  0x03,
                  0x21,
                  0x00,
              ]),
              let signature = (record["signature"] as? String).flatMap(hubBase64UrlDecode),
              let publicKey = try? Curve25519.Signing.PublicKey(rawRepresentation: der.suffix(32)),
              try publicKey.isValidSignature(signature, for: recordData(record, signature: false))
        else { throw HubConnectionError.invalid("invalid ownership signature") }
    }

    static func read(_ hub: [String: Any], hubKey: String, held: HubOwnership?,
                     epoch: Int?) throws -> HubOwnership?
    {
        let fail = HubConnectionError.invalid("stale or conflicting ownership")
        guard let nextEpoch = hubWholeNumber(hub["epoch"]), nextEpoch >= (epoch ?? 0) else { throw fail }
        guard let proof = hub["ownership"] as? [String: Any] else {
            guard held == nil else { throw fail }
            return nil
        }
        guard let root = proof["root"] as? String, held == nil || held?.root == root,
              hubWholeNumber(proof["epoch"]) == nextEpoch,
              let chain = proof["chain"] as? [[String: Any]] else { throw fail }
        var points = [Point(epoch: 1, hash: "", takeover: false)]
        var owner: String?
        var tipKey: String?
        if let base = proof["base"] as? [String: Any] {
            guard hubWholeNumber(base["v"]) == 2, base["kind"] as? String == "base",
                  let number = hubWholeNumber(base["epoch"]), number >= 2,
                  let previous = base["previous"] as? String,
                  let name = base["owner"] as? String, let key = base["hubKey"] as? String else { throw fail }
            try verify(base, key: root)
            points = [Point(epoch: number, hash: previous, takeover: false)]
            owner = name
            tipKey = key
        }
        for record in chain {
            let last = points.last!
            let kind = record["kind"] as? String
            guard hubWholeNumber(record["v"]) == 2,
                  let number = hubWholeNumber(record["epoch"]), number > last.epoch,
                  record["previous"] as? String == last.hash,
                  let to = record["to"] as? String, let key = record["hubKey"] as? String,
                  kind == "transfer" || kind == "takeover" else { throw fail }
            if kind == "transfer" {
                let next = (last.epoch + 1) % 1000 == 0 ? last.epoch + 2 : last.epoch + 1
                guard number == next, owner == nil || record["from"] as? String == owner else { throw fail }
                try verify(record, key: root)
            } else {
                guard number % 1000 == 0, record["fenced"] as? Bool == true,
                      let signer = record["signer"] as? String else { throw fail }
                try verify(record, key: signer)
            }
            let hash = try SHA256.hash(data: recordData(record, signature: true)).map { String(
                format: "%02x",
                $0
            ) }.joined()
            points.append(Point(epoch: number, hash: hash, takeover: kind == "takeover"))
            owner = to
            tipKey = key
        }
        guard points.last?.epoch == nextEpoch, tipKey == nil || tipKey == hubKey else { throw fail }
        var lineage = points.last(where: \.takeover)?.epoch ?? points[0].epoch
        if let held {
            guard follows(held.points, points) else { throw fail }
            if !points.contains(where: \.takeover), points[0].epoch > 1,
               held.points.contains(where: { have in
                   points.contains { $0.epoch == have.epoch && $0.hash == have.hash }
               })
            {
                lineage = held.counterLineage
            }
        }
        return HubOwnership(root: root, epoch: nextEpoch, points: points, lineage: lineage)
    }

    private static func follows(_ have: [Point], _ got: [Point]) -> Bool {
        let newest = have.last!.epoch
        func wins(_ from: Int) -> Bool {
            got.dropFirst(from).contains { $0.takeover && $0.epoch > newest }
        }
        for (i, point) in have.enumerated() {
            guard let j = got.firstIndex(where: { $0.epoch == point.epoch && $0.hash == point.hash })
            else { continue }
            let mine = Array(have.dropFirst(i + 1))
            let theirs = Array(got.dropFirst(j + 1))
            for (n, one) in mine.enumerated() {
                guard n < theirs.count else { return false }
                if one.hash != theirs[n].hash {
                    return wins(j + 1 + n)
                }
            }
            return true
        }
        return got[0].epoch > newest || wins(1)
    }
}

struct HubAccessFloor: Codable, Equatable {
    var seq: Int
    var lineage: Int

    static func strongest(_ one: HubAccessFloor?, _ other: HubAccessFloor?) -> HubAccessFloor? {
        guard let one, let other else {
            return one ?? other
        }
        return (one.lineage, one.seq) >= (other.lineage, other.seq) ? one : other
    }
}

func hubValidateEvidence(
    _ message: HubMessage,
    hubKey: String,
    ownership: HubOwnership?,
    epoch: Int?,
    floor: HubAccessFloor?
) throws -> HubOwnership? {
    let state = message.object["state"] as? [String: Any]
    guard let hub = (message.object["hub"] ?? state?["hub"]) as? [String: Any] else {
        throw HubConnectionError.invalid("missing hub evidence")
    }
    let next = try HubOwnership.read(hub, hubKey: hubKey, held: ownership, epoch: epoch)
    let stateHub = state?["hub"] as? [String: Any]
    if state != nil {
        if let other = hubWholeNumber(stateHub?["epoch"]), other != hubWholeNumber(hub["epoch"]) {
            throw HubConnectionError.invalid("conflicting state epoch")
        }
        if let stateHub, stateHub["ownership"] != nil {
            _ = try HubOwnership.read(
                stateHub,
                hubKey: hubKey,
                held: next,
                epoch: hubWholeNumber(hub["epoch"])
            )
        }
    }
    if let floor, (next?.counterLineage ?? 1) <= floor.lineage {
        guard let seq = hubWholeNumber(((stateHub ?? hub)["access"] as? [String: Any])?["seq"]),
              seq >= floor.seq
        else {
            throw HubConnectionError.invalid("stale access evidence")
        }
    }
    return next
}
