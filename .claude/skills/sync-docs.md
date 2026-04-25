---
name: sync
description: Sync all documentation — changelog, architecture, sprint tracking, and handoff notes via the Archiver agent.
---

# Skill: Sync Documentation

Trigger: `/sync`

## Workflow

1. Load Archiver agent context from `.claude/agents/archiver.md`
2. Read `.claude/context/handoff.md` for latest changes
3. Parse `documentation/qa/BUG_TRACKER.md` for status changes
4. Update `documentation/changelog/CHANGELOG.md`
5. Update `documentation/architecture/SYSTEMS.md`
6. Refresh `.claude/context/current-sprint.md`
7. Update `CLAUDE.md` if architectural changes warrant it
8. Archive old handoff entries

## Usage Examples

```bash
# Full documentation sync
claude --system-prompt .claude/agents/archiver.md -p "Sync all documentation"

# Sync after major feature
claude --system-prompt .claude/agents/archiver.md -p "Sync docs after OrderManager implementation"
```

## Expected Output

- All tracking documents updated and consistent
- Handoff notes archived
- Discrepancies and gaps reported
- CLAUDE.md updated if needed
