//
//  TrayView.swift
//  ActionTracker
//
//  Created by Stephen Parker on 4/2/25.
//

import SwiftUI

struct TrayView: View {
    @State private var selectedAction: Action?
    @Environment(\.dismiss) var dismiss
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    
    let onActionSelected: (ActionItem) -> Void
    
    // Accessibility improvement - readable content width
    var maxWidthForContent: CGFloat {
        return dynamicTypeSize >= .accessibility1 ? .infinity : 500
    }
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                VStack(spacing: 12) {
                    HStack {
                        Text("Choose Your Action")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .accessibilityAddTraits(.isHeader)
                        
                        Spacer(minLength: 0)
                        
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundStyle(Color.gray, Color.primary.opacity(0.1))
                                .accessibilityLabel("Close")
                        }
                    }
                    .padding(.bottom, 10)
                    
                    // Scrollable action list for better accessibility
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(actions) { action in
                                ActionRow(
                                    action: action, 
                                    isSelected: selectedAction?.id == action.id
                                ) {
                                    withAnimation(.snappy) {
                                        selectedAction = selectedAction?.id == action.id ? nil : action
                                    }
                                }
                                .contentShape(.rect)
                                .frame(maxWidth: maxWidthForContent)
                            }
                        }
                    }
                    .scrollIndicators(.visible)
                }
            }
            .compositingGroup()
            
            // Continue Button
            Button {
                guard let selectedAction else { return }
                onActionSelected(ActionItem(id: UUID(), label: selectedAction.title, isUsed: false))
                dismiss()
            } label: {
                Text("Continue")
                    .fontWeight(.semibold)
                    .frame(maxWidth: maxWidthForContent)
                    .padding(.vertical, 15)
                    .foregroundStyle(.white)
                    .background(selectedAction == nil ? Color.gray : Color.blue, in: .capsule)
            }
            .disabled(selectedAction == nil)
            .padding(.top, 15)
            .accessibilityHint(selectedAction == nil ? "Select an action first" : "Add the selected action")
        }
        .padding(20)
    }
}

// Extracted reusable component for better layout and maintainability
struct ActionRow: View {
    let action: Action
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: action.image)
                    .font(.title2)
                    .frame(width: 40)
                    .foregroundColor(.primary)
                    .accessibilityHidden(true)
                
                Text(action.title)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer(minLength: 0)
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .contentTransition(.symbolEffect)
                    .foregroundStyle(isSelected ? Color.blue : Color.gray)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityLabel("\(action.title) action")
    }
}
