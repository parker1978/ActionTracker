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
    
    // For debugging
    @State private var debugMessage: String = ""

    var filteredCharacters: [Character] {
        guard !searchText.isEmpty else { return characters }
        
        // Check for special search tokens
        if searchText.lowercased().hasPrefix("set:") {
            let setQuery = searchText.dropFirst(4).trimmingCharacters(in: .whitespaces)
            return characters.filter { 
                guard let set = $0.set else { return false }
                return set.localizedCaseInsensitiveContains(setQuery)
            }
        } else if searchText.lowercased().hasPrefix("skill:") {
            let skillQuery = searchText.dropFirst(6).trimmingCharacters(in: .whitespaces)
            return characters.filter { 
                ($0.skills ?? []).contains { 
                    $0.name.localizedCaseInsensitiveContains(skillQuery)
                }
            }
        } else {
            // Standard search - name or any skill
            return characters.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                ($0.skills ?? []).contains { $0.name.localizedCaseInsensitiveContains(searchText) } ||
                (($0.set ?? "").localizedCaseInsensitiveContains(searchText))
            }
        }
    }

    var body: some View {
        ZStack {
            NavigationStack {
                VStack(spacing: 0) {
                    // Prominent search bar at the top
                    SearchBar(text: $searchText)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color(.systemBackground))
                    
                    List {
                        // Debug section (collapsible)
                        DisclosureGroup("Characters / Skills Info") {
                            Text("Characters: \(characters.count)")
                            Button("Refresh Data") {
                                refreshDataModel()
                            }
                            Text(debugMessage)
                        }
                        
                        // Navigation link to skill search
                        Section {
                            NavigationLink(destination: SkillSearchView()) {
                                Label("Search by Skills", systemImage: "magnifyingglass")
                            }
                        }

                        // Main list of characters
                        Section("Characters") {
                            ForEach(filteredCharacters) { character in
                                Button {
                                    // Navigate to edit character
                                    selectedCharacter = character
                                } label: {
                                    VStack(alignment: .leading) {
                                        Text(character.set?.isEmpty == false ? "\(character.name) (\(character.set!))" : character.name)
                                            .font(.headline)
                                        // Display skills sorted by position with enhanced description display
                                        SkillsWithDescriptionView(skills: (character.skills ?? []).sorted { $0.position < $1.position })
                                    }
                                    .foregroundColor(.primary)
                                }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        withAnimation {
                                            // Remove the character from all its skills but don't delete skills
                                            for skill in (character.skills ?? []) {
                                                if skill.characters == nil {
                                                    skill.characters = []
                                                }
                                                skill.characters?.removeAll { $0.id == character.id }
                                            }
                                            // Then delete the character
                                            context.delete(character)
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        withAnimation {
                                            // Remove the character from all its skills but don't delete skills
                                            for skill in (character.skills ?? []) {
                                                if skill.characters == nil {
                                                    skill.characters = []
                                                }
                                                skill.characters?.removeAll { $0.id == character.id }
                                            }
                                            // Then delete the character
                                            context.delete(character)
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    .searchSuggestions {
                        if searchText.isEmpty {
                            Text("Try searching by name")
                                .searchCompletion("Fred")
                            Text("Search by set")
                                .searchCompletion("set: Core")
                            Text("Filter by skill")
                                .searchCompletion("skill: +1 Die")
                        }
                    }
                    .modifier(CharacterSeeder())
                    .listStyle(PlainListStyle())
                }
                // No toolbar needed anymore as options moved to HeaderView
                .onAppear {
                    refreshDataModel()
                }
            }
        }
        // Sheet for adding a new character
        .sheet(isPresented: $isShowingAddCharacter) {
            NavigationStack {
                AddCharacterView(character: nil)
            }
        }
        // Sheet for editing an existing character - using item presentation for reliability
        .sheet(item: $selectedCharacter) { character in
            NavigationStack {
                AddCharacterView(character: character)
            }
        }
    }
    
    // Custom Search Bar View
    struct SearchBar: View {
        @Binding var text: String
        @FocusState private var isSearchFocused: Bool
        
        var body: some View {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search by name, set, or skill", text: $text)
                    .autocorrectionDisabled()
                    .focused($isSearchFocused)
                    .submitLabel(.search)
                    .onSubmit {
                        isSearchFocused = false
                    }
                
                if isSearchFocused {
                    Button("Done") {
                        isSearchFocused = false
                    }
                    .foregroundColor(.blue)
                }
                
                if !text.isEmpty {
                    Button(action: {
                        text = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .onTapGesture {
                // This helps with tapping on the search bar background to focus
                if !isSearchFocused {
                    isSearchFocused = true
                }
            }
            .overlay(
                // Invisible button that covers the entire screen when search is active
                // to enable tapping outside to dismiss
                Group {
                    if isSearchFocused {
                        GeometryReader { _ in
                            Button("") {
                                isSearchFocused = false
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.clear)
                        }
                        .ignoresSafeArea()
                    }
                }
            )
        }
    }
    
    private func refreshDataModel() {
        // For debugging purposes
        let allSkills = (try? context.fetch(FetchDescriptor<Skill>())) ?? []
        let skillsWithCharacters = allSkills.filter { $0.characters != nil && !$0.characters!.isEmpty }
        let orphanedSkills = allSkills.filter { $0.characters == nil || $0.characters!.isEmpty }
        
        debugMessage = """
        Total skills: \(allSkills.count)
        Skills with characters: \(skillsWithCharacters.count)
        Orphaned skills: \(orphanedSkills.count)
        """
        
        // Force SwiftData to refresh by forcing a new fetch if needed
        if characters.isEmpty {
            try? context.fetch(FetchDescriptor<Character>())
        }
    }
    
    // The wipe functions have been moved to HeaderView.swift
}

// Simple skill list display with full wrapping
struct SkillsWithDescriptionView: View {
    let skills: [Skill]
    
    var body: some View {
        // Show just the skill names with proper wrapping
        Text(skills.map { $0.name }.joined(separator: ", "))
            .font(.caption)
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true) // Ensure proper wrapping
    }
}

#Preview {
    ContentView()
}
