# Task 3.5 — Queue Slot Anchors in TruckInterior

**Engine:** Godot 4.6 | **Phase:** 3 — Customer AI & Queue Logic | **Predecessors:** Tasks 3.2 (`CustomerNPC`) + 3.3 (`QueueManager`) scripts written; `NodePool`, `EventBus`, `GameManager` registered | **Successor handoff:** Phase 4 `OrderManager` reads `QueueManager.pending_ticket`; Phase 5 HUD reads `EventBus.customer_arrived`

## Objective

Wire the physical queue infrastructure into `TruckInterior.tscn` and produce the runtime contract that `QueueManager` and `CustomerNPC` depend on. Responsibilities:

1. Add three `Marker3D` slot anchors outside the serving window, spaced for up to three concurrent customers.
2. Add a `NodePoolContainer` node as the pool parent (required by `NodePool.register_container()`).
3. Create `TruckInterior.gd` extending `cogito_scene.gd` to call pool + slot registration in `_ready()` without breaking existing COGITO scene-management logic.
4. Define the slot-assignment, queue-shuffle, and customer movement contract so `QueueManager` can call `CustomerNPC.move_to_slot()` to animate position changes.

## Boundary

This task does NOT:

- Implement `CustomerNPC` patience or state machine (Task 3.2).
- Implement `QueueManager` spawning loop or patience enforcement (Task 3.3).
- Add customer mesh or animations (Phase 6).
- Handle `TacoTicket` generation or ordering (Tasks 3.1, 4.1).

It only installs the anchor nodes, wires the two boot calls, and specifies the movement API surface.

---

## System Architecture

`TruckInterior._ready()` is the single boot point for scene-level infrastructure. It must fire the two calls that depend on scene-tree presence (NodePool and QueueManager registrations) — autoloads cannot do this themselves because they have no reference to scene nodes. The slot anchors are dumb `Marker3D` nodes; `QueueManager` reads their `global_position` once per slot assignment and does not poll them afterward. Queue shuffling (moving remaining customers forward when one leaves) is triggered inside `QueueManager._release_customer()` by calling `CustomerNPC.move_to_slot()` with the new slot's world position. `CustomerNPC._physics_process()` drives the interpolation with no `await` or `Tween`.

## File Roster

| Action | Path |
|---|---|
| `CREATE` | `res://_src/levels/TruckInterior.gd` |
| `MODIFY` | `res://_src/levels/TruckInterior.tscn` — add `NodePoolContainer`, `QueueAnchors/Slot0/Slot1/Slot2`, assign root script |
| `MODIFY` | `res://_src/autoloads/QueueManager.gd` — add `_shuffle_queue()` call in `_release_customer()` |
| `MODIFY` | `res://_src/entities/customer/CustomerNPC.gd` — add `move_to_slot()` + `_tick_movement()` |

---

## Section A — Node Hierarchy

### A.1 — Nodes to add in `TruckInterior.tscn` `[EDITOR]`

The final scene tree additions (place at the same level as `Stations` and `Lighting`):

```
TruckInterior (Node3D)          ← existing root; script changes in Section C
├── NodePoolContainer (Node)    ← NEW — pool parent; keeps pooled nodes out of Stations subtree
├── QueueAnchors (Node3D)       ← NEW — logical group; no physics, no mesh
│   ├── Slot0 (Marker3D)        ← NEW — front slot, directly at serving window
│   ├── Slot1 (Marker3D)        ← NEW — middle slot, 1 m back
│   └── Slot2 (Marker3D)        ← NEW — back slot, 2 m back
├── Stations (existing)
├── CSGGeo (existing)
├── CogitoPlayer (existing)
└── Lighting (existing)
```

**Why `Marker3D`:** zero runtime cost (no mesh, no collision body), visible as axis gizmo in the editor for accurate positioning, and `global_position` is the only property `QueueManager` ever reads from it.

**Why `NodePoolContainer` as `Node` (not `Node3D`):** pooled nodes need a stable parent; `Node` has no transform overhead and prevents accidentally inheriting viewport or physics layer settings.

### A.2 — Editor steps `[EDITOR]`

1. Open `TruckInterior.tscn`.
2. In the Scene panel, select the root `TruckInterior` node.
3. Add child → `Node`; rename to `NodePoolContainer`.
4. Add child → `Node3D`; rename to `QueueAnchors`.
5. Select `QueueAnchors`, add three `Marker3D` children named `Slot0`, `Slot1`, `Slot2`.
6. Set transforms per Section B.
7. Save the scene.

---

## Section B — Spatial Layout

### B.1 — Coordinate reference

