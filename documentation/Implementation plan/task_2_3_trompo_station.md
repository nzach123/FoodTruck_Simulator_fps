# Task 2.3 — TrompoStation: MASH Implementation

## Task Overview

The Trompo (vertical spit) is the **meat-shaving station** of Midnight Munch. Until now, `TrompoStation.tscn` exists only as a placeholder (a brown CSG cylinder with a generic `TruckStation.gd` script attached and `interaction_type = MASH (1)` already set in the editor). This task gives it a dedicated subclass that:

1. Locks `interaction_type = MASH`, `requires_held_item = true`, and the prompt text in code (so an Inspector edit cannot accidentally desync the station).
2. Emits `EventBus.order_step_completed("meat", quality)` on completion, identical in shape to `SauceStation` and `ToppingStation`.
3. Plays a per-tick spin animation hook on the meat cylinder via `on_interaction_tick(progress)`.

In parallel, the `InteractionStateMachine` (ISM) gains a **gating guard** for any station whose `requires_held_item` flag is true. Because `OrderManager` does not yet exist (Phase 4), the guard must be **null-safe and forward-compatible**: it queries `/root/OrderManager` with `get_node_or_null` and only blocks when the autoload is present and reports no active taco. Until OrderManager ships, the Trompo is freely usable, which is exactly the behaviour required for early-phase development and unit testing.

The ISM also gains a new `station_blocked(reason: String)` signal so the HUD (Phase 5) can flash the prompt red without ISM holding any UI references. Finally, the per-day `DayConfig.mash_presses_required` override is honoured so difficulty scaling for the Trompo is data-driven.

Expected end-to-end behaviour after this task:
- Player walks up to the Trompo → crosshair switches to HOVER, prompt reads "Shave Meat".
- Player presses `mm_interact` → ISM enters MASH state, mash bar fills.
- Each `mm_interact` press adds `1.0 / mash_presses_required` of progress (default 5 presses = 0.2 each).
- Last press completes the interaction, emits `order_step_completed("meat", IngredientState.State.PERFECT)`.
- If/when OrderManager exists and there is no active taco, the press is rejected with `station_blocked.emit("no_taco")` and the ISM rolls back to HOVER.

## Scene Architecture

`res://_src/interactables/TrompoStation.tscn` exists. Update it as follows.

```
TrompoStation                     [Node3D]            (script: TrompoStation.gd, this task)
├── Hitbox                        [StaticBody3D]      collision_layer = 4, collision_mask = 0
│   ├── CollisionShape3D          [CollisionShape3D]  BoxShape3D, sized to spit base
│   └── BasicInteraction          [COGITO instance]   input_map_action = "mm_interact"
├── InteractionPrompt             [Node3D]            (reserved for world-space prompt)
├── SnapZone                      [Area3D]            collision_layer = 8 (snap-zone layer)
│   └── CollisionShape3D          [CollisionShape3D]  SphereShape3D
├── CSGMeat                       [CSGCylinder3D]     radius 0.35, height 1.25, brown material
└── MashSFX                       [AudioStreamPlayer3D]   (optional, Task 6.1 hook)
```

Editor changes required on the existing scene:
- Root `TrompoStation` node: change attached script from `TruckStation.gd` to `res://_src/interactables/TrompoStation.gd`.
- Root: clear `interaction_type` / `interact_action` / `interaction_prompt_text` overrides in the Inspector (script `_ready()` will set them authoritatively).
- `BasicInteraction` child: change `input_map_action` from `"interact2"` to `"mm_interact"` and `interaction_text` to `"Shave Meat"` so COGITO's prompt matches the ISM prompt.

## COGITO Integration

- Subclasses `TruckStation` (`res://_src/interactables/base/TruckStation.gd`).
- Re-uses the existing COGITO `BasicInteraction` instance already wired in `TrompoStation.tscn` for prompt rendering and input action mapping. No COGITO source files are touched.
- All cross-system messaging routes through the `EventBus` autoload — `EventBus.order_step_completed` is emitted on completion. A new `station_blocked` signal is added to the `InteractionStateMachine`, not the EventBus, because it is a **player-input-domain** signal (the HUD listens directly to ISM for crosshair/input feedback).
- `GameManager` (autoload) is read for `difficulty_config.mash_presses_required` so per-day difficulty is honoured.
- Object lifetime is unaffected — the Trompo is a static scene node, never pooled.

## Implementation Steps

