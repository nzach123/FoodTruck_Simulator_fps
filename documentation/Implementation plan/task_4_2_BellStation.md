# Task 4.2 — BellStation Validation Trigger

**Engine:** Godot 4.6 | **Phase:** 4 — Game Loop & Economy | **Predecessors:** Task 4.1 OrderManager autoload registered; `BellStation.tscn` exists at `res://_src/interactables/BellStation.tscn` with `TruckStation` script attached | **Successor handoff:** Task 4.3 finalises `OrderManager.validate_against_ticket()` body; Task 4.4 lands `EconomyManager.process_payment` integration; Phase 5.5 adds the ConfirmServePopup that closes the force-serve loop.

## Objective

Replace BellStation's behavior so that ringing the bell synchronously calls `OrderManager.validate_against_ticket()` and routes to one of three outcomes:

1. **Complete order** → `EconomyManager.process_payment(sloppy_count)` → `OrderManager.clear_active_order()`.
2. **Incomplete order** → `EventBus.bell_missing_ingredients.emit(missing)`. The ConfirmServePopup (Phase 5.5) listens; if the player confirms, it emits `EventBus.bell_force_serve_confirmed`. BellStation listens for that and runs the rejected-order path.
3. **No active order** (no taco or no ticket) → ISM `station_blocked.emit("no_taco")` would have already gated this; as a safety net, log a debug warning and short-circuit.

The bell is an INSTANT-type station; the ISM completes its interaction in a single physics frame.

## Boundary

This task does NOT:
- Render the confirm popup (Phase 5.5).
- Calculate tips or modify the balance (Task 4.4).
- Validate ingredient *quality* — only presence (Task 4.3 owns the body of `validate_against_ticket`).
- Drive customer departure animation (Phase 6).

It owns: the `BellStation.gd` script, EventBus signal additions for the force-serve flow, and the connection from `bell_force_serve_confirmed` back into the rejected-order code path.

---

## System Architecture

`BellStation` extends `TruckStation` with `interaction_type = INSTANT`. The ISM completes the interaction in a single frame and calls `on_interaction_complete(IngredientState.State.PERFECT)`. The override calls into the OrderManager (downward call within the same logical layer is fine — both are autoloads / scene-graph singletons; the rule "no sibling-to-sibling calls" applies to gameplay nodes communicating across systems, not to a station calling an autoload). On an incomplete result, BellStation emits `EventBus.bell_missing_ingredients` and connects (one-shot) to `EventBus.bell_force_serve_confirmed` so the popup's YES button can land back in this script. NO never reaches BellStation — the popup just closes itself.

## File Roster

| Action | Path |
|---|---|
| `[CREATE]` | `res://_src/interactables/BellStation.gd` |
| `[MODIFY]` | `res://_src/interactables/BellStation.tscn` — assign new script to root, remove the `BasicInteraction` child (we use ISM exclusively, not COGITO interactions) `[EDITOR]` |
| `[MODIFY]` | `res://_src/autoloads/EventBus.gd` — add `bell_missing_ingredients(missing: Array)` and `bell_force_serve_confirmed()` |

---

## Node Architecture

```
BellStation (Node3D)              ← TruckStation root; new script BellStation.gd
├── Hitbox (StaticBody3D)         ← collision_layer 4 (legacy COGITO); keep as-is
│   └── CollisionShape3D          ← group "interactable"
├── InteractionPrompt (Node3D)
├── SnapZone (Area3D)             ← legacy; kept for COGITO carry compatibility
│   └── CollisionShape3D
└── Bell (CSGCylinder3D)          ← gold material visual

(REMOVE) Hitbox/BasicInteraction  ← was COGITO interaction; ISM handles it now
```

The Hitbox is currently on collision_layer 4. The ISM raycast mask is layer 3 per project convention. Verify this matches the other working stations: TortillaStation, TrompoStation use layer 3. Adjust BellStation Hitbox `collision_layer = 4` → `collision_layer = 4` is correct **only if** other stations are also on 4. Re-check during smoke test; if hover does not register, change to layer 3.

## Signal Contract

