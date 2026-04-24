# Skill: Create Tests

Trigger: `/test-create <component>`

## Purpose
Analyze a game component and generate comprehensive GUT unit tests.

## Workflow

1. Load Tester agent context from `.claude/agents/tester.md`
2. Read target script and identify testable logic
3. Cross-reference GDD for expected values and behaviors
4. Generate GUT test script following naming conventions
5. Validate generated code with linter
6. Write test file to appropriate `tests/` subdirectory

## Usage Examples

```bash
# Create tests for a specific script
claude --system-prompt .claude/agents/tester.md -p "Create unit tests for scripts/autoloads/EconomyManager.gd"

# Create tests for a system
claude --system-prompt .claude/agents/tester.md -p "Create tests for the sauce power bar interaction"

# Create tests based on GDD section
claude --system-prompt .claude/agents/tester.md -p "Create tests covering GDD Section 7 (Economy System)"
```

## Expected Output

1. **Analysis** — Summary of logic and edge cases identified
2. **GUT Test Script** — Complete, linted test file
3. **File Location** — Where the test was saved
4. **Execution Command** — Ready-to-run CLI command

## Test File Naming Convention

```
tests/unit/test_<system_name>.gd
tests/integration/test_<flow_name>.gd
```

## Headless Executable
```
C:\00_Godot\z_installer\Godot_v4.6-stable_win64.exe
```
