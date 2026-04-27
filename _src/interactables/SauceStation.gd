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
const CSG_NODE_NAME: String = "CSGWhiteSauce"

## Name of the particle emitter inside SauceStation.tscn.
const STREAM_NODE_NAME: String = "SauceStream"

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
		_apply_stream_material()
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

## Creates a unique material for the particle stream to match sauce_color.
func _apply_stream_material() -> void:
	if _stream == null:
		return
	var mat := StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = sauce_color
	mat.billboard_mode = StandardMaterial3D.BILLBOARD_PARTICLES
	_stream.material_override = mat

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
	# Thicken the stream as the gauge fills.
	_stream.amount_ratio = clampf(progress, 0.5, 1.0)

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
	_stream.amount_ratio = 1.0
	_stream.restart()
	_stream.emitting = true

func _stop_stream() -> void:
	if not is_instance_valid(_stream):
		return
	_stream.emitting = false
	_stream.amount_ratio = 0.0
