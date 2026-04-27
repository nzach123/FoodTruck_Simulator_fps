# ISM Refactor Plan
# InteractionStateMachine.gd — Analysis & Refactoring Strategy

**File:** `res://_src/player/InteractionStateMachine.gd`  
**Branch target:** `Phase-2-Issues-Check`  
**Scope:** Refactor only — no new features, no API surface changes.

---

## 1. Analysis

### 1.1 Structural Overview

The ISM is a flat state machine (`enum State`) that lives as a child of the player node.
It owns:
- Raycast hover detection (IDLE ↔ HOVER transitions)
- Input routing for all four interaction primitives (INSTANT / MASH / HOLD / TIMING)
- Per-primitive tick logic (`_tick_hold`, `_tick_timing`)
- Interaction completion and retry reset
- Dropped-topping physics spawn on TIMING miss

The overall design is sound. The signal topology, the "call down / signal up" rule, and the
web-safety constraints (no `await`, fixed-step timing) are all correctly implemented.
The issues below are precision bugs and efficiency gaps rather than architectural flaws.

---

### 1.2 Identified Issues

#### BUG-1 — Wrong input method: `_input` used instead of `_unhandled_input` (HIGH)

**Location:** `_input()` (line 219)

The file's own header comment says:
> "Input events handled in `_unhandled_input` only; never polled in physics."

