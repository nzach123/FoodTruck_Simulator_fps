## TacoBase.gd
## In-memory food container tracking the ingredients assembled for a single order.
##
## RESPONSIBILITIES:
##   - Store ingredient_id → quality (IngredientState.State) mappings
##   - Expose has_ingredient(), get_quality(), get_sloppy_count() for OrderManager
##   - Emit ingredient_added signal on each successful add
##   - Guard against duplicate adds (silent overwrite would corrupt the order record)
##
## DOES NOT:
##   - Own 3D visuals (visual nodes are children set up by the scene)
##   - Drive payment calculation (→ EconomyManager.process_payment)
##   - Track recipe completeness (→ OrderManager, Phase 4)
##
## Lifecycle: NodePool.checkout() → add ingredients → NodePool.ret() → reset()
## Path: res://_src/entities/food/TacoBase.gd

class_name TacoBase
extends Node3D

signal ingredient_added(ingredient_id: String, quality: int)

var ingredients: Dictionary = {}

func reset() -> void:
	ingredients.clear()

func add_ingredient(ingredient_id: String, quality: int) -> void:
	if ingredients.has(ingredient_id):
		push_warning("[TacoBase] Duplicate ingredient: %s — ignoring" % ingredient_id)
		return
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
