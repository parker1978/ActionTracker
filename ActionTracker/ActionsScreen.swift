//
//  ActionsScreen.swift
//  ZombiTrack
//
//  Created by Stephen Parker on 6/6/25.
//
//  This file contains the main Actions screen which displays the active game session,
//  including action tracking, experience management, timer, and game controls.
//

import SwiftUI
import SwiftData

// MARK: - Main Actions Screen

/// Main screen for the Actions tab
/// Displays either a "start game" view or the active game session
struct ActionsScreen: View {
    var weaponsManager: WeaponsManager
    @Environment(\.modelContext) private var modelContext

    // Query for active (non-ended) game sessions
    @Query(filter: #Predicate<GameSession> { $0.endedAt == nil }, sort: \GameSession.startedAt, order: .reverse)
    private var activeSessions: [GameSession]

    @Query private var allCharacters: [Character]
    @State private var showingCharacterPicker = false

    var body: some View {
        NavigationStack {
            if let session = activeSessions.first {
                // Show active game
                ActiveGameView(session: session, weaponsManager: weaponsManager)
            } else {
                // Show "start game" view
                StartGameView(showingCharacterPicker: $showingCharacterPicker)
            }
        }
        .sheet(isPresented: $showingCharacterPicker) {
            CharacterPickerSheet(isPresented: $showingCharacterPicker)
        }
    }
}

// MARK: - Start Game View

/// View displayed when no active game session exists
/// Prompts the user to select a character to begin tracking
struct StartGameView: View {
    @Binding var showingCharacterPicker: Bool

    var body: some View {
        ContentUnavailableView {
            Label("No Active Game", systemImage: "gamecontroller")
        } description: {
            Text("Select a character to start tracking")
        } actions: {
            Button {
                showingCharacterPicker = true
            } label: {
                Text("Select Character")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
        }
        .navigationTitle("Actions")
    }
}

// MARK: - Active Game View

/// Main game tracking view displayed during an active session
/// Contains character info, actions, experience tracking, timer, and end game button
struct ActiveGameView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var session: GameSession
    var weaponsManager: WeaponsManager

    // Timer state
    @State private var timer: Timer?
    @State private var isTimerRunning = true

    // UI state
    @State private var showingEndConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Character information card
                CharacterInfoCard(session: session)

                // Health tracking card
                HealthCard(session: session)

                // Action tracking card (with edit mode for deletion)
                ActionsCard(session: session)

                // Inventory card (weapons)
                InventoryCard(session: session, weaponsManager: weaponsManager)

                // Experience and skill tracking card
                ExperienceCard(session: session)

                // Game duration timer card
                TimerCard(session: session, isRunning: $isTimerRunning, onToggle: toggleTimer)

                // End game button with confirmation
                Button(role: .destructive) {
                    showingEndConfirmation = true
                } label: {
                    Label("End Game", systemImage: "stop.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.red)
                }
                .padding(.top)
            }
            .padding()
        }
        .navigationTitle("Actions")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
        .alert("End Game?", isPresented: $showingEndConfirmation) {
            Button("End Game", role: .destructive) {
                endGame()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to end this game session?")
        }
    }

    // MARK: - Timer Functions

    /// Starts the game timer, incrementing elapsed seconds every second
    private func startTimer() {
        guard timer == nil else { return }
        isTimerRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            session.elapsedSeconds += 1
        }
    }

    /// Stops the game timer
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        isTimerRunning = false
    }

    /// Toggles the timer between running and paused states
    private func toggleTimer() {
        if isTimerRunning {
            stopTimer()
        } else {
            startTimer()
        }
    }

    /// Ends the current game session by setting endedAt timestamp
    private func endGame() {
        stopTimer()
        session.endedAt = Date()
        try? modelContext.save()
    }
}

// MARK: - Character Info Card

