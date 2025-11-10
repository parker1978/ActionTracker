//
//  DeckContentsView.swift
//  ActionTracker
//
//  View to browse all weapons in a deck in their current shuffled order
//

import SwiftUI
import CoreDomain
import SharedUI

public struct DeckContentsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var deckState: WeaponDeckState
    @State private var searchText = ""
    @State private var selectedWeapon: Weapon?

    public init(deckState: WeaponDeckState) {
        self.deckState = deckState
    }

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

    public var body: some View {
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
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    deckState.moveCardToTop(weapon)
                                } label: {
                                    Label("Top", systemImage: "arrow.up.to.line")
                                }
                                .tint(.blue)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    deckState.discardFromDeck(weapon)
                                } label: {
                                    Label("Discard", systemImage: "trash")
                                }

                                Button {
                                    deckState.moveCardToBottom(weapon)
                                } label: {
                                    Label("Bottom", systemImage: "arrow.down.to.line")
                                }
                                .tint(.green)
                            }
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
