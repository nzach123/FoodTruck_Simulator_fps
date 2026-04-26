# Task 3.3 — QueueManager Autoload

**Engine:** Godot 4.6 | **Phase:** 3 — Customer AI & Queue Logic | **Predecessors:** Tasks 3.1 + 3.2 complete; `EventBus`, `GameManager`, `EconomyManager`, `NodePool` registered | **Successor handoff:** Task 3.4 provides `DifficultySchedule.tres`; Phase 4 `OrderManager` consumes `EventBus.customer_accepted`

## Objective

Create the autoload that owns customer spawning, slot assignment, and patience enforcement. Responsibilities:
1. Tick a `_spawn_timer` against `day_config.spawn_interval` in `_physics_process`.
2. Checkout `CustomerNPC` from `NodePool`, assign a freshly generated `TacoTicket`, position at a registered `Marker3D` slot.
3. Enforce queue cap via `day_config.max_concurrent` (≤ `MAX_QUEUE_SIZE`).
4. Listen to `CustomerNPC.patience_expired` → debit penalty, emit `EventBus.customer_left`, return to pool.
5. Listen to `EventBus.order_completed` / `EventBus.order_rejected` → release accepted customer.
6. Listen to `EventBus.day_started` / `EventBus.day_ended` → start/stop spawning.

## Boundary

This task does NOT:
- Validate ingredients (Phase 4 `OrderManager`).
- Render UI prompts (Phase 5).
- Drive customer animation (Phase 6).

It only relays signals and shuffles pooled nodes between the slot anchors and the pool container.

---

## System Architecture

`QueueManager` is registered as the 5th custom autoload (after `NodePool`, before COGITO autoloads). It owns three pieces of mutable state: `active_customers` (live `Array[CustomerNPC]`), `pending_ticket` (the `TacoTicket` of the player-accepted customer, kept here so `OrderManager` can read it without re-emitting), and `_spawn_timer` (resets to `day_config.spawn_interval` after each spawn). Slot anchors are passed in by `TruckInterior._ready()` via `register_slots()`. All cross-system messaging flows through `EventBus`. Two new signals (`customer_arrived`, `customer_accepted`) are added to `EventBus.gd`.

## File Roster

| Action | Path |
|---|---|
| `CREATE` | `res://_src/autoloads/QueueManager.gd` |
| `MODIFY` | `res://_src/autoloads/EventBus.gd` (add 2 signals) |
| `MODIFY` | `project.godot` `[autoload]` section (register `QueueManager`) |
| `NO CHANGE` | `_src/autoloads/GameManager.gd`, `EconomyManager.gd`, `NodePool.gd` |

## Signal Contract

| Emitter | Signal | Receiver |
|---|---|---|
| `EventBus` | `day_started(day_number: int)` (existing) | `QueueManager._on_day_started` |
| `EventBus` | `day_ended(day_number: int)` (existing) | `QueueManager._on_day_ended` |
| `EventBus` | `order_completed(payment, tip)` (existing) | `QueueManager._on_order_completed` |
| `EventBus` | `order_rejected(food_cost)` (existing) | `QueueManager._on_order_rejected` |
| `CustomerNPC` | `patience_expired(c)` (Task 3.2) | `QueueManager._on_customer_patience_expired` |
| `CustomerNPC` | `accepted(c)` (Task 3.2) | `QueueManager._on_customer_accepted_local` |
| `CustomerNPC` | `departed(c)` (Task 3.2) | `QueueManager._on_customer_departed` |
| `QueueManager` | `EventBus.customer_arrived(c)` (NEW) | Phase 5 `OrderPanel`, Phase 6 SFX |
| `QueueManager` | `EventBus.customer_accepted(c)` (NEW) | Phase 4 `OrderManager` |
| `QueueManager` | `EventBus.customer_left(penalty)` (existing) | `PenaltyTicker`, HUD |

---

## Section A — Add Signals to `EventBus.gd`

**File:** `res://_src/autoloads/EventBus.gd`

### A.1 — Add inside the CUSTOMER SIGNALS block

Locate:

```gdscript
# ─────────────────────────────────────────────────────────────────────────────
# CUSTOMER SIGNALS
# ─────────────────────────────────────────────────────────────────────────────

## Emitted by QueueManager when a customer's patience runs out and they leave.
## penalty is the amount already debited from EconomyManager.
## Listeners: PenaltyTicker (show "-$X.XX" float text), HUD
signal customer_left(penalty: float)
```

