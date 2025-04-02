//
//  ContentView.swift
//  ActionTracker
//
//  Created by Stephen Parker on 4/1/25.
//

import SwiftUI

struct ContentView: View {
    // The list of actions; starts with three default actions
    @State private var actionItems: [ActionItem] = ActionItem.defaultActions()
    @State private var config: DrawerConfig = .init()
    @State private var showActions: Bool = false
    @State private var trayContinuation: CheckedContinuation<ActionItem?, Never>? = nil
    
    // Computes how many actions are still available (i.e. not used)
    var availableActions: Int {
        actionItems.filter { !$0.isUsed }.count
    }

    func waitForTraySelection() async -> ActionItem? {
        await withCheckedContinuation { continuation in
            trayContinuation = continuation
            showActions = true
        }
    }

    var body: some View {
        VStack {
            // Header with available actions counter and control buttons
            HStack {
                Text("Actions Available: \(availableActions)")
                    .font(.headline)
                
                Spacer()
                
                DrawerButton(title: "Reset", config: $config)
            }
            .padding()
            
            // List showing each action as an HStack with a toggle and a text field
            List {
                ForEach(actionItems.indices, id: \.self) { index in
                    HStack {
                        Toggle("", isOn: $actionItems[index].isUsed)
                            .labelsHidden()
                        TextField("Action \(index + 1)", text: $actionItems[index].label)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .overlay(
                                HStack {
                                    Spacer()
                                    if !actionItems[index].label.isEmpty {
                                        Button(action: {
                                            actionItems[index].label = ""
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
                                actionItems.remove(at: index)
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
                    Task {
                        if let newAction = await waitForTraySelection() {
                            actionItems.append(newAction)
                        }
                    }
                }
                .padding()
                
                Spacer()
                
                Button("End Turn") {
                    // Reset all toggles (mark all actions as unused) without changing the number of actions
                    for index in actionItems.indices {
                        actionItems[index].isUsed = false
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
        }
        .padding()
        .systemTrayView($showActions) {
            TrayView { selectedAction in
                trayContinuation?.resume(returning: selectedAction)
                trayContinuation = nil
                showActions = false
            }
            //TrayView()
        }
        .alertDrawer(config: $config, primaryTitle: "Reset", secondaryTitle: "Cancel") {
            actionItems = ActionItem.defaultActions()
            return true
        } onSecondaryClick: {
            return true
        } content: {
            /// Dummy Content
            VStack(alignment: .leading, spacing: 15) {
                Image(systemName: "exclamationmark.circle")
                    .font(.largeTitle)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("Are you sure?")
                    .font(.title2.bold())
                
                Text("This will remove any extra actions and mark all actions as unused.")
                    .foregroundStyle(.gray)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: 300)
            }
        }
    }
}

#Preview {
    ContentView()
}
