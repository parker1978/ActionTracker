//
//  WeaponDiscardView.swift
//  ActionTracker
//
//  Discard pile management for weapon decks
//  Supports viewing, returning cards to deck, and reshuffling
//

import SwiftUI
import SwiftData
import CoreDomain
import DataLayer

public struct WeaponDiscardView: View {
    @Bindable var deckState: WeaponDeckState
    @Environment(\.dismiss) private var dismiss
    @State private var weaponToAdd: Weapon?

    // Access to active game session for inventory management
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<CoreDomain.GameSession> { $0.endedAt == nil }, sort: \CoreDomain.GameSession.startedAt, order: .reverse)
    private var activeSessions: [CoreDomain.GameSession]

    public init(deckState: WeaponDeckState) {
        self.deckState = deckState
    }

    private var activeSession: CoreDomain.GameSession? {
        activeSessions.first
    }

    public var body: some View {
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
                                WeaponDiscardRow(
                                    weapon: weapon,
                                    deckState: deckState,
                                    activeSession: activeSession,
                                    onAddToInventory: { weapon in
                                        addWeaponToInventory(weapon)
                                    }
                                )
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
            .sheet(item: $weaponToAdd) { weapon in
                if let session = activeSession {
                    InventoryManagementSheet(
                        weaponToAdd: weapon,
                        session: session,
                        onReplace: { replacedWeapon in
                            // Discard the replaced weapon
                            deckState.discardCard(replacedWeapon)
                            // Remove the added weapon from discard pile
                            deckState.removeFromDiscard(weapon)
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
            // Remove from discard pile
            deckState.removeFromDiscard(weapon)
            return
        }

        // Check if there's space in backpack
        let maxInactive = 3 + session.extraInventorySlots
        if inactiveWeapons.count < maxInactive {
            inactiveWeapons.append(weapon.name)
            session.inactiveWeapons = InventoryFormatter.join(inactiveWeapons)
            // Remove from discard pile
            deckState.removeFromDiscard(weapon)
            return
        }

        // No space - show replacement picker
        weaponToAdd = weapon
    }
}

// MARK: - Weapon Discard Row

struct WeaponDiscardRow: View {
    let weapon: Weapon
    @Bindable var deckState: WeaponDeckState
    let activeSession: CoreDomain.GameSession?
    let onAddToInventory: (Weapon) -> Void

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
            // Add to Inventory button (only if active session exists and not zombie card)
            if activeSession != nil && !weapon.isZombieCard {
                Button {
                    onAddToInventory(weapon)
                } label: {
                    Label("Inventory", systemImage: "bag.badge.plus")
                }
                .tint(.purple)
            }

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
        weapons: WeaponRepository.shared.allWeapons
    ))
}
