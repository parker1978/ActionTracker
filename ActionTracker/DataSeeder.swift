import Foundation
import SwiftData

// MARK: - Data Seeder

struct DataSeeder {
    // Version tracking
    private static let SKILLS_DATA_VERSION = "1.0"
    private static let skillsVersionKey = "SkillsDataVersion"

    /// Seeds the database with built-in characters and skills if not already seeded
    static func seedIfNeeded(context: ModelContext) {
        // Clean up any duplicate skills first (one-time operation)
        cleanupDuplicateSkills(context: context)

        // Seed skills with versioning
        seedSkills(context: context)

        // Seed characters with versioning
        seedCharacters(context: context)

        // Save context
        try? context.save()
    }

    /// Check if characters need to be reseeded based on version
    private static func shouldReseedCharacters(context: ModelContext) -> Bool {
        // Check for version mismatch using UserDefaults
        let currentVersion = CharacterRepository.CHARACTERS_DATA_VERSION
        let storedVersion = UserDefaults.standard.string(forKey: "CharactersDataVersion")

        if storedVersion != currentVersion {
            return true
        }

        // Check if any built-in characters exist
        let descriptor = FetchDescriptor<Character>(
            predicate: #Predicate { $0.isBuiltIn == true }
        )

        if let count = try? context.fetchCount(descriptor), count == 0 {
            return true
        }

        return false
    }

    /// Check if skills need to be reseeded based on version
    private static func shouldReseedSkills(context: ModelContext) -> Bool {
        // Check for version mismatch using UserDefaults
        let currentVersion = SKILLS_DATA_VERSION
        let storedVersion = UserDefaults.standard.string(forKey: skillsVersionKey)

        if storedVersion != currentVersion {
            return true
        }

        // Check if any built-in skills exist
        let descriptor = FetchDescriptor<Skill>(
            predicate: #Predicate { $0.isBuiltIn == true }
        )

        if let count = try? context.fetchCount(descriptor), count == 0 {
            return true
        }

        return false
    }

    /// Remove duplicate skills from the database (one-time cleanup)
    private static func cleanupDuplicateSkills(context: ModelContext) {
        // Fetch all skills
        let descriptor = FetchDescriptor<Skill>()

        guard let allSkills = try? context.fetch(descriptor) else {
            return
        }

        // Group skills by name
        var skillsByName: [String: [Skill]] = [:]
        for skill in allSkills {
            if skillsByName[skill.name] == nil {
                skillsByName[skill.name] = []
            }
            skillsByName[skill.name]?.append(skill)
        }

        // Remove duplicates (keep first occurrence)
        var duplicatesRemoved = 0
        for (_, skills) in skillsByName where skills.count > 1 {
            // Keep the first one, delete the rest
            for skill in skills.dropFirst() {
                context.delete(skill)
                duplicatesRemoved += 1
            }
        }

        if duplicatesRemoved > 0 {
            print("🧹 Cleaned up \(duplicatesRemoved) duplicate skills")
        }
    }

    // MARK: - Seed Skills