| Emitter | Signal | Receiver |
|---|---|---|
| ISM | `on_interaction_complete(PERFECT)` (virtual call) | `BellStation.on_interaction_complete` |
| `BellStation` → autoloads | direct call `OrderManager.validate_against_ticket()` | OrderManager |
| `BellStation` → autoloads | direct call `EconomyManager.process_payment(sloppy)` | EconomyManager (Task 4.4) |
| `BellStation` → autoloads | direct call `OrderManager.clear_active_order()` | OrderManager |
| `BellStation` → `EventBus` | `bell_missing_ingredients(missing: Array)` (NEW) | Phase 5.5 ConfirmServePopup |
| `EventBus` | `bell_force_serve_confirmed()` (NEW) | `BellStation._on_force_serve_confirmed` (one-shot) |
| `BellStation` → autoloads | direct call `EconomyManager.deduct_food_cost(ingredient_ids)` on force-serve | EconomyManager |

## API Interface

```gdscript
class_name BellStation
extends TruckStation

func _ready() -> void
func on_interaction_complete(_result: int) -> void  # virtual override
func _on_force_serve_confirmed() -> void            # one-shot popup callback
```

No exports beyond what `TruckStation` already provides.

---

## Section A — Add Signals to `EventBus.gd`

**File:** `res://_src/autoloads/EventBus.gd`

Insert under the ORDER LIFECYCLE block (below `tortilla_taken`):

```gdscript
## Emitted by BellStation when the player rings with required ingredients missing.
## Payload is an Array[String] of missing ingredient_ids (e.g. ["meat", "red_sauce"]).
## Listener: ConfirmServePopup (Phase 5.5) — shows modal asking to force-serve.
signal bell_missing_ingredients(missing: Array)

## Emitted by ConfirmServePopup when the player chooses YES on the force-serve modal.
## Listener: BellStation (one-shot connect made when bell_missing_ingredients fired).
signal bell_force_serve_confirmed()
```

---

## Section B — Create `BellStation.gd`

**File:** `res://_src/interactables/BellStation.gd`

### B.1 — Full script

```gdscript
## BellStation.gd
## Order submission station. Player rings the bell to validate the active taco
## against the active TacoTicket and trigger payment.
##
## INTERACTION:
##   INSTANT type — ISM resolves on the same frame mm_interact is pressed.
##   The held-item gate in ISM is NOT applied here (requires_held_item = false)
##   because the player must be able to ring the bell with no taco in hand to
##   intentionally reject an empty order in the rare cancellation case. Validation
##   below short-circuits gracefully when current_taco is null.
##
## OUTCOMES:
##   1. Complete order  → EconomyManager.process_payment(sloppy_count) → clear.
##   2. Incomplete order → EventBus.bell_missing_ingredients(missing) → wait for
##      EventBus.bell_force_serve_confirmed (one-shot) → deduct_food_cost → clear.
##   3. No active order → debug log; no-op.
##
## Path: res://_src/interactables/BellStation.gd

class_name BellStation
extends TruckStation

# ─────────────────────────────────────────────────────────────────────────────
# LIFECYCLE
# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
    interaction_type = InteractionType.INSTANT
    interact_action = &"mm_interact"
    display_name = "Bell"
    interaction_prompt_text = "Ring Bell"
    requires_held_item = false  # see comment in header

# ─────────────────────────────────────────────────────────────────────────────
# TRUCK STATION VIRTUAL OVERRIDES
# ─────────────────────────────────────────────────────────────────────────────

func on_interaction_complete(_result: int) -> void:
    if OS.is_debug_build():
        print("[BellStation] Bell rung.")

    # Guard: no order in progress — bell does nothing.
    if not OrderManager.has_active_taco() or OrderManager.current_ticket == null:
        if OS.is_debug_build():
            print("[BellStation] Bell ignored — no active order.")
        return

    var validation: Dictionary = OrderManager.validate_against_ticket()

    if validation.complete:
        # Path 1 — full payment.
        var sloppy: int = int(validation.sloppy_count)
        EconomyManager.process_payment(sloppy)
        OrderManager.clear_active_order()
        return

    # Path 2 — incomplete order. Open confirm dialog.
    var missing: Array = validation.missing
    if OS.is_debug_build():
        print("[BellStation] Order incomplete. Missing: %s" % str(missing))

    # One-shot connect: when the popup fires confirmed, run force-serve once
    # then disconnect so the next bell ring is a clean state.
    if not EventBus.bell_force_serve_confirmed.is_connected(_on_force_serve_confirmed):
        EventBus.bell_force_serve_confirmed.connect(
            _on_force_serve_confirmed,
            CONNECT_ONE_SHOT
        )

    EventBus.bell_missing_ingredients.emit(missing)


# ─────────────────────────────────────────────────────────────────────────────
# FORCE-SERVE PATH
# ─────────────────────────────────────────────────────────────────────────────

func _on_force_serve_confirmed() -> void:
    # Re-check: the player might have completed the order while the popup was
    # open (no — modal blocks input — but defensive code is cheap)
    if not OrderManager.has_active_taco():
        if OS.is_debug_build():
            print("[BellStation] Force-serve ignored — taco no longer active.")
        return

    var ingredient_ids: Array[String] = OrderManager.current_taco.get_ingredient_ids()
    EconomyManager.deduct_food_cost(ingredient_ids)
    # EconomyManager emits EventBus.order_rejected which OrderManager listens
    # to and calls clear_active_order(). No need to call clear here.
```

