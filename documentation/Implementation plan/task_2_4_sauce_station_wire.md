# Task 2.4 — SauceStation: Confirm HOLD Outcomes & Wire to TacoBase

## Task Overview

`SauceStation.gd` already exists and handles the HOLD interaction surface (color setup, completion emission). This task **completes the visual loop and locks down the contract**:

1. Add a `GPUParticles3D` sauce-stream node to `SauceStation.tscn`, gate emission via `on_interaction_start()` / `on_interaction_complete()`, and modulate its `amount_ratio` from `on_interaction_tick(progress)` so a longer hold visibly produces more sauce.
2. Confirm and document why the HOLD threshold constants (`HOLD_GREEN_MIN = 0.45`, `HOLD_GREEN_MAX = 0.75`) live on the `InteractionStateMachine`, not the station — the ISM owns interaction-primitive behaviour, the station owns ingredient identity.
3. Confirm and document the under-pour behaviour: when `hold_progress < 0.45`, ISM calls `_reset_to_hover()` without emitting any signal and without debiting the player. The station never learns about an under-pour — that is correct.
4. **Forward-wire to `OrderManager`** (Phase 4) using a null-safe `get_node_or_null` lookup so the eventual `OrderManager.record_step()` call is already in place. Today, the call is a no-op; the day OrderManager ships, the existing line activates with no further station code changes.

After this task, the SauceStation behaviour is:
- Hover → prompt "Dispense Sauce".
- Press-and-hold `mm_interact` → particle stream on, gauge fills, station tints particles `sauce_color`.
- Release < 0.45 → no signal, no penalty, particle stream off, return to HOVER.
- Release 0.45–0.75 → `EventBus.order_step_completed(ingredient_id, PERFECT)`, particle stream off, return to IDLE.
- Release > 0.75 → `EventBus.order_step_completed(ingredient_id, SLOPPY)`, particle stream off, return to IDLE.

## Scene Architecture

Updated `res://_src/interactables/SauceStation.tscn`:

```
SauceStation                      [Node3D]            (script: SauceStation.gd)
├── Hitbox                        [StaticBody3D]      collision_layer = 4
│   ├── CollisionShape3D          [CollisionShape3D]  BoxShape3D
│   └── BasicInteraction          [COGITO instance]   interaction_text = "Dispense Sauce"
├── InteractionPrompt             [Node3D]
├── SnapZone                      [Area3D]            collision_layer = 8
│   └── CollisionShape3D          [CollisionShape3D]  SphereShape3D
├── CSGWhiteSauce                 [CSGCylinder3D]     bottle mesh, tinted at runtime
└── SauceStream                   [GPUParticles3D]    NEW NODE — see below
    └── DrawPass1                 [QuadMesh]          tiny droplet quad, sub-resource
```

`SauceStream` (`GPUParticles3D`) configuration set in the editor:
- `emitting = false` (start disabled; script enables it).
- `amount = 32`.
- `lifetime = 0.7`.
- `local_coords = false` (so the drops continue down even if the station moves).
- `transform.origin = Vector3(0, -0.25, 0)` — at the bottom of the bottle nozzle.
- `process_material` = a new `ParticleProcessMaterial`:
  - `direction = Vector3(0, -1, 0)`
  - `gravity = Vector3(0, -3.0, 0)`
  - `initial_velocity_min = 0.4`, `initial_velocity_max = 0.6`
  - `spread = 4.0`
  - `color = Color(1, 1, 1, 1)` (modulated by station script via `modulate`)
- `draw_pass_1` = `QuadMesh` size `Vector2(0.04, 0.04)` with a basic `StandardMaterial3D` whose `albedo_color` is left white (the station script tints the particles via `modulate` to match `sauce_color`).

No other scene changes.

## COGITO Integration

- `SauceStation` extends `TruckStation`. Interaction primitive owned by `InteractionStateMachine`.
- `BasicInteraction` (COGITO) is reused as-is for the prompt overlay; the gameplay press itself routes through ISM, not COGITO.
- All inter-system communication remains routed via `EventBus.order_step_completed`. The Phase 4 `OrderManager` is queried defensively with `get_node_or_null("/root/OrderManager")` and given a `record_step(ingredient_id, quality)` call — the same call shape that `OrderManager` will be authored to accept.
- `GPUParticles3D` is a Godot built-in — no addon dependency.

## Implementation Steps

