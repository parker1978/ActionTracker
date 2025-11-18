//
//  CustomizationServiceTests.swift
//  CoreDomainTests
//
//  Tests for CustomizationService
//  Validates preset CRUD, customization application, and export/import
//

import Testing
import SwiftData
import Foundation
@testable import CoreDomain

@MainActor
struct CustomizationServiceTests {

    // MARK: - Test Setup

    private func createTestContainer() -> ModelContainer {
        let schema = Schema([
            WeaponDefinition.self,
            WeaponCardInstance.self,
            DeckRuntimeState.self,
            GameSession.self,
            Character.self,
            DeckPreset.self,
            DeckCustomization.self,
            WeaponInventoryItem.self,
            InventoryEvent.self
        ])

        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [configuration])
    }

    private func createTestService(container: ModelContainer) -> CustomizationService {
        let context = ModelContext(container)
        return CustomizationService(context: context)
    }

    private func createTestWeaponDefinitions(context: ModelContext, count: Int = 3) -> [WeaponDefinition] {
        var definitions: [WeaponDefinition] = []

        for i in 0..<count {
            let definition = WeaponDefinition(
                name: "Weapon\(i)",
                set: "Test Set",
                deckType: "regular",
                defaultCount: 2,
                combatStats: "{}"
            )
            context.insert(definition)
            definitions.append(definition)
        }

        try! context.save()
        return definitions
    }

    // MARK: - Preset Management Tests

    @Test func testCreatePreset() async throws {
        let container = createTestContainer()
        let service = createTestService(container: container)

        let preset = try await service.createPreset(
            name: "Test Preset",
            description: "A test preset",
            isDefault: false
        )

        #expect(preset.name == "Test Preset")
        #expect(preset.presetDescription == "A test preset")
        #expect(!preset.isDefault)
        #expect(preset.customizations.isEmpty)
    }

    @Test func testCreatePresetAsDefault() async throws {
        let container = createTestContainer()
        let service = createTestService(container: container)

        let preset = try await service.createPreset(
            name: "Default Preset",
            description: "Default",
            isDefault: true
        )

        #expect(preset.isDefault)

        // Create second default, should unset first
        let preset2 = try await service.createPreset(
            name: "New Default",
            description: "New",
            isDefault: true
        )

        #expect(preset2.isDefault)
        #expect(!preset.isDefault, "First preset should no longer be default")
    }

    @Test func testCreatePresetBasedOnExisting() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let service = createTestService(container: container)

        let definitions = createTestWeaponDefinitions(context: context, count: 2)

        // Create original preset with customizations
        let original = try await service.createPreset(
            name: "Original",
            description: "Original preset",
            isDefault: false
        )

        try await service.setCustomization(
            for: definitions[0],
            in: original,
            isEnabled: false,
            customCount: 5,
            notes: "Test note"
        )

        // Create copy
        let copy = try await service.createPreset(
            name: "Copy",
            description: "Copied preset",
            isDefault: false,
            basedOn: original
        )

        #expect(copy.customizations.count == 1)

        let copiedCustomization = copy.customizations.first
        #expect(copiedCustomization?.isEnabled == false)
        #expect(copiedCustomization?.customCount == 5)
        #expect(copiedCustomization?.notes == "Test note")
    }

    @Test func testGetPresets() async throws {
        let container = createTestContainer()
        let service = createTestService(container: container)

        let initialPresets = try service.getPresets()
        #expect(initialPresets.isEmpty)

        _ = try await service.createPreset(name: "Preset 1", description: "First", isDefault: false)
        _ = try await service.createPreset(name: "Preset 2", description: "Second", isDefault: false)

        let presets = try service.getPresets()
        #expect(presets.count == 2)
    }

    @Test func testGetDefaultPreset() async throws {
        let container = createTestContainer()
        let service = createTestService(container: container)

        let noDefault = try service.getDefaultPreset()
        #expect(noDefault == nil)

        _ = try await service.createPreset(name: "Not Default", description: "No", isDefault: false)
        let stillNoDefault = try service.getDefaultPreset()
        #expect(stillNoDefault == nil)

        let defaultPreset = try await service.createPreset(name: "Default", description: "Yes", isDefault: true)
        let foundDefault = try service.getDefaultPreset()
        #expect(foundDefault?.id == defaultPreset.id)
    }

    @Test func testDeletePreset() async throws {
        let container = createTestContainer()
        let service = createTestService(container: container)

        let preset = try await service.createPreset(name: "To Delete", description: "Test", isDefault: false)

        var presets = try service.getPresets()
        #expect(presets.count == 1)

        try await service.deletePreset(preset)

        presets = try service.getPresets()
        #expect(presets.isEmpty)
    }

    @Test func testDeletePresetFailsForLastDefault() async throws {
        let container = createTestContainer()
        let service = createTestService(container: container)

        let preset = try await service.createPreset(name: "Only Default", description: "Test", isDefault: true)

        do {
            try await service.deletePreset(preset)
            #expect(Bool(false), "Should have thrown error")
        } catch {
            #expect(error is CustomizationError)
        }
    }

    @Test func testSetDefaultPreset() async throws {
        let container = createTestContainer()
        let service = createTestService(container: container)

        let preset1 = try await service.createPreset(name: "Preset 1", description: "First", isDefault: true)
        let preset2 = try await service.createPreset(name: "Preset 2", description: "Second", isDefault: false)

        #expect(preset1.isDefault)
        #expect(!preset2.isDefault)

        try await service.setDefaultPreset(preset2)

        #expect(!preset1.isDefault)
        #expect(preset2.isDefault)
        #expect(preset2.lastUsed != nil)
    }

    @Test func testMarkPresetUsed() async throws {
        let container = createTestContainer()
        let service = createTestService(container: container)

        let preset = try await service.createPreset(name: "Test", description: "Test", isDefault: false)

        let initialLastUsed = preset.lastUsed

        try await service.markPresetUsed(preset)

        #expect(preset.lastUsed != initialLastUsed)
    }

    // MARK: - Customization Application Tests

    @Test func testGetEffectiveCountWithoutPreset() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let service = createTestService(container: container)

        let definitions = createTestWeaponDefinitions(context: context, count: 1)
        let definition = definitions[0]

        let count = service.getEffectiveCount(for: definition, preset: nil)

        #expect(count == definition.defaultCount)
    }

    @Test func testGetEffectiveCountWithCustomization() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let service = createTestService(container: container)

        let definitions = createTestWeaponDefinitions(context: context, count: 1)
        let definition = definitions[0]

        let preset = try await service.createPreset(name: "Test", description: "Test", isDefault: false)

        try await service.setCustomization(
            for: definition,
            in: preset,
            customCount: 5
        )

        let count = service.getEffectiveCount(for: definition, preset: preset)

        #expect(count == 5)
    }

    @Test func testIsEnabledWithoutPreset() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let service = createTestService(container: container)

        let definitions = createTestWeaponDefinitions(context: context, count: 1)

        let enabled = service.isEnabled(definition: definitions[0], in: nil)

        #expect(enabled, "Should be enabled by default without preset")
    }

    @Test func testIsEnabledWithDisabledCustomization() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let service = createTestService(container: container)

        let definitions = createTestWeaponDefinitions(context: context, count: 1)
        let definition = definitions[0]

        let preset = try await service.createPreset(name: "Test", description: "Test", isDefault: false)

        try await service.setCustomization(
            for: definition,
            in: preset,
            isEnabled: false
        )

        let enabled = service.isEnabled(definition: definition, in: preset)

        #expect(!enabled)
    }

    @Test func testApplyCustomizationsFiltersDisabled() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let service = createTestService(container: container)

        let definitions = createTestWeaponDefinitions(context: context, count: 3)

        let preset = try await service.createPreset(name: "Test", description: "Test", isDefault: false)

        // Disable second weapon
        try await service.setCustomization(
            for: definitions[1],
            in: preset,
            isEnabled: false
        )

        let result = service.applyCustomizations(to: definitions, preset: preset)

        #expect(result.count == 2, "Should filter out disabled weapon")
        #expect(result.allSatisfy { $0.definition.name != "Weapon1" })
    }

    @Test func testApplyCustomizationsFiltersZeroCount() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let service = createTestService(container: container)

        let definitions = createTestWeaponDefinitions(context: context, count: 3)

        let preset = try await service.createPreset(name: "Test", description: "Test", isDefault: false)

        // Set count to 0
        try await service.setCustomization(
            for: definitions[1],
            in: preset,
            customCount: 0
        )

        let result = service.applyCustomizations(to: definitions, preset: preset)

        #expect(result.count == 2, "Should filter out zero-count weapon")
    }

    @Test func testApplyCustomizationsUsesCustomCounts() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let service = createTestService(container: container)

        let definitions = createTestWeaponDefinitions(context: context, count: 2)

        let preset = try await service.createPreset(name: "Test", description: "Test", isDefault: false)

        try await service.setCustomization(
            for: definitions[0],
            in: preset,
            customCount: 10
        )

        let result = service.applyCustomizations(to: definitions, preset: preset)

        let customized = result.first { $0.definition.id == definitions[0].id }
        #expect(customized?.effectiveCount == 10)
    }

    @Test func testApplyCustomizationsFiltersDeprecated() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let service = createTestService(container: container)

        let definitions = createTestWeaponDefinitions(context: context, count: 2)
        definitions[1].isDeprecated = true
        try context.save()

        let result = service.applyCustomizations(to: definitions, preset: nil)

        #expect(result.count == 1, "Should filter deprecated weapons")
        #expect(!result[0].definition.isDeprecated)
    }

    // MARK: - Customization CRUD Tests

    @Test func testSetCustomizationCreatesNew() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let service = createTestService(container: container)

        let definitions = createTestWeaponDefinitions(context: context, count: 1)
        let preset = try await service.createPreset(name: "Test", description: "Test", isDefault: false)

        #expect(preset.customizations.isEmpty)

        try await service.setCustomization(
            for: definitions[0],
            in: preset,
            isEnabled: true,
            customCount: 5,
            notes: "Test note"
        )

        #expect(preset.customizations.count == 1)

        let customization = preset.customizations.first!
        #expect(customization.isEnabled)
        #expect(customization.customCount == 5)
        #expect(customization.notes == "Test note")
    }

    @Test func testSetCustomizationUpdatesExisting() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let service = createTestService(container: container)

        let definitions = createTestWeaponDefinitions(context: context, count: 1)
        let preset = try await service.createPreset(name: "Test", description: "Test", isDefault: false)

        try await service.setCustomization(
            for: definitions[0],
            in: preset,
            customCount: 5
        )

        try await service.setCustomization(
            for: definitions[0],
            in: preset,
            customCount: 10
        )

        #expect(preset.customizations.count == 1, "Should update, not create new")

        let customization = preset.customizations.first!
        #expect(customization.customCount == 10)
    }

    @Test func testRemoveCustomization() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let service = createTestService(container: container)

        let definitions = createTestWeaponDefinitions(context: context, count: 1)
        let preset = try await service.createPreset(name: "Test", description: "Test", isDefault: false)

        try await service.setCustomization(
            for: definitions[0],
            in: preset,
            customCount: 5
        )

        #expect(preset.customizations.count == 1)

        try await service.removeCustomization(for: definitions[0], in: preset)

        #expect(preset.customizations.isEmpty)
    }

    // MARK: - Diffing Tests

    @Test func testDiffsFromDefaultEmpty() async throws {
        let container = createTestContainer()
        let service = createTestService(container: container)

        let preset = try await service.createPreset(name: "Test", description: "Test", isDefault: false)

        let diffs = try service.diffsFromDefault(preset: preset)

        #expect(diffs.isEmpty)
    }

    @Test func testDiffsFromDefaultCountChanged() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let service = createTestService(container: container)

        let definitions = createTestWeaponDefinitions(context: context, count: 1)
        let definition = definitions[0]

        let preset = try await service.createPreset(name: "Test", description: "Test", isDefault: false)

        try await service.setCustomization(
            for: definition,
            in: preset,
            customCount: 10
        )

        let diffs = try service.diffsFromDefault(preset: preset)

        #expect(diffs.count == 1)
        #expect(diffs[0].type == .countChanged)
        #expect(diffs[0].defaultCount == definition.defaultCount)
        #expect(diffs[0].customCount == 10)
    }

    @Test func testDiffsFromDefaultDisabled() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let service = createTestService(container: container)

        let definitions = createTestWeaponDefinitions(context: context, count: 1)

        let preset = try await service.createPreset(name: "Test", description: "Test", isDefault: false)

        try await service.setCustomization(
            for: definitions[0],
            in: preset,
            isEnabled: false
        )

        let diffs = try service.diffsFromDefault(preset: preset)

        #expect(diffs.count == 1)
        #expect(diffs[0].type == .disabled)
        #expect(!diffs[0].isEnabled)
    }

    // MARK: - Export/Import Tests

    @Test func testExportPreset() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let service = createTestService(container: container)

        let definitions = createTestWeaponDefinitions(context: context, count: 2)

        let preset = try await service.createPreset(
            name: "Export Test",
            description: "Test export",
            isDefault: false
        )

        try await service.setCustomization(
            for: definitions[0],
            in: preset,
            isEnabled: false,
            customCount: 5,
            notes: "Test note"
        )

        let data = try service.exportPreset(preset)

        #expect(!data.isEmpty)

        // Verify it's valid JSON
        let exportData = try JSONDecoder().decode(CustomizationService.PresetExportData.self, from: data)
        #expect(exportData.name == "Export Test")
        #expect(exportData.description == "Test export")
        #expect(exportData.customizations.count == 1)
    }

    @Test func testImportPreset() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let service = createTestService(container: container)

        // Create weapons first
        let definitions = createTestWeaponDefinitions(context: context, count: 2)

        // Create export data
        let exportData = CustomizationService.PresetExportData(
            name: "Imported Preset",
            description: "Imported",
            customizations: [
                CustomizationService.PresetExportData.CustomizationExportData(
                    weaponID: definitions[0].id,
                    isEnabled: false,
                    customCount: 7,
                    notes: "Imported note"
                )
            ]
        )

        let jsonData = try JSONEncoder().encode(exportData)

        let imported = try await service.importPreset(from: jsonData, setAsDefault: false)

        #expect(imported.name == "Imported Preset")
        #expect(imported.presetDescription == "Imported")
        #expect(imported.customizations.count == 1)

        let customization = imported.customizations.first!
        #expect(!customization.isEnabled)
        #expect(customization.customCount == 7)
        #expect(customization.notes == "Imported note")
    }

    @Test func testImportPresetAsDefault() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let service = createTestService(container: container)

        let definitions = createTestWeaponDefinitions(context: context, count: 1)

        // Create existing default
        let existing = try await service.createPreset(name: "Old Default", description: "Old", isDefault: true)

        #expect(existing.isDefault)

        // Import as default
        let exportData = CustomizationService.PresetExportData(
            name: "New Default",
            description: "New",
            customizations: []
        )

        let jsonData = try JSONEncoder().encode(exportData)
        let imported = try await service.importPreset(from: jsonData, setAsDefault: true)

        #expect(imported.isDefault)
        #expect(!existing.isDefault, "Old default should be unset")
    }

    @Test func testImportPresetSkipsUnknownWeapons() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let service = createTestService(container: container)

        // Create only one weapon
        let definitions = createTestWeaponDefinitions(context: context, count: 1)

        // Try to import with unknown weapon ID
        let exportData = CustomizationService.PresetExportData(
            name: "Test",
            description: "Test",
            customizations: [
                CustomizationService.PresetExportData.CustomizationExportData(
                    weaponID: "unknown-weapon-id",
                    isEnabled: true,
                    customCount: 5,
                    notes: nil
                ),
                CustomizationService.PresetExportData.CustomizationExportData(
                    weaponID: definitions[0].id,
                    isEnabled: true,
                    customCount: 3,
                    notes: nil
                )
            ]
        )

        let jsonData = try JSONEncoder().encode(exportData)
        let imported = try await service.importPreset(from: jsonData, setAsDefault: false)

        #expect(imported.customizations.count == 1, "Should skip unknown weapon")
    }

    @Test func testExportImportRoundTrip() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let service = createTestService(container: container)

        let definitions = createTestWeaponDefinitions(context: context, count: 3)

        let original = try await service.createPreset(
            name: "Round Trip Test",
            description: "Test round trip",
            isDefault: false
        )

        // Add customizations
        try await service.setCustomization(for: definitions[0], in: original, isEnabled: false)
        try await service.setCustomization(for: definitions[1], in: original, customCount: 10)
        try await service.setCustomization(for: definitions[2], in: original, customCount: 3, notes: "Note")

        // Export
        let exportData = try service.exportPreset(original)

        // Import
        let imported = try await service.importPreset(from: exportData, setAsDefault: false)

        #expect(imported.name == original.name)
        #expect(imported.presetDescription == original.presetDescription)
        #expect(imported.customizations.count == 3)

        // Verify customizations match
        for customization in original.customizations {
            guard let weaponID = customization.definition?.id else { continue }

            let importedCustomization = imported.customizations.first { $0.definition?.id == weaponID }
            #expect(importedCustomization != nil)
            #expect(importedCustomization?.isEnabled == customization.isEnabled)
            #expect(importedCustomization?.customCount == customization.customCount)
            #expect(importedCustomization?.notes == customization.notes)
        }
    }
}
