## NodePool.gd
## Object pool for all runtime-spawned nodes in Midnight Munch.
##
## ARCHITECTURE RULE: queue_free() is BANNED during gameplay.
##   - At scene load: _prewarm() instantiates all required nodes and hides them.
##   - During gameplay: checkout() retrieves a hidden node and makes it live.
##   - When done: ret() hides the node and resets its state for reuse.
##
## WHY: WASM/web builds cannot tolerate GC spikes from runtime instantiation.
##   Pre-warming amortises all allocation cost to scene load, giving us
##   a flat memory profile during the 5-minute service window.
##
## USAGE:
##   var taco := NodePool.checkout("res://_src/entities/food/TortillaItem.tscn")
##   # ... use taco ...
##   NodePool.ret(taco)
##
## Registered in: Project Settings > Autoloads > NodePool
## Path: res://_src/autoloads/NodePool.gd

extends Node

# ─────────────────────────────────────────────────────────────────────────────
# CONSTANTS — Pre-warm counts (tuned to GDD max simultaneous instances)
# ─────────────────────────────────────────────────────────────────────────────

## Scene paths and their pre-warm counts.
## Adjust counts here if profiling shows pool exhaustion warnings.
const PREWARM_CONFIG: Dictionary = {
	"res://_src/entities/food/TacoBase.tscn":      3,   # Max 1 active; headroom for hand-off
	"res://_src/entities/food/TortillaItem.tscn":  10,  # Max ~3 active; headroom for holds
	"res://_src/entities/food/MeatPortion.tscn":   20,  # High churn — each order reuses
	"res://_src/entities/food/ToppingItem.tscn":   15,  # × 3 topping types, can drop
	"res://_src/entities/food/SauceStream.tscn":   50,  # Particle bursts; high count
	"res://_src/entities/customer/Customer.tscn":   5,  # Max 3 concurrent + 2 transitioning
}

## Target total pooled node count. Log a warning if we exceed this.
## GDD budget: ~125 nodes total well within WASM heap.
const MAX_POOL_NODE_TARGET: int = 150

# ─────────────────────────────────────────────────────────────────────────────
# STATE
# ─────────────────────────────────────────────────────────────────────────────

## Master pool dictionary.
## Key: scene path (String)  →  Value: Array of all pooled nodes (both active and idle)
var _pools: Dictionary = {}

## Reference to the NodePoolContainer node in the active scene.
## Set by the scene that contains this container (TruckInterior).
## The pool still works without it (nodes are added to the autoload), but
## keeping them in a dedicated container makes the scene tree cleaner.
var _container: Node = null

# ─────────────────────────────────────────────────────────────────────────────
# LIFECYCLE
# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Pre-warming happens when the gameplay scene loads, not at autoload init.
	# Call register_container() + prewarm_all() from TruckInterior._ready().
	pass


# ─────────────────────────────────────────────────────────────────────────────
# PUBLIC API
# ─────────────────────────────────────────────────────────────────────────────

## Register the scene-level NodePoolContainer so pooled nodes have a clean parent.
## Call this from TruckInterior._ready() BEFORE calling prewarm_all().
func register_container(container: Node) -> void:
	_container = container


## Pre-warm all pools defined in PREWARM_CONFIG.
## Call this from TruckInterior._ready() after register_container().
func prewarm_all() -> void:
	for scene_path: String in PREWARM_CONFIG.keys():
		_prewarm(scene_path, PREWARM_CONFIG[scene_path])

	_log_pool_status()


## Retrieve an idle node from the pool for gameplay use.
## Returns null and logs an error if the pool is empty (should not happen in production).
##
## The returned node is:
##   - Made visible (show())
##   - Re-parented to the scene root if it has no scene parent
##   - NOT reset — the caller is responsible for configuring state before use
func checkout(scene_path: String) -> Node:
	if not _pools.has(scene_path):
		push_error("[NodePool] checkout() called for unregistered scene: '%s'" % scene_path)
		return null

	var pool: Array = _pools[scene_path]

	# Find first hidden (idle) node in the pool.
	for node: Node in pool:
		if not node.visible:
			node.show()
			return node

	# ── POOL EXHAUSTED ────────────────────────────────────────────────────────
	# This should never happen in production if PREWARM_CONFIG counts are correct.
	# We do NOT return null and crash; instead, instantiate a fresh node with a warning.
	# This keeps the game running while signalling to the dev that counts need tuning.
	push_warning("[NodePool] Pool exhausted for '%s'. Instantiating extra node. " \
		+ "Increase PREWARM_CONFIG count for this scene." % scene_path)
	return _instantiate_and_add(scene_path)


