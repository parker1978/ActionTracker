//
//  InventoryService.swift
//  CoreDomain
//
//  Phase 2: Service layer for inventory management
//  Handles slot enforcement, add/remove/move operations, and history tracking
//

import SwiftData
import Foundation
import OSLog

/// Service for managing weapon inventory operations
/// Enforces slot limits, tracks history, and coordinates with deck service
@MainActor
public class InventoryService {
    private let context: ModelContext
    private let deckService: WeaponsDeckService

    public init(context: ModelContext, deckService: WeaponsDeckService) {
        self.context = context
        self.deckService = deckService
    }

    // MARK: - Capacity Management

    /// Get active slot capacity (always 2 hands)
    public func getActiveCapacity(for session: GameSession) -> Int {
        return 2
    }

    /// Get backpack capacity (3 base + extraInventorySlots)
    public func getBackpackCapacity(for session: GameSession) -> Int {
        return 3 + session.extraInventorySlots
    }

    /// Check if can add to active slots
    public func canAddToActive(session: GameSession) -> Bool {
        let activeItems = session.inventoryItems.filter { $0.slotType == "active" }
        return activeItems.count < getActiveCapacity(for: session)
    }

    /// Check if can add to backpack
    public func canAddToBackpack(session: GameSession) -> Bool {
        let backpackItems = session.inventoryItems.filter { $0.slotType == "backpack" }
        return backpackItems.count < getBackpackCapacity(for: session)
    }

    /// Get current active count
    public func getActiveCount(session: GameSession) -> Int {
        return session.inventoryItems.filter { $0.slotType == "active" }.count
    }

    /// Get current backpack count
    public func getBackpackCount(session: GameSession) -> Int {
        return session.inventoryItems.filter { $0.slotType == "backpack" }.count
    }

    // MARK: - Add Operations

    /// Add weapon to active slot
    /// Returns nil if successful, error message if failed
    public func addToActive(
        instance: WeaponCardInstance,
        session: GameSession,
        deckState: DeckRuntimeState?
    ) async throws -> String? {
        // Check capacity
        guard canAddToActive(session: session) else {
            return "Active slots full (2/2). Move a weapon to backpack first."
        }

        // Find next available slot index
        let activeItems = session.inventoryItems.filter { $0.slotType == "active" }
        let usedIndices = Set(activeItems.map { $0.slotIndex })
        let nextIndex = (0..<2).first { !usedIndices.contains($0) } ?? 0

        // Create inventory item
        let item = WeaponInventoryItem(
            slotType: "active",
            slotIndex: nextIndex,
            cardInstance: instance
        )
        item.session = session
        context.insert(item)

        // Remove from deck if provided
        if let deckState = deckState {
            try await deckService.removeFromDiscard(instance, in: deckState)
        }

        // Record event
        try await recordEvent(
            type: "add",
            session: session,
            instance: instance,
            slotType: "active",
            slotIndex: nextIndex
        )

        try context.save()
        WeaponsLogger.inventory.notice("Added \(instance.definition?.name ?? "weapon") to active slot \(nextIndex)")
        return nil  // Success
    }

    /// Add weapon to backpack
    /// Returns nil if successful, error message if failed
    public func addToBackpack(
        instance: WeaponCardInstance,
        session: GameSession,
        deckState: DeckRuntimeState?
    ) async throws -> String? {
        // Check capacity
        guard canAddToBackpack(session: session) else {
            let capacity = getBackpackCapacity(for: session)
            return "Backpack full (\(capacity)/\(capacity)). Discard a weapon first."
        }

        // Find next available slot index
        let backpackItems = session.inventoryItems.filter { $0.slotType == "backpack" }
        let usedIndices = Set(backpackItems.map { $0.slotIndex })
        let nextIndex = (0..<99).first { !usedIndices.contains($0) } ?? 0

        // Create inventory item
        let item = WeaponInventoryItem(
            slotType: "backpack",
            slotIndex: nextIndex,
            cardInstance: instance
        )
        item.session = session
        context.insert(item)

        // Remove from deck if provided
        if let deckState = deckState {
            try await deckService.removeFromDiscard(instance, in: deckState)
        }

        // Record event
        try await recordEvent(
            type: "add",
            session: session,
            instance: instance,
            slotType: "backpack",
            slotIndex: nextIndex
        )

        try context.save()
        WeaponsLogger.inventory.notice("Added \(instance.definition?.name ?? "weapon") to backpack slot \(nextIndex)")
        return nil  // Success
    }

    // MARK: - Remove Operations

    /// Remove weapon from inventory
    /// Optionally discard back to deck
    public func remove(
        item: WeaponInventoryItem,
        session: GameSession,
        discardToDeck: Bool = false,
        deckState: DeckRuntimeState? = nil
    ) async throws {
        guard let instance = item.cardInstance else { return }

        // Record event before removal
        try await recordEvent(
            type: "remove",
            session: session,
            instance: instance,
            slotType: nil,
            slotIndex: nil
        )

        // Discard to deck if requested
        if discardToDeck, let deckState = deckState {
            try await deckService.discard(instance, to: deckState)
        }

        // Remove from inventory
        context.delete(item)
        try context.save()
    }

    // MARK: - Move Operations

