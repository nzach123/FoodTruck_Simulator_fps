class_name TacoBase
extends Node3D

signal ingredient_added(ingredient_id: String, quality: int)

var ingredients: Dictionary = {}

func reset() -> void:
	ingredients.clear()

func add_ingredient(ingredient_id: String, quality: int) -> void:
	ingredients[ingredient_id] = quality
	ingredient_added.emit(ingredient_id, quality)

func has_ingredient(ingredient_id: String) -> bool:
	return ingredients.has(ingredient_id)

func get_quality(ingredient_id: String) -> int:
	return ingredients.get(ingredient_id, IngredientState.State.MISSING)

func get_sloppy_count() -> int:
	var count: int = 0
	for quality: int in ingredients.values():
		if quality == IngredientState.State.SLOPPY:
			count += 1
	return count

func get_ingredient_ids() -> Array[String]:
	var ids: Array[String] = []
	for key: String in ingredients.keys():
		ids.append(key)
	return ids
