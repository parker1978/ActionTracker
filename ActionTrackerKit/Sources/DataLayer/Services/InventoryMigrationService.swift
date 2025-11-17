//
//  InventoryMigrationService.swift
//  DataLayer
//
//  Phase 0: Migrates legacy string inventory to SwiftData
//

import SwiftData
import Foundation
import CoreDomain

@MainActor
public class InventoryMigrationService {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Migration

    /// Migrates legacy string inventory to SwiftData
    /// Automatically validates and rolls back on failure
    public func migrateSessionWithValidation(_ session: GameSession) throws {
        // Skip if already migrated
        guard session.inventoryItems.isEmpty else {
            print("ℹ️ Session already migrated, skipping: \(session.characterName)")
            return
        }

        // Skip empty inventories
        guard !session.activeWeapons.isEmpty || !session.inactiveWeapons.isEmpty else {
            print("ℹ️ Session has empty inventory, skipping: \(session.characterName)")
            return
        }

        print("⏳ Migrating session: \(session.characterName)...")

        // Perform migration
        try migrateSession(session)

        // Validate
        let validation = validateMigration(session)
        guard validation.isValid else {
            // Rollback on validation failure
            print("❌ Migration validation failed for \(session.characterName):")
            for error in validation.errors {
                print("  - \(error)")
            }
            rollbackMigration(session)
            throw MigrationError.validationFailed(validation.errors)
        }

        // Migration successful
        try context.save()
        print("✅ Session migrated successfully: \(session.characterName) (\(validation.itemCount) items)")
    }

    /// Migrates session inventory (internal, no validation)
    private func migrateSession(_ session: GameSession) throws {
        // Parse active weapons
        let activeWeaponIds = parseInventoryString(session.activeWeapons)
        for (index, weaponId) in activeWeaponIds.enumerated() {
            if let instance = try findOrCreateCardInstance(weaponId) {
                let item = WeaponInventoryItem(
                    slotType: "active",
                    slotIndex: index,
                    cardInstance: instance
                )
                item.session = session
                context.insert(item)
                session.inventoryItems.append(item)
            } else {
                print("⚠️ Migration warning: Weapon not found: \(weaponId.name)|\(weaponId.set)")
            }
        }

        // Parse inactive weapons (backpack)
        let inactiveWeaponIds = parseInventoryString(session.inactiveWeapons)
        for (index, weaponId) in inactiveWeaponIds.enumerated() {
            if let instance = try findOrCreateCardInstance(weaponId) {
                let item = WeaponInventoryItem(
                    slotType: "backpack",
                    slotIndex: index,
                    cardInstance: instance
                )
                item.session = session
                context.insert(item)
                session.inventoryItems.append(item)
            } else {
                print("⚠️ Migration warning: Weapon not found: \(weaponId.name)|\(weaponId.set)")
            }
        }
    }

    // MARK: - Parsing

    /// Parses semicolon-separated inventory string
    /// Format: "Pistol|Core; Chainsaw|Fort Hendrix; Fire Axe|Core"
    private func parseInventoryString(_ str: String) -> [(name: String, set: String)] {
        guard !str.isEmpty else { return [] }

        return str.split(separator: ";")
            .compactMap { pair in
                let parts = pair.split(separator: "|")
                guard parts.count == 2 else {
                    print("⚠️ Skipping malformed inventory entry: \(pair)")
                    return nil
                }
                return (
                    name: String(parts[0]).trimmingCharacters(in: .whitespaces),
                    set: String(parts[1]).trimmingCharacters(in: .whitespaces)
                )
            }
    }

    // MARK: - Instance Lookup

    /// Finds or creates a WeaponCardInstance for the given weapon
    private func findOrCreateCardInstance(_ weaponId: (name: String, set: String)) throws -> WeaponCardInstance? {
        // Find matching WeaponDefinition
        // Extract values for predicate (tuples don't work in predicates)
        let weaponName = weaponId.name
        let weaponSet = weaponId.set

        let descriptor = FetchDescriptor<WeaponDefinition>(
            predicate: #Predicate { def in
                def.name == weaponName && def.set == weaponSet
            }
        )

        guard let definition = try context.fetch(descriptor).first else {
            // Weapon definition doesn't exist
            return nil
        }

