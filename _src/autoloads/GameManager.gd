## GameManager.gd
## Core game state machine. Owns the day lifecycle and phase transitions.
##
## RESPONSIBILITIES:
##   - Track current GamePhase (MAIN_MENU → TUTORIAL → PLAYING → END_OF_DAY)
##   - Own the 5-minute day countdown timer (visual only; use _process)
##   - Load DayConfig resources from DifficultySchedule.tres
##   - Trigger EconomyManager, QueueManager resets at day start
##   - Trigger save, then emit day_ended on countdown expiry
##
## DOES NOT:
##   - Handle money or transactions (→ EconomyManager)
##   - Spawn customers (→ QueueManager)
##   - Track orders (→ OrderManager)
##
## Registered in: Project Settings > Autoloads > GameManager
## Path: res://_src/autoloads/GameManager.gd

extends Node

# ─────────────────────────────────────────────────────────────────────────────
# CONSTANTS
# ─────────────────────────────────────────────────────────────────────────────

## Total day duration in seconds (5 minutes).
const DAY_DURATION_SECONDS: float = 300.0

## Path to the DifficultySchedule resource array (Array[DayConfig]).
const DIFFICULTY_SCHEDULE_PATH: String = "res://_src/data/difficulty/DifficultySchedule.tres"

# ─────────────────────────────────────────────────────────────────────────────
# ENUMS
# ─────────────────────────────────────────────────────────────────────────────

## All valid top-level game phases.
## The state machine only advances forward; no phase can revert to a prior phase.
enum GamePhase {
	MAIN_MENU,   # Title/save-load screen — no gameplay active
	TUTORIAL,    # Day 0 scripted orders — patience disabled, spawns manual
	PLAYING,     # Live day — timer running, real customers, economy active
	END_OF_DAY,  # Score screen + upgrade shop — timer stopped, input blocked
}

# ─────────────────────────────────────────────────────────────────────────────
# STATE VARIABLES
# ─────────────────────────────────────────────────────────────────────────────

## The currently active phase. Read-only outside GameManager.
var current_phase: GamePhase = GamePhase.MAIN_MENU

## Which calendar day we are on. Day 0 = tutorial; Day 1+ = live service.
var current_day: int = 0

## Remaining seconds on the day countdown. Set to DAY_DURATION_SECONDS on start.
## Decremented in _process; used by GameHUD to display MM:SS timer.
var day_timer: float = DAY_DURATION_SECONDS

## Controls whether _process should decrement day_timer.
## False during MAIN_MENU, TUTORIAL pre-start, END_OF_DAY, and modal popups.
var is_timer_running: bool = false

## The loaded DayConfig resource for the current day. Null before start_day().
## Read by QueueManager, EconomyManager, and Customer nodes.
var difficulty_config: Resource = null  # DayConfig — typed after resource script exists

## Full difficulty schedule loaded at boot. Index = day number.
var _difficulty_schedule: Array = []

# ─────────────────────────────────────────────────────────────────────────────
# LIFECYCLE
# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_load_difficulty_schedule()


func _process(delta: float) -> void:
	# Only tick the countdown during the PLAYING phase with the timer active.
	# TUTORIAL uses a different flow (manual customer pushes, no countdown).
	if not is_timer_running:
		return
	if current_phase != GamePhase.PLAYING:
		return

	day_timer -= delta

	if day_timer <= 0.0:
		day_timer = 0.0
		end_day()

# ─────────────────────────────────────────────────────────────────────────────
# PUBLIC API
# ─────────────────────────────────────────────────────────────────────────────

## Call this from MainMenu ([New Game] / [Continue]) or EndOfDayScreen ([Next Day]).
## day: the day index to start (0 = tutorial, 1+ = live service).
func start_day(day: int) -> void:
	current_day = day
	difficulty_config = get_day_config(day)

	# Determine phase: Day 0 is always tutorial mode.
	if day == 0:
		current_phase = GamePhase.TUTORIAL
		is_timer_running = false  # Tutorial has no countdown
	else:
		current_phase = GamePhase.PLAYING
		day_timer = DAY_DURATION_SECONDS
		is_timer_running = true

	# Bail-out check: if player ended yesterday at $0, QueueManager will
	# handle the RegularCustomer bailout cutscene after this signal fires.
	EventBus.day_started.emit(current_day)

	push_warning("[GameManager] Day %d started. Phase: %s" % [current_day, GamePhase.keys()[current_phase]])


## Called automatically when day_timer reaches zero, or manually by tutorial completion.
## Stops the timer, saves progress, then emits day_ended for EndOfDayScreen.
func end_day() -> void:
	is_timer_running = false
	current_phase = GamePhase.END_OF_DAY

	# Auto-save BEFORE showing the end-of-day screen.
	# SaveManager is registered as an autoload in Phase 3.
	# Use get_node to avoid a parse-time error when it is not yet registered.
	var save_mgr: Node = get_node_or_null("/root/SaveManager")
	if save_mgr:
		save_mgr.call("save", save_mgr.call("build_save_dict"))

	EventBus.day_ended.emit(current_day)
	push_warning("[GameManager] Day %d ended." % current_day)


## Returns the DayConfig resource for a given day number.
## Falls back to the last defined config if day exceeds the schedule length.
## Returns null only if the schedule failed to load entirely.
func get_day_config(day: int) -> Resource:
	if _difficulty_schedule.is_empty():
		push_error("[GameManager] Difficulty schedule is empty — check DifficultySchedule.tres path.")
		return null

	# Clamp to last defined day config for days beyond the schedule.
	var idx: int = clamp(day, 0, _difficulty_schedule.size() - 1)
	return _difficulty_schedule[idx]


## Convenience: returns remaining time formatted as "MM:SS" for the HUD.
func get_timer_display() -> String:
	var mins: int = int(day_timer) / 60
	var secs: int = int(day_timer) % 60
	return "%02d:%02d" % [mins, secs]

# ─────────────────────────────────────────────────────────────────────────────
# PRIVATE HELPERS
# ─────────────────────────────────────────────────────────────────────────────

## Load the DifficultySchedule resource at boot.
## Expected type: Resource with @export var days: Array[DayConfig]
func _load_difficulty_schedule() -> void:
	if not ResourceLoader.exists(DIFFICULTY_SCHEDULE_PATH):
		push_warning("[GameManager] DifficultySchedule.tres not found at '%s'. Create it before starting Day 1." % DIFFICULTY_SCHEDULE_PATH)
		return

	var schedule_resource: Resource = ResourceLoader.load(DIFFICULTY_SCHEDULE_PATH)

	# The schedule resource exposes a 'days' property (Array[DayConfig]).
	# If the resource type isn't finalised yet, guard with has_method.
	if schedule_resource and schedule_resource.get("days") != null:
		_difficulty_schedule = schedule_resource.days
	else:
		push_error("[GameManager] DifficultySchedule.tres exists but has no 'days' property.")
