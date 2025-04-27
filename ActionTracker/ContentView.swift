//
//  ContentView.swift
//  ActionTracker
//
//  Created by Stephen Parker on 4/1/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    // Main app state via EnvironmentObject
    @EnvironmentObject private var appViewModel: AppViewModel
    
    // Required SwiftData model context to configure the view model
    @Environment(\.modelContext) private var modelContext
    
    // Persist state using AppStorage
    @AppStorage("keepAwakeEnabled") private var keepAwake: Bool = false
    @AppStorage("activeViewTab") private var activeViewString: String = "action"
    
    // Transform the string-based AppStorage to enum for the view
    @State private var currentView: ViewType = .action
    @State private var isShowingAddCharacter = false
    
    // Timer state
    @State private var timerIsRunning: Bool = false
    
    // Actions state with custom persistence via Codable
    @State private var actionItems: [ActionItem] = []
    
    var body: some View {
        VStack {
            HeaderView(keepAwake: $keepAwake, 
                       currentView: $currentView, 
                       actionItems: $actionItems, 
                       isShowingAddCharacter: $isShowingAddCharacter,
                       timerRunningBinding: $timerIsRunning)
            
            switch currentView {
            case .action:
                ActionView(actionItems: $actionItems, timerIsRunning: $timerIsRunning)
            case .character:
                CharacterListView(isShowingAddCharacter: $isShowingAddCharacter)
            case .campaign:
                CampaignView()
            }
        }
        .onChange(of: keepAwake) {
            UIApplication.shared.isIdleTimerDisabled = keepAwake
        }
        .onChange(of: currentView) { _, newValue in
            // Save the view type when it changes
            switch newValue {
            case .action:
                activeViewString = "action"
            case .character:
                activeViewString = "character"
            case .campaign:
                activeViewString = "campaign"
            }
        }
        .onChange(of: actionItems) { _, newItems in
            // Save actionItems when they change
            saveActionItems(newItems)
        }
        .onAppear {
            // Initialize the AppViewModel with the model context
            appViewModel.configure(with: modelContext)
            
            // Initialize the view state from AppStorage
            switch activeViewString {
            case "action":
                currentView = .action
            case "character":
                currentView = .character
            case "campaign":
                currentView = .campaign
            default:
                currentView = .action
            }
            
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
    
    // Save action items to UserDefaults - now in a more efficient way
    private func saveActionItems(_ items: [ActionItem]) {
        Task {
            // Move encoding to background thread
            guard let encoded = try? JSONEncoder().encode(items) else {
                print("Failed to encode action items")
                return
            }
            
            // UI updates back on main thread
            await MainActor.run {
                UserDefaults.standard.set(encoded, forKey: "savedActionItems")
            }
        }
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
        .environmentObject(AppViewModel())
}
