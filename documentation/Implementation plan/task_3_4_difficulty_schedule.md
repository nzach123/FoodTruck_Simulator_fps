# Task 3.4 — Day 1–7 Difficulty Schedule Resource

**Engine:** Godot 4.6 | **Phase:** 3 — Customer AI & Queue Logic | **Predecessors:** `DayConfig.gd` exists; Tasks 3.1–3.3 complete | **Successor handoff:** `GameManager._load_difficulty_schedule()` no longer warns

## Objective

Create the eight `DayConfig.tres` files (Day 0 tutorial through Day 7+) plus a `DifficultySchedule` resource type and the master `DifficultySchedule.tres` that aggregates them. Numeric values come from the GDD difficulty table.

## Boundary

This task is purely data-authoring. No script logic changes outside the new `DifficultySchedule.gd` resource class. `GameManager._load_difficulty_schedule()` already expects this exact path and shape (`days: Array[DayConfig]`).

---

## System Architecture

`DifficultySchedule` is a thin `Resource` wrapper exporting `Array[DayConfig]`. `GameManager` already loads it from a hardcoded path and reads the `days` property; this task supplies the missing `.tres` files and the schedule resource class. Each `DayConfig.tres` is a saved instance of the existing `DayConfig` script with values from the GDD.

## File Roster

| Action | Path |
|---|---|
| `CREATE` | `res://_src/data/difficulty/DifficultySchedule.gd` |
| `CREATE` | `res://_src/data/difficulty/Day0_Tutorial.tres` |
| `CREATE` | `res://_src/data/difficulty/Day1.tres` |
| `CREATE` | `res://_src/data/difficulty/Day2.tres` |
| `CREATE` | `res://_src/data/difficulty/Day3.tres` |
| `CREATE` | `res://_src/data/difficulty/Day4.tres` |
| `CREATE` | `res://_src/data/difficulty/Day5.tres` |
| `CREATE` | `res://_src/data/difficulty/Day6.tres` |
| `CREATE` | `res://_src/data/difficulty/Day7_Plus.tres` |
| `CREATE` | `res://_src/data/difficulty/DifficultySchedule.tres` |
| `NO CHANGE` | `res://_src/data/difficulty/DayConfig.gd` |
| `NO CHANGE` | `res://_src/autoloads/GameManager.gd` |

## Signal Contract

None. Pure resource authoring.

---

## Section A — Create `DifficultySchedule.gd`

**File:** `res://_src/data/difficulty/DifficultySchedule.gd`

### A.1 — Full script

```gdscript
## DifficultySchedule.gd
## Resource that aggregates DayConfig instances for the entire campaign.
##
## Indexed by day number: schedule.days[0] = Day 0 tutorial, schedule.days[7] = Day 7+.
## GameManager._load_difficulty_schedule() reads this and clamps day overflow
## to the last entry (so "Day 8" reuses Day 7's config).
##
## Path: res://_src/data/difficulty/DifficultySchedule.gd

class_name DifficultySchedule
extends Resource

## Ordered DayConfig list. Index 0 = Day 0 tutorial.
@export var days: Array[DayConfig] = []
```

### A.2 — Verify

Save. Editor reports zero parse errors. New Resource picker now lists `DifficultySchedule`.

---

## Section B — Create the eight `DayConfig.tres` Files `[EDITOR]`

For each day, the same procedure applies. Use the GDD values in the table.

### B.1 — GDD value table

| File | day | patience_seconds | spawn_interval | max_concurrent | mash_presses_required | allow_optional_ingredients |
|---|---|---|---|---|---|---|
| `Day0_Tutorial.tres` | 0 | 9999.0 | 999.0 | 1 | 0 | false |
| `Day1.tres`          | 1 | 60.0   | 45.0  | 2 | 0 | false |
| `Day2.tres`          | 2 | 55.0   | 40.0  | 2 | 0 | true  |
| `Day3.tres`          | 3 | 50.0   | 35.0  | 3 | 0 | true  |
| `Day4.tres`          | 4 | 45.0   | 30.0  | 3 | 0 | true  |
| `Day5.tres`          | 5 | 40.0   | 25.0  | 3 | 0 | true  |
| `Day6.tres`          | 6 | 35.0   | 22.0  | 3 | 0 | true  |
| `Day7_Plus.tres`     | 7 | 30.0   | 20.0  | 3 | 0 | true  |

