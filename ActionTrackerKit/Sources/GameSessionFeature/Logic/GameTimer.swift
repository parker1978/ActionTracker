//
//  GameTimer.swift
//  GameSessionFeature
//
//  Game session timer management with pause/resume functionality
//

import Foundation
import SwiftUI
import SwiftData
import CoreDomain

/// Manages game session timer state and operations
/// Handles starting, stopping, and toggling the game duration timer
@Observable
class GameTimer {
    private var timer: Timer?
    var isRunning: Bool = true
    weak var session: GameSession?

    init(session: GameSession) {
        self.session = session
    }

    /// Starts the game timer, incrementing elapsed seconds every second
    func start() {
        guard timer == nil else { return }
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.session?.elapsedSeconds += 1
        }
    }

    /// Stops the game timer
    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    /// Toggles the timer between running and paused states
    func toggle() {
        if isRunning {
            stop()
        } else {
            start()
        }
    }
}
