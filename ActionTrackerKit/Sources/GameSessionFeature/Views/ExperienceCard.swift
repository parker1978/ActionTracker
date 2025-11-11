//
//  ExperienceCard.swift
//  GameSessionFeature
//
//  Card for tracking and managing character experience (XP) and skills
//

import SwiftUI
import SwiftData
import CoreDomain

/// Card for tracking and managing character experience (XP) and skills
/// Displays current XP, cycle information, skill levels, and active skills
/// Handles automatic skill selection at XP milestones
struct ExperienceCard: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var session: GameSession
    @State private var showingSkillSelection = false

    var body: some View {
        VStack(spacing: 16) {
            // MARK: Header with Cycle Indicator
            HStack {
                Label("Experience", systemImage: "star.fill")
                    .font(.headline)

                Spacer()

                // Show cycle number if in cycle 2 or 3
                if session.xpCycle > 1 {
                    Text("Cycle \(session.xpCycle)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.orange.opacity(0.2))
                        .foregroundStyle(.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }

            // MARK: XP Counter
            HStack(spacing: 20) {
                // Decrement button
                Button {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        if session.currentExperience > 0 {
                            session.currentExperience -= 1
                        }
                        try? modelContext.save()
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title)
                        .foregroundStyle(session.currentExperience > 0 ? .orange : .gray)
                }
                .disabled(session.currentExperience <= 0)

                // XP display with cycle position
                VStack(spacing: 4) {
                    Text("\(session.currentExperience)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .frame(minWidth: 80)

                    Text("(\(session.displayNormalizedXP) in cycle)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // Increment button
                Button {
                    let previousXP = session.currentExperience
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        session.currentExperience += 1

                        // Auto-add action when reaching Yellow (XP 7)
                        if previousXP < 7 && session.currentExperience >= 7 {
                            session.addAction(ofType: .action)
                        }

                        try? modelContext.save()
                    }
                    // Check if skill selection needed
                    if session.needsSkillSelection() != nil {
                        showingSkillSelection = true
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title)
                        .foregroundStyle(.orange)
                }
            }

            // MARK: XP Level Indicator
            HStack(spacing: 8) {
                XPLevelBadge(
                    level: "Blue",
                    range: "0-6",
                    isActive: true,
                    color: .blue
                )
                XPLevelBadge(
                    level: "Yellow",
                    range: "7-18",
                    isActive: session.currentExperience >= 7,
                    color: .yellow
                )
                XPLevelBadge(
                    level: "Orange",
                    range: "19-42",
                    isActive: session.currentExperience >= 19,
                    color: .orange
                )
                XPLevelBadge(
                    level: "Red",
                    range: "43",
                    isActive: session.currentExperience >= 43,
                    color: .red
                )
            }

            // MARK: Active Skills Summary
            if !session.getActiveSkills().isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()

                    HStack {
                        Label("Active Skills", systemImage: "sparkles")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Spacer()

                        // Button to open skill selection sheet
                        Button {
                            showingSkillSelection = true
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.subheadline)
                        }
                    }

                    // List of currently active skills with color coding
                    ForEach(session.getActiveSkills(), id: \.self) { skill in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(skillColor(for: skill).gradient)
                                .frame(width: 6, height: 6)

                            Text(skill)
                                .font(.caption)

                            Spacer()
                        }
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .sheet(isPresented: $showingSkillSelection) {
            SkillSelectionSheet(session: session, isPresented: $showingSkillSelection)
        }
    }

    /// Determines the color for a skill based on its tier
    private func skillColor(for skill: String) -> Color {
        guard let character = session.character else { return .gray }

        if character.blueSkillsList.contains(skill) {
            return .blue
        } else if character.yellowSkillsList.contains(skill) {
            return .yellow
        } else if character.orangeSkillsList.contains(skill) {
            return .orange
        } else if character.redSkillsList.contains(skill) {
            return .red
        }
        return .gray
    }
}

// MARK: - XP Level Badge

/// Badge displaying a skill level tier (Blue, Yellow, Orange, or Red)
/// Shows the level name, XP range, and highlights when active
struct XPLevelBadge: View {
    let level: String
    let range: String
    let isActive: Bool
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(level)
                .font(.caption2)
                .fontWeight(.semibold)
            Text(range)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            isActive ? color.opacity(0.2) : Color.clear,
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isActive ? color : .gray.opacity(0.3), lineWidth: 2)
        )
    }
}

// MARK: - Skill Selection Sheet

