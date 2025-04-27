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
}
