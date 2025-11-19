//
//  WeaponImportService.swift
//  DataLayer
//
//  Phase 0: Imports weapons.xml into SwiftData
//

import SwiftData
import Foundation
import CoreDomain
import OSLog

@MainActor
public class WeaponImportService {
    private let context: ModelContext

    /// Version of the weapons data
    private static let WEAPONS_DATA_VERSION = "2.3.0"

    public init(context: ModelContext) {
        self.context = context
    }

    // MARK: - XML Loading

    /// Load weapons from bundled XML
    private func loadWeaponsFromXML() throws -> (weapons: [Weapon], version: String) {
        guard let url = Bundle.main.url(forResource: "weapons", withExtension: "xml") else {
            throw ImportError.noWeaponsFound
        }

        let data = try Data(contentsOf: url)
        let parser = WeaponXMLParser()
        let weapons = parser.parse(data: data)
        let version = parser.getVersion()

        return (weapons, version)
    }

    // MARK: - Import

    /// Imports weapons from XML into SwiftData (idempotent)
    /// Returns true if import was performed, false if already imported
    @discardableResult
    public func importWeaponsIfNeeded() async throws -> Bool {
        // Get XML version from bundled weapons
        let (_, xmlVersion) = try loadWeaponsFromXML()

        // Check if already imported
        let versionDescriptor = FetchDescriptor<WeaponDataVersion>()
        if let existing = try context.fetch(versionDescriptor).first {
            // Compare versions
            let comparison = compareVersions(xmlVersion, existing.latestImported)

            switch comparison {
            case .greater:
                WeaponsLogger.importer.notice("XML version (\(xmlVersion)) is newer than imported version (\(existing.latestImported))")
                WeaponsLogger.importer.info("Starting incremental weapon update...")
                let startTime = Date()
                let updated = try await updateWeaponsIncrementally(from: existing.latestImported, to: xmlVersion)
                let duration = Date().timeIntervalSince(startTime)
                WeaponsLogger.performance.info("Incremental weapon update completed in \(String(format: "%.2f", duration))s")
                return updated

            case .equal, .less:
                WeaponsLogger.importer.info("Weapons already up to date (v\(existing.latestImported)) at \(existing.lastChecked)")
                return false
            }
        }

        WeaponsLogger.importer.info("Starting initial weapons import from XML...")
        let startTime = Date()

        // Load weapons from XML
        let (weapons, _) = try loadWeaponsFromXML()

        guard !weapons.isEmpty else {
            throw ImportError.noWeaponsFound
        }

        // Disable autosave for batch insert performance
        context.autosaveEnabled = false

        var definitionCount = 0
        var instanceCount = 0

        // Create WeaponDefinition and WeaponCardInstance for each weapon
        for weapon in weapons {
            // Create WeaponDefinition
            let definition = WeaponDefinition(
                name: weapon.name,
                set: weapon.expansion,
                deckType: weapon.deck.rawValue,
                category: weapon.category.rawValue,
                defaultCount: weapon.count
            )

            // Encode new stats format as JSON
            if let meleeStats = weapon.meleeStats {
                let meleeData = MeleeStatsData(
                    range: meleeStats.range,
                    dice: meleeStats.dice,
                    accuracy: meleeStats.accuracy,
                    damage: meleeStats.damage,
                    overload: meleeStats.overload > 0 ? meleeStats.overload : nil,
                    killNoise: meleeStats.killNoise
                )
                definition.meleeStatsJSON = try? JSONEncoder().encode(meleeData)
            }

            if let rangedStats = weapon.rangedStats {
                let rangedData = RangedStatsData(
                    rangeMin: rangedStats.rangeMin,
                    rangeMax: rangedStats.rangeMax,
                    dice: rangedStats.dice,
                    accuracy: rangedStats.accuracy,
                    damage: rangedStats.damage,
                    overload: rangedStats.overload > 0 ? rangedStats.overload : nil,
                    killNoise: rangedStats.killNoise,
                    ammoType: rangedStats.ammoType.rawValue
                )
                definition.rangedStatsJSON = try? JSONEncoder().encode(rangedData)
            }

            // Legacy stats (for backward compatibility)
            definition.dice = weapon.dice
            if let accuracyStr = weapon.accuracy {
                // Convert "3+" to 3, "100%" to 0
                if accuracyStr == "100%" {
                    definition.accuracy = 0
                } else if let value = Int(accuracyStr.replacingOccurrences(of: "+", with: "")) {
                    definition.accuracy = value
                }
            }
            definition.damage = weapon.damage
            definition.rangeValue = weapon.range
            definition.rangeMin = weapon.rangeMin
            definition.rangeMax = weapon.rangeMax

            // Abilities
            definition.canOpenDoor = weapon.openDoor
            definition.doorNoise = weapon.doorNoise
            definition.killNoise = weapon.killNoise
            definition.isDual = weapon.dual
            definition.hasOverload = weapon.overload
            definition.special = weapon.special.isEmpty ? nil : weapon.special

            context.insert(definition)
            definitionCount += 1

            // Create card instances for each copy
            // Skip weapons with count <= 0 (shouldn't happen, but be defensive)
            guard weapon.count > 0 else {
                WeaponsLogger.importer.warning("Skipping card instances for \(weapon.name) (count: \(weapon.count))")
                continue
            }

            for copyIndex in 1...weapon.count {
                let instance = WeaponCardInstance(
                    definition: definition,
                    copyIndex: copyIndex
                )
                context.insert(instance)
                instanceCount += 1
            }
        }

        // Mark import as complete
        let version = WeaponDataVersion(version: Self.WEAPONS_DATA_VERSION)
        context.insert(version)

        // Save in single transaction
        try context.save()

        let duration = Date().timeIntervalSince(startTime)
        WeaponsLogger.importer.notice("Imported \(definitionCount) weapons (\(instanceCount) card instances)")
        WeaponsLogger.performance.info("Weapon import completed in \(String(format: "%.2f", duration))s")

        return true
    }

