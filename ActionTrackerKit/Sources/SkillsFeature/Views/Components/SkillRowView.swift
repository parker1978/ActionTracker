//
//  SkillRowView.swift
//  SkillsFeature
//
//  Created by Stephen Parker on 6/6/25.
//

import SwiftUI
import CoreDomain

public struct SkillRowView: View {
    let skill: Skill
    let characterCount: Int

    public init(skill: Skill, characterCount: Int) {
        self.skill = skill
        self.characterCount = characterCount
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(skill.name)
                    .font(.headline)

                Spacer()

                // Character count badge
                HStack(spacing: 4) {
                    Image(systemName: "person.fill")
                        .font(.caption2)
                    Text("\(characterCount)")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.15))
                .clipShape(Capsule())
            }

            Text(skill.skillDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
}