The implementation uses `_input`, which fires for **all** input events including those already
consumed by UI nodes (Godot's EasyMenus pause panel, any Control with `mouse_filter != IGNORE`).
This means interaction presses can leak through menu layers.

Fix: rename `_input` → `_unhandled_input`.

---

#### BUG-2 — `on_interaction_interrupted` called without a matching `on_interaction_start` (HIGH)

**Location:** `_start_interaction()` → held-item gate (lines 258–266) → `_reset_to_hover()` (line 265)

When `requires_held_item` is true and the gate fails:
1. `on_interaction_start()` has **not** been called (line 269 has not been reached).
2. `_reset_to_hover()` is called, which calls `active_station.on_interaction_interrupted()`.

Stations that do setup work in `on_interaction_start` (e.g. `TrompoStation` resets `_current_spin`)
receive an `interrupted` notification for an interaction that never started. Currently benign,
but this will become a correctness bug when any station uses `on_interaction_interrupted` to
clean up resources allocated in `on_interaction_start`.

Fix: in the held-item gate path, set state directly back to HOVER without calling
`_reset_to_hover`. Only `station_blocked` needs to be emitted; no station callback is warranted.

```gdscript
# BEFORE
station_blocked.emit("no_taco")
_reset_to_hover()

# AFTER
station_blocked.emit("no_taco")
_set_state(State.HOVER)
return
```

---

#### BUG-3 — `_set_state` emits signals on no-op same-state transitions (MEDIUM)

**Location:** `_set_state()` (line 495)

No idempotency guard exists. Calling `_set_state(State.HOVER)` while already in HOVER re-emits
`crosshair_state_changed("hover")` every call. Because `_reset_to_hover` calls `_set_state(State.HOVER)`
and can be called on repeated under-pours, this fires the crosshair signal unnecessarily on
every failed retry.

Fix: add an early return guard.

```gdscript
func _set_state(new_state: State) -> void:
    if new_state == state:
        return
    state = new_state
    ...
```

---

#### BUG-4 — Raycast tree-walk runs on every physics frame during active states (MEDIUM)

**Location:** `_physics_process` → `_update_hover()` (lines 152–153)

`_update_hover()` walks the scene tree every frame (the `while node != null` loop, lines 172–177)
even during MASH / HOLD / TIMING states. The hover enter/exit guards inside `_on_hover_enter`
and `_on_hover_exit` prevent actual state side-effects, but the O(depth) tree traversal is
wasted every fixed-step tick during active play.

Fix: short-circuit `_update_hover` when not in a hover-eligible state.

```gdscript
func _update_hover() -> void:
    if ray_cast == null:
        return
    # No hover change is possible while an active interaction is running.
    if state != State.IDLE and state != State.HOVER:
        return
    ...
```

---

#### BUG-5 — `_complete_interaction` nulls `_last_hovered_station`, causing immediate re-hover (LOW)

**Location:** `_complete_interaction()` (line 474)

After a successful interaction, `_last_hovered_station` is set to `null`. On the very next
physics frame `_update_hover` sees the same station as a "new" hover arrival and calls
`on_hover_enter()` again. This means `on_hover_enter` fires immediately after
`on_interaction_complete` on the same station — in the same tick pipeline.

Currently harmless because all `on_hover_enter` overrides are stubs. Future implementations
(highlight shader, SFX) could double-trigger.

Fix: preserve `_last_hovered_station` across completion so re-hover is suppressed until the
player actually exits and re-enters the raycast hit zone. Set `_last_hovered_station` only to
null in `_on_hover_exit`, not in `_complete_interaction`.

```gdscript
func _complete_interaction(result: int) -> void:
    if active_station == null:
        return
    active_station.on_interaction_complete(result)
    _set_state(State.HOVER)           # stay in HOVER; player is still looking at station
    # active_station stays set; _last_hovered_station is unchanged
    # ISM naturally re-enters idle only when raycast loses the station
```

> **Note:** this changes the post-completion state from IDLE to HOVER. The crosshair signal
> will emit `"hover"` instead of `"idle"` after completion. If the UX requirement is to
> briefly show an "idle" crosshair after completion before re-showing "hover", a one-frame
> intermediary state or a timer flag is needed. The plan below logs this as a design question
> for the author.

---

#### QUALITY-1 — `_get_mash_per_press()` uses unsafe duck-typed property access (LOW)

**Location:** `_get_mash_per_press()` (lines 291–303)

`gm.get("difficulty_config")` is an untyped `Variant` call. If `GameManager`'s property is
renamed, this silently returns `null` and falls back to `MASH_PER_PRESS` with no warning.

Fix: add a `push_warning` on the null path so regressions are visible in debug builds.

```gdscript
if gm == null or not is_instance_valid(gm):
    return MASH_PER_PRESS
var cfg = gm.get("difficulty_config")
if cfg == null:
    if OS.is_debug_build():
        push_warning("[ISM] GameManager.difficulty_config not found; using default mash rate.")
    return MASH_PER_PRESS
```

---

#### QUALITY-2 — `_find_station_from_collider` logic is inline (LOW)

**Location:** `_update_hover()` lines 169–177

The tree-walk to resolve a collider to its TruckStation ancestor is useful logic worth naming.
Extracting it to a helper makes `_update_hover` easier to read and makes the walk testable.

Fix: extract to `_find_station_from_collider(collider: Node) -> TruckStation`.

---

#### QUALITY-3 — No auto-cancel when player looks away during HOLD (DESIGN NOTE)

When a player starts a HOLD interaction and then turns to look at a wall or another station:
- `_update_hover` calls `_on_hover_exit` which returns early (state is HOLD, not HOVER).
- `active_station.on_hover_exit()` is never called on the sauce station.
- The HOLD tick continues indefinitely until the player releases the button.

This is **not a bug** for SauceStation because `on_interaction_complete` / `_evaluate_hold`
always calls `_stop_stream` on release. But it is an edge case the system currently accepts
by design (pressing and holding the sauce dispenser while looking at the ceiling is valid).

**Decision required by author:** Should looking away auto-cancel the HOLD interaction?
If yes, add an auto-cancel call in `_update_hover` when state is HOLD/MASH/TIMING and
`hit_station` no longer matches `active_station`. If no, document this explicitly.

Plan assumes: **no auto-cancel** (current behavior is accepted).

---

## 2. Refactoring Strategy

### Principles

- No new public API surface. All signals, exports, and class names remain identical.
- No behavioral changes beyond the bug fixes above.
- No new abstractions beyond the `_find_station_from_collider` helper (QUALITY-2).
- All changes are surgical: change only what the issue requires.

### Priority Order

| # | Issue | Risk | Effort |
|---|-------|------|--------|
| 1 | BUG-1: `_input` → `_unhandled_input` | Low | Trivial |
| 2 | BUG-2: held-item gate calls interrupted without start | Low | Trivial |
| 3 | BUG-3: idempotency guard on `_set_state` | Low | Trivial |
| 4 | BUG-4: short-circuit `_update_hover` during active states | Low | Small |
| 5 | BUG-5: re-hover after completion | Medium (UX change) | Small + design question |
| 6 | QUALITY-1: mash config warning | None | Trivial |
| 7 | QUALITY-2: extract collider helper | None | Small |
| 8 | QUALITY-3: document look-away design decision | None | Comment only |

---

## 3. Implementation Spec

### Step 1 — Rename `_input` → `_unhandled_input`

```gdscript
# Line 219: change method signature only
func _unhandled_input(event: InputEvent) -> void:
```

No body changes required.

---

### Step 2 — Fix held-item gate path

```gdscript
func _start_interaction() -> void:
    if active_station == null:
        return

    if active_station.requires_held_item:
        var order_mgr: Node = get_node_or_null("/root/OrderManager")
        if is_instance_valid(order_mgr) and order_mgr.has_method("has_active_taco"):
            if not order_mgr.call("has_active_taco"):
                if OS.is_debug_build():
                    print("[ISM] Station '%s' blocked: no active taco." % active_station.name)
                station_blocked.emit("no_taco")
                _set_state(State.HOVER)   # ← was _reset_to_hover()
                return
    ...
```

---

### Step 3 — Idempotency guard in `_set_state`

```gdscript
func _set_state(new_state: State) -> void:
    if new_state == state:   # ← add this guard
        return
    state = new_state
    match new_state:
        State.IDLE:
            crosshair_state_changed.emit("idle")
        State.HOVER:
            crosshair_state_changed.emit("hover")
        State.ACTIVE, State.MASH, State.HOLD, State.TIMING:
            crosshair_state_changed.emit("active")
```

---

### Step 4 — Short-circuit `_update_hover` during active states

```gdscript
func _update_hover() -> void:
    if ray_cast == null:
        return
    if state != State.IDLE and state != State.HOVER:   # ← add this guard
        return
    ...
```

---

### Step 5 — BUG-5 fix (requires author decision first)

**Hold until design question is resolved:** Should `_complete_interaction` leave the ISM in
HOVER (player can immediately re-interact with the same station) or IDLE (player must exit
and re-enter the hit zone)?

- **Option A (current):** → IDLE. `_last_hovered_station = null`. Re-hover fires on next frame.
  - Pro: resets the UX state cleanly.
  - Con: `on_hover_enter` fires on the same station one frame after `on_interaction_complete`.
- **Option B (proposed):** → HOVER. Keep `_last_hovered_station` intact.
  - Pro: no spurious `on_hover_enter` re-fire.
  - Con: UX crosshair stays "hover" immediately after completion with no "idle" flash.
- **Option C:** → IDLE with a one-frame flag `_just_completed = true` that suppresses the next
  hover-enter for the same station.

**Implement Option B** unless author prefers Option C.

```gdscript
func _complete_interaction(result: int) -> void:
    if active_station == null:
        return
    active_station.on_interaction_complete(result)
    _set_state(State.HOVER)
    # active_station and _last_hovered_station remain set.
    # _update_hover will transition to IDLE naturally if player
    # looks away after this frame.
```

---

### Step 6 — `_get_mash_per_press` warning

```gdscript
func _get_mash_per_press() -> float:
    var gm: Node = get_node_or_null("/root/GameManager")
    if not is_instance_valid(gm):
        return MASH_PER_PRESS

    var cfg = gm.get("difficulty_config")
    if cfg == null:
        if OS.is_debug_build():
            push_warning("[ISM] GameManager.difficulty_config not found; using default mash rate.")
        return MASH_PER_PRESS

    var presses_required: int = int(cfg.get("mash_presses_required") if cfg.get("mash_presses_required") != null else 0)
    if presses_required <= 0:
        return MASH_PER_PRESS
    return MASH_THRESHOLD / float(presses_required)
```

---

### Step 7 — Extract `_find_station_from_collider`

Extract the parent-walk loop from `_update_hover` into its own helper.

```gdscript
func _find_station_from_collider(collider: Node) -> TruckStation:
    var node := collider
    while node != null:
        if node is TruckStation:
            return node as TruckStation
        node = node.get_parent()
    return null
```

Then in `_update_hover`:

```gdscript
if ray_cast.is_colliding():
    var collider := ray_cast.get_collider()
    hit_station = _find_station_from_collider(collider)
```

---

### Step 8 — Document look-away design decision

Add a comment to `_on_hover_exit`:

```gdscript
func _on_hover_exit(station: TruckStation) -> void:
    # Do not interrupt an active interaction when the player looks away.
    # Design decision: HOLD/MASH/TIMING interactions persist through look-away;
    # the interaction resolves only via input (release / press / timeout).
    if state != State.HOVER:
        return
    ...
```

---

## 4. Files Changed

| File | Change type |
|------|------------|
| `_src/player/InteractionStateMachine.gd` | Bug fixes + quality improvements (8 edits) |

No other files require changes. The public API (signals, exports, class name, state enum)
is unchanged. All existing station scripts (`TruckStation`, `SauceStation`, `ToppingStation`,
`TrompoStation`, `TortillaStation`) are unaffected.

---

## 5. Testing Checklist

After implementing, verify manually in Godot editor (MCP `run_project`):

- [ ] HOLD interaction: start sauce pour, release at under-pour → retry without crash
- [ ] HOLD interaction: start sauce pour, look away during hold, release → completes cleanly, stream stops
- [ ] TIMING interaction: miss → topping spawns on floor, no crash
- [ ] MASH interaction: spam presses → progress bar fills, meat spins
- [ ] INSTANT interaction: single press → completes immediately
- [ ] Open pause/menu → interact press while menu open → interaction does NOT fire (BUG-1 fix)
- [ ] TrompoStation: attempt interact without tortilla → `station_blocked("no_taco")` emitted, no interrupted callback fires (BUG-2 fix)
- [ ] Rapid re-interaction on same station after completion → only one `on_hover_enter` call per arrival (BUG-5 fix)
- [ ] `crosshair_state_changed` signal: confirm it does not double-fire on retry under-pours

---

## 6. Open Questions for Author

1. **BUG-5 option choice:** After `_complete_interaction`, should the ISM land in HOVER (Option B)
   or stay IDLE with a re-hover on next frame (current behavior / Option A)?  
   Affects crosshair flash UX between interactions on the same station.

2. **QUALITY-3 decision:** Should looking away during an active HOLD auto-cancel the interaction,
   or is the current "keep holding even while looking at ceiling" behavior intentional?
