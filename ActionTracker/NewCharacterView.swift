import SwiftUI
import SwiftData

struct NewCharacterView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var set = ""
    @State private var notes = ""
    @State private var isFavorite = false
    @State private var blueSkills = ""
    @State private var orangeSkills = ""
    @State private var redSkills = ""
    @State private var showDetails = false
    @State private var appear = false

    var body: some View {
        VStack {
            Form {
                Section {
                    TextField("Character Name", text: $name)
                        .textInputAutocapitalization(.words)

                    TextField("Set (Optional)", text: $set)
                        .textInputAutocapitalization(.words)

                    Toggle("Favorite", isOn: $isFavorite.animation())
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Blue Skills", systemImage: "circle.fill")
                            .foregroundStyle(.blue)
                            .font(.subheadline)

                        TextField("Skill 1;Skill 2;Skill 3", text: $blueSkills, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...4)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Orange Skills", systemImage: "circle.fill")
                            .foregroundStyle(.orange)
                            .font(.subheadline)

                        TextField("Skill 1;Skill 2;Skill 3", text: $orangeSkills, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...4)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Red Skills", systemImage: "circle.fill")
                            .foregroundStyle(.red)
                            .font(.subheadline)

                        TextField("Skill 1;Skill 2;Skill 3", text: $redSkills, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...4)
                    }
                } header: {
                    Text("Skills")
                } footer: {
                    Text("Separate multiple skills with semicolons (;)")
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
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { appear = true }
    }

    private func save() {
        let character = Character(
            name: name,
            set: set,
            notes: notes,
            isFavorite: isFavorite,
            isBuiltIn: false, // User-created characters are not built-in
            blueSkills: blueSkills,
            orangeSkills: orangeSkills,
            redSkills: redSkills
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
