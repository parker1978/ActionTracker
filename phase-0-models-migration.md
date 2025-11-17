# Claude Prompt: Phase 0 - SwiftData Models & Migration

Implement Phase 0 of the weapons deck upgrade for ActionTracker. This phase creates the SwiftData schema for the weapons system and migrates existing string-based inventory data to proper relational models with comprehensive validation and rollback capabilities.

---

## Phase 0: SwiftData Models & Migration

**Duration:** 2 weeks
**Complexity:** High 🔴
**Prerequisites:** None

### Deliverables

1. ✅ SwiftData schema with 8 new models
2. ✅ Migration logic for string → SwiftData
3. ✅ Migration validation and error handling
4. ✅ Comprehensive migration tests
5. ✅ Migration safety mechanisms (validation/rollback)

### Git Commit Strategy

```bash
# Commit 1: Add SwiftData models
feat(models): add SwiftData schema for weapons system

- Add WeaponDefinition, WeaponCardInstance models
- Add DeckTemplate, DeckCustomization, DeckPreset models
- Add WeaponInventoryItem model
- Add WeaponDataVersion singleton
- Keep legacy string fields for backward compatibility
- Update SwiftData schema version

# Commit 2: Add migration logic
feat(migration): add string inventory → SwiftData migration

- Parse activeWeapons/inactiveWeapons strings
- Create WeaponInventoryItem records
- Validate migration completeness
- Add error handling and rollback on failure
- Keep legacy strings for Phase 5 removal

# Commit 3: Add migration tests
test(migration): comprehensive migration test suite

- Test empty inventory migration
- Test malformed string handling
- Test legacy format compatibility
- Test large inventory migration
- Test concurrent access scenarios
```

### Claude Implementation Prompt

```markdown
# Phase 0: Implement SwiftData Models & Migration

## Context
You are implementing Phase 0 of the weapons deck upgrade for ActionTracker, a Zombicide companion app. Currently, weapon inventory is stored as semicolon-separated strings on GameSession (e.g., "Pistol|Core; Chainsaw|Fort Hendrix"). This phase migrates to a proper SwiftData relational model with comprehensive validation.

## Current Implementation
- **GameSession.swift**: Contains `activeWeapons: String` and `inactiveWeapons: String`
- **InventoryFormatter.swift**: Parses/joins inventory strings
- **WeaponModels.swift**: Contains `Weapon` struct (in-memory only)
- **Storage**: Mix of UserDefaults (customization) and SwiftData (sessions)

## Your Task
Implement the following SwiftData models and migration logic:

### 1. Create SwiftData Models

Create new file `CoreDomain/Models/WeaponDataModels.swift`:

```swift
import SwiftData
import Foundation

@Model
final class WeaponDefinition {
    @Attribute(.unique) var id: UUID
    var name: String
    var set: String  // Expansion/set name
    var deckType: String  // "Starting", "Regular", "Ultrared"
    var category: String  // "Melee", "Ranged", "Firearm", "Dual"
    var defaultCount: Int  // How many copies in default deck

    // Combat stats (stored as JSON for flexibility)
    @Attribute var meleeStatsJSON: Data?
    @Attribute var rangedStatsJSON: Data?

    // Abilities
    var canOpenDoor: Bool
    var isDual: Bool
    var hasOverload: Bool

    // Metadata
    var metadataVersion: String  // Track when this definition was imported
    var lastUpdated: Date

    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \WeaponCardInstance.definition)
    var cardInstances: [WeaponCardInstance] = []

    init(name: String, set: String, deckType: String, category: String, defaultCount: Int) {
        self.id = UUID()
        self.name = name
        self.set = set
        self.deckType = deckType
        self.category = category
        self.defaultCount = defaultCount
        self.canOpenDoor = false
        self.isDual = false
        self.hasOverload = false
        self.metadataVersion = "2.2.0"
        self.lastUpdated = Date()
    }
}

@Model
final class WeaponCardInstance {
    @Attribute(.unique) var id: UUID
    var copyIndex: Int  // Which copy (1, 2, 3)
    var serial: String  // "Starting:Pistol:Core:1"

    // Relationships
    var definition: WeaponDefinition?

    init(definition: WeaponDefinition, copyIndex: Int) {
        self.id = UUID()
        self.definition = definition
        self.copyIndex = copyIndex
        self.serial = "\(definition.deckType):\(definition.name):\(definition.set):\(copyIndex)"
    }
}

@Model
final class WeaponInventoryItem {
    @Attribute(.unique) var id: UUID
    var slotType: String  // "active" or "backpack"
    var slotIndex: Int
    var isEquipped: Bool
    var addedAt: Date

    // Relationships
    var session: GameSession?
    var cardInstance: WeaponCardInstance?

    init(slotType: String, slotIndex: Int, cardInstance: WeaponCardInstance) {
        self.id = UUID()
        self.slotType = slotType
        self.slotIndex = slotIndex
        self.isEquipped = slotType == "active"
        self.addedAt = Date()
        self.cardInstance = cardInstance
    }
}

@Model
final class DeckCustomization {
    @Attribute(.unique) var id: UUID
    var isEnabled: Bool
    var customCount: Int?  // nil = use default
    var priority: Int  // For ordering
    var notes: String?

    // Relationships
    var definition: WeaponDefinition?
    var ownerPreset: DeckPreset?  // nil = global default

    init(definition: WeaponDefinition, isEnabled: Bool = true) {
        self.id = UUID()
        self.definition = definition
        self.isEnabled = isEnabled
        self.priority = 0
    }
}

@Model
final class DeckPreset {
    @Attribute(.unique) var id: UUID
    var name: String
    var presetDescription: String
    var isDefault: Bool
    var createdAt: Date
    var lastUsed: Date?

    // Relationships
    @Relationship(deleteRule: .cascade)
    var customizations: [DeckCustomization] = []

    init(name: String, description: String, isDefault: Bool = false) {
        self.id = UUID()
        self.name = name
        self.presetDescription = description
        self.isDefault = isDefault
        self.createdAt = Date()
    }
}

@Model
final class WeaponDataVersion {
    @Attribute(.unique) var id: UUID
    var latestImported: String
    var lastChecked: Date

    init(version: String) {
        self.id = UUID()
        self.latestImported = version
        self.lastChecked = Date()
    }
}
```

### 2. Update GameSession Model

Modify `CoreDomain/Models/GameSession.swift`:

```swift
// Add new relationships (KEEP legacy strings for now)
@Relationship(deleteRule: .cascade)
var inventoryItems: [WeaponInventoryItem] = []

// Keep these for backward compatibility
@Attribute var activeWeapons: String = ""
@Attribute var inactiveWeapons: String = ""
```

### 3. Create Migration Service

Create `DataLayer/InventoryMigrationService.swift`:

```swift
import SwiftData
import Foundation

@MainActor
class InventoryMigrationService {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// Migrates legacy string inventory to SwiftData
    func migrateSession(_ session: GameSession) throws {
        // Skip if already migrated
        guard session.inventoryItems.isEmpty else { return }

        // Parse active weapons
        let activeWeaponIds = parseInventoryString(session.activeWeapons)
        for (index, weaponId) in activeWeaponIds.enumerated() {
            if let instance = findOrCreateCardInstance(weaponId) {
                let item = WeaponInventoryItem(
                    slotType: "active",
                    slotIndex: index,
                    cardInstance: instance
                )
                item.session = session
                session.inventoryItems.append(item)
            }
        }

        // Parse inactive weapons (backpack)
        let inactiveWeaponIds = parseInventoryString(session.inactiveWeapons)
        for (index, weaponId) in inactiveWeaponIds.enumerated() {
            if let instance = findOrCreateCardInstance(weaponId) {
                let item = WeaponInventoryItem(
                    slotType: "backpack",
                    slotIndex: index,
                    cardInstance: instance
                )
                item.session = session
                session.inventoryItems.append(item)
            }
        }

        try context.save()
    }

