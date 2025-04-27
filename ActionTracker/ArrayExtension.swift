//
//  ArrayExtension.swift
//  ActionTracker
//
//  Created by Stephen Parker on 4/11/25.
//

import SwiftUI
import SwiftData

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// Color functions moved to SkillColorExtension.swift
