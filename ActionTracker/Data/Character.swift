//
//  Character.swift
//  ZombicideCharacters
//
//  Created by Stephen Parker on 4/11/25.
//

import Foundation
import SwiftData

@Model
class Character {
    // Remove unique constraint as it's not supported with CloudKit
    var name: String = ""
    var set: String?
    // Add default empty array for non-optional array property
    var allSkills: [String] = []
    var notes: String?
    
    init(name: String, set: String? = nil, allSkills: [String], notes: String? = nil) {
        self.name = name
        self.set = set
        self.allSkills = allSkills
        self.notes = notes
    }
}
