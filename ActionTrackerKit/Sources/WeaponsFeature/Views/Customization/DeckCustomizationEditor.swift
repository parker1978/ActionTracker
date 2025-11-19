//
//  DeckCustomizationEditor.swift
//  WeaponsFeature
//
//  Main editor for customizing deck composition
//

import SwiftUI
import SwiftData
import CoreDomain

public struct DeckCustomizationEditor: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var weaponDefinitions: [WeaponDefinition]

    @Bindable var preset: DeckPreset
    let gameSession: GameSession?  // Optional: for session override mode

    @State private var isSessionOverrideMode = false
    @State private var showBulkActions = false
    @State private var showExportImport = false
    @State private var hasUnsavedChanges = false
    @State private var showDiscardChangesAlert = false

    private var customizationService: CustomizationService {
        CustomizationService(context: modelContext)
    }

    // Group weapons by expansion set
    private var weaponsBySet: [String: [WeaponDefinition]] {
        let activeWeapons = weaponDefinitions.filter { !$0.isDeprecated }
        return Dictionary(grouping: activeWeapons, by: { $0.set })
    }

    private var sortedSets: [String] {
        weaponsBySet.keys.sorted()
    }

    public init(preset: DeckPreset, gameSession: GameSession? = nil) {
        self.preset = preset
        self.gameSession = gameSession
    }

    public var body: some View {
        NavigationStack {
            List {
                // Session Override Toggle (if in session context)
                if let session = gameSession {
                    Section {
                        Toggle("Session-Only Changes", isOn: $isSessionOverrideMode)
                    } footer: {
                        Text("Enable to make temporary changes that only apply to this game session without modifying the preset.")
                    }
                }

                // Weapons by Set
                ForEach(sortedSets, id: \.self) { set in
                    Section(header: setHeader(for: set)) {
                        ForEach(weaponsBySet[set] ?? [], id: \.id) { weapon in
                            WeaponCustomizationRow(
                                weapon: weapon,
                                preset: preset,
                                sessionOverride: isSessionOverrideMode ? gameSession?.sessionDeckOverride : nil,
                                customizationService: customizationService,
                                onChanged: {
                                    hasUnsavedChanges = true
                                }
                            )
                        }
                    }
                }
            }
            .navigationTitle("Customize Deck")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if hasUnsavedChanges {
                            showDiscardChangesAlert = true
                        } else {
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    Button {
                        showBulkActions = true
                    } label: {
                        Label("Bulk Actions", systemImage: "square.stack.3d.up")
                    }

                    Spacer()

                    Button {
                        showExportImport = true
                    } label: {
                        Label("Export/Import", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .sheet(isPresented: $showBulkActions) {
                BulkActionSheet(
                    preset: preset,
                    sessionOverride: isSessionOverrideMode ? gameSession?.sessionDeckOverride : nil,
                    weaponsBySet: weaponsBySet,
                    customizationService: customizationService,
                    onChanged: {
                        hasUnsavedChanges = true
                    }
                )
            }
            .sheet(isPresented: $showExportImport) {
                PresetExportImportView(preset: preset)
            }
            .alert("Discard Changes?", isPresented: $showDiscardChangesAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Discard", role: .destructive) {
                    dismiss()
                }
            } message: {
                Text("You have unsaved changes. Are you sure you want to discard them?")
            }
        }
    }

    @ViewBuilder
    private func setHeader(for set: String) -> some View {
        HStack {
            Text(set)

            Spacer()

            if let weapons = weaponsBySet[set] {
                let enabledCount = weapons.filter { weapon in
                    customizationService.isEnabled(
                        definition: weapon,
                        in: preset,
                        sessionOverride: isSessionOverrideMode ? gameSession?.sessionDeckOverride : nil
                    )
                }.count

                Text("\(enabledCount)/\(weapons.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: DeckPreset.self, WeaponDefinition.self, configurations: config)
    let context = ModelContext(container)

    let preset = DeckPreset(name: "Test Preset", description: "Test", isDefault: false)
    context.insert(preset)

    return DeckCustomizationEditor(preset: preset)
        .modelContainer(container)
}
