import Foundation

// MARK: - Share Mirror Structs (Codable, not @Model)

struct SharePayload: Codable {
    var gameID: UUID
    var date: Date
    var players: [SharePlayer]
    var rounds: [ShareRound]
    var eliminatedSlotIDs: [UUID]
    var winnerSlotID: UUID?
    var isComplete: Bool
}

struct SharePlayer: Codable {
    var slotID: UUID
    var playerTag: String
    var displayName: String
    var runningTotal: Int
    var isEliminated: Bool
}

struct ShareRound: Codable {
    var roundNumber: Int
    var scores: [String: Int] // UUID.uuidString keys — JSON requires String keys
    var timestamp: Date
}

// MARK: - Errors

enum ShareError: LocalizedError {
    case invalidURL
    case encodingFailed
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "The share link is invalid or malformed."
        case .encodingFailed: return "Could not encode game data for sharing."
        case .decodingFailed: return "Could not decode the shared game data."
        }
    }
}

// MARK: - Encoder

enum ShareEncoder {

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    // MARK: Encode GameSession → URL

    static func encode(_ session: GameSession) throws -> URL {
        let payload = SharePayload(
            gameID: session.id,
            date: session.date,
            players: session.sortedPlayers.map { player in
                SharePlayer(
                    slotID: player.slotID,
                    playerTag: player.playerTag,
                    displayName: player.displayName,
                    runningTotal: player.runningTotal,
                    isEliminated: player.isEliminated
                )
            },
            rounds: session.sortedRounds.map { round in
                ShareRound(
                    roundNumber: round.roundNumber,
                    scores: Dictionary(
                        uniqueKeysWithValues: round.scores.map { (k, v) in (k.uuidString, v) }
                    ),
                    timestamp: round.timestamp
                )
            },
            eliminatedSlotIDs: session.eliminatedSlotIDs,
            winnerSlotID: session.winnerSlotID,
            isComplete: session.isComplete
        )

        let data = try encoder.encode(payload)
        let base64 = data.base64EncodedString()
        // URL-safe base64: replace + → -, / → _, strip padding =
        let urlSafe = base64
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        var components = URLComponents()
        components.scheme = "rummytracker"
        components.host = "game"
        components.queryItems = [URLQueryItem(name: "data", value: urlSafe)]

        guard let url = components.url else { throw ShareError.encodingFailed }
        return url
    }

    // MARK: Decode URL → SharePayload

    static func decode(_ url: URL) throws -> SharePayload {
        guard url.scheme == "rummytracker",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let dataItem = components.queryItems?.first(where: { $0.name == "data" }),
              let urlSafe = dataItem.value
        else { throw ShareError.invalidURL }

        // Reverse URL-safe encoding and restore padding
        var base64 = urlSafe
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let paddingNeeded = (4 - base64.count % 4) % 4
        base64 += String(repeating: "=", count: paddingNeeded)

        guard let data = Data(base64Encoded: base64) else { throw ShareError.decodingFailed }

        do {
            return try decoder.decode(SharePayload.self, from: data)
        } catch {
            throw ShareError.decodingFailed
        }
    }
}
