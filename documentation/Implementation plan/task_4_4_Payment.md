# Task 4.4 — Payment & Tip Pipeline

**Engine:** Godot 4.6 | **Phase:** 4 — Game Loop & Economy | **Predecessors:** Tasks 4.1 (OrderManager), 4.2 (BellStation), 4.3 (Validator); EconomyManager + EconomyConfig already in place from prior phases | **Successor handoff:** Task 4.5 SaveManager reads `EconomyManager.balance` and `tally_day()`; Phase 5 OrderHUD listens to `EventBus.order_completed` for the count-up animation; Phase 3 QueueManager already listens for `order_completed` to release the served customer.

## Objective

Verify and tighten the existing payment pipeline (already partially implemented in `EconomyManager`) so that ringing the bell on a complete order:
1. Adds `taco_base_price` to the balance.
2. Calculates tip from `sloppy_count` per the GDD tier table.
3. Adds tip (if > 0) to the balance.
4. Updates day stats.
5. Emits `EventBus.order_completed(payment, tip)` exactly once per order.
6. Triggers customer departure via the existing `QueueManager._on_order_completed` listener.
7. Triggers `OrderManager.clear_active_order()` via the existing `_on_order_completed` listener (no change needed — already wired in Task 4.1).

The work in this task is mostly **integration verification** plus a small additional connection: ensuring the per-day `orders_completed` and `day_earnings` accumulators do not double-count when force-serve runs.

## Boundary

This task does NOT:
- Add new EventBus signals (none needed).
- Change the tip tier numbers (live in `EconomyConfig.tres`).
- Drive the customer leave animation (Phase 6).

It owns: integration test, a minor `EconomyManager.deduct_food_cost` audit (verify it does NOT call `process_payment`), and a regression test for the tip tiers.

---

## System Architecture

The payment pipeline is fully signal-driven. BellStation calls `EconomyManager.process_payment(sloppy)` synchronously. EconomyManager:
1. Increments `orders_attempted`, `orders_completed`.
2. Computes `base_price` and `tip` from `EconomyConfig`.
3. Calls `credit()` for both — each `credit()` emits `balance_changed`.
4. Emits `order_completed(base, tip)` on EventBus.
5. Resets `sloppy_flags` (legacy field; current implementation uses caller-provided sloppy_count, but this is reset for safety).

EventBus.order_completed has three listeners:
- **OrderManager._on_order_completed** → `clear_active_order()` returns TacoBase to pool, emits `taco_returned`.
- **QueueManager._on_order_completed** → releases the accepted customer, shuffles queue forward, returns customer to pool.
- **OrderHUD._on_order_completed** (Phase 5) → clears pills.

## File Roster

| Action | Path |
|---|---|
| `[MODIFY]` | `res://_src/autoloads/EconomyManager.gd` — verify `process_payment` ordering; ensure `deduct_food_cost` does NOT call `process_payment` (audit) |
| `[CREATE]` | `res://tests/integration/test_payment_pipeline.gd` |
| `[NO CHANGE]` | `EconomyConfig.tres`, `EventBus.gd`, `BellStation.gd`, `OrderManager.gd` — already correct |

---

## Node Architecture

No scene changes. EconomyManager is a non-visual autoload.

## Signal Contract

| Emitter | Signal | Receiver |
|---|---|---|
| `BellStation` | direct call `EconomyManager.process_payment(sloppy)` | EconomyManager |
| `EconomyManager` | `EventBus.balance_changed(new, delta)` ×2 (base + tip) | HUDHeader (Phase 5.2) |
| `EconomyManager` | `EventBus.order_completed(base, tip)` | OrderManager (clears taco), QueueManager (releases customer), OrderHUD (clears pills) |
| `BellStation` (force-serve path) | direct call `EconomyManager.deduct_food_cost(ids)` | EconomyManager |
| `EconomyManager` | `EventBus.balance_changed(new, -cost)` | HUDHeader |
| `EconomyManager` | `EventBus.order_rejected(food_cost)` | OrderManager (clears taco), QueueManager (releases rejected customer) |

## API Interface

The public surface is unchanged from the existing implementation:

```gdscript
# EconomyManager — already public, no changes.
func process_payment(sloppy_count: int) -> void
func deduct_food_cost(ingredients: Array) -> void
func tally_day() -> Dictionary
func reset_day_stats() -> void
```

---

## Section A — Audit Existing `process_payment`

**File:** `res://_src/autoloads/EconomyManager.gd`

The current implementation (verified, lines 100–119) already:
1. Increments stats.
2. Reads base price + tip via `_get_config_value`.
3. Calls `credit(base)` then `credit(tip)`.
4. Resets `sloppy_flags`.
5. Emits `order_completed(base, tip)`.

**Required confirmations** (no code change unless test fails):

- Order of operations is `credit(base) → credit(tip) → order_completed.emit(...)`. Verify `order_completed` fires AFTER both credits so listeners see the final balance. ✅ (current source order is correct).
- `tip == 0.0` does not call `credit(0.0)` (the `credit()` guard would reject with a warning). ✅ (current source has the `if tip > 0.0:` guard).
- `deduct_food_cost()` does NOT call `process_payment` (we never want to pay for a rejected order). ✅ (verified — emits `order_rejected` only).

If any of those drift in a refactor, the integration test below will catch it.

## Section B — Tip-Tier Regression Test

**File:** `res://tests/integration/test_payment_pipeline.gd`

