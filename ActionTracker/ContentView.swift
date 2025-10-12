import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        if #available(iOS 26.0, *) {
            TabView(selection: $selectedTab) {
                Tab("Actions", systemImage: "bolt.fill", value: 0) {
                    ActionsScreen()
                }
                
                Tab("Characters", systemImage: "person.3.fill", value: 1) {
                    CharactersScreen()
                }
                
                Tab(value: 2, role: .search) {
                    CharactersSearchScreen()
                }
            }
            .tabBarMinimizeBehavior(.onScrollDown)
            .tabViewStyle(.sidebarAdaptable)
        } else {
            // Fallback on earlier versions: Use a basic TabView without iOS 26-only modifiers
            TabView(selection: $selectedTab) {
                // Use legacy tab item style for compatibility
                ActionsScreen()
                    .tabItem { Label("Actions", systemImage: "bolt.fill") }
                    .tag(0)
                
                CharactersScreen()
                    .tabItem { Label("Characters", systemImage: "person.3.fill") }
                    .tag(1)
                
                CharactersSearchScreen()
                    .tabItem { Label("Search", systemImage: "magnifyingglass") }
                    .tag(2)
            }
        }
    }
}

#Preview {
    ContentView()
}