/// Sheet for viewing and selecting character skills at various XP thresholds
/// Displays all skill tiers with selection controls based on current XP cycle
internal struct SkillSelectionSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var session: GameSession
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // MARK: Current XP Info
                    VStack(spacing: 8) {
                        HStack {
                            Label("Current XP", systemImage: "star.fill")
                                .font(.headline)
                            Spacer()
                            Text("\(session.currentExperience)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .monospacedDigit()
                        }

                        HStack {
                            Text("Cycle \(session.xpCycle)")
                                .font(.subheadline)
                            Spacer()
                            Text("Position: \(session.displayNormalizedXP)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

                    // MARK: Blue Skills (Always Active)
                    if let character = session.character, !character.blueSkillsList.isEmpty {
                        SkillLevelSection(
                            title: "Blue Skills (Always Active)",
                            color: .blue,
                            skills: character.blueSkillsList,
                            selectedSkills: character.blueSkillsList,
                            isSelectable: false,
                            onSelect: { _ in }
                        )
                    }

                    // MARK: Yellow Skills (Auto-selected at XP 7)
                    if let character = session.character, !character.yellowSkillsList.isEmpty {
                        SkillLevelSection(
                            title: "Yellow Skills (Active at 7+ XP)",
                            color: .yellow,
                            skills: character.yellowSkillsList,
                            selectedSkills: session.normalizedXP >= 7 ? [session.selectedYellowSkill] : [],
                            isSelectable: false,
                            onSelect: { _ in }
                        )
                    }

                    // MARK: Orange Skills (Choose 1 in Cycle 1, gain 2nd in Cycle 2)
                    if let character = session.character, !character.orangeSkillsList.isEmpty {
                        let availableSkills = character.orangeSkillsList
                        let selectedSkills = session.selectedOrangeSkillsList
                        let canSelect = session.normalizedXP >= 19 && session.xpCycle == 1

                        SkillLevelSection(
                            title: orangeSkillTitle,
                            color: .orange,
                            skills: availableSkills,
                            selectedSkills: selectedSkills,
                            isSelectable: canSelect,
                            onSelect: { skill in
                                var transaction = Transaction()
                                transaction.disablesAnimations = true
                                withTransaction(transaction) {
                                    // Replace selection (only 1 allowed in cycle 1)
                                    session.selectedOrangeSkills = skill
                                    try? modelContext.save()
                                }
                            }
                        )
                    }

                    // MARK: Red Skills (Choose 1 in Cycle 1, 2nd in Cycle 2, gain 3rd in Cycle 3)
                    if let character = session.character, !character.redSkillsList.isEmpty {
                        let availableSkills = character.redSkillsList
                        let selectedSkills = session.selectedRedSkillsList
                        let maxSelections = session.xpCycle == 1 ? 1 : 2
                        let canSelect = session.currentExperience >= 43

                        SkillLevelSection(
                            title: redSkillTitle,
                            color: .red,
                            skills: availableSkills,
                            selectedSkills: selectedSkills,
                            isSelectable: canSelect,
                            maxSelections: maxSelections,
                            onSelect: { skill in
                                var transaction = Transaction()
                                transaction.disablesAnimations = true
                                withTransaction(transaction) {
                                    var currentSelections = session.selectedRedSkillsList

                                    if maxSelections == 1 {
                                        // Cycle 1: Replace selection (like orange)
                                        session.selectedRedSkills = skill
                                    } else {
                                        // Cycle 2+: Toggle selection
                                        if currentSelections.contains(skill) {
                                            // Deselect
                                            currentSelections.removeAll { $0 == skill }
                                        } else if currentSelections.count < maxSelections {
                                            // Add selection
                                            currentSelections.append(skill)
                                        }
                                        session.selectedRedSkills = currentSelections.joined(separator: ";")
                                    }

                                    try? modelContext.save()
                                }
                            }
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Skills")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }

    /// Generates appropriate title for orange skills based on cycle
    private var orangeSkillTitle: String {
        let cycle = session.xpCycle
        let selected = session.selectedOrangeSkillsList.count

        if cycle == 1 {
            return "Orange Skills (Choose 1 at 19+ XP)"
        } else if cycle == 2 && selected < 2 {
            return "Orange Skills (Gain Remaining)"
        } else {
            return "Orange Skills (Active at 19+ XP)"
        }
    }

    /// Generates appropriate title for red skills based on cycle
    private var redSkillTitle: String {
        let cycle = session.xpCycle
        let selected = session.selectedRedSkillsList.count

        if cycle == 1 {
            return "Red Skills (Choose 1 at 43 XP)"
        } else if cycle == 2 && selected < 2 {
            return "Red Skills (Choose 2nd)"
        } else if cycle == 3 && selected < 3 {
            return "Red Skills (Gain Last)"
        } else {
            return "Red Skills (Active at 43 XP)"
        }
    }
}

// MARK: - Skill Level Section

/// Section displaying skills of a specific tier (Blue, Yellow, Orange, or Red)
/// Handles skill selection logic based on cycle and tier restrictions
struct SkillLevelSection: View {
    let title: String
    let color: Color
    let skills: [String]
    let selectedSkills: [String]
    let isSelectable: Bool
    var maxSelections: Int = 0
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(color)

            VStack(spacing: 8) {
                ForEach(skills, id: \.self) { skill in
                    SkillRow(
                        skill: skill,
                        color: color,
                        isSelected: selectedSkills.contains(skill),
                        isSelectable: isSelectable,
                        canToggle: isSelectable && (maxSelections == 1 || selectedSkills.contains(skill) || selectedSkills.count < maxSelections || maxSelections == 0),
                        onSelect: { onSelect(skill) }
                    )
                }
            }
        }
        .padding()
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Skill Row

/// Individual skill row with selection state and tap handling
struct SkillRow: View {
    let skill: String
    let color: Color
    let isSelected: Bool
    let isSelectable: Bool
    let canToggle: Bool
    let onSelect: () -> Void

    var body: some View {
        Button {
            if canToggle {
                onSelect()
            }
        } label: {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? color : .gray)
                    .font(.title3)

                Text(skill)
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                Spacer()
            }
            .padding()
            .background(
                isSelected ? color.opacity(0.15) : Color(.systemGray6),
                in: RoundedRectangle(cornerRadius: 8)
            )
        }
        .disabled(!canToggle)
        .opacity(canToggle || isSelected ? 1.0 : 0.6)
    }
}
