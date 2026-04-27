# Midnight Munch — Phase 1 & Phase 2 Code and Architecture Review

**Project:** FoodTruck Simulator FPS (Midnight Munch)  
**Reviewer:** Lead Godot Engineer / Software Architect  
**Review Scope:** All custom scripts under `_src/`, Phase 1 (Player Interaction FSM) and Phase 2 (Cooking Stations)  
**Date:** 2026-04-26

---

## Executive Summary

The Phase 1 and Phase 2 implementation demonstrates a **well-reasoned architecture** with clear separation of concerns, a disciplined signal-bus pattern, and strong awareness of the web/WASM target constraints. The design foundations — signal-centric communication, object pooling, data-driven configuration, and a dedicated Interaction State Machine — are all correct and worth preserving.

Two **critical bugs** require fixes before any Phase 3 work begins. Seven **high-priority design gaps** will cause integration pain when OrderManager and BellStation arrive in Phase 3 if not addressed now. The remaining issues are medium or low priority structural inconsistencies that can be addressed incrementally.

---

## Architecture Overview

The project correctly implements the following patterns:

| Pattern | Implementation | Quality |
|---|---|---|
| Signal Bus | `EventBus` autoload — pure signal declarations only | Excellent |
| State Machine | `GameManager` phase FSM, `InteractionStateMachine` state FSM | Excellent |
| Object Pool | `NodePool` with pre-warm and self-healing fallback | Good |
| Resource-Based Config | `EconomyConfig`, `DayConfig`, `RecipeData` | Excellent |
| Template Method | `TruckStation` virtual callbacks, called by ISM only | Excellent |
| Data-Driven Difficulty | `DifficultySchedule.tres` → `DayConfig` per day | Structurally broken (see P1-1) |

The **"Signal Up, Call Down"** rule is enforced consistently. No sibling-to-sibling direct calls exist in the current code. `EventBus` is used correctly as the communication backbone.

---

## Phase 1 & 2 Implementation Status

### Phase 1: Player Interaction FSM

| Deliverable | Status | Notes |
|---|---|---|
| `InteractionStateMachine.gd` | Complete | Web-safe, no await/yield |
| INSTANT, MASH, HOLD, TIMING primitives | Complete | Correct threshold ownership |
| Hover enter/exit via raycast | Complete | |
| Held-item gate (OrderManager forward-compat) | Complete | |
| UI: `HoldGauge`, `ShrinkingCircle` | Complete | Threshold constants duplicated — see P3-3 |
| `NodePool` pooling system | Complete | See P2-2 (visibility contract) |

### Phase 2: Cooking Stations

| Deliverable | Status | Notes |
|---|---|---|
| `TruckStation.gd` (base class) | Complete | See P3-1 (unconditional debug prints) |
| `TortillaStation` (INSTANT) | Complete | **Critical bug** — wrong interact_action (see P1-2) |
| `TrompoStation` (MASH) | Complete | |
| `SauceStation` (HOLD) | Complete | See P2-4 (missing on_interaction_interrupted override) |
| `ToppingStation` (TIMING) | Complete | |
| `TacoBase` food container | Complete | See P4-1 (silent overwrite) |
| `ToppingItem` pooled prop | Complete | |
| Dropped-topping spawn logic | Functional | See P1-3 (printerr misuse), P2-2 (show-before-position) |
| Test suite | Partial | See P3-4 (test coverage gaps) |

### Missing Foundations (Blockers for Phase 3)

| Missing | Needed By |
|---|---|
| `DifficultySchedule.gd` resource class | `GameManager` at every `start_day()` call |
| Populated `DifficultySchedule.tres` | Any day beyond tutorial |
| `BellStation.gd` | Phase 3 order checkout flow |
| `OrderManager` autoload | Phase 3 order lifecycle |

---

## Issue Analysis

Issues are ordered **P1 → P4** (highest to lowest priority). P1 items will cause crashes or broken gameplay. P4 items are structural clean-up.

---

