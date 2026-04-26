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
const CSG_NODE_NAME: String = "CSGMeat"

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
