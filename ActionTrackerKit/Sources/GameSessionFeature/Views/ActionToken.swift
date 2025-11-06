//
//  ActionToken.swift
//  GameSessionFeature
//
//  Individual action token component for action tracking
//

import SwiftUI
import SwiftData
import CoreDomain
import SharedUI

/// Individual action token that can be tapped to toggle used state
/// In edit mode, displays shake animation and allows deletion via tap
/// Default actions (first 3) cannot be deleted
struct ActionToken: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var action: ActionInstance
    let isEditMode: Bool

    var body: some View {
        Button {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                if isEditMode && !action.isDefault {
                    // Delete action in edit mode (only non-default actions)
                    if let session = action.session {
                        session.removeAction(action)
                        try? modelContext.save()
                    }
                } else {
                    // Toggle used state in normal mode
                    action.isUsed.toggle()
                    try? modelContext.save()
                }
            }
        } label: {
            ZStack {
                // Background circle
                Circle()
                    .fill(action.isUsed ? Color(.systemGray4) : action.type.color)
                    .frame(width: 50, height: 50)

                // Border ring for unused actions
                Circle()
                    .strokeBorder(
                        action.isUsed ? Color.clear : action.type.color.opacity(0.6),
                        lineWidth: 4
                    )
                    .frame(width: 58, height: 58)

                // Icon (checkmark when used, X when deletable in edit mode, type icon otherwise)
                Group {
                    if isEditMode && !action.isDefault {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                    } else if action.isUsed {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                    } else {
                        Image(systemName: action.type.icon)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .shadow(
            color: action.isUsed ? .clear : action.type.color.opacity(0.5),
            radius: 6,
            x: 0,
            y: 3
        )
        // Apply shake effect when in edit mode for non-default actions
        .modifier(ShakeEffect(isShaking: isEditMode && !action.isDefault))
    }
}
