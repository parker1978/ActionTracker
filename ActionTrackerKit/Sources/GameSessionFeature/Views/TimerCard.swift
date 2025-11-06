//
//  TimerCard.swift
//  GameSessionFeature
//
//  Card displaying game duration with pause/resume controls
//

import SwiftUI
import CoreDomain

/// Card displaying game duration with pause/resume controls
struct TimerCard: View {
    let session: GameSession
    @Binding var isRunning: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Label("Game Duration", systemImage: "clock")
                    .font(.headline)

                Spacer()

                // Pause/Resume button
                Button {
                    onToggle()
                } label: {
                    Image(systemName: isRunning ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(isRunning ? .orange : .green)
                }
            }

            // Large formatted time display
            Text(session.formattedDuration)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
