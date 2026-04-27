## EconomyManager.gd
## Tracks all money, tips, penalties, and ingredient costs for Midnight Munch.
##
## RESPONSIBILITIES:
##   - Maintain the player's live bank balance (never below $0.00)
##   - Credit payments and tips after each completed order
##   - Debit penalties (patience expiry, topping drops) and ingredient costs
##   - Track per-day stats (earnings, tips, orders, sloppy count)
##   - Emit EventBus.balance_changed on every change for HUD reactivity
##
## DOES NOT:
##   - Decide when to pay (→ BellStation / OrderManager)
##   - Track upgrade inventory (→ UpgradeManager, planned Phase 3)
##   - Trigger UI animations directly (→ BankBalanceLabel listens to signals)
##
## Registered in: Project Settings > Autoloads > EconomyManager
## Path: res://_src/autoloads/EconomyManager.gd

extends Node

# ─────────────────────────────────────────────────────────────────────────────
# CONSTANTS
# ─────────────────────────────────────────────────────────────────────────────

## Path to the EconomyConfig resource with all prices/tips/penalties.
const ECONOMY_CONFIG_PATH: String = "res://_src/data/economy/EconomyConfig.tres"

# ─────────────────────────────────────────────────────────────────────────────
# STATE VARIABLES
# ─────────────────────────────────────────────────────────────────────────────

## Live bank balance. Read by EndOfDayScreen, UpgradeShop, SaveManager.
## Never mutate directly from outside — use credit() / debit().
var balance: float = 0.0

## Total money earned this day (base price only, tips counted separately).
var day_earnings: float = 0.0

## Total tip money earned this day.
var day_tips: float = 0.0

## Number of orders fully served (bell rung with all ingredients).
var orders_completed: int = 0

## Number of orders attempted (bell rung, complete or incomplete).
var orders_attempted: int = 0

## Internal sloppy count for the current order. Not incremented by EconomyManager —
## the caller computes sloppy_count via TacoBase.get_sloppy_count() and passes it
## directly to process_payment(). This field is kept only to satisfy reset_day_stats().
var _sloppy_count_this_order: int = 0

## Loaded EconomyConfig resource. Null until _ready() completes.
var config: Resource = null  # EconomyConfig — typed once resource script exists

# ─────────────────────────────────────────────────────────────────────────────
# LIFECYCLE
# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_load_config()
	# Apply starting balance from config; fallback to hardcoded GDD value.
	balance = config.starting_balance if config else 5.00


# ─────────────────────────────────────────────────────────────────────────────
# PUBLIC API — TRANSACTIONS
# ─────────────────────────────────────────────────────────────────────────────

## Add money to the player's balance.
## reason: human-readable log string (e.g. "taco_base_price", "tip_perfect")
func credit(amount: float, reason: String = "") -> void:
	if amount <= 0.0:
		push_warning("[EconomyManager] credit() called with non-positive amount: %.2f (%s)" % [amount, reason])
		return

	var previous: float = balance
	balance += amount
	EventBus.balance_changed.emit(balance, amount)
	_log_transaction("CREDIT", amount, reason, previous)


## Subtract money from the player's balance. Balance is floored at $0.00.
## reason: human-readable log string (e.g. "patience_expired", "topping_drop")
func debit(amount: float, reason: String = "") -> void:
	if amount <= 0.0:
		push_warning("[EconomyManager] debit() called with non-positive amount: %.2f (%s)" % [amount, reason])
		return

	var previous: float = balance
	# $0 floor — design constraint: player can never go negative.
	balance = max(0.0, balance - amount)
	var actual_debit: float = previous - balance
	EventBus.balance_changed.emit(balance, -actual_debit)
	_log_transaction("DEBIT", actual_debit, reason, previous)


## Called by BellStation / OrderManager after a valid order submission.
## Calculates base price + tip based on sloppy_count, then credits both.
## sloppy_count should be obtained by the caller via TacoBase.get_sloppy_count().
func process_payment(sloppy_count: int) -> void:
	orders_attempted += 1
	orders_completed += 1

	var base_price: float = _get_config_value("taco_base_price", 3.50)
	var tip: float = _calculate_tip(sloppy_count)

	# Credit base price and tip as separate transactions for clear logging.
	credit(base_price, "taco_base_price")
	day_earnings += base_price

	if tip > 0.0:
		credit(tip, "tip_sloppy_%d" % sloppy_count)
		day_tips += tip

	# Reset internal sloppy counter for the next order.
	_sloppy_count_this_order = 0

	# Order completed signal carries final payment data for HUD/log.
	EventBus.order_completed.emit(base_price, tip)


