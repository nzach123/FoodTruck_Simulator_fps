extends GutTest

func test_interaction_interrupted_called_on_reset():
	var ism_script = load("res://_src/player/InteractionStateMachine.gd")
	var ism = ism_script.new()
	
	# Create a mock station node that extends TruckStation
	var mock_station = Node3D.new() # TruckStation extends Node3D
	
	# Attach a script that implements the interrupted hook and extends TruckStation
	var test_script = GDScript.new()
	test_script.source_code = "extends TruckStation\nvar interrupted_called = false\nfunc on_interaction_interrupted():\n\tinterrupted_called = true\n\tprint('[TEST] Mock interrupted called')"
	test_script.reload()
	mock_station.set_script(test_script)
	
	# Manually set the active station
	ism.active_station = mock_station
	
	# Trigger the reset
	ism._reset_to_hover()
	
	assert_true(mock_station.interrupted_called, "on_interaction_interrupted should have been called on the active station")
	
	# Clean up
	mock_station.free()
	ism.free()
