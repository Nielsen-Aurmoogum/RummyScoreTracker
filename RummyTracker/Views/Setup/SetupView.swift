import SwiftUI
import SwiftData

// MARK: - Setup Slot (local value type)

struct SetupSlot: Identifiable {
    var id = UUID()
    var name: String = ""
    var profileID: UUID?
    var playerTag: String = ""
    var avatarColorHex: String
}

// MARK: - SetupView

struct SetupView: View {
    @Environment(GameStore.self) private var gameStore
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \PlayerProfile.name) private var profiles: [PlayerProfile]

    @State private var slots: [SetupSlot] = []

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                VStack(spacing: 0) {
                    playerCountHeader
                    slotList
                    startButton
                        .padding()
                }
            }
            .navigationTitle("New Game")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.primary)
                }
            }
            .onAppear {
                if slots.isEmpty { addSlots(count: 4) }
            }
        }
    }

    // MARK: - Player Count Header

    private var playerCountHeader: some View {
        HStack {
            Text("Players")
                .font(.headline)
                .foregroundStyle(Color.primary)
            Spacer()
            HStack(spacing: 16) {
                Button {
                    guard slots.count > 2 else { return }
                    slots.removeLast()
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(slots.count > 2 ? Color.primary : Color(.systemGray3))
                }
                .disabled(slots.count <= 2)

                Text("\(slots.count)")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.primary)
                    .frame(minWidth: 24)

                Button {
                    guard slots.count < 6 else { return }
                    let newSlot = SetupSlot(avatarColorHex: Color.avatarColor(at: slots.count).toHex())
                    slots.append(newSlot)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(slots.count < 6 ? Color.primary : Color(.systemGray3))
                }
                .disabled(slots.count >= 6)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - Slot List

    private var slotList: some View {
        List {
            ForEach(Array(slots.enumerated()), id: \.element.id) { index, slot in
                SlotRow(
                    slot: $slots[index],
                    index: index,
                    profiles: profiles,
                    excludedProfileIDs: slots.compactMap(\.profileID),
                    onSelectProfile: { profile in
                        slots[index].name = profile.name
                        slots[index].profileID = profile.id
                        slots[index].playerTag = profile.playerTag
                        slots[index].avatarColorHex = profile.avatarColorHex
                    },
                    onClearProfile: {
                        slots[index].profileID = nil
                        slots[index].playerTag = ""
                    }
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            .onMove { source, destination in
                slots.move(fromOffsets: source, toOffset: destination)
                for i in slots.indices {
                    if slots[i].profileID == nil {
                        slots[i].avatarColorHex = Color.avatarColor(at: i).toHex()
                    }
                }
            }
            .onDelete { offsets in
                guard slots.count - offsets.count >= 2 else { return }
                slots.remove(atOffsets: offsets)
            }
        }
        .listStyle(.plain)
        .environment(\.editMode, .constant(.active))
        .scrollContentBackground(.hidden)
    }

    // MARK: - Start Button

    private var isValid: Bool {
        slots.allSatisfy { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    private var startButton: some View {
        Button {
            let playerSlots = slots.map { slot in
                (
                    name: slot.name.trimmingCharacters(in: .whitespaces),
                    profileID: slot.profileID,
                    avatarColorHex: slot.avatarColorHex,
                    playerTag: slot.playerTag.isEmpty
                        ? PlayerProfile.generateTag(for: slot.name)
                        : slot.playerTag
                )
            }
            gameStore.startGame(playerSlots: playerSlots)
            dismiss()
        } label: {
            Text("Start Game")
                .font(.headline)
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(isValid ? Color.accentColor : Color(.systemGray3), in: RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!isValid)
    }

    // MARK: - Helpers

    private func addSlots(count: Int) {
        for i in 0..<count {
            slots.append(SetupSlot(avatarColorHex: Color.avatarColor(at: i).toHex()))
        }
    }
}

// MARK: - SlotRow

private struct SlotRow: View {
    @Binding var slot: SetupSlot
    let index: Int
    let profiles: [PlayerProfile]
    let excludedProfileIDs: [UUID]
    let onSelectProfile: (PlayerProfile) -> Void
    let onClearProfile: () -> Void

    @State private var isFocused: Bool = false
    @FocusState private var textFieldFocused: Bool

    /// Profiles that match the current text, excluding already-assigned ones
    private var suggestions: [PlayerProfile] {
        let text = slot.name.trimmingCharacters(in: .whitespaces).lowercased()
        guard !text.isEmpty, slot.profileID == nil else { return [] }
        return profiles
            .filter { !excludedProfileIDs.contains($0.id) }
            .filter { $0.name.lowercased().contains(text) }
            .prefix(4)
            .map { $0 }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main row
            HStack(spacing: 12) {
                // Avatar circle
                ZStack {
                    Circle()
                        .fill(Color(hex: slot.avatarColorHex))
                        .frame(width: 40, height: 40)
                    if let emoji = slot.profileID != nil ? findProfileEmoji() : nil {
                        Text(emoji)
                            .font(.system(size: 20))
                    } else {
                        Text(initials)
                            .font(.system(.caption, design: .rounded).weight(.bold))
                            .foregroundStyle(Color.white)
                    }
                }

                // Name field
                TextField("Player \(index + 1)", text: $slot.name)
                    .font(.body)
                    .foregroundStyle(Color.primary)
                    .tint(Color.accentColor)
                    .focused($textFieldFocused)
                    .onChange(of: textFieldFocused) { _, focused in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isFocused = focused
                        }
                    }
                    .onChange(of: slot.name) { _, _ in
                        // Clear profile link when user edits the name manually
                        if slot.profileID != nil && textFieldFocused {
                            slot.profileID = nil
                            slot.playerTag = ""
                        }
                    }

                Spacer()

                // Profile link indicator
                if slot.profileID != nil {
                    Button(action: onClearProfile) {
                        Image(systemName: "person.fill.checkmark")
                            .foregroundStyle(Color.green)
                    }
                }
            }
            .padding(12)
            .glassCard()
            .padding(.horizontal)
            .padding(.vertical, 4)

            // Dropdown suggestions
            if isFocused && !suggestions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(suggestions) { profile in
                        Button {
                            onSelectProfile(profile)
                            textFieldFocused = false
                        } label: {
                            HStack(spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(profile.avatarColor)
                                        .frame(width: 30, height: 30)
                                    if let emoji = profile.avatarEmoji, !emoji.isEmpty {
                                        Text(emoji)
                                            .font(.system(size: 14))
                                    } else {
                                        Text(profile.initials)
                                            .font(.system(.caption2, design: .rounded).weight(.bold))
                                            .foregroundStyle(.white)
                                    }
                                }

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(profile.name)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.primary)
                                    Text(profile.playerTag)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if profile.gamesPlayed > 0 {
                                    Text("\(profile.gamesWon)W/\(profile.gamesPlayed)G")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)

                        if profile.id != suggestions.last?.id {
                            Divider().padding(.leading, 54)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
                )
                .padding(.horizontal, 28)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var initials: String {
        let trimmed = slot.name.trimmingCharacters(in: .whitespaces)
        let words = trimmed.split(separator: " ")
        if words.count >= 2 {
            return String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        }
        return String(trimmed.prefix(2)).uppercased()
    }

    private func findProfileEmoji() -> String? {
        guard let profileID = slot.profileID else { return nil }
        return profiles.first { $0.id == profileID }?.avatarEmoji
    }
}
