//
//  CharacterPickerSheet.swift
//  GameSessionFeature
//
//  Sheet for selecting a character to start a new game session
//

import SwiftUI
import SwiftData
import CoreDomain
import SpawnDeckFeature

/// Sheet for selecting a character to start a new game session
internal struct CharacterPickerSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allCharacters: [CoreDomain.Character]
    @Binding var isPresented: Bool

    var weaponsManager: WeaponsManager
    var spawnDeckManager: SpawnDeckManager

    /// Characters sorted with favorites first, then alphabetically
    var sortedCharacters: [CoreDomain.Character] {
        allCharacters.sorted {
            if $0.isFavorite == $1.isFavorite {
                return $0.name < $1.name
            }
            return $0.isFavorite && !$1.isFavorite
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(sortedCharacters) { character in
                    Button {
                        startGame(with: character)
                    } label: {
                        CharacterRow(character: character)
                    }
                }
            }
            .navigationTitle("Select Character")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }

    /// Creates and starts a new game session with the selected character
    private func startGame(with character: CoreDomain.Character) {
        // Reset all weapon decks at current difficulty
        weaponsManager.resetAllDecks()

        // Reset spawn deck at current mode and difficulty
        spawnDeckManager.loadDeck()

        // Create and save the new game session
        let session = CoreDomain.GameSession(character: character)
        modelContext.insert(session)
        try? modelContext.save()
        isPresented = false
    }
}

// MARK: - Character Row

/// Simple character row display for picker
/// NOTE: This is a temporary simplified version. The full CharacterRow will be in CharacterFeature (Phase 6)
struct CharacterRow: View {
    let character: CoreDomain.Character

    var body: some View {
        HStack {
            if character.isFavorite {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                    .font(.caption)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(character.name)
                    .font(.headline)
                    .foregroundStyle(.primary)

                if !character.set.isEmpty {
                    Text(character.set)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
