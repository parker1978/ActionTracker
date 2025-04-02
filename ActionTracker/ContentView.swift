//
//  ContentView.swift
//  ActionTracker
//
//  Created by Stephen Parker on 4/1/25.
//

import SwiftUI

// A simple model for an action
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

struct ContentView: View {
    // The list of actions; starts with three default actions
    @State private var actions: [ActionItem] = ActionItem.defaultActions()
    @State private var showResetConfirmation = false
    
    // Computes how many actions are still available (i.e. not used)
    var availableActions: Int {
        actions.filter { !$0.isUsed }.count
    }

    var body: some View {
        VStack {
            // Header with available actions counter and control buttons
            HStack {
                Text("Actions Available: \(availableActions)")
                    .font(.headline)
                Spacer()
                
                Button("Reset") {
                    showResetConfirmation = true
                }
                .padding(.horizontal)
                .alert("Reset Game?", isPresented: $showResetConfirmation) {
                    Button("Cancel", role: .cancel) { }
                    Button("Reset", role: .destructive) {
                        // Reset the game: clear extra actions and mark all as unused
                        actions = ActionItem.defaultActions()
                    }
                } message: {
                    Text("Are you sure you want to reset your actions? This will remove any extra actions and mark all actions as unused.")
                }
            }
            .padding()
            
            // List showing each action as an HStack with a toggle and a text field
            List {
                ForEach(actions.indices, id: \.self) { index in
                    HStack {
                        Toggle("", isOn: $actions[index].isUsed)
                            .labelsHidden()
                        TextField("Action \(index + 1)", text: $actions[index].label)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .overlay(
                                HStack {
                                    Spacer()
                                    if !actions[index].label.isEmpty {
                                        Button(action: {
                                            actions[index].label = ""
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.secondary)
                                                .padding(8)
                                        }
                                        .frame(width: 44, height: 44)
                                        .contentShape(Rectangle())
                                        .buttonStyle(PlainButtonStyle())
                                        .padding(.trailing, 8)
                                    }
                                }
                            )
                    }
                    // Enable swipe-to-delete only for actions beyond the first three
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        if index >= 3 {
                            Button(role: .destructive) {
                                actions.remove(at: index)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .listStyle(PlainListStyle())
            
            // Button to add an extra action, up to a maximum of 6 actions
            HStack {
                Spacer()
                
                Button("Add Action") {
                    let newActionNumber = actions.count + 1
                    actions.append(ActionItem(id: UUID(), label: "Action \(newActionNumber)", isUsed: false))
                }
                .padding()
                
                Spacer()
                
                Button("End Turn") {
                    // Reset all toggles (mark all actions as unused) without changing the number of actions
                    for index in actions.indices {
                        actions[index].isUsed = false
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
