//
//  ActionTrackerApp.swift
//  ActionTracker
//
//  Created by Stephen Parker on 4/1/25.
//

import SwiftUI
import SwiftData
import OSLog

@main
struct ActionTrackerApp: App {
    // Setup logger
    private let logger = Logger(subsystem: "com.parker1978.ActionTracker", category: "SwiftData")
    
    // Create a simplified SwiftData container
    @State private var modelContainerError: Error?
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: Character.self, isAutosaveEnabled: true)
                .onAppear {
                    // Reset the persistent store if there was an error with migrations
                    if UserDefaults.standard.bool(forKey: "swiftdata_reset_needed") {
                        resetSwiftDataStore()
                        UserDefaults.standard.set(false, forKey: "swiftdata_reset_needed")
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .modelContainerError)) { notification in
                    if let error = notification.userInfo?["error"] as? Error {
                        logger.error("SwiftData error: \(error.localizedDescription)")
                        
                        // Set flag to reset store on next launch
                        UserDefaults.standard.set(true, forKey: "swiftdata_reset_needed")
                    }
                }
        }
    }
    
    // Helper function to reset the SwiftData store if needed
    private func resetSwiftDataStore() {
        logger.notice("Resetting SwiftData store due to previous error")
        
        // Get URL for the SwiftData store
        let storeURL = URL.applicationSupportDirectory
            .appending(path: "default.store")
        
        // Try to remove files
        do {
            if FileManager.default.fileExists(atPath: storeURL.path) {
                try FileManager.default.removeItem(at: storeURL)
                logger.notice("Successfully reset SwiftData store")
            }
        } catch {
            logger.error("Failed to reset SwiftData store: \(error.localizedDescription)")
        }
    }
}

// Extension for SwiftData error notifications
extension Notification.Name {
    static let modelContainerError = Notification.Name("modelContainerError")
}
