//
//  ContentView.swift
//  ActionTracker
//
//  Created by Stephen Parker on 4/1/25.
//

import SwiftUI

struct ContentView: View {
    // Persist state using AppStorage
    @AppStorage("keepAwakeEnabled") private var keepAwake: Bool = false
    @AppStorage("activeViewTab") private var activeViewString: String = "action"
    
    // Transform the string-based AppStorage to enum for the view
    @State private var currentView: ViewType = .action
    @State private var isShowingAddCharacter = false
    
    // Actions state with custom persistence via Codable
    @State private var actionItems: [ActionItem] = []
    
    var body: some View {
        VStack {
            HeaderView(keepAwake: $keepAwake, 
                       currentView: $currentView, 
                       actionItems: $actionItems, 
                       isShowingAddCharacter: $isShowingAddCharacter)
            
            if currentView == .action {
                ActionView(actionItems: $actionItems)
            } else {
                CharacterListView(isShowingAddCharacter: $isShowingAddCharacter)
            }
        }
        .onChange(of: keepAwake) {
            UIApplication.shared.isIdleTimerDisabled = keepAwake
        }
        .onChange(of: currentView) { _, newValue in
            // Save the view type when it changes
            activeViewString = newValue == .action ? "action" : "character"
        }
        .onChange(of: actionItems) { _, newItems in
            // Save actionItems when they change
            saveActionItems(newItems)
        }
        .onAppear {
            // Initialize the view state from AppStorage
            currentView = activeViewString == "action" ? .action : .character
            
            // Load saved actions if available, otherwise use defaults
            if let savedItems = loadActionItems() {
                actionItems = savedItems
            } else {
                actionItems = ActionItem.defaultActions()
            }
            
            // Apply idle timer setting
            UIApplication.shared.isIdleTimerDisabled = keepAwake
        }
    }
    
    // Save action items to UserDefaults
    private func saveActionItems(_ items: [ActionItem]) {
        guard let encoded = try? JSONEncoder().encode(items) else {
            print("Failed to encode action items")
            return
        }
        UserDefaults.standard.set(encoded, forKey: "savedActionItems")
    }
    
    // Load action items from UserDefaults
    private func loadActionItems() -> [ActionItem]? {
        guard let data = UserDefaults.standard.data(forKey: "savedActionItems"),
              let decoded = try? JSONDecoder().decode([ActionItem].self, from: data) else {
            return nil
        }
        return decoded
    }
}

#Preview {
    ContentView()
}
