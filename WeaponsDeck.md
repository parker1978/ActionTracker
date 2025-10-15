# Weapons Deck
## feature/weapons-deck

### Zombicide 2nd Edition — Weapon Card System Overview

In *Zombicide 2nd Edition*, weapon cards represent the tools survivors use to fight zombies or interact with the environment. They are part of the Equipment deck and come in two main categories: **Melee** and **Ranged** weapons — though some rare cards can function as both. Each weapon card displays **combat characteristics** that define its effectiveness and behavior in play.

Your digital implementation mirrors these mechanics, using structured data in a CSV file to store and manage every weapon's stats, symbols, and attributes. This makes it easy to filter decks, adjust difficulty, and include or exclude expansion content.

---

### 1. Weapon Categories

**Melee Weapons**
- Identified by the **Melee symbol**.  
- Have a **Range of 0**, meaning they can only be used in the same Zone as the Survivor.  
- Used with **Melee Actions**.  
- Examples: Crowbar, Fire Axe, Baseball Bat, Ka-Bar.  
- In your CSV, these are stored as `Category = Melee` with `Range = 0`.

**Ranged Weapons**
- Identified by the **Ranged symbol**.  
- Typically have a **maximum range of 1 or more**.  
- Used with **Ranged Actions**, even when firing into the same Zone.  
- Examples: Pistol, Rifle, Shotgun, Sniper Rifle.  
- In your CSV, these have `Category = Ranged` and include both `Range Min` and `Range Max` values.

**Dual-Type Weapons (Melee Ranged)**
- A small number of weapons can act as **both Melee and Ranged**, such as the *Gunblade*.  
- In your CSV, these are marked as `Category = Melee Ranged`.  
- The **Dice**, **Accuracy**, and **Damage** values represent the weapon's **ranged** performance.  
- **Melee-specific details**, such as how many dice are rolled in melee and whether the attack creates noise, are described in the `Special` field.  
- App logic should treat `Melee Ranged` weapons as having **two attack modes**:
  - **Ranged Mode:** Uses the normal Range, Dice, Accuracy, and Damage fields.  
  - **Melee Mode:** Pulls melee dice and noise info from `Special` while reusing the same Accuracy and Damage values.

---

### 2. Ammo and Re-Rolls

Ranged weapons have **infinite ammo**, but not all use the same type.  
- **Bullets** → small-caliber firearms (e.g., Pistols, Rifles). May benefit from *Plenty of Bullets*.  
- **Shells** → high-caliber firearms (e.g., Shotguns). May benefit from *Plenty of Shells*.  
- Melee weapons do **not** use ammo.  
- In your dataset, ammo is tracked via the `Ammo Type` field.

---

### 3. Door-Opening & Noise

Certain weapons (e.g., Crowbar, Fire Axe, Chainsaw) can **open doors** in addition to attacking zombies.

Your dataset tracks these through:
- `Open Door` → whether the weapon can open doors (`True`/`False`).  
- `Door Noise` → whether opening doors creates noise.  
- `Kill Noise` → whether attacking with the weapon creates noise.  

Noise determines zombie attraction in play.

---

### 4. Combat Characteristics (Card Bottom Section)

Every weapon card includes the following key stats:

| Attribute | Description | CSV Field |
|------------|--------------|------------|
| **Weapon Type** | Melee, Ranged, or Melee Ranged. | `Category` |
| **Range** | Minimum and maximum number of Zones it can reach. "0" = same Zone only. | `Range Min`, `Range Max`, or `Range` |
| **Dice** | Number of dice rolled per attack. For dual-type weapons, this value reflects the ranged mode. | `Dice` |
| **Accuracy** | Minimum die result (on a d6) required for a hit. Equal or higher = success. | `Accuracy` |
| **Damage** | Damage dealt per successful hit (does not stack). | `Damage` |
| **Dual** | Indicates if it can be dual-wielded. | `Dual` |
| **Ammo Type** | "Bullets," "Shells," or none for melee. | `Ammo Type` |
| **Overload** | Whether the weapon gains extra dice under overload. | `Overload`, `Overload Dice` |
| **Special** | Unique effects, melee behavior for "Melee Ranged," conditional bonuses. | `Special` |
| **Expansion** | Which expansion or set it belongs to. | `Expansion` |
| **Deck** | Which deck it's drawn from (e.g., "Starting," "Regular," "Ultrared"). | `Deck` |
| **Count** | Number of copies included in the deck. | `Count` |

