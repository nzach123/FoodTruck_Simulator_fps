# Midnight Munch — Technical Implementation Plan

**Engine:** Godot 4.6 (GDScript only) | **Target:** Web/WASM, 60 FPS | **Framework:** COGITO v1.1
**Core scene:** `res://_src/levels/TruckInterior.tscn`

## Project Summary

Midnight Munch is a first-person cozy taco-truck cooking simulator built on the COGITO FPS framework. The player assembles tacos using four physical interaction primitives (Click, Mash, Hold, Timing), serves customers under a 5-minute day timer, and grows a bank balance across a 7-day difficulty arc. This plan extends the existing scaffold (autoloads, ISM, station base, three working stations, shrinking-circle HUD) to a full vertical slice.

**Already in place:**
- Autoloads: `EventBus`, `GameManager`, `EconomyManager`, `NodePool`
- ISM with HOVER/ACTIVE/MASH/HOLD/TIMING states + web-tuned constants
- `TruckStation` base class + virtual lifecycle
- `SauceStation`, `ToppingStation` (working), plus `TortillaStation.tscn`, `TrompoStation.tscn`, `BellStation.tscn` placeholders
- `ShrinkingCircle` HUD overlay wired to ISM
- Resource scripts: `DayConfig`, `EconomyConfig`, `RecipeData`, `UpgradeData`

**To build:** `OrderManager`, `QueueManager`, `TacoBase`, `CustomerNPC`, `BellStation` validator, full HUD, end-of-day screen, audio, save integration.

---

## Phase 1 — Project Setup & Core Controller Verification

Goal: prove the existing skeleton runs end-to-end before adding gameplay systems on top.

### Task 1.1 — Verify COGITO Player Movement & Raycast Hover

Confirm the COGITO player in `TruckInterior.tscn` walks freely inside the truck and that the `InteractionRaycast` correctly hits stations on physics layer 3.

- [ ] Run `TruckInterior.tscn` directly from the editor (F6)
- [ ] Confirm WASD locomotion works inside the truck; collisions block exit through `CSGBody`
- [ ] Confirm the camera-mounted `RayCast3D` reports `is_colliding()` when the crosshair is on a station collider (add a temp `print()` in `InteractionStateMachine._update_hover()` if needed; gate behind `OS.is_debug_build()`)
- [ ] Confirm `station_focus_entered` signal fires on hover (subscribe a temp `print` in `_on_hover_enter`)
- [ ] Confirm collision masks: stations are on physics layer 3, raycast mask matches
- [ ] Remove any temporary debug prints before committing

### Task 1.2 — Verify Shrinking Circle Timing on Topping Station

Confirm the HOLD/TIMING ISM branch resolves correctly through `ToppingStation` to `EventBus.order_step_completed`.

- [ ] Hover the Cilantro station, press `mm_interact`
- [ ] Confirm the `ShrinkingCircle` overlay appears, ring shrinks at ~220 px/s
- [ ] Press `mm_interact` inside target band → `ToppingStation.on_interaction_complete(2)` runs
- [ ] Press outside band → ISM calls `EconomyManager.debit(0.05, "timing_miss")` and resets to HOVER
- [ ] Connect a temp listener to `EventBus.order_step_completed(ingredient_id, quality)` and verify both arguments
- [ ] Verify `crosshair_state_changed` toggles `idle`/`hover`/`active` in the HUD overlay

### Task 1.3 — Wire Sauce Station HOLD Loop End-to-End

Same verification for the Sauce station.

- [ ] Hover White Sauce, press-and-hold `mm_interact`
- [ ] Verify `hold_progress_changed` ticks 0.0 → 1.0 at 0.4/s
- [ ] Release in green band (0.45–0.75) → quality 2 (PERFECT)
- [ ] Release after 0.75 → quality 3 (SLOPPY)
- [ ] Release before 0.45 → no completion, returns to HOVER (under-pour retry)

