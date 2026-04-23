import Foundation
import SwiftData
import SwiftUI

// MARK: - GameSession

@Model
final class GameSession {
    @Attribute(.unique) var id: UUID
    var date: Date
    var isComplete: Bool
    var statsHaveBeenApplied: Bool
    var winnerSlotIDString: String?
    var eliminatedSlotIDStrings: [String]

    // Denormalized for @Query filtering by profile — stores profile id strings
    var participantProfileIDs: [String]

    @Relationship(deleteRule: .cascade, inverse: \GamePlayer.session)
    var players: [GamePlayer]

    @Relationship(deleteRule: .cascade, inverse: \RoundEntry.session)
    var rounds: [RoundEntry]

    init(date: Date = .now) {
        self.id = UUID()
        self.date = date
        self.isComplete = false
        self.statsHaveBeenApplied = false
        self.winnerSlotIDString = nil
        self.eliminatedSlotIDStrings = []
        self.participantProfileIDs = []
        self.players = []
        self.rounds = []
    }

    // MARK: - Computed Convenience

    var winnerSlotID: UUID? {
        get { winnerSlotIDString.flatMap { UUID(uuidString: $0) } }
        set { winnerSlotIDString = newValue?.uuidString }
    }

    var eliminatedSlotIDs: [UUID] {
        get { eliminatedSlotIDStrings.compactMap { UUID(uuidString: $0) } }
        set { eliminatedSlotIDStrings = newValue.map(\.uuidString) }
    }

    var activePlayers: [GamePlayer] {
        players
            .filter { !$0.isEliminated }
            .sorted { $0.turnOrder < $1.turnOrder }
    }

    var sortedPlayers: [GamePlayer] {
        players.sorted { $0.turnOrder < $1.turnOrder }
    }

    var currentRoundNumber: Int {
        rounds.count + 1
    }

    var winnerPlayer: GamePlayer? {
        guard let winnerSlotID else { return nil }
        return players.first { $0.slotID == winnerSlotID }
    }

    var sortedRounds: [RoundEntry] {
        rounds.sorted { $0.roundNumber < $1.roundNumber }
    }

    // Players sorted for scoreboard: active by score ascending, then eliminated greyed at bottom
    var scoreboardPlayers: [GamePlayer] {
        let active = players
            .filter { !$0.isEliminated }
            .sorted { $0.runningTotal < $1.runningTotal }
        let eliminated = eliminatedSlotIDs.compactMap { id in
            players.first { $0.slotID == id }
        }.reversed()
        return active + Array(eliminated)
    }
}

// MARK: - GamePlayer

@Model
final class GamePlayer {
    var slotID: UUID
    var playerTag: String
    var displayName: String
    var localProfileIDString: String?
    var runningTotal: Int
    var isEliminated: Bool
    var turnOrder: Int
    var avatarColorHex: String

    var session: GameSession?

    init(
        slotID: UUID = UUID(),
        playerTag: String,
        displayName: String,
        localProfileIDString: String? = nil,
        turnOrder: Int,
        avatarColorHex: String = "#4A90D9"
    ) {
        self.slotID = slotID
        self.playerTag = playerTag
        self.displayName = displayName
        self.localProfileIDString = localProfileIDString
        self.runningTotal = 0
        self.isEliminated = false
        self.turnOrder = turnOrder
        self.avatarColorHex = avatarColorHex
    }

    var localProfileID: UUID? {
        get { localProfileIDString.flatMap { UUID(uuidString: $0) } }
        set { localProfileIDString = newValue?.uuidString }
    }

    var initials: String {
        let words = displayName.split(separator: " ")
        if words.count >= 2 {
            return String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        }
        return String(displayName.prefix(2)).uppercased()
    }

    var avatarColor: SwiftUI.Color {
        SwiftUI.Color(hex: avatarColorHex)
    }
}
