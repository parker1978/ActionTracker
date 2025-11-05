//
//  WeaponRepository.swift
//  DataLayer
//
//  Loads weapons from bundled JSON data generated from CSV at build time.
//  Ensures all players/devices use identical weapon data.
//

import Foundation
import CoreDomain

// MARK: - Weapon Repository

/// Loads and provides access to bundled weapon data
public class WeaponRepository {
    public static let shared = WeaponRepository()

    /// Version of the weapons data (for debugging and sync verification)
    public static let WEAPONS_DATA_VERSION = "1.0.0"

    public private(set) var allWeapons: [Weapon] = []

    private init() {
        loadWeapons()
    }

    // MARK: - Loading

    /// Load weapons from bundled JSON file
    private func loadWeapons() {
        guard let url = Bundle.module.url(forResource: "weapons", withExtension: "json") else {
            print("❌ Could not find weapons.json in bundle")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let weaponData = try decoder.decode([WeaponData].self, from: data)

            // Convert WeaponData to Weapon models
            allWeapons = weaponData.map { convertToWeapon($0) }

            print("✅ Loaded \(allWeapons.count) weapons (v\(Self.WEAPONS_DATA_VERSION))")
        } catch {
            print("❌ Failed to load weapons: \(error)")
        }
    }

    // MARK: - Filtering

    /// Get weapons for a specific deck type
    public func getWeapons(for deckType: DeckType) -> [Weapon] {
        allWeapons.filter { $0.deck == deckType }
    }

    /// Get weapons by expansion
    public func getWeapons(forExpansion expansion: String) -> [Weapon] {
        allWeapons.filter { $0.expansion == expansion }
    }

    /// Get all expansions
    public var expansions: [String] {
        Array(Set(allWeapons.map { $0.expansion })).sorted()
    }

    // MARK: - Conversion

    /// Convert WeaponData (from JSON) to Weapon model
    private func convertToWeapon(_ data: WeaponData) -> Weapon {
        // Parse category
        let category: WeaponCategory
        switch data.category.lowercased() {
        case "melee": category = .melee
        case "ranged": category = .ranged
        case "melee ranged": category = .meleeRanged
        default: category = .melee
        }

        // Parse deck type
        let deck: DeckType
        switch data.deck.lowercased() {
        case "starting": deck = .starting
        case "regular": deck = .regular
        case "ultrared": deck = .ultrared
        default: deck = .regular
        }

        // Parse ammo type
        let ammoType: AmmoType
        switch data.ammoType.lowercased() {
        case "bullets": ammoType = .bullets
        case "shells": ammoType = .shells
        default: ammoType = .none
        }

        // Parse booleans
        let openDoor = parseBool(data.openDoor)
        let doorNoise = parseBool(data.doorNoise)
        let killNoise = parseBool(data.killNoise)
        let dual = parseBool(data.dual)
        let overload = parseBool(data.overload)

        return Weapon(
            name: data.name,
            expansion: data.expansion,
            deck: deck,
            count: data.count ?? 1,
            category: category,
            dice: data.dice,
            accuracy: data.accuracy,
            damage: data.damage,
            rangeMin: data.rangeMin,
            rangeMax: data.rangeMax,
            range: data.range,
            ammoType: ammoType,
            openDoor: openDoor,
            doorNoise: doorNoise,
            killNoise: killNoise,
            dual: dual,
            overload: overload,
            overloadDice: data.overloadDice,
            special: data.special
        )
    }

    /// Parse boolean from string (TRUE/FALSE from CSV)
    private func parseBool(_ value: String) -> Bool {
        value.uppercased() == "TRUE"
    }
}

// MARK: - Weapon Data (JSON Decoding)

/// Intermediate struct for decoding JSON data from CSV export
public struct WeaponData: Codable {
    public let name: String
    public let expansion: String
    public let deck: String
    public let count: Int?
    public let category: String
    public let ammoType: String
    public let openDoor: String
    public let doorNoise: String
    public let killNoise: String
    public let dual: String
    public let overload: String
    public let rangeMin: Int?
    public let rangeMax: Int?
    public let range: Int?
    public let dice: Int?
    public let accuracy: String?
    public let damage: Int?
    public let overloadDice: Int?
    public let special: String

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case expansion = "Expansion"
        case deck = "Deck"
        case count = "Count"
        case category = "Category"
        case ammoType = "Ammo Type"
        case openDoor = "Open Door"
        case doorNoise = "Door Noise"
        case killNoise = "Kill Noise"
        case dual = "Dual"
        case overload = "Overload"
        case rangeMin = "Range Min"
        case rangeMax = "Range Max"
        case range = "Range"
        case dice = "Dice"
        case accuracy = "Accuracy"
        case damage = "Damage"
        case overloadDice = "Overload Dice"
        case special = "Special"
    }
}
