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
    @State private var searchText = ""
    @State private var showingNewCharacter = false

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

    var body: some View {
        NavigationStack {
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
            .navigationTitle("Characters")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNewCharacter = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewCharacter) {
                NewCharacterView()
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
