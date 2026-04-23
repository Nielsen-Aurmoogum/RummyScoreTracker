import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(GameStore.self) private var gameStore
    @Query(
        filter: #Predicate<GameSession> { $0.isComplete },
        sort: \GameSession.date, order: .reverse
    ) private var recentGames: [GameSession]

    @State private var showSetup = false
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                CardSuitsBackground()

                ScrollView {
                    VStack(spacing: 24) {
                        // Resume banner (in-progress game)
                        if let active = gameStore.activeGame, !active.isComplete {
                            ResumeBanner(game: active) {
                                path.append(NavigationDestination.activeGame)
                            }
                            .padding(.horizontal)
                        }

                        // Deep-link claim banner
                        if gameStore.pendingSharedGame != nil {
                            ClaimBanner {
                                gameStore.isShowingClaimGame = true
                            }
                            .padding(.horizontal)
                        }

                        // Deep-link error banner
                        if let error = gameStore.deepLinkError {
                            ErrorBanner(message: error) {
                                gameStore.deepLinkError = nil
                            }
                            .padding(.horizontal)
                        }

                        // Title
                        VStack(spacing: 4) {
                            Text("Rummy")
                                .font(.system(size: 52, weight: .black, design: .rounded))
                                .foregroundStyle(Color.primary)
                            Text("Score Tracker")
                                .font(.title3.weight(.medium))
                                .foregroundStyle(Color.secondary)
                        }
                        .padding(.top, gameStore.activeGame == nil ? 40 : 0)

                        // New Game button
                        Button {
                            showSetup = true
                        } label: {
                            Text("New Game")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(Color.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16))
                        }
                        .padding(.horizontal)

                        // Recent Games
                        if !recentGames.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Recent Games")
                                    .font(.headline)
                                    .foregroundStyle(Color.secondary)
                                    .padding(.horizontal)

                                ForEach(recentGames.prefix(3)) { game in
                                    RecentGameRow(game: game) {
                                        path.append(NavigationDestination.game(game.id))
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }

                        // Nav links
                        HStack(spacing: 12) {
                            NavPill(label: "History", icon: "clock.fill") {
                                path.append(NavigationDestination.history)
                            }
                            NavPill(label: "Profiles", icon: "person.2.fill") {
                                path.append(NavigationDestination.profiles)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 40)
                    }
                    .padding(.top, 20)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showSetup, onDismiss: {
                // If a game was started, navigate to it
                if gameStore.activeGame != nil {
                    path.append(NavigationDestination.activeGame)
                }
            }) {
                SetupView()
            }
            .sheet(isPresented: Binding(
                get: { gameStore.isShowingClaimGame },
                set: { gameStore.isShowingClaimGame = $0 }
            )) {
                ClaimGameView()
            }
            .navigationDestination(for: NavigationDestination.self) { dest in
                switch dest {
                case .activeGame:
                    GameView()
                case .game(let id):
                    if let game = recentGames.first(where: { $0.id == id }) {
                        GameDetailView(game: game)
                    }
                case .history:
                    HistoryView()
                case .profiles:
                    ProfilesView()
                }
            }
        }
    }
}

// MARK: - Navigation Destination

enum NavigationDestination: Hashable {
    case activeGame
    case game(UUID)
    case history
    case profiles
}

// MARK: - Card Suits Background

struct CardSuitsBackground: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1/4)) { timeline in
            Canvas { context, size in
                let elapsed = timeline.date.timeIntervalSinceReferenceDate
                let suits = ["♠", "♥", "♦", "♣"]
                var rng = SeededRNG(seed: 42)
                for i in 0..<12 {
                    let x = Double.random(in: 0...size.width, using: &rng)
                    let speed = Double.random(in: 12...30, using: &rng)
                    let startY = Double.random(in: -200...0, using: &rng)
                    let y = (startY + elapsed * speed).truncatingRemainder(dividingBy: size.height + 100)
                    let suit = suits[i % suits.count]
                    let fontSize = Double.random(in: 16...28, using: &rng)
                    context.opacity = 0.035
                    context.draw(
                        Text(suit)
                            .font(.system(size: fontSize))
                            .foregroundColor(Color(.systemGray3)),
                        at: CGPoint(x: x, y: y)
                    )
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - Resume Banner

private struct ResumeBanner: View {
    let game: GameSession
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Continue Game")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.primary)
                    Text("Round \(game.currentRoundNumber - 1) played \u{00B7} \(game.players.count) players")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(Color.secondary.opacity(0.5))
            }
            .padding()
            .glassCard()
        }
    }
}

// MARK: - Claim Banner

private struct ClaimBanner: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.cardRed)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Shared Game Available")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.primary)
                    Text("Tap to import and claim your results")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(Color.secondary.opacity(0.5))
            }
            .padding()
            .glassCard()
        }
    }
}

// MARK: - Error Banner

private struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.orange)
            Text(message)
                .font(.caption)
                .foregroundStyle(Color.primary)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Color.secondary)
            }
        }
        .padding()
        .glassCard()
    }
}

// MARK: - Recent Game Row

private struct RecentGameRow: View {
    let game: GameSession
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(playerNames)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)
                    Text(game.date.friendlyFormat)
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    if let winner = game.winnerPlayer {
                        Text(winner.displayName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.green)
                    }
                    Text("\(game.rounds.count) rounds")
                        .font(.caption2)
                        .foregroundStyle(Color.secondary.opacity(0.7))
                }
            }
            .padding(14)
            .glassCard()
        }
    }

    private var playerNames: String {
        game.sortedPlayers.map(\.displayName).joined(separator: " \u{00B7} ")
    }
}

// MARK: - Nav Pill

private struct NavPill: View {
    let label: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(label)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(Color.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color(.separator), lineWidth: 1)
            )
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
            )
        }
    }
}
