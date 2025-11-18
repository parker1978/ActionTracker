//
//  WeaponImportService.swift
//  DataLayer
//
//  Phase 0: Imports weapons.xml into SwiftData
//

import SwiftData
import Foundation
import CoreDomain

@MainActor
public class WeaponImportService {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Import

    /// Imports weapons from XML into SwiftData (idempotent)
    /// Returns true if import was performed, false if already imported
    @discardableResult
    public func importWeaponsIfNeeded() async throws -> Bool {
        // Get XML version from bundled weapons
        let xmlVersion = WeaponRepository.shared.xmlVersion

        // Check if already imported
        let versionDescriptor = FetchDescriptor<WeaponDataVersion>()
        if let existing = try context.fetch(versionDescriptor).first {
            // Compare versions
            let comparison = compareVersions(xmlVersion, existing.latestImported)

            switch comparison {
            case .greater:
                print("🔄 XML version (\(xmlVersion)) is newer than imported version (\(existing.latestImported))")
                print("⏳ Starting incremental update...")
                return try await updateWeaponsIncrementally(from: existing.latestImported, to: xmlVersion)

            case .equal, .less:
                print("✅ Weapons already up to date (v\(existing.latestImported)) at \(existing.lastChecked)")
                return false
            }
        }

        print("⏳ Starting initial weapons import from XML...")
        let startTime = Date()

        // Load weapons from XML using existing WeaponRepository
        let weapons = WeaponRepository.shared.allWeapons

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
                print("⚠️ Skipping card instances for \(weapon.name) (count: \(weapon.count))")
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
        let version = WeaponDataVersion(version: WeaponRepository.WEAPONS_DATA_VERSION)
        context.insert(version)

        // Save in single transaction
        try context.save()

        let duration = Date().timeIntervalSince(startTime)
        print("✅ Imported \(definitionCount) weapons (\(instanceCount) card instances) in \(String(format: "%.2f", duration))s")

        return true
    }

    // MARK: - Incremental Update

    /// Updates existing weapon definitions from XML while preserving customizations
    /// Returns true if update was performed
    private func updateWeaponsIncrementally(from oldVersion: String, to newVersion: String) async throws -> Bool {
        let startTime = Date()

        // Load weapons from XML
        let weapons = WeaponRepository.shared.allWeapons
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
        print("✅ Incremental update complete in \(String(format: "%.2f", duration))s")
        print("   • Updated: \(updatedCount) definitions")
        print("   • Added: \(addedCount) definitions (\(addedInstanceCount) instances)")
        print("   • Deprecated: \(deprecatedCount) definitions")

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

        print("✅ Import validation passed: \(definitions.count) definitions, \(instances.count) instances")
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
