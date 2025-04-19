//
//  SkillView.swift
//  ActionTracker
//
//  Created by Stephen Parker on 4/19/25.
//

import SwiftUI
import SwiftData

struct SkillView: View {
    @Environment(\.modelContext) private var context
    @Query var skills: [Skill]
    @State private var searchText = ""
    
    var filteredSkills: [Skill] {
        guard !searchText.isEmpty else { return skills }
        return skills.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.skillDescription.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var orphanedSkills: [Skill] {
        filteredSkills.filter { $0.characters == nil || $0.characters!.isEmpty }
    }
    
    var activeSkills: [Skill] {
        filteredSkills.filter { $0.characters != nil && !$0.characters!.isEmpty }
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section("Active Skills (\(activeSkills.count))") {
                    if activeSkills.isEmpty {
                        Text("No active skills found")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(activeSkills.sorted(by: { $0.name < $1.name })) { skill in
                            SkillItemView(skill: skill)
                        }
                    }
                }
                
                Section("Unused Skills (\(orphanedSkills.count))") {
                    if orphanedSkills.isEmpty {
                        Text("No unused skills found")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(orphanedSkills.sorted(by: { $0.name < $1.name })) { skill in
                            SkillItemView(skill: skill)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        withAnimation {
                                            // Only delete skills with no characters
                                            if skill.characters == nil || skill.characters!.isEmpty {
                                                context.delete(skill)
                                            }
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
            .searchable(text: $searchText)
            .navigationTitle("Skill Library")
        }
    }
}

struct SkillItemView: View {
    let skill: Skill
    @State private var showingDetail = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(skill.name)
                .font(.headline)
            
            if !skill.skillDescription.isEmpty {
                Text(skill.skillDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if skill.characters != nil && !skill.characters!.isEmpty {
                Text("Used by: \(characterNames)")
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
        .onTapGesture {
            showingDetail.toggle()
        }
        .sheet(isPresented: $showingDetail) {
            SkillDetailView(skill: skill)
        }
    }
    
    private var characterNames: String {
        (skill.characters ?? [])
            .map { $0.name }
            .sorted()
            .joined(separator: ", ")
    }
}

struct SkillDetailView: View {
    let skill: Skill
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    @State private var editedName: String
    @State private var editedDescription: String
    @State private var isEditing = false
    
    init(skill: Skill) {
        self.skill = skill
        _editedName = State(initialValue: skill.name)
        _editedDescription = State(initialValue: skill.skillDescription)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Skill Information") {
                    if isEditing {
                        TextField("Name", text: $editedName)
                        TextField("Description", text: $editedDescription)
                    } else {
                        LabeledContent("Name", value: skill.name)
                        
                        if !skill.skillDescription.isEmpty {
                            LabeledContent("Description", value: skill.skillDescription)
                        }
                    }
                    
                    LabeledContent("Manually Created", value: skill.manual ? "Yes" : "No")
                    LabeledContent("Imported", value: skill.importedFlag ? "Yes" : "No")
                }
                
                if skill.characters != nil && !skill.characters!.isEmpty {
                    Section("Used By Characters") {
                        ForEach((skill.characters ?? []).sorted(by: { $0.name < $1.name })) { character in
                            Text(character.name)
                        }
                    }
                }
            }
            .navigationTitle("Skill Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isEditing {
                        Button("Save") {
                            // Only update if values have changed
                            if editedName != skill.name || editedDescription != skill.skillDescription {
                                skill.name = editedName
                                skill.skillDescription = editedDescription
                                try? context.save()
                            }
                            isEditing = false
                        }
                    } else {
                        Button("Edit") {
                            isEditing = true
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    SkillView()
}