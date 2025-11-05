//
//  WeaponModels.swift
//  CoreDomain
//
//  Weapon deck models for Zombicide 2nd Edition.
//  Supports Starting, Regular, and Ultrared decks with difficulty modes.
//

import Foundation
import SwiftUI

// MARK: - Weapon Category

/// Type of weapon: Melee, Ranged, or both
public enum WeaponCategory: String, Codable, CaseIterable {
    case melee = "Melee"
    case ranged = "Ranged"
    case meleeRanged = "Melee Ranged"

    public var displayName: String { rawValue }

    public var icon: String {
        switch self {
        case .melee: return "figure.fencing"
        case .ranged: return "figure.archery"
        case .meleeRanged: return "bolt.trianglebadge.exclamationmark"
        }
    }

    public var color: Color {
        switch self {
        case .melee: return .orange
        case .ranged: return .purple
        case .meleeRanged: return .blue
        }
    }
}

// MARK: - Ammo Type

public enum AmmoType: String, Codable {
    case bullets = "Bullets"
    case shells = "Shells"
    case none = ""

    public var displayName: String {
        self == .none ? "None" : rawValue
    }
}

// MARK: - Deck Type

public enum DeckType: String, Codable, CaseIterable {
    case starting = "Starting"
    case regular = "Regular"
    case ultrared = "Ultrared"

    public var displayName: String { rawValue }

    public var color: Color {
        switch self {
        case .starting: return .gray
        case .regular: return .blue
        case .ultrared: return .red
        }
    }
}

// MARK: - Difficulty Mode

public enum DifficultyMode: String, Codable, CaseIterable {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"

    public var displayName: String { rawValue }
}

// MARK: - Weapon Model

/// Represents a weapon card from the Equipment deck
public struct Weapon: Identifiable, Codable, Hashable {
    public let id: UUID

    // Core Properties
    public let name: String
    public let expansion: String
    public let deck: DeckType
    public let count: Int  // Number of copies in the deck
    public let category: WeaponCategory

    // Combat Stats
    public let dice: Int?
    public let accuracy: String?  // e.g., "3+", "4+", "5+"
    public let damage: Int?

    // Range (for ranged weapons)
    public let rangeMin: Int?
    public let rangeMax: Int?
    public let range: Int?  // For melee weapons (always 0)

    // Ammo
    public let ammoType: AmmoType

    // Abilities
    public let openDoor: Bool
    public let doorNoise: Bool
    public let killNoise: Bool
    public let dual: Bool  // Can be dual-wielded

    // Overload
    public let overload: Bool
    public let overloadDice: Int?

    // Special abilities text
    public let special: String

    public init(
        id: UUID = UUID(),
        name: String,
        expansion: String,
        deck: DeckType,
        count: Int,
        category: WeaponCategory,
        dice: Int?,
        accuracy: String?,
        damage: Int?,
        rangeMin: Int?,
        rangeMax: Int?,
        range: Int?,
        ammoType: AmmoType,
        openDoor: Bool,
        doorNoise: Bool,
        killNoise: Bool,
        dual: Bool,
        overload: Bool,
        overloadDice: Int?,
        special: String
    ) {
        self.id = id
        self.name = name
        self.expansion = expansion
        self.deck = deck
        self.count = count
        self.category = category
        self.dice = dice
        self.accuracy = accuracy
        self.damage = damage
        self.rangeMin = rangeMin
        self.rangeMax = rangeMax
        self.range = range
        self.ammoType = ammoType
        self.openDoor = openDoor
        self.doorNoise = doorNoise
        self.killNoise = killNoise
        self.dual = dual
        self.overload = overload
        self.overloadDice = overloadDice
        self.special = special
    }

    // MARK: - Computed Properties

    /// Formatted range display (e.g., "0", "0-1", "1-3")
    public var rangeDisplay: String {
        if let range = range {
            return "\(range)"
        } else if let min = rangeMin, let max = rangeMax {
            return min == max ? "\(min)" : "\(min)-\(max)"
        }
        return "—"
    }

    /// Whether this is a bonus item (not a weapon)
    public var isBonus: Bool {
        category == .melee && dice == nil && damage == nil && name.contains("Flashlight", "Water", "Bag", "Food", "Bullets", "Shells")
    }

    /// Whether this is a zombie card (AAAHH!!)
    public var isZombieCard: Bool {
        name.contains("AAAHH")
    }

    /// Power score for difficulty weighting (higher = more powerful)
    public var powerScore: Int {
        let diceValue = dice ?? 0
        let damageValue = damage ?? 0
        let accuracyValue = accuracyNumeric ?? 0

        // Higher dice and damage = more powerful
        // Lower accuracy needed (e.g., 3+ vs 6) = more powerful
        return (diceValue * 2) + (damageValue * 3) - accuracyValue
    }

    /// Numeric accuracy value (3+ = 3, 4+ = 4, etc.)
    public var accuracyNumeric: Int? {
        guard let accuracy = accuracy else { return nil }
        let cleaned = accuracy.replacingOccurrences(of: "+", with: "")
        return Int(cleaned)
    }

    /// Create an identical weapon with a new unique identifier. Used when multiple copies of the same card exist in a deck.
    public func duplicate(withID id: UUID = UUID()) -> Weapon {
        Weapon(
            id: id,
            name: name,
            expansion: expansion,
            deck: deck,
            count: count,
            category: category,
            dice: dice,
            accuracy: accuracy,
            damage: damage,
            rangeMin: rangeMin,
            rangeMax: rangeMax,
            range: range,
            ammoType: ammoType,
            openDoor: openDoor,
            doorNoise: doorNoise,
            killNoise: killNoise,
            dual: dual,
            overload: overload,
            overloadDice: overloadDice,
            special: special
        )
    }
}
