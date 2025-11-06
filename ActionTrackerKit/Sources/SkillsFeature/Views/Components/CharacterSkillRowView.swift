//
//  CharacterSkillRowView.swift
//  SkillsFeature
//
//  Created by Stephen Parker on 6/6/25.
//

import SwiftUI
import CoreDomain

public struct CharacterSkillRowView: View {
    let character: Character
    let skillTiers: [SkillTier]

    public init(character: Character, skillTiers: [SkillTier]) {
        self.character = character
        self.skillTiers = skillTiers
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if character.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)
                }

                Text(character.name)
                    .font(.headline)
            }

            Text(character.set)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Tier badges
            if !skillTiers.isEmpty {
                HStack(spacing: 6) {
                    ForEach(skillTiers) { tier in
                        Text(tier.displayName)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(tier.color)
                            .clipShape(Capsule())
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }
}
