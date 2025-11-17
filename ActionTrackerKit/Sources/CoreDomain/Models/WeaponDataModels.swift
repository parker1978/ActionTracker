//
//  WeaponDataModels.swift
//  ActionTracker
//
//  Phase 0: SwiftData models for weapons system
//

import SwiftData
import Foundation

// MARK: - WeaponDefinition

@Model
final class WeaponDefinition {
    @Attribute(.unique) var id: String
    var name: String
    var set: String  // Expansion/set name
    var deckType: String  // "Starting", "Regular", "Ultrared"
    var category: String  // "Melee", "Ranged", "Firearm", "Dual"
    var defaultCount: Int  // How many copies in default deck

    // Combat stats (stored as JSON for flexibility)
    @Attribute var meleeStatsJSON: Data?
    @Attribute var rangedStatsJSON: Data?

    // Legacy stats (for backward compatibility)
    var dice: Int?
    var accuracy: Int?
    var damage: Int?
    var rangeValue: Int?
    var rangeMin: Int?
    var rangeMax: Int?

    // Abilities
    var canOpenDoor: Bool
    var doorNoise: Bool
    var killNoise: Bool
    var isDual: Bool
    var hasOverload: Bool
    var special: String?

    // Metadata
    var metadataVersion: String  // Track when this definition was imported
    var lastUpdated: Date

    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \WeaponCardInstance.definition)
    var cardInstances: [WeaponCardInstance] = []

    init(name: String, set: String, deckType: String, category: String, defaultCount: Int) {
        // Deterministic ID for stable relationships
        self.id = "\(deckType):\(name):\(set)"
        self.name = name
        self.set = set
        self.deckType = deckType
        self.category = category
        self.defaultCount = defaultCount
        self.canOpenDoor = false
        self.doorNoise = false
        self.killNoise = false
        self.isDual = false
        self.hasOverload = false
        self.metadataVersion = "2.2.0"
        self.lastUpdated = Date()
    }
}

// MARK: - WeaponCardInstance

@Model
final class WeaponCardInstance {
    @Attribute(.unique) var id: UUID
    var copyIndex: Int  // Which copy (1, 2, 3, etc.)
    var serial: String  // "Starting:Pistol:Core:1"

    // Relationships
    var definition: WeaponDefinition?

    init(definition: WeaponDefinition, copyIndex: Int) {
        self.id = UUID()
        self.definition = definition
        self.copyIndex = copyIndex
        self.serial = "\(definition.deckType):\(definition.name):\(definition.set):\(copyIndex)"
    }
}

// MARK: - WeaponInventoryItem

@Model
final class WeaponInventoryItem {
    @Attribute(.unique) var id: UUID
    var slotType: String  // "active" or "backpack"
    var slotIndex: Int
    var isEquipped: Bool
    var addedAt: Date

    // Relationships
    var session: GameSession?
    var cardInstance: WeaponCardInstance?

    init(slotType: String, slotIndex: Int, cardInstance: WeaponCardInstance) {
        self.id = UUID()
        self.slotType = slotType
        self.slotIndex = slotIndex
        self.isEquipped = slotType == "active"
        self.addedAt = Date()
        self.cardInstance = cardInstance
    }
}

// MARK: - DeckCustomization

@Model
final class DeckCustomization {
    @Attribute(.unique) var id: UUID
    var isEnabled: Bool
    var customCount: Int?  // nil = use default
    var priority: Int  // For ordering
    var notes: String?

    // Relationships
    var definition: WeaponDefinition?
    var ownerPreset: DeckPreset?  // nil = global default

    init(definition: WeaponDefinition, isEnabled: Bool = true) {
        self.id = UUID()
        self.definition = definition
        self.isEnabled = isEnabled
        self.priority = 0
    }
}

// MARK: - DeckPreset

@Model
final class DeckPreset {
    @Attribute(.unique) var id: UUID
    var name: String
    var presetDescription: String
    var isDefault: Bool
    var createdAt: Date
    var lastUsed: Date?

    // Relationships
    @Relationship(deleteRule: .cascade)
    var customizations: [DeckCustomization] = []

    init(name: String, description: String, isDefault: Bool = false) {
        self.id = UUID()
        self.name = name
        self.presetDescription = description
        self.isDefault = isDefault
        self.createdAt = Date()
    }
}

// MARK: - WeaponDataVersion

@Model
final class WeaponDataVersion {
    @Attribute(.unique) var id: String  // Singleton: always "singleton"
    var latestImported: String
    var lastChecked: Date

    init(version: String) {
        self.id = "singleton"
        self.latestImported = version
        self.lastChecked = Date()
    }
}

// MARK: - Supporting Structs for JSON Stats

struct MeleeStatsData: Codable {
    var range: Int
    var dice: Int
    var accuracy: Int
    var damage: Int
    var overload: Int?
    var killNoise: Bool
}

struct RangedStatsData: Codable {
    var rangeMin: Int
    var rangeMax: Int
    var dice: Int
    var accuracy: Int
    var damage: Int
    var overload: Int?
    var killNoise: Bool
    var ammoType: String?
}
