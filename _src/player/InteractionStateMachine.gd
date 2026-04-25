## InteractionStateMachine.gd
## Owns all player interaction input context for Midnight Munch.
##
## Lives as a child of TruckPlayer (CharacterBody3D). Movement (WASD) runs
## independently in TruckPlayer.gd and never interrupts an active interaction.
##
## STATE TRANSITIONS:
##   IDLE   → HOVER   : raycast hits a TruckStation node
##   HOVER  → IDLE    : raycast no longer hits a station
##   HOVER  → ACTIVE  : player presses mm_interact
##   ACTIVE → MASH    : station.interaction_type == MASH
##   ACTIVE → HOLD    : station.interaction_type == HOLD
##   ACTIVE → TIMING  : station.interaction_type == TIMING
##   ACTIVE → IDLE    : station.interaction_type == INSTANT (resolves immediately)
##   Any active → IDLE: interaction complete or cancelled
##
## WEB-SAFETY:
##   - All timing logic in _physics_process (fixed timestep, web-safe).
##   - No await, no yield anywhere in this file.
##   - Input events handled in _unhandled_input only; never polled in physics.
##   - TIMING_SHRINK_SPEED is 30% slower than native feel for web latency.
##   - TIMING_TARGET window is 30% wider than native for web latency.
##
## Path: res://_src/player/InteractionStateMachine.gd

extends Node
class_name InteractionStateMachine

# ─────────────────────────────────────────────────────────────────────────────
# CONSTANTS
# Web-tuned values. Document any changes with a rationale comment.
# ─────────────────────────────────────────────────────────────────────────────

## Starting radius (pixels) of the shrinking circle.
const TIMING_START_RADIUS: float = 400.0

## Inner edge of the success band (pixels). Click must land inside this radius.
## 30% wider window vs native 100 px = 80 px inner bound.
const TIMING_TARGET_MIN: float = 80.0

## Outer edge of the success band (pixels). Click must land outside this radius.
## 30% wider window vs native 100 px = 130 px outer bound.
const TIMING_TARGET_MAX: float = 130.0

## Pixels per second the circle shrinks. Fixed-timestep via _physics_process.
## 30% slower than a native 310 px/s feel = 220 px/s.
const TIMING_SHRINK_SPEED: float = 220.0

## Rate at which hold_progress fills per second (0.0 → 1.0).
## 0.4/s means a full pour takes 2.5 seconds.
const HOLD_FILL_RATE: float = 0.4

## Normalised hold progress: below this is an under-pour (retry, no penalty).
const HOLD_GREEN_MIN: float = 0.45

## Normalised hold progress: above this is a sloppy pour.
const HOLD_GREEN_MAX: float = 0.75

## Normalised progress added per mash keypress (base, no upgrade).
const MASH_PER_PRESS: float = 0.2

## Normalised mash progress value that triggers completion.
const MASH_THRESHOLD: float = 1.0

# ─────────────────────────────────────────────────────────────────────────────
# ENUMS
# ─────────────────────────────────────────────────────────────────────────────

enum State {
	IDLE,    ## No station in range.
	HOVER,   ## Station in raycast; prompt visible.
	ACTIVE,  ## Interaction dispatching (one-frame transition state).
	MASH,    ## Trompo: button-mash fills bar.
	HOLD,    ## Sauce: hold fills vertical gauge.
	TIMING,  ## Topping: shrinking circle.
}

# ─────────────────────────────────────────────────────────────────────────────
# EXPORTS
# ─────────────────────────────────────────────────────────────────────────────

## RayCast3D from the player camera. Set in TruckPlayer.tscn inspector.
## Length 3.0 m. Collision mask must be set to physics layer 3 (Stations).
@export var ray_cast: RayCast3D

# ─────────────────────────────────────────────────────────────────────────────
# STATE VARIABLES
# ─────────────────────────────────────────────────────────────────────────────

## Current machine state.
var state: State = State.IDLE

## The station currently in raycast focus (HOVER) or being interacted with (active states).
var active_station: TruckStation = null

## Previous station used to detect hover enter/exit without repeated calls.
var _last_hovered_station: TruckStation = null

## Normalised mash fill progress (0.0 → MASH_THRESHOLD).
var mash_progress: float = 0.0

