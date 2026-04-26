# Task 4.3 — Order Validator (inline on OrderManager)

**Engine:** Godot 4.6 | **Phase:** 4 — Game Loop & Economy | **Predecessors:** Task 4.1 OrderManager skeleton (with stub `validate_against_ticket()`); Task 4.2 BellStation calling into the validator | **Successor handoff:** Task 4.4 reads `validation.sloppy_count` to derive the tip tier.

## Objective

Finalise the body of `OrderManager.validate_against_ticket()` so it deterministically reports:
1. **Completeness** — every `required_ingredient` present in the active TacoBase.
2. **Quality** — count of `IngredientState.SLOPPY` entries (used for tip calculation).
3. **Missing list** — exact `ingredient_id` strings absent from the taco, in the original ticket order so the popup renders them predictably.

Add unit-test coverage so subsequent tip-tier changes cannot silently regress validation.

## Boundary

This task does NOT:
- Calculate price or tip (Task 4.4).
- Decide the popup wording (Phase 5.5).
- Reject orders with *extra* ingredients (player paid the COGS already; extras are not penalized — by GDD).

It owns: the validation function body, the canonical Dictionary shape, and the GUT test file.

---

## System Architecture

`validate_against_ticket()` is a pure function over two pieces of state already owned by OrderManager: `current_taco` and `current_ticket`. No external lookups, no signal emissions, no side effects. Returning the same Dictionary shape on every code path keeps the BellStation caller branch-free aside from `validation.complete`. Tests live under `res://tests/unit/test_order_validator.gd` and use GUT's `assert_eq` to lock the contract.

## File Roster

| Action | Path |
|---|---|
| `[MODIFY]` | `res://_src/autoloads/OrderManager.gd` — replace stub body of `validate_against_ticket()` |
| `[CREATE]` | `res://tests/unit/test_order_validator.gd` |

---

## Node Architecture

No scene tree changes. OrderManager remains a non-visual autoload. Tests run via GUT panel against the autoload-singleton instance.

## Signal Contract

No new signals. The validator is a synchronous return-value API.

## API Interface

```gdscript
## Public — already declared in Task 4.1, body finalised here.
func validate_against_ticket() -> Dictionary

# Returned Dictionary shape (canonical):
# {
#     "complete": bool,           # all required_ingredients present
#     "missing": Array[String],   # absent ingredient_ids in ticket order
#     "sloppy_count": int,        # count of IngredientState.SLOPPY entries
# }
```

---

## Section A — Replace Function Body

**File:** `res://_src/autoloads/OrderManager.gd`

### A.1 — Full final implementation

Replace the stub body added in Task 4.1 with:

```gdscript
## Compares the active taco against the active ticket.
## Returns a Dictionary — see file header for shape contract.
##
## Notes:
##   - "Complete" means presence-only. A SLOPPY ingredient still counts as present.
##   - sloppy_count is summed across ALL ingredients on the taco (not just
##     required ones). Today the player cannot add extras; this is futureproofing.
##   - missing[] preserves the ticket's required_ingredients order so the popup
##     reads naturally ("Missing: meat, red sauce" instead of dictionary-hash order).
func validate_against_ticket() -> Dictionary:
    # Defensive default — keeps BellStation callsite branch-light.
    var result: Dictionary = {
        "complete": false,
        "missing": [] as Array[String],
        "sloppy_count": 0,
    }

    if not is_instance_valid(current_taco):
        return result
    if current_ticket == null:
        return result

    var missing: Array[String] = []
    for ingredient_id: String in current_ticket.required_ingredients:
        if not current_taco.has_ingredient(ingredient_id):
            missing.append(ingredient_id)

    result.missing = missing
    result.complete = missing.is_empty()
    result.sloppy_count = current_taco.get_sloppy_count()
    return result
```

### A.2 — Guarantees

1. The function never raises. Null-state inputs return the default Dictionary.
2. `missing` is always typed `Array[String]` so consumers can iterate without `str()` coercion.
3. `sloppy_count` reads from `TacoBase.get_sloppy_count()` (already implemented in Phase 2.1) so this validator never needs to know what `IngredientState.State.SLOPPY` evaluates to numerically.

---

## Section B — Unit Tests

**File:** `res://tests/unit/test_order_validator.gd`

