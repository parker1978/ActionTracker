# Troubleshooting Guide: Weapons System

**Version:** 2.0
**Last Updated:** 2025-11-19

---

## Quick Diagnostic Checklist

Before diving into specific issues, run through this checklist:

- [ ] Check Console.app for logs (filter by "ActionTracker" subsystem)
- [ ] Verify SwiftData container is configured correctly
- [ ] Confirm `WeaponImportService.importWeaponsIfNeeded()` was called
- [ ] Check that `ModelContext` is injected into views
- [ ] Verify async/await usage (no blocking calls)
- [ ] Clear derived data if build issues occur

---

## Common Issues

### 1. Weapons Not Loading

#### Symptoms
- Empty weapons list
- "No weapons found" errors
- Deck shows 0 cards

#### Diagnostic Steps
1. Check if import ran:
```swift
// In Console.app, filter for "WeaponImporter"
// Look for: "Starting initial weapons import from XML..."
```

2. Verify `weapons.xml` exists:
```swift
guard let xmlURL = Bundle.main.url(forResource: "weapons", withExtension: "xml") else {
    print("❌ weapons.xml not found in bundle")
    return
}
```

3. Check SwiftData:
```swift
let descriptor = FetchDescriptor<WeaponDefinition>()
let definitions = try context.fetch(descriptor)
print("Found \(definitions.count) weapon definitions")
```

#### Solutions

**Solution A: Force Re-Import**
```swift
// Delete WeaponDataVersion to trigger re-import
let descriptor = FetchDescriptor<WeaponDataVersion>()
if let version = try? context.fetch(descriptor).first {
    context.delete(version)
    try? context.save()
}
// Restart app
```

**Solution B: Validate XML**
- Ensure `weapons.xml` is in Copy Bundle Resources
- Check XML schema matches expected format
- Verify no XML parsing errors in logs

**Solution C: Reset SwiftData**
```swift
// Nuclear option: delete container
// WARNING: Loses all game data
try? FileManager.default.removeItem(at: containerURL)
```

---

### 2. Deck State Not Persisting

#### Symptoms
- Deck resets to full after app restart
- Discard pile disappears
- Recent draws lost

#### Diagnostic Steps
1. Check deck state exists:
```swift
let descriptor = FetchDescriptor<DeckRuntimeState>(
    predicate: #Predicate { $0.deckType == "Regular" }
)
let states = try context.fetch(descriptor)
print("Found \(states.count) deck states")
```

2. Verify session relationship:
```swift
if let state = deckStates.first {
    print("Session: \(state.session?.id)")  // Should not be nil
}
```

3. Check save calls:
```swift
// Look for "save()" calls in WeaponsDeckService
// Every operation should call try context.save()
```

#### Solutions

**Solution A: Rebuild Deck**
```swift
let deckVM = DeckViewModel(deckType: "Regular", deckService: service, context: context)
await deckVM.reset(for: session)  // Rebuilds from scratch
```

**Solution B: Check Relationships**
```swift
// Ensure DeckRuntimeState.session is set
deckState.session = session
try context.save()
```

**Solution C: Verify Context Configuration**
```swift
// In your SwiftData container setup:
let modelContainer = try ModelContainer(
    for: GameSession.self,
    DeckRuntimeState.self,
    WeaponDefinition.self,
    // ... other models
    configurations: ModelConfiguration(isStoredInMemoryOnly: false)  // Must be false!
)
```

---

### 3. Inventory Operations Failing

#### Symptoms
- "Active slots full" when they're not
- Weapons disappear when added
- Duplicate weapons in inventory

#### Diagnostic Steps
1. Check current inventory:
```swift
let activeItems = session.inventoryItems.filter { $0.slotType == "active" }
let backpackItems = session.inventoryItems.filter { $0.slotType == "backpack" }
print("Active: \(activeItems.count)/2, Backpack: \(backpackItems.count)/\(3 + session.extraInventorySlots)")
```

2. Check for orphaned items:
```swift
// Items without session relationship
let descriptor = FetchDescriptor<WeaponInventoryItem>(
    predicate: #Predicate { $0.session == nil }
)
let orphans = try context.fetch(descriptor)
print("Found \(orphans.count) orphaned items")
```

3. Review inventory events:
```swift
let events = inventoryService.getHistory(for: session)
for event in events {
    print("\(event.eventType): \(event.cardInstance?.definition?.name ?? "unknown") at \(event.timestamp)")
}
```

#### Solutions

**Solution A: Clean Orphaned Items**
```swift
let descriptor = FetchDescriptor<WeaponInventoryItem>(
    predicate: #Predicate { $0.session == nil }
)
let orphans = try context.fetch(descriptor)
for item in orphans {
    context.delete(item)
}
try context.save()
```

