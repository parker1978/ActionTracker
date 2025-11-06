//
//  SpawnCardView.swift
//  SpawnDeckFeature
//
//  Displays a single spawn card with difficulty levels and spawn counts
//

import SwiftUI
import CoreDomain
import SharedUI

public struct SpawnCardView: View {
    let card: SpawnCard

    public init(card: SpawnCard) {
        self.card = card
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Card Header
            cardHeader

            // Spawn Counts - round bottom corners only if there's no note
            spawnCounts

            // Note Section - only show if there's a note
            if !card.note.isEmpty {
                noteSection
            }
        }
        .frame(maxWidth: .infinity, minHeight: 450, maxHeight: 450)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
        .padding(.horizontal, 20)
    }

    // MARK: - Card Header

    private var cardHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(card.type.rawValue.uppercased())
                    .font(card.type == .extraActivation ? .title3 : .title)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                if card.isRush {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.caption)
                        Text("RUSH!")
                            .font(.subheadline)
                            .fontWeight(.bold)
                    }
                    .foregroundStyle(.yellow)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.yellow.opacity(0.25), in: Capsule())
                }
            }

            Spacer()

            Text("#\(card.id)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding()
        .background(card.type == .extraActivation ? Color.red : Color.black)
        .cornerRadius(16, corners: [.topLeft, .topRight])
    }

    // MARK: - Spawn Counts

    private var spawnCounts: some View {
        VStack(spacing: 16) {
            difficultyRow(level: .blue, count: card.spawnCount(for: .blue), isExtraActivation: card.type == .extraActivation)
            difficultyRow(level: .yellow, count: card.spawnCount(for: .yellow), isExtraActivation: card.type == .extraActivation)
            difficultyRow(level: .orange, count: card.spawnCount(for: .orange), isExtraActivation: card.type == .extraActivation)
            difficultyRow(level: .red, count: card.spawnCount(for: .red), isExtraActivation: card.type == .extraActivation)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.white)
        .if(card.note.isEmpty) { view in
            view.cornerRadius(16, corners: [.bottomLeft, .bottomRight])
        }
    }

    // MARK: - Note Section

    private var noteSection: some View {
        Text(card.note)
            .font(.callout)
            .fontWeight(.semibold)
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(card.isRush ? Color.yellow : Color.yellow.opacity(0.3))
            .cornerRadius(16, corners: [.bottomLeft, .bottomRight])
    }

    // MARK: - Difficulty Row

    private func difficultyRow(level: DifficultyLevel, count: String, isExtraActivation: Bool) -> some View {
        HStack(spacing: 12) {
            // Color indicator with icon
            ZStack {
                Circle()
                    .fill(level.color)
                    .frame(width: 40, height: 40)

                Image(systemName: "figure.walk")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
            }

            Text(level.displayName)
                .font(.headline)
                .foregroundStyle(.primary)
                .frame(width: 80, alignment: .leading)

            Spacer()

            // Spawn count - smaller text for Extra Activation
            Text(count)
                .font(isExtraActivation ? .system(size: 20, weight: .bold, design: .rounded) : .system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(level.color)
                .frame(minWidth: 60, alignment: .trailing)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SpawnCardView(card: SpawnCard(
        id: "001",
        type: .walkers,
        isRush: false,
        blue: 1,
        yellow: 2,
        orange: 4,
        red: 6,
        note: ""
    ))
}
