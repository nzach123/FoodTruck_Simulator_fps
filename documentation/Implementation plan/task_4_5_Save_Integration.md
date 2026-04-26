# Task 4.5 — Save Integration via SaveManager

**Engine:** Godot 4.6 | **Phase:** 4 — Game Loop & Economy | **Predecessors:** Tasks 4.1–4.4; `GameManager` already calls `get_node_or_null("/root/SaveManager").call("save", ...)` defensively in `end_day()` (lines 126–128) | **Successor handoff:** Phase 5.4 MainMenu reads `SaveManager.has_save()` to gate the [Continue] button; `SaveManager.load_save()` provides the resume payload.

## Objective

Persist day stats and player progress to disk using a typed Resource wrapper (not a raw Dictionary) for WASM safety, with a fail-safe load-on-boot fallback. The save fires automatically at end-of-day before `EventBus.day_ended` propagates to the EndOfDayScreen, and on the [Save & Exit] button in Phase 5.3.

Responsibilities:
1. Define `SaveData` Resource with typed fields.
2. Implement `SaveManager` autoload with `save(data)`, `load_save() → Dictionary`, `has_save() → bool`, `build_save_dict() → Dictionary`.
3. Use `ResourceSaver.save()` / `ResourceLoader.load()` against `user://midnight_munch_save.tres` — never `ConfigFile` (binary path stability under WASM is better with Resources).
4. Restore `GameManager.current_day` and `EconomyManager.balance` on boot when [Continue] is chosen.
5. Defensively wipe partial saves if the schema version mismatches.

## Boundary

This task does NOT:
- Save station upgrades (Phase 5.4 / 6 — UpgradeManager is post-Phase-4).
- Save the live in-progress order or the current customer queue (intentional — saves only happen at end-of-day, between service windows).
- Implement the MainMenu [Continue] button itself (Phase 5.4).

It owns: `SaveData` Resource, `SaveManager.gd` autoload, the `save()` call site in `GameManager.end_day()` (already wired defensively; will become a typed call once SaveManager exists), and a unit test for round-trip integrity.

---

## System Architecture

`SaveData` is a typed `Resource` subclass with `@export var schema_version`, `@export var current_day`, `@export var balance`, and a flat `lifetime_stats` dictionary for forward-extensibility. `SaveManager` autoloads as the 7th custom autoload (after OrderManager). It exposes a synchronous API; both `save()` and `load_save()` use Godot's `ResourceSaver` / `ResourceLoader` which work identically on WASM (the Godot Web export uses IndexedDB-backed `user://` storage). Schema versioning lets us evolve the resource without nuking existing saves silently — on mismatch we log a warning and start fresh.

## File Roster

| Action | Path |
|---|---|
| `[CREATE]` | `res://_src/data/save/SaveData.gd` |
| `[CREATE]` | `res://_src/autoloads/SaveManager.gd` |
| `[MODIFY]` | `res://_src/autoloads/GameManager.gd` — replace defensive `get_node_or_null` save call with typed `SaveManager.save(SaveManager.build_save_dict())` |
| `[MODIFY]` | `project.godot` `[autoload]` — register `SaveManager` after `OrderManager` `[EDITOR]` |
| `[CREATE]` | `res://tests/unit/test_save_manager.gd` |

---

## Node Architecture

No scene tree. SaveManager is a non-visual autoload. `SaveData` lives only as a resource on disk and an in-memory instance during save/load.

## Signal Contract

No new signals are required for the core save flow — saves fire synchronously inside `GameManager.end_day()`. For Phase 5 the following may be added later (out of scope here): `save_completed`, `save_failed`. Today we use return values + push_warning for diagnostics.

## API Interface

```gdscript
# SaveManager — public autoload API
const SAVE_PATH: String = "user://midnight_munch_save.tres"
const SCHEMA_VERSION: int = 1

func save(data: Dictionary) -> bool
func load_save() -> Dictionary
func has_save() -> bool
func clear_save() -> void
func build_save_dict() -> Dictionary
```

```gdscript
# SaveData — typed Resource fields
@export var schema_version: int = 1
@export var current_day: int = 0
@export var balance: float = 0.0
@export var lifetime_stats: Dictionary = {}
```

