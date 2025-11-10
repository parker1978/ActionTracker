//
//  InventoryManagementSheet.swift
//  ActionTracker
//
//  Sheet for replacing weapons when inventory is full
//

import SwiftUI
import CoreDomain
import DataLayer

public struct InventoryManagementSheet: View {
    @Environment(\.dismiss) private var dismiss
    let weaponToAdd: Weapon
    let session: GameSession
    let onReplace: (Weapon) -> Void

    public init(weaponToAdd: Weapon, session: GameSession, onReplace: @escaping (Weapon) -> Void) {
        self.weaponToAdd = weaponToAdd
        self.session = session
        self.onReplace = onReplace
    }

    // Parse current inventory
    private var activeWeapons: [String] {
        InventoryFormatter.parse(session.activeWeapons)
    }

    private var inactiveWeapons: [String] {
        InventoryFormatter.parse(session.inactiveWeapons)
    }

    public var body: some View {
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
                            ForEach(Array(activeWeapons.enumerated()), id: \.offset) { _, weaponIdentifier in
                                Button {
                                    replaceWeapon(weaponIdentifier)
                                } label: {
                                    HStack {
                                        Image(systemName: "hand.raised.fill")
                                            .foregroundStyle(.blue)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(weaponName(from: weaponIdentifier))
                                                .foregroundStyle(.primary)
                                            Text(weaponExpansion(from: weaponIdentifier))
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
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
                            ForEach(Array(inactiveWeapons.enumerated()), id: \.offset) { _, weaponIdentifier in
                                Button {
                                    replaceWeapon(weaponIdentifier)
                                } label: {
                                    HStack {
                                        Image(systemName: "backpack.fill")
                                            .foregroundStyle(.green)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(weaponName(from: weaponIdentifier))
                                                .foregroundStyle(.primary)
                                            Text(weaponExpansion(from: weaponIdentifier))
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
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

    private func replaceWeapon(_ weaponIdentifier: String) {
        // Parse the identifier to get name and expansion
        let parts = weaponIdentifier.split(separator: "|").map(String.init)
        guard parts.count == 2 else {
            dismiss()
            return
        }
        let name = parts[0]
        let expansion = parts[1]

        // Find the weapon object to discard
        guard let weaponToDiscard = WeaponRepository.shared.allWeapons.first(where: { $0.name == name && $0.expansion == expansion }) else {
            dismiss()
            return
        }

        // Remove from inventory and add new weapon
        var newActiveWeapons = activeWeapons
        var newInactiveWeapons = inactiveWeapons

        if let activeIndex = newActiveWeapons.firstIndex(of: weaponIdentifier) {
            newActiveWeapons[activeIndex] = "\(weaponToAdd.name)|\(weaponToAdd.expansion)"
            session.activeWeapons = InventoryFormatter.join(newActiveWeapons)
        } else if let inactiveIndex = newInactiveWeapons.firstIndex(of: weaponIdentifier) {
            newInactiveWeapons[inactiveIndex] = "\(weaponToAdd.name)|\(weaponToAdd.expansion)"
            session.inactiveWeapons = InventoryFormatter.join(newInactiveWeapons)
        }

        // Call the callback to discard the replaced weapon
        onReplace(weaponToDiscard)
        dismiss()
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
