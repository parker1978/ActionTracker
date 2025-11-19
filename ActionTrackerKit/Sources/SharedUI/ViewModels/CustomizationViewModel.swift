//
//  CustomizationViewModel.swift
//  SharedUI
//
//  Phase 4: View model for deck customization and preset management
//  Wraps CustomizationService and provides @Published state for SwiftUI
//

import SwiftUI
import SwiftData
import CoreDomain
import Observation

/// View model for deck customization and preset management
/// Wraps CustomizationService and manages preset state for UI
@MainActor
@Observable
public final class CustomizationViewModel {
    private let customizationService: CustomizationService
    private let context: ModelContext

    // Published state for UI
    public var presets: [DeckPreset] = []
    public var selectedPreset: DeckPreset?
    public var sessionOverride: SessionDeckOverride?
    public var isLoading = false
    public var errorMessage: String?

    // Computed properties
    public var hasPresets: Bool {
        !presets.isEmpty
    }

    public var defaultPreset: DeckPreset? {
        presets.first { $0.isDefault }
    }

    public init(customizationService: CustomizationService, context: ModelContext) {
        self.customizationService = customizationService
        self.context = context
    }

    // MARK: - Loading

    /// Load all presets
    public func loadPresets() {
        do {
            presets = try customizationService.getPresets()
            selectedPreset = defaultPreset
        } catch {
            errorMessage = "Failed to load presets: \(error.localizedDescription)"
        }
    }

    /// Load session override for a game session
    public func loadSessionOverride(for session: GameSession) {
        sessionOverride = session.sessionDeckOverride
    }

    // MARK: - Preset Management

    /// Create a new preset
    public func createPreset(
        name: String,
        description: String,
        isDefault: Bool = false,
        basedOn existingPreset: DeckPreset? = nil
    ) async {
        isLoading = true
        errorMessage = nil

        do {
            let preset = try await customizationService.createPreset(
                name: name,
                description: description,
                isDefault: isDefault,
                basedOn: existingPreset
            )
            loadPresets()
            selectedPreset = preset
        } catch {
            errorMessage = "Failed to create preset: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Delete a preset
    public func deletePreset(_ preset: DeckPreset) async {
        isLoading = true
        errorMessage = nil

        do {
            try await customizationService.deletePreset(preset)
            loadPresets()
        } catch {
            errorMessage = "Failed to delete preset: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Set a preset as default
    public func setDefaultPreset(_ preset: DeckPreset) async {
        isLoading = true
        errorMessage = nil

        do {
            try await customizationService.setDefaultPreset(preset)
            loadPresets()
        } catch {
            errorMessage = "Failed to set default preset: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Mark preset as used (updates lastUsed timestamp)
    public func markPresetUsed(_ preset: DeckPreset) async {
        do {
            try await customizationService.markPresetUsed(preset)
        } catch {
            print("⚠️ Failed to mark preset as used: \(error)")
        }
    }

    // MARK: - Session Override Management

    /// Create or get session override
    public func getOrCreateSessionOverride(for session: GameSession) {
        do {
            sessionOverride = try customizationService.getOrCreateSessionOverride(for: session)
        } catch {
            errorMessage = "Failed to create session override: \(error.localizedDescription)"
        }
    }

    /// Clear session override
    public func clearSessionOverride(for session: GameSession) {
        do {
            try customizationService.clearSessionOverride(for: session)
            sessionOverride = nil
        } catch {
            errorMessage = "Failed to clear session override: \(error.localizedDescription)"
        }
    }

    /// Check if session has overrides
    public func hasSessionOverrides(for session: GameSession) -> Bool {
        return customizationService.hasSessionOverrides(for: session)
    }

    // MARK: - Customization Application

    /// Get effective count for a weapon
    public func getEffectiveCount(
        for definition: WeaponDefinition,
        preset: DeckPreset? = nil,
        sessionOverride: SessionDeckOverride? = nil
    ) -> Int {
        return customizationService.getEffectiveCount(
            for: definition,
            preset: preset ?? selectedPreset,
            sessionOverride: sessionOverride ?? self.sessionOverride
        )
    }

    /// Check if weapon is enabled
    public func isEnabled(
        definition: WeaponDefinition,
        in preset: DeckPreset? = nil,
        sessionOverride: SessionDeckOverride? = nil
    ) -> Bool {
        return customizationService.isEnabled(
            definition: definition,
            in: preset ?? selectedPreset,
            sessionOverride: sessionOverride ?? self.sessionOverride
        )
    }

    /// Apply customizations to filter weapon definitions
    public func applyCustomizations(
        to definitions: [WeaponDefinition],
        preset: DeckPreset? = nil,
        sessionOverride: SessionDeckOverride? = nil
    ) -> [(definition: WeaponDefinition, effectiveCount: Int)] {
        return customizationService.applyCustomizations(
            to: definitions,
            preset: preset ?? selectedPreset,
            sessionOverride: sessionOverride ?? self.sessionOverride
        )
    }

    // MARK: - Customization CRUD

    /// Set customization for a weapon in a preset
    public func setCustomization(
        for definition: WeaponDefinition,
        in preset: DeckPreset,
        isEnabled: Bool? = nil,
        customCount: Int? = nil,
        notes: String? = nil
    ) async {
        do {
            try await customizationService.setCustomization(
                for: definition,
                in: preset,
                isEnabled: isEnabled,
                customCount: customCount,
                notes: notes
            )
        } catch {
            errorMessage = "Failed to set customization: \(error.localizedDescription)"
        }
    }

    /// Remove customization (revert to default)
    public func removeCustomization(
        for definition: WeaponDefinition,
        in preset: DeckPreset
    ) async {
        do {
            try await customizationService.removeCustomization(
                for: definition,
                in: preset
            )
        } catch {
            errorMessage = "Failed to remove customization: \(error.localizedDescription)"
        }
    }

    // MARK: - Diffing

    /// Calculate diffs from default configuration
    public func diffsFromDefault(preset: DeckPreset) -> [CustomizationService.CustomizationDiff] {
        do {
            return try customizationService.diffsFromDefault(preset: preset)
        } catch {
            errorMessage = "Failed to calculate diffs: \(error.localizedDescription)"
            return []
        }
    }

    /// Calculate diffs for session override
    public func sessionOverrideDiffs(
        sessionOverride: SessionDeckOverride,
        basePreset: DeckPreset?
    ) -> [CustomizationService.CustomizationDiff] {
        do {
            return try customizationService.sessionOverrideDiffs(
                sessionOverride: sessionOverride,
                basePreset: basePreset
            )
        } catch {
            errorMessage = "Failed to calculate session override diffs: \(error.localizedDescription)"
            return []
        }
    }

    // MARK: - Export/Import

    /// Export preset to JSON
    public func exportPreset(_ preset: DeckPreset) -> Data? {
        do {
            return try customizationService.exportPreset(preset)
        } catch {
            errorMessage = "Failed to export preset: \(error.localizedDescription)"
            return nil
        }
    }

    /// Import preset from JSON
    public func importPreset(from data: Data, setAsDefault: Bool = false) async {
        isLoading = true
        errorMessage = nil

        do {
            let preset = try await customizationService.importPreset(from: data, setAsDefault: setAsDefault)
            loadPresets()
            selectedPreset = preset
        } catch {
            errorMessage = "Failed to import preset: \(error.localizedDescription)"
        }

        isLoading = false
    }
}
