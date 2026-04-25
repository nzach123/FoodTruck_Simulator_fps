---
name: test-run
description: Execute GUT tests headlessly and report results. Usage: /test-run [all|unit|integration|<filename>]
---

# Skill: Run Tests

Trigger: `/test-run [scope]`

## Purpose
Execute GUT tests headlessly and report results.

## Scope Options

- `all` — Run entire test suite
- `unit` — Run only unit tests
- `integration` — Run only integration tests
- `<filename>` — Run specific test file
- `<filename>::<method>` — Run specific test method

## Workflow

1. Load Tester agent context from `.claude/agents/tester.md`
2. Construct appropriate GUT CLI command
3. Execute tests via headless Godot
4. Parse and format results
5. Update `documentation/qa/TEST_RESULTS.md`
6. If failures found, create entries in `documentation/qa/BUG_TRACKER.md`

## Headless Executable
```
C:\00_Godot\z_installer\Godot_v4.6-stable_win64.exe
```

## Execution Commands

```bash
# Run all tests
"C:\00_Godot\z_installer\Godot_v4.6-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd

# Run all unit tests
"C:\00_Godot\z_installer\Godot_v4.6-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit

# Run specific test file
"C:\00_Godot\z_installer\Godot_v4.6-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_economy.gd

# Run specific test method
"C:\00_Godot\z_installer\Godot_v4.6-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_economy.gd -gunit_test_name=test_balance_floor

# Run with verbose logging
"C:\00_Godot\z_installer\Godot_v4.6-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -glog=3

# Run and exit with error code on failure
"C:\00_Godot\z_installer\Godot_v4.6-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gexit
```

## Usage Examples

```bash
# Run all tests
claude --system-prompt .claude/agents/tester.md -p "Run all tests and report results"

# Run economy tests only
claude --system-prompt .claude/agents/tester.md -p "Run tests/unit/test_economy.gd"

# Run specific test
claude --system-prompt .claude/agents/tester.md -p "Run test_tip_calculation in test_economy.gd"
```

## Expected Output

```markdown
## Test Run — YYYY-MM-DD HH:MM

### Command Executed
```bash
[exact command]
```

### Results Summary
- Total: XX
- Passed: XX (XX%)
- Failed: XX
- Pending: XX

### Failed Tests
| Test | File | Error |
|------|------|-------|
| test_name | test_file.gd | Error message |

### Recommendations
- Priority fixes based on failures
```
