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

    var filteredCharacters: [Character] {
        allCharacters.filter { character in
            selectedSkills.allSatisfy { skill in
                character.allSkills.contains(skill)
            }
        }
    }

    func availableSkills(for index: Int) -> [String] {
        let characters = index == 0 ? allCharacters : filteredCharacters
        let usedSkills = Set(selectedSkills.prefix(index))
        let remainingSkills = characters.flatMap { $0.allSkills }
        let uniqueRemaining = Set(remainingSkills).subtracting(usedSkills)
        return uniqueRemaining.sorted()
    }

    var body: some View {
        NavigationStack {
            Form {
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
                                if index < selectedSkills.count {
                                    selectedSkills[index] = newValue
                                } else {
                                    selectedSkills.append(newValue)
                                }
                                performSearch()
                            })) {
                            Text("").tag("")
                            ForEach(skills, id: \.self) { skill in
                                Text(skill).tag(skill)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                }

                if hasSearched {
                    if searchResults.isEmpty {
                        Text("No characters found with all selected skills.")
                            .foregroundColor(.secondary)
                    } else {
                        Section("Results") {
                            ForEach(searchResults) { character in
                                VStack(alignment: .leading) {
                                    Text(character.name).font(.headline)
                                    Text(character.allSkills.joined(separator: ", "))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Search by Skills")
        }
    }

    private func dropdownCount() -> Int {
        var count = 0
        var currentSkills = [String]()
        var matching = allCharacters

        while true {
            if matching.count <= 1 { break } // Stop if only one or zero characters remain

            let usedSet = Set(currentSkills)
            let available = Set(matching.flatMap { $0.allSkills }).subtracting(usedSet)

            if available.isEmpty { break }

            count += 1
            if count > selectedSkills.count { break }

            if let currentSkill = selectedSkills[safe: count - 1] {
                currentSkills.append(currentSkill)
                matching = matching.filter { $0.allSkills.contains(currentSkill) }
            }
        }

        return count
    }
    
    private func performSearch() {
        searchResults = filteredCharacters
        hasSearched = true
    }
}
