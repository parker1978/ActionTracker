# Claude Prompt: Phase 1 - XML Versioning & Incremental Import

Implement Phase 1 of the weapons deck upgrade for ActionTracker. This phase adds version tracking to the weapons.xml file and implements smart incremental imports that preserve user customizations while updating weapon definitions.

---

## Phase 1: XML Versioning & Incremental Import

**Duration:** 1 week
**Complexity:** Medium 🟡
**Prerequisites:** Phase 0 complete

### Deliverables

1. ✅ Updated weapons.xml with version attribute
2. ✅ weapons.xsd schema for validation
3. ✅ Version checking logic
4. ✅ Incremental import algorithm
5. ✅ User customization preservation

### Git Commit Strategy

```bash
# Commit 1: Add XML version and schema
feat(data): add XML versioning and schema validation

- Update weapons.xml with version="2.3.0" attribute
- Create weapons.xsd schema
- Add schema validation to project
- Update WeaponXMLParser to read version

# Commit 2: Implement version checking
feat(import): add XML version gating logic

- Check bundle version vs WeaponDataVersion
- Skip import if bundle version not newer
- Update WeaponDataVersion after successful import
- Add logging for import decisions

# Commit 3: Implement incremental import
feat(import): implement incremental import with customization preservation

- Diff existing WeaponDefinitions vs XML
- Update changed definitions (preserve UUID)
- Add new definitions
- Flag removed definitions
- Never overwrite user DeckCustomizations
- Handle variant weapons (same name, different set)

# Commit 4: Add import tests
test(import): comprehensive XML import test suite

- Test version gating (skip if same version)
- Test schema validation failures
- Test incremental updates (changed stats)
- Test new weapon additions
- Test weapon removals
- Test customization preservation
```

### Implementation Details

See the detailed implementation guide above for:
- XML version attribute and schema
- WeaponXMLImporter service implementation
- App launch integration
- Comprehensive test suite
- Version comparison logic
- Customization preservation strategy

### Success Criteria

- ✅ XML version checking implemented
- ✅ Schema validation working
- ✅ Incremental import preserves UUIDs
- ✅ User customizations never lost
- ✅ Import runs only when needed
- ✅ All import tests passing

### Testing Checklist

- [ ] Version gating skips when same version
- [ ] Version gating runs when newer version
- [ ] Schema validation catches malformed XML
- [ ] Incremental import updates existing weapons
- [ ] Incremental import adds new weapons
- [ ] Removed weapons handled gracefully
- [ ] User customizations preserved
- [ ] Performance acceptable (<1s for ~150 weapons)