/// Card displaying basic character information during an active game
struct CharacterInfoCard: View {
    let session: GameSession

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(session.characterName)
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                // Link to full character details
                if let character = session.character {
                    NavigationLink {
                        CharacterDetailView(character: character)
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.title3)
                    }
                }
            }

            // Display character set if available
            if let character = session.character, !character.set.isEmpty {
                HStack {
                    Text(character.set)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Health Card

/// Card for tracking character health during gameplay
/// Health starts at character's base health value and can be incremented/decremented
/// Minimum health: 0, Maximum health: 10
struct HealthCard: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var session: GameSession

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Label("Health", systemImage: "heart.fill")
                    .font(.headline)
                    .foregroundStyle(.red)

                Spacer()
            }

            // Health counter with increment/decrement buttons
            HStack(spacing: 20) {
                // Decrement button
                Button {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        if session.currentHealth > 0 {
                            session.currentHealth -= 1
                        }
                        try? modelContext.save()
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title)
                        .foregroundStyle(session.currentHealth > 0 ? .red : .gray)
                }
                .disabled(session.currentHealth <= 0)

                // Health display
                VStack(spacing: 4) {
                    Text("\(session.currentHealth)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .frame(minWidth: 100)
                        .foregroundStyle(.red)

                    // Health bar indicator
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background bar
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 8)

                            // Filled portion based on current health
                            RoundedRectangle(cornerRadius: 4)
                                .fill(healthBarColor)
                                .frame(width: geometry.size.width * CGFloat(session.currentHealth) / 10.0, height: 8)
                        }
                    }
                    .frame(height: 8)

                    Text("/ 10")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Increment button
                Button {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        if session.currentHealth < 10 {
                            session.currentHealth += 1
                        }
                        try? modelContext.save()
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title)
                        .foregroundStyle(session.currentHealth < 10 ? .red : .gray)
                }
                .disabled(session.currentHealth >= 10)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    /// Color for health bar based on current health percentage
    private var healthBarColor: Color {
        let percentage = Double(session.currentHealth) / 10.0
        if percentage > 0.5 {
            return .green
        } else if percentage > 0.25 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Timer Card

/// Card displaying game duration with pause/resume controls
struct TimerCard: View {
    let session: GameSession
    @Binding var isRunning: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Label("Game Duration", systemImage: "clock")
                    .font(.headline)

                Spacer()

                // Pause/Resume button
                Button {
                    onToggle()
                } label: {
                    Image(systemName: isRunning ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(isRunning ? .orange : .green)
                }
            }

            // Large formatted time display
            Text(session.formattedDuration)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Actions Card

/// Card for managing action tokens during gameplay
/// Supports adding, using, removing, and resetting actions
/// Features an edit mode for deleting non-default actions
struct ActionsCard: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var session: GameSession

    @State private var showingAddAction = false
    @State private var isEditMode = false

    var body: some View {
        VStack(spacing: 16) {
            // MARK: Header with Edit Button
            HStack {
                Label("Actions", systemImage: "bolt.fill")
                    .font(.headline)

                Spacer()

                // Action counter (remaining / total)
                Text("\(session.remainingActions)/\(session.totalActions)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)

                // Edit/Done button for removing actions
                Button {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        isEditMode.toggle()
                    }
                } label: {
                    Text(isEditMode ? "Done" : "Edit")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .buttonStyle(.bordered)
                .tint(isEditMode ? .green : .blue)
            }

            // MARK: Action Types Display
            if session.actionsByType.isEmpty {
                Text("No actions available")
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                VStack(spacing: 12) {
                    ForEach(session.actionsByType, id: \.type) { actionGroup in
                        ActionTypeRow(
                            session: session,
                            actionType: actionGroup.type,
                            isEditMode: isEditMode
                        )
                    }
                }
                .animation(nil, value: session.actionsByType.map { $0.type })
            }

            // MARK: Action Buttons
            HStack(spacing: 12) {
                // Add Action button
                Button {
                    showingAddAction = true
                } label: {
                    Label("Add Action", systemImage: "plus.circle")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Reset Turn button (marks all actions as unused)
                Button {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        session.resetTurn()
                        try? modelContext.save()
                    }
                } label: {
                    Label("Reset Turn", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.green.opacity(0.1))
                        .foregroundStyle(.green)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .font(.subheadline)
            .fontWeight(.semibold)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .animation(nil, value: session.actions.count)
        .sheet(isPresented: $showingAddAction) {
            AddActionSheet(session: session, isPresented: $showingAddAction)
        }
    }
}

// MARK: - Action Type Row

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

// MARK: - Action Token

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

// MARK: - Shake Effect

/// View modifier that creates a smooth horizontal shake animation
/// Used to indicate deletable action tokens in edit mode
struct ShakeEffect: ViewModifier {
    let isShaking: Bool
    @State private var offset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            // Apply repeating animation when shaking, default animation when stopping
            .animation(isShaking ? .easeInOut(duration: 0.1).repeatForever(autoreverses: true) : .default, value: offset)
            .onChange(of: isShaking) { oldValue, newValue in
                if newValue {
                    // Start shaking
                    offset = 2
                } else {
                    // Stop shaking
                    offset = 0
                }
            }
            .onAppear {
                if isShaking {
                    offset = 2
                }
            }
    }
}

// MARK: - Flow Layout

/// Custom layout that arranges subviews in a flowing horizontal pattern
/// Similar to CSS flexbox with wrapping enabled
/// Used for arranging action tokens that wrap to new lines as needed
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }

    /// Helper struct that calculates positions for flow layout
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if currentX + size.width > maxWidth && currentX > 0 {
                    // Move to next line
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: currentX, y: currentY))
                currentX += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }

            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

// MARK: - Inventory Card

/// Card for managing character weapon inventory
/// Players self-manage weapons with simple text input
struct InventoryCard: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var session: GameSession
    var weaponsManager: WeaponsManager
    @State private var showingInventorySheet = false
    @State private var showingWeaponDetail = false
    @State private var selectedWeapon: Weapon?

    // Parse weapon names from stored strings
    private var activeWeaponsList: [String] {
        InventoryFormatter.parse(session.activeWeapons)
    }

    private var inactiveWeaponsList: [String] {
        InventoryFormatter.parse(session.inactiveWeapons)
    }

    // Helper to find weapon by name
    private func findWeapon(byName name: String) -> Weapon? {
        WeaponRepository.shared.allWeapons.first { $0.name == name }
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Label("Inventory", systemImage: "shield.lefthalf.filled")
                    .font(.headline)

                Spacer()

                // Weapon count
                let totalWeapons = activeWeaponsList.count + inactiveWeaponsList.count
                Text("\(totalWeapons) weapons")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // Manage button
                Button {
                    showingInventorySheet = true
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.title3)
                }
            }

            // Quick Summary
            if activeWeaponsList.isEmpty && inactiveWeaponsList.isEmpty {
                Text("No weapons equipped")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    // Active Weapons
                    if !activeWeaponsList.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "hand.raised.fill")
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                                Text("Active (\(activeWeaponsList.count)/2)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }

                            ForEach(Array(activeWeaponsList.prefix(2).enumerated()), id: \.offset) { _, weaponName in
                                if let weapon = findWeapon(byName: weaponName) {
                                    Button {
                                        selectedWeapon = weapon
                                        showingWeaponDetail = true
                                    } label: {
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                Text(weaponName)
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                                    .foregroundStyle(.primary)
                                                Spacer()
                                                Image(systemName: "info.circle")
                                                    .font(.caption)
                                                    .foregroundStyle(.blue)
                                            }

                                            // Combat stats row
                                            HStack(spacing: 8) {
                                                if weapon.range != nil || weapon.rangeMin != nil {
                                                    HStack(spacing: 2) {
                                                        Image(systemName: "arrow.right")
                                                            .font(.caption2)
                                                        Text(weapon.rangeDisplay)
                                                            .font(.caption2)
                                                    }
                                                    .foregroundStyle(.secondary)
                                                }

                                                if let dice = weapon.dice {
                                                    HStack(spacing: 2) {
                                                        Image(systemName: "dice")
                                                            .font(.caption2)
                                                        Text("\(dice)")
                                                            .font(.caption2)
                                                    }
                                                    .foregroundStyle(.secondary)
                                                }

                                                if let accuracy = weapon.accuracy {
                                                    HStack(spacing: 2) {
                                                        Image(systemName: "target")
                                                            .font(.caption2)
                                                        Text(accuracy)
                                                            .font(.caption2)
                                                    }
                                                    .foregroundStyle(.secondary)
                                                }

                                                if let damage = weapon.damage {
                                                    HStack(spacing: 2) {
                                                        Image(systemName: "bolt.fill")
                                                            .font(.caption2)
                                                        Text("\(damage)")
                                                            .font(.caption2)
                                                    }
                                                    .foregroundStyle(.secondary)
                                                }
                                            }
                                        }
                                        .padding(.vertical, 2)
                                    }
                                }
                            }
                        }
                    }

                    // Inactive Weapons
                    if !inactiveWeaponsList.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "backpack.fill")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                                Text("Backpack (\(inactiveWeaponsList.count)/\(3 + session.extraInventorySlots))")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }

                            ForEach(Array(inactiveWeaponsList.prefix(3).enumerated()), id: \.offset) { _, weaponName in
                                if let weapon = findWeapon(byName: weaponName) {
                                    Button {
                                        selectedWeapon = weapon
                                        showingWeaponDetail = true
                                    } label: {
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                Text(weaponName)
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                                    .foregroundStyle(.primary)
                                                Spacer()
                                                Image(systemName: "info.circle")
                                                    .font(.caption)
                                                    .foregroundStyle(.blue)
                                            }

                                            // Combat stats row
                                            HStack(spacing: 8) {
                                                if weapon.range != nil || weapon.rangeMin != nil {
                                                    HStack(spacing: 2) {
                                                        Image(systemName: "arrow.right")
                                                            .font(.caption2)
                                                        Text(weapon.rangeDisplay)
                                                            .font(.caption2)
                                                    }
                                                    .foregroundStyle(.secondary)
                                                }

                                                if let dice = weapon.dice {
                                                    HStack(spacing: 2) {
                                                        Image(systemName: "dice")
                                                            .font(.caption2)
                                                        Text("\(dice)")
                                                            .font(.caption2)
                                                    }
                                                    .foregroundStyle(.secondary)
                                                }

                                                if let accuracy = weapon.accuracy {
                                                    HStack(spacing: 2) {
                                                        Image(systemName: "target")
                                                            .font(.caption2)
                                                        Text(accuracy)
                                                            .font(.caption2)
                                                    }
                                                    .foregroundStyle(.secondary)
                                                }

                                                if let damage = weapon.damage {
                                                    HStack(spacing: 2) {
                                                        Image(systemName: "bolt.fill")
                                                            .font(.caption2)
                                                        Text("\(damage)")
                                                            .font(.caption2)
                                                    }
                                                    .foregroundStyle(.secondary)
                                                }
                                            }
                                        }
                                        .padding(.vertical, 2)
                                    }
                                }
                            }

                            if inactiveWeaponsList.count > 3 {
                                Button {
                                    showingInventorySheet = true
                                } label: {
                                    Text("+ \(inactiveWeaponsList.count - 3) more...")
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .sheet(isPresented: $showingInventorySheet) {
            InventoryManagementSheet(session: session, weaponsManager: weaponsManager)
        }
        .sheet(isPresented: $showingWeaponDetail) {
            if let weapon = selectedWeapon {
                NavigationStack {
                    ScrollView {
                        WeaponCardView(weapon: weapon)
                            .padding()
                    }
                    .navigationTitle(weapon.name)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") {
                                showingWeaponDetail = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
        }
    }
}

// MARK: - Inventory Management Sheet

struct InventoryManagementSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var session: GameSession
    var weaponsManager: WeaponsManager

    @State private var activeWeapons: [String] = []
    @State private var inactiveWeapons: [String] = []
    @State private var showingAddActiveWeapon = false
    @State private var showingAddInactiveWeapon = false
    @State private var showingWeaponDetail = false
    @State private var selectedWeapon: Weapon?

    // Get all weapon names from repository, excluding zombie cards
    private var allWeaponNames: [String] {
        Array(Set(WeaponRepository.shared.allWeapons
            .filter { !$0.isZombieCard }
            .map { $0.name }))
            .sorted()
    }

    // Helper to find weapon by name
    private func findWeapon(byName name: String) -> Weapon? {
        WeaponRepository.shared.allWeapons.first { $0.name == name }
    }

    var body: some View {
        NavigationStack {
            Form {
                // Active Weapons Section
                Section {
                    if activeWeapons.isEmpty {
                        Text("No active weapons")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(activeWeapons.indices, id: \.self) { index in
                            HStack(spacing: 8) {
                                Image(systemName: "hand.raised.fill")
                                    .foregroundStyle(.blue)
                                    .font(.caption)

                                Text(activeWeapons[index])
                                    .foregroundStyle(.primary)

                                Spacer()

                                Button {
                                    if let weapon = findWeapon(byName: activeWeapons[index]) {
                                        selectedWeapon = weapon
                                        showingWeaponDetail = true
                                    }
                                } label: {
                                    Image(systemName: "info.circle")
                                        .font(.body)
                                        .foregroundStyle(.blue)
                                }
                                .buttonStyle(.borderless)

                                Button(role: .destructive) {
                                    let weaponName = activeWeapons[index]
                                    // Find weapon and discard to appropriate deck
                                    if let weapon = WeaponRepository.shared.allWeapons.first(where: { $0.name == weaponName }) {
                                        weaponsManager.getDeck(weapon.deck).discardCard(weapon)
                                    }
                                    activeWeapons.remove(at: index)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.body)
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }

                    Button {
                        showingAddActiveWeapon = true
                    } label: {
                        Label("Add Weapon", systemImage: "plus.circle")
                    }
                    .disabled(activeWeapons.count >= 2)

                    Text("Capacity: \(activeWeapons.count)/2 slots")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Label("Active Weapons (Hands)", systemImage: "hand.raised.fill")
                }

                // Inactive Weapons Section
                Section {
                    if inactiveWeapons.isEmpty {
                        Text("No inactive weapons")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(inactiveWeapons.indices, id: \.self) { index in
                            HStack(spacing: 8) {
                                Image(systemName: "backpack.fill")
                                    .foregroundStyle(.orange)
                                    .font(.caption)

                                Text(inactiveWeapons[index])
                                    .foregroundStyle(.primary)

                                Spacer()

                                Button {
                                    if let weapon = findWeapon(byName: inactiveWeapons[index]) {
                                        selectedWeapon = weapon
                                        showingWeaponDetail = true
                                    }
                                } label: {
                                    Image(systemName: "info.circle")
                                        .font(.body)
                                        .foregroundStyle(.blue)
                                }
                                .buttonStyle(.borderless)

                                Button(role: .destructive) {
                                    let weaponName = inactiveWeapons[index]
                                    // Find weapon and discard to appropriate deck
                                    if let weapon = WeaponRepository.shared.allWeapons.first(where: { $0.name == weaponName }) {
                                        weaponsManager.getDeck(weapon.deck).discardCard(weapon)
                                    }
                                    inactiveWeapons.remove(at: index)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.body)
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }

                    Button {
                        showingAddInactiveWeapon = true
                    } label: {
                        Label("Add Weapon", systemImage: "plus.circle")
                    }
                    .disabled(inactiveWeapons.count >= (3 + session.extraInventorySlots))

                    HStack {
                        Text("Capacity: \(inactiveWeapons.count)/\(3 + session.extraInventorySlots) slots")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Stepper("Bonus: \(session.extraInventorySlots)", value: $session.extraInventorySlots, in: 0...10)
                            .font(.caption)
                    }
                } header: {
                    Label("Inactive Weapons (Backpack)", systemImage: "backpack.fill")
                }

                // Modifiers Section
                Section {
                    Toggle("All Inventory Counts as Active", isOn: $session.allInventoryActive)
                } header: {
                    Text("Modifiers")
                } footer: {
                    Text("Enable this if a skill or ability makes all weapons in your inventory count as active.")
                }
            }
            .navigationTitle("Manage Inventory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveInventory()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadInventory()
            }
            .sheet(isPresented: $showingAddActiveWeapon) {
                WeaponPickerSheet(
                    allWeapons: allWeaponNames,
                    selectedWeapons: $activeWeapons,
                    title: "Add Active Weapon"
                )
            }
            .sheet(isPresented: $showingAddInactiveWeapon) {
                WeaponPickerSheet(
                    allWeapons: allWeaponNames,
                    selectedWeapons: $inactiveWeapons,
                    title: "Add Inactive Weapon"
                )
            }
            .sheet(isPresented: $showingWeaponDetail) {
                if let weapon = selectedWeapon {
                    NavigationStack {
                        ScrollView {
                            WeaponCardView(weapon: weapon)
                                .padding()
                        }
                        .navigationTitle(weapon.name)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") {
                                    showingWeaponDetail = false
                                }
                            }
                        }
                    }
                    .presentationDetents([.medium, .large])
                }
            }
        }
    }

    private func loadInventory() {
        activeWeapons = InventoryFormatter.parse(session.activeWeapons)
        inactiveWeapons = InventoryFormatter.parse(session.inactiveWeapons)
    }

    private func saveInventory() {
        session.activeWeapons = InventoryFormatter.join(activeWeapons)
        session.inactiveWeapons = InventoryFormatter.join(inactiveWeapons)
        try? modelContext.save()
    }
}

// MARK: - Weapon Picker Sheet

struct WeaponPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let allWeapons: [String]
    @Binding var selectedWeapons: [String]
    let title: String

    @State private var searchText = ""

    private var filteredWeapons: [String] {
        if searchText.isEmpty {
            return allWeapons
        } else {
            return allWeapons.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredWeapons, id: \.self) { weapon in
                    Button {
                        selectedWeapons.append(weapon)
                        dismiss()
                    } label: {
                        HStack {
                            Text(weapon)
                                .foregroundStyle(.primary)

                            Spacer()

                            if selectedWeapons.contains(weapon) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search weapons")
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Add Action Sheet

/// Sheet for selecting a new action type to add to the character's pool
struct AddActionSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var session: GameSession
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(ActionType.allCases, id: \.self) { type in
                        Button {
                            var transaction = Transaction()
                            transaction.disablesAnimations = true
                            withTransaction(transaction) {
                                session.addAction(ofType: type)
                                try? modelContext.save()
                            }
                            isPresented = false
                        } label: {
                            HStack {
                                Image(systemName: type.icon)
                                    .font(.title3)
                                    .foregroundStyle(type.color)
                                    .frame(width: 30)

                                Text(type.displayName)
                                    .foregroundStyle(.primary)

                                Spacer()

                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(type.color)
                            }
                        }
                    }
                } header: {
                    Text("Select Action Type")
                }
            }
            .navigationTitle("Add Action")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

// MARK: - Experience Card

/// Card for tracking and managing character experience (XP) and skills
/// Displays current XP, cycle information, skill levels, and active skills
/// Handles automatic skill selection at XP milestones
struct ExperienceCard: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var session: GameSession
    @State private var showingSkillSelection = false

    var body: some View {
        VStack(spacing: 16) {
            // MARK: Header with Cycle Indicator
            HStack {
                Label("Experience", systemImage: "star.fill")
                    .font(.headline)

                Spacer()

                // Show cycle number if in cycle 2 or 3
                if session.xpCycle > 1 {
                    Text("Cycle \(session.xpCycle)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.orange.opacity(0.2))
                        .foregroundStyle(.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }

            // MARK: XP Counter
            HStack(spacing: 20) {
                // Decrement button
                Button {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        if session.currentExperience > 0 {
                            session.currentExperience -= 1
                        }
                        try? modelContext.save()
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(session.currentExperience > 0 ? .orange : .gray)
                }
                .disabled(session.currentExperience <= 0)

                // XP display with cycle position
                VStack(spacing: 4) {
                    Text("\(session.currentExperience)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .frame(minWidth: 80)

                    Text("(\(session.displayNormalizedXP) in cycle)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // Increment button
                Button {
                    let previousXP = session.currentExperience
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        session.currentExperience += 1

                        // Auto-add action when reaching Yellow (XP 7)
                        if previousXP < 7 && session.currentExperience >= 7 {
                            session.addAction(ofType: .action)
                        }

                        try? modelContext.save()
                    }
                    // Check if skill selection needed
                    if session.needsSkillSelection() != nil {
                        showingSkillSelection = true
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)
                }
            }

            // MARK: XP Level Indicator
            HStack(spacing: 8) {
                XPLevelBadge(
                    level: "Blue",
                    range: "0-6",
                    isActive: true,
                    color: .blue
                )
                XPLevelBadge(
                    level: "Yellow",
                    range: "7-18",
                    isActive: session.currentExperience >= 7,
                    color: .yellow
                )
                XPLevelBadge(
                    level: "Orange",
                    range: "19-42",
                    isActive: session.currentExperience >= 19,
                    color: .orange
                )
                XPLevelBadge(
                    level: "Red",
                    range: "43+",
                    isActive: session.currentExperience >= 43,
                    color: .red
                )
            }

            // MARK: Active Skills Summary
            if !session.getActiveSkills().isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()

                    HStack {
                        Label("Active Skills", systemImage: "sparkles")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Spacer()

                        // Button to open skill selection sheet
                        Button {
                            showingSkillSelection = true
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.subheadline)
                        }
                    }

                    // List of currently active skills with color coding
                    ForEach(session.getActiveSkills(), id: \.self) { skill in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(skillColor(for: skill).gradient)
                                .frame(width: 6, height: 6)

                            Text(skill)
                                .font(.caption)

                            Spacer()
                        }
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .sheet(isPresented: $showingSkillSelection) {
            SkillSelectionSheet(session: session, isPresented: $showingSkillSelection)
        }
    }

    /// Determines the color for a skill based on its tier
    private func skillColor(for skill: String) -> Color {
        guard let character = session.character else { return .gray }

        if character.blueSkillsList.contains(skill) {
            return .blue
        } else if character.yellowSkillsList.contains(skill) {
            return .yellow
        } else if character.orangeSkillsList.contains(skill) {
            return .orange
        } else if character.redSkillsList.contains(skill) {
            return .red
        }
        return .gray
    }
}

// MARK: - XP Level Badge

/// Badge displaying a skill level tier (Blue, Yellow, Orange, or Red)
/// Shows the level name, XP range, and highlights when active
struct XPLevelBadge: View {
    let level: String
    let range: String
    let isActive: Bool
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(level)
                .font(.caption2)
                .fontWeight(.semibold)
            Text(range)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            isActive ? color.opacity(0.2) : Color.clear,
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isActive ? color : .gray.opacity(0.3), lineWidth: 2)
        )
    }
}

// MARK: - Skill Selection Sheet

/// Sheet for viewing and selecting character skills at various XP thresholds
/// Displays all skill tiers with selection controls based on current XP cycle
struct SkillSelectionSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var session: GameSession
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // MARK: Current XP Info
                    VStack(spacing: 8) {
                        HStack {
                            Label("Current XP", systemImage: "star.fill")
                                .font(.headline)
                            Spacer()
                            Text("\(session.currentExperience)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .monospacedDigit()
                        }

                        HStack {
                            Text("Cycle \(session.xpCycle)")
                                .font(.subheadline)
                            Spacer()
                            Text("Position: \(session.displayNormalizedXP)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

                    // MARK: Blue Skills (Always Active)
                    if let character = session.character, !character.blueSkillsList.isEmpty {
                        SkillLevelSection(
                            title: "Blue Skills (Always Active)",
                            color: .blue,
                            skills: character.blueSkillsList,
                            selectedSkills: character.blueSkillsList,
                            isSelectable: false,
                            onSelect: { _ in }
                        )
                    }

                    // MARK: Yellow Skills (Auto-selected at XP 7)
                    if let character = session.character, !character.yellowSkillsList.isEmpty {
                        SkillLevelSection(
                            title: "Yellow Skills (Active at 7+ XP)",
                            color: .yellow,
                            skills: character.yellowSkillsList,
                            selectedSkills: session.normalizedXP >= 7 ? [session.selectedYellowSkill] : [],
                            isSelectable: false,
                            onSelect: { _ in }
                        )
                    }

                    // MARK: Orange Skills (Choose 1 in Cycle 1, gain 2nd in Cycle 2)
                    if let character = session.character, !character.orangeSkillsList.isEmpty {
                        let availableSkills = character.orangeSkillsList
                        let selectedSkills = session.selectedOrangeSkillsList
                        let canSelect = session.normalizedXP >= 19 && session.xpCycle == 1

                        SkillLevelSection(
                            title: orangeSkillTitle,
                            color: .orange,
                            skills: availableSkills,
                            selectedSkills: selectedSkills,
                            isSelectable: canSelect,
                            onSelect: { skill in
                                var transaction = Transaction()
                                transaction.disablesAnimations = true
                                withTransaction(transaction) {
                                    // Replace selection (only 1 allowed in cycle 1)
                                    session.selectedOrangeSkills = skill
                                    try? modelContext.save()
                                }
                            }
                        )
                    }

                    // MARK: Red Skills (Choose 1 in Cycle 1, 2nd in Cycle 2, gain 3rd in Cycle 3)
                    if let character = session.character, !character.redSkillsList.isEmpty {
                        let availableSkills = character.redSkillsList
                        let selectedSkills = session.selectedRedSkillsList
                        let maxSelections = session.xpCycle == 1 ? 1 : 2
                        let canSelect = session.currentExperience >= 43

                        SkillLevelSection(
                            title: redSkillTitle,
                            color: .red,
                            skills: availableSkills,
                            selectedSkills: selectedSkills,
                            isSelectable: canSelect,
                            maxSelections: maxSelections,
                            onSelect: { skill in
                                var transaction = Transaction()
                                transaction.disablesAnimations = true
                                withTransaction(transaction) {
                                    var currentSelections = session.selectedRedSkillsList

                                    if maxSelections == 1 {
                                        // Cycle 1: Replace selection (like orange)
                                        session.selectedRedSkills = skill
                                    } else {
                                        // Cycle 2+: Toggle selection
                                        if currentSelections.contains(skill) {
                                            // Deselect
                                            currentSelections.removeAll { $0 == skill }
                                        } else if currentSelections.count < maxSelections {
                                            // Add selection
                                            currentSelections.append(skill)
                                        }
                                        session.selectedRedSkills = currentSelections.joined(separator: ";")
                                    }

                                    try? modelContext.save()
                                }
                            }
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Skills")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }

    /// Generates appropriate title for orange skills based on cycle
    private var orangeSkillTitle: String {
        let cycle = session.xpCycle
        let selected = session.selectedOrangeSkillsList.count

        if cycle == 1 {
            return "Orange Skills (Choose 1 at 19+ XP)"
        } else if cycle == 2 && selected < 2 {
            return "Orange Skills (Gain Remaining)"
        } else {
            return "Orange Skills (Active at 19+ XP)"
        }
    }

    /// Generates appropriate title for red skills based on cycle
    private var redSkillTitle: String {
        let cycle = session.xpCycle
        let selected = session.selectedRedSkillsList.count

        if cycle == 1 {
            return "Red Skills (Choose 1 at 43+ XP)"
        } else if cycle == 2 && selected < 2 {
            return "Red Skills (Choose 2nd)"
        } else if cycle == 3 && selected < 3 {
            return "Red Skills (Gain Last)"
        } else {
            return "Red Skills (Active at 43+ XP)"
        }
    }
}

// MARK: - Skill Level Section

/// Section displaying skills of a specific tier (Blue, Yellow, Orange, or Red)
/// Handles skill selection logic based on cycle and tier restrictions
struct SkillLevelSection: View {
    let title: String
    let color: Color
    let skills: [String]
    let selectedSkills: [String]
    let isSelectable: Bool
    var maxSelections: Int = 0
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(color)

            VStack(spacing: 8) {
                ForEach(skills, id: \.self) { skill in
                    SkillRow(
                        skill: skill,
                        color: color,
                        isSelected: selectedSkills.contains(skill),
                        isSelectable: isSelectable,
                        canToggle: isSelectable && (maxSelections == 1 || selectedSkills.contains(skill) || selectedSkills.count < maxSelections || maxSelections == 0),
                        onSelect: { onSelect(skill) }
                    )
                }
            }
        }
        .padding()
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Skill Row

/// Individual skill row with selection state and tap handling
struct SkillRow: View {
    let skill: String
    let color: Color
    let isSelected: Bool
    let isSelectable: Bool
    let canToggle: Bool
    let onSelect: () -> Void

    var body: some View {
        Button {
            if canToggle {
                onSelect()
            }
        } label: {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? color : .gray)
                    .font(.title3)

                Text(skill)
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                Spacer()
            }
            .padding()
            .background(
                isSelected ? color.opacity(0.15) : Color(.systemGray6),
                in: RoundedRectangle(cornerRadius: 8)
            )
        }
        .disabled(!canToggle)
        .opacity(canToggle || isSelected ? 1.0 : 0.6)
    }
}

// MARK: - Character Picker Sheet

/// Sheet for selecting a character to start a new game session
struct CharacterPickerSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allCharacters: [Character]
    @Binding var isPresented: Bool

    /// Characters sorted with favorites first, then alphabetically
    var sortedCharacters: [Character] {
        allCharacters.sorted {
            if $0.isFavorite == $1.isFavorite {
                return $0.name < $1.name
            }
            return $0.isFavorite && !$1.isFavorite
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(sortedCharacters) { character in
                    Button {
                        startGame(with: character)
                    } label: {
                        CharacterRow(character: character)
                    }
                }
            }
            .navigationTitle("Select Character")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }

    /// Creates and starts a new game session with the selected character
    private func startGame(with character: Character) {
        let session = GameSession(character: character)
        modelContext.insert(session)
        try? modelContext.save()
        isPresented = false
    }
}