```gdscript
## test_payment_pipeline.gd
## Locks the tip-tier behaviour and order_completed signal payload.
##
## Run via GUT panel → Run All.
## Path: res://tests/integration/test_payment_pipeline.gd

extends GutTest

# Snapshot of EconomyConfig defaults (mirrors EconomyConfig.gd).
const BASE_PRICE: float = 3.50
const TIP_PERFECT: float = 1.00
const TIP_ONE_SLOPPY: float = 0.50

var _last_payment: float = 0.0
var _last_tip: float = 0.0
var _order_completed_count: int = 0


func before_each() -> void:
    _last_payment = 0.0
    _last_tip = 0.0
    _order_completed_count = 0
    EconomyManager.balance = 0.0
    EconomyManager.reset_day_stats()
    EventBus.order_completed.connect(_on_order_completed)


func after_each() -> void:
    if EventBus.order_completed.is_connected(_on_order_completed):
        EventBus.order_completed.disconnect(_on_order_completed)


func _on_order_completed(payment: float, tip: float) -> void:
    _last_payment = payment
    _last_tip = tip
    _order_completed_count += 1


# ─────────────────────────────────────────────────────────────────────────────
# TIP TIERS
# ─────────────────────────────────────────────────────────────────────────────

func test_zero_sloppy_full_tip() -> void:
    EconomyManager.process_payment(0)
    assert_almost_eq(EconomyManager.balance, BASE_PRICE + TIP_PERFECT, 0.001)
    assert_almost_eq(_last_payment, BASE_PRICE, 0.001)
    assert_almost_eq(_last_tip, TIP_PERFECT, 0.001)


func test_one_sloppy_half_tip() -> void:
    EconomyManager.process_payment(1)
    assert_almost_eq(EconomyManager.balance, BASE_PRICE + TIP_ONE_SLOPPY, 0.001)
    assert_almost_eq(_last_tip, TIP_ONE_SLOPPY, 0.001)


func test_two_sloppy_no_tip() -> void:
    EconomyManager.process_payment(2)
    assert_almost_eq(EconomyManager.balance, BASE_PRICE, 0.001)
    assert_almost_eq(_last_tip, 0.0, 0.001)


func test_three_sloppy_no_tip() -> void:
    EconomyManager.process_payment(3)
    assert_almost_eq(EconomyManager.balance, BASE_PRICE, 0.001)
    assert_almost_eq(_last_tip, 0.0, 0.001)


# ─────────────────────────────────────────────────────────────────────────────
# SIGNAL ORDERING
# ─────────────────────────────────────────────────────────────────────────────

func test_order_completed_fires_exactly_once() -> void:
    EconomyManager.process_payment(0)
    assert_eq(_order_completed_count, 1, "order_completed must fire exactly once")


func test_balance_at_signal_time_is_final() -> void:
    var captured_balance: float = -1.0
    var capture_cb: Callable = func(_p: float, _t: float) -> void:
        captured_balance = EconomyManager.balance
    EventBus.order_completed.connect(capture_cb)
    EconomyManager.process_payment(0)
    EventBus.order_completed.disconnect(capture_cb)
    # By the time the signal fires both credits have been applied.
    assert_almost_eq(captured_balance, BASE_PRICE + TIP_PERFECT, 0.001,
        "balance at signal-time should already include base + tip")


# ─────────────────────────────────────────────────────────────────────────────
# REJECT PATH (no double counting)
# ─────────────────────────────────────────────────────────────────────────────

func test_deduct_food_cost_does_not_emit_order_completed() -> void:
    EconomyManager.balance = 5.00
    EconomyManager.deduct_food_cost(["tortilla", "meat"])
    assert_eq(_order_completed_count, 0,
        "rejected orders must not emit order_completed")
    # 0.25 + 0.75 = 1.00 deducted.
    assert_almost_eq(EconomyManager.balance, 4.00, 0.001)
```

---

## Section C — Implementation Stub Excerpt

```gdscript
# EconomyManager.process_payment (verified current implementation)
func process_payment(sloppy_count: int) -> void:
    orders_attempted += 1
    orders_completed += 1

    var base_price: float = _get_config_value("taco_base_price", 3.50)
    var tip: float = _calculate_tip(sloppy_count)

    credit(base_price, "taco_base_price")
    day_earnings += base_price

    if tip > 0.0:
        credit(tip, "tip_sloppy_%d" % sloppy_count)
        day_tips += tip

    sloppy_flags = 0
    EventBus.order_completed.emit(base_price, tip)
```

---

## Section D — Smoke Test Checklist

- [ ] GUT panel: all seven tests in `test_payment_pipeline.gd` pass.
- [ ] Live play: full perfect order → balance jumps by 4.50 in two flashes (base then tip). HUD shows green flash twice.
- [ ] One sloppy: balance jumps by 4.00.
- [ ] Two sloppy: balance jumps by 3.50, no tip flash.
- [ ] Force-serve incomplete: balance drops by sum of `ingredient_costs` for the partial taco; `order_completed` does not fire; `order_rejected` does.
- [ ] After three completed orders, `EconomyManager.tally_day()` reports `orders_completed = 3` and the correct earnings sum.

## Edge Cases

| Case | Behaviour |
|---|---|
| `process_payment(-1)` (defensive) | Treated as 2+ sloppy by `_calculate_tip` (default branch returns 0.0). Tip is 0; no negative tip ever applied. |
| `EconomyConfig.tres` missing entirely | `_get_config_value` returns hardcoded GDD defaults; payment still works. |
| Balance overflow (multi-day session, no upgrades) | Float64 is fine for any human-realistic balance; not a concern within scope. |
| `order_completed` emitted but no listener connected | Harmless; signal emit is a no-op when listener list is empty. |
| QueueManager not yet ready (race at boot) | Cannot happen: autoloads boot in fixed order; QueueManager precedes BellStation interactions. |
