import SwiftUI
import SwiftData
import AppShell
import CoreDomain
import DataLayer

@main
struct ZombiTrackApp: App {
    private static let storeName = "ActionTrackerModel-v2"

    private static func legacyStoreURL() -> URL? {
        guard let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return baseURL.appendingPathComponent("default.store", isDirectory: false)
    }

    private static func purgeLegacyStoreIfNeeded() {
        guard let legacyURL = legacyStoreURL(),
              FileManager.default.fileExists(atPath: legacyURL.path) else {
            return
        }

        do {
            try FileManager.default.removeItem(at: legacyURL)
            print("🗑️ Removed legacy SwiftData store at: \(legacyURL.path)")
        } catch {
            print("⚠️ Failed to remove legacy SwiftData store: \(error)")
        }
    }

    var sharedModelContainer: ModelContainer = {
        purgeLegacyStoreIfNeeded()

        let schema = Schema([
            // Core models
            CoreDomain.Character.self,
            CoreDomain.Skill.self,
            CoreDomain.GameSession.self,
            CoreDomain.ActionInstance.self,
            // Phase 0: Weapon models
            CoreDomain.WeaponDefinition.self,
            CoreDomain.WeaponCardInstance.self,
            CoreDomain.WeaponInventoryItem.self,
            CoreDomain.DeckCustomization.self,
            CoreDomain.DeckPreset.self,
            CoreDomain.WeaponDataVersion.self,
        ])
        let modelConfiguration = ModelConfiguration(
            storeName,
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])

            // Preload built-in data on first launch
            let context = ModelContext(container)
            DataSeeder.seedIfNeeded(context: context)

            // Phase 0: Import weapons from XML into SwiftData
            Task { @MainActor in
                do {
                    let importService = WeaponImportService(context: context)
                    try await importService.importWeaponsIfNeeded()
                    try importService.validateImport()
                } catch {
                    print("⚠️ Weapons import failed: \(error)")
                }
            }

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
