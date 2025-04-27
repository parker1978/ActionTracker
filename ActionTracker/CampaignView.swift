//
//  CampaignView.swift
//  ActionTracker
//
//  Created by Stephen Parker on 4/22/25.
//

import SwiftUI
import SwiftData
import Foundation

struct CampaignView: View {
    @Environment(\.modelContext) private var context
    @Query private var campaigns: [Campaign]
    @State private var showingAddCampaign = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(campaigns) { campaign in
                    NavigationLink(destination: CampaignDetailView(campaign: campaign)) {
                        CampaignRow(campaign: campaign)
                    }
                }
                .onDelete(perform: deleteCampaigns)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddCampaign = true }) {
                        Image(systemName: "plus")
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
            }
            .sheet(isPresented: $showingAddCampaign) {
                AddCampaignView()
            }
        }
    }
    
    private func deleteCampaigns(at offsets: IndexSet) {
        for index in offsets {
            let campaign = campaigns[index]
            context.delete(campaign)
        }
        try? context.save()
    }
}

struct CampaignRow: View {
    var campaign: Campaign
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(campaign.campaignName)
                    .font(.headline)
                Spacer()
                Text(formatDate(campaign.startDate))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("Survivor: \(campaign.survivorName)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Total CXP: \(campaign.totalCXP)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: Campaign Detail View
// Campaign detail view to show detailed progress
struct CampaignDetailView: View {
    @Bindable var campaign: Campaign
    @Environment(\.modelContext) private var context
    @State private var showingAddSkill = false
    @State private var showingAddAchievement = false
    @State private var showingAddEquipment = false
    @State private var showingAddMission = false
    @State private var newSkill = ""
    @State private var newAchievement = ""
    @State private var newEquipment = ""
    @FocusState private var focusedField: CampaignDetailField?
    
    enum CampaignDetailField: Hashable {
        case survivorName
        case achievement
        case equipment
    }
    
    private func deleteMission(_ mission: Mission) {
        // Adjust campaign values before deleting
        
        // Subtract CXP
        campaign.totalCXP -= mission.cxpEarned
        
        // Remove the earned bonus actions from the campaign
        campaign.bonusActionsEarned -= mission.bonusActionsUsed
        campaign.bonusActions -= mission.bonusActionsUsed
        
        // Remove the mission from the campaign
        campaign.missions?.removeAll { $0.id == mission.id }
        
        // Delete the mission from the context
        context.delete(mission)
        try? context.save()
    }
    
    private func insertTextAtCursor(_ text: String) {
        if let field = focusedField {
            switch field {
            case .survivorName:
                campaign.survivorName += text
            case .achievement:
                newAchievement += text
            case .equipment:
                newEquipment += text
            }
        }
    }
    
    var body: some View {
        List {
            Section("Survivor Info") {
                TextField("Survivor Name", text: $campaign.survivorName)
                    .focused($focusedField, equals: .survivorName)
                    .submitLabel(.done)
                    .onSubmit {
                        focusedField = nil
                    }
                
                HStack {
                    Text("Total CXP:")
                    Spacer()
                    
                    Text("\(campaign.totalCXP)")
                        .frame(minWidth: 40)
                }
            }

            Section("Campaign Skills") {
                if campaign.campaignSkills.isEmpty {
                    Text("No campaign skills yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(campaign.campaignSkills, id: \.self) { skill in
                        Text(skill)
                    }
                }
            }

            Section("Bonus Actions") {
                HStack {
                    Text("Available:")
                    Spacer()
                    
                    Button("-", action: { 
                        if campaign.bonusActions > 0 {
                            campaign.bonusActions -= 1
                        }
                    })
                    .buttonStyle(.bordered)
                    .disabled(campaign.bonusActions <= 0)
                    
                    Text("\(campaign.bonusActions)")
                        .frame(minWidth: 40)
                    
                    Button("+", action: { 
                        // Only allow incrementing up to total earned
                        if campaign.bonusActions < campaign.bonusActionsEarned {
                            campaign.bonusActions += 1
                        }
                    })
                    .buttonStyle(.bordered)
                    .disabled(campaign.bonusActions >= campaign.bonusActionsEarned)
                }
                
                Text("Total Earned: \(campaign.bonusActionsEarned)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Text("Achievements")
                    Spacer()
                    Button(action: { 
                        showingAddAchievement = true 
                        focusedField = .achievement
                    }) {
                        Image(systemName: "plus.circle")
                    }
                }
                
                if showingAddAchievement {
                    HStack {
                        TextField("New Achievement", text: $newAchievement)
                            .focused($focusedField, equals: .achievement)
                            .submitLabel(.done)
                            .onSubmit {
                                if !newAchievement.isEmpty {
                                    campaign.campaignAchievements.append(newAchievement)
                                    newAchievement = ""
                                    showingAddAchievement = false
                                }
                            }
                        
                        Button("Add") {
                            if !newAchievement.isEmpty {
                                campaign.campaignAchievements.append(newAchievement)
                                newAchievement = ""
                                showingAddAchievement = false
                            }
                        }
                    }
                }
                
                if campaign.campaignAchievements.isEmpty && !showingAddAchievement {
                    Text("No achievements yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(campaign.campaignAchievements, id: \.self) { achievement in
                        Text(achievement)
                    }
                    .onDelete { indexSet in
                        campaign.campaignAchievements.remove(atOffsets: indexSet)
                    }
                }
            }

            Section {
                HStack {
                    Text("Equipment Kept")
                    Spacer()
                    Button(action: { 
                        showingAddEquipment = true
                        focusedField = .equipment
                    }) {
                        Image(systemName: "plus.circle")
                    }
                }
                
                if showingAddEquipment {
                    HStack {
                        TextField("New Equipment", text: $newEquipment)
                            .focused($focusedField, equals: .equipment)
                            .submitLabel(.done)
                            .onSubmit {
                                if !newEquipment.isEmpty {
                                    campaign.equipmentKept.append(newEquipment)
                                    newEquipment = ""
                                    showingAddEquipment = false
                                }
                            }
                        
                        Button("Add") {
                            if !newEquipment.isEmpty {
                                campaign.equipmentKept.append(newEquipment)
                                newEquipment = ""
                                showingAddEquipment = false
                            }
                        }
                    }
                }
                
                if campaign.equipmentKept.isEmpty && !showingAddEquipment {
                    Text("No equipment saved yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(campaign.equipmentKept, id: \.self) { equipment in
                        Text(equipment)
                    }
                    .onDelete { indexSet in
                        campaign.equipmentKept.remove(atOffsets: indexSet)
                    }
                }
            }

            Section {
                HStack {
                    Text("Missions")
                    Spacer()
                    Button(action: { showingAddMission = true }) {
                        Image(systemName: "plus.circle")
                    }
                }
                
                if campaign.missions?.isEmpty ?? true {
                    Text("No missions played yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(campaign.missions ?? []) { mission in
                        NavigationLink(destination: MissionDetailView(mission: mission)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(mission.missionName)
                                    .font(.headline)
                                Text("CXP Earned: \(mission.cxpEarned)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if !mission.equipmentGained.isEmpty {
                                    Text("Equipment: \(mission.equipmentGained.joined(separator: ", "))")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                deleteMission(mission)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .onDelete { indexSet in
                        if let missions = campaign.missions {
                            indexSet.forEach { index in
                                if index < missions.count {
                                    let mission = missions[index]
                                    deleteMission(mission)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(campaign.campaignName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            EditButton()
        }
        .sheet(isPresented: $showingAddMission) {
            AddMissionView(campaign: campaign)
        }
        .keyboardToolbar(
            onInsertText: { insertTextAtCursor($0) },
            onDone: { focusedField = nil }
        )
    }
}

// MARK: Add Campaign View
struct AddCampaignView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @State private var campaignName = ""
    @State private var campaignDescription = ""
    @State private var selectedCharacter: Character?
    @State private var showingCharacterSelector = false
    @FocusState private var focusedField: CampaignField?
    
    enum CampaignField: Hashable {
        case name
        case description
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Campaign Information") {
                    TextField("Campaign Name", text: $campaignName)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .description
                        }
                    TextField("Description (Optional)", text: $campaignDescription)
                        .focused($focusedField, equals: .description)
                        .submitLabel(.done)
                        .onSubmit {
                            focusedField = nil
                        }
                }
                
                Section("Survivor Information") {
                    Button(action: {
                        showingCharacterSelector = true
                    }) {
                        HStack {
                            Text(selectedCharacter == nil ? "Select Character" : "Selected: \(selectedCharacter!.name)")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let character = selectedCharacter {
                        VStack(alignment: .leading) {
                            Text(character.set?.isEmpty == false ? "Set: \(character.set!)" : "")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            // Display skills
                            if let skills = character.skills, !skills.isEmpty {
                                Text("Skills: \(skills.map { $0.name }.joined(separator: ", "))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Campaign")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        addCampaign()
                    }
                    .disabled(campaignName.isEmpty || selectedCharacter == nil)
                }
            }
            .sheet(isPresented: $showingCharacterSelector) {
                CharacterSelectorView(selectedCharacter: $selectedCharacter, dismiss: { showingCharacterSelector = false })
            }
            .keyboardToolbar(
                onInsertText: { insertTextAtCursor($0) },
                onDone: { focusedField = nil }
            )
        }
    }
    
    private func insertTextAtCursor(_ text: String) {
        if let field = focusedField {
            switch field {
                case .name:
                    campaignName.append(text)
                case .description:
                    campaignDescription.append(text)
            }
        }
    }
    
    private func addCampaign() {
        guard let character = selectedCharacter else { return }
        
        let newCampaign = Campaign(
            campaignName: campaignName,
            survivorName: character.name,
            campaignDescription: campaignDescription.isEmpty ? nil : campaignDescription
        )
        
        context.insert(newCampaign)
        try? context.save()
        dismiss()
    }
}

// MARK: Add Mission View
struct AddMissionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    var campaign: Campaign
    
    @State private var missionName = ""
    @State private var cxpEarned = 0
    @State private var bonusActionsUsed = 0
    @State private var newEquipment = ""
    @State private var equipmentList: [String] = []
    @State private var newObjective = ""
    @State private var objectivesList: [String] = []
    @State private var notes = ""
    @FocusState private var focusedField: MissionField?
    
    enum MissionField: Hashable {
        case name, equipment, objective, notes
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Mission Information") {
                    TextField("Mission Name", text: $missionName)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .notes
                        }
                    
                    Stepper("CXP Earned: \(cxpEarned)", value: $cxpEarned, in: 0...100)
                    Stepper("Bonus Actions Earned: \(bonusActionsUsed)", value: $bonusActionsUsed, in: 0...10)
                    
                    TextField("Notes (Optional)", text: $notes, axis: .vertical)
                        .focused($focusedField, equals: .notes)
                        .submitLabel(.done)
                        .onSubmit {
                            focusedField = nil
                        }
                        .lineLimit(3, reservesSpace: true)
                }
                
                Section("Equipment Gained") {
                    HStack {
                        TextField("Add Equipment", text: $newEquipment)
                            .focused($focusedField, equals: .equipment)
                            .submitLabel(.done)
                            .onSubmit {
                                addEquipment()
                            }
                        
                        Button("Add") {
                            addEquipment()
                        }
                        .disabled(newEquipment.isEmpty)
                    }
                    
                    ForEach(equipmentList, id: \.self) { item in
                        Text(item)
                    }
                    .onDelete { indexSet in
                        equipmentList.remove(atOffsets: indexSet)
                    }
                }
                
                Section("Objectives Completed") {
                    HStack {
                        TextField("Add Objective", text: $newObjective)
                            .focused($focusedField, equals: .objective)
                            .submitLabel(.done)
                            .onSubmit {
                                addObjective()
                            }
                        
                        Button("Add") {
                            addObjective()
                        }
                        .disabled(newObjective.isEmpty)
                    }
                    
                    ForEach(objectivesList, id: \.self) { item in
                        Text(item)
                    }
                    .onDelete { indexSet in
                        objectivesList.remove(atOffsets: indexSet)
                    }
                }
            }
            .navigationTitle("Add Mission")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveMission()
                    }
                    .disabled(missionName.isEmpty)
                }
            }
            .keyboardToolbar(
                onInsertText: { insertTextAtCursor($0) }, 
                onDone: { focusedField = nil }
            )
        }
    }
    
    private func insertTextAtCursor(_ text: String) {
        if let field = focusedField {
            switch field {
                case .name:
                    missionName += text
                case .equipment:
                    newEquipment += text
                case .objective:
                    newObjective += text
                case .notes:
                    notes += text
            }
        }
    }
    
    private func addEquipment() {
        if !newEquipment.isEmpty {
            equipmentList.append(newEquipment)
            newEquipment = ""
            focusedField = .equipment
        }
    }
    
    private func addObjective() {
        if !newObjective.isEmpty {
            objectivesList.append(newObjective)
            newObjective = ""
            focusedField = .objective
        }
    }
    
    private func saveMission() {
        let mission = Mission(
            missionName: missionName,
            cxpEarned: cxpEarned,
            objectivesCompleted: objectivesList,
            bonusActionsUsed: bonusActionsUsed,
            equipmentGained: equipmentList,
            notes: notes.isEmpty ? nil : notes
        )
        
        campaign.missions?.append(mission)
        
        // Update campaign totals based on mission data
        campaign.totalCXP += cxpEarned
        
        // Add bonus actions earned to the campaign
        campaign.bonusActionsEarned += bonusActionsUsed
        campaign.bonusActions += bonusActionsUsed
        
        // Add any new equipment to kept equipment
        for equipment in equipmentList {
            if !campaign.equipmentKept.contains(equipment) {
                campaign.equipmentKept.append(equipment)
            }
        }
        
        try? context.save()
        dismiss()
    }
}

// MARK: Mission Detail View 
struct MissionDetailView: View {
    @Bindable var mission: Mission
    @Environment(\.modelContext) private var context
    @State private var showingAddEquipment = false
    @State private var showingAddObjective = false
    @State private var showingAddCampaignSkill = false
    @State private var newEquipment = ""
    @State private var newObjective = ""
    @State private var selectedCampaignSkill = ""
    @FocusState private var focusedField: MissionDetailField?
    
    enum MissionDetailField: Hashable {
        case name
        case notes
        case equipment
        case objective
    }
    
    // Available campaign skills
    private let availableCampaignSkills = [
        "Combat reflexes", 
        "Destiny", 
        "Hoard", 
        "Hold your nose", 
        "Home defender", 
        "Lifesaver", 
        "Low profile", 
        "Night fighter", 
        "Sidestep", 
        "Starts with 2 AP", 
        "Starts with a Repair Kit", 
        "Starts with an Ammo card", 
        "Steady hand", 
        "Webbing"
    ]
    
    private func insertTextAtCursor(_ text: String) {
        if let field = focusedField {
            switch field {
            case .name:
                mission.missionName += text
            case .notes:
                if mission.notes == nil {
                    mission.notes = text
                } else {
                    mission.notes! += text
                }
            case .equipment:
                newEquipment += text
            case .objective:
                newObjective += text
            }
        }
    }
    
    var body: some View {
        Form {
            Section {
                TextField("Mission Name", text: $mission.missionName)
                    .focused($focusedField, equals: .name)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .notes
                    }
                
                Stepper("CXP Earned: \(mission.cxpEarned)", value: $mission.cxpEarned, in: 0...100)
                    .onChange(of: mission.cxpEarned) { oldValue, newValue in
                        // Update campaign total whenever mission CXP changes
                        if let campaign = mission.campaign {
                            let difference = newValue - oldValue
                            campaign.totalCXP += difference
                        }
                    }
                
                // This is now "Bonus Actions Earned" but the field name remains the same
                Stepper("Bonus Actions Earned: \(mission.bonusActionsUsed)", value: $mission.bonusActionsUsed, in: 0...10)
                    .onChange(of: mission.bonusActionsUsed) { oldValue, newValue in
                        // Update campaign's bonus actions whenever mission's earned actions changes
                        if let campaign = mission.campaign {
                            let difference = newValue - oldValue
                            campaign.bonusActionsEarned += difference  // Update total earned
                            campaign.bonusActions += difference  // Update available
                        }
                    }
                
                if mission.notes != nil {
                    TextField("Notes", text: Binding(
                        get: { mission.notes ?? "" },
                        set: { mission.notes = $0.isEmpty ? nil : $0 }
                    ), axis: .vertical)
                    .focused($focusedField, equals: .notes)
                    .submitLabel(.done)
                    .lineLimit(3, reservesSpace: true)
                } else {
                    Button("Add Notes") {
                        mission.notes = ""
                        focusedField = .notes
                    }
                }
            }
            
            Section {
                HStack {
                    Text("Campaign Skills")
                    Spacer()
                    Button(action: {
                        showingAddCampaignSkill = true
                    }) {
                        Image(systemName: "plus.circle")
                    }
                }
                
                if showingAddCampaignSkill {
                    Picker("Select Campaign Skill", selection: $selectedCampaignSkill) {
                        Text("Select a skill").tag("")
                        ForEach(availableCampaignSkills.filter { skill in
                            guard let campaign = mission.campaign else { return true }
                            return !campaign.campaignSkills.contains(skill)
                        }, id: \.self) { skill in
                            Text(skill).tag(skill)
                        }
                    }
                    
                    Button("Add Skill") {
                        if !selectedCampaignSkill.isEmpty {
                            if let campaign = mission.campaign {
                                // Add to campaign skills
                                campaign.campaignSkills.append(selectedCampaignSkill)
                                selectedCampaignSkill = ""
                                showingAddCampaignSkill = false
                            }
                        }
                    }
                    .disabled(selectedCampaignSkill.isEmpty)
                }
                
                if let campaign = mission.campaign, !campaign.campaignSkills.isEmpty {
                    ForEach(campaign.campaignSkills, id: \.self) { skill in
                        Text(skill)
                    }
                    .onDelete { indexSet in
                        if let campaign = mission.campaign {
                            campaign.campaignSkills.remove(atOffsets: indexSet)
                        }
                    }
                } else if !showingAddCampaignSkill {
                    Text("No campaign skills yet.")
                        .foregroundStyle(.secondary)
                }
            }
            
            Section {
                HStack {
                    Text("Equipment Gained")
                    Spacer()
                    Button(action: {
                        showingAddEquipment = true
                        focusedField = .equipment
                    }) {
                        Image(systemName: "plus.circle")
                    }
                }
                
                if showingAddEquipment {
                    HStack {
                        TextField("New Equipment", text: $newEquipment)
                            .focused($focusedField, equals: .equipment)
                            .submitLabel(.done)
                            .onSubmit {
                                if !newEquipment.isEmpty {
                                    mission.equipmentGained.append(newEquipment)
                                    // Also add to campaign's kept equipment
                                    if let campaign = mission.campaign, !campaign.equipmentKept.contains(newEquipment) {
                                        campaign.equipmentKept.append(newEquipment)
                                    }
                                    newEquipment = ""
                                    showingAddEquipment = false
                                }
                            }
                        
                        Button("Add") {
                            if !newEquipment.isEmpty {
                                mission.equipmentGained.append(newEquipment)
                                // Also add to campaign's kept equipment
                                if let campaign = mission.campaign, !campaign.equipmentKept.contains(newEquipment) {
                                    campaign.equipmentKept.append(newEquipment)
                                }
                                newEquipment = ""
                                showingAddEquipment = false
                            }
                        }
                    }
                }
                
                if mission.equipmentGained.isEmpty && !showingAddEquipment {
                    Text("No equipment gained.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(mission.equipmentGained, id: \.self) { equipment in
                        Text(equipment)
                    }
                    .onDelete { indexSet in
                        mission.equipmentGained.remove(atOffsets: indexSet)
                    }
                }
            }
            
            Section {
                HStack {
                    Text("Objectives Completed")
                    Spacer()
                    Button(action: {
                        showingAddObjective = true
                        focusedField = .objective
                    }) {
                        Image(systemName: "plus.circle")
                    }
                }
                
                if showingAddObjective {
                    HStack {
                        TextField("New Objective", text: $newObjective)
                            .focused($focusedField, equals: .objective)
                            .submitLabel(.done)
                            .onSubmit {
                                if !newObjective.isEmpty {
                                    mission.objectivesCompleted.append(newObjective)
                                    newObjective = ""
                                    showingAddObjective = false
                                }
                            }
                        
                        Button("Add") {
                            if !newObjective.isEmpty {
                                mission.objectivesCompleted.append(newObjective)
                                newObjective = ""
                                showingAddObjective = false
                            }
                        }
                    }
                }
                
                if mission.objectivesCompleted.isEmpty && !showingAddObjective {
                    Text("No objectives completed.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(mission.objectivesCompleted, id: \.self) { objective in
                        Text(objective)
                    }
                    .onDelete { indexSet in
                        mission.objectivesCompleted.remove(atOffsets: indexSet)
                    }
                }
            }
        }
        .navigationTitle(mission.missionName)
        .navigationBarTitleDisplayMode(.inline)
        .keyboardToolbar(
            onInsertText: { insertTextAtCursor($0) },
            onDone: { focusedField = nil }
        )
    }
}

// Character Selector View
struct CharacterSelectorView: View {
    @Binding var selectedCharacter: Character?
    var dismiss: () -> Void
    
    @Query(sort: \Character.name) var characters: [Character]
    @State private var searchText = ""
    
    var filteredCharacters: [Character] {
        guard !searchText.isEmpty else { return characters }
        
        // Check for special search tokens
        if searchText.lowercased().hasPrefix("set:") {
            let setQuery = searchText.dropFirst(4).trimmingCharacters(in: .whitespaces)
            return characters.filter { 
                guard let set = $0.set else { return false }
                return set.localizedCaseInsensitiveContains(setQuery)
            }
        } else if searchText.lowercased().hasPrefix("skill:") {
            let skillQuery = searchText.dropFirst(6).trimmingCharacters(in: .whitespaces)
            return characters.filter { 
                ($0.skills ?? []).contains { 
                    $0.name.localizedCaseInsensitiveContains(skillQuery)
                }
            }
        } else {
            // Standard search - name or any skill
            return characters.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                ($0.skills ?? []).contains { $0.name.localizedCaseInsensitiveContains(searchText) } ||
                (($0.set ?? "").localizedCaseInsensitiveContains(searchText))
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar at the top
                CharacterListView.SearchBar(text: $searchText)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(.systemBackground))
                
                List {
                    ForEach(filteredCharacters) { character in
                        Button {
                            selectedCharacter = character
                            dismiss()
                        } label: {
                            VStack(alignment: .leading) {
                                Text(character.set?.isEmpty == false ? "\(character.name) (\(character.set!))" : character.name)
                                    .font(.headline)
                                // Display skills sorted by position
                                if let skills = character.skills, !skills.isEmpty {
                                    SkillsWithDescriptionView(skills: skills.sorted { $0.position < $1.position })
                                }
                            }
                            .foregroundColor(.primary)
                        }
                    }
                }
                .searchSuggestions {
                    if searchText.isEmpty {
                        Text("Try searching by name")
                            .searchCompletion("Fred")
                        Text("Search by set")
                            .searchCompletion("set: Core")
                        Text("Filter by skill")
                            .searchCompletion("skill: +1 Die")
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Select Character")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// Already declared in CharacterListView, so we don't need to redeclare it here

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    do {
        let schema = Schema([Campaign.self, Mission.self, Character.self, Skill.self])
        let container = try ModelContainer(for: schema, configurations: config)

        // Add a sample character
        let character = Character(name: "John Doe", set: "Core Box", allSkills: ["Steady Aim", "First Aid"])
        container.mainContext.insert(character)
        
        let campaign = Campaign(
            campaignName: "Fort Hendrix",
            survivorName: "John Doe"
        )
        campaign.totalCXP = 12
        campaign.campaignSkills = ["Sniper", "Night Vision"]
        campaign.bonusActions = 2
        campaign.campaignAchievements = ["Saved Base", "Rescued Civilians"]
        campaign.equipmentKept = ["M4 Rifle", "First Aid Kit"]

        let mission1 = Mission(
            missionName: "Secure the Gates",
            cxpEarned: 6,
            objectivesCompleted: ["Gate Secured"],
            bonusActionsUsed: 1,
            equipmentGained: ["Ammo Pack"]
        )

        let mission2 = Mission(
            missionName: "Night Raid",
            cxpEarned: 6,
            objectivesCompleted: ["Intel Gathered"],
            bonusActionsUsed: 1,
            equipmentGained: ["Flashlight"]
        )

        container.mainContext.insert(campaign)
        campaign.missions?.append(contentsOf: [mission1, mission2])

        return NavigationStack {
            CampaignView()
                .modelContainer(container)
        }
    } catch {
        return Text("Preview failed: \(error.localizedDescription)")
            .padding()
    }
}
