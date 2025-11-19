//
//  PresetPickerView.swift
//  WeaponsFeature
//
//  Preset picker for selecting active preset in a game session
//

import SwiftUI
import SwiftData
import CoreDomain

public struct PresetPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \DeckPreset.lastUsed, order: .reverse) private var presets: [DeckPreset]

    let currentPreset: DeckPreset?
    let onSelect: (DeckPreset?) -> Void

    @State private var showingPresetList = false

    public init(currentPreset: DeckPreset?, onSelect: @escaping (DeckPreset?) -> Void) {
        self.currentPreset = currentPreset
        self.onSelect = onSelect
    }

    private var defaultPreset: DeckPreset? {
        presets.first { $0.isDefault }
    }

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        onSelect(nil)
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("No Preset")
                                    .font(.headline)
                                Text("Use default deck configuration")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if currentPreset == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }

                if !presets.isEmpty {
                    Section("Available Presets") {
                        ForEach(presets) { preset in
                            Button {
                                onSelect(preset)
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(preset.name)
                                                .font(.headline)

                                            if preset.isDefault {
                                                Image(systemName: "star.fill")
                                                    .foregroundStyle(.yellow)
                                                    .font(.caption)
                                            }
                                        }

                                        if !preset.presetDescription.isEmpty {
                                            Text(preset.presetDescription)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(2)
                                        }

                                        Text("\(preset.customizations.count) customizations")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    if preset.id == currentPreset?.id {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("Select Preset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingPresetList = true
                    } label: {
                        Label("Manage Presets", systemImage: "gear")
                    }
                }
            }
            .sheet(isPresented: $showingPresetList) {
                PresetListView()
            }
        }
    }
}

#Preview {
    PresetPickerView(currentPreset: nil) { _ in }
        .modelContainer(for: [DeckPreset.self], inMemory: true)
}
