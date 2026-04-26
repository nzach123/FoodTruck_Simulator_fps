# Task 4.1 — OrderManager Autoload

**Engine:** Godot 4.6 | **Phase:** 4 — Game Loop & Economy | **Predecessors:** Phase 2 (TacoBase, IngredientState, all four cooking stations) and Phase 3 (TacoTicket, CustomerNPC, QueueManager) complete | **Successor handoff:** Task 4.2 (BellStation) calls `OrderManager.validate_against_ticket()` and `OrderManager.clear_active_order()`; Phase 5 OrderHUD reads `EventBus.order_accepted` for pill rendering.

## Objective

Create the single owner of the in-progress taco order. OrderManager listens for cooking-step signals, writes them into the active TacoBase, attaches the TacoBase to the player's hand on tortilla pickup, and exposes a synchronous validation API that BellStation will call. It owns no UI and no economy logic — it is the bridge between cooking stations and the bell.

Responsibilities:
1. Hold a reference to the active `TacoBase` (the in-hand taco) and the active `TacoTicket` (the accepted customer's order).
2. On `EventBus.tortilla_taken`, checkout a TacoBase from NodePool and parent it to the player's HandAnchor Marker3D.
3. On `EventBus.order_step_completed(ingredient_id, quality)`, write into `current_taco.add_ingredient()`.
4. On `EventBus.customer_accepted(customer)`, capture `customer.ticket` as `current_ticket` and emit `EventBus.order_accepted` for the HUD.
5. Provide `validate_against_ticket() -> Dictionary` for BellStation (Task 4.2 / 4.3).
6. Provide `clear_active_order()` to return the TacoBase to the pool after payment.
7. Provide `has_active_taco() -> bool` for the ISM held-item gate already wired in `_start_interaction()`.

## Boundary

This task does NOT:
- Score quality (Task 4.3 — but `validate_against_ticket()` is added here as the contract surface; the inline body is finalised in 4.3).
- Touch money (Task 4.4 — EconomyManager).
- Render the order panel (Phase 5).
- Drive customer acceptance UX (Phase 5 — accept-by-click on customer is added later).

It only owns the lifecycle of `current_taco` + `current_ticket`.

---

## System Architecture

OrderManager registers as the 6th custom autoload, after `QueueManager` and before `SaveManager`. It connects to four EventBus signals at `_ready()` and exposes three public methods (`has_active_taco`, `validate_against_ticket`, `clear_active_order`) plus two new EventBus signals (`taco_attached_to_hand`, `taco_returned`). The HandAnchor `Marker3D` is added under the COGITO player's camera in `TruckInterior.tscn` and tagged with the `player_hand_anchor` group so OrderManager can resolve it via `get_tree().get_first_node_in_group()` once per session (cached). All node hand-off uses `NodePool.checkout` / `NodePool.ret` — never `queue_free`.

## File Roster

| Action | Path |
|---|---|
| `[CREATE]` | `res://_src/autoloads/OrderManager.gd` |
| `[MODIFY]` | `res://_src/autoloads/EventBus.gd` (add 2 signals: `taco_attached_to_hand`, `taco_returned`) |
| `[MODIFY]` | `project.godot` `[autoload]` section — register `OrderManager` after `QueueManager` `[EDITOR]` |
| `[MODIFY]` | `res://_src/levels/TruckInterior.tscn` — add `HandAnchor` Marker3D under `CogitoPlayer/Body/Neck/Head/Eyes/Camera`, add to group `player_hand_anchor` `[EDITOR]` |
| `[MODIFY]` | `res://_src/autoloads/QueueManager.gd` — emit `EventBus.customer_accepted(c)` from `accept_customer()` (already specced in Task 3.3 as the new EventBus signal) |
| `[NO CHANGE]` | `_src/player/InteractionStateMachine.gd` — its existing `has_active_taco` lookup at lines 256–257 lights up automatically once the autoload exists. |

---

## Node Architecture

```
TruckInterior (Node3D)
└── CogitoPlayer (CharacterBody3D)
    └── Body
        └── Neck
            └── Head
                └── Eyes
                    └── Camera (Camera3D)
                        └── HandAnchor (Marker3D)        ← NEW; group "player_hand_anchor"
                            (TacoBase will reparent here at runtime)
```

The HandAnchor's local transform should be `(0.18, -0.20, -0.45)` so the taco sits in the lower-right of the screen at arm's length without occluding the crosshair. No physics body — the taco rides on the camera's transform automatically.

OrderManager itself is a non-visual autoload (`extends Node`); it has no scene tree representation.

## Signal Contract

| Emitter | Signal | Receiver |
|---|---|---|
| `EventBus` | `tortilla_taken()` (existing) | `OrderManager._on_tortilla_taken` |
| `EventBus` | `order_step_completed(id, quality)` (existing) | `OrderManager._on_step_completed` |
| `EventBus` | `customer_accepted(customer: CustomerNPC)` (Task 3.3) | `OrderManager._on_customer_accepted` |
| `EventBus` | `order_completed(payment, tip)` (existing) | `OrderManager._on_order_completed` (clears state) |
| `EventBus` | `order_rejected(food_cost)` (existing) | `OrderManager._on_order_rejected` (clears state) |
| `OrderManager` → `EventBus` | `taco_attached_to_hand(taco: TacoBase)` (NEW) | Phase 5 HUD, Phase 6 SFX |
| `OrderManager` → `EventBus` | `taco_returned()` (NEW) | Phase 5 HUD (clear pills), Phase 6 SFX |
| `OrderManager` → `EventBus` | `order_accepted(customer: Node)` (existing) | Phase 5 OrderHUD pill builder |

## API Interface

```gdscript
# Public API (autoload-singleton accessible)
func has_active_taco() -> bool
func validate_against_ticket() -> Dictionary
func clear_active_order() -> void

# Public state (read-only outside)
var current_taco: TacoBase = null
var current_ticket: TacoTicket = null
```

The `validate_against_ticket()` return shape is the canonical Validator contract used by BellStation:
```
{
    "complete": bool,           # true if every required ingredient is present
    "missing": Array[String],   # ingredient_ids absent from current_taco
    "sloppy_count": int,        # how many SLOPPY-quality steps recorded
}
```

---

## Section A — Add Signals to `EventBus.gd`

**File:** `res://_src/autoloads/EventBus.gd`

Insert directly below the `tortilla_taken` declaration (line ~43):

```gdscript
## Emitted by OrderManager after a TacoBase is checked out and parented to
## the player's HandAnchor. Listeners: HUD (show empty taco), SFX (pickup pop).
signal taco_attached_to_hand(taco: Node)

## Emitted by OrderManager after the active TacoBase is returned to NodePool.
## Fires on order_completed, order_rejected, and end-of-day cleanup.
## Listeners: HUD (clear pills), SFX (place sound).
signal taco_returned()
```

---

## Section B — Create `OrderManager.gd`

**File:** `res://_src/autoloads/OrderManager.gd`

### B.1 — Full script

```gdscript
## OrderManager.gd
## Single owner of the in-progress taco order.
##
## Listens to cooking-station EventBus signals and writes results into the
## active TacoBase. Holds the active TacoTicket (copied from the accepted
## customer) for BellStation to validate against.
##
## DOES NOT: handle money, render UI, or queue_free anything.
## All node lifecycle goes through NodePool.
##
## Registered in: Project Settings > Autoloads > OrderManager (after QueueManager).
## Path: res://_src/autoloads/OrderManager.gd

extends Node

# ─────────────────────────────────────────────────────────────────────────────
# CONSTANTS
# ─────────────────────────────────────────────────────────────────────────────

const TACO_SCENE_PATH: String = "res://_src/entities/food/TacoBase.tscn"
const HAND_ANCHOR_GROUP: String = "player_hand_anchor"

# ─────────────────────────────────────────────────────────────────────────────
# STATE
# ─────────────────────────────────────────────────────────────────────────────

## The TacoBase currently parented to the player's HandAnchor.
## Null when the player has nothing in hand.
var current_taco: TacoBase = null

## The TacoTicket of the customer the player has accepted.
## Null when no order is in progress.
var current_ticket: TacoTicket = null

## Cached HandAnchor Marker3D under the player's camera.
## Resolved lazily on first tortilla pickup and reused thereafter.
var _hand_anchor: Node3D = null

# ─────────────────────────────────────────────────────────────────────────────
# LIFECYCLE
# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
    EventBus.tortilla_taken.connect(_on_tortilla_taken)
    EventBus.order_step_completed.connect(_on_step_completed)
    EventBus.customer_accepted.connect(_on_customer_accepted)
    EventBus.order_completed.connect(_on_order_completed)
    EventBus.order_rejected.connect(_on_order_rejected)

# ─────────────────────────────────────────────────────────────────────────────
# PUBLIC API
# ─────────────────────────────────────────────────────────────────────────────

## Used by InteractionStateMachine._start_interaction() to gate stations
## with requires_held_item = true (Trompo, Sauce, Topping).
func has_active_taco() -> bool:
    return is_instance_valid(current_taco)


## Compares the active taco against the active ticket.
## Body finalised in Task 4.3; this stub returns a safe default until then.
func validate_against_ticket() -> Dictionary:
    if not is_instance_valid(current_taco) or current_ticket == null:
        return {"complete": false, "missing": [] as Array[String], "sloppy_count": 0}
    var missing: Array[String] = []
    for ingredient_id: String in current_ticket.required_ingredients:
        if not current_taco.has_ingredient(ingredient_id):
            missing.append(ingredient_id)
    return {
        "complete": missing.is_empty(),
        "missing": missing,
        "sloppy_count": current_taco.get_sloppy_count(),
    }


## Returns the active TacoBase to NodePool and clears all order state.
## Called by BellStation after a successful payment, and by EventBus.order_*
## listeners as a safety net.
func clear_active_order() -> void:
    if is_instance_valid(current_taco):
        # Detach from hand anchor before pooling so the pool's container
        # becomes the new parent on ret().
        if current_taco.get_parent() != null:
            current_taco.get_parent().remove_child(current_taco)
        NodePool.ret(current_taco)
    current_taco = null
    current_ticket = null
    EventBus.taco_returned.emit()
    if OS.is_debug_build():
        print("[OrderManager] Active order cleared.")

# ─────────────────────────────────────────────────────────────────────────────
# EVENT HANDLERS
# ─────────────────────────────────────────────────────────────────────────────

func _on_tortilla_taken() -> void:
    # Already holding a taco — ignore double-pickup.
    if has_active_taco():
        if OS.is_debug_build():
            print("[OrderManager] tortilla_taken ignored — already holding taco.")
        return

    var anchor: Node3D = _resolve_hand_anchor()
    if not is_instance_valid(anchor):
        push_error("[OrderManager] No HandAnchor found in group '%s'." % HAND_ANCHOR_GROUP)
        return

    var taco: Node = NodePool.checkout(TACO_SCENE_PATH)
    if not (taco is TacoBase):
        push_error("[OrderManager] NodePool returned non-TacoBase node for '%s'." % TACO_SCENE_PATH)
        return

    current_taco = taco as TacoBase
    current_taco.reset()  # belt-and-braces; NodePool also calls reset()
    # Tortilla itself is a recipe step; record it now so the player does not
    # need to "re-add" it later. Quality PERFECT for INSTANT pickup.
    current_taco.add_ingredient("tortilla", IngredientState.State.PERFECT)

    # Reparent under the camera-mounted HandAnchor.
    if current_taco.get_parent() != null:
        current_taco.get_parent().remove_child(current_taco)
    anchor.add_child(current_taco)
    current_taco.transform = Transform3D.IDENTITY

    EventBus.taco_attached_to_hand.emit(current_taco)
    if OS.is_debug_build():
        print("[OrderManager] Taco attached to hand.")


func _on_step_completed(ingredient_id: String, quality: int) -> void:
    # The tortilla pickup path writes its own ingredient; ignore the duplicate
    # signal to avoid double-counting.
    if ingredient_id == "tortilla":
        return
    if not has_active_taco():
        if OS.is_debug_build():
            print("[OrderManager] Step '%s' ignored — no active taco." % ingredient_id)
        return
    current_taco.add_ingredient(ingredient_id, quality)


func _on_customer_accepted(customer: Node) -> void:
    if customer == null or customer.get("ticket") == null:
        push_warning("[OrderManager] customer_accepted with null ticket.")
        return
    current_ticket = customer.ticket as TacoTicket
    EventBus.order_accepted.emit(customer)
    if OS.is_debug_build():
        print("[OrderManager] Order accepted: %s" % str(current_ticket.required_ingredients))


func _on_order_completed(_payment: float, _tip: float) -> void:
    clear_active_order()


func _on_order_rejected(_food_cost: float) -> void:
    clear_active_order()

# ─────────────────────────────────────────────────────────────────────────────
# PRIVATE HELPERS
# ─────────────────────────────────────────────────────────────────────────────

func _resolve_hand_anchor() -> Node3D:
    if is_instance_valid(_hand_anchor):
        return _hand_anchor
    var node: Node = get_tree().get_first_node_in_group(HAND_ANCHOR_GROUP)
    if node is Node3D:
        _hand_anchor = node as Node3D
    return _hand_anchor
```

---

## Section C — Implementation Stub Excerpt

```gdscript
extends Node

var current_taco: TacoBase = null
var current_ticket: TacoTicket = null

func _ready() -> void:
    EventBus.tortilla_taken.connect(_on_tortilla_taken)
    EventBus.order_step_completed.connect(_on_step_completed)
    EventBus.customer_accepted.connect(_on_customer_accepted)

func has_active_taco() -> bool:
    return is_instance_valid(current_taco)

func _on_step_completed(ingredient_id: String, quality: int) -> void:
    if ingredient_id == "tortilla" or not has_active_taco():
        return
    current_taco.add_ingredient(ingredient_id, quality)
```

---

## Section D — Editor Steps `[EDITOR]`

1. Open `Project Settings → Autoload`. Add `res://_src/autoloads/OrderManager.gd` with name `OrderManager`. Drag it to position **after** `QueueManager` and **before** `SaveManager` (Task 4.5).
2. Open `res://_src/levels/TruckInterior.tscn`. Navigate to `CogitoPlayer/Body/Neck/Head/Eyes/Camera`. Add child → `Marker3D`, rename `HandAnchor`. Set local transform position `(0.18, -0.20, -0.45)`. In the Node tab, add it to group `player_hand_anchor`.
3. Save scene.

## Section E — Smoke Test Checklist

- [ ] Run `TruckInterior.tscn`. No autoload errors in the Output panel.
- [ ] Walk to TortillaStation, press `mm_interact`. Console prints `[OrderManager] Taco attached to hand.` and a TacoBase mesh is visible at lower-right of the camera.
- [ ] Walk to TrompoStation. ISM no longer logs `Station blocked: no_taco` because `has_active_taco()` returns true.
- [ ] Complete a meat mash. `current_taco.has_ingredient("meat")` evaluates true (verify via Remote tab).
- [ ] Add a SauceStation HOLD. `current_taco.get_sloppy_count()` reflects 1 if the player over-pours.
- [ ] Manually emit `EventBus.order_completed.emit(3.50, 1.00)` from Remote tab. TacoBase disappears from hand and returns to pool.

## Edge Cases

| Case | Behaviour |
|---|---|
| `tortilla_taken` while already holding a taco | Ignored with debug print; no double-checkout. |
| `order_step_completed` with no active taco | Ignored; ingredient is dropped. Player must pick up tortilla first. |
| HandAnchor missing from scene tree | `push_error` logged; taco stays in pool, `current_taco` remains null, `has_active_taco()` returns false. |
| `customer_accepted` with null ticket | `push_warning`; `current_ticket` stays null, `validate_against_ticket()` returns `{complete: false, ...}`. |
| `clear_active_order()` called twice | Second call is a no-op (`is_instance_valid` guard); `taco_returned` still emits — UI listeners must be idempotent. |
