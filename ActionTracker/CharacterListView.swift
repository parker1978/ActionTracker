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
                        isShowingAddCharacter = true
                        selectedCharacter = character
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
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $isShowingAddCharacter) {
            AddCharacterView(character: selectedCharacter)
                .onDisappear {
                    // Reset selected character when sheet is dismissed
                    selectedCharacter = nil
                }
        }
    }
}

#Preview {
    ContentView()
}