Insert directly **above** the `customer_left` block (so all three customer signals are grouped together):

```gdscript
## Emitted by QueueManager when a CustomerNPC is checked out of the pool,
## given a TacoTicket, and placed at a queue slot.
## Listeners: OrderPanel (show waiting indicator), SFX (door chime).
signal customer_arrived(customer: CustomerNPC)

## Emitted by QueueManager when the player clicks/interacts with a waiting
## customer and the customer transitions WAITING → ACCEPTED.
## Listeners: OrderManager (build pills + start tracking the order).
signal customer_accepted(customer: CustomerNPC)
```

### A.2 — Verify

Save. Editor reports zero parse errors. Re-running the project loads autoloads cleanly.

---

## Section B — Create `QueueManager.gd`

**File:** `res://_src/autoloads/QueueManager.gd`

### B.1 — Full script

Create the file with exactly this content:

```gdscript
## QueueManager.gd
## Owns customer spawning, queue slot assignment, and patience enforcement.
##
## Architecture rules:
##   - Autoload — registered after NodePool, before COGITO autoloads.
##   - All timing in _physics_process (no Timer nodes, no await).
##   - Listens to EventBus for day + order lifecycle; emits via EventBus.
##   - Pool-only — never queue_free() a customer; always NodePool.ret().
##
## Lifecycle:
##   day_started → start_day(config) → _physics_process spawns until cap
##                                  → patience_expired or order_completed
##                                  → release customer → NodePool.ret
##   day_ended  → stop_day() → drain queue, return all customers
##
## Path: res://_src/autoloads/QueueManager.gd

extends Node

# ─────────────────────────────────────────────────────────────────────────────
# CONSTANTS
# ─────────────────────────────────────────────────────────────────────────────

## Hard cap on concurrent visible customers, regardless of DayConfig.
const MAX_QUEUE_SIZE: int = 3

## Pool key for CustomerNPC. Must match NodePool.PREWARM_CONFIG entry.
const CUSTOMER_SCENE: String = "res://_src/entities/customer/CustomerNPC.tscn"

## Path to the master RecipeData resource. Loaded once at _ready().
const RECIPE_DATA_PATH: String = "res://_src/data/recipes/RecipeData.tres"

## Fallback patience-expiry penalty if EconomyConfig is missing the value.
const DEFAULT_PATIENCE_PENALTY: float = 1.50

## Day-3 threshold above which weird orders may roll true.
const WEIRD_ORDERS_FROM_DAY: int = 3

# ─────────────────────────────────────────────────────────────────────────────
# STATE
# ─────────────────────────────────────────────────────────────────────────────

## All customers currently visible in the queue (WAITING or ACCEPTED).
## Departing customers are removed when their `departed` signal fires.
var active_customers: Array[CustomerNPC] = []

## TacoTicket of the player-accepted customer. OrderManager (Phase 4) will
## read this on customer_accepted, so we keep the reference here rather than
## re-emit it through the signal arg.
var pending_ticket: TacoTicket = null

## DayConfig active for the current day. Set by start_day(); null otherwise.
var _day_config: DayConfig = null

## Master recipe template. Loaded once at _ready().
var _recipe: RecipeData = null

## Queue slot Marker3Ds, registered by TruckInterior._ready(). Length == MAX_QUEUE_SIZE.
var _queue_slots: Array[Node3D] = []

## Bookkeeping: which slot index is currently held by which customer (or null).
## Length always == MAX_QUEUE_SIZE.
var _slot_occupants: Array = [null, null, null]

## Seconds until next spawn attempt. Decremented in _physics_process.
var _spawn_timer: float = 0.0

## True between day_started and day_ended. Gates _physics_process work.
var _is_day_active: bool = false

# ─────────────────────────────────────────────────────────────────────────────
# LIFECYCLE
# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_load_recipe()

	# EventBus connections — set up once, persist across days.
	EventBus.day_started.connect(_on_day_started)
	EventBus.day_ended.connect(_on_day_ended)
	EventBus.order_completed.connect(_on_order_completed)
	EventBus.order_rejected.connect(_on_order_rejected)


func _physics_process(delta: float) -> void:
	if not _is_day_active:
		return
	if not is_instance_valid(_day_config):
		return

	# Tutorial day uses spawn_interval 999 — never spawns automatically.
	# (Manual pushes via spawn_next_customer() are still allowed.)
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = _day_config.spawn_interval
		_try_spawn()

# ─────────────────────────────────────────────────────────────────────────────
# PUBLIC API — called by TruckInterior, GameManager
# ─────────────────────────────────────────────────────────────────────────────

## Register Marker3D anchors for queue positions. Called by TruckInterior._ready().
## slots length must be exactly MAX_QUEUE_SIZE; extra slots are ignored.
func register_slots(slots: Array[Node3D]) -> void:
	_queue_slots.clear()
	for i: int in range(min(MAX_QUEUE_SIZE, slots.size())):
		if is_instance_valid(slots[i]):
			_queue_slots.append(slots[i])
		else:
			push_error("[QueueManager] register_slots: slot %d is invalid." % i)

	if _queue_slots.size() < MAX_QUEUE_SIZE:
		push_warning("[QueueManager] Only %d/%d queue slots registered." \
			% [_queue_slots.size(), MAX_QUEUE_SIZE])


## Begin a day. Called via EventBus.day_started.
## day_config is read from GameManager.difficulty_config.
func start_day(day_config: DayConfig) -> void:
	if not is_instance_valid(day_config):
		push_error("[QueueManager] start_day: DayConfig is null.")
		return

	_day_config = day_config
	_spawn_timer = day_config.spawn_interval
	_is_day_active = true

	if OS.is_debug_build():
		print("[QueueManager] Day started. spawn_interval=%.1f, max_concurrent=%d" \
			% [day_config.spawn_interval, day_config.max_concurrent])


## End the day. Called via EventBus.day_ended.
## Drains the queue: returns every active customer to the pool.
func stop_day() -> void:
	_is_day_active = false
	_spawn_timer = 0.0

	# Iterate a copy because _release_customer mutates active_customers.
	var snapshot: Array[CustomerNPC] = active_customers.duplicate()
	for c: CustomerNPC in snapshot:
		_release_customer(c)

	pending_ticket = null
	active_customers.clear()
	for i: int in range(_slot_occupants.size()):
		_slot_occupants[i] = null


## Player has interacted with a waiting customer (e.g. clicked their bubble).
## Phase 5 input layer calls this directly when the player picks a customer.
func accept_customer(c: CustomerNPC) -> void:
	if not is_instance_valid(c):
		push_error("[QueueManager] accept_customer: null customer.")
		return
	if c.state != CustomerNPC.CustomerState.WAITING:
		push_warning("[QueueManager] accept_customer: customer not WAITING (state=%s)" \
			% CustomerNPC.CustomerState.keys()[c.state])
		return

	pending_ticket = c.ticket
	c.accept()
	# c.accept() emits CustomerNPC.accepted; relayed in _on_customer_accepted_local.

# ─────────────────────────────────────────────────────────────────────────────
# PRIVATE — SPAWN
# ─────────────────────────────────────────────────────────────────────────────

## Attempt one spawn. No-op if cap reached, no free slots, or no pool node.
func _try_spawn() -> void:
	# Concurrent cap (DayConfig overrides hard cap, capped at MAX_QUEUE_SIZE).
	var cap: int = min(MAX_QUEUE_SIZE, _day_config.max_concurrent)
	if active_customers.size() >= cap:
		return

	var slot_idx: int = _find_free_slot()
	if slot_idx == -1:
		return

	var customer: Node = NodePool.checkout(CUSTOMER_SCENE)
	if not is_instance_valid(customer):
		push_error("[QueueManager] _try_spawn: NodePool.checkout returned null.")
		return
	if not (customer is CustomerNPC):
		push_error("[QueueManager] _try_spawn: pool returned non-CustomerNPC node.")
		NodePool.ret(customer)
		return

	var c: CustomerNPC = customer as CustomerNPC

	# Build ticket from active day config.
	var allow_weird: bool = GameManager.current_day >= WEIRD_ORDERS_FROM_DAY
	var ticket: TacoTicket = TacoTicket.generate(_recipe, _day_config, allow_weird)
	c.assign_ticket(ticket)

	# Position at the slot anchor.
	var anchor: Node3D = _queue_slots[slot_idx]
	if is_instance_valid(anchor):
		c.global_transform = anchor.global_transform

	c.set_queue_slot(slot_idx)
	_slot_occupants[slot_idx] = c
	active_customers.append(c)

	# Connect lifecycle signals (use one-shot pattern: disconnect on departure).
	if not c.patience_expired.is_connected(_on_customer_patience_expired):
		c.patience_expired.connect(_on_customer_patience_expired)
	if not c.accepted.is_connected(_on_customer_accepted_local):
		c.accepted.connect(_on_customer_accepted_local)
	if not c.departed.is_connected(_on_customer_departed):
		c.departed.connect(_on_customer_departed)

	EventBus.customer_arrived.emit(c)

	if OS.is_debug_build():
		print("[QueueManager] Spawned customer at slot %d. Active: %d" \
			% [slot_idx, active_customers.size()])


## Returns the lowest free slot index, or -1 if all occupied.
func _find_free_slot() -> int:
	for i: int in range(_slot_occupants.size()):
		if _slot_occupants[i] == null:
			return i
	return -1

# ─────────────────────────────────────────────────────────────────────────────
# PRIVATE — RELEASE / CLEANUP
# ─────────────────────────────────────────────────────────────────────────────

## Returns a customer to the pool, frees their slot, disconnects signals.
## Safe to call multiple times on the same customer.
func _release_customer(c: CustomerNPC) -> void:
	if not is_instance_valid(c):
		return

	# Free the slot.
	var idx: int = c.queue_slot_index
	if idx >= 0 and idx < _slot_occupants.size():
		if _slot_occupants[idx] == c:
			_slot_occupants[idx] = null

	# Remove from active list.
	active_customers.erase(c)

	# Disconnect to avoid double-fires when the same instance is recycled.
	if c.patience_expired.is_connected(_on_customer_patience_expired):
		c.patience_expired.disconnect(_on_customer_patience_expired)
	if c.accepted.is_connected(_on_customer_accepted_local):
		c.accepted.disconnect(_on_customer_accepted_local)
	if c.departed.is_connected(_on_customer_departed):
		c.departed.disconnect(_on_customer_departed)

	# Clear pending ticket if this was the accepted customer.
	if pending_ticket != null and c.ticket == pending_ticket:
		pending_ticket = null

	NodePool.ret(c)

# ─────────────────────────────────────────────────────────────────────────────
# PRIVATE — EVENT HANDLERS
# ─────────────────────────────────────────────────────────────────────────────

func _on_day_started(_day_number: int) -> void:
	# GameManager has already set difficulty_config; pull from there.
	var cfg: DayConfig = GameManager.difficulty_config as DayConfig
	if cfg == null:
		push_error("[QueueManager] _on_day_started: GameManager.difficulty_config is null.")
		return
	start_day(cfg)


func _on_day_ended(_day_number: int) -> void:
	stop_day()


func _on_customer_patience_expired(c: CustomerNPC) -> void:
	# Debit penalty from EconomyConfig (with fallback).
	var penalty: float = DEFAULT_PATIENCE_PENALTY
	if is_instance_valid(EconomyManager.config) \
			and EconomyManager.config.get("penalty_patience") != null:
		penalty = EconomyManager.config.penalty_patience

	EconomyManager.debit(penalty, "patience_expired")
	EventBus.customer_left.emit(penalty)
	# CustomerNPC has already self-transitioned to LEAVING_ANGRY;
	# we wait for `departed` to actually return to pool.


func _on_customer_accepted_local(c: CustomerNPC) -> void:
	# Relay to EventBus for OrderManager (Phase 4).
	EventBus.customer_accepted.emit(c)
	# Also fire legacy order_accepted for backwards compatibility with Phase 4 hooks.
	EventBus.order_accepted.emit(c)


func _on_customer_departed(c: CustomerNPC) -> void:
	_release_customer(c)


func _on_order_completed(_payment: float, _tip: float) -> void:
	# The accepted customer (held in pending_ticket via the customer ref)
	# should leave happy. Find them and trigger depart_happy().
	for c: CustomerNPC in active_customers:
		if c.state == CustomerNPC.CustomerState.ACCEPTED:
			c.depart_happy()
			break  # Only one accepted customer at a time.


func _on_order_rejected(_food_cost: float) -> void:
	for c: CustomerNPC in active_customers:
		if c.state == CustomerNPC.CustomerState.ACCEPTED:
			c.depart_angry()
			break

# ─────────────────────────────────────────────────────────────────────────────
# PRIVATE — RESOURCE LOAD
# ─────────────────────────────────────────────────────────────────────────────

func _load_recipe() -> void:
	if ResourceLoader.exists(RECIPE_DATA_PATH):
		_recipe = ResourceLoader.load(RECIPE_DATA_PATH) as RecipeData
		if _recipe == null:
			push_error("[QueueManager] Failed to cast RecipeData at '%s'." % RECIPE_DATA_PATH)
	else:
		push_warning("[QueueManager] RecipeData.tres not found; using runtime default.")
		_recipe = RecipeData.new()
```