## Called when the player force-serves with missing ingredients (bell confirm YES).
## Deducts the cost of each ingredient in the provided list from the balance.
## ingredients: Array[String] of ingredient IDs (e.g. ["tortilla", "meat"])
func deduct_food_cost(ingredients: Array) -> void:
	orders_attempted += 1

	var total_cost: float = 0.0
	var ingredient_costs: Dictionary = _get_config_value(
		"ingredient_costs",
		{"tortilla": 0.25, "meat": 0.75, "red_sauce": 0.15,
		 "white_sauce": 0.15, "cilantro": 0.10, "tomato": 0.10, "onion": 0.10}
	)

	for ingredient_id: String in ingredients:
		var cost: float = ingredient_costs.get(ingredient_id, 0.0)
		total_cost += cost

	if total_cost > 0.0:
		debit(total_cost, "food_cost_rejected_order")

	EventBus.order_rejected.emit(total_cost)


## Deducts the topping-drop penalty as configured in EconomyConfig.penalty_topping_drop.
## Called by ISM._on_timing_miss() so the penalty value is never hardcoded in the caller.
func debit_topping_drop() -> void:
	debit(_get_config_value("penalty_topping_drop", 0.05), "topping_drop")


## Resets all per-day stat trackers. Called by GameManager at start_day().
## Does NOT reset the balance — balance persists across days.
func reset_day_stats() -> void:
	day_earnings = 0.0
	day_tips = 0.0
	orders_completed = 0
	orders_attempted = 0
	_sloppy_count_this_order = 0


## Returns a summary Dictionary for the EndOfDayScreen and SaveManager.
func tally_day() -> Dictionary:
	return {
		"balance": balance,
		"day_earnings": day_earnings,
		"day_tips": day_tips,
		"orders_completed": orders_completed,
		"orders_attempted": orders_attempted,
	}


## Returns lifetime stats merged from save data + current session.
## Exposed to SaveManager via build_save_dict().
func get_lifetime_stats() -> Dictionary:
	# In Phase 3, this will accumulate across days from save data.
	# For now, returns current session data.
	return tally_day()

# ─────────────────────────────────────────────────────────────────────────────
# PRIVATE HELPERS
# ─────────────────────────────────────────────────────────────────────────────

## Load the EconomyConfig resource. Falls back to GDD hardcoded defaults on failure.
func _load_config() -> void:
	if not ResourceLoader.exists(ECONOMY_CONFIG_PATH):
		push_warning("[EconomyManager] EconomyConfig.tres not found at '%s'. Using hardcoded GDD defaults." % ECONOMY_CONFIG_PATH)
		return

	config = ResourceLoader.load(ECONOMY_CONFIG_PATH)
	if not config:
		push_error("[EconomyManager] Failed to load EconomyConfig.tres.")


## Calculate tip amount based on GDD rules:
##   0 sloppy → tip_perfect ($1.00)
##   1 sloppy → tip_one_sloppy ($0.50)
##   2+ sloppy → tip_sloppy_plus ($0.00, per GDD; configurable for future balance)
func _calculate_tip(sloppy_count: int) -> float:
	match sloppy_count:
		0:
			return _get_config_value("tip_perfect", 1.00)
		1:
			return _get_config_value("tip_one_sloppy", 0.50)
		_:
			return _get_config_value("tip_sloppy_plus", 0.0)


## Safe accessor for config values with GDD-specified fallbacks.
## Falls back to default_value if config is null or property is missing.
func _get_config_value(property: String, default_value: Variant) -> Variant:
	if config and config.get(property) != null:
		return config.get(property)
	return default_value


## Prints a consistent transaction log line in debug builds.
func _log_transaction(type: String, amount: float, reason: String, previous: float) -> void:
	if OS.is_debug_build():
		print("[EconomyManager] %s $%.2f (%s) | $%.2f → $%.2f" \
			% [type, amount, reason, previous, balance])
