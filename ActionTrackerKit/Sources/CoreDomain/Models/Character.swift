//
//  Character.swift
//  CoreDomain
//
//  Represents a playable character in Zombicide.
//  Can be either built-in (from expansions) or user-created.
//

import Foundation
import SwiftData

/// Represents a playable character in Zombicide
/// Can be either built-in (from expansions) or user-created
@Model
public final class Character {
    // MARK: - Core Properties

    @Attribute(.unique) public var id: UUID
    public var name: String
    public var set: String  // Expansion set name (e.g., "Supernatural", "Fort Hendrix")
    public var notes: String
    public var isFavorite: Bool
    public var isBuiltIn: Bool  // True for preloaded characters, false for user-created
    public var teen: Bool  // True if character is a teen survivor
    public var health: Int  // Starting health value for the character
    public var createdAt: Date
    public var updatedAt: Date

    // MARK: - Skill Properties
    // Skills are stored as semicolon-separated strings for SwiftData compatibility
    // Blue skills are always active from the start
    public var blueSkills: String

    // Yellow skills unlock at XP 7+ and grant +1 Action
    public var yellowSkills: String

    // Orange skills unlock at XP 19+ (choose 1 in cycle 1, gain 2nd in cycle 2)
    public var orangeSkills: String

    // Red skills unlock at XP 43+ (choose 1 in cycle 1, 2nd in cycle 2, gain 3rd in cycle 3)
    public var redSkills: String

    // MARK: - Relationships

    /// All game sessions using this character (past and present)
    @Relationship(deleteRule: .cascade) public var gameSessions: [GameSession] = []

    // MARK: - Initializer

    public init(
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
    public var blueSkillsList: [String] {
        blueSkills.split(separator: ";").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// Yellow skills parsed into an array (usually just 1 skill: "+1 Action")
    public var yellowSkillsList: [String] {
        yellowSkills.split(separator: ";").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// Orange skills parsed into an array (usually 2 options, choose 1 initially)
    public var orangeSkillsList: [String] {
        orangeSkills.split(separator: ";").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// Red skills parsed into an array (usually 3 options, unlock progressively)
    public var redSkillsList: [String] {
        redSkills.split(separator: ";").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// All skills combined across all tiers
    public var allSkillsList: [String] {
        blueSkillsList + yellowSkillsList + orangeSkillsList + redSkillsList
    }
}
