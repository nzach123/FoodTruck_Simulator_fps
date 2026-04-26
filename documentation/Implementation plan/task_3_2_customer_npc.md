# Task 3.2 — CustomerNPC Scene & Script

**Engine:** Godot 4.6 | **Phase:** 3 — Customer AI & Queue Logic | **Predecessors:** Task 3.1 (`TacoTicket`) complete | **Successor handoff:** Task 3.3 `QueueManager` checks out `CustomerNPC` from `NodePool`

## Objective

Build a poolable, lightweight customer entity that:
1. Holds a `TacoTicket` reference and a `CustomerState` enum.
2. Drains `patience_remaining` in `_physics_process` (no Timer node, no `await`).
3. Emits three lifecycle signals (`patience_expired`, `accepted`, `departed`) consumed by `QueueManager`.
4. Implements `reset()` so `NodePool.ret()` can recycle it without `queue_free()`.

The scene is **not** a COGITO NPC subclass. COGITO's NPC system is too heavy for this use; we only need a positioned visual placeholder + a script. The pooling key MUST match `NodePool.PREWARM_CONFIG` exactly.

## Boundary

This task does NOT:
- Spawn customers (Task 3.3)
- Validate served tacos (Phase 4 `OrderManager`)
- Drive any locomotion/animation (Phase 5/6)

Patience countdown happens locally; only the timing logic and state mutation live here. The penalty debit is emitted via signal and applied by `QueueManager`.

---

## System Architecture

`CustomerNPC` extends `Node3D` and is treated as a pooled visual object. The script owns its own state machine (`CustomerState`) and its own patience countdown. State transitions are driven by external calls (`assign_ticket()`, `accept()`, `depart_happy()`) plus one internal trigger (patience expiry inside `_physics_process`). All lifecycle events leave the node via the three local signals — `QueueManager` connects to them in Task 3.3 and rebroadcasts to `EventBus` as needed. The scene contains a placeholder `MeshInstance3D` capsule, a `Node3D` `SpeechBubbleAnchor`, and nothing else — Phase 5 will add the bubble UI as a child of the anchor.

⚠ The `NodePool.PREWARM_CONFIG` currently lists `res://_src/entities/customer/Customer.tscn` (count 5). The Phase 3 spec requires the file at `res://_src/entities/customer/CustomerNPC.tscn`. **This task updates `NodePool.PREWARM_CONFIG` to use the new path.**

## File Roster

| Action | Path |
|---|---|
| `CREATE` | `res://_src/entities/customer/CustomerNPC.gd` |
| `CREATE` | `res://_src/entities/customer/CustomerNPC.tscn` |
| `MODIFY` | `res://_src/autoloads/NodePool.gd` (rename pool key) |

## Signal Contract

| Emitter | Signal | Receiver |
|---|---|---|
| `CustomerNPC` | `patience_expired(customer: CustomerNPC)` | `QueueManager._on_customer_patience_expired` |
| `CustomerNPC` | `accepted(customer: CustomerNPC)` | `QueueManager.accept_customer` (forwards to `EventBus.customer_accepted`) |
| `CustomerNPC` | `departed(customer: CustomerNPC)` | `QueueManager` → `NodePool.ret(customer)` |

`CustomerNPC` does NOT touch `EventBus` directly — `QueueManager` is the relay.

---

## Section A — Create `CustomerNPC.gd`

**File:** `res://_src/entities/customer/CustomerNPC.gd`

### A.1 — Full script

Create the file with exactly this content:

