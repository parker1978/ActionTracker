//
//  Data.swift
//  ActionTracker
//
//  Created by Stephen Parker on 4/2/25.
//

import SwiftUI

struct ActionItem: Identifiable {
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
