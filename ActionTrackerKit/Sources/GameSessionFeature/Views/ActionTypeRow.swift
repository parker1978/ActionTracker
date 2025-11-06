//
//  ActionTypeRow.swift
//  GameSessionFeature
//
//  Row displaying action tokens grouped by action type
//

import SwiftUI
import SwiftData
import CoreDomain
import SharedUI

/// Row displaying action tokens grouped by action type
/// Shows type icon, name, count, and individual action tokens
struct ActionTypeRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var session: GameSession
    let actionType: ActionType
    let isEditMode: Bool

    /// Get all actions of this specific type
    var actionsOfType: [ActionInstance] {
        session.actions.filter { $0.type == actionType }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // MARK: Type Header
            HStack {
                Image(systemName: actionType.icon)
                    .font(.subheadline)
                    .foregroundStyle(actionType.color)

                Text(actionType.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                // Remaining / Total counter for this type
                Text("\(actionsOfType.filter { !$0.isUsed }.count)/\(actionsOfType.count)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            // MARK: Action Tokens (flow layout)
            FlowLayout(spacing: 8) {
                ForEach(actionsOfType) { action in
                    ActionToken(action: action, isEditMode: isEditMode)
                }
            }
            .animation(nil, value: actionsOfType.map { $0.id })
        }
        .padding(12)
        .background(actionType.color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .animation(nil, value: actionsOfType.map { $0.isUsed })
    }
}