### P1 — CRITICAL: Breaks Core Functionality

#### P1-1 · `DifficultySchedule.tres` has no backing script class

**Location:** `_src/data/difficulty/DifficultySchedule.tres` and `GameManager.gd:159–171`

**Problem:** `GameManager._load_difficulty_schedule()` reads the resource and immediately calls `schedule_resource.get("days")`. The `.tres` file is a bare `Resource` with no attached script, so it has no `days` property. The condition evaluates to null, an error is pushed, and `_difficulty_schedule` stays empty. Any subsequent call to `start_day(1+)` will hit the empty-schedule guard at `get_day_config()`, push another error, and return `null` for `difficulty_config`. Every system that reads `difficulty_config` (ISM's mash-override, QueueManager's patience/spawn) will receive null and either crash or silently use defaults.

There is no `DifficultySchedule.gd` resource class anywhere in the project to define the `days` property. This class needs to be created, the TRES file needs to be re-saved with the script attached, and the `days` Array needs to be populated with `DayConfig` instances for Days 0–4 (at minimum).

**Impact:** `difficulty_config` is always `null`. All difficulty-dependent systems degrade silently.

---

#### P1-2 · `TortillaStation` uses wrong `interact_action`

**Location:** `_src/interactables/TortillaStation.gd:29–32`

**Problem:** `TortillaStation._ready()` sets `interaction_type` and `interaction_prompt_text` but never sets `interact_action`. The base class `TruckStation` defaults `interact_action` to `&"interact"` — COGITO's interaction action — not `&"mm_interact"`, the game's custom action.

`InteractionStateMachine._input()` reads `active_station.interact_action` to determine which input action to listen for:

```
var action: StringName = active_station.interact_action if active_station != null else &""
if event.is_action_pressed(action):
    _start_interaction()
```

Because TortillaStation's `interact_action` is `&"interact"` and not `&"mm_interact"`, the ISM will only respond to the COGITO interact key for tortilla pickup. If the project's input map has separate keybindings for `interact` and `mm_interact`, the tortilla station will behave differently from every other station. Conversely, if they share the same key, this is a silent inconsistency that will break as soon as they diverge.

Every other station (`TrompoStation`, `SauceStation`) explicitly sets `interact_action = &"mm_interact"` in `_ready()`. `TortillaStation` must do the same.

**Impact:** Tortilla pickup responds to the wrong input action, or silently works only because the bindings currently share a key.

---

#### P1-3 · `_spawn_dropped_topping()` uses `printerr()` for debug logging

**Location:** `_src/player/InteractionStateMachine.gd:397, 399, 405, 411, 449`

**Problem:** Five `printerr()` calls are used as debug-level information logs (start, success, failure messages). `printerr()` writes to stderr and is treated as an error by the Godot editor and CI. In a web build, these will appear in the browser console as errors. This violates the CLAUDE.md convention: debug output must be wrapped in `if OS.is_debug_build()` and must use `print()`, not `printerr()`, for non-error states.

The function contains legitimate error paths (null active_station, null checkout, wrong node type) — those could stay as `push_error()`. The success/start messages should be `print()` inside `if OS.is_debug_build()`.

**Impact:** Every timing miss floods the console and browser devtools with fake error entries, masking real errors.

---

### P2 — HIGH: Architecture Violations and Design Gaps

#### P2-1 · `EconomyManager.sloppy_flags` has no writer — design ambiguity

**Location:** `_src/autoloads/EconomyManager.gd:48–50, 100–119`

**Problem:** `sloppy_flags: int` is declared as an instance variable and reset inside `process_payment()` and `reset_day_stats()`. However, no code in the current codebase ever **increments** `sloppy_flags`. Meanwhile, `process_payment(sloppy_count: int)` accepts the sloppy count as a parameter and passes it directly to `_calculate_tip()`.

This creates two parallel and mutually exclusive designs:

- **Pattern A (current parameter):** The caller (BellStation or OrderManager) computes the sloppy count from `TacoBase.get_sloppy_count()` and passes it to `process_payment(sloppy_count)`. `sloppy_flags` is dead state.
- **Pattern B (internal accumulation):** External code calls something like `EconomyManager.increment_sloppy()` per sloppy step, and `process_payment()` reads `self.sloppy_flags` internally. The parameter becomes redundant.

Pattern A is the cleaner design (smaller API surface, no hidden mutation). Pattern B is what `sloppy_flags` implies by its presence. The current code implements Pattern A in practice but declares Pattern B infrastructure that is never used. This ambiguity must be resolved before BellStation is built in Phase 3 — the caller needs a clear contract.

**Impact:** Phase 3 BellStation implementation may be built against the wrong pattern, requiring a refactor.

---

#### P2-2 · `NodePool.checkout()` shows the node before the caller can position it

**Location:** `_src/autoloads/NodePool.gd:92–123` and `_src/player/InteractionStateMachine.gd:396–449`

**Problem:** `NodePool.checkout()` calls `node.show()` before returning the node to the caller. In `_spawn_dropped_topping()`, the caller then reparents the node, sets its global transform, unfreezes physics, and applies an impulse. This sequence means there is a window — one physics frame — where the node is **visible at its old pool location** before it is moved to `spawn_pos`.

For `ToppingItem` (a `RigidBody3D`), showing a physics body before repositioning and unfreezing it also risks a physics engine inconsistency in the current frame. The correct order of operations should be: configure transform while hidden → reparent → show → unfreeze → apply impulse.

The NodePool API contract in the `checkout()` docstring says "the caller is responsible for configuring state before use," which contradicts calling `show()` before returning.

**Impact:** Dropped toppings may flash briefly at the wrong position. Physics bodies may behave unpredictably on the frame they are checked out.

---

#### P2-3 · `_on_timing_miss()` hardcodes penalty amount, bypassing EconomyConfig

**Location:** `_src/player/InteractionStateMachine.gd:380–381`

**Problem:** `EconomyManager.debit(0.05, "timing_miss")` hardcodes the topping-drop penalty at `$0.05`. `EconomyConfig` already defines `penalty_topping_drop: float = 0.05` for exactly this purpose. The ISM should not know the numeric value of the penalty — it should ask EconomyManager to apply the canonical penalty for a topping drop.

Two acceptable resolutions:

- **Option A:** `EconomyManager` exposes a dedicated method: `debit_topping_drop()` that reads from `config.penalty_topping_drop` internally. ISM calls the method name, not a number.
- **Option B:** ISM reads the value from EconomyManager's config reference: `EconomyManager.config.penalty_topping_drop` — preserves the single call but removes the hardcoded literal.

**Impact:** If `EconomyConfig.penalty_topping_drop` is tuned in the TRES file, the running game silently ignores the change and always deducts $0.05.

---

#### P2-4 · `SauceStation` does not override `on_interaction_interrupted()`

**Location:** `_src/interactables/SauceStation.gd`

**Problem:** When a HOLD interaction is interrupted (under-pour, or player walks away mid-pour), `ISM._reset_to_hover()` calls `active_station.on_interaction_interrupted()`. `SauceStation` does not override this callback. The base class `TruckStation.on_interaction_interrupted()` fires instead — which only calls `print()` and does nothing to stop the particle stream.

The particle stream (`GPUParticles3D`) is stopped via `SauceStation.on_hover_exit()`, which is a separate callback called only when the raycast exits the station. `on_hover_exit()` is NOT called during `_reset_to_hover()`. So from the point `on_interaction_interrupted()` is called until the player physically looks away from the station, the sauce particle stream will continue emitting — visible to the player despite the interaction being cancelled.

The sauce stream should be halted immediately on interruption, not one frame later when the raycast exits.

**Impact:** Sauce particles visually persist for a variable amount of time after an under-pour cancellation.

---

#### P2-5 · `_get_mash_per_press()` queries `GameManager` on every keypress