---

## Section A — Create `SaveData.gd`

**File:** `res://_src/data/save/SaveData.gd`

```gdscript
## SaveData.gd
## Typed Resource wrapper for persisted game state.
##
## WHY a Resource (not Dictionary or ConfigFile):
##   - ResourceSaver/ResourceLoader work identically on WASM with IndexedDB backing.
##   - Typed fields catch schema drift at load time.
##   - schema_version field allows safe evolution without silent data loss.
##
## Path: res://_src/data/save/SaveData.gd

class_name SaveData
extends Resource

## Increment when adding/removing/renaming fields. SaveManager wipes the file
## if the on-disk version does not match SaveManager.SCHEMA_VERSION.
@export var schema_version: int = 1

## Day the player should resume on. 0 = tutorial, 1+ = live service.
@export var current_day: int = 0

## Player's bank balance at end of last completed day.
@export var balance: float = 0.0

## Lifetime tally — orders served, sloppy %, etc. Free-form dictionary
## so adding new metrics never breaks the schema.
@export var lifetime_stats: Dictionary = {}
```

---

## Section B — Create `SaveManager.gd`

**File:** `res://_src/autoloads/SaveManager.gd`

```gdscript
## SaveManager.gd
## Persists and restores game progress between sessions.
##
## CALL SITES:
##   - GameManager.end_day() → save(build_save_dict()) before day_ended emits.
##   - MainMenu [Continue]    → load_save() → restore day + balance.
##   - EndOfDayScreen [Save & Exit] → save(build_save_dict()) → quit_to_menu.
##
## STORAGE:
##   user://midnight_munch_save.tres  (IndexedDB-backed under WASM)
##
## SCHEMA EVOLUTION:
##   Bump SCHEMA_VERSION when fields change. On version mismatch we wipe
##   the file rather than risk loading partially-typed data.
##
## Registered in: Project Settings > Autoloads > SaveManager (after OrderManager).
## Path: res://_src/autoloads/SaveManager.gd

extends Node

# ─────────────────────────────────────────────────────────────────────────────
# CONSTANTS
# ─────────────────────────────────────────────────────────────────────────────

const SAVE_PATH: String = "user://midnight_munch_save.tres"
const SCHEMA_VERSION: int = 1

# ─────────────────────────────────────────────────────────────────────────────
# PUBLIC API
# ─────────────────────────────────────────────────────────────────────────────

## Returns true if a save file exists on disk. Used by MainMenu to enable [Continue].
func has_save() -> bool:
    return FileAccess.file_exists(SAVE_PATH)


## Builds the canonical save Dictionary from current autoload state.
## Pulled out of save() so EndOfDayScreen can preview the payload.
func build_save_dict() -> Dictionary:
    var stats: Dictionary = {}
    if is_instance_valid(EconomyManager) and EconomyManager.has_method("tally_day"):
        stats = EconomyManager.tally_day()
    return {
        "schema_version": SCHEMA_VERSION,
        "current_day": GameManager.current_day,
        "balance": EconomyManager.balance,
        "lifetime_stats": stats,
    }


## Persist the provided Dictionary to disk via a typed SaveData resource.
## Returns true on success. Logs and returns false on any failure.
func save(data: Dictionary) -> bool:
    var sd: SaveData = SaveData.new()
    sd.schema_version = SCHEMA_VERSION
    sd.current_day = int(data.get("current_day", 0))
    sd.balance = float(data.get("balance", 0.0))
    sd.lifetime_stats = data.get("lifetime_stats", {})

    var err: int = ResourceSaver.save(sd, SAVE_PATH)
    if err != OK:
        push_error("[SaveManager] Save failed (err %d) at '%s'." % [err, SAVE_PATH])
        return false

    if OS.is_debug_build():
        print("[SaveManager] Saved day %d balance %.2f to %s"
            % [sd.current_day, sd.balance, SAVE_PATH])
    return true


## Loads the save file as a Dictionary. Returns an empty Dictionary on any
## failure (file missing, corrupt, schema mismatch). Caller checks emptiness.
func load_save() -> Dictionary:
    if not has_save():
        return {}

    var res: Resource = ResourceLoader.load(SAVE_PATH)
    if not (res is SaveData):
        push_warning("[SaveManager] Save file is not a SaveData resource. Wiping.")
        clear_save()
        return {}

    var sd: SaveData = res as SaveData
    if sd.schema_version != SCHEMA_VERSION:
        push_warning("[SaveManager] Save schema mismatch (file=%d, runtime=%d). Wiping."
            % [sd.schema_version, SCHEMA_VERSION])
        clear_save()
        return {}

    return {
        "schema_version": sd.schema_version,
        "current_day": sd.current_day,
        "balance": sd.balance,
        "lifetime_stats": sd.lifetime_stats,
    }


## Deletes the save file. Used on schema mismatch and on a future [New Game]
## that overrides an existing save.
func clear_save() -> void:
    if not has_save():
        return
    var dir: DirAccess = DirAccess.open("user://")
    if dir == null:
        push_error("[SaveManager] Cannot open user:// to clear save.")
        return
    var err: int = dir.remove(SAVE_PATH.get_file())
    if err != OK:
        push_error("[SaveManager] Failed to remove save (err %d)." % err)
    elif OS.is_debug_build():
        print("[SaveManager] Save cleared.")
```

