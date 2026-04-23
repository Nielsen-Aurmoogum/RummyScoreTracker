import SwiftUI

struct GameOverView: View {
    let game: GameSession
    @Environment(GameStore.self) private var gameStore
    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false
    @State private var shareURL: URL?
    @State private var showRoundTable = false

    private var winner: GamePlayer? { game.winnerPlayer }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            CelebrationView(seed: UInt64(game.id.hashValue.magnitude))
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    winnerSection

                    leaderboardSection

                    roundTableSection

                    actionButtons
                }
                .padding()
                .padding(.top, 20)
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationTitle("Game Over")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $showShareSheet) {
            if let url = shareURL {
                ShareView(url: url)
            }
        }
        .onAppear {
            #if canImport(UIKit)
            UIImpactFeedbackGenerator.impact(.rigid)
            #endif
        }
    }

    // MARK: - Winner Section

    private var winnerSection: some View {
        VStack(spacing: 14) {
            if let winner {
                ZStack {
                    Circle()
                        .fill(winner.avatarColor.opacity(0.15))
                        .frame(width: 100, height: 100)
                    Circle()
                        .fill(winner.avatarColor)
                        .frame(width: 84, height: 84)
                    Text(winner.initials)
                        .font(.system(.title, design: .rounded).weight(.bold))
                        .foregroundStyle(Color.white)
                }

                Text(winner.displayName)
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(Color.primary)

                Text("wins")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(Color.secondary)

                Text("\(winner.runningTotal) pts final score")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 24)
        .glassCard()
    }

    // MARK: - Leaderboard

    private var leaderboardSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Final Standings")
                .font(.headline)
                .foregroundStyle(Color.secondary)

            ForEach(Array(game.scoreboardPlayers.enumerated()), id: \.element.slotID) { rank, player in
                HStack(spacing: 12) {
                    Text("#\(rank + 1)")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(Color.secondary.opacity(0.6))
                        .frame(width: 28)

                    ZStack {
                        Circle()
                            .fill(player.avatarColor)
                            .frame(width: 32, height: 32)
                        Text(player.initials)
                            .font(.system(.caption2, design: .rounded).weight(.bold))
                            .foregroundStyle(Color.white)
                    }

                    Text(player.displayName)
                        .font(.body.weight(.medium))
                        .foregroundStyle(player.isEliminated ? Color.gray : Color.primary)

                    if player.slotID == game.winnerSlotID {
                        Image(systemName: "crown.fill")
                            .font(.caption)
                            .foregroundStyle(Color.yellow)
                    }

                    Spacer()

                    Text("\(player.runningTotal) pts")
                        .font(.system(.body, design: .rounded).weight(.bold))
                        .foregroundStyle(rank == 0 ? Color.green : Color.secondary)
                }
                .padding(12)
                .glassCard()
            }
        }
    }

    // MARK: - Round Table

    private var roundTableSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation { showRoundTable.toggle() }
            } label: {
                HStack {
                    Text("Round by Round")
                        .font(.headline)
                        .foregroundStyle(Color.secondary)
                    Spacer()
                    Image(systemName: showRoundTable ? "chevron.up" : "chevron.down")
                        .foregroundStyle(Color.secondary.opacity(0.5))
                }
            }
            .buttonStyle(.plain)

            if showRoundTable {
                RoundTable(game: game)
                    .padding(.top, 4)
            }
        }
        .padding()
        .glassCard()
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                shareURL = try? ShareEncoder.encode(game)
                showShareSheet = shareURL != nil
            } label: {
                Label("Share Game", systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .glassCard()
            }

            Button {
                gameStore.clearCompletedActiveGame()
                dismiss()
            } label: {
                Text("Done")
                    .font(.headline)
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(.bottom, 40)
    }
}

// MARK: - CelebrationView

struct CelebrationView: View {
    let seed: UInt64
    @State private var startDate = Date()

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let elapsed = timeline.date.timeIntervalSince(startDate)
                guard elapsed < 5 else { return }

                var rng = SeededRNG(seed: seed)

                let amberTones: [Color] = [
                    Color(red: 0.93, green: 0.79, blue: 0.33),
                    Color(red: 0.87, green: 0.68, blue: 0.22),
                    Color(red: 0.95, green: 0.85, blue: 0.50),
                    Color(red: 0.80, green: 0.60, blue: 0.15),
                    Color(red: 0.98, green: 0.90, blue: 0.60),
                ]

                for _ in 0..<30 {
                    let x = Double.random(in: 0...size.width, using: &rng)
                    let baseY = size.height + Double.random(in: 20...200, using: &rng)
                    let speed = Double.random(in: 30...80, using: &rng)
                    let y = baseY - elapsed * speed

                    guard y > -20 && y < size.height + 50 else { continue }

                    let color = amberTones[Int.random(in: 0..<amberTones.count, using: &rng)]
                    let radius = Double.random(in: 1.5...4.0, using: &rng)

                    let normalizedHeight = 1.0 - ((size.height - y) / size.height)
                    let fadeIn = min(1.0, (size.height - y) / 100.0)
                    let fadeOut = min(1.0, max(0, y + 20) / 100.0)
                    let timeFade = min(1.0, max(0, 1.0 - (elapsed - 3.0) / 2.0))
                    let drift = sin(elapsed * 0.5 + Double.random(in: 0...6.28, using: &rng)) * 8

                    context.opacity = Double(fadeIn * fadeOut * timeFade) * (0.15 + normalizedHeight * 0.35)
                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: x + drift - radius,
                            y: y - radius,
                            width: radius * 2,
                            height: radius * 2
                        )),
                        with: .color(color)
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}
