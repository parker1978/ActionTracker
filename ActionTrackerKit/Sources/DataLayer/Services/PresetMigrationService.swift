//
//  PresetMigrationService.swift
//  DataLayer
//
//  Migrates UserDefaults-based deck customizations to SwiftData presets
//

import Foundation
import SwiftData
import CoreDomain

/// Service for migrating legacy UserDefaults deck customizations to SwiftData presets
@MainActor
public class PresetMigrationService {
    private let context: ModelContext
    private let customizationService: CustomizationService

    // UserDefaults keys (legacy)
    private let selectedExpansionsKey = "selectedExpansions"
    private let disabledCardsBySetKey = "disabledCardsBySet"
    private let migrationCompletedKey = "presetMigrationCompleted_v1"

    public init(context: ModelContext) {
        self.context = context
        self.customizationService = CustomizationService(context: context)
    }

    /// Check if migration has already been completed
    public func isMigrationCompleted() -> Bool {
        UserDefaults.standard.bool(forKey: migrationCompletedKey)
    }

    /// Perform one-time migration from UserDefaults to SwiftData
    /// Creates a "Default" preset with current user customizations
    public func migrateIfNeeded() async throws {
        // Skip if already migrated
        guard !isMigrationCompleted() else {
            print("✅ Preset migration already completed, skipping")
            return
        }

        print("🔄 Starting preset migration from UserDefaults to SwiftData...")

        // Read legacy UserDefaults
        let selectedExpansions = UserDefaults.standard.array(forKey: selectedExpansionsKey) as? [String] ?? []
        let disabledCardsBySet = UserDefaults.standard.dictionary(forKey: disabledCardsBySetKey) as? [String: [String]] ?? [:]

        // Check if there are any customizations to migrate
        let hasCustomizations = !selectedExpansions.isEmpty || !disabledCardsBySet.isEmpty

        if !hasCustomizations {
            print("ℹ️ No legacy customizations found, skipping migration")
            markMigrationCompleted()
            return
        }

        // Create "Default" preset
        print("📦 Creating 'Default' preset from legacy settings...")
        let defaultPreset = try await customizationService.createPreset(
            name: "Default",
            description: "Migrated from previous settings",
            isDefault: true,
            basedOn: nil
        )

        // Fetch all weapon definitions
        let weaponDescriptor = FetchDescriptor<WeaponDefinition>()
        let allWeapons = try context.fetch(weaponDescriptor)

        print("🔍 Found \(allWeapons.count) weapon definitions")

        // Build customizations based on legacy settings
        var customizationCount = 0

        for weapon in allWeapons {
            // Determine if weapon should be enabled based on expansion selection
            let isExpansionSelected = selectedExpansions.isEmpty || selectedExpansions.contains(weapon.set)

            // Check if specifically disabled in DisabledCardsManager
            let isSpecificallyDisabled = disabledCardsBySet[weapon.set]?.contains(weapon.name) ?? false

            // Final enabled state
            let isEnabled = isExpansionSelected && !isSpecificallyDisabled

            // Only create customization if it differs from default (disabled)
            if !isEnabled {
                try await customizationService.setCustomization(
                    for: weapon,
                    in: defaultPreset,
                    isEnabled: false
                )
                customizationCount += 1
            }
        }

        print("✅ Created \(customizationCount) customizations in 'Default' preset")

        // Mark migration as completed
        markMigrationCompleted()

        // Optional: Clear legacy UserDefaults (commented out for safety)
        // You may want to keep these for a version or two as backup
        // UserDefaults.standard.removeObject(forKey: selectedExpansionsKey)
        // UserDefaults.standard.removeObject(forKey: disabledCardsBySetKey)

        print("✅ Preset migration completed successfully")
    }

    /// Force re-migration (useful for testing)
    public func resetMigration() {
        UserDefaults.standard.removeObject(forKey: migrationCompletedKey)
        print("⚠️ Migration flag reset - will run on next app launch")
    }

    private func markMigrationCompleted() {
        UserDefaults.standard.set(true, forKey: migrationCompletedKey)
        print("✅ Migration marked as completed")
    }

    /// Get migration info for debugging
    public func getMigrationInfo() -> MigrationInfo {
        let selectedExpansions = UserDefaults.standard.array(forKey: selectedExpansionsKey) as? [String] ?? []
        let disabledCardsBySet = UserDefaults.standard.dictionary(forKey: disabledCardsBySetKey) as? [String: [String]] ?? [:]
        let isCompleted = isMigrationCompleted()

        return MigrationInfo(
            isCompleted: isCompleted,
            selectedExpansions: selectedExpansions,
            disabledCardsBySet: disabledCardsBySet
        )
    }

    public struct MigrationInfo {
        public let isCompleted: Bool
        public let selectedExpansions: [String]
        public let disabledCardsBySet: [String: [String]]

        public var hasLegacyData: Bool {
            !selectedExpansions.isEmpty || !disabledCardsBySet.isEmpty
        }

        public var disabledCardCount: Int {
            disabledCardsBySet.values.flatMap { $0 }.count
        }
    }
}
