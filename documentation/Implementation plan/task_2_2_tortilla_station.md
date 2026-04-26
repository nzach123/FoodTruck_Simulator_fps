# Task 2.2 — TortillaStation: INSTANT Spawns TacoBase

**Engine:** Godot 4.6 | **Phase:** 2 — Stations | **Predecessors:** Task 1.x station scaffold complete | **Successor handoff:** Phase 4 OrderManager listens for `tortilla_taken`

## Objective

Convert `TortillaStation.tscn` from a placeholder using COGITO's generic `cogito_object` + `BasicInteraction` into a working `INSTANT` station that:
1. Uses the project's `InteractionStateMachine` (not COGITO's interaction system).
2. Resolves a tortilla pickup on a single `mm_interact` press.
3. Emits `EventBus.tortilla_taken` so a future `OrderManager` can checkout a `TacoBase` from `NodePool` and parent it to the player's hand.

## Boundary With Phase 4

This task does NOT:
- Checkout `TacoBase` from `NodePool`.
- Parent any node to the player hand.
- Apply held-item logic in any other station.

The `OrderManager` (Phase 4) owns those responsibilities. Task 2.2 stops at the `tortilla_taken` emit.

---

## System Architecture

`TortillaStation` becomes the first concrete `INSTANT`-type subclass of `TruckStation`, overriding `on_interaction_complete()` to emit a new `EventBus.tortilla_taken` signal. The station does NOT touch `NodePool` directly — `TacoBase` checkout/parenting belongs to the future `OrderManager` (Phase 4) listening on that signal. The scene is repaired (collision layer 3, removal of conflicting COGITO `BasicInteraction`, correct `interact_action`) so the `InteractionStateMachine` raycast can walk from the `Hitbox` `StaticBody3D` up to the `TruckStation` root and dispatch `INSTANT` resolution on the first `mm_interact` press.

## File Roster

| Action | Path |
|---|---|
| `MODIFY` | `res://_src/interactables/TortillaStation.tscn` |
| `CREATE` | `res://_src/interactables/TortillaStation.gd` |
| `MODIFY` | `res://_src/autoloads/EventBus.gd` |
| `VERIFY ONLY` | `res://_src/entities/food/TacoBase.tscn` |
| `NO CHANGE` | `res://_src/autoloads/NodePool.gd` (PREWARM_CONFIG already has TacoBase × 3) |

## Signal Contract

- `TortillaStation.gd` → `interaction_completed(station: TruckStation, result: Dictionary)` — inherited from `TruckStation`; reserved listener: future `OrderManager`
- `TortillaStation.gd` → `EventBus.tortilla_taken()` — consumed by `OrderManager` in Phase 4
- `EventBus.order_step_completed` — **NOT** emitted by tortilla; tortilla is the taco base, not a recipe step
- `InteractionStateMachine.station_focus_entered(station: TruckStation)` — drives HUD prompt (reused, no change)

---

## Section A — `EventBus.gd` Modification

**File:** `res://_src/autoloads/EventBus.gd`

### A.1 — Add new signal

Insert directly after `signal order_rejected(food_cost: float)`, inside the `ORDER LIFECYCLE SIGNALS` block, using the file's existing `##` docstring style:

```gdscript
## Emitted by TortillaStation when the player INSTANT-interacts to pick up a tortilla.
## Listener: OrderManager (Phase 4) → checkout TacoBase from NodePool, parent to player hand.
signal tortilla_taken()
```

**Verification:** Save the file. Confirm the GDScript editor reports zero parse errors. Open the project and confirm the autoload still loads without error.

---

## Section B — `TacoBase.tscn` Verification (NO EDIT)

**File:** `res://_src/entities/food/TacoBase.tscn`

The scene already exists. Open it and confirm:

- Root node type: `Node3D`, name `TacoBase`.
- Script attached: `res://_src/entities/food/TacoBase.gd`.
- Child node: `Mesh` (`MeshInstance3D`) with a `CylinderMesh` sub-resource (low-poly tortilla disc proportions).
- Scene path resolves — `NodePool.PREWARM_CONFIG` must match this exact path.

If any of the above is missing, halt and resolve before continuing. `NodePool.prewarm_all()` will silently skip a missing scene path with a `push_warning`, which will block Phase 4.

