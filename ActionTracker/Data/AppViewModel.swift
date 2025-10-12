//
//  AppViewModel.swift
//  ActionTracker
//
//  Created by Stephen Parker on 4/27/25.
//

import SwiftUI
import SwiftData
import Combine
import OSLog

/// Central application state manager to optimize data flow and avoid redundant operations
class AppViewModel: ObservableObject {
    // MARK: - Properties
    
    // Logger
    private let logger = Logger(subsystem: "com.parker1978.ActionTracker", category: "AppViewModel")
    
    // Character state
    @Published private(set) var characters: [Character] = []
    @Published private(set) var selectedCharacter: Character?
    @Published private(set) var filteredCharacters: [Character] = []
    @Published var searchText: String = "" {
        didSet { filterCharacters() }
    }
    
    // Experience tracking
    @AppStorage("playerExperience") var experience: Int = 0 {
        willSet { objectWillChange.send() }
    }
    @AppStorage("ultraRedCount") var ultraRedCount: Int = 0 {
        willSet { objectWillChange.send() }
    }
    @AppStorage("totalExperienceGained") var totalExperienceGained: Int = 0 {
        willSet { objectWillChange.send() }
    }
    
    // Selected character persistence
    @AppStorage("selectedCharacterName") var selectedCharacterName: String = "" {
        willSet { objectWillChange.send() }
    }
    @AppStorage("selectedCharacterSet") var selectedCharacterSet: String = "" {
        willSet { objectWillChange.send() }
    }
    
    // Mission tracking
    @AppStorage("currentMissionID") var currentMissionID: String = "" {
        willSet { objectWillChange.send() }
    }
    @AppStorage("missionStartXP") var missionStartXP: Int = 0 {
        willSet { objectWillChange.send() }
    }
    
    // UI state
    @Published var showCharacterPicker = false
    @Published var showSkillManager = false
    
    // Data context
    private var modelContext: ModelContext?
    
    // MARK: - Initialization
    
    init() {
        // Initialize with empty state
        logger.debug("AppViewModel initialized")
    }
    
    // MARK: - Data Management
    
    /// Configure with SwiftData context
    func configure(with context: ModelContext) {
        self.modelContext = context
        logger.debug("ModelContext configured")
        
        // Initial fetch
        fetchCharacters()
        
        // Try to restore previously selected character
        restoreSelectedCharacter()
    }
    
    /// Fetch all characters with optimized sorting
    func fetchCharacters() {
        guard let context = modelContext else {
            logger.error("ModelContext not available for fetchCharacters")
            return
        }
        
        do {
            var descriptor = FetchDescriptor<Character>()
            descriptor.sortBy = [SortDescriptor(\Character.name)]
            
            // Fetch within try block since it can throw
            var fetchedCharacters = try context.fetch(descriptor)
            
            // Sort favorites to the top manually - only once
            fetchedCharacters.sort { (char1, char2) -> Bool in
                if char1.isFavorite && !char2.isFavorite {
                    return true
                } else if !char1.isFavorite && char2.isFavorite {
                    return false
                } else {
                    return char1.name.localizedCaseInsensitiveCompare(char2.name) == .orderedAscending
                }
            }
            
            // Update state all at once
            self.characters = fetchedCharacters
            filterCharacters()
            
            logger.debug("Fetched \(fetchedCharacters.count) characters")
        } catch {
            logger.error("Error fetching characters: \(error.localizedDescription)")
            self.characters = []
            filterCharacters()
        }
    }
    
