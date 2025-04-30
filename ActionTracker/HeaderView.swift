//
//  HeaderView.swift
//  ActionTracker
//
//  Created by Stephen Parker on 4/12/25.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UIKit
import Foundation

// Removed menu tracking

enum ViewType {
    case action
    case character
    case campaign
}

struct HeaderView: View {
    @Binding var keepAwake: Bool
    @Binding var currentView: ViewType
    @Binding var actionItems: [ActionItem]
    @Binding var isShowingAddCharacter: Bool
    @State private var addWiggle: Bool = false
    @State private var showingSkillLibrary: Bool = false
    
    // Timer related state - simplified
    @State private var timerStartDate: Date? = nil
    @State private var elapsedTime: TimeInterval = 0
    @State private var showResetConfirmation: Bool = false
    @State private var showStopConfirmation: Bool = false
    @State private var showGameSummary: Bool = false
    @State private var gameEndDate: Date? = nil
    @State private var displayPaused: Bool = false
    
    // Binding to share timer state with parent and siblings
    @Binding var timerRunningBinding: Bool
    
    @Query(sort: \Character.name) var characters: [Character]
    @Environment(\.modelContext) private var context
    
    var title: String {
        switch currentView {
        case .action:
            return "Actions"
        case .character:
            return "Characters"
        case .campaign:
            return "Campaigns"
        }
    }
    
    // Format the elapsed time - hours and minutes only
    var formattedElapsedTime: String {
        let hours = Int(elapsedTime) / 3600
        let minutes = (Int(elapsedTime) % 3600) / 60
        
        // Always show hours and minutes only (no seconds)
        return String(format: "%02d:%02d", hours, minutes)
    }
    
