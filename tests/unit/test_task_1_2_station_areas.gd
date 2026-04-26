extends GutTest
## Task 1.2 — Interactable Area3D Setups
##
## Verifies every station scene has the correct Area3D node structure
## and that TruckInterior.tscn groups them under the Stations hierarchy.
##
## Physics layer bitmasks:
##   Layer 3 (Stations)  = 2^2 = 4
##   Layer 4 (SnapZones) = 2^3 = 8

const BellStationScene = preload("res://_src/interactables/BellStation.tscn")
const SauceStationScene = preload("res://_src/interactables/SauceStation.tscn")
const ToppingStationScene = preload("res://_src/interactables/ToppingStation.tscn")
const TortillaStationScene = preload("res://_src/interactables/TortillaStation.tscn")
const TrompoStationScene = preload("res://_src/interactables/TrompoStation.tscn")


func _verify_station_structure(station: Node3D, label: String) -> void:
	var hitbox: Node = station.get_node_or_null("Hitbox")
	assert_not_null(hitbox, "%s: missing Hitbox child" % label)
	# Hitbox is now a StaticBody3D for ISM raycasting.
	assert_true(hitbox is StaticBody3D or hitbox is Area3D, "%s: Hitbox must be StaticBody3D or Area3D" % label)
	assert_eq(hitbox.collision_layer, 4, "%s: Hitbox must be on layer 3 (bitmask 4)" % label)
	assert_eq(hitbox.collision_mask, 0, "%s: Hitbox collision_mask must be 0" % label)
	assert_not_null(hitbox.get_node_or_null("CollisionShape3D"),
			"%s: Hitbox must have a CollisionShape3D child" % label)

	var snap_zone: Node = station.get_node_or_null("SnapZone")
	assert_not_null(snap_zone, "%s: missing SnapZone child" % label)
	assert_is(snap_zone, Area3D, "%s: SnapZone must be Area3D" % label)
	assert_eq(snap_zone.collision_layer, 8, "%s: SnapZone must be on layer 4 (bitmask 8)" % label)
	assert_eq(snap_zone.collision_mask, 0, "%s: SnapZone collision_mask must be 0" % label)
	assert_not_null(snap_zone.get_node_or_null("CollisionShape3D"),
			"%s: SnapZone must have a CollisionShape3D child" % label)

	var prompt: Node = station.get_node_or_null("InteractionPrompt")
	assert_not_null(prompt, "%s: missing InteractionPrompt child" % label)
	assert_is(prompt, Node3D, "%s: InteractionPrompt must be Node3D" % label)


# =============================================================================
# Station structure tests
# =============================================================================

func test_bell_station_area3d_structure() -> void:
	var station: Node3D = BellStationScene.instantiate()
	add_child_autofree(station)
	_verify_station_structure(station, "BellStation")


func test_sauce_station_area3d_structure() -> void:
	var station: Node3D = SauceStationScene.instantiate()
	add_child_autofree(station)
	_verify_station_structure(station, "SauceStation")


func test_topping_station_area3d_structure() -> void:
	var station: Node3D = ToppingStationScene.instantiate()
	add_child_autofree(station)
	_verify_station_structure(station, "ToppingStation")


func test_tortilla_station_area3d_structure() -> void:
	var station: Node3D = TortillaStationScene.instantiate()
	add_child_autofree(station)
	_verify_station_structure(station, "TortillaStation")


func test_trompo_station_area3d_structure() -> void:
	var station: Node3D = TrompoStationScene.instantiate()
	add_child_autofree(station)
	_verify_station_structure(station, "TrompoStation")


# =============================================================================
# TruckInterior hierarchy tests
# =============================================================================

func test_truck_interior_has_stations_node() -> void:
	var scene: PackedScene = load("res://_src/levels/TruckInterior.tscn")
	assert_not_null(scene, "TruckInterior.tscn must load successfully")
	var truck: Node3D = scene.instantiate()
	add_child_autofree(truck)
	assert_not_null(truck.get_node_or_null("Stations"), "TruckInterior must have a Stations node")


func test_truck_interior_front_stations_has_six_children() -> void:
	var truck: Node3D = load("res://_src/levels/TruckInterior.tscn").instantiate()
	add_child_autofree(truck)
	var front: Node = truck.get_node_or_null("Stations/FrontStations")
	assert_not_null(front, "TruckInterior must have Stations/FrontStations")
	assert_eq(front.get_child_count(), 6,
			"FrontStations must have 6 children: Bell, 2×Sauce, 3×Topping")


func test_truck_interior_back_stations_has_two_children() -> void:
	var truck: Node3D = load("res://_src/levels/TruckInterior.tscn").instantiate()
	add_child_autofree(truck)
	var back: Node = truck.get_node_or_null("Stations/BackStations")
	assert_not_null(back, "TruckInterior must have Stations/BackStations")
	assert_eq(back.get_child_count(), 2,
			"BackStations must have 2 children: Tortilla + Trompo")


func test_all_front_station_hitboxes_on_layer_3() -> void:
	var truck: Node3D = load("res://_src/levels/TruckInterior.tscn").instantiate()
	add_child_autofree(truck)
	var front: Node = truck.get_node_or_null("Stations/FrontStations")
	assert_not_null(front)
	for child in front.get_children():
		var hitbox: Node = child.get_node_or_null("Hitbox")
		assert_not_null(hitbox, "%s: missing Hitbox" % child.name)
		assert_eq((hitbox as CollisionObject3D).collision_layer, 4,
				"%s/Hitbox must be on layer 3 (bitmask 4)" % child.name)


func test_all_back_station_hitboxes_on_layer_3() -> void:
	var truck: Node3D = load("res://_src/levels/TruckInterior.tscn").instantiate()
	add_child_autofree(truck)
	var back: Node = truck.get_node_or_null("Stations/BackStations")
	assert_not_null(back)
	for child in back.get_children():
		var hitbox: Node = child.get_node_or_null("Hitbox")
		assert_not_null(hitbox, "%s: missing Hitbox" % child.name)
		assert_eq((hitbox as CollisionObject3D).collision_layer, 4,
				"%s/Hitbox must be on layer 3 (bitmask 4)" % child.name)
