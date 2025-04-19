//
//  SkillSearchView.swift
//  ZombicideCharacters
//
//  Created by Stephen Parker on 4/11/25.
//

import SwiftUI
import SwiftData

struct SkillSearchView: View {
    @Query var allCharacters: [Character]
    @State private var selectedSkills: [String] = []
    @State private var searchResults: [Character] = []
    @State private var hasSearched = false
    @State private var selectedCharacter: Character?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    // Returns filtered characters matching ALL selected skills, including group skills
    var filteredCharacters: [Character] {
        allCharacters.filter { character in
            let characterSkillNames = (character.skills ?? []).map { $0.name }
            
            return selectedSkills.allSatisfy { skill in
                if isGroupSkill(skill) {
                    // For a group skill, check if character has ANY of the skills in the group
                    let groupSkills = skillsInGroup(skill)
                    return !Set(characterSkillNames).isDisjoint(with: groupSkills)
                } else {
                    // For a regular skill, character must have the exact skill
                    return characterSkillNames.contains(skill)
                }
            }
        }
    }

    // Return skills available for the dropdown at given index position, including custom group skills
    func availableSkills(for index: Int) -> [String] {
        // For first dropdown show all skills, for subsequent dropdowns filter by current matches
        let characters = index == 0 ? allCharacters : filteredCharacters
        
        // Don't show skills already selected in previous dropdowns
        let usedSkills = Set(selectedSkills.prefix(index))
        
        // Get all skills from relevant characters
        let remainingSkills = characters.flatMap { ($0.skills ?? []).map { $0.name } }
        
        // Remove duplicates and already selected skills
        let uniqueRemaining = Set(remainingSkills).subtracting(usedSkills)
        
        // Create a dictionary to group skills by their prefix (up to the colon)
        var skillGroups: [String: [String]] = [:]
        
        // Process each skill to find common prefixes
        for skill in uniqueRemaining {
            if let colonIndex = skill.firstIndex(of: ":") {
                let prefix = String(skill[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                if prefix.isEmpty { continue }
                
                if skillGroups[prefix] == nil {
                    skillGroups[prefix] = [skill]
                } else {
                    skillGroups[prefix]!.append(skill)
                }
            }
        }
        
        // Create the final list with group headers and individual skills
        var result: [String] = []
        
        // Add group skills to the top (only if they have more than one skill in the group)
        let groupPrefixes = skillGroups.filter { $0.value.count > 1 }
                                      .keys
                                      .sorted()
        
        for prefix in groupPrefixes {
            // Create a formatted group skill that's not actually a real skill but a group identifier
            let groupSkill = prefix
            result.append(groupSkill)
        }
        
        // Add all individual skills, sorted alphabetically
        let sortedSkills = Array(uniqueRemaining).sorted()
        result.append(contentsOf: sortedSkills)
        
        return result
    }
    
    // Get all skills that belong to a group prefix
    private func skillsInGroup(_ prefix: String) -> [String] {
        let allSkillsList = allCharacters.flatMap { ($0.skills ?? []).map { $0.name } }
        
        return allSkillsList.filter { skill in
            if let colonIndex = skill.firstIndex(of: ":") {
                let skillPrefix = String(skill[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                return skillPrefix == prefix
            }
            return false
        }
    }
    
    // Check if a skill is a group header
    private func isGroupSkill(_ skill: String) -> Bool {
        // If it contains no colon but exists as a prefix for other skills
        if !skill.contains(":") {
            let grouped = skillsInGroup(skill)
            return !grouped.isEmpty
        }
        return false
    }

    var body: some View {
        ZStack {
            NavigationStack {
                VStack {
                    if allCharacters.isEmpty {
                        ContentUnavailableView(
                            "No Characters",
                            systemImage: "person.fill.questionmark",
                            description: Text("Add some characters first")
                        )
                        .padding(.top, 50)
                    } else {
                        Form {
                            Section("Select Skills") {
                                ForEach(0..<dropdownCount(), id: \.self) { index in
                                    let skills = availableSkills(for: index)
                                    if !skills.isEmpty {
                                        Picker("Skill \(index + 1)", selection: Binding(
                                            get: {
                                                if index < selectedSkills.count {
                                                    return selectedSkills[index]
                                                } else {
                                                    return ""
                                                }
                                            },
                                            set: { newValue in
                                                withAnimation {
                                                    // If changing an existing selection
                                                    if index < selectedSkills.count {
                                                        // If selection cleared, remove this and all subsequent selections
                                                        if newValue.isEmpty {
                                                            selectedSkills.removeSubrange(index...)
                                                        } else {
                                                            // Update with new selection, remove all subsequent selections
                                                            selectedSkills[index] = newValue
                                                            if selectedSkills.count > index + 1 {
                                                                selectedSkills.removeSubrange((index + 1)...)
                                                            }
                                                        }
                                                    } else if !newValue.isEmpty {
                                                        // Adding a new selection
                                                        selectedSkills.append(newValue)
                                                    }
                                                    performSearch()
                                                }
                                            })) {
                                            Text("Select a skill").tag("")
                                            ForEach(skills, id: \.self) { skill in
                                                if isGroupSkill(skill) {
                                                    // Display group skills with bold text and an indicator
                                                    Text("\(skill) (Group)")
                                                        .bold()
                                                        .tag(skill)
                                                } else {
                                                    Text(skill).tag(skill)
                                                }
                                            }
                                        }
                                        .pickerStyle(MenuPickerStyle())
                                    }
                                }
                                
                                if !selectedSkills.isEmpty {
                                    Button(role: .destructive) {
                                        withAnimation {
                                            selectedSkills.removeAll()
                                            performSearch()
                                        }
                                    } label: {
                                        Label("Clear All Selections", systemImage: "xmark.circle")
                                    }
                                }
                            }

                            if hasSearched {
                                Section {
                                    if searchResults.isEmpty {
                                        Text("No characters found with all selected skills.")
                                            .foregroundColor(.secondary)
                                            .frame(maxWidth: .infinity, alignment: .center)
                                            .padding()
                                    } else {
                                        Text("Found \(searchResults.count) character\(searchResults.count == 1 ? "" : "s")")
                                            .foregroundColor(.secondary)
                                            .font(.caption)
                                    }
                                }
                                
                                if !searchResults.isEmpty {
                                    Section("Results") {
                                        // Results are already sorted in performSearch()
                                        ForEach(searchResults) { character in
                                            Button {
                                                selectedCharacter = character
                                            } label: {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(character.set?.isEmpty == false ? "\(character.name) (\(character.set!))" : character.name)
                                                        .font(.headline)
                                                    
                                                    // Highlight matched skills in the results
                                                    SkillsView(
                                                        allSkills: (character.skills ?? []).sorted { $0.position < $1.position }.map { $0.name }, 
                                                        highlightSkills: selectedSkills
                                                    )
                                                }
                                                .padding(.vertical, 4)
                                                .foregroundColor(.primary)
                                            }
                                        }
                                    }
                                }
                            } else {
                                Section {
                                    Text("Found \(allCharacters.count) character\(searchResults.count == 1 ? "" : "s")")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                            }
                        }
                    }
                }
                .navigationTitle("Search by Skills")
            }
        }
        // Sheet for editing a character - using item presentation for reliability
        .sheet(item: $selectedCharacter) { character in
            NavigationStack {
                AddCharacterView(character: character)
            }
        }
    }

    private func dropdownCount() -> Int {
        // Maximum number of skill dropdowns to show
        let maxDropdowns = min(5, allCharacters.flatMap { ($0.skills ?? []).map { $0.name } }.count)
        
        // Calculate how many dropdowns to show based on current selections and available skills
        var count = min(selectedSkills.count + 1, maxDropdowns)
        var currentSkills = [String]()
        var matching = allCharacters

        // Don't show more dropdowns than needed
        for i in 0..<count {
            if matching.count <= 1 { 
                count = i + 1
                break 
            }

            if let currentSkill = selectedSkills[safe: i] {
                currentSkills.append(currentSkill)
                matching = matching.filter { character in 
                    let skillNames = (character.skills ?? []).map { $0.name }
                    return skillNames.contains(currentSkill)
                }
                
                // Check if there are any remaining skills for the next dropdown
                let usedSet = Set(currentSkills)
                let available = Set(matching.flatMap { ($0.skills ?? []).map { $0.name } }).subtracting(usedSet)
                
                if available.isEmpty {
                    count = i + 1
                    break
                }
            }
        }

        return count
    }
    
    private func performSearch() {
        // Sort the filtered characters by name, then by set
        searchResults = filteredCharacters.sorted { char1, char2 in
            if char1.name != char2.name {
                return char1.name < char2.name // Primary sort by name
            } else {
                // Secondary sort by set if names are identical
                let set1 = char1.set ?? ""
                let set2 = char2.set ?? ""
                return set1 < set2
            }
        }
        hasSearched = true
    }
}

// Component to display skills with highlighting for matches
struct SkillsView: View {
    let allSkills: [String]
    let highlightSkills: [String]
    
    var body: some View {
        Text(attributedSkillsString)
            .font(.caption)
    }
    
    private var attributedSkillsString: AttributedString {
        var result = AttributedString("")
        
        // Get the skills sorted by position if they're from a character
        for (index, skill) in allSkills.enumerated() {
            var skillText = AttributedString(skill)
            
            // Determine if this skill should be highlighted
            let shouldHighlight = isSkillHighlighted(skill)
            
            // Apply highlighting
            if shouldHighlight {
                skillText.foregroundColor = .blue
                skillText.font = .caption.bold()
            } else {
                skillText.foregroundColor = .secondary
            }
            
            result.append(skillText)
            
            // Add separators between skills
            if index < allSkills.count - 1 {
                var separator = AttributedString(", ")
                separator.foregroundColor = .secondary
                result.append(separator)
            }
        }
        
        return result
    }
    
    // Determine if a skill should be highlighted based on direct matches or group matches
    private func isSkillHighlighted(_ skill: String) -> Bool {
        // Direct match
        if highlightSkills.contains(skill) {
            return true
        }
        
        // Check if this skill matches any group
        if let colonIndex = skill.firstIndex(of: ":") {
            let prefix = String(skill[..<colonIndex]).trimmingCharacters(in: .whitespaces)
            if highlightSkills.contains(prefix) {
                return true
            }
        }
        
        return false
    }
}
