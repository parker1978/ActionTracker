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
    
    let onActionSelected: (ActionItem) -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                VStack(spacing: 12) {
                    HStack {
                        Text("Choose Your Action")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Spacer(minLength: 0)
                        
                        Button {
                            /// Dismissing Sheet
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundStyle(Color.gray, Color.primary.opacity(0.1))
                        }
                    }
                    .padding(.bottom, 10)
                    
                    /// Custom Checkbox Menu
                    ForEach(actions) { action in
                        let isSelected: Bool = selectedAction?.id == action.id
                        
                        HStack(spacing: 10) {
                            Image(systemName: action.image)
                                .font(.title)
                                .frame(width: 40)
                            
                            Text(action.title)
                                .fontWeight(.semibold)
                            
                            Spacer(minLength: 0)
                            
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle.fill")
                                .font(.title)
                                .contentTransition(.symbolEffect)
                                .foregroundStyle(isSelected ? Color.blue : Color.gray.opacity(0.2))
                        }
                        .padding(.vertical, 6)
                        .contentShape(.rect)
                        .onTapGesture {
                            withAnimation(.snappy) {
                                selectedAction = isSelected ? nil : action
                            }
                        }
                    }
                }
            }
            .compositingGroup()
            
            /// Continue Button
            Button {
                onActionSelected(ActionItem(id: UUID(), label: selectedAction!.title, isUsed: false))
                dismiss()
            } label: {
                Text("Continue")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .foregroundStyle(.white)
                    .background(.blue, in: .capsule)
            }
            .disabledWithOpacity(selectedAction == nil ? true : false)
            .padding(.top, 15)
        }
        .padding(20)
    }
}
