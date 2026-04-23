import SwiftUI
import SwiftData

// MARK: - Profile Mapping (used in ClaimGameView / importGame)

enum ProfileMapping {
    case linked(UUID)           // link to an existing local profile
    case create(String)         // create a new profile with this name
    case skip                   // no tracking for this player on this device
}

// MARK: - GameStore

@MainActor
@Observable
final class GameStore {

    // MARK: - State

    var activeGame: GameSession?
    var pendingSharedGame: SharePayload?
    var isShowingClaimGame: Bool = false
    var isShowingUndoRound1Confirm: Bool = false
    var deepLinkError: String?

    private let modelContext: ModelContext

    // MARK: - Init

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadActiveGame()
    }

    // MARK: - Load Active Game

    func loadActiveGame() {
        var descriptor = FetchDescriptor<GameSession>(
            predicate: #Predicate { !$0.isComplete },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        activeGame = (try? modelContext.fetch(descriptor))?.first
    }

    // MARK: - Clear Completed Game

    /// Clears the active game reference after a completed game is dismissed.
    func clearCompletedActiveGame() {
        if activeGame?.isComplete == true {
            activeGame = nil
        }
    }

    // MARK: - Start Game

    func startGame(playerSlots: [(name: String, profileID: UUID?, avatarColorHex: String, playerTag: String)]) {
        let session = GameSession()
        modelContext.insert(session)

        for (index, slot) in playerSlots.enumerated() {
            let player = GamePlayer(
                playerTag: slot.playerTag,
                displayName: slot.name,
                localProfileIDString: slot.profileID?.uuidString,
                turnOrder: index,
                avatarColorHex: slot.avatarColorHex
            )
            session.players.append(player)
            modelContext.insert(player)
        }

        session.participantProfileIDs = playerSlots.compactMap { $0.profileID?.uuidString }

        save()
        activeGame = session
    }

    // MARK: - Add Round

    func addRound(scores: [UUID: Int]) {
        guard let game = activeGame, !game.isComplete else { return }

        let roundNumber = game.currentRoundNumber
        let round = RoundEntry(roundNumber: roundNumber, scores: scores)
        game.rounds.append(round)
        modelContext.insert(round)

        // Apply scores to players
        for player in game.players where !player.isEliminated {
            if let delta = scores[player.slotID] {
                player.runningTotal += delta
            }
        }

        // Process eliminations
        processEliminations(in: game)
        checkAndFinalizeGameOver(in: game)

        save()
    }

    // MARK: - Edit Round Score

    /// Edits a single player's score in a specific round, then recomputes all game state.
    func editRoundScore(in game: GameSession, roundID: UUID, playerSlotID: UUID, newScore: Int) {
        guard let round = game.rounds.first(where: { $0.id == roundID }) else { return }

        var scores = round.scores
        scores[playerSlotID] = max(0, newScore)
        round.scores = scores

        // Full recompute from scratch
        recomputeEliminations(in: game)
        checkAndFinalizeGameOver(in: game)

        save()
    }

    // MARK: - Undo Last Round

    func undoLastRound() {
        guard let game = activeGame else { return }

        if game.rounds.count == 1 {
            isShowingUndoRound1Confirm = true
            return
        }

        guard let lastRound = game.sortedRounds.last else { return }

        for player in game.players {
            if let delta = lastRound.scores[player.slotID] {
                player.runningTotal -= delta
            }
        }

        modelContext.delete(lastRound)
        recomputeEliminations(in: game)
        save()
    }

    func confirmUndoRound1() {
        guard let game = activeGame else { return }
        modelContext.delete(game)
        activeGame = nil
        save()
    }

    // MARK: - Elimination Processing

    private func processEliminations(in game: GameSession) {
        let newlyEliminated = game.players
            .filter { !$0.isEliminated && $0.runningTotal >= 101 }
            .sorted { $0.turnOrder < $1.turnOrder }

        guard !newlyEliminated.isEmpty else { return }

        for player in newlyEliminated {
            player.isEliminated = true
            game.eliminatedSlotIDStrings.append(player.slotID.uuidString)
        }
    }

    private func checkAndFinalizeGameOver(in game: GameSession) {
        let remaining = game.activePlayers

        if remaining.count == 1 {
            game.winnerSlotID = remaining[0].slotID
            game.isComplete = true
            updateStatistics(for: game)
        } else if remaining.count == 0 {
            let allEliminated = game.players.filter { $0.isEliminated }
            if let winner = allEliminated.min(by: { $0.runningTotal < $1.runningTotal }) {
                game.winnerSlotID = winner.slotID
            }
            game.isComplete = true
            updateStatistics(for: game)
        }
    }

    private func recomputeEliminations(in game: GameSession) {
        // Reset all players
        for player in game.players {
            player.isEliminated = false
            player.runningTotal = 0
        }
        game.eliminatedSlotIDStrings = []
        game.winnerSlotID = nil
        game.isComplete = false

        // Replay all remaining rounds
        for round in game.sortedRounds {
            for player in game.players where !player.isEliminated {
                if let delta = round.scores[player.slotID] {
                    player.runningTotal += delta
                }
            }
            processEliminations(in: game)
        }
    }

    // MARK: - Statistics Update

    private func updateStatistics(for session: GameSession) {
        guard !session.statsHaveBeenApplied, session.isComplete else { return }
        session.statsHaveBeenApplied = true

        let winnerSlotID = session.winnerSlotID

        var profileMap: [UUID: PlayerProfile] = [:]
        for player in session.players {
            guard let profileIDString = player.localProfileIDString,
                  let profileID = UUID(uuidString: profileIDString) else { continue }
            var descriptor = FetchDescriptor<PlayerProfile>(
                predicate: #Predicate { $0.id == profileID }
            )
            descriptor.fetchLimit = 1
            if let profile = (try? modelContext.fetch(descriptor))?.first {
                profileMap[player.slotID] = profile
            }
        }

        let roundCount = session.rounds.count

        for player in session.players {
            guard let profile = profileMap[player.slotID] else { continue }
            let isWinner = player.slotID == winnerSlotID

            profile.gamesPlayed += 1
            profile.totalRoundsPlayed += roundCount

            let playerTotal = session.rounds.reduce(0) { acc, round in
                acc + (round.scores[player.slotID] ?? 0)
            }
            profile.totalPointsScored += playerTotal

            if isWinner {
                profile.gamesWon += 1
                profile.currentWinStreak += 1
                if profile.currentWinStreak > profile.longestWinStreak {
                    profile.longestWinStreak = profile.currentWinStreak
                }
            } else {
                profile.currentWinStreak = 0
            }

            for opponentPlayer in session.players where opponentPlayer.slotID != player.slotID {
                guard let opponentProfile = profileMap[opponentPlayer.slotID] else { continue }

                let matchup = profile.matchupRecords.first { $0.opponentID == opponentProfile.id }
                    ?? createMatchupRecord(for: profile, opponent: opponentProfile)

                matchup.gamesPlayedTogether += 1
                if isWinner {
                    matchup.winsAgainst += 1
                }
                let differential = player.runningTotal - opponentPlayer.runningTotal
                matchup.totalPointsDifferential += differential
            }
        }

        save()
    }

    private func createMatchupRecord(for profile: PlayerProfile, opponent: PlayerProfile) -> MatchupRecord {
        let record = MatchupRecord(
            opponentID: opponent.id,
            opponentTag: opponent.playerTag,
            opponentName: opponent.name
        )
        record.owner = profile
        profile.matchupRecords.append(record)
        modelContext.insert(record)
        return record
    }

    // MARK: - Deep Link Handling

    func handleDeepLink(_ url: URL) {
        do {
            let payload = try ShareEncoder.decode(url)

            let gameID = payload.gameID
            let descriptor = FetchDescriptor<GameSession>(
                predicate: #Predicate { $0.id == gameID }
            )
            if let existing = (try? modelContext.fetch(descriptor))?.first {
                deepLinkError = "You already have this game from \(existing.date.friendlyFormat)."
                return
            }

            pendingSharedGame = payload
            isShowingClaimGame = true
        } catch {
            deepLinkError = "Could not read the shared game link."
        }
    }

    // MARK: - Import Game

    func importGame(_ payload: SharePayload, selfSlotID: UUID, mappings: [UUID: ProfileMapping]) {
        let session = GameSession(date: payload.date)
        modelContext.insert(session)

        for (index, sharePlayer) in payload.players.enumerated() {
            let profileIDString: String? = {
                switch mappings[sharePlayer.slotID] {
                case .linked(let id): return id.uuidString
                case .create(let name):
                    let profile = PlayerProfile(name: name)
                    modelContext.insert(profile)
                    return profile.id.uuidString
                case .skip, .none: return nil
                }
            }()

            let player = GamePlayer(
                slotID: sharePlayer.slotID,
                playerTag: sharePlayer.playerTag,
                displayName: sharePlayer.displayName,
                localProfileIDString: profileIDString,
                turnOrder: index,
                avatarColorHex: Color.avatarColor(at: index).toHex()
            )
            player.runningTotal = sharePlayer.runningTotal
            player.isEliminated = sharePlayer.isEliminated
            session.players.append(player)
            modelContext.insert(player)
        }

        for shareRound in payload.rounds {
            let scores = Dictionary(
                uniqueKeysWithValues: shareRound.scores.compactMap { k, v in
                    UUID(uuidString: k).map { ($0, v) }
                }
            )
            let round = RoundEntry(roundNumber: shareRound.roundNumber, scores: scores, timestamp: shareRound.timestamp)
            session.rounds.append(round)
            modelContext.insert(round)
        }

        session.winnerSlotID = payload.winnerSlotID
        session.eliminatedSlotIDs = payload.eliminatedSlotIDs
        session.isComplete = payload.isComplete
        session.participantProfileIDs = session.players.compactMap { $0.localProfileIDString }

        if session.isComplete {
            updateStatistics(for: session)
        }

        save()

        pendingSharedGame = nil
        isShowingClaimGame = false
    }

    // MARK: - Persistence

    private func save() {
        do {
            try modelContext.save()
        } catch {
            print("[GameStore] Save failed: \(error)")
        }
    }
}
