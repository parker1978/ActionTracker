//
//  ActiveSkillsView.swift
//  ActionTracker
//
//  Created by Stephen Parker on 4/27/25.
//

import SwiftUI
import SwiftData
import Observation

struct ActiveSkillsView: View {
    var character: Character
    var experience: Int
    @Binding var showSkillManager: Bool
    @State private var isExpanded: Bool = true // Controls whether skills are shown or hidden
    
    // Create a cache of tagged skills to improve performance
    private var taggedSkills: [(id: String, name: String)] {
        // Combine skills with their type tags
        let blueSkills = character.activeBlueSkills.map { (id: "blue_\($0)", name: $0) }
        let orangeSkills = character.activeOrangeSkills.map { (id: "orange_\($0)", name: $0) }
        let redSkills = character.activeRedSkills.map { (id: "red_\($0)", name: $0) }
        
        return blueSkills + orangeSkills + redSkills
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with title, toggle button and manage button
            HStack {
                Button(action: {
                    withAnimation(.spring(duration: 0.3)) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundColor(.primary)
                        
                        Text("Active Skills:")
                            .font(.headline)
                    }
                }
                .buttonStyle(.plain)
                
                if !isExpanded && !character.allActiveSkills().isEmpty {
                    // When collapsed, show count of active skills
                    Text("\(taggedSkills.count)")
                        .font(.caption)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(.green)
                        )
                        .frame(minWidth: 40)
                }
                
                Spacer()
                
                Button("Manage") {
                    showSkillManager = true
                }
                .buttonStyle(.bordered)
            }
            
            // Only show the skills content when expanded
            if isExpanded {
                // Simple, clean skills display
                if character.allActiveSkills().isEmpty {
                    Text("No active skills for \(character.name)")
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                } else {
                    // LazyVGrid layout for skills with automatic columns
                    let columns = [
                        GridItem(.adaptive(minimum: 80, maximum: 160), spacing: 6)
                    ]
                    
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
                        // Render all skills with their proper color
                        ForEach(taggedSkills, id: \.id) { skill in
                            if skill.id.hasPrefix("blue_") {
                                SkillPill(text: skill.name, color: .skillBlue)
                            } else if skill.id.hasPrefix("orange_") {
                                SkillPill(text: skill.name, color: .skillOrange)
                            } else { // red skills
                                SkillPill(text: skill.name, color: .skillRed)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity) // Ensure the VStack takes full available width
        .background(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

// No longer needed as we're using FlowLayout directly

// Single skill pill
struct SkillPill: View {
    var text: String
    var color: Color
    
    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundColor(.white)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .center)
            .background(
                Capsule()
                    .fill(color)
            )
    }
}

// Flow layout to handle multiple lines of skill pills
struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let containerWidth = proposal.width ?? .infinity
        
        var height: CGFloat = 0
        var width: CGFloat = 0
        var lineHeight: CGFloat = 0
        var lineWidth: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if lineWidth + size.width > containerWidth {
                // Start a new line
                width = max(width, lineWidth)
                height += lineHeight + spacing
                lineWidth = size.width
                lineHeight = size.height
            } else {
                // Add to the current line
                lineWidth += size.width + (lineWidth > 0 ? spacing : 0)
                lineHeight = max(lineHeight, size.height)
            }
        }
        
        // Account for the last line
        width = max(width, lineWidth)
        height += lineHeight
        
        return CGSize(width: width, height: height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let containerWidth = bounds.width
        
        var lineX: CGFloat = bounds.minX
        var lineY: CGFloat = bounds.minY
        var lineHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            // Check if we need to start a new line
            if lineX + size.width > containerWidth {
                lineX = bounds.minX
                lineY += lineHeight + spacing
                lineHeight = 0
            }
            
            // Place the view
            subview.place(at: CGPoint(x: lineX, y: lineY), proposal: ProposedViewSize(size))
            
            // Update line information
            lineX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