### Task 1.4 — Sanity-Check Autoload Order

`EventBus` must initialise before any system that emits during `_ready()`.

- [ ] Open Project Settings → Autoload tab `[EDITOR]`
- [ ] Confirm order: `EventBus` → `GameManager` → `EconomyManager` → `NodePool` → COGITO autoloads
- [ ] Resolve any push_warning logs about missing config resources by creating placeholder `.tres` files

---

## Phase 2 — Ingredient & Cooking Systems

Goal: every cooking station produces a typed result that funnels into a single in-hand `TacoBase` carriable.

### Task 2.1 — IngredientState Enum & TacoBase Resource

Centralise the quality-state enum (currently magic numbers 2/3/4) and define the in-hand taco data model.

**New file:** `res://_src/data/IngredientState.gd`

```gdscript
class_name IngredientState
extends RefCounted

enum State {
    UNADDED = 0,
    PULSING = 1,
    PERFECT = 2,
    SLOPPY  = 3,
    MISSING = 4,
}
```

**New file:** `res://_src/entities/food/TacoBase.gd`

```gdscript
class_name TacoBase
extends Node3D

signal ingredient_added(ingredient_id: String, quality: int)

var ingredients: Dictionary = {}  # { "tortilla": IngredientState.PERFECT, ... }

func reset() -> void: ingredients.clear()
func add_ingredient(ingredient_id: String, quality: int) -> void
func has_ingredient(ingredient_id: String) -> bool
func get_quality(ingredient_id: String) -> int
func get_sloppy_count() -> int
func get_ingredient_ids() -> Array[String]
```

- [ ] Create `res://_src/data/IngredientState.gd`
- [ ] Create `res://_src/entities/food/TacoBase.gd` extending `Node3D`
- [ ] Create `res://_src/entities/food/TacoBase.tscn` with a placeholder `MeshInstance3D` (low-poly tortilla disc)
- [ ] Add scene path to `NodePool.PREWARM_CONFIG` with count 3
- [ ] Replace literal `2`/`3` quality values in `SauceStation`, `ToppingStation`, ISM with `IngredientState.State.PERFECT` / `.SLOPPY`
- [ ] Implement `reset()` so `NodePool._reset_node()` calls it on return

### Task 2.2 — TortillaStation: INSTANT Spawns TacoBase

Make the existing `TortillaStation.tscn` produce a `TacoBase` from `NodePool` and attach it to the player's hand slot.

**New file:** `res://_src/interactables/TortillaStation.gd`

```gdscript
class_name TortillaStation
extends TruckStation

const TACO_SCENE_PATH: String = "res://_src/entities/food/TacoBase.tscn"

func _ready() -> void:
    interaction_type = InteractionType.INSTANT
    interaction_prompt_text = "Take Tortilla"
    display_name = "Tortillas"

func on_interaction_complete(result: int) -> void:
    EventBus.order_step_completed.emit("tortilla", result)
    EventBus.tortilla_taken.emit()  # OrderManager listens, attaches taco to player hand
```

- [ ] Create `res://_src/interactables/TortillaStation.gd`
- [ ] Attach the script to `TortillaStation.tscn` root
- [ ] Add `signal tortilla_taken()` to `EventBus.gd`
- [ ] `OrderManager` (Phase 4) will checkout `TacoBase` from `NodePool` and parent to player hand on this signal

### Task 2.3 — TrompoStation: MASH Implementation

Wire the existing `TrompoStation.tscn` to MASH; gate it on `requires_held_item`.

**New file:** `res://_src/interactables/TrompoStation.gd`

```gdscript
class_name TrompoStation
extends TruckStation

func _ready() -> void:
    interaction_type = InteractionType.MASH
    interaction_prompt_text = "Shave Meat"
    display_name = "Trompo"
    requires_held_item = true

func on_interaction_complete(result: int) -> void:
    EventBus.order_step_completed.emit("meat", result)
```

