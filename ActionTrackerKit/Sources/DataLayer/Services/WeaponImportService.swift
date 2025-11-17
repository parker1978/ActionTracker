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
        // Check if already imported
        let versionDescriptor = FetchDescriptor<WeaponDataVersion>()
        if let existing = try context.fetch(versionDescriptor).first {
            print("✅ Weapons already imported (v\(existing.latestImported)) at \(existing.lastChecked)")
            return false
        }

        print("⏳ Starting weapons import from XML...")
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
