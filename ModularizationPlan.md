# Aggressive Modularization Plan - ActionTracker Swift App

## Overview
Transform the monolithic 23-file app into a multi-module SPM architecture with:
- **Single local package**: `ActionTrackerKit` with 8 module targets
- **Very aggressive file splitting**: 23 files → ~60+ focused files (~100-150 lines each)
- **Strict dependency rules**: Unidirectional dependencies enforced via SPM
- **Full test coverage**: Unit test targets for all modules
- **Incremental approach**: App builds after each phase with git commits

---

## Phase 1: Setup & Package Structure

1. Create git branch
2. Create `ActionTrackerKit/` directory at project root
3. Create `Package.swift` with 8 module targets:
   - `CoreDomain` (no dependencies)
   - `DataLayer` (depends on CoreDomain)
   - `SharedUI` (depends on CoreDomain)
   - `CharacterFeature` (depends on CoreDomain, DataLayer, SharedUI)
   - `SkillsFeature` (depends on CoreDomain, DataLayer, SharedUI)
   - `GameSessionFeature` (depends on CoreDomain, DataLayer, SharedUI)
   - `WeaponsFeature` (depends on CoreDomain, DataLayer, SharedUI)
   - `SpawnDeckFeature` (depends on CoreDomain, DataLayer, SharedUI)
4. Create directory structure with `Sources/` and `Tests/` folders
5. Link package to Xcode project
6. **Commit**: "Setup SPM package structure"

---

## Phase 2: Extract CoreDomain (Foundation Layer)
**Files to split**: `Models.swift` (581 lines) → 9 files

1. Create module structure:
   ```
   CoreDomain/
   ├── Models/
   │   ├── Character.swift (~120 lines)
   │   ├── Skill.swift (~40 lines)
   │   ├── GameSession.swift (~180 lines)
   │   ├── ActionInstance.swift (~30 lines)
   ├── Enums/
   │   ├── ActionType.swift (~50 lines)
   │   ├── SkillLevel.swift (~30 lines)
   │   └── DifficultyLevel.swift (~20 lines)
   └── Utilities/
       ├── InventoryFormatter.swift (~40 lines)
       └── StringExtensions.swift (~20 lines)
   ```

2. Move model definitions from `Models.swift` to individual files
3. Extract enums scattered across files
4. Move utility functions to Utilities/
5. Update imports in main app to `import CoreDomain`
6. Delete original `Models.swift`
7. Build and verify app works
8. **Commit**: "Extract CoreDomain module with models, enums, utilities"

---

## Phase 3: Extract DataLayer
**Files to move**: 3 files + data seeding logic

1. Create module structure:
   ```
   DataLayer/
   ├── Protocols/
   │   └── DataRepository.swift (~40 lines)
   ├── Repositories/
   │   ├── CharacterRepository.swift (~100 lines)
   │   └── WeaponRepository.swift (~180 lines)
   └── Seeding/
       └── DataSeeder.swift (~320 lines)
   ```

2. Define `DataRepository` protocol for abstraction
3. Move `CharacterRepository.swift` and make it conform to protocol
4. Move `WeaponRepository.swift` and make it conform to protocol
5. Move `DataSeeder.swift` and bundle resource handling
6. Update SwiftData container setup in app
7. Update imports to `import DataLayer`
8. Build and verify data loading works
9. **Commit**: "Extract DataLayer module with repositories and seeding"

---

## Phase 4: Extract SharedUI
**Files to extract**: Reusable UI components

1. Create module structure:
   ```
   SharedUI/
   ├── Components/
   │   ├── FlowLayout.swift (~80 lines) - extract from ActionsScreen
   │   └── DiscardPileView.swift (~220 lines)
   ├── Modifiers/
   │   └── ShakeEffect.swift (~40 lines)
   └── Extensions/
       └── Color+ActionType.swift (~30 lines)
   ```