**Location:** `_src/player/InteractionStateMachine.gd:286–298`

**Problem:** Every time the player presses the mash button, `_get_mash_per_press()` is called. This method calls `get_node_or_null("/root/GameManager")` and then dereferences `difficulty_config` via duck-typing to read `mash_presses_required`. For a 5-press interaction, this is 5 node-path lookups and 5 duck-type property reads.

This is unnecessary because the day's difficulty config is static for the entire duration of the interaction. The value should be read **once** at `_start_interaction()` and cached as a local variable for the duration of the MASH interaction.

**Impact:** Minor runtime overhead per mash press. More importantly, if `difficulty_config` changes during a mash interaction (unlikely but undefined), the press-count changes mid-interaction.

---

#### P2-6 · `EconomyConfig.tip_sloppy_plus` is never read in `_calculate_tip()`

**Location:** `_src/autoloads/EconomyManager.gd:192–199`, `_src/data/economy/EconomyConfig.gd:43–44`

**Problem:** `EconomyConfig` exposes `tip_sloppy_plus: float = 0.00` for the 2+ sloppy case, correctly placing it in the designer's control. However, `_calculate_tip()` hardcodes a return of `0.0` for the `_:` match arm without reading `config.tip_sloppy_plus`. If a designer sets `tip_sloppy_plus = 0.25` to implement "no tip is never truly nothing" — or to test balance — the code ignores it.

This is a minor data-driven consistency break. The `_:` arm should return `_get_config_value("tip_sloppy_plus", 0.0)` for full consistency.

**Impact:** `tip_sloppy_plus` in EconomyConfig.tres is silently ignored. Designer changes have no effect.

---

### P3 — MEDIUM: Design Inconsistencies

#### P3-1 · Unconditional `print()` calls throughout station scripts

**Location:** `TruckStation.gd:94, 106, 110`, `TortillaStation.gd:46, 54, 71`, `TrompoStation.gd:69, 78, 88`, `ToppingStation.gd:86, 96, 107`

**Problem:** Every station's `on_interaction_start()`, `on_interaction_complete()`, and `on_interaction_interrupted()` implementations contain unconditional `print()` calls. CLAUDE.md explicitly requires debug output to be wrapped in `if OS.is_debug_build()`. In a released web build, these produce console spam on every player interaction.

The `TruckStation` base class also has unconditional prints in its default virtual implementations — any station that fails to override a callback will also log to the console in production.

**Impact:** Console spam in release/web builds. Masks real errors.

---

#### P3-2 · `ShrinkingCircle._draw()` hardcodes target arc radius

**Location:** `_src/ui/ShrinkingCircle.gd:35`

**Problem:** The target band arc is drawn at `105.0` px radius, which is `(TIMING_TARGET_MIN + TIMING_TARGET_MAX) / 2 = (80 + 130) / 2`. This magic number is not derived from ISM constants and is not documented. If `TIMING_TARGET_MIN` or `TIMING_TARGET_MAX` are tuned for a future balance pass, the visual target band will silently display at the wrong position relative to where PERFECT actually triggers.

This is the same threshold-drift risk as `HoldGauge.GREEN_MIN / GREEN_MAX`, but `HoldGauge` at least documents the relationship with a comment. `ShrinkingCircle` does not.

**Impact:** Silent UI desync when ISM timing constants change.

---

#### P3-3 · `HoldGauge` duplicates ISM threshold constants without a synchronisation mechanism

**Location:** `_src/ui/HoldGauge.gd:22–23`

**Problem:** `HoldGauge` declares `GREEN_MIN = 0.45` and `GREEN_MAX = 0.75` as its own constants, with a comment noting they must match ISM. This is a manual synchronisation requirement between two files — exactly the kind of contract that breaks silently. If ISM thresholds change for a balance pass, HoldGauge must be updated manually or the visual zone drifts from the actual success zone.

