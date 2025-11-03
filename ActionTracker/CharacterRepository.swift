//
//  CharacterRepository.swift
//  ActionTracker
//
//  Loads characters from bundled JSON data
//  Ensures all players/devices use identical character data
//

import Foundation

// MARK: - Character Repository

/// Loads and provides access to bundled character data
class CharacterRepository {
    static let shared = CharacterRepository()

    /// Version of the characters data (for debugging and sync verification)
    static let CHARACTERS_DATA_VERSION = "1.0.0"

    private(set) var allCharacters: [CharacterData] = []

    private init() {
        loadCharacters()
    }

    // MARK: - Loading

    /// Load characters from bundled JSON file
    private func loadCharacters() {
        guard let url = Bundle.main.url(forResource: "characters", withExtension: "json") else {
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
    func getCharacters(forSet set: String) -> [CharacterData] {
        allCharacters.filter { $0.set == set }
    }

    /// Get all unique expansion sets
    var expansionSets: [String] {
        let sets = Set(allCharacters.compactMap { $0.set }.filter { !$0.isEmpty })
        return Array(sets).sorted()
    }
}

// MARK: - Character Data (JSON Decoding)

/// Intermediate struct for decoding JSON data from characters.json
struct CharacterData: Codable {
    let name: String
    let set: String?
    let notes: String?
    let blue: String
    let orange: String
    let red: String
    let teen: String
    let health: String

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
    var isTeen: Bool {
        teen.lowercased() == "true"
    }

    /// Parse health from string
    var healthValue: Int {
        Int(health) ?? 3
    }
}