`mash_presses_required = 0` keeps the ISM default (5 presses) until upgrades change it.

### B.2 — Editor steps for each file `[EDITOR]`

For **each row** in the table:

1. `[EDITOR]` In FileSystem dock, right-click `_src/data/difficulty/` → New Resource.
2. `[EDITOR]` In the dialog, type/search `DayConfig` → OK.
3. `[EDITOR]` Save dialog → name the file exactly as the table specifies (e.g. `Day0_Tutorial.tres`) → Save.
4. `[EDITOR]` Open the new resource (double-click). In the inspector, set every field per the table row.
5. `[EDITOR]` Save (Ctrl+S). Confirm the resource icon shows the new name in the FileSystem dock.

Repeat for all 8 rows.

### B.3 — Verify

After all 8 files are authored, the `_src/data/difficulty/` folder should contain:

```
DayConfig.gd
Day0_Tutorial.tres
Day1.tres
Day2.tres
Day3.tres
Day4.tres
Day5.tres
Day6.tres
Day7_Plus.tres
DifficultySchedule.gd
```

Open one (e.g. `Day3.tres`) and confirm: `day=3`, `patience_seconds=50.0`, `spawn_interval=35.0`, `max_concurrent=3`, `mash_presses_required=0`, `allow_optional_ingredients=true`.

---

## Section C — Create `DifficultySchedule.tres` `[EDITOR]`

### C.1 — Editor steps

1. `[EDITOR]` In FileSystem dock, right-click `_src/data/difficulty/` → New Resource.
2. `[EDITOR]` Type/search `DifficultySchedule` → OK.
3. `[EDITOR]` Save as exactly `DifficultySchedule.tres` (path must be `res://_src/data/difficulty/DifficultySchedule.tres` to match `GameManager.DIFFICULTY_SCHEDULE_PATH`).
4. `[EDITOR]` Open the resource. Inspector shows `Days: Array[DayConfig]` (empty).
5. `[EDITOR]` Click Days → Resize → 8.
6. `[EDITOR]` For each index 0–7, click the `<empty>` slot → Quick Load → choose the matching `.tres` file:
   - Index 0 → `Day0_Tutorial.tres`
   - Index 1 → `Day1.tres`
   - Index 2 → `Day2.tres`
   - Index 3 → `Day3.tres`
   - Index 4 → `Day4.tres`
   - Index 5 → `Day5.tres`
   - Index 6 → `Day6.tres`
   - Index 7 → `Day7_Plus.tres`
7. `[EDITOR]` Save (Ctrl+S).

### C.2 — Verify in editor

Re-open `DifficultySchedule.tres`. The Days array shows 8 sub-resources; expanding each must reveal the correct `day` value (0,1,2,3,4,5,6,7). No empty slots.

---

## Section D — Verify `GameManager` Loads the Schedule

### D.1 — Run the project

1. `[EDITOR]` Run the project (F5). The console must NOT print:
   ```
   [GameManager] DifficultySchedule.tres not found at '...'
   ```
   nor:
   ```
   [GameManager] DifficultySchedule.tres exists but has no 'days' property.
   ```
2. From the Remote scene tree, evaluate `GameManager._difficulty_schedule.size()` → expect `8`.
3. Evaluate `GameManager.get_day_config(3).patience_seconds` → expect `50.0`.
4. Evaluate `GameManager.get_day_config(99).day` → expect `7` (clamped to last entry).

---

## Edge Cases Covered

| Case | Behaviour |
|---|---|
| Player reaches Day 8+ (beyond schedule) | `GameManager.get_day_config()` clamps to last index (Day 7+ config). |
| `DifficultySchedule.tres` accidentally has empty days array | `GameManager` logs `[GameManager] Difficulty schedule is empty`; no crash. |
| Wrong `.tres` saved as `.res` (binary form) | Both formats load the same way; no behavioural change. |
| File path typo on schedule resource | `GameManager._load_difficulty_schedule` logs `not found` warning at boot; live customers never spawn until fixed. |
| `mash_presses_required` accidentally non-zero | ISM picks up the override (later Phase 6 upgrade hook); for Phase 3 keep 0. |
| Day 0 spawn_interval=999 | Tutorial day never auto-spawns; tutorial flow pushes customers manually via a future API. |
