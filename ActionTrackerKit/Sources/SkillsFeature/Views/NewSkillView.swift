//
//  NewSkillView.swift
//  SkillsFeature
//

import SwiftUI
import SwiftData
import CoreDomain

public struct NewSkillView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var skillName = ""
    @State private var skillDescription = ""

    public init() {}

    public var body: some View {
        NavigationStack {
            Form {
                Section("Skill Details") {
                    TextField("Skill Name", text: $skillName)

                    TextField("Description", text: $skillDescription, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("New Skill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSkill()
                    }
                    .disabled(skillName.isEmpty || skillDescription.isEmpty)
                }
            }
        }
    }

    private func saveSkill() {
        let newSkill = Skill(
            name: skillName.trimmingCharacters(in: .whitespacesAndNewlines),
            skillDescription: skillDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            isBuiltIn: false
        )

        modelContext.insert(newSkill)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Error saving skill: \(error)")
        }
    }
}

#Preview {
    NewSkillView()
        .modelContainer(for: [Skill.self], inMemory: true)
}
