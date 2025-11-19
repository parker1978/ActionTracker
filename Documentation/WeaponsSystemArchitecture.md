# Weapons System Architecture

**Version:** 2.0 (Phases 0-5 Complete)
**Last Updated:** 2025-11-19

---

## Overview

The weapons deck system has been completely redesigned to use SwiftData for persistence, replacing the legacy in-memory system. The new architecture provides:

- ✅ Persistent deck state across app launches
- ✅ Full audit trail of all inventory operations
- ✅ Deck customization via presets
- ✅ Session-specific temporary overrides
- ✅ Clean separation of concerns (Services → View Models → Views)
- ✅ Structured logging for production monitoring

---

## Architecture Layers

```
┌─────────────────────────────────────────────────┐
│              SwiftUI Views                      │
│  (WeaponsScreenNew, InventoryCardNew, etc.)     │
└──────────────────┬──────────────────────────────┘
                   │ @Observable
┌──────────────────▼──────────────────────────────┐
│            View Models (@Observable)            │
│  • DeckViewModel                                │
│  • InventoryViewModel                           │
│  • CustomizationViewModel                       │
└──────────────────┬──────────────────────────────┘
                   │ Async/Await
┌──────────────────▼──────────────────────────────┐
│              Services (@MainActor)              │
│  • WeaponsDeckService                           │
│  • InventoryService                             │
│  • CustomizationService                         │
│  • WeaponImportService                          │
└──────────────────┬──────────────────────────────┘
                   │ SwiftData
┌──────────────────▼──────────────────────────────┐
│         SwiftData Models (@Model)               │
│  • WeaponDefinition                             │
│  • WeaponCardInstance                           │
│  • DeckRuntimeState                             │
│  • WeaponInventoryItem                          │
│  • DeckPreset / DeckCustomization               │
│  • SessionDeckOverride                          │
└─────────────────────────────────────────────────┘
```

---

## Data Models

### Core Models

#### `WeaponDefinition`
Defines a unique weapon card type.

```swift
@Model
class WeaponDefinition {
    @Attribute(.unique) var id: String  // "Regular:Pistol:Core"
    var name: String
    var set: String  // Expansion name
    var deckType: String  // "Starting", "Regular", "Ultrared"
    var category: String  // "Melee", "Ranged", "Firearm", "Dual"
    var defaultCount: Int  // How many in default deck

    // Combat stats
    var meleeStatsJSON: Data?
    var rangedStatsJSON: Data?

    // Abilities
    var canOpenDoor: Bool
    var special: String?

    // Relationships
    var cardInstances: [WeaponCardInstance]
}
```

#### `WeaponCardInstance`
Represents a physical card copy.

```swift
@Model
class WeaponCardInstance {
    @Attribute(.unique) var id: UUID
    var copyIndex: Int  // 1, 2, 3...
    var serial: String  // "Regular:Pistol:Core:2"
    var definition: WeaponDefinition?
}
```

#### `DeckRuntimeState`
Persistent deck state per game session.

```swift
@Model
class DeckRuntimeState {
    @Attribute(.unique) var id: UUID
    var deckType: String
    var remainingCardIDs: [UUID]  // Cards still in deck
    var discardCardIDs: [UUID]    // Discard pile
    var recentDrawIDs: [UUID]     // Last 3 draws
    var lastShuffled: Date?
    var session: GameSession?
}
```

#### `WeaponInventoryItem`
Tracks weapons in player inventory.

```swift
@Model
class WeaponInventoryItem {
    @Attribute(.unique) var id: UUID
    var slotType: String  // "active" or "backpack"
    var slotIndex: Int
    var isEquipped: Bool
    var addedAt: Date
    var session: GameSession?
    var cardInstance: WeaponCardInstance?
}
```

### Customization Models

#### `DeckPreset`
Named deck configuration that can be reused.

