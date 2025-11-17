# Claude Prompt: Phase 2 - Service Layer Foundation

Implement Phase 2 of the weapons deck upgrade for ActionTracker. This phase builds the domain services that encapsulate all deck and inventory business logic. **Critical requirement:** Port the existing proven shuffle algorithm from WeaponDeckState.swift directly - do not rewrite it.

---

## Phase 2: Service Layer Foundation

**Duration:** 2 weeks
**Complexity:** High 🔴
**Prerequisites:** Phase 0 & 1 complete

### Deliverables

1. ✅ WeaponsDeckService with full deck runtime logic
2. ✅ InventoryService with slot management
3. ✅ CustomizationService for preset handling
4. ✅ Comprehensive service tests
5. ✅ Ported shuffle algorithm

### Git Commit Strategy

```bash
# Commit 1: Create WeaponsDeckService
feat(services): implement WeaponsDeckService for deck runtime

- Create DeckRuntimeState model
- Implement deck building from template + customizations
- Port shuffle algorithm from WeaponDeckState
- Implement draw, discard, reshuffle operations
- Add Flashlight draw-two logic
- Add zombie auto-discard
- Add card movement (top/bottom)

# Commit 2: Create InventoryService
feat(services): implement InventoryService for inventory management

- Implement slot enforcement (2 active, 3+ backpack)
- Add/remove/move operations
- Replacement flow when full
- Integration with WeaponsDeckService
- History tracking via InventoryEvent
- Validate against game session modifiers

# Commit 3: Create CustomizationService
feat(services): implement CustomizationService for preset management

- Aggregate template + customization + overrides
- Apply preset to deck service
- Diff current vs default
- Preset CRUD operations
- Export/import preset data

# Commit 4: Add service tests
test(services): comprehensive service layer test suite

- WeaponsDeckService: shuffle, draw, discard, edge cases
- InventoryService: slot limits, replacement, moves
- CustomizationService: preset application, diffing
- Integration tests between services
```

### Key Requirements

**CRITICAL:** The shuffle algorithm must be ported directly from `WeaponDeckState.swift:129-180`. This is a proven algorithm that:
- Prevents back-to-back duplicates
- Handles edge cases (few unique cards)
- Never infinite loops
- Auto-reshuffles when depleted

Do NOT rewrite this algorithm - it works perfectly and any changes risk behavioral regressions.

### Success Criteria

- ✅ All three services implemented
- ✅ Shuffle algorithm ported successfully
- ✅ 30+ service tests passing
- ✅ No behavioral regressions
- ✅ Services integrate with SwiftData models

### Testing Checklist

**WeaponsDeckService:**
- [ ] Shuffle prevents back-to-back duplicates
- [ ] Draw decrements remaining count
- [ ] Auto-reshuffle when deck empty
- [ ] Flashlight draws two cards
- [ ] Zombie cards auto-discard
- [ ] Return to top/bottom works
- [ ] Edge case: deck with 1 unique card

**InventoryService:**
- [ ] Enforces 2 active slot limit
- [ ] Enforces 3+ backpack limit (with modifiers)
- [ ] Replacement flow when full
- [ ] Move active ↔ backpack
- [ ] Remove weapon updates session
- [ ] Handles extraInventorySlots modifier
- [ ] Handles allInventoryActive modifier
