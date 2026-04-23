import SwiftUI
import SwiftData

@Model
final class PlayerProfile {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var playerTag: String
    var name: String
    var avatarColorHex: String

    var avatarEmoji: String?   // optional fun emoji avatar

    // Statistics
    var gamesPlayed: Int
    var gamesWon: Int
    var currentWinStreak: Int
    var longestWinStreak: Int
    var totalPointsScored: Int
    var totalRoundsPlayed: Int

    @Relationship(deleteRule: .cascade, inverse: \MatchupRecord.owner)
    var matchupRecords: [MatchupRecord]

    init(name: String, avatarColorHex: String = "#4A90D9", avatarEmoji: String? = nil) {
        self.id = UUID()
        self.playerTag = PlayerProfile.generateTag(for: name)
        self.name = name
        self.avatarColorHex = avatarColorHex
        self.avatarEmoji = avatarEmoji
        self.gamesPlayed = 0
        self.gamesWon = 0
        self.currentWinStreak = 0
        self.longestWinStreak = 0
        self.totalPointsScored = 0
        self.totalRoundsPlayed = 0
        self.matchupRecords = []
    }

    // MARK: - Emoji Palette

    static let emojiPalette: [String] = [
        "🃏", "♠️", "♥️", "♦️", "♣️", "🎴",
        "🦊", "🐻", "🐼", "🦁", "🐯", "🐸",
        "🧙‍♂️", "🧝‍♀️", "🦹‍♂️", "🥷", "🧑‍🚀", "🧛",
        "🔥", "⚡️", "💎", "🌟", "🎯", "🏆",
        "😎", "🤠", "🥶", "🤩", "👻", "💀",
    ]

    // MARK: - Computed Properties

    var avatarColor: Color {
        get { Color(hex: avatarColorHex) }
        set { avatarColorHex = newValue.toHex() }
    }

    var winRate: Double {
        gamesPlayed > 0 ? Double(gamesWon) / Double(gamesPlayed) : 0
    }

    var avgPointsPerRound: Double {
        totalRoundsPlayed > 0 ? Double(totalPointsScored) / Double(totalRoundsPlayed) : 0
    }

    var initials: String {
        let words = name.split(separator: " ")
        if words.count >= 2 {
            return String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    // MARK: - Tag Generation

    static func generateTag(for name: String) -> String {
        let prefix = name.lowercased()
            .filter(\.isLetter)
            .prefix(8)
        let suffix = String(format: "%04d", Int.random(in: 0...9999))
        return "\(prefix)#\(suffix)"
    }
}

// MARK: - MatchupRecord

@Model
final class MatchupRecord {
    var opponentID: UUID
    var opponentTag: String
    var opponentName: String
    var gamesPlayedTogether: Int
    var winsAgainst: Int
    var totalPointsDifferential: Int

    var owner: PlayerProfile?

    init(opponentID: UUID, opponentTag: String, opponentName: String) {
        self.opponentID = opponentID
        self.opponentTag = opponentTag
        self.opponentName = opponentName
        self.gamesPlayedTogether = 0
        self.winsAgainst = 0
        self.totalPointsDifferential = 0
    }

    var winRate: Double {
        gamesPlayedTogether > 0 ? Double(winsAgainst) / Double(gamesPlayedTogether) : 0
    }

    var avgPointsDifferential: Double {
        gamesPlayedTogether > 0 ? Double(totalPointsDifferential) / Double(gamesPlayedTogether) : 0
    }
}
