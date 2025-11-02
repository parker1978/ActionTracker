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

    var body: some View {
        NavigationStack {
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
            .navigationTitle("Skills")
            .searchable(text: $searchText, prompt: "Search skills...")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
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
