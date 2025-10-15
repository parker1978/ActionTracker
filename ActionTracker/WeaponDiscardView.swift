//
//  WeaponDiscardView.swift
//  ActionTracker
//
//  Discard pile management for weapon decks
//  Supports viewing, returning cards to deck, and reshuffling
//

import SwiftUI

struct WeaponDiscardView: View {
    @Bindable var deckState: WeaponDeckState
    @Environment(\.dismiss) private var dismiss
    @State private var showClearConfirmation = false

    var body: some View {
        NavigationStack {
            Group {
                if deckState.discardCount == 0 {
                    ContentUnavailableView {
                        Label("No Discarded Cards", systemImage: "tray")
                    } description: {
                        Text("Cards will appear here when discarded")
                    }
                } else {
                    List {
                        // Discard Pile Section
                        Section {
                            ForEach(deckState.discard) { weapon in
                                WeaponDiscardRow(weapon: weapon, deckState: deckState)
                            }
                        } header: {
                            HStack {
                                Text("Discarded Cards")
                                Spacer()
                                Text("\(deckState.discardCount)")
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // Actions Section
                        Section {
                            // Shuffle All Back
                            Button(action: {
                                deckState.reclaimAllDiscardIntoDeck(shuffle: true)
                            }) {
                                Label("Shuffle All Back to Deck", systemImage: "shuffle")
                                    .foregroundStyle(.blue)
                            }

                            // Clear All (dev/debug)
                            Button(role: .destructive, action: {
                                showClearConfirmation = true
                            }) {
                                Label("Clear All", systemImage: "trash")
                            }
                        } header: {
                            Text("Actions")
                        }
                    }
                }
            }
            .navigationTitle("\(deckState.deckType.displayName) Discard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Clear Discard Pile?", isPresented: $showClearConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Clear All", role: .destructive) {
                    deckState.clearDiscard()
                }
            } message: {
                Text("This will permanently remove all cards from the discard pile. This action cannot be undone.")
            }
        }
    }
}

// MARK: - Weapon Discard Row

struct WeaponDiscardRow: View {
    let weapon: Weapon
    @Bindable var deckState: WeaponDeckState

    var body: some View {
        HStack(spacing: 12) {
            // Weapon Category Icon
            Image(systemName: weapon.category.icon)
                .font(.title2)
                .foregroundStyle(weapon.category.color)
                .frame(width: 40)

            // Weapon Info
            VStack(alignment: .leading, spacing: 4) {
                Text(weapon.name)
                    .font(.headline)

                HStack(spacing: 8) {
                    if let dice = weapon.dice {
                        HStack(spacing: 2) {
                            Image(systemName: "dice")
                                .font(.caption2)
                            Text("\(dice)")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }

                    if let accuracy = weapon.accuracy {
                        HStack(spacing: 2) {
                            Image(systemName: "target")
                                .font(.caption2)
                            Text(accuracy)
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }

                    if let damage = weapon.damage {
                        HStack(spacing: 2) {
                            Image(systemName: "bolt.fill")
                                .font(.caption2)
                            Text("\(damage)")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // Deck badge
            Text(weapon.deck.displayName)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Capsule().fill(weapon.deck.color.opacity(0.2)))
                .foregroundStyle(weapon.deck.color)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                deckState.returnFromDiscardToTop(weapon)
            } label: {
                Label("Top", systemImage: "arrow.up.to.line")
            }
            .tint(.blue)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                deckState.returnFromDiscardToBottom(weapon)
            } label: {
                Label("Bottom", systemImage: "arrow.down.to.line")
            }
            .tint(.green)
        }
    }
}

#Preview {
    WeaponDiscardView(deckState: WeaponDeckState(
        deckType: .regular,
        difficulty: .medium,
        weapons: WeaponRepository.shared.allWeapons
    ))
}
