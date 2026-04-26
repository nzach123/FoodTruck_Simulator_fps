## TortillaStation.gd
## Tortilla pickup station. Extends TruckStation with INSTANT interaction type.
##
## This station handles the immediate pickup of a tortilla base.
## When interacted with, it emits EventBus.tortilla_taken to signal the
## OrderManager (Phase 4) to checkout a TacoBase from NodePool and
## parent it to the player's hand.
##
## Interaction logic (instant resolution) lives in InteractionStateMachine.
## This script owns: interaction type setup, signal emission.
##
## Path: res://_src/interactables/TortillaStation.gd

extends TruckStation
class_name TortillaStation

# ─────────────────────────────────────────────────────────────────────────────
# EXPORTS
# ─────────────────────────────────────────────────────────────────────────────

## Ingredient ID string used by future analytics/save.
## Tortilla is the base and is also tracked as a mandatory recipe step.
@export var ingredient_id: String = "tortilla"

# ─────────────────────────────────────────────────────────────────────────────
# LIFECYCLE
# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	interaction_type = InteractionType.INSTANT
	interaction_prompt_text = "Take Tortilla"

# ─────────────────────────────────────────────────────────────────────────────
# TRUCK STATION VIRTUAL OVERRIDES
# ─────────────────────────────────────────────────────────────────────────────

func on_hover_enter() -> void:
	# Reserved for highlight shader or SFX in a future task.
	pass

func on_hover_exit() -> void:
	pass

func on_interaction_start() -> void:
	print("[%s] Interaction START" % name)
	# Reserved for pickup SFX (Task 1.7).
	pass

func on_interaction_tick(_progress: float) -> void:
	# Never called for INSTANT type.
	pass

func on_interaction_complete(result: int) -> void:
	print("[%s] Interaction COMPLETE (Result: %d)" % [name, result])
	# result = IngredientState.State.PERFECT (2) for all INSTANT interactions.
	
	var result_dict: Dictionary = {
		"ingredient_id": ingredient_id,
		"quality": result,
	}
	interaction_completed.emit(self, result_dict)

	# Notify EventBus so OrderManager can record the step.
	EventBus.order_step_completed.emit(ingredient_id, result)

	# Notify EventBus that a tortilla was taken.
	# Phase 4 OrderManager listens for this to handle TacoBase lifecycle.
	EventBus.tortilla_taken.emit()

func on_interaction_interrupted() -> void:
	print("[%s] Interaction INTERRUPTED" % name)
