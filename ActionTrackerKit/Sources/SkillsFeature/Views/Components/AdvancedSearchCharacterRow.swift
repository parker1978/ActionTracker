//
//  AdvancedSearchCharacterRow.swift
//  SkillsFeature
//
//  Created by Stephen Parker on 6/6/25.
//

import SwiftUI
import CoreDomain

public struct AdvancedSearchCharacterRow: View {
    let character: Character
    let selectedSkills: Set<String>

    public init(character: Character, selectedSkills: Set<String>) {
        self.character = character
        self.selectedSkills = selectedSkills
    }

    public var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(character.name)
                        .font(.headline)

                    if character.isFavorite {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption)
                    }

                    if !character.set.isEmpty {
                        Text(character.set)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: Capsule())
                            .foregroundStyle(.secondary)
                    }
                }

                // Show matching skills in bold blue
                if !selectedSkills.isEmpty {
                    let matchingSkills = character.allSkillsList.filter { selectedSkills.contains($0) }
                    if !matchingSkills.isEmpty {
                        Text(matchingSkills.joined(separator: " • "))
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.blue)
                    }
                }

                // Show other skills normally
                let otherSkills = character.allSkillsList.filter { !selectedSkills.contains($0) }
                if !otherSkills.isEmpty {
                    Text(otherSkills.prefix(3).joined(separator: " • "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
    }
}
