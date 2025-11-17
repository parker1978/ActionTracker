# Claude Prompt: Phase 3 - Preset & Customization System

Implement Phase 3 of the weapons deck upgrade for ActionTracker. This phase builds the preset system that lets users save and restore deck configurations, and migrates away from UserDefaults to SwiftData.

---

## Phase 3: Preset & Customization System

**Duration:** 2 weeks
**Complexity:** Medium 🟡
**Prerequisites:** Phases 0-2 complete

### Deliverables

1. ✅ CustomizationService with preset CRUD
2. ✅ Preset manager UI
3. ✅ Card customization editor
4. ✅ Migration from UserDefaults
5. ✅ Visual diff display

### Git Commit Strategy

```bash
# Commit 1: Implement CustomizationService
feat(customization): implement preset management service

- CRUD operations for presets
- Apply preset to deck service
- Diff current vs default template
- Merge customizations (preset + override)
- Export/import preset JSON

# Commit 2: Create preset manager UI
feat(ui): add preset manager interface

- List view of saved presets
- Create/edit/delete preset flows
- Mark default preset
- Apply preset to active session
- Visual indication of active preset

# Commit 3: Create customization editor UI
feat(ui): add deck customization editor

- Per-card enable/disable toggles
- Adjust copy counts
- Bulk actions (enable/disable all in set)
- Visual diff vs default
- Save as new preset

# Commit 4: Migrate UserDefaults → SwiftData
feat(migration): migrate UserDefaults customizations to presets

- Read selectedExpansions array
- Read disabledCardsBySet dictionary
- Create "Default" preset with current settings
- Mark as active preset
- Clear old UserDefaults keys
```

### Key Features

**Preset Management:**
- Create, edit, delete presets
- Set default preset
- Apply preset to active game session
- Export/import presets as JSON

**Customization Editor:**
- Enable/disable individual cards
- Adjust card copy counts
- Bulk enable/disable by set
- Visual diff showing changes from default

**UserDefaults Migration:**
- Automatic one-time migration
- Preserves all existing customizations
- Creates "Default" preset from current settings
- Cleans up old UserDefaults keys

### Success Criteria

- ✅ Preset system fully functional
- ✅ UserDefaults successfully migrated
- ✅ UI for preset management
- ✅ Can create, edit, delete presets
- ✅ Visual diff working

### Testing Checklist

- [ ] Create preset with customizations
- [ ] Edit existing preset
- [ ] Delete preset
- [ ] Set/unset default preset
- [ ] Apply preset to deck
- [ ] Visual diff shows changes correctly
- [ ] Migration preserves legacy settings
- [ ] Export/import preset JSON
