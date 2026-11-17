import Foundation
@testable import Moblin
import Testing

private let proofText = #"{"epoch":1000,"ownership":{"root":"MCowBQYDK2VwAyEA_RckOFqgx1tk-3jNYC-h2ZH96_drE8WO1wLqyDXp9hg","epoch":1000,"chain":[{"v":2,"epoch":1000,"from":"first","to":"second","urls":["ws://127.0.0.1:9000"],"hubKey":"synthetic-hub-key","previous":"","checkpoint":"synthetic-checkpoint","kind":"takeover","fenced":true,"signer":"MCowBQYDK2VwAyEA_RckOFqgx1tk-3jNYC-h2ZH96_drE8WO1wLqyDXp9hg","signature":"jnB7d87RNrxc1y7LIMuB_IEvXBScvDrI8F5pdOK_TgOl-ZfQO46m17kvchigKZxAOG8GIg9yTm31eTW5vC63Aw"}]}}"#

struct HubOwnershipSuite {
    private func proof() throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: Data(proofText.utf8)) as! [String: Any]
    }

    @Test
    func signedTakeoverPinsAndSurvivesPersistence() throws {
        let hub = try proof()
        let accepted = try HubOwnership.read(hub, hubKey: "synthetic-hub-key", held: nil, epoch: 1)
        let restored = try JSONDecoder().decode(
            HubOwnership.self,
            from: JSONEncoder().encode(#require(accepted))
        )
        #expect(try HubOwnership
            .read(hub, hubKey: "synthetic-hub-key", held: restored, epoch: 1000) == accepted)
        #expect(throws: (any Error).self) {
            try HubOwnership.read(["epoch": 999], hubKey: "synthetic-hub-key", held: restored, epoch: 1000)
        }
        #expect(throws: (any Error).self) {
            try HubOwnership.read(["epoch": 1000], hubKey: "synthetic-hub-key", held: restored, epoch: 1000)
        }
    }

    @Test
    func changedRootUnsignedEpochWrongKeyAndTamperedSignatureAreRejected() throws {
        let hub = try proof()
        let accepted = try HubOwnership.read(hub, hubKey: "synthetic-hub-key", held: nil, epoch: 1)
        #expect(throws: (any Error).self) {
            try HubOwnership.read(hub, hubKey: "different-key", held: accepted, epoch: 1000)
        }
        for field in ["root", "epoch", "chain"] {
            var changed = hub
            var ownership = try #require(changed["ownership"] as? [String: Any])
            if field == "root" {
                ownership[field] = "changed-root"
            }
            if field == "epoch" {
                ownership[field] = 2000
            }
            if field == "chain" {
                var chain = try #require(ownership[field] as? [[String: Any]])
                chain[0]["checkpoint"] = "tampered"
                ownership[field] = chain
            }
            changed["ownership"] = ownership
            #expect(throws: (any Error).self) {
                try HubOwnership.read(changed, hubKey: "synthetic-hub-key", held: accepted, epoch: 1000)
            }
        }
    }

    @Test
    func stateCannotLowerCounterWithinTheSameTakeoverLineage() throws {
        var message = try proof()
        message["type"] = "welcome"
        message["hub"] = try proof()
        message["state"] = ["hub": ["epoch": 1000, "access": ["seq": 40]]]
        #expect(throws: (any Error).self) {
            try hubValidateEvidence(HubMessage(object: message), hubKey: "synthetic-hub-key",
                                    ownership: nil, epoch: 1000, floor: HubAccessFloor(
                                        seq: 50,
                                        lineage: 1000
                                    ))
        }
        #expect(try hubValidateEvidence(HubMessage(object: message), hubKey: "synthetic-hub-key",
                                        ownership: nil, epoch: 3,
                                        floor: HubAccessFloor(seq: 50, lineage: 1)) !=
                nil)
    }

    @Test
    func newSetupDoesNotInheritAnotherDevicesEvidence() {
        var seen = HubSeen(accessSeq: 50, heardAt: 1000)
        seen.setup = "first-key:first-device"
        #expect(HubSeen.scoped(seen, setup: "second-key:second-device") == nil)
        #expect(HubSeen.scoped(seen, setup: "first-key:first-device") == seen)
    }
}
