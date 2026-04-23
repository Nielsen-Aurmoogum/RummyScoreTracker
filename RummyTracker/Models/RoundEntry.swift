import Foundation
import SwiftData

@Model
final class RoundEntry {
    var id: UUID
    var roundNumber: Int
    // JSON-encoded [String: Int] where keys are UUID.uuidString (slotIDs)
    var scoresData: Data
    var timestamp: Date

    var session: GameSession?

    init(roundNumber: Int, scores: [UUID: Int], timestamp: Date = .now) {
        self.id = UUID()
        self.roundNumber = roundNumber
        self.timestamp = timestamp
        self.scoresData = RoundEntry.encode(scores)
    }

    // MARK: - Scores Computed Property

    var scores: [UUID: Int] {
        get { RoundEntry.decode(scoresData) }
        set { scoresData = RoundEntry.encode(newValue) }
    }

    // MARK: - Encode / Decode Helpers

    private static func encode(_ scores: [UUID: Int]) -> Data {
        let stringKeyed = Dictionary(
            uniqueKeysWithValues: scores.map { (k, v) in (k.uuidString, v) }
        )
        return (try? JSONEncoder().encode(stringKeyed)) ?? Data()
    }

    private static func decode(_ data: Data) -> [UUID: Int] {
        guard let decoded = try? JSONDecoder().decode([String: Int].self, from: data) else {
            return [:]
        }
        return Dictionary(
            uniqueKeysWithValues: decoded.compactMap { k, v in
                UUID(uuidString: k).map { ($0, v) }
            }
        )
    }
}
