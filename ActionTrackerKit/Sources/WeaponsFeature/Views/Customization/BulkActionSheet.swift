//
//  BulkActionSheet.swift
//  WeaponsFeature
//
//  Bulk actions for enabling/disabling weapons
//

import SwiftUI
import CoreDomain

public struct BulkActionSheet: View {
    @Environment(\.dismiss) private var dismiss

    let preset: DeckPreset
    let sessionOverride: SessionDeckOverride?
    let weaponsBySet: [String: [WeaponDefinition]]
    let customizationService: CustomizationService
    let onChanged: () -> Void

    @State private var isProcessing = false

    public init(
        preset: DeckPreset,
        sessionOverride: SessionDeckOverride?,
        weaponsBySet: [String: [WeaponDefinition]],
        customizationService: CustomizationService,
        onChanged: @escaping () -> Void
    ) {
        self.preset = preset
        self.sessionOverride = sessionOverride
        self.weaponsBySet = weaponsBySet
        self.customizationService = customizationService
        self.onChanged = onChanged
    }

    private var sortedSets: [String] {
        weaponsBySet.keys.sorted()
    }

    public var body: some View {
        NavigationStack {
            List {
                // Global Actions
                Section("All Weapons") {
                    Button {
                        Task {
                            await bulkAction(enableAll: true)
                        }
                    } label: {
                        Label("Enable All", systemImage: "checkmark.circle")
                    }
                    .disabled(isProcessing)

                    Button {
                        Task {
                            await bulkAction(enableAll: false)
                        }
                    } label: {
                        Label("Disable All", systemImage: "xmark.circle")
                    }
                    .disabled(isProcessing)
                }

                // By Expansion Set
                Section("By Expansion Set") {
                    ForEach(sortedSets, id: \.self) { set in
                        HStack {
                            Text(set)

                            Spacer()

                            Button {
                                Task {
                                    await bulkActionForSet(set, enable: true)
                                }
                            } label: {
                                Image(systemName: "checkmark.circle")
                                    .foregroundStyle(.green)
                            }
                            .buttonStyle(.plain)
                            .disabled(isProcessing)

                            Button {
                                Task {
                                    await bulkActionForSet(set, enable: false)
                                }
                            } label: {
                                Image(systemName: "xmark.circle")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                            .disabled(isProcessing)
                        }
                    }
                }

                // By Deck Type
                Section("By Deck Type") {
                    ForEach(["Starting", "Regular", "Ultrared"], id: \.self) { deckType in
                        HStack {
                            Text(deckType)

                            Spacer()

                            Button {
                                Task {
                                    await bulkActionForDeckType(deckType, enable: true)
                                }
                            } label: {
                                Image(systemName: "checkmark.circle")
                                    .foregroundStyle(.green)
                            }
                            .buttonStyle(.plain)
                            .disabled(isProcessing)

                            Button {
                                Task {
                                    await bulkActionForDeckType(deckType, enable: false)
                                }
                            } label: {
                                Image(systemName: "xmark.circle")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                            .disabled(isProcessing)
                        }
                    }
                }
            }
            .navigationTitle("Bulk Actions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .disabled(isProcessing)
                }
            }
            .overlay {
                if isProcessing {
                    ProgressView("Processing...")
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private func bulkAction(enableAll: Bool) async {
        isProcessing = true
        defer { isProcessing = false }

        let allWeapons = weaponsBySet.values.flatMap { $0 }

        for weapon in allWeapons {
            if let override = sessionOverride {
                try? await customizationService.setSessionOverrideCustomization(
                    for: weapon,
                    in: override,
                    isEnabled: enableAll
                )
            } else {
                try? await customizationService.setCustomization(
                    for: weapon,
                    in: preset,
                    isEnabled: enableAll
                )
            }
        }

        onChanged()
        dismiss()
    }

    private func bulkActionForSet(_ set: String, enable: Bool) async {
        isProcessing = true
        defer { isProcessing = false }

        guard let weapons = weaponsBySet[set] else { return }

        for weapon in weapons {
            if let override = sessionOverride {
                try? await customizationService.setSessionOverrideCustomization(
                    for: weapon,
                    in: override,
                    isEnabled: enable
                )
            } else {
                try? await customizationService.setCustomization(
                    for: weapon,
                    in: preset,
                    isEnabled: enable
                )
            }
        }

        onChanged()
        dismiss()
    }

    private func bulkActionForDeckType(_ deckType: String, enable: Bool) async {
        isProcessing = true
        defer { isProcessing = false }

        let weaponsInDeckType = weaponsBySet.values.flatMap { $0 }.filter { $0.deckType == deckType }

        for weapon in weaponsInDeckType {
            if let override = sessionOverride {
                try? await customizationService.setSessionOverrideCustomization(
                    for: weapon,
                    in: override,
                    isEnabled: enable
                )
            } else {
                try? await customizationService.setCustomization(
                    for: weapon,
                    in: preset,
                    isEnabled: enable
                )
            }
        }

        onChanged()
        dismiss()
    }
}