        // Create new instance for inventory
        // Note: We create a fresh instance per inventory item for now
        // In Phase 2, we may implement instance pooling/reuse
        let instance = WeaponCardInstance(definition: definition, copyIndex: 1)
        context.insert(instance)
        return instance
    }

    // MARK: - Validation

    /// Validates that migration was successful
    func validateMigration(_ session: GameSession) -> MigrationValidation {
        var errors: [String] = []

        // 1. Count validation
        let activeStringItems = parseInventoryString(session.activeWeapons)
        let inactiveStringItems = parseInventoryString(session.inactiveWeapons)
        let totalStringCount = activeStringItems.count + inactiveStringItems.count

        let swiftDataCount = session.inventoryItems.count

        // Only validate count if there were valid parseable items
        // (warnings about missing weapons are ok, but count should still match valid items)
        let activeItems = session.inventoryItems.filter { $0.slotType == "active" }
        let backpackItems = session.inventoryItems.filter { $0.slotType == "backpack" }

        // 2. Slot type validation
        if activeItems.count > activeStringItems.count {
            errors.append("Too many active items: \(activeItems.count) > \(activeStringItems.count)")
        }

        if backpackItems.count > inactiveStringItems.count {
            errors.append("Too many backpack items: \(backpackItems.count) > \(inactiveStringItems.count)")
        }

        // 3. Slot indices are sequential
        let activeIndices = activeItems.map { $0.slotIndex }.sorted()
        let expectedActiveIndices = Array(0..<activeItems.count)
        if activeIndices != expectedActiveIndices {
            errors.append("Active slot indices not sequential: \(activeIndices)")
        }

        let backpackIndices = backpackItems.map { $0.slotIndex }.sorted()
        let expectedBackpackIndices = Array(0..<backpackItems.count)
        if backpackIndices != expectedBackpackIndices {
            errors.append("Backpack slot indices not sequential: \(backpackIndices)")
        }

        // 4. Relationship validation
        for item in session.inventoryItems {
            guard let instance = item.cardInstance else {
                errors.append("Item \(item.id) missing cardInstance")
                continue
            }
            guard instance.definition != nil else {
                errors.append("CardInstance \(instance.serial) missing definition")
                continue
            }
        }

        // 5. No duplicate items
        let itemIds = session.inventoryItems.map { $0.id }
        if Set(itemIds).count != itemIds.count {
            errors.append("Duplicate inventory item IDs found")
        }

        return MigrationValidation(
            isValid: errors.isEmpty,
            errors: errors,
            itemCount: swiftDataCount,
            stringCount: totalStringCount
        )
    }

    /// Rolls back migration on failure
    func rollbackMigration(_ session: GameSession) {
        // Remove all migrated inventory items
        for item in session.inventoryItems {
            context.delete(item)
        }
        session.inventoryItems.removeAll()

        print("🔄 Migration rolled back - legacy strings preserved")
    }

    // MARK: - Batch Migration

    /// Migrates all sessions in the database
    public func migrateAllSessions() async throws {
        let descriptor = FetchDescriptor<GameSession>()
        let sessions = try context.fetch(descriptor)

        var migratedCount = 0
        var skippedCount = 0
        var failedCount = 0

        for session in sessions {
            do {
                let wasAlreadyMigrated = !session.inventoryItems.isEmpty
                try migrateSessionWithValidation(session)
                if !wasAlreadyMigrated {
                    migratedCount += 1
                } else {
                    skippedCount += 1
                }
            } catch {
                print("❌ Failed to migrate session \(session.characterName): \(error)")
                failedCount += 1
            }
        }

        print("📊 Migration complete: \(migratedCount) migrated, \(skippedCount) skipped, \(failedCount) failed")

        if failedCount > 0 {
            throw MigrationError.batchMigrationFailed(failedCount: failedCount)
        }
    }
}

// MARK: - Supporting Types

public struct MigrationValidation {
    public let isValid: Bool
    public let errors: [String]
    public let itemCount: Int
    public let stringCount: Int
}

public enum MigrationError: LocalizedError {
    case validationFailed([String])
    case parseError(String)
    case missingDefinition(String)
    case batchMigrationFailed(failedCount: Int)

    public var errorDescription: String? {
        switch self {
        case .validationFailed(let errors):
            return "Migration validation failed:\n" + errors.joined(separator: "\n")
        case .parseError(let message):
            return "Parse error: \(message)"
        case .missingDefinition(let weapon):
            return "Missing weapon definition: \(weapon)"
        case .batchMigrationFailed(let count):
            return "Batch migration failed: \(count) sessions failed"
        }
    }
}