1. **Open `SauceStation.tscn`.** Add a child node `SauceStream : GPUParticles3D` under the root.
2. **Configure `SauceStream`** with the values listed in *Scene Architecture* above. Save the scene.
3. **Update `SauceStation.gd`** to cache the `SauceStream` node in `_ready()` and tint its `modulate` to `sauce_color`.
4. **Drive emission** in `on_interaction_start()` (turn on) and `on_interaction_complete()` (turn off). Also turn off in a new `on_hover_exit()` override as a safety net for under-pour cancels (under-pour does not call `on_interaction_complete`).
5. **Modulate `amount_ratio`** in `on_interaction_tick(progress)` so longer holds emit more particles. Use `clampf(progress, 0.0, 1.0)`.
6. **Forward to `OrderManager`** in `on_interaction_complete()` via a null-safe `get_node_or_null` lookup. Place this call AFTER the `EventBus.order_step_completed.emit()` so the EventBus is canonical and OrderManager is a redundant write that becomes meaningful in Phase 4.
7. **Confirm thresholds in code.** No code change needed — `_evaluate_hold()` already uses 0.45/0.75. Add a docstring block to `SauceStation.gd` explicitly stating the contract so future contributors do not duplicate the thresholds at the station level.
8. **Smoke test.** Enter `TruckInterior.tscn`, hold `mm_interact` on the white sauce bottle. Verify particle stream visible, gauge fills, releasing in green band emits `order_step_completed("white_sauce", 2)`, releasing in red band emits `order_step_completed("white_sauce", 3)`, releasing under 0.45 emits nothing.
9. **Pool note.** The particle node is part of the station scene tree — it is NOT a `NodePool` candidate. The `SauceStream.tscn` entry in `NodePool.PREWARM_CONFIG` is a *separate* burst-particle scene used for one-shot splash effects in Phase 3 and is unrelated to this in-station emitter.

## Code Implementation

### `res://_src/interactables/SauceStation.gd` — COMPLETE updated file

