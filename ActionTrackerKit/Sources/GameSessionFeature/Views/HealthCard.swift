//
//  HealthCard.swift
//  GameSessionFeature
//
//  Card for tracking character health during gameplay
//

import SwiftUI
import SwiftData
import CoreDomain

/// Card for tracking character health during gameplay
/// Health starts at character's base health value and can be incremented/decremented
/// Minimum health: 0, Maximum health: 10
struct HealthCard: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var session: GameSession

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Label("Health", systemImage: "heart.fill")
                    .font(.headline)
                    .foregroundStyle(.red)

                Spacer()

                // Max health indicator
                if let character = session.character {
                    Text("Max: \(character.health)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            // Health counter with increment/decrement buttons
            HStack(spacing: 20) {
                // Decrement button
                Button {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        if session.currentHealth > 0 {
                            session.currentHealth -= 1
                        }
                        try? modelContext.save()
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title)
                        .foregroundStyle(session.currentHealth > 0 ? healthColor : .gray)
                }
                .disabled(session.currentHealth <= 0)

                // Health display
                VStack(spacing: 8) {
                    Text("\(session.currentHealth)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .frame(minWidth: 100)
                        .foregroundStyle(healthColor)

                    // Health bar - shows all segments with color change for filled vs empty
                    HStack(spacing: 4) {
                        ForEach(0..<maxHealthSegments, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(index < session.currentHealth ? healthColor : emptySegmentColor)
                                .frame(width: 40, height: 10)
                        }
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: session.currentHealth)
                }

                // Increment button
                Button {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        if session.currentHealth < 5 {
                            session.currentHealth += 1
                        }
                        try? modelContext.save()
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title)
                        .foregroundStyle(session.currentHealth < 5 ? healthColor : .gray)
                }
                .disabled(session.currentHealth >= 10)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    /// Color for health display based on absolute health value
    /// Most characters start with 3 health (their normal max)
    private var healthColor: Color {
        switch session.currentHealth {
        case 0:
            return .gray  // Dead/unconscious
        case 1:
            return .red   // Critical
        case 2:
            return .orange // Damaged
        default:
            return .green  // 3+ is healthy/normal (including bonus health)
        }
    }

    /// Number of segments to display in health bar
    /// Shows segments up to the character's max health, or current health if higher (for bonus health)
    private var maxHealthSegments: Int {
        guard let character = session.character else { return session.currentHealth }
        return max(character.health, session.currentHealth)
    }

    /// Color for empty health segments - visible against .ultraThinMaterial background
    private var emptySegmentColor: Color {
        Color(.systemGray4)
    }
}
