import SwiftUI

struct PlayerScoreHistorySheet: View {
    let player: GamePlayer
    let game: GameSession
    let isEditable: Bool
    var onEditScore: ((UUID, UUID, Int) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var editingRoundID: UUID?
    @State private var editText: String = ""

    private var rounds: [RoundEntry] { game.sortedRounds }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    playerHeader
                }
                .listRowBackground(Color(.systemBackground))
                .listRowSeparator(.hidden)

                Section {
                    ForEach(rounds) { round in
                        roundRow(round: round)
                    }
                } header: {
                    HStack {
                        Text("Round")
                        Spacer()
                        Text("Score")
                            .frame(width: 60, alignment: .trailing)
                        Text("Total")
                            .frame(width: 60, alignment: .trailing)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(.systemBackground))
            .navigationTitle(player.displayName)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationBackground(Color(.systemBackground))
    }

    // MARK: - Player Header

    private var playerHeader: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(player.avatarColor)
                    .frame(width: 56, height: 56)
                Text(player.initials)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(player.displayName)
                    .font(.title3.weight(.bold))
                HStack(spacing: 12) {
                    Label("\(player.runningTotal) pts", systemImage: "number")
                    Label("\(rounds.count) rounds", systemImage: "arrow.triangle.2.circlepath")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if player.isEliminated {
                Text("OUT")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red, in: Capsule())
            } else if game.winnerSlotID == player.slotID {
                Text("WON")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green, in: Capsule())
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Round Row

    private func roundRow(round: RoundEntry) -> some View {
        let score = round.scores[player.slotID]
        let runningTotal = computeRunningTotal(through: round)
        let isEditing = editingRoundID == round.id

        return HStack {
            Text("R\(round.roundNumber)")
                .font(.system(.body, design: .rounded).weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .leading)

            Spacer()

            if isEditing {
                TextField("0", text: $editText)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                    .font(.system(.body, design: .rounded).weight(.bold))
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 6))

                Button {
                    if let newScore = Int(editText) {
                        onEditScore?(round.id, player.slotID, newScore)
                    }
                    editingRoundID = nil
                } label: {
                    Text("Save")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.accentColor, in: Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    editingRoundID = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.body)
                }
                .buttonStyle(.plain)
            } else {
                Group {
                    if let score {
                        Text(score == 0 ? "★" : "+\(score)")
                            .foregroundStyle(score == 0 ? Color.green : Color.primary)
                    } else {
                        Text("–")
                            .foregroundStyle(.tertiary)
                    }
                }
                .font(.system(.body, design: .rounded).weight(.bold))
                .frame(width: 60, alignment: .trailing)

                Text("\(runningTotal)")
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(runningTotal >= 101 ? Color.red : Color.primary)
                    .frame(width: 60, alignment: .trailing)

                if isEditable && score != nil {
                    Button {
                        editText = "\(score ?? 0)"
                        editingRoundID = round.id
                    } label: {
                        Image(systemName: "pencil.circle")
                            .foregroundStyle(Color.accentColor.opacity(0.6))
                            .font(.callout)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Helpers

    private func computeRunningTotal(through targetRound: RoundEntry) -> Int {
        var total = 0
        for round in rounds {
            if let delta = round.scores[player.slotID] {
                total += delta
            }
            if round.id == targetRound.id { break }
        }
        return total
    }
}
