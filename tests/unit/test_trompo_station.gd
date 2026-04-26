extends "res://addons/gut/test.gd"

var TrompoStation = load("res://_src/interactables/TrompoStation.gd")
var InteractionStateMachine = load("res://_src/player/InteractionStateMachine.gd")
var TruckStation = load("res://_src/interactables/base/TruckStation.gd")

var _trompo = null
var _ism = null
var _raycast = null

func before_each():
	_trompo = TrompoStation.new()
	_trompo.name = "TrompoStation"
	add_child(_trompo)
	
	# Simulate _ready since it won't run automatically in a test without being in a scene tree properly
	_trompo._ready()
	
	_ism = InteractionStateMachine.new()
	_raycast = RayCast3D.new()
	_ism.ray_cast = _raycast
	add_child(_ism)
	
	# Mock EventBus since it's an autoload
	# In GUT, we can usually just rely on the autoload being there if it's a project setting,
	# but for pure unit tests we might need to be careful.
	# Assuming EventBus is available as it's an autoload in the project.

func after_each():
	_trompo.free()
	_ism.free()
	_raycast.free()

func test_trompo_initialization():
	assert_eq(_trompo.interaction_type, TruckStation.InteractionType.MASH, "Trompo should be MASH type")
	assert_eq(_trompo.requires_held_item, true, "Trompo should require held item")
	assert_eq(_trompo.display_name, "Trompo")

func test_ism_mash_logic():
	# Simulate hovering over the trompo
	_ism.active_station = _trompo
	_ism.state = _ism.State.HOVER
	
	# We need to simulate _start_interaction.
	# Since OrderManager is likely not present in the test environment, the gate should pass.
	_ism._start_interaction()
	
	assert_eq(_ism.state, _ism.State.MASH, "ISM should be in MASH state")
	assert_eq(_ism.mash_progress, 0.0, "Mash progress should start at 0")
	
	# Simulate mash presses
	# Default MASH_PER_PRESS is 0.2, so 5 presses to reach 1.0
	for i in range(4):
		_ism._on_mash_press()
		assert_almost_eq(_ism.mash_progress, 0.2 * (i + 1), 0.01)
		assert_eq(_ism.state, _ism.State.MASH, "ISM should still be in MASH state")
	
	# Last press should complete it
	watch_signals(EventBus)
	_ism._on_mash_press()
	
	assert_signal_emitted(EventBus, "order_step_completed", "EventBus should emit order_step_completed")
	assert_eq(_ism.state, _ism.State.IDLE, "ISM should return to IDLE after completion")
	assert_eq(_ism.active_station, null, "Active station should be cleared")

func test_ism_blocked_logic():
	# This test is a bit tricky because we'd need to mock OrderManager.
	# If OrderManager is not present, it shouldn't block.
	
	# If we want to test blocking, we'd need to add a mock OrderManager to /root
	var mock_order_mgr = Node.new()
	mock_order_mgr.name = "OrderManager"
	# Add a method to it
	var script = GDScript.new()
	script.source_code = "extends Node\nfunc has_active_taco(): return false"
	script.reload()
	mock_order_mgr.set_script(script)
	
	get_tree().root.add_child(mock_order_mgr)
	
	_ism.active_station = _trompo
	_ism.state = _ism.State.HOVER
	
	watch_signals(_ism)
	_ism._start_interaction()
	
	assert_signal_emitted(_ism, "station_blocked", "ISM should emit station_blocked when no taco")
	assert_eq(_ism.state, _ism.State.HOVER, "ISM should roll back to HOVER")
	
	mock_order_mgr.free()
