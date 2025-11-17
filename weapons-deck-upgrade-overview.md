# Weapons Deck Upgrade Assessment & Implementation Guide

**Date:** 2025-11-13
**Project:** ActionTracker
**Current Version:** 21.0.0 (build 8)

---

## Executive Summary

This document assesses the feasibility and effort required to implement the comprehensive weapons deck upgrade specification. The upgrade represents a **major architectural refactor** that will modernize the weapons system, eliminate technical debt, and provide powerful deck customization features.

**Bottom Line:**
- **Total Effort:** 8-10 weeks
- **Risk Level:** Medium-High (data migration risks)
- **Recommendation:** Proceed with phased approach and recommended modifications
- **ROI:** High - addresses significant technical debt and enables future features

---

## Table of Contents

1. [Current State Analysis](#current-state-analysis)
2. [Effort Assessment](#effort-assessment)
3. [Risk Analysis](#risk-analysis)
4. [Key Recommendations](#key-recommendations)
5. [Phased Implementation Plan](#phased-implementation-plan)
6. [Testing Strategy](#testing-strategy)
7. [Success Metrics](#success-metrics)

---

## Current State Analysis

### Architecture Overview

**Current Codebase Metrics:**
- Total weapon-related code: ~3,500 LOC across 13 files
- WeaponsFeature module: 8 files, 1,765 LOC
- Core weapon models: 3 files, 638 LOC
- Shared UI: 1 file, 502 LOC
- Actions tab inventory: 1 file, 758 LOC

**Key Components:**

| Component | LOC | Responsibility | Storage |
|-----------|-----|----------------|---------|
| WeaponRepository | 318 | XML loading/parsing | In-memory |
| WeaponDeckState | 253 | Deck runtime state | In-memory |
| WeaponsManager | 49 | Coordinate 3 decks | In-memory |
| DisabledCardsManager | 117 | Card customization | UserDefaults |
| GameSession | 332 | Game state + **inventory strings** | SwiftData |
| InventoryCard | 758 | Inventory UI | - |
| WeaponsScreen | 437 | Main weapons interface | - |
| DeckSettingsSheet | 387 | Settings/customization | - |

### Current Storage Architecture

```
┌─────────────────────┐
│  weapons.xml        │ → Loaded once at app launch (no versioning)
└─────────────────────┘
          ↓
┌─────────────────────┐
│ WeaponRepository    │ → In-memory singleton (318 LOC)
│ (Singleton)         │
└─────────────────────┘
          ↓
┌─────────────────────┐
│ WeaponsManager      │ → Creates 3 deck instances (in-memory)
│ (@Observable)       │
└─────────────────────┘
          ↓
┌─────────────────────┐
│ WeaponDeckState x3  │ → Deck state (NOT persisted)
│ (@Observable)       │
└─────────────────────┘
          ↓
┌─────────────────────┐
│ GameSession         │ → SwiftData @Model
│ - activeWeapons     │    • "Pistol|Core; Chainsaw|Fort Hendrix"
│ - inactiveWeapons   │    • Manual string parsing required
└─────────────────────┘

┌─────────────────────┐
│ UserDefaults        │ → User preferences (no migration support)
│ - selectedExpansions│
│ - disabledCardsBySet│
└─────────────────────┘
```

### Major Pain Points

#### 1. **String-Based Inventory** (Critical)
```swift
// Current approach in GameSession.swift
@Attribute var activeWeapons: String = ""  // "Pistol|Core; Chainsaw|Fort Hendrix"
@Attribute var inactiveWeapons: String = ""
```

**Problems:**
- No type safety or referential integrity
- Manual parsing on every display operation
- Can reference non-existent weapons
- Difficult to query or filter
- No history tracking
- Hard to extend with metadata (slot index, equipped state)

#### 2. **No Deck Persistence** (High)
- Deck state (shuffle, draws, discard pile) lost on app restart
- Users lose progress mid-session if app closes
- Cannot resume games with exact deck state

#### 3. **Multiple Storage Systems** (Medium)
- SwiftData (GameSession)
- UserDefaults (preferences, disabled cards)
- In-memory (weapon data, deck state)
- **No single source of truth**

#### 4. **No XML Versioning** (Medium)
```swift
// WeaponRepository.swift - hardcoded version
private let dataVersion = "2.2.0"  // No comparison or gating
```
- Cannot detect when bundled XML is updated
- Cannot perform incremental updates
- Risk of overwriting customizations on app update

#### 5. **Scattered Customization Logic** (Medium)
- Expansion filtering logic duplicated in 4+ places
- DisabledCardsManager accessed directly in views
- No preset system for saving configurations
- UserDefaults coupling makes testing difficult

### Current Strengths (To Preserve)

✅ **Excellent shuffle algorithm** - WeaponDeckState.swift:129-180
- Prevents back-to-back duplicates
- Handles edge cases (few unique cards)
- Auto-reshuffles when depleted

✅ **Clean UI/UX** - Well-designed card displays
- WeaponCardView: Comprehensive, visually appealing
- InventoryCard: Intuitive inventory management
- Good use of swipe actions and context menus

✅ **Modern Observable architecture** - iOS 17+ patterns
- @Observable for deck state
- SwiftData for persistence
- Clean separation of concerns

✅ **Flexible expansion filtering** - Good foundation
- Per-set enable/disable
- Per-card customization
- Bulk actions

✅ **Dual format support** - Smooth data evolution
- Handles both legacy and new weapon stats
- Backward compatibility maintained

---

## Effort Assessment

### Complexity Breakdown

#### **Phase 0: SwiftData Models & Migration** (2 weeks)
**Complexity: High** 🔴

New models to create:
- `WeaponDefinition` (replaces in-memory Weapon)
- `WeaponCardInstance` (physical card copies)
- `DeckTemplate` (default deck composition)
- `DeckCustomization` (user adjustments)
- `DeckPreset` (saved configurations)
- `SessionDeckOverride` (temporary changes)
- `WeaponInventoryItem` (replaces strings)
- `WeaponDataVersion` (import tracking)

Migration requirements:
- Parse existing `activeWeapons`/`inactiveWeapons` strings
- Create SwiftData inventory items with validation
- Rollback mechanism on validation failure
- Keep legacy strings temporarily for Phase 5 removal
- Comprehensive migration tests

**Risk:** Data loss during migration (mitigated by validation & rollback)

---

#### **Phase 1: XML Versioning & Import** (1 week)
**Complexity: Medium** 🟡

Tasks:
- Add `version` attribute to weapons.xml
- Create weapons.xsd schema
- Implement version checking logic
- Build incremental import algorithm
- Preserve user customizations during import
- Handle schema validation failures

**Risk:** Import conflicts with existing customizations

---

#### **Phase 2: Service Layer Foundation** (2 weeks)
**Complexity: High** 🔴

Services to build:
- `WeaponsDeckService` - deck runtime operations
  - Build DeckRuntimeState from template + customizations
  - Shuffle/draw/discard operations
  - Port existing shuffle algorithm
  - Flashlight draw-two logic
  - Zombie auto-discard
  - Card movement (top/bottom)

- `InventoryService` - inventory management
  - Slot enforcement (2 active, 3+ backpack)
  - Add/remove/move operations
  - Replacement flow
  - History tracking
  - Integration with deck service

- `CustomizationService` - preset management
  - Aggregate template + customization + overrides
  - Preset CRUD operations
  - Diff vs default
  - Export/import presets

**Risk:** Behavioral regressions vs current deck logic

---

#### **Phase 3: Preset & Customization System** (2 weeks)
**Complexity: Medium** 🟡

UI components:
- Preset manager view
- Customization editor (per card/set)
- Visual diff display
- Import/export flows
- Session override indicator

Data migration:
- Convert UserDefaults → DeckCustomization
- Create default preset from current settings
- Migrate disabled cards per set

**Risk:** Complex UI states and edge cases

---

#### **Phase 4: UI Integration** (2 weeks)
**Complexity: Medium** 🟡

Refactoring:
- Extract shared components to SharedUI:
  - WeaponCardView (already shared, update for new models)
  - DeckSummaryHeader (new)
  - DeckActionButtons (new)
  - WeaponListRow (new)
  - InventorySlotView (new)

- Create shared view models:
  - DeckViewModel (injects WeaponsDeckService)
  - InventoryViewModel (injects InventoryService)

- Update Weapons tab:
  - WeaponsScreen → use DeckViewModel
  - DeckSettingsSheet → preset-based
  - Remove direct UserDefaults access

- Update Actions tab:
  - InventoryCard → use InventoryViewModel
  - Remove string parsing logic

**Risk:** UI regressions, broken data flow

---

#### **Phase 5: Cleanup & Polish** (1 week)
**Complexity: Low** 🟢

Tasks:
- Remove legacy code:
  - WeaponRepository singleton
  - DisabledCardsManager
  - InventoryFormatter
  - UserDefaults keys
  - String inventory fields (after migration period)

- Add logging/telemetry:
  - Import runs
  - Deck operations
  - Inventory mutations
  - Performance metrics

- Documentation:
  - API documentation
  - Migration guide
  - Architecture decision records

- Final testing:
  - Integration tests
  - Performance testing
  - Migration testing with real data

**Risk:** Low - cleanup phase

---

### Total Effort Summary

| Phase | Duration | Complexity | Risk |
|-------|----------|------------|------|
| Phase 0: Models & Migration | 2 weeks | High | High |
| Phase 1: XML Versioning | 1 week | Medium | Medium |
| Phase 2: Service Layer | 2 weeks | High | Medium |
| Phase 3: Preset System | 2 weeks | Medium | Low |
| Phase 4: UI Integration | 2 weeks | Medium | Medium |
| Phase 5: Cleanup | 1 week | Low | Low |
| **TOTAL** | **10 weeks** | | |

**Note:** Estimates assume:
- Single developer working full-time
- No major scope changes mid-stream
- Adequate testing infrastructure
- Access to real user data for migration testing

**Optimistic scenario:** 8 weeks (if phases go smoothly)
**Pessimistic scenario:** 12 weeks (if major issues discovered)

---

## Risk Analysis

### High-Risk Areas 🔴

#### 1. **Data Migration - String Inventory → SwiftData**
**Impact:** Could corrupt/lose user inventory data

**Scenarios:**
- User has 50+ game sessions with inventory
- String format has unexpected variations
- Migration fails mid-process
- App crashes during migration

**Mitigation:**
- Comprehensive migration validation before committing changes
- Automatic rollback mechanism on validation failure
- Keep legacy strings as read-only backup until Phase 5
- Comprehensive migration tests covering all edge cases
- Beta testing with real user data
- Detailed logging of all migration operations

**Testing Required:**
```swift
// Test cases needed:
- Empty inventory strings
- Malformed inventory strings
- Legacy format (without "|" separator)
- Maximum inventory size
- Special characters in weapon names
- Non-existent weapon references
- Concurrent migration scenarios
```

---

#### 2. **Performance - Card Instance Generation**
**Impact:** Slow app launch or deck operations

**Concern:** Spec proposes generating `WeaponCardInstance` for every physical card copy:
- ~150 unique weapons × average 3 copies = 450+ instances
- Each with UUID, relationships, SwiftData overhead

**Mitigation:**
- Benchmark instance generation
- Lazy-load instances per deck type
- Use background context for import
- Consider simplification (see recommendations)
- Profile with Instruments

---

### Medium-Risk Areas 🟡

#### 3. **Behavioral Regressions**
**Impact:** Deck behavior changes vs current implementation

**Areas of concern:**
- Shuffle algorithm differences
- Draw logic edge cases
- Discard pile behavior
- Flashlight draw-two
- Zombie card handling

**Mitigation:**
- Port existing shuffle algorithm directly (don't rewrite)
- Comprehensive unit tests for all deck operations
- Side-by-side testing (old vs new)
- Beta testing period

---

#### 4. **Import Conflicts**
**Impact:** User customizations overwritten by XML import

**Scenarios:**
- Bundled XML changes weapon stats
- New XML removes a weapon user has customized
- Set names change between versions

**Mitigation:**
- Clear import rules (spec section 6)
- User notification when conflicts detected
- Import preview before applying
- Rollback capability

---

### Low-Risk Areas 🟢

#### 5. **UI Regressions**
**Impact:** Visual or interaction bugs

**Mitigation:**
- Existing UI is good reference implementation
- Incremental refactoring
- Snapshot testing for shared components
- UI integration tests

---

#### 6. **Preset System Complexity**
**Impact:** Confusing UX or complex state management

**Mitigation:**
- Start with simple preset model
- Clear labeling (preset vs session override)
- User testing before ship

---

## Key Recommendations

### 🎯 Must-Implement (Critical for Success)

#### 1. **Single Migration with Comprehensive Validation**

**Problem:** String-based inventory needs to migrate to SwiftData reliably.

**Solution:**
```
Single Release: Migrate all sessions on first launch with new version
- Parse legacy strings → create SwiftData inventory items
- Keep legacy strings as read-only backup temporarily
- Validate migration success before UI uses new data
- Remove strings in cleanup phase (Phase 5)
```

**Benefits:**
- Clean transition, no hybrid state
- Simpler codebase (no dual-write logic)
- Faster time to completion
- Migration happens once, thoroughly tested

**Implementation:**
```swift
// Phase 0: Add SwiftData models, keep strings temporarily
@Attribute var activeWeapons: String = ""  // Keep for Phase 5 removal
@Relationship var inventoryItems: [WeaponInventoryItem] = []  // New system

// Migration service validates completeness
func migrateSession(_ session: GameSession) throws {
    guard session.inventoryItems.isEmpty else { return }  // Already migrated

    // Parse and migrate
    let items = parseInventoryStrings(session)
    session.inventoryItems.append(contentsOf: items)

    // Validate migration success
    guard validateMigration(session) else {
        throw MigrationError.validationFailed
    }

    try context.save()
}
```

---

#### 2. **Simplify Card Instance Model**

**Problem:** Spec proposes `WeaponCardInstance` for every physical card:
- 150 weapons × 3 copies = 450+ SwiftData objects
- Uncertain benefit for complexity cost
- Performance concerns

**Recommendation:** Hybrid approach:
```swift
// Simplified model - instances only when needed
@Model class WeaponDefinition {
    var name: String
    var set: String
    var defaultCount: Int  // How many copies in deck
    // ... stats
}

@Model class WeaponInventoryItem {
    // Only create instances for cards in inventory
    var definition: WeaponDefinition
    var serialNumber: String?  // Optional: "Starting:Pistol:2"
}

// Deck runtime tracks counts, not individual instances
struct DeckRuntimeState {
    var cardCounts: [WeaponDefinition: Int]  // Pistol: 3
    var drawnCards: [WeaponDefinition]
    var discardPile: [WeaponDefinition]
}
```

**Benefits:**
- Simpler data model
- Better performance
- Still supports all required features
- Can add full instances later if needed

**Trade-off:** Cannot track history of specific physical card #2 vs #3, but this isn't needed for current use case.

---

#### 3. **Comprehensive Test Suite**

**Problem:** No visible unit tests in current codebase. Refactor without tests is dangerous.

**Recommendation:** Build tests alongside refactor:

```swift
// WeaponsDeckServiceTests.swift
class WeaponsDeckServiceTests: XCTestCase {
    func testShufflePreventsDuplicates() { ... }
    func testDrawDecrementsDeckCount() { ... }
    func testFlashlightDrawsTwo() { ... }
    func testZombieCardAutoDiscards() { ... }
    func testDeckReshufflesWhenEmpty() { ... }
}

// InventoryServiceTests.swift
class InventoryServiceTests: XCTestCase {
    func testEnforcesActiveSlotLimit() { ... }
    func testEnforcesBackpackLimit() { ... }
    func testReplaceFlowWhenFull() { ... }
    func testMoveActiveToBackpack() { ... }
}

// MigrationTests.swift
class InventoryMigrationTests: XCTestCase {
    func testEmptyStringMigration() { ... }
    func testLegacyFormatMigration() { ... }
    func testMalformedStringHandling() { ... }
    func testMaxInventoryMigration() { ... }
}
```

**Coverage targets:**
- Unit tests: 80%+ coverage
- Integration tests: Critical user flows
- Migration tests: All edge cases
- Performance tests: Benchmarks for large datasets

---

### 💡 Should-Implement (Strongly Recommended)

#### 4. **Defer Session Overrides to V2**

**Problem:** `SessionDeckOverride` adds significant complexity:
- Separate model + relationships
- UI to show "session-only" state
- Cleanup logic on session end
- Testing matrix doubles (preset vs override)

**Recommendation:** Ship presets first, validate demand:
1. Phase 3: Implement preset system
2. Gather user feedback
3. Assess if session overrides are actually needed
4. Implement in future release if validated

**Benefits:**
- Reduces initial scope by ~1 week
- Simpler mental model for users
- Can iterate based on real usage

---

#### 5. **Feature Flags for Progressive Rollout**

**Problem:** Big-bang release is risky.

**Recommendation:** Use feature flags:
```swift
enum FeatureFlag {
    static let useNewWeaponsSystem = false  // Phase 0-1
    static let useInventoryService = false  // Phase 2
    static let usePresetSystem = false      // Phase 3
}
```

**Rollout:**
1. Internal testing: All flags on
2. Beta release: Flags on for beta users
3. Production: Gradual rollout (10% → 50% → 100%)
4. Hotfix capability: Can disable if critical bug found

---

#### 6. **Preserve Existing Shuffle Algorithm**

**Problem:** Rewriting shuffle risks behavioral changes.

**Recommendation:** Port directly from `WeaponDeckState.swift:129-180`:
```swift
// WeaponsDeckService.swift
func shuffle() {
    // Direct port from WeaponDeckState (proven algorithm)
    // ... existing logic ...
}
```

**Benefits:**
- Proven algorithm (no infinite loops)
- Maintains user experience
- Less testing required
- Quick win

---

### 🤔 Nice-to-Have (Consider if Time Allows)

#### 7. **XSD Schema Validation**

**Value:** Catch XML errors early
**Cost:** 1-2 days
**Verdict:** Include if time permits in Phase 1

---

#### 8. **Preset Import/Export**

**Value:** Users can share deck configurations
**Cost:** 2-3 days
**Verdict:** Good candidate for Phase 3 extension

---

#### 9. **Deck State Persistence**

**Value:** Resume games with exact deck state
**Cost:** Already included in spec, verify necessity
**Verdict:** Implement if users request it

---

## Phased Implementation Plan

Each phase includes:
- Clear deliverables and success criteria
- Git commit strategy
- Detailed Claude prompt for implementation
- Testing requirements

---
