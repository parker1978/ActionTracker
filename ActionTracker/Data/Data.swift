//
//  Data.swift
//  ActionTracker
//
//  Created by Stephen Parker on 4/2/25.
//

import SwiftUI

struct ActionItem: Identifiable, Codable, Equatable {
    var id: UUID
    var label: String
    var isUsed: Bool

    // Returns the default three actions
    static func defaultActions() -> [ActionItem] {
        return [
            ActionItem(id: UUID(), label: "Action 1", isUsed: false),
            ActionItem(id: UUID(), label: "Action 2", isUsed: false),
            ActionItem(id: UUID(), label: "Action 3", isUsed: false)
        ]
    }
    
    // Codable conformance is auto-synthesized since all properties are Codable
    
    // Equatable to detect changes for persistence
    static func == (lhs: ActionItem, rhs: ActionItem) -> Bool {
        return lhs.id == rhs.id && lhs.label == rhs.label && lhs.isUsed == rhs.isUsed
    }
}

struct Action: Identifiable, Hashable {
    var id: String = UUID().uuidString
    var image: String
    var title: String
}

let actions: [Action] = [
    .init(image: "star.circle.fill", title: "Action"),
    .init(image: "figure.socialdance.circle.fill", title: "Combat"),
    .init(image: "figure.fencing.circle.fill", title: "Melee"),
    .init(image: "figure.archery.circle.fill", title: "Ranged"),
    .init(image: "figure.run.circle.fill", title: "Move"),
    .init(image: "flashlight.on.circle.fill", title: "Search"),
]

/// For custom keypad entry
struct KeyPad: Identifiable {
    var id: String = UUID().uuidString
    var title: String
    var value: Int
    var isBack: Bool = false
}

let keypadValues: [KeyPad] = (1...9).compactMap({ .init(title: String("\($0)"), value: $0) }) + [
    .init(title: "0", value: 0),
    .init(title: "chevron.left", value: -1, isBack: true)
]
