# Claude Prompt: Phase 5 - Cleanup, Testing & Documentation

Implement Phase 5 (final phase) of the weapons deck upgrade for ActionTracker. This phase removes legacy code, adds production-ready logging, comprehensive documentation, and performs final testing and validation.

---

## Phase 5: Cleanup, Testing & Documentation

**Duration:** 1 week
**Complexity:** Low 🟢
**Prerequisites:** All previous phases complete

### Deliverables

1. ✅ Legacy code removed
2. ✅ Logging/telemetry added
3. ✅ Documentation complete
4. ✅ Final integration testing
5. ✅ Performance validation

### Git Commit Strategy

```bash
# Commit 1: Remove legacy code
chore: remove legacy weapons system code

- Delete WeaponRepository.swift
- Delete DisabledCardsManager.swift
- Delete InventoryFormatter.swift
- Remove legacy UserDefaults keys
- Remove string inventory fields from GameSession (after verification)
- Update imports and references

# Commit 2: Add logging and telemetry
feat(logging): add structured logging for weapons system

- Log import runs with timing
- Log deck operations (draw, shuffle, discard)
- Log inventory mutations
- Add performance metrics
- Use os_log for production logging

# Commit 3: Add documentation
docs: comprehensive weapons system documentation

- Architecture decision records
- API documentation
- Migration guide
- Troubleshooting guide
- Component diagrams

# Commit 4: Final testing and polish
test: final integration and performance testing

- End-to-end user flow tests
- Performance benchmarks
- Memory leak checks
- Accessibility audit
- Final bug fixes
```

### Files to Delete

**Legacy Code (after verification):**
- `DataLayer/WeaponRepository.swift` (318 LOC)
- `CoreDomain/Services/DisabledCardsManager.swift` (117 LOC)
- `DataLayer/InventoryFormatter.swift` (30 LOC)

**GameSession Model:**
```swift
// Remove these after confirming migration complete
@Attribute var activeWeapons: String = ""
@Attribute var inactiveWeapons: String = ""
```

**UserDefaults Keys:**
- "selectedExpansions"
- "disabledCardsBySet"
- "hasRunWeaponsMigration" (if exists)

### Logging Implementation

Use `os_log` for structured logging:

```swift
import OSLog

struct WeaponsLogger {
    static let importer = Logger(subsystem: "ActionTracker", category: "WeaponImporter")
    static let deck = Logger(subsystem: "ActionTracker", category: "DeckService")
    static let inventory = Logger(subsystem: "ActionTracker", category: "InventoryService")
    static let performance = Logger(subsystem: "ActionTracker", category: "Performance")
}
```

### Documentation to Create

**Required Documentation:**
1. `Documentation/WeaponsSystemArchitecture.md` - System architecture overview
2. `Documentation/MigrationGuide.md` - Migration from v20.x to v21.x
3. `Documentation/TroubleshootingGuide.md` - Common issues and solutions
4. API documentation (inline code comments)

### Success Criteria

- ✅ All legacy code removed
- ✅ Production logging implemented
- ✅ Documentation complete
- ✅ All tests passing
- ✅ Performance validated
- ✅ Ready for production release

### Final Checklist

- [ ] Legacy files deleted
- [ ] Legacy UserDefaults keys removed
- [ ] Logging added to all services
- [ ] Architecture docs written
- [ ] Migration guide written
- [ ] API documentation complete
- [ ] All unit tests passing
- [ ] All integration tests passing
- [ ] Performance tests passing
- [ ] Memory leak check clean
- [ ] Accessibility audit passed
- [ ] Ready for beta testing

### Performance Targets

- XML import: <1s for ~150 weapons
- Deck shuffle: <50ms
- Inventory operations: <50ms
- App launch impact: <200ms additional
- Memory footprint: <5MB additional
- Migration (50+ sessions): <2s
