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

    func body(content: Content) -> some View {
        content
            .onAppear {
                if existing.isEmpty {
                    seedCharacters()
                }
            }
    }

    private func seedCharacters() {
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
    }
}