    private static func seedSkills(context: ModelContext) {
        // Check if reseeding is needed
        guard shouldReseedSkills(context: context) else {
            return
        }

        // Delete existing built-in skills
        let descriptor = FetchDescriptor<Skill>(
            predicate: #Predicate { $0.isBuiltIn == true }
        )

        if let existingSkills = try? context.fetch(descriptor) {
            for skill in existingSkills {
                context.delete(skill)
            }
        }

        let skills: [(String, String)] = [
            ("+1 Damage With Katana", ""),
            ("+1 Damage With Machete", ""),
            ("+1 Damage: [Action]", "The Survivor gets a +1 Damage bonus with the specified type of Action (Combat, Melee, or Ranged)."),
            ("+1 Damage: Combat", "The Survivor gets a +1 Damage bonus with Combat."),
            ("+1 Damage: Melee", "The Survivor gets a +1 Damage bonus with Melee."),
            ("+1 Damage: Ranged", "The Survivor gets a +1 Damage bonus with Ranged."),
            ("+1 Die: [Action]", "Each of the Survivor's weapons rolls an extra die with Actions of the specified type (Combat, Melee, or Ranged). Dual weapons each gain a die, for a total of +2 dice per Dual Action of the specified type."),
            ("+1 Die: Combat", "Each of the Survivor's weapons rolls an extra die with Combat. Dual weapons each gain a die, for a total of +2 dice per Dual Action of Combat."),
            ("+1 Die: Melee", "Each of the Survivor's weapons rolls an extra die with Melee. Dual weapons each gain a die, for a total of +2 dice per Dual Action of Melee."),
            ("+1 Die: Ranged", "Each of the Survivor's weapons rolls an extra die with Ranged. Dual weapons each gain a die, for a total of +2 dice per Dual Action of Ranged."),
            ("+1 Free [Action Type] Action", "The Survivor has 1 extra free Action of the specified type (Combat, Melee, Move, Ranged, or Search). This Action may only be used to perform an Action of the specified type."),
            ("+1 Free Action: Combat", "The Survivor has 1 extra free Action of Combat. This Action may only be used to perform an Action of Combat."),
            ("+1 Free Action: Melee", "The Survivor has 1 extra free Action of Melee. This Action may only be used to perform an Action of Melee."),
            ("+1 Free Action: Move", "The Survivor has 1 extra free Action of Move. This Action may only be used to perform an Action of Move."),
            ("+1 Free Action: Ranged", "The Survivor has 1 extra free Action of Ranged. This Action may only be used to perform an Action of Ranged."),
            ("+1 Free Action: Search", "The Survivor has 1 extra free Action of Search. This Action may only be used to perform an Action of Search."),
            ("+1 Free Combat Action", ""),
            ("+1 Free Melee Action", ""),
            ("+1 Free Move Action", ""),
            ("+1 Free Reload", ""),
            ("+1 Max Range", "The maximum Range of Ranged weapons the Survivor uses is increased by 1."),
            ("+1 To Dice Roll: [Action]", "The Survivor adds 1 to the result of each die they roll with Actions of the specified type (Combat, Melee, or Ranged). The maximum result is always 6."),
            ("+1 To Dice Roll: Combat", "The Survivor adds 1 to the result of each die they roll with Combat. The maximum result is always 6."),
            ("+1 To Dice Roll: Melee", "The Survivor adds 1 to the result of each die they roll with Melee. The maximum result is always 6."),
            ("+1 To Dice Roll: Ranged", "The Survivor adds 1 to the result of each die they roll with Ranged. The maximum result is always 6."),
            ("+1 Zone Per Move", "When the Survivor spends 1 Action to Move, they can Move 1 or 2 Zones instead of 1. Entering a Zone containing Zombies still ends the Survivor's Move Action."),
            ("2 Cocktails Are Better Than 1", "Roll a die each time the Survivor discards a Molotov to perform a Ranged Action. On a result of • or more, the Molotov Equipment card may be put in the Survivor's Backpack instead, for free. The die result may not be altered or re-rolled in any way."),
            ("All-Out: +1 Damage: Melee", ""),
            ("All-Out: +1 Die: Combat", ""),
            ("All-Out: +1 Die: Melee", ""),
            ("All-Out: +1 Free Action: Ranged", ""),
            ("All-Out: +1 To Dice Roll: Combat", ""),
            ("All-Out: Ranged: Damage 2", ""),
            ("Ambidextrous", "The Survivor treats all weapons as if they had the Dual symbol."),
            ("B.I.A.: +1 Free Action: Combat", "The Survivor can use this Skill whenever they are standing in the same Zone as at least 1 other Survivor. As long as Brother in arms is active, each Survivor in the Zone (including the one with this Skill) benefits from +1 Free Action: Combat. Companions do not benefit from this Skill."),
            ("B.I.A.: Born Leader", "The Survivor can use this Skill whenever they are standing in the same Zone as at least 1 other Survivor. As long as Brother in arms is active, each Survivor in the Zone (including the one with this Skill) benefits from Born Leader. Companions do not benefit from this Skill."),
            ("B.I.A.: Field Medic", "The Survivor can use this Skill whenever they are standing in the same Zone as at least 1 other Survivor. As long as Brother in arms is active, each Survivor in the Zone (including the one with this Skill) benefits from Field Medic. Companions do not benefit from this Skill."),
            ("B.I.A.: Lucky", "The Survivor can use this Skill whenever they are standing in the same Zone as at least 1 other Survivor. As long as Brother in arms is active, each Survivor in the Zone (including the one with this Skill) benefits from Lucky. Companions do not benefit from this Skill."),
            ("B.I.A: Tough", "The Survivor can use this Skill whenever they are standing in the same Zone as at least 1 other Survivor. As long as Brother in arms is active, each Survivor in the Zone (including the one with this Skill) benefits from Tough. Companions do not benefit from this Skill."),
            ("Barbarian", "When resolving a Melee Action, the Survivor may substitute the Dice number of the Melee weapon(s) they use with the number of Zombies standing in their Zone. Skills affecting the dice value, like +1 die: Melee, still apply."),
            ("Blitz", "The Survivor can use this Skill once during each of their Turns. The Survivor spends 1 Action: they Move up to 2 Zones, to a Zone where Zombies are within Range of one of their equipped Ranged weapons. They then gain 1 free Ranged Action. Normal Movement rules apply."),
            ("Bloodlust: [Action]", "The Survivor can use this Skill once during each of their Turns. The Survivor spends 1 Action: they Move up to 2 Zones to a Zone containing at least 1 Zombie. They then gain 1 free Action of the specified type (Combat, Melee, or Ranged). Normal Movement rules apply."),
            ("Bloodlust: Combat", "The Survivor can use this Skill once during each of their Turns. The Survivor spends 1 Action: they Move up to 2 Zones to a Zone containing at least 1 Zombie. They then gain 1 free Action of Combat. Normal Movement rules apply."),
            ("Bloodlust: Melee", "The Survivor can use this Skill once during each of their Turns. The Survivor spends 1 Action: they Move up to 2 Zones to a Zone containing at least 1 Zombie. They then gain 1 free Action of Melee. Normal Movement rules apply."),
            ("Born Leader", "During the Survivor's Turn, the Survivor may give 1 free Action to another Survivor to use as they please. This Action is used immediately. Then, the Born leader Survivor resumes their Turn."),
            ("Break-In", "The Survivor doesn't need any Equipment to open doors. They don't make Noise while using this Skill. However, other prerequisites still apply (such as taking a designated Objective before a door can be opened). Moreover, the Survivor gains one extra free Action that can only be used to open doors."),
            ("Brother In Arms: [Game Effect]", "The Survivor can use this Skill whenever they are standing in the same Zone as at least 1 other Survivor. As long as Brother in arms is active, each Survivor in the Zone (including the one with this Skill) benefits from the indicated Skill or game effect. Companions do not benefit from this Skill. NOTE: Brother in arms may be shortened to B.I.A."),
            ("Can Search More Than Once", "The Survivor can Search multiple times per Turn, spending 1 Action for each Search Action."),
            ("Camaraderie", ""),
            ("Charge", "The Survivor can use this Skill once during each of their Turns, for free. They move up to 2 Zones to a Zone containing at least 1 Zombie. Normal Movement rules still apply. Entering a Zone containing Zombies still ends the Survivor's Move Action."),
            ("Combat Reflexes", "Whenever any Zombies spawn within Range 0-1 (and before any Rush), the Survivor may immediately perform a free Combat Action against them. This Action may eliminate more Zombies than have spawned. Ranged Actions must still be aimed at the Zone where the Zombies spawned. The Survivor may use this Skill once per Zombie card drawn."),
            ("Combat: Damage 2", "Weapons of Combat used by the Survivor and having a Damage value of 1 are considered to have a Damage value of 2."),
            ("Destiny", "The Survivor can use this Skill once per Turn when they reveal an Equipment card they drew. They can ignore and discard that card. Then, draw another Equipment card from the same deck."),
            ("Distributor", "When resolving the Spawn Step during the Zombie Phase, draw as many Zombie Cards as there are active Spawn Zones. Look at the Zombie Cards, then assign 1 of them to each active Spawn Zone, spawning Zombies as indicated."),
            ("Double All-Out Dice", ""),
            ("Dreadnought: [Zombie Type]", "The Survivor ignores all Wounds coming from Zombies having the indicated keyword in its name. Dreadnought: Walker works with any Walker, for example."),
            ("Dreadnought: Walker", "The Survivor ignores all Wounds coming from Walker Zombies."),
            ("Dual Expert", "The Survivor has a free Combat Action as long as they have Dual weapons equipped. This Action may only be used with the Dual equipped weapons."),
            ("Escalation: [Action]", "The Survivor gains 1 extra die to roll for consecutive Actions of the specified type (Combat, Melee, or Ranged). The bonus is cumulative and applies until the end of the Survivor's Turn. The bonus is lost whenever the Survivor performs another kind of Action."),
            ("Escalation: Combat", "The Survivor gains 1 extra die to roll for consecutive Actions Combat. The bonus is cumulative and applies until the end of the Survivor's Turn. The bonus is lost whenever the Survivor performs another kind of Action."),
            ("Field Medic", "The Survivor can use this Skill once during each of their Turns. The Survivor spends 1 Action: they Move up to 2 Zones to a Zone containing at least 1 Survivor. Then, they may heal 1 Wound from any Survivor in the destination Zone, including themselves. Normal Movement rules apply. Field Medic may be used even if all Survivors in the destination Zone have no Wounds."),
            ("Free Reload", "The Survivor reloads reloadable weapons (Ma's Shotgun, Sawed-Off, etc.) for free."),
            ("Full Auto", "When resolving a Ranged Action, the Survivor may substitute the Dice number of the Ranged weapon(s) they use with the number of Zombies standing in the targeted Zone. Skills affecting the dice value, like +1 die: Ranged, still apply."),
            ("Gunslinger", "The Survivor treats all Ranged weapons as if they had the Dual symbol."),
            ("Hit & Run", "The Survivor can use this Skill for free just after they resolve a Melee or Ranged Action resulting in at least 1 Zombie being eliminated. They can then make a free Move Action. The Survivor does not spend extra Actions to perform this free Move Action if Zombies are standing in their Zone."),
            ("Hoard", "The Survivor can carry up to 2 extra Equipment cards. They are placed near their Dashboard and are considered to be in their Backpack."),
            ("Hold Your Nose", "The Survivor draws an Equipment card (from the Core Equipment deck only) whenever the last Zombie standing in their Zone is eliminated (by the Survivor themselves, another Survivor, or any game effect). This Skill works in any Zone, even a street Zone, and can be used multiple times in the same Turn. This is NOT considered a Search Action."),
            ("Home Defender", "The Survivor is not limited to Range 0-1 when tracing Lines of Sight through building Zones."),
            ("Ignore 1 Break", ""),
            ("Improvised Weapon: Melee", "The Survivor can use this Skill once during each of their Turns. They perform a free Melee Attack using these characteristics. Melee modifiers (other Skills, for example) apply."),
            ("Improvised Weapon: Ranged", "The Survivor can use this Skill once during each of their Turns. They perform a free Ranged Attack using these characteristics. Ranged modifiers (other Skills, for example) apply."),
            ("Is That All You Got?", "This Skill can be used any time the Survivor is about to endure Wounds. Negate 1 Wound for each Equipment card discarded from the Survivor's inventory."),
            ("Is That All You've Got?", "This Skill can be used any time the Survivor is about to endure Wounds. Negate 1 Wound for each Equipment card discarded from the Survivor's inventory."),
            ("Jump", "The Survivor can use this Skill once during each of their Turns. The Survivor spends 1 Action and moves 2 Zones. Ignore everything in the intervening Zone, except walls and closed doors. Movement related Skills (like +1 Zone per Move or Slippery) are ignored, but Movement penalties (like having Zombies in the starting Zone) apply."),
            ("Lifesaver", "The Survivor can use this Skill once during each of their Turns, for free. Select a Zone containing at least 1 Zombie and at least 1 Survivor at Range 1 from the Survivor. Both Zones need to share a clear path and a Line of Sight. Choose Survivors in the selected Zone to be dragged to the Survivor's Zone without penalty. This is not a Move Action. A Survivor may decline the rescue and stay in the selected Zone if their player chooses."),
            ("Low Profile", "The Survivor can't get hit by Friendly Fire (Molotov rules still apply). Ignore them when shooting at the Zone they stand in."),
            ("Lucky", "For each Action the Survivor takes, the player may choose to re-roll all the dice an additional time. The new result replaces the previous one. This Skill stacks with the effects of Equipment that allows re-rolls."),
            ("Matching Set", "When the Survivor performs a Search Action and draws an Equipment card with the Dual symbol, they can immediately take a second card of the same type from the Equipment deck. Shuffle the deck afterward."),
            ("Medic", "This Skill is used for free during each End Phase. The Survivor, and all other Survivors standing in the same Zone, may heal 1 Wound (min. 0 Wound). The Survivor earns 1 AP for each Wound healed this way."),
            ("Melee: Damage 2", "Weapons of Melee used by the Survivor and having a Damage value of 1 are considered to have a Damage value of 2."),
            ("Night Vision", ""),
            ("Parrying Blow", ""),
            ("Point-Blank", "The Survivor can perform Ranged Actions in their own Zone, no matter the minimum Range. When resolving a Ranged Action at Range 0, the Survivor freely chooses the targets and can eliminate any type of Zombies (no matter the special abilities they may have). Their Ranged weapons still need to inflict enough Damage to eliminate the targets. Friendly Fire is ignored."),
            ("Ranged: Damage 2", "Weapons of Ranged used by the Survivor and having a Damage value of 1 are considered to have a Damage value of 2."),
            ("Reaper: [Action]", "This Skill can be used when assigning hits while resolving an Action of the specified type (Combat, Melee, or Ranged). 1 of these hits can freely eliminate an additional identical Zombie in the same Zone. Only a single additional Zombie can be eliminated per Action when using this Skill. The Survivor gains the Adrenaline for the additional Zombie."),
            ("Reaper: Combat", "This Skill can be used when assigning hits while resolving an Action of Combat. 1 of these hits can freely eliminate an additional identical Zombie in the same Zone. Only a single additional Zombie can be eliminated per Action when using this Skill. The Survivor gains the Adrenaline for the additional Zombie."),
            ("Reaper: Melee", "This Skill can be used when assigning hits while resolving an Action of Melee. 1 of these hits can freely eliminate an additional identical Zombie in the same Zone. Only a single additional Zombie can be eliminated per Action when using this Skill. The Survivor gains the Adrenaline for the additional Zombie."),
            ("Reaper: Ranged", "This Skill can be used when assigning hits while resolving an Action of Ranged. 1 of these hits can freely eliminate an additional identical Zombie in the same Zone. Only a single additional Zombie can be eliminated per Action when using this Skill. The Survivor gains the Adrenaline for the additional Zombie."),
            ("Regeneration", "During each End Phase, the Survivor's Health is fully restored to its maximum."),
            ("Roll 6: +1 Damage", ""),
            ("Roll 6: +1 Damage [Action]", "Add 1 to the Damage value of the weapon the Survivor uses for each 6 rolled on an Action of the specified type (Combat, Melee, or Ranged). Game effects that allow re-rolls must be used before determining the Damage bonus granted by this Skill."),
            ("Roll 6: +1 Die [Action]", "An additional die can be rolled for each 6 rolled on an Action of the specified type (Combat, Melee, or Ranged). Keep on rolling additional dice as long as the player keeps getting 6. Game effects that allow re-rolls must be used before rolling any additional dice for this Skill."),
            ("Roll 6: +1 Die Combat", "An additional die can be rolled for each 6 rolled on an Action of Combat. Keep on rolling additional dice as long as the player keeps getting 6. Game effects that allow re-rolls must be used before rolling any additional dice for this Skill."),
            ("Roll 6: +1 Die Melee", "An additional die can be rolled for each 6 rolled on an Action of Melee. Keep on rolling additional dice as long as the player keeps getting 6. Game effects that allow re-rolls must be used before rolling any additional dice for this Skill."),
            ("Roll 6: +1 Die Ranged", "An additional die can be rolled for each 6 rolled on an Action of Ranged. Keep on rolling additional dice as long as the player keeps getting 6. Game effects that allow re-rolls must be used before rolling any additional dice for this Skill."),
            ("Ronald's Ray Gun", ""),
            ("Scavenger", "The Survivor may Search in any building or street Zone. Normal Search rules apply (no Search in Zones with Zombies, for example)."),
            ("Search: 2 Cards", ""),
            ("Shove", "The Survivor can use this Skill once during each of their Turns, for free. Select a Zone at Range 1 from the Survivor. Both Zones need to share a clear path. All Zombies standing in the Survivor's Zone are pushed to the selected Zone. This is not a Movement."),
            ("Sidestep", "Whenever any Zombies spawn within Range 0-1 (and before any Rushes), the Survivor may immediately perform a free Move Action. The Survivor does not spend extra Actions to perform this free Move Action if Zombies are standing in their Zone. The Survivor may use this Skill once per Zombie card drawn."),
            ("Slippery", "The Survivor does not spend extra Actions when they perform a Move Action out of a Zone containing Zombies. The Survivor also ignores Zombies when performing Move Actions (including those allowing them to cross several Zones, with the Sprint Skill for example)."),
            ("Sniper", "The Survivor may freely choose the targets of all their Ranged Actions. Friendly Fire is ignored."),
            ("Spare Parts", "Each time the Survivor gets 1 break result (or more) on a Melee or Ranged Attack they may discard a weapon card of the corresponding type (Ranged or Melee) to ignore these Break results."),
            ("Sprint", "The Survivor can use this Skill once during each of their Turns. Spend 1 Move Action with the Survivor: they may move 2 or 3 Zones instead of 1. Entering a Zone containing Zombies still ends the Survivor's Move Action."),
            ("Starts With 2 Ap", "The Survivor begins the game with 2 Adrenaline Points. Note: Survivors with this Skill cannot be used as Companions."),
            ("Starts With [X] Health", "The Survivor starts with the indicated amount of Health. This is their base level. Note: Survivors with this Skill cannot be used as Companions."),
            ("Starts With A [Equipment]", "The Survivor begins the game with the indicated Equipment. Its card(s) is/are automatically assigned to them during Setup. Note: Survivors with this Skill cannot be used as Companions."),
            ("Starts With: 2 Kukris", "The Survivor begins the game with the indicated Equipment. Its card(s) is/are automatically assigned to them during Setup. Note: Survivors with this Skill cannot be used as Companions."),
            ("Starts With: 2 Machetes", "The Survivor begins the game with the indicated Equipment. Its card(s) is/are automatically assigned to them during Setup. Note: Survivors with this Skill cannot be used as Companions."),
            ("Starts With: 2 Molotov", "The Survivor begins the game with the indicated Equipment. Its card(s) is/are automatically assigned to them during Setup. Note: Survivors with this Skill cannot be used as Companions."),
            ("Starts With: A Chainsaw", "The Survivor begins the game with the indicated Equipment. Its card(s) is/are automatically assigned to them during Setup. Note: Survivors with this Skill cannot be used as Companions."),
            ("Starts With: A Fire Axe", "The Survivor begins the game with the indicated Equipment. Its card(s) is/are automatically assigned to them during Setup. Note: Survivors with this Skill cannot be used as Companions."),
            ("Starts With: A Flashlight", "The Survivor begins the game with the indicated Equipment. Its card(s) is/are automatically assigned to them during Setup. Note: Survivors with this Skill cannot be used as Companions."),
            ("Starts With: A Katana", "The Survivor begins the game with the indicated Equipment. Its card(s) is/are automatically assigned to them during Setup. Note: Survivors with this Skill cannot be used as Companions."),
            ("Starts With: A Sawed-Off", "The Survivor begins the game with the indicated Equipment. Its card(s) is/are automatically assigned to them during Setup. Note: Survivors with this Skill cannot be used as Companions."),
            ("Starts With: A Shotgun", "The Survivor begins the game with the indicated Equipment. Its card(s) is/are automatically assigned to them during Setup. Note: Survivors with this Skill cannot be used as Companions."),
            ("Starts With: A Sniper Rifle", "The Survivor begins the game with the indicated Equipment. Its card(s) is/are automatically assigned to them during Setup. Note: Survivors with this Skill cannot be used as Companions."),
            ("Starts With: A Sub-Mg", "The Survivor begins the game with the indicated Equipment. Its card(s) is/are automatically assigned to them during Setup. Note: Survivors with this Skill cannot be used as Companions."),
            ("Steady Hand", "The Survivor can ignore other Survivors of their choosing when missing with a Ranged Action. This Skill does not apply to game effects killing everything in the targeted Zone (such as a Molotov, for example)."),
            ("Super Strength", "Consider the Damage value of Melee weapons used by the Survivor to be 3."),
            ("Swordmaster", "The Survivor treats all Melee weapons as if they had the Dual symbol."),
            ("Tactician", "The Survivor's Turn can be resolved anytime during the Player Phase, before or after any other Survivor's Turn. If several Survivors benefit from this Skill, players choose their Turn order."),
            ("Taunt", "The Survivor can use this Skill once during each of their Turns, for free. Select a Zone up to 2 Zones away from the Survivor and having a clear path to the Survivor (no walls, closed Barricades, or closed Doors). No Line of Sight is needed. All Zombies standing in the selected Zone immediately gain an extra Activation. They try to reach the taunting Survivor by any means available. Taunted Zombies ignore all other Survivors. They do not attack them and leave the Zone they are standing in if needed to reach the taunting Survivor."),
            ("Tough", "The Survivor ignores the first Wound they receive during each Attack Step (Zombie Phase) and during Friendly Fire (Survivor's Ranged Action)."),
            ("Trump Card", ""),
            ("Webbing", "All Equipment in the Survivor's inventory is considered equipped in Hand."),
            ("Zombie Link", "The Survivor plays an extra Turn each time an Extra Activation card (NOT Rushes) is drawn from the Zombie pile. They play before the extra-activated Zombies. If several Survivors benefit from this Skill at the same time, players choose their Turn order."),
        ]

        for (name, description) in skills {
            let skill = Skill(name: name, skillDescription: description, isBuiltIn: true)
            context.insert(skill)
        }

        // Update version in UserDefaults
        UserDefaults.standard.set(SKILLS_DATA_VERSION, forKey: skillsVersionKey)

        print("✅ Seeded \(skills.count) skills (v\(SKILLS_DATA_VERSION))")
    }

