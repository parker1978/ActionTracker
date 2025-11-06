//
//  View+CornerRadius.swift
//  SharedUI
//
//  Extension for selective corner rounding using RoundedCorner shape.
//

import SwiftUI

#if canImport(UIKit)
import UIKit

public extension View {
    /// Clips the view with rounded corners on specific corners only
    /// - Parameters:
    ///   - radius: The corner radius
    ///   - corners: Which corners to round (e.g., [.topLeft, .topRight])
    /// - Returns: Modified view with selective corner rounding
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}
#endif
