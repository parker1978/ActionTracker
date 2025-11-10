//
//  WeaponModels.swift
//  CoreDomain
//
//  Weapon deck models for Zombicide 2nd Edition.
//  Supports Starting, Regular, and Ultrared decks.
//

import Foundation
import SwiftUI

// MARK: - Weapon Category

/// Type of weapon: Melee, Ranged, Dual (both), Bonus items, or Zombie cards
public enum WeaponCategory: String, Codable, CaseIterable {
    case melee = "Melee"
    case ranged = "Ranged"
    case dual = "Dual"
    case bonus = "Bonus"
    case zombie = "Zombie"

    public var displayName: String { rawValue }

    public var icon: String {
        switch self {
        case .melee: return "figure.fencing"
        case .ranged: return "figure.archery"
        case .dual: return "bolt.trianglebadge.exclamationmark"
        case .bonus: return "gift.fill"
        case .zombie: return "figure.walk"
        }
    }

    public var color: Color {
        switch self {
        case .melee: return .orange
        case .ranged: return .purple
        case .dual: return .blue
        case .bonus: return .green
        case .zombie: return .red
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

public enum DeckType: String, Codable, CaseIterable, Identifiable {
    case starting = "Starting"
    case regular = "Regular"
    case ultrared = "Ultrared"

    public var id: String { rawValue }
    public var displayName: String { rawValue }

    public var color: Color {
        switch self {
        case .starting: return .gray
        case .regular: return .blue
        case .ultrared: return .red
        }
    }
}

// MARK: - Combat Stats

/// Melee combat statistics
public struct MeleeStats: Codable, Hashable {
    public let range: Int
    public let dice: Int
    public let accuracy: Int  // 0-6, 0=100% auto-hit, displayed as "3+" unless 6
    public let damage: Int
    public let overload: Int  // 0 = no overload, >0 = overload dice bonus
    public let killNoise: Bool

    public init(range: Int, dice: Int, accuracy: Int, damage: Int, overload: Int, killNoise: Bool) {
        self.range = range
        self.dice = dice
        self.accuracy = accuracy
        self.damage = damage
        self.overload = overload
        self.killNoise = killNoise
    }

    /// Formatted accuracy display (e.g., "3+", "4+", "6", or "100%")
    public var accuracyDisplay: String {
        if accuracy == 0 {
            return "100%"
        } else if accuracy == 6 {
            return "6"
        } else {
            return "\(accuracy)+"
        }
    }

    /// Whether this accuracy is auto-hit (100%)
    public var isAutoHit: Bool {
        accuracy == 0
    }
}

/// Ranged combat statistics
public struct RangedStats: Codable, Hashable {
    public let ammoType: AmmoType
    public let rangeMin: Int
    public let rangeMax: Int
    public let dice: Int
    public let accuracy: Int  // 0-6, 0=100% auto-hit, displayed as "3+" unless 6
    public let damage: Int
    public let overload: Int  // 0 = no overload, >0 = overload dice bonus
    public let killNoise: Bool

    public init(ammoType: AmmoType, rangeMin: Int, rangeMax: Int, dice: Int, accuracy: Int, damage: Int, overload: Int, killNoise: Bool) {
        self.ammoType = ammoType
        self.rangeMin = rangeMin
        self.rangeMax = rangeMax
        self.dice = dice
        self.accuracy = accuracy
        self.damage = damage
        self.overload = overload
        self.killNoise = killNoise
    }

    /// Formatted accuracy display (e.g., "3+", "4+", "6", or "100%")
    public var accuracyDisplay: String {
        if accuracy == 0 {
            return "100%"
        } else if accuracy == 6 {
            return "6"
        } else {
            return "\(accuracy)+"
        }
    }

    /// Whether this accuracy is auto-hit (100%)
    public var isAutoHit: Bool {
        accuracy == 0
    }
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

    // New XML Format: Separate Melee/Ranged Stats
    public let meleeStats: MeleeStats?
    public let rangedStats: RangedStats?

    // Legacy Combat Stats (kept for backward compatibility during transition)
    public let dice: Int?
    public let accuracy: String?  // e.g., "3+", "4+", "5+"
    public let damage: Int?

    // Legacy Range (for ranged weapons)
    public let rangeMin: Int?
    public let rangeMax: Int?
    public let range: Int?  // For melee weapons (always 0)

    // Legacy Ammo
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
        meleeStats: MeleeStats? = nil,
        rangedStats: RangedStats? = nil,
        dice: Int? = nil,
        accuracy: String? = nil,
        damage: Int? = nil,
        rangeMin: Int? = nil,
        rangeMax: Int? = nil,
        range: Int? = nil,
        ammoType: AmmoType = .none,
        openDoor: Bool = false,
        doorNoise: Bool = false,
        killNoise: Bool = false,
        dual: Bool = false,
        overload: Bool = false,
        overloadDice: Int? = nil,
        special: String = ""
    ) {
        self.id = id
        self.name = name
        self.expansion = expansion
        self.deck = deck
        self.count = count
        self.category = category
        self.meleeStats = meleeStats
        self.rangedStats = rangedStats
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
        // Prefer new format
        if let rangedStats = rangedStats {
            let min = rangedStats.rangeMin
            let max = rangedStats.rangeMax
            return min == max ? "\(min)" : "\(min)-\(max)"
        } else if let meleeStats = meleeStats {
            return "\(meleeStats.range)"
        }

        // Fall back to legacy format
        if let range = range {
            return "\(range)"
        } else if let min = rangeMin, let max = rangeMax {
            return min == max ? "\(min)" : "\(min)-\(max)"
        }
        return "—"
    }

    /// Whether this is a bonus item (not a weapon)
    public var isBonus: Bool {
        category == .bonus
    }

    /// Whether this is a zombie card (AAAHH!!)
    public var isZombieCard: Bool {
        category == .zombie
    }

    /// Power score for difficulty weighting (higher = more powerful)
    public var powerScore: Int {
        // Use new format if available
        var diceValue = 0
        var damageValue = 0
        var accuracyValue = 0

        if let melee = meleeStats {
            diceValue = melee.dice
            damageValue = melee.damage
            accuracyValue = melee.accuracy
        } else if let ranged = rangedStats {
            diceValue = ranged.dice
            damageValue = ranged.damage
            accuracyValue = ranged.accuracy
        } else {
            // Fall back to legacy
            diceValue = dice ?? 0
            damageValue = damage ?? 0
            accuracyValue = accuracyNumeric ?? 0
        }

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
            meleeStats: meleeStats,
            rangedStats: rangedStats,
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