The ISM already emits signals to communicate progress state. The threshold values could instead be read from the ISM directly (ISM exposes them as constants, UI accesses `ism.HOLD_GREEN_MIN`), or the ISM could emit an initialisation signal carrying the thresholds when the HOLD state is entered.

**Impact:** Visual success zone drifts from actual success zone if ISM thresholds are tuned without updating HoldGauge.

---

#### P3-4 · Test coverage gaps for key completion paths

**Location:** `tests/unit/`

**Problem:** The existing tests cover: TortillaStation setup, TrompoStation initialization and mash logic, ISM interruption hook, and station scene hierarchy. What is not covered:

- `EconomyManager.process_payment()` — credit and tip logic paths (0, 1, 2+ sloppy)
- `EconomyManager.deduct_food_cost()` — ingredient cost deduction
- `SauceStation` HOLD complete/sloppy/underpour paths through ISM
- `ToppingStation` TIMING hit/miss paths through ISM
- `NodePool.checkout()` and `ret()` happy-path round-trip
- `TacoBase` ingredient addition, `get_sloppy_count()`, `get_ingredient_ids()`
- `GameManager.start_day()` / `end_day()` phase transitions

Phase 3 will introduce `OrderManager` and `BellStation` — without coverage of EconomyManager's core API now, regressions in the payment pipeline will go undetected.

**Impact:** Economic regressions and interaction-path bugs will not be caught by the test suite.

---

### P4 — LOW: Structural Nitpicks

#### P4-1 · `TacoBase.add_ingredient()` silently overwrites duplicate ingredients

**Location:** `_src/entities/food/TacoBase.gd:11–13`

**Problem:** `ingredients[ingredient_id] = quality` overwrites any existing entry for the same key. If `add_ingredient("meat", PERFECT)` is called twice, the first call is silently discarded. While ISM state transitions prevent this in normal gameplay today, OrderManager (Phase 3) will call this method externally and should receive an error or warning if a duplicate is attempted.

---

#### P4-2 · `TacoBase.gd` and `ShrinkingCircle.gd` are missing header documentation

**Location:** Both files

**Problem:** Every other custom script begins with a `##` documentation block stating the class role, responsibilities, path, and architecture notes. These two files are bare. This is a consistency issue, not a functional bug.

---

#### P4-3 · `ShrinkingCircle` connects `station_focus_entered/exited` with empty handlers

**Location:** `_src/ui/ShrinkingCircle.gd:13–14, 25–29`

**Problem:** `_on_station_entered()` and `_on_station_exited()` are connected to ISM signals but contain only `pass`. The connection consumes a slot and emits a signal every time the player looks at any station, for zero effect. Either implement the intended behavior or remove the connections until needed.

---

#### P4-4 · `NodePool.ret()` validates pool membership with an O(n) linear scan

**Location:** `_src/autoloads/NodePool.gd:136–146`

**Problem:** `ret()` iterates through every pool and every node to confirm the returned node is tracked. With 103+ pooled nodes at startup, this is a full array scan on every return event. A `Set` (or a `Dictionary` keyed by node instance ID) for checked-out nodes would reduce this to O(1).

This is currently acceptable at the project's pool sizes but will become visible in profiling if pool counts grow for Phase 3 customers.

---

#### P4-5 · `EconomyManager.get_lifetime_stats()` is a stub alias

**Location:** `_src/autoloads/EconomyManager.gd:169–172`

**Problem:** `get_lifetime_stats()` is documented as returning accumulated cross-day stats but is currently identical to `tally_day()`. The comment acknowledges this as a Phase 3 concern. This is not a bug, but `SaveManager` (Phase 3) will call this expecting lifetime data; if the distinction is not implemented by then, the save will contain only the current day's figures.

---

## Tasks and Refactoring Plan

Tasks are grouped by priority. Complete all P1 tasks before starting Phase 3. P2 tasks should be resolved before BellStation or OrderManager are written.

---

### Priority 1 — Fix Before Any Phase 3 Work

**Task R-1: Create `DifficultySchedule.gd` and populate `DifficultySchedule.tres`**

