//
//  WeaponCardView.swift
//  ActionTracker
//
//  Displays a weapon card with all its stats and abilities
//  Used in modals, recent draws, and inventory views
//

import SwiftUI
import CoreDomain

#if canImport(UIKit)
import UIKit
#endif

public struct WeaponCardView: View {
    let weapon: Weapon

    public init(weapon: Weapon) {
        self.weapon = weapon
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            cardHeader

            // Combat Stats (if applicable)
            if !weapon.isBonus && !weapon.isZombieCard {
                combatStats
            }

            // Abilities & Features
            abilitiesSection

            // Special Text
            if !weapon.special.isEmpty {
                specialSection
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(weapon.deck.color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(weapon.deck.color, lineWidth: 2)
                )
        )
    }

    // MARK: - Header

    private var cardHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Weapon Name
                Text(weapon.name)
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                // Category Icon
                Image(systemName: weapon.category.icon)
                    .font(.title2)
                    .foregroundStyle(weapon.category.color)
            }

            // Expansion & Deck
            HStack(spacing: 8) {
                if !weapon.expansion.isEmpty {
                    Text(weapon.expansion)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color(.systemGray5)))
                }

                Text(weapon.deck.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(weapon.deck.color.opacity(0.2)))
                    .foregroundStyle(weapon.deck.color)
            }
        }
    }

    // MARK: - Combat Stats

    private var combatStats: some View {
        VStack(alignment: .leading, spacing: 12) {
            // For Dual weapons, show both Melee and Ranged sections
            if weapon.category == .dual {
                // Melee Section
                if let meleeStats = weapon.meleeStats {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Melee Combat Stats")
                            .font(.headline)
                        meleeStatsView(meleeStats)
                    }
                }

                // Ranged Section
                if let rangedStats = weapon.rangedStats {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ranged Combat Stats")
                            .font(.headline)
                        rangedStatsView(rangedStats)
                    }
                }
            }
            // For Melee-only weapons
            else if weapon.category == .melee, let meleeStats = weapon.meleeStats {
                Text("Combat Stats")
                    .font(.headline)
                meleeStatsView(meleeStats)
            }
            // For Ranged-only weapons
            else if weapon.category == .ranged, let rangedStats = weapon.rangedStats {
                Text("Combat Stats")
                    .font(.headline)
                rangedStatsView(rangedStats)
            }
            // Legacy fallback for old format
            else {
                Text("Combat Stats")
                    .font(.headline)
                legacyStatsView
            }
        }
    }

    private func meleeStatsView(_ stats: MeleeStats) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Build array of badges to display
            let badges = buildMeleeBadges(stats)

            // Use LazyVGrid with flexible columns
            let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Array(badges.enumerated()), id: \.offset) { _, badge in
                    badge
                }
            }
        }
    }

    @ViewBuilder
    private func buildMeleeBadges(_ stats: MeleeStats) -> [AnyView] {
        var badges: [AnyView] = []

        // Always show Range
        badges.append(AnyView(StatBadge(icon: "arrow.right", label: "Range", value: "\(stats.range)")))

        // Show Dice only if > 0
        if stats.dice > 0 {
            badges.append(AnyView(StatBadge(icon: "dice", label: "Dice", value: "\(stats.dice)")))
        }

        // Show Overload only if > 0
        if stats.overload > 0 {
            badges.append(AnyView(StatBadge(icon: "exclamationmark.triangle", label: "Overload", value: "+\(stats.overload)")))
        }

        // Accuracy badge with special styling for 100%
        if stats.isAutoHit {
            badges.append(AnyView(StatBadge(icon: "target", label: "Accuracy", value: stats.accuracyDisplay, backgroundColor: Color.green.opacity(0.2))))
        } else {
            badges.append(AnyView(StatBadge(icon: "target", label: "Accuracy", value: stats.accuracyDisplay)))
        }

        // Show Damage only if > 0
        if stats.damage > 0 {
            badges.append(AnyView(StatBadge(icon: "bolt.fill", label: "Damage", value: "\(stats.damage)")))
        }

        return badges
    }

    private func rangedStatsView(_ stats: RangedStats) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Build array of badges to display
            let badges = buildRangedBadges(stats)

            // Use LazyVGrid with flexible columns
            let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Array(badges.enumerated()), id: \.offset) { _, badge in
                    badge
                }
            }

            // Ammo as pill capsule below badges
            if stats.ammoType != .none {
                HStack(spacing: 4) {
                    Image(systemName: "circle.grid.3x3.fill")
                        .font(.caption)
                    Text(stats.ammoType.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color(.systemGray5)))
                .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func buildRangedBadges(_ stats: RangedStats) -> [AnyView] {
        var badges: [AnyView] = []

        // Always show Range
        let rangeDisplay = stats.rangeMin == stats.rangeMax ? "\(stats.rangeMin)" : "\(stats.rangeMin)-\(stats.rangeMax)"
        badges.append(AnyView(StatBadge(icon: "arrow.right", label: "Range", value: rangeDisplay)))

        // Show Dice only if > 0
        if stats.dice > 0 {
            badges.append(AnyView(StatBadge(icon: "dice", label: "Dice", value: "\(stats.dice)")))
        }

        // Show Overload only if > 0
        if stats.overload > 0 {
            badges.append(AnyView(StatBadge(icon: "exclamationmark.triangle", label: "Overload", value: "+\(stats.overload)")))
        }

        // Accuracy badge with special styling for 100%
        if stats.isAutoHit {
            badges.append(AnyView(StatBadge(icon: "target", label: "Accuracy", value: stats.accuracyDisplay, backgroundColor: Color.green.opacity(0.2))))
        } else {
            badges.append(AnyView(StatBadge(icon: "target", label: "Accuracy", value: stats.accuracyDisplay)))
        }

        // Show Damage only if > 0
        if stats.damage > 0 {
            badges.append(AnyView(StatBadge(icon: "bolt.fill", label: "Damage", value: "\(stats.damage)")))
        }

        return badges
    }

    private var legacyStatsView: some View {
        VStack(spacing: 12) {
            // First row: Range, Dice, Accuracy
            HStack(spacing: 12) {
                StatBadge(
                    icon: "arrow.right",
                    label: "Range",
                    value: weapon.rangeDisplay
                )

                if let dice = weapon.dice {
                    StatBadge(
                        icon: "dice",
                        label: "Dice",
                        value: "\(dice)"
                    )
                }

                if let accuracy = weapon.accuracy {
                    StatBadge(
                        icon: "target",
                        label: "Accuracy",
                        value: accuracy
                    )
                }
            }

            // Second row: Damage, Ammo, Overload
            HStack(spacing: 12) {
                if let damage = weapon.damage {
                    StatBadge(
                        icon: "bolt.fill",
                        label: "Damage",
                        value: "\(damage)"
                    )
                }

                if weapon.ammoType != .none {
                    StatBadge(
                        icon: "circle.grid.3x3.fill",
                        label: "Ammo",
                        value: weapon.ammoType.displayName
                    )
                }

                if weapon.overload {
                    let overloadValue = weapon.overloadDice.map { "+\($0)" } ?? "Yes"
                    StatBadge(
                        icon: "exclamationmark.triangle",
                        label: "Overload",
                        value: overloadValue
                    )
                }
            }
        }
    }

    // MARK: - Abilities

    private var abilitiesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Only show abilities section if weapon has any abilities
            let hasAbilities = weapon.dual || weapon.openDoor || hasKillNoise || weapon.category == .dual

            if hasAbilities {
                Text("Abilities")
                    .font(.headline)

                FlowLayout(spacing: 8) {
                    if weapon.dual {
                        AbilityTag(icon: "02.circle", text: "Dual", color: .blue)
                    }

                    if weapon.openDoor {
                        AbilityTag(
                            icon: weapon.doorNoise ? "door.left.hand.open" : "door.left.hand.closed",
                            text: weapon.doorNoise ? "Open Door (Noise)" : "Open Door",
                            color: .green
                        )
                    }

                    // Kill noise handling based on new format
                    if hasKillNoise {
                        AbilityTag(icon: "speaker.wave.3", text: "Kill Noise", color: .orange)
                    } else if !weapon.isBonus && !weapon.isZombieCard {
                        AbilityTag(icon: "speaker.slash", text: "Silent", color: .gray)
                    }

                    // Dual Mode special indicator
                    if weapon.category == .dual {
                        AbilityTag(icon: "bolt.trianglebadge.exclamationmark", text: "Dual Mode", color: .purple)
                    }
                }
            }
        }
    }

    private var hasKillNoise: Bool {
        // Check new format first
        if let meleeStats = weapon.meleeStats, meleeStats.killNoise {
            return true
        }
        if let rangedStats = weapon.rangedStats, rangedStats.killNoise {
            return true
        }
        // Fall back to legacy format
        return weapon.killNoise
    }

    // MARK: - Special

    private var specialSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Special")
                .font(.headline)

            Text(weapon.special)
                .font(.body)
                .foregroundStyle(.secondary)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray6))
                )
        }
    }
}

