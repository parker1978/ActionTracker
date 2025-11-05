//
//  DataRepository.swift
//  DataLayer
//
//  Protocol defining the interface for data repositories.
//  Provides abstraction for data loading and versioning.
//

import Foundation

/// Base protocol defining the interface for data repositories
public protocol DataRepository {
    associatedtype DataType

    /// All items in the repository
    var allItems: [DataType] { get }

    /// Data version for tracking updates
    static var dataVersion: String { get }
}

/// Character-specific repository interface
public protocol CharacterDataRepository: DataRepository {
    /// Get characters for a specific expansion set
    /// - Parameter set: The expansion set name
    /// - Returns: Array of characters from that set
    func getCharacters(forSet set: String) -> [DataType]

    /// All available expansion sets
    var expansionSets: [String] { get }
}

/// Weapon-specific repository interface
public protocol WeaponDataRepository: DataRepository {
    /// Get weapons for a specific deck type
    /// - Parameter deckType: The deck type (Starting, Regular, Ultrared)
    /// - Returns: Array of weapons from that deck
    func getWeapons(for deckType: String) -> [DataType]

    /// Get weapons for a specific expansion
    /// - Parameter expansion: The expansion name
    /// - Returns: Array of weapons from that expansion
    func getWeapons(forExpansion expansion: String) -> [DataType]

    /// All available expansion names
    var expansions: [String] { get }
}
