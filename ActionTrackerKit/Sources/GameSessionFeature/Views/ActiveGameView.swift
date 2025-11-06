//
//  ActiveGameView.swift
//  GameSessionFeature
//
//  Main game tracking view displayed during an active session
//

import SwiftUI
import SwiftData
import CoreDomain
import DataLayer

/// Main game tracking view displayed during an active session
/// Contains character info, actions, experience tracking, timer, and end game button
public struct ActiveGameView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var session: GameSession
    var weaponsManager: WeaponsManager

    // Timer state
    @StateObject private var gameTimer: GameTimer

    // UI state
    @State private var showingEndConfirmation = false

    public init(session: GameSession, weaponsManager: WeaponsManager) {
        self.session = session
        self.weaponsManager = weaponsManager
        _gameTimer = StateObject(wrappedValue: GameTimer(session: session))
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Character information card
                CharacterInfoCard(session: session)

                // Health tracking card
                HealthCard(session: session)

                // Action tracking card (with edit mode for deletion)
                ActionsCard(session: session)

                // Inventory card (weapons)
                InventoryCard(session: session, weaponsManager: weaponsManager)

                // Experience and skill tracking card
                ExperienceCard(session: session)

                // Game duration timer card
                TimerCard(session: session, isRunning: $gameTimer.isRunning, onToggle: gameTimer.toggle)

                // End game button with confirmation
                Button(role: .destructive) {
                    showingEndConfirmation = true
                } label: {
                    Label("End Game", systemImage: "stop.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.red)
                }
                .padding(.top)
            }
            .padding()
        }
        .navigationTitle("Actions")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            gameTimer.start()
        }
        .onDisappear {
            gameTimer.stop()
        }
        .alert("End Game?", isPresented: $showingEndConfirmation) {
            Button("End Game", role: .destructive) {
                endGame()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to end this game session?")
        }
    }

    /// Ends the current game session by setting endedAt timestamp
    private func endGame() {
        gameTimer.stop()
        session.endedAt = Date()
        try? modelContext.save()
    }
}
