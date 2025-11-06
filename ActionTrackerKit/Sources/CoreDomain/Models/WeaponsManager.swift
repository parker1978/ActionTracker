//
//  WeaponsManager.swift
//  ActionTracker
//
//  Manages all three weapon decks and global settings
//

import Foundation
import SwiftUI
import CoreDomain

// MARK: - Weapons Manager

/// Manages all three weapon decks and global settings
@Observable
public class WeaponsManager {
    private(set) public var startingDeck: WeaponDeckState
    private(set) public var regularDeck: WeaponDeckState
    private(set) public var ultraredDeck: WeaponDeckState

    public var currentDifficulty: DifficultyMode {
        didSet {
            if currentDifficulty != oldValue {
                changeDifficultyForAllDecks(to: currentDifficulty)
            }
        }
    }

    public init(weapons: [Weapon], difficulty: DifficultyMode = .medium) {
        self.currentDifficulty = difficulty
        self.startingDeck = WeaponDeckState(deckType: .starting, difficulty: difficulty, weapons: weapons)
        self.regularDeck = WeaponDeckState(deckType: .regular, difficulty: difficulty, weapons: weapons)
        self.ultraredDeck = WeaponDeckState(deckType: .ultrared, difficulty: difficulty, weapons: weapons)
    }

    /// Get deck state by type
    public func getDeck(_ type: DeckType) -> WeaponDeckState {
        switch type {
        case .starting: return startingDeck
        case .regular: return regularDeck
        case .ultrared: return ultraredDeck
        }
    }

    /// Change difficulty for all decks (resets all decks)
    private func changeDifficultyForAllDecks(to mode: DifficultyMode) {
        startingDeck.changeDifficulty(to: mode)
        regularDeck.changeDifficulty(to: mode)
        ultraredDeck.changeDifficulty(to: mode)
    }

    /// Reset all decks
    public func resetAllDecks() {
        startingDeck.reset()
        regularDeck.reset()
        ultraredDeck.reset()
    }

    /// Update weapons for all decks (for expansion filtering)
    public func updateWeapons(_ weapons: [Weapon]) {
        startingDeck.updateWeapons(weapons)
        regularDeck.updateWeapons(weapons)
        ultraredDeck.updateWeapons(weapons)
    }
}