```gdscript
## CustomerNPC.gd
## Pooled customer entity. Owns a TacoTicket and a patience countdown.
##
## Architecture rules:
##   - Pool-only — never queue_free(). Use NodePool.ret(self) externally.
##   - All timing in _physics_process (no Timer nodes, no await).
##   - Emits local signals; QueueManager rebroadcasts to EventBus.
##   - reset() returns the node to a clean IDLE state ready for the pool.
##
## Lifecycle:
##   IDLE → (assign_ticket) → WAITING → (accept) → ACCEPTED → ...
##                                  └→ (patience ≤ 0) → LEAVING_ANGRY → (departed)
##                                  └→ (depart_happy) → LEAVING_HAPPY → (departed)
##
## Path: res://_src/entities/customer/CustomerNPC.gd

class_name CustomerNPC
extends Node3D

# ─────────────────────────────────────────────────────────────────────────────
# ENUMS
# ─────────────────────────────────────────────────────────────────────────────

enum CustomerState {
	IDLE,            # In pool, hidden, no ticket.
	WAITING,         # In queue, ticket assigned, patience draining.
	ACCEPTED,        # Player accepted; OrderManager owns the order. Patience frozen.
	LEAVING_HAPPY,   # Order completed; brief leave-state before NodePool.ret.
	LEAVING_ANGRY,   # Patience expired or order rejected; brief leave-state before NodePool.ret.
}

# ─────────────────────────────────────────────────────────────────────────────
# CONSTANTS
# ─────────────────────────────────────────────────────────────────────────────

## How long (seconds) the customer remains visible in a LEAVING_* state
## before QueueManager calls NodePool.ret(). Lets us play a leave anim later.
const LEAVE_DURATION_SECONDS: float = 0.8

# ─────────────────────────────────────────────────────────────────────────────
# SIGNALS
# ─────────────────────────────────────────────────────────────────────────────

## Emitted when patience_remaining reaches 0 in WAITING state.
## Listener: QueueManager → debit penalty, emit EventBus.customer_left.
signal patience_expired(customer: CustomerNPC)

## Emitted when QueueManager calls accept() on this customer.
## Listener: QueueManager → forward to EventBus.customer_accepted, EventBus.order_accepted.
signal accepted(customer: CustomerNPC)

## Emitted when LEAVING_* expires and the customer is ready for NodePool.ret().
## Listener: QueueManager → NodePool.ret(self), free the slot.
signal departed(customer: CustomerNPC)

# ─────────────────────────────────────────────────────────────────────────────
# STATE
# ─────────────────────────────────────────────────────────────────────────────

## The order assigned to this customer. Null in IDLE, non-null in WAITING+.
var ticket: TacoTicket = null

## Current FSM state. Read-only outside this script.
var state: CustomerState = CustomerState.IDLE

## Patience countdown, ticked in _physics_process while in WAITING.
## Set from ticket.patience_seconds in assign_ticket().
var patience_remaining: float = 0.0

## Index of the queue slot this customer occupies. -1 when in pool.
## Used by QueueManager.register_slots() positioning + cleanup.
var queue_slot_index: int = -1

## Internal countdown for LEAVING_* visible-leave window.
var _leave_timer: float = 0.0

# ─────────────────────────────────────────────────────────────────────────────
# LIFECYCLE
# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Pool may instantiate us hidden; ensure clean state regardless.
	reset()


func _physics_process(delta: float) -> void:
	match state:
		CustomerState.WAITING:
			_tick_patience(delta)
		CustomerState.LEAVING_HAPPY, CustomerState.LEAVING_ANGRY:
			_tick_leave(delta)
		_:
			# IDLE / ACCEPTED do not tick.
			pass

# ─────────────────────────────────────────────────────────────────────────────
# PUBLIC API — called by QueueManager only
# ─────────────────────────────────────────────────────────────────────────────

## Resets ALL state to IDLE-ready for pool recycling.
## Called by NodePool._reset_node() via the .has_method("reset") hook.
func reset() -> void:
	ticket = null
	state = CustomerState.IDLE
	patience_remaining = 0.0
	queue_slot_index = -1
	_leave_timer = 0.0
	hide()


## Assigns a ticket and transitions IDLE → WAITING.
## QueueManager calls this immediately after NodePool.checkout().
func assign_ticket(t: TacoTicket) -> void:
	if not is_instance_valid(t):
		push_error("[CustomerNPC] assign_ticket() called with null TacoTicket.")
		return

	ticket = t
	patience_remaining = max(TacoTicket.MIN_PATIENCE_SECONDS, t.patience_seconds)
	state = CustomerState.WAITING
	show()

	if OS.is_debug_build():
		print("[CustomerNPC] assigned ticket (patience=%.1fs, ingredients=%s)" \
			% [patience_remaining, str(t.required_ingredients)])


## Player accepted this customer's order.
## Transitions WAITING → ACCEPTED and freezes patience drain.
## QueueManager calls this; relays to EventBus.
func accept() -> void:
	if state != CustomerState.WAITING:
		push_warning("[CustomerNPC] accept() called from non-WAITING state: %s" % CustomerState.keys()[state])
		return

	state = CustomerState.ACCEPTED
	accepted.emit(self)


## Order completed successfully; trigger happy departure.
## QueueManager calls this on EventBus.order_completed.
func depart_happy() -> void:
	state = CustomerState.LEAVING_HAPPY
	_leave_timer = LEAVE_DURATION_SECONDS


## Patience-expired or rejected; trigger angry departure.
## Called internally on patience expiry; QueueManager may also call on order_rejected.
func depart_angry() -> void:
	state = CustomerState.LEAVING_ANGRY
	_leave_timer = LEAVE_DURATION_SECONDS


## Sets the queue slot index. Called by QueueManager when this customer
## is placed at a Marker3D anchor.
func set_queue_slot(index: int) -> void:
	queue_slot_index = index

# ─────────────────────────────────────────────────────────────────────────────
# PRIVATE HELPERS
# ─────────────────────────────────────────────────────────────────────────────

## Decrement patience while in WAITING. Emit and transition on expiry.
func _tick_patience(delta: float) -> void:
	patience_remaining -= delta
	if patience_remaining <= 0.0:
		patience_remaining = 0.0
		# Emit BEFORE state change so listeners can read 'state' as WAITING.
		patience_expired.emit(self)
		depart_angry()


## Decrement leave-visible timer. Emit departed when done.
func _tick_leave(delta: float) -> void:
	_leave_timer -= delta
	if _leave_timer <= 0.0:
		_leave_timer = 0.0
		departed.emit(self)
		# QueueManager will call NodePool.ret(self) which calls reset().
```

