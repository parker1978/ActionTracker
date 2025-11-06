//
//  RoundedCorner.swift
//  SharedUI
//
//  Custom shape for selective corner rounding.
//  Allows rounding specific corners of a view.
//

import SwiftUI

#if canImport(UIKit)
import UIKit

/// Custom shape for selective corner rounding
/// Allows rounding specific corners of a view (e.g., only top corners)
public struct RoundedCorner: Shape {
    public var radius: CGFloat
    public var corners: UIRectCorner

    public init(radius: CGFloat = .infinity, corners: UIRectCorner = .allCorners) {
        self.radius = radius
        self.corners = corners
    }

    public func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
#endif
