import SwiftUI
import SwiftData

struct SkillPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Skill.name) private var allSkills: [Skill]

    let currentSkills: [String]
    let colorTier: String
    let onSelect: (String) -> Void

    @State private var searchText = ""

    var filteredSkills: [Skill] {
        let filtered = searchText.isEmpty ? allSkills : allSkills.filter { skill in
            skill.name.localizedCaseInsensitiveContains(searchText)
        }

        // Filter out skills already in this tier
        return filtered.filter { skill in
            !currentSkills.contains(skill.name)
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
                            Text("All available skills have been added to this tier.")
                        } else {
                            Text("Try a different search term.")
                        }
                    }
                } else {
                    ForEach(filteredSkills, id: \.id) { skill in
                        Button {
                            onSelect(skill.name)
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
            .navigationTitle("Add \(colorTier) Skill")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search skills")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
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
