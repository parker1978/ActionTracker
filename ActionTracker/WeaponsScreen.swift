//
//  WeaponsScreen.swift
//  ActionTracker
//
//  Main weapons deck screen with tab-based deck switcher
//  Phase 2: Basic UI structure with difficulty toggle and deck controls
//

import SwiftUI
import SwiftData

struct WeaponsScreen: View {
    @Bindable var weaponsManager: WeaponsManager
    @State private var selectedDeck: DeckType = .regular
    @State private var showDifficultyConfirmation = false
    @State private var pendingDifficulty: DifficultyMode?
    @State private var drawnCards: [Weapon] = []
    @State private var showCardDetail = false
    @State private var enableDrawTwo = false
    @State private var showDiscardPile = false
    @State private var showDeckSettings = false
    @State private var showInventoryReplacement = false
    @State private var weaponToAdd: Weapon?
    @State private var handledCardIDs: Set<UUID> = [] // Track which cards have been added to inventory or discarded

    // Access to active game session for inventory management
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<GameSession> { $0.endedAt == nil }, sort: \GameSession.startedAt, order: .reverse)
    private var activeSessions: [GameSession]

    private var activeSession: GameSession? {
        activeSessions.first
    }

    var body: some View {
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
            .sheet(isPresented: $showInventoryReplacement) {
                if let weapon = weaponToAdd, let session = activeSession {
                    InventoryReplacementSheet(
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
        showInventoryReplacement = true
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

// MARK: - Deck Settings Sheet

struct DeckSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var weaponsManager: WeaponsManager

    @State private var selectedExpansions: Set<String> = []
    @State private var isCustomExpansionSelection = false
    @State private var showDeckContents = false
    @State private var selectedDeckForContents: DeckType = .regular
    @State private var showResetConfirmation = false

    // Get all unique expansions from the repository
    private var allExpansions: [String] {
        let expansions = WeaponRepository.shared.expansions
        var result: [String] = []

        // Add "Core Set" for empty expansion strings
        if expansions.contains("") {
            result.append("Core Set")
        }

        // Add all named expansions
        result.append(contentsOf: expansions.filter { !$0.isEmpty }.sorted())

        return result
    }

    var body: some View {
        NavigationStack {
            Form {
                // Deck Statistics Section
                deckStatisticsSection

                // View Deck Contents
                viewDeckContentsSection

                // Expansion Filter
                expansionFilterSection

                // Deck Management Options
                deckManagementSection
            }
            .navigationTitle("Deck Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showDeckContents) {
                DeckContentsView(deckState: weaponsManager.getDeck(selectedDeckForContents))
            }
            .alert("Reset All Decks?", isPresented: $showResetConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    resetAllDecks()
                }
            } message: {
                Text("This will reshuffle all three decks and clear all discard piles.")
            }
            .onAppear {
                loadSelectedExpansions()
            }
        }
    }

    // MARK: - Deck Statistics Section

    private var deckStatisticsSection: some View {
        Section {
            HStack {
                Label("Total Weapons", systemImage: "square.stack.3d.up")
                Spacer()
                Text("\(weaponCount(total: true))")
                    .foregroundStyle(.secondary)
            }

            ForEach(DeckType.allCases, id: \.self) { deckType in
                HStack {
                    Circle()
                        .fill(deckType.color)
                        .frame(width: 8, height: 8)
                    Text(deckType.displayName)
                    Spacer()
                    Text("\(weaponCount(for: deckType))")
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Deck Statistics")
        } footer: {
            if selectedExpansions.count < allExpansions.count {
                Text("Showing counts for selected expansions only.")
            }
        }
    }

    // MARK: - View Deck Contents Section

    private var viewDeckContentsSection: some View {
        Section {
            ForEach(DeckType.allCases, id: \.self) { deckType in
                Button {
                    selectedDeckForContents = deckType
                    showDeckContents = true
                } label: {
                    HStack {
                        Circle()
                            .fill(deckType.color)
                            .frame(width: 8, height: 8)
                        Text("View \(deckType.displayName) Deck")
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("View Deck Contents")
        } footer: {
            Text("Browse all weapons in each deck to plan your strategy.")
        }
    }

    // MARK: - Expansion Filter Section

    private var expansionFilterSection: some View {
        Section {
            ForEach(allExpansions, id: \.self) { expansion in
                Toggle(isOn: Binding(
                    get: {
                        // Map "Core Set" display name back to empty string for checking
                        let actualExpansion = expansion == "Core Set" ? "" : expansion
                        return selectedExpansions.contains(actualExpansion)
                    },
                    set: { isOn in
                        isCustomExpansionSelection = true
                        // Map "Core Set" display name back to empty string for storage
                        let actualExpansion = expansion == "Core Set" ? "" : expansion
                        if isOn {
                            selectedExpansions.insert(actualExpansion)
                        } else {
                            selectedExpansions.remove(actualExpansion)
                        }
                        saveExpansionFilter()
                    }
                )) {
                    HStack {
                        Text(expansion)
                        Spacer()
                        Text("\(expansionWeaponCount(expansion))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if allExpansions.count > 1 {
                HStack {
                    Button("Select All") {
                        // Map all expansion names back to their actual values (empty string for "Core Set")
                        isCustomExpansionSelection = false
                        selectedExpansions = Set(allExpansions.map { $0 == "Core Set" ? "" : $0 })
                        saveExpansionFilter()
                    }
                    .font(.subheadline)

                    Spacer()

                    Button("Deselect All") {
                        isCustomExpansionSelection = true
                        selectedExpansions.removeAll()
                        saveExpansionFilter()
                    }
                    .font(.subheadline)
                }
            }
        } header: {
            Text("Expansions")
        } footer: {
            Text("Select which expansions to include in your decks. Changes require a deck reset to take effect.")
        }
    }

    // MARK: - Deck Management Section

    private var deckManagementSection: some View {
        Section {
            HStack {
                Label("Current Difficulty", systemImage: "slider.horizontal.3")
                Spacer()
                Text(weaponsManager.currentDifficulty.displayName)
                    .foregroundStyle(.secondary)
            }

            Button(role: .destructive) {
                showResetConfirmation = true
            } label: {
                Label("Reset All Decks", systemImage: "arrow.counterclockwise.circle")
            }
        } header: {
            Text("Deck Management")
        } footer: {
            Text("Reset will reshuffle all three decks and clear discard piles.")
        }
    }

    // MARK: - Helper Functions

    private func weaponCount(for deckType: DeckType) -> Int {
        // Return the actual card count in the deck (including duplicates)
        return weaponsManager.getDeck(deckType).remainingCount + weaponsManager.getDeck(deckType).discardCount
    }

    private func weaponCount(total: Bool) -> Int {
        // Return total card count across all decks (including duplicates)
        var total = 0
        for deckType in DeckType.allCases {
            let deck = weaponsManager.getDeck(deckType)
            total += deck.remainingCount + deck.discardCount
        }
        return total
    }

    private func expansionWeaponCount(_ expansion: String) -> Int {
        // Map "Core Set" display name back to empty string for counting
        let actualExpansion = expansion == "Core Set" ? "" : expansion
        return WeaponRepository.shared.allWeapons.filter { $0.expansion == actualExpansion }.count
    }

    private func getFilteredWeapons() -> [Weapon] {
        if !isCustomExpansionSelection {
            return WeaponRepository.shared.allWeapons
        } else {
            return WeaponRepository.shared.allWeapons.filter { selectedExpansions.contains($0.expansion) }
        }
    }

    private func loadSelectedExpansions() {
        if let saved = UserDefaults.standard.array(forKey: "selectedExpansions") as? [String] {
            isCustomExpansionSelection = true
            selectedExpansions = Set(saved)
        } else {
            // Default: all expansions enabled (including empty string for core set)
            isCustomExpansionSelection = false
            selectedExpansions = Set(WeaponRepository.shared.expansions)
        }
    }

    private func saveExpansionFilter() {
        let allExpansionsSet = Set(WeaponRepository.shared.expansions)

        if !isCustomExpansionSelection || selectedExpansions == allExpansionsSet {
            isCustomExpansionSelection = false
            selectedExpansions = allExpansionsSet
            UserDefaults.standard.removeObject(forKey: "selectedExpansions")
        } else {
            UserDefaults.standard.set(Array(selectedExpansions), forKey: "selectedExpansions")
        }

        // Update the weapons manager with filtered weapons
        weaponsManager.updateWeapons(getFilteredWeapons())
    }

    private func resetAllDecks() {
        weaponsManager.resetAllDecks()
    }
}

// MARK: - Deck Contents View

struct DeckContentsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var deckState: WeaponDeckState
    @State private var searchText = ""
    @State private var selectedWeapon: Weapon?

    // Get weapons in their current shuffled order (remaining deck)
    private var weapons: [Weapon] {
        deckState.remaining
    }

    private var filteredWeapons: [Weapon] {
        if searchText.isEmpty {
            return weapons
        } else {
            return weapons.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.expansion.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if filteredWeapons.isEmpty {
                        Text("Deck is empty")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(filteredWeapons.enumerated()), id: \.element.id) { index, weapon in
                            Button {
                                selectedWeapon = weapon
                            } label: {
                                HStack(spacing: 12) {
                                    // Position number
                                    Text("\(index + 1)")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 30, alignment: .trailing)

                                    Image(systemName: weapon.category.icon)
                                        .font(.title3)
                                        .foregroundStyle(weapon.category.color)
                                        .frame(width: 30)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(weapon.name)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundStyle(.primary)

                                        // Combat stats
                                        HStack(spacing: 8) {
                                            if weapon.range != nil || weapon.rangeMin != nil {
                                                HStack(spacing: 2) {
                                                    Image(systemName: "arrow.right")
                                                        .font(.caption2)
                                                    Text(weapon.rangeDisplay)
                                                        .font(.caption2)
                                                }
                                            }

                                            if let dice = weapon.dice {
                                                HStack(spacing: 2) {
                                                    Image(systemName: "dice")
                                                        .font(.caption2)
                                                    Text("\(dice)")
                                                        .font(.caption2)
                                                }
                                            }

                                            if let accuracy = weapon.accuracy {
                                                HStack(spacing: 2) {
                                                    Image(systemName: "target")
                                                        .font(.caption2)
                                                    Text(accuracy)
                                                        .font(.caption2)
                                                }
                                            }

                                            if let damage = weapon.damage {
                                                HStack(spacing: 2) {
                                                    Image(systemName: "bolt.fill")
                                                        .font(.caption2)
                                                    Text("\(damage)")
                                                        .font(.caption2)
                                                }
                                            }
                                        }
                                        .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "info.circle")
                                        .font(.body)
                                        .foregroundStyle(.blue)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    HStack {
                        Text("Current Deck Order")
                        Spacer()
                        Text("\(filteredWeapons.count) cards")
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("Showing weapons in their current shuffled order. The top card is what will be drawn next.")
                }
            }
            .searchable(text: $searchText, prompt: "Search weapons")
            .navigationTitle("\(deckState.deckType.displayName) Deck")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $selectedWeapon) { weapon in
                NavigationStack {
                    ScrollView {
                        WeaponCardView(weapon: weapon)
                            .padding()
                    }
                    .navigationTitle(weapon.name)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") {
                                selectedWeapon = nil
                            }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
        }
    }
}

// MARK: - Inventory Replacement Sheet

struct InventoryReplacementSheet: View {
    @Environment(\.dismiss) private var dismiss
    let weaponToAdd: Weapon
    let session: GameSession
    let onReplace: (Weapon) -> Void

    // Parse current inventory
    private var activeWeapons: [String] {
        InventoryFormatter.parse(session.activeWeapons)
    }

    private var inactiveWeapons: [String] {
        InventoryFormatter.parse(session.inactiveWeapons)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Header info
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.orange)

                    Text("Inventory Full")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Choose a weapon to replace with:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    // New weapon card
                    HStack {
                        Image(systemName: weaponToAdd.category.icon)
                            .foregroundStyle(weaponToAdd.category.color)
                        Text(weaponToAdd.name)
                            .fontWeight(.semibold)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding()

                // Current inventory
                List {
                    if !activeWeapons.isEmpty {
                        Section {
                            ForEach(Array(activeWeapons.enumerated()), id: \.offset) { _, weaponName in
                                Button {
                                    replaceWeapon(weaponName)
                                } label: {
                                    HStack {
                                        Image(systemName: "hand.raised.fill")
                                            .foregroundStyle(.blue)
                                        Text(weaponName)
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        Image(systemName: "arrow.left.arrow.right")
                                            .foregroundStyle(.orange)
                                    }
                                }
                            }
                        } header: {
                            Text("Active Weapons (Hand)")
                        }
                    }

                    if !inactiveWeapons.isEmpty {
                        Section {
                            ForEach(Array(inactiveWeapons.enumerated()), id: \.offset) { _, weaponName in
                                Button {
                                    replaceWeapon(weaponName)
                                } label: {
                                    HStack {
                                        Image(systemName: "backpack.fill")
                                            .foregroundStyle(.green)
                                        Text(weaponName)
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        Image(systemName: "arrow.left.arrow.right")
                                            .foregroundStyle(.orange)
                                    }
                                }
                            }
                        } header: {
                            Text("Backpack")
                        }
                    }
                }
            }
            .navigationTitle("Replace Weapon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func replaceWeapon(_ weaponName: String) {
        // Find the weapon object to discard
        guard let weaponToDiscard = WeaponRepository.shared.allWeapons.first(where: { $0.name == weaponName }) else {
            dismiss()
            return
        }

        // Remove from inventory and add new weapon
        var newActiveWeapons = activeWeapons
        var newInactiveWeapons = inactiveWeapons

        if let activeIndex = newActiveWeapons.firstIndex(of: weaponName) {
            newActiveWeapons[activeIndex] = weaponToAdd.name
            session.activeWeapons = InventoryFormatter.join(newActiveWeapons)
        } else if let inactiveIndex = newInactiveWeapons.firstIndex(of: weaponName) {
            newInactiveWeapons[inactiveIndex] = weaponToAdd.name
            session.inactiveWeapons = InventoryFormatter.join(newInactiveWeapons)
        }

        // Call the callback to discard the replaced weapon
        onReplace(weaponToDiscard)
        dismiss()
    }
}

#Preview {
    WeaponsScreen(weaponsManager: WeaponsManager(
        weapons: WeaponRepository.shared.allWeapons,
        difficulty: .medium
    ))
}
