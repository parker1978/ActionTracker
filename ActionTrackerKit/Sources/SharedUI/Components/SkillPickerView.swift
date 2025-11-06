//
//  SkillPickerView.swift
//  SharedUI
//
//  Created by Stephen Parker on 6/6/25.
//

import SwiftUI
import SwiftData
import CoreDomain

public struct SkillPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // Support both patterns: binding for NewCharacterView, callback for CharacterDetailView
    @Binding var selectedSkills: [String]
    let excludedSkills: [String]
    let allSkills: [Skill]

    // Optional callback pattern for backward compatibility
    var currentSkills: [String]?
    var colorTier: String?
    var onSelect: ((String) -> Void)?

    // Optional closure for adding new skills (allows parent to control behavior)
    var onAddNewSkill: (() -> Void)?

    @State private var searchText = ""

    public init(
        selectedSkills: Binding<[String]>,
        excludedSkills: [String],
        allSkills: [Skill],
        onAddNewSkill: (() -> Void)? = nil
    ) {
        self._selectedSkills = selectedSkills
        self.excludedSkills = excludedSkills
        self.allSkills = allSkills
        self.currentSkills = nil
        self.colorTier = nil
        self.onSelect = nil
        self.onAddNewSkill = onAddNewSkill
    }

    public init(
        currentSkills: [String],
        colorTier: String,
        allSkills: [Skill],
        onSelect: @escaping (String) -> Void,
        onAddNewSkill: (() -> Void)? = nil
    ) {
        self._selectedSkills = .constant([])
        self.excludedSkills = currentSkills
        self.allSkills = allSkills
        self.currentSkills = currentSkills
        self.colorTier = colorTier
        self.onSelect = onSelect
        self.onAddNewSkill = onAddNewSkill
    }

    var filteredSkills: [Skill] {
        let filtered = searchText.isEmpty ? allSkills : allSkills.filter { skill in
            skill.name.localizedCaseInsensitiveContains(searchText) ||
            skill.skillDescription.localizedCaseInsensitiveContains(searchText)
        }

        // Filter out skills already selected/excluded
        return filtered.filter { skill in
            !excludedSkills.contains(skill.name)
        }
    }

    public var body: some View {
        NavigationStack {
            List {
                if filteredSkills.isEmpty {
                    ContentUnavailableView {
                        Label("No Skills Found", systemImage: "magnifyingglass")
                    } description: {
                        if searchText.isEmpty {
                            Text("All available skills have been added.")
                        } else {
                            Text("Try a different search term or create a new skill.")
                        }
                    }
                } else {
                    ForEach(filteredSkills, id: \.id) { skill in
                        Button {
                            if let onSelect = onSelect {
                                // Legacy callback pattern
                                onSelect(skill.name)
                            } else {
                                // New binding pattern
                                selectedSkills.append(skill.name)
                            }
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(skill.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)

                                if !skill.skillDescription.isEmpty {
                                    Text(skill.skillDescription)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle(colorTier ?? "Add Skill")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .searchable(text: $searchText, prompt: "Search skills")
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                #endif

                // Only show add button if parent provides the closure
                if let onAddNewSkill = onAddNewSkill {
                    #if os(iOS)
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            onAddNewSkill()
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                    #else
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            onAddNewSkill()
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                    #endif
                }
            }
        }
    }
}

#Preview {
    SkillPickerView(
        currentSkills: ["Barbarian", "+1 Damage: Combat"],
        colorTier: "Blue",
        allSkills: [],
        onSelect: { skillName in
            print("Selected: \(skillName)")
        }
    )
}