    private func parseInventoryString(_ str: String) -> [(name: String, set: String)] {
        str.split(separator: ";")
            .compactMap { pair in
                let parts = pair.split(separator: "|")
                guard parts.count == 2 else { return nil }
                return (String(parts[0]).trimmingCharacters(in: .whitespaces),
                        String(parts[1]).trimmingCharacters(in: .whitespaces))
            }
    }

    private func findOrCreateCardInstance(_ weaponId: (name: String, set: String)) -> WeaponCardInstance? {
        // Find matching WeaponDefinition
        let descriptor = FetchDescriptor<WeaponDefinition>(
            predicate: #Predicate { def in
                def.name == weaponId.name && def.set == weaponId.set
            }
        )

        guard let definition = try? context.fetch(descriptor).first else {
            print("⚠️ Migration warning: Weapon not found: \(weaponId.name) (\(weaponId.set))")
            return nil
        }

        // Create new instance or reuse existing
        // For now, create fresh instance for inventory
        let instance = WeaponCardInstance(definition: definition, copyIndex: 1)
        context.insert(instance)
        return instance
    }
}
```

### 4. Add Migration Validation

Update `DataLayer/InventoryMigrationService.swift` with validation:

```swift
extension InventoryMigrationService {
    /// Validates that migration was successful
    func validateMigration(_ session: GameSession) -> Bool {
        // Count items in strings
        let activeStringCount = parseInventoryString(session.activeWeapons).count
        let inactiveStringCount = parseInventoryString(session.inactiveWeapons).count
        let totalStringCount = activeStringCount + inactiveStringCount

        // Count SwiftData items
        let totalSwiftDataCount = session.inventoryItems.count

        // Validate counts match
        guard totalStringCount == totalSwiftDataCount else {
            print("❌ Migration validation failed: string count (\(totalStringCount)) != SwiftData count (\(totalSwiftDataCount))")
            return false
        }

        // Validate slot type counts match
        let swiftDataActive = session.inventoryItems.filter { $0.slotType == "active" }.count
        let swiftDataBackpack = session.inventoryItems.filter { $0.slotType == "backpack" }.count

        guard activeStringCount == swiftDataActive else {
            print("❌ Migration validation failed: active count mismatch")
            return false
        }

        guard inactiveStringCount == swiftDataBackpack else {
            print("❌ Migration validation failed: backpack count mismatch")
            return false
        }

        // Validate all items have valid definitions
        for item in session.inventoryItems {
            guard item.cardInstance?.definition != nil else {
                print("❌ Migration validation failed: item missing weapon definition")
                return false
            }
        }

        print("✅ Migration validation passed: \(totalSwiftDataCount) items migrated successfully")
        return true
    }

    /// Rolls back migration on failure
    func rollbackMigration(_ session: GameSession) {
        // Remove all migrated inventory items
        session.inventoryItems.forEach { context.delete($0) }
        session.inventoryItems.removeAll()

        print("🔄 Migration rolled back - legacy strings preserved")
    }

    /// Complete migration with validation
    func migrateSessionWithValidation(_ session: GameSession) throws {
        // Skip if already migrated
        guard session.inventoryItems.isEmpty else {
            print("ℹ️ Session already migrated, skipping")
            return
        }

        // Perform migration
        try migrateSession(session)

        // Validate
        guard validateMigration(session) else {
            // Rollback on validation failure
            rollbackMigration(session)
            throw MigrationError.validationFailed
        }

        // Migration successful, keep legacy strings for Phase 5 removal
        print("✅ Session migrated successfully")
    }
}

