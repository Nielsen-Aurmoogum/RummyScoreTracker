import SwiftUI
import SwiftData

struct ProfileDetailView: View {
    @Bindable var profile: PlayerProfile
    @Environment(\.modelContext) private var modelContext
    @State private var showEditSheet = false
    @State private var editedName = ""
    @State private var selectedColorIndex = 0
    @State private var selectedEmoji: String? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                profileHeader
                statsGrid

                if !profile.matchupRecords.isEmpty {
                    matchupSection
                }
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .navigationTitle(profile.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    editedName = profile.name
                    selectedEmoji = profile.avatarEmoji
                    selectedColorIndex = Color.avatarPalette.firstIndex(where: {
                        $0.toHex() == profile.avatarColorHex
                    }) ?? 0
                    showEditSheet = true
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            EditProfileSheet(
                name: $editedName,
                selectedColorIndex: $selectedColorIndex,
                selectedEmoji: $selectedEmoji
            ) {
                profile.name = editedName.trimmingCharacters(in: .whitespaces)
                profile.avatarColorHex = Color.avatarPalette[selectedColorIndex].toHex()
                profile.avatarEmoji = selectedEmoji
                try? modelContext.save()
            }
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(profile.avatarColor)
                    .frame(width: 80, height: 80)
                    .shadow(color: profile.avatarColor.opacity(0.3), radius: 10, y: 4)
                if let emoji = profile.avatarEmoji, !emoji.isEmpty {
                    Text(emoji)
                        .font(.system(size: 36))
                } else {
                    Text(profile.initials)
                        .font(.system(.title, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                }
            }

            Text(profile.name)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(.primary)

            Text(profile.playerTag)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .glassCard()
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(title: "Games Played", value: "\(profile.gamesPlayed)")
            StatCard(title: "Games Won", value: "\(profile.gamesWon)")
            StatCard(title: "Win Rate", value: String(format: "%.0f%%", profile.winRate * 100))
            StatCard(title: "Avg Pts/Round", value: String(format: "%.1f", profile.avgPointsPerRound))
            StatCard(title: "Win Streak", value: "\(profile.currentWinStreak)")
            StatCard(title: "Best Streak", value: "\(profile.longestWinStreak)")
        }
    }

    // MARK: - Matchup Section

    private var matchupSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Head to Head")
                .font(.headline)
                .foregroundStyle(.primary)

            ForEach(profile.matchupRecords.sorted { $0.gamesPlayedTogether > $1.gamesPlayedTogether }, id: \.opponentID) { record in
                MatchupRow(record: record)
            }
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(.primary)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .glassCard()
    }
}

// MARK: - Matchup Row

private struct MatchupRow: View {
    let record: MatchupRecord

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(record.opponentName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Text(record.opponentTag)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(record.winsAgainst)W / \(record.gamesPlayedTogether - record.winsAgainst)L")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(.primary)
                let diff = record.avgPointsDifferential
                Text(String(format: "%+.1f avg pts", diff))
                    .font(.caption2)
                    .foregroundStyle(diff < 0 ? Color.green : Color.red)
            }
        }
        .padding(12)
        .glassCard()
    }
}

// MARK: - Edit Profile Sheet

private struct EditProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var name: String
    @Binding var selectedColorIndex: Int
    @Binding var selectedEmoji: String?
    let onSave: () -> Void

    @State private var showEmojiPicker = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    avatarPreviewButton
                    nameField
                    colorPickerSection
                    if showEmojiPicker {
                        emojiPickerSection
                    }
                    Spacer(minLength: 40)
                }
                .padding(.top, 32)
            }
            .background(Color(.systemBackground))
            .navigationTitle("Edit Profile")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Sub-views

    private var avatarPreviewButton: some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                showEmojiPicker.toggle()
            }
        } label: {
            let currentColor = Color.avatarPalette[selectedColorIndex]
            ZStack {
                Circle()
                    .fill(currentColor)
                    .frame(width: 90, height: 90)
                    .shadow(color: currentColor.opacity(0.4), radius: 12, y: 4)

                if let emoji = selectedEmoji {
                    Text(emoji)
                        .font(.system(size: 40))
                } else {
                    Text(initials)
                        .font(.system(.title, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                }

                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.white, Color.accentColor)
                    .offset(x: 32, y: 32)
            }
        }
        .buttonStyle(.plain)
    }

    private var nameField: some View {
        TextField("Name", text: $name)
            .font(.title3)
            .foregroundStyle(.primary)
            .multilineTextAlignment(.center)
            .padding()
            .glassCard()
            .padding(.horizontal)
    }

    private var colorPickerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("COLOR")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 8)
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Array(Color.avatarPalette.enumerated()), id: \.offset) { index, color in
                    ColorCircle(
                        color: color,
                        isSelected: selectedColorIndex == index
                    ) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedColorIndex = index
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private var emojiPickerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("AVATAR")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if selectedEmoji != nil {
                    Button("Remove") {
                        selectedEmoji = nil
                    }
                    .font(.caption)
                    .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 4)

            let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 6)
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(PlayerProfile.emojiPalette, id: \.self) { emoji in
                    EmojiCell(
                        emoji: emoji,
                        isSelected: selectedEmoji == emoji
                    ) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedEmoji = selectedEmoji == emoji ? nil : emoji
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var initials: String {
        let words = name.trimmingCharacters(in: .whitespaces).split(separator: " ")
        if words.count >= 2 { return String(words[0].prefix(1) + words[1].prefix(1)).uppercased() }
        return String(name.prefix(2)).uppercased()
    }
}

