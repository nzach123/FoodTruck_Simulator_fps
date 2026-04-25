---
name: godot
version: 1.3.0
description: Develop, test, build, and deploy Godot 4.x games. Uses GUT for GDScript unit tests. Supports web/desktop exports and CI/CD pipelines.
---

# Godot Skill

Develop, test, build, and deploy Godot 4.x games.

## Executable Paths

| Exe | Purpose |
|---|---|
| `C:\00_Godot\z_installer\Godot_v4.6-stable_win64.exe` | Editor (GUI) |
| `C:\00_Godot\z_installer\Godot_v4.6-stable_win64_console.exe` | Headless / CI (shows stdout) |

**Always use the console exe for headless operations** — it pipes stdout to the terminal.

```bash
# Alias for readability (use the full path in all commands below)
GODOT="C:\00_Godot\z_installer\Godot_v4.6-stable_win64_console.exe"
PROJECT="C:\00_Repos\Godot_Projects\Food-Truck-Sim\FoodTruck_Simulator_fps"
```

## Quick Reference

```bash
# Run GUT tests headless
"C:\00_Godot\z_installer\Godot_v4.6-stable_win64_console.exe" --headless \
  --path "C:\00_Repos\Godot_Projects\Food-Truck-Sim\FoodTruck_Simulator_fps" \
  -s res://addons/gut/gut_cmdln.gd \
  -gconfig=res://tests/.gutconfig.json

# Run a specific test file headless
"C:\00_Godot\z_installer\Godot_v4.6-stable_win64_console.exe" --headless \
  --path "C:\00_Repos\Godot_Projects\Food-Truck-Sim\FoodTruck_Simulator_fps" \
  -s res://addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit/ -gtest=res://tests/unit/test_my_script.gd

# Export web build
"C:\00_Godot\z_installer\Godot_v4.6-stable_win64_console.exe" --headless \
  --path "C:\00_Repos\Godot_Projects\Food-Truck-Sim\FoodTruck_Simulator_fps" \
  --export-release "Web" ./build/index.html
```

---

## Testing Overview

This project uses **GUT** (Godot Unit Testing) — a GDScript-native test framework that runs inside Godot.

| Setting | Value |
|---|---|
| Test dirs | `res://tests/unit/`, `res://tests/integration/` |
| File prefix | `test_` |
| File suffix | `.gd` |
| Config | `res://tests/.gutconfig.json` |
| Base class | `GutTest` |
| CLI script | `res://addons/gut/gut_cmdln.gd` |

---

## GUT (GDScript Tests)

### Project Structure

```
project/
├── addons/gut/              # GUT addon
├── tests/
│   ├── .gutconfig.json      # GUT config (dirs, prefix, suffix, should_exit)
│   ├── unit/
│   │   └── test_my_script.gd
│   └── integration/
│       └── test_my_scene.gd
└── _src/
    └── ...                  # Game source
```

### Basic Unit Test

```gdscript
# tests/unit/test_my_script.gd
extends GutTest

var subject

func before_each() -> void:
    subject = auto_free(MyClass.new())

func after_each() -> void:
    pass

func test_initial_state() -> void:
    assert_eq(subject.value, 0, "should start at zero")
    assert_true(subject.is_ready(), "should be ready")

func test_pending_feature() -> void:
    pending("Not yet implemented")
```

### GUT Assertions

```gdscript
# Equality / comparison
assert_eq(actual, expected, "message")
assert_ne(actual, unexpected, "message")
assert_gt(value, threshold)
assert_lt(value, threshold)
assert_between(value, low, high)

# Boolean / null
assert_true(condition, "message")
assert_false(condition, "message")
assert_null(value)
assert_not_null(value)

# Strings / arrays
assert_string_contains(text, "substring")
assert_has(array, element)
assert_does_not_have(array, element)

# Node lifecycle
add_child_autofree(node)   # freed automatically after test
auto_free(obj)             # returns obj, freed after test

# Signals
watch_signals(node)
assert_signal_emitted(node, "signal_name")
assert_signal_not_emitted(node, "signal_name")
assert_signal_emitted_with_parameters(node, "signal_name", [arg1, arg2])
```

### Scene Test with Input Simulation

