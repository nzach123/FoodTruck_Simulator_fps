# Systems Architecture

Technical implementation tracking for Midnight Munch.

---

## Planned Systems (from GDD)

### EventBus
**Status:** Planned
**Files:** `scripts/autoloads/EventBus.gd`
**Dependencies:** None (foundational)

#### Overview
Global signal bus for cross-system communication.

#### Signals
- `order_accepted` — Player accepts a customer order
- `order_completed` — Order successfully served
- `order_rejected` — Customer rejects incomplete order
- `day_ended` — 5-minute timer expires
- `upgrade_purchased` — Player buys upgrade
- `balance_changed` — Bank balance modified

---

### GameManager
**Status:** Planned
**Files:** `scripts/autoloads/GameManager.gd`
**Dependencies:** EventBus

#### Overview
Day state machine controlling game phases.

#### States
- `TUTORIAL` — Day 0, scripted sequence
- `PLAYING` — Active gameplay, timer running
- `END_OF_DAY` — Results screen, upgrade shop

---

### EconomyManager
**Status:** Planned
**Files:** `scripts/autoloads/EconomyManager.gd`
**Dependencies:** EventBus

#### Overview
Handles all monetary transactions.

#### Key Features
- Bank balance tracking
- $0 floor enforcement
- Tip calculation (0/1/2+ sloppy flags)
- Food cost deduction on rejection

---

### NodePool
**Status:** Planned
**Files:** `scripts/autoloads/NodePool.gd`
**Dependencies:** None

#### Overview
Object pooling for all recyclable game objects.

#### Pool Sizes (per GDD)
- Tortilla nodes: 10
- Shaved meat portions: 20
- Sauce stream particles: 50
- Topping items (per type): 15
- Customer NPC nodes: 5

---

### Input State Machine
**Status:** Planned
**Files:** `scripts/input/InputStateMachine.gd`
**Dependencies:** Station components

#### Overview
Central input handler with context-aware state.

#### States
```
IDLE → HOVER → ACTIVE → [MASH|HOLD|TIMING|INSTANT]_INTERACTION
```

---

## Implemented Systems

### TruckStation (Base Class)
**Status:** Implemented (Task 1.3)
**File:** `_src/interactables/base/TruckStation.gd`
**Class name:** `TruckStation`
**Dependencies:** None

#### Overview
Base class for all cooking stations. Defines the `InteractionType` enum, export vars, signals, and virtual callback stubs. No interaction logic — that lives exclusively in `InteractionStateMachine`.

#### InteractionType Enum
- `INSTANT` — single click, immediate completion (Tortilla, Bell)
- `MASH` — button mash fills bar (Trompo)
- `HOLD` — hold to fill gauge (Sauce stations)
- `TIMING` — shrinking circle click (Topping stations)

#### Signals
- `station_hovered(station)` — reserved for future prompt/tutorial system
- `station_unhovered(station)` — reserved
- `interaction_completed(station, result: Dictionary)` — key signal consumed by OrderManager

---

### InteractionStateMachine
**Status:** Implemented (Task 1.3)
**File:** `_src/player/InteractionStateMachine.gd`
**Dependencies:** TruckStation (class_name), RayCast3D (export), EconomyManager (autoload — guarded)

#### Overview
Owns all player interaction input context. Lives as a child of TruckPlayer. Uses a RayCast3D to detect stations on physics layer 3. All timing logic in `_physics_process` (web-safe). No `await`.

#### States
`IDLE → HOVER → ACTIVE → MASH | HOLD | TIMING`

#### Key Constants (web-tuned)
- `TIMING_SHRINK_SPEED = 220.0` px/s (30% slower than native)
- `TIMING_TARGET_MIN/MAX = 80–130` px (30% wider window)
- `HOLD_GREEN_MIN/MAX = 0.45–0.75`
- `MASH_PER_PRESS = 0.2`, `MASH_THRESHOLD = 1.0`

#### Signals Emitted
- `crosshair_state_changed(state: String)` — "idle" / "hover" / "active"
- `hold_progress_changed(progress: float)`
- `mash_progress_changed(progress: float)`
- `timing_radius_changed(radius: float)`
- `station_focus_entered(station)` / `station_focus_exited(station)`

#### Pending Wiring (manual editor step)
- `ray_cast` export must be wired to a `RayCast3D` (layer 3, length 3.0 m) in TruckPlayer.tscn
- All output signals must be connected to HUD nodes

---

### SauceStation
**Status:** Implemented (Task 1.3 — color/visual layer only; full HOLD logic Task 1.7)
**File:** `_src/interactables/SauceStation.gd`
**Scene:** `_src/interactables/SauceStation.tscn`
**Dependencies:** TruckStation, EventBus

#### Overview
Extends TruckStation. Sets CSG cylinder material color at `_ready()` from `@export var sauce_color`. On completion emits `interaction_completed` + `EventBus.order_step_completed`.

---

### ToppingStation
**Status:** Implemented (Task 1.3 — color/visual layer only; full TIMING logic Task 1.6)
**File:** `_src/interactables/ToppingStation.gd`
**Scene:** `_src/interactables/ToppingStation.tscn`
**Dependencies:** TruckStation, EventBus

#### Overview
Extends TruckStation. Sets CSG box material color at `_ready()` from `@export var topping_color`. Supports Cilantro, Tomato, Onion via per-instance color + ingredient_id export overrides.
