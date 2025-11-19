# Migration Guide: Legacy to SwiftData Weapons System

**Migration Version:** 1.0 → 2.0
**Target Completion:** Phase 5 Complete
**Last Updated:** 2025-11-19

---

## Overview

This guide covers migrating from the legacy in-memory weapons system to the new SwiftData-based architecture completed in Phases 0-5.

---

## What Changed

### Removed Components

#### 1. **WeaponRepository (Singleton)**
```swift
// ❌ OLD: Global singleton
let weapons = WeaponRepository.shared.allWeapons

// ✅ NEW: SwiftData queries
let descriptor = FetchDescriptor<WeaponDefinition>()
let definitions = try context.fetch(descriptor)
```

#### 2. **WeaponsManager (In-Memory State)**
```swift
// ❌ OLD: In-memory deck state
@State private var weaponsManager = WeaponsManager(weapons: ...)
weaponsManager.regularDeck.draw()

// ✅ NEW: Persistent deck state via view models
let deckVM = DeckViewModel(deckType: "Regular", ...)
await deckVM.loadDeck(for: session)
await deckVM.draw()
```

#### 3. **DisabledCardsManager (UserDefaults)**
```swift
// ❌ OLD: UserDefaults for card filtering
let manager = DisabledCardsManager()
manager.setCardDisabled("Pistol", in: "Core", disabled: true)

// ✅ NEW: CustomizationService with presets
let service = CustomizationService(context: context)
await service.setCustomization(for: definition, in: preset, isEnabled: false)
```

#### 4. **InventoryFormatter (String Parsing)**
```swift
// ❌ OLD: String-based inventory
let weapons = InventoryFormatter.parse(session.activeWeapons)
session.activeWeapons = InventoryFormatter.join(weapons)

// ✅ NEW: SwiftData relationships
let activeItems = session.inventoryItems.filter { $0.slotType == "active" }
```

#### 5. **String Inventory Fields**
```swift
// ❌ OLD: GameSession string fields
public var activeWeapons: String = ""
public var inactiveWeapons: String = ""

// ✅ NEW: SwiftData relationship
@Relationship(deleteRule: .cascade)
public var inventoryItems: [WeaponInventoryItem] = []
```

---

## Migration Steps

### Step 1: Data Import

The first time the app launches with the new system:

```swift
// WeaponImportService automatically runs on first launch
let importService = WeaponImportService(context: context)
try await importService.importWeaponsIfNeeded()
```

**What happens:**
1. Reads `weapons.xml` from bundle
2. Creates `WeaponDefinition` for each unique weapon
3. Creates `WeaponCardInstance` for each copy
4. Stores version info in `WeaponDataVersion`
5. Validates import integrity

**Performance:** <1s for ~150 weapons

### Step 2: Legacy Data Migration (Optional)

If you have existing game sessions with string-based inventory:

```swift
// Migration helper (if needed)
func migrateStringInventoryToSwiftData(session: GameSession) {
    // Parse legacy strings
    let activeWeapons = session.activeWeapons.split(separator: ";").map(String.init)
    let backpackWeapons = session.inactiveWeapons.split(separator: ";").map(String.init)

    // Convert to WeaponInventoryItem
    let inventoryService = InventoryService(context: context, deckService: deckService)

    for (index, weaponIdentifier) in activeWeapons.enumerated() {
        // Parse "WeaponName|ExpansionSet"
        let parts = weaponIdentifier.split(separator: "|").map(String.init)
        guard parts.count == 2 else { continue }

        // Find definition
        let descriptor = FetchDescriptor<WeaponDefinition>(
            predicate: #Predicate {
                $0.name == parts[0] && $0.set == parts[1]
            }
        )
        guard let definition = try? context.fetch(descriptor).first else { continue }

        // Find available instance
        guard let instance = definition.cardInstances.first else { continue }

        // Create inventory item
        let item = WeaponInventoryItem(
            slotType: "active",
            slotIndex: index,
            cardInstance: instance
        )
        item.session = session
        context.insert(item)
    }

    // Repeat for backpack weapons...

    // Clear legacy fields
    session.activeWeapons = ""
    session.inactiveWeapons = ""

    try? context.save()
}
```

**Note:** The legacy fields were removed in Phase 5, so this migration would need to be run BEFORE upgrading to Phase 5 if you have existing data.

### Step 3: Update View References

#### Before (Phase 0-3):
```swift
struct WeaponsScreen: View {
    @State private var weaponsManager = WeaponsManager(
        weapons: WeaponRepository.shared.allWeapons
    )

    var body: some View {
        Button("Draw") {
            if let card = weaponsManager.regularDeck.draw() {
                // Handle card
            }
        }
    }
}
```

#### After (Phase 4+):
```swift
struct WeaponsScreenNew: View {
    @State private var regularDeckVM: DeckViewModel
    @Environment(\.modelContext) private var modelContext

    init(context: ModelContext) {
        let deckService = WeaponsDeckService(context: context)
        _regularDeckVM = State(initialValue: DeckViewModel(
            deckType: "Regular",
            deckService: deckService,
            context: context
        ))
    }

    var body: some View {
        Button("Draw") {
            Task {
                if let card = await regularDeckVM.draw() {
                    // Handle card
                }
            }
        }
    }
}
```

### Step 4: Update Main App Integration

#### Before:
```swift
// ContentView.swift
@State private var weaponsManager = WeaponsManager(
    weapons: WeaponRepository.shared.allWeapons
)

WeaponsScreen(weaponsManager: weaponsManager)
ActionsScreen(weaponsManager: weaponsManager, ...)
```

#### After:
```swift
// ContentView.swift
@Environment(\.modelContext) private var modelContext

WeaponsScreenNew(context: modelContext)
ActionsScreen(spawnDeckManager: spawnDeckManager)  // No weaponsManager needed
```