- [ ] Create the script and attach to `TrompoStation.tscn`
- [ ] In `InteractionStateMachine._start_interaction()`, add a guard: if `active_station.requires_held_item` and `OrderManager` has no active taco, return early to HOVER and emit `station_blocked(reason: String)`
- [ ] Add `signal station_blocked(reason: String)` to ISM (HUD listener flashes prompt)
- [ ] Apply per-day mash count via `DayConfig.mash_presses_required`: ISM reads `GameManager.difficulty_config.mash_presses_required` in `_start_interaction()`

### Task 2.4 — SauceStation: Confirm HOLD Outcomes & Wire to TacoBase

Existing script already handles HOLD. Extend `on_interaction_complete()` to write into the active taco.

- [ ] Modify `res://_src/interactables/SauceStation.gd` — `on_interaction_complete()` continues to emit `EventBus.order_step_completed`; `OrderManager` (Phase 4) is the canonical writer to `TacoBase`
- [ ] Verify `_evaluate_hold()` thresholds match GDD: 0.45 = green min, 0.75 = green max
- [ ] Confirm under-pour returns to HOVER without emitting

### Task 2.5 — ToppingStation: Drop Penalty & Floor Despawn

Existing miss path already debits $0.05. Add the dropped-topping floor visual.

**New file:** `res://_src/entities/food/ToppingItem.gd`

```gdscript
class_name ToppingItem
extends RigidBody3D

const DESPAWN_AFTER: float = 10.0
var _timer: float = 0.0

func reset() -> void:
    freeze = false
    linear_velocity = Vector3.ZERO
    angular_velocity = Vector3.ZERO
    _timer = 0.0

func _physics_process(delta: float) -> void:
    if not visible: return
    _timer += delta
    if _timer >= DESPAWN_AFTER:
        NodePool.ret(self)
```

- [ ] Create `ToppingItem.gd` and `ToppingItem.tscn` (small `MeshInstance3D` + `CollisionShape3D`)
- [ ] Confirm scene path matches `NodePool.PREWARM_CONFIG` entry `res://_src/entities/food/ToppingItem.tscn` (count 15 already configured)
- [ ] Modify `res://_src/player/InteractionStateMachine.gd` — in `_on_timing_miss()`, checkout a `ToppingItem` from `NodePool` and place it in front of the active station (`active_station.global_position + Vector3.UP * 0.1`)
- [ ] Use `_physics_process` for despawn — never `await` or `Timer`

---

## Phase 3 — Customer AI & Queue Logic

Goal: customers spawn through `QueueManager`, hold a `TacoTicket`, drain patience, and emit lifecycle signals.

### Task 3.1 — TacoTicket Resource

Per-customer order data.

**New file:** `res://_src/data/recipes/TacoTicket.gd`

```gdscript
class_name TacoTicket
extends Resource

@export var required_ingredients: Array[String] = []  # always_ + selected optional_
@export var is_weird: bool = false                    # Day 3+ unusual orders
@export var patience_seconds: float = 60.0            # copied from DayConfig at spawn
@export var customer_archetype: String = "standard"
```

- [ ] Create the script
- [ ] Add a static factory: `static func generate(recipe: RecipeData, day_config: DayConfig, allow_weird: bool) -> TacoTicket`
- [ ] Factory uses `randi_range()` to pick 0–N optional ingredients capped by `recipe.max_optional_count`

### Task 3.2 — CustomerNPC Scene & Script

Stripped-down NPC; not a COGITO NPC subclass — uses pooled `Node3D` only.

**New file:** `res://_src/entities/customer/CustomerNPC.gd`
**New file:** `res://_src/entities/customer/CustomerNPC.tscn`