2. Extract `FlowLayout` from ActionsScreen.swift
3. Move `DiscardPileView.swift`
4. Extract `ShakeEffect` modifier
5. Create color extensions for ActionType
6. Update imports to `import SharedUI`
7. Build and verify UI components work
8. **Commit**: "Extract SharedUI module with reusable components"

---

## Phase 5: GameSessionFeature - Split ActionsScreen
**Files to split**: `ActionsScreen.swift` (1,860 lines) → 14 files

1. Create module structure:
   ```
   GameSessionFeature/
   ├── Views/
   │   ├── ActionsScreen.swift (~120 lines) - coordination only
   │   ├── StartGameView.swift (~140 lines)
   │   ├── ActiveGameView.swift (~150 lines)
   │   ├── CharacterInfoCard.swift (~100 lines)
   │   ├── HealthCard.swift (~130 lines)
   │   ├── ActionsCard.swift (~140 lines)
   │   ├── ActionTypeRow.swift (~80 lines)
   │   ├── ActionToken.swift (~60 lines)
   │   ├── InventoryCard.swift (~150 lines)
   │   ├── ExperienceCard.swift (~140 lines)
   │   ├── TimerCard.swift (~120 lines)
   │   ├── SkillSelectionSheet.swift (~180 lines)
   │   └── CharacterPickerSheet.swift (~140 lines)
   └── Logic/
       └── GameTimer.swift (~60 lines)
   ```

2. Extract each view component into separate file
3. Keep `ActionsScreen.swift` as coordinator (imports all subviews)
4. Extract game timer logic
5. Update all imports to use module imports
6. Build and verify Actions tab works completely
7. **Commit**: "Extract GameSessionFeature module - split ActionsScreen into 14 files"

---

## Phase 6: Extract CharacterFeature
**Files to move**: 4 files, minimal splitting needed

1. Create module structure:
   ```
   CharacterFeature/
   └── Views/
       ├── CharactersScreen.swift (~150 lines)
       ├── CharacterDetailView.swift (~360 lines)
       ├── NewCharacterView.swift (~190 lines)
       └── Components/
           └── CharacterRow.swift (~80 lines) - extract from CharactersScreen
   ```

2. Move character-related views
3. Extract `CharacterRow` component
4. Update imports
5. Build and verify Characters tab works
6. **Commit**: "Extract CharacterFeature module"

---

## Phase 7: Extract SkillsFeature
**Files to move**: 5 files

1. Create module structure:
   ```
   SkillsFeature/
   └── Views/
       ├── SkillsScreen.swift (~280 lines) - keep main screen + list
       ├── AdvancedSkillSearchView.swift (~230 lines)
       ├── SkillCharactersView.swift (~240 lines)
       ├── SkillPickerView.swift (~130 lines)
       ├── NewSkillView.swift (~70 lines)
       └── Components/
           └── SkillRowView.swift (~80 lines) - extract from SkillsScreen
   ```

2. Move skill-related views
3. Extract `SkillRowView` component
4. Update imports
5. Build and verify Skills tab works
6. **Commit**: "Extract SkillsFeature module"

---

## Phase 8: Extract WeaponsFeature
**Files to split**: `WeaponsScreen.swift` (989 lines) → 6 files

1. Create module structure:
   ```
   WeaponsFeature/
   ├── Models/
   │   ├── WeaponModels.swift (~250 lines)
   │   ├── WeaponDeckState.swift (~330 lines)
   │   └── WeaponsManager.swift (~150 lines) - extract from WeaponDeckState
   └── Views/
       ├── WeaponsScreen.swift (~180 lines) - main coordinator
       ├── WeaponCardView.swift (~310 lines)
       ├── WeaponDiscardView.swift (~240 lines)
       ├── DeckSettingsSheet.swift (~180 lines) - extract from WeaponsScreen
       ├── DeckContentsView.swift (~140 lines) - extract from WeaponsScreen
       └── InventoryManagementSheet.swift (~150 lines) - extract from WeaponsScreen
   ```