    // MARK: - Incremental Update

    /// Updates existing weapon definitions from XML while preserving customizations
    /// Returns true if update was performed
    private func updateWeaponsIncrementally(from oldVersion: String, to newVersion: String) async throws -> Bool {
        let startTime = Date()

        // Load weapons from XML
        let (weapons, _) = try loadWeaponsFromXML()
        guard !weapons.isEmpty else {
            throw ImportError.noWeaponsFound
        }

        // Fetch all existing definitions
        let definitionDescriptor = FetchDescriptor<WeaponDefinition>()
        let existingDefinitions = try context.fetch(definitionDescriptor)

        // Create lookup by deterministic ID
        var existingLookup = Dictionary(uniqueKeysWithValues: existingDefinitions.map { ($0.id, $0) })

        var updatedCount = 0
        var addedCount = 0
        var addedInstanceCount = 0

        context.autosaveEnabled = false

        // Process each weapon from XML
        for weapon in weapons {
            let deterministicID = "\(weapon.deck.rawValue):\(weapon.name):\(weapon.expansion)"

            if let existingDefinition = existingLookup[deterministicID] {
                // Update existing definition (preserve UUID and relationships)
                updateDefinition(existingDefinition, with: weapon, version: newVersion)
                updatedCount += 1

                // Remove from lookup (to track deprecated weapons later)
                existingLookup.removeValue(forKey: deterministicID)

                // Handle count changes: add/remove instances if needed
                let currentInstanceCount = existingDefinition.cardInstances.count
                let newCount = weapon.count

                if newCount > currentInstanceCount {
                    // Add more instances
                    for copyIndex in (currentInstanceCount + 1)...newCount {
                        let instance = WeaponCardInstance(
                            definition: existingDefinition,
                            copyIndex: copyIndex
                        )
                        context.insert(instance)
                        addedInstanceCount += 1
                    }
                } else if newCount < currentInstanceCount {
                    // Remove excess instances (keep first N)
                    let instancesToRemove = existingDefinition.cardInstances.suffix(currentInstanceCount - newCount)
                    for instance in instancesToRemove {
                        context.delete(instance)
                    }
                }

            } else {
                // New weapon not in database - insert as normal
                let definition = WeaponDefinition(
                    name: weapon.name,
                    set: weapon.expansion,
                    deckType: weapon.deck.rawValue,
                    category: weapon.category.rawValue,
                    defaultCount: weapon.count
                )

                updateDefinition(definition, with: weapon, version: newVersion)
                context.insert(definition)
                addedCount += 1

                // Create card instances
                for copyIndex in 1...weapon.count {
                    let instance = WeaponCardInstance(
                        definition: definition,
                        copyIndex: copyIndex
                    )
                    context.insert(instance)
                    addedInstanceCount += 1
                }
            }
        }

        // Mark remaining definitions as deprecated (not in XML anymore)
        var deprecatedCount = 0
        for (_, definition) in existingLookup {
            if !definition.isDeprecated {
                definition.isDeprecated = true
                definition.lastUpdated = Date()
                deprecatedCount += 1
            }
        }

        // Update version singleton
        let versionDescriptor = FetchDescriptor<WeaponDataVersion>()
        if let versionRecord = try context.fetch(versionDescriptor).first {
            versionRecord.latestImported = newVersion
            versionRecord.lastChecked = Date()
        }

        // Save in single transaction
        try context.save()

        let duration = Date().timeIntervalSince(startTime)
        WeaponsLogger.importer.notice("Incremental update complete: \(updatedCount) updated, \(addedCount) added (\(addedInstanceCount) instances), \(deprecatedCount) deprecated")
        WeaponsLogger.performance.info("Incremental update completed in \(String(format: "%.2f", duration))s")

        return true
    }

