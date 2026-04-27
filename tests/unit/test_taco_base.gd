extends "res://addons/gut/test.gd"
## test_taco_base.gd
## Unit tests for TacoBase — the in-memory food container node.
##
## TacoBase is not a scene; it is instantiated directly from its script.
## Each test creates a fresh instance via add_child_autofree().
##
## GDD References:
##   Section 4 — Order Pipeline: ingredient quality states PERFECT=2, SLOPPY=3, MISSING=4

var TacoBaseScript = load("res://_src/entities/food/TacoBase.gd")

func _make_taco() -> TacoBase:
	var taco: TacoBase = TacoBaseScript.new()
	add_child_autofree(taco)
	return taco


# ─────────────────────────────────────────────────────────────────────────────
# ADDING INGREDIENTS
# ─────────────────────────────────────────────────────────────────────────────

func test_add_ingredient_stores_quality() -> void:
	var taco: TacoBase = _make_taco()
	taco.add_ingredient("tortilla", IngredientState.State.PERFECT)
	assert_eq(taco.get_quality("tortilla"), IngredientState.State.PERFECT,
		"add_ingredient should store quality and retrieve it via get_quality")


func test_add_ingredient_emits_signal() -> void:
	var taco: TacoBase = _make_taco()
	watch_signals(taco)
	taco.add_ingredient("meat", IngredientState.State.SLOPPY)
	assert_signal_emitted(taco, "ingredient_added",
		"add_ingredient should emit ingredient_added signal")


func test_add_ingredient_duplicate_is_ignored() -> void:
	# R-12 guard: second add for the same ingredient_id should be a no-op.
	var taco: TacoBase = _make_taco()
	taco.add_ingredient("tortilla", IngredientState.State.PERFECT)
	taco.add_ingredient("tortilla", IngredientState.State.SLOPPY)
	assert_eq(taco.get_quality("tortilla"), IngredientState.State.PERFECT,
		"duplicate add should not overwrite the first quality value")


# ─────────────────────────────────────────────────────────────────────────────
# QUERYING INGREDIENTS
# ─────────────────────────────────────────────────────────────────────────────

func test_get_quality_returns_missing_for_absent() -> void:
	var taco: TacoBase = _make_taco()
	assert_eq(taco.get_quality("cilantro"), IngredientState.State.MISSING,
		"get_quality for a missing ingredient should return MISSING")


func test_has_ingredient_returns_false_before_add() -> void:
	var taco: TacoBase = _make_taco()
	assert_false(taco.has_ingredient("onion"),
		"has_ingredient should return false before any add")


func test_has_ingredient_returns_true_after_add() -> void:
	var taco: TacoBase = _make_taco()
	taco.add_ingredient("onion", IngredientState.State.PERFECT)
	assert_true(taco.has_ingredient("onion"),
		"has_ingredient should return true after add_ingredient")


# ─────────────────────────────────────────────────────────────────────────────
# SLOPPY COUNT
# ─────────────────────────────────────────────────────────────────────────────

func test_get_sloppy_count_zero_when_all_perfect() -> void:
	var taco: TacoBase = _make_taco()
	taco.add_ingredient("tortilla", IngredientState.State.PERFECT)
	taco.add_ingredient("meat", IngredientState.State.PERFECT)
	assert_eq(taco.get_sloppy_count(), 0,
		"get_sloppy_count should be 0 when all ingredients are PERFECT")


func test_get_sloppy_count() -> void:
	var taco: TacoBase = _make_taco()
	taco.add_ingredient("tortilla", IngredientState.State.PERFECT)
	taco.add_ingredient("meat", IngredientState.State.SLOPPY)
	taco.add_ingredient("red_sauce", IngredientState.State.SLOPPY)
	assert_eq(taco.get_sloppy_count(), 2,
		"get_sloppy_count should count only SLOPPY-quality ingredients")


# ─────────────────────────────────────────────────────────────────────────────
# RESET
# ─────────────────────────────────────────────────────────────────────────────

func test_reset_clears_ingredients() -> void:
	var taco: TacoBase = _make_taco()
	taco.add_ingredient("tortilla", IngredientState.State.PERFECT)
	taco.add_ingredient("meat", IngredientState.State.SLOPPY)
	taco.reset()
	assert_false(taco.has_ingredient("tortilla"),
		"reset() should clear all stored ingredients")
	assert_eq(taco.get_sloppy_count(), 0,
		"sloppy count should be 0 after reset")


func test_get_ingredient_ids_reflects_adds() -> void:
	var taco: TacoBase = _make_taco()
	taco.add_ingredient("tortilla", IngredientState.State.PERFECT)
	taco.add_ingredient("meat", IngredientState.State.PERFECT)
	var ids: Array[String] = taco.get_ingredient_ids()
	assert_eq(ids.size(), 2, "get_ingredient_ids should return one entry per unique ingredient")
	assert_true(ids.has("tortilla"), "ids should include 'tortilla'")
	assert_true(ids.has("meat"), "ids should include 'meat'")