    /// Move weapon from active to backpack
    public func moveActiveToBackpack(
        item: WeaponInventoryItem,
        session: GameSession
    ) async throws -> String? {
        guard item.slotType == "active" else {
            return "Item is not in active slot"
        }

        // Check backpack capacity
        guard canAddToBackpack(session: session) else {
            let capacity = getBackpackCapacity(for: session)
            return "Backpack full (\(capacity)/\(capacity))"
        }

        guard let instance = item.cardInstance else {
            return "No weapon instance found"
        }

        // Find next backpack slot
        let backpackItems = session.inventoryItems.filter { $0.slotType == "backpack" }
        let usedIndices = Set(backpackItems.map { $0.slotIndex })
        let nextIndex = (0..<99).first { !usedIndices.contains($0) } ?? 0

        // Record event
        try await recordEvent(
            type: "move",
            session: session,
            instance: instance,
            slotType: "backpack",
            slotIndex: nextIndex,
            fromSlotType: "active",
            fromSlotIndex: item.slotIndex
        )

        // Update item
        item.slotType = "backpack"
        item.slotIndex = nextIndex
        item.isEquipped = false

        try context.save()
        return nil  // Success
    }

    /// Move weapon from backpack to active
    public func moveBackpackToActive(
        item: WeaponInventoryItem,
        session: GameSession
    ) async throws -> String? {
        guard item.slotType == "backpack" else {
            return "Item is not in backpack"
        }

        // Check active capacity
        guard canAddToActive(session: session) else {
            return "Active slots full (2/2)"
        }

        guard let instance = item.cardInstance else {
            return "No weapon instance found"
        }

        // Find next active slot
        let activeItems = session.inventoryItems.filter { $0.slotType == "active" }
        let usedIndices = Set(activeItems.map { $0.slotIndex })
        let nextIndex = (0..<2).first { !usedIndices.contains($0) } ?? 0

        // Record event
        try await recordEvent(
            type: "move",
            session: session,
            instance: instance,
            slotType: "active",
            slotIndex: nextIndex,
            fromSlotType: "backpack",
            fromSlotIndex: item.slotIndex
        )

        // Update item
        item.slotType = "active"
        item.slotIndex = nextIndex
        item.isEquipped = true

        try context.save()
        return nil  // Success
    }

    // MARK: - Replacement Flow

    /// Replace a weapon (remove old, add new)
    /// Used when inventory is full
    public func replaceWeapon(
        old: WeaponInventoryItem,
        new: WeaponCardInstance,
        session: GameSession,
        discardOldToDeck: Bool = true,
        deckState: DeckRuntimeState? = nil
    ) async throws {
        let oldSlotType = old.slotType
        let oldSlotIndex = old.slotIndex

        // Remove old weapon
        try await remove(
            item: old,
            session: session,
            discardToDeck: discardOldToDeck,
            deckState: deckState
        )

        // Add new weapon to same slot
        let newItem = WeaponInventoryItem(
            slotType: oldSlotType,
            slotIndex: oldSlotIndex,
            cardInstance: new
        )
        newItem.session = session
        context.insert(newItem)

        // Remove new weapon from deck
        if let deckState = deckState {
            try await deckService.removeFromDiscard(new, in: deckState)
        }

        // Record replacement event
        try await recordEvent(
            type: "replace",
            session: session,
            instance: new,
            slotType: oldSlotType,
            slotIndex: oldSlotIndex
        )

        try context.save()
    }

    // MARK: - History Tracking

    /// Record an inventory event
    private func recordEvent(
        type: String,
        session: GameSession,
        instance: WeaponCardInstance,
        slotType: String?,
        slotIndex: Int?,
        fromSlotType: String? = nil,
        fromSlotIndex: Int? = nil
    ) async throws {
        let event = InventoryEvent(
            eventType: type,
            slotType: slotType,
            slotIndex: slotIndex
        )
        event.session = session
        event.cardInstance = instance
        event.fromSlotType = fromSlotType
        event.fromSlotIndex = fromSlotIndex

        context.insert(event)
    }

    /// Get inventory event history for a session
    public func getHistory(for session: GameSession) -> [InventoryEvent] {
        return session.inventoryEvents.sorted { $0.timestamp > $1.timestamp }
    }

    /// Get inventory events for a specific weapon
    public func getHistory(for instance: WeaponCardInstance, in session: GameSession) -> [InventoryEvent] {
        return session.inventoryEvents
            .filter { $0.cardInstance?.id == instance.id }
            .sorted { $0.timestamp > $1.timestamp }
    }

    // MARK: - Modifiers Support

    /// Check if "all inventory active" modifier is enabled
    /// When true, all backpack weapons count as active
    public func isAllInventoryActive(session: GameSession) -> Bool {
        return session.allInventoryActive
    }

    /// Get effective active weapons (considering modifiers)
    public func getEffectiveActiveWeapons(session: GameSession) -> [WeaponInventoryItem] {
        if session.allInventoryActive {
            // All weapons count as active
            return session.inventoryItems
        } else {
            // Only active slot weapons
            return session.inventoryItems.filter { $0.slotType == "active" }
        }
    }

    // MARK: - Utility Methods

    /// Get all active items
    public func getActiveItems(session: GameSession) -> [WeaponInventoryItem] {
        return session.inventoryItems
            .filter { $0.slotType == "active" }
            .sorted { $0.slotIndex < $1.slotIndex }
    }

    /// Get all backpack items
    public func getBackpackItems(session: GameSession) -> [WeaponInventoryItem] {
        return session.inventoryItems
            .filter { $0.slotType == "backpack" }
            .sorted { $0.slotIndex < $1.slotIndex }
    }

    /// Check if session has any inventory
    public func hasInventory(session: GameSession) -> Bool {
        return !session.inventoryItems.isEmpty
    }

    /// Get total inventory count
    public func getTotalCount(session: GameSession) -> Int {
        return session.inventoryItems.count
    }
}