The truck interior geometry is built from `CSGBody` (centre `(0.017, 1.35, 0.0)`, half-extents `(1.83, 1.59, 2.85)`). The exterior left wall sits at **X ≈ −1.81**. The serving window cutout (`CSGBool`) is centred at `(−1.56, 1.38, 1.74)` — left wall, positive-Z half of the truck. `BellStation` is at `(−1.27, 0.75, 1.02)` — this is the primary customer–player contact point. The floor top surface is **Y = 0.0** (`CSGFloor` centre `Y = −0.125`, half-height `0.125`).

The customer queue forms on the **exterior left** (negative-X) side, running along negative-Z away from the window.

### B.2 — Slot transforms

| Node | Transform (X, Y, Z) | Notes |
|---|---|---|
| `QueueAnchors` | `(0.0, 0.0, 0.0)` | Identity — children use global positions |
| `Slot0` | `(−2.5, 0.0, 1.5)` | Front — aligned with window and `BellStation` Z |
| `Slot1` | `(−2.5, 0.0, 0.5)` | Middle — 1 m back |
| `Slot2` | `(−2.5, 0.0, −0.5)` | Back — 2 m back |

**Rationale:**
- X = −2.5 places NPCs 0.69 m clear of the exterior wall, enough for a capsule body.
- Y = 0.0 is flush with the floor surface; CustomerNPC capsule bottom aligns here.
- 1.0 m Z-spacing accommodates a standard NPC capsule (`radius 0.3`, `height 1.8`) with comfortable gap.
- Slot0's Z = 1.5 matches the serving window midpoint so the front customer faces the player through the window.

### B.3 — Rotation

Leave all three `Marker3D` nodes at default rotation `(0, 0, 0)`. If customers need to face the truck, set `Slot0.rotation.y = PI / 2` (facing positive-X, toward the truck). The exact facing is cosmetic and can be tuned in Phase 6.

---

## Section C — `TruckInterior.gd`

### C.1 — COGITO inheritance constraint

`cogito_scene.gd` (at `res://addons/cogito/SceneManagement/cogito_scene.gd`) extends `Node` directly with **no `class_name`** and **no `_ready()` method**. It registers the scene root with `CogitoSceneManager` in `_enter_tree()`. Because it has no `class_name`, we extend it by file path.

**Critical:** TruckInterior.gd must extend `cogito_scene.gd` by path — not `Node3D` directly — to preserve `_enter_tree()` behavior (scene-root registration with `CogitoSceneManager`).

### C.2 — Create `TruckInterior.gd`

**File:** `res://_src/levels/TruckInterior.gd`

```gdscript
## TruckInterior.gd
## Boot script for the main gameplay scene.
##
## Responsibilities:
##   1. Extend cogito_scene.gd so COGITO's _enter_tree() registration is preserved.
##   2. Register the NodePoolContainer with NodePool (must happen before prewarm).
##   3. Prewarm all NodePool entries (amortises WASM allocation at load time).
##   4. Register queue slot anchors with QueueManager.
##
## _ready() fires AFTER _enter_tree(), so CogitoSceneManager is already set
## and all autoloads (including QueueManager) are ready before we call them.
##
## Path: res://_src/levels/TruckInterior.gd

extends "res://addons/cogito/SceneManagement/cogito_scene.gd"

# NodePool container — keeps pooled nodes out of the Stations subtree.
@onready var _pool_container: Node = $NodePoolContainer

# Queue slot anchors registered with QueueManager.
@onready var _slot0: Marker3D = $QueueAnchors/Slot0
@onready var _slot1: Marker3D = $QueueAnchors/Slot1
@onready var _slot2: Marker3D = $QueueAnchors/Slot2


func _ready() -> void:
	# 1. Register container first — NodePool._prewarm() uses _container as parent.
	NodePool.register_container(_pool_container)

	# 2. Prewarm all pooled scenes.
	#    This is synchronous on WASM; all nodes exist before the frame renders.
	NodePool.prewarm_all()

	# 3. Hand slot anchors to QueueManager.
	#    QueueManager must be registered as an autoload before this point.
	var slots: Array[Node3D] = [_slot0, _slot1, _slot2]
	QueueManager.register_slots(slots)
```

### C.3 — Attach script to scene root `[EDITOR]`

1. Open `TruckInterior.tscn`.
2. Select the root `TruckInterior` node.
3. In the Inspector, click the Script field (currently shows `cogito_scene.gd`).
4. Choose "Load" → navigate to `res://_src/levels/TruckInterior.gd`.
5. Confirm. The Inspector now shows `TruckInterior.gd`.
6. Save the scene.