1. Create `_src/data/difficulty/DifficultySchedule.gd` extending `Resource` with a single export: `@export var days: Array[DayConfig] = []`.
2. In the Godot editor, open `DifficultySchedule.tres`, attach the new `DifficultySchedule.gd` script, and re-save the resource.
3. In the inspector, add `DayConfig` instances for Day 0 through Day 4 minimum. Populate each with values from the GDD difficulty schedule table:
   - Day 0 (tutorial): `patience_seconds=999, spawn_interval=999, max_concurrent=1, allow_optional_ingredients=false`
   - Day 1: `patience_seconds=60, spawn_interval=45, max_concurrent=2, allow_optional_ingredients=false`
   - (Continue per GDD table for Days 2–4.)
4. Verify `GameManager._load_difficulty_schedule()` logs the correct node count and no errors on startup.

---

**Task R-2: Fix `TortillaStation.interact_action`**

1. In `TortillaStation._ready()`, add `interact_action = &"mm_interact"` immediately after `interaction_type = InteractionType.INSTANT`.
2. Add a test assertion in `test_tortilla_station.gd` confirming `interact_action == &"mm_interact"`, consistent with the existing `test_tortilla_station_setup()` test.

---

**Task R-3: Fix `printerr()` misuse in `_spawn_dropped_topping()`**

1. Identify the five `printerr()` calls in `ISM._spawn_dropped_topping()`.
2. For the two legitimate error paths (null `active_station`, null `checkout` return), replace `printerr()` with `push_error()`.
3. For the start and success log messages, replace `printerr()` with `print()` inside an `if OS.is_debug_build()` guard.
4. For the node-type error case, replace `printerr()` with `push_error()`.

---

### Priority 2 — Resolve Before Phase 3 Integration Work

**Task R-4: Resolve `sloppy_flags` API ambiguity in EconomyManager**

1. Decide on Pattern A (caller computes and passes count to `process_payment()`) or Pattern B (EconomyManager accumulates internally). Pattern A is recommended: it gives OrderManager/BellStation full control without requiring EconomyManager mutation from multiple sources.
2. If adopting Pattern A: remove `sloppy_flags` as a publicly writable field. If it needs to survive for internal tracking (e.g., per-session analytics), make it `var _sloppy_count_this_order: int` (private) and document its writer as being the `process_payment()` parameter only.
3. Add a clear comment to `process_payment()` documenting exactly where the caller should obtain `sloppy_count` from (`TacoBase.get_sloppy_count()`).

---

**Task R-5: Fix `NodePool.checkout()` visibility order**

1. Remove the `node.show()` call from `NodePool.checkout()`. The method should return the node **hidden**.
2. Update the `checkout()` docstring to state: "Returns a hidden node. Caller must position and configure it before calling `show()`."
3. In `_spawn_dropped_topping()`, add `body.show()` immediately before `body.freeze = false` and after both `body.reparent(scene_root)` and `body.global_transform = Transform3D(...)` are complete.
4. Confirm no other call site of `checkout()` relied on the node being pre-shown. Audit all callers (currently only `_spawn_dropped_topping`).

---

**Task R-6: Add `EconomyManager.debit_topping_drop()` method**

1. Add a new method to `EconomyManager`: `debit_topping_drop() -> void` that reads `_get_config_value("penalty_topping_drop", 0.05)` and calls `debit(amount, "topping_drop")`.
2. In `ISM._on_timing_miss()`, replace `EconomyManager.debit(0.05, "timing_miss")` with `EconomyManager.debit_topping_drop()`.
3. Similarly, fix `_calculate_tip()` to return `_get_config_value("tip_sloppy_plus", 0.0)` for the `_:` arm instead of hardcoding `0.0`.

---

**Task R-7: Override `on_interaction_interrupted()` in `SauceStation`**

1. Add `func on_interaction_interrupted() -> void:` to `SauceStation.gd`.
2. Inside, call `_stop_stream()`.
3. Add a test case in the appropriate test file: simulate a HOLD underpour, call `_reset_to_hover()`, and assert the stream is no longer emitting.

