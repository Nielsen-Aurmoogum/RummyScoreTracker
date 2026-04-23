import SwiftUI

// MARK: - ScoreboardView

struct ScoreboardView: View {
    let game: GameSession
    var onPlayerTap: ((GamePlayer) -> Void)?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(game.scoreboardPlayers) { player in
                    PlayerRowView(
                        player: player,
                        lastRoundDelta: lastRoundDelta(for: player),
                        isWinner: game.winnerSlotID == player.slotID,
                        onPlayerTap: onPlayerTap
                    )
                    .padding(.horizontal)
                }
            }
            .padding(.vertical, 8)
        }
    }

    private func lastRoundDelta(for player: GamePlayer) -> Int? {
        game.sortedRounds.last?.scores[player.slotID]
    }
}

// MARK: - PlayerRowView

struct PlayerRowView: View {
    let player: GamePlayer
    let lastRoundDelta: Int?
    var isWinner: Bool = false
    var onPlayerTap: ((GamePlayer) -> Void)?

    var body: some View {
        Button {
            onPlayerTap?(player)
        } label: {
            HStack(spacing: 12) {
                avatarView

                VStack(alignment: .leading, spacing: 2) {
                    Text(player.displayName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(player.isEliminated ? Color.gray : Color.primary)

                    if player.isEliminated {
                        Text("Eliminated")
                            .font(.caption2)
                            .foregroundStyle(Color.red.opacity(0.8))
                    }
                }

                Spacer()

                if let delta = lastRoundDelta, !player.isEliminated || delta > 0 {
                    DeltaBadge(delta: delta)
                }

                Text("\(player.runningTotal)")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(scoreColor)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: player.runningTotal)
                    .frame(minWidth: 48, alignment: .trailing)
            }
            .padding(14)
            .glassCard()
            .opacity(player.isEliminated ? 0.5 : 1)
            .overlay(alignment: .topTrailing) {
                if player.isEliminated {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.red)
                        .font(.caption)
                        .offset(x: 6, y: -6)
                }
                if isWinner {
                    Image(systemName: "crown.fill")
                        .foregroundStyle(Color.yellow)
                        .font(.caption)
                        .offset(x: 6, y: -6)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var avatarView: some View {
        ZStack {
            Circle()
                .fill(player.avatarColor)
                .frame(width: 44, height: 44)
            Text(player.initials)
                .font(.system(.callout, design: .rounded).weight(.bold))
                .foregroundStyle(Color.white)
        }
        .opacity(player.isEliminated ? 0.5 : 1)
    }

    private var scoreColor: Color {
        if isWinner { return Color.green }
        if player.isEliminated || player.runningTotal >= 101 { return Color.red }
        if player.runningTotal >= 90 { return Color.orange }
        return Color.primary
    }
}

// MARK: - DeltaBadge

struct DeltaBadge: View {
    let delta: Int

    var body: some View {
        Text(delta == 0 ? "\u{2605}" : "+\(delta)")
            .font(.system(.caption2, design: .rounded).weight(.bold))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(delta == 0 ? Color.green : Color.red, in: Capsule())
    }
}
