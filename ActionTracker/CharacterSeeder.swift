//
//  CharacterSeeder.swift
//  ZombicideCharacters
//
//  Created by Stephen Parker on 4/11/25.
//

import SwiftUI
import SwiftData

struct CharacterSeeder: ViewModifier {
    @Environment(\.modelContext) private var context
    @Query var existing: [Character]
    @State private var hasAttemptedSeed = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                // Add a longer delay to ensure modelContext is properly set up
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    if !hasAttemptedSeed && existing.isEmpty {
                        hasAttemptedSeed = true
                        seedCharacters()
                    }
                }
            }
            .task {
                // This is a secondary attempt to seed the data if the first one fails
                try? await Task.sleep(for: .seconds(2))
                if !hasAttemptedSeed && existing.isEmpty {
                    hasAttemptedSeed = true
                    seedCharacters()
                }
            }
    }

    private func seedCharacters() {
        print("Seeding initial character data...")
        let characters: [Character] = [
            Character(
                name: "Fred",
                allSkills: ["Reaper: Combat","+1 Free Combat Action","Dreadnought: Walker","+1 Die: Combat","+1 Free Combat Action","+1 To Dice Roll: Combat"]
            ),
            Character(
                name: "Bunny G",
                allSkills: ["Lucky","+1 To Dice Roll: Melee","Jump","+1 Damage: Melee","+1 Free Combat Action","Roll 6: +1 Die Combat"]
            ),
            Character(
                name: "Tiger Sam",
                allSkills: ["+1 Die: Ranged", "+1 Free Move Action", "Sniper", "+1 Damage: Ranged", "+1 Free Combat Action", "Shove"]
            )
        ]

        for character in characters {
            context.insert(character)
        }
        
        // Attempt to save changes immediately
        do {
            try context.save()
            print("Successfully saved \(characters.count) seed characters")
        } catch {
            print("Failed to save seed characters: \(error)")
        }
    }
}
