import SwiftUI
import SwiftData
import CoreDomain
import DataLayer
import GameSessionFeature
import CharacterFeature
import SkillsFeature
import WeaponsFeature
import SpawnDeckFeature

public struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab = 0
    @State private var spawnDeckManager = SpawnDeckManager()

    public init() {}

    public var body: some View {
        if #available(iOS 26.0, *) {
            TabView(selection: $selectedTab) {
                Tab("Actions", systemImage: "bolt.fill", value: 0) {
                    ActionsScreen(spawnDeckManager: spawnDeckManager)
                }

                Tab("Characters", systemImage: "person.3.fill", value: 1) {
                    CharactersSearchScreen()
                }

                Tab("Skills", systemImage: "sparkles", value: 2) {
                    SkillsScreen()
                }

                Tab("Spawn Deck", systemImage: "rectangle.stack.fill", value: 3) {
                    SpawnDeckView(deckManager: spawnDeckManager)
                }

                Tab("Weapons", systemImage: "shield.lefthalf.filled", value: 4) {
                    WeaponsScreenNew(context: modelContext)
                }
            }
            .tabBarMinimizeBehavior(.onScrollDown)
            .tabViewStyle(.sidebarAdaptable)
        } else {
            // Fallback on earlier versions: Use a basic TabView without iOS 26-only modifiers
            TabView(selection: $selectedTab) {
                // Use legacy tab item style for compatibility
                ActionsScreen(spawnDeckManager: spawnDeckManager)
                    .tabItem { Label("Actions", systemImage: "bolt.fill") }
                    .tag(0)

                CharactersSearchScreen()
                    .tabItem { Label("Characters", systemImage: "person.3.fill") }
                    .tag(1)

                SkillsScreen()
                    .tabItem { Label("Skills", systemImage: "sparkles") }
                    .tag(2)

                SpawnDeckView(deckManager: spawnDeckManager)
                    .tabItem { Label("Spawn Deck", systemImage: "rectangle.stack.fill") }
                    .tag(3)

                WeaponsScreenNew(context: modelContext)
                    .tabItem { Label("Weapons", systemImage: "shield.lefthalf.filled") }
                    .tag(4)
            }
        }
    }
}

#Preview {
    ContentView()
}
