//
//  PresetDetailView.swift
//  WeaponsFeature
//
//  View and edit preset details and customizations
//

import SwiftUI
import SwiftData
import CoreDomain

public struct PresetDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var preset: DeckPreset

    @State private var editedName: String
    @State private var editedDescription: String
    @State private var isEditing = false
    @State private var showDeleteConfirmation = false

    private var customizationService: CustomizationService {
        CustomizationService(context: modelContext)
    }

    private var diffs: [CustomizationService.CustomizationDiff] {
        (try? customizationService.diffsFromDefault(preset: preset)) ?? []
    }

    public init(preset: DeckPreset) {
        self.preset = preset
        _editedName = State(initialValue: preset.name)
        _editedDescription = State(initialValue: preset.presetDescription)
    }

    public var body: some View {
        NavigationStack {
            Form {
                // Preset Info Section
                Section("Preset Information") {
                    if isEditing {
                        TextField("Preset Name", text: $editedName)
                            .autocorrectionDisabled()

                        TextField("Description", text: $editedDescription, axis: .vertical)
                            .lineLimit(3...6)
                    } else {
                        LabeledContent("Name", value: preset.name)
                        if !preset.presetDescription.isEmpty {
                            LabeledContent("Description", value: preset.presetDescription)
                        }
                    }

                    LabeledContent("Created", value: preset.createdAt, format: .dateTime)

                    if let lastUsed = preset.lastUsed {
                        LabeledContent("Last Used", value: lastUsed, format: .relative(presentation: .named))
                    }
                }

                // Default Status Section
                Section {
                    if preset.isDefault {
                        Label("Default Preset", systemImage: "star.fill")
                            .foregroundStyle(.yellow)
                    } else {
                        Button {
                            Task {
                                try? await customizationService.setDefaultPreset(preset)
                            }
                        } label: {
                            Label("Set as Default", systemImage: "star")
                        }
                    }
                }

                // Customizations Summary
                Section {
                    NavigationLink {
                        CustomizationDiffView(diffs: diffs)
                    } label: {
                        LabeledContent("Customizations") {
                            Text("\(preset.customizations.count)")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Deck Customizations")
                } footer: {
                    if diffs.isEmpty {
                        Text("This preset uses all default settings.")
                    } else {
                        Text("\(diffs.count) changes from default configuration.")
                    }
                }

                // Danger Zone
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete Preset", systemImage: "trash")
                    }
                }
            }
            .navigationTitle(preset.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isEditing ? "Cancel" : "Done") {
                        if isEditing {
                            // Revert changes
                            editedName = preset.name
                            editedDescription = preset.presetDescription
                            isEditing = false
                        } else {
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(isEditing ? "Save" : "Edit") {
                        if isEditing {
                            saveChanges()
                        } else {
                            isEditing = true
                        }
                    }
                }
            }
            .alert("Delete Preset?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task {
                        try? await customizationService.deletePreset(preset)
                        dismiss()
                    }
                }
            } message: {
                Text("Are you sure you want to delete \"\(preset.name)\"? This action cannot be undone.")
            }
        }
    }

    private func saveChanges() {
        preset.name = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        preset.presetDescription = editedDescription.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            try modelContext.save()
            isEditing = false
        } catch {
            // Handle error
            print("Error saving preset: \(error)")
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: DeckPreset.self, configurations: config)
    let context = ModelContext(container)

    let preset = DeckPreset(name: "My Custom Preset", description: "A preset with custom settings", isDefault: true)
    context.insert(preset)

    return PresetDetailView(preset: preset)
        .modelContainer(container)
}