---

## Section C — Wire `GameManager.end_day()`

**File:** `res://_src/autoloads/GameManager.gd`

Replace the defensive lookup (lines 126–128 of the current source):

```gdscript
# OLD — defensive lookup needed before SaveManager existed.
var save_mgr: Node = get_node_or_null("/root/SaveManager")
if save_mgr:
    save_mgr.call("save", save_mgr.call("build_save_dict"))
```

With the typed call:

```gdscript
# NEW — SaveManager is a guaranteed autoload after Task 4.5 lands.
SaveManager.save(SaveManager.build_save_dict())
```

The autoload registration order ensures `SaveManager` is initialised before any `end_day()` can fire.

---

## Section D — Round-Trip Integration Test

**File:** `res://tests/unit/test_save_manager.gd`

```gdscript
## test_save_manager.gd
## Locks the SaveManager round-trip and schema-version contract.
##
## NOTE: tests touch the real user:// save path. Each test wipes before/after
## so they remain order-independent.
##
## Run via GUT panel → Run All.
## Path: res://tests/unit/test_save_manager.gd

extends GutTest


func before_each() -> void:
    SaveManager.clear_save()


func after_each() -> void:
    SaveManager.clear_save()


# ─────────────────────────────────────────────────────────────────────────────
# CORE ROUND-TRIP
# ─────────────────────────────────────────────────────────────────────────────

func test_has_save_false_when_clean() -> void:
    assert_false(SaveManager.has_save(), "no save file should exist after clear")


func test_save_then_load_round_trip() -> void:
    var ok: bool = SaveManager.save({
        "current_day": 3,
        "balance": 12.75,
        "lifetime_stats": {"orders_completed": 17},
    })
    assert_true(ok, "save() should return true")
    assert_true(SaveManager.has_save())

    var data: Dictionary = SaveManager.load_save()
    assert_eq(int(data.get("current_day", -1)), 3)
    assert_almost_eq(float(data.get("balance", -1.0)), 12.75, 0.001)
    var stats: Dictionary = data.get("lifetime_stats", {})
    assert_eq(int(stats.get("orders_completed", -1)), 17)


func test_load_returns_empty_when_no_save() -> void:
    var data: Dictionary = SaveManager.load_save()
    assert_eq(data.size(), 0, "load_save with no file returns {}")


# ─────────────────────────────────────────────────────────────────────────────
# SCHEMA VERSIONING
# ─────────────────────────────────────────────────────────────────────────────

func test_schema_mismatch_wipes_save() -> void:
    # Forge a SaveData with a wrong schema_version directly.
    var sd: SaveData = SaveData.new()
    sd.schema_version = 999
    sd.current_day = 5
    sd.balance = 9.99
    var err: int = ResourceSaver.save(sd, SaveManager.SAVE_PATH)
    assert_eq(err, OK, "manual save should succeed")

    var data: Dictionary = SaveManager.load_save()
    assert_eq(data.size(), 0, "load_save returns {} on schema mismatch")
    assert_false(SaveManager.has_save(), "mismatched save should be wiped")


# ─────────────────────────────────────────────────────────────────────────────
# BUILD DICT REFLECTS LIVE STATE
# ─────────────────────────────────────────────────────────────────────────────

func test_build_save_dict_pulls_live_values() -> void:
    GameManager.current_day = 4
    EconomyManager.balance = 7.25

    var d: Dictionary = SaveManager.build_save_dict()
    assert_eq(int(d.current_day), 4)
    assert_almost_eq(float(d.balance), 7.25, 0.001)
    assert_eq(int(d.schema_version), SaveManager.SCHEMA_VERSION)
```

