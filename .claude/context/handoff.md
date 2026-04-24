# Handoff Notes — TASK-001: Project Bootstrap

**Date:** 2026-04-24
**Agent:** BUILDER
**Task:** Task 1.1 — Project Bootstrap (Implementation Plan Phase 1)

---

## What Was Implemented

### 4 Autoload Scripts (`_src/autoloads/`)

| File | Purpose |
|------|---------|
| `EventBus.gd` | All cross-system signals declared. Emit/connect pattern ready. |
| `GameManager.gd` | Day phase state machine, 5-min countdown, DifficultySchedule loader. |
| `EconomyManager.gd` | Balance, credit/debit, tip calc, food cost deduction, day stats. |
| `NodePool.gd` | Pre-warm + checkout + ret pattern. Container registration via `register_container()`. |

### 4 Resource Class Scripts (`_src/data/`)

| File | Purpose |
|------|---------|
| `difficulty/DayConfig.gd` | Per-day patience, spawn interval, max concurrent, topping toggle. |
| `recipes/RecipeData.gd` | Always/optional ingredient arrays; max optional count. |
| `upgrades/UpgradeData.gd` | ID, cost, description, modifier dict, one-time flag. |
| `economy/EconomyConfig.gd` | All GDD prices, tips, penalties, starting balance, ingredient costs. |

### `project.godot` Patches

1. **Autoloads registered:** `EventBus`, `GameManager`, `EconomyManager`, `NodePool` added after COGITO singletons.
2. **Input actions added:** `mm_interact` (LMB), `mm_mash` (LMB + F key).
3. **Physics layers updated:** Layer 2 renamed `Player`, Layer 3 = `Stations`, Layer 4 = `SnapZones`.

---

## Required Manual Steps (Next Person Opening the Editor)

> [!IMPORTANT]
> The `project.godot` changes register autoloads by **file path** (not UID).
> After opening Godot Editor for the first time after this commit:
> 1. Go to **Project → Project Settings → Autoloads**
> 2. Confirm all 4 MM autoloads appear and have no error icons.
> 3. If any show errors, delete and re-add them manually pointing to `_src/autoloads/`.

---

## What Is NOT Yet Done (Next Task)

- `DifficultySchedule.tres` — must be created in the editor using `DayConfig.gd` resource.
- `EconomyConfig.tres` — must be created in the editor using `EconomyConfig.gd` resource.
- `TruckInterior.tscn` — Task 1.2 (blockout scene).
- `InteractionStateMachine.gd` — Task 1.3.
- `TruckStation.gd` base class — Task 1.3.

---

## Known Issues / Watch Points

- `GameManager._load_difficulty_schedule()` expects a resource with a `days` property (Array[DayConfig]).
  The `DifficultySchedule.tres` resource type that wraps this array needs to be created.
  Consider a simple `DifficultySchedule.gd` resource with `@export var days: Array[DayConfig]`.
- `NodePool` pre-warms scene paths that do not exist yet. The pool will log warnings and skip gracefully.
  No crash — safe to run headlessly before food item scenes are created.
- Physics layer rename from `Interactables` → `Player`+`Stations`+`SnapZones` may cause
  the existing COGITO demo scenes to show layer warnings in the editor. These are cosmetic only;
  COGITO demo scenes are not used in Midnight Munch gameplay.