### B.2 — Verify

Save. Editor reports zero parse errors. The script will fail at autoload time only if Section C is skipped.

---

## Section C — Register `QueueManager` Autoload `[EDITOR]`

### C.1 — Editor steps

1. `[EDITOR]` Project → Project Settings → Autoload tab.
2. `[EDITOR]` Path: `res://_src/autoloads/QueueManager.gd`. Node Name: `QueueManager`. Click Add.
3. `[EDITOR]` Drag/move `QueueManager` so the order is exactly:
   ```
   EventBus
   GameManager
   EconomyManager
   NodePool
   QueueManager        ← new
   CogitoGlobals
   CogitoSceneManager
   CogitoQuestManager
   (other COGITO autoloads)
   ```
   `QueueManager` MUST appear **after** `EventBus`, `GameManager`, `EconomyManager`, `NodePool` (it references all four at `_ready`).
4. `[EDITOR]` Save Project Settings; close the dialog.

### C.2 — Verify autoload registration

Run the project (F5). The debug console must show no `[QueueManager]` errors. `print(QueueManager)` from any other script returns a non-null reference.

`project.godot` should now contain:

```
QueueManager="*res://_src/autoloads/QueueManager.gd"
```

---

## Section D — Smoke Test

1. Open `TruckInterior.tscn` (Task 3.5 will wire it; until then, run an isolated test).
2. From an editor TestRunner or via the Remote tab in a running session, call:
   ```gdscript
   var cfg := DayConfig.new()
   cfg.patience_seconds = 6.0
   cfg.spawn_interval = 2.0
   cfg.max_concurrent = 2
   cfg.allow_optional_ingredients = true
   QueueManager.register_slots([Marker3D.new(), Marker3D.new(), Marker3D.new()])
   QueueManager.start_day(cfg)
   ```
