//
//  WeaponListRow.swift
//  SharedUI
//
//  Phase 4: Shared UI component for weapon list row
//

import SwiftUI
import CoreDomain

/// Displays a single weapon in a list with compact stats
/// Used in inventory lists, deck contents, and search results
public struct WeaponListRow: View {
    public let weaponName: String
    public let weaponSet: String
    public let category: String?
    public let icon: String?
    public let iconColor: Color?
    public var showInfoButton: Bool = true
    public var onInfo: (() -> Void)?

    public init(
        weaponName: String,
        weaponSet: String,
        category: String? = nil,
        icon: String? = nil,
        iconColor: Color? = nil,
        showInfoButton: Bool = true,
        onInfo: (() -> Void)? = nil
    ) {
        self.weaponName = weaponName
        self.weaponSet = weaponSet
        self.category = category
        self.icon = icon
        self.iconColor = iconColor
        self.showInfoButton = showInfoButton
        self.onInfo = onInfo
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Icon (if provided)
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundStyle(iconColor ?? .secondary)
                    .font(.caption)
            }

            // Weapon info
            VStack(alignment: .leading, spacing: 2) {
                Text(weaponName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                HStack(spacing: 8) {
                    Text(weaponSet)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if let category = category {
                        Text("•")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Text(category)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // Info button
            if showInfoButton, let onInfo = onInfo {
                Button(action: onInfo) {
                    Image(systemName: "info.circle")
                        .font(.body)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Convenience Initializers

extension WeaponListRow {
    /// Create row for inventory item
    public init(
        weaponName: String,
        weaponSet: String,
        slotIcon: String,
        slotColor: Color,
        category: String? = nil,
        onInfo: (() -> Void)? = nil
    ) {
        self.init(
            weaponName: weaponName,
            weaponSet: weaponSet,
            category: category,
            icon: slotIcon,
            iconColor: slotColor,
            showInfoButton: true,
            onInfo: onInfo
        )
    }
}

#Preview {
    VStack(spacing: 8) {
        WeaponListRow(
            weaponName: "Pistol",
            weaponSet: "Core",
            category: "Firearm",
            icon: "hand.raised.fill",
            iconColor: .blue,
            onInfo: {}
        )

        WeaponListRow(
            weaponName: "Chainsaw",
            weaponSet: "Fort Hendrix",
            category: "Melee",
            icon: "backpack.fill",
            iconColor: .orange,
            onInfo: {}
        )

        WeaponListRow(
            weaponName: "Fire Axe",
            weaponSet: "Core",
            showInfoButton: false
        )

        WeaponListRow(
            weaponName: "Sniper Rifle",
            weaponSet: "Army Ranger",
            category: "Firearm",
            onInfo: {}
        )
    }
    .padding()
}
