# Task 1.3 — InteractionStateMachine Skeleton + Station Visual Colors
## Implementation Plan

**Engine:** Godot 4.6 | **GDScript Only** | **Branch:** feature-task-03
**Relates to:** TechnicalImplementationPlan_Part1.md §3.2, §3.3

---

## 1. State Machine Design

The `InteractionStateMachine` owns all interaction input context for the player. Movement (WASD) runs independently in `TruckPlayer.gd` and does not interrupt any active interaction state.

### States

| State   | Meaning                                                                 |
|---------|-------------------------------------------------------------------------|
| IDLE    | No station in raycast. Crosshair: small dot.                           |
| HOVER   | Raycast hits a TruckStation. Prompt visible. Crosshair: large ring.    |
| ACTIVE  | Player pressed mm_interact. Transitioning into a primitive.            |
| MASH    | Dispatched for TrompoStation. Player button-mashes to fill a bar.      |
| HOLD    | Dispatched for SauceStation. Player holds to fill a vertical gauge.    |
| TIMING  | Dispatched for ToppingStation. Shrinking circle; click in target band. |

INSTANT (TortillaStation, BellStation) completes in one physics tick — there is no separate INSTANT state; the machine resolves from HOVER directly to IDLE via `_complete_interaction()`.

### GDD Primitive Mapping

| GDD Primitive | ISM State | Station(s)                       |
|---------------|-----------|----------------------------------|
| Click         | (none — INSTANT resolves immediately) | TortillaStation, BellStation |
| Mash          | MASH      | TrompoStation                    |
| Hold          | HOLD      | SauceStation (Red + White)       |
| Timing        | TIMING    | ToppingStation (Cilantro/Tomato/Onion) |

---

## 2. State Transition Diagram

```
                +--------+
        ────►   │  IDLE  │  ◄─────────────────────────────────────────────┐
                +--------+                                                  │
                    │ raycast hits TruckStation                             │
                    ▼                                                       │
                +--------+                                                  │
                │ HOVER  │ ──── raycast misses ──────────────────────────► │
                +--------+                                                  │
                    │ mm_interact pressed                                   │
                    ▼                                                       │
                +--------+                                                  │
                │ ACTIVE │ (reads station.interaction_type)                 │
                +----+---+                                                  │
                     │                                                      │
          ┌──────────┼────────────────────────┐                            │
          │          │                        │                             │
          ▼          ▼                        ▼                             │
      +------+   +------+               +--------+                         │
      │ MASH │   │ HOLD │               │ TIMING │                         │
      +--+---+   +--+---+               +---+----+                         │
         │          │                       │                               │
         │ mash_    │ mm_interact           │ mm_interact                  │
         │ progress │ released              │ pressed                      │
         │ >= 1.0   │                       │                               │
         │          ▼                       ▼                               │
         │    _evaluate_hold()       _evaluate_timing()                    │
         │          │                       │                               │
         └──────────┴────── _complete_interaction() / _on_timing_miss() ──►│
                                                                            │
         INSTANT stations: ACTIVE ──► _complete_interaction() ────────────►│
```

**Cancel path:** Any active state + action cancelled = IDLE.
**Miss path:** timing_radius <= 0 in TIMING = `_on_timing_miss()` = IDLE.

---

## 3. File List

### New Files (this task)

| File | Role |
|------|------|
| `_src/interactables/base/TruckStation.gd` | Base class for all stations. Enum, signals, virtual callbacks. No interaction logic. |
| `_src/player/InteractionStateMachine.gd` | Owns all input context. Casts ray, manages states, calls station callbacks, emits HUD signals. |
| `_src/interactables/SauceStation.gd` | Extends TruckStation. Sets CSG cylinder color at _ready() via @export var sauce_color. |
| `_src/interactables/ToppingStation.gd` | Extends TruckStation. Sets CSG box color at _ready() via @export var topping_color. |

### Modified Files (this task)

| File | What changes |
|------|--------------|
| `_src/interactables/SauceStation.tscn` | Add script reference to SauceStation.gd; update StandardMaterial3D albedo_color to white-sauce default (0.95, 0.95, 0.90). |
| `_src/interactables/ToppingStation.tscn` | Add script reference to ToppingStation.gd; existing green color is correct cilantro default — no color change needed. |

### Future Tasks (not this task)

| File | When |
|------|------|
| `_src/player/TruckPlayer.tscn` | Task 1.4 — wire RayCast3D export on InteractionStateMachine node |
| `_src/ui/SauceGauge.tscn` | Task 1.7 — connects to hold_progress_changed signal |
| `_src/ui/ShrinkingCircle.tscn` | Task 1.4 spike — connects to timing_radius_changed signal |
| `_src/ui/MashProgressBar.tscn` | Task 1.6 — connects to mash_progress_changed signal |
| `_src/interactables/TrompoStation.gd` | Task 1.6 |
| `_src/interactables/TortillaStation.gd` | Task 1.5 |
| `_src/interactables/BellStation.gd` | Task 2.7 |

---

## 4. Station Color Palette

All colors are set at `_ready()` by the station's GDScript by modifying the CSG mesh's `surface_material_override[0]`. Colors below are authoritative.

