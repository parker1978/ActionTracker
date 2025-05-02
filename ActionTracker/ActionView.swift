//
//  ActionView.swift
//  ActionTracker
//
//  Created by Stephen Parker on 4/12/25.
//

import SwiftUI
import SwiftData
import TipKit

struct ActionView: View {
    // Central app state model
    @EnvironmentObject private var appViewModel: AppViewModel
    @Environment(\.dismiss) var dismiss
    @Binding var actionItems: [ActionItem]
    @Binding var timerIsRunning: Bool
    @State private var showActions: Bool = false
    @State private var trayContinuation: CheckedContinuation<ActionItem?, Never>? = nil
    @State private var addBounce: Bool = false
    @State private var shouldRotate: Bool = false
    @State private var showBulkXPInput: Bool = false
    @State private var bulkXPAmount: String = ""
    @State var duration: String = ""
    
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
            // Header with character selector and available actions counter
            HStack {
                // Character Selection Button
                Button(action: {
                    appViewModel.showCharacterPicker = true
                }) {
                    HStack {
                        if let character = appViewModel.selectedCharacter, character.isFavorite {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                        }
                        Image(systemName: "person.fill")
                        Text(appViewModel.selectedCharacter?.name ?? "Select Character")
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.blue.opacity(0.5), lineWidth: 1)
                    )
                }
                
                Spacer()
                
                Text("Actions Available: \(availableActions)")
                    .font(.headline)
            }
            .padding(.horizontal)
            
            // List showing each action with identity for efficient updates
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
                    // Use id to ensure proper identification for ForEach
                    .id("action_\(index)_\(actionItems[index].label)")
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
            
            // Active Skills Display
            if let character = appViewModel.selectedCharacter {
                ActiveSkillsView(
                    character: character,
                    experience: appViewModel.experience,
                    showSkillManager: $appViewModel.showSkillManager
                )
                .padding(.horizontal)
                .padding(.bottom, 6) // Add space between skills and experience section
            } else {
                // Simple placeholder when no character selected
                VStack(alignment: .leading) {
                    HStack {
                        Text("Active Skills:")
                            .font(.headline)
                        Spacer()
                    }
                    Text("No character selected")
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
                        .padding(.horizontal, 10)
                )
                .padding(.bottom, 6) // Add space between message and experience section
            }
            
            // Experience tracking and controls
            VStack(spacing: 12) {
                // Experience level indicator
                ZStack {
                    // ULTRA banner (only when in ultra mode - experience > 43)
                    if appViewModel.isUltraMode() {
                        // Calculate which Ultra cycle we're in (0-based)
                        let ultraCycle = ((appViewModel.experience - 1) / 43)
                        
                        // First Ultra cycle (ultraCycle = 1) shows just "ULTRA"
                        // Second Ultra cycle (ultraCycle = 2) shows "ULTRA X"
                        // Third Ultra cycle (ultraCycle = 3) shows "ULTRA XX" etc.
                        let xCount = max(0, ultraCycle - 1)  // No X's for first Ultra
                        let ultraText = xCount > 0 ? "ULTRA " + String(repeating: "X", count: xCount) : "ULTRA"
                        
                        Text(ultraText)
                            .font(.system(size: 16, weight: .black))
                            .foregroundColor(.white)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 11)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.red)
                            )
                            .fixedSize(horizontal: true, vertical: false)
                            .frame(minWidth: 80)
                    }
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Level: \(appViewModel.getLevelLabel())")
                                .font(.headline)
                                .foregroundColor(appViewModel.getExperienceColor())
                        }
                        .padding(.horizontal)
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("XP: \(appViewModel.getCurrentBaseLevel())/43")
                                .font(.headline)
                                .foregroundColor(appViewModel.getExperienceColor())
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity) // Ensure same width as skills section
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(appViewModel.getExperienceColor(), lineWidth: 2)
                            .padding(.horizontal, 8)
                    )
                }
                
                // Experience stepper
                HStack {
                    Text("Experience:")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button(action: {
                        bulkXPAmount = ""
                        showBulkXPInput = true
                    }) {
                        Image(systemName: "plus.square.fill")
                            .foregroundColor(appViewModel.getExperienceColor())
                            .font(.system(size: 22))
                    }
                    .padding(.trailing, 4)
                    .systemTrayView($showBulkXPInput) {
                        KeyPadView()
                    }
                    
                    Stepper(value: Binding(
                        get: { appViewModel.experience },
                        set: { appViewModel.updateExperience($0) }
                    ), in: 0...Int.max, step: 1) {
                        Text("\(appViewModel.experience)")
                            .foregroundColor(appViewModel.getExperienceColor())
                            .fontWeight(.bold)
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
        .sheet(isPresented: $appViewModel.showCharacterPicker) {
            CharacterPickerView()
        }
        .sheet(isPresented: $appViewModel.showSkillManager) {
            if let character = appViewModel.selectedCharacter {
                SkillManagerView(
                    character: character,
                    experience: appViewModel.experience
                )
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
            appViewModel.resetExperience()
            
            // Reset all actions to unused state
            for index in actionItems.indices {
                actionItems[index].isUsed = false
            }
            
            // Also clear the selected character
            appViewModel.clearSelectedCharacter()
        }
    }
    
    // Renumber action items to maintain a clean sequence 
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
    
    /// View for keyboard
    @ViewBuilder
    func KeyPadView() -> some View {
        VStack(spacing: 12) {
            HStack {
                Text("Bulk AP")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer(minLength: 0)
                
                Button {
                    withAnimation(.bouncy) {
                        showBulkXPInput = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(Color.gray, Color.primary.opacity(0.1))
                }
            }
            .padding(.bottom, 10)
            
            VStack(spacing: 6) {
                Text(duration.isEmpty ? "0" : duration)
                    .font(.system(size: 60, weight: .black))
                    .contentTransition(.numericText())
                
                Text("Action Points")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            .padding(.vertical, 20)
            
            /// Custom Keypad View
            LazyVGrid(columns: Array(repeating: GridItem(), count: 3), spacing: 15) {
                ForEach(keypadValues) { keyValue in
                    if keyValue.value == 0 {
                        Spacer()
                    }
                    
                    Group {
                        if keyValue.isBack {
                            Image(systemName: keyValue.title)
                        } else {
                            Text(keyValue.title)
                        }
                    }
                    .font(.title2)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .contentShape(.rect)
                    .onTapGesture {
                        withAnimation(.snappy) {
                            if keyValue.isBack {
                                if !duration.isEmpty {
                                    duration.removeLast()
                                }
                            } else if duration.count < 2 {
                                print(duration)
                                duration.append(keyValue.title)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, -15)
            
            Button {
                withAnimation(.bouncy) {
                    if let amount = Int(duration), amount >= 1, amount <= 99 {
                        appViewModel.updateExperience(appViewModel.experience + amount)
                    }
                    duration = ""
                    showBulkXPInput = false
                }
            } label: {
                Text("Continue")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .foregroundStyle(.white)
                    .background(.blue, in: .capsule)
            }
        }
        .padding(20)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppViewModel())
}
