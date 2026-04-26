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
## Note: This station does NOT emit EventBus.order_step_completed because
## a tortilla is the taco base, not a recipe step.
##
## Path: res://_src/interactables/TortillaStation.gd

extends TruckStation
class_name TortillaStation

# ─────────────────────────────────────────────────────────────────────────────
# EXPORTS
# ─────────────────────────────────────────────────────────────────────────────

## Ingredient ID string used by future analytics/save.
## Tortilla is the base, not a recipe step, so this is not emitted via order_step_completed.
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
	# Reserved for pickup SFX (Task 1.7).
	pass

func on_interaction_tick(_progress: float) -> void:
	# Never called for INSTANT type.
	pass

func on_interaction_complete(result: int) -> void:
	# result = IngredientState.State.PERFECT (2) for all INSTANT interactions.
	
	var result_dict: Dictionary = {
		"ingredient_id": ingredient_id,
		"quality": result,
	}
	interaction_completed.emit(self, result_dict)

	# Notify EventBus that a tortilla was taken.
	# Phase 4 OrderManager listens for this to handle TacoBase lifecycle.
	EventBus.tortilla_taken.emit()
	
	if OS.is_debug_build():
		print("[TortillaStation] Tortilla taken (quality=%d)" % result)