    var body: some View {
        HStack {
            Text(title)
                .font(.largeTitle.bold())
                
            Spacer()
            
            // Timer display - only show in action view
            if currentView == .action {
                HStack(spacing: 4) {
                    // Show icon based on timer state
                    if timerRunningBinding {
                        if displayPaused {
                            // Paused state - show pause icon
                            Image(systemName: "pause.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Image(systemName: "play.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    } else if timerStartDate != nil {
                        // Stopped state
                        Image(systemName: "stop.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    // Timer text with simple styling based on state
                    Text(formattedElapsedTime)
                        .font(.title2.monospacedDigit())
                        .foregroundColor(getTimerTextColor())
                        .contentTransition(.numericText())
                        .animation(displayPaused ? nil : .easeInOut, value: elapsedTime)
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(getTimerBackgroundColor())
                        .animation(.easeInOut(duration: 0.2), value: timerRunningBinding)
                        .animation(.easeInOut(duration: 0.2), value: displayPaused)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(getTimerBorderColor(), lineWidth: 1.5)
                        .animation(.easeInOut(duration: 0.2), value: timerRunningBinding)
                        .animation(.easeInOut(duration: 0.2), value: displayPaused)
                )
                .onTapGesture {
                    // Only allow pause/unpause when timer is running
                    if timerRunningBinding {
                        withAnimation {
                            displayPaused.toggle()
                        }
                        
                        // When unpausing, update immediately
                        if !displayPaused {
                            updateElapsedTime()
                        }
                    }
                }
            }
            
            Spacer()
            
            // Ensure skill names are always normalized when view appears
            .onAppear {
                normalizeSkillNamesIfNeeded()
            }
            
            Menu {
                    Button {
                        keepAwake.toggle()
                        UIApplication.shared.isIdleTimerDisabled = keepAwake
                    } label: {
                        Label(keepAwake ? "Disable Keep Awake" : "Enable Keep Awake", systemImage: keepAwake ? "moon" : "sun.max")
                    }
                    .onAppear {
                        UIApplication.shared.isIdleTimerDisabled = keepAwake
                    }

                    Button {
                        withAnimation(.snappy) {
                            currentView = .action
                        }
                    } label: {
                        Label(
                            "Switch to Actions",
                            systemImage: "checkmark.seal.fill"
                        )
                    }
                
                    Button {
                        withAnimation(.snappy) {
                            currentView = .character
                        }
                    } label: {
                        Label(
                            "Switch to Characters",
                            systemImage: "person.2.fill"
                        )
                    }

                    Button {
                        withAnimation(.snappy) {
                            currentView = .campaign
                        }
                    } label: {
                        Label(
                            "Switch to Campaigns",
                            systemImage: "list.bullet.clipboard"
                        )
                    }
                
                    switch currentView {
                    case .action:
                        Divider ()
                        
                        Button(role: .destructive) {
                            resetActions()
                        } label: {
                            HStack {
                                Text("Reset Actions")
                                Image(systemName: "trash")
                            }
                            .foregroundColor(.red)
                        }
                    case .character:
                        Divider()
                        
                        Button {
                            isShowingAddCharacter = true
                            addWiggle.toggle()
                        } label: {
                            HStack {
                                Text("Add Character")
                                Image(systemName: "plus.circle.fill")
                                    .symbolEffect(.wiggle, value: addWiggle)
                            }
                        }
                        
                        Button {
                            showingSkillLibrary = true
                        } label: {
                            Text("Skill Library")
                            Image(systemName: "book.fill")
                        }
                    case .campaign:
                        Divider()
                        
                        Button(role: .destructive) {
                            withAnimation(.easeOut(duration: 30)) {
                                wipeAllCampaigns()
                            }
                        } label: {
                            HStack {
                                Text("Reset Campaigns")
                                Image(systemName: "trash")
                            }
                            .foregroundColor(.red)
                        }
                    }
                Divider()
                
                Menu {
                    Button {
                        startTimer()
                    } label: {
                        Label(
                            "Start",
                            systemImage: "timer"
                        )
                    }
                    .disabled(timerRunningBinding)
                    
                    Button {
                        showResetConfirmation = true
                    } label: {
                        Label(
                            "Reset",
                            systemImage: "clock.arrow.trianglehead.2.counterclockwise.rotate.90"
                        )
                    }
                    .disabled(timerStartDate == nil)
                    
                    Button {
                        showStopConfirmation = true
                    } label: {
                        Label(
                            "Stop",
                            systemImage: "exclamationmark.arrow.trianglehead.counterclockwise.rotate.90"
                        )
                    }
                    .disabled(!timerRunningBinding)
                } label: {
                    Text("Timer")
                }
                
                Divider()
                
                Menu {
                    // Import options
                    Button {
                        importCharacters()
                    } label: {
                        Label(
                            "Import Characters",
                            systemImage: "square.and.arrow.down.fill"
                        )
                    }
                        
                    Button {
                        importSkills()
                    } label: {
                        Label(
                            "Import Skills",
                            systemImage: "square.and.arrow.down.on.square.fill"
                        )
                    }
                        
                    Divider()
                        
                    // Export options
                    Button {
                        exportCharacters()
                    } label: {
                        Label(
                            "Export Characters",
                            systemImage: "square.and.arrow.up.fill"
                        )
                    }
                        
                    Button {
                        exportSkills()
                    } label: {
                        Label(
                            "Export Skills",
                            systemImage: "square.and.arrow.up.on.square.fill"
                        )
                    }
                } label: {
                    Label(
                        "Import/Export",
                        systemImage: "square.and.arrow.up.down.fill"
                    )
                }
                    
                Divider()
                    
                Button(role: .destructive) {
                    wipeAllCharacters()
                } label: {
                    Label("Delete All Characters", systemImage: "trash.fill")
                }
                    
                Button(role: .destructive) {
                    wipeAllSkills()
                } label: {
                    Label("Delete All Skills", systemImage: "trash.fill")
                }
                    
                Button(role: .destructive) {
                    wipeAllData()
                } label: {
                    Label(
                        "Delete All Data",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.largeTitle)
                    .padding()
            }
        }
        .padding(.horizontal)
        .onAppear {
            normalizeSkillNamesIfNeeded()
        }
        .sheet(isPresented: $showingSkillLibrary) {
            SkillView()
        }
        .confirmationDialog("Reset Timer?", isPresented: $showResetConfirmation) {
            Button("Reset", role: .destructive) {
                resetTimer()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to reset the timer? This will restart the timer at 00:00:00.")
        }
        .confirmationDialog("Stop Timer?", isPresented: $showStopConfirmation) {
            Button("Stop", role: .destructive) {
                stopTimer()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to stop the timer? This will end the current game session.")
        }
        .alert("Game Summary", isPresented: $showGameSummary) {
            Button("OK") {}
        } message: {
            if let startDate = timerStartDate, let endDate = gameEndDate {
                let startFormatter = DateFormatter()
                startFormatter.dateStyle = .none
                startFormatter.timeStyle = .short  // HH:MM format
                
                let endFormatter = DateFormatter()
                endFormatter.dateStyle = .none
                endFormatter.timeStyle = .short    // HH:MM format
                
                let durationHours = Int(elapsedTime) / 3600
                let durationMinutes = (Int(elapsedTime) % 3600) / 60
                
                // Get current experience and total gained
                let currentXP = UserDefaults.standard.integer(forKey: "playerExperience")
                let totalXP = UserDefaults.standard.integer(forKey: "totalExperienceGained")
                
                // Include experience info in summary
                return Text("Game session started at \(startFormatter.string(from: startDate)) and ended at \(endFormatter.string(from: endDate)).\n\nTotal game time: \(durationHours)h \(durationMinutes)m\n\nCurrent Experience: \(currentXP)\nTotal Experience Gained: \(totalXP)")
            } else {
                return Text("Game session ended.")
            }
        }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
            // Update once per minute to keep timer showing the right time
            // Since we only display HH:MM, updating more frequently isn't needed
            if timerRunningBinding && !displayPaused {
                updateElapsedTime()
            }
        }
        // Also update every second in background (while not displaying)
        // This ensures we have the correct time even when paused
        .onReceive(Timer.publish(every: 10, on: .main, in: .common).autoconnect()) { _ in
            if timerRunningBinding {
                // Silent update - just calculate time but don't update display
                // This ensures when we unpause, we have the correct time
                if let startDate = timerStartDate {
                    // Store but don't display if paused
                    elapsedTime = Date().timeIntervalSince(startDate)
                }
            }
        }
    }
    
    // Timer functions - simplified
    private func startTimer() {
        // Start a new timer
        timerStartDate = Date()
        timerRunningBinding = true
        displayPaused = false  // Always start with display active
        elapsedTime = 0
        updateElapsedTime()    // Initialize with proper time
    }
    
    private func resetTimer() {
        // Reset the timer to current time
        timerStartDate = Date()
        timerRunningBinding = true
        displayPaused = false  // Always reset with display active
        elapsedTime = 0
        updateElapsedTime()    // Initialize with proper time
    }
    
    private func stopTimer() {
        timerRunningBinding = false
        gameEndDate = Date()
        showGameSummary = true
    }
    
    // Helper functions for timer display
    private func updateElapsedTime() {
        if let startDate = timerStartDate {
            elapsedTime = Date().timeIntervalSince(startDate)
        }
    }
    
    // Get the appropriate text color based on timer state
    private func getTimerTextColor() -> Color {
        if !timerRunningBinding && timerStartDate != nil {
            // Stopped state - red text
            return .red
        } else if displayPaused {
            // Paused state - grey text
            return .secondary
        } else {
            // Running state - white/primary text
            return .primary
        }
    }
    
    // Get the appropriate background color based on timer state
    private func getTimerBackgroundColor() -> Color {
        if !timerRunningBinding && timerStartDate != nil {
            // Stopped state - light red background
            return Color.red.opacity(0.1)
        } else if displayPaused {
            // Paused state - light grey background
            return Color(UIColor.secondarySystemBackground).opacity(0.3)
        } else {
            // Running state - subtle blue background
            return Color.blue.opacity(0.05)
        }
    }
    
    // Get the appropriate border color based on timer state
    private func getTimerBorderColor() -> Color {
        if !timerRunningBinding && timerStartDate != nil {
            // Stopped state - red border
            return Color.red.opacity(0.3)
        } else if displayPaused {
            // Paused state - grey border
            return Color.secondary.opacity(0.3)
        } else {
            // Running state - blue border
            return Color.blue.opacity(0.3)
        }
    }
    
    private func exportCharacters() {
        // Dictionary to track processed characters by name+set to prevent duplicates
        // Key format is "name|set" in lowercase
        var processedCharacters: [String: Character] = [:]
        
        // First pass - collect unique characters by name+set combo
        for character in characters {
            // Normalize the name and set - trim and fix all whitespace issues
            let trimmedName = character.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedName = trimmedName.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).lowercased()
            
            let trimmedSet = (character.set ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedSet = trimmedSet.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).lowercased()
            
            // Create a composite key for uniqueness
            let key = "\(normalizedName)|\(normalizedSet)"
            
            // If this name/set combo exists, keep the one with more information
            if let existingChar = processedCharacters[key] {
                // Treat a nil skills array as “0” skills
                let existingSkillCount = existingChar.skills?.count ?? 0
                let newSkillCount      = character.skills?.count     ?? 0
                let existingNotesLength = existingChar.notes?.count ?? 0
                let newNotesLength      = character.notes?.count     ?? 0

                // Now both are Int, so you can compare safely
                if newSkillCount > existingSkillCount ||
                   (newSkillCount == existingSkillCount && newNotesLength > existingNotesLength) {
                    processedCharacters[key] = character
                }
            } else {
                processedCharacters[key] = character
            }
        }
        
        // Generate CSV content - updated header for the new format
        var csvString = "Name,Set,Notes,Blue,Orange,Red\n"
        
        // Sort the unique characters alphabetically by name, then by set
        let uniqueCharacters = processedCharacters.values.sorted { char1, char2 in
            if char1.name.lowercased() != char2.name.lowercased() {
                return char1.name.lowercased() < char2.name.lowercased()
            } else {
                let set1 = char1.set?.lowercased() ?? ""
                let set2 = char2.set?.lowercased() ?? ""
                return set1 < set2
            }
        }
        
        // Process each unique character for CSV export
        for character in uniqueCharacters {
            // First clean up all whitespace in both name and set
            let cleanName = character.name.trimmingCharacters(in: .whitespacesAndNewlines)
                                         .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            
            // Capitalize the name properly for a character (Title Case)
            let nameWords = cleanName.split(separator: " ")
            let capitalizedName = nameWords.map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }.joined(separator: " ")
            
            // Clean up set and notes too
            let cleanSet = (character.set ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                                              .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            
            let cleanNotes = (character.notes ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                                                  .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            
            // Escape quotes for CSV
            let name = capitalizedName.replacingOccurrences(of: "\"", with: "\"\"") 
            let set = cleanSet.replacingOccurrences(of: "\"", with: "\"\"") 
            let notes = cleanNotes.replacingOccurrences(of: "\"", with: "\"\"") 
            
            // Group skills by color
            var blueSkills: [String] = []
            var orangeSkills: [String] = []
            var redSkills: [String] = []
            
            // Sort skills by position and group by color
            if let sortedSkills = character.skills?
                                    .sorted(by: { $0.position < $1.position }) {
                for skill in sortedSkills {
                    let normalizedName = Skill.normalizeSkillName(skill.name)

                    switch skill.color {
                    case .blue:
                        blueSkills.append(normalizedName)
                    case .orange:
                        orangeSkills.append(normalizedName)
                    case .red:
                        redSkills.append(normalizedName)
                    case .none:
                        break   // or handle missing color if needed
                    }
                }
            }
            
            // Join skills by color with semicolons and escape quotes
            let blueSkillsStr = blueSkills.joined(separator: ";").replacingOccurrences(of: "\"", with: "\"\"")
            let orangeSkillsStr = orangeSkills.joined(separator: ";").replacingOccurrences(of: "\"", with: "\"\"")
            let redSkillsStr = redSkills.joined(separator: ";").replacingOccurrences(of: "\"", with: "\"\"")
            
            // Create the CSV row with the new format
            let row = "\"\(name)\",\"\(set)\",\"\(notes)\",\"\(blueSkillsStr)\",\"\(orangeSkillsStr)\",\"\(redSkillsStr)\""
            csvString.append(row + "\n")
        }
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("characters.csv")
        do {
            try csvString.write(to: tempURL, atomically: true, encoding: .utf8)
            let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(activityVC, animated: true, completion: nil)
            }
        } catch {
            print("Export failed: \(error)")
            
            // Show error alert
            let alert = UIAlertController(
                title: "Export Failed",
                message: "Failed to export characters: \(error.localizedDescription)",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(alert, animated: true)
            }
        }
    }
    
    private func exportSkills() {
        // Fetch all skills
        let skillsDescriptor = FetchDescriptor<Skill>(sortBy: [SortDescriptor(\.name)])
        
        do {
            let allSkills = try context.fetch(skillsDescriptor)
            
            if allSkills.isEmpty {
                // Show alert if no skills to export
                let alert = UIAlertController(
                    title: "No Skills",
                    message: "There are no skills to export.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootVC = windowScene.windows.first?.rootViewController {
                    rootVC.present(alert, animated: true)
                }
                return
            }
            
            // Dictionary to track processed skills by name (lowercase) to prevent duplicates
            var processedSkills: [String: Skill] = [:]
            
            // First pass - collect unique skills by lowercase name
            for skill in allSkills {
                // Clean up whitespace before normalization
                let trimmedName = skill.name.trimmingCharacters(in: .whitespacesAndNewlines)
                let cleanName = trimmedName.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                let lowerName = cleanName.lowercased()
                
                // If this lowercase name exists, keep the one with more information
                if let existingSkill = processedSkills[lowerName] {
                    // Choose the one with the most information
                    if skill.skillDescription.count > existingSkill.skillDescription.count {
                        processedSkills[lowerName] = skill
                    }
                } else {
                    // First time seeing this skill name
                    processedSkills[lowerName] = skill
                }
            }
            
            // Generate CSV content
            var csvString = "Name,Description\n"
            
            // Sort the unique skills alphabetically
            let uniqueSkills = processedSkills.values.sorted { $0.name.lowercased() < $1.name.lowercased() }
            
            for skill in uniqueSkills {
                // Use normalized name to ensure consistent capitalization
                let name = Skill.normalizeSkillName(skill.name).replacingOccurrences(of: "\"", with: "\"\"")
                
                // Clean up description whitespace
                let cleanDescription = skill.skillDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                                                            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                                                            .replacingOccurrences(of: "\"", with: "\"\"")
                
                let row = "\"\(name)\",\"\(cleanDescription)\""
                csvString.append(row + "\n")
            }
            
            // Write to temporary file
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("skills.csv")
            try csvString.write(to: tempURL, atomically: true, encoding: .utf8)
            
            // Show share sheet
            let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(activityVC, animated: true, completion: nil)
            }
            
        } catch {
            print("Failed to export skills: \(error)")
            
            // Show error alert
            let alert = UIAlertController(
                title: "Export Failed",
                message: "Failed to export skills: \(error.localizedDescription)",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(alert, animated: true)
            }
        }
    }
    
    // Static key to store the coordinator reference to prevent it from being deallocated
    private static var coordinatorKey = "com.actiontracker.skillImportCoordinatorKey"
    
    // Coordinator class for handling skill imports
    class SkillImportCoordinator: NSObject, UIDocumentPickerDelegate {
        private let modelContext: ModelContext
        
        init(modelContext: ModelContext) {
            self.modelContext = modelContext
            super.init()
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            
            guard url.startAccessingSecurityScopedResource() else {
                print("Failed to access security-scoped resource.")
                return
            }
            
            defer { url.stopAccessingSecurityScopedResource() }
            
            do {
                // Read the CSV file
                let content = try String(contentsOf: url, encoding: .utf8)
                let rows = content.components(separatedBy: CharacterSet.newlines).dropFirst() // Skip header
                
                var importedCount = 0
                var skippedCount = 0
                
                // Process each row
                for line in rows {
                    guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
                    
                    // Parse the CSV line (assuming no commas in quoted values for simplicity)
                    let columns = parseCSVLine(line)
                    guard columns.count >= 2 else { continue }
                    
                    // Clean up name and description - trim spaces and normalize internal spacing
                    let rawName = columns[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    let cleanName = rawName.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                    
                    let rawDescription = columns[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    let cleanDescription = rawDescription.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                    
                    // Skip if empty name
                    if cleanName.isEmpty { continue }
                    
                    // Check if skill with the same name (case-insensitive) already exists
                    // First normalize the name using our helper
                    let normalizedName = Skill.normalizeSkillName(cleanName)
                    
                    // For predicate, we can only use exact matching without string functions
                    var skillDescriptor = FetchDescriptor<Skill>()
                    skillDescriptor.predicate = #Predicate<Skill> { skill in 
                        skill.name == normalizedName
                    }
                    
                    do {
                        let existingSkills = try modelContext.fetch(skillDescriptor)
                        
                        if existingSkills.isEmpty {
                            // Create new skill - Note: Skill initializer will normalize the name automatically
                            let newSkill = Skill(name: cleanName, skillDescription: cleanDescription, manual: true, importedFlag: true, color: .blue)
                            modelContext.insert(newSkill)
                            importedCount += 1
                        } else {
                            // Skill already exists, skip
                            skippedCount += 1
                            
                            // Optionally update description if the existing one is empty
                            if let existingSkill = existingSkills.first, existingSkill.skillDescription.isEmpty && !cleanDescription.isEmpty {
                                existingSkill.skillDescription = cleanDescription
                            }
                        }
                    } catch {
                        print("Error checking for existing skill: \(error)")
                    }
                }
                
                // Save changes
                try modelContext.save()
                
                // Show success alert
                DispatchQueue.main.async {
                    self.showResultAlert(imported: importedCount, skipped: skippedCount)
                }
                
            } catch {
                print("Import failed: \(error)")
                
                // Show error alert
                DispatchQueue.main.async {
                    self.showErrorAlert(error: error)
                }
            }
        }
        
        private func parseCSVLine(_ line: String) -> [String] {
            var results: [String] = []
            var value = ""
            var insideQuotes = false
            
            var iterator = line.makeIterator()
            while let char = iterator.next() {
                switch char {
                case "\"":
                    insideQuotes.toggle()
                case ",":
                    if insideQuotes {
                        value.append(char)
                    } else {
                        results.append(value)
                        value = ""
                    }
                default:
                    value.append(char)
                }
            }
            results.append(value)
            return results.map { $0.replacingOccurrences(of: "\"\"", with: "\"") }
        }
        
        private func showResultAlert(imported: Int, skipped: Int) {
            let alert = UIAlertController(
                title: "Import Complete",
                message: "Successfully imported \(imported) new skills. \(skipped) existing skills were skipped.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(alert, animated: true)
            }
        }
        
        private func showErrorAlert(error: Error) {
            let alert = UIAlertController(
                title: "Import Failed",
                message: "Failed to import skills: \(error.localizedDescription)",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(alert, animated: true)
            }
        }
    }
    
    private func importSkills() {
        let alert = UIAlertController(
            title: "Import Skills",
            message: """
            Import will add new skills to your library.
            Existing skills with the same name will be skipped.
            
            Make sure your CSV has this format:
            
            Name,Description
            "+1 Die: Combat","Add 1 die to combat rolls"
            "Lucky","Re-roll one failed die per turn"
            """,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Continue", style: .default) { _ in
            let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.commaSeparatedText])
            documentPicker.allowsMultipleSelection = false
            
            // Using a coordinator for the document picker
            let coordinator = SkillImportCoordinator(modelContext: self.context)
            documentPicker.delegate = coordinator
            
            // Keep a reference to the coordinator to prevent it from being deallocated
            objc_setAssociatedObject(documentPicker, HeaderView.coordinatorKey, coordinator, .OBJC_ASSOCIATION_RETAIN)
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(documentPicker, animated: true, completion: nil)
            }
        })
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(alert, animated: true, completion: nil)
        }
    }
    
