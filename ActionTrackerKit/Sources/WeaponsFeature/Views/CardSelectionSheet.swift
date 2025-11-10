import SwiftUI
import CoreDomain
import DataLayer
import SharedUI

/// Sheet view for selecting which cards from a set are enabled/disabled
public struct CardSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var disabledCardsManager: DisabledCardsManager

    let setName: String
    let onDismiss: () -> Void

    @State private var selectedWeapon: Weapon?
    @State private var expandedDeckTypes: Set<DeckType> = [.starting, .regular, .ultrared]

    public init(
        setName: String,
        disabledCardsManager: DisabledCardsManager,
        onDismiss: @escaping () -> Void
    ) {
        self.setName = setName
        self.disabledCardsManager = disabledCardsManager
        self.onDismiss = onDismiss
    }

    // Get all weapons for this set from repository
    private var weaponsInSet: [Weapon] {
        WeaponRepository.shared.allWeapons.filter { $0.expansion == setName }
    }

    // Group weapons by deck type
    private func weapons(for deckType: DeckType) -> [Weapon] {
        weaponsInSet
            .filter { $0.deck == deckType }
            .sorted { $0.name < $1.name }  // Alphabetical sort
    }

    // Check if all weapons in a deck type are enabled
    private func areAllEnabled(for deckType: DeckType) -> Bool {
        let weaponsInDeckType = weapons(for: deckType)
        return weaponsInDeckType.allSatisfy { weapon in
            !disabledCardsManager.isCardDisabled(weapon.name, in: setName)
        }
    }

    // Check if all weapons in a deck type are disabled
    private func areAllDisabled(for deckType: DeckType) -> Bool {
        let weaponsInDeckType = weapons(for: deckType)
        return weaponsInDeckType.allSatisfy { weapon in
            disabledCardsManager.isCardDisabled(weapon.name, in: setName)
        }
    }

    public var body: some View {
        NavigationStack {
            List {
                // Show deck types in order: Starting, Regular, Ultrared
                ForEach([DeckType.starting, .regular, .ultrared], id: \.self) { deckType in
                    let weaponsInDeckType = weapons(for: deckType)

                    if !weaponsInDeckType.isEmpty {
                        Section {
                            DisclosureGroup(
                                isExpanded: Binding(
                                    get: { expandedDeckTypes.contains(deckType) },
                                    set: { isExpanded in
                                        if isExpanded {
                                            expandedDeckTypes.insert(deckType)
                                        } else {
                                            expandedDeckTypes.remove(deckType)
                                        }
                                    }
                                )
                            ) {
                                ForEach(weaponsInDeckType) { weapon in
                                    cardRow(for: weapon)
                                }
                            } label: {
                                HStack {
                                    // Deck type badge
                                    Text(deckType.displayName)
                                        .font(.headline)
                                        .foregroundStyle(deckType.color)

                                    Spacer()

                                    // Card count
                                    Text("\(weaponsInDeckType.count) cards")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } header: {
                            // Deck type section with Select All / Deselect All buttons
                            HStack {
                                Text(deckType.displayName.uppercased())
                                    .font(.caption)

                                Spacer()

                                HStack(spacing: 12) {
                                    if !areAllEnabled(for: deckType) {
                                        Button("Select All") {
                                            disabledCardsManager.setCards(
                                                enabled: true,
                                                for: deckType,
                                                in: setName,
                                                weapons: weaponsInSet
                                            )
                                        }
                                        .font(.caption)
                                        .buttonStyle(.plain)
                                    }

                                    if !areAllDisabled(for: deckType) {
                                        Button("Deselect All") {
                                            disabledCardsManager.setCards(
                                                enabled: false,
                                                for: deckType,
                                                in: setName,
                                                weapons: weaponsInSet
                                            )
                                        }
                                        .font(.caption)
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(setName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDismiss()
                        dismiss()
                    }
                }
            }
            .sheet(item: $selectedWeapon) { weapon in
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
                                selectedWeapon = nil
                            }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: - Card Row

    @ViewBuilder
    private func cardRow(for weapon: Weapon) -> some View {
        HStack(spacing: 12) {
            // Card info
            VStack(alignment: .leading, spacing: 4) {
                Text(weapon.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                // Deck type badge
                Text(weapon.deck.displayName)
                    .font(.caption2)
                    .foregroundStyle(weapon.deck.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(weapon.deck.color.opacity(0.15))
                    .cornerRadius(4)
            }

            Spacer()

            // View Card button
            Button {
                selectedWeapon = weapon
            } label: {
                Text("View Card")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)

            // Enable/Disable toggle
            Toggle(
                isOn: Binding(
                    get: {
                        !disabledCardsManager.isCardDisabled(weapon.name, in: setName)
                    },
                    set: { isEnabled in
                        if isEnabled {
                            disabledCardsManager.enableCard(weapon.name, in: setName)
                        } else {
                            disabledCardsManager.disableCard(weapon.name, in: setName)
                        }
                    }
                )
            ) {
                EmptyView()
            }
            .labelsHidden()
        }
    }
}
