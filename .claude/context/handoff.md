# Handoff Notes — TASK-1.3: InteractionStateMachine Skeleton + Station Colors

**Date:** 2026-04-25
**Agent:** BUILDER
**Task:** Task 1.3 — InteractionStateMachine, TruckStation base, station visual colors

---

## What Was Implemented

### New GDScript Files

| File | Purpose |
|------|---------|
| `_src/interactables/base/TruckStation.gd` | Base class (class_name TruckStation). Defines InteractionType enum, @export vars, signals, and virtual on_* callbacks. |
| `_src/player/InteractionStateMachine.gd` | Full state machine: IDLE/HOVER/ACTIVE/MASH/HOLD/TIMING. Raycast detection, mash/hold/timing tick logic, crosshair signal emission. All web-safe (no await, all timing in _physics_process). |
| `_src/interactables/SauceStation.gd` | Extends TruckStation. Sets CSG cylinder color from @export var sauce_color at _ready(). Emits interaction_completed and EventBus.order_step_completed on complete. |
| `_src/interactables/ToppingStation.gd` | Extends TruckStation. Sets CSG box color from @export var topping_color at _ready(). Same signal pattern as SauceStation. |

### Modified Scene Files

| File | Change |
|------|--------|
| `_src/interactables/SauceStation.tscn` | Added SauceStation.gd as root node script. Set StandardMaterial3D albedo_color = Color(0.95, 0.95, 0.90, 1) as white-sauce default. |
| `_src/interactables/ToppingStation.tscn` | Added ToppingStation.gd as root node script. Existing green material Color(0.23, 0.66, 0.27) retained as cilantro default. |

### Documentation

| File | Content |
|------|---------|
| `documentation/Implementation plan/Task_1.3_InteractionStateMachine_Plan.md` | Full state diagram, color palette, file list, signal wiring table, crosshair design, web-safety rules, editor workflow for per-instance color overrides. |

---

## Required Manual Steps (Next Person Opening the Editor)

1. Connect ISM signals to HUD (can be deferred to Task 1.4 spike):
   - `crosshair_state_changed` → Crosshair Control
   - `hold_progress_changed` → SauceGauge
   - `mash_progress_changed` → MashProgressBar
   - `timing_radius_changed` → ShrinkingCircle

---

## What Is NOT Yet Done (Next Tasks)

- TruckPlayer.tscn does not yet exist as a custom scene (uses cogito_player.tscn). Needs Task 1.2b.
- SauceStation.gd collision_layer on Hitbox should be layer 3, not layer 2. Currently layer 2 (COGITO default). Change when Task 1.7 is implemented.
- TrompoStation and TortillaStation and BellStation do not yet have custom .gd scripts (Tasks 1.5, 1.6, 2.7).
- HUD nodes (SauceGauge, MashProgressBar, ShrinkingCircle, Crosshair) do not exist yet.

---

## Known Issues / Watch Points

- **Collision layer mismatch:** All station Hitbox StaticBody3D nodes use `collision_layer = 2` (COGITO's "Interactables" layer). The ISM RayCast3D is spec'd to target Layer 3 (Stations). Either: (a) update all Hitbox layers to 3 when writing station .gd scripts, or (b) change the RayCast3D mask to Layer 2 temporarily. Recommend option (a) as part of each station's Task.
- **COGITO script on Hitbox:** Each station's `Hitbox` StaticBody3D still runs `cogito_object.gd`. This is harmless for now (it adds COGITO's interaction component support). When custom station logic is added, consider whether to remove it or leave it for COGITO's interaction prompt system to coexist.
- **SauceStation.gd extends TruckStation but TruckStation extends Node3D:** The scene root is already Node3D, so this is correct. However since SauceStation.gd is attached to the scene root AND the Hitbox has cogito_object.gd, the root will have two effective scripts. This is fine in Godot — root script wins for class_name.
- **EconomyManager singleton check in ISM:** `InteractionStateMachine._on_timing_miss()` uses `Engine.has_singleton("EconomyManager")` before calling `EconomyManager.debit()`. This is defensive. Once EconomyManager is fully implemented (Task 1.10), this guard can be removed.

---

# Handoff Notes — TASK-001: Project Bootstrap

**Date:** 2026-04-24
**Agent:** BUILDER
**Task:** Task 1.1 — Project Bootstrap (Implementation Plan Phase 1)

---

## What Was Implemented

### 4 Autoload Scripts (`_src/autoloads/`)

| File | Purpose |
|------|---------|
| `EventBus.gd` | All cross-system signals declared. Emit/connect pattern ready. |
| `GameManager.gd` | Day phase state machine, 5-min countdown, DifficultySchedule loader. |
| `EconomyManager.gd` | Balance, credit/debit, tip calc, food cost deduction, day stats. |
| `NodePool.gd` | Pre-warm + checkout + ret pattern. Container registration via `register_container()`. |

### 4 Resource Class Scripts (`_src/data/`)

| File | Purpose |
|------|---------|
| `difficulty/DayConfig.gd` | Per-day patience, spawn interval, max concurrent, topping toggle. |
| `recipes/RecipeData.gd` | Always/optional ingredient arrays; max optional count. |
| `upgrades/UpgradeData.gd` | ID, cost, description, modifier dict, one-time flag. |
| `economy/EconomyConfig.gd` | All GDD prices, tips, penalties, starting balance, ingredient costs. |

### `project.godot` Patches

1. **Autoloads registered:** `EventBus`, `GameManager`, `EconomyManager`, `NodePool` added after COGITO singletons.
2. **Input actions added:** `mm_interact` (LMB), `mm_mash` (LMB + F key).
3. **Physics layers updated:** Layer 2 renamed `Player`, Layer 3 = `Stations`, Layer 4 = `SnapZones`.

---

## Required Manual Steps (Next Person Opening the Editor)

> [!IMPORTANT]
> The `project.godot` changes register autoloads by **file path** (not UID).
> After opening Godot Editor for the first time after this commit:
> 1. Go to **Project → Project Settings → Autoloads**
> 2. Confirm all 4 MM autoloads appear and have no error icons.
> 3. If any show errors, delete and re-add them manually pointing to `_src/autoloads/`.

---

## What Is NOT Yet Done (Next Task)

- `DifficultySchedule.tres` — must be created in the editor using `DayConfig.gd` resource.
- `EconomyConfig.tres` — must be created in the editor using `EconomyConfig.gd` resource.
- `TruckInterior.tscn` — Task 1.2 (blockout scene).
- `InteractionStateMachine.gd` — Task 1.3.
- `TruckStation.gd` base class — Task 1.3.

---

## Known Issues / Watch Points

- `GameManager._load_difficulty_schedule()` expects a resource with a `days` property (Array[DayConfig]).
  The `DifficultySchedule.tres` resource type that wraps this array needs to be created.
  Consider a simple `DifficultySchedule.gd` resource with `@export var days: Array[DayConfig]`.
- `NodePool` pre-warms scene paths that do not exist yet. The pool will log warnings and skip gracefully.
  No crash — safe to run headlessly before food item scenes are created.
- Physics layer rename from `Interactables` → `Player`+`Stations`+`SnapZones` may cause
  the existing COGITO demo scenes to show layer warnings in the editor. These are cosmetic only;
  COGITO demo scenes are not used in Midnight Munch gameplay.
