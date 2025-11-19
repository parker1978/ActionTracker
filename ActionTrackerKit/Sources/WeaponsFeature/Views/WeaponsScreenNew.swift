//
//  WeaponsScreenNew.swift
//  ActionTracker
//
//  Phase 4: Refactored weapons screen using new architecture
//  Uses DeckViewModel and InventoryViewModel instead of legacy managers
//

import SwiftUI
import SwiftData
import CoreDomain
import DataLayer
import SharedUI

public struct WeaponsScreenNew: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<GameSession> { $0.endedAt == nil }, sort: \GameSession.startedAt, order: .reverse)
    private var activeSessions: [GameSession]

    // Deck view models for each deck type
    @State private var startingDeckVM: DeckViewModel
    @State private var regularDeckVM: DeckViewModel
    @State private var ultraredDeckVM: DeckViewModel

    // Inventory view model
    @State private var inventoryVM: InventoryViewModel

    // Customization view model
    @State private var customizationVM: CustomizationViewModel

    // UI state
    @State private var selectedDeckType: String = "Regular"
    @State private var drawnCards: [WeaponCardInstance] = []
    @State private var showCardDetail = false
    @State private var enableDrawTwo = false
    @State private var showDiscardPile = false
    @State private var showDeckSettings = false
    @State private var showPresetPicker = false
    @State private var showDeckContents = false
    @State private var handledCardIDs: Set<UUID> = []
    @State private var hasInitialized = false

    private var activeSession: GameSession? {
        activeSessions.first
    }

    private var currentDeckVM: DeckViewModel {
        switch selectedDeckType {
        case "Starting": return startingDeckVM
        case "Ultrared": return ultraredDeckVM
        default: return regularDeckVM
        }
    }

    private var deckColor: Color {
        switch selectedDeckType {
        case "Starting": return .green
        case "Ultrared": return .red
        default: return .blue
        }
    }

    public init(context: ModelContext) {
        // Initialize services
        let deckService = WeaponsDeckService(context: context)
        let inventoryService = InventoryService(context: context, deckService: deckService)
        let customizationService = CustomizationService(context: context)

        // Initialize view models
        _startingDeckVM = State(initialValue: DeckViewModel(
            deckType: "Starting",
            deckService: deckService,
            context: context
        ))
        _regularDeckVM = State(initialValue: DeckViewModel(
            deckType: "Regular",
            deckService: deckService,
            context: context
        ))
        _ultraredDeckVM = State(initialValue: DeckViewModel(
            deckType: "Ultrared",
            deckService: deckService,
            context: context
        ))
        _inventoryVM = State(initialValue: InventoryViewModel(
            inventoryService: inventoryService,
            context: context
        ))
        _customizationVM = State(initialValue: CustomizationViewModel(
            customizationService: customizationService,
            context: context
        ))
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Deck Switcher
                deckSwitcher
                    .padding(.horizontal)
                    .padding(.top, 8)

                // Current Deck View
                if hasInitialized {
                    deckContentView
                } else {
                    ProgressView("Loading deck...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                Spacer()
            }
            .navigationTitle("Weapons")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showDeckSettings = true
                    } label: {
                        Label("Deck Settings", systemImage: "gearshape")
                    }
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    // Shuffle Button
                    Button(action: {
                        Task {
                            await currentDeckVM.shuffle()
                        }
                    }) {
                        Label("Shuffle", systemImage: "shuffle")
                    }
                    .disabled(currentDeckVM.isEmpty)

                    // Reset Button
                    Button(action: {
                        Task {
                            if let session = activeSession {
                                await currentDeckVM.reset(
                                    for: session,
                                    preset: customizationVM.selectedPreset
                                )
                            }
                        }
                    }) {
                        Label("Reset", systemImage: "arrow.clockwise")
                    }
                }
            }
            .sheet(isPresented: $showCardDetail, onDismiss: {
                // Auto-discard unhandled cards
                Task {
                    for card in drawnCards where !handledCardIDs.contains(card.id) {
                        await currentDeckVM.discard(card)
                    }
                    drawnCards.removeAll()
                    handledCardIDs.removeAll()
                }
            }) {
                DrawnCardsSheet(
                    cards: drawnCards,
                    handledCardIDs: $handledCardIDs,
                    session: activeSession,
                    deckVM: currentDeckVM,
                    inventoryVM: inventoryVM
                )
            }
            .sheet(isPresented: $showDiscardPile) {
                if let session = activeSession {
                    DiscardPileView(deckVM: currentDeckVM, session: session)
                }
            }
            .sheet(isPresented: $showDeckContents) {
                DeckContentsViewNew(deckType: selectedDeckType, session: activeSession)
            }
            .sheet(isPresented: $showDeckSettings) {
                DeckSettingsSheetNew(customizationVM: customizationVM)
            }
            .sheet(isPresented: $showPresetPicker) {
                PresetPickerView(
                    currentPreset: customizationVM.selectedPreset,
                    onSelect: { preset in
                        customizationVM.selectedPreset = preset
                        // Reload decks with new preset
                        Task {
                            if let session = activeSession {
                                await loadDecks(for: session)
                            }
                        }
                    }
                )
            }
            .task {
                // Initialize on first appear
                if !hasInitialized, let session = activeSession {
                    customizationVM.loadPresets()
                    await loadDecks(for: session)
                    inventoryVM.loadInventory(for: session)
                    hasInitialized = true
                }
            }
        }
    }

    // MARK: - Deck Loading

    private func loadDecks(for session: GameSession) async {
        let preset = customizationVM.selectedPreset
        await startingDeckVM.loadDeck(for: session, preset: preset)
        await regularDeckVM.loadDeck(for: session, preset: preset)
        await ultraredDeckVM.loadDeck(for: session, preset: preset)
    }

    // MARK: - Deck Switcher

    private var deckSwitcher: some View {
        Picker("Deck", selection: $selectedDeckType) {
            Text("Starting").tag("Starting")
            Text("Regular").tag("Regular")
            Text("Ultrared").tag("Ultrared")
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Deck Content View

    private var deckContentView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Deck Header
                DeckSummaryHeader(
                    deckTypeName: selectedDeckType,
                    deckColor: deckColor,
                    remainingCount: currentDeckVM.remainingCount,
                    discardCount: currentDeckVM.discardCount,
                    onTapRemaining: {
                        showDeckContents = true
                    },
                    onTapDiscard: {
                        showDiscardPile = true
                    }
                )
                .padding(.horizontal)
                .padding(.top)

                // Preset Picker (if customization enabled)
                if customizationVM.hasPresets {
                    presetSection
                        .padding(.horizontal)
                }

                // Draw Buttons
                DeckActionButtons(
                    deckColor: deckColor,
                    deckType: selectedDeckType,
                    isEmpty: currentDeckVM.isEmpty,
                    enableDrawTwo: selectedDeckType == "Regular" ? $enableDrawTwo : nil,
                    onDraw: {
                        Task {
                            if let card = await currentDeckVM.draw() {
                                drawnCards = [card]
                                showCardDetail = true
                            }
                        }
                    },
                    onDrawTwo: selectedDeckType == "Regular" ? {
                        Task {
                            let cards = await currentDeckVM.drawTwo()
                            if !cards.isEmpty {
                                drawnCards = cards
                                showCardDetail = true
                            }
                        }
                    } : nil
                )
                .padding(.horizontal)
            }
            .padding(.bottom)
        }
    }

    // MARK: - Preset Section

    private var presetSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Active Preset")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button(action: {
                showPresetPicker = true
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(customizationVM.selectedPreset?.name ?? "Default")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        if let description = customizationVM.selectedPreset?.presetDescription, !description.isEmpty {
                            Text(description)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Supporting Views

private struct DrawnCardsSheet: View {
    let cards: [WeaponCardInstance]
    @Binding var handledCardIDs: Set<UUID>
    let session: GameSession?
    let deckVM: DeckViewModel
    let inventoryVM: InventoryViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(cards, id: \.id) { card in
                        VStack(spacing: 12) {
                            // Card display
                            if let definition = card.definition {
                                WeaponCardViewNew(definition: definition)
                            }

                            // Action buttons or handled indicator
                            if handledCardIDs.contains(card.id) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                    Text("Handled")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 8)
                            } else {
                                cardActionButtons(for: card)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                .padding()
            }
            .navigationTitle(cards.count == 1 ? "Drawn Card" : "Drawn Cards (\(cards.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func cardActionButtons(for card: WeaponCardInstance) -> some View {
        VStack(spacing: 8) {
            // Add to Inventory button
            if let session = session {
                Button(action: {
                    Task {
                        _ = await inventoryVM.addToActive(
                            card,
                            session: session,
                            deckState: deckVM.deckState
                        )
                        handledCardIDs.insert(card.id)
                        if handledCardIDs.count == cards.count {
                            dismiss()
                        }
                    }
                }) {
                    Label("Add to Inventory", systemImage: "bag.badge.plus")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            // Discard button
            Button(action: {
                Task {
                    await deckVM.discard(card)
                    handledCardIDs.insert(card.id)
                    if handledCardIDs.count == cards.count {
                        dismiss()
                    }
                }
            }) {
                Label("Discard", systemImage: "trash")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.orange.opacity(0.1))
                    .foregroundStyle(.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

// Temporary placeholder for WeaponCardView that works with WeaponDefinition
private struct WeaponCardViewNew: View {
    let definition: WeaponDefinition

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(definition.name)
                .font(.title2)
                .fontWeight(.bold)

            HStack {
                Text(definition.set)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color(.systemGray5)))

                Text(definition.deckType)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.blue.opacity(0.2)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.blue.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.blue, lineWidth: 2)
                )
        )
    }
}

private struct DiscardPileView: View {
    let deckVM: DeckViewModel
    let session: GameSession
    @Environment(\.dismiss) private var dismiss
    @State private var discardCards: [WeaponCardInstance] = []

    var body: some View {
        NavigationStack {
            List {
                ForEach(discardCards, id: \.id) { card in
                    if let definition = card.definition {
                        Text(definition.name)
                    }
                }
            }
            .navigationTitle("Discard Pile")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                discardCards = await deckVM.getDiscardCards()
            }
        }
    }
}

private struct DeckContentsViewNew: View {
    let deckType: String
    let session: GameSession?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Text("Deck contents for \(deckType)")
                .navigationTitle("\(deckType) Deck")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

private struct DeckSettingsSheetNew: View {
    let customizationVM: CustomizationViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Presets") {
                    ForEach(customizationVM.presets) { preset in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(preset.name)
                                if !preset.presetDescription.isEmpty {
                                    Text(preset.presetDescription)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if preset.isDefault {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(.yellow)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Deck Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
