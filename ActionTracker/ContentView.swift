//
//  ContentView.swift
//  ActionTracker
//
//  Created by Stephen Parker on 4/1/25.
//

import SwiftUI
import TipKit

struct ContentView: View {
    // The list of actions; starts with three default actions
    @State private var actionItems: [ActionItem] = ActionItem.defaultActions()
    @State private var config: DrawerConfig = .init()
    @State private var showActions: Bool = false
    @State private var trayContinuation: CheckedContinuation<ActionItem?, Never>? = nil
    @State private var addBounce: Bool = false
    @State private var shouldRotate: Bool = false
    
    var availableActions: Int {
        actionItems.filter { !$0.isUsed }.count
    }
    
    var actionActions: Int {
        actionItems.filter { $0.label.hasPrefix("Action") }.count
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
                DrawerButton(title: "Reset", config: $config)
                
                Spacer()
                
                Text("Actions Available: \(availableActions)")
                    .font(.headline)
            }
            .padding()
            
            // List showing each action as an HStack with a toggle and a text field
            List {
                ForEach(actionItems.indices, id: \.self) { index in
                    HStack {
                        Text(actionItems[index].label)
                        
                        Spacer()
                        
                        Button(action: {
                            actionItems[index].isUsed.toggle()
                        }, label: {
                            Image(systemName: actionItems[index].isUsed ? "checkmark.square.fill" : "square")
                                .font(.title)
                        })
                        .buttonStyle(BorderlessButtonStyle())
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
            .task {
                try? Tips.configure()
            }
            
            // Button to add an extra action, up to a maximum of 6 actions
            HStack {
                Spacer()
                
                Button(action: {
                    Task {
                        if let newAction = await waitForTraySelection() {
                            var action = newAction
                            if action.label == "Action" {
                                action.label = "Action \(actionActions + 1)"
                            }
                            actionItems.append(action)
                            renumberActionItems()
                            addBounce.toggle()
                        }
                    }
                }, label: {
                    Image(systemName: "plus.circle.fill")
                        .symbolEffect(.bounce, value: addBounce)
                        .fontWeight(.light)
                        .font(.system(size:56))
                })
                .popoverTip(AddActionTip(), arrowEdge: .top)
                .padding()
                
                Spacer()
                
                Button(action: {
                    shouldRotate.toggle()
                    for index in actionItems.indices {
                        actionItems[index].isUsed = false
                    }
                }, label: {
                    if #available(iOS 18.0, *) {
                        Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90.circle.fill")
                            .symbolEffect(.rotate.byLayer, options: .nonRepeating, value: shouldRotate)
                            .fontWeight(.light)
                            .font(.system(size:56))
                    } else {
                        Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90.circle.fill")
                            .symbolEffect(.bounce, options: .nonRepeating, value: shouldRotate)
                            .fontWeight(.light)
                            .font(.system(size:56))
                    }
                })
                .popoverTip(EndTurnTip(), arrowEdge: .top)
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
    
    func renumberActionItems() {
        var expectedNumber = 1
        for index in actionItems.indices where actionItems[index].label.hasPrefix("Action") {
            let components = actionItems[index].label.split(separator: " ")
            if components.count > 1, let number = Int(components[1]), number != expectedNumber {
                actionItems[index].label = "Action \(expectedNumber)"
            } else if components.count == 1 {
                actionItems[index].label = "Action \(expectedNumber)"
            }
            expectedNumber += 1
        }
    }
}

#Preview {
    ContentView()
}
