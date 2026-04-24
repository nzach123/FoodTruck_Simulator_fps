# Midnight Munch - Technical Implementation Plan

## High-Level Strategy
The development of "Midnight Munch" will follow a bottom-up approach, prioritizing the stability and feel of the core physical cooking interactions (mash, hold, timing, click) before layering on meta-systems like the economy and progression. Given the strict 3-week prototype scope and web-target constraints, Godot 4.6 (GDScript only) will be utilized with a rigid object pooling system from day one to prevent garbage collection spikes. The architecture will strictly enforce a "Signal Up, Call Down" hierarchy, relying on global Autoloads (`EventBus`, `GameManager`, `EconomyManager`, `NodePool`) to decouple systems and manage game state safely. All data (recipes, upgrades) will be data-driven via Godot Resources (`.tres`), ensuring minimal hardcoding and a lightweight `user://save.json` implementation.

## Development Phases

### Phase 1: Core Mechanics & Foundation
**Objective:** Establish the environment blockout and prove out the core, web-safe physical cooking interactions.
This phase focuses entirely on the player's immediate tactile experience behind the counter. The interaction state machine and input primitives must be robust before complex rules are added. 

### Phase 2: Game Loop, Triage & Serving
**Objective:** Implement the procedural order system, customer queue, and triage mechanics.
This phase transforms the isolated cooking mechanics into a game by introducing the cognitive load of reading orders, managing customer patience, and assembling the correct ingredients under pressure.

### Phase 3: Progression & Persistence
**Objective:** Implement the economy, day loop, upgrades, and save system.
This phase introduces the meta-game, tying individual days together through persistent progression, balancing the tension of the $0 floor with the satisfaction of purchasing upgrades.

### Phase 4: Onboarding & Polish
**Objective:** Finalize the tutorial, integrate audio, and validate the web build.
The final phase focuses on smoothing the player experience with a guided, penalty-free onboarding day, followed by a rigorous QA pass to ensure the timing interactions remain fair and responsive in browser environments.

## Prioritized Task List

### Phase 1: Core Mechanics & Foundation
- [ ] **Task 1.1:** Initialize Godot 4.6 project, configure web export settings, and define global Autoloads (`EventBus`, `GameManager`, `EconomyManager`, `NodePool`).
- [ ] **Task 1.2:** Block out the Truck Interior scene (180° clamped mouse-look camera, basic interactable Area3D setup).
- [ ] **Task 1.3:** Build the `InteractionStateMachine` (Idle -> Hover -> Active -> [Primitive]).
- [ ] **Task 1.4:** **SPIKE:** Implement the Shrinking Circle mechanic (Toppings) via `_physics_process` and validate input latency on Chrome/Firefox.
- [ ] **Task 1.5:** Implement the Click/Grab mechanic (Tortillas) and persistent held-item HUD.
- [ ] **Task 1.6:** Implement the Button Mash mechanic (Meat Trompo) with radial progress bar logic.
- [ ] **Task 1.7:** Implement the Power Bar mechanic (Sauces) with 3-zone outcome validation.

### Phase 2: Game Loop, Triage & Serving
- [ ] **Task 2.1:** Implement the `NodePool` to handle dynamic pre-instantiation and recycling of food items and NPCs.
- [ ] **Task 2.2:** Build the `OrderManager` and procedural recipe generation logic (utilizing Resource `.tres` files).
- [ ] **Task 2.3:** Implement the Order HUD Panel with live ingredient state updates (Grey, White, Green, Orange, Red).
- [ ] **Task 2.4:** Develop the Customer Queue (up to 3 NPCs, patience arcs, speech bubble instantiation).
- [ ] **Task 2.5:** Implement Order Acceptance logic (locking order to HUD, isolating triage from the queue).
- [ ] **Task 2.6:** Implement the Bell Service logic (validation against recipe, confirmation popup for incomplete orders).

### Phase 3: Progression & Persistence
- [ ] **Task 3.1:** Implement the Day Timer (5-minute clock) and day state transitions within `GameManager`.
- [ ] **Task 3.2:** Build the `EconomyManager` (process payments, tips based on sloppy flags, deductions, $0 floor bail-out).
- [ ] **Task 3.3:** Implement the End-of-Day Screen and next-day difficulty progression scaling.
- [ ] **Task 3.4:** Build the Upgrade Shop (Sharper Knife, Better Sauce Bottle logic hooks).
- [ ] **Task 3.5:** Implement the `user://save.json` serialization for day, balance, and upgrades.

### Phase 4: Onboarding & Polish
- [ ] **Task 4.1:** Develop the Day 0 Tutorial sequence (scripted 5-order queue, infinite patience, guided world-space prompts).
- [ ] **Task 4.2:** Integrate placeholder Audio (latency-safe triggering for SFX, looping music).
- [ ] **Task 4.3:** Conduct final balancing pass and implement placeholder Kenney 3D models.
- [ ] **Task 4.4:** Final QA web export validation (60 FPS minimum, memory leak check).

## Estimated Schedule
*Assuming a standard indie development pace (1 developer) to hit the 3-week prototype scope.*

- **Week 1:** Complete Phase 1 (Core Mechanics & Foundation). Major milestone is the successful WebGL spike of the timing mechanic.
- **Week 2:** Complete Phase 2 (Game Loop, Triage) and begin Phase 3 (Economy). Major milestone is successfully taking an order, cooking it, and ringing the bell for money.
- **Week 3:** Complete Phase 3 (Progression) and Phase 4 (Tutorial & Polish). Final milestone is an end-to-end playable web build with persistent saving.
