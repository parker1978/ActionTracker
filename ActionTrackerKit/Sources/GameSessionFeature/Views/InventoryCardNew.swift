//
//  InventoryCardNew.swift
//  GameSessionFeature
//
//  Phase 4: Refactored inventory card using new architecture
//  Uses InventoryViewModel instead of legacy string parsing
//

import SwiftUI
import SwiftData
import CoreDomain
import SharedUI

/// Card for managing character weapon inventory using the new architecture
/// Phase 4: Refactored to use InventoryViewModel and SwiftData models
struct InventoryCardNew: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var session: GameSession

    // Initialize view model
    @State private var inventoryVM: InventoryViewModel
    @State private var showingInventorySheet = false
    @State private var selectedWeaponDefinition: WeaponDefinition?

    init(session: GameSession, context: ModelContext) {
        self.session = session

        // Initialize inventory service and view model
        let deckService = WeaponsDeckService(context: context)
        let inventoryService = InventoryService(context: context, deckService: deckService)
        _inventoryVM = State(initialValue: InventoryViewModel(
            inventoryService: inventoryService,
            context: context
        ))
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Label("Inventory", systemImage: "shield.lefthalf.filled")
                    .font(.headline)

                Spacer()

                // Weapon count
                Text("\(inventoryVM.totalCount) weapons")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // Manage button
                Button {
                    showingInventorySheet = true
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.title3)
                }
            }

            // Quick Summary
            if !inventoryVM.hasInventory {
                Text("No weapons equipped")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    // Active Weapons
                    if !inventoryVM.activeItems.isEmpty {
                        InventorySlotView(
                            title: "Active",
                            icon: "hand.raised.fill",
                            iconColor: .blue,
                            weapons: inventoryVM.activeItems.prefix(2).map { item in
                                InventoryWeaponInfo(
                                    id: item.id,
                                    name: inventoryVM.getWeaponName(from: item),
                                    set: inventoryVM.getWeaponSet(from: item),
                                    category: inventoryVM.getWeaponCategory(from: item),
                                    statsText: formatStats(for: item)
                                )
                            },
                            currentCount: inventoryVM.activeItems.count,
                            maxCount: inventoryVM.activeCapacity,
                            onTapWeapon: { weaponInfo in
                                // Find and show weapon detail
                                if let item = inventoryVM.activeItems.first(where: { $0.id == weaponInfo.id }),
                                   let definition = item.cardInstance?.definition {
                                    selectedWeaponDefinition = definition
                                }
                            }
                        )
                    }

                    // Backpack Weapons
                    if !inventoryVM.backpackItems.isEmpty {
                        let visibleCount = min(3, inventoryVM.backpackItems.count)
                        let moreCount = max(0, inventoryVM.backpackItems.count - 3)

                        InventorySlotView(
                            title: "Backpack",
                            icon: "backpack.fill",
                            iconColor: .orange,
                            weapons: inventoryVM.backpackItems.prefix(3).map { item in
                                InventoryWeaponInfo(
                                    id: item.id,
                                    name: inventoryVM.getWeaponName(from: item),
                                    set: inventoryVM.getWeaponSet(from: item),
                                    category: inventoryVM.getWeaponCategory(from: item),
                                    statsText: formatStats(for: item)
                                )
                            },
                            currentCount: inventoryVM.backpackItems.count,
                            maxCount: inventoryVM.backpackCapacity,
                            showMoreCount: moreCount > 0 ? moreCount : nil,
                            onTapWeapon: { weaponInfo in
                                if let item = inventoryVM.backpackItems.first(where: { $0.id == weaponInfo.id }),
                                   let definition = item.cardInstance?.definition {
                                    selectedWeaponDefinition = definition
                                }
                            },
                            onShowMore: {
                                showingInventorySheet = true
                            }
                        )
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .sheet(isPresented: $showingInventorySheet) {
            InventoryManagementSheetNew(
                session: session,
                inventoryVM: inventoryVM,
                context: modelContext
            )
        }
        .sheet(item: $selectedWeaponDefinition) { definition in
            WeaponDetailSheet(definition: definition)
        }
        .onAppear {
            inventoryVM.loadInventory(for: session)
        }
    }

    // MARK: - Helpers

    private func formatStats(for item: WeaponInventoryItem) -> String? {
        guard let definition = item.cardInstance?.definition else { return nil }

        // Format basic stats for display
        var parts: [String] = []

        if let dice = definition.dice {
            parts.append("Dice: \(dice)")
        }
        if let damage = definition.damage {
            parts.append("Damage: \(damage)")
        }

        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }
}

// MARK: - Inventory Management Sheet

