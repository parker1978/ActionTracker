//
//  CreatePresetSheet.swift
//  WeaponsFeature
//
//  Sheet for creating a new deck preset
//

import SwiftUI
import SwiftData
import CoreDomain

public struct CreatePresetSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var presets: [DeckPreset]

    @State private var presetName: String = ""
    @State private var presetDescription: String = ""
    @State private var isDefault: Bool = false
    @State private var basePreset: DeckPreset?
    @State private var isCreating = false
    @State private var showError = false
    @State private var errorMessage = ""

    private var customizationService: CustomizationService {
        CustomizationService(context: modelContext)
    }

    private var canCreate: Bool {
        !presetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public init() {}

    public var body: some View {
        NavigationStack {
            Form {
                Section("Preset Details") {
                    TextField("Preset Name", text: $presetName)
                        .autocorrectionDisabled()

                    TextField("Description (optional)", text: $presetDescription, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Toggle("Set as Default Preset", isOn: $isDefault)
                } footer: {
                    Text("The default preset is automatically used when starting a new game session.")
                }

                if !presets.isEmpty {
                    Section {
                        Picker("Copy from Existing", selection: $basePreset) {
                            Text("Start from Scratch")
                                .tag(nil as DeckPreset?)

                            ForEach(presets) { preset in
                                Text(preset.name)
                                    .tag(preset as DeckPreset?)
                            }
                        }
                    } footer: {
                        Text("Copy customizations from an existing preset, or start with no customizations.")
                    }
                }
            }
            .navigationTitle("New Preset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isCreating)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createPreset()
                    }
                    .disabled(!canCreate || isCreating)
                }
            }
            .alert("Error Creating Preset", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func createPreset() {
        isCreating = true

        Task {
            do {
                _ = try await customizationService.createPreset(
                    name: presetName.trimmingCharacters(in: .whitespacesAndNewlines),
                    description: presetDescription.trimmingCharacters(in: .whitespacesAndNewlines),
                    isDefault: isDefault,
                    basedOn: basePreset
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
                isCreating = false
            }
        }
    }
}

#Preview {
    CreatePresetSheet()
        .modelContainer(for: [DeckPreset.self, DeckCustomization.self], inMemory: true)
}
