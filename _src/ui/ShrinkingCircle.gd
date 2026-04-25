extends Control
class_name ShrinkingCircle

@export var ism: InteractionStateMachine

var _current_radius: float = 0.0

func _ready() -> void:
	if is_instance_valid(ism):
		ism.timing_radius_changed.connect(_on_radius_changed)
		ism.crosshair_state_changed.connect(_on_crosshair_changed)
		ism.station_focus_entered.connect(_on_station_entered)
		ism.station_focus_exited.connect(_on_station_exited)

func _on_radius_changed(radius: float) -> void:
	_current_radius = radius
	visible = true
	queue_redraw()

func _on_crosshair_changed(crosshair_state: String) -> void:
	print("[DEBUG] Crosshair state: ", crosshair_state)
	if crosshair_state == "idle" or crosshair_state == "hover":
		visible = false
		_current_radius = 0.0

func _on_station_entered(station: TruckStation) -> void:
	print("[DEBUG] Now interacting with: ", station.display_name if station else "Unknown")

func _on_station_exited(_station: TruckStation) -> void:
	print("[DEBUG] Stopped interacting with object.")

func _draw() -> void:
	var center = get_rect().size / 2.0
	
	# Target band (mirrors ISM.TIMING_TARGET_MIN/MAX)
	draw_arc(center, 105.0, 0, TAU, 64, Color(1, 1, 1, 0.25), 50.0, true)
	
	# Shrinking ring
	if _current_radius > 0:
		draw_arc(center, _current_radius, 0, TAU, 64, Color(1, 1, 1, 0.9), 4.0, true)
