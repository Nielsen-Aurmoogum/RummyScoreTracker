import SwiftUI
import SwiftData

// MARK: - Claim Step

private enum ClaimStep {
    case identifySelf
    case mapOthers
    case confirm
}

// MARK: - ClaimGameView

struct ClaimGameView: View {
    @Environment(GameStore.self) private var gameStore
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \PlayerProfile.name) private var profiles: [PlayerProfile]

    @State private var step: ClaimStep = .identifySelf
    @State private var selfSlotID: UUID? = nil
    @State private var mappings: [UUID: ProfileMapping] = [:]

    private var payload: SharePayload? { gameStore.pendingSharedGame }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if payload != nil {
                    stepIndicator
                }

                if let payload {
                    Group {
                        switch step {
                        case .identifySelf:
                            identifyStep(payload: payload)
                        case .mapOthers:
                            mapOthersStep(payload: payload)
                        case .confirm:
                            confirmStep(payload: payload)
                        }
                    }
                    .transition(.slide)
                    .animation(.easeInOut, value: step)
                } else {
                    ContentUnavailableView("No Pending Game", systemImage: "link.badge.plus")
                }
            }
            .background(Color(.systemBackground))
            .navigationTitle("Import Game")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        gameStore.pendingSharedGame = nil
                        gameStore.isShowingClaimGame = false
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        let steps = ["You", "Others", "Confirm"]
        let currentIndex = step == .identifySelf ? 0 : step == .mapOthers ? 1 : 2

        return HStack(spacing: 8) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, label in
                HStack(spacing: 4) {
                    Circle()
                        .fill(index <= currentIndex ? Color.accentColor : Color(.systemGray4))
                        .frame(width: 8, height: 8)
                    Text(label)
                        .font(.caption2.weight(index == currentIndex ? .bold : .regular))
                        .foregroundStyle(index <= currentIndex ? Color.accentColor : Color.secondary)
                }
                if index < steps.count - 1 {
                    Rectangle()
                        .fill(index < currentIndex ? Color.accentColor : Color(.systemGray4))
                        .frame(height: 1.5)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground).opacity(0.6))
        .animation(.easeInOut(duration: 0.2), value: step)
    }

    // MARK: - Step 1: Identify Self

    private func identifyStep(payload: SharePayload) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Which player are you?")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                    .padding(.top, 20)

                Text("Tap your name in this game")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ForEach(payload.players, id: \.slotID) { player in
                    Button {
                        selfSlotID = player.slotID
                        mappings[player.slotID] = resolveMapping(for: player, isSelf: true)
                        autoMatchRemaining(payload: payload, excludingSelf: player.slotID)
                        step = .mapOthers
                    } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color.avatarColor(at: payload.players.firstIndex(where: { $0.slotID == player.slotID }) ?? 0))
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Text(String(player.displayName.prefix(2)).uppercased())
                                        .font(.system(.callout, design: .rounded).weight(.bold))
                                        .foregroundStyle(.white)
                                )

                            VStack(alignment: .leading) {
                                Text(player.displayName)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(player.playerTag)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(player.runningTotal) pts")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .glassCard()
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding()
        }
    }

    // MARK: - Step 2: Map Others

    private func mapOthersStep(payload: SharePayload) -> some View {
        let others = payload.players.filter { $0.slotID != selfSlotID }
        return VStack(spacing: 0) {
            Text("Match the other players")
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)
                .padding()

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(others, id: \.slotID) { player in
                        PlayerMappingRow(
                            player: player,
                            mapping: Binding(
                                get: { mappings[player.slotID] ?? .skip },
                                set: { mappings[player.slotID] = $0 }
                            ),
                            profiles: profiles.filter { profile in
                                !mappings.values.contains(where: {
                                    if case .linked(let id) = $0 { return id == profile.id }
                                    return false
                                })
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }

            Button {
                step = .confirm
            } label: {
                Text("Continue")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
            }
            .padding()
        }
    }

    // MARK: - Step 3: Confirm

    private func confirmStep(payload: SharePayload) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Import Summary")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                    .padding(.top, 20)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(payload.players, id: \.slotID) { player in
                        HStack {
                            Text(player.displayName)
                                .foregroundStyle(.primary)
                            Spacer()
                            mappingStatusLabel(for: mappings[player.slotID] ?? .skip)
                        }
                        .padding(10)
                        .glassCard()
                    }
                }

                Spacer(minLength: 24)

                Button {
                    if let selfSlotID {
                        gameStore.importGame(payload, selfSlotID: selfSlotID, mappings: mappings)
                        dismiss()
                    }
                } label: {
                    Text("Import Game")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
                }

                Button {
                    step = .mapOthers
                } label: {
                    Text("Back")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
    }

    // MARK: - Helpers

    private func resolveMapping(for player: SharePlayer, isSelf: Bool) -> ProfileMapping {
        if let match = profiles.first(where: { $0.playerTag == player.playerTag }) {
            return .linked(match.id)
        }
        return .skip
    }

    private func autoMatchRemaining(payload: SharePayload, excludingSelf: UUID) {
        for player in payload.players where player.slotID != excludingSelf {
            if mappings[player.slotID] == nil {
                mappings[player.slotID] = resolveMapping(for: player, isSelf: false)
            }
        }
    }

    @ViewBuilder
    private func mappingStatusLabel(for mapping: ProfileMapping) -> some View {
        switch mapping {
        case .linked(let id):
            let name = profiles.first(where: { $0.id == id })?.name ?? "Linked"
            Text(name)
                .font(.caption)
                .foregroundStyle(Color.green)
        case .create(let name):
            Text("New: \(name)")
                .font(.caption)
                .foregroundStyle(Color.accentColor)
        case .skip:
            Text("Skipped")
                .font(.caption)
                .foregroundStyle(Color.gray)
        }
    }
}