```swift
@Model
class DeckPreset {
    @Attribute(.unique) var id: UUID
    var name: String
    var presetDescription: String
    var isDefault: Bool
    var customizations: [DeckCustomization]
}
```

#### `SessionDeckOverride`
Temporary customizations for a specific game session.

```swift
@Model
class SessionDeckOverride {
    @Attribute(.unique) var id: UUID
    var customizations: [DeckCustomization]
    // Auto-deleted when session ends
}
```

---

## Services

### WeaponImportService

**Purpose:** Import weapon definitions from XML into SwiftData.

**Key Operations:**
- `importWeaponsIfNeeded()` - Idempotent import with version checking
- `updateWeaponsIncrementally()` - Smart updates for new XML versions
- `validateImport()` - Data integrity checks

**Performance:**
- Target: <1s for ~150 weapons
- Uses batch insert with `autosaveEnabled = false`
- Validates card instance counts

### WeaponsDeckService

**Purpose:** Manage deck runtime state and operations.

**Key Operations:**
- `buildDeck()` - Create deck from definitions with customizations
- `shuffleDeck()` - Shuffle with duplicate prevention algorithm
- `draw()` / `drawTwo()` - Draw cards with auto-reshuffle
- `discard()` - Add to discard pile
- `reclaimAllDiscardIntoDeck()` - Reshuffle discard into deck

**Performance:**
- Target: <50ms for shuffle operations
- Shuffle algorithm prevents back-to-back duplicates
- Efficient UUID-based lookups

### InventoryService

**Purpose:** Manage player weapon inventory.

**Key Operations:**
- `addToActive()` / `addToBackpack()` - Add with capacity checks
- `remove()` - Remove with optional discard to deck
- `moveActiveToBackpack()` / `moveBackpackToActive()` - Move between slots
- `replaceWeapon()` - Atomic replacement flow

**Features:**
- Enforces slot limits (2 active, 3+ backpack)
- Tracks inventory history via `InventoryEvent`
- Coordinates with deck service for discard operations
- Supports "all inventory active" modifier

### CustomizationService

**Purpose:** Manage deck customization presets and overrides.

**Key Operations:**
- `createPreset()` / `deletePreset()` - CRUD for presets
- `setDefaultPreset()` - Mark default configuration
- `applyCustomizations()` - Filter and modify deck composition
- `exportPreset()` / `importPreset()` - Share configurations

**Features:**
- Per-weapon enable/disable
- Custom card counts
- Priority ordering
- Session overrides (temporary)
- Diff calculation for UI

---

## View Models

### DeckViewModel

**Purpose:** Manage deck state for SwiftUI views.

**Key Features:**
- `@Observable` for reactive UI updates
- Wraps `WeaponsDeckService`
- Computed properties: `remainingCount`, `discardCount`, `isEmpty`
- Error handling with user-friendly messages
- Async/await throughout

**Example Usage:**
```swift
let deckVM = DeckViewModel(
    deckType: "Regular",
    deckService: deckService,
    context: context
)
await deckVM.loadDeck(for: session)
if let card = await deckVM.draw() {
    // Handle drawn card
}
```

### InventoryViewModel

**Purpose:** Manage inventory state for SwiftUI views.

**Key Features:**
- `@Observable` for reactive UI updates
- Wraps `InventoryService`
- Computed properties: `canAddToActive`, `hasInventory`, `totalCount`
- Automatic refresh after operations
- Helper methods for weapon display

### CustomizationViewModel

**Purpose:** Manage preset selection and customization.

**Key Features:**
- `@Observable` for reactive UI updates
- Wraps `CustomizationService`
- Preset list management
- Session override tracking
- Import/export support

---

## Shared UI Components

### DeckSummaryHeader
Displays deck statistics (remaining, discard, color indicator).

### DeckActionButtons
Draw and shuffle buttons with flashlight mode support.

### WeaponListRow
Compact weapon display for lists.

### InventorySlotView
Inventory slot with capacity indicator.