```gdscript
## test_order_validator.gd
## Locks the contract shape and edge cases of OrderManager.validate_against_ticket().
##
## Run via GUT panel → Run All in res://tests/.gutconfig.json scope.
## Path: res://tests/unit/test_order_validator.gd

extends GutTest

const TACO_SCENE: PackedScene = preload("res://_src/entities/food/TacoBase.tscn")


func before_each() -> void:
    # Reset state directly on the autoload singleton.
    OrderManager.current_taco = null
    OrderManager.current_ticket = null


func _make_taco() -> TacoBase:
    var taco: TacoBase = TACO_SCENE.instantiate() as TacoBase
    add_child_autofree(taco)
    return taco


func _make_ticket(required: Array[String]) -> TacoTicket:
    var t: TacoTicket = TacoTicket.new()
    t.required_ingredients = required.duplicate()
    return t


# ─────────────────────────────────────────────────────────────────────────────
# CONTRACT — return shape
# ─────────────────────────────────────────────────────────────────────────────

func test_returns_default_when_no_state() -> void:
    var r: Dictionary = OrderManager.validate_against_ticket()
    assert_eq(r.complete, false, "complete should be false on null state")
    assert_eq(r.missing.size(), 0, "missing should be empty on null state")
    assert_eq(r.sloppy_count, 0, "sloppy_count should be 0 on null state")


func test_returns_default_when_taco_only() -> void:
    OrderManager.current_taco = _make_taco()
    OrderManager.current_taco.add_ingredient("tortilla", IngredientState.State.PERFECT)
    var r: Dictionary = OrderManager.validate_against_ticket()
    assert_eq(r.complete, false, "no ticket → complete is false")


# ─────────────────────────────────────────────────────────────────────────────
# COMPLETENESS
# ─────────────────────────────────────────────────────────────────────────────

func test_complete_when_all_present_perfect() -> void:
    OrderManager.current_taco = _make_taco()
    OrderManager.current_taco.add_ingredient("tortilla", IngredientState.State.PERFECT)
    OrderManager.current_taco.add_ingredient("meat",     IngredientState.State.PERFECT)
    OrderManager.current_ticket = _make_ticket(["tortilla", "meat"])

    var r: Dictionary = OrderManager.validate_against_ticket()
    assert_eq(r.complete, true)
    assert_eq(r.missing.size(), 0)
    assert_eq(r.sloppy_count, 0)


func test_missing_one_ingredient() -> void:
    OrderManager.current_taco = _make_taco()
    OrderManager.current_taco.add_ingredient("tortilla", IngredientState.State.PERFECT)
    OrderManager.current_ticket = _make_ticket(["tortilla", "meat"])

    var r: Dictionary = OrderManager.validate_against_ticket()
    assert_eq(r.complete, false)
    assert_eq(r.missing, ["meat"])
    assert_eq(r.sloppy_count, 0)


func test_missing_preserves_ticket_order() -> void:
    OrderManager.current_taco = _make_taco()
    OrderManager.current_taco.add_ingredient("tortilla", IngredientState.State.PERFECT)
    OrderManager.current_ticket = _make_ticket(["tortilla", "meat", "red_sauce", "cilantro"])

    var r: Dictionary = OrderManager.validate_against_ticket()
    assert_eq(r.missing, ["meat", "red_sauce", "cilantro"],
        "missing array preserves ticket ordering")


# ─────────────────────────────────────────────────────────────────────────────
# QUALITY
# ─────────────────────────────────────────────────────────────────────────────

func test_one_sloppy_ingredient() -> void:
    OrderManager.current_taco = _make_taco()
    OrderManager.current_taco.add_ingredient("tortilla", IngredientState.State.PERFECT)
    OrderManager.current_taco.add_ingredient("meat",     IngredientState.State.SLOPPY)
    OrderManager.current_ticket = _make_ticket(["tortilla", "meat"])

    var r: Dictionary = OrderManager.validate_against_ticket()
    assert_eq(r.complete, true, "sloppy still counts as present")
    assert_eq(r.sloppy_count, 1)


func test_fully_sloppy() -> void:
    OrderManager.current_taco = _make_taco()
    OrderManager.current_taco.add_ingredient("tortilla", IngredientState.State.SLOPPY)
    OrderManager.current_taco.add_ingredient("meat",     IngredientState.State.SLOPPY)
    OrderManager.current_taco.add_ingredient("red_sauce",IngredientState.State.SLOPPY)
    OrderManager.current_ticket = _make_ticket(["tortilla", "meat", "red_sauce"])

    var r: Dictionary = OrderManager.validate_against_ticket()
    assert_eq(r.complete, true)
    assert_eq(r.sloppy_count, 3)
```

---

## Section C — Implementation Stub Excerpt

```gdscript
func validate_against_ticket() -> Dictionary:
    var result := {"complete": false, "missing": [] as Array[String], "sloppy_count": 0}
    if not is_instance_valid(current_taco) or current_ticket == null:
        return result
    var missing: Array[String] = []
    for id: String in current_ticket.required_ingredients:
        if not current_taco.has_ingredient(id):
            missing.append(id)
    result.missing = missing
    result.complete = missing.is_empty()
    result.sloppy_count = current_taco.get_sloppy_count()
    return result
```

---

## Section D — Smoke Test Checklist

- [ ] GUT panel → Run All. All seven tests in `test_order_validator.gd` pass green.
- [ ] In live play: take tortilla, ring bell with no other ingredients. Popup shows `Missing: meat`. Console matches.
- [ ] Sloppy a sauce, ring bell. Validation reports `complete: true, sloppy_count: 1` — Task 4.4 pipes that into `EconomyManager.process_payment(1)` → tip $0.50.
- [ ] Two sloppy + one perfect on a four-ingredient ticket → tip $0.00 (verifies sloppy_count summation).

## Edge Cases

| Case | Behaviour |
|---|---|
| TacoBase has an extra ingredient not on the ticket | Not penalised; `missing` only inspects ticket-required keys. `sloppy_count` includes the extra (tip still drops if extra was sloppy). |
| `current_ticket.required_ingredients` is empty (degenerate ticket) | `missing` is empty → `complete: true`. Defensive but correct. |
| Player adds the same ingredient twice (re-pour) | `TacoBase.add_ingredient` overwrites the dictionary entry; latest quality wins. Validator reflects the final value only. |
| Quality value outside the IngredientState enum | `get_sloppy_count` only counts equality-to-`SLOPPY`. Out-of-range values are silently ignored. |
