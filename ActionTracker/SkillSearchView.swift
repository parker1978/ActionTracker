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
    @State private var isShowingEditCharacter = false
    @State private var selectedCharacter: Character?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    // Returns filtered characters matching ALL selected skills
    var filteredCharacters: [Character] {
        allCharacters.filter { character in
            selectedSkills.allSatisfy { skill in
                character.allSkills.contains(skill)
            }
        }
    }

    // Return skills available for the dropdown at given index position
    func availableSkills(for index: Int) -> [String] {
        // For first dropdown show all skills, for subsequent dropdowns filter by current matches
        let characters = index == 0 ? allCharacters : filteredCharacters
        
        // Don't show skills already selected in previous dropdowns
        let usedSkills = Set(selectedSkills.prefix(index))
        
        // Get all skills from relevant characters
        let remainingSkills = characters.flatMap { $0.allSkills }
        
        // Remove duplicates and already selected skills, then sort alphabetically
        let uniqueRemaining = Set(remainingSkills).subtracting(usedSkills)
        return Array(uniqueRemaining).sorted()
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
                                                Text(skill).tag(skill)
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
                                        ForEach(searchResults) { character in
                                            Button {
                                                selectedCharacter = character
                                                isShowingEditCharacter = true
                                            } label: {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(character.set?.isEmpty == false ? "\(character.name) (\(character.set!))" : character.name)
                                                        .font(.headline)
                                                    
                                                    // Highlight matched skills in the results
                                                    SkillsView(allSkills: character.allSkills, highlightSkills: selectedSkills)
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
        .sheet(isPresented: $isShowingEditCharacter) {
            if let character = selectedCharacter {
                AddCharacterView(character: character)
                    .onDisappear {
                        selectedCharacter = nil
                    }
            }
        }
    }

    private func dropdownCount() -> Int {
        // Maximum number of skill dropdowns to show
        let maxDropdowns = min(5, allCharacters.flatMap { $0.allSkills }.count)
        
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
                matching = matching.filter { $0.allSkills.contains(currentSkill) }
                
                // Check if there are any remaining skills for the next dropdown
                let usedSet = Set(currentSkills)
                let available = Set(matching.flatMap { $0.allSkills }).subtracting(usedSet)
                
                if available.isEmpty {
                    count = i + 1
                    break
                }
            }
        }

        return count
    }
    
    private func performSearch() {
        searchResults = filteredCharacters
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
        
        for (index, skill) in allSkills.enumerated() {
            var skillText = AttributedString(skill)
            
            // Highlight matches
            if highlightSkills.contains(skill) {
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
}
