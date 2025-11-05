//
//  Skill.swift
//  CoreDomain
//
//  Reusable skill definition with name and description.
//  Used for displaying skill details in character views.
//

import Foundation
import SwiftData

/// Reusable skill definition with name and description
/// Used for displaying skill details in character views
@Model
public final class Skill {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var skillDescription: String
    public var isBuiltIn: Bool  // True for preloaded skills

    public init(id: UUID = UUID(), name: String, skillDescription: String, isBuiltIn: Bool = false) {
        self.id = id
        self.name = name
        self.skillDescription = skillDescription
        self.isBuiltIn = isBuiltIn
    }
}