    private func importCharacters() {
        // Configure with context and completion handler
        CustomContext.shared.configure(with: context) {
            // This will be called after successful import
            print("Import completed, refreshing view...")
            
            // Important: Save the context and send a notification
            do {
                try context.save()
                print("Context saved after import")
                
                // Verify character count from the context that's using the view
                let verifyCount = try context.fetch(FetchDescriptor<Character>()).count
                print("Verified after import completion: \(verifyCount) characters in UI context")
                
                // Force refresh notification
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    print("==== SENDING REFRESH NOTIFICATION AFTER IMPORT ====")
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshCharacterData"), object: nil)
                }
            } catch {
                print("Error saving context after import: \(error)")
            }
        }
        
        let alert = UIAlertController(
            title: "Import Format",
            message: """
            Import will replace all existing characters.
            
            Make sure your CSV has this format:
            
            Name,Set,Notes,Blue,Orange,Red
            "Adam","","Special","Zombie Link","+1 To Dice Roll: Melee;Distributor","+1 Damage: Combat;+1 Free Action: Combat;Born Leader"
            
            - Blue skills are active by default
            - Orange skills can be activated at XP 19
            - Red skills can be activated at XP 43
            - Multiple skills in the same power level are separated by ";"
            """,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Continue", style: .default) { _ in
            let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.commaSeparatedText])
            documentPicker.allowsMultipleSelection = false
            documentPicker.delegate = CustomContext.shared
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(documentPicker, animated: true, completion: nil)
            }
        })
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(alert, animated: true, completion: nil)
        }
        return
    }
    
    // Ensures that all skill names are consistently capitalized
    private func normalizeSkillNamesIfNeeded() {
        // Check if we've already normalized skill names this session
        let normalizedKey = "ActionTracker.skillsNormalizedThisSession"
        if UserDefaults.standard.bool(forKey: normalizedKey) {
            return  // Already normalized this session
        }
        
        // Fetch all skills
        let skillsDescriptor = FetchDescriptor<Skill>()
        
        do {
            let allSkills = try context.fetch(skillsDescriptor)
            var changesMade = false
            
            // Normalize each skill name
            for skill in allSkills {
                let currentName = skill.name
                let normalizedName = Skill.normalizeSkillName(currentName)
                
                // Check if the name needs normalization
                if currentName != normalizedName {
                    print("Normalizing skill name from '\(currentName)' to '\(normalizedName)'")
                    skill.name = normalizedName
                    changesMade = true
                }
            }
            
            // Save changes if needed
            if changesMade {
                try context.save()
                print("Successfully normalized skill names")
            }
            
            // Mark as normalized for this session
            UserDefaults.standard.set(true, forKey: normalizedKey)
        } catch {
            print("Error normalizing skill names: \(error)")
        }
    }
    
    // MARK: - Data Wiping Functions
    private func resetActions() {
        // Get current experience for the summary
        let currentExperience = UserDefaults.standard.integer(forKey: "playerExperience")
        _ = UserDefaults.standard.integer(forKey: "totalExperienceGained")
        
        // Show confirmation alert with experience info
        let alert = UIAlertController(
            title: "Reset All Actions",
            message: "This will reset ALL to the default 3 starting actions, reset your experience to 0, and stop the timer if running. Your current experience is \(currentExperience). This action cannot be undone.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Reset All", style: .destructive) { _ in
            self.executeResetActions()
        })
        
        // Present the alert
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(alert, animated: true)
        }
    }
    
    private func executeResetActions() {
        // First stop the timer if it's running
        if timerRunningBinding {
            stopTimer()
        }
        
        // Reset the actions
        withAnimation(.easeOut(duration: 0.5)) {
            actionItems = ActionItem.defaultActions()
        }
        
        // Get the current experience for the summary alert
        let currentExperience = UserDefaults.standard.integer(forKey: "playerExperience")
        let totalXP = UserDefaults.standard.integer(forKey: "totalExperienceGained")
        
        // Reset experience to 0
        UserDefaults.standard.set(0, forKey: "playerExperience")
        UserDefaults.standard.set(0, forKey: "ultraRedCount")
        // Also reset total experience gained
        UserDefaults.standard.set(0, forKey: "totalExperienceGained")
        
        // Post a notification to tell ActionView to update its experience value
        NotificationCenter.default.post(name: NSNotification.Name("ResetExperience"), object: nil)
        
        // Show a summary alert with experience data
        let experienceSummary = UIAlertController(
            title: "Game Session Summary",
            message: "Game session ended.\n\nExperience reset from \(currentExperience) to 0.\nTotal experience gained during your adventure: \(totalXP).",
            preferredStyle: .alert
        )
        
        experienceSummary.addAction(UIAlertAction(title: "OK", style: .default))
        
        // Present the summary after a short delay
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            // Use a slight delay to show this after any timer summary
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                rootVC.present(experienceSummary, animated: true)
            }
        }
    }
    
    private func wipeAllCharacters() {
        // Show confirmation alert
        let alert = UIAlertController(
            title: "Delete All Characters",
            message: "This will delete ALL characters in the database. Skills will remain but will be orphaned. This action cannot be undone.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete All", style: .destructive) { _ in
            self.executeWipeAllCharacters()
        })
        
        // Present the alert
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(alert, animated: true)
        }
    }
    
    private func executeWipeAllCharacters() {
        do {
            // 1. Fetch all characters
            let allCharacters = try context.fetch(FetchDescriptor<Character>())
            
            // 2. Delete all characters
            for character in allCharacters {
                context.delete(character)
            }
            
            // 3. Save changes
            try context.save()
            
            // 4. Post notification to refresh views
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NotificationCenter.default.post(name: NSNotification.Name("RefreshCharacterData"), object: nil)
            }
        } catch {
            print("Error wiping characters: \(error)")
            
            // Show error alert
            let alert = UIAlertController(
                title: "Error",
                message: "Failed to delete characters: \(error.localizedDescription)",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(alert, animated: true)
            }
        }
    }
    
    private func wipeAllCampaigns() {
        // Show confirmation alert
        let alert = UIAlertController(
            title: "Wipe All Campaigns",
            message: "This will delete ALL campaigns in the database. This action cannot be undone.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete All", style: .destructive) { _ in
            self.executeWipeAllCampaigns()
        })
        
        // Present the alert
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(alert, animated: true)
        }
    }
    
    private func executeWipeAllCampaigns() {
        do {
            let allCampaigns = try context.fetch(FetchDescriptor<Campaign>())
            
            for campaign in allCampaigns {
                context.delete(campaign)
            }
            
            try context.save()
            
            // Post notification to refresh views
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NotificationCenter.default.post(name: NSNotification.Name("RefreshCharacterData"), object: nil)
            }
        } catch {
            print("Error wiping campaigns: \(error)")
            
            let alert = UIAlertController(
                title: "Error",
                message: "Failed to delete campaigns: \(error.localizedDescription)",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(alert, animated: true)
            }
        }
    }
    
    private func wipeAllSkills() {
        // Show confirmation alert
        let alert = UIAlertController(
            title: "Delete All Skills",
            message: "This will delete ALL skills in the database and remove them from all characters. This action cannot be undone.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete All", style: .destructive) { _ in
            self.executeWipeAllSkills()
        })
        
        // Present the alert
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(alert, animated: true)
        }
    }
    
    private func executeWipeAllSkills() {
        do {
            // 1. First, clear skills from all characters
            for character in characters {
                character.skills = []
            }
            
            // 2. Fetch all skills
            let allSkills = try context.fetch(FetchDescriptor<Skill>())
            
            // 3. Delete all skills
            for skill in allSkills {
                context.delete(skill)
            }
            
            // 4. Save changes
            try context.save()
            
            // 5. Post notification to refresh views
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NotificationCenter.default.post(name: NSNotification.Name("RefreshCharacterData"), object: nil)
            }
        } catch {
            print("Error wiping skills: \(error)")
            
            // Show error alert
            let alert = UIAlertController(
                title: "Error",
                message: "Failed to delete skills: \(error.localizedDescription)",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(alert, animated: true)
            }
        }
    }
    
    private func wipeAllData() {
        // Show confirmation alert
        let alert = UIAlertController(
            title: "Delete ALL Data",
            message: "This will delete ALL characters AND skills in the database. The database will be completely empty. This action cannot be undone.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete Everything", style: .destructive) { _ in
            self.executeWipeAllData()
        })
        
        // Present the alert
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(alert, animated: true)
        }
    }
    
    private func executeWipeAllData() {
        do {
            // 1. First, delete all characters
            let allCharacters = try context.fetch(FetchDescriptor<Character>())
            for character in allCharacters {
                context.delete(character)
            }
            
            // 2. Then, delete all skills
            let allSkills = try context.fetch(FetchDescriptor<Skill>())
            for skill in allSkills {
                context.delete(skill)
            }
            
            // 3. Save changes
            try context.save()
            
            // 4. Post notification to refresh views
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NotificationCenter.default.post(name: NSNotification.Name("RefreshCharacterData"), object: nil)
            }
        } catch {
            print("Error wiping all data: \(error)")
            
            // Show error alert
            let alert = UIAlertController(
                title: "Error",
                message: "Failed to delete all data: \(error.localizedDescription)",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(alert, animated: true)
            }
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var timerRunning: Bool = false
        
        var body: some View {
            ContentView()
                .environmentObject(AppViewModel())
        }
    }
    
    return PreviewWrapper()
}
