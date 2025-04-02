//
//  ViewExt.swift
//  ActionTracker
//
//  Created by Stephen Parker on 4/2/25.
//

import Foundation
import SwiftUI

extension View {
    func disabledWithOpacity(_ status: Bool) -> some View {
        self
            .disabled(status)
            .opacity(status ? 0.5 : 1)
    }
}