> **Verify:** Run the scene (F6). The Remote tab should show `NodePoolContainer` as parent of prewarmed nodes. No `[QueueManager]` or `[NodePool]` errors in the output.

---

## Section D — CustomerNPC Movement API

The following must be implemented in `CustomerNPC.gd` (Task 3.2 script) to satisfy the slot-assignment and queue-shuffle calls from `QueueManager`.

### D.1 — State additions

```gdscript
# Slot management — set by QueueManager; read back in _release_customer.
var queue_slot_index: int = -1

# Movement target — updated by move_to_slot(); consumed by _tick_movement().
var _target_position: Vector3 = Vector3.ZERO
var _is_moving: bool = false
```

### D.2 — Public API

```gdscript
## Called by QueueManager to record which slot this customer occupies.
## Also used for the initial placement teleport on spawn.
func set_queue_slot(slot_idx: int) -> void:
	queue_slot_index = slot_idx


## Called by QueueManager when the customer must slide to a new slot position.
## Triggers smooth movement via _tick_movement() in _physics_process().
## Never teleports (except at spawn — see QueueManager._try_spawn()).
func move_to_slot(slot_world_pos: Vector3) -> void:
	_target_position = slot_world_pos
	_is_moving = true
```

### D.3 — Movement tick (add to `_physics_process`)

```gdscript
const MOVE_SPEED: float = 2.0       # m/s — tunable for Phase 6 polish
const SNAP_THRESHOLD: float = 0.05  # snap within 5 cm to avoid float jitter

func _physics_process(delta: float) -> void:
	_tick_patience(delta)   # existing patience countdown (Task 3.2)
	_tick_movement(delta)


func _tick_movement(delta: float) -> void:
	if not _is_moving:
		return
	var dist: float = global_position.distance_to(_target_position)
	if dist <= SNAP_THRESHOLD:
		global_position = _target_position
		_is_moving = false
		return
	global_position = global_position.move_toward(_target_position, MOVE_SPEED * delta)
```

**Constraints:**
- Uses `move_toward()` — no `await`, no `Timer`, no `Tween`. Safe on WASM.
- `MOVE_SPEED` moves a customer 1 m in 0.5 s — feels natural at normal game pace.
- `SNAP_THRESHOLD` of 0.05 prevents float jitter at the destination but is imperceptible visually.
- `_tick_movement` is a no-op when `_is_moving == false`, adding zero cost to stationary customers.

### D.4 — Reset contract

`CustomerNPC.reset()` (called by `NodePool._reset_node()` on pool return) must clear movement state:

```gdscript
func reset() -> void:
	ticket = null
	state = CustomerState.IDLE
	queue_slot_index = -1
	_target_position = Vector3.ZERO
	_is_moving = false
	patience_remaining = 0.0
	hide()
```

---

## Section E — Queue Shuffle in `QueueManager`

When a customer leaves (patience expired, order completed, or order rejected), all customers behind the freed slot must slide forward to maintain a tight queue. This addition extends `QueueManager._release_customer()` from Task 3.3.

### E.1 — Add `_shuffle_queue()` to `QueueManager.gd`

Add this private method:

```gdscript
## After a customer vacates slot `freed_idx`, shift every customer at a higher
## slot index one step forward (toward index 0 / the serving window).
## Calls move_to_slot() on each affected customer to trigger smooth movement.
func _shuffle_queue(freed_idx: int) -> void:
	for i: int in range(freed_idx, _slot_occupants.size() - 1):
		var next_customer: CustomerNPC = _slot_occupants[i + 1]
		if next_customer == null:
			break  # gap in queue — no further customers to shift
		# Move forward by one slot.
		_slot_occupants[i] = next_customer
		_slot_occupants[i + 1] = null
		next_customer.queue_slot_index = i
		if i < _queue_slots.size() and is_instance_valid(_queue_slots[i]):
			next_customer.move_to_slot(_queue_slots[i].global_position)
```

### E.2 — Call site in `_release_customer()`

Inside the existing `_release_customer()` method in `QueueManager.gd`, add the `_shuffle_queue()` call **after** the slot is freed and **before** `NodePool.ret()`:

```gdscript
func _release_customer(c: CustomerNPC) -> void:
	if not is_instance_valid(c):
		return

	var idx: int = c.queue_slot_index
	if idx >= 0 and idx < _slot_occupants.size():
		if _slot_occupants[idx] == c:
			_slot_occupants[idx] = null
			_shuffle_queue(idx)      # ← ADD THIS LINE

	active_customers.erase(c)

	# ... disconnect signals, clear pending_ticket, NodePool.ret(c) — unchanged
```

### E.3 — Shuffle invariants

