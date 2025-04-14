//
//  ActionTrackerApp.swift
//  ActionTracker
//
//  Created by Stephen Parker on 4/1/25.
//

import SwiftUI
import SwiftData

@main
struct ActionTrackerApp: App {
    // Create a persistent SwiftData container with schema versioning
    let container: ModelContainer = {
        let schema = Schema([Character.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)
        }
    }
}
