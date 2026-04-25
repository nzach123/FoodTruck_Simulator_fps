# Midnight Munch — Technical Implementation Plan (Part 1)

**Engine:** Godot 4.6 | **GDScript Only** | **Platform:** Web (HTML5/WebGL2)
**Based on:** GDD v2.0, High-Level Schedule, COGITO Framework v1.1

---

## 1. Architecture Overview

### Design Patterns

- **Signal Up, Call Down** — child nodes emit signals upward; parent/manager scripts call downward via direct references only.
- **Event Bus** — all cross-system communication (economy changes, order events, day transitions) route through `EventBus.gd` autoload.
- **Data-Driven via Resources** — all game data (recipes, upgrades, difficulty schedule) stored as `.tres` files under `_src/data/`. Zero hardcoded values in scripts.
- **Object Pooling (Day 1)** — `NodePool.gd` autoload pre-instantiates all food items and NPC nodes at scene load. `queue_free()` is **banned** during gameplay.
- **Input State Machine** — a single `InteractionStateMachine` owns all player input context. Stations are dumb data objects; they never poll input.
- **Component-Based Stations** — each prep station is a self-contained scene with an exported `InteractionType` enum. The state machine reads type; the station receives callbacks.

### COGITO Integration Strategy

The COGITO framework is **retained as infrastructure** (autoloads, scene manager, audio bus) but the gameplay layer is built **from scratch** in `_src/`. COGITO's player controller, inventory, wieldables, and NPC system are **not used**. The following COGITO systems are leveraged:

| COGITO System | Usage in Midnight Munch |
|---|---|
| `Audio` autoload | SFX and music bus management |
| `CogitoSceneManager` | Main menu → Game scene transitions |
| `MenuTemplateManager` | Settings overlay (volume sliders) |
| Jolt Physics (project-wide) | RigidBody3D topping drops |
| `project.godot` render config | gl_compatibility renderer (web-safe) |

The COGITO main menu scene is replaced by a custom `MainMenu.tscn`. All game logic lives in `_src/`.

---

## 2. Scene & Node Structure

### 2.1 File/Scene Map

```
res://_src/
├── autoloads/
│   ├── EventBus.gd
│   ├── GameManager.gd
│   ├── EconomyManager.gd
│   └── NodePool.gd
├── data/
│   ├── recipes/
│   │   └── TacoRecipeData.tres       # RecipeData resource
│   ├── upgrades/
│   │   ├── UpgradeKnife.tres         # UpgradeData resource
│   │   └── UpgradeSauceBottle.tres
│   ├── difficulty/
│   │   └── DifficultySchedule.tres   # Array of DayConfig resources
│   └── economy/
│       └── EconomyConfig.tres        # Prices, tips, penalties
├── player/
│   ├── TruckPlayer.tscn              # Root: Node3D
│   └── InteractionStateMachine.gd
├── interactables/
│   ├── base/
│   │   └── TruckStation.gd           # Base class
│   ├── TortillaStation.tscn
│   ├── TrompoStation.tscn
│   ├── SauceStation.tscn             # @export var sauce_type: SauceType
│   ├── ToppingStation.tscn           # @export var topping_type: ToppingType
│   └── BellStation.tscn
├── entities/
│   ├── customer/
│   │   ├── Customer.tscn             # Root: Node3D (pooled)
│   │   ├── Customer.gd
│   │   ├── PatienceArc.tscn          # World-space UI: SubViewport or Label3D
│   │   └── SpeechBubble.tscn
│   └── food/
│       ├── TortillaItem.tscn         # Root: Node3D (pooled)
│       ├── MeatPortion.tscn          # Root: Node3D (pooled)
│       ├── ToppingItem.tscn          # Root: RigidBody3D (pooled)
│       └── SauceStream.tscn          # Root: GPUParticles3D (pooled)
├── levels/
│   ├── TruckInterior.tscn            # Main gameplay scene
│   └── MainMenu.tscn
├── ui/
│   ├── GameHUD.tscn
│   ├── OrderPanel.tscn               # Top-right ingredient pills
│   ├── EndOfDayScreen.tscn
│   ├── UpgradeShop.tscn
│   ├── BellConfirmationPopup.tscn
│   ├── SauceGauge.tscn               # Screen-centre contextual
│   ├── MashProgressBar.tscn          # Screen-centre contextual
│   ├── ShrinkingCircle.tscn          # Screen-centre contextual
│   └── PenaltyTicker.tscn
└── assets/
    ├── kenney_models/                # Raw Kenney GLTF imports
    └── placeholder/                  # Grey-box MeshInstance3D resources
```