**Solution B: Reindex Slots**
```swift
// Ensure sequential slot indices
let activeItems = session.inventoryItems.filter { $0.slotType == "active" }
for (index, item) in activeItems.enumerated() {
    item.slotIndex = index
}
try context.save()
```

**Solution C: Force Refresh**
```swift
// Reload inventory in view model
inventoryVM.loadInventory(for: session)
```

---

### 4. Shuffle Takes Too Long

#### Symptoms
- UI freezes when shuffling
- Shuffle duration > 50ms
- Infinite loop suspected

#### Diagnostic Steps
1. Check performance logs:
```swift
// In Console.app, filter for "Performance"
// Look for: "Shuffle completed in X ms"
```

2. Profile with Instruments:
```bash
# Use Time Profiler
# Check for hot spots in shuffleDeck()
```

3. Check deck size:
```swift
print("Shuffling \(state.remainingCardIDs.count) cards")
// Should be < 100 cards typically
```

#### Solutions

**Solution A: Verify Algorithm**
```swift
// Shuffle algorithm in WeaponsDeckService is proven
// DO NOT MODIFY unless you know what you're doing
// If modified, revert to original implementation
```

**Solution B: Check For Duplicates**
```swift
// Count duplicate definitions
let instances = await getRemainingCards()
let names = instances.compactMap { $0.definition?.name }
let duplicates = Dictionary(grouping: names, by: { $0 })
    .filter { $0.value.count > 3 }  // More than 3 of same card
print("Excessive duplicates: \(duplicates)")
```

**Solution C: Optimize Lookups**
```swift
// Ensure efficient card instance lookups
// Uses Dictionary for O(1) lookup
let instanceLookup = try await getCardInstanceLookup(ids: remaining)
```

---

### 5. Deck Customization Not Working

#### Symptoms
- Preset doesn't apply to deck
- Card counts don't match customization
- Disabled cards still appear

#### Diagnostic Steps
1. Check preset exists:
```swift
let descriptor = FetchDescriptor<DeckPreset>()
let presets = try context.fetch(descriptor)
print("Found \(presets.count) presets")
```

2. Verify customizations:
```swift
if let preset = presets.first {
    print("Preset '\(preset.name)' has \(preset.customizations.count) customizations")
    for custom in preset.customizations {
        print("  - \(custom.definition?.name ?? "?"): enabled=\(custom.isEnabled), count=\(custom.customCount ?? -1)")
    }
}
```

3. Check application:
```swift
// When building deck, customization should be passed
let deckState = try await deckService.buildDeck(
    deckType: "Regular",
    session: session,
    customization: preset  // ← Should not be nil if using preset
)
```

#### Solutions

**Solution A: Rebuild with Preset**
```swift
let deckVM = DeckViewModel(...)
await deckVM.reset(for: session, preset: selectedPreset)
```

**Solution B: Verify Preset Structure**
```swift
// Each customization should have definition relationship
for custom in preset.customizations {
    guard custom.definition != nil else {
        print("❌ Customization missing definition")
        continue
    }
}
```

**Solution C: Check Default Preset**
```swift
// If no preset selected, check if default exists
let defaultPreset = presets.first { $0.isDefault }
await deckVM.loadDeck(for: session, preset: defaultPreset)
```

---

### 6. Import Validation Fails

#### Symptoms
- "Import validation failed" error
- Instance count mismatch
- Missing card instances

#### Diagnostic Steps
1. Check validation error:
```swift
// In Console.app, look for:
// "Instance count mismatch: X != Y"
```

2. Count manually:
```swift
let descriptor = FetchDescriptor<WeaponDefinition>()
let definitions = try context.fetch(descriptor)
let expectedCount = definitions.reduce(0) { $0 + $1.defaultCount }

let instanceDescriptor = FetchDescriptor<WeaponCardInstance>()
let instances = try context.fetch(instanceDescriptor)
print("Expected: \(expectedCount), Actual: \(instances.count)")
```

3. Find missing instances:
```swift
for def in definitions {
    if def.cardInstances.count != def.defaultCount {
        print("❌ \(def.name): \(def.cardInstances.count)/\(def.defaultCount)")
    }
}
```

#### Solutions

**Solution A: Force Full Re-Import**
```swift
// Delete all weapons data
let defDescriptor = FetchDescriptor<WeaponDefinition>()
let defs = try context.fetch(defDescriptor)
for def in defs {
    context.delete(def)
}

let versionDescriptor = FetchDescriptor<WeaponDataVersion>()
if let version = try context.fetch(versionDescriptor).first {
    context.delete(version)
}

try context.save()

// Restart app to trigger fresh import
```