```gdscript
# tests/unit/test_truck_station.gd
extends GutTest

var scene_root: Node

func before_each() -> void:
    scene_root = add_child_autofree(
        load("res://_src/interactables/stations/MyStation.tscn").instantiate()
    )
    await get_tree().process_frame

func test_interaction_complete_emits_signal() -> void:
    watch_signals(scene_root)
    scene_root.on_interaction_complete(3)
    assert_signal_emitted(scene_root, "interaction_done")
```

### Running GUT Tests

```bash
# All tests (uses .gutconfig.json)
"C:\00_Godot\z_installer\Godot_v4.6-stable_win64_console.exe" --headless \
  --path "C:\00_Repos\Godot_Projects\Food-Truck-Sim\FoodTruck_Simulator_fps" \
  -s res://addons/gut/gut_cmdln.gd \
  -gconfig=res://tests/.gutconfig.json

# Single test file
"C:\00_Godot\z_installer\Godot_v4.6-stable_win64_console.exe" --headless \
  --path "C:\00_Repos\Godot_Projects\Food-Truck-Sim\FoodTruck_Simulator_fps" \
  -s res://addons/gut/gut_cmdln.gd \
  -gtest=res://tests/unit/test_my_script.gd

# Unit tests only
"C:\00_Godot\z_installer\Godot_v4.6-stable_win64_console.exe" --headless \
  --path "C:\00_Repos\Godot_Projects\Food-Truck-Sim\FoodTruck_Simulator_fps" \
  -s res://addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit/

# With JUnit XML output (CI)
"C:\00_Godot\z_installer\Godot_v4.6-stable_win64_console.exe" --headless \
  --path "C:\00_Repos\Godot_Projects\Food-Truck-Sim\FoodTruck_Simulator_fps" \
  -s res://addons/gut/gut_cmdln.gd \
  -gconfig=res://tests/.gutconfig.json \
  -gjunit_xml_file=./reports/results.xml
```

### Editor (GUI) Testing

Open the project in the Godot editor → **GUT panel** (bottom dock) → **Run All**.  
The gutconfig is auto-loaded from `res://tests/.gutconfig.json`.

---

## Building & Deployment

### Web Export

```bash
# Requires export_presets.cfg with a "Web" preset and web export templates installed
"C:\00_Godot\z_installer\Godot_v4.6-stable_win64_console.exe" --headless \
  --path "C:\00_Repos\Godot_Projects\Food-Truck-Sim\FoodTruck_Simulator_fps" \
  --export-release "Web" ./build/index.html
```

### Export Preset (export_presets.cfg)

```ini
[preset.0]
name="Web"
platform="Web"
runnable=true
export_path="build/index.html"
```

This project targets the **GL Compatibility** renderer for web/WASM — ensure the Web preset uses Compatibility mode.

---

## CI/CD

### GitHub Actions Example

```yaml
- name: Setup Godot
  run: |
    curl -L -o godot.zip https://github.com/godotengine/godot/releases/download/4.6-stable/Godot_v4.6-stable_linux.x86_64.zip
    unzip godot.zip -d /usr/local/bin/
    chmod +x /usr/local/bin/Godot_v4.6-stable_linux.x86_64
    ln -s /usr/local/bin/Godot_v4.6-stable_linux.x86_64 /usr/local/bin/godot

- name: Import project
  run: godot --headless --path . --import || true

- name: Run GUT Tests
  run: |
    godot --headless --path . \
      -s res://addons/gut/gut_cmdln.gd \
      -gconfig=res://tests/.gutconfig.json \
      -gjunit_xml_file=./reports/results.xml

- name: Upload Results
  uses: actions/upload-artifact@v4
  if: always()
  with:
    name: test-results
    path: reports/
```

> On Linux CI, substitute the Linux Godot binary. On Windows CI runners, use the same paths as local development.

---

## Project Conventions (Midnight Munch)

When writing or modifying code for this project, apply these rules in addition to standard GDScript:

- Static typing everywhere: `var x: int`, `func f() -> void`
- All custom code under `res://_src/`. Never modify `addons/`.
- Cross-system comms via `EventBus` signals only — no sibling-to-sibling calls.
- Never call `queue_free()` on gameplay nodes; use `NodePool.ret(node)`.
- All station scripts extend `TruckStation`.
- All timing uses `_physics_process`, never `await`/`yield`.
- Web/WASM constants need 30% latency adjustment vs native values.
- Wrap debug prints in `if OS.is_debug_build()`. Prefix errors with `[ClassName]`.
- Progress values normalized 0.0–1.0 before leaving a station script.
