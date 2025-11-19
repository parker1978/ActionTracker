//
//  WeaponCustomizationRow.swift
//  WeaponsFeature
//
//  Row for customizing individual weapon (enable/disable, count)
//

import SwiftUI
import CoreDomain

public struct WeaponCustomizationRow: View {
    let weapon: WeaponDefinition
    let preset: DeckPreset
    let sessionOverride: SessionDeckOverride?
    let customizationService: CustomizationService
    let onChanged: () -> Void

    @State private var isEnabled: Bool
    @State private var customCount: Int

    public init(
        weapon: WeaponDefinition,
        preset: DeckPreset,
        sessionOverride: SessionDeckOverride?,
        customizationService: CustomizationService,
        onChanged: @escaping () -> Void
    ) {
        self.weapon = weapon
        self.preset = preset
        self.sessionOverride = sessionOverride
        self.customizationService = customizationService
        self.onChanged = onChanged

        // Initialize state from service
        _isEnabled = State(initialValue: customizationService.isEnabled(
            definition: weapon,
            in: preset,
            sessionOverride: sessionOverride
        ))
        _customCount = State(initialValue: customizationService.getEffectiveCount(
            for: weapon,
            preset: preset,
            sessionOverride: sessionOverride
        ))
    }

    private var hasCustomization: Bool {
        isEnabled != true || customCount != weapon.defaultCount
    }

    public var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(weapon.name)
                    .font(.headline)
                    .foregroundStyle(isEnabled ? .primary : .secondary)

                HStack(spacing: 8) {
                    Text(weapon.category)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if hasCustomization {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 4))
                            .foregroundStyle(.blue)

                        Text("Customized")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
                }
            }

            Spacer()

            // Count Stepper
            Stepper(
                value: $customCount,
                in: 0...10,
                onEditingChanged: { _ in
                    Task {
                        await applyCountChange()
                    }
                }
            ) {
                Text("\(customCount)")
                    .font(.body.monospacedDigit())
                    .foregroundStyle(customCount != weapon.defaultCount ? .blue : .secondary)
                    .frame(minWidth: 30, alignment: .trailing)
            }
            .disabled(!isEnabled)

            // Enable/Disable Toggle
            Toggle("", isOn: $isEnabled)
                .labelsHidden()
                .onChange(of: isEnabled) { _, newValue in
                    Task {
                        await applyEnabledChange(newValue)
                    }
                }
        }
    }

    private func applyEnabledChange(_ enabled: Bool) async {
        if let override = sessionOverride {
            try? await customizationService.setSessionOverrideCustomization(
                for: weapon,
                in: override,
                isEnabled: enabled,
                customCount: customCount != weapon.defaultCount ? customCount : nil
            )
        } else {
            try? await customizationService.setCustomization(
                for: weapon,
                in: preset,
                isEnabled: enabled,
                customCount: customCount != weapon.defaultCount ? customCount : nil
            )
        }
        onChanged()
    }

    private func applyCountChange() async {
        if let override = sessionOverride {
            try? await customizationService.setSessionOverrideCustomization(
                for: weapon,
                in: override,
                isEnabled: isEnabled,
                customCount: customCount != weapon.defaultCount ? customCount : nil
            )
        } else {
            try? await customizationService.setCustomization(
                for: weapon,
                in: preset,
                isEnabled: isEnabled,
                customCount: customCount != weapon.defaultCount ? customCount : nil
            )
        }
        onChanged()
    }
}