// MARK: - PlayerMappingRow

private struct PlayerMappingRow: View {
    let player: SharePlayer
    @Binding var mapping: ProfileMapping
    let profiles: [PlayerProfile]

    @State private var showProfilePicker = false
    @State private var showCreateField = false
    @State private var newName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(player.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(player.playerTag)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                rowMappingStatusLabel
            }

            HStack(spacing: 8) {
                MappingButton(label: "Link", icon: "person.fill.checkmark", active: isLinked) {
                    showProfilePicker = true
                }
                MappingButton(label: "Create", icon: "person.badge.plus", active: isCreate) {
                    showCreateField.toggle()
                }
                MappingButton(label: "Skip", icon: "xmark.circle", active: isSkip) {
                    mapping = .skip
                    showCreateField = false
                }
            }

            if showCreateField {
                HStack {
                    TextField("Enter name", text: $newName)
                        .font(.body)
                        .foregroundStyle(.primary)
                    Button("Done") {
                        if !newName.isEmpty {
                            mapping = .create(newName)
                            showCreateField = false
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                }
                .padding(10)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(12)
        .glassCard()
        .sheet(isPresented: $showProfilePicker) {
            NavigationStack {
                List(profiles) { profile in
                    Button {
                        mapping = .linked(profile.id)
                        showProfilePicker = false
                    } label: {
                        HStack {
                            Circle().fill(profile.avatarColor).frame(width: 32, height: 32)
                                .overlay(Text(profile.initials).font(.caption.weight(.bold)).foregroundStyle(.white))
                            Text(profile.name).foregroundStyle(.primary)
                        }
                    }
                }
                .navigationTitle("Link to Profile")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showProfilePicker = false }
                    }
                }
            }
        }
    }

    private var isLinked: Bool {
        if case .linked = mapping { return true }
        return false
    }

    private var isCreate: Bool {
        if case .create = mapping { return true }
        return false
    }

    private var isSkip: Bool {
        if case .skip = mapping { return true }
        return false
    }

    @ViewBuilder
    private var rowMappingStatusLabel: some View {
        switch mapping {
        case .linked(let id):
            let name = profiles.first(where: { $0.id == id })?.name ?? "Linked"
            Text(name)
                .font(.caption)
                .foregroundStyle(Color.green)
        case .create(let name):
            Text("New: \(name)")
                .font(.caption)
                .foregroundStyle(Color.accentColor)
        case .skip:
            Text("Skipped")
                .font(.caption)
                .foregroundStyle(Color.gray)
        }
    }
}

// MARK: - Mapping Button

private struct MappingButton: View {
    let label: String
    let icon: String
    let active: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(active ? Color.white : Color.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(active ? Color.accentColor : Color(.secondarySystemBackground), in: Capsule())
        }
    }
}
