# Task 3.1 — TacoTicket Resource

**Engine:** Godot 4.6 | **Phase:** 3 — Customer AI & Queue Logic | **Predecessors:** Phase 2 stations complete; `RecipeData`, `DayConfig` resources exist | **Successor handoff:** Task 3.2 `CustomerNPC.assign_ticket()` consumes a `TacoTicket`

## Objective

Create a per-customer order data carrier as a `Resource` subclass. Each `TacoTicket` is generated at customer-spawn time by combining a `RecipeData` template with a `DayConfig` to produce:
- A concrete `required_ingredients` list (always_ + a randomised subset of optional_)
- A copy of the day's `patience_seconds` (so live customers are immune to mid-day balance changes)
- An archetype label and a "weird order" flag for Day 3+ variety

Tickets are pure data — no signals, no `_process`. They are passed by reference into `CustomerNPC.assign_ticket()`.

## Boundary With Other Tasks

This task does NOT:
- Spawn or pool customers (Task 3.2/3.3)
- Render the ticket bubble UI (Phase 5)
- Award payment (Phase 4 `OrderManager` reads `ticket.required_ingredients` to validate served tacos)

---

## System Architecture

`TacoTicket` extends `Resource` so it can be (a) saved/restored later by `SaveManager`, (b) serialised cheaply between spawn and acceptance, and (c) inspected in the editor for debugging. It exposes a single `static func generate()` factory that pulls randomness through `randi_range()` against `recipe.optional_ingredients`, capped by `recipe.max_optional_count` and gated by `day_config.allow_optional_ingredients`. The `customer_archetype` field is a forward-compatibility hook for Phase 6 personality variants — Phase 3 only ever sets it to `"standard"` or `"weird"`.

## File Roster

| Action | Path |
|---|---|
| `CREATE` | `res://_src/data/recipes/TacoTicket.gd` |
| `NO CHANGE` | `res://_src/data/recipes/RecipeData.gd` |
| `NO CHANGE` | `res://_src/data/difficulty/DayConfig.gd` |

## Signal Contract

`TacoTicket` is a passive Resource. It emits **no signals**.

---

## Section A — Create `TacoTicket.gd`

**File:** `res://_src/data/recipes/TacoTicket.gd`

### A.1 — Full script

Create the file with exactly this content:

