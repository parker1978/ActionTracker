//
//  WeaponsManager.swift
//  ActionTracker
//
//  Manages all three weapon decks and global settings
//  Phase 2: Integrates with service layer while maintaining backward compatibility
//

import Foundation
import SwiftUI
import CoreDomain

// MARK: - Weapons Manager

/// Manages all three weapon decks and global settings
/// Phase 2: Now delegates to services for persistence and advanced features
@Observable
public class WeaponsManager {
    // Phase 2: Keep existing deck states for backward compatibility
    // UI will continue using these until Phase 4
    private(set) public var startingDeck: WeaponDeckState
    private(set) public var regularDeck: WeaponDeckState
    private(set) public var ultraredDeck: WeaponDeckState

    // Phase 2: Service layer integration (optional, for future use)
    private var deckService: WeaponsDeckService?
    private var customizationService: CustomizationService?

    public init(weapons: [Weapon]) {
        self.startingDeck = WeaponDeckState(deckType: .starting, weapons: weapons)
        self.regularDeck = WeaponDeckState(deckType: .regular, weapons: weapons)
        self.ultraredDeck = WeaponDeckState(deckType: .ultrared, weapons: weapons)
    }

    /// Phase 2: Initialize with services for enhanced functionality
    public init(
        weapons: [Weapon],
        deckService: WeaponsDeckService,
        customizationService: CustomizationService
    ) {
        self.startingDeck = WeaponDeckState(deckType: .starting, weapons: weapons)
        self.regularDeck = WeaponDeckState(deckType: .regular, weapons: weapons)
        self.ultraredDeck = WeaponDeckState(deckType: .ultrared, weapons: weapons)
        self.deckService = deckService
        self.customizationService = customizationService
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

    // MARK: - Phase 2: Service Access

    /// Get deck service (if available)
    public var hasDeckService: Bool {
        deckService != nil
    }

    /// Get customization service (if available)
    public var hasCustomizationService: Bool {
        customizationService != nil
    }
}