2. Split `WeaponsScreen.swift` into 4 view files
3. Move all weapon models
4. Extract `WeaponsManager` as separate state manager
5. Update imports and state management
6. Build and verify Weapons tab works
7. **Commit**: "Extract WeaponsFeature module - split WeaponsScreen into 6 files"

---

## Phase 9: Extract SpawnDeckFeature
**Files to split**: `SpawnDeckView.swift` (488 lines) → 3 files

1. Create module structure:
   ```
   SpawnDeckFeature/
   ├── Models/
   │   └── SpawnDeckManager.swift (~400 lines)
   └── Views/
       ├── SpawnDeckView.swift (~180 lines) - main coordinator
       ├── SpawnCardView.swift (~140 lines) - extract card display
       └── SpawnStatsView.swift (~120 lines) - extract stats panel
   ```

2. Split `SpawnDeckView.swift` into 3 view files
3. Move `SpawnDeckModels.swift` → `SpawnDeckManager.swift`
4. Update imports
5. Build and verify Spawn Deck tab works
6. **Commit**: "Extract SpawnDeckFeature module - split SpawnDeckView into 3 files"

---

## Phase 10: Create AppKit Module
**Purpose**: Thin app shell that wires features together

1. Create module structure:
   ```
   Sources/
   └── AppKit/
       └── ContentView.swift (~80 lines)
   ```

2. Move `ContentView.swift` to AppKit module
3. Update main app target to depend on:
   - CoreDomain
   - DataLayer
   - SharedUI
   - CharacterFeature
   - SkillsFeature
   - GameSessionFeature
   - WeaponsFeature
   - SpawnDeckFeature
   - AppKit

4. Update `ZombiTrackApp.swift` to import AppKit
5. Build and verify full app integration
6. **Commit**: "Create AppKit module - complete modularization"

---

## Phase 11: Add Unit Tests
**Coverage**: All modules except features (integration tests later)

1. Create test targets in `Package.swift`:
   - `CoreDomainTests`
   - `DataLayerTests`
   - `SharedUITests`

2. CoreDomain tests:
   - Model initialization and relationships
   - Inventory string parsing
   - XP cycle calculations
   - Enum cases and properties

3. DataLayer tests:
   - Repository data loading
   - JSON parsing
   - Data seeding logic

4. SharedUI tests:
   - FlowLayout calculations
   - View modifier behavior

5. Run all tests and ensure they pass
6. **Commit**: "Add unit tests for CoreDomain, DataLayer, SharedUI"

---

## Phase 12: Validation & Cleanup

1. **Dependency validation**:
   - Verify no feature modules import other features
   - Check dependency graph follows rules
   - Ensure CoreDomain has no external dependencies

2. **File size audit**:
   - Confirm all files are <300 lines (target: 100-150)
   - Identify any remaining large files

3. **Build performance**:
   - Clean build and measure compile time
   - Check for circular dependencies

4. **Access control**:
   - Mark internal types that shouldn't be public
   - Ensure proper API surface for each module

5. **Documentation**:
   - Add module-level documentation comments
   - Update README with architecture diagram

6. **Final verification**:
   - Run full app on simulator
   - Test all features work correctly
   - Verify data seeding still works

7. **Commit**: "Final cleanup and validation"

---

## Success Metrics

- **Files**: 23 → ~65 files (182% increase in modularity)
- **Largest file**: 1,860 lines → ~360 lines (80% reduction)
- **Average file size**: ~326 lines → ~115 lines (65% reduction)
- **Module count**: 1 monolith → 8 focused modules
- **Test coverage**: 0% → 60%+ (CoreDomain, DataLayer, SharedUI)
- **Build time**: Baseline → Incremental compilation enabled
- **Dependency violations**: 0 (enforced by SPM)

---

## git Graph

