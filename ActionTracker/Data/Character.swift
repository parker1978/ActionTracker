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
    @Attribute(.unique) var name: String
    var set: String?
    var allSkills: [String]
    var notes: String?
    
    init(name: String, set: String? = nil, allSkills: [String], notes: String? = nil) {
        self.name = name
        self.set = set
        self.allSkills = allSkills
        self.notes = notes
    }
}