    // MARK: - Seed Characters

    private static func seedCharacters(context: ModelContext) {
        // Check if reseeding is needed
        guard shouldReseedCharacters(context: context) else {
            return
        }

        // Delete existing built-in characters
        let descriptor = FetchDescriptor<Character>(
            predicate: #Predicate { $0.isBuiltIn == true }
        )

        if let existingCharacters = try? context.fetch(descriptor) {
            for character in existingCharacters {
                context.delete(character)
            }
        }

        // Load characters from repository
        let repository = CharacterRepository.shared
        let characterDataList = repository.allCharacters

        // Insert characters into database
        for data in characterDataList {
            let character = Character(
                name: data.name,
                set: data.set ?? "",
                notes: data.notes ?? "",
                isBuiltIn: true,
                teen: data.isTeen,
                health: data.healthValue,
                blueSkills: data.blue,
                yellowSkills: "+1 Action",  // Standard yellow skill
                orangeSkills: data.orange,
                redSkills: data.red
            )
            context.insert(character)
        }

        // Update version in UserDefaults
        UserDefaults.standard.set(CharacterRepository.CHARACTERS_DATA_VERSION, forKey: "CharactersDataVersion")

        print("✅ Seeded \(characterDataList.count) characters (v\(CharacterRepository.CHARACTERS_DATA_VERSION))")
    }
}