```mermaind
gitGraph
  commit id: "main init"
  branch develop
  checkout develop
  commit id: "bootstrap"

  %% Phase 1
  branch feature/setup-spm-package
  commit id: "SPM Package.swift + skeleton"
  checkout develop
  merge feature/setup-spm-package tag: "phase-1"

  %% Phase 2
  branch feature/core-domain-module
  commit id: "Extract CoreDomain"
  checkout develop
  merge feature/core-domain-module tag: "phase-2"

  %% Phase 3
  branch feature/data-layer-module
  commit id: "Extract DataLayer"
  checkout develop
  merge feature/data-layer-module tag: "phase-3"

  %% Phase 4
  branch feature/shared-ui-module
  commit id: "Extract SharedUI"
  checkout develop
  merge feature/shared-ui-module tag: "phase-4"

  %% Phase 5
  branch feature/gamesession-feature
  commit id: "Split ActionsScreen → module"
  checkout develop
  merge feature/gamesession-feature tag: "phase-5"

  %% Phase 6
  branch feature/character-feature
  commit id: "Characters screens → module"
  checkout develop
  merge feature/character-feature tag: "phase-6"

  %% Phase 7
  branch feature/skills-feature
  commit id: "Skills screens → module"
  checkout develop
  merge feature/skills-feature tag: "phase-7"

  %% Phase 8
  branch feature/weapons-feature
  commit id: "Split WeaponsScreen → module"
  checkout develop
  merge feature/weapons-feature tag: "phase-8"

  %% Phase 9
  branch feature/spawndeck-feature
  commit id: "SpawnDeck → module"
  checkout develop
  merge feature/spawndeck-feature tag: "phase-9"

  %% Phase 10
  branch feature/appkit-shell
  commit id: "AppKit shell + ContentView"
  checkout develop
  merge feature/appkit-shell tag: "phase-10"

  %% Phase 11
  branch feature/unit-tests
  commit id: "CoreDomain/DataLayer/SharedUI tests"
  checkout develop
  merge feature/unit-tests tag: "phase-11"

  %% Phase 12
  branch feature/final-cleanup
  commit id: "Validation + docs + access control"
  checkout develop
  merge feature/final-cleanup tag: "phase-12"

  %% Integration hardening
  branch integration/modularization-qa
  checkout integration/modularization-qa
  merge develop id: "Full app QA"

  %% Release
  checkout main
  merge integration/modularization-qa id: "Modularized baseline"
  tag "v2.0.0"
```

---

## Dependency Graph (Final)

```
┌─────────────────────────────────────────┐
│ Main App Target (ZombiTrack)           │
│ - SwiftData ModelContainer setup        │
│ - App lifecycle                         │
└────────────────┬────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────┐
│ AppKit                                  │
│ - ContentView (tab coordination)        │
└──┬───┬───┬───┬───┬────────────────────┘
   │   │   │   │   │
   │   │   │   │   └─────────────┐
   │   │   │   └──────────┐      │
   │   │   └───────┐      │      │
   │   └────┐      │      │      │
   ▼        ▼      ▼      ▼      ▼
Character Skills Game  Weapons Spawn
Feature  Feature Session Feature  Deck
                Feature          Feature
   │        │      │      │      │
   └────────┴──────┴──────┴──────┘
                 │
         ┌───────┴────────┐
         ▼                ▼
    DataLayer         SharedUI
         │                │
         └────────┬───────┘
                  ▼
            CoreDomain
          (Foundation)
```

**Rules**:
- ✅ Features depend on DataLayer, SharedUI, CoreDomain
- ✅ DataLayer depends only on CoreDomain
- ✅ SharedUI depends only on CoreDomain
- ✅ CoreDomain has NO dependencies
- ❌ Features CANNOT depend on each other

---

## Estimated Timeline
- **Total**: 12-16 hours across 12 phases
- **Phase 1-4**: 4 hours (foundation)
- **Phase 5-9**: 6-8 hours (features)
- **Phase 10-12**: 2-4 hours (integration & testing)
