import SwiftUI

struct GameView: View {
    @Environment(GameStore.self) private var gameStore
    @State private var showRoundEntry = false
    @State private var showGameOver = false
    @State private var selectedPlayer: GamePlayer?

    private var game: GameSession? { gameStore.activeGame }

    var body: some View {
        Group {
            if let game {
                content(game: game)
                    .navigationDestination(isPresented: $showGameOver) {
                        GameOverView(game: game)
                    }
            } else {
                ContentUnavailableView("No Active Game", systemImage: "gamecontroller")
            }
        }
        .onChange(of: gameStore.activeGame?.isComplete) { _, isComplete in
            if isComplete == true {
                #if canImport(UIKit)
                UIImpactFeedbackGenerator.impact(.rigid)
                #endif
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    showGameOver = true
                }
            }
        }
        .onChange(of: gameStore.activeGame?.eliminatedSlotIDStrings.count) { old, new in
            guard let old, let new, new > old else { return }
            #if canImport(UIKit)
            UIImpactFeedbackGenerator.impact(.heavy)
            #endif
        }
    }

    @ViewBuilder
    private func content(game: GameSession) -> some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                roundBar(game: game)

                ScoreboardView(game: game) { player in
                    selectedPlayer = player
                }

                bottomBar(game: game)
            }
        }
        .navigationTitle("Round \(game.currentRoundNumber)")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $showRoundEntry) {
            RoundEntryView(game: game) { scores in
                gameStore.addRound(scores: scores)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedPlayer) { player in
            PlayerScoreHistorySheet(
                player: player,
                game: game,
                isEditable: !game.isComplete,
                onEditScore: { roundID, slotID, newScore in
                    gameStore.editRoundScore(
                        in: game,
                        roundID: roundID,
                        playerSlotID: slotID,
                        newScore: newScore
                    )
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .confirmationDialog(
            "Undo First Round",
            isPresented: Binding(
                get: { gameStore.isShowingUndoRound1Confirm },
                set: { gameStore.isShowingUndoRound1Confirm = $0 }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Game", role: .destructive) {
                gameStore.confirmUndoRound1()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Undoing round 1 will delete this game. This cannot be undone.")
        }
    }

    // MARK: - Round Bar

    private func roundBar(game: GameSession) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("ROUND")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.secondary.opacity(0.7))
                Text("\(game.currentRoundNumber - 1) played")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
            }
            Spacer()
            Text("\(game.activePlayers.count) active")
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.green)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.1), in: Capsule())
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground).opacity(0.8))
    }

    // MARK: - Bottom Bar

    private func bottomBar(game: GameSession) -> some View {
        HStack(spacing: 12) {
            // Undo
            Button {
                gameStore.undoLastRound()
            } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(game.rounds.isEmpty ? Color(.systemGray3) : Color.primary)
            }
            .disabled(game.rounds.isEmpty || game.isComplete)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .glassCard(cornerRadius: 12)

            // Add Round
            Button {
                guard !game.isComplete else { return }
                showRoundEntry = true
            } label: {
                Label("Add Round", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.white)
            }
            .disabled(game.isComplete)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                game.isComplete ? Color(.systemGray4) : Color.accentColor,
                in: RoundedRectangle(cornerRadius: 12)
            )
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground).opacity(0.8))
    }
}


// MARK: - Share Game Button

struct ShareGameButton: View {
    let game: GameSession
    @State private var shareURL: URL?
    @State private var showShareSheet = false

    var body: some View {
        Button {
            shareURL = try? ShareEncoder.encode(game)
            showShareSheet = shareURL != nil
        } label: {
            Label("Share", systemImage: "square.and.arrow.up")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.primary)
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = shareURL {
                ShareView(url: url)
            }
        }
    }
}
