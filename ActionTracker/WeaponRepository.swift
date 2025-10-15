//
//  WeaponRepository.swift
//  ActionTracker
//
//  Loads weapons from bundled JSON data generated from CSV at build time
//  Ensures all players/devices use identical weapon data
//

import Foundation

// MARK: - Weapon Repository

/// Loads and provides access to bundled weapon data
class WeaponRepository {
    static let shared = WeaponRepository()

    /// Version of the weapons data (for debugging and sync verification)
    static let WEAPONS_DATA_VERSION = "1.0.0"

    private(set) var allWeapons: [Weapon] = []

    private init() {
        loadWeapons()
    }

    // MARK: - Loading

    /// Load weapons from bundled JSON file
    private func loadWeapons() {
        guard let url = Bundle.main.url(forResource: "weapons", withExtension: "json") else {
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
    func getWeapons(for deckType: DeckType) -> [Weapon] {
        allWeapons.filter { $0.deck == deckType }
    }

    /// Get weapons by expansion
    func getWeapons(forExpansion expansion: String) -> [Weapon] {
        allWeapons.filter { $0.expansion == expansion }
    }

    /// Get all expansions
    var expansions: [String] {
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
struct WeaponData: Codable {
    let name: String
    let expansion: String
    let deck: String
    let count: Int?
    let category: String
    let ammoType: String
    let openDoor: String
    let doorNoise: String
    let killNoise: String
    let dual: String
    let overload: String
    let rangeMin: Int?
    let rangeMax: Int?
    let range: Int?
    let dice: Int?
    let accuracy: String?
    let damage: Int?
    let overloadDice: Int?
    let special: String

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