### 2.2 TruckInterior.tscn Hierarchy

```
TruckInterior (Node3D)
├── Environment (Node3D)              # Truck mesh, walls, counter, window
│   ├── MeshInstance3D [front_counter]
│   ├── MeshInstance3D [back_counter]
│   ├── MeshInstance3D [walls]
│   ├── MeshInstance3D [window_frame]
│   └── OccasionalFlicker (Node3D)    # Cozy-uncanny light flicker
│       └── OmniLight3D [counter_light]
├── Stations (Node3D)
│   ├── FrontStations (Node3D)        # Customer-facing counter (near serving window)
│   │   ├── RedSauceStation (SauceStation.tscn)
│   │   ├── WhiteSauceStation (SauceStation.tscn)
│   │   ├── CilantroStation (ToppingStation.tscn)
│   │   ├── TomatoStation (ToppingStation.tscn)
│   │   ├── OnionStation (ToppingStation.tscn)
│   │   └── BellStation (BellStation.tscn)
│   └── BackStations (Node3D)         # Truck interior rear counter
│       ├── TortillaStation (TortillaStation.tscn)
│       └── TrompoStation (TrompoStation.tscn)
├── CustomerQueue (Node3D)            # World-space, visible through window
│   └── QueueManager.gd
├── TruckPlayer (TruckPlayer.tscn)    # CharacterBody3D — WASD movement
│   ├── CollisionShape3D              # Player capsule for wall collision
│   ├── Camera3D [pitch clamped ±60°]  # Yaw unclamped (full 360°)
│   ├── RayCast3D [interaction ray]    # 3.0 m reach; collision mask = layer 3
│   └── InteractionStateMachine.gd
├── NodePoolContainer (Node3D)        # Hidden; holds all pooled nodes
├── GameHUD (CanvasLayer)
│   ├── OrderPanel
│   ├── DayTimerLabel
│   ├── BankBalanceLabel
│   ├── HeldItemIcon
│   ├── SauceGauge            [hidden by default]
│   ├── MashProgressBar       [hidden by default]
│   ├── ShrinkingCircle       [hidden by default]
│   ├── PenaltyTicker         [hidden by default]
│   └── BellConfirmationPopup [hidden by default]
└── OrderManager (Node)               # Pure logic node, no mesh
```

### 2.3 Station Node Structure (all stations share this pattern)

```
TrompoStation (Node3D)    ← TruckStation.gd
├── MeshInstance3D [trompo_visual]
├── Area3D [hitbox]       ← 1.5x mesh size; collision layer 3
│   └── CollisionShape3D
├── InteractionPrompt (Node3D) [world-space label, shown on hover]
└── SnapZone (Area3D)     ← receives food items; collision layer 4
    └── CollisionShape3D
```

---

## 3. Core Logic & Systems

### 3.1 Autoloads

#### EventBus.gd
```gdscript
extends Node

signal order_accepted(customer: Customer)
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

#### GameManager.gd
```gdscript
extends Node

enum GamePhase { MAIN_MENU, TUTORIAL, PLAYING, END_OF_DAY }

var current_phase: GamePhase = GamePhase.MAIN_MENU
var current_day: int = 0
var day_timer: float = 300.0   # 5 minutes in seconds
var is_timer_running: bool = false

# Loaded from DifficultySchedule.tres
var difficulty_config: DayConfig

func start_day(day: int) -> void: ...
func _process(delta: float) -> void: ...   # countdown only
func end_day() -> void: ...
func get_day_config(day: int) -> DayConfig: ...
```

#### EconomyManager.gd
```gdscript
extends Node

var balance: float = 0.0
var day_earnings: float = 0.0
var day_tips: float = 0.0
var orders_completed: int = 0
var orders_attempted: int = 0
var sloppy_flags: int = 0    # reset per order

func credit(amount: float, reason: String) -> void: ...
func debit(amount: float, reason: String) -> void: ...   # floor at 0
func process_payment(sloppy_count: int) -> void: ...
func deduct_food_cost(ingredients: Array) -> void: ...
func reset_day_stats() -> void: ...
func tally_day() -> Dictionary: ...
```

#### NodePool.gd
```gdscript
extends Node

var _pools: Dictionary = {}  # key: scene_path, value: Array[Node]

func _ready() -> void:
    _prewarm("res://_src/entities/food/TortillaItem.tscn", 10)
    _prewarm("res://_src/entities/food/MeatPortion.tscn", 20)
    _prewarm("res://_src/entities/food/ToppingItem.tscn", 15)  # × 3 types
    _prewarm("res://_src/entities/food/SauceStream.tscn", 50)
    _prewarm("res://_src/entities/customer/Customer.tscn", 5)

func checkout(scene_path: String) -> Node: ...
func ret(node: Node) -> void: ...    # "return" is reserved
func _prewarm(scene_path: String, count: int) -> void: ...
```

### 3.2 InteractionStateMachine.gd

The interaction state machine handles **interaction input only**. Player movement (WASD) is processed in `TruckPlayer.gd` independently and does **not** interrupt any active interaction state. A player can continue mashing, holding, or waiting for a timing window while walking.

```gdscript
extends Node

enum State { IDLE, HOVER, MASH, HOLD, TIMING, INSTANT }

var state: State = State.IDLE
var active_station: TruckStation = null
var mash_progress: float = 0.0
var hold_progress: float = 0.0
var timing_radius: float = 0.0

# Shrinking circle constants
const TIMING_START_RADIUS: float = 400.0
const TIMING_TARGET_MIN: float = 80.0
const TIMING_TARGET_MAX: float = 130.0
const TIMING_SHRINK_SPEED: float = 220.0   # px/sec — physics_process only

func _physics_process(delta: float) -> void:
    match state:
        State.MASH:   _tick_mash(delta)
        State.HOLD:   _tick_hold(delta)
        State.TIMING: _tick_timing(delta)

func _tick_timing(delta: float) -> void:
    timing_radius -= TIMING_SHRINK_SPEED * delta
    if timing_radius <= 0.0:
        _on_timing_miss()
    # emit signal for ShrinkingCircle UI to update radius
```

### 3.3 TruckStation.gd (Base Class)

```gdscript
extends Node3D
class_name TruckStation

enum InteractionType { INSTANT, MASH, HOLD, TIMING }

@export var interaction_type: InteractionType = InteractionType.INSTANT
@export var interaction_prompt_text: String = "Interact"
@export var requires_held_item: bool = false

signal station_hovered(station: TruckStation)
signal station_unhovered(station: TruckStation)
signal interaction_completed(station: TruckStation, result: Dictionary)

# Called by InteractionStateMachine — never by self
func on_interaction_start() -> void: pass
func on_interaction_tick(progress: float) -> void: pass
func on_interaction_complete(result: int) -> void: pass
```

### 3.4 OrderManager.gd

```gdscript
extends Node

var current_order: OrderData = null     # null = no active order
var active_customer: Customer = null
var ingredient_states: Dictionary = {}  # ingredient_id -> IngredientState enum

enum IngredientState { PENDING, ACTIVE, PERFECT, SLOPPY, MISSING }

func accept_order(customer: Customer) -> void: ...
func complete_step(ingredient_id: String, quality: IngredientState) -> void: ...
func validate_order() -> bool: ...   # called by BellStation
func submit_order(force: bool = false) -> void: ...
func _generate_recipe() -> OrderData: ...  # reads RecipeData.tres, randomises optionals
func clear_order() -> void: ...
```

### 3.5 Customer.gd

```gdscript
extends Node3D
class_name Customer

var patience_max: float = 60.0
var patience_current: float = 60.0
var order: OrderData = null
var is_accepted: bool = false
var customer_id: int = 0

signal patience_expired(customer: Customer)
signal order_accepted_by_player(customer: Customer)

func _physics_process(delta: float) -> void:
    if not is_accepted:
        patience_current -= delta
        if patience_current <= 0.0:
            emit_signal("patience_expired", self)

func configure(config: DayConfig, pool_id: int) -> void: ...
func accept() -> void: ...          # stops patience drain? No — GDD: drain continues
func leave_angry() -> void: ...     # plays animation, returns self to pool
```

### 3.6 QueueManager.gd

```gdscript
extends Node

var queue: Array[Customer] = []
var spawn_timer: float = 0.0
var max_concurrent: int = 2

func _physics_process(delta: float) -> void:
    spawn_timer -= delta
    if spawn_timer <= 0.0 and queue.size() < max_concurrent:
        _spawn_customer()
        spawn_timer = _get_spawn_interval()

func _spawn_customer() -> void:
    var c: Customer = NodePool.checkout("res://_src/entities/customer/Customer.tscn")
    c.configure(GameManager.difficulty_config, queue.size())
    c.patience_expired.connect(_on_customer_patience_expired)
    queue.append(c)

func _on_customer_patience_expired(customer: Customer) -> void:
    EconomyManager.debit(1.50, "patience_expired")
    EventBus.customer_left.emit(1.50)
    queue.erase(customer)
    customer.leave_angry()
```

### 3.7 Data Resources (`.tres` structures)

```gdscript
# RecipeData.gd
class_name RecipeData extends Resource
@export var always_ingredients: Array[String] = ["tortilla", "meat"]
@export var optional_ingredients: Array[String] = ["red_sauce","white_sauce","cilantro","tomato","onion"]

# DayConfig.gd
class_name DayConfig extends Resource
@export var day: int = 1
@export var patience_seconds: float = 60.0
@export var spawn_interval: float = 45.0
@export var max_concurrent: int = 2

# UpgradeData.gd
class_name UpgradeData extends Resource
@export var upgrade_id: String = ""
@export var display_name: String = ""
@export var cost: float = 25.0
@export var description: String = ""
# Upgrade effect applied as a modifier dict read by relevant station
@export var modifier: Dictionary = {}

# EconomyConfig.gd
class_name EconomyConfig extends Resource
@export var taco_base_price: float = 3.50
@export var tip_perfect: float = 1.00
@export var tip_one_sloppy: float = 0.50
@export var tip_sloppy_plus: float = 0.00
@export var penalty_patience: float = 1.50
@export var penalty_topping_drop: float = 0.05
@export var starting_balance: float = 5.00
@export var bailout_amount: float = 2.00
@export var ingredient_costs: Dictionary = {
    "tortilla": 0.25, "meat": 0.75,
    "red_sauce": 0.15, "white_sauce": 0.15,
    "cilantro": 0.10, "tomato": 0.10, "onion": 0.10
}
```

### 3.8 Save System

```gdscript
# SaveManager.gd  (can be a static function set or small autoload)
const SAVE_PATH: String = "user://save.json"

static func save(data: Dictionary) -> void:
    var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    file.store_string(JSON.stringify(data))
    file.close()

static func load_save() -> Dictionary:
    if not FileAccess.file_exists(SAVE_PATH):
        return {}
    var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
    var result = JSON.parse_string(file.get_as_text())
    file.close()
    return result if result else {}

static func build_save_dict() -> Dictionary:
    return {
        "current_day": GameManager.current_day,
        "balance": EconomyManager.balance,
        "upgrades": UpgradeManager.purchased_upgrades,
        "stats": EconomyManager.get_lifetime_stats()
    }
```

### 3.9 Tutorial System (Day 0)

```gdscript
# TutorialManager.gd — attached to TruckInterior scene root
extends Node

const SCRIPTED_ORDERS: Array = [
    { "ingredients": ["tortilla", "meat"], "prompts": "full" },
    { "ingredients": ["tortilla", "meat", "red_sauce"], "prompts": "sauce_only" },
    { "ingredients": ["tortilla", "meat", "cilantro"], "prompts": "topping_only" },
    { "ingredients": ["tortilla", "meat", "red_sauce", "white_sauce", "cilantro", "tomato"], "prompts": "light" },
    { "ingredients": null, "prompts": "none" }   # random, no prompts
]

var current_step: int = 0
var world_arrow: Node3D   # world-space prompt arrow

func advance_step() -> void: ...
func show_prompt(station: TruckStation, text: String) -> void: ...
func hide_prompt() -> void: ...
```

---

## 4. Web Optimization Strategy

### 4.1 Renderer Configuration

- **`gl_compatibility` renderer** already set in `project.godot`. Do **not** change to Forward Plus or Mobile.
- **No bloom, no SSAO, no SSIL.** Environment node uses ambient light only.
- **Point filtering** on all textures (`Filter: Nearest`). Set as importer default.
- **No anti-aliasing** (MSAA currently set to 1x — leave it).
- Canvas scale: keep `window/stretch/mode = canvas_items` with `aspect = expand`.

### 4.2 Physics Process Discipline

All timing-sensitive logic runs **exclusively** in `_physics_process`:

| System | Process type | Reason |
|---|---|---|
| Shrinking circle radius | `_physics_process` | Fixed timestep = consistent feel across frame rates |
| Mash progress | `_physics_process` | Deterministic fill rate |
| Hold gauge fill | `_physics_process` | Smooth, frame-rate-independent |
| Patience bar drain | `_physics_process` | Fair across devices |
| Customer spawn timer | `_physics_process` | Consistent spawn cadence |
| Day countdown | `_process` | Visual only; imprecision acceptable |

Audio callbacks always fire **after** visual state is set. Never use audio as a timing cue.

### 4.3 Memory Management

- `NodePool` pre-warms at scene load. No runtime instantiation after `_ready()`.
- Dropped topping `RigidBody3D` nodes: `freeze = true` on ground contact, auto-return to pool after 10 seconds via `Timer` node (not `await`).
- GPUParticles3D sauce streams: `one_shot = true`, emission disabled when returned to pool.
- Customer NPC nodes: reset all state variables on pool return. Never destroy.
- Total pooled nodes target: **~125 nodes**. Well within WASM heap budget.

### 4.4 Asset Budget (Prototype)

| Asset Type | Target | Notes |
|---|---|---|
| Total VRAM | < 128 MB | Kenney low-poly + placeholder geo |
| Audio compressed | < 20 MB | OGG Vorbis, mono SFX |
| Texture atlas | 512×512 px | Point-filtered, palette limited |
| WASM bundle | < 35 MB | GDScript-only; no C# inflates bundle |

### 4.5 Input Latency Mitigation

- Shrinking circle timing window: **30% wider** than a native-feel window.
- No `await` inside interaction handlers (blocks until next frame; breaks on web tab switch).
- Mouse capture: `Input.mouse_mode = Input.MOUSE_MODE_CAPTURED` only while in `PLAYING` phase. Release on `END_OF_DAY` and popup modals.
- Test shrinking circle in Chrome as Week 1 spike **before** building any other timing system.

### 4.6 Build Export Settings

```
Export Preset: Web
- Minify: On
- GDScript debug symbols: Off
- Export PCK/ZIP: Off (embed)
- VRAM texture compression: On
- Thread support: Off  ← critical for itch.io/GitHub Pages hosting without SharedArrayBuffer
```

---

## 5. Step-by-Step Execution Plan

### PHASE 1 — Foundation & Core Interactions (Week 1)

**Task 1.1 — Project Bootstrap**
- [ ] Add `mm_interact` mouse button (LMB) and `mm_mash` keyboard (F or LMB) to `project.godot` InputMap
- [ ] Create `_src/` folder structure (all empty dirs as above)
- [ ] Register `EventBus`, `GameManager`, `EconomyManager`, `NodePool` as Autoloads in `project.godot`
- [ ] Create stub `.gd` files for all 4 autoloads with `extends Node` + all signal declarations
- [ ] Create `DayConfig.gd`, `RecipeData.gd`, `UpgradeData.gd`, `EconomyConfig.gd` resource scripts
- [ ] Populate `DifficultySchedule.tres` with Days 0–7+ config values from GDD
- [ ] Populate `EconomyConfig.tres` with all prices, tips, and penalties from GDD

**Task 1.2 — Truck Interior Blockout**
- [ ] Create `TruckInterior.tscn` with placeholder `MeshInstance3D` boxes for all surfaces
- [ ] Create two distinct counter meshes: `front_counter` (serving window side) and `back_counter` (truck interior rear)
- [ ] Label all placeholder objects: `bell`, `red_sauce`, `white_sauce`, `cilantro`, `tomato`, `onion` on front counter; `tortilla_station`, `trompo` on back counter
- [ ] Add `StaticBody3D` boundary walls to physically prevent player leaving the truck area (all four walls + floor)
- [ ] Set physics layers: Environment = layer 1, Stations = layer 3, Snap zones = layer 4
- [ ] Add `mm_move_forward`, `mm_move_back`, `mm_strafe_left`, `mm_strafe_right` input actions (W/A/S/D) to `project.godot` InputMap
- [ ] Create `TruckPlayer.tscn` as `CharacterBody3D` root with `CollisionShape3D` (capsule) child
- [ ] Attach `Camera3D` as a child of the player head node; implement pitch clamp (±60°) via `clamp(camera.rotation.x, ...)`
- [ ] Implement mouse-look in `TruckPlayer.gd`: rotate **player node** on Y-axis (yaw, unclamped) with mouse X; rotate **Camera3D** on X-axis (pitch, clamped) with mouse Y
- [ ] Implement WASD movement in `TruckPlayer.gd._physics_process()` using `CharacterBody3D.move_and_slide()`
- [ ] Add `RayCast3D` from camera forward; length 3.0 m; collision mask = layer 3
- [ ] Group front stations under `FrontStations (Node3D)` and back stations under `BackStations (Node3D)` inside `Stations (Node3D)`
- [ ] Verify camera feel and movement in-editor: player can walk between front and back counter and reach all stations

**Task 1.3 — InteractionStateMachine Skeleton**
- [ ] Implement `TruckStation.gd` base class with enum, signals, and virtual methods
- [ ] Implement `InteractionStateMachine.gd` state enum and state transitions (IDLE → HOVER on raycast hit, HOVER → IDLE on miss)
- [ ] Wire raycast hits to `station_hovered`/`station_unhovered` signals
- [ ] Show/hide `InteractionPrompt` label on hover (world-space `Label3D` or `Sprite3D`)
- [ ] Implement crosshair cursor states (small dot → large circle on hover)

**Task 1.4 — ⚡ SPIKE: Shrinking Circle (web validation)**
- [ ] Create `ShrinkingCircle.tscn` as a `Control` node with a `TextureRect` ring that scales via `custom_minimum_size`
- [ ] Implement radius shrink in `_physics_process` using `TIMING_SHRINK_SPEED`
- [ ] Draw target band as a fixed annulus (inner and outer radius visible from frame 1)
- [ ] On LMB click: check if current radius is within `[TIMING_TARGET_MIN, TIMING_TARGET_MAX]`
- [ ] **Export to web. Open Chrome. Test 20 times. Adjust `TIMING_SHRINK_SPEED` and window width until it feels fair.**
- [ ] Confirm audio fires after visual state change only
- [ ] Document final constants in a comment block at top of `InteractionStateMachine.gd`

**Task 1.5 — Tortilla Station (INSTANT interaction)**
- [ ] Create `TortillaStation.tscn` extending `TruckStation`
- [ ] Set `interaction_type = INSTANT`
- [ ] On `on_interaction_complete`: call `NodePool.checkout(TortillaItem)`, attach to player hand slot
- [ ] Show held item icon (bottom-centre HUD `TextureRect`)
- [ ] Emit `EventBus.order_step_completed("tortilla", PERFECT)` only if `OrderManager.current_order` contains tortilla

**Task 1.6 — Trompo Station (MASH interaction)**
- [ ] Create `TrompoStation.tscn` extending `TruckStation`, `interaction_type = MASH`
- [ ] Track `mash_progress: float` in `InteractionStateMachine`. Each `mm_mash` press = +0.2 (base) or +0.35 (with Sharper Knife upgrade)
- [ ] Show `MashProgressBar` (radial `TextureProgressBar`) while MASH state is active
- [ ] On `mash_progress >= 1.0`: call `on_interaction_complete(PERFECT)`, reset progress, hide bar
- [ ] Require `player_has_tortilla` check. If no tortilla: play error sound, no-op
- [ ] Emit `EventBus.order_step_completed("meat", PERFECT)`

**Task 1.7 — Sauce Stations (HOLD interaction)**
- [ ] Create `SauceStation.tscn` with `@export var sauce_type: SauceType` enum (RED, WHITE)
- [ ] `interaction_type = HOLD`
- [ ] `hold_progress` fills at 0.4/sec while `mm_interact` held; shown in `SauceGauge` vertical bar
- [ ] Three zones: `< 0.45` = under-pour (no-op, retry), `0.45–0.75` = green (PERFECT), `> 0.75` = red (SLOPPY)
- [ ] Better Sauce Bottle upgrade: extend green zone to `0.35–0.85`
- [ ] Emit `order_step_completed(sauce_type, quality)` on release if green or red zone hit
- [ ] Under-pour: no emit, player can retry immediately

---

*Continued in Part 2 (Phases 2–4 and full signal connection reference)*
