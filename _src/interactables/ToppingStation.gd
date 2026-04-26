## ToppingStation.gd
## Topping dispenser station. Extends TruckStation with TIMING interaction type.
##
## Visual color is driven by the @export var topping_color. Set per instance
## in TruckInterior.tscn via the Inspector:
##   CilantroStation → topping_color = Color(0.18, 0.65, 0.22, 1)  (fresh green)
##   TomatoStation   → topping_color = Color(0.90, 0.22, 0.10, 1)  (tomato red-orange)
##   OnionStation    → topping_color = Color(0.92, 0.86, 0.78, 1)  (light tan/beige)
##
## The CSG mesh node is "CSGCilantro" in ToppingStation.tscn — shared for all
## topping types; color differentiates them visually.
##
## Interaction logic (shrinking circle) lives in InteractionStateMachine.
## This script owns: color setup, SFX hooks, and interaction_completed emission.
## On a timing miss the ISM calls EconomyManager.debit(0.05) directly before
## calling _reset_to_hover — this station only handles successful completions.
##
## Path: res://_src/interactables/ToppingStation.gd

extends TruckStation
class_name ToppingStation

# ─────────────────────────────────────────────────────────────────────────────
# EXPORTS
# ─────────────────────────────────────────────────────────────────────────────

## Visual color applied to the CSG box mesh at _ready().
## Override per instance in TruckInterior.tscn inspector.
## Default is cilantro green.
@export var topping_color: Color = Color(0.18, 0.65, 0.22, 1)

## Ingredient ID string matching keys in RecipeData and EconomyConfig.
## Set to "cilantro", "tomato", or "onion" per instance.
@export var ingredient_id: String = "cilantro"

# ─────────────────────────────────────────────────────────────────────────────
# NODE REFERENCES
# ─────────────────────────────────────────────────────────────────────────────

## Name of the CSG mesh node inside ToppingStation.tscn.
const CSG_NODE_NAME: String = "CSGCilantro"

var _csg_mesh: Node = null
var _material: StandardMaterial3D = null

# ─────────────────────────────────────────────────────────────────────────────
# LIFECYCLE
# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	interaction_type = InteractionType.TIMING
	interaction_prompt_text = "Add Topping"

	_csg_mesh = get_node_or_null(CSG_NODE_NAME)
	if _csg_mesh == null:
		push_warning("ToppingStation: could not find CSG mesh node '%s'." % CSG_NODE_NAME)
		return

	_apply_color()

# ─────────────────────────────────────────────────────────────────────────────
# COLOR APPLICATION
# ─────────────────────────────────────────────────────────────────────────────

func _apply_color() -> void:
	if _csg_mesh == null:
		return

	_material = StandardMaterial3D.new()
	_material.albedo_color = topping_color
	# Use set_material so we do not mutate the shared .tscn sub_resource.
	_csg_mesh.set_material(_material)

# ─────────────────────────────────────────────────────────────────────────────
# TRUCK STATION VIRTUAL OVERRIDES
# ─────────────────────────────────────────────────────────────────────────────

func on_hover_enter() -> void:
	# Reserved for highlight or SFX.
	pass

func on_hover_exit() -> void:
	pass

func on_interaction_start() -> void:
	print("[%s] Interaction START" % name)
	# Reserved for topping-start SFX (Task 1.6).
	pass

func on_interaction_tick(progress: float) -> void:
	# progress is normalised 0.0–1.0 (1.0 = fully shrunk circle).
	# Reserved for visual feedback animation (Task 1.6).
	pass

func on_interaction_complete(result: int) -> void:
	print("[%s] Interaction COMPLETE (Result: %d)" % [name, result])
	var result_dict: Dictionary = {
		"ingredient_id": ingredient_id,
		"quality": result,
	}
	interaction_completed.emit(self, result_dict)

	# Notify EventBus so OrderManager can record the step.
	EventBus.order_step_completed.emit(ingredient_id, result)

func on_interaction_interrupted() -> void:
	print("[%s] Interaction INTERRUPTED" % name)
