# Skill: Lint Code

Trigger: `/lint [path]`

## Purpose
Validate GDScript code against linter standards before commit.

## Scope Options

- `all` — Lint entire `scripts/` directory
- `tests` — Lint all test files
- `<filepath>` — Lint specific file
- `<directory>` — Lint all `.gd` files in directory

## Workflow

1. Identify target files for linting
2. Execute GDScript linter via headless Godot
3. Parse warnings and errors
4. Report issues with file locations and line numbers
5. Suggest fixes for common issues

## Headless Executable
```
C:\00_Godot\z_installer\Godot_v4.6-stable_win64.exe
```

## Linter Add-on
```
addons/gdscript-linter/
```

## Execution Commands

```bash
# Lint specific file
"C:\00_Godot\z_installer\Godot_v4.6-stable_win64.exe" --headless --script addons/gdscript-linter/linter.gd -- path/to/file.gd

# Lint directory
"C:\00_Godot\z_installer\Godot_v4.6-stable_win64.exe" --headless --script addons/gdscript-linter/linter.gd -- scripts/

# Lint with specific rules
"C:\00_Godot\z_installer\Godot_v4.6-stable_win64.exe" --headless --script addons/gdscript-linter/linter.gd --config=.gdlintrc -- path/to/file.gd
```

## Usage Examples

```bash
# Lint a new script
claude --system-prompt .claude/agents/tester.md -p "Lint scripts/autoloads/EconomyManager.gd"

# Lint all tests
claude --system-prompt .claude/agents/tester.md -p "Lint all files in tests/"

# Lint before PR
claude --system-prompt .claude/agents/tester.md -p "Lint all changed files"
```

## Expected Output

```markdown
## Lint Results — YYYY-MM-DD HH:MM

### Files Checked
- file1.gd
- file2.gd

### Summary
- Errors: X
- Warnings: X
- Clean Files: X

### Issues

#### Errors (must fix)
| File | Line | Issue |
|------|------|-------|
| file.gd | 42 | Description |

#### Warnings (should fix)
| File | Line | Issue |
|------|------|-------|
| file.gd | 15 | Description |

### Auto-fix Suggestions
- Issue: Suggested fix
```

## Common Linter Rules

| Rule | Description |
|------|-------------|
| `unused-variable` | Variable declared but never used |
| `unused-argument` | Function argument never used |
| `missing-type-hint` | Variable/function lacks type annotation |
| `line-too-long` | Line exceeds 100 characters |
| `trailing-whitespace` | Whitespace at end of line |
| `mixed-tabs-spaces` | Inconsistent indentation |
| `missing-return-type` | Function lacks return type hint |