    /// Filter characters based on search text - computed once
    private func filterCharacters() {
        if searchText.isEmpty {
            filteredCharacters = characters
        } else {
            filteredCharacters = characters.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                ($0.set ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    /// Attempt to restore previously selected character
    private func restoreSelectedCharacter() {
        if !selectedCharacterName.isEmpty {
            selectedCharacter = characters.first { character in
                character.name == selectedCharacterName && 
                (character.set ?? "") == selectedCharacterSet
            }
            
            if selectedCharacter != nil {
                logger.debug("Restored selected character: \(self.selectedCharacterName)")
            }
        }
    }
    
    /// Select a character and save selection
    func selectCharacter(_ character: Character) {
        selectedCharacter = character
        selectedCharacterName = character.name
        selectedCharacterSet = character.set ?? ""
        
        // Reset character skills when selected - only blue skills should be active
        resetCharacterSkills(character)
        
        logger.debug("Selected character: \(character.name)")
    }
    
    /// Clear selected character
    func clearSelectedCharacter() {
        selectedCharacter = nil
        selectedCharacterName = ""
        selectedCharacterSet = ""
        
        logger.debug("Cleared selected character")
    }
    
    // MARK: - Experience Management
    
    /// Get color based on experience level - cached
    func getExperienceColor() -> Color {
        // For starting level
        if experience == 0 {
            return .gray
        }
        
        // Determine cycle (1-based) and base level
        let cycle = ((experience - 1) / 43) + 1
        let baseLevel = ((experience - 1) % 43) + 1
        
        // Base colors
        let blueColor = Color(red: 0.0, green: 0.5, blue: 1.0)
        let yellowColor = Color(red: 1.0, green: 0.84, blue: 0.0)
        let orangeColor = Color(red: 1.0, green: 0.6, blue: 0.0)
        let redColor = Color(red: 1.0, green: 0.2, blue: 0.2)
        
        // In Ultra-Red mode (cycle > 1), use more intense colors
        if cycle > 1 {
            // For Ultra-Red cycles, use more vibrant colors with subtle glow effect
            switch baseLevel {
            case 1...6:
                // Ultra-Blue: more vibrant blue
                return Color(red: 0.1, green: 0.4, blue: 1.0)
            case 7...18:
                // Ultra-Yellow: more vibrant yellow/gold
                return Color(red: 1.0, green: 0.85, blue: 0.2)
            case 19...42:
                // Ultra-Orange: more vibrant orange
                return Color(red: 1.0, green: 0.5, blue: 0.0)
            case 43:
                // Ultra-Red: bright crimson red
                return Color(red: 0.85, green: 0.0, blue: 0.0)
            default:
                return .gray
            }
        } else {
            // Standard colors for first cycle
            switch baseLevel {
            case 1...6:
                return blueColor
            case 7...18:
                return yellowColor
            case 19...42:
                return orangeColor
            case 43:
                return redColor
            default:
                return .gray
            }
        }
    }
    
    /// Get level label based on experience - cached
    func getLevelLabel() -> String {
        if experience == 0 {
            return "Novice"
        }
        
        // Calculate which cycle we're in (0-based)
        let baseLevel = experience == 0 ? 0 : ((experience - 1) % 43) + 1
        
        // Determine level name based only on the base level
        switch baseLevel {
        case 1...6:
            return "Blue"
        case 7...18:
            return "Yellow"
        case 19...42:
            return "Orange"
        case 43:
            return "Red"
        default:
            return "Novice"
        }
    }
    
    /// Get the current base level (1-43)
    func getCurrentBaseLevel() -> Int {
        if experience == 0 {
            return 0
        }
        return ((experience - 1) % 43) + 1
    }
    
    /// Check if in ultra-red mode (beyond first level 43)
    func isUltraMode() -> Bool {
        return experience > 43
    }
    
    /// Calculate max orange skills based on experience (including ultra cycles)
    func getMaxOrangeSkills() -> Int {
        if experience < 19 {
            return 0
        }
        
        // Calculate ultra cycles (0-based)
        let orangeUltraCycles = ((experience - 19) / 43)
        return 1 + orangeUltraCycles // 1 is base orange skill count
    }
    
    /// Calculate max red skills based on experience (including ultra cycles)
    func getMaxRedSkills() -> Int {
        if experience < 43 {
            return 0
        }
        
        // Calculate ultra cycles (0-based)
        let redUltraCycles = ((experience - 43) / 43)
        return 1 + redUltraCycles // 1 is base red skill count
    }
    
    /// Update experience with side effects
    func updateExperience(_ newValue: Int) {
        let oldValue = experience
        experience = newValue
        
        // Track total experience gained
        if newValue > oldValue {
            totalExperienceGained += (newValue - oldValue)
        }
        
        // Handle level transitions - base level calculation is crucial
        let oldBaseLevel = oldValue == 0 ? 0 : ((oldValue - 1) % 43) + 1
        let newBaseLevel = newValue == 0 ? 0 : ((newValue - 1) % 43) + 1
        
        // When base level goes from 43 to something higher (which would wrap to 1+)
        if oldBaseLevel == 43 && newBaseLevel < oldBaseLevel && newValue > oldValue {
            // We've gone past level 43 - increment ultra count
            ultraRedCount += 1
        }
        
        logger.debug("Updated experience: \(oldValue) -> \(newValue)")
    }
    
    // MARK: - Character Skill Management
    
    /// Reset a character's skills to default state (only blue skills active)
    func resetCharacterSkills(_ character: Character) {
        guard let context = modelContext else {
            logger.error("ModelContext not available for resetCharacterSkills")
            return
        }
        
        // Keep all blue skills active
        character.activeBlueSkills = character.blueSkills
        
        // Reset orange and red skills (none active)
        character.activeOrangeSkills = []
        character.activeRedSkills = []
        
        // Save changes to the database
        do {
            try context.save()
            logger.debug("Reset skills for character: \(character.name)")
        } catch {
            logger.error("Error saving character skill reset: \(error.localizedDescription)")
        }
    }
    
    /// Reset all experience tracking
    func resetExperience() {
        experience = 0
        ultraRedCount = 0
        totalExperienceGained = 0
        
        logger.debug("Reset all experience values")
    }
    
    // MARK: - Mission Tracking
    
    /// Start tracking a new mission
    func startTrackingMission(missionID: String) {
        self.currentMissionID = missionID
        self.missionStartXP = experience
        logger.debug("Started tracking mission: \(missionID), starting XP: \(self.missionStartXP)")
    }
    
    /// Update mission notes with the gameplay information
    func updateMissionNotes(elapsedTime: TimeInterval) -> Bool {
        print("DEBUG: Updating mission notes, elapsed time: \(elapsedTime)")
        print("DEBUG: Current mission ID: \(self.currentMissionID), has context: \(modelContext != nil)")
        
        guard !self.currentMissionID.isEmpty, let context = modelContext else {
            logger.error("Cannot update mission notes: no current mission or context")
            print("DEBUG: Failed to update mission notes - missing mission ID or context")
            return false
        }
        
        // Find the mission using the UUID string
        guard let missionUUID = UUID(uuidString: self.currentMissionID) else {
            logger.error("Invalid mission UUID: \(self.currentMissionID)")
            print("DEBUG: Failed to parse UUID from: \(self.currentMissionID)")
            return false
        }
        
        print("DEBUG: Looking for mission with UUID: \(missionUUID)")
        
        do {
            // Create a predicate to find the mission
            let missionDescriptor = FetchDescriptor<Mission>(predicate: #Predicate<Mission> { mission in
                mission.id == missionUUID
            })
            
            let missions = try context.fetch(missionDescriptor)
            print("DEBUG: Found \(missions.count) missions matching UUID")
            
            guard let mission = missions.first else {
                logger.error("Mission not found: \(self.currentMissionID)")
                print("DEBUG: No mission found with UUID: \(missionUUID)")
                return false
            }
            
            print("DEBUG: Found mission: \(mission.missionName)")
            
            // Calculate time played
            let hours = Int(elapsedTime) / 3600
            let minutes = (Int(elapsedTime) % 3600) / 60
            let timeString = "\(hours) hour\(hours == 1 ? "" : "s") \(minutes) minute\(minutes == 1 ? "" : "s") played"
            print("DEBUG: Time string: \(timeString)")
            
            // Calculate XP gained during mission
            let xpGained = self.experience - self.missionStartXP
            print("DEBUG: XP gained during mission: \(xpGained) (start: \(self.missionStartXP), current: \(self.experience))")
            
            // Format the current level with Ultra information if applicable
            let baseLevel = getCurrentBaseLevel()
            let totalAP = experience // Use total AP (experience) rather than base level
            let levelName = getLevelLabel()
            
            // For display in notes, we want to add ULTRA information for levels > 43
            let displayLevelName: String
            if isUltraMode() {
                // Calculate which Ultra cycle we're in (1-based)
                let cycle = ((experience - 1) / 43) + 1
                // First Ultra cycle (cycle = 2) shows just "ULTRA"
                // Second Ultra cycle (cycle = 3) shows "ULTRA X"
                // Third Ultra cycle (cycle = 4) shows "ULTRA XX" etc.
                let xCount = max(0, cycle - 2)  // No X's for first Ultra
                let ultraSuffix = xCount > 0 ? " ULTRA " + String(repeating: "X", count: xCount) : " ULTRA"
                displayLevelName = "\(levelName)\(ultraSuffix)"
            } else {
                displayLevelName = levelName
            }
            
            print("DEBUG: Current level: \(displayLevelName) (\(totalAP) AP)")
            
            // Create or update notes - use total AP (experience) not base level
            let missionInfo = "\n\(timeString)\nLevel: \(displayLevelName) (\(totalAP) AP)"
            print("DEBUG: Mission info to add: \(missionInfo)")
            
            // Check existing notes
            if let existingNotes = mission.notes, !existingNotes.isEmpty {
                print("DEBUG: Existing notes: \(existingNotes)")
                
                // Check if the mission note already has timing information (to avoid duplications)
                if existingNotes.contains(" played\n") {
                    print("DEBUG: Notes already contain play time, updating...")
                    // Note already has timing info, likely going to update it
                    // Find the position to update
                    if let playedRange = existingNotes.range(of: " played\n") {
                        // Find the starting position of the play time info
                        // We search backwards for a newline before the "played" string
                        let searchStart = existingNotes.startIndex
                        let searchEnd = playedRange.lowerBound
                        let searchRange = searchStart..<searchEnd
                        
                        if let lastNewline = existingNotes[searchRange].lastIndex(of: "\n") {
                            // Extract the part before the timing info
                            let notesWithoutTiming = existingNotes[..<lastNewline]
                            mission.notes = String(notesWithoutTiming) + missionInfo
                            print("DEBUG: Updated existing play time info")
                        } else {
                            // Can't find where to update, append
                            mission.notes = existingNotes + missionInfo
                            print("DEBUG: Couldn't find exact play time section start, appending")
                        }
                    } else {
                        // Can't find where to update, append
                        mission.notes = existingNotes + missionInfo
                        print("DEBUG: Couldn't find play time section to update, appending")
                    }
                } else {
                    // Append to existing notes
                    mission.notes = existingNotes + missionInfo
                    print("DEBUG: Appending play time to existing notes")
                }
            } else {
                // Create new notes with just the session info - remove leading newline for new notes
                mission.notes = timeString + "\nLevel: \(displayLevelName) (\(totalAP) AP)"
                print("DEBUG: Creating new notes with play time")
            }
            
            print("DEBUG: Final notes: \(mission.notes ?? "nil")")
            
            try context.save()
            print("DEBUG: Successfully saved mission notes")
            
            // Reset mission tracking
            currentMissionID = ""
            missionStartXP = 0
            print("DEBUG: Reset mission tracking variables")
            
            logger.debug("Updated mission notes for \(missionUUID) with play time and level info")
            return true
        } catch {
            logger.error("Failed to update mission notes: \(error.localizedDescription)")
            print("DEBUG ERROR: Failed to update mission notes: \(error)")
            return false
        }
    }
}