**Pool requirement:** `NodePool.PREWARM_CONFIG` already contains `"res://_src/entities/food/TacoBase.tscn": 3`. No change required.

---

## Section C — `TortillaStation.tscn` Scene Repair

**File:** `res://_src/interactables/TortillaStation.tscn`

### C.1 — Detach the wrong root script

Open the scene in the Godot editor. Select the root node `TortillaStation`. The script slot currently holds `res://_src/interactables/base/TruckStation.gd` (the base class). After Section D produces the subclass script, replace this with `res://_src/interactables/TortillaStation.gd`.

### C.2 — Fix `interact_action` on root

In the Inspector for the root `TortillaStation` node:

| Property | Current value | New value |
|---|---|---|
| `interact_action` | `&"interact2"` | `&"interact"` |
| `interaction_type` | (default INSTANT) | `INSTANT` (confirm) |
| `display_name` | `"Tortilla Station"` | unchanged |
| `interaction_prompt_text` | `"Take Tortilla"` | unchanged |
| `requires_held_item` | `false` | `false` (confirmed) |

**Important:** Verify the exact action name against Project Settings → Input Map before saving. The ISM reads `active_station.interact_action` verbatim. If the project's action is `&"mm_interact"` rather than `&"interact"`, use that value. Check `SauceStation.tscn` or `ToppingStation.tscn` for the correct precedent.

### C.3 — Remove COGITO conflicts on `Hitbox`

The `Hitbox` node currently has a COGITO `cogito_object.gd` script and a `BasicInteraction` child. Both must be removed — COGITO's interaction system competes with the project's ISM and will consume the `interact` input event first.

Steps in the editor:

1. Select `TortillaStation/Hitbox` (`StaticBody3D`).
2. In the Inspector, right-click the Script field → **Clear**.
3. The `cogito_name` and `display_name` exported fields vanish once the script is cleared.
4. Select child node `TortillaStation/Hitbox/BasicInteraction`. Right-click → **Delete Node**.
5. Confirm `Hitbox` is now a plain `StaticBody3D` with only `CollisionShape3D` as a child.

### C.4 — Confirm `Hitbox` collision layer

In the Inspector for `Hitbox` (`StaticBody3D`):

| Property | Current value | Correct value | Note |
|---|---|---|---|
| `collision_layer` | `4` | `4` | Layer 3 in Godot = bit value `2^(3-1) = 4`. This is correct. |
| `collision_mask` | `0` | `0` | No incoming queries needed. |

**Verify:** Open Project Settings → Layer Names → 3D Physics → Layer 3 should be labelled `Stations`. If unlabelled, name it `Stations` for clarity. If the project places stations on a different bit number, set `Hitbox.collision_layer` to the matching bit value.

Also confirm: the player `RayCast3D` `collision_mask` contains the same layer. Check `addons/cogito/PackedScenes/cogito_player.tscn` → `InteractionRaycast.collision_mask`. This should have been verified in Task 1.1.

### C.5 — Confirm tree shape for ISM walk

`InteractionStateMachine._update_hover()` walks from the raycast collider up via `get_parent()` until it finds a `TruckStation`. The required tree is:

```
TortillaStation              (Node3D, script=TortillaStation.gd, extends TruckStation)
├── Hitbox                   (StaticBody3D, collision_layer=4, no script, no COGITO)
│   └── CollisionShape3D     (BoxShape3D)
├── InteractionPrompt        (Node3D — kept for future HUD anchor)
├── SnapZone                 (Area3D, collision_layer=8 — kept for future taco snap)
│   └── CollisionShape3D     (SphereShape3D)
└── CSGTortilla              (CSGCylinder3D — visual mesh)
```

Walk path: `CollisionShape3D` → `Hitbox` → `TortillaStation` (TruckStation match → stop). Two `get_parent()` hops. No restructuring needed.

### C.6 — Save the scene

After Section D produces the script, return here, set the root node script to `TortillaStation.gd`, and save. Confirm zero parse errors in the Output panel.

---

## Section D — Create `TortillaStation.gd`

**File (new):** `res://_src/interactables/TortillaStation.gd`

### D.1 — Header and class declaration