private struct InventoryManagementSheetNew: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var session: GameSession
    @Bindable var inventoryVM: InventoryViewModel
    let context: ModelContext

    @State private var showingAddActiveWeapon = false
    @State private var showingAddBackpackWeapon = false
    @State private var showingCapacityAlert = false
    @State private var capacityAlertMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                // Active Weapons Section
                Section {
                    if inventoryVM.activeItems.isEmpty {
                        Text("No active weapons")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(inventoryVM.activeItems) { item in
                            weaponRow(for: item, slotType: "active")
                                .swipeActions(edge: .leading) {
                                    Button {
                                        Task {
                                            _ = await inventoryVM.moveActiveToBackpack(item, session: session)
                                        }
                                    } label: {
                                        Label("To Backpack", systemImage: "backpack.fill")
                                    }
                                    .tint(.orange)
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        Task {
                                            await inventoryVM.remove(item, session: session, discardToDeck: true)
                                        }
                                    } label: {
                                        Label("Discard", systemImage: "trash")
                                    }
                                }
                        }
                    }

                    Button {
                        showingAddActiveWeapon = true
                    } label: {
                        Label("Add Weapon", systemImage: "plus.circle")
                    }
                    .disabled(!inventoryVM.canAddToActive)

                    Text("Capacity: \(inventoryVM.activeItems.count)/\(inventoryVM.activeCapacity) slots")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Label("Active Weapons (Hands)", systemImage: "hand.raised.fill")
                }

                // Backpack Weapons Section
                Section {
                    if inventoryVM.backpackItems.isEmpty {
                        Text("No backpack weapons")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(inventoryVM.backpackItems) { item in
                            weaponRow(for: item, slotType: "backpack")
                                .swipeActions(edge: .leading) {
                                    Button {
                                        Task {
                                            _ = await inventoryVM.moveBackpackToActive(item, session: session)
                                        }
                                    } label: {
                                        Label("To Hands", systemImage: "hand.raised.fill")
                                    }
                                    .tint(.blue)
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        Task {
                                            await inventoryVM.remove(item, session: session, discardToDeck: true)
                                        }
                                    } label: {
                                        Label("Discard", systemImage: "trash")
                                    }
                                }
                        }
                    }

                    Button {
                        showingAddBackpackWeapon = true
                    } label: {
                        Label("Add Weapon", systemImage: "plus.circle")
                    }
                    .disabled(!inventoryVM.canAddToBackpack)

                    HStack {
                        Text("Capacity: \(inventoryVM.backpackItems.count)/\(inventoryVM.backpackCapacity) slots")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Stepper("Bonus: \(session.extraInventorySlots)", value: $session.extraInventorySlots, in: 0...10)
                            .font(.caption)
                    }
                } header: {
                    Label("Backpack", systemImage: "backpack.fill")
                }

                // Modifiers Section
                Section {
                    Toggle("All Inventory Counts as Active", isOn: $session.allInventoryActive)
                } header: {
                    Text("Modifiers")
                } footer: {
                    Text("Enable if a skill makes all weapons in your inventory count as active.")
                }
            }
            .navigationTitle("Manage Inventory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("No Capacity Available", isPresented: $showingCapacityAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(capacityAlertMessage)
            }
        }
    }

    @ViewBuilder
    private func weaponRow(for item: WeaponInventoryItem, slotType: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: slotType == "active" ? "hand.raised.fill" : "backpack.fill")
                .foregroundStyle(slotType == "active" ? .blue : .orange)
                .font(.caption)

            VStack(alignment: .leading, spacing: 2) {
                Text(inventoryVM.getWeaponName(from: item))
                    .foregroundStyle(.primary)
                Text(inventoryVM.getWeaponSet(from: item))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

// MARK: - Weapon Detail Sheet

private struct WeaponDetailSheet: View {
    let definition: WeaponDefinition
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Basic weapon info
                    VStack(alignment: .leading, spacing: 16) {
                        Text(definition.name)
                            .font(.title2)
                            .fontWeight(.bold)

                        HStack(spacing: 8) {
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

                            Text(definition.category)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.orange.opacity(0.2)))
                        }

                        // Stats
                        if let dice = definition.dice {
                            HStack {
                                Text("Dice:")
                                    .foregroundStyle(.secondary)
                                Text("\(dice)")
                            }
                        }

                        if let damage = definition.damage {
                            HStack {
                                Text("Damage:")
                                    .foregroundStyle(.secondary)
                                Text("\(damage)")
                            }
                        }

                        if let accuracy = definition.accuracy {
                            HStack {
                                Text("Accuracy:")
                                    .foregroundStyle(.secondary)
                                Text("\(accuracy)+")
                            }
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
                .padding()
            }
            .navigationTitle(definition.name)
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
}
