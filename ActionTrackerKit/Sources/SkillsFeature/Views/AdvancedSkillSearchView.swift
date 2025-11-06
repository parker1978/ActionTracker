//
//  AdvancedSkillSearchView.swift
//  SkillsFeature
//

import SwiftUI
import SwiftData
import CoreDomain
import SharedUI

public struct AdvancedSkillSearchView: View {
    @Query var allCharacters: [CoreDomain.Character]
    @Query var allSkills: [CoreDomain.Skill]
    @State private var selectedSkills: Set<String> = []
    @State private var searchText = ""
    @State private var isSkillPickerExpanded = true

    public init() {}

    // MARK: - Computed Properties

    private var availableSkills: [String] {
        let allSkillNames = Set(allSkills.map { $0.name })
        return Array(allSkillNames).sorted()
    }

    private var filteredSkills: [String] {
        guard !searchText.isEmpty else { return availableSkills }
        return availableSkills.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    private var matchingCharacters: [CoreDomain.Character] {
        guard !selectedSkills.isEmpty else { return [] }

        return allCharacters.filter { character in
            selectedSkills.allSatisfy { skillName in
                character.allSkillsList.contains(skillName)
            }
        }
        .sorted { $0.name < $1.name }
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            // Selected skills display
            if !selectedSkills.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(Array(selectedSkills).sorted(), id: \.self) { skill in
                            HStack(spacing: 4) {
                                Text(skill)
                                    .font(.caption)

                                Button {
                                    var transaction = Transaction()
                                    transaction.disablesAnimations = true
                                    let _ = withTransaction(transaction) {
                                        selectedSkills.remove(skill)
                                    }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background {
                                Capsule()
                                    .fill(.blue.opacity(0.2))
                            }
                            .foregroundStyle(.blue)
                        }

                        Button("Clear All") {
                            var transaction = Transaction()
                            transaction.disablesAnimations = true
                            withTransaction(transaction) {
                                selectedSkills.removeAll()
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.red)
                    }
                    .padding()
                }
                .background(.ultraThinMaterial)

                Divider()
            }

            // Main content - Skill picker at top, results below
            List {
                // Skill selection section - Collapsible
                Section {
                    if isSkillPickerExpanded {
                        ForEach(filteredSkills, id: \.self) { skill in
                            Button {
                                var transaction = Transaction()
                                transaction.disablesAnimations = true
                                withTransaction(transaction) {
                                    if selectedSkills.contains(skill) {
                                        selectedSkills.remove(skill)
                                    } else {
                                        selectedSkills.insert(skill)
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(skill)
                                        .foregroundStyle(.primary)

                                    Spacer()

                                    if selectedSkills.contains(skill) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    Button {
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            isSkillPickerExpanded.toggle()
                        }
                    } label: {
                        HStack {
                            Text(selectedSkills.isEmpty ? "Select Skills to Filter" : "Add More Skills")
                            Spacer()
                            Image(systemName: isSkillPickerExpanded ? "chevron.down" : "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                } footer: {
                    if isSkillPickerExpanded {
                        Text("Select multiple skills to find characters that have ALL of them")
                    }
                }

                // Results section - Below skill picker
                if !selectedSkills.isEmpty {
                    Section {
                        if matchingCharacters.isEmpty {
                            ContentUnavailableView(
                                "No Matches",
                                systemImage: "person.crop.circle.badge.xmark",
                                description: Text("No characters have all selected skills")
                            )
                        } else {
                            ForEach(matchingCharacters) { character in
                                NavigationLink {
                                    CharacterDetailView(character: character)
                                } label: {
                                    AdvancedSearchCharacterRow(character: character, selectedSkills: selectedSkills)
                                }
                            }
                        }
                    } header: {
                        Text("\(matchingCharacters.count) Character(s) Found")
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search skills")
        }
        .navigationTitle("Advanced Search")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AdvancedSkillSearchView()
    }
}