---

### 5. Design Notes for Digital Version

- Each CSV row maps to a **Weapon object** with structured attributes.  
- **Melee Ranged** weapons require conditional logic to handle both attack modes correctly.  
- Decks can be **filtered** by attributes such as weapon type, expansion, or difficulty.  
- Difficulty can be adjusted dynamically using dice count, damage, or deck weighting.  
- Noise generation, dual-wield capability, and door-opening functionality can be automated from Boolean flags.  
- Cards with entries in `Special` (e.g., "Add +1 die to another equipped Melee weapon") should trigger additional combat logic.

---

### 6. SF Symbols to Use

- `figure.archery` — Ranged  
- `figure.fencing` — Melee  
- `door.left.hand.closed` — Open Door = false  
- `door.left.hand.open` — Open Door = true  
- `speaker.slash` — Kill Noise = false  
- `speaker.wave.3` — Kill Noise = true  
- `ear.trianglebadge.exclamationmark` — Door Noise = true  
- `02.circle` — Dual = true  
- `exclamationmark.triangle` — Overload = true  

> We don't have to use symbols for all of these. **Capsule text tags** may be clearer on digital cards.

---

### 7. Examples and Logic

In the folder **WeaponsExamplesLogic** are photos of actual game cards.
- Gray background = Starting Deck
- Blue background = Regular Deck
- Red background = Ultrared Deck (special rare weapons)

The folder also includes `Weapons.pdf`, which contains two pages from the Zombicide 2nd Edition manual explaining weapon cards and their symbols.

---

### 8. App Feature Instructions

This feature should be implemented in **phases**, with a review and testing break between each stage. I will confirm approval before moving to the next phase.

#### Weapon Deck Types

**Starting Deck**
- Used at the beginning of a game when each player draws a starting weapon.  
- Generally **low-power** weapons; at least **one must be able to open doors**.  
- If all starters drawn lack the "Open Door" ability, return all cards, shuffle, and re-draw until at least one door-opening weapon is dealt.  
- Data source: `Deck = Starting` in the CSV.

**Regular Deck**
- The most frequently drawn deck, used for **Search Actions** during gameplay.  
- Some **skills or items** (e.g., *Flashlight*) allow players to draw **two cards** instead of one.  
- Data source: `Deck = Regular`.

**Ultrared Deck**
- Contains rare and **high-power** weapons.  
- Drawn only when players discover certain **objectives** on the map.  
- Typically drawn only **6–12 times per game**.  
- Data source: `Deck = Ultrared`.

#### Inventory and Player Interaction Rules

Weapons drawn from these decks go directly into a **player's inventory**, unlike the Spawn Deck which manages game events.

Each player's character has:
- **2 Active weapon slots** (hands)
- **3 Inactive inventory slots**

Modifiers:
- Skills can **increase inventory capacity**.
- Certain effects can make the entire inventory **count as active**.  

To support this:
- The UI must allow **adding/removing cards** from both **hands** and **inventory**.
- Provide a **toggle/option** to expand capacity for special abilities.
- Players can **transfer** weapons between themselves using a player-to-player trade action.
- Items within a player's inventory should be **reorderable** or **movable** using an action.

---

## Phase Breakdown

#### **Phase 1: Core Deck Logic** (Backend only, no UI)
```
Implement deck state management:
- Load cards from a bundled dataset generated from CSV
- Create shuffle function
- Create draw/discard mechanics
- Implement different modes of play (easy, medium, hard)
- Handle deck reset when empty
Test this logic thoroughly before adding any UI.
```

#### **Phase 2: Basic UI Structure**
```
Create foundational UI elements for deck interaction:
- Add new "Weapons" tab to the bottom tab bar
- Create basic page structure
- Add easy/medium/hard mode toggle
- Add Reset and Shuffle buttons
No animations yet; just the skeleton.
```

#### **Phase 3: Deck Visualization (iOS Tab Bar)**
Goal: Represent **three independent decks** (Starting, Regular, Ultrared) in a way that's fast, obvious, and mobile-friendly—without simulating a single card pile.

