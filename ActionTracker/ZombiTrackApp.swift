import SwiftUI
import SwiftData

@main
struct ZombiTrackApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Character.self,
            Skill.self,
            GameSession.self,
            ActionInstance.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])

            // Preload built-in data on first launch
            let context = ModelContext(container)
            DataSeeder.seedIfNeeded(context: context)

            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
