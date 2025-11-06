//
//  CharacterInfoCard.swift
//  GameSessionFeature
//
//  Card displaying basic character information during an active game
//

import SwiftUI
import CoreDomain

/// Card displaying basic character information during an active game
public struct CharacterInfoCard: View {
    let session: GameSession

    public var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(session.characterName)
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                // Link to full character details
                if let character = session.character {
                    NavigationLink {
                        CharacterDetailView(character: character)
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.title3)
                    }
                }
            }

            // Display character set if available
            if let character = session.character, !character.set.isEmpty {
                HStack {
                    Text(character.set)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