**Primary UI Pattern: Segmented Deck Switcher**
- **Navigation:** Bottom tab bar → **Weapons** tab  
- **Inside the tab:** a segmented picker to switch between the three decks, each with its own controls and state.

**Layout (concept):**
- **Header**: Segmented control — `Starting | Regular | Ultrared`
- **Deck Summary Bar**: "X cards remaining" + quick actions (Shuffle, View Discard)
- **Action Row**: `Draw` (primary), optional `Draw x2` (if skills/items allow)
- **Drawn Card Panel**: Shows the latest weapon with key stats and actions: **Add to Inventory**, **Give to Player**, **Close**
- **Recent History (optional)**: last 3 drawn cards for quick reference

**Why this works**
- Focuses on one deck at a time (matches gameplay intent).
- Clear, one-tap switching between decks.
- Minimal cognitive load; easy to extend later (difficulty toggle, expansion filters).

**SwiftUI structure (for Codex):**
- `WeaponsTabView` (tab content)
  - `DeckSwitcherView` with `Picker(selection: $selectedDeck, ...)`
  - `DeckHeaderView(deckState: DeckState)` → remaining count, buttons
  - `DrawnCardView(card: Weapon?)` → stats + actions
  - `RecentDrawsView(cards: [Weapon])` (optional)

**State model (shared per deck):**
- `DeckState` with:
  - `remaining: Int`
  - `discard: [Weapon]`
  - `draw() -> Weapon?`
  - `drawTwo() -> [Weapon]`
  - `shuffle()`
  - `reset()`
  - `mode: Difficulty` (easy/medium/hard)
  - `filters: DeckFilters` (expansions, include/exclude)

> Each deck has its own `DeckState` instance. Switching segments swaps the bound state object.

#### **Phase 4: Discard Pile & Management**

**Goal:** Add a clear and functional way to manage discarded cards for all three weapon decks (Starting, Regular, Ultrared).

**Purpose**
Phase 3 provides a “View Discard” entry point; Phase 4 implements the full **discard lifecycle** — how cards are sent to discard, reviewed, returned, or reshuffled into the deck.

**Features**
- Maintain a discard pile for each deck.
- Show a discard count in the Deck Header.
- View and manage discarded cards in a modal/sheet.
- Auto-discard unkept cards from “Draw 2, keep 1.”
- When a deck is empty, allow reshuffling the discard back into the deck.

**UI Design**
- **Discard Button/Badge:** Each deck header shows “Discard (X)”.
- **Discard Sheet:**
  - Scrollable list of discarded cards (newest first)
  - Swipe actions per card: **Return to Top**, **Return to Bottom**, **Give to Player**
  - Footer actions: **Shuffle Back All** (returns all discards + shuffle), **Clear All** (dev/debug only)

**Discard Sheet (iOS Detents)**
- Use `.presentationDetents([.height(280), .medium, .large])` with a visible grabber.  
- Remember last detent per deck via `@SceneStorage`.
- Use `.presentationCornerRadius(16)`; enable interactive dismiss with confirmations for destructive actions.

**Core Logic**
```
remaining: [Weapon]
discard: [Weapon]

discard(_ card: Weapon)
returnFromDiscardToTop(_ card: Weapon)
returnFromDiscardToBottom(_ card: Weapon)
reclaimAllDiscardIntoDeck(shuffle: Bool = true)
```

**Testing Scenarios**
- Draw-two/keep-one discards the other card.
- Empty deck → reshuffle discard works.
- Return to top/bottom maintains order correctly.
- Discard per-deck state persists across tab switches.
- Filters/difficulty changes do not break the discard view.

#### **Phase 5: Player Inventory Management (Actions Tab)**

**Why:** Each player's inventory must be controllable by the player — **even when another player operates the Weapon Deck UI**. Therefore, inventory editing belongs in the **Actions** tab (per-turn screen), not inside the deck views.

**Scope**
- Add an **Inventory panel** to the Actions tab for the active player, supporting:
  - **2 Active (hand) slots** and **3 Inactive (backpack) slots** by default.
  - **Capacity modifiers** (skills/abilities) that expand inventory or treat inventory as active.
  - **Equip/Unequip** between active ↔︎ inactive.
  - **Trade**: Give/receive with another player during the correct action windows.
  - **Reorder** inactive items; quick move to hand if space allows.
