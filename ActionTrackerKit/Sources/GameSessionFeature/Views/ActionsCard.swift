//
//  ActionsCard.swift
//  GameSessionFeature
//
//  Card for managing action tokens during gameplay
//

import SwiftUI
import SwiftData
import CoreDomain

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
