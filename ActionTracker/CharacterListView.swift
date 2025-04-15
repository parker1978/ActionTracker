//
//  CharacterListView.swift
//  ZombicideCharacters
//
//  Created by Stephen Parker on 4/11/25.
//

import SwiftUI
import SwiftData

struct CharacterListView: View {
    @Query(sort: \Character.name) var characters: [Character]
    @State private var searchText = ""
    @Binding var isShowingAddCharacter: Bool
    @State private var isShowingEditCharacter = false
    @State private var selectedCharacter: Character?
    @Environment(\.modelContext) private var context

    var filteredCharacters: [Character] {
        guard !searchText.isEmpty else { return characters }
        return characters.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.allSkills.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        ZStack {
            NavigationStack {
                List {
                    // Navigation link to skill search
                    NavigationLink(destination: SkillSearchView()) {
                        Label("Search by Skills", systemImage: "magnifyingglass")
                    }

                    // Main list of characters
                    ForEach(filteredCharacters) { character in
                        Button {
                            // Navigate to edit character
                            selectedCharacter = character
                            isShowingEditCharacter = true
                        } label: {
                            VStack(alignment: .leading) {
                                Text(character.set?.isEmpty == false ? "\(character.name) (\(character.set!))" : character.name)
                                    .font(.headline)
                                Text(character.allSkills.joined(separator: ", ")).font(.caption)
                            }
                            .foregroundColor(.primary)
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                withAnimation {
                                    context.delete(character)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                withAnimation {
                                    context.delete(character)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .searchable(text: $searchText)
                .modifier(CharacterSeeder())
                .listStyle(PlainListStyle())
                .toolbar(.hidden, for: .navigationBar)
            }
        }
        // Sheet for adding a new character
        .sheet(isPresented: $isShowingAddCharacter) {
            NavigationStack {
                AddCharacterView(character: nil)
            }
        }
        // Sheet for editing an existing character
        .sheet(isPresented: $isShowingEditCharacter) {
            if let character = selectedCharacter {
                NavigationStack {
                    AddCharacterView(character: character)
                }
                .onDisappear {
                    // Reset selected character when sheet is dismissed
                    selectedCharacter = nil
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
