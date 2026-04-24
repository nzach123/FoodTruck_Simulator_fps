# Skill: Run QA Scan

Trigger: `/qa [scope]`

## Scope Options

- `full` — Entire codebase scan
- `economy` — Economy system only
- `timing` — Timing interactions only
- `stations` — All truck stations
- `<path>` — Specific file or directory

## Workflow

1. Load Bug Hunter agent context from `.claude/agents/bughunter.md`
2. Execute scan methodology for specified scope
3. Document findings in `documentation/qa/BUG_TRACKER.md`
4. Update `documentation/qa/TEST_RESULTS.md`
5. Write handoff with priority recommendations

## Usage Examples

```bash
# Full codebase scan
claude --system-prompt .claude/agents/bughunter.md -p "Perform full QA scan"

# Targeted scan
claude --system-prompt .claude/agents/bughunter.md -p "Scan economy system for GDD compliance"

# Specific file scan
claude --system-prompt .claude/agents/bughunter.md -p "Scan scripts/stations/SauceStation.gd"

# Verify bug fix
claude --system-prompt .claude/agents/bughunter.md -p "Verify BUG-003 is resolved and update tracker"
```

## Expected Output

- Updated BUG_TRACKER.md with new issues
- Updated TEST_RESULTS.md with scan summary
- Handoff notes with priority recommendations
- Blockers.md updated if critical issues found