---

## Section C — Implementation Stub Excerpt

```gdscript
class_name BellStation
extends TruckStation

func _ready() -> void:
    interaction_type = InteractionType.INSTANT
    display_name = "Bell"
    interaction_prompt_text = "Ring Bell"

func on_interaction_complete(_result: int) -> void:
    if not OrderManager.has_active_taco() or OrderManager.current_ticket == null:
        return
    var validation: Dictionary = OrderManager.validate_against_ticket()
    if validation.complete:
        EconomyManager.process_payment(int(validation.sloppy_count))
        OrderManager.clear_active_order()
    else:
        EventBus.bell_force_serve_confirmed.connect(
            _on_force_serve_confirmed, CONNECT_ONE_SHOT)
        EventBus.bell_missing_ingredients.emit(validation.missing)
```

---

## Section D — Editor Steps `[EDITOR]`

1. Open `res://_src/interactables/BellStation.tscn`.
2. Select the root `BellStation` node.
3. In the Inspector → Script field, replace `TruckStation.gd` with `res://_src/interactables/BellStation.gd`.
4. In the Scene panel, select `Hitbox/BasicInteraction` and delete it (we use the ISM's raycast, not COGITO interactions).
5. Verify `Hitbox.collision_layer` matches the layer used by the other functioning stations (TortillaStation, TrompoStation). If raycast hover does not register during smoke test, set `collision_layer` to `1 << 2` (layer 3, value 4 — already set).
6. Save scene.

## Section E — Smoke Test Checklist

- [ ] Walk up to BellStation. Crosshair shows hover state. Console prints from `_on_hover_enter`.
- [ ] Press `mm_interact` with no taco in hand: Console prints `[BellStation] Bell ignored — no active order.` Nothing else happens.
- [ ] Take a tortilla, mash meat to completion, ring bell. With Phase 4.4 wired, `EconomyManager.balance` increases by base_price + tip and TacoBase returns to pool.
- [ ] Take a tortilla only (no meat), ring bell. `EventBus.bell_missing_ingredients` fires with `["meat"]` (verify via temp listener). Without Phase 5.5 popup yet, manually emit `EventBus.bell_force_serve_confirmed.emit()` from Remote tab. EconomyManager debits the tortilla cost and `order_rejected` flows through.
- [ ] Ring bell twice in quick succession with the same incomplete order: only the first call connects the one-shot listener; CONNECT_ONE_SHOT auto-disconnects after first fire.

## Edge Cases

| Case | Behaviour |
|---|---|
| Bell rung with `current_taco` valid but `current_ticket` null (no customer accepted) | Guard at top of `on_interaction_complete` short-circuits with debug log. |
| Player accepts a customer, fully cooks, force-quits the day mid-bell | `OrderManager.clear_active_order()` is called by `EventBus.day_ended` listener (Phase 4.5 SaveManager flow); pooled taco is safe. |
| Two consecutive bells with missing ingredients before popup responds | `is_connected()` guard prevents double-connect; `CONNECT_ONE_SHOT` auto-cleans after fire. The second bell call still re-emits `bell_missing_ingredients`, refreshing the popup payload. |
| Popup never closes (player tabs away) | One-shot connection sits in the EventBus until next emission; harmless (no leaked memory because EventBus signals do not strong-hold beyond one-shot semantics). |
| `validation.missing` returned as untyped `Array` instead of `Array[String]` | Receiving popup must call `var ids: Array[String] = []; for s in payload: ids.append(str(s))` to convert. |
