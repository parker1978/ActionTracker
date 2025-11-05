//
//  ActionInstance.swift
//  CoreDomain
//
//  Represents a single action token during gameplay.
//  Can be used/unused and marked as default (cannot be deleted).
//

import Foundation
import SwiftData

/// Represents a single action token during gameplay
/// Can be used/unused and marked as default (cannot be deleted)
@Model
public final class ActionInstance {
    @Attribute(.unique) public var id: UUID
    public var type: ActionType  // Type of action (action, combat, melee, etc.)
    public var isDefault: Bool   // True for the initial 3 actions (cannot be deleted)
    public var isUsed: Bool      // True when action has been spent this turn

    /// Reference back to the game session
    @Relationship(inverse: \GameSession.actions) public var session: GameSession?

    public init(id: UUID = UUID(), type: ActionType, isDefault: Bool = false, isUsed: Bool = false) {
        self.id = id
        self.type = type
        self.isDefault = isDefault
        self.isUsed = isUsed
    }
}
