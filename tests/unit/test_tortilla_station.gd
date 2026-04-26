extends "res://addons/gut/test.gd"

var TortillaStationScene = load("res://_src/interactables/TortillaStation.tscn")

func test_tortilla_station_setup():
	var station = TortillaStationScene.instantiate()
	add_child(station)
	
	assert_eq(station.interaction_type, 0, "Interaction type should be INSTANT (0)")
	assert_eq(station.interact_action, &"mm_interact", "Interact action should be mm_interact")
	assert_eq(station.display_name, "Tortilla Station", "Display name should be set")
	
	station.free()

func test_tortilla_station_interaction():
	var station = TortillaStationScene.instantiate()
	add_child(station)
	
	watch_signals(EventBus)
	watch_signals(station)
	
	# Simulate completion
	station.on_interaction_complete(2) # PERFECT
	
	assert_signal_emitted(EventBus, "tortilla_taken")
	assert_signal_emitted(EventBus, "order_step_completed")
	assert_signal_emitted(station, "interaction_completed")
	
	station.free()

func test_hitbox_setup():
	var station = TortillaStationScene.instantiate()
	var hitbox = station.get_node("Hitbox")
	
	assert_not_null(hitbox, "Hitbox should exist")
	assert_eq(hitbox.collision_layer, 4, "Collision layer should be 4 (Stations)")
	assert_null(hitbox.get_script(), "Hitbox should have no script (Cogito removed)")
	assert_false(hitbox.has_node("BasicInteraction"), "BasicInteraction should be removed")
	
	station.free()
