extends PanelContainer
class_name MunchPrompt

@export var ism: InteractionStateMachine

@onready var interaction_text: Label = $HBoxContainer/InteractionText
@onready var interaction_button: DynamicInputIcon = $HBoxContainer/Container/InteractionButton

func _ready() -> void:
	visible = false
	if is_instance_valid(ism):
		ism.station_focus_entered.connect(_on_station_entered)
		ism.station_focus_exited.connect(_on_station_exited)
		ism.crosshair_state_changed.connect(_on_crosshair_changed)

func _on_station_entered(station: TruckStation) -> void:
	if OS.is_debug_build():
		print("[DEBUG] MunchPrompt: station entered: ", station.display_name)
	interaction_text.text = station.interaction_prompt_text
	visible = true

func _on_station_exited(_station: TruckStation) -> void:
	if OS.is_debug_build():
		print("[DEBUG] MunchPrompt: station exited")
	visible = false

func _on_crosshair_changed(crosshair_state: String) -> void:
	# Hide prompt during active interaction (TIMING, HOLD, etc.)
	if crosshair_state == "active":
		visible = false
	elif crosshair_state == "hover":
		# Only show if we have an active station
		if is_instance_valid(ism) and ism.active_station != null:
			visible = true
