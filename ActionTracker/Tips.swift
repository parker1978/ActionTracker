//
//  Tips.swift
//  ActionTracker
//
//  Created by Stephen Parker on 4/3/25.
//

import Foundation
import TipKit

struct EndTurnTip: Tip {
    var title = Text("End Turn")
    
    var message: Text? = Text("Tap here to reset all actions for the current turn.")
}

struct AddActionTip: Tip {
    var title = Text("Add Action")
    
    var message: Text? = Text("Tap here to add a new action.")
}
