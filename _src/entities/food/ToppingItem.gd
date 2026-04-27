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
	# Pool keeps us hidden and frozen between checkouts; ignore time then.
	if not visible or freeze:
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
