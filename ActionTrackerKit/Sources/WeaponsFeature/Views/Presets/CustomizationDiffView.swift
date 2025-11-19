//
//  CustomizationDiffView.swift
//  WeaponsFeature
//
//  Shows customization differences from default with simple indicators
//

import SwiftUI
import CoreDomain

public struct CustomizationDiffView: View {
    let diffs: [CustomizationService.CustomizationDiff]

    // Group diffs by expansion set
    private var groupedDiffs: [String: [CustomizationService.CustomizationDiff]] {
        Dictionary(grouping: diffs, by: { $0.weaponSet })
    }

    private var sortedSets: [String] {
        groupedDiffs.keys.sorted()
    }

    public init(diffs: [CustomizationService.CustomizationDiff]) {
        self.diffs = diffs
    }

    public var body: some View {
        List {
            if diffs.isEmpty {
                ContentUnavailableView(
                    "No Customizations",
                    systemImage: "checkmark.circle",
                    description: Text("This preset uses all default settings")
                )
            } else {
                ForEach(sortedSets, id: \.self) { set in
                    Section(set) {
                        ForEach(groupedDiffs[set] ?? [], id: \.weaponName) { diff in
                            DiffRow(diff: diff)
                        }
                    }
                }
            }
        }
        .navigationTitle("Customizations")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Diff Row

private struct DiffRow: View {
    let diff: CustomizationService.CustomizationDiff

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(diff.weaponName)
                    .font(.headline)

                HStack(spacing: 8) {
                    // Status badge
                    statusBadge

                    // Count change indicator
                    if case .countChanged = diff.type,
                       let customCount = diff.customCount {
                        countBadge(default: diff.defaultCount, custom: customCount)
                    }
                }
            }

            Spacer()
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch diff.type {
        case .disabled:
            HStack(spacing: 4) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                Text("Disabled")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.red.opacity(0.1))
            .clipShape(Capsule())

        case .enabled:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Enabled")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.green.opacity(0.1))
            .clipShape(Capsule())

        case .countChanged:
            if !diff.isEnabled {
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                    Text("Disabled")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.red.opacity(0.1))
                .clipShape(Capsule())
            }
        }
    }

    private func countBadge(default defaultCount: Int, custom customCount: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "number.circle.fill")
                .foregroundStyle(.blue)
            Text("\(defaultCount) → \(customCount)")
                .font(.caption)
                .foregroundStyle(.blue)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.blue.opacity(0.1))
        .clipShape(Capsule())
    }
}

#Preview {
    NavigationStack {
        CustomizationDiffView(diffs: [
            CustomizationService.CustomizationDiff(
                weaponName: "Pistol",
                weaponSet: "Core",
                type: .disabled,
                defaultCount: 3,
                customCount: nil,
                isEnabled: false
            ),
            CustomizationService.CustomizationDiff(
                weaponName: "Chainsaw",
                weaponSet: "Fort Hendrix",
                type: .countChanged,
                defaultCount: 2,
                customCount: 5,
                isEnabled: true
            ),
            CustomizationService.CustomizationDiff(
                weaponName: "Shotgun",
                weaponSet: "Core",
                type: .enabled,
                defaultCount: 2,
                customCount: nil,
                isEnabled: true
            )
        ])
    }
}