```gdscript
## TacoTicket.gd
## Per-customer order payload. Generated at customer spawn from a RecipeData
## template and a DayConfig, then handed to CustomerNPC.assign_ticket().
##
## Architecture rules:
##   - Resource (not Node) — cheap to create, easy to save/restore.
##   - Pure data; no _process, no signals.
##   - Generation is deterministic given the same RNG state, so save/load
##     can replay seeds if needed.
##
## Path: res://_src/data/recipes/TacoTicket.gd

class_name TacoTicket
extends Resource

# ─────────────────────────────────────────────────────────────────────────────
# CONSTANTS
# ─────────────────────────────────────────────────────────────────────────────

## Archetype label used by Phase 6 customer personality system.
## Phase 3 uses only STANDARD and WEIRD.
const ARCHETYPE_STANDARD: String = "standard"
const ARCHETYPE_WEIRD: String = "weird"

## Floor on patience copied from DayConfig (defensive default).
const MIN_PATIENCE_SECONDS: float = 5.0

# ─────────────────────────────────────────────────────────────────────────────
# EXPORTS — written once by generate(), read by CustomerNPC + OrderManager
# ─────────────────────────────────────────────────────────────────────────────

## Final ingredient list this customer expects on the served taco.
## Order: always_ingredients first, then any selected optional_ingredients.
@export var required_ingredients: Array[String] = []

## Day 3+ flag for unusual orders (reserved for Phase 6 personality variants).
## Phase 3 only flips this to true via DayConfig opt-in; Phase 4 OrderManager
## may use it later for tip multipliers.
@export var is_weird: bool = false

## Patience window in seconds. Snapshotted from DayConfig at spawn so live
## customers are immune to mid-day config changes.
@export var patience_seconds: float = 60.0

## Customer archetype label (forward-compat, Phase 6 personalities).
@export var customer_archetype: String = ARCHETYPE_STANDARD

# ─────────────────────────────────────────────────────────────────────────────
# STATIC FACTORY
# ─────────────────────────────────────────────────────────────────────────────

## Build a TacoTicket from a RecipeData template and the active DayConfig.
##
## recipe       : the master RecipeData resource (always + optional pools).
## day_config   : the active DayConfig (patience, optional gating).
## allow_weird  : when true AND day_config.allow_optional_ingredients is true,
##                there's a small chance the ticket is flagged as weird.
##
## Returns a fully populated TacoTicket. Never returns null — falls back to
## a tortilla+meat order with default patience if inputs are bad.
static func generate(
	recipe: RecipeData,
	day_config: DayConfig,
	allow_weird: bool
) -> TacoTicket:
	var ticket: TacoTicket = TacoTicket.new()

	# ── Defensive null handling — never return null. ───────────────────────
	if not is_instance_valid(recipe):
		push_error("[TacoTicket] generate() called with null RecipeData. Falling back to tortilla+meat.")
		ticket.required_ingredients = ["tortilla", "meat"]
		ticket.patience_seconds = MIN_PATIENCE_SECONDS
		ticket.customer_archetype = ARCHETYPE_STANDARD
		return ticket

	# ── Always-required ingredients (tortilla + meat) ──────────────────────
	var ingredients: Array[String] = []
	for ing: String in recipe.always_ingredients:
		ingredients.append(ing)

	# ── Optional ingredients (gated by DayConfig) ──────────────────────────
	var optional_pool: Array[String] = recipe.optional_ingredients.duplicate()
	var allow_optional: bool = is_instance_valid(day_config) and day_config.allow_optional_ingredients

	if allow_optional and optional_pool.size() > 0:
		var max_count: int = min(recipe.max_optional_count, optional_pool.size())
		var pick_count: int = randi_range(0, max_count)

		for i: int in range(pick_count):
			if optional_pool.is_empty():
				break
			var idx: int = randi_range(0, optional_pool.size() - 1)
			ingredients.append(optional_pool[idx])
			optional_pool.remove_at(idx)

	ticket.required_ingredients = ingredients

	# ── Patience snapshot from DayConfig (with floor) ──────────────────────
	if is_instance_valid(day_config):
		ticket.patience_seconds = max(MIN_PATIENCE_SECONDS, day_config.patience_seconds)
	else:
		ticket.patience_seconds = MIN_PATIENCE_SECONDS

	# ── Archetype + weird flag ─────────────────────────────────────────────
	# Weirdness only possible when optional ingredients are unlocked.
	# 15% chance, gated by allow_weird argument.
	if allow_weird and allow_optional and randf() < 0.15:
		ticket.is_weird = true
		ticket.customer_archetype = ARCHETYPE_WEIRD
	else:
		ticket.is_weird = false
		ticket.customer_archetype = ARCHETYPE_STANDARD

	if OS.is_debug_build():
		print("[TacoTicket] Generated: %s (patience=%.1fs, weird=%s)" \
			% [str(ticket.required_ingredients), ticket.patience_seconds, ticket.is_weird])

	return ticket
```

### A.2 — Verify

1. Save the file.
2. The Godot editor must report **zero** parse errors.
3. Open the FileSystem dock and confirm `TacoTicket.gd` shows the `Resource` icon.
4. In the editor: right-click `_src/data/recipes/` → New Resource → search "TacoTicket" — the class should appear in the picker.

---

## Section B — Smoke Test (manual, optional)

In a temporary script or the Remote Inspector:

```gdscript
var recipe: RecipeData = load("res://_src/data/recipes/RecipeData.tres") if ResourceLoader.exists("res://_src/data/recipes/RecipeData.tres") else RecipeData.new()
var day: DayConfig = DayConfig.new()
day.patience_seconds = 45.0
day.allow_optional_ingredients = true
var ticket: TacoTicket = TacoTicket.generate(recipe, day, true)
assert(ticket.required_ingredients.has("tortilla"))
assert(ticket.required_ingredients.has("meat"))
assert(ticket.patience_seconds == 45.0)
```

Expected console output: `[TacoTicket] Generated: ["tortilla", "meat", ...] (patience=45.0s, weird=false)` (or `weird=true` ~15% of runs).

---

## Edge Cases Covered

| Case | Behaviour |
|---|---|
| `recipe` is null | Returns ticket with `["tortilla", "meat"]` and `MIN_PATIENCE_SECONDS`; logs error. |
| `day_config` is null | Returns ticket with `MIN_PATIENCE_SECONDS`; no optional ingredients added. |
| `recipe.optional_ingredients` is empty | No optional picks; ticket has only always_ingredients. |
| `recipe.max_optional_count` exceeds pool size | Clamped to `optional_pool.size()`. |
| `allow_optional_ingredients` is false | `pick_count` is never evaluated; weird flag is forced to false. |
| `day_config.patience_seconds` < `MIN_PATIENCE_SECONDS` | Patience clamped to floor. |
