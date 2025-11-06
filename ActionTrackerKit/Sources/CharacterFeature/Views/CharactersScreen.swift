//
//  CharactersScreen.swift
//  CharacterFeature
//
//  Created by Stephen Parker on 6/6/25.
//

import SwiftUI
import SwiftData
import CoreDomain
import SharedUI

public struct CharactersScreen: View {
    @Query var allCharacters: [Character]

    public init() {}

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

    public var body: some View {
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

public struct CharactersSearchScreen: View {
    @Query var allCharacters: [Character]
    @State private var searchText = ""
    @State private var showingNewCharacter = false

    public init() {}

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

    public var body: some View {
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