| Element | Requirement |
|---|---|
| Docstring | `##`-style block comment (6–10 lines) explaining: INSTANT tortilla pickup, ISM owns timing/input, this script emits `EventBus.tortilla_taken` and `interaction_completed`. Note the Phase 4 boundary explicitly. |
| Line 1 | `extends TruckStation` |
| Line 2 | `class_name TortillaStation` |

Follow the docstring style and section separator style of `SauceStation.gd` and `ToppingStation.gd`.

### D.2 — Exports

Single export:

| Export name | Type | Default | Purpose |
|---|---|---|---|
| `ingredient_id` | `String` | `"tortilla"` | Used by future analytics/save; not emitted via `order_step_completed` (tortilla is the base, not a step). |

Do not export `tortilla_color` — the visual is set via the embedded `StandardMaterial3D` sub-resource in the scene, not per-instance overrides.

### D.3 — `_ready()` override

Set interaction type at runtime to prevent misconfiguration:

| Step | Action |
|---|---|
| 1 | `interaction_type = InteractionType.INSTANT` |
| 2 | `interaction_prompt_text = "Take Tortilla"` |

Do NOT set `interact_action` here — leave it as an Inspector-set value so per-instance overrides remain possible.

### D.4 — Virtual override stubs

Define empty bodies for unused virtuals to match the sibling station pattern (filled by Task 6 for SFX and highlights):

| Function | Body | Note |
|---|---|---|
| `on_hover_enter() -> void` | `pass` | Reserved for highlight/SFX |
| `on_hover_exit() -> void` | `pass` | Reserved for highlight removal |
| `on_interaction_start() -> void` | `pass` | Reserved for pickup SFX |
| `on_interaction_tick(progress: float) -> void` | `pass` | Never called for INSTANT type |

### D.5 — `on_interaction_complete()` — the critical override

The ISM calls this with `result = IngredientState.State.PERFECT` (= `2`) for all INSTANT interactions.

Required behaviour:

1. Build a result `Dictionary` matching the `interaction_completed` signal contract on `TruckStation.gd`:
   - `"ingredient_id"` → `ingredient_id` (the export, defaults to `"tortilla"`)
   - `"quality"` → `result` (passed through; always `2` for INSTANT)
2. Emit `interaction_completed.emit(self, result_dict)` (inherited signal — preserves the sibling pattern and gives any local listener a complete payload).
3. Emit `EventBus.tortilla_taken.emit()` (zero arguments — Phase 4 `OrderManager` owns ingredient lookup; this signal is purely a "go" trigger).
4. **Do NOT** emit `EventBus.order_step_completed`. Tortilla is the taco base, not a recipe step. This is the intentional architectural difference from `SauceStation` and `ToppingStation`.
5. If `OS.is_debug_build()`: print `"[TortillaStation] Tortilla taken (quality=%d)" % result`.

### D.6 — Prohibited patterns

Do NOT include any of the following in this script:

| Prohibition | Reason |
|---|---|
| `NodePool.checkout(...)` | Phase 4 — OrderManager owns TacoBase lifecycle |
| Reparenting or positioning nodes | Phase 4 — hand attachment is OrderManager's job |
| `queue_free()` | Banned project-wide; use NodePool.ret() |
| `await`, `Timer`, `yield` | Banned project-wide; all timing via `_physics_process` |
| Direct call to `OrderManager` | Cross-system communication is signal-only via EventBus |
| `EventBus.order_step_completed.emit(...)` | Tortilla is the base, not a step |

### D.7 — Save

Save `TortillaStation.gd`. Confirm zero parse errors. Then perform Section C.6.

---

## Section E — Verification

### E.1 — Static checks (no run required)

1. Open `TortillaStation.tscn`. Confirm:
   - Root script path = `res://_src/interactables/TortillaStation.gd`.
   - `interact_action` matches the input action bound to `mm_interact` in `project.godot`.
   - `Hitbox` has no script and no `BasicInteraction` child.
   - `Hitbox.collision_layer == 4`, `collision_mask == 0`.
2. Open `EventBus.gd`. Confirm `signal tortilla_taken()` is present and the file parses cleanly.
3. Open `NodePool.gd`. Confirm `PREWARM_CONFIG` still contains the `TacoBase.tscn` line unchanged.

### E.2 — Editor parse check

In the Godot editor: **Project → Tools → Reload Current Project**. Watch the Output panel:
- No `Parse Error` lines.
- No `[NodePool] _prewarm() skipped — scene not found` warning for TacoBase.
- No `BasicInteraction` orphan warnings.

