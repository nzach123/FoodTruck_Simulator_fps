# Task 2.5 — ToppingStation: Drop Penalty & Floor Despawn

## Task Overview

When the player misses the TIMING band on a `ToppingStation`, the GDD calls for **two** simultaneous penalties: a small economy debit (already implemented in `ISM._on_timing_miss()`) and a **physical "dropped topping" prop** that falls onto the floor in front of the station to communicate the miss visually. After 10 seconds the dropped topping returns to the `NodePool` so the truck floor never accumulates clutter.

This task delivers the dropped-topping prop pipeline end-to-end:

1. **Create `ToppingItem.tscn` and `ToppingItem.gd`.** A small `RigidBody3D` with a `MeshInstance3D` and a `CollisionShape3D`. The script tracks a self-despawn timer in `_physics_process` (no `await`, no `Timer` node — both forbidden by project conventions).
2. **Wire `ISM._on_timing_miss()`** to checkout a `ToppingItem` from `NodePool`, position it just in front of the active station, and apply a small randomised central impulse so it tumbles convincingly.
3. **Confirm `NodePool.PREWARM_CONFIG`** already lists `res://_src/entities/food/ToppingItem.tscn` with count 15. No change needed there.
4. **Use `NodePool.ret(self)` for despawn** — never `queue_free()`. The pool's `_reset_node()` method already handles `RigidBody3D` reset (clears velocities, unfreezes), and our `reset()` method handles the timer. This double-coverage is intentional: the pool's generic reset survives changes to our script, and our `reset()` survives changes to the pool.

End-to-end behaviour after this task:
- Player presses `mm_interact` outside the green band on a topping → ISM calls `_on_timing_miss()`.
- `_on_timing_miss()` debits $0.05, checks out a `ToppingItem`, places it 0.4 m in front and 0.1 m above the station, applies a random impulse, and resets to HOVER.
- The topping tumbles, settles on the floor, lies there for 10 s, then is silently returned to the pool.
- 15 simultaneous drops are supported without GC pressure (matches `NodePool.PREWARM_CONFIG` count).

## Scene Architecture

New scene `res://_src/entities/food/ToppingItem.tscn`:

```
ToppingItem                       [RigidBody3D]       (script: ToppingItem.gd)
                                                      collision_layer = 16   (layer "Pickups")
                                                      collision_mask  = 1    (world geometry only)
                                                      mass            = 0.05
                                                      gravity_scale   = 1.0
                                                      can_sleep       = true
├── MeshInstance3D                [MeshInstance3D]    SphereMesh radius 0.025, height 0.05
│                                                     surface_material_override = green StandardMaterial3D
│                                                     (cilantro green: Color(0.18, 0.65, 0.22, 1))
└── CollisionShape3D              [CollisionShape3D]  SphereShape3D radius 0.03
```

Save under `res://_src/entities/food/ToppingItem.tscn`. The path MUST exactly match the entry already present in `NodePool.PREWARM_CONFIG` (`"res://_src/entities/food/ToppingItem.tscn": 15`).

The scene is reparented into `NodePoolContainer` at scene-load by `NodePool.prewarm_all()` — do not place an instance directly in `TruckInterior.tscn`.

## COGITO Integration

- No COGITO interaction component on `ToppingItem` — it is a passive prop, not an interactable. The player cannot pick up dropped toppings.
- Object lifetime is governed exclusively by `NodePool` (`res://_src/autoloads/NodePool.gd`). `queue_free()` is never called.
- The despawn timer runs in `ToppingItem._physics_process(delta)` consistent with the project rule "all timing in `_physics_process`, never `await`".
- The ISM already has a downward call permission to `EconomyManager`; it is the only autoload-to-autoload call permitted in `_on_timing_miss()`. The new `NodePool.checkout()` call is also a downward call (player-domain → utility autoload), which is allowed by the architecture rules.
- No new EventBus signal is needed. The drop is purely cosmetic and self-contained.

## Implementation Steps

1. **Author `res://_src/entities/food/ToppingItem.gd`** with the script in *Code Implementation* below.
2. **Build `res://_src/entities/food/ToppingItem.tscn`** in the editor with the node tree above. Attach `ToppingItem.gd` to the root.
3. **Verify pool registration.** Open `res://_src/autoloads/NodePool.gd` and confirm `"res://_src/entities/food/ToppingItem.tscn": 15` is present in `PREWARM_CONFIG` (it already is).
4. **Update `InteractionStateMachine.gd._on_timing_miss()`** to spawn the dropped topping. Replace the existing method body with the version in *Code Implementation*. The economy debit logic is preserved.
5. **Add a private helper `_spawn_dropped_topping()`** to ISM that contains the checkout / position / impulse logic. Keeping it private and below `_on_timing_miss()` keeps `_on_timing_miss()` readable.
6. **Smoke test.** Enter `TruckInterior.tscn`, walk to the cilantro topping, press `mm_interact` outside the green band, verify (a) the gauge resets, (b) `EconomyManager.balance` drops by $0.05, (c) a small green sphere falls to the floor, (d) it disappears 10 seconds later.
7. **Stress test.** Trigger 16 misses rapidly. The 16th will log `[NodePool] Pool exhausted` and instantiate an overflow node — this is acceptable but indicates the production-tuned 15 count is correct because intentional overuse is rare.

