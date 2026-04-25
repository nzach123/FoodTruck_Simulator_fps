# Shrinking Circle Mechanic — Implementation Plan

**Feature:** Topping placement timing UI (TIMING interaction type)  
**Date:** April 2026  
**Status:** Approved

---

## What already exists (do not re-implement)

- `InteractionStateMachine.gd` — TIMING state fully implemented: `_tick_timing(delta)` shrinks `timing_radius` at 220 px/s, `_evaluate_timing()` checks the 80–130 px band, `_on_timing_miss()` debits $0.05, `timing_radius_changed(radius)` emits every physics tick
- `ToppingStation.gd` — `interaction_type = TIMING`, `on_interaction_complete(result)` emits `EventBus.order_step_completed`
- All constants live in ISM: `TIMING_START_RADIUS = 400`, `TIMING_TARGET_MIN = 80`, `TIMING_TARGET_MAX = 130`, `TIMING_SHRINK_SPEED = 220`

---

## Files to create

### 1. `_src/ui/ShrinkingCircle.gd`

A `Control` node that draws the timing UI entirely via `_draw()`. No textures, no shaders.

**Node requirements:**
- Anchors: full-rect (`ANCHOR_BEGIN` 0.0, `ANCHOR_END` 1.0 on all sides) so it fills the CanvasLayer
- `mouse_filter = MOUSE_FILTER_IGNORE` — must not consume `mm_interact` input events; ISM's `_unhandled_input` must still fire
- `visible = false` by default

**Export:**
```gdscript
@export var ism: InteractionStateMachine
```
Wired in TruckInterior.tscn inspector. No auto-discovery via path — explicit reference.

**Private state:**
```gdscript
var _current_radius: float = 0.0
```

**`_ready()`:**
Connect two ISM signals (guard with `is_instance_valid(ism)`):
- `ism.timing_radius_changed.connect(_on_radius_changed)`
- `ism.crosshair_state_changed.connect(_on_crosshair_changed)`

**`_on_radius_changed(radius: float)`:**
```gdscript
_current_radius = radius
visible = true
queue_redraw()
```

**`_on_crosshair_changed(crosshair_state: String)`:**
```gdscript
if crosshair_state == "idle" or crosshair_state == "hover":
    visible = false
    _current_radius = 0.0
```

**`_draw()`:**

Center point is `get_rect().size / 2.0`.

Draw two elements:

1. **Target band** (always drawn when visible — player sees the goal from frame 1):
   - `draw_arc(center, 105.0, 0, TAU, 64, Color(1, 1, 1, 0.25), 50.0, true)`
   - Mid radius 105.0 = (TIMING_TARGET_MIN + TIMING_TARGET_MAX) / 2 = (80 + 130) / 2
   - Width 50.0 = TIMING_TARGET_MAX - TIMING_TARGET_MIN = 130 - 80
   - Comment: `# mirrors ISM.TIMING_TARGET_MIN/MAX`

2. **Shrinking ring** (only drawn when `_current_radius > 0`):
   - `draw_arc(center, _current_radius, 0, TAU, 64, Color(1, 1, 1, 0.9), 4.0, true)`

---

### 2. `_src/ui/ShrinkingCircle.tscn`

Single-node scene:
```
ShrinkingCircle (Control, script = ShrinkingCircle.gd)
```
Anchors set to full-rect. No children required.

---

## Files to modify

### `_src/levels/TruckInterior.tscn`

Add two nodes as **local children** of the CogitoPlayer instance. Do not modify `cogito_player.tscn`.

```
CogitoPlayer  [instanced: cogito_player.tscn]
  └── MidnightMunchHUD  [CanvasLayer, layer = 2]
        └── ShrinkingCircle  [instanced: ShrinkingCircle.tscn]
```

- CanvasLayer `layer = 2` renders above COGITO's default layer 1 GUI
- Wire `ShrinkingCircle.ism` in the inspector to the `InteractionStateMachine` node under CogitoPlayer

---

## Signal wiring summary

```
ISM.timing_radius_changed   → ShrinkingCircle._on_radius_changed    (show + redraw)
ISM.crosshair_state_changed → ShrinkingCircle._on_crosshair_changed (hide on idle/hover)
```

Direct node-to-node connections in `_ready()`. ShrinkingCircle is a listener only — it never calls back into ISM or any station. No EventBus involvement.

---

## Explicitly out of scope

- Floor-drop physics prop (NodePool checkout on miss)
- Penalty ticker ("-$0.05" float text)
- Audio hooks on ToppingStation
- Crosshair changes during TIMING state
- Any changes to `addons/cogito/`