```gdscript
class_name CustomerNPC
extends Node3D

enum CustomerState { IDLE, WAITING, ACCEPTED, LEAVING_HAPPY, LEAVING_ANGRY }

signal patience_expired(customer: CustomerNPC)
signal accepted(customer: CustomerNPC)
signal departed(customer: CustomerNPC)

var ticket: TacoTicket = null
var state: CustomerState = CustomerState.IDLE
var patience_remaining: float = 0.0
var queue_slot_index: int = -1

func reset() -> void
func assign_ticket(t: TacoTicket) -> void
func _physics_process(delta: float) -> void
```

- [ ] Create script + scene (placeholder `MeshInstance3D` capsule, `Node3D` `SpeechBubbleAnchor`)
- [ ] Patience countdown in `_physics_process`; when ≤ 0, emit `patience_expired` and set `LEAVING_ANGRY`
- [ ] Confirm scene path matches `NodePool.PREWARM_CONFIG` entry — rename prewarm key to `res://_src/entities/customer/CustomerNPC.tscn` in `NodePool.gd`
- [ ] Implement `reset()` so the pool can recycle: clear `ticket`, set state to `IDLE`, hide

### Task 3.3 — QueueManager Autoload

Owns customer spawning, queue slot assignment, and patience enforcement.

**New file:** `res://_src/autoloads/QueueManager.gd`

```gdscript
extends Node

const MAX_QUEUE_SIZE: int = 3
const CUSTOMER_SCENE: String = "res://_src/entities/customer/CustomerNPC.tscn"

var active_customers: Array[CustomerNPC] = []
var pending_ticket: TacoTicket = null  # the customer the player has accepted
var _spawn_timer: float = 0.0
var _queue_slots: Array[Node3D] = []   # set by TruckInterior on _ready

func register_slots(slots: Array[Node3D]) -> void
func start_day(day_config: DayConfig) -> void
func stop_day() -> void
func accept_customer(c: CustomerNPC) -> void
func _spawn_next_customer() -> void
func _on_customer_patience_expired(c: CustomerNPC) -> void
```

- [ ] Create the script
- [ ] Register in Project Settings → Autoload as `QueueManager` (after `EconomyManager`, before COGITO autoloads) `[EDITOR]`
- [ ] `_physics_process` ticks `_spawn_timer` against `day_config.spawn_interval`
- [ ] Connect to `EventBus.day_started` → `start_day(GameManager.difficulty_config)`
- [ ] Connect to `EventBus.day_ended` → `stop_day()`
- [ ] On patience expiry: `EconomyManager.debit(penalty_patience, "patience_expired")` then `EventBus.customer_left.emit(penalty)` then `NodePool.ret(customer)`

### Task 3.4 — Day 1–7 Difficulty Schedule Resource

Concrete `.tres` files matching the GDD difficulty table.

**New files:** `res://_src/data/difficulty/Day0_Tutorial.tres` through `Day7_Plus.tres`
**New file:** `res://_src/data/difficulty/DifficultySchedule.gd`
**New file:** `res://_src/data/difficulty/DifficultySchedule.tres`

```gdscript
class_name DifficultySchedule
extends Resource

@export var days: Array[DayConfig] = []
```

- [ ] Create `DifficultySchedule.gd` resource class
- [ ] Create 8 `DayConfig.tres` files in editor with values from GDD table `[EDITOR]`:
  - Day 0: patience 9999, spawn 999, max_concurrent 1, allow_optional false
  - Day 1: 60 / 45 / 2 / false
  - Day 2: 55 / 40 / 2 / true
  - Day 3: 50 / 35 / 3 / true
  - Day 4: 45 / 30 / 3 / true
  - Day 5: 40 / 25 / 3 / true
  - Day 6: 35 / 22 / 3 / true
  - Day 7: 30 / 20 / 3 / true
- [ ] Build `DifficultySchedule.tres` with `days = [day0, day1, ..., day7]`
- [ ] Confirm `GameManager._load_difficulty_schedule()` resolves without push_error

### Task 3.5 — Queue Slot Anchors in TruckInterior

Add three `Marker3D` nodes near the serving window for customer positions.

