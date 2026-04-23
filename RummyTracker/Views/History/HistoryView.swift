import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(
        filter: #Predicate<GameSession> { $0.isComplete },
        sort: \GameSession.date, order: .reverse
    ) private var games: [GameSession]

    var body: some View {
        Group {
            if games.isEmpty {
                ContentUnavailableView(
                    "No Games Yet",
                    systemImage: "clock",
                    description: Text("Complete a game to see it here.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(games) { game in
                            NavigationLink(value: game) {
                                HistoryRowView(game: game)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
            }
        }
        .background(Color(.systemBackground))
        .navigationTitle("History")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .navigationDestination(for: GameSession.self) { game in
            GameDetailView(game: game)
        }
    }
}

// MARK: - History Row

struct HistoryRowView: View {
    let game: GameSession

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(game.date.friendlyFormat)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(game.rounds.count) rounds")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                ForEach(game.sortedPlayers.prefix(4)) { player in
                    Circle()
                        .fill(player.avatarColor)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Text(player.initials)
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        )
                }

                if game.players.count > 4 {
                    Text("+\(game.players.count - 4)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let winner = game.winnerPlayer {
                    HStack(spacing: 4) {
                        Image(systemName: "crown.fill")
                            .font(.caption2)
                            .foregroundStyle(Color.yellow)
                        Text(winner.displayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
        .padding(14)
        .glassCard()
    }
}
