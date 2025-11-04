//
//  SkillsScreen.swift
//  ActionTracker
//

import SwiftUI
import SwiftData

struct SkillsScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allSkills: [Skill]
    @Query private var allCharacters: [Character]

    @State private var searchText = ""
    @State private var sortOption: SortOption = .alphabeticalAZ
    @State private var filterOption: FilterOption = .all
    @State private var showingFilters = false
    @State private var searchMode: SearchMode = .skillsList
    @State private var showingNewSkill = false

    // Advanced search state
    @State private var selectedSkills: [String] = []
    @State private var skillSearchText = ""
    @State private var isSearchingSkills = false

    enum SearchMode: String, CaseIterable {
        case skillsList = "Skills List"
        case advancedSkillSearch = "Advanced Skill Search"
    }

    enum SortOption: String, CaseIterable {
        case alphabeticalAZ = "A-Z"
        case alphabeticalZA = "Z-A"
        case mostUsed = "Most Used"
        case leastUsed = "Least Used"

        var icon: String {
            switch self {
            case .alphabeticalAZ: return "arrow.up"
            case .alphabeticalZA: return "arrow.down"
            case .mostUsed: return "arrow.up.circle.fill"
            case .leastUsed: return "arrow.down.circle.fill"
            }
        }
    }

    enum FilterOption: String, CaseIterable {
        case all = "All Skills"
        case builtIn = "Built-in"
        case userCreated = "User Created"
        case withCharacters = "Has Characters"
        case withoutCharacters = "No Characters"
    }

    var filteredAndSortedSkills: [Skill] {
        var skills = allSkills

        // Apply search filter
        if !searchText.isEmpty {
            skills = skills.filter { skill in
                skill.name.localizedCaseInsensitiveContains(searchText) ||
                skill.skillDescription.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Apply filter option
        switch filterOption {
        case .all:
            break
        case .builtIn:
            skills = skills.filter { $0.isBuiltIn }
        case .userCreated:
            skills = skills.filter { !$0.isBuiltIn }
        case .withCharacters:
            skills = skills.filter { skill in
                characterCount(for: skill) > 0
            }
        case .withoutCharacters:
            skills = skills.filter { skill in
                characterCount(for: skill) == 0
            }
        }

        // Apply sorting
        switch sortOption {
        case .alphabeticalAZ:
            skills.sort { $0.name < $1.name }
        case .alphabeticalZA:
            skills.sort { $0.name > $1.name }
        case .mostUsed:
            skills.sort { characterCount(for: $0) > characterCount(for: $1) }
        case .leastUsed:
            skills.sort { characterCount(for: $0) < characterCount(for: $1) }
        }

        return skills
    }

    func characterCount(for skill: Skill) -> Int {
        allCharacters.filter { character in
            character.allSkillsList.contains(skill.name)
        }.count
    }

    // MARK: - Advanced Search Computed Properties

    private var characters: [Character] {
        allCharacters.sorted {
            if $0.isFavorite == $1.isFavorite {
                return $0.name < $1.name
            }
            return $0.isFavorite && !$1.isFavorite
        }
    }

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
                if searchMode == .skillsList {
                    skillsListView
                } else {
                    advancedSkillSearchView
                }
            }
            .navigationTitle("Skills")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if searchMode == .skillsList {
                        HStack(spacing: 16) {
                            Menu {
                                Section("Sort By") {
                                    ForEach(SortOption.allCases, id: \.self) { option in
                                        Button {
                                            sortOption = option
                                        } label: {
                                            Label(option.rawValue, systemImage: option.icon)
                                            if sortOption == option {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }

                                Section("Filter") {
                                    ForEach(FilterOption.allCases, id: \.self) { option in
                                        Button {
                                            filterOption = option
                                        } label: {
                                            Text(option.rawValue)
                                            if filterOption == option {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                Label("Sort & Filter", systemImage: "line.3.horizontal.decrease.circle")
                            }

                            Button {
                                showingNewSkill = true
                            } label: {
                                Image(systemName: "plus")
                            }
                        }
                    } else {
                        Button {
                            showingNewSkill = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingNewSkill) {
                NewSkillView()
            }
        }
    }

    // MARK: - Skills List View

    private var skillsListView: some View {
        Group {
            if filteredAndSortedSkills.isEmpty {
                ContentUnavailableView {
                    Label("No Skills Found", systemImage: "sparkles.rectangle.stack")
                } description: {
                    if !searchText.isEmpty {
                        Text("No skills match '\(searchText)'")
                    } else if filterOption != .all {
                        Text("No skills match the current filter")
                    } else {
                        Text("No skills available")
                    }
                } actions: {
                    if !searchText.isEmpty || filterOption != .all {
                        Button("Clear Filters") {
                            searchText = ""
                            filterOption = .all
                        }
                    }
                }
            } else {
                List {
                    ForEach(filteredAndSortedSkills) { skill in
                        NavigationLink {
                            SkillCharactersView(skill: skill)
                        } label: {
                            SkillRowView(skill: skill, characterCount: characterCount(for: skill))
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .searchable(text: $searchText, prompt: "Search skills...")
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

struct SkillRowView: View {
    let skill: Skill
    let characterCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(skill.name)
                    .font(.headline)

                Spacer()

                // Character count badge
                HStack(spacing: 4) {
                    Image(systemName: "person.fill")
                        .font(.caption2)
                    Text("\(characterCount)")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.15))
                .clipShape(Capsule())
            }

            Text(skill.skillDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SkillsScreen()
        .modelContainer(for: [Skill.self, Character.self], inMemory: true)
}