## Return a node to the pool when it is no longer needed.
## The node is:
##   - Hidden (hide())
##   - Re-parented to _container (or the autoload if no container)
##   - State is reset via _reset_node() — caller should NOT access after calling ret()
func ret(node: Node) -> void:
	if node == null:
		push_warning("[NodePool] ret() called with null node.")
		return

	# Ensure node belongs to a pool. If not, just hide it and warn.
	var found: bool = false
	for scene_path: String in _pools.keys():
		if _pools[scene_path].has(node):
			found = true
			break

	if not found:
		push_warning("[NodePool] ret() called with a node not in any pool. Node: %s" % node.name)
		node.hide()
		return

	_reset_node(node)
	node.hide()

	# Re-parent to container to keep scene tree clean.
	var target_parent: Node = _container if _container else self
	if node.get_parent() != target_parent:
		node.reparent(target_parent)

# ─────────────────────────────────────────────────────────────────────────────
# PRIVATE HELPERS
# ─────────────────────────────────────────────────────────────────────────────

## Instantiate `count` nodes from `scene_path` and add them to the pool hidden.
func _prewarm(scene_path: String, count: int) -> void:
	if not ResourceLoader.exists(scene_path):
		push_warning("[NodePool] _prewarm() skipped — scene not found: '%s'" % scene_path)
		return

	if not _pools.has(scene_path):
		_pools[scene_path] = []

	var packed: PackedScene = ResourceLoader.load(scene_path)
	if not packed:
		push_error("[NodePool] Failed to load PackedScene: '%s'" % scene_path)
		return

	var parent: Node = _container if _container else self

	for i: int in range(count):
		var node: Node = packed.instantiate()
		node.hide()
		parent.add_child(node)
		_pools[scene_path].append(node)

	if OS.is_debug_build():
		print("[NodePool] Pre-warmed %d × '%s'" % [count, scene_path.get_file()])


## Instantiate a single node outside of the prewarm phase (emergency overflow).
func _instantiate_and_add(scene_path: String) -> Node:
	var packed: PackedScene = ResourceLoader.load(scene_path)
	if not packed:
		push_error("[NodePool] Cannot instantiate overflow node — scene failed to load: '%s'" % scene_path)
		return null

	var node: Node = packed.instantiate()
	var parent: Node = _container if _container else self
	parent.add_child(node)
	_pools[scene_path].append(node)
	node.show()
	return node


## Reset node state on return. Handles known node types.
## Add explicit reset paths here as new poolable types are created.
func _reset_node(node: Node) -> void:
	# GPUParticles3D sauce streams — disable emission to avoid orphan particles.
	if node is GPUParticles3D:
		node.emitting = false

	# RigidBody3D toppings — unfreeze so physics re-activates on next checkout.
	if node is RigidBody3D:
		node.freeze = false
		node.linear_velocity = Vector3.ZERO
		node.angular_velocity = Vector3.ZERO

	# Generic reset: clear any groups or metadata set during gameplay.
	# Node-specific reset logic should be in a reset() method on the node script.
	if node.has_method("reset"):
		node.reset()


## Print pool status to the console for debugging.
func _log_pool_status() -> void:
	if not OS.is_debug_build():
		return

	var total: int = 0
	print("─────────────────────────────────")
	print("[NodePool] Pool status after prewarm:")
	for scene_path: String in _pools.keys():
		var count: int = _pools[scene_path].size()
		total += count
		print("  %-50s %d nodes" % [scene_path.get_file(), count])
	print("  TOTAL: %d nodes (target ≤ %d)" % [total, MAX_POOL_NODE_TARGET])
	if total > MAX_POOL_NODE_TARGET:
		push_warning("[NodePool] Pool size %d exceeds target %d. Review PREWARM_CONFIG." % [total, MAX_POOL_NODE_TARGET])
	print("─────────────────────────────────")