## Code Implementation

### `res://_src/entities/food/ToppingItem.gd` — new file

```gdscript
## ToppingItem.gd
## Dropped-topping floor prop. Spawned by InteractionStateMachine on TIMING miss.
##
## LIFETIME:
##   Created at scene-load by NodePool.prewarm_all (count 15).
##   checkout()  → ISM places it, applies impulse, physics tumbles it.
##   _physics_process counts up _timer; at DESPAWN_AFTER seconds it returns
##   itself to the pool via NodePool.ret(self).
##
## RULES:
##   - No queue_free anywhere.
##   - No await / yield / Timer node — despawn lives in _physics_process.
##   - reset() is called by NodePool._reset_node when the node is returned
##     so the next checkout starts cleanly.
##
## Path: res://_src/entities/food/ToppingItem.gd

class_name ToppingItem
extends RigidBody3D

# ─────────────────────────────────────────────────────────────────────────────
# CONSTANTS
# ─────────────────────────────────────────────────────────────────────────────

## Seconds the dropped topping remains visible on the floor before despawning.
const DESPAWN_AFTER: float = 10.0

# ─────────────────────────────────────────────────────────────────────────────
# STATE
# ─────────────────────────────────────────────────────────────────────────────

## Accumulated visible-time. Resets to 0 every checkout (via reset()).
var _timer: float = 0.0

# ─────────────────────────────────────────────────────────────────────────────
# LIFECYCLE
# ─────────────────────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	# Pool keeps us hidden between checkouts; ignore time while invisible.
	if not visible:
		return

	_timer += delta
	if _timer < DESPAWN_AFTER:
		return

	# Despawn: hand ourselves back to the pool. Do NOT queue_free.
	NodePool.ret(self)

# ─────────────────────────────────────────────────────────────────────────────
# POOL CONTRACT
# ─────────────────────────────────────────────────────────────────────────────

## Called by NodePool._reset_node when this node is returned.
## Must leave the node in a state where the next checkout can use it
## without manual cleanup.
func reset() -> void:
	freeze = false
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	sleeping = false
	_timer = 0.0
```

### `res://_src/player/InteractionStateMachine.gd` — modifications

Replace the existing `_on_timing_miss()` method and add the new `_spawn_dropped_topping()` helper immediately below it. These are COMPLETE method replacements/additions:

```gdscript
# ─────────────────────────────────────────────────────────────────────────────
# TIMING MISS — debit $0.05, drop a topping, return to HOVER for retry.
# ─────────────────────────────────────────────────────────────────────────────

func _on_timing_miss() -> void:
	# GDD: -$0.05 penalty on miss. EconomyManager is a downward call from ISM,
	# allowed by the architecture rules.
	if is_instance_valid(EconomyManager):
		EconomyManager.debit(0.05, "timing_miss")

	# Spawn the dropped-topping floor prop in front of the active station.
	# Must happen BEFORE _reset_to_hover, while active_station is still valid.
	_spawn_dropped_topping()

	_reset_to_hover()


## Checkout a ToppingItem from NodePool, position it just in front of the
## active station, and apply a small randomised impulse so the topping
## tumbles convincingly. Idempotent against missing pool / inactive station.
func _spawn_dropped_topping() -> void:
	if not is_instance_valid(active_station):
		return

	var topping_path: String = "res://_src/entities/food/ToppingItem.tscn"
	var topping: Node = NodePool.checkout(topping_path)
	if not is_instance_valid(topping):
		push_warning("[ISM] _spawn_dropped_topping(): NodePool.checkout returned null.")
		return

	# Cast and validate. ToppingItem is a RigidBody3D subclass.
	var body: RigidBody3D = topping as RigidBody3D
	if body == null:
		push_warning("[ISM] Pooled ToppingItem is not a RigidBody3D.")
		return

	# Position in front of the station: 0.4 m forward (station-local -Z),
	# 0.1 m up, slight random horizontal jitter so repeats do not stack.
	var station_xform: Transform3D = active_station.global_transform
	var jitter: Vector3 = Vector3(
		randf_range(-0.08, 0.08),
		0.10,
		-0.40 + randf_range(-0.05, 0.05)
	)
	var spawn_pos: Vector3 = station_xform.origin + station_xform.basis * jitter

	# Reparent to the scene root so physics simulation is uninhibited by the
	# station's hidden NodePool container. NodePool will reparent on return.
	var scene_root: Node = get_tree().current_scene
	if is_instance_valid(scene_root) and body.get_parent() != scene_root:
		body.reparent(scene_root)

	# Apply position FIRST, THEN unfreeze and impulse — set_global_transform
	# must occur before any forces are applied this frame.
	body.global_transform = Transform3D(Basis.IDENTITY, spawn_pos)
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.freeze = false
	body.sleeping = false

	# Small randomised toss so the drop feels organic, not gridded.
	var impulse: Vector3 = Vector3(
		randf_range(-0.6, 0.6),
		randf_range(0.4, 1.0),
		randf_range(-0.6, 0.6)
	)
	body.apply_central_impulse(impulse)

	if OS.is_debug_build():
		print("[ISM] Dropped topping spawned at %s (impulse %s)." % [spawn_pos, impulse])
```