---

**Task R-8: Cache mash difficulty override in `_start_interaction()`**

1. Add a private variable `_mash_per_press_cache: float = MASH_PER_PRESS` to ISM.
2. At the top of the `TruckStation.InteractionType.MASH` branch in `_start_interaction()`, call `_get_mash_per_press()` once and store the result in `_mash_per_press_cache`.
3. Modify `_on_mash_press()` to use `_mash_per_press_cache` instead of calling `_get_mash_per_press()` each press.
4. Reset `_mash_per_press_cache = MASH_PER_PRESS` in `_reset_to_hover()`.

---

### Priority 3 — Clean Up Before Phase 3 Feature Work

**Task R-9: Wrap all station debug prints in `OS.is_debug_build()` guards**

1. In `TruckStation.gd` base class: wrap all three `print()` calls in virtual method stubs.
2. In `TortillaStation.gd`, `TrompoStation.gd`, `ToppingStation.gd`: wrap all `print()` calls.
3. Note: `SauceStation.gd` already guards its single `print()` with `if OS.is_debug_build()` — no change needed there.
4. Search the full codebase for any additional unguarded `print()` calls in gameplay code.

---

**Task R-10: Remove `ShrinkingCircle` threshold magic number**

1. In `ShrinkingCircle._draw()`, replace the hardcoded `105.0` with a computed value that reads from the ISM reference: `(ism.TIMING_TARGET_MIN + ism.TIMING_TARGET_MAX) / 2.0`. Guard with a null check.
2. Add a short comment explaining the `105.0` is the visual target midpoint.
3. Evaluate whether HoldGauge's `GREEN_MIN / GREEN_MAX` can similarly be derived from `ism.HOLD_GREEN_MIN / HOLD_GREEN_MAX` — if ISM is always wired in the exported field, this is a clean option.

---

**Task R-11: Expand test coverage for EconomyManager and TacoBase**

1. Create `tests/unit/test_economy_manager.gd` with the following test cases:
   - `test_credit_adds_balance()` — verify balance increases
   - `test_debit_floors_at_zero()` — balance cannot go negative
   - `test_process_payment_zero_sloppy()` — base price + $1.00 tip
   - `test_process_payment_one_sloppy()` — base price + $0.50 tip
   - `test_process_payment_two_sloppy()` — base price + $0.00 tip
   - `test_deduct_food_cost()` — deducts correct ingredient costs
   - `test_reset_day_stats_preserves_balance()` — balance survives day reset
2. Create `tests/unit/test_taco_base.gd` with:
   - `test_add_ingredient_stores_quality()`
   - `test_get_quality_returns_missing_for_absent()`
   - `test_get_sloppy_count()`
   - `test_reset_clears_ingredients()`

---

### Priority 4 — Structural Housekeeping

**Task R-12: Add guard to `TacoBase.add_ingredient()` for duplicates**

1. At the start of `add_ingredient()`, check `if ingredients.has(ingredient_id)` and call `push_warning()` with the ingredient name. Do not silently overwrite.
2. Decide whether to return early on duplicate or allow overwrite (return early is recommended — the first addition is the canonical result).

**Task R-13: Remove or implement `ShrinkingCircle` station enter/exit handlers**

1. Either implement `_on_station_entered()` / `_on_station_exited()` (e.g., show/hide a prompt label when the TIMING station is in focus), or disconnect and remove the signal connections and empty methods.

**Task R-14: Add header documentation to `TacoBase.gd` and `ShrinkingCircle.gd`**

1. Follow the established `##` documentation block format used by all other scripts.

**Task R-15: Improve `NodePool.ret()` membership validation**

1. Add a `_active_nodes: Dictionary` (node instance ID → bool) to NodePool.
2. On `checkout()`, add the node to `_active_nodes`.
3. On `ret()`, look up the node in `_active_nodes` instead of doing a linear pool scan.
4. Remove the node from `_active_nodes` after reset.

