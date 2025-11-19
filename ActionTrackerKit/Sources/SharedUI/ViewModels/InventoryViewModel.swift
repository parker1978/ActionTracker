//
//  InventoryViewModel.swift
//  SharedUI
//
//  Phase 4: View model for inventory operations
//  Wraps InventoryService and provides @Published state for SwiftUI
//

import SwiftUI
import SwiftData
import CoreDomain
import Observation

/// View model for weapon inventory operations
/// Wraps InventoryService and manages inventory state for UI
@MainActor
@Observable
public final class InventoryViewModel {
    private let inventoryService: InventoryService
    private let context: ModelContext

    // Published state for UI
    public var activeItems: [WeaponInventoryItem] = []
    public var backpackItems: [WeaponInventoryItem] = []
    public var isLoading = false
    public var errorMessage: String?

    // Capacity info
    public var activeCapacity: Int = 2
    public var backpackCapacity: Int = 3

    // Computed properties
    public var canAddToActive: Bool {
        activeItems.count < activeCapacity
    }

    public var canAddToBackpack: Bool {
        backpackItems.count < backpackCapacity
    }

    public var hasInventory: Bool {
        !activeItems.isEmpty || !backpackItems.isEmpty
    }

    public var totalCount: Int {
        activeItems.count + backpackItems.count
    }

    public init(inventoryService: InventoryService, context: ModelContext) {
        self.inventoryService = inventoryService
        self.context = context
    }

    // MARK: - Loading

    /// Load inventory for the given session
    public func loadInventory(for session: GameSession) {
        activeItems = inventoryService.getActiveItems(session: session)
        backpackItems = inventoryService.getBackpackItems(session: session)
        activeCapacity = inventoryService.getActiveCapacity(for: session)
        backpackCapacity = inventoryService.getBackpackCapacity(for: session)
    }

    /// Refresh inventory (call after operations)
    public func refresh(for session: GameSession) {
        loadInventory(for: session)
    }

    // MARK: - Add Operations

    /// Add weapon to active slot
    @discardableResult
    public func addToActive(
        _ instance: WeaponCardInstance,
        session: GameSession,
        deckState: DeckRuntimeState? = nil
    ) async -> String? {
        let error = try? await inventoryService.addToActive(
            instance: instance,
            session: session,
            deckState: deckState
        )

        if error == nil {
            refresh(for: session)
        } else {
            errorMessage = error
        }

        return error
    }

    /// Add weapon to backpack
    @discardableResult
    public func addToBackpack(
        _ instance: WeaponCardInstance,
        session: GameSession,
        deckState: DeckRuntimeState? = nil
    ) async -> String? {
        let error = try? await inventoryService.addToBackpack(
            instance: instance,
            session: session,
            deckState: deckState
        )

        if error == nil {
            refresh(for: session)
        } else {
            errorMessage = error
        }

        return error
    }

    // MARK: - Remove Operations

    /// Remove weapon from inventory
    public func remove(
        _ item: WeaponInventoryItem,
        session: GameSession,
        discardToDeck: Bool = false,
        deckState: DeckRuntimeState? = nil
    ) async {
        do {
            try await inventoryService.remove(
                item: item,
                session: session,
                discardToDeck: discardToDeck,
                deckState: deckState
            )
            refresh(for: session)
        } catch {
            errorMessage = "Failed to remove weapon: \(error.localizedDescription)"
        }
    }

    // MARK: - Move Operations

    /// Move weapon from active to backpack
    @discardableResult
    public func moveActiveToBackpack(
        _ item: WeaponInventoryItem,
        session: GameSession
    ) async -> String? {
        let error = try? await inventoryService.moveActiveToBackpack(
            item: item,
            session: session
        )

        if error == nil {
            refresh(for: session)
        } else {
            errorMessage = error
        }

        return error
    }

    /// Move weapon from backpack to active
    @discardableResult
    public func moveBackpackToActive(
        _ item: WeaponInventoryItem,
        session: GameSession
    ) async -> String? {
        let error = try? await inventoryService.moveBackpackToActive(
            item: item,
            session: session
        )

        if error == nil {
            refresh(for: session)
        } else {
            errorMessage = error
        }

        return error
    }

    // MARK: - Replacement Flow

    /// Replace a weapon (remove old, add new)
    public func replaceWeapon(
        old: WeaponInventoryItem,
        new: WeaponCardInstance,
        session: GameSession,
        discardOldToDeck: Bool = true,
        deckState: DeckRuntimeState? = nil
    ) async {
        do {
            try await inventoryService.replaceWeapon(
                old: old,
                new: new,
                session: session,
                discardOldToDeck: discardOldToDeck,
                deckState: deckState
            )
            refresh(for: session)
        } catch {
            errorMessage = "Failed to replace weapon: \(error.localizedDescription)"
        }
    }

    // MARK: - Modifiers Support

    /// Check if "all inventory active" modifier is enabled
    public func isAllInventoryActive(session: GameSession) -> Bool {
        return inventoryService.isAllInventoryActive(session: session)
    }

    /// Get effective active weapons (considering modifiers)
    public func getEffectiveActiveWeapons(session: GameSession) -> [WeaponInventoryItem] {
        return inventoryService.getEffectiveActiveWeapons(session: session)
    }

    // MARK: - History

    /// Get inventory event history
    public func getHistory(for session: GameSession) -> [InventoryEvent] {
        return inventoryService.getHistory(for: session)
    }

    /// Get inventory events for a specific weapon
    public func getHistory(for instance: WeaponCardInstance, in session: GameSession) -> [InventoryEvent] {
        return inventoryService.getHistory(for: instance, in: session)
    }

    // MARK: - Helpers

    /// Get weapon display name from inventory item
    public func getWeaponName(from item: WeaponInventoryItem) -> String {
        return item.cardInstance?.definition?.name ?? "Unknown"
    }

    /// Get weapon set from inventory item
    public func getWeaponSet(from item: WeaponInventoryItem) -> String {
        return item.cardInstance?.definition?.set ?? ""
    }

    /// Get weapon category from inventory item
    public func getWeaponCategory(from item: WeaponInventoryItem) -> String {
        return item.cardInstance?.definition?.category ?? ""
    }
}
