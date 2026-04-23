import SwiftUI
import SwiftData

struct ProfilesView: View {
    @Query(sort: \PlayerProfile.name) private var profiles: [PlayerProfile]
    @Environment(\.modelContext) private var modelContext
    @State private var showCreateProfile = false

    var body: some View {
        Group {
            if profiles.isEmpty {
                ContentUnavailableView(
                    "No Profiles Yet",
                    systemImage: "person.badge.plus",
                    description: Text("Create a profile to track your stats across games.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(profiles) { profile in
                            NavigationLink(value: profile) {
                                ProfileRowView(profile: profile)
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
        .navigationTitle("Profiles")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .navigationDestination(for: PlayerProfile.self) { profile in
            ProfileDetailView(profile: profile)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCreateProfile = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .sheet(isPresented: $showCreateProfile) {
            CreateProfileSheet { name, colorHex, emoji in
                let profile = PlayerProfile(name: name, avatarColorHex: colorHex, avatarEmoji: emoji)
                modelContext.insert(profile)
                try? modelContext.save()
            }
        }
    }
}

// MARK: - Profile Row

struct ProfileRowView: View {
    let profile: PlayerProfile

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(profile.avatarColor)
                    .frame(width: 44, height: 44)
                if let emoji = profile.avatarEmoji, !emoji.isEmpty {
                    Text(emoji)
                        .font(.system(size: 22))
                } else {
                    Text(profile.initials)
                        .font(.system(.callout, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(profile.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(profile.playerTag)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(String(format: "%.0f%%", profile.winRate * 100))
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(.primary)
                Text("\(profile.gamesPlayed)G")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .glassCard()
    }
}

// MARK: - Create Profile Sheet

struct CreateProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onCreate: (String, String, String?) -> Void

    @State private var name = ""
    @State private var selectedColorIndex = 0
    @State private var selectedEmoji: String? = nil
    @State private var showEmojiPicker = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    avatarPreview
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
            .navigationTitle("New Profile")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let colorHex = Color.avatarPalette[selectedColorIndex].toHex()
                        onCreate(
                            name.trimmingCharacters(in: .whitespaces),
                            colorHex,
                            selectedEmoji
                        )
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Sub-views

    private var avatarPreview: some View {
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
        TextField("Your name", text: $name)
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
