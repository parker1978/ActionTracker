//
//  PresetListView.swift
//  WeaponsFeature
//
//  Preset management view - list, create, edit, delete presets
//

import SwiftUI
import SwiftData
import CoreDomain

public struct PresetListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \DeckPreset.createdAt, order: .reverse) private var presets: [DeckPreset]

    @State private var showingCreateSheet = false
    @State private var selectedPreset: DeckPreset?
    @State private var presetToDelete: DeckPreset?
    @State private var showDeleteConfirmation = false

    private var customizationService: CustomizationService {
        CustomizationService(context: modelContext)
    }

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                if presets.isEmpty {
                    ContentUnavailableView(
                        "No Presets",
                        systemImage: "folder.badge.gearshape",
                        description: Text("Create a preset to save deck customizations")
                    )
                } else {
                    ForEach(presets) { preset in
                        PresetRow(preset: preset) {
                            selectedPreset = preset
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                presetToDelete = preset
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            if !preset.isDefault {
                                Button {
                                    Task {
                                        try? await customizationService.setDefaultPreset(preset)
                                    }
                                } label: {
                                    Label("Set Default", systemImage: "star.fill")
                                }
                                .tint(.yellow)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Deck Presets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreateSheet = true
                    } label: {
                        Label("New Preset", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateSheet) {
                CreatePresetSheet()
            }
            .sheet(item: $selectedPreset) { preset in
                PresetDetailView(preset: preset)
            }
            .alert("Delete Preset?", isPresented: $showDeleteConfirmation, presenting: presetToDelete) { preset in
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task {
                        try? await customizationService.deletePreset(preset)
                    }
                }
            } message: { preset in
                Text("Are you sure you want to delete \"\(preset.name)\"? This action cannot be undone.")
            }
        }
    }
}

// MARK: - Preset Row

private struct PresetRow: View {
    let preset: DeckPreset
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
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

                    HStack {
                        Text("\(preset.customizations.count) customizations")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        if let lastUsed = preset.lastUsed {
                            Text("•")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("Last used \(lastUsed, format: .relative(presentation: .named))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
                    .font(.caption)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PresetListView()
        .modelContainer(for: [DeckPreset.self, DeckCustomization.self], inMemory: true)
}
