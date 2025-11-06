//
//  ActionsScreen.swift
//  GameSessionFeature
//
//  Main screen for the Actions tab
//

import SwiftUI
import SwiftData
import CoreDomain
import DataLayer

/// Main screen for the Actions tab
/// Displays either a "start game" view or the active game session
public struct ActionsScreen: View {
    public var weaponsManager: WeaponsManager
    @Environment(\.modelContext) private var modelContext

    // Query for active (non-ended) game sessions
    @Query(filter: #Predicate<GameSession> { $0.endedAt == nil }, sort: \GameSession.startedAt, order: .reverse)
    private var activeSessions: [GameSession]

    @Query private var allCharacters: [Character]
    @State private var showingCharacterPicker = false

    public init(weaponsManager: WeaponsManager) {
        self.weaponsManager = weaponsManager
    }

    public var body: some View {
        NavigationStack {
            if let session = activeSessions.first {
                // Show active game
                ActiveGameView(session: session, weaponsManager: weaponsManager)
            } else {
                // Show "start game" view
                StartGameView(showingCharacterPicker: $showingCharacterPicker)
            }
        }
        .sheet(isPresented: $showingCharacterPicker) {
            CharacterPickerSheet(isPresented: $showingCharacterPicker)
        }
    }
}
