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
public final class WeaponDefinition {
    @Attribute(.unique) public var id: String
    public var name: String
    public var set: String  // Expansion/set name
    public var deckType: String  // "Starting", "Regular", "Ultrared"
    public var category: String  // "Melee", "Ranged", "Firearm", "Dual"
    public var defaultCount: Int  // How many copies in default deck

    // Combat stats (stored as JSON for flexibility)
    @Attribute public var meleeStatsJSON: Data?
    @Attribute public var rangedStatsJSON: Data?

    // Legacy stats (for backward compatibility)
    public var dice: Int?
    public var accuracy: Int?
    public var damage: Int?
    public var rangeValue: Int?
    public var rangeMin: Int?
    public var rangeMax: Int?

    // Abilities
    public var canOpenDoor: Bool
    public var doorNoise: Bool
    public var killNoise: Bool
    public var isDual: Bool
    public var hasOverload: Bool
    public var special: String?

    // Metadata
    public var metadataVersion: String  // Track when this definition was imported
    public var lastUpdated: Date
    public var isDeprecated: Bool  // True if removed from latest XML but kept for reference integrity

    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \WeaponCardInstance.definition)
    public var cardInstances: [WeaponCardInstance] = []

    public init(name: String, set: String, deckType: String, category: String, defaultCount: Int) {
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
        self.isDeprecated = false
    }
}

// MARK: - WeaponCardInstance

@Model
public final class WeaponCardInstance {
    @Attribute(.unique) public var id: UUID
    public var copyIndex: Int  // Which copy (1, 2, 3, etc.)
    public var serial: String  // "Starting:Pistol:Core:1"

    // Relationships
    public var definition: WeaponDefinition?

    public init(definition: WeaponDefinition, copyIndex: Int) {
        self.id = UUID()
        self.definition = definition
        self.copyIndex = copyIndex
        self.serial = "\(definition.deckType):\(definition.name):\(definition.set):\(copyIndex)"
    }
}

// MARK: - WeaponInventoryItem

@Model
public final class WeaponInventoryItem {
    @Attribute(.unique) public var id: UUID
    public var slotType: String  // "active" or "backpack"
    public var slotIndex: Int
    public var isEquipped: Bool
    public var addedAt: Date

    // Relationships
    public var session: GameSession?
    public var cardInstance: WeaponCardInstance?

    public init(slotType: String, slotIndex: Int, cardInstance: WeaponCardInstance) {
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
public final class DeckCustomization {
    @Attribute(.unique) public var id: UUID
    public var isEnabled: Bool
    public var customCount: Int?  // nil = use default
    public var priority: Int  // For ordering
    public var notes: String?

    // Relationships
    public var definition: WeaponDefinition?
    public var ownerPreset: DeckPreset?  // nil = global default

    public init(definition: WeaponDefinition, isEnabled: Bool = true) {
        self.id = UUID()
        self.definition = definition
        self.isEnabled = isEnabled
        self.priority = 0
    }
}

// MARK: - DeckPreset

@Model
public final class DeckPreset {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var presetDescription: String
    public var isDefault: Bool
    public var createdAt: Date
    public var lastUsed: Date?

    // Relationships
    @Relationship(deleteRule: .cascade)
    public var customizations: [DeckCustomization] = []

    public init(name: String, description: String, isDefault: Bool = false) {
        self.id = UUID()
        self.name = name
        self.presetDescription = description
        self.isDefault = isDefault
        self.createdAt = Date()
    }
}

// MARK: - SessionDeckOverride

/// Temporary deck customizations for a specific game session
/// Automatically deleted when the session ends
@Model
public final class SessionDeckOverride {
    @Attribute(.unique) public var id: UUID
    public var createdAt: Date
    public var notes: String?  // Optional description of why overrides were applied

    // Relationships
    @Relationship(deleteRule: .cascade)
    public var customizations: [DeckCustomization] = []

    public init(notes: String? = nil) {
        self.id = UUID()
        self.createdAt = Date()
        self.notes = notes
    }
}

// MARK: - WeaponDataVersion

@Model
public final class WeaponDataVersion {
    @Attribute(.unique) public var id: String  // Singleton: always "singleton"
    public var latestImported: String
    public var lastChecked: Date

    public init(version: String) {
        self.id = "singleton"
        self.latestImported = version
        self.lastChecked = Date()
    }
}

// MARK: - DeckRuntimeState

/// Persists deck state (remaining cards, discard pile) for a specific deck type in a game session
@Model
public final class DeckRuntimeState {
    @Attribute(.unique) public var id: UUID
    public var deckType: String  // "Starting", "Regular", "Ultrared"
    public var lastShuffled: Date?
    public var lastDrawn: Date?

    // Store UUIDs of card instances for persistence
    // These reference WeaponCardInstance.id
    public var remainingCardIDs: [UUID] = []  // Cards still in deck
    public var discardCardIDs: [UUID] = []    // Cards in discard pile
    public var recentDrawIDs: [UUID] = []     // Last 3 drawn cards (for UI)

    // Relationships
    public var session: GameSession?

    public init(deckType: String) {
        self.id = UUID()
        self.deckType = deckType
    }
}

// MARK: - InventoryEvent

/// Tracks history of inventory operations for audit trail and undo capability
@Model
public final class InventoryEvent {
    @Attribute(.unique) public var id: UUID
    public var eventType: String  // "add", "remove", "move", "replace"
    public var timestamp: Date
    public var slotType: String?  // "active" or "backpack" (nil for remove)
    public var slotIndex: Int?    // Slot position
    public var fromSlotType: String?  // For move operations
    public var fromSlotIndex: Int?     // For move operations

    // Relationships
    public var session: GameSession?
    public var cardInstance: WeaponCardInstance?

    public init(eventType: String, slotType: String? = nil, slotIndex: Int? = nil) {
        self.id = UUID()
        self.eventType = eventType
        self.timestamp = Date()
        self.slotType = slotType
        self.slotIndex = slotIndex
    }
}

// MARK: - Supporting Structs for JSON Stats

public struct MeleeStatsData: Codable {
    public var range: Int
    public var dice: Int
    public var accuracy: Int
    public var damage: Int
    public var overload: Int?
    public var killNoise: Bool

    public init(range: Int, dice: Int, accuracy: Int, damage: Int, overload: Int?, killNoise: Bool) {
        self.range = range
        self.dice = dice
        self.accuracy = accuracy
        self.damage = damage
        self.overload = overload
        self.killNoise = killNoise
    }
}

public struct RangedStatsData: Codable {
    public var rangeMin: Int
    public var rangeMax: Int
    public var dice: Int
    public var accuracy: Int
    public var damage: Int
    public var overload: Int?
    public var killNoise: Bool
    public var ammoType: String?

    public init(rangeMin: Int, rangeMax: Int, dice: Int, accuracy: Int, damage: Int, overload: Int?, killNoise: Bool, ammoType: String?) {
        self.rangeMin = rangeMin
        self.rangeMax = rangeMax
        self.dice = dice
        self.accuracy = accuracy
        self.damage = damage
        self.overload = overload
        self.killNoise = killNoise
        self.ammoType = ammoType
    }
}