3. Within 4 seconds you should see two `[QueueManager] Spawned customer at slot N` log lines.
4. Wait 6+ seconds without accepting; expect one or two `[EconomyManager] DEBIT $X.XX (patience_expired)` lines and `EventBus.customer_left` fired.
5. Call `QueueManager.stop_day()`. `active_customers.size()` returns to 0.

---

## Edge Cases Covered

| Case | Behaviour |
|---|---|
| `NodePool.checkout` returns null (pool exhausted, scene missing) | Logs error, no crash, no slot consumed. |
| Pool returns wrong type | Logs error, returns the node to the pool, no slot consumed. |
| `_queue_slots` shorter than `MAX_QUEUE_SIZE` | `_find_free_slot()` only returns indices that exist; cap is effective. |
| `register_slots` called twice | Replaces the array; no leftover references. |
| Day ends with active customers | `stop_day()` snapshot-iterates and releases each one cleanly. |
| Same `CustomerNPC` instance re-spawned later | Signals are reconnected only if not already connected; `is_connected` guards prevent duplicate fires. |
| `accept_customer` called on a non-WAITING customer | Logs warning, no state change. |
| `EconomyManager.config` is null | Falls back to `DEFAULT_PATIENCE_PENALTY`. |
| `RecipeData.tres` missing | Falls back to a default `RecipeData.new()` (`["tortilla", "meat"]`). |
| `GameManager.difficulty_config` is null at `day_started` | Logs error, does not call `start_day`; `_is_day_active` stays false. |
| Multiple customers accept simultaneously (cannot happen with current ISM, but defensive) | `_on_order_completed` `break`s after first match — only one happy departure per signal. |
