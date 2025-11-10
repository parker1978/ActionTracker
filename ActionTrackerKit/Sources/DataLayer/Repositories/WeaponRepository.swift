//
//  WeaponRepository.swift
//  DataLayer
//
//  Loads weapons from bundled XML data.
//  Ensures all players/devices use identical weapon data.
//

import Foundation
import CoreDomain

// MARK: - Weapon Repository

/// Loads and provides access to bundled weapon data
public class WeaponRepository {
    public static let shared = WeaponRepository()

    /// Version of the weapons data (for debugging and sync verification)
    public static let WEAPONS_DATA_VERSION = "2.2.0"

    public private(set) var allWeapons: [Weapon] = []

    private init() {
        loadWeapons()
    }

    // MARK: - Loading

    /// Load weapons from bundled XML file
    private func loadWeapons() {
        guard let url = Bundle.module.url(forResource: "weapons", withExtension: "xml") else {
            print("❌ Could not find weapons.xml in bundle")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let parser = WeaponXMLParser()
            allWeapons = parser.parse(data: data)

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

}

// MARK: - XML Parser

/// Parses weapons from XML data
class WeaponXMLParser: NSObject, XMLParserDelegate {
    private var weapons: [Weapon] = []
    private var currentElement = ""
    private var currentWeapon: WeaponBuilder?
    private var currentMeleeStats: MeleeStatsBuilder?
    private var currentRangedStats: RangedStatsBuilder?
    private var isInMeleeSection = false
    private var isInRangedSection = false

    func parse(data: Data) -> [Weapon] {
        weapons = []
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return weapons
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName

        switch elementName {
        case "Weapon":
            currentWeapon = WeaponBuilder()
        case "Melee":
            isInMeleeSection = true
            currentMeleeStats = MeleeStatsBuilder()
        case "Ranged":
            isInRangedSection = true
            currentRangedStats = RangedStatsBuilder()
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if isInMeleeSection {
            parseMeleeElement(trimmed)
        } else if isInRangedSection {
            parseRangedElement(trimmed)
        } else {
            parseWeaponElement(trimmed)
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch elementName {
        case "Weapon":
            if let weapon = currentWeapon?.build() {
                weapons.append(weapon)
            }
            currentWeapon = nil
        case "Melee":
            if let stats = currentMeleeStats?.build() {
                currentWeapon?.meleeStats = stats
            }
            currentMeleeStats = nil
            isInMeleeSection = false
        case "Ranged":
            if let stats = currentRangedStats?.build() {
                currentWeapon?.rangedStats = stats
            }
            currentRangedStats = nil
            isInRangedSection = false
        default:
            break
        }
        currentElement = ""
    }

    // MARK: - Element Parsing

    private func parseWeaponElement(_ value: String) {
        guard let weapon = currentWeapon else { return }

        switch currentElement {
        case "Name": weapon.name += value
        case "Set": weapon.expansion += value
        case "Deck": weapon.deck += value
        case "Count": weapon.count = Int(value)
        case "Category": weapon.category += value
        case "Open_Door": weapon.openDoor = parseBool(value)
        case "Door_Noise": weapon.doorNoise = parseBool(value)
        case "Dual": weapon.dual = parseBool(value)
        case "Special": weapon.special += value
        default: break
        }
    }

    private func parseMeleeElement(_ value: String) {
        guard let stats = currentMeleeStats else { return }

        switch currentElement {
        case "Range": stats.range = Int(value)
        case "Dice": stats.dice = Int(value)
        case "Accuracy": stats.accuracy = Int(value)
        case "Damage": stats.damage = Int(value)
        case "Overload": stats.overload = Int(value) ?? 0
        case "Kill_Noise": stats.killNoise = parseBool(value)
        default: break
        }
    }

    private func parseRangedElement(_ value: String) {
        guard let stats = currentRangedStats else { return }

        switch currentElement {
        case "Ammo_Type": stats.ammoType += value
        case "Range_Min": stats.rangeMin = Int(value)
        case "Range_Max": stats.rangeMax = Int(value)
        case "Dice": stats.dice = Int(value)
        case "Accuracy": stats.accuracy = Int(value)
        case "Damage": stats.damage = Int(value)
        case "Overload": stats.overload = Int(value) ?? 0
        case "Kill_Noise": stats.killNoise = parseBool(value)
        default: break
        }
    }

    private func parseBool(_ value: String) -> Bool {
        value.uppercased() == "TRUE"
    }
}

// MARK: - Builder Classes

class WeaponBuilder {
    var name: String = ""
    var expansion: String = ""
    var deck: String = ""
    var count: Int?
    var category: String = ""
    var meleeStats: MeleeStats?
    var rangedStats: RangedStats?
    var openDoor: Bool = false
    var doorNoise: Bool = false
    var dual: Bool = false
    var special: String = ""

    func build() -> Weapon? {
        guard !name.isEmpty else { return nil }

        let weaponCategory: WeaponCategory = {
            switch category {
            case "Melee": return .melee
            case "Ranged": return .ranged
            case "Dual": return .dual
            case "Bonus": return .bonus
            case "Zombie": return .zombie
            default: return .melee
            }
        }()

        let deckType: DeckType = {
            switch deck {
            case "Starting": return .starting
            case "Regular": return .regular
            case "Ultrared": return .ultrared
            default: return .regular
            }
        }()

        return Weapon(
            name: name,
            expansion: expansion,
            deck: deckType,
            count: count ?? 1,
            category: weaponCategory,
            meleeStats: meleeStats,
            rangedStats: rangedStats,
            openDoor: openDoor,
            doorNoise: doorNoise,
            killNoise: false,
            dual: dual,
            special: special
        )
    }
}

class MeleeStatsBuilder {
    var range: Int?
    var dice: Int?
    var accuracy: Int?
    var damage: Int?
    var overload: Int = 0
    var killNoise: Bool = false

    func build() -> MeleeStats? {
        guard let range = range,
              let dice = dice,
              let accuracy = accuracy,
              let damage = damage else {
            return nil
        }

        return MeleeStats(
            range: range,
            dice: dice,
            accuracy: accuracy,
            damage: damage,
            overload: overload,
            killNoise: killNoise
        )
    }
}

class RangedStatsBuilder {
    var ammoType: String = ""
    var rangeMin: Int?
    var rangeMax: Int?
    var dice: Int?
    var accuracy: Int?
    var damage: Int?
    var overload: Int = 0
    var killNoise: Bool = false

    func build() -> RangedStats? {
        guard let rangeMin = rangeMin,
              let rangeMax = rangeMax,
              let dice = dice,
              let accuracy = accuracy,
              let damage = damage else {
            return nil
        }

        let ammo: AmmoType = {
            switch ammoType {
            case "Bullets": return .bullets
            case "Shells": return .shells
            default: return .none
            }
        }()

        return RangedStats(
            ammoType: ammo,
            rangeMin: rangeMin,
            rangeMax: rangeMax,
            dice: dice,
            accuracy: accuracy,
            damage: damage,
            overload: overload,
            killNoise: killNoise
        )
    }
}
