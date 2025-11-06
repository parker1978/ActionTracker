//
//  StartGameView.swift
//  GameSessionFeature
//
//  View displayed when no active game session exists
//

import SwiftUI

/// View displayed when no active game session exists
/// Prompts the user to select a character to begin tracking
internal struct StartGameView: View {
    @Binding var showingCharacterPicker: Bool

    var body: some View {
        ContentUnavailableView {
            Label("No Active Game", systemImage: "gamecontroller")
        } description: {
            Text("Select a character to start tracking")
        } actions: {
            Button {
                showingCharacterPicker = true
            } label: {
                Text("Select Character")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
        }
        .navigationTitle("Actions")
    }
}
