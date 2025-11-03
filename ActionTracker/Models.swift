//
//  Models.swift
//  ZombiTrack
//
//  Created by Stephen Parker on 6/6/25.
//
//  This file contains all SwiftData models for the ZombiTrack app, including:
//  - ActionType: Enum for different types of actions in Zombicide
//  - SkillLevel: Enum for XP-based skill tiers
//  - Character: Player character with skills across 4 tiers
//  - Skill: Reusable skill definitions with descriptions
//  - GameSession: Active game tracking with XP, actions, and skill progression
//  - ActionInstance: Individual action tokens used during gameplay
//

import Foundation
import SwiftData

// MARK: - Action Type Enum

/// Types of actions available in Zombicide gameplay
/// Each type has a unique icon, color, and display name
enum ActionType: String, Codable, CaseIterable {
    case action  // Generic action (default)
    case combat  // Combined melee/ranged attack
    case melee   // Close-range attack
    case ranged  // Long-range attack
    case move    // Movement between zones
    case search  // Search for equipment

    /// User-friendly display name for the action type
    var displayName: String {
        switch self {
        case .action: return "Action"
        case .combat: return "Combat"
        case .melee: return "Melee"
        case .ranged: return "Ranged"
        case .move: return "Move"
        case .search: return "Search"
        }
    }

    /// SF Symbol icon name for the action type
    var icon: String {
        switch self {
        case .action: return "bolt.fill"
        case .combat: return "flame.fill"
        case .melee: return "hammer.fill"
        case .ranged: return "scope"
        case .move: return "figure.walk"
        case .search: return "magnifyingglass"
        }
    }
}

// MARK: - Action Type SwiftUI Extension

import SwiftUI

extension ActionType {
    /// Color associated with each action type for UI consistency
    var color: Color {
        switch self {
        case .action: return .blue
        case .combat: return .red
        case .melee: return .orange
        case .ranged: return .purple
        case .move: return .green
        case .search: return .yellow
        }
    }
}

// MARK: - Skill Level Enum

/// Four skill tiers in Zombicide based on experience points
/// Characters unlock higher tiers as they gain XP within each cycle
enum SkillLevel: String, Codable, CaseIterable {
    case blue    // Starting tier (0-6 XP)
    case yellow  // Second tier (7-18 XP)
    case orange  // Third tier (19-42 XP)
    case red     // Final tier (43+ XP)

    /// User-friendly display name (capitalized color)
    var displayName: String {
        rawValue.capitalized
    }

    /// XP range for this skill level within a single cycle
    var xpRange: ClosedRange<Int> {
        switch self {
        case .blue: return 0...6
        case .yellow: return 7...18
        case .orange: return 19...42
        case .red: return 43...Int.max
        }
    }
}

// MARK: - Character Model

/// Represents a playable character in Zombicide
/// Can be either built-in (from expansions) or user-created
@Model
final class Character {
    // MARK: - Core Properties

    @Attribute(.unique) var id: UUID
    var name: String
    var set: String  // Expansion set name (e.g., "Supernatural", "Fort Hendrix")
    var notes: String
    var isFavorite: Bool
    var isBuiltIn: Bool  // True for preloaded characters, false for user-created
    var teen: Bool  // True if character is a teen survivor
    var health: Int  // Starting health value for the character
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Skill Properties
    // Skills are stored as semicolon-separated strings for SwiftData compatibility
    // Blue skills are always active from the start
    var blueSkills: String

    // Yellow skills unlock at XP 7+ and grant +1 Action
    var yellowSkills: String

    // Orange skills unlock at XP 19+ (choose 1 in cycle 1, gain 2nd in cycle 2)
    var orangeSkills: String

    // Red skills unlock at XP 43+ (choose 1 in cycle 1, 2nd in cycle 2, gain 3rd in cycle 3)
    var redSkills: String

    // MARK: - Relationships

    /// All game sessions using this character (past and present)
    @Relationship(deleteRule: .cascade) var gameSessions: [GameSession] = []

    // MARK: - Initializer