| Condition | Behaviour |
|---|---|
| Slot 0 freed (front customer served) | Slot 1 customer moves to slot 0; slot 2 customer moves to slot 1. |
| Slot 1 freed (middle customer left angry) | Slot 2 customer moves to slot 1; slot 0 unaffected. |
| Slot 2 freed (back customer left angry) | No shuffle needed — gap is at the end. |
| Gap in occupants before end (`null` at index i+1) | `break` immediately — preserves sparse array safety. |

---

## Section F — Integration Contract Summary

This is the complete surface Task 3.5 provides to its consumers:

| Provided by Task 3.5 | Called/read by |
|---|---|
| `QueueManager.register_slots(Array[Node3D])` — invoked in `TruckInterior._ready()` | `QueueManager._queue_slots` used in `_try_spawn()` and `_shuffle_queue()` |
| `NodePool.register_container($NodePoolContainer)` — invoked in `TruckInterior._ready()` | `NodePool._container` used in `checkout()` and `ret()` |
| `NodePool.prewarm_all()` — invoked in `TruckInterior._ready()` | All pooled scene paths in `PREWARM_CONFIG` |
| `CustomerNPC.set_queue_slot(int)` | `QueueManager._try_spawn()` — initial slot assignment |
| `CustomerNPC.move_to_slot(Vector3)` | `QueueManager._shuffle_queue()` — queue compaction |
| `CustomerNPC.queue_slot_index: int` | `QueueManager._release_customer()` — determines which slot to free |
| `CustomerNPC.reset()` clears slot/movement state | `NodePool._reset_node()` on every pool return |
| `Slot0–Slot2` `Marker3D` `global_position` (read-only) | `QueueManager._try_spawn()`, `QueueManager._shuffle_queue()` |

**Autoload order dependency:**
`QueueManager` must be registered **before** `TruckInterior._ready()` fires. This is guaranteed by the autoload order:

```
EventBus → GameManager → EconomyManager → NodePool → QueueManager → (COGITO autoloads)
```

The COGITO autoloads boot before the scene tree, so `QueueManager` is always available when `TruckInterior._ready()` runs.

---

## Section G — Smoke Test Checklist

Run after all sections complete:

- [ ] Open `TruckInterior.tscn` in editor; `QueueAnchors/Slot0/Slot1/Slot2` visible as gizmo markers in the 3D viewport, positioned outside the truck's left wall near positive-Z.
- [ ] Run scene (F6). Debug output shows `[NodePool] Pre-warmed N × <scene>` lines for each `PREWARM_CONFIG` entry — confirms `prewarm_all()` ran.
- [ ] Debug output shows `[QueueManager] registered 3 slots` (add a `print` guard in `register_slots()` behind `OS.is_debug_build()`).
- [ ] Remote tab in running session: `NodePoolContainer` is a child of `TruckInterior` and contains the prewarmed hidden nodes.
- [ ] Temporarily call `QueueManager.start_day(GameManager.get_day_config(1))` via `@tool` or Remote tab. After `spawn_interval` seconds, a `CustomerNPC` appears at `Slot2` global position (spawns at back of queue). Wait; if patience expires, `EventBus.customer_left` fires and customer is returned to pool.
- [ ] Spawn two customers (one at Slot2, one at Slot1). Release the Slot1 customer (force via Remote tab: `QueueManager._release_customer(active_customers[0])`). Confirm Slot2 customer slides to Slot1 position at 2 m/s.
- [ ] No `push_error` or `push_warning` in the output after the boot sequence.

---

## Edge Cases

| Case | Behaviour |
|---|---|
| `TruckInterior.gd` attached but `QueueAnchors` node missing | `@onready` assignment fails; editor shows a red error on the `@onready` line. Fix by adding the node in the editor. |
| `register_slots` called before `QueueManager` is registered as autoload | Crashes with `Identifier 'QueueManager' not declared`. Fix: ensure autoload order in `project.godot`. |
| `prewarm_all()` called before `register_container()` | NodePool falls back to parenting prewarmed nodes to the autoload itself (safe, but leaves nodes in the wrong subtree). Always call `register_container` first. |
| `_shuffle_queue` called when `_queue_slots` is empty (slot anchors missing) | Inner `is_instance_valid(_queue_slots[i])` check prevents crash; `move_to_slot` is never called. |
| Customer `move_to_slot` called while already `_is_moving` | Overwrites `_target_position` to the newer destination — correct behaviour for a mid-slide re-shuffle. |
| `cogito_scene.gd` upstream update changes `_enter_tree` signature | TruckInterior.gd inherits the update automatically; only breaking change is if the file is moved. Pin the addon version to avoid this. |
