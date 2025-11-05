//
//  GameSession.swift
//  CoreDomain
//
//  Tracks an active or completed game session for a specific character.
//  Manages XP progression, skill selection, action tracking, and game duration.
//

import Foundation
import SwiftData

/// Tracks an active or completed game session for a specific character
/// Manages XP progression, skill selection, action tracking, and game duration
@Model
public final class GameSession {
    // MARK: - Core Properties

    @Attribute(.unique) public var id: UUID
    public var characterName: String  // Denormalized for quick access
    public var startedAt: Date
    public var endedAt: Date?  // Nil while game is active
    public var currentExperience: Int
    public var currentHealth: Int  // Current health during game (0-10, starts at character's health)
    public var elapsedSeconds: Int  // Game duration in seconds

    // MARK: - Inventory
    // Weapons stored as JSON-encoded array of weapon names
    // Players self-manage inventory; no strict enforcement
    public var activeWeapons: String = ""  // 2 active slots (hands)
    public var inactiveWeapons: String = ""  // 3+ inactive slots (backpack)
    public var extraInventorySlots: Int = 0  // Bonus slots from skills/items
    public var allInventoryActive: Bool = false  // All weapons count as active

    // MARK: - Skill Selection
    // Tracks which skills the player has chosen during this session

    /// Auto-selected yellow skill (always "+1 Action" if available)
    public var selectedYellowSkill: String = ""

    /// Selected orange skills (semicolon-separated)
    /// Cycle 1: Choose 1 of 2
    /// Cycle 2: Gain the 2nd automatically
    public var selectedOrangeSkills: String = ""

    /// Selected red skills (semicolon-separated)
    /// Cycle 1: Choose 1 of 3
    /// Cycle 2: Choose 2nd of remaining 2
    /// Cycle 3: Gain the 3rd automatically
    public var selectedRedSkills: String = ""

    // MARK: - Relationships

    /// The character being played in this session
    @Relationship(inverse: \Character.gameSessions) public var character: Character?

    /// All action instances (tokens) for this session
    @Relationship(deleteRule: .cascade) public var actions: [ActionInstance] = []

    // MARK: - Initializer

    public init(
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
    public var isActive: Bool {
        endedAt == nil
    }

    /// Formatted duration string (HH:MM:SS or MM:SS)
    public var formattedDuration: String {
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
    public var totalActions: Int {
        actions.count
    }

    /// Number of actions that haven't been used yet this turn
    public var remainingActions: Int {
        actions.filter { !$0.isUsed }.count
    }

    /// Actions grouped by type for display
    /// Returns array of (type, total count, remaining count) tuples
    public var actionsByType: [(type: ActionType, total: Int, remaining: Int)] {
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
    public func useAction(ofType type: ActionType) {
        if let action = actions.first(where: { $0.type == type && !$0.isUsed }) {
            action.isUsed = true
        }
    }

    /// Add a new action token to the character's pool
    public func addAction(ofType type: ActionType) {
        let newAction = ActionInstance(type: type, isDefault: false)
        actions.append(newAction)
    }

    /// Remove a specific action token from the pool
    public func removeAction(_ action: ActionInstance) {
        if let index = actions.firstIndex(where: { $0.id == action.id }) {
            actions.remove(at: index)
        }
    }

    /// Reset all actions for the next turn (marks all as unused)
    public func resetTurn() {
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
    public var xpCycle: Int {
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
    public var normalizedXP: Int {
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
    public var displayNormalizedXP: Int {
        if currentExperience <= 43 {
            return currentExperience
        } else {
            // In cycles 2+, show 1-44 instead of 0-43
            return normalizedXP + 1
        }
    }

    /// Get current skill level based on normalized XP
    public var currentSkillLevel: SkillLevel {
        let xp = normalizedXP
        if xp <= 6 { return .blue }
        else if xp <= 18 { return .yellow }
        else if xp <= 42 { return .orange }
        else { return .red }
    }

    /// Get list of selected orange skills
    public var selectedOrangeSkillsList: [String] {
        selectedOrangeSkills.split(separator: ";").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// Get list of selected red skills
    public var selectedRedSkillsList: [String] {
        selectedRedSkills.split(separator: ";").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// Get all currently active skills based on XP and selections
    /// Skills remain active once unlocked, even across cycles
    public func getActiveSkills() -> [String] {
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
    public func needsSkillSelection() -> SkillLevel? {
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
    public func selectOrangeSkill(_ skill: String) {
        if selectedOrangeSkillsList.isEmpty {
            selectedOrangeSkills = skill
        } else {
            selectedOrangeSkills += ";" + skill
        }
    }

    /// Select a red skill (adds to selection)
    public func selectRedSkill(_ skill: String) {
        if selectedRedSkillsList.isEmpty {
            selectedRedSkills = skill
        } else {
            selectedRedSkills += ";" + skill
        }
    }
}
