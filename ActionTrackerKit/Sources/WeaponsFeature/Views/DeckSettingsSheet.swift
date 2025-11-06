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

    @State private var selectedExpansions: Set<String> = []
    @State private var isCustomExpansionSelection = false
    @State private var showDeckContents = false
    @State private var selectedDeckForContents: DeckType = .regular
    @State private var showResetConfirmation = false

    public init(weaponsManager: WeaponsManager) {
        self.weaponsManager = weaponsManager
    }

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

    public var body: some View {
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