## Normalised hold fill progress (0.0 → 1.0).
var hold_progress: float = 0.0

## Current timing circle radius in pixels (shrinks toward zero).
var timing_radius: float = 0.0

# ─────────────────────────────────────────────────────────────────────────────
# SIGNALS
# ─────────────────────────────────────────────────────────────────────────────

## Emitted every physics tick during HOLD. Listener: SauceGauge UI.
signal hold_progress_changed(progress: float)

## Emitted every physics tick during MASH. Listener: MashProgressBar UI.
signal mash_progress_changed(progress: float)

## Emitted every physics tick during TIMING. Listener: ShrinkingCircle UI.
signal timing_radius_changed(radius: float)

## Emitted on any state change to drive crosshair visual.
## Values: "idle", "hover", "active"
signal crosshair_state_changed(crosshair_state: String)

## Emitted when a hover starts on a station. Listener: HUD prompt label.
signal station_focus_entered(station: TruckStation)

## Emitted when hover leaves a station. Listener: HUD prompt label.
signal station_focus_exited(station: TruckStation)

# ─────────────────────────────────────────────────────────────────────────────
# LIFECYCLE
# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	if ray_cast == null:
		push_warning("InteractionStateMachine: ray_cast export is not set. Wire RayCast3D in TruckPlayer.tscn.")

# ─────────────────────────────────────────────────────────────────────────────
# PHYSICS PROCESS — raycast + active-state ticking
# ─────────────────────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	_update_hover()

	match state:
		State.HOLD:
			_tick_hold(delta)
		State.TIMING:
			_tick_timing(delta)

# Update hover state based on current raycast result.
# Called every physics tick regardless of interaction state.
func _update_hover() -> void:
	if ray_cast == null:
		return

	var hit_station: TruckStation = null

	if ray_cast.is_colliding():
		var collider := ray_cast.get_collider()
		# Walk up the tree: the collider may be a StaticBody3D child of TruckStation.
		var node := collider
		while node != null:
			if node is TruckStation:
				hit_station = node as TruckStation
				break
			node = node.get_parent()

	# Detect hover enter.
	if hit_station != null and hit_station != _last_hovered_station:
		if _last_hovered_station != null:
			_on_hover_exit(_last_hovered_station)
		_on_hover_enter(hit_station)
		_last_hovered_station = hit_station

	# Detect hover exit.
	if hit_station == null and _last_hovered_station != null:
		_on_hover_exit(_last_hovered_station)
		_last_hovered_station = null

# ─────────────────────────────────────────────────────────────────────────────
# HOVER ENTER / EXIT
# ─────────────────────────────────────────────────────────────────────────────

func _on_hover_enter(station: TruckStation) -> void:
	# Do not interrupt an active interaction.
	if state != State.IDLE:
		return

	active_station = station
	_set_state(State.HOVER)
	station.on_hover_enter()
	station_focus_entered.emit(station)

func _on_hover_exit(station: TruckStation) -> void:
	# Do not interrupt an active interaction.
	if state != State.HOVER:
		return

	station.on_hover_exit()
	station_focus_exited.emit(station)
	active_station = null
	_set_state(State.IDLE)

# ─────────────────────────────────────────────────────────────────────────────
# INPUT — all interaction input routed through _unhandled_input
# ─────────────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	match state:
		State.HOVER:
			if event.is_action_pressed("mm_interact"):
				_start_interaction()

		State.MASH:
			if event.is_action_pressed("mm_mash"):
				_on_mash_press()

		State.HOLD:
			if event.is_action_released("mm_interact"):
				_evaluate_hold()

		State.TIMING:
			if event.is_action_pressed("mm_interact"):
				_evaluate_timing()

# ─────────────────────────────────────────────────────────────────────────────
# INTERACTION START — HOVER → ACTIVE → branch
# ─────────────────────────────────────────────────────────────────────────────

func _start_interaction() -> void:
	if active_station == null:
		return

	_set_state(State.ACTIVE)
	active_station.on_interaction_start()

	match active_station.interaction_type:
		TruckStation.InteractionType.INSTANT:
			_complete_interaction(2)  # 2 = PERFECT

		TruckStation.InteractionType.MASH:
			mash_progress = 0.0
			_set_state(State.MASH)

		TruckStation.InteractionType.HOLD:
			hold_progress = 0.0
			_set_state(State.HOLD)

		TruckStation.InteractionType.TIMING:
			timing_radius = TIMING_START_RADIUS
			_set_state(State.TIMING)