- [ ] Modify `res://_src/levels/TruckInterior.tscn` — add `QueueAnchors/Slot0/Slot1/Slot2` `Marker3D` nodes outside the truck window
- [ ] Create `TruckInterior.gd` if not present; wire `_ready()` to call `QueueManager.register_slots([$QueueAnchors/Slot0, $QueueAnchors/Slot1, $QueueAnchors/Slot2])`
- [ ] Same `_ready()` calls `NodePool.register_container($NodePoolContainer)` then `NodePool.prewarm_all()`
- [ ] Add `NodePoolContainer` (Node) child of `TruckInterior` as pool parent

---

## Phase 4 — Game Loop & Economy

Goal: full Tortilla → Trompo → Sauce → Topping → Bell loop with economy and save.

### Task 4.1 — OrderManager Autoload

The single owner of the in-progress order. Listens to all stations via `EventBus`.

**New file:** `res://_src/autoloads/OrderManager.gd`

```gdscript
extends Node

var current_taco: TacoBase = null
var current_ticket: TacoTicket = null

signal taco_started(taco: TacoBase)
signal taco_cleared()

func _ready() -> void:
    EventBus.tortilla_taken.connect(_on_tortilla_taken)
    EventBus.order_step_completed.connect(_on_step_completed)
    EventBus.order_accepted.connect(_on_order_accepted)

func _on_tortilla_taken() -> void  # checkout TacoBase, attach to player hand
func _on_step_completed(ingredient_id: String, quality: int) -> void
func _on_order_accepted(customer: Node) -> void
func validate_against_ticket() -> Dictionary  # returns { complete: bool, missing: Array, sloppy_count: int }
func clear_active_order() -> void  # NodePool.ret(current_taco)
```

- [ ] Create the script
- [ ] Register as autoload after `QueueManager` `[EDITOR]`
- [ ] Add `HandAnchor` `Marker3D` under `CogitoPlayer/Body/Neck/Head/Eyes/Camera` in `TruckInterior.tscn`
- [ ] Cache the hand-anchor path via `get_tree().get_first_node_in_group("player_hand_anchor")`

### Task 4.2 — BellStation: Validation Trigger

Replace placeholder with a `TruckStation` INSTANT that triggers `OrderManager.validate_against_ticket()`.

**New file:** `res://_src/interactables/BellStation.gd`

```gdscript
class_name BellStation
extends TruckStation

func _ready() -> void:
    interaction_type = InteractionType.INSTANT
    interaction_prompt_text = "Ring Bell"
    display_name = "Bell"

func on_interaction_complete(_result: int) -> void:
    var validation: Dictionary = OrderManager.validate_against_ticket()
    if validation.complete:
        EconomyManager.process_payment(validation.sloppy_count)
        OrderManager.clear_active_order()
    else:
        EventBus.bell_missing_ingredients.emit(validation.missing)
```

- [ ] Create the script and attach to `BellStation.tscn` root
- [ ] Modify `BellStation.tscn` — remove `BasicInteraction` child; set `Hitbox` collision_layer 3 to match station raycast mask
- [ ] Add `signal bell_missing_ingredients(missing: Array)` and `signal bell_force_serve_confirmed()` to `EventBus.gd`
- [ ] HUD popup (Phase 5) listens to `bell_missing_ingredients` and emits `bell_force_serve_confirmed` on YES
- [ ] Connect `bell_force_serve_confirmed` in `BellStation` to call `EconomyManager.deduct_food_cost(current_taco.get_ingredient_ids())`

### Task 4.3 — OrderValidator (Inline on OrderManager)

```gdscript
# OrderManager.gd
func validate_against_ticket() -> Dictionary:
    if current_taco == null or current_ticket == null:
        return { "complete": false, "missing": [], "sloppy_count": 0 }
    var missing: Array[String] = []
    for ingredient_id: String in current_ticket.required_ingredients:
        if not current_taco.has_ingredient(ingredient_id):
            missing.append(ingredient_id)
    return {
        "complete": missing.is_empty(),
        "missing": missing,
        "sloppy_count": current_taco.get_sloppy_count(),
    }
```