---

## Clarification Questions

The following design decisions are ambiguous from the code alone. Answers will determine the correct approach for Tasks R-4, R-6, and Phase 3 BellStation design.

---

**Q1 — `EconomyManager.sloppy_flags` ownership**

The field exists but has no writer. Two patterns are possible:

- **A (parameter):** BellStation/OrderManager calls `TacoBase.get_sloppy_count()` and passes the result to `EconomyManager.process_payment(count)`. `sloppy_flags` is dead state and should be removed.
- **B (accumulation):** ISM or a station emits a sloppy event, EconomyManager accumulates internally via a dedicated method, and `process_payment()` reads `self.sloppy_flags`. The parameter becomes redundant.

**Which pattern is the intended design?** Pattern A is recommended for encapsulation, but confirmation is needed before BellStation is built.

---

**Q2 — `TortillaStation.interact_action` intent**

Is the tortilla station intentionally bound to COGITO's `&"interact"` action, or is this an omission? Specifically: should the tortilla pickup coexist with COGITO's built-in interaction system (e.g., to display COGITO's interaction prompt), or should it use only `&"mm_interact"` like the other cooking stations?

---

**Q3 — `NodePool.checkout()` visibility contract**

Should `checkout()` return the node **already visible** (current behavior) or **hidden** (requiring the caller to show it after positioning)? For `ToppingItem`, showing before positioning causes a 1-frame visual glitch. For simpler node types (future customers, UI elements), pre-showing may be convenient.

The recommendation is to **not show** on checkout and let callers show when ready. Confirm this is acceptable before Task R-5 is implemented.

---

**Q4 — `BellStation` order validation and checkout flow**

When BellStation lands in Phase 3, who is responsible for the following decisions?

| Decision | BellStation? | OrderManager? | EconomyManager? |
|---|---|---|---|
| Check `TacoBase` completeness vs recipe | | ? | |
| Show "Incomplete — serve anyway?" prompt | ? | | |
| Call `process_payment(sloppy_count)` | | ? | |
| Call `deduct_food_cost(ingredients)` | | ? | |
| Emit `order_completed` to EventBus | | | ✓ (already emits after `process_payment`) |

Confirming the intended call chain will ensure EventBus signals are connected in the right direction.

---

**Q5 — Day 0 (Tutorial) and `DifficultySchedule.tres`**

Should the tutorial day (Day 0) have a real `DayConfig` entry in `DifficultySchedule.tres`, or is the tutorial's infinite patience by design (not requiring patience/spawn config)? Currently `GameManager.start_day(0)` calls `get_day_config(0)`, which will attempt to return the first entry. If Day 0 is tutorial-only and patience is disabled anyway, a placeholder `DayConfig` at index 0 is still needed to avoid the empty-schedule error.

---

**Q6 — `EconomyManager.get_lifetime_stats()` cross-day accumulation**

Where will lifetime stats be accumulated across days? Is the intended flow:
- `SaveManager.load()` → passes historical stats back into `EconomyManager` at boot?
- Or `EconomyManager` accumulates internally across `reset_day_stats()` calls, and save/load just snapshots the current totals?

The answer determines whether `EconomyManager` needs a `lifetime_earnings: float` field alongside `day_earnings`, or whether `SaveManager` owns the accumulation.

---

## Summary

| Priority | Count | Action Required |
|---|---|---|
| P1 — Critical bugs | 3 | Fix immediately, before any Phase 3 work |
| P2 — High priority design gaps | 6 | Fix before writing BellStation or OrderManager |
| P3 — Medium inconsistencies | 4 | Fix during Phase 3 alongside new systems |
| P4 — Low structural clean-up | 5 | Address incrementally, block no milestones |

The architecture is fundamentally sound. None of the identified issues require a structural rewrite. The project is well-positioned to enter Phase 3 after the P1 fixes are applied and the clarification questions are resolved.
