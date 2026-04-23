import SwiftUI
import SwiftData

@main
struct RummyApp: App {
    let container: ModelContainer
    @State private var gameStore: GameStore

    init() {
        let schema = Schema([
            PlayerProfile.self,
            MatchupRecord.self,
            GameSession.self,
            GamePlayer.self,
            RoundEntry.self
        ])
        let config = ModelConfiguration("RummyTracker", schema: schema)
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            self.container = container
            _gameStore = State(wrappedValue: GameStore(modelContext: container.mainContext))
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(gameStore)
                .modelContainer(container)
                .onOpenURL { url in
                    gameStore.handleDeepLink(url)
                }
        }
    }
}