1. **Create the subclass script.** Author `res://_src/interactables/TrompoStation.gd` extending `TruckStation`. Lock interaction parameters in `_ready()`. Override `on_interaction_tick()` to spin the CSG mesh (cosmetic) and `on_interaction_complete()` to emit the EventBus signal.
2. **Re-attach the script in the scene.** Open `TrompoStation.tscn` in the editor, select the root, change the script reference to the new `TrompoStation.gd`, and clear Inspector-level overrides for `interaction_type`, `interact_action`, and `interaction_prompt_text`.
3. **Update the COGITO BasicInteraction child.** Set `input_map_action = "mm_interact"` and `interaction_text = "Shave Meat"`.
4. **Add the `station_blocked` signal to ISM.** Append `signal station_blocked(reason: String)` to the signals block of `InteractionStateMachine.gd`.
5. **Replace `_start_interaction()` in ISM** with the gated version that:
   - Reads `mash_presses_required` from `GameManager.difficulty_config` (fall back to base 5 → `MASH_PER_PRESS = 0.2`).
   - Checks `requires_held_item` and queries `OrderManager` only if the autoload is present.
   - Emits `station_blocked("no_taco")` and rolls back to HOVER if blocked.
   - Otherwise dispatches identically to the original.
6. **Add `_get_mash_per_press()` helper** to ISM to centralise the per-press progress computation, so MASH math survives a per-day override without scattering arithmetic.
7. **Update `_on_mash_press()`** in ISM to use the helper instead of the hard-coded `MASH_PER_PRESS` constant.
8. **Smoke test.** Enter `TruckInterior.tscn`, hover Trompo (prompt should read "Shave Meat"), press `mm_interact` 5 times, watch the console for an `order_step_completed("meat", 2)` debug line.
9. **Defensive forward test.** With OrderManager absent (current state), the station should always succeed. Re-test once OrderManager is added in Phase 4 — pressing without an active taco must trigger `station_blocked("no_taco")`.

## Code Implementation

### `res://_src/interactables/TrompoStation.gd` — new file

```gdscript
## TrompoStation.gd
## Vertical-spit meat-shaving station. Extends TruckStation as MASH type.
##
## INTERACTION:
##   Player must be holding a TacoBase (requires_held_item = true).
##   Each mm_interact press adds (1.0 / DayConfig.mash_presses_required) progress.
##   On full bar, emits EventBus.order_step_completed("meat", quality).
##
## VISUAL:
##   on_interaction_tick(progress) drives a procedural Y-axis spin of the CSGMeat
##   cylinder. The spin speed scales with progress so the meat "spins faster"
##   the more aggressively the player mashes — purely cosmetic feedback.
##
## Path: res://_src/interactables/TrompoStation.gd

class_name TrompoStation
extends TruckStation

# ─────────────────────────────────────────────────────────────────────────────
# CONSTANTS
# ─────────────────────────────────────────────────────────────────────────────

## Name of the visible CSG mesh node inside TrompoStation.tscn.
const CSG_NODE_NAME: StringName = &"CSGMeat"

## Name used by the EventBus order pipeline. Matches RecipeData ingredient key.
const INGREDIENT_ID: String = "meat"

## Maximum spin speed (radians per second) at progress = 1.0.
const MAX_SPIN_RAD_PER_SEC: float = 6.0

# ─────────────────────────────────────────────────────────────────────────────
# STATE
# ─────────────────────────────────────────────────────────────────────────────

var _csg_mesh: Node3D = null
var _current_spin: float = 0.0

# ─────────────────────────────────────────────────────────────────────────────
# LIFECYCLE
# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Lock the interaction profile in code so an Inspector edit cannot desync it.
	interaction_type = InteractionType.MASH
	interact_action = &"mm_interact"
	display_name = "Trompo"
	interaction_prompt_text = "Shave Meat"
	requires_held_item = true

	_csg_mesh = get_node_or_null(CSG_NODE_NAME) as Node3D
	if _csg_mesh == null:
		push_warning("[TrompoStation] CSG mesh '%s' not found on '%s'." % [CSG_NODE_NAME, name])

func _physics_process(delta: float) -> void:
	# Decay spin to zero between mash presses so the meat slows naturally.
	if _current_spin <= 0.0:
		return
	if not is_instance_valid(_csg_mesh):
		return
	_csg_mesh.rotate_y(_current_spin * delta)
	_current_spin = maxf(0.0, _current_spin - MAX_SPIN_RAD_PER_SEC * delta * 0.5)

# ─────────────────────────────────────────────────────────────────────────────
# TRUCK STATION VIRTUAL OVERRIDES
# ─────────────────────────────────────────────────────────────────────────────

func on_interaction_start() -> void:
	_current_spin = 0.0
	if OS.is_debug_build():
		print("[TrompoStation] Interaction started.")

func on_interaction_tick(progress: float) -> void:
	# progress is 0.0 → 1.0 (mash_progress / MASH_THRESHOLD).
	# Spin speed scales with progress so the meat appears to ramp up.
	_current_spin = clampf(progress, 0.0, 1.0) * MAX_SPIN_RAD_PER_SEC

func on_interaction_complete(result: int) -> void:
	_current_spin = 0.0

	var result_dict: Dictionary = {
		"ingredient_id": INGREDIENT_ID,
		"quality": result,
	}
	interaction_completed.emit(self, result_dict)
	EventBus.order_step_completed.emit(INGREDIENT_ID, result)

	if OS.is_debug_build():
		print("[TrompoStation] order_step_completed.emit('%s', %d)" % [INGREDIENT_ID, result])
```

