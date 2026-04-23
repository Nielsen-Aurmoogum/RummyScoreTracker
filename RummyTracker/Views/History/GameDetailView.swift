import SwiftUI

struct GameDetailView: View {
    let game: GameSession
    @State private var showShareSheet = false
    @State private var shareURL: URL?

    private var sortedPlayers: [GamePlayer] { game.sortedPlayers }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard
                roundTableCard
                shareButton
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .navigationTitle(game.date.shortDateFormat)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $showShareSheet) {
            if let url = shareURL {
                ShareView(url: url)
            }
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text(game.date.friendlyFormat)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(game.rounds.count) rounds")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            ForEach(Array(game.scoreboardPlayers.enumerated()), id: \.element.slotID) { rank, player in
                HStack(spacing: 10) {
                    Text("#\(rank + 1)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24)

                    Circle()
                        .fill(player.avatarColor)
                        .frame(width: 30, height: 30)
                        .overlay(
                            Text(player.initials)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        )

                    Text(player.displayName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(player.isEliminated ? Color.gray : Color.primary)

                    if player.slotID == game.winnerSlotID {
                        Image(systemName: "crown.fill")
                            .font(.caption)
                            .foregroundStyle(Color.yellow)
                    }

                    Spacer()

                    Text("\(player.runningTotal)")
                        .font(.system(.body, design: .rounded).weight(.bold))
                        .foregroundStyle(rank == 0 ? Color.green : Color.primary)
                }
            }
        }
        .padding()
        .glassCard()
    }

    // MARK: - Round Table

    private var roundTableCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Round by Round")
                .font(.headline)
                .foregroundStyle(.primary)

            RoundTable(game: game)
        }
        .padding()
        .glassCard()
    }

    // MARK: - Share Button

    private var shareButton: some View {
        Button {
            shareURL = try? ShareEncoder.encode(game)
            showShareSheet = shareURL != nil
        } label: {
            Label("Share this Game", systemImage: "square.and.arrow.up")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(maxWidth: .infinity)
                .padding()
                .glassCard()
        }
        .padding(.bottom, 20)
    }
}

// MARK: - Round Table (shared by GameDetailView and GameOverView)

struct RoundTable: View {
    let game: GameSession

    private var players: [GamePlayer] { game.sortedPlayers }
    private var rounds: [RoundEntry] { game.sortedRounds }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(spacing: 0) {
                headerRow

                Divider()

                ForEach(rounds) { round in
                    RoundTableRow(round: round, players: players, eliminatedIDs: game.eliminatedSlotIDs)
                    Divider()
                }

                Divider()

                totalsRow
            }
        }
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            Text("Rnd")
                .font(.system(.caption, design: .monospaced).weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .leading)

            ForEach(players) { player in
                Text(player.displayName.prefix(6))
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 52, alignment: .trailing)
            }
        }
        .padding(.vertical, 6)
    }

    private var totalsRow: some View {
        HStack(spacing: 0) {
            Text("Tot")
                .font(.system(.caption, design: .monospaced).weight(.bold))
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .leading)

            ForEach(players) { player in
                Text("\(player.runningTotal)")
                    .font(.system(.caption, design: .monospaced).weight(.bold))
                    .foregroundStyle(player.slotID == game.winnerSlotID ? Color.green : Color.primary)
                    .frame(width: 52, alignment: .trailing)
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Round Table Row

private struct RoundTableRow: View {
    let round: RoundEntry
    let players: [GamePlayer]
    let eliminatedIDs: [UUID]

    var body: some View {
        HStack(spacing: 0) {
            Text("\(round.roundNumber)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .leading)

            ForEach(players) { player in
                let score = round.scores[player.slotID]
                let isElimThisRound = eliminatedIDs.contains(player.slotID)
                    && isLastRoundForPlayer(player: player, round: round)

                Group {
                    if let score {
                        Text(score == 0 ? "\u{2605}" : "\(score)")
                            .foregroundStyle(score == 0 ? Color.green : Color.red)
                    } else if isElimThisRound {
                        Text("\u{2715}")
                            .foregroundStyle(Color.gray)
                    } else {
                        Text("\u{2013}")
                            .foregroundStyle(Color.secondary)
                    }
                }
                .font(.system(.caption, design: .monospaced))
                .frame(width: 52, alignment: .trailing)
            }
        }
        .padding(.vertical, 5)
    }

    private func isLastRoundForPlayer(player: GamePlayer, round: RoundEntry) -> Bool {
        round.scores[player.slotID] != nil && player.isEliminated
    }
}
