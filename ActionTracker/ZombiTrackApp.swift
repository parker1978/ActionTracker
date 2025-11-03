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

            // Run spawn deck tests (can be commented out after verification)
//            #if DEBUG
//            SpawnDeckManager.runTests()
//            #endif

            return container
        } catch {
            // If migration fails, try to delete and recreate the store
            print("⚠️ ModelContainer creation failed: \(error)")
            print("🔄 Attempting to delete and recreate the data store...")

            do {
                // Delete the existing store
                let url = modelConfiguration.url
                if FileManager.default.fileExists(atPath: url.path) {
                    try FileManager.default.removeItem(at: url)
                    print("✅ Deleted existing store at: \(url.path)")
                }

                // Try creating container again
                let container = try ModelContainer(for: schema, configurations: [modelConfiguration])

                // Reseed data
                let context = ModelContext(container)
                DataSeeder.seedIfNeeded(context: context)

                print("✅ Successfully recreated ModelContainer")
                return container
            } catch {
                fatalError("Could not create ModelContainer even after deleting store: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
