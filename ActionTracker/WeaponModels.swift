//
//  WeaponModels.swift
//  ActionTracker
//
//  Weapon deck models for Zombicide 2nd Edition
//  Supports Starting, Regular, and Ultrared decks with difficulty modes
//

import Foundation
import SwiftUI

// MARK: - Weapon Category

/// Type of weapon: Melee, Ranged, or both
enum WeaponCategory: String, Codable, CaseIterable {
    case melee = "Melee"
    case ranged = "Ranged"
    case meleeRanged = "Melee Ranged"

    var displayName: String { rawValue }

    var icon: String {
        switch self {
        case .melee: return "figure.fencing"
        case .ranged: return "figure.archery"
        case .meleeRanged: return "bolt.trianglebadge.exclamationmark"
        }
    }

    var color: Color {
        switch self {
        case .melee: return .orange
        case .ranged: return .purple
        case .meleeRanged: return .blue
        }
    }
}

// MARK: - Ammo Type

enum AmmoType: String, Codable {
    case bullets = "Bullets"
    case shells = "Shells"
    case none = ""

    var displayName: String {
        self == .none ? "None" : rawValue
    }
}

// MARK: - Deck Type

enum DeckType: String, Codable, CaseIterable {
    case starting = "Starting"
    case regular = "Regular"
    case ultrared = "Ultrared"

    var displayName: String { rawValue }

    var color: Color {
        switch self {
        case .starting: return .gray
        case .regular: return .blue
        case .ultrared: return .red
        }
    }
}

// MARK: - Difficulty Mode

enum DifficultyMode: String, Codable, CaseIterable {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"

    var displayName: String { rawValue }
}

// MARK: - Weapon Model

/// Represents a weapon card from the Equipment deck
struct Weapon: Identifiable, Codable, Hashable {
    let id: UUID

    // Core Properties
    let name: String
    let expansion: String
    let deck: DeckType
    let count: Int  // Number of copies in the deck
    let category: WeaponCategory

    // Combat Stats
    let dice: Int?
    let accuracy: String?  // e.g., "3+", "4+", "5+"
    let damage: Int?

    // Range (for ranged weapons)
    let rangeMin: Int?
    let rangeMax: Int?
    let range: Int?  // For melee weapons (always 0)

    // Ammo
    let ammoType: AmmoType

    // Abilities
    let openDoor: Bool
    let doorNoise: Bool
    let killNoise: Bool
    let dual: Bool  // Can be dual-wielded

    // Overload
    let overload: Bool
    let overloadDice: Int?

    // Special abilities text
    let special: String

    init(
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
    var rangeDisplay: String {
        if let range = range {
            return "\(range)"
        } else if let min = rangeMin, let max = rangeMax {
            return min == max ? "\(min)" : "\(min)-\(max)"
        }
        return "—"
    }

    /// Whether this is a bonus item (not a weapon)
    var isBonus: Bool {
        category == .melee && dice == nil && damage == nil && name.contains("Flashlight", "Water", "Bag", "Food", "Bullets", "Shells")
    }

    /// Whether this is a zombie card (AAAHH!!)
    var isZombieCard: Bool {
        name.contains("AAAHH")
    }

    /// Power score for difficulty weighting (higher = more powerful)
    var powerScore: Int {
        let diceValue = dice ?? 0
        let damageValue = damage ?? 0
        let accuracyValue = accuracyNumeric ?? 0

        // Higher dice and damage = more powerful
        // Lower accuracy needed (e.g., 3+ vs 6) = more powerful
        return (diceValue * 2) + (damageValue * 3) - accuracyValue
    }

    /// Numeric accuracy value (3+ = 3, 4+ = 4, etc.)
    var accuracyNumeric: Int? {
        guard let accuracy = accuracy else { return nil }
        let cleaned = accuracy.replacingOccurrences(of: "+", with: "")
        return Int(cleaned)
    }

    /// Create an identical weapon with a new unique identifier. Used when multiple copies of the same card exist in a deck.
    func duplicate(withID id: UUID = UUID()) -> Weapon {
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

// MARK: - String Contains Helper

extension String {
    func contains(_ strings: String...) -> Bool {
        for string in strings {
            if self.localizedCaseInsensitiveContains(string) {
                return true
            }
        }
        return false
    }
}
