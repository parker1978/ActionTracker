import Foundation
import SwiftUI
import CoreDomain

/// Manages the enabled/disabled state of individual weapon cards within sets
@MainActor
public class DisabledCardsManager: ObservableObject {
    private static let storageKey = "disabledCardsBySet"

    /// Dictionary mapping set names to arrays of disabled weapon names
    /// Structure: [setName: [weaponName1, weaponName2, ...]]
    @Published private(set) var disabledCardsBySet: [String: [String]] = [:]

    public init() {
        loadFromUserDefaults()
    }

    // MARK: - Public Methods

    /// Check if a specific weapon card is disabled
    public func isCardDisabled(_ weaponName: String, in setName: String) -> Bool {
        guard let disabledCards = disabledCardsBySet[setName] else {
            return false
        }
        return disabledCards.contains(weaponName)
    }

    /// Toggle the enabled/disabled state of a weapon card
    public func toggleCard(_ weaponName: String, in setName: String) {
        if isCardDisabled(weaponName, in: setName) {
            enableCard(weaponName, in: setName)
        } else {
            disableCard(weaponName, in: setName)
        }
    }

    /// Enable a specific weapon card
    public func enableCard(_ weaponName: String, in setName: String) {
        guard var disabledCards = disabledCardsBySet[setName] else {
            return
        }

        disabledCards.removeAll { $0 == weaponName }

        if disabledCards.isEmpty {
            disabledCardsBySet.removeValue(forKey: setName)
        } else {
            disabledCardsBySet[setName] = disabledCards
        }

        saveToUserDefaults()
    }

    /// Disable a specific weapon card
    public func disableCard(_ weaponName: String, in setName: String) {
        var disabledCards = disabledCardsBySet[setName] ?? []

        if !disabledCards.contains(weaponName) {
            disabledCards.append(weaponName)
            disabledCardsBySet[setName] = disabledCards
            saveToUserDefaults()
        }
    }

    /// Enable or disable all cards of a specific deck type within a set
    public func setCards(
        enabled: Bool,
        for deckType: DeckType,
        in setName: String,
        weapons: [Weapon]
    ) {
        let weaponsInDeckType = weapons.filter {
            $0.expansion == setName && $0.deck == deckType
        }

        for weapon in weaponsInDeckType {
            if enabled {
                enableCard(weapon.name, in: setName)
            } else {
                disableCard(weapon.name, in: setName)
            }
        }
    }

    /// Get all disabled weapon names for a specific set
    public func getDisabledCards(for setName: String) -> [String] {
        disabledCardsBySet[setName] ?? []
    }

    /// Check if there are any custom disabled cards
    public var hasCustomDisabledCards: Bool {
        !disabledCardsBySet.isEmpty
    }

    /// Clear all disabled cards
    public func clearAll() {
        disabledCardsBySet.removeAll()
        saveToUserDefaults()
    }

    // MARK: - Private Methods

    private func loadFromUserDefaults() {
        if let data = UserDefaults.standard.dictionary(forKey: Self.storageKey) as? [String: [String]] {
            disabledCardsBySet = data
        }
    }

    private func saveToUserDefaults() {
        if disabledCardsBySet.isEmpty {
            UserDefaults.standard.removeObject(forKey: Self.storageKey)
        } else {
            UserDefaults.standard.set(disabledCardsBySet, forKey: Self.storageKey)
        }
    }
}