- Inventory editing must be available **independently** from the Weapon Deck screen so players can manage loadouts while someone else draws.

**UI (Actions Tab)**
- **Inventory Summary Row**: shows active weapons, remaining capacity, quick actions (Equip, Unequip, Trade).
- **Edit Inventory Sheet** (detents recommended): `.medium` for quick swaps, `.large` for full management.
- Lists **Active** (hand L/R) and **Inactive** with drag-and-drop or buttons for move/reorder.
- Validation: block illegal states (e.g., both hands occupied when equipping a two-hander, if applicable).

**Data & State**
```
Player { id, name, inventory: Inventory, modifiers: InventoryModifiers }
Inventory { active: [Weapon?] /* size 2 */, inactive: [Weapon] /* size 3..N */ }
InventoryModifiers { extraSlots: Int, inventoryCountsAsActive: Bool }

canEquip(_ weapon: Weapon) -> Bool
equip(_ weapon: Weapon, hand: HandSlot)
unequip(from hand: HandSlot)
moveToInactive(_ weapon: Weapon)
trade(to: Player, weapon: Weapon)
```

**Integration with Decks**
- From a draw: **Add to Inventory** → player picker → slot picker (same inventory APIs).
- From Actions tab: players can **equip/unequip/trade** without touching deck views.
- Dropping to supply routes to the **deck’s discard** for the corresponding deck.

**Testing**
- Equipping/unequipping respects capacity and modifiers.
- Trading updates both players atomically.
- Illegal moves are prevented with clear errors.
- Inventory edits work while another device/user draws from decks.

---

### Data Source Consistency: Hardcode Weapons Data

**Goal:** Ensure all players/devices use an identical weapon set regardless of connectivity.

- Bundle a normalized weapons dataset with the app (e.g., **`weapons.json` generated from `weapons.csv` at build time**).
- Expose a `WEAPONS_DATA_VERSION` constant; surface version in Settings/About for debugging.
- Load from bundle on launch (no network dependency). Optionally allow **developer-only overrides** in Debug builds.
- Keep the repository abstraction (`WeaponRepository`) so future updates can swap the source transparently.

---

#### **Phase 6: Polish & Edge Cases**
```
Final touches:
- Ensure styling matches the rest of the app
- Test mode switching (easy ↔ hard)
- Test deck reset functionality
- Add any loading states, transitions, and error handling
```

# Section 9: Game Mechanics & Rules

This section defines the gameplay mechanics that the Weapons Deck feature must support. These rules determine how cards are drawn, distributed, and managed during play.

---

## 9.1 Player Setup & Starting Weapons

**Player Count**
- Supports **2 to 12 players**
- Typical family games: 5-6 players

**Starting Weapon Distribution**
At the beginning of a new game:
1. Each player draws **1 card** from the **Starting Deck**
2. **Door-Opener Requirement:**
   - At least one player in the group should have a door-opening weapon
   - The Starting Deck always contains **12 cards total**, with **4 door-opening weapons**
   - With typical player counts (2-6), probability is high that at least one door-opener is drawn
   - **No automatic validation or redraw** - players can manually assign a door-opening weapon to a player via the Actions tab inventory management if needed

**UI Implementation:**
- Simple "Deal Starting Weapons" button that draws X cards (where X = number of players)
- No complex validation logic required
- Players handle assignment via inventory management

---

## 9.2 Difficulty Modes

Three difficulty settings modify deck composition by **weighting toward more or less powerful weapons**.

### **Easy Mode**
**Goal:** Increase player power and survivability

**Implementation:**
- **Weight deck toward higher-power weapons**
- When building/shuffling the deck, increase the probability of drawing powerful weapons:
  - Weapons with **Dice ≥ 4**: Include extra virtual copies in shuffle pool
  - Weapons with **Damage ≥ 3**: Include extra virtual copies in shuffle pool
  - High-power combinations (high Dice AND high Damage): Triple representation

**Example Algorithm:**
```swift
// When building Easy mode deck
for weapon in allWeapons {
    let baseCount = weapon.count
    var effectiveCount = baseCount
    
    if weapon.dice >= 4 { effectiveCount += baseCount }
    if weapon.damage >= 3 { effectiveCount += baseCount }
    
    // Add 'effectiveCount' copies to shuffle pool
    for _ in 0..<effectiveCount {
        deck.append(weapon)
    }
}
```