### A.2 — Verify script parses

1. Save. Editor reports zero parse errors.
2. Open FileSystem dock; the script should have the `Node3D`-with-script icon.

---

## Section B — Create `CustomerNPC.tscn`

**File:** `res://_src/entities/customer/CustomerNPC.tscn`

### B.1 — Node hierarchy

```
CustomerNPC                      [Node3D]   (script: CustomerNPC.gd)
├── Visual                       [MeshInstance3D]    (CapsuleMesh placeholder)
└── SpeechBubbleAnchor           [Node3D]            (positioned above head)
```

### B.2 — Editor steps `[EDITOR]`

1. `[EDITOR]` In Godot, right-click `_src/entities/customer/` (create folder if absent) → New Scene → Other Node → `Node3D`. Rename root to `CustomerNPC`. Save as `CustomerNPC.tscn`.
2. `[EDITOR]` Select root `CustomerNPC` → Inspector → "Attach Script" → choose existing `res://_src/entities/customer/CustomerNPC.gd`.
3. `[EDITOR]` Add child `MeshInstance3D`, rename `Visual`.
   - Inspector → Mesh → New CapsuleMesh.
   - Open the mesh: Radius `0.3`, Height `1.7`.
   - Transform → Position `Y = 0.85` (capsule centred on the ground at root origin).
4. `[EDITOR]` Add child `Node3D`, rename `SpeechBubbleAnchor`.
   - Transform → Position `Y = 1.9` (above head, where Phase 5 mounts the bubble).
5. `[EDITOR]` Save the scene (Ctrl+S).
6. `[EDITOR]` Confirm the saved file path is **exactly** `res://_src/entities/customer/CustomerNPC.tscn`.

### B.3 — Verify scene

Open scene; root inspector shows the script's `state`, `ticket`, `patience_remaining` fields (all defaults). Run scene standalone (F6); console prints nothing (correct — script does nothing in IDLE). No errors.

---

## Section C — Update `NodePool.PREWARM_CONFIG`

**File:** `res://_src/autoloads/NodePool.gd`

### C.1 — Replace the customer pool entry

Locate:

```gdscript
"res://_src/entities/customer/Customer.tscn":   5,  # Max 3 concurrent + 2 transitioning
```

Replace with:

```gdscript
"res://_src/entities/customer/CustomerNPC.tscn":   5,  # Max 3 concurrent + 2 transitioning
```

### C.2 — Verify pool prewarm

1. Open `TruckInterior.tscn` (Phase 3.5 will wire prewarm; for now the autoload will silently skip if no container is registered).
2. After Task 3.5 completes, run the scene; debug console must print:
   ```
   [NodePool] Pre-warmed 5 × 'CustomerNPC.tscn'
   ```
3. No `[NodePool] _prewarm() skipped — scene not found` warning.

---

## Edge Cases Covered

| Case | Behaviour |
|---|---|
| `assign_ticket(null)` | Logs error, leaves state untouched. |
| `accept()` called outside WAITING | Logs warning, no state change, no signal. |
| Patience expires exactly at frame boundary | Clamped to 0; emits `patience_expired` once; transitions to LEAVING_ANGRY immediately. |
| `_physics_process` runs while hidden | Match falls into `_` branch (IDLE/ACCEPTED), so no work done. |
| Pool recycles the same instance | `reset()` clears every field; `state` is forced back to IDLE. |
| Scene path mismatch with PREWARM_CONFIG | Section C.1 updates the key; verified in Section C.2. |