    /// Updates a WeaponDefinition with data from XML Weapon
    /// Preserves user customizations (handled by DeckCustomization, not touched here)
    private func updateDefinition(_ definition: WeaponDefinition, with weapon: Weapon, version: String) {
        // Update basic properties
        definition.defaultCount = weapon.count
        definition.category = weapon.category.rawValue

        // Update combat stats (JSON format)
        if let meleeStats = weapon.meleeStats {
            let meleeData = MeleeStatsData(
                range: meleeStats.range,
                dice: meleeStats.dice,
                accuracy: meleeStats.accuracy,
                damage: meleeStats.damage,
                overload: meleeStats.overload > 0 ? meleeStats.overload : nil,
                killNoise: meleeStats.killNoise
            )
            definition.meleeStatsJSON = try? JSONEncoder().encode(meleeData)
        } else {
            definition.meleeStatsJSON = nil
        }

        if let rangedStats = weapon.rangedStats {
            let rangedData = RangedStatsData(
                rangeMin: rangedStats.rangeMin,
                rangeMax: rangedStats.rangeMax,
                dice: rangedStats.dice,
                accuracy: rangedStats.accuracy,
                damage: rangedStats.damage,
                overload: rangedStats.overload > 0 ? rangedStats.overload : nil,
                killNoise: rangedStats.killNoise,
                ammoType: rangedStats.ammoType.rawValue
            )
            definition.rangedStatsJSON = try? JSONEncoder().encode(rangedData)
        } else {
            definition.rangedStatsJSON = nil
        }

        // Update legacy stats (backward compatibility)
        definition.dice = weapon.dice
        if let accuracyStr = weapon.accuracy {
            if accuracyStr == "100%" {
                definition.accuracy = 0
            } else if let value = Int(accuracyStr.replacingOccurrences(of: "+", with: "")) {
                definition.accuracy = value
            }
        }
        definition.damage = weapon.damage
        definition.rangeValue = weapon.range
        definition.rangeMin = weapon.rangeMin
        definition.rangeMax = weapon.rangeMax

        // Update abilities
        definition.canOpenDoor = weapon.openDoor
        definition.doorNoise = weapon.doorNoise
        definition.killNoise = weapon.killNoise
        definition.isDual = weapon.dual
        definition.hasOverload = weapon.overload
        definition.special = weapon.special.isEmpty ? nil : weapon.special

        // Update metadata
        definition.metadataVersion = version
        definition.lastUpdated = Date()
        definition.isDeprecated = false  // Un-deprecate if it was deprecated before
    }

    // MARK: - Validation

    /// Validates the imported data
    public func validateImport() throws {
        // Count definitions
        let definitionDescriptor = FetchDescriptor<WeaponDefinition>()
        let definitions = try context.fetch(definitionDescriptor)

        guard !definitions.isEmpty else {
            throw ImportError.validationFailed("No weapon definitions found")
        }

        // Count instances
        let instanceDescriptor = FetchDescriptor<WeaponCardInstance>()
        let instances = try context.fetch(instanceDescriptor)

        guard !instances.isEmpty else {
            throw ImportError.validationFailed("No card instances found")
        }

        // Validate relationships
        for instance in instances {
            guard instance.definition != nil else {
                throw ImportError.validationFailed("Card instance missing definition: \(instance.serial)")
            }
        }

        // Validate total count matches expected
        let expectedCount = definitions.reduce(0) { $0 + $1.defaultCount }
        guard instances.count == expectedCount else {
            throw ImportError.validationFailed("Instance count mismatch: \(instances.count) != \(expectedCount)")
        }

        WeaponsLogger.importer.info("Import validation passed: \(definitions.count) definitions, \(instances.count) instances")
    }
}

// MARK: - Errors

public enum ImportError: LocalizedError {
    case noWeaponsFound
    case validationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .noWeaponsFound:
            return "No weapons found in XML"
        case .validationFailed(let message):
            return "Import validation failed: \(message)"
        }
    }
}

// MARK: - Version Comparison

enum VersionComparison {
    case greater
    case equal
    case less
}

/// Compares two semantic version strings (e.g., "2.3.0" vs "2.2.0")
/// Returns: .greater if v1 > v2, .equal if v1 == v2, .less if v1 < v2
func compareVersions(_ v1: String, _ v2: String) -> VersionComparison {
    let components1 = v1.split(separator: ".").compactMap { Int($0) }
    let components2 = v2.split(separator: ".").compactMap { Int($0) }

    let maxCount = max(components1.count, components2.count)

    for i in 0..<maxCount {
        let num1 = i < components1.count ? components1[i] : 0
        let num2 = i < components2.count ? components2[i] : 0

        if num1 > num2 {
            return .greater
        } else if num1 < num2 {
            return .less
        }
    }

    return .equal
}

// MARK: - XML Parser

/// Parses weapons from XML data
class WeaponXMLParser: NSObject, XMLParserDelegate {
    private var weapons: [Weapon] = []
    private var xmlVersion: String = "unknown"
    private var currentElement = ""
    private var currentWeapon: WeaponBuilder?
    private var currentMeleeStats: MeleeStatsBuilder?
    private var currentRangedStats: RangedStatsBuilder?
    private var isInMeleeSection = false
    private var isInRangedSection = false

    func parse(data: Data) -> [Weapon] {
        weapons = []
        xmlVersion = "unknown"
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return weapons
    }

    /// Returns the version attribute from the XML root element
    func getVersion() -> String {
        return xmlVersion
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName

        switch elementName {
        case "Weapons":
            // Extract version attribute from root element
            if let version = attributeDict["version"] {
                xmlVersion = version
            }
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
