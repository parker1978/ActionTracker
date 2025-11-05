//
//  CharacterRepository.swift
//  DataLayer
//
//  Loads characters from bundled JSON data.
//  Ensures all players/devices use identical character data.
//

import Foundation

// MARK: - Character Repository

/// Loads and provides access to bundled character data
public class CharacterRepository {
    public static let shared = CharacterRepository()

    /// Version of the characters data (for debugging and sync verification)
    public static let CHARACTERS_DATA_VERSION = "1.0.0"

    public private(set) var allCharacters: [CharacterData] = []

    private init() {
        loadCharacters()
    }

    // MARK: - Loading

    /// Load characters from bundled JSON file
    private func loadCharacters() {
        guard let url = Bundle.module.url(forResource: "characters", withExtension: "json") else {
            print("❌ Could not find characters.json in bundle")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            allCharacters = try decoder.decode([CharacterData].self, from: data)

            print("✅ Loaded \(allCharacters.count) characters (v\(Self.CHARACTERS_DATA_VERSION))")
        } catch {
            print("❌ Failed to load characters: \(error)")
        }
    }

    // MARK: - Filtering

    /// Get characters by expansion set
    public func getCharacters(forSet set: String) -> [CharacterData] {
        allCharacters.filter { $0.set == set }
    }

    /// Get all unique expansion sets
    public var expansionSets: [String] {
        let sets = Set(allCharacters.compactMap { $0.set }.filter { !$0.isEmpty })
        return Array(sets).sorted()
    }
}

// MARK: - Character Data (JSON Decoding)

/// Intermediate struct for decoding JSON data from characters.json
public struct CharacterData: Codable {
    public let name: String
    public let set: String?
    public let notes: String?
    public let blue: String
    public let orange: String
    public let red: String
    public let teen: String
    public let health: String

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case set = "Set"
        case notes = "Notes"
        case blue = "Blue"
        case orange = "Orange"
        case red = "Red"
        case teen = "Teen"
        case health = "Health"
    }

    /// Parse boolean from string (True/False from JSON)
    public var isTeen: Bool {
        teen.lowercased() == "true"
    }

    /// Parse health from string
    public var healthValue: Int {
        Int(health) ?? 3
    }
}