### **Medium Mode** (Default)
**Goal:** Standard game balance as designed

**Implementation:**
- Include all weapons using exact `Count` values from CSV data
- No weighting adjustments
- Deck composition matches official game design

### **Hard Mode**
**Goal:** Increase challenge and resource scarcity

**Implementation:**
- **Weight deck toward lower-power weapons**
- When building/shuffling the deck, increase the probability of drawing weaker weapons:
  - Weapons with **Dice ≤ 2**: Include extra virtual copies
  - Weapons with **Damage ≤ 1**: Include extra virtual copies
  - Weapons with **Accuracy ≥ 5**: Include extra virtual copies (harder to hit)

**Example Algorithm:**
```swift
// When building Hard mode deck
for weapon in allWeapons {
    let baseCount = weapon.count
    var effectiveCount = baseCount
    
    if weapon.dice <= 2 { effectiveCount += baseCount }
    if weapon.damage <= 1 { effectiveCount += baseCount }
    if weapon.accuracy >= 5 { effectiveCount += baseCount }
    
    for _ in 0..<effectiveCount {
        deck.append(weapon)
    }
}
```

**Important Notes:**
- Weighting creates *virtual copies* for shuffling purposes only
- Physical `Count` field from CSV remains unchanged
- All weapons remain available, just with different draw probabilities
- Discard pile management unaffected (cards return as drawn)

**UI Implementation:**
- Segmented picker: `Easy | Medium | Hard`
- Changing difficulty **resets all three decks** (Starting, Regular, Ultrared)
- Confirmation dialog: "Changing difficulty will reset and reshuffle all decks. Continue?"
- Setting persists per game session

---

## 9.3 Draw Mechanics

### **Standard Draw (Single Card)**
- Used during normal Search Actions
- Player draws 1 card from **Regular Deck** or **Ultrared Deck** (depending on trigger)
- Card goes directly to player's inventory or requires placement decision (see Section 9.5)

### **Enhanced Draw (Draw 2, Keep 2)**
**Current Trigger Conditions:**
- Player has equipped the **Flashlight** item
- **Manual toggle:** "Draw 2 Mode" available in UI for future game expansions or character abilities

**UI Flow:**
1. Player taps `Draw x2` button (appears when Flashlight equipped OR toggle enabled)
2. Draw 2 cards from the selected deck
3. **Both cards go to the player** - no selection UI needed
4. Player manages placement via standard inventory rules (see Section 9.5)

**Logic:**
```swift
func drawTwo(from deck: DeckState, player: Player) {
    let cards = deck.drawTwo() // Returns [Weapon, Weapon]
    
    // Both cards go to player
    for card in cards {
        player.addToInventory(card) // Triggers placement flow if needed
    }
}
```

**Settings:**
- Add toggle in game settings: "Enable Draw 2, Keep 2" (default: OFF unless Flashlight detected)
- This accommodates future expansions without code changes

---

## 9.4 Inventory Management

### **Capacity Rules**

**Standard Capacity (All Characters)**
- **2 Active slots** (left hand, right hand)
- **3 Inactive slots** (backpack/reserve)
- **Total: 5 weapons maximum**

**Active vs. Inactive:**
- **Active weapons** can be used immediately during combat
- **Inactive weapons** cannot be used until equipped (moved to Active)
- Players manage equipping/unequipping timing based on game rules

### **Capacity Modifiers**

**Extra Slots:**
- Players can **manually adjust** inactive slot count via inventory settings
- Default: 3 inactive slots
- UI: Stepper control "Inactive Slots: [- 3 +]" (range: 1-10)
- Increases **Inactive capacity only** - Active slots remain 2

**"All Inventory Counts as Active" Toggle:**
- Players can enable via inventory settings
- When enabled: All weapons (Active + Inactive) function as if Active
- Player can use any weapon without moving to Active slots first
- Visual indicator: Badge or highlight on inventory panel
- Inventory capacity unchanged

**UI Implementation (Phase 5):**
```
Inventory Settings (gear icon in Actions tab)
├─ Inactive Slots: [- 3 +]
└─ ☐ All Weapons Count as Active
```

---

## 9.5 Weapon Placement Flow