enum MigrationError: Error {
    case validationFailed
    case parseError
    case missingDefinition
}
```

### 5. Add Tests

Create `Tests/MigrationTests.swift`:

```swift
import XCTest
import SwiftData
@testable import ActionTracker

final class InventoryMigrationTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!
    var migrationService: InventoryMigrationService!

    override func setUp() async throws {
        // Setup in-memory container for testing
        let schema = Schema([GameSession.self, WeaponDefinition.self, /* ... */])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: config)
        context = ModelContext(container)
        migrationService = InventoryMigrationService(context: context)

        // Add test weapon definitions
        // ...
    }

    func testEmptyInventoryMigration() throws {
        let session = GameSession()
        session.activeWeapons = ""
        session.inactiveWeapons = ""

        try migrationService.migrateSession(session)

        XCTAssertTrue(session.inventoryItems.isEmpty)
    }

    func testBasicInventoryMigration() throws {
        let session = GameSession()
        session.activeWeapons = "Pistol|Core; Chainsaw|Fort Hendrix"
        session.inactiveWeapons = "Fire Axe|Core"

        try migrationService.migrateSession(session)

        XCTAssertEqual(session.inventoryItems.count, 3)
        XCTAssertEqual(session.inventoryItems.filter { $0.slotType == "active" }.count, 2)
        XCTAssertEqual(session.inventoryItems.filter { $0.slotType == "backpack" }.count, 1)
    }

    func testMalformedStringHandling() throws {
        let session = GameSession()
        session.activeWeapons = "Pistol|Core; InvalidFormat; Chainsaw"

        // Should not crash, should skip invalid entries
        XCTAssertNoThrow(try migrationService.migrateSession(session))
    }

    // Add more tests...
}
```

## Success Criteria

✅ All SwiftData models compile and integrate with schema
✅ Migration service successfully converts string → SwiftData
✅ Migration validation catches all errors
✅ All migration tests pass
✅ No crashes with malformed data
✅ Rollback works correctly on validation failure

## Testing Checklist

- [ ] Test with empty inventory
- [ ] Test with single weapon
- [ ] Test with full inventory (2 active + 5 backpack)
- [ ] Test with malformed strings
- [ ] Test with legacy format (no "|" separator)
- [ ] Test with non-existent weapon references
- [ ] Verify migration validation detects mismatches
- [ ] Verify rollback on validation failure
- [ ] Verify SwiftData relationships work correctly

## Notes

- **Do NOT remove legacy string fields yet** - keep for Phase 5
- Migration happens once per session on first access with new system
- Use background context for bulk migrations if performance issues
- Log all migration warnings and validation results
- Legacy strings remain as read-only backup until Phase 5

## Questions to Resolve

1. Should we create one CardInstance per inventory item, or reuse instances?
2. How to handle weapons that no longer exist in current XML?
3. Should migration happen automatically on launch or on-demand when accessing weapons?
```

### Success Criteria

- ✅ All 6 SwiftData models created and integrated
- ✅ GameSession updated with inventory relationship
- ✅ Migration service handles all edge cases
- ✅ Migration validation detects all errors
- ✅ Rollback mechanism works correctly
- ✅ 10+ migration tests passing
- ✅ No performance regressions on launch

### Testing Requirements

**Unit Tests:**
- [ ] Empty inventory migration
- [ ] Single weapon migration
- [ ] Full inventory migration (2 active + 5 backpack)
- [ ] Malformed string handling
- [ ] Legacy format compatibility
- [ ] Non-existent weapon references
- [ ] Migration validation detects mismatches
- [ ] Rollback on validation failure
- [ ] Concurrent migration safety

**Integration Tests:**
- [ ] End-to-end session creation → add inventory → migrate
- [ ] Migration validation with real data
- [ ] SwiftData relationship integrity

**Performance Tests:**
- [ ] Migration of 50+ sessions
- [ ] Large inventory (10+ weapons per session)