    init(
        id: UUID = UUID(),
        name: String,
        set: String = "",
        notes: String = "",
        isFavorite: Bool = false,
        isBuiltIn: Bool = false,
        teen: Bool = false,
        health: Int = 3,
        blueSkills: String = "",
        yellowSkills: String = "",
        orangeSkills: String = "",
        redSkills: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.set = set
        self.notes = notes
        self.isFavorite = isFavorite
        self.isBuiltIn = isBuiltIn
        self.teen = teen
        self.health = health
        self.blueSkills = blueSkills
        self.yellowSkills = yellowSkills
        self.orangeSkills = orangeSkills
        self.redSkills = redSkills
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Computed Properties

    /// Blue skills parsed into an array
    var blueSkillsList: [String] {
        blueSkills.split(separator: ";").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// Yellow skills parsed into an array (usually just 1 skill: "+1 Action")
    var yellowSkillsList: [String] {
        yellowSkills.split(separator: ";").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// Orange skills parsed into an array (usually 2 options, choose 1 initially)
    var orangeSkillsList: [String] {
        orangeSkills.split(separator: ";").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// Red skills parsed into an array (usually 3 options, unlock progressively)
    var redSkillsList: [String] {
        redSkills.split(separator: ";").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// All skills combined across all tiers
    var allSkillsList: [String] {
        blueSkillsList + yellowSkillsList + orangeSkillsList + redSkillsList
    }
}

// MARK: - Skill Model

/// Reusable skill definition with name and description
/// Used for displaying skill details in character views
@Model
final class Skill {
    @Attribute(.unique) var id: UUID
    var name: String
    var skillDescription: String
    var isBuiltIn: Bool  // True for preloaded skills

    init(id: UUID = UUID(), name: String, skillDescription: String, isBuiltIn: Bool = false) {
        self.id = id
        self.name = name
        self.skillDescription = skillDescription
        self.isBuiltIn = isBuiltIn
    }
}

// MARK: - Game Session Model

/// Tracks an active or completed game session for a specific character
/// Manages XP progression, skill selection, action tracking, and game duration
@Model
final class GameSession {
    // MARK: - Core Properties

    @Attribute(.unique) var id: UUID
    var characterName: String  // Denormalized for quick access
    var startedAt: Date
    var endedAt: Date?  // Nil while game is active
    var currentExperience: Int
    var currentHealth: Int  // Current health during game (0-10, starts at character's health)
    var elapsedSeconds: Int  // Game duration in seconds

    // MARK: - Inventory
    // Weapons stored as JSON-encoded array of weapon names
    // Players self-manage inventory; no strict enforcement
    var activeWeapons: String = ""  // 2 active slots (hands)
    var inactiveWeapons: String = ""  // 3+ inactive slots (backpack)
    var extraInventorySlots: Int = 0  // Bonus slots from skills/items
    var allInventoryActive: Bool = false  // All weapons count as active

    // MARK: - Skill Selection
    // Tracks which skills the player has chosen during this session

    /// Auto-selected yellow skill (always "+1 Action" if available)
    var selectedYellowSkill: String = ""

    /// Selected orange skills (semicolon-separated)
    /// Cycle 1: Choose 1 of 2
    /// Cycle 2: Gain the 2nd automatically
    var selectedOrangeSkills: String = ""

    /// Selected red skills (semicolon-separated)
    /// Cycle 1: Choose 1 of 3
    /// Cycle 2: Choose 2nd of remaining 2
    /// Cycle 3: Gain the 3rd automatically
    var selectedRedSkills: String = ""

    // MARK: - Relationships

    /// The character being played in this session
    @Relationship(inverse: \Character.gameSessions) var character: Character?

    /// All action instances (tokens) for this session
    @Relationship(deleteRule: .cascade) var actions: [ActionInstance] = []

    // MARK: - Initializer

    init(
        id: UUID = UUID(),
        character: Character,
        currentExperience: Int = 0,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        elapsedSeconds: Int = 0
    ) {
        self.id = id
        self.character = character
        self.characterName = character.name
        self.currentExperience = currentExperience
        self.currentHealth = character.health  // Start with character's base health
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.elapsedSeconds = elapsedSeconds

        // Create initial 3 default actions
        self.actions = [
            ActionInstance(type: .action, isDefault: true),
            ActionInstance(type: .action, isDefault: true),
            ActionInstance(type: .action, isDefault: true)
        ]

        // Auto-select yellow skill if exists (always "+1 Action")
        if !character.yellowSkillsList.isEmpty {
            self.selectedYellowSkill = character.yellowSkillsList.first ?? ""
        }
    }

    // MARK: - Session Status

    /// Returns true if the game session is still active (not ended)
    var isActive: Bool {
        endedAt == nil
    }

    /// Formatted duration string (HH:MM:SS or MM:SS)
    var formattedDuration: String {
        let hours = elapsedSeconds / 3600
        let minutes = (elapsedSeconds % 3600) / 60
        let seconds = elapsedSeconds % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    // MARK: - Action Management

    /// Total number of action tokens available this turn
    var totalActions: Int {
        actions.count
    }

    /// Number of actions that haven't been used yet this turn
    var remainingActions: Int {
        actions.filter { !$0.isUsed }.count
    }

    /// Actions grouped by type for display
    /// Returns array of (type, total count, remaining count) tuples
    var actionsByType: [(type: ActionType, total: Int, remaining: Int)] {
        let types = ActionType.allCases
        return types.compactMap { type in
            let typeActions = actions.filter { $0.type == type }
            guard !typeActions.isEmpty else { return nil }
            let remaining = typeActions.filter { !$0.isUsed }.count
            return (type: type, total: typeActions.count, remaining: remaining)
        }
    }

    /// Mark an action of a specific type as used
    /// Uses the first available unused action of that type
    func useAction(ofType type: ActionType) {
        if let action = actions.first(where: { $0.type == type && !$0.isUsed }) {
            action.isUsed = true
        }
    }

    /// Add a new action token to the character's pool
    func addAction(ofType type: ActionType) {
        let newAction = ActionInstance(type: type, isDefault: false)
        actions.append(newAction)
    }

    /// Remove a specific action token from the pool
    func removeAction(_ action: ActionInstance) {
        if let index = actions.firstIndex(where: { $0.id == action.id }) {
            actions.remove(at: index)
        }
    }

    /// Reset all actions for the next turn (marks all as unused)
    func resetTurn() {
        for action in actions {
            action.isUsed = false
        }
    }

    // MARK: - Experience & Skill Management

    /// Get the current XP cycle (1, 2, or 3)
    /// Each cycle is 44 XP points (0-43)
    /// Cycle 1: XP 0-43
    /// Cycle 2: XP 44-87
    /// Cycle 3: XP 88+
    var xpCycle: Int {
        if currentExperience <= 43 {
            return 1
        } else if currentExperience <= 87 {
            return 2
        } else {
            return 3
        }
    }

    /// Get normalized XP within current cycle (maps to 0-43 for threshold checks)
    /// Used internally for skill unlock logic
    var normalizedXP: Int {
        if currentExperience <= 43 {
            return currentExperience
        } else if currentExperience <= 87 {
            // Cycle 2: XP 44-87 maps to 0-43
            return currentExperience - 44
        } else {
            // Cycle 3: XP 88+ maps to 0-43+
            return currentExperience - 88
        }
    }

    /// Get display XP for showing user (starts at 1 in cycles 2+, not 0)
    /// This matches player expectations for cycle positioning
    var displayNormalizedXP: Int {
        if currentExperience <= 43 {
            return currentExperience
        } else {
            // In cycles 2+, show 1-44 instead of 0-43
            return normalizedXP + 1
        }
    }

    /// Get current skill level based on normalized XP
    var currentSkillLevel: SkillLevel {
        let xp = normalizedXP
        if xp <= 6 { return .blue }
        else if xp <= 18 { return .yellow }
        else if xp <= 42 { return .orange }
        else { return .red }
    }

    /// Get list of selected orange skills
    var selectedOrangeSkillsList: [String] {
        selectedOrangeSkills.split(separator: ";").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// Get list of selected red skills
    var selectedRedSkillsList: [String] {
        selectedRedSkills.split(separator: ";").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// Get all currently active skills based on XP and selections
    /// Skills remain active once unlocked, even across cycles
    func getActiveSkills() -> [String] {
        guard let character = character else { return [] }

        var skills: [String] = []

        // Blue skill is always active from the start
        skills.append(contentsOf: character.blueSkillsList)

        // Yellow skill activates at XP 7+ and stays active forever
        if currentExperience >= 7 && !selectedYellowSkill.isEmpty {
            skills.append(selectedYellowSkill)
        }

        // Orange skills stay active once selected
        if !selectedOrangeSkillsList.isEmpty {
            skills.append(contentsOf: selectedOrangeSkillsList)
        }

        // Red skills stay active once selected
        if !selectedRedSkillsList.isEmpty {
            skills.append(contentsOf: selectedRedSkillsList)
        }

        return skills
    }

    /// Check if player needs to select skills at current XP level
    /// Returns the skill level that needs selection, or nil if none
    func needsSkillSelection() -> SkillLevel? {
        guard let character = character else { return nil }

        let cycle = xpCycle

        // Use normalized XP for threshold checks
        let checkXP = cycle == 1 ? currentExperience : normalizedXP

        // Yellow: Auto-selected, never needs manual selection

        // Orange: Need selection at XP 19 in each cycle
        // Cycle 1: Choose 1 of 2
        // Cycle 2: Auto-gain the 2nd
        let orangeThreshold = cycle == 1 ? 19 : 18
        if checkXP >= orangeThreshold {
            let availableOrange = character.orangeSkillsList
            let selectedCount = selectedOrangeSkillsList.count

            // Cycle 1: Choose 1 of 2
            if cycle == 1 && selectedCount < 1 && availableOrange.count >= 2 {
                return .orange
            }
            // Cycle 2: Automatically get the remaining one
            if cycle == 2 && selectedCount < 2 && availableOrange.count >= 2 {
                let remaining = availableOrange.filter { !selectedOrangeSkillsList.contains($0) }
                if let remainingSkill = remaining.first {
                    selectOrangeSkill(remainingSkill)
                }
            }
        }

        // Red: Need selection at XP 43 in each cycle
        // Cycle 1: Choose 1 of 3
        // Cycle 2: Choose 2nd of remaining 2
        // Cycle 3: Auto-gain the 3rd
        let redThreshold = cycle == 1 ? 43 : 42
        if checkXP >= redThreshold {
            let availableRed = character.redSkillsList
            let selectedCount = selectedRedSkillsList.count

            // Cycle 1: Choose 1 of 3
            if cycle == 1 && selectedCount < 1 && availableRed.count >= 3 {
                return .red
            }
            // Cycle 2: Choose 2nd of remaining 2
            if cycle == 2 && selectedCount < 2 && availableRed.count >= 3 {
                return .red
            }
            // Cycle 3: Automatically get last one
            if cycle == 3 && selectedCount < 3 && availableRed.count >= 3 {
                let remaining = availableRed.filter { !selectedRedSkillsList.contains($0) }
                if let remainingSkill = remaining.first {
                    selectRedSkill(remainingSkill)
                }
            }
        }

        return nil
    }

    /// Select an orange skill (adds to selection)
    func selectOrangeSkill(_ skill: String) {
        if selectedOrangeSkillsList.isEmpty {
            selectedOrangeSkills = skill
        } else {
            selectedOrangeSkills += ";" + skill
        }
    }

    /// Select a red skill (adds to selection)
    func selectRedSkill(_ skill: String) {
        if selectedRedSkillsList.isEmpty {
            selectedRedSkills = skill
        } else {
            selectedRedSkills += ";" + skill
        }
    }
}

// MARK: - Inventory Helpers

enum InventoryFormatter {
    private static let separators = CharacterSet(charactersIn: ",;")

    /// Convert a persisted inventory string into an array of weapon names.
    static func parse(_ inventory: String) -> [String] {
        inventory
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// Convert an array of weapon names into the canonical persisted format.
    static func join(_ weapons: [String]) -> String {
        weapons.joined(separator: "; ")
    }
}

// MARK: - Action Instance Model

/// Represents a single action token during gameplay
/// Can be used/unused and marked as default (cannot be deleted)
@Model
final class ActionInstance {
    @Attribute(.unique) var id: UUID
    var type: ActionType  // Type of action (action, combat, melee, etc.)
    var isDefault: Bool   // True for the initial 3 actions (cannot be deleted)
    var isUsed: Bool      // True when action has been spent this turn

    /// Reference back to the game session
    @Relationship(inverse: \GameSession.actions) var session: GameSession?

    init(id: UUID = UUID(), type: ActionType, isDefault: Bool = false, isUsed: Bool = false) {
        self.id = id
        self.type = type
        self.isDefault = isDefault
        self.isUsed = isUsed
    }
}
