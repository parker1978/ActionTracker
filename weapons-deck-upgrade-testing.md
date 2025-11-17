# Weapons Deck Upgrade: Testing Strategy & Success Metrics

This document outlines the comprehensive testing strategy, success metrics, and comparison matrix for the weapons deck upgrade.

---

## Testing Strategy

### Unit Tests (Target: 80%+ Coverage)

**Services:**
- `WeaponsDeckServiceTests`: 15+ tests
  - Shuffle prevents back-to-back duplicates
  - Draw decrements remaining count
  - Auto-reshuffle when deck empty
  - Flashlight draws two cards
  - Zombie cards auto-discard
  - Return to top/bottom works
  - Edge cases (single unique card, empty deck, etc.)

- `InventoryServiceTests`: 12+ tests
  - Enforces active slot limits
  - Enforces backpack limits with modifiers
  - Replacement flow when full
  - Move operations (active ↔ backpack)
  - Remove weapon updates session
  - Session modifier handling

- `CustomizationServiceTests`: 8+ tests
  - Preset CRUD operations
  - Apply preset to deck
  - Diff vs default
  - Export/import presets
  - Default preset management

- `WeaponXMLImporterTests`: 10+ tests
  - Version gating logic
  - Schema validation
  - Incremental import
  - Customization preservation
  - Handle removed weapons
  - Performance benchmarks

**Migrations:**
- `InventoryMigrationTests`: 8+ tests
  - Empty inventory migration
  - Single weapon migration
  - Full inventory migration
  - Malformed string handling
  - Legacy format compatibility
  - Non-existent weapon references
  - Validation and rollback

- `CustomizationMigrationTests`: 5+ tests
  - UserDefaults to preset migration
  - Preserve disabled cards
  - Preserve expansion selections
  - Migration idempotency

**Total:** 58+ unit tests

---

### Integration Tests

**User Flows:**
- Complete game flow: start → draw → inventory → end
- Preset creation and application
- XML import with customizations preserved
- Deck state persistence across sessions

**Cross-Component:**
- Deck service ↔ Inventory service integration
- View models ↔ Services integration
- SwiftData relationship integrity
- Concurrent operation handling

**Total:** 12+ integration tests

---

### UI Tests

**Snapshot Tests:**
- WeaponCardView variants (melee, ranged, dual)
- InventorySlotView states (active, backpack, empty)
- DeckSummaryHeader layouts (different deck states)
- Preset manager screens

**Interaction Tests:**
- Draw weapon flow
- Add to inventory flow
- Create preset flow
- Apply customization flow
- Move weapon between slots
- Replace full slot

**Total:** 10+ UI tests

---

### Performance Tests

**Benchmarks:**
- XML import time: <1s for ~150 weapons
- Deck shuffle time: <50ms
- Inventory operation time: <50ms per operation
- Large session migration: <2s for 50+ sessions
- App launch impact: <200ms additional time
- Memory footprint: <5MB additional during normal use

**Total:** 6+ performance tests

---

### Migration Tests

**Real Data Scenarios:**
- Empty database (new user)
- Small database (1-5 sessions)
- Medium database (10-20 sessions)
- Large database (50+ sessions)
- Edge cases (malformed data, missing weapons, corrupted strings)

**Validation:**
- 100% data preservation
- No data loss
- Rollback works correctly
- Legacy strings remain as backup

**Total:** 8+ migration scenarios

---

## Success Metrics

### Technical Metrics

- ✅ **Code Coverage:** 80%+ across all new code
- ✅ **Import Performance:** <1s for ~150 weapons
- ✅ **Deck Operations:** <50ms per operation (shuffle, draw, discard)
- ✅ **App Launch Impact:** <200ms additional time
- ✅ **Memory Footprint:** <5MB additional during normal use
- ✅ **SwiftData Efficiency:** <100 objects in memory during normal use

### User Experience Metrics

- ✅ **Feature Parity:** All existing features work identically
- ✅ **New Capabilities:** Presets, deck persistence, better inventory management
- ✅ **Migration Success:** 100% of users migrate without data loss
- ✅ **UI Responsiveness:** No perceivable lag in any operation
- ✅ **Accessibility:** VoiceOver compatible, Dynamic Type support

### Business Metrics

- ✅ **Beta Feedback:** Positive response to preset system
- ✅ **Crash Rate:** <0.1% (no increase from current)
- ✅ **Support Tickets:** No increase in weapons-related issues
- ✅ **Adoption:** Users actively create and use custom presets

---

## Comparison Matrix

| Aspect | Current (v20.x) | After Upgrade (v21.x) |
|--------|----------------|----------------------|
| **Weapon Storage** | In-memory singleton | SwiftData (persistent) |
| **Inventory Storage** | Strings on GameSession | WeaponInventoryItem (relational) |
| **Customization Storage** | UserDefaults | DeckPreset (SwiftData) |
| **Deck Persistence** | None (lost on restart) | Full persistence |
| **XML Versioning** | None | Version gating + incremental |
| **Code Architecture** | Mixed (repository + managers) | Service-oriented |
| **Testing** | None visible | 80%+ coverage |
| **Documentation** | Minimal | Comprehensive |
| **Migration Support** | Manual | Automatic with validation |
| **Preset System** | None | Full CRUD + export/import |
| **Lines of Code** | ~3,500 | ~4,500 (with tests) |
| **Technical Debt** | High | Low |

---

## Questions & Clarifications

Before starting implementation, consider:

1. **Session Overrides:** Still want to implement in Phase 3, or defer to v2?
2. **Card Instance Model:** Prefer full instances per physical card, or simplified hybrid approach?
3. **Feature Flags:** Want gradual rollout capability?
4. **Beta Testing:** How many users, what timeframe?
5. **Rollback Plan:** If critical bug found post-launch, revert to legacy or fix forward?

---

## Conclusion

This weapons deck upgrade is a **significant but worthwhile investment**. The current string-based inventory and UserDefaults customization system have accumulated technical debt that limits future development.

**Recommendation:** Proceed with phased approach using the provided implementation prompts. Each phase has clear deliverables, testing requirements, and commit strategy. The total 10-week estimate is realistic for a complete, well-tested implementation.

**Risk Mitigation:** The single-pass migration with comprehensive validation and automatic rollback, combined with thorough testing, significantly reduces the risk of data loss or user-facing issues.

**ROI:** Once complete, the new architecture will enable:
- Easy addition of new deck types
- Rich customization features
- Better user experience (presets, persistence)
- Maintainable, testable codebase
- Foundation for future multiplayer features

---

**Ready to proceed?** Start with Phase 0 using the provided Claude prompt. Each phase builds incrementally, so you can validate functionality before moving forward.
