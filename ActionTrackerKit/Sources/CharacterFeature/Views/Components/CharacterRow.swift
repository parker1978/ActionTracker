//
//  CharacterRow.swift
//  CharacterFeature
//
//  Created by Stephen Parker on 6/6/25.
//

import SwiftUI
import CoreDomain

// MARK: - Character Row Component

public struct CharacterRow: View {
    let character: Character

    public init(character: Character) {
        self.character = character
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

                // Show first few skills as preview
                if !character.allSkillsList.isEmpty {
                    Text(character.allSkillsList.prefix(3).joined(separator: " • "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()
        }
    }
}
