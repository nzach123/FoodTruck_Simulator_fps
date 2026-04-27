## ShrinkingCircle.gd
## HUD overlay that draws the TIMING interaction shrinking-circle indicator.
##
## RESPONSIBILITIES:
##   - Listen to ISM.timing_radius_changed to update the shrinking ring.
##   - Listen to ISM.crosshair_state_changed to hide itself outside TIMING state.
##   - Draw the static target-band arc and the animated shrinking ring via _draw().
##
## DOES NOT:
##   - Own any timing logic (→ InteractionStateMachine)
##   - Evaluate success/miss (→ ISM._evaluate_timing)
##
## The target band radius is derived from ISM.TIMING_TARGET_MIN/MAX at draw-time
## so the visual automatically tracks constant changes.
##
## Path: res://_src/ui/ShrinkingCircle.gd

extends Control
class_name ShrinkingCircle

@export var ism: InteractionStateMachine

var _current_radius: float = 0.0

func _ready() -> void:
	if is_instance_valid(ism):
		ism.timing_radius_changed.connect(_on_radius_changed)
		ism.crosshair_state_changed.connect(_on_crosshair_changed)

func _on_radius_changed(radius: float) -> void:
	_current_radius = radius
	visible = true
	queue_redraw()

func _on_crosshair_changed(crosshair_state: String) -> void:
	if crosshair_state == "idle" or crosshair_state == "hover":
		visible = false
		_current_radius = 0.0

func _draw() -> void:
	var center = get_rect().size / 2.0

	# Target band arc radius: midpoint of TIMING_TARGET_MIN and TIMING_TARGET_MAX.
	# Read from ISM constants so this stays in sync if the constants change.
	# Falls back to (80 + 130) / 2 = 105.0 if ism is not connected.
	var target_radius: float = 105.0
	if is_instance_valid(ism):
		target_radius = (ism.TIMING_TARGET_MIN + ism.TIMING_TARGET_MAX) / 2.0
	draw_arc(center, target_radius, 0, TAU, 64, Color(1, 1, 1, 0.25), 50.0, true)
	
	# Shrinking ring
	if _current_radius > 0:
		draw_arc(center, _current_radius, 0, TAU, 64, Color(1, 1, 1, 0.9), 4.0, true)