---

## Logging

All services use structured logging via `WeaponsLogger`:

```swift
import OSLog

struct WeaponsLogger {
    static let importer = Logger(subsystem: "ActionTracker", category: "WeaponImporter")
    static let deck = Logger(subsystem: "ActionTracker", category: "DeckService")
    static let inventory = Logger(subsystem: "ActionTracker", category: "InventoryService")
    static let customization = Logger(subsystem: "ActionTracker", category: "CustomizationService")
    static let performance = Logger(subsystem: "ActionTracker", category: "Performance")
}
```

**Log Levels:**
- `.error` - Failures (via throws)
- `.notice` - Significant events (imports, adds)
- `.info` - Routine operations (shuffle, load)
- `.debug` - Detailed tracing (draw, discard)

**Performance Metrics:**
- Import duration
- Shuffle duration
- Deck build duration

---

## Data Flow Examples

### Starting a New Game

```
User taps "Start Game"
  ↓
CharacterPickerSheet creates GameSession
  ↓
WeaponsScreenNew initializes
  ↓
DeckViewModel.loadDeck()
  ↓
WeaponsDeckService.buildDeck()
  ↓
Queries WeaponDefinition from SwiftData
  ↓
Creates DeckRuntimeState
  ↓
Shuffles and saves to SwiftData
```

### Drawing a Card

```
User taps "Draw Card"
  ↓
DeckViewModel.draw()
  ↓
WeaponsDeckService.draw()
  ↓
Pops UUID from remainingCardIDs
  ↓
Queries WeaponCardInstance
  ↓
Updates recentDrawIDs
  ↓
Saves to SwiftData
  ↓
Returns card to view
```

### Adding to Inventory

```
User taps "Add to Inventory"
  ↓
InventoryViewModel.addToActive()
  ↓
InventoryService.addToActive()
  ↓
Checks capacity (2 active slots)
  ↓
Creates WeaponInventoryItem
  ↓
Removes from deck discard (if applicable)
  ↓
Records InventoryEvent
  ↓
Saves to SwiftData
  ↓
Logs operation
```

---

## Migration from Legacy System

See [MigrationGuide.md](./MigrationGuide.md) for detailed migration instructions.

**Key Changes:**
- ❌ Removed: `WeaponRepository.shared` singleton
- ❌ Removed: `WeaponsManager` in-memory state
- ❌ Removed: `DisabledCardsManager` UserDefaults
- ❌ Removed: String-based inventory fields
- ✅ Added: SwiftData models and services
- ✅ Added: View models and shared components
- ✅ Added: Structured logging

---

## Testing

### Unit Tests
- Service layer operations
- Shuffle algorithm correctness
- Capacity enforcement
- Customization application

### Integration Tests
- Full game flow (start → draw → inventory → end)
- Deck persistence across app launches
- Preset import/export
- Migration from legacy data

### Performance Tests
- Import duration < 1s
- Shuffle duration < 50ms
- Inventory operations < 50ms
- Memory footprint < 5MB additional

---

## Troubleshooting

See [TroubleshootingGuide.md](./TroubleshootingGuide.md) for common issues and solutions.

---

## Future Enhancements

### Phase 6+ Considerations

- **Multiplayer sync** - Deck state syncing
- **Undo/redo** - Leverage inventory event history
- **Analytics** - Track card draw statistics
- **Advanced customization** - Card attributes, abilities

---

## References

- [Phase 0 Implementation](../phase-0-swiftdata-models.md)
- [Phase 1 Implementation](../phase-1-importer-service.md)
- [Phase 2 Implementation](../phase-2-services-layer.md)
- [Phase 3 Implementation](../phase-3-preset-system.md)
- [Phase 4 Implementation](../phase-4-ui-integration.md)
- [Phase 5 Implementation](../phase-5-cleanup-docs.md)
- [Phase 4 Summary](../phase-4-implementation-summary.md)