**Solution B: Fix XML**
```xml
<!-- Ensure all weapons have count > 0 -->
<weapon name="Pistol" count="3" deck="Regular">
  <!-- count must be positive -->
</weapon>
```

**Solution C: Skip Validation (Temporary)**
```swift
// Only for debugging - not recommended for production
// Comment out validation in WeaponImportService
// try await validateImport()
```

---

### 7. Memory Issues

#### Symptoms
- App crashes with memory warnings
- Slow performance over time
- Memory footprint > 5MB additional

#### Diagnostic Steps
1. Profile with Instruments (Leaks, Allocations)
2. Check for retain cycles in view models
3. Verify cleanup in deinit

#### Solutions

**Solution A: Clear Recent Draws**
```swift
// Recent draws limited to 3, but verify
if state.recentDrawIDs.count > 3 {
    state.recentDrawIDs = Array(state.recentDrawIDs.prefix(3))
    try context.save()
}
```

**Solution B: Batch Fetch**
```swift
// Use batch fetching for large queries
let descriptor = FetchDescriptor<WeaponCardInstance>(
    sortBy: [SortDescriptor(\.copyIndex)]
)
descriptor.fetchLimit = 100  // Process in batches
```

**Solution C: Release View Models**
```swift
// Ensure view models are released when views dismissed
// Use @StateObject or @State appropriately
```

---

## Logging Best Practices

### Viewing Logs

**Console.app (macOS):**
```
1. Open Console.app
2. Select your device/simulator
3. Filter by "ActionTracker" subsystem
4. Select category:
   - WeaponImporter: Import operations
   - DeckService: Deck operations
   - InventoryService: Inventory operations
   - Performance: Timing metrics
```

**Xcode Console:**
```swift
// Logs appear in Xcode console when running
// Filter by emoji or keywords:
// 🔄 ⏳ ✅ ⚠️ ❌
```

### Adding Debug Logging

```swift
import OSLog

// Temporary debug logging
WeaponsLogger.deck.debug("Current state: \(state.remainingCardIDs.count) remaining")

// Performance measurement
let start = Date()
// ... operation ...
let duration = Date().timeIntervalSince(start)
WeaponsLogger.performance.info("Operation took \(duration)s")
```

---

## Performance Benchmarks

### Expected Performance

| Operation | Target | Typical |
|-----------|--------|---------|
| Weapon import (cold) | < 1s | ~0.5s |
| Deck shuffle | < 50ms | ~20ms |
| Deck build | < 200ms | ~100ms |
| Inventory add | < 50ms | ~10ms |
| App launch impact | < 200ms | ~100ms |

### Measuring Performance

```swift
// In Console.app, enable Performance category
// Look for timing logs:
// "Weapon import completed in 0.48s"
// "Shuffle completed in 18.3ms"
```

### Optimization Tips

1. **Use batch operations** - Save once after multiple inserts
2. **Disable autosave during import** - Re-enable after
3. **Use predicates efficiently** - Index key fields
4. **Avoid fetching in loops** - Batch fetch upfront
5. **Profile regularly** - Use Instruments

---

## When To File A Bug

File a GitHub issue if:

1. ✅ You've followed all troubleshooting steps
2. ✅ The issue is reproducible
3. ✅ You have logs/screenshots
4. ✅ Performance is outside expected range
5. ✅ Data corruption occurs

**Include in bug report:**
- Device/simulator info
- iOS version
- Steps to reproduce
- Console logs (filtered by ActionTracker)
- Screenshots/screen recordings
- Expected vs actual behavior

---

## FAQ

### Q: Can I use the weapons system offline?
**A:** Yes, all data is local SwiftData. No network required.

### Q: How do I backup/restore weapon data?
**A:** SwiftData container can be backed up via iCloud or file copy. Consider exporting presets as JSON.

### Q: Can I customize weapons without code?
**A:** Yes, use deck presets and export/import JSON for sharing.

### Q: What happens if I delete a game session?
**A:** Cascade delete removes all deck states, inventory items, and events for that session.

### Q: How do I reset everything?
**A:** Delete app and reinstall, or delete SwiftData container (loses all game data).

---

## Additional Resources

- [WeaponsSystemArchitecture.md](./WeaponsSystemArchitecture.md) - System design
- [MigrationGuide.md](./MigrationGuide.md) - Upgrading from legacy
- [GitHub Issues](https://github.com/parker1978/ActionTracker/issues) - Report bugs

---

## Contact

For questions or support:
- GitHub Issues: https://github.com/parker1978/ActionTracker/issues
- Documentation: [WeaponsSystemArchitecture.md](./WeaponsSystemArchitecture.md)
