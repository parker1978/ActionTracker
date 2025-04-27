//
//  SkillManagerView.swift
//  ActionTracker
//
//  Created by Stephen Parker on 4/27/25.
//

import SwiftUI
import SwiftData
import Observation

struct SkillManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var appViewModel: AppViewModel
    
    var character: Character
    let experience: Int
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Character") {
                    HStack {
                        Text(character.name)
                            .font(.headline)
                        
                        if let set = character.set, !set.isEmpty {
                            Text("(\(set))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Blue Skills - always active by default
                Section("Blue Skills") {
                    if character.blueSkills.isEmpty {
                        Text("No blue skills available")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(character.blueSkills, id: \.self) { skill in
                            SkillToggleRow(
                                skill: skill,
                                isActive: character.activeBlueSkills.contains(skill),
                                color: .skillBlue,
                                isEnabled: true,
                                toggleAction: { isActive in
                                    if isActive {
                                        character.activateSkill(name: skill, color: .blue)
                                    } else {
                                        character.deactivateSkill(name: skill, color: .blue)
                                    }
                                    try? context.save()
                                }
                            )
                        }
                    }
                }
                
                // Orange Skills - available at XP 19
                let orangeSkillsAllowed = appViewModel.getMaxOrangeSkills()
                Section(header: Text("Orange Skills (Available at XP 19+)")) {
                    if character.orangeSkills.isEmpty {
                        Text("No orange skills available")
                            .foregroundColor(.secondary)
                    } else {
                        if experience < 19 {
                            Text("Character hasn't reached Orange skill level yet (XP 19)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 4)
                        } else {
                            Text("Can select \(orangeSkillsAllowed) orange skill(s)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 4)
                        }
                        
                        ForEach(character.orangeSkills, id: \.self) { skill in
                            SkillToggleRow(
                                skill: skill,
                                isActive: character.activeOrangeSkills.contains(skill),
                                color: .skillOrange,
                                isEnabled: experience >= 19 && 
                                          (character.activeOrangeSkills.contains(skill) || 
                                           character.activeOrangeSkills.count < orangeSkillsAllowed),
                                toggleAction: { isActive in
                                    if isActive {
                                        character.activateSkill(name: skill, color: .orange)
                                    } else {
                                        character.deactivateSkill(name: skill, color: .orange)
                                    }
                                    try? context.save()
                                }
                            )
                        }
                    }
                }
                
                // Red Skills - available at XP 43
                let redSkillsAllowed = appViewModel.getMaxRedSkills()
                Section(header: Text("Red Skills (Available at XP 43+)")) {
                    if character.redSkills.isEmpty {
                        Text("No red skills available")
                            .foregroundColor(.secondary)
                    } else {
                        if experience < 43 {
                            Text("Character hasn't reached Red skill level yet (XP 43)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 4)
                        } else {
                            Text("Can select \(redSkillsAllowed) red skill(s)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 4)
                        }
                        
                        ForEach(character.redSkills, id: \.self) { skill in
                            SkillToggleRow(
                                skill: skill,
                                isActive: character.activeRedSkills.contains(skill),
                                color: .skillRed,
                                isEnabled: experience >= 43 && 
                                          (character.activeRedSkills.contains(skill) || 
                                           character.activeRedSkills.count < redSkillsAllowed),
                                toggleAction: { isActive in
                                    if isActive {
                                        character.activateSkill(name: skill, color: .red)
                                    } else {
                                        character.deactivateSkill(name: skill, color: .red)
                                    }
                                    try? context.save()
                                }
                            )
                        }
                    }
                }
            }
            .navigationTitle("Manage Skills")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// Row component for toggling a skill - optimized with equatable
struct SkillToggleRow: View, Equatable {
    let skill: String
    let isActive: Bool
    let color: Color
    let isEnabled: Bool
    let toggleAction: (Bool) -> Void
    
    // For efficient SwiftUI rendering with ForEach
    static func == (lhs: SkillToggleRow, rhs: SkillToggleRow) -> Bool {
        return lhs.skill == rhs.skill &&
               lhs.isActive == rhs.isActive &&
               lhs.isEnabled == rhs.isEnabled
    }
    
    var body: some View {
        HStack {
            Toggle(isOn: Binding(
                get: { isActive },
                set: { toggleAction($0) }
            )) {
                Text(skill)
                    .foregroundColor(isEnabled ? .primary : .secondary)
            }
            .tint(color)
            .disabled(!isEnabled)
        }
        // Add id for stable identity in views
        .id("skill_toggle_\(skill)_\(isActive ? "active" : "inactive")")
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var mockCharacter: Character?
        
        var body: some View {
            VStack {
                if let character = mockCharacter {
                    SkillManagerView(
                        character: character,
                        experience: 45
                    )
                } else {
                    Text("Loading preview...")
                        .onAppear {
                            let character = Character(
                                name: "Preview Character",
                                blueSkills: ["Zombie Link", "Taunt"],
                                orangeSkills: ["+1 Die: Combat", "+1 To Dice Roll: Melee"],
                                redSkills: ["+1 Damage: Combat", "+1 Free Action: Combat"]
                            )
                            
                            mockCharacter = character
                        }
                }
            }
        }
    }
    
    return PreviewWrapper()
}