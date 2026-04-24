## RecipeData.gd
## Resource defining what ingredients make up a valid taco order.
##
## One RecipeData instance is used as a template. At runtime, OrderManager
## reads this and randomly selects a subset of optional_ingredients to
## create per-order variety.
##
## Path: res://_src/data/recipes/RecipeData.gd

class_name RecipeData
extends Resource

## Ingredients that are ALWAYS in every order, regardless of randomisation.
## GDD: tortilla and meat are mandatory for every taco.
@export var always_ingredients: Array[String] = ["tortilla", "meat"]

## Pool of optional ingredients. OrderManager randomly selects 0–N of these.
## GDD allows: red_sauce, white_sauce, cilantro, tomato, onion.
@export var optional_ingredients: Array[String] = [
	"red_sauce", "white_sauce", "cilantro", "tomato", "onion"
]

## Maximum number of optional ingredients to include in a single order.
## Increases over days via DayConfig (or hardcoded progression).
@export var max_optional_count: int = 3
