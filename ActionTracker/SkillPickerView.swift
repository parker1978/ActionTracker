import SwiftUI
import SwiftData

struct SkillPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // Support both patterns: binding for NewCharacterView, callback for CharacterDetailView
    @Binding var selectedSkills: [String]
    let excludedSkills: [String]
    let allSkills: [Skill]

    // Optional callback pattern for backward compatibility
    var currentSkills: [String]?
    var colorTier: String?
    var onSelect: ((String) -> Void)?

    @State private var searchText = ""
    @State private var showingNewSkill = false

    init(selectedSkills: Binding<[String]>, excludedSkills: [String], allSkills: [Skill]) {
        self._selectedSkills = selectedSkills
        self.excludedSkills = excludedSkills
        self.allSkills = allSkills
        self.currentSkills = nil
        self.colorTier = nil
        self.onSelect = nil
    }

    init(currentSkills: [String], colorTier: String, onSelect: @escaping (String) -> Void) {
        self._selectedSkills = .constant([])
        self.excludedSkills = currentSkills
        self.allSkills = []
        self.currentSkills = currentSkills
        self.colorTier = colorTier
        self.onSelect = onSelect
    }

    var filteredSkills: [Skill] {
        let filtered = searchText.isEmpty ? allSkills : allSkills.filter { skill in
            skill.name.localizedCaseInsensitiveContains(searchText) ||
            skill.skillDescription.localizedCaseInsensitiveContains(searchText)
        }

        // Filter out skills already selected/excluded
        return filtered.filter { skill in
            !excludedSkills.contains(skill.name)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if filteredSkills.isEmpty {
                    ContentUnavailableView {
                        Label("No Skills Found", systemImage: "magnifyingglass")
                    } description: {
                        if searchText.isEmpty {
                            Text("All available skills have been added.")
                        } else {
                            Text("Try a different search term or create a new skill.")
                        }
                    }
                } else {
                    ForEach(filteredSkills, id: \.id) { skill in
                        Button {
                            if let onSelect = onSelect {
                                // Legacy callback pattern
                                onSelect(skill.name)
                            } else {
                                // New binding pattern
                                selectedSkills.append(skill.name)
                            }
                            dismiss()
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
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle(colorTier ?? "Add Skill")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search skills")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingNewSkill = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewSkill) {
                NewSkillView()
            }
        }
    }
}

#Preview {
    SkillPickerView(
        currentSkills: ["Barbarian", "+1 Damage: Combat"],
        colorTier: "Blue",
        onSelect: { skillName in
            print("Selected: \(skillName)")
        }
    )
}
