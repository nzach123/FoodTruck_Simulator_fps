# Skill: Validate GDD Compliance

Trigger: `/validate-gdd [system]`

## Purpose
Create and run tests that verify implementation matches GDD specifications exactly.

## Scope Options

- `economy` — Validate all economy values (prices, tips, costs)
- `timing` — Validate timing windows and durations
- `progression` — Validate day difficulty schedule
- `interactions` — Validate cooking mechanic behaviors
- `all` — Full GDD compliance check

## Workflow

1. Load Tester agent context
2. Read relevant GDD sections from `documentation/gdd/`
3. Extract quantitative specifications
4. Generate assertion-based tests for each spec
5. Run tests headlessly
6. Report compliance percentage and deviations

## Headless Executable
```
C:\00_Godot\z_installer\Godot_v4.6-stable_win64.exe
```

## GDD Specification Tables

### Economy Values (GDD Section 7)
| Item | Expected Value |
|------|----------------|
| Starting Balance | $5.00 |
| Base Taco Price | $3.50 |
| Tip (0 sloppy) | $1.00 |
| Tip (1 sloppy) | $0.50 |
| Tip (2+ sloppy) | $0.00 |
| Tortilla Cost | $0.25 |
| Meat Cost | $0.75 |
| Sauce Cost (each) | $0.15 |
| Topping Cost (each) | $0.10 |
| Topping Drop Penalty | $0.05 |
| Patience Expiry Penalty | $1.50 |
| Balance Floor | $0.00 |

### Day Progression (GDD Section 5)
| Day | Patience (sec) | Spawn Rate | Max Queue |
|-----|----------------|------------|-----------|
| 0 | ∞ | Scripted | 1 |
| 1 | 60 | 1/45s | 2 |
| 2 | 55 | 1/40s | 2 |
| 3 | 50 | 1/35s | 3 |
| 4 | 45 | 1/30s | 3 |
| 5 | 40 | 1/25s | 3 |
| 6 | 35 | 1/22s | 3 |
| 7+ | 30 | 1/20s | 3 |

### Timing Constraints
| Mechanic | Constraint |
|----------|------------|
| All timing | `_physics_process` only |
| Web timing windows | 30% wider than native |
| Day duration | 5 minutes (300 seconds) |

## Usage Examples

```bash
# Validate economy implementation
claude --system-prompt .claude/agents/tester.md -p "Validate GDD compliance for economy system"

# Full validation
claude --system-prompt .claude/agents/tester.md -p "Run full GDD compliance check"
```

## Expected Output

```markdown
## GDD Compliance Report — YYYY-MM-DD HH:MM

### System: Economy
**Compliance: XX%**

| Specification | Expected | Actual | Status |
|--------------|----------|--------|--------|
| Starting Balance | $5.00 | $5.00 | PASS |
| Base Taco Price | $3.50 | $3.00 | FAIL |

### Deviations Found
- Base Taco Price: Expected $3.50, found $3.00 in EconomyManager.gd:42

### Recommendations
1. Update BASE_TACO_PRICE constant to 3.50
```
