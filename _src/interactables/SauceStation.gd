## SauceStation.gd
## Sauce dispenser station. Extends TruckStation with HOLD interaction type.
##
## Visual color is driven by the @export var sauce_color. Set this per instance
## in TruckInterior.tscn via the Inspector:
##   WhiteSauceStation → sauce_color = Color(0.95, 0.95, 0.90, 1)
##   RedSauceStation   → sauce_color = Color(0.85, 0.12, 0.12, 1)
##
## The CSG mesh name is "CSGWhiteSauce" in SauceStation.tscn — it is shared
## for both sauce types; color differentiates them visually.
##
## Interaction logic (hold fill, zone evaluation) lives in InteractionStateMachine.
## This script owns: color setup, SFX hooks, and interaction_completed emission.
##
## Path: res://_src/interactables/SauceStation.gd

extends TruckStation
class_name SauceStation

# ─────────────────────────────────────────────────────────────────────────────
# EXPORTS
# ─────────────────────────────────────────────────────────────────────────────

## Visual color applied to the CSG cylinder mesh at _ready().
## Override per instance in TruckInterior.tscn inspector.
## Default is white sauce (Color(0.95, 0.95, 0.90, 1)).
@export var sauce_color: Color = Color(0.95, 0.95, 0.90, 1)

## Ingredient ID string matching keys in RecipeData and EconomyConfig.
## Set to "red_sauce" or "white_sauce" per instance.
@export var ingredient_id: String = "white_sauce"

# ─────────────────────────────────────────────────────────────────────────────
# NODE REFERENCES
# ─────────────────────────────────────────────────────────────────────────────

## Name of the CSG mesh node inside SauceStation.tscn.
const CSG_NODE_NAME: String = "CSGWhiteSauce"

var _csg_mesh: Node = null
var _material: StandardMaterial3D = null

# ─────────────────────────────────────────────────────────────────────────────
# LIFECYCLE
# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	interaction_type = InteractionType.HOLD
	interaction_prompt_text = "Dispense Sauce"

	_csg_mesh = get_node_or_null(CSG_NODE_NAME)
	if _csg_mesh == null:
		push_warning("SauceStation: could not find CSG mesh node '%s'." % CSG_NODE_NAME)
		return

	_apply_color()

# ─────────────────────────────────────────────────────────────────────────────
# COLOR APPLICATION
# ─────────────────────────────────────────────────────────────────────────────

func _apply_color() -> void:
	if _csg_mesh == null:
		return

	_material = StandardMaterial3D.new()
	_material.albedo_color = sauce_color
	# Use surface_material_override so we do not mutate the shared .tscn sub_resource.
	_csg_mesh.set_material(_material)

# ─────────────────────────────────────────────────────────────────────────────
# TRUCK STATION VIRTUAL OVERRIDES
# ─────────────────────────────────────────────────────────────────────────────

func on_hover_enter() -> void:
	# Reserved for highlight shader or SFX in a future task.
	pass

func on_hover_exit() -> void:
	pass

func on_interaction_start() -> void:
	# Reserved for sauce-start SFX (Task 1.7).
	pass

func on_interaction_tick(progress: float) -> void:
	# Reserved for sauce stream particle rate (Task 1.7).
	pass

func on_interaction_complete(result: int) -> void:
	var result_dict: Dictionary = {
		"ingredient_id": ingredient_id,
		"quality": result,
	}
	interaction_completed.emit(self, result_dict)

	# Notify EventBus so OrderManager can record the step.
	EventBus.order_step_completed.emit(ingredient_id, result)
