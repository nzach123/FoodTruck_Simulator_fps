## EconomyConfig.gd
## Resource containing all price, tip, and penalty values for the economy.
##
## ONE global instance stored at res://_src/data/economy/EconomyConfig.tres.
## EconomyManager loads this at boot and uses it for all calculations.
## Zero hardcoded values should exist in EconomyManager.gd itself.
##
## All values sourced from GDD Section 3 — Economy.
## Path: res://_src/data/economy/EconomyConfig.gd

class_name EconomyConfig
extends Resource

# ─────────────────────────────────────────────────────────────────────────────
# PRICING
# ─────────────────────────────────────────────────────────────────────────────

## Base payment received for every completed order, regardless of quality.
@export var taco_base_price: float = 3.50

# ─────────────────────────────────────────────────────────────────────────────
# TIPS (added on top of base price)
# ─────────────────────────────────────────────────────────────────────────────

## Tip for a perfect order (0 sloppy steps).
@export var tip_perfect: float = 1.00

## Tip for an order with exactly 1 sloppy step.
@export var tip_one_sloppy: float = 0.50

## Tip for orders with 2+ sloppy steps — always $0.00 per GDD.
## Kept as a variable for potential future balance tweaks.
@export var tip_sloppy_plus: float = 0.00

# ─────────────────────────────────────────────────────────────────────────────
# PENALTIES
# ─────────────────────────────────────────────────────────────────────────────

## Penalty deducted when a customer's patience expires and they leave.
@export var penalty_patience: float = 1.50

## Penalty deducted each time a topping is dropped on the floor.
@export var penalty_topping_drop: float = 0.05

# ─────────────────────────────────────────────────────────────────────────────
# STARTING STATE
# ─────────────────────────────────────────────────────────────────────────────

## Player's starting balance at the beginning of a new game (Day 0 tutorial).
@export var starting_balance: float = 5.00

## Emergency cash injection on Day 1 if the player ended the previous day at $0.
## A "regular customer" cutscene hands this to the player before the clock starts.
@export var bailout_amount: float = 2.00

# ─────────────────────────────────────────────────────────────────────────────
# INGREDIENT COSTS (deducted when a rejected order is force-served)
# ─────────────────────────────────────────────────────────────────────────────

## Per-ingredient cost of goods sold. Deducted when an incomplete order is confirmed.
## Keys must match the ingredient_id strings used in RecipeData.
@export var ingredient_costs: Dictionary = {
	"tortilla":    0.25,
	"meat":        0.75,
	"red_sauce":   0.15,
	"white_sauce": 0.15,
	"cilantro":    0.10,
	"tomato":      0.10,
	"onion":       0.10,
}
