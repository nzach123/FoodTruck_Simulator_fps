# Midnight Munch — Game Design Document

**Author:** Nick
**Date:** April 2026
**Engine:** Godot 4.6 (GDScript only — no C#)
**Platform:** Web (HTML5 / WebGL2)
**Genre:** Cozy Time-Management Cooking Sim
**Target Audience:** Casual and cozy gamers. Cooking rhythm game players who enjoy grinding and watching a bank account grow.
**Prototype Scope:** 3 weeks. One truck (taco). Core cooking loop. Tutorial day. No driving.
**Performance Target:** 60 FPS on a 2019 MacBook Air or equivalent Windows laptop.

---

## 1. Introduction

### Game Summary Pitch

Midnight Munch is a first-person cozy time-management cooking sim. You play as a man in the middle of a mid-life crisis who quits his office job to run a taco food truck. Customers line up at your serving window, you assemble their orders using four distinct physical interactions, ring the bell, and collect payment. Days are 5 minutes long. Profits fund upgrades. The pressure never stops building — until you build enough skill to outrun it.

### Inspiration

- **Cook, Serve, Delicious!** — borrowing the rhythm of reading an order and executing it under pressure. We extend this by making each ingredient feel physically different rather than mapping everything to a single key.
- **Overcooked** — borrowing the escalating pressure of a queue that never fully empties, and the satisfaction of a clean service. We strip the co-op chaos and replace it with personal skill expression.
- **Stardew Valley** — borrowing the cozy grind loop: each day is self-contained, profits roll over, upgrades compound, and watching a bank account grow is its own reward.

### Player Experience

The player stands first-person inside a taco food truck and can move freely between the front and back of the kitchen using WASD controls. Through the serving window at the front they can see a queue of up to three customers, each with a patience bar above their head and a speech bubble showing their order. The player accepts an order, then moves between the back counter (to grab a tortilla and shave meat off the trompo) and the front counter (to add sauces, place toppings, and ring the bell to submit the finished order).

The emotional arc of a session moves from calm and methodical at the start of a day to tense and rhythmic as the queue fills and patience bars tick down faster. A perfect run feels like flow state. A bad run — a rejected order, a customer storming off — stings just enough to make the next day feel like redemption.

### Platform & Tools

- **Platform:** Web (HTML5 / WebGL2)
- **Engine:** Godot 4.6 (GDScript only — no C#, required for WASM compatibility)
- **Art Tools:** Blender (low-poly modelling), Aseprite (PS1-style textures)
- **Audio Tools:** TBD

### Genre

Time-Management Cooking Sim / Cozy Arcade

### Target Audience

Casual and cozy gamers. Players who enjoy cooking rhythm games, satisfying grind loops, and watching a bank account grow. The core appeal is competence — starting clumsy and becoming fast, accurate, and efficient.

---

## 2. Main Menu

The first screen the player sees. Simple and atmospheric.

**Layout:**
- Background: low-poly taco truck parked at night, neon "Midnight Munch" sign glowing
- Ambient audio: soft city ambience, distant crowd, truck engine idling
- Buttons: `[New Game]` / `[Continue]` / `[Settings]` / `[Credits]`

**Logic:**
- `[New Game]` appears only if no save file exists
- `[Continue]` appears if a save file exists and loads directly to the saved day
- `[Settings]`: audio volume sliders only for prototype
- First-time players go straight to Day 0 (tutorial) after `[New Game]`

---

## 3. Session Structure

### Gameplay Overview

Each session is one 5-minute "day." The player assembles tacos to order and serves as many customers as possible before the timer runs out. Payment accumulates in a live bank balance. At the end of the day, an upgrade shop unlocks if the player can afford it. The next day begins with higher customer volume and shorter patience bars. There is no explicit win state — the game is a score chase and economic progression loop.

Success is determined by order accuracy (correct ingredients), execution quality (interactions hit within the ideal zone), and speed (serving customers before patience expires). Failure is never total — even a bad day earns some money — but waste and mistakes visibly erode the balance.

---

### Day 0 — Tutorial (Required Scope)

A scripted sequence of five orders. No timer. No patience bars. No penalties. The player cannot fail.

| Order | Ingredients | Guidance |
|-------|-------------|----------|
| 1 | Tortilla + Meat only | Full guided prompts at every station |
| 2 | Tortilla + Meat + Red Sauce | Guided prompts for sauce only |
| 3 | Tortilla + Meat + one Topping | Guided prompt for topping only |
| 4 | Tortilla + Meat + both Sauces + two Toppings | Light prompts |
| 5 | Full random order | No prompts — player flies solo |

**Guided prompt system:** A world-space arrow + text label appears above the next required station ("Click the tortilla stack to grab one"). Fades immediately once the action completes. Never tells the player what not to do — only points toward what to do next.

**Feedback on correct action:** Green particle burst + chime. Establish that the rhythm of a good order feels good before any stakes are introduced.

**End of Day 0:** Transition screen — *"The truck is ready. Real customers start tomorrow. Don't keep them waiting."* → Player presses `[Open for Business]` → Day 1 begins.

---

### Day 1+ — Full Session

A countdown timer (visible as a clock on the truck wall) runs for **5 minutes**. Customers arrive throughout. When the timer hits zero, the serving window closes and the end-of-day screen appears. Any in-progress order is abandoned without penalty.

### Day Progression

Each new day increases pressure automatically. No player-facing difficulty announcement — the heat just builds.

| Day | Patience (sec) | Spawn Rate | Max Concurrent | Feel |
|-----|----------------|------------|----------------|------|
| 0 | ∞ | Scripted | 1 | Tutorial — no pressure |
| 1 | 60 | 1 per 45s | 2 | Forgiving. Establish the loop. |
| 2 | 55 | 1 per 40s | 2 | Barely noticeable shift. |
| 3 | 50 | 1 per 35s | 3 | Queue starts filling. |
| 4 | 45 | 1 per 30s | 3 | Rush feeling emerges. |
| 5 | 40 | 1 per 25s | 3 | Expert territory begins. |
| 6 | 35 | 1 per 22s | 3 | Mastery required. |
| 7+ | 30 | 1 per 20s | 3 | Ceiling. Held indefinitely. |

After Day 7, the values hold. Further progression comes from player skill against a fixed wall, not an infinitely rising one.

### End-of-Day Screen

Appears after the 5-minute timer expires. Auto-saves before any button is pressed.

1. Total money earned (animated count-up)
2. Orders completed / orders attempted
3. Total tips earned
4. Upgrade shop (visible; greyed out if unaffordable)
5. `[Save & Exit]` — returns to main menu
6. `[Next Day]` — begins next day immediately

---

## 4. Customer Queue & Triage

### Queue Rules

- Maximum **3 customers** visible in the queue at once (data-driven; can be increased without code changes)
- Each unaccepted customer has a persistent speech bubble showing their required ingredients (small, always visible)
- Each customer has a **patience arc bar** above their head that depletes from the moment they arrive — even before the player accepts their order

### One Order at a Time

The player accepts one customer's order. That order locks into the top-right HUD. The player cannot accept a second order until the current taco is served. All other customers' patience continues draining while the player cooks.

**The skill is triage:** choosing which order to take first. A simple order for an impatient customer versus a complex order for a patient one. This decision repeats every 60–90 seconds and is the primary strategic layer of the game.

### Accepting an Order

- Player clicks on a customer to accept
- Their speech bubble is replaced by a small `[WAITING]` indicator
- Order moves to the top-right HUD panel
- Player begins assembly

### Customer Archetypes

Customers are not enemies — they are the clock. Their function is to create urgency and prioritisation decisions.

- **Standard Customer:** Average patience bar. One or two optional ingredients. The baseline order.
- **Picky Customer** *(stretch goal)*: Short patience bar. Requires all optional ingredients. High tip reward for perfect execution. Forces the player to be both fast and accurate simultaneously.
- **Chill Customer** *(stretch goal)*: Long patience bar. Only meat and tortilla. Low tip. Acts as breathing room during rush moments.

For the prototype, all customers use Standard behaviour. Archetype variation is a post-prototype feature.

### Patience Expiry

When an arc bar hits zero:
- Customer leaves (anger animation)
- Bank balance is debited **$1.50** (capped — cannot push balance below $0)
- Queue shifts forward; new customer may arrive

### Soft Bail-Out

If the player ends a day with a $0 balance, a "Regular Customer" appears at the start of the next day and hands over **$2.00** before the clock starts. This is diegetic, happens only once per failed day, and never lets the player go below zero across sessions.

---

## 5. Order System

### Recipe Structure

Every taco always contains:
- **Tortilla** (always)
- **Meat** (always)

Plus any combination of the optional ingredients:

| Ingredient | Optional |
|------------|----------|
| Red Sauce | Yes |
| White Sauce | Yes |
| Cilantro | Yes |
| Tomato | Yes |
| Onion | Yes |

Orders are procedurally generated. Combination is random per customer. No two customers are guaranteed the same order.

### Order HUD Panel (Top-Right)

Always visible once an order is accepted. Never fades. Each ingredient is a pill that changes state in real time:

| State | Visual | Meaning |
|-------|--------|---------|
| Grey outline | `[ Red Sauce ]` | Required, not yet added |
| Pulsing white | `[ Red Sauce ]` | Currently being interacted with |
| Green + checkmark | `[✓ Red Sauce ]` | Added perfectly |
| Orange + checkmark | `[~ Red Sauce ]` | Added (sloppy execution) |
| Red + X | `[✗ Red Sauce ]` | Bell rung — this item was missing |

The cognitive challenge is **speed and triage**, not memorisation. The HUD is the ground truth.

---

## 6. Cooking Mechanics

Four interactions. Each is physically and mechanically distinct. Learn them once and they apply everywhere.

| Primitive | Input | Feedback | Used For |
|-----------|-------|----------|----------|
| **Mash** | Rapidly press button | Radial progress bar fills | Shaving meat |
| **Power Bar** | Hold then release | Vertical gauge with green/red zones | Pouring sauces |
| **Shrinking Circle** | Press at the right moment | Circle shrinks to centre target | Placing toppings |
| **Click** | Single click | Instant | Grabbing tortilla, ringing bell |

---

### 6.1 Grab Tortilla — Click

**Station:** Tortilla stack on the **back counter** (truck interior rear). The player walks to the back of the truck to reach it.

**Action:** Player clicks the stack. A tortilla spawns in hand. Held item icon appears bottom-centre HUD. The tortilla persists in-hand through all subsequent steps until served.

**Fail state:** None. The stack is always available. Tortillas do not run out in the prototype.

---

### 6.2 Shave Meat — Button Mash

**Station:** Trompo (vertical al pastor meat spit) on the **back counter**, next to the tortilla stack. The player stays at the back of the truck to use it after grabbing a tortilla.

**Action:** Player stands at the back counter with tortilla in hand and repeatedly presses the interact key. A radial circular progress bar fills with each press. When the bar reaches 100%, a shaved portion of meat falls into the tortilla.

**Timing logic:** Built on `_physics_process` (fixed timestep) for stability on web.

**Feedback:**
- Each press: visual flash on the trompo + brief sizzle/scrape sound
- Bar fills: continuous visual fill
- Complete: meat-fall particle, satisfying thud, bar resets

**Upgrade effect (Sharper Knife):** The bar fills more per keypress. Fewer presses required.

---

### 6.3 Apply Sauce — Power Bar

**Station:** Sauce bottles on the **front counter**, near the serving window. Red and white are separate stations with distinct bottle shapes and colours. The player walks to the front of the truck after finishing at the back counter.

**Action:** Player stands at the front counter and holds the interact key on a sauce bottle. A vertical gauge fills from bottom to top. Player releases to lock in the pour amount.

**Three-zone outcomes:**

| Zone | Release Point | Outcome | HUD State |
|------|---------------|---------|-----------|
| Below green | Gauge in grey/empty range | Sauce NOT added. Ingredient still shows as missing. Player can try again. | Pill remains grey |
| Green zone | Gauge in bright green band | Sauce added cleanly. Marked perfect. | Pill turns green ✓ |
| Red zone | Gauge past green into red | Sauce added but over-poured. Taco marked sloppy. Disqualifies tip. | Pill turns orange ~ |

**Under-pour recovery:** The player can attempt the same sauce again immediately. The ingredient simply isn't registered yet — no penalty, just wasted time.

**Over-pour note:** The sauce is on the taco. It cannot be undone. The order will complete but the tip is forfeit.

**Feedback:**
- Gauge visible from the moment the player faces the station (green zone clearly shown before interaction begins)
- While holding in green: soft pleasant hum
- While holding in red: warning tone (audio plays after visual, not as sync reference — web latency)
- On release: immediate burst animation (green spray / red drip) + HUD pill state change

**Upgrade effect (Better Sauce Bottle):** The green zone band is wider.

---

### 6.4 Place Toppings — Shrinking Circle

**Station:** Three separate bins — cilantro (green), tomato (red), onion (white) — on the **front counter**, alongside the sauce bottles.

**Action:** Player clicks a topping bin. A large circle appears centred on screen and shrinks toward a visible target band. Player must click when the shrinking ring enters the target band.

**Critical web implementation note:** Timing logic runs on `_physics_process` only. Audio feedback plays *after* hit confirmation — never as a sync cue. Timing window is 30% wider than a native equivalent would be, to compensate for web input latency. Prototype this in Week 1 as a standalone spike.

**Outcomes:**

| Result | Condition | Consequence |
|--------|-----------|-------------|
| Hit | Click inside target band | Topping placed in taco. HUD pill turns green ✓. |
| Miss | Click outside band | Topping drops on floor. -$0.05 deducted. Player can try again. |

**Target band:** Visible from frame 1 of the animation. The player always knows where to aim.

**Drop recovery:** A missed topping sits on the floor as a physics prop (pooled `RigidBody3D`, frozen on impact). Player clicks the topping bin again to try fresh. Dropped item despawns after 10 seconds and is recycled to the pool.

**Feedback:**
- Hit: topping lands in taco with satisfying sound + green flash + HUD update
- Miss: topping bounces on floor + dull thud + -$0.05 ticker on screen

---

### 6.5 Ring the Bell — Serve

**Station:** Service bell on the **front counter**, near the serving window. Already in reach once the player has finished adding sauces and toppings at the front.

**Action:** Player clicks the bell.

**Validation logic:**

| Condition | Outcome |
|-----------|---------|
| All HUD pills green or orange (all ingredients present) | Serve immediately — see scoring below |
| Any HUD pill still grey (missing ingredient) | Confirmation popup appears |

**Confirmation popup (missing ingredient):**
> *"This order is missing [ingredient name]. Serve anyway?"*
> `[YES — Serve]` / `[NO — Keep Cooking]`

- `[YES]` → order submitted incomplete → customer rejects → food cost deducted → customer leaves
- `[NO]` → popup closes, no penalty, player returns to cooking

This prevents a single misclick from triggering a $2+ penalty. The player must deliberately choose to submit a wrong order.

---

## 7. Quality & Scoring

### Per-Order Quality Assessment

The game tracks quality flags across the entire assembly of one taco:

| Interaction | Perfect flag | Sloppy flag |
|-------------|-------------|-------------|
| Sauce | Released in green zone | Released in red zone (over-pour) |
| Topping | Hit target band on first try | Missed and retried (even if eventual hit) |
| Meat | Always considered neutral | N/A |

### Outcome Table

| Condition | Payment | Tip | Notes |
|-----------|---------|-----|-------|
| All interactions perfect (0 sloppy flags) | $3.50 | $1.00 | HUD pills all green |
| 1 sloppy flag | $3.50 | $0.50 | One orange pill |
| 2+ sloppy flags | $3.50 | $0.00 | Multiple orange pills |
| Missing ingredient (confirmed submission) | None | None | Customer rejects. Food cost deducted. |

---

## 8. Economy

### Starting Balance

Player begins Day 1 with **$5.00**. This is enough to absorb one rejection and one angry customer, but not both. Designed to feel precarious without being cruel.

### Revenue

| Source | Amount |
|--------|--------|
| Taco sale (any completion) | $3.50 |
| Tip — 0 sloppy flags | +$1.00 |
| Tip — 1 sloppy flag | +$0.50 |
| Tip — 2+ sloppy flags | +$0.00 |

### Deductions

| Event | Deduction | Notes |
|-------|-----------|-------|
| Drop topping | $0.05 | Per drop |
| Under-pour sauce (retry only) | $0.00 | No penalty — just lost time |
| Over-pour sauce (sloppy) | $0.00 | Penalty is lost tip, not a direct deduction |
| Customer patience expires | $1.50 | Capped — cannot push below $0 |
| Wrong order confirmed + rejected | Food cost of taco | See food cost table |

### Food Cost Per Ingredient

| Ingredient | Cost |
|------------|------|
| Tortilla | $0.25 |
| Meat (per shave) | $0.75 |
| Red Sauce | $0.15 |
| White Sauce | $0.15 |
| Cilantro | $0.10 |
| Tomato | $0.10 |
| Onion | $0.10 |

- Base taco (meat + tortilla): **$1.00** food cost
- Fully loaded taco: **$1.60** food cost
- Player's margin: $1.90–$2.50 per successful order (before tips)

### Economy Arc

| Days | Typical Balance | Feel |
|------|-----------------|------|
| 1–2 | $5–$25 | Scraping by. Upgrades out of reach. Every mistake stings. |
| 3–4 | $25–$60 | First upgrade affordable. Noticeable rhythm improvement. |
| 5–7 | $60–$150+ | Second upgrade in reach. Skill and upgrades compound. Flow state emerges. |

### Economy Floor

Balance cannot go below **$0.00**. Any penalty that would push below zero is capped at the current balance. If a day ends at $0, the bail-out Regular Customer appears at the start of the next day (+$2.00).

---

## 9. Upgrade Shop

Available on the end-of-day screen when funds permit. No day unlock gates — earn it, buy it.

| Upgrade | Cost | Effect |
|---------|------|--------|
| Sharper Knife | $25 | Meat progress bar fills more per keypress |
| Better Sauce Bottle | $40 | Green zone band is wider on sauce gauge |

Both can be purchased in any order. No dependency tree. Each is a one-time purchase.

**Design rationale:** A good Day 1 earns roughly $15–20. The knife is tantalizingly out of reach on Day 1 and comfortably affordable by Day 2–3. The sauce bottle follows once the knife is purchased. Together they transform Days 5–7 from punishing to satisfying.

*Future upgrades (post-prototype): topping timing window assist, patience extender, second bell slot.*

---

## 10. HUD Layout

**Resolution:** 1280 × 720 (16:9, standard web canvas)

| Element | Position | Behaviour |
|---------|----------|-----------|
| Day timer | Top-left | Counts down 5:00 → 0:00. Clock face on truck wall (world-space) mirrors the number. |
| Bank balance | Top-left (below timer) | Updates live on every transaction. Brief green flash on credit, red flash on debit. |
| Current order panel | Top-right | Ingredient pills with live state feedback. Always visible once order is accepted. Disappears on serve. |
| Held item icon | Bottom-centre | Shows what is currently in the player's hand. Empty hand = no icon. |
| Interaction prompt | World-space above station | Contextual label: "Click to grab" / "Hold to pour" / "Click to time" / "Click to serve". Appears on hover only. |
| Patience arcs | World-space above NPCs | Arc depletes in real time. Turns red in last 10 seconds. |
| Sauce gauge | Screen-centre (contextual) | Only visible during sauce interaction. Green zone visible before interaction begins. |
| Mash progress bar | Screen-centre (contextual) | Radial bar only visible during meat shaving. |
| Shrinking circle | Screen-centre (contextual) | Only visible during topping placement. Target band visible from frame 1. |
| Penalty ticker | Screen-centre (brief) | "-$0.05" floats and fades over 1 second on topping drop. |
| Bell confirmation popup | Screen-centre (modal) | Blocks interaction until dismissed. "Missing [X]. Serve anyway?" |

---

## 11. Scene Layout & Camera

### Camera System

**WASD movement + mouse-look (unclamped yaw, pitch-clamped).**

The player moves freely inside the food truck using WASD controls. Mouse-look rotates the camera in any horizontal direction (360° yaw, unclamped), allowing the player to face forward toward the serving window or turn around toward the back counter. Vertical pitch is clamped (±60°) to prevent looking at the ceiling or floor. This provides:
- Natural station discovery by physically walking to each station
- Intuitive front-to-back rhythm: grab supplies from the back, serve from the front
- Persistent sense of being *inside the truck*, not floating in space

Mouse movement → camera rotation (continuous). WASD → player movement within truck bounds. Click → interact with whatever the crosshair targets.

### Station Layout

```
════════════════[ SERVING WINDOW ]════════════════
           [ Customer queue visible here ]

 [ Bell ] [ Red Sauce ] [ White Sauce ] [ Cilantro ] [ Tomato ] [ Onion ]
 ←—————————————— FRONT COUNTER (customer-facing) ——————————————→

                     ↑ player moves ↑↓

             [ Tortilla Stack ] [ Trompo ]
 ←————————————— BACK COUNTER (truck interior rear) —————————————→
```

Player workflow: walk to the **back** to grab a tortilla and shave meat, then turn and walk to the **front** to add sauces, place toppings, and ring the bell.

### Interaction Hitboxes

Each station has:
- A visual mesh (the actual object)
- An invisible `Area3D` proxy **1.5× larger** than the mesh as the raycast target

The raycast originates from the `Camera3D` and has a reach of **3.0 m** — enough to interact with any station the player is standing in front of, but not enough to accidentally trigger stations across the truck.

Cursor states:
- Default: small crosshair dot
- Over interactable: larger circle + context icon (hand, pour, timer)
- Over nothing interactable: dimmed dot

**One-station-active rule:** Only the station the cursor is over can be interacted with. Adjacent stations do not highlight simultaneously.

### Physics Layers

| Layer | Contents |
|-------|----------|
| 1 | Environment (walls, counter, truck body) |
| 2 | Player raycast |
| 3 | Interactable stations and items |
| 4 | Snap zones (tortilla surface, serving tray) |

---

## 12. Art & Tone Direction

### Visual Style

Low-poly PS1 aesthetic. Chunky geometry. Unfiltered, low-resolution textures. No anti-aliasing. No bloom. Point filtering on all sprites and textures.

**Prototype exception:** PS1 retexturing is a post-prototype task (Week 4+). The prototype uses Kenney library assets raw and grey-box placeholder objects where models aren't available. Mechanics are proven before aesthetics are refined.

### Tone — Cozy-Uncanny

The game sits at the intersection of comfortable and slightly wrong. Inspired by Twin Peaks: warm but off, familiar but strange. Specific implementations:

- Customers are slightly too still when waiting. Their idle animation loops a beat too long.
- The radio in the truck occasionally plays a few seconds of reversed speech, then returns to normal.
- The ambient crowd noise outside fades correctly except for one laugh that loops slightly out of time.
- The light above the prep counter flickers once per minute for half a second. Then nothing.

These cost 1–2 days of implementation. They are the single biggest ROI for tone on minimal budget.

### Colour Logic

| Zone | Palette | Purpose |
|------|---------|---------|
| Truck interior | Warm amber + cream | Kitchen comfort, safety |
| Customer queue (through window) | Cooler, slightly desaturated | Outside vs inside contrast |
| Interaction feedback — perfect | Bright green | Universal positive |
| Interaction feedback — sloppy | Amber/orange | Warning, recoverable |
| Interaction feedback — fail | Red | Stop, wrong, penalty |
| UI elements | White + gold on dark | Legible, slightly luxe |

### Asset List (Prototype)

**Environment**
- Truck interior (counter, walls, window, floor)
- Trompo (vertical meat spit with meat block)
- Sauce bottles (red and white, distinct shapes)
- Topping bins (three: cilantro, tomato, onion)
- Tortilla stack
- Service bell
- Serving tray / window ledge
- Wall clock (mirrors day timer)

**Characters**
- Customer base model (Kenney library — low-poly humanoid)
- Patience arc (world-space UI above head)
- Speech bubble (world-space, shows ingredient icons)

**Food Items**
- Tortilla (in-hand and placed states)
- Meat (shaved portion)
- Sauce pour (particle stream — GPUParticles3D)
- Topping items (cilantro, tomato, onion — floor drop state)
- Assembled taco (final served state)

### Audio Requirements

**Music**
- Gameplay loop: lo-fi diner jazz with a subtle unsettling undertone. Upbeat enough to maintain rhythm, strange enough to maintain vibe.
- End-of-day screen: slower, contemplative. One instrument drops out.

**SFX**
- Mash (per press): rhythmic scrape/sizzle
- Sauce hold: wet hiss; warning tone on over-pour
- Sauce release — perfect: clean squirt + short positive note
- Sauce release — sloppy: splatter + dull note
- Topping hit: satisfying thud/crunch
- Topping miss: drop + floor bounce
- Bell ring: clean, bright ding
- Order complete: warm register chime
- Order rejected: buzzer + disappointed murmur
- Customer leaves (patience): door slam + muttering
- Penalty deduction: brief low tone

---

## 13. Technical Architecture

### Core Principles

- **GDScript only.** No C#. Required for Web/WASM build size and compatibility.
- **Signal Up, Call Down.** Components emit signals to their direct parent. No sibling-to-sibling signal connections.
- **EventBus for cross-system events.** All game-wide state changes route through `EventBus.gd`.
- **Resources for all data.** Recipes, upgrade stats, pricing, and difficulty schedule defined in `.tres` files. Nothing hardcoded in script.
- **Object pooling.** Pre-instantiate all food item nodes at scene load. Recycle on serve or trash. Never `queue_free()` during gameplay.

### Autoloads

| Singleton | Responsibility |
|-----------|---------------|
| `EventBus.gd` | Global signals: `order_accepted`, `order_completed`, `order_rejected`, `day_ended`, `upgrade_purchased`, `balance_changed` |
| `GameManager.gd` | Day state (tutorial / playing / end-of-day), timer, phase transitions |
| `EconomyManager.gd` | Bank balance, all debits/credits, end-of-day tally, $0 floor enforcement |
| `NodePool.gd` | Object pool — checkout/return for all food items and NPC nodes |

### Object Pool Sizes

| Pool | Count | Notes |
|------|-------|-------|
| Tortilla nodes | 10 | 3 active max + buffer |
| Shaved meat portions | 20 | Per-mash particle items |
| Sauce stream (GPUParticles3D) | 50 | Shared between red/white |
| Topping items (per type) | 15 each | Floor drop + persistence |
| Customer NPC nodes | 5 | 3 active + 2 refill buffer |

### Input State Machine

A single `InteractionStateMachine` on the player controller routes all **interaction** input. WASD movement is handled separately in `TruckPlayer.gd` and does **not** interrupt any active interaction state — the player can continue mashing, holding, or timing while walking.

```
IDLE
  └─ (cursor enters station Area3D) → HOVER
       └─ (click) → ACTIVE
            ├─ station.interaction_type == MASH    → MASH_INTERACTION
            ├─ station.interaction_type == HOLD    → HOLD_INTERACTION
            ├─ station.interaction_type == TIMING  → TIMING_INTERACTION
            └─ station.interaction_type == INSTANT → INSTANT_INTERACTION
                                                       └─ (completes immediately) → IDLE
```

Each station declares its interaction type as an exported `enum` value. The state machine reads the type and routes accordingly. Stations never check their own input type — the state machine owns input context entirely.

### Core Signal Flow

```
SnapZone.item_snapped → TruckStation → OrderManager.complete_step
OrderManager.step_completed → ObjectiveHUD.update_pill_state
Bell.rung → OrderManager.validate_order
  ├─ (complete) → EconomyManager.process_payment → EventBus.order_completed
  └─ (incomplete) → BellConfirmationPopup.show
       └─ (confirmed) → EconomyManager.deduct_food_cost → EventBus.order_rejected
GameManager.day_ended → EndOfDayScreen.show → EconomyManager.tally_day
```

### Timing Mechanic — Web Safety

All time-sensitive interactions use `_physics_process` only:
- Shrinking circle logic on fixed timestep
- Audio feedback fires *after* visual confirmation — never used as sync reference
- Timing windows are 30% wider than native equivalents
- **Week 1 spike:** build shrinking circle as first standalone test and verify feel in Chrome before proceeding

### Save System

**Format:** Single JSON file at `user://save.json` (maps to `IndexedDB` on web via Godot `FileAccess`).

```json
{
  "current_day": 4,
  "balance": 42.50,
  "upgrades": ["sharper_knife"],
  "stats": {
    "total_orders_completed": 23,
    "total_orders_rejected": 2,
    "total_tips_earned": 12.50,
    "best_day_earnings": 32.00
  }
}
```

**Auto-save:** Triggers automatically on the end-of-day screen, before any player input. The `[Save & Exit]` button returns to the main menu. Auto-save means tab crashes never cause progress loss.

**Size budget:** <4KB. All recipe, upgrade, and pricing data lives in bundled `.tres` Resources — never serialised to the save file.

### Browser Compatibility

| Browser | Version | Tier |
|---------|---------|------|
| Chrome | 110+ | Primary — test daily |
| Firefox | 110+ | Primary — test weekly |
| Edge | 110+ | Secondary — Chromium parity assumed |
| Safari | Latest | Best-effort — test pre-launch |
| Mobile browsers | — | Out of scope for prototype |

---

## 14. Development Timeline

### Week 1 — Interactions

| #   | Task                                                                                                           | Type |
| --- | -------------------------------------------------------------------------------------------------------------- | ---- |
| 1   | Truck interior scene. Two-sided station layout (front/back). WASD player movement. Mouse-look (unclamped yaw). | Code |
| 2   | **SPIKE: Shrinking circle interaction — test on web in Chrome. Verify feel.**                                  | Code |
| 3   | Tortilla grab (click → spawns in hand) — back counter station                                                  | Code |
| 4   | Meat mash (button mash → radial bar → meat added) — back counter station                                       | Code |
| 5   | Sauce power bar (hold → three-zone outcome) — front counter station                                            | Code |
| 6   | Topping shrinking circle (timing → place or drop) — front counter station                                      | Code |

### Week 2 — Loop

| # | Task | Type |
|---|------|------|
| 7 | Bell + order validation (confirmation popup on incomplete) | Code |
| 8 | Order system: procedural recipe generation, HUD ingredient pills with state feedback | Code |
| 9 | Customer queue: 3 NPCs, patience arcs, one-order-at-a-time acceptance | Code |
| 10 | Economy manager: all credits/debits, $0 floor, live balance display | Code |
| 11 | Day timer (5 min), end-of-day screen, basic tally display | Code |

### Week 3 — Polish & Ship

| # | Task | Type |
|---|------|------|
| 12 | Day 0 tutorial: scripted 5-order sequence, guided prompts, no timer | Code |
| 13 | Upgrade shop, day loop (next day loads with difficulty schedule), save/load | Code |
| — | Web export. Chrome + Firefox testing. 60 FPS pass. Audio latency verification. | QA |
| — | Kenney asset swap (replace grey boxes where models exist). Placeholder audio (beeps). | Art/Audio |

### Art Strategy

All art is placeholder for the 3-week prototype. Grey-box labelled objects where models don't exist. Kenney library assets used raw, no PS1 retexture. One customer NPC model from Kenney, no animation beyond idle. PS1 aesthetic and custom assets are a post-prototype pass.

### Stretch Goals

| # | Feature | Type |
|---|---------|------|
| 1 | Customer archetypes (Picky / Chill) | Code |
| 2 | Particle effects — sauce stream, meat fall, topping drop | Art/Code |
| 3 | Second truck type (Shawarma or Burger) | Code/Art |
| 4 | Driving / travel screen between locations | Code |
| 5 | Narrative layer — mid-life crisis story beats between days | Code |
| 6 | Additional upgrades (topping timing assist, patience extender) | Code |

---

## 15. Out of Scope (Prototype)

| Feature | Status |
|---------|--------|
| Driving / third-person vehicle mode | Post-prototype |
| City map / location selection | Post-prototype |
| Multiple truck types | Post-prototype |
| PS1 retexture / custom art pass | Post-prototype (Week 4+) |
| Customer archetypes (Picky / Chill) | Stretch goal |
| Particle system polish | Stretch goal |
| Narrative / story beats between days | Post-prototype |
| Mobile / controller input | Out of scope |
| Soundtrack (original music) | Post-prototype |
| Customer dialogue | Post-prototype |

---

## 16. Open Questions

1. **Order sequencing:** Does the recipe enforce ingredient order (meat before sauce before toppings), or can the player add in any sequence? Current assumption: any order. To be resolved in playtesting.
2. **Topping retry quality:** If a player drops a topping and retries successfully, does the orange sloppy flag apply? Current answer: yes — the first miss sets the flag permanently for that topping.
3. **Weird customer frequency:** One unusual order per day from Day 3 onward — how unusual? Needs playtesting before spec.
4. **Sound design brief:** Complete audio pass requires a decision on DAW and whether music is licensed or original.