| Station | Node in Scene | CSG Type | Color (r, g, b, a) | Hex Approx |
|---------|---------------|----------|--------------------|------------|
| RedSauceStation | `CSGWhiteSauce` (reused cylinder) | CSGCylinder3D | `Color(0.85, 0.12, 0.12, 1)` | `#D91F1F` |
| WhiteSauceStation | `CSGWhiteSauce` | CSGCylinder3D | `Color(0.95, 0.95, 0.90, 1)` | `#F2F2E5` |
| CilantroStation | `CSGCilantro` | CSGBox3D | `Color(0.18, 0.65, 0.22, 1)` | `#2EA638` |
| TomatoStation | `CSGCilantro` (reused box) | CSGBox3D | `Color(0.90, 0.22, 0.10, 1)` | `#E5381A` |
| OnionStation | `CSGCilantro` (reused box) | CSGBox3D | `Color(0.92, 0.86, 0.78, 1)` | `#EBD9C7` |
| TortillaStation | `CSGTortilla` | CSGCylinder3D | `Color(0.93, 0.85, 0.65, 1)` | `#EDD9A6` — already set in .tscn |
| TrompoStation | `CSGMeat` | CSGCylinder3D | `Color(0.72, 0.22, 0.12, 1)` | `#B8381F` — override existing brown |
| BellStation | `Bell` | CSGCylinder3D | `Color(0.95, 0.82, 0.20, 1)` | `#F2D133` — already set in .tscn |

**Architecture note:** SauceStation.gd and ToppingStation.gd use `@export var sauce_color: Color` / `@export var topping_color: Color`. The TruckInterior.tscn instances (RedSauceStation, TomatoStation, etc.) override these exports in the scene inspector to set per-instance colors. This is the correct Godot pattern for instanced scene overrides — no tscn sub_resource manipulation needed.

**TrompoStation note:** The existing `.tscn` material (`Color(0.47, 0.33, 0.10)`) is a brownish color. TrompoStation.gd (Task 1.6) will override to the authoritative dark maroon. TortillaStation.gd (Task 1.5) will not need to change its existing tan color.

---

## 5. Crosshair Design

The `InteractionStateMachine` emits `crosshair_state_changed(state: String)` which the HUD listens to.

| Signal value | Visual | Meaning |
|--------------|--------|---------|
| `"idle"` | Small 4px dot, 50% opacity, white | No station nearby |
| `"hover"` | Ring 24px diameter, 100% opacity, white, 2px stroke | Station in range |
| `"active"` | Ring 24px diameter, 100% opacity, yellow (#F2D133), pulsing | Interaction in progress |

The HUD's crosshair `Control` node switches between three children (DotCrosshair, RingCrosshair, ActiveCrosshair) based on the signal value. No shader needed — use `TextureRect` or `ColorRect` with `draw_arc()` in a custom `Control._draw()`.

---

## 6. Signal Wiring Table

| Emitter | Signal | Receiver | Effect |
|---------|--------|----------|--------|
| `InteractionStateMachine` | `crosshair_state_changed(state)` | `GameHUD / Crosshair` | Switch crosshair visual |
| `InteractionStateMachine` | `hold_progress_changed(progress)` | `GameHUD / SauceGauge` | Update vertical bar fill |
| `InteractionStateMachine` | `mash_progress_changed(progress)` | `GameHUD / MashProgressBar` | Update radial bar fill |
| `InteractionStateMachine` | `timing_radius_changed(radius)` | `GameHUD / ShrinkingCircle` | Update ring radius |
| `TruckStation` (any) | `station_hovered(station)` | `InteractionStateMachine` | Currently unused — ISM already knows via raycast. Reserved for future prompt system. |
| `TruckStation` (any) | `station_unhovered(station)` | `InteractionStateMachine` | Same as above. |
| `TruckStation` (any) | `interaction_completed(station, result)` | `OrderManager` | Record ingredient quality |
| `InteractionStateMachine` | (calls EventBus directly) | `EventBus.order_step_completed` | Only after station callback confirmed |

**Rule:** `InteractionStateMachine` is the only node that calls station virtual methods (`on_interaction_start`, `on_interaction_tick`, `on_interaction_complete`). Stations never call back into the ISM.

---

## 7. Web-Safety Notes

| Rule | Reason |
|------|--------|
| All timing logic in `_physics_process(delta)` | Fixed timestep = deterministic shrink/fill across browser frame rates |
| No `await` in interaction handlers | `await` blocks until next frame; web tab switches cause the frame to be skipped, creating stuck states |
| No `yield` | Removed in Godot 4 — just confirming |
| `TIMING_SHRINK_SPEED = 220.0` | 30% slower than a "native feel" 310 px/s — accounts for web input latency |
| `TIMING_TARGET_MAX - TIMING_TARGET_MIN = 50.0 px` | 30% wider than a 35 px native window |
| Input events via `_unhandled_input` not `_input` | Prevents consuming UI events; avoids double-firing on web |
| `Input.is_action_just_pressed()` only inside `_unhandled_input` | Never poll in `_physics_process` — use event parameter instead |
| Mouse mode: `MOUSE_MODE_CAPTURED` only during PLAYING phase | Release on popups; web browsers block capture after tab switch |

---

## 8. Per-Instance Color Override Workflow (How to Set Colors in Editor)

After attaching `SauceStation.gd` and `ToppingStation.gd` to their scene roots:

1. Open `TruckInterior.tscn` in the Godot editor.
2. Select `RedSauceStation` instance in the scene tree.
3. In the Inspector, find `Sauce Color` export var.
4. Set to `Color(0.85, 0.12, 0.12, 1)`.
5. Repeat for `WhiteSauceStation` → `Color(0.95, 0.95, 0.90, 1)`.
6. Select `TomatoStation` → `Topping Color` → `Color(0.90, 0.22, 0.10, 1)`.
7. Select `OnionStation` → `Topping Color` → `Color(0.92, 0.86, 0.78, 1)`.
8. Select `CilantroStation` → `Topping Color` → `Color(0.18, 0.65, 0.22, 1)` (overrides the green default only if desired).

These values are saved as scene-instance property overrides in `TruckInterior.tscn` by the editor — no manual tscn editing required.
