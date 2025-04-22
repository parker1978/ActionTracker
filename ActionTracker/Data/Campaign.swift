//
//  Campaign.swift
//  ActionTracker
//
//  Created by Stephen Parker on 4/22/25.
//

import Foundation
import SwiftData

@Model
public final class Campaign {
    public var id: UUID = UUID()
    
    // Campaign Information
    public var campaignName: String = ""
    public var campaignDescription: String?
    public var startDate: Date = Date()
    public var endDate: Date?

    // Survivor Information
    public var survivorName: String = ""
    public var totalCXP: Int = 0

    // Progress Tracking
    public var campaignSkills: [String] = []
    public var bonusActions: Int = 0
    public var bonusActionsEarned: Int = 0
    public var campaignAchievements: [String] = []
    public var equipmentKept: [String] = []

    // Missions Relationship
    @Relationship(deleteRule: .cascade, inverse: \Mission.campaign)
    public var missions: [Mission]? = []
    
    public init(
        campaignName: String,
        survivorName: String,
        campaignDescription: String? = nil,
        startDate: Date = Date()
    ) {
        self.campaignName = campaignName
        self.survivorName = survivorName
        self.campaignDescription = campaignDescription
        self.startDate = startDate
        self.missions = []
    }
}

@Model
public final class Mission {
    public var id: UUID = UUID()
    
    public var missionName: String = ""
    public var datePlayed: Date = Date()
    public var cxpEarned: Int = 0
    public var objectivesCompleted: [String] = []
    public var bonusActionsUsed: Int = 0 // This is now "Bonus Actions Earned"
    public var notes: String?
    public var equipmentGained: [String] = []

    public var campaign: Campaign?
    
    public init(
        missionName: String,
        cxpEarned: Int,
        objectivesCompleted: [String] = [],
        bonusActionsUsed: Int = 0, // Renamed semantically to "Bonus Actions Earned"
        equipmentGained: [String] = [],
        notes: String? = nil
    ) {
        self.missionName = missionName
        self.cxpEarned = cxpEarned
        self.objectivesCompleted = objectivesCompleted
        self.bonusActionsUsed = bonusActionsUsed
        self.equipmentGained = equipmentGained
        self.notes = notes
    }
}