- [ ] Add the method to `OrderManager.gd`
- [ ] Unit test: `tests/unit/test_order_validator.gd` — covers complete / missing-one / fully-sloppy cases

### Task 4.4 — Payment & Tip Pipeline

- [ ] Verify `EconomyManager._calculate_tip(0)` = 1.00, `_calculate_tip(1)` = 0.50, `_calculate_tip(2)` = 0.00
- [ ] Verify `debit()` floors at 0.0 (economy floor clamp — no negative balance)
- [ ] Confirm `EventBus.order_completed.emit(base, tip)` fires before `OrderManager.clear_active_order()`

### Task 4.5 — Save/Load via SaveManager

**New file:** `res://_src/autoloads/SaveManager.gd`

```gdscript
extends Node

const SAVE_PATH: String = "user://midnight_munch_save.tres"

func build_save_dict() -> Dictionary:
    return {
        "current_day": GameManager.current_day,
        "balance": EconomyManager.balance,
        "lifetime_stats": EconomyManager.get_lifetime_stats(),
    }

func save(data: Dictionary) -> void
func load_save() -> Dictionary
func has_save() -> bool
```

- [ ] Create script and register as autoload `[EDITOR]`
- [ ] `GameManager.end_day()` calls `SaveManager.save(SaveManager.build_save_dict())`
- [ ] On `MainMenu` `[Continue]` → `SaveManager.load_save()` → restore day + balance
- [ ] Use `ResourceSaver.save()` with a typed `Resource` wrapper (not raw Dictionary) for WASM safety

---

## Phase 5 — UI/UX

Goal: player-readable HUD, end-of-day screen, main menu reskin.

### Task 5.1 — Order HUD Panel (Top-Right)

Dynamic ingredient pills bound to current ticket + taco state.

**New file:** `res://_src/ui/OrderHUD.gd`
**New file:** `res://_src/ui/OrderHUD.tscn`
**New file:** `res://_src/ui/IngredientPill.gd`
**New file:** `res://_src/ui/IngredientPill.tscn`

```gdscript
# OrderHUD.gd
extends Control

@onready var pill_container: HBoxContainer = $PillContainer
const PILL_SCENE: PackedScene = preload("res://_src/ui/IngredientPill.tscn")

func _ready() -> void:
    EventBus.order_accepted.connect(_on_order_accepted)
    EventBus.order_step_completed.connect(_on_step_completed)
    EventBus.order_completed.connect(_on_order_completed)
```

```gdscript
# IngredientPill.gd
extends PanelContainer

@export var ingredient_id: String = ""

func set_state(state: int) -> void:
    # IngredientState.UNADDED  → grey outline
    # IngredientState.PULSING  → pulsing white tween
    # IngredientState.PERFECT  → green + checkmark
    # IngredientState.SLOPPY   → orange + tilde
    # IngredientState.MISSING  → red + X
    pass
```

- [ ] Create `IngredientPill` script + scene (`PanelContainer` with `Label` + `Icon`)
- [ ] Create `OrderHUD` script + scene (`Control` anchored top-right)
- [ ] Add `OrderHUD` instance to `MidnightMunchHUD` CanvasLayer in `TruckInterior.tscn`
- [ ] On `order_accepted`: clear and rebuild pills from `customer.ticket.required_ingredients`
- [ ] On `order_step_completed`: find pill by `ingredient_id` and call `set_state(quality)`
- [ ] Use `tween_property` for pulse animation — avoid `await`

### Task 5.2 — Bank Balance & Day Timer Labels

Header strip: balance left, timer right, day center.

**New file:** `res://_src/ui/HUDHeader.gd`
**New file:** `res://_src/ui/HUDHeader.tscn`

