# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**Midnight Munch** — a cozy first-person taco food truck simulator. Built on the **COGITO FPS framework** (v1.1, `addons/cogito/`). Target: web (WASM), GL Compatibility renderer, 60 FPS on a 2019 MacBook Air. GDScript only.

Main entry scene: `res://addons/cogito/DemoScenes/COGITO_0_MainMenu.tscn`  
Core gameplay scene: `res://_src/levels/TruckInterior.tscn`

## Running, Testing, and Linting

There is no CLI build step. Use the Godot editor or MCP godot tool directly.

**Run the project (MCP):**
```
mcp__godot__run_project
```

**Run tests via GUT:**  
Open `res://tests/.gutconfig.json` in the Godot editor → GUT panel → Run All.  
Test directories: `res://tests/unit/`, `res://tests/integration/`  
File prefix/suffix: `test_` prefix, `.gd` suffix.

**Lint (gdscript-linter addon):**  
`addons/gdscript-linter/` — invoke through the Godot editor plugin panel.

## Architecture

All custom game code lives under `_src/`. COGITO and other third-party plugins are in `addons/` and should not be modified.

### Autoloads (Global Managers)

| Autoload | Responsibility |
|---|---|
| `EventBus` | Pure signal bus — no state, no logic |
| `GameManager` | Game-phase FSM, day countdown timer, difficulty config |
| `EconomyManager` | Player balance, per-day stats, payment calculation |
| `NodePool` | Object pool for food items / customers (WASM GC safety) |
| `CogitoGlobals`, `CogitoSceneManager`, `CogitoQuestManager` | COGITO internals |

**Cross-system communication:** signal up through `EventBus`, call down within a subtree. No direct sibling-to-sibling method calls.

### Station Interaction Loop

```
Raycast (every _physics_process)
  → ISM.HOVER → player presses mm_interact
  → ISM.ACTIVE → branch on station.interaction_type:
      INSTANT | MASH (5 presses) | HOLD (fill gauge) | TIMING (shrinking circle)
  → station.on_interaction_complete(quality: int)
  → EventBus.order_step_completed.emit(ingredient_id, quality)
```

`InteractionStateMachine` lives on the player node (`_src/player/InteractionStateMachine.gd`). All station scripts extend `TruckStation` (`_src/interactables/base/TruckStation.gd`) and override virtual callbacks.

### Data / Configuration

All numeric tuning lives in `.tres` resource files loaded at runtime:
- `DayConfig` — patience, spawn interval, customer count, per-day overrides
- `EconomyConfig` — prices, tips, penalties, ingredient costs
- `RecipeData` — always/optional ingredients, max optional count

Fallback pattern when config is absent:
```gdscript
func _get_config_value(property: String, default_value: Variant) -> Variant:
    if config and config.get(property) != null:
        return config.get(property)
    return default_value  # GDD-specified fallback
```

### Object Pooling (WASM Constraint)

**Never call `queue_free()` on gameplay nodes.** Use `NodePool` instead:
- `NodePool.checkout(scene_path) -> Node` — retrieve a hidden, pre-warmed node
- `NodePool.ret(node)` — reset state and return to pool

`NodePool.prewarm_all()` is called by `TruckInterior` on load. Pool sizes: tortillas 10, meat 20, toppings 15, sauce streams 50, customers 5.

### Web-Tuned Interaction Constants

All ISM timing uses `_physics_process`, never `await`/`yield`. Web-specific tuning:
- `TIMING_SHRINK_SPEED`: 220 px/s (30% slower than native 310 px/s)
- `TIMING_TARGET_MIN/MAX`: 80–130 px (30% wider than native 100 px)

Any future timing constants should follow the same 30% web-latency adjustment.

## COGITO Integration

COGITO provides: FPS player controller, interaction component system, inventory, menus (EasyMenus), scene transitions, localization. **Do not modify files under `addons/cogito/`.**

Extend COGITO behavior by:
- Subclassing COGITO's interaction components and attaching to station scenes
- Adding custom signals to `EventBus` rather than modifying COGITO signal flow
- Using `addons/cogito/PackedScenes/cogito_player.tscn` as the player scene (already instanced in `TruckInterior.tscn`)

COGITO docs: `documentation/Cogito_docs/`

## Conventions

- **Naming:** `PascalCase` classes, `snake_case` methods/vars, `ALL_CAPS` constants
- **Signals:** emit-only from the node that owns the state; connect in parent or EventBus
- **Logging:** wrap debug output in `if OS.is_debug_build()`; prefix errors with `[ClassName]`
- **Node validity:** use `is_instance_valid(node)` not `node != null`
- **GameManager** owns phases/timer. **EconomyManager** owns money. Neither drives the other directly.
- Progress values are always normalized 0.0–1.0 before leaving a station script.

## Key Input Actions

Custom actions defined in `project.godot`:
- `mm_interact` — station interaction (primary)
- `mm_mash` — mash-type station presses
- `forward/back/left/right`, `jump`, `crouch`, `sprint` — locomotion (COGITO)
