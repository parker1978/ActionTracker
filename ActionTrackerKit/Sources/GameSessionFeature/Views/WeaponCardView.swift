//
//  WeaponCardView.swift
//  ActionTracker
//
//  Displays a weapon card with all its stats and abilities
//  Used in modals, recent draws, and inventory views
//

import SwiftUI
import CoreDomain
import SharedUI

struct WeaponCardView: View {
    let weapon: Weapon

    var body: some View {
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
            Text("Combat Stats")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                // Range
                StatBadge(
                    icon: "arrow.right",
                    label: "Range",
                    value: weapon.rangeDisplay
                )

                // Dice
                if let dice = weapon.dice {
                    StatBadge(
                        icon: "dice",
                        label: "Dice",
                        value: "\(dice)"
                    )
                }

                // Accuracy
                if let accuracy = weapon.accuracy {
                    StatBadge(
                        icon: "target",
                        label: "Accuracy",
                        value: accuracy
                    )
                }

                // Damage
                if let damage = weapon.damage {
                    StatBadge(
                        icon: "bolt.fill",
                        label: "Damage",
                        value: "\(damage)"
                    )
                }

                // Ammo Type
                if weapon.ammoType != .none {
                    StatBadge(
                        icon: "circle.grid.3x3.fill",
                        label: "Ammo",
                        value: weapon.ammoType.displayName
                    )
                }

                // Overload
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

                if weapon.killNoise {
                    AbilityTag(icon: "speaker.wave.3", text: "Kill Noise", color: .orange)
                } else if !weapon.isBonus && !weapon.isZombieCard {
                    AbilityTag(icon: "speaker.slash", text: "Silent", color: .gray)
                }

                // Melee Ranged special indicator
                if weapon.category == .meleeRanged {
                    AbilityTag(icon: "bolt.trianglebadge.exclamationmark", text: "Dual Mode", color: .purple)
                }
            }
        }
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

struct StatBadge: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
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
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

// MARK: - Ability Tag

struct AbilityTag: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
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

            // Gunblade example
            WeaponCardView(weapon: Weapon(
                name: "Gunblade",
                expansion: "Core",
                deck: .ultrared,
                count: 1,
                category: .meleeRanged,
                dice: 2,
                accuracy: "4+",
                damage: 2,
                rangeMin: 0,
                rangeMax: 1,
                range: 0,
                ammoType: .bullets,
                openDoor: false,
                doorNoise: false,
                killNoise: true,
                dual: true,
                overload: false,
                overloadDice: nil,
                special: "For Melee: Roll 4 dice. No kill noise."
            ))
        }
        .padding()
    }
}
