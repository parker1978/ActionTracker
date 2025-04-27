//
//  ActionView.swift
//  ActionTracker
//
//  Created by Stephen Parker on 4/12/25.
//

import SwiftUI
import TipKit

struct ActionView: View {
    @Binding var actionItems: [ActionItem]
    @Binding var timerIsRunning: Bool
    @State private var showActions: Bool = false
    @State private var trayContinuation: CheckedContinuation<ActionItem?, Never>? = nil
    @State private var addBounce: Bool = false
    @State private var shouldRotate: Bool = false
    
    // Experience tracking
    @AppStorage("playerExperience") private var experience: Int = 0
    @AppStorage("ultraRedCount") private var ultraRedCount: Int = 0
    @AppStorage("totalExperienceGained") private var totalExperienceGained: Int = 0
    
    var availableActions: Int {
        actionItems.filter { !$0.isUsed }.count
    }
    
    var actionActions: Int {
        actionItems.filter { $0.label.hasPrefix("Action") }.count
    }
    
    // Helper functions for experience tracking
    
    // Get color based on experience level
    private func getExperienceColor() -> Color {
        // For starting level
        if experience == 0 {
            return .gray
        }
        
        // Determine cycle (1-based) and base level
        let cycle = ((experience - 1) / 43) + 1
        let baseLevel = ((experience - 1) % 43) + 1
        
        // Base colors
        let blueColor = Color(red: 0.0, green: 0.5, blue: 1.0)
        let yellowColor = Color(red: 1.0, green: 0.84, blue: 0.0)
        let orangeColor = Color(red: 1.0, green: 0.6, blue: 0.0)
        let redColor = Color(red: 1.0, green: 0.2, blue: 0.2)
        
        // In Ultra-Red mode (cycle > 1), use more intense colors
        if cycle > 1 {
            // For Ultra-Red cycles, use more vibrant colors with subtle glow effect
            switch baseLevel {
            case 1...6:
                // Ultra-Blue: more vibrant blue
                return Color(red: 0.1, green: 0.4, blue: 1.0)
            case 7...18:
                // Ultra-Yellow: more vibrant yellow/gold
                return Color(red: 1.0, green: 0.85, blue: 0.2)
            case 19...42:
                // Ultra-Orange: more vibrant orange
                return Color(red: 1.0, green: 0.5, blue: 0.0)
            case 43:
                // Ultra-Red: bright crimson red
                return Color(red: 0.85, green: 0.0, blue: 0.0)
            default:
                return .gray
            }
        } else {
            // Standard colors for first cycle
            switch baseLevel {
            case 1...6:
                return blueColor
            case 7...18:
                return yellowColor
            case 19...42:
                return orangeColor
            case 43:
                return redColor
            default:
                return .gray
            }
        }
    }
    
    // Get level label based on experience
    private func getLevelLabel() -> String {
        if experience == 0 {
            return "Novice"
        }
        
        // Calculate which cycle we're in (0-based)
        let baseLevel = experience == 0 ? 0 : ((experience - 1) % 43) + 1
        
        // Determine level name based only on the base level
        switch baseLevel {
        case 1...6:
            return "Blue"
        case 7...18:
            return "Yellow"
        case 19...42:
            return "Orange"
        case 43:
            return "Red"
        default:
            return "Novice"
        }
    }
    
    // Check if in ultra-red mode (beyond first level 43)
    private func isUltraMode() -> Bool {
        return experience > 43
    }
    
    // Get the current base level (1-43)
    private func getCurrentBaseLevel() -> Int {
        if experience == 0 {
            return 0
        }
        return ((experience - 1) % 43) + 1
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
                Spacer()
                
                Text("Actions Available: \(availableActions)")
                    .font(.headline)
            }
            .padding(.horizontal)
            
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
            
            // Experience tracking and controls
            VStack(spacing: 12) {
                // ULTRA banner (only when in ultra mode - experience > 43)
                if experience > 43 {
                    // Calculate which Ultra cycle we're in (0-based)
                    let ultraCycle = ((experience - 1) / 43)
                    
                    // First Ultra cycle (ultraCycle = 1) shows just "ULTRA"
                    // Second Ultra cycle (ultraCycle = 2) shows "ULTRA X"
                    // Third Ultra cycle (ultraCycle = 3) shows "ULTRA XX" etc.
                    let xCount = max(0, ultraCycle - 1)  // No X's for first Ultra
                    let ultraText = xCount > 0 ? "ULTRA " + String(repeating: "X", count: xCount) : "ULTRA"
                    
                    Text(ultraText)
                        .font(.system(size: 16, weight: .black))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.red)
                        )
                        .padding(.horizontal, 8)
                }
                
                // Experience level indicator
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Level: \(getLevelLabel())")
                            .font(.headline)
                            .foregroundColor(getExperienceColor())
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("XP: \(getCurrentBaseLevel())/43")
                            .font(.headline)
                            .foregroundColor(getExperienceColor())
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(getExperienceColor(), lineWidth: 2)
                        .padding(.horizontal, 8)
                )
                
                // Experience stepper
                HStack {
                    Text("Experience:")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Stepper(value: $experience, in: 0...Int.max, step: 1) {
                        Text("\(experience)")
                            .foregroundColor(getExperienceColor())
                            .fontWeight(.bold)
                    }
                    .onChange(of: experience) { oldValue, newValue in
                        // Track total experience gained
                        if newValue > oldValue {
                            totalExperienceGained += (newValue - oldValue)
                        }
                        
                        // Handle level transitions - base level calculation is crucial
                        let oldBaseLevel = oldValue == 0 ? 0 : ((oldValue - 1) % 43) + 1
                        let newBaseLevel = newValue == 0 ? 0 : ((newValue - 1) % 43) + 1
                        
                        // When base level goes from 43 to something higher (which would wrap to 1+)
                        if oldBaseLevel == 43 && newBaseLevel < oldBaseLevel && newValue > oldValue {
                            // We've gone past level 43 - increment ultra count
                            ultraRedCount += 1
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Button controls
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
        }
        .systemTrayView($showActions) {
            TrayView { selectedAction in
                trayContinuation?.resume(returning: selectedAction)
                trayContinuation = nil
                showActions = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ResetExperience"))) { _ in
            // Reset all experience tracking when notification is received
            experience = 0
            ultraRedCount = 0
            totalExperienceGained = 0
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
