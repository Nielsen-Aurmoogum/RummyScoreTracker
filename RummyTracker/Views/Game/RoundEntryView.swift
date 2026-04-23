import SwiftUI

struct RoundEntryView: View {
    let game: GameSession
    let onConfirm: ([UUID: Int]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var entries: [UUID: String] = [:]
    @State private var showValidationAlert = false
    @State private var validationMessage = ""

    private var activePlayers: [GamePlayer] {
        game.activePlayers
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                VStack(spacing: 0) {
                    roundHeader
                    playerEntryList
                    statusBar
                    confirmButton
                        .padding(.horizontal)
                        .padding(.bottom)
                }
            }
            .navigationTitle("Round \(game.currentRoundNumber)")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.secondary)
                }
            }
            .alert("Invalid Entry", isPresented: $showValidationAlert) {
                Button("OK") {}
            } message: {
                Text(validationMessage)
            }
            .onAppear {
                for player in activePlayers {
                    entries[player.slotID] = ""
                }
            }
        }
    }

    // MARK: - Round Header

    private var roundHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Enter unmelded points for each player")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
                Text("Leave the round winner blank")
                    .font(.caption)
                    .foregroundStyle(Color.green)
            }
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground).opacity(0.6))
    }

    // MARK: - Player Entry List

    private var playerEntryList: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(activePlayers) { player in
                    let isBlank = (entries[player.slotID] ?? "").isEmpty
                    let isOnlyBlank = isBlank && blankCount == 1

                    PlayerEntryRow(
                        player: player,
                        text: Binding(
                            get: { entries[player.slotID] ?? "" },
                            set: { entries[player.slotID] = $0 }
                        ),
                        isRoundWinner: isOnlyBlank
                    )
                }
            }
            .padding()
        }
    }

    // MARK: - Validation

    /// Number of blank/empty fields
    private var blankCount: Int {
        activePlayers.filter { player in
            let text = (entries[player.slotID] ?? "").trimmingCharacters(in: .whitespaces)
            return text.isEmpty
        }.count
    }

    /// Number of fields with valid numeric scores (including blank = will be 0)
    private var filledCount: Int {
        activePlayers.filter { player in
            let text = (entries[player.slotID] ?? "").trimmingCharacters(in: .whitespaces)
            return !text.isEmpty && Int(text) != nil
        }.count
    }

    /// Valid when: all fields filled, OR exactly one blank (auto-zero for winner)
    private var isValid: Bool {
        let blanks = blankCount
        let filled = filledCount
        let total = activePlayers.count

        // All filled with valid numbers
        if blanks == 0 && filled == total { return true }
        // Exactly one blank, rest are valid numbers
        if blanks == 1 && filled == total - 1 { return true }

        return false
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        Group {
            if blankCount == 1 {
                let winnerName = activePlayers.first { player in
                    (entries[player.slotID] ?? "").trimmingCharacters(in: .whitespaces).isEmpty
                }?.displayName ?? "?"

                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.green)
                    Text("\(winnerName) wins this round (0 pts)")
                        .font(.caption)
                        .foregroundStyle(Color.green)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.green.opacity(0.08))
            } else if blankCount > 1 {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.caption2)
                        .foregroundStyle(Color.secondary)
                    Text("\(blankCount) fields remaining — leave 1 blank for winner")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground).opacity(0.4))
            } else if blankCount == 0 && isValid {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.green)
                    Text("All scores entered")
                        .font(.caption)
                        .foregroundStyle(Color.green)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.green.opacity(0.08))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: blankCount)
    }

    // MARK: - Confirm Button

    private var confirmButton: some View {
        Button {
            // Validate: check for non-numeric entries
            let hasInvalid = activePlayers.contains { player in
                let text = (entries[player.slotID] ?? "").trimmingCharacters(in: .whitespaces)
                return !text.isEmpty && Int(text) == nil
            }
            if hasInvalid {
                validationMessage = "Some fields contain invalid values. Please enter numbers only."
                showValidationAlert = true
                return
            }
            guard isValid else {
                validationMessage = "Enter scores for all players. You can leave exactly one field blank for the round winner."
                showValidationAlert = true
                return
            }

            // Build scores — blank fields become 0
            let scores = Dictionary(
                uniqueKeysWithValues: activePlayers.map { player -> (UUID, Int) in
                    let text = (entries[player.slotID] ?? "").trimmingCharacters(in: .whitespaces)
                    let value = Int(text) ?? 0
                    return (player.slotID, max(0, value))
                }
            )

            #if canImport(UIKit)
            UIImpactFeedbackGenerator.impact(.medium)
            #endif
            onConfirm(scores)
            dismiss()
        } label: {
            Text("Confirm Round")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    isValid ? Color.accentColor : Color(.systemGray4),
                    in: RoundedRectangle(cornerRadius: 14)
                )
        }
        .disabled(!isValid)
        .animation(.easeInOut(duration: 0.2), value: isValid)
    }
}

// MARK: - PlayerEntryRow

private struct PlayerEntryRow: View {
    let player: GamePlayer
    @Binding var text: String
    var isRoundWinner: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(player.avatarColor)
                    .frame(width: 40, height: 40)
                Text(player.initials)
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(player.displayName)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.primary)

                if isRoundWinner {
                    Text("Round winner · 0 pts")
                        .font(.caption2)
                        .foregroundStyle(Color.green)
                }
            }

            Spacer()

            TextField("pts", text: $text)
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(Color.primary)
                .multilineTextAlignment(.trailing)
                .frame(width: 64)
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .background(
                    isRoundWinner ? Color.green.opacity(0.08) : Color(.tertiarySystemFill),
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isRoundWinner ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1.5)
                )
        }
        .padding(12)
        .glassCard()
        .animation(.easeInOut(duration: 0.15), value: isRoundWinner)
    }
}
