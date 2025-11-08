//
//  WeaponsScreen.swift
//  ActionTracker
//
//  Main weapons deck screen with tab-based deck switcher
//  Phase 8: Modularized into WeaponsFeature
//

import SwiftUI
import SwiftData
import CoreDomain
import DataLayer
import SharedUI

public struct WeaponsScreen: View {
    @Bindable var weaponsManager: WeaponsManager
    @State private var selectedDeck: DeckType = .regular
    @State private var showDifficultyConfirmation = false
    @State private var pendingDifficulty: DifficultyMode?
    @State private var drawnCards: [Weapon] = []
    @State private var showCardDetail = false
    @State private var enableDrawTwo = false
    @State private var showDiscardPile = false
    @State private var showDeckSettings = false
    @State private var weaponToAdd: Weapon?
    @State private var handledCardIDs: Set<UUID> = [] // Track which cards have been added to inventory or discarded

    // Access to active game session for inventory management
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<CoreDomain.GameSession> { $0.endedAt == nil }, sort: \CoreDomain.GameSession.startedAt, order: .reverse)
    private var activeSessions: [CoreDomain.GameSession]

    public init(weaponsManager: WeaponsManager) {
        self.weaponsManager = weaponsManager
    }

    private var activeSession: CoreDomain.GameSession? {
        activeSessions.first
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Difficulty Mode Picker
                difficultyPicker
                    .padding()
                    .background(Color(.systemGroupedBackground))

                // Deck Switcher (Segmented Control)
                deckSwitcher
                    .padding(.horizontal)
                    .padding(.top, 8)

                // Current Deck View
                deckContentView

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
                        currentDeck.shuffle()
                    }) {
                        Label("Shuffle", systemImage: "shuffle")
                    }
                    .disabled(currentDeck.isEmpty)

                    // Reset Button
                    Button(action: {
                        currentDeck.reset()
                    }) {
                        Label("Reset", systemImage: "arrow.clockwise")
                    }
                }
            }
            .alert("Change Difficulty?", isPresented: $showDifficultyConfirmation) {
                Button("Cancel", role: .cancel) {
                    pendingDifficulty = nil
                }
                Button("Reset & Change", role: .destructive) {
                    if let newDifficulty = pendingDifficulty {
                        weaponsManager.currentDifficulty = newDifficulty
                    }
                    pendingDifficulty = nil
                }
            } message: {
                Text("Changing difficulty will reset and reshuffle all three decks. Continue?")
            }
            .sheet(isPresented: $showCardDetail, onDismiss: {
                // Auto-discard only unhandled cards when sheet is dismissed
                for card in drawnCards where !handledCardIDs.contains(card.id) {
                    currentDeck.discardCard(card)
                }
                drawnCards.removeAll()
                handledCardIDs.removeAll()
            }) {
                NavigationStack {
                    VStack(spacing: 0) {
                        ScrollView {
                            VStack(spacing: 20) {
                                ForEach(drawnCards) { card in
                                    VStack(spacing: 12) {
                                        // Card display
                                        WeaponCardView(weapon: card)

                                        // Show handled indicator or action buttons
                                        if handledCardIDs.contains(card.id) {
                                            // Card has been handled - show indicator
                                            HStack {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundStyle(.green)
                                                Text("Handled")
                                                    .font(.subheadline)
                                                    .foregroundStyle(.secondary)
                                            }
                                            .padding(.vertical, 8)
                                        } else {
                                            // Card not yet handled - show action buttons
                                            VStack(spacing: 8) {
                                                // Add to Inventory Button (only if active session exists and not zombie card)
                                                if let _ = activeSession, !card.isZombieCard {
                                                    Button(action: {
                                                        addWeaponToInventory(card)
                                                    }) {
                                                        Label("Add to Inventory", systemImage: "bag.badge.plus")
                                                            .frame(maxWidth: .infinity)
                                                            .padding(.vertical, 12)
                                                            .background(Color.blue.opacity(0.1))
                                                            .foregroundStyle(.blue)
                                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                                    }
                                                }

                                                // Discard Button
                                                Button(action: {
                                                    discardCard(card)
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
                                    .padding(.vertical, 8)
                                }
                            }
                            .padding()
                        }
                    }
                    .navigationTitle(drawnCards.count == 1 ? "Drawn Card" : "Drawn Cards (\(drawnCards.count))")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") {
                                showCardDetail = false
                            }
                        }
                    }
                }
                .presentationDetents({
                    if drawnCards.count > 1 {
                        [.large]
                    } else if let weapon = drawnCards.first, !weapon.isBonus && !weapon.isZombieCard {
                        [.fraction(0.75), .large]
                    } else {
                        [.medium, .large]
                    }
                }())
            }
            .sheet(isPresented: $showDiscardPile) {
                WeaponDiscardView(deckState: currentDeck)
            }
            .sheet(isPresented: $showDeckSettings) {
                DeckSettingsSheet(weaponsManager: weaponsManager)
            }
            .sheet(item: $weaponToAdd) { weapon in
                if let session = activeSession {
                    InventoryManagementSheet(
                        weaponToAdd: weapon,
                        session: session,
                        onReplace: { replacedWeapon in
                            // Discard both the replaced weapon and the added weapon
                            currentDeck.discardCard(replacedWeapon)
                            currentDeck.discardCard(weapon)
                            // Mark the added weapon as handled
                            handledCardIDs.insert(weapon.id)
                            // Close the drawn card sheet if all cards handled
                            if handledCardIDs.count == drawnCards.count {
                                showCardDetail = false
                            }
                        }
                    )
                } else {
                    ContentUnavailableView {
                        Label("No Active Session", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text("Start a game session to add weapons to inventory")
                    }
                }
            }
        }
    }

    // MARK: - Card Management

    private func discardCard(_ weapon: Weapon) {
        // Discard card to deck
        currentDeck.discardCard(weapon)
        // Mark as handled
        handledCardIDs.insert(weapon.id)
        // Close sheet if all cards handled
        if handledCardIDs.count == drawnCards.count {
            showCardDetail = false
        }
    }

    // MARK: - Inventory Management

    private func addWeaponToInventory(_ weapon: Weapon) {
        guard let session = activeSession else { return }

        // Parse current inventory
        var activeWeapons = InventoryFormatter.parse(session.activeWeapons)
        var inactiveWeapons = InventoryFormatter.parse(session.inactiveWeapons)

        // Check if there's space in active slots (hands) first
        if activeWeapons.count < 2 {
            activeWeapons.append(weapon.name)
            session.activeWeapons = InventoryFormatter.join(activeWeapons)
            // Mark as handled
            handledCardIDs.insert(weapon.id)
            // Close sheet if all cards handled
            if handledCardIDs.count == drawnCards.count {
                showCardDetail = false
            }
            return
        }

        // Check if there's space in backpack
        let maxInactive = 3 + session.extraInventorySlots
        if inactiveWeapons.count < maxInactive {
            inactiveWeapons.append(weapon.name)
            session.inactiveWeapons = InventoryFormatter.join(inactiveWeapons)
            // Mark as handled
            handledCardIDs.insert(weapon.id)
            // Close sheet if all cards handled
            if handledCardIDs.count == drawnCards.count {
                showCardDetail = false
            }
            return
        }

        // No space - show replacement picker
        weaponToAdd = weapon
    }

    // MARK: - Draw Actions

    private func drawCard() {
        if let card = currentDeck.draw() {
            drawnCards = [card]
            showCardDetail = true
        }
    }

    private func drawTwoCards() {
        let cards = currentDeck.drawTwo()
        if !cards.isEmpty {
            drawnCards = cards
            showCardDetail = true
        }
    }

    // MARK: - Current Deck Helper

    private var currentDeck: WeaponDeckState {
        weaponsManager.getDeck(selectedDeck)
    }

    // MARK: - Difficulty Picker

    private var difficultyPicker: some View {
        VStack(spacing: 8) {
            Text("Difficulty")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Difficulty", selection: difficultyBinding) {
                ForEach(DifficultyMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var difficultyBinding: Binding<DifficultyMode> {
        Binding(
            get: { weaponsManager.currentDifficulty },
            set: { newValue in
                if newValue != weaponsManager.currentDifficulty {
                    pendingDifficulty = newValue
                    showDifficultyConfirmation = true
                }
            }
        )
    }

    // MARK: - Deck Switcher

    private var deckSwitcher: some View {
        Picker("Deck", selection: $selectedDeck) {
            ForEach(DeckType.allCases, id: \.self) { deck in
                Text(deck.displayName).tag(deck)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Deck Content View

    private var deckContentView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Deck Header
                deckHeader(for: currentDeck)
                    .padding(.horizontal)
                    .padding(.top)

                // Draw Buttons
                drawButtonsSection
                    .padding(.horizontal)
            }
            .padding(.bottom)
        }
    }

    // MARK: - Draw Buttons

    private var drawButtonsSection: some View {
        VStack(spacing: 12) {
            // Draw Buttons Row
            HStack(spacing: 12) {
                // Draw 1 Button
                Button(action: {
                    drawCard()
                }) {
                    Label("Draw Card", systemImage: "plus.rectangle")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(currentDeck.deckType.color.gradient)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(currentDeck.isEmpty)

                // Draw 2 Button (appears next to Draw 1 when enabled, Regular deck only)
                if enableDrawTwo && selectedDeck == .regular {
                    Button(action: {
                        drawTwoCards()
                    }) {
                        Label("Draw 2", systemImage: "plus.rectangle.on.rectangle")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(currentDeck.deckType.color.opacity(0.7).gradient)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(currentDeck.isEmpty)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: enableDrawTwo)

            // Draw 2 Toggle (Regular deck only)
            if selectedDeck == .regular {
                HStack {
                    Toggle("Flashlight Mode", isOn: $enableDrawTwo)
                        .font(.subheadline)
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Deck Header

    private func deckHeader(for deck: WeaponDeckState) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(deck.deckType.displayName + " Deck")
                    .font(.headline)

                HStack(spacing: 12) {
                    Label("\(deck.remainingCount) cards", systemImage: "rectangle.stack")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button(action: {
                        showDiscardPile = true
                    }) {
                        Label("\(deck.discardCount) discard", systemImage: "tray")
                            .font(.subheadline)
                            .foregroundStyle(deck.discardCount > 0 ? .orange : .secondary)
                    }
                }
            }

            Spacer()

            // Deck color indicator
            Circle()
                .fill(deck.deckType.color.gradient)
                .frame(width: 12, height: 12)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

#Preview {
    WeaponsScreen(weaponsManager: WeaponsManager(
        weapons: WeaponRepository.shared.allWeapons,
        difficulty: .medium
    ))
}
