# Claude Prompt: Phase 4 - UI Integration & Shared Components

Implement Phase 4 of the weapons deck upgrade for ActionTracker. This phase refactors the UI layer to use shared view models and components, eliminating direct data access from views.

---

## Phase 4: UI Integration & Shared Components

**Duration:** 2 weeks
**Complexity:** Medium 🟡
**Prerequisites:** Phases 0-3 complete

### Deliverables

1. ✅ Shared UI components extracted
2. ✅ Shared view models
3. ✅ Weapons tab refactored
4. ✅ Actions tab refactored
5. ✅ No direct SwiftData access from views

### Git Commit Strategy

```bash
# Commit 1: Extract shared components
feat(ui): extract shared weapon components to SharedUI

- Update WeaponCardView for new models
- Create DeckSummaryHeader component
- Create DeckActionButtons component
- Create WeaponListRow component
- Create InventorySlotView component
- Add Previews for all components

# Commit 2: Create shared view models
feat(viewmodels): add shared view models for weapons & inventory

- Create DeckViewModel (injects WeaponsDeckService)
- Create InventoryViewModel (injects InventoryService)
- Create CustomizationViewModel (injects CustomizationService)
- Handle all business logic in view models
- Expose @Published state for SwiftUI

# Commit 3: Refactor Weapons tab
refactor(weapons): update Weapons tab to use new architecture

- Update WeaponsScreen to use DeckViewModel
- Update DeckSettingsSheet to use CustomizationViewModel
- Remove direct UserDefaults access
- Use shared components
- Integrate preset picker

# Commit 4: Refactor Actions tab
refactor(actions): update Actions tab to use new architecture

- Update InventoryCard to use InventoryViewModel
- Remove string parsing logic
- Use shared components
- Remove InventoryFormatter dependency
```

### Architecture Goals

**Separation of Concerns:**
- Views only handle UI rendering
- View models handle business logic
- Services handle data operations
- No direct SwiftData access from views
- No direct UserDefaults access from views

**Shared Components:**
- DeckSummaryHeader - deck stats display
- DeckActionButtons - draw/shuffle/etc buttons
- WeaponListRow - individual weapon row
- InventorySlotView - inventory slot display
- WeaponCardView - updated for new models

**View Models:**
- DeckViewModel - deck operations
- InventoryViewModel - inventory management
- CustomizationViewModel - preset management

### Success Criteria

- ✅ Shared components extracted
- ✅ View models handle business logic
- ✅ Weapons tab refactored
- ✅ Actions tab refactored
- ✅ No direct data access from views

### Testing Checklist

- [ ] WeaponsScreen draws cards correctly
- [ ] InventoryCard displays inventory correctly
- [ ] Add/remove weapons works
- [ ] Move active ↔ backpack works
- [ ] Preset application updates deck
- [ ] Flashlight toggle affects draw
- [ ] Deck stats update in real-time
- [ ] No UI regressions