# ─────────────────────────────────────────────────────────────────────────────
# MASH LOGIC
# ─────────────────────────────────────────────────────────────────────────────

func _on_mash_press() -> void:
	mash_progress += MASH_PER_PRESS
	mash_progress_changed.emit(mash_progress)

	if active_station != null:
		active_station.on_interaction_tick(mash_progress / MASH_THRESHOLD)

	if mash_progress >= MASH_THRESHOLD:
		_complete_interaction(2)  # 2 = PERFECT

# ─────────────────────────────────────────────────────────────────────────────
# HOLD LOGIC
# ─────────────────────────────────────────────────────────────────────────────

func _tick_hold(delta: float) -> void:
	hold_progress += HOLD_FILL_RATE * delta
	hold_progress = clampf(hold_progress, 0.0, 1.0)
	hold_progress_changed.emit(hold_progress)

	if active_station != null:
		active_station.on_interaction_tick(hold_progress)

func _evaluate_hold() -> void:
	if hold_progress < HOLD_GREEN_MIN:
		# Under-pour: no penalty, player can retry immediately.
		_reset_to_hover()
		return

	if hold_progress <= HOLD_GREEN_MAX:
		_complete_interaction(2)  # 2 = PERFECT
	else:
		_complete_interaction(3)  # 3 = SLOPPY

# ─────────────────────────────────────────────────────────────────────────────
# TIMING LOGIC
# ─────────────────────────────────────────────────────────────────────────────

func _tick_timing(delta: float) -> void:
	timing_radius -= TIMING_SHRINK_SPEED * delta
	timing_radius_changed.emit(timing_radius)

	if active_station != null:
		# Pass normalised progress: 0 at start, 1 when circle is fully shrunk.
		var normalised: float = 1.0 - clampf(timing_radius / TIMING_START_RADIUS, 0.0, 1.0)
		active_station.on_interaction_tick(normalised)

	if timing_radius <= 0.0:
		_on_timing_miss()

func _evaluate_timing() -> void:
	if timing_radius >= TIMING_TARGET_MIN and timing_radius <= TIMING_TARGET_MAX:
		_complete_interaction(2)  # 2 = PERFECT
	else:
		# Outside target band: counts as a miss with topping drop penalty.
		_on_timing_miss()

func _on_timing_miss() -> void:
	# GDD: -$0.05 penalty on miss; sets sloppy flag; player can retry.
	# Direct call is acceptable: ISM → EconomyManager is a downward call.
	# EconomyManager is a GDScript autoload — use is_instance_valid guard instead
	# of Engine.has_singleton (which only covers C++ engine singletons).
	if is_instance_valid(EconomyManager):
		EconomyManager.debit(0.05, "timing_miss")

	_reset_to_hover()

# ─────────────────────────────────────────────────────────────────────────────
# COMPLETION & RESET
# ─────────────────────────────────────────────────────────────────────────────

## Finalise a successful (or sloppy) interaction.
## result: IngredientState int — PERFECT=2, SLOPPY=3
func _complete_interaction(result: int) -> void:
	if active_station == null:
		return

	active_station.on_interaction_complete(result)
	_set_state(State.IDLE)
	active_station = null
	_last_hovered_station = null

## Return to HOVER after an under-pour or timing miss that allows retry.
## Keeps active_station and _last_hovered_station intact.
func _reset_to_hover() -> void:
	hold_progress = 0.0
	mash_progress = 0.0
	timing_radius = 0.0

	if active_station != null:
		_set_state(State.HOVER)
	else:
		_set_state(State.IDLE)

# ─────────────────────────────────────────────────────────────────────────────
# STATE MANAGEMENT
# ─────────────────────────────────────────────────────────────────────────────

func _set_state(new_state: State) -> void:
	state = new_state

	match new_state:
		State.IDLE:
			crosshair_state_changed.emit("idle")
		State.HOVER:
			crosshair_state_changed.emit("hover")
		State.ACTIVE, State.MASH, State.HOLD, State.TIMING:
			crosshair_state_changed.emit("active")
