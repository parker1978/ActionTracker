//
//  CharacterListView.swift
//  ZombicideCharacters
//
//  Created by Stephen Parker on 4/11/25.
//

import SwiftUI
import SwiftData

struct CharacterListView: View {
    // Use State instead of Query as a workaround for SwiftData issues
    @State private var characters: [Character] = []
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
                            Button("Create Test Character") {
                                createTestCharacter()
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
                                    HStack {
                                        VStack(alignment: .leading) {
                                            HStack {
                                                if character.isFavorite {
                                                    Image(systemName: "star.fill")
                                                        .foregroundColor(.yellow)
                                                }
                                                Text(character.set?.isEmpty == false ? "\(character.name) (\(character.set!))" : character.name)
                                                    .font(.headline)
                                            }
                                            // Display skills sorted by position with enhanced description display
                                            SkillsWithDescriptionView(skills: (character.skills ?? []).sorted { $0.position < $1.position })
                                        }
                                        
                                        Spacer()
                                        
                                        // Favorite toggle button
                                        Button {
                                            toggleFavorite(character)
                                        } label: {
                                            Image(systemName: character.isFavorite ? "star.fill" : "star")
                                                .foregroundColor(character.isFavorite ? .yellow : .gray)
                                        }
                                        .buttonStyle(BorderlessButtonStyle())
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
                .onChange(of: isShowingAddCharacter) { oldValue, newValue in
                    if oldValue && !newValue {
                        // Character sheet was dismissed, refresh data
                        refreshDataModel()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshCharacterData"))) { _ in
                    print("==== RECEIVED NOTIFICATION TO REFRESH CHARACTER DATA ====")
                    
                    // Let's double-check the data is available in the database before refreshing
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        do {
                            let count = try context.fetch(FetchDescriptor<Character>()).count
                            print("Current character count before refresh: \(count)")
                        } catch {
                            print("Error checking characters: \(error)")
                        }
                        refreshDataModel()
                    }
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
        
        private func insertTextAtCursor(_ text: String) {
            if isSearchFocused {
                self.text.append(text)
            }
        }
        
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
            .keyboardToolbar(
                onInsertText: { insertTextAtCursor($0) },
                onDone: { isSearchFocused = false }
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
        
        // First make sure any changes are saved
        do {
            try context.save()
        } catch {
            print("Error saving context before fetch: \(error)")
        }
        
        // Always fetch characters to ensure we have the latest data
        do {
            var descriptor = FetchDescriptor<Character>()
            descriptor.sortBy = [SortDescriptor(\.name)]
            
            // Reset modelContext to make sure we have fresh data
            context.processPendingChanges()
            
            // Fetch characters from database
            var fetchedCharacters = try context.fetch(descriptor)
            
            // Sort favorites to the top manually
            fetchedCharacters.sort { (char1, char2) -> Bool in
                if char1.isFavorite && !char2.isFavorite {
                    return true
                } else if !char1.isFavorite && char2.isFavorite {
                    return false
                } else {
                    return char1.name.localizedCaseInsensitiveCompare(char2.name) == .orderedAscending
                }
            }
            
            characters = fetchedCharacters
            
            print("Fetched \(characters.count) characters from context \(context)")
            
            // If characters is empty, try again after a brief delay
            if characters.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.retryFetchCharacters()
                }
            }
        } catch {
            print("Error fetching characters: \(error)")
            characters = []
        }
    }
    
    private func retryFetchCharacters() {
        do {
            var descriptor = FetchDescriptor<Character>()
            descriptor.sortBy = [SortDescriptor(\.name)]
            
            // Fetch characters from database
            var fetchedCharacters = try context.fetch(descriptor)
            
            // Sort favorites to the top manually
            fetchedCharacters.sort { (char1, char2) -> Bool in
                if char1.isFavorite && !char2.isFavorite {
                    return true
                } else if !char1.isFavorite && char2.isFavorite {
                    return false
                } else {
                    return char1.name.localizedCaseInsensitiveCompare(char2.name) == .orderedAscending
                }
            }
            
            characters = fetchedCharacters
            
            print("Retry fetch: \(characters.count) characters")
        } catch {
            print("Error in retry fetch: \(error)")
            characters = []
        }
    }
    
    private func createTestCharacter() {
        // Create a test character directly
        let testCharacter = Character(
            name: "MANUAL TEST CHARACTER \(Date().timeIntervalSince1970)", 
            set: "Test Set", 
            notes: "Test Notes",
            isFavorite: false,
            blueSkills: ["Test Blue Skill"],
            orangeSkills: ["Test Orange Skill"],
            redSkills: ["Test Red Skill"]
        )
        
        // Insert and save
        context.insert(testCharacter)
        do {
            try context.save()
            print("Test character saved successfully")
            refreshDataModel()
        } catch {
            print("Error saving test character: \(error)")
        }
    }
    
    private func toggleFavorite(_ character: Character) {
        character.isFavorite.toggle()
        
        // Save changes
        do {
            try context.save()
            // Refresh the list to update sorting
            refreshDataModel()
        } catch {
            print("Error toggling favorite status: \(error)")
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
