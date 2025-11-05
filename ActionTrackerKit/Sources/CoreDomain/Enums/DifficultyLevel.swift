//
//  DifficultyLevel.swift
//  CoreDomain
//
//  Four difficulty levels matching the game's color system.
//  Shared between spawn deck and skill progression.
//

import Foundation

/// Four difficulty levels matching the game's color system
public enum DifficultyLevel: String, Codable, CaseIterable {
    case blue = "Blue"
    case yellow = "Yellow"
    case orange = "Orange"
    case red = "Red"

    public var displayName: String { rawValue }
}
