import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var weaponsManager = WeaponsManager(
        weapons: WeaponRepository.shared.allWeapons,
        difficulty: .medium
    )

    var body: some View {
        if #available(iOS 26.0, *) {
            TabView(selection: $selectedTab) {
                Tab("Actions", systemImage: "bolt.fill", value: 0) {
                    ActionsScreen(weaponsManager: weaponsManager)
                }

                Tab("Skills", systemImage: "sparkles", value: 1) {
                    SkillsScreen()
                }

                Tab("Spawn Deck", systemImage: "rectangle.stack.fill", value: 2) {
                    SpawnDeckView()
                }

                Tab("Weapons", systemImage: "shield.lefthalf.filled", value: 3) {
                    WeaponsScreen(weaponsManager: weaponsManager)
                }

                Tab(value: 4, role: .search) {
                    CharactersSearchScreen()
                }
            }
            .tabBarMinimizeBehavior(.onScrollDown)
            .tabViewStyle(.sidebarAdaptable)
        } else {
            // Fallback on earlier versions: Use a basic TabView without iOS 26-only modifiers
            TabView(selection: $selectedTab) {
                // Use legacy tab item style for compatibility
                ActionsScreen(weaponsManager: weaponsManager)
                    .tabItem { Label("Actions", systemImage: "bolt.fill") }
                    .tag(0)

                SkillsScreen()
                    .tabItem { Label("Skills", systemImage: "sparkles") }
                    .tag(1)

                SpawnDeckView()
                    .tabItem { Label("Spawn Deck", systemImage: "rectangle.stack.fill") }
                    .tag(2)

                WeaponsScreen(weaponsManager: weaponsManager)
                    .tabItem { Label("Weapons", systemImage: "shield.lefthalf.filled") }
                    .tag(3)

                CharactersSearchScreen()
                    .tabItem { Label("Search", systemImage: "magnifyingglass") }
                    .tag(4)
            }
        }
    }
}

#Preview {
    ContentView()
}