```gdscript
## SauceStation.gd
## Sauce dispenser station. Extends TruckStation with HOLD interaction type.
##
## INTERACTION CONTRACT:
##   The HOLD primitive lives in InteractionStateMachine (ISM). The station does
##   NOT own the 0.45 / 0.75 threshold constants — those are
##   InteractionStateMachine.HOLD_GREEN_MIN and HOLD_GREEN_MAX. This separation
##   is deliberate: the primitive is shared across all HOLD-type stations
##   (sauces, future drink dispensers), and the station only owns ingredient
##   identity, color, and the visual stream.
##
##   Under-pour behaviour (hold_progress < HOLD_GREEN_MIN) is also owned by ISM:
##   the player can release early without penalty and try again. The station
##   never receives on_interaction_complete for an under-pour — only
##   on_hover_exit if the player walks away.
##
## VISUAL:
##   A GPUParticles3D node "SauceStream" emits droplets while held.
##   Particles are tinted by sauce_color via .modulate.
##   amount_ratio is driven by on_interaction_tick(progress) so the stream
##   thickens as the gauge fills.
##
## ECONOMY HOOKUP:
##   on_interaction_complete() emits EventBus.order_step_completed and, when
##   OrderManager exists (Phase 4), calls OrderManager.record_step() directly.
##   Until OrderManager is registered as an autoload, the direct call is a
##   silent no-op via get_node_or_null.
##
## Path: res://_src/interactables/SauceStation.gd

extends TruckStation
class_name SauceStation

# ─────────────────────────────────────────────────────────────────────────────
# EXPORTS
# ─────────────────────────────────────────────────────────────────────────────

## Visual color applied to the CSG cylinder mesh and the particle stream.
## Override per instance in TruckInterior.tscn inspector.
@export var sauce_color: Color = Color(0.95, 0.95, 0.90, 1)

## Ingredient ID string matching keys in RecipeData and EconomyConfig.
## Set to "red_sauce" or "white_sauce" per instance.
@export var ingredient_id: String = "white_sauce"

# ─────────────────────────────────────────────────────────────────────────────
# CONSTANTS
# ─────────────────────────────────────────────────────────────────────────────

## Name of the CSG mesh node inside SauceStation.tscn.
const CSG_NODE_NAME: StringName = &"CSGWhiteSauce"

## Name of the particle emitter inside SauceStation.tscn.
const STREAM_NODE_NAME: StringName = &"SauceStream"

# ─────────────────────────────────────────────────────────────────────────────
# NODE REFERENCES
# ─────────────────────────────────────────────────────────────────────────────

var _csg_mesh: Node = null
var _material: StandardMaterial3D = null
var _stream: GPUParticles3D = null

# ─────────────────────────────────────────────────────────────────────────────
# LIFECYCLE
# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	interaction_type = InteractionType.HOLD
	interact_action = &"mm_interact"
	interaction_prompt_text = "Dispense Sauce"

	_csg_mesh = get_node_or_null(CSG_NODE_NAME)
	if _csg_mesh == null:
		push_warning("[SauceStation] CSG mesh '%s' not found." % CSG_NODE_NAME)
	else:
		_apply_color()

	_stream = get_node_or_null(STREAM_NODE_NAME) as GPUParticles3D
	if _stream == null:
		push_warning("[SauceStation] '%s' GPUParticles3D node missing — visual stream disabled." % STREAM_NODE_NAME)
	else:
		_stream.emitting = false
		_stream.modulate = sauce_color
		_stream.amount_ratio = 0.0

# ─────────────────────────────────────────────────────────────────────────────
# COLOR APPLICATION
# ─────────────────────────────────────────────────────────────────────────────

func _apply_color() -> void:
	if _csg_mesh == null:
		return
	_material = StandardMaterial3D.new()
	_material.albedo_color = sauce_color
	_csg_mesh.set_material(_material)

# ─────────────────────────────────────────────────────────────────────────────
# TRUCK STATION VIRTUAL OVERRIDES
# ─────────────────────────────────────────────────────────────────────────────

func on_hover_enter() -> void:
	# Reserved for highlight shader / SFX (Task 6.4).
	pass

func on_hover_exit() -> void:
	# Safety net: if the player walks away mid-pour the ISM resets to IDLE
	# without calling on_interaction_complete. Make absolutely sure the
	# particle stream is off so we never strand emitting particles.
	_stop_stream()

func on_interaction_start() -> void:
	_start_stream()

func on_interaction_tick(progress: float) -> void:
	if not is_instance_valid(_stream):
		return
	# Thicken the stream as the gauge fills. Floor at 0.25 so the stream is
	# visible from the very first frame of the hold.
	_stream.amount_ratio = clampf(progress, 0.25, 1.0)

func on_interaction_complete(result: int) -> void:
	_stop_stream()

	var result_dict: Dictionary = {
		"ingredient_id": ingredient_id,
		"quality": result,
	}
	interaction_completed.emit(self, result_dict)

	# Canonical pipeline: EventBus is the source of truth.
	EventBus.order_step_completed.emit(ingredient_id, result)

	# Forward-wire to OrderManager (Phase 4). Null-safe today, active when
	# the autoload is registered. No code change required at that point.
	var order_mgr: Node = get_node_or_null("/root/OrderManager")
	if is_instance_valid(order_mgr) and order_mgr.has_method("record_step"):
		order_mgr.call("record_step", ingredient_id, result)

	if OS.is_debug_build():
		print("[SauceStation] order_step_completed.emit('%s', %d)" % [ingredient_id, result])

# ─────────────────────────────────────────────────────────────────────────────
# PARTICLE STREAM HELPERS
# ─────────────────────────────────────────────────────────────────────────────

func _start_stream() -> void:
	if not is_instance_valid(_stream):
		return
	_stream.modulate = sauce_color
	_stream.amount_ratio = 0.25
	_stream.restart()
	_stream.emitting = true

func _stop_stream() -> void:
	if not is_instance_valid(_stream):
		return
	_stream.emitting = false
	_stream.amount_ratio = 0.0
```

### Documentation patch on `InteractionStateMachine.gd` — no behavioural change

Add a docstring block above the `_evaluate_hold()` definition to lock the contract in place:

```gdscript
## HOLD primitive contract (used by all HOLD-type stations, e.g. SauceStation):
##
##   hold_progress < HOLD_GREEN_MIN (0.45)        →  under-pour
##       _reset_to_hover() — NO completion signal, NO economy debit.
##       The station receives on_hover_exit only if the player walks away.
##
##   HOLD_GREEN_MIN ≤ hold_progress ≤ HOLD_GREEN_MAX (0.45 – 0.75)
##       _complete_interaction(IngredientState.State.PERFECT)
##       Station receives on_interaction_complete(2).
##
##   hold_progress > HOLD_GREEN_MAX (0.75)        →  over-pour
##       _complete_interaction(IngredientState.State.SLOPPY)
##       Station receives on_interaction_complete(3).
##
## These thresholds are owned here, not by the station, because the HOLD
## primitive is shared across all HOLD-type stations. Stations own ingredient
## identity and visuals only.
func _evaluate_hold() -> void:
	if hold_progress < HOLD_GREEN_MIN:
		_reset_to_hover()
		return
	if hold_progress <= HOLD_GREEN_MAX:
		_complete_interaction(IngredientState.State.PERFECT)
	else:
		_complete_interaction(IngredientState.State.SLOPPY)
```