---

## Section E — Implementation Stub Excerpt

```gdscript
extends Node

const SAVE_PATH: String = "user://midnight_munch_save.tres"
const SCHEMA_VERSION: int = 1

func has_save() -> bool:
    return FileAccess.file_exists(SAVE_PATH)

func save(data: Dictionary) -> bool:
    var sd: SaveData = SaveData.new()
    sd.schema_version = SCHEMA_VERSION
    sd.current_day = int(data.get("current_day", 0))
    sd.balance = float(data.get("balance", 0.0))
    sd.lifetime_stats = data.get("lifetime_stats", {})
    return ResourceSaver.save(sd, SAVE_PATH) == OK

func load_save() -> Dictionary:
    if not has_save(): return {}
    var sd: SaveData = ResourceLoader.load(SAVE_PATH) as SaveData
    if sd == null or sd.schema_version != SCHEMA_VERSION:
        clear_save(); return {}
    return {
        "current_day": sd.current_day,
        "balance": sd.balance,
        "lifetime_stats": sd.lifetime_stats,
    }
```

---

## Section F — Editor Steps `[EDITOR]`

1. Open `Project Settings → Autoload`. Add `res://_src/autoloads/SaveManager.gd` with name `SaveManager`. Drag to position **after** `OrderManager` and **before** the COGITO autoloads.
2. Save project settings.

## Section G — Smoke Test Checklist

- [ ] Run scene. Console shows no autoload errors.
- [ ] In Remote tab: `SaveManager.save({"current_day": 2, "balance": 8.00, "lifetime_stats": {}})` returns `true`.
- [ ] On disk: `<project user dir>/midnight_munch_save.tres` exists. Open it in a text editor — schema_version, current_day, balance values are visible.
- [ ] `SaveManager.load_save()` returns the same Dictionary.
- [ ] `GameManager.end_day()` invoked manually → save file is updated; no `push_error`.
- [ ] Restart editor, open Remote tab on a fresh run: `SaveManager.has_save()` returns `true` from the previous session's file.
- [ ] GUT: all five tests in `test_save_manager.gd` pass.
- [ ] Web export: load the WASM build in a browser, complete a day, refresh the page, observe save persists across reload (IndexedDB-backed `user://`).

## Edge Cases

| Case | Behaviour |
|---|---|
| Disk full / write error | `ResourceSaver.save` returns non-OK; `save()` logs `push_error` and returns false. Caller (GameManager) does not crash. |
| Save file corrupted (manually edited to invalid TRES) | `ResourceLoader.load` returns null; `load_save` wipes file, returns `{}`. Player effectively starts a new game next boot. |
| Schema version increment in a future patch | `load_save` detects mismatch, logs warning, wipes file. Communicates "save reset" to the player via Phase 5.4 menu copy. |
| Save fires mid-`end_day` while `tally_day` returns transient state | `tally_day` is a pure read of EconomyManager state; safe to call inline. No race because EconomyManager runs on the main thread. |
| WASM cold-boot before IndexedDB ready | Godot's File API on Web waits for IDB ready before `_ready()` fires; `has_save()` is reliable from `_ready()` onward. |
| Player runs [New Game] over an existing save | Phase 5.4 must call `SaveManager.clear_save()` before `GameManager.start_day(0)`. Out of scope here — noted as a successor-task contract. |
