//
//  CustomizationService.swift
//  CoreDomain
//
//  Phase 2: Service layer for preset and customization management
//  Handles preset CRUD, customization application, and diffing
//

import SwiftData
import Foundation

/// Service for managing deck presets and customizations
/// Aggregates template + customizations for deck building
@MainActor
public class CustomizationService {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Preset Management

    /// Get all presets
    public func getPresets() throws -> [DeckPreset] {
        let descriptor = FetchDescriptor<DeckPreset>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    /// Get default preset (if exists)
    public func getDefaultPreset() throws -> DeckPreset? {
        let descriptor = FetchDescriptor<DeckPreset>(
            predicate: #Predicate { $0.isDefault == true }
        )
        return try context.fetch(descriptor).first
    }

    /// Create a new preset
    public func createPreset(
        name: String,
        description: String,
        isDefault: Bool = false,
        basedOn existingPreset: DeckPreset? = nil
    ) async throws -> DeckPreset {
        // If setting as default, unset other defaults
        if isDefault {
            try unsetAllDefaults()
        }

        let preset = DeckPreset(
            name: name,
            description: description,
            isDefault: isDefault
        )

        // Copy customizations from existing preset if provided
        if let existing = existingPreset {
            for customization in existing.customizations {
                guard let definition = customization.definition else { continue }

                let newCustomization = DeckCustomization(
                    definition: definition,
                    isEnabled: customization.isEnabled
                )
                newCustomization.customCount = customization.customCount
                newCustomization.priority = customization.priority
                newCustomization.notes = customization.notes
                newCustomization.ownerPreset = preset

                context.insert(newCustomization)
            }
        }

        context.insert(preset)
        try context.save()

        return preset
    }

    /// Delete a preset
    public func deletePreset(_ preset: DeckPreset) async throws {
        // Don't allow deleting the last preset if it's default
        if preset.isDefault {
            let allPresets = try getPresets()
            if allPresets.count == 1 {
                throw CustomizationError.cannotDeleteLastDefault
            }
        }

        context.delete(preset)
        try context.save()
    }

    /// Set a preset as default
    public func setDefaultPreset(_ preset: DeckPreset) async throws {
        try unsetAllDefaults()
        preset.isDefault = true
        preset.lastUsed = Date()
        try context.save()
    }

    /// Update preset last used timestamp
    public func markPresetUsed(_ preset: DeckPreset) async throws {
        preset.lastUsed = Date()
        try context.save()
    }

    // MARK: - Session Override Management

    /// Create or get session override for a game session
    public func getOrCreateSessionOverride(for session: GameSession) throws -> SessionDeckOverride {
        if let existing = session.sessionDeckOverride {
            return existing
        }

        let override = SessionDeckOverride()
        context.insert(override)
        session.sessionDeckOverride = override
        try context.save()

        return override
    }

    /// Clear session override from a game session
    public func clearSessionOverride(for session: GameSession) throws {
        guard let override = session.sessionDeckOverride else { return }

        context.delete(override)
        session.sessionDeckOverride = nil
        try context.save()
    }

    /// Check if session has any overrides active
    public func hasSessionOverrides(for session: GameSession) -> Bool {
        guard let override = session.sessionDeckOverride else { return false }
        return !override.customizations.isEmpty
    }

    // MARK: - Customization Application

    /// Get effective count for a weapon (considers preset + session override)
    /// Session override takes precedence over preset
    public func getEffectiveCount(
        for definition: WeaponDefinition,
        preset: DeckPreset?,
        sessionOverride: SessionDeckOverride? = nil
    ) -> Int {
        // Check session override first (highest priority)
        if let sessionOverride = sessionOverride,
           let customization = sessionOverride.customizations.first(where: { $0.definition?.id == definition.id }) {
            return customization.customCount ?? definition.defaultCount
        }

        // Check preset next
        if let preset = preset,
           let customization = preset.customizations.first(where: { $0.definition?.id == definition.id }) {
            return customization.customCount ?? definition.defaultCount
        }

        // Default
        return definition.defaultCount
    }

    /// Check if weapon is enabled (considers preset + session override)
    /// Session override takes precedence over preset
    public func isEnabled(
        definition: WeaponDefinition,
        in preset: DeckPreset?,
        sessionOverride: SessionDeckOverride? = nil
    ) -> Bool {
        // Check session override first (highest priority)
        if let sessionOverride = sessionOverride,
           let customization = sessionOverride.customizations.first(where: { $0.definition?.id == definition.id }) {
            return customization.isEnabled
        }

        // Check preset next
        if let preset = preset,
           let customization = preset.customizations.first(where: { $0.definition?.id == definition.id }) {
            return customization.isEnabled
        }

        // Default: enabled
        return true
    }

    /// Apply customizations to filter and adjust weapon definitions
    /// Supports both preset and session override (session override takes precedence)
    public func applyCustomizations(
        to definitions: [WeaponDefinition],
        preset: DeckPreset?,
        sessionOverride: SessionDeckOverride? = nil
    ) -> [(definition: WeaponDefinition, effectiveCount: Int)] {
        return definitions.compactMap { definition in
            // Skip deprecated weapons
            guard !definition.isDeprecated else { return nil }

            // Check if enabled (session override takes precedence)
            guard isEnabled(definition: definition, in: preset, sessionOverride: sessionOverride) else { return nil }

            // Get effective count (session override takes precedence)
            let count = getEffectiveCount(for: definition, preset: preset, sessionOverride: sessionOverride)

            // Skip if count is 0
            guard count > 0 else { return nil }

            return (definition, count)
        }
    }

    // MARK: - Customization CRUD

    /// Create or update customization for a weapon in a preset
    public func setCustomization(
        for definition: WeaponDefinition,
        in preset: DeckPreset,
        isEnabled: Bool? = nil,
        customCount: Int? = nil,
        notes: String? = nil
    ) async throws {
        // Find existing customization
        if let existing = preset.customizations.first(where: { $0.definition?.id == definition.id }) {
            // Update existing
            if let isEnabled = isEnabled {
                existing.isEnabled = isEnabled
            }
            if let customCount = customCount {
                existing.customCount = customCount
            }
            if let notes = notes {
                existing.notes = notes
            }
        } else {
            // Create new
            let customization = DeckCustomization(
                definition: definition,
                isEnabled: isEnabled ?? true
            )
            customization.customCount = customCount
            customization.notes = notes
            customization.ownerPreset = preset

            context.insert(customization)
        }

        try context.save()
    }

    /// Remove customization for a weapon (revert to default)
    public func removeCustomization(
        for definition: WeaponDefinition,
        in preset: DeckPreset
    ) async throws {
        if let customization = preset.customizations.first(where: { $0.definition?.id == definition.id }) {
            context.delete(customization)
            try context.save()
        }
    }

    // MARK: - Session Override Customization CRUD

    /// Create or update customization for a weapon in a session override
    public func setSessionOverrideCustomization(
        for definition: WeaponDefinition,
        in sessionOverride: SessionDeckOverride,
        isEnabled: Bool? = nil,
        customCount: Int? = nil,
        notes: String? = nil
    ) async throws {
        // Find existing customization
        if let existing = sessionOverride.customizations.first(where: { $0.definition?.id == definition.id }) {
            // Update existing
            if let isEnabled = isEnabled {
                existing.isEnabled = isEnabled
            }
            if let customCount = customCount {
                existing.customCount = customCount
            }
            if let notes = notes {
                existing.notes = notes
            }
        } else {
            // Create new
            let customization = DeckCustomization(
                definition: definition,
                isEnabled: isEnabled ?? true
            )
            customization.customCount = customCount
            customization.notes = notes
            customization.ownerPreset = nil  // Session override, not preset

            context.insert(customization)
            sessionOverride.customizations.append(customization)
        }

        try context.save()
    }

    /// Remove customization from session override (revert to preset/default)
    public func removeSessionOverrideCustomization(
        for definition: WeaponDefinition,
        in sessionOverride: SessionDeckOverride
    ) async throws {
        if let customization = sessionOverride.customizations.first(where: { $0.definition?.id == definition.id }) {
            context.delete(customization)
            try context.save()
        }
    }

    // MARK: - Diffing

    /// Diff structure for preset comparison
    public struct CustomizationDiff {
        public let weaponName: String
        public let weaponSet: String
        public let type: DiffType
        public let defaultCount: Int
        public let customCount: Int?
        public let isEnabled: Bool

        public enum DiffType {
            case countChanged
            case disabled
            case enabled
        }

        public init(weaponName: String, weaponSet: String, type: DiffType, defaultCount: Int, customCount: Int?, isEnabled: Bool) {
            self.weaponName = weaponName
            self.weaponSet = weaponSet
            self.type = type
            self.defaultCount = defaultCount
            self.customCount = customCount
            self.isEnabled = isEnabled
        }
    }

    /// Calculate diffs from default configuration
    public func diffsFromDefault(preset: DeckPreset) throws -> [CustomizationDiff] {
        var diffs: [CustomizationDiff] = []

        for customization in preset.customizations {
            guard let definition = customization.definition else { continue }

            // Count changed
            if let customCount = customization.customCount,
               customCount != definition.defaultCount {
                diffs.append(CustomizationDiff(
                    weaponName: definition.name,
                    weaponSet: definition.set,
                    type: .countChanged,
                    defaultCount: definition.defaultCount,
                    customCount: customCount,
                    isEnabled: customization.isEnabled
                ))
            }

            // Disabled
            if !customization.isEnabled {
                diffs.append(CustomizationDiff(
                    weaponName: definition.name,
                    weaponSet: definition.set,
                    type: .disabled,
                    defaultCount: definition.defaultCount,
                    customCount: customization.customCount,
                    isEnabled: false
                ))
            }
        }

        return diffs.sorted { $0.weaponName < $1.weaponName }
    }

    /// Calculate diffs for session override from its base preset (or default if no preset)
    public func sessionOverrideDiffs(
        sessionOverride: SessionDeckOverride,
        basePreset: DeckPreset?
    ) throws -> [CustomizationDiff] {
        var diffs: [CustomizationDiff] = []

        for customization in sessionOverride.customizations {
            guard let definition = customization.definition else { continue }

            // Get what the preset says (or default)
            let presetCount = basePreset?.customizations
                .first(where: { $0.definition?.id == definition.id })?.customCount ?? definition.defaultCount
            let presetEnabled = basePreset?.customizations
                .first(where: { $0.definition?.id == definition.id })?.isEnabled ?? true

            // Count changed from preset
            if let customCount = customization.customCount,
               customCount != presetCount {
                diffs.append(CustomizationDiff(
                    weaponName: definition.name,
                    weaponSet: definition.set,
                    type: .countChanged,
                    defaultCount: presetCount,
                    customCount: customCount,
                    isEnabled: customization.isEnabled
                ))
            }

            // Enabled/disabled state changed from preset
            if customization.isEnabled != presetEnabled {
                diffs.append(CustomizationDiff(
                    weaponName: definition.name,
                    weaponSet: definition.set,
                    type: customization.isEnabled ? .enabled : .disabled,
                    defaultCount: presetCount,
                    customCount: customization.customCount,
                    isEnabled: customization.isEnabled
                ))
            }
        }

        return diffs.sorted { $0.weaponName < $1.weaponName }
    }

    // MARK: - Export/Import

    /// Exportable preset data structure
    public struct PresetExportData: Codable {
        public let name: String
        public let description: String
        public let customizations: [CustomizationExportData]

        public struct CustomizationExportData: Codable {
            public let weaponID: String  // Deterministic ID
            public let isEnabled: Bool
            public let customCount: Int?
            public let notes: String?
        }
    }

    /// Export preset to JSON data
    public func exportPreset(_ preset: DeckPreset) throws -> Data {
        let customizationData = preset.customizations.compactMap { customization -> PresetExportData.CustomizationExportData? in
            guard let definition = customization.definition else { return nil }

            return PresetExportData.CustomizationExportData(
                weaponID: definition.id,
                isEnabled: customization.isEnabled,
                customCount: customization.customCount,
                notes: customization.notes
            )
        }

        let exportData = PresetExportData(
            name: preset.name,
            description: preset.presetDescription,
            customizations: customizationData
        )

        return try JSONEncoder().encode(exportData)
    }

    /// Import preset from JSON data
    public func importPreset(from data: Data, setAsDefault: Bool = false) async throws -> DeckPreset {
        let exportData = try JSONDecoder().decode(PresetExportData.self, from: data)

        // Create preset
        let preset = DeckPreset(
            name: exportData.name,
            description: exportData.description,
            isDefault: setAsDefault
        )

        if setAsDefault {
            try unsetAllDefaults()
        }

        context.insert(preset)

        // Import customizations
        for customizationData in exportData.customizations {
            // Find weapon definition
            let descriptor = FetchDescriptor<WeaponDefinition>(
                predicate: #Predicate { $0.id == customizationData.weaponID }
            )

            guard let definition = try context.fetch(descriptor).first else {
                print("⚠️ Skipping customization for unknown weapon: \(customizationData.weaponID)")
                continue
            }

            let customization = DeckCustomization(
                definition: definition,
                isEnabled: customizationData.isEnabled
            )
            customization.customCount = customizationData.customCount
            customization.notes = customizationData.notes
            customization.ownerPreset = preset

            context.insert(customization)
        }

        try context.save()
        return preset
    }

    // MARK: - Private Helpers

    /// Unset all default presets
    private func unsetAllDefaults() throws {
        let descriptor = FetchDescriptor<DeckPreset>(
            predicate: #Predicate { $0.isDefault == true }
        )
        let defaults = try context.fetch(descriptor)
        for preset in defaults {
            preset.isDefault = false
        }
    }
}

// MARK: - Errors

public enum CustomizationError: LocalizedError {
    case cannotDeleteLastDefault

    public var errorDescription: String? {
        switch self {
        case .cannotDeleteLastDefault:
            return "Cannot delete the last default preset"
        }
    }
}
