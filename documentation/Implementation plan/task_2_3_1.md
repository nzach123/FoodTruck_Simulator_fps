# Task 2.3.1: Interaction Debugging and Spam Removal

## Spam Removal
**File Path:** `addons/cogito/Components/DynamicInputIcon.gd`

```gdscript
func _is_steam_deck() -> bool:
	if RenderingServer.get_rendering_device() == null:
		# print("DynamicInputIcon: ISSUE: No rendering device detected.")
		return false
	if RenderingServer.get_rendering_device().get_device_name().contains("RADV VANGOGH") \
	or OS.get_processor_name().contains("AMD CUSTOM APU 0405"):
		return true
	else:
		return false
```

## Interaction Debugging

*(Note: To properly capture when an interaction is "interrupted" — such as looking away or under-pouring before a completion is reached — a new `on_interaction_interrupted()` hook has been added. The `InteractionStateMachine` must be updated to call this hook when resetting to hover.)*

### Missing Gap: Interaction State Machine
**File Path:** `_src/player/InteractionStateMachine.gd`

```gdscript
## Return to HOVER after an under-pour or timing miss that allows retry.
## Keeps active_station and _last_hovered_station intact.
func _reset_to_hover() -> void:
	hold_progress = 0.0
	mash_progress = 0.0
	timing_radius = 0.0

	if active_station != null:
		if active_station.has_method("on_interaction_interrupted"):
			active_station.on_interaction_interrupted()
		_set_state(State.HOVER)
	else:
		_set_state(State.IDLE)
```

### 1. Base Station / Bell Station
**File Path:** `_src/interactables/base/TruckStation.gd`
*(The Bell Station uses this script directly.)*

```gdscript
func on_interaction_start() -> void:
	print("[%s] Interaction START" % name)

func on_interaction_tick(progress: float) -> void:
	pass

func on_interaction_complete(result: int) -> void:
	print("[%s] Interaction COMPLETE (Result: %d)" % [name, result])

func on_interaction_interrupted() -> void:
	print("[%s] Interaction INTERRUPTED" % name)
```

### 2. Trompo Station
**File Path:** `_src/interactables/TrompoStation.gd`

```gdscript
func on_interaction_start() -> void:
	print("[%s] Interaction START" % name)
	_current_spin = 0.0

func on_interaction_tick(progress: float) -> void:
	_current_spin = clampf(progress, 0.0, 1.0) * MAX_SPIN_RAD_PER_SEC

func on_interaction_complete(result: int) -> void:
	print("[%s] Interaction COMPLETE (Result: %d)" % [name, result])
	_current_spin = 0.0
	
func on_interaction_interrupted() -> void:
	print("[%s] Interaction INTERRUPTED" % name)
	_current_spin = 0.0
```

### 3. Tortilla Station
**File Path:** `_src/interactables/TortillaStation.gd`

```gdscript
func on_interaction_start() -> void:
	print("[%s] Interaction START" % name)
	# Reserved for sizzle start SFX (Task 1.7)
	pass

func on_interaction_tick(_progress: float) -> void:
	pass

func on_interaction_complete(result: int) -> void:
	print("[%s] Interaction COMPLETE (Result: %d)" % [name, result])
	var result_dict: Dictionary = {
		"ingredient_id": ingredient_id,
		"quality": result,
	}
	interaction_completed.emit(self, result_dict)
	EventBus.order_step_completed.emit(ingredient_id, result)

func on_interaction_interrupted() -> void:
	print("[%s] Interaction INTERRUPTED" % name)
```

### 4. Sauce Station
**File Path:** `_src/interactables/SauceStation.gd`

```gdscript
func on_interaction_start() -> void:
	print("[%s] Interaction START" % name)
	# Reserved for sauce-start SFX (Task 1.7).
	pass

func on_interaction_tick(progress: float) -> void:
	# Reserved for sauce stream particle rate (Task 1.7).
	pass

func on_interaction_complete(result: int) -> void:
	print("[%s] Interaction COMPLETE (Result: %d)" % [name, result])
	var result_dict: Dictionary = {
		"ingredient_id": ingredient_id,
		"quality": result,
	}
	interaction_completed.emit(self, result_dict)
	EventBus.order_step_completed.emit(ingredient_id, result)

func on_interaction_interrupted() -> void:
	print("[%s] Interaction INTERRUPTED" % name)
```

### 5. Topping Station
**File Path:** `_src/interactables/ToppingStation.gd`

```gdscript
func on_interaction_start() -> void:
	print("[%s] Interaction START" % name)
	# Reserved for topping drop start SFX (Task 1.7)
	pass

func on_interaction_tick(progress: float) -> void:
	pass

func on_interaction_complete(result: int) -> void:
	print("[%s] Interaction COMPLETE (Result: %d)" % [name, result])
	var result_dict: Dictionary = {
		"ingredient_id": ingredient_id,
		"quality": result,
	}
	interaction_completed.emit(self, result_dict)
	EventBus.order_step_completed.emit(ingredient_id, result)

func on_interaction_interrupted() -> void:
	print("[%s] Interaction INTERRUPTED" % name)
```