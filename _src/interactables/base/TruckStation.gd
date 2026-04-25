## TruckStation.gd
## Base class for all cooking stations in the Midnight Munch food truck.
##
## Architecture rules:
##   - InteractionStateMachine (ISM) is the ONLY node that calls virtual methods
##     (on_hover_enter, on_hover_exit, on_interaction_start, on_interaction_tick,
##     on_interaction_complete). Stations never call back into the ISM.
##   - Stations emit signals upward. The ISM and OrderManager listen.
##   - All interaction TYPE logic lives in the ISM. Stations are data + visual only.
##
## Subclass by creating a script that extends TruckStation and overrides
## the on_* virtual methods as needed.
##
## Registered in: _src/interactables/<StationName>.gd (per station)
## Path: res://_src/interactables/base/TruckStation.gd

extends Node3D
class_name TruckStation

# ─────────────────────────────────────────────────────────────────────────────
# ENUMS
# ─────────────────────────────────────────────────────────────────────────────

## Maps to the four cooking interaction primitives defined in the GDD.
## The InteractionStateMachine reads this and branches into the correct state.
enum InteractionType {
	INSTANT,  ## Single click completes immediately. Used by Tortilla and Bell.
	MASH,     ## Rapid button presses fill a radial bar. Used by Trompo.
	HOLD,     ## Hold button to fill a vertical gauge. Used by Sauce stations.
	TIMING,   ## Shrinking circle; click in target band. Used by Topping stations.
}

# ─────────────────────────────────────────────────────────────────────────────
# EXPORTS
# ─────────────────────────────────────────────────────────────────────────────

## Which interaction primitive this station uses.
## The ISM reads this on HOVER → ACTIVE transition.
@export var interaction_type: InteractionType = InteractionType.INSTANT

## Human-readable name shown in interaction prompts and HUD.
@export var display_name: String = "Station"

## Short verb phrase shown in the interaction prompt when hovering.
## Example: "Take Tortilla", "Slice Meat", "Dispense Sauce"
@export var interaction_prompt_text: String = "Interact"

## If true, the ISM will only allow interaction when the player
## has a food item in their hand slot (e.g. Trompo requires tortilla).
## Enforcement logic lives in the ISM, not here.
@export var requires_held_item: bool = false

# ─────────────────────────────────────────────────────────────────────────────
# SIGNALS
# ─────────────────────────────────────────────────────────────────────────────

## Emitted when the player raycast first hits this station.
## Listener: InteractionStateMachine (currently unused — ISM uses raycast directly;
## reserved for future prompt/tutorial systems).
signal station_hovered(station: TruckStation)

## Emitted when the player raycast stops hitting this station.
## Listener: Same as above.
signal station_unhovered(station: TruckStation)

## Emitted by the subclass (or by on_interaction_complete) when
## an interaction finishes. The result Dictionary must contain:
##   "quality": int  — IngredientState enum value (PERFECT=2, SLOPPY=3, MISSING=4)
##   "ingredient_id": String  — matches RecipeData ingredient key
## Listener: OrderManager
signal interaction_completed(station: TruckStation, result: Dictionary)

# ─────────────────────────────────────────────────────────────────────────────
# VIRTUAL CALLBACKS  (called by InteractionStateMachine only)
# ─────────────────────────────────────────────────────────────────────────────

## Called the first physics frame the player raycast hits this station.
## Override to: play hover SFX, highlight mesh, show world prompt.
func on_hover_enter() -> void:
	pass

## Called the first physics frame the player raycast leaves this station.
## Override to: remove highlight, hide world prompt.
func on_hover_exit() -> void:
	pass

## Called when the player presses mm_interact while hovering (HOVER → ACTIVE).
## Override to: play start SFX, reset any internal progress counters.
func on_interaction_start() -> void:
	pass

## Called every physics tick while an interaction is in progress.
## progress is normalised 0.0–1.0 (mash fill, hold fill, or 1.0 - timing_ratio).
## Override to: drive station-local animations (e.g. meat spinning faster).
func on_interaction_tick(progress: float) -> void:
	pass

## Called by the ISM when the interaction resolves (complete or miss).
## result is an IngredientState enum int: PERFECT=2, SLOPPY=3, MISSING=4.
## Override to: emit interaction_completed, notify EventBus, play SFX.
func on_interaction_complete(result: int) -> void:
	pass
