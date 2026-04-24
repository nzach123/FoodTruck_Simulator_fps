# Skill: Update Changelog

Trigger: `/changelog`

## Workflow

1. Load Archiver agent context from `.claude/agents/archiver.md`
2. Read git log since last changelog entry
3. Read `.claude/context/handoff.md` for context
4. Categorize changes (Added/Changed/Fixed/Removed)
5. Update `documentation/changelog/CHANGELOG.md` with new entries
6. Cross-reference BUG-XXX for any fixes

## Usage Examples

```bash
# Update changelog with recent changes
claude --system-prompt .claude/agents/archiver.md -p "Update changelog with recent commits"

# Prepare release changelog
claude --system-prompt .claude/agents/archiver.md -p "Prepare changelog for version 0.2.0 release"
```

## Expected Output

- Updated CHANGELOG.md with properly categorized entries
- Cross-references to bugs, tasks, and commits
- Chronologically ordered entries
