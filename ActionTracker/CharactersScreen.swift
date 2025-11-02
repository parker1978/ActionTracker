//
//  CharactersScreen.swift
//  ZombiTrack
//
//  Created by Stephen Parker on 6/6/25.
//

import SwiftUI
import SwiftData

struct CharactersScreen: View {
    @Query var allCharacters: [Character]

    // MARK: - Computed Properties

    var characters: [Character] {
        allCharacters.sorted {
            if $0.isFavorite == $1.isFavorite {
                return $0.name < $1.name
            }
            return $0.isFavorite && !$1.isFavorite
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                ForEach(characters) { character in
                    NavigationLink {
                        CharacterDetailView(character: character)
                    } label: {
                        CharacterRow(character: character)
                    }
                }
            }
            .navigationTitle("Characters")
            .toolbar {
                NavigationLink {
                    NewCharacterView()
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }
}

// MARK: - Characters Search Screen

struct CharactersSearchScreen: View {
    @Query var allCharacters: [Character]
    @Query var allSkills: [Skill]
    @State private var searchText = ""
    @State private var searchMode: SearchMode = .characters
    @State private var showingNewCharacter = false
    @State private var showingNewSkill = false

    // Advanced search state
    @State private var selectedSkills: [String] = []
    @State private var skillSearchText = ""
    @State private var isSearchingSkills = false

    enum SearchMode: String, CaseIterable {
        case characters = "Characters"
        case advancedSkillSearch = "Advanced Skill Search"
    }

    var characters: [Character] {
        allCharacters.sorted {
            if $0.isFavorite == $1.isFavorite {
                return $0.name < $1.name
            }
            return $0.isFavorite && !$1.isFavorite
        }
    }

    private var filteredCharacters: [Character] {
        guard !searchText.isEmpty else { return characters }
        let searchLower = searchText.lowercased()
        return characters.filter { character in
            character.name.lowercased().contains(searchLower) ||
            character.set.lowercased().contains(searchLower) ||
            character.allSkillsList.contains { skill in
                skill.lowercased().contains(searchLower)
            }
        }
    }

    // Advanced search computed properties
    private var skillSuggestions: [Skill] {
        guard !skillSearchText.isEmpty else { return [] }

        return allSkills
            .filter { skill in
                !selectedSkills.contains(skill.name) &&
                (skill.name.localizedCaseInsensitiveContains(skillSearchText) ||
                 skill.skillDescription.localizedCaseInsensitiveContains(skillSearchText))
            }
            .sorted { $0.name < $1.name }
            .prefix(10)
            .map { $0 }
    }

    private var filteredCharactersBySkills: [Character] {
        guard !selectedSkills.isEmpty else { return [] }

        return characters.filter { character in
            selectedSkills.allSatisfy { skillName in
                character.allSkillsList.contains(skillName)
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented control
                Picker("Search Mode", selection: $searchMode) {
                    ForEach(SearchMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Content based on selected mode
                if searchMode == .characters {
                    characterSearchView
                } else {
                    advancedSkillSearchView
                }
            }
            .navigationTitle("Search")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if searchMode == .characters {
                            showingNewCharacter = true
                        } else {
                            showingNewSkill = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewCharacter) {
                NewCharacterView()
            }
            .sheet(isPresented: $showingNewSkill) {
                NewSkillView()
            }
        }
    }

    // MARK: - Character Search View

    private var characterSearchView: some View {
        List {
            ForEach(filteredCharacters) { character in
                NavigationLink {
                    CharacterDetailView(character: character)
                } label: {
                    CharacterRow(character: character)
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search by name, set, or skill")
    }

    // MARK: - Advanced Skill Search View

    private var advancedSkillSearchView: some View {
        VStack(spacing: 0) {
            // Selected skills chips
            if !selectedSkills.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(selectedSkills, id: \.self) { skill in
                            HStack(spacing: 6) {
                                Text(skill)
                                    .font(.subheadline)
                                    .lineLimit(1)

                                Button {
                                    withAnimation {
                                        selectedSkills.removeAll { $0 == skill }
                                    }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.8))
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background {
                                Capsule()
                                    .fill(.blue)
                            }
                            .foregroundStyle(.white)
                        }

                        Button {
                            withAnimation {
                                selectedSkills.removeAll()
                            }
                        } label: {
                            Text("Clear All")
                                .font(.subheadline)
                                .foregroundStyle(.red)
                        }
                        .padding(.leading, 4)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                .background(.ultraThinMaterial)

                Divider()
            }

            // Main content area
            ZStack {
                // Character results list
                List {
                    if selectedSkills.isEmpty {
                        // Show helpful message when no filters applied
                        Section {
                            VStack(spacing: 12) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.secondary)

                                Text("Search for Skills")
                                    .font(.headline)

                                Text("Type in the search bar above to find skills, then tap to filter characters")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        }
                    } else if filteredCharactersBySkills.isEmpty {
                        ContentUnavailableView {
                            Label("No Matches", systemImage: "person.slash")
                        } description: {
                            Text("No characters have all \(selectedSkills.count) selected skill\(selectedSkills.count == 1 ? "" : "s")")
                        }
                    } else {
                        Section {
                            ForEach(filteredCharactersBySkills) { character in
                                NavigationLink {
                                    CharacterDetailView(character: character)
                                } label: {
                                    AdvancedSearchCharacterRow(
                                        character: character,
                                        selectedSkills: Set(selectedSkills)
                                    )
                                }
                            }
                        } header: {
                            Text("\(filteredCharactersBySkills.count) Character\(filteredCharactersBySkills.count == 1 ? "" : "s") Found")
                        }
                    }
                }
                .searchable(
                    text: $skillSearchText,
                    isPresented: $isSearchingSkills,
                    prompt: "Search skills to filter characters"
                )

                // Skill suggestions overlay (only when searching)
                if !skillSearchText.isEmpty && !skillSuggestions.isEmpty {
                    VStack(spacing: 0) {
                        List {
                            Section {
                                ForEach(skillSuggestions) { skill in
                                    Button {
                                        withAnimation {
                                            selectedSkills.append(skill.name)
                                            skillSearchText = ""
                                        }
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
                                                    .lineLimit(2)
                                            }
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                            } header: {
                                Text("Tap to add filter")
                                    .textCase(.none)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .scrollContentBackground(.hidden)
                        .background(.regularMaterial)
                    }
                }
            }
        }
    }
}

// MARK: - Character Row Component

struct CharacterRow: View {
    let character: Character

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(character.name)
                        .font(.headline)

                    if character.isFavorite {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption)
                    }

                    if !character.set.isEmpty {
                        Text(character.set)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: Capsule())
                            .foregroundStyle(.secondary)
                    }
                }

                // Show first few skills as preview
                if !character.allSkillsList.isEmpty {
                    Text(character.allSkillsList.prefix(3).joined(separator: " • "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()
        }
    }
}
