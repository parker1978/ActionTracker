//
//  WeaponsLogger.swift
//  CoreDomain
//
//  Phase 5: Structured logging for weapons system
//  Provides os_log categories for production logging
//

import OSLog

/// Centralized logging for the weapons system
/// Uses os_log for structured, performant production logging
public struct WeaponsLogger {
    /// Logger for weapon import operations
    public static let importer = Logger(subsystem: "ActionTracker", category: "WeaponImporter")

    /// Logger for deck service operations (draw, shuffle, discard)
    public static let deck = Logger(subsystem: "ActionTracker", category: "DeckService")

    /// Logger for inventory service operations (add, remove, move)
    public static let inventory = Logger(subsystem: "ActionTracker", category: "InventoryService")

    /// Logger for customization service operations (presets, overrides)
    public static let customization = Logger(subsystem: "ActionTracker", category: "CustomizationService")

    /// Logger for performance metrics and timing
    public static let performance = Logger(subsystem: "ActionTracker", category: "Performance")
}
