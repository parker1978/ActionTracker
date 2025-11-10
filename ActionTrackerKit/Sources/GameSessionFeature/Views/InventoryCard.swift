//
//  InventoryCard.swift
//  GameSessionFeature
//
//  Card for managing character weapon inventory
//

import SwiftUI
import SwiftData
import CoreDomain
import DataLayer
import SharedUI

// NOTE: WeaponsManager is passed from main app until WeaponsFeature is extracted (Phase 8)
// This maintains dependency rules while allowing functionality to work

/// Card for managing character weapon inventory
/// Players self-manage weapons with simple text input
struct InventoryCard: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var session: GameSession
    var weaponsManager: WeaponsManager
    @State private var showingInventorySheet = false
    @State private var selectedWeapon: Weapon?
    @State private var weaponDetailDetent: PresentationDetent = .fraction(0.75)

    // Parse weapon names from stored strings
    private var activeWeaponsList: [String] {
        InventoryFormatter.parse(session.activeWeapons)
    }

    private var inactiveWeaponsList: [String] {
        InventoryFormatter.parse(session.inactiveWeapons)
    }

    // Helper to find weapon by identifier (name|expansion)
    private func findWeapon(byIdentifier identifier: String) -> Weapon? {
        let parts = identifier.split(separator: "|").map(String.init)
        guard parts.count == 2 else { return nil }
        let name = parts[0]
        let expansion = parts[1]
        return WeaponRepository.shared.allWeapons.first { $0.name == name && $0.expansion == expansion }
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Label("Inventory", systemImage: "shield.lefthalf.filled")
                    .font(.headline)

                Spacer()

                // Weapon count
                let totalWeapons = activeWeaponsList.count + inactiveWeaponsList.count
                Text("\(totalWeapons) weapons")
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
            if activeWeaponsList.isEmpty && inactiveWeaponsList.isEmpty {
                Text("No weapons equipped")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    // Active Weapons
                    if !activeWeaponsList.isEmpty {
                        weaponSection(
                            title: "Active",
                            icon: "hand.raised.fill",
                            iconColor: .blue,
                            weapons: Array(activeWeaponsList.prefix(2)),
                            capacity: "(\(activeWeaponsList.count)/2)"
                        )
                    }

                    // Inactive Weapons
                    if !inactiveWeaponsList.isEmpty {
                        weaponSection(
                            title: "Backpack",
                            icon: "backpack.fill",
                            iconColor: .orange,
                            weapons: Array(inactiveWeaponsList.prefix(3)),
                            capacity: "(\(inactiveWeaponsList.count)/\(3 + session.extraInventorySlots))"
                        )

                        if inactiveWeaponsList.count > 3 {
                            Button {
                                showingInventorySheet = true
                            } label: {
                                Text("+ \(inactiveWeaponsList.count - 3) more...")
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .sheet(isPresented: $showingInventorySheet) {
            InventoryManagementSheet(session: session, weaponsManager: weaponsManager)
        }
        .sheet(item: $selectedWeapon) { weapon in
            NavigationStack {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 20) {
                            WeaponCardView(weapon: weapon)
                        }
                        .padding()
                    }
                    .scrollBounceBehavior(.basedOnSize)
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
            .presentationDetents([.fraction(0.75), .large], selection: $weaponDetailDetent)
            .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private func weaponSection(title: String, icon: String, iconColor: Color, weapons: [String], capacity: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(iconColor)
                Text("\(title) \(capacity)")
                    .font(.caption)
                    .fontWeight(.semibold)
            }

            ForEach(Array(weapons.enumerated()), id: \.offset) { _, weaponIdentifier in
                if let weapon = findWeapon(byIdentifier: weaponIdentifier) {
                    Button {
                        selectedWeapon = weapon
                    } label: {
                        weaponRow(weapon: weapon)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func weaponRow(weapon: Weapon) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(weapon.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }

            // Combat stats row
            HStack(spacing: 8) {
                if weapon.range != nil || weapon.rangeMin != nil {
                    statLabel(icon: "arrow.right", text: weapon.rangeDisplay)
                }
                if let dice = weapon.dice {
                    statLabel(icon: "dice", text: String(dice))
                }
                if let accuracy = weapon.accuracy {
                    statLabel(icon: "target", text: accuracy)
                }
                if let damage = weapon.damage {
                    statLabel(icon: "bolt.fill", text: String(damage))
                }
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func statLabel(icon: String, text: String) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption2)
        }
        .foregroundStyle(.secondary)
    }
}

// MARK: - Inventory Management Sheet

internal struct InventoryManagementSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var session: GameSession
    var weaponsManager: WeaponsManager

    @State private var activeWeapons: [String] = []
    @State private var inactiveWeapons: [String] = []
    @State private var userCancelled = false
    @State private var showingAddActiveWeapon = false
    @State private var showingAddInactiveWeapon = false
    @State private var selectedWeapon: Weapon?
    @State private var weaponDetailDetent: PresentationDetent = .fraction(0.75)
    @State private var showingCapacityAlert = false
    @State private var capacityAlertMessage = ""

    // Get all weapon identifiers (name|expansion) from repository, excluding zombie cards
    private var allWeaponNames: [String] {
        Array(Set(WeaponRepository.shared.allWeapons
            .filter { !$0.isZombieCard }
            .map { "\($0.name)|\($0.expansion)" }))
            .sorted()
    }

    // Helper to find weapon by identifier (name|expansion)
    private func findWeapon(byIdentifier identifier: String) -> Weapon? {
        let parts = identifier.split(separator: "|").map(String.init)
        guard parts.count == 2 else { return nil }
        let name = parts[0]
        let expansion = parts[1]
        return WeaponRepository.shared.allWeapons.first { $0.name == name && $0.expansion == expansion }
    }

    var body: some View {
        NavigationStack {
            Form {
                // Active Weapons Section
                Section {
                    if activeWeapons.isEmpty {
                        Text("No active weapons")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(activeWeapons.indices, id: \.self) { index in
                            weaponRow(
                                weapon: activeWeapons[index],
                                icon: "hand.raised.fill",
                                iconColor: .blue,
                                onInfo: {
                                    if let weapon = findWeapon(byIdentifier: activeWeapons[index]) {
                                        selectedWeapon = weapon
                                    }
                                }
                            )
                            .swipeActions(edge: .leading) {
                                Button {
                                    moveToBackpack(from: index)
                                } label: {
                                    Label("To Backpack", systemImage: "backpack.fill")
                                }
                                .tint(.orange)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    discardWeapon(activeWeapons[index])
                                    activeWeapons.remove(at: index)
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
                    .disabled(activeWeapons.count >= 2)

                    Text("Capacity: \(activeWeapons.count)/2 slots")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Label("Active Weapons (Hands)", systemImage: "hand.raised.fill")
                }

                // Inactive Weapons Section
                Section {
                    if inactiveWeapons.isEmpty {
                        Text("No inactive weapons")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(inactiveWeapons.indices, id: \.self) { index in
                            weaponRow(
                                weapon: inactiveWeapons[index],
                                icon: "backpack.fill",
                                iconColor: .orange,
                                onInfo: {
                                    if let weapon = findWeapon(byIdentifier: inactiveWeapons[index]) {
                                        selectedWeapon = weapon
                                    }
                                }
                            )
                            .swipeActions(edge: .leading) {
                                Button {
                                    moveToHands(from: index)
                                } label: {
                                    Label("To Hands", systemImage: "hand.raised.fill")
                                }
                                .tint(.blue)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    discardWeapon(inactiveWeapons[index])
                                    inactiveWeapons.remove(at: index)
                                } label: {
                                    Label("Discard", systemImage: "trash")
                                }
                            }
                        }
                    }

                    Button {
                        showingAddInactiveWeapon = true
                    } label: {
                        Label("Add Weapon", systemImage: "plus.circle")
                    }
                    .disabled(inactiveWeapons.count >= (3 + session.extraInventorySlots))

                    HStack {
                        Text("Capacity: \(inactiveWeapons.count)/\(3 + session.extraInventorySlots) slots")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Stepper("Bonus: \(session.extraInventorySlots)", value: $session.extraInventorySlots, in: 0...10)
                            .font(.caption)
                    }
                } header: {
                    Label("Inactive Weapons (Backpack)", systemImage: "backpack.fill")
                }

                // Modifiers Section
                Section {
                    Toggle("All Inventory Counts as Active", isOn: $session.allInventoryActive)
                } header: {
                    Text("Modifiers")
                } footer: {
                    Text("Enable this if a skill or ability makes all weapons in your inventory count as active.")
                }

                // Swipe Instructions Section
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.left")
                            .foregroundStyle(.blue)
                            .font(.caption)
                        Text("Swipe left to move items between lists")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 12) {
                        Image(systemName: "arrow.right")
                            .foregroundStyle(.red)
                            .font(.caption)
                        Text("Swipe right to delete items")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Swipe Actions")
                }
            }
            .navigationTitle("Manage Inventory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveInventory()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        userCancelled = true
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadInventory()
            }
            .onDisappear {
                if !userCancelled {
                    saveInventory()
                }
                userCancelled = false
            }
            .alert("No Capacity Available", isPresented: $showingCapacityAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(capacityAlertMessage)
            }
            .sheet(isPresented: $showingAddActiveWeapon) {
                WeaponPickerSheet(
                    allWeapons: allWeaponNames,
                    selectedWeapons: $activeWeapons,
                    title: "Add Active Weapon"
                )
            }
            .sheet(isPresented: $showingAddInactiveWeapon) {
                WeaponPickerSheet(
                    allWeapons: allWeaponNames,
                    selectedWeapons: $inactiveWeapons,
                    title: "Add Inactive Weapon"
                )
            }
            .sheet(item: $selectedWeapon) { weapon in
                NavigationStack {
                    VStack(spacing: 0) {
                        ScrollView {
                            VStack(spacing: 20) {
                                WeaponCardView(weapon: weapon)
                            }
                            .padding()
                        }
                        .scrollBounceBehavior(.basedOnSize)
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
                .presentationDetents([.fraction(0.75), .large], selection: $weaponDetailDetent)
                .presentationDragIndicator(.visible)
            }
        }
    }

    @ViewBuilder
    private func weaponRow(weapon: String, icon: String, iconColor: Color, onInfo: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .font(.caption)

            VStack(alignment: .leading, spacing: 2) {
                Text(weaponName(from: weapon))
                    .foregroundStyle(.primary)
                Text(weaponExpansion(from: weapon))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                onInfo()
            } label: {
                Image(systemName: "info.circle")
                    .font(.body)
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.borderless)
        }
    }

    private func weaponName(from identifier: String) -> String {
        let parts = identifier.split(separator: "|").map(String.init)
        return parts.first ?? identifier
    }

    private func weaponExpansion(from identifier: String) -> String {
        let parts = identifier.split(separator: "|").map(String.init)
        return parts.count == 2 ? parts[1] : ""
    }

    private func moveToBackpack(from index: Int) {
        if inactiveWeapons.count < (3 + session.extraInventorySlots) {
            let weaponName = activeWeapons[index]
            activeWeapons.remove(at: index)
            inactiveWeapons.append(weaponName)
        } else {
            capacityAlertMessage = "Backpack is full. Maximum capacity is \(3 + session.extraInventorySlots) slots."
            showingCapacityAlert = true
        }
    }

    private func moveToHands(from index: Int) {
        if activeWeapons.count < 2 {
            let weaponName = inactiveWeapons[index]
            inactiveWeapons.remove(at: index)
            activeWeapons.append(weaponName)
        } else {
            capacityAlertMessage = "Active weapons slots are full. Maximum capacity is 2 slots."
            showingCapacityAlert = true
        }
    }

    private func discardWeapon(_ weaponIdentifier: String) {
        if let weapon = findWeapon(byIdentifier: weaponIdentifier) {
            weaponsManager.getDeck(weapon.deck).discardCard(weapon)
        }
    }

    private func loadInventory() {
        activeWeapons = InventoryFormatter.parse(session.activeWeapons)
        inactiveWeapons = InventoryFormatter.parse(session.inactiveWeapons)
    }

    private func saveInventory() {
        session.activeWeapons = InventoryFormatter.join(activeWeapons)
        session.inactiveWeapons = InventoryFormatter.join(inactiveWeapons)
        try? modelContext.save()
    }
}

// MARK: - Weapon Picker Sheet

internal struct WeaponPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let allWeapons: [String]
    @Binding var selectedWeapons: [String]
    let title: String

    @State private var searchText = ""

    private var filteredWeapons: [String] {
        if searchText.isEmpty {
            return allWeapons
        } else {
            return allWeapons.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredWeapons, id: \.self) { weapon in
                    Button {
                        selectedWeapons.append(weapon)
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(weaponName(from: weapon))
                                    .foregroundStyle(.primary)
                                Text(weaponExpansion(from: weapon))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if selectedWeapons.contains(weapon) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search weapons")
            .navigationTitle(title)
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

    private func weaponName(from identifier: String) -> String {
        let parts = identifier.split(separator: "|").map(String.init)
        return parts.first ?? identifier
    }

    private func weaponExpansion(from identifier: String) -> String {
        let parts = identifier.split(separator: "|").map(String.init)
        return parts.count == 2 ? parts[1] : ""
    }
}