When a card is drawn (from any deck), the player determines placement via the Actions tab inventory management.

**Standard Flow:**
1. Card is drawn from deck
2. **Show card detail modal** with weapon stats
3. Player dismisses modal
4. Player opens **Actions tab → Inventory panel**
5. Player adds weapon to their inventory manually
6. Or player adds weapon to another player's inventory

**Full Inventory Handling:**
- If player's inventory is full, they manage swaps via inventory panel
- Dropped weapons can be moved to deck's discard pile via inventory management
- No automatic enforcement - players self-manage inventory limits

**UI Pattern:**
- Keep drawn cards visible in "Recent Draws" area until player confirms placement
- Players can drag from Recent Draws to inventory slots
- Or use "Add to [Player]" button with player picker

---

## 9.6 Trading Between Players

**Philosophy:**
Trading between players is **very forgiving** and subject to **house rules**. The app does not enforce trading restrictions.

**Implementation:**
- Players can freely **edit any player's inventory** via the Actions tab
- Players can **move weapons between players** without restrictions
- The game relies on **player honesty** to follow their chosen trading rules
- No validation of:
  - Turn phase
  - Player proximity/zones
  - Action costs
  - Number of trades per turn

**UI Implementation (Phase 5):**
From Actions tab inventory panel:
- Button: "Manage All Players" → shows all player inventories
- Player can tap any player → edit their inventory
- Or long-press weapon → "Move to [Player Picker]"

**Note:**
This flexible approach accommodates various house rules without requiring rule engine complexity.

---

## 9.7 Two-Handed Weapons

**Not applicable** - Zombicide 2nd Edition does not have two-handed weapons.

No special logic or UI needed. All weapons can be equipped in either hand independently.

---

## 9.8 Deck Exhaustion & Reshuffling

**When a deck runs out:**
1. Draw action attempts to draw from empty deck
2. **Automatic reshuffle** triggers:
   - All cards from that deck's **discard pile** → back into deck
   - Shuffle deck
   - Complete the draw action
3. **UI Feedback:** Brief toast/animation: "Reshuffling [Deck Name]..."

**Edge Case: Deck AND Discard Both Empty**
This is **extremely rare** but can occur in Hard Mode when certain weapons are excluded via weighting and all included cards are in player inventories.

**Solution:**
- Temporarily **bring back excluded cards** from Hard Mode:
  - Rebuild deck with **Medium Mode weighting** for this reshuffle only
  - Continue playing with this expanded deck
  - Show message: "All weapons in play. Drawing from full deck."

**Implementation Notes:**
```swift
func drawCard() -> Weapon? {
    if deck.isEmpty {
        if discard.isNotEmpty {
            // Standard reshuffle
            deck = discard.shuffled()
            discard.removeAll()
        } else {
            // Emergency: rebuild with medium mode
            deck = buildDeck(mode: .medium).shuffled()
            showMessage("All weapons in play. Drawing from full deck.")
        }
    }
    return deck.popFirst()
}
```

---

## 9.9 Discard Pile (aka "Supply")

**Terminology Clarification:**
- "Supply" = "Discard Pile" (use terms interchangeably in documentation)
- Each deck (Starting, Regular, Ultrared) has its **own discard pile**
- Discarded weapons return to **their original deck's discard pile**

**Discard Sources:**
1. Player drops weapon from inventory
2. Deck reshuffle returns cards from discard
3. Player explicitly discards during inventory management

**Reclaim from Discard:**
- Players can browse discard pile via "View Discard" button (Phase 4)
- Players can move weapons from discard back to any player's inventory
- No restrictions - players manage this freely

---

## 9.10 Action Points & Timing

**Philosophy:**
The app **does not enforce action economy or timing rules**. Players self-manage:
- When weapons can be drawn
- When weapons can be equipped/unequipped
- How many actions have been used
- What game phase it currently is

**What the app provides:**
- Tools to **execute** weapon management actions
- Clear inventory state visualization
- Easy movement of weapons between states

**What players control:**
- Deciding when an action is legal
- Counting actions used per turn
- Enforcing house rules
- Adjudicating edge cases

**Implementation Impact:**
- No "action cost" validation in code
- No turn phase tracking required
- No "you can't do that now" error messages
- Focus on smooth, unrestricted UI flows