- [ ] Create script + scene with three `Label` children
- [ ] Connect `EventBus.balance_changed` → update balance label, flash green/red briefly
- [ ] In `_process()`, read `GameManager.get_timer_display()` for the timer label
- [ ] Connect `EventBus.day_started` → update day label

### Task 5.3 — End-of-Day Summary Screen

Full-screen panel shown on `EventBus.day_ended`.

**New file:** `res://_src/ui/EndOfDayScreen.gd`
**New file:** `res://_src/ui/EndOfDayScreen.tscn`

- [ ] Create as a `Control` with rows: tacos completed, attempted, sloppy %, base earnings, tips, total, current balance
- [ ] On `EventBus.day_ended`: pull `EconomyManager.tally_day()` and animate count-up via `_process`
- [ ] `[Continue]` button → `GameManager.start_day(current_day + 1)` and `EconomyManager.reset_day_stats()`
- [ ] `[Save & Exit]` → `SaveManager.save()` → load main menu
- [ ] `Input.MOUSE_MODE_VISIBLE` while panel visible; restore `MOUSE_MODE_CAPTURED` on close

### Task 5.4 — Main Menu Reskin

Replace COGITO demo menu visuals with Midnight Munch branding while keeping COGITO menu logic.

- [ ] Modify `res://_src/levels/MainMenu.tscn` — set background to placeholder neon-truck image, override COGITO theme colours
- [ ] `[New Game]` button → `GameManager.start_day(0)`
- [ ] `[Continue]` button visible only when `SaveManager.has_save()` returns true
- [ ] `[Continue]` calls `SaveManager.load_save()` then `GameManager.start_day(saved_day)`

### Task 5.5 — Confirm-Force-Serve Popup

Modal triggered by `EventBus.bell_missing_ingredients`.

**New file:** `res://_src/ui/ConfirmServePopup.gd`
**New file:** `res://_src/ui/ConfirmServePopup.tscn`

- [ ] `AcceptDialog` with dynamic body text listing missing ingredients
- [ ] YES → `EventBus.bell_force_serve_confirmed.emit()`
- [ ] NO → close, no signal
- [ ] Add to `MidnightMunchHUD` CanvasLayer

---

## Phase 6 — Audio & Polish

Goal: spatialised station audio, UI feedback sounds, finishing touches.

### Task 6.1 — Station 3D Audio

- [ ] Modify each station scene (`SauceStation.tscn`, `ToppingStation.tscn`, `TortillaStation.tscn`, `TrompoStation.tscn`, `BellStation.tscn`) — add `AudioStreamPlayer3D` child named `SFX` with `unit_size = 1.0`, `max_distance = 5.0`
- [ ] In each station script, add `func _play_sfx(stream: AudioStream, pitch_scale: float = 1.0) -> void`
- [ ] Trigger on `on_interaction_start` / `on_interaction_complete` callbacks

### Task 6.2 — Pitch-Shifted Sauce Pour Audio

- [ ] Modify `res://_src/interactables/SauceStation.gd` — in `on_interaction_tick(progress)`: `_sfx.pitch_scale = lerp(0.9, 1.3, progress)`
- [ ] On `on_interaction_complete`: play burst SFX, reset pitch to 1.0
- [ ] Source audio from `addons/cogito/Assets/Audio/Kenney/` (already in repo)

### Task 6.3 — UI Feedback Sounds

**New file:** `res://_src/ui/UIAudioPlayer.gd` (autoload)

- [ ] Create `UIAudioPlayer.gd` as autoload — listens to `EventBus` and routes sounds
- [ ] BellStation INSTANT click → Kenney `confirmation_001.ogg`
- [ ] Force-serve popup YES → Kenney `error_008.ogg`
- [ ] End-of-day count-up → soft tick per $1
- [ ] Customer patience expiry → low thud

### Task 6.4 — Visual Polish Pass