---

## API Changes

### Deck Operations

| Legacy | SwiftData |
|--------|-----------|
| `weaponsManager.getDeck(.regular)` | `DeckViewModel(deckType: "Regular", ...)` |
| `deck.draw()` | `await deckVM.draw()` |
| `deck.shuffle()` | `await deckVM.shuffle()` |
| `deck.reset()` | `await deckVM.reset(for: session)` |
| `deck.discardCard(weapon)` | `await deckVM.discard(instance)` |
| `deck.remainingCount` | `deckVM.remainingCount` |
| `deck.discardCount` | `deckVM.discardCount` |

### Inventory Operations

| Legacy | SwiftData |
|--------|-----------|
| `session.activeWeapons` (String) | `session.inventoryItems` (Relationship) |
| `InventoryFormatter.parse(...)` | `inventoryVM.activeItems` |
| Manual string manipulation | `await inventoryVM.addToActive(...)` |
| No history tracking | `inventoryService.getHistory(...)` |

### Customization

| Legacy | SwiftData |
|--------|-----------|
| `DisabledCardsManager` | `CustomizationService` |
| UserDefaults keys | `DeckPreset` model |
| No export/import | `exportPreset()` / `importPreset()` |
| No session overrides | `SessionDeckOverride` model |

---

## Testing Your Migration

### 1. Fresh Install Test
```swift
// Delete app, reinstall
// Verify:
1. Weapons import successfully
2. Can create game session
3. Can draw cards
4. Can add to inventory
5. Deck state persists after app restart
```

### 2. Upgrade Test (if migrating existing data)
```swift
// Install over existing version
// Verify:
1. Existing sessions still load
2. Inventory migrates correctly
3. No data loss
4. Performance acceptable
```

### 3. Performance Test
```swift
// Measure operations:
- Weapon import: < 1s
- Deck shuffle: < 50ms
- Inventory add: < 50ms
- App launch: < 200ms additional
```

---

## Troubleshooting

### Import Issues

**Problem:** Weapons don't import on first launch

**Solutions:**
1. Check `weapons.xml` exists in bundle
2. Verify `WeaponImportService.importWeaponsIfNeeded()` is called
3. Check Console.app for `WeaponImporter` category logs
4. Validate XML schema matches expected format

### Deck State Not Persisting

**Problem:** Deck resets every app launch

**Solutions:**
1. Verify `ModelContext` is properly injected
2. Check `try context.save()` calls succeed
3. Ensure `DeckRuntimeState` has `session` relationship set
4. Check SwiftData container configuration

### Missing Inventory Items

**Problem:** Weapons disappear from inventory

**Solutions:**
1. Check cascade delete rules on relationships
2. Verify `InventoryEvent` history for operations
3. Ensure `GameSession` relationship is set
4. Check for duplicate inventory items

### Performance Issues

**Problem:** Shuffle/draw operations slow

**Solutions:**
1. Check SwiftData index configuration
2. Verify efficient predicate usage
3. Profile with Instruments
4. Check for main thread blocking

---

## Rollback Plan

If you need to rollback to the legacy system:

### Option 1: Git Revert
```bash
git revert HEAD~N  # Revert Phase 5, 4, 3, 2, 1, 0 commits
```

### Option 2: Feature Flag
```swift
// Add feature flag during transition
if FeatureFlags.useSwiftDataWeapons {
    WeaponsScreenNew(context: modelContext)
} else {
    WeaponsScreen(weaponsManager: weaponsManager)
}
```

**Note:** Phase 5 removed all legacy code, so rollback requires reverting to a pre-Phase 5 commit or maintaining parallel implementations during a transition period.

---

## Common Pitfalls

### 1. Forgetting @MainActor
```swift
// ❌ Crash: ModelContext used off main thread
Task.detached {
    try context.save()  // CRASH
}

// ✅ Correct: Use @MainActor
@MainActor
func saveContext() {
    try context.save()
}
```

### 2. Not Using Async/Await
```swift
// ❌ Blocking main thread
let card = deckService.draw(from: state)  // If this does heavy work

// ✅ Use async/await
let card = await deckVM.draw()  // Non-blocking
```

### 3. Forgetting to Load Deck
```swift
// ❌ Deck state is nil
let card = await deckVM.draw()  // nil because not loaded

// ✅ Load deck first
await deckVM.loadDeck(for: session)
let card = await deckVM.draw()  // Works
```

### 4. Direct Service Access from Views
```swift
// ❌ Tight coupling
let service = WeaponsDeckService(context: context)
let card = try await service.draw(from: state)

// ✅ Use view model
let card = await deckVM.draw()
```

---

## Best Practices

1. **Always use view models in views** - Don't access services directly
2. **Use async/await throughout** - No completion handlers
3. **Leverage @Observable** - Automatic UI updates
4. **Check capacity before adding** - Use view model helpers
5. **Log important operations** - Use `WeaponsLogger`
6. **Test thoroughly** - Unit, integration, and performance tests

---

## Support

For issues or questions:
- Check [TroubleshootingGuide.md](./TroubleshootingGuide.md)
- Review [WeaponsSystemArchitecture.md](./WeaponsSystemArchitecture.md)
- File issue at: [GitHub Issues](https://github.com/parker1978/ActionTracker/issues)

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 → 2.0 | 2025-11-19 | Complete SwiftData migration (Phases 0-5) |
| 0.9 | 2025-11-18 | Phase 4: UI Integration |
| 0.8 | 2025-11-17 | Phase 3: Preset System |
| 0.7 | 2025-11-16 | Phase 2: Services Layer |
| 0.6 | 2025-11-15 | Phase 1: Import Service |
| 0.5 | 2025-11-14 | Phase 0: SwiftData Models |
