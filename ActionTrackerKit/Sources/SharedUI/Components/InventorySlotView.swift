//
//  InventorySlotView.swift
//  SharedUI
//
//  Phase 4: Shared UI component for inventory slot display
//

import SwiftUI

/// Displays an inventory slot with weapon information and capacity indicator
/// Used in inventory cards and management views
public struct InventorySlotView: View {
    public let title: String
    public let icon: String
    public let iconColor: Color
    public let weapons: [InventoryWeaponInfo]
    public let currentCount: Int
    public let maxCount: Int
    public let showMoreCount: Int?
    public var onTapWeapon: ((InventoryWeaponInfo) -> Void)?
    public var onShowMore: (() -> Void)?

    public init(
        title: String,
        icon: String,
        iconColor: Color,
        weapons: [InventoryWeaponInfo],
        currentCount: Int,
        maxCount: Int,
        showMoreCount: Int? = nil,
        onTapWeapon: ((InventoryWeaponInfo) -> Void)? = nil,
        onShowMore: (() -> Void)? = nil
    ) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.weapons = weapons
        self.currentCount = currentCount
        self.maxCount = maxCount
        self.showMoreCount = showMoreCount
        self.onTapWeapon = onTapWeapon
        self.onShowMore = onShowMore
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Section header with capacity
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(iconColor)
                Text("\(title) (\(currentCount)/\(maxCount))")
                    .font(.caption)
                    .fontWeight(.semibold)
            }

            // Weapons list
            if weapons.isEmpty {
                Text("No weapons")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            } else {
                ForEach(weapons) { weaponInfo in
                    if let onTap = onTapWeapon {
                        Button(action: { onTap(weaponInfo) }) {
                            weaponRow(weaponInfo: weaponInfo)
                        }
                    } else {
                        weaponRow(weaponInfo: weaponInfo)
                    }
                }
            }

            // Show more button
            if let showMoreCount = showMoreCount, showMoreCount > 0, let onShowMore = onShowMore {
                Button(action: onShowMore) {
                    Text("+ \(showMoreCount) more...")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
                .padding(.leading, 4)
            }
        }
    }

    @ViewBuilder
    private func weaponRow(weaponInfo: InventoryWeaponInfo) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(weaponInfo.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                Spacer()
                if onTapWeapon != nil {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }

            // Stats display
            if let statsText = weaponInfo.statsText {
                Text(statsText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Supporting Types

public struct InventoryWeaponInfo: Identifiable {
    public let id: UUID
    public let name: String
    public let set: String
    public let category: String?
    public let statsText: String?

    public init(
        id: UUID = UUID(),
        name: String,
        set: String,
        category: String? = nil,
        statsText: String? = nil
    ) {
        self.id = id
        self.name = name
        self.set = set
        self.category = category
        self.statsText = statsText
    }
}

#Preview {
    VStack(spacing: 16) {
        InventorySlotView(
            title: "Active",
            icon: "hand.raised.fill",
            iconColor: .blue,
            weapons: [
                InventoryWeaponInfo(
                    name: "Pistol",
                    set: "Core",
                    category: "Firearm",
                    statsText: "Range: 2-4 • Dice: 2 • Damage: 1"
                ),
                InventoryWeaponInfo(
                    name: "Fire Axe",
                    set: "Core",
                    category: "Melee",
                    statsText: "Range: 1 • Dice: 3 • Damage: 2"
                )
            ],
            currentCount: 2,
            maxCount: 2,
            onTapWeapon: { _ in }
        )

        InventorySlotView(
            title: "Backpack",
            icon: "backpack.fill",
            iconColor: .orange,
            weapons: [
                InventoryWeaponInfo(
                    name: "Chainsaw",
                    set: "Fort Hendrix",
                    category: "Melee"
                ),
                InventoryWeaponInfo(
                    name: "Sniper Rifle",
                    set: "Army Ranger",
                    category: "Firearm"
                ),
                InventoryWeaponInfo(
                    name: "Shotgun",
                    set: "Core",
                    category: "Firearm"
                )
            ],
            currentCount: 5,
            maxCount: 6,
            showMoreCount: 2,
            onTapWeapon: { _ in },
            onShowMore: {}
        )

        InventorySlotView(
            title: "Active",
            icon: "hand.raised.fill",
            iconColor: .blue,
            weapons: [],
            currentCount: 0,
            maxCount: 2
        )
    }
    .padding()
}
