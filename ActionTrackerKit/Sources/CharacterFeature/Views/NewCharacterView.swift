//
//  NewCharacterView.swift
//  CharacterFeature
//
//  Created by Stephen Parker on 6/6/25.
//

import SwiftUI
import SwiftData
import CoreDomain
import SharedUI

public struct NewCharacterView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allSkills: [CoreDomain.Skill]

    @State private var name = ""
    @State private var notes = ""
    @State private var isFavorite = false
    @State private var isTeen = false
    @State private var maxHealth = 3

    // Skills stored as arrays for easier manipulation
    @State private var blueSkills: [String] = []
    @State private var orangeSkills: [String] = []
    @State private var redSkills: [String] = []

    @State private var showDetails = false
    @State private var appear = false

    // Skill picker states
    @State private var showingBlueSkillPicker = false
    @State private var showingOrangeSkillPicker = false
    @State private var showingRedSkillPicker = false

    public init() {}

    public var body: some View {
        VStack {
            Form {
                Section {
                    TextField("Character Name", text: $name)
                        .textInputAutocapitalization(.words)

                    Toggle("Favorite", isOn: $isFavorite.animation())
                }

                Section {
                    Toggle("Teen Character", isOn: $isTeen.animation())

                    Stepper(value: $maxHealth, in: 1...5) {
                        HStack {
                            Text("Max Health")
                            Spacer()
                            Text("\(maxHealth)")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Character Type")
                }

                // Blue Skills Section
                Section {
                    ForEach(blueSkills, id: \.self) { skill in
                        HStack {
                            Text(skill)
                            Spacer()
                            Button {
                                blueSkills.removeAll { $0 == skill }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                        }
                    }

                    Button {
                        showingBlueSkillPicker = true
                    } label: {
                        Label("Add Blue Skill", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Label("Blue Skills", systemImage: "circle.fill")
                        .foregroundStyle(.blue)
                }

                // Orange Skills Section
                Section {
                    ForEach(orangeSkills, id: \.self) { skill in
                        HStack {
                            Text(skill)
                            Spacer()
                            Button {
                                orangeSkills.removeAll { $0 == skill }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                        }
                    }

                    Button {
                        showingOrangeSkillPicker = true
                    } label: {
                        Label("Add Orange Skill", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Label("Orange Skills", systemImage: "circle.fill")
                        .foregroundStyle(.orange)
                }

                // Red Skills Section
                Section {
                    ForEach(redSkills, id: \.self) { skill in
                        HStack {
                            Text(skill)
                            Spacer()
                            Button {
                                redSkills.removeAll { $0 == skill }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                        }
                    }

                    Button {
                        showingRedSkillPicker = true
                    } label: {
                        Label("Add Red Skill", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Label("Red Skills", systemImage: "circle.fill")
                        .foregroundStyle(.red)
                }

                DisclosureGroup(isExpanded: $showDetails.animation(.easeInOut)) {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                } label: {
                    Label("Notes (Optional)", systemImage: "note.text")
                        .font(.subheadline)
                }
            }
            .formStyle(.grouped)
            .opacity(appear ? 1 : 0)
            .animation(.easeInOut(duration: 0.4), value: appear)

            Button(action: save) {
                Text("Save Character")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(name.isEmpty ? Color.gray : Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(name.isEmpty)
            .padding()
            .scaleEffect(appear ? 1 : 0.5)
            .animation(.spring(), value: appear)
        }
        .navigationTitle("New Character")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear { appear = true }
        .onChange(of: isTeen) { oldValue, newValue in
            let slipperyText = "Teen Character - Slippery: The Survivor does not spend extra Actions when they perform a Move Action out of a Zone containing Zombies. The Survivor also ignores Zombies when performing Move Actions (including those allowing them to cross several Zones, with the Sprint Skill for example)."

            if newValue {
                // Teen toggled ON
                if maxHealth == 3 {
                    maxHealth = 2
                }

                // Add Slippery text to notes if not already present
                if !notes.contains(slipperyText) {
                    if notes.isEmpty {
                        notes = slipperyText
                    } else {
                        notes = slipperyText + "\n\n" + notes
                    }
                }
            } else {
                // Teen toggled OFF
                if maxHealth == 2 {
                    maxHealth = 3
                }

                // Remove Slippery text from notes
                if notes.hasPrefix(slipperyText + "\n\n") {
                    notes = String(notes.dropFirst(slipperyText.count + 2))
                } else if notes == slipperyText {
                    notes = ""
                }
            }
        }
        .sheet(isPresented: $showingBlueSkillPicker) {
            SkillPickerView(
                selectedSkills: $blueSkills,
                excludedSkills: blueSkills,
                allSkills: allSkills
            )
        }
        .sheet(isPresented: $showingOrangeSkillPicker) {
            SkillPickerView(
                selectedSkills: $orangeSkills,
                excludedSkills: orangeSkills,
                allSkills: allSkills
            )
        }
        .sheet(isPresented: $showingRedSkillPicker) {
            SkillPickerView(
                selectedSkills: $redSkills,
                excludedSkills: redSkills,
                allSkills: allSkills
            )
        }
    }

    private func save() {
        let character = Character(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            set: "User Created", // All user-created characters have this set
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            isFavorite: isFavorite,
            isBuiltIn: false,
            teen: isTeen,
            health: maxHealth,
            blueSkills: blueSkills.joined(separator: ";"),
            orangeSkills: orangeSkills.joined(separator: ";"),
            redSkills: redSkills.joined(separator: ";")
        )
        modelContext.insert(character)
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    NavigationStack {
        NewCharacterView()
    }
}