### `res://_src/player/InteractionStateMachine.gd` — modifications

Add the new signal in the SIGNALS block:

```gdscript
## Emitted when an interaction press is rejected (e.g. no taco in hand).
## reason values: "no_taco", "wrong_item", "wrong_phase".
## Listener: HUD (flash interaction prompt red), Tutorial (replay hint).
signal station_blocked(reason: String)
```

Replace the entire `_start_interaction()` method with the gated version below. This is the COMPLETE updated method:

```gdscript
# ─────────────────────────────────────────────────────────────────────────────
# INTERACTION START — HOVER → ACTIVE → branch
# Honours TruckStation.requires_held_item by querying OrderManager, if present.
# Honours DayConfig.mash_presses_required for MASH-type stations.
# ─────────────────────────────────────────────────────────────────────────────

func _start_interaction() -> void:
	if active_station == null:
		return

	# ── Held-item gate ────────────────────────────────────────────────────────
	# OrderManager is a Phase 4 autoload; until it exists, the guard is a no-op.
	# This lets the MASH/HOLD/TIMING stations be tested in isolation today
	# while remaining forward-compatible with OrderManager when it lands.
	if active_station.requires_held_item:
		var order_mgr: Node = get_node_or_null("/root/OrderManager")
		if is_instance_valid(order_mgr) and order_mgr.has_method("has_active_taco"):
			if not order_mgr.call("has_active_taco"):
				if OS.is_debug_build():
					print("[ISM] Station '%s' blocked: no active taco." % active_station.name)
				station_blocked.emit("no_taco")
				_reset_to_hover()
				return

	_set_state(State.ACTIVE)
	active_station.on_interaction_start()

	match active_station.interaction_type:
		TruckStation.InteractionType.INSTANT:
			_complete_interaction(IngredientState.State.PERFECT)

		TruckStation.InteractionType.MASH:
			mash_progress = 0.0
			_set_state(State.MASH)

		TruckStation.InteractionType.HOLD:
			hold_progress = 0.0
			_set_state(State.HOLD)

		TruckStation.InteractionType.TIMING:
			timing_radius = TIMING_START_RADIUS
			timing_radius_changed.emit(timing_radius)
			_set_state(State.TIMING)
```

Add the helper directly below `_start_interaction()`:

```gdscript
## Returns the progress added per mash press, honouring the per-day override.
## Falls back to MASH_PER_PRESS (5 presses base) if no DayConfig override is set.
func _get_mash_per_press() -> float:
	var presses_required: int = 0

	var gm: Node = get_node_or_null("/root/GameManager")
	if is_instance_valid(gm) and gm.get("difficulty_config") != null:
		var cfg: Resource = gm.get("difficulty_config") as Resource
		if cfg and cfg.get("mash_presses_required") != null:
			presses_required = int(cfg.get("mash_presses_required"))

	if presses_required <= 0:
		return MASH_PER_PRESS

	return MASH_THRESHOLD / float(presses_required)
```

Replace `_on_mash_press()` to use the helper:

```gdscript
# ─────────────────────────────────────────────────────────────────────────────
# MASH LOGIC
# ─────────────────────────────────────────────────────────────────────────────

func _on_mash_press() -> void:
	mash_progress += _get_mash_per_press()
	mash_progress_changed.emit(mash_progress)

	if active_station != null:
		active_station.on_interaction_tick(mash_progress / MASH_THRESHOLD)

	if mash_progress >= MASH_THRESHOLD:
		_complete_interaction(IngredientState.State.PERFECT)
```
