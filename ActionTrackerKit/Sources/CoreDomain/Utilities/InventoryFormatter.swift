//
//  InventoryFormatter.swift
//  CoreDomain
//
//  String parsing utilities for weapon inventory.
//  Handles comma and semicolon separators.
//

import Foundation

/// Utility for formatting and parsing inventory strings
public enum InventoryFormatter {
    private static let separators = CharacterSet(charactersIn: ",;")

    /// Convert a persisted inventory string into an array of weapon identifiers (name|expansion)
    /// Returns empty array for old format data (entries without "|" separator)
    public static func parse(_ inventory: String) -> [String] {
        inventory
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { $0.contains("|") }  // Filter out old format (name-only entries)
    }

    /// Convert an array of weapon identifiers (name|expansion) into the canonical persisted format
    public static func join(_ weapons: [String]) -> String {
        weapons.joined(separator: "; ")
    }
}