// MARK: - Stat Badge

public struct StatBadge: View {
    let icon: String
    let label: String
    let value: String
    let backgroundColor: Color

    public init(icon: String, label: String, value: String, backgroundColor: Color? = nil) {
        self.icon = icon
        self.label = label
        self.value = value
        self.backgroundColor = backgroundColor ?? Color(.secondarySystemGroupedBackground)
    }

    public var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColor)
        )
    }
}

// MARK: - Ability Tag

public struct AbilityTag: View {
    let icon: String
    let text: String
    let color: Color

    public init(icon: String, text: String, color: Color) {
        self.icon = icon
        self.text = text
        self.color = color
    }

    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)

            Text(text)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(color.opacity(0.15)))
        .foregroundStyle(color)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            // Sample weapon card
            WeaponCardView(weapon: Weapon(
                name: "Fire Axe",
                expansion: "Core",
                deck: .starting,
                count: 1,
                category: .melee,
                dice: 1,
                accuracy: "4+",
                damage: 2,
                rangeMin: nil,
                rangeMax: nil,
                range: 0,
                ammoType: .none,
                openDoor: true,
                doorNoise: true,
                killNoise: false,
                dual: false,
                overload: false,
                overloadDice: nil,
                special: ""
            ))

            // Gunblade example (Dual weapon)
            WeaponCardView(weapon: Weapon(
                name: "Gunblade",
                expansion: "Zombicide 2nd Edition",
                deck: .ultrared,
                count: 1,
                category: .dual,
                meleeStats: MeleeStats(
                    range: 0,
                    dice: 2,
                    accuracy: 4,
                    damage: 2,
                    overload: 0,
                    killNoise: false
                ),
                rangedStats: RangedStats(
                    ammoType: .bullets,
                    rangeMin: 0,
                    rangeMax: 1,
                    dice: 1,
                    accuracy: 4,
                    damage: 2,
                    overload: 0,
                    killNoise: true
                ),
                openDoor: false,
                doorNoise: false,
                dual: false,
                special: "For Melee: Roll 4 dice. No kill noise."
            ))
        }
        .padding()
    }
}
