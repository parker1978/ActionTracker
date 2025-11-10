//
//  DeckSettingsSheet.swift
//  ActionTracker
//
//  Deck settings and configuration for weapon decks
//  Allows expansion filtering, viewing deck contents, and deck management
//

import SwiftUI
import CoreDomain
import DataLayer

public struct DeckSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var weaponsManager: WeaponsManager
    @StateObject private var disabledCardsManager = DisabledCardsManager()

    @State private var selectedExpansions: Set<String> = []
    @State private var isCustomExpansionSelection = false
    @State private var selectedDeckForContents: DeckType?
    @State private var selectedSetForCards: String?
    @State private var showResetConfirmation = false

    public init(weaponsManager: WeaponsManager) {
        self.weaponsManager = weaponsManager
    }

    // Get all unique sets from the repository
    private var allSets: [String] {
        WeaponRepository.shared.expansions.sorted()
    }

    public var body: some View {
        NavigationStack {
            Form {
                // Deck Statistics Section
                deckStatisticsSection

                // View Deck Contents
                viewDeckContentsSection

                // Set Filter
                expansionFilterSection

                // Card Selection
                cardSelectionSection

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
            .sheet(item: $selectedDeckForContents) { deckType in
                DeckContentsView(deckState: weaponsManager.getDeck(deckType))
            }
            .sheet(item: Binding(
                get: { selectedSetForCards.map { IdentifiableString(value: $0) } },
                set: { selectedSetForCards = $0?.value }
            )) { identifiableSet in
                CardSelectionSheet(
                    setName: identifiableSet.value,
                    disabledCardsManager: disabledCardsManager,
                    onDismiss: {
                        applyCardSelectionChanges()
                    }
                )
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
            if selectedExpansions.count < allSets.count {
                Text("Showing counts for selected sets only.")
            }
        }
    }

    // MARK: - View Deck Contents Section

    private var viewDeckContentsSection: some View {
        Section {
            ForEach(DeckType.allCases, id: \.self) { deckType in
                Button {
                    selectedDeckForContents = deckType
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

    // MARK: - Set Filter Section

    private var expansionFilterSection: some View {
        Section {
            ForEach(allSets, id: \.self) { setName in
                Toggle(isOn: Binding(
                    get: {
                        selectedExpansions.contains(setName)
                    },
                    set: { isOn in
                        isCustomExpansionSelection = true
                        if isOn {
                            selectedExpansions.insert(setName)
                        } else {
                            selectedExpansions.remove(setName)
                        }
                        saveExpansionFilter()
                    }
                )) {
                    HStack {
                        Text(setName)
                        Spacer()
                        Text("\(setWeaponCount(setName))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if allSets.count > 1 {
                HStack {
                    Button("Select All") {
                        isCustomExpansionSelection = false
                        selectedExpansions = Set(allSets)
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
            Text("Sets")
        } footer: {
            Text("Select which sets to include in your decks. Tap a set name to customize card selection. Changes require a deck reset to take effect.")
        }
    }

    // MARK: - Card Selection Section

    private var cardSelectionSection: some View {
        Section {
            ForEach(allSets.filter { selectedExpansions.contains($0) }, id: \.self) { setName in
                Button {
                    selectedSetForCards = setName
                } label: {
                    HStack {
                        Text(setName)
                            .foregroundStyle(.primary)
                        Spacer()

                        // Show count of disabled cards if any
                        let disabledCount = disabledCardsManager.getDisabledCards(for: setName).count
                        if disabledCount > 0 {
                            Text("\(disabledCount) disabled")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("Card Selection")
        } footer: {
            Text("Tap a set to enable or disable individual cards.")
        }
    }

    // MARK: - Deck Management Section

    private var deckManagementSection: some View {
        Section {
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

    private func setWeaponCount(_ setName: String) -> Int {
        // Sum up the count property to get total cards (not just unique weapons)
        return WeaponRepository.shared.allWeapons
            .filter { $0.expansion == setName }
            .reduce(0) { $0 + $1.count }
    }

    private func getFilteredWeapons() -> [Weapon] {
        var weapons = WeaponRepository.shared.allWeapons

        // Apply set/expansion filter
        if isCustomExpansionSelection {
            weapons = weapons.filter { selectedExpansions.contains($0.expansion) }
        }

        // Apply card-level disabled filter
        weapons = weapons.filter { weapon in
            !disabledCardsManager.isCardDisabled(weapon.name, in: weapon.expansion)
        }

        return weapons
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

    private func applyCardSelectionChanges() {
        // Apply the card selection changes by updating the weapons manager
        weaponsManager.updateWeapons(getFilteredWeapons())
    }
}

// MARK: - Helper Types

/// Helper struct to make String identifiable for sheet presentation
private struct IdentifiableString: Identifiable {
    let id = UUID()
    let value: String
}