### E.3 — Smoke test in `TruckInterior.tscn`

1. Open `res://_src/levels/TruckInterior.tscn` and run with **F6**.
2. Walk to the tortilla station with WASD.
3. Hover crosshair over the tortilla mesh. Confirm:
   - HUD prompt label shows `"Take Tortilla"` (driven by `station_focus_entered` → HUD listener).
   - Crosshair changes to the `hover` variant.
4. Press `mm_interact`.
5. Expected console output (debug build):
   ```
   ISM: Raycast hitting: Hitbox
   ISM: Station focus entered: TortillaStation
   [TortillaStation] Tortilla taken (quality=2)
   ```
6. Confirm no error or warning lines appear.
7. Move crosshair off the station — crosshair should return to `idle`, ISM returns to `IDLE`.

### E.4 — Signal smoke test (temporary listener)

In `TruckInterior.gd`, add a temporary listener and remove it before committing:

| Step | Action |
|---|---|
| 1 | `EventBus.tortilla_taken.connect(_on_tortilla_taken_test)` in `_ready()` |
| 2 | `func _on_tortilla_taken_test() -> void: print("[TEST] tortilla_taken received")` |
| 3 | Run, interact with station. Confirm print appears exactly once per press. |
| 4 | Remove both lines before commit. |

### E.5 — Pool integrity check

In debug build, `TruckInterior._ready()` runs `NodePool.prewarm_all()` which should print:
```
[NodePool] Pre-warmed 3 × 'TacoBase.tscn'
```
If this line is absent, `TacoBase.tscn` failed to load and Phase 4 will be blocked. Resolve before declaring Task 2.2 complete.

### E.6 — Regression check

Briefly retest `SauceStation` and `ToppingStation` interactions. Confirm they still:
- Enter HOLD / TIMING states correctly.
- Emit `EventBus.order_step_completed` with correct `(ingredient_id, quality)` tuples.
- Produce no new warnings.

### E.7 — Done criteria

Task 2.2 is complete when **all** of the following are simultaneously true:

- [ ] `TortillaStation.gd` exists, `extends TruckStation`, declares `class_name TortillaStation`.
- [ ] `TortillaStation.tscn` root uses the new script; `interact_action` matches the project's mapped input.
- [ ] `Hitbox` has no COGITO script and no `BasicInteraction` child; `collision_layer = 4`.
- [ ] `EventBus.gd` declares `signal tortilla_taken()` exactly once.
- [ ] Pressing interact while hovering the tortilla station emits `tortilla_taken` on each press with no errors.
- [ ] `NodePool` pre-warms 3 × `TacoBase.tscn` at scene start without warnings.
- [ ] No regression in `SauceStation` / `ToppingStation` interactions.
- [ ] No `queue_free()`, `await`, `Timer`, or `yield` introduced anywhere in this task's files.

---

## Section F — Handoff Notes for Phase 4 (OrderManager)

When `OrderManager` is built (Task 4.1), its handler for `EventBus.tortilla_taken` will:

1. `var taco := NodePool.checkout("res://_src/entities/food/TacoBase.tscn")`
2. Reparent `taco` under the player's hand anchor node (a `Marker3D` parented under `Camera3D`).
3. Reset its local transform to the hand-mount offset.
4. Store the active taco reference for subsequent `order_step_completed` ingredient additions.

Nothing in Task 2.2 pre-empts those steps. The tortilla station is intentionally stateless — it announces the event and forgets.

---

## Reference File Paths

| Role | Absolute path |
|---|---|
| Scene to modify | `_src\interactables\TortillaStation.tscn` |
| Script to create | `_src\interactables\TortillaStation.gd` |
| EventBus to modify | `_src\autoloads\EventBus.gd` |
| TacoBase scene (verify) | `_src\entities\food\TacoBase.tscn` |
| TacoBase script (reference) | `_src\entities\food\TacoBase.gd` |
| NodePool (no change) | `_src\autoloads\NodePool.gd` |
| Base class (reference) | `_src\interactables\base\TruckStation.gd` |
| ISM (reference) | `_src\player\InteractionStateMachine.gd` |
| Sibling pattern | `_src\interactables\SauceStation.gd`, `ToppingStation.gd` |
