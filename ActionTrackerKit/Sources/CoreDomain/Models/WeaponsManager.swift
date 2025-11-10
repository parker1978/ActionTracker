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

    public init(weapons: [Weapon]) {
        self.startingDeck = WeaponDeckState(deckType: .starting, weapons: weapons)
        self.regularDeck = WeaponDeckState(deckType: .regular, weapons: weapons)
        self.ultraredDeck = WeaponDeckState(deckType: .ultrared, weapons: weapons)
    }

    /// Get deck state by type
    public func getDeck(_ type: DeckType) -> WeaponDeckState {
        switch type {
        case .starting: return startingDeck
        case .regular: return regularDeck
        case .ultrared: return ultraredDeck
        }
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
