## HoldGauge.gd
## Visual feedback for the HOLD sauce-pour interaction.
##
## Draws a vertical fill bar right of centre. The bar fills from bottom as the
## player holds mm_interact, turns green inside the PERFECT zone (0.45–0.75),
## and orange outside. Hidden whenever not in HOLD state.
##
## Mirrors HOLD_GREEN_MIN / HOLD_GREEN_MAX from InteractionStateMachine exactly;
## update both places if thresholds change.
##
## Path: res://_src/ui/HoldGauge.gd

extends Control
class_name HoldGauge

@export var ism: InteractionStateMachine

const BAR_WIDTH: float = 22.0
const BAR_HEIGHT: float = 180.0
## Horizontal offset from screen centre (positive = right).
const BAR_OFFSET_X: float = 80.0

## Must match ISM.HOLD_GREEN_MIN / ISM.HOLD_GREEN_MAX.
const GREEN_MIN: float = 0.45
const GREEN_MAX: float = 0.75

var _progress: float = 0.0

func _ready() -> void:
	visible = false
	if not is_instance_valid(ism):
		push_error("[HoldGauge] ism export is null — check NodePath in TruckInterior.tscn.")
		return
	ism.hold_progress_changed.connect(_on_progress_changed)
	ism.crosshair_state_changed.connect(_on_crosshair_changed)

func _on_progress_changed(progress: float) -> void:
	_progress = progress
	visible = true
	queue_redraw()

func _on_crosshair_changed(crosshair_state: String) -> void:
	if crosshair_state == "idle" or crosshair_state == "hover":
		visible = false
		_progress = 0.0

func _draw() -> void:
	var rect: Rect2 = get_rect()
	var cx: float = rect.size.x / 2.0 + BAR_OFFSET_X
	var cy: float = rect.size.y / 2.0
	var bar_top_y: float = cy - BAR_HEIGHT / 2.0
	var bar_left_x: float = cx - BAR_WIDTH / 2.0

	# Background
	draw_rect(Rect2(bar_left_x, bar_top_y, BAR_WIDTH, BAR_HEIGHT),
		Color(0.1, 0.1, 0.1, 0.75))

	# Green target zone (grows from bottom, same coordinate origin as fill)
	var zone_bottom_offset: float = BAR_HEIGHT * GREEN_MIN
	var zone_top_offset: float = BAR_HEIGHT * GREEN_MAX
	var zone_top_y: float = bar_top_y + BAR_HEIGHT - zone_top_offset
	var zone_height: float = BAR_HEIGHT * (GREEN_MAX - GREEN_MIN)
	draw_rect(Rect2(bar_left_x, zone_top_y, BAR_WIDTH, zone_height),
		Color(0.2, 0.85, 0.3, 0.35))

	# Fill bar (grows upward from the bottom edge)
	var fill_height: float = BAR_HEIGHT * clampf(_progress, 0.0, 1.0)
	var fill_color: Color
	if _progress >= GREEN_MIN and _progress <= GREEN_MAX:
		fill_color = Color(0.3, 1.0, 0.4, 0.9)
	else:
		fill_color = Color(1.0, 0.45, 0.1, 0.9)
	draw_rect(Rect2(bar_left_x, bar_top_y + BAR_HEIGHT - fill_height, BAR_WIDTH, fill_height),
		fill_color)

	# Border
	draw_rect(Rect2(bar_left_x, bar_top_y, BAR_WIDTH, BAR_HEIGHT),
		Color(1.0, 1.0, 1.0, 0.6), false, 1.5)