- [ ] Hover highlight: each station's `on_hover_enter()` lerps `_material.emission_energy` 0 → 0.4 over 0.1 s via `_physics_process` (no `Tween`)
- [ ] `on_hover_exit()` reverses the lerp
- [ ] Tip ticker: float `+$1.00` text up from BankBalance label on credit; pool via `NodePool`
- [ ] Crosshair colour: connect `ISM.crosshair_state_changed` to `Crosshair.gd` overlay (`idle` = white, `hover` = yellow, `active` = invisible)

---

## EventBus Signal Inventory (Final State)

### Already declared in `EventBus.gd`
```gdscript
signal order_accepted(customer: Node)
signal order_step_completed(ingredient_id: String, quality: int)
signal order_completed(payment: float, tip: float)
signal order_rejected(food_cost: float)
signal customer_left(penalty: float)
signal balance_changed(new_balance: float, delta: float)
signal day_started(day_number: int)
signal day_ended(day_number: int)
signal upgrade_purchased(upgrade_id: String)
signal tutorial_step_advanced(step_index: int)
```

### To add during this plan (modify `EventBus.gd`)
```gdscript
signal tortilla_taken()                              # Phase 2.2
signal bell_missing_ingredients(missing: Array)      # Phase 4.2
signal bell_force_serve_confirmed()                  # Phase 4.2
signal customer_arrived(customer: CustomerNPC)       # Phase 3.3
signal customer_accepted(customer: CustomerNPC)      # Phase 3.3
signal taco_attached_to_hand(taco: TacoBase)         # Phase 4.1
signal taco_returned()                               # Phase 4.1
```

---

## Autoload Registration Order (Final)

```
EventBus
GameManager
EconomyManager
NodePool
QueueManager      ← new (Phase 3.3)
OrderManager      ← new (Phase 4.1)
SaveManager       ← new (Phase 4.5)
UIAudioPlayer     ← new (Phase 6.3)
CogitoGlobals
CogitoSceneManager
CogitoQuestManager
```

---

## Dependency Graph

```
Phase 1 (verification)
    ↓
Phase 2.1 IngredientState/TacoBase ──→ Phase 2.2 Tortilla ─┐
                                       Phase 2.3 Trompo  ──┤
                                       Phase 2.4 Sauce   ──┼──→ Phase 4.1 OrderManager
                                       Phase 2.5 Topping ──┘
    ↓
Phase 3.1 TacoTicket ──→ Phase 3.2 CustomerNPC ──→ Phase 3.3 QueueManager
                                                          ↓
                                                   Phase 3.4 DifficultySchedule
                                                          ↓
                                                   Phase 3.5 Anchors
    ↓
Phase 4.1 OrderManager ──→ Phase 4.2 BellStation ──→ Phase 4.3 Validator
                                                          ↓
                                                   Phase 4.4 Payment ──→ Phase 4.5 Save
    ↓
Phase 5.1 OrderHUD ─┐
Phase 5.2 Header   ─┼──→ Phase 5.3 EndOfDay ──→ Phase 5.4 MainMenu ──→ Phase 5.5 ConfirmPopup
    ↓
Phase 6 Audio + Polish
```

**Compile-and-smoke-test gates between phases:**
- After Phase 2: walk to each station, complete each interaction, watch `EventBus.order_step_completed` fire with correct `(ingredient_id, quality)` tuples
- After Phase 3: customer spawns, patience drains, customer leaves angry, penalty debited
- After Phase 4: full Tortilla → Trompo → Sauce → Topping → Bell loop produces a payment and tip
- After Phase 5: complete day visible in HUD, end-of-day screen renders, save/load round-trip works
- After Phase 6: no `push_warning` on autoload boot; web export shows steady 60 FPS

**Critical-path note:** Phases 2 → 3 → 4 must complete in sequence. Phase 5 can start in parallel with Phase 4 once `OrderManager` and `EventBus` signals from Phase 4.1 land. Phase 6 is entirely additive.
