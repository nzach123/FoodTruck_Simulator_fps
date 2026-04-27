extends "res://addons/gut/test.gd"
## test_economy_manager.gd
## Unit tests for EconomyManager autoload.
##
## EconomyManager is registered as a project autoload, so it is available
## directly by name in every test. Each test that mutates state must restore
## balance and stats via reset_day_stats() + a manual balance assignment.
##
## GDD References:
##   Section 3 — Economy: base $3.50, tip $1.00/$0.50/$0.00, floor $0.00

func before_each() -> void:
	# Reset EconomyManager to a known baseline before every test.
	EconomyManager.balance = 0.0
	EconomyManager.reset_day_stats()


func after_each() -> void:
	# Leave EconomyManager clean for the next test suite.
	EconomyManager.balance = 0.0
	EconomyManager.reset_day_stats()


# ─────────────────────────────────────────────────────────────────────────────
# CREDIT / DEBIT PRIMITIVES
# ─────────────────────────────────────────────────────────────────────────────

func test_credit_adds_balance() -> void:
	EconomyManager.balance = 5.00
	EconomyManager.credit(2.50, "test")
	assert_almost_eq(EconomyManager.balance, 7.50, 0.001,
		"credit() should add to balance")


func test_debit_floors_at_zero() -> void:
	EconomyManager.balance = 1.00
	# Debit more than the available balance.
	EconomyManager.debit(5.00, "test_floor")
	assert_almost_eq(EconomyManager.balance, 0.0, 0.001,
		"balance cannot go below $0.00")


func test_credit_non_positive_does_nothing() -> void:
	EconomyManager.balance = 3.00
	EconomyManager.credit(0.0, "zero_credit")
	assert_almost_eq(EconomyManager.balance, 3.00, 0.001,
		"credit(0) should not change balance")


# ─────────────────────────────────────────────────────────────────────────────
# PROCESS PAYMENT
# ─────────────────────────────────────────────────────────────────────────────

func test_process_payment_zero_sloppy() -> void:
	# 0 sloppy → base price ($3.50) + perfect tip ($1.00) = $4.50 earned
	EconomyManager.balance = 0.0
	EconomyManager.process_payment(0)
	# EconomyConfig may not be loaded in test env; use fallback values from EconomyManager
	var expected: float = 3.50 + 1.00
	assert_almost_eq(EconomyManager.balance, expected, 0.01,
		"0 sloppy: balance should be base_price + tip_perfect")
	assert_eq(EconomyManager.orders_completed, 1,
		"orders_completed should increment")


func test_process_payment_one_sloppy() -> void:
	# 1 sloppy → base price ($3.50) + half tip ($0.50) = $4.00 earned
	EconomyManager.balance = 0.0
	EconomyManager.process_payment(1)
	var expected: float = 3.50 + 0.50
	assert_almost_eq(EconomyManager.balance, expected, 0.01,
		"1 sloppy: balance should be base_price + tip_one_sloppy")


func test_process_payment_two_sloppy() -> void:
	# 2+ sloppy → base price ($3.50) + tip_sloppy_plus ($0.00 per GDD) = $3.50
	EconomyManager.balance = 0.0
	EconomyManager.process_payment(2)
	var expected: float = 3.50 + 0.00
	assert_almost_eq(EconomyManager.balance, expected, 0.01,
		"2+ sloppy: balance should be base_price only (tip_sloppy_plus = $0.00)")


func test_process_payment_increments_both_counters() -> void:
	EconomyManager.process_payment(0)
	assert_eq(EconomyManager.orders_attempted, 1, "orders_attempted should increment")
	assert_eq(EconomyManager.orders_completed, 1, "orders_completed should increment")


# ─────────────────────────────────────────────────────────────────────────────
# DEDUCT FOOD COST (rejected / incomplete order)
# ─────────────────────────────────────────────────────────────────────────────

func test_deduct_food_cost() -> void:
	EconomyManager.balance = 10.00
	# tortilla=0.25, meat=0.75 → total cost $1.00
	EconomyManager.deduct_food_cost(["tortilla", "meat"])
	assert_almost_eq(EconomyManager.balance, 9.00, 0.01,
		"deduct_food_cost should debit ingredient costs from balance")


func test_deduct_food_cost_increments_attempted_not_completed() -> void:
	EconomyManager.balance = 5.00
	EconomyManager.deduct_food_cost(["tortilla"])
	assert_eq(EconomyManager.orders_attempted, 1, "orders_attempted should increment")
	assert_eq(EconomyManager.orders_completed, 0,
		"orders_completed should NOT increment for a rejected order")


# ─────────────────────────────────────────────────────────────────────────────
# RESET DAY STATS
# ─────────────────────────────────────────────────────────────────────────────

func test_reset_day_stats_preserves_balance() -> void:
	EconomyManager.balance = 12.50
	EconomyManager.orders_completed = 5
	EconomyManager.day_earnings = 17.50
	EconomyManager.reset_day_stats()
	assert_almost_eq(EconomyManager.balance, 12.50, 0.001,
		"reset_day_stats() must NOT reset the balance")
	assert_eq(EconomyManager.orders_completed, 0,
		"reset_day_stats() should reset orders_completed to 0")
	assert_almost_eq(EconomyManager.day_earnings, 0.0, 0.001,
		"reset_day_stats() should reset day_earnings to 0.0")
