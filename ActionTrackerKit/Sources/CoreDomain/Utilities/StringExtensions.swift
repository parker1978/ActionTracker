//
//  StringExtensions.swift
//  CoreDomain
//
//  Utility extensions for String operations.
//

import Foundation

public extension String {
    /// Check if the string contains any of the provided search strings (case-insensitive)
    /// - Parameter strings: Variadic list of strings to search for
    /// - Returns: True if any of the strings are found
    func contains(_ strings: String...) -> Bool {
        for string in strings {
            if self.localizedCaseInsensitiveContains(string) {
                return true
            }
        }
        return false
    }
}
