# Skill: Implement Feature

Trigger: `/implement <feature-name>`

## Workflow

1. Load Builder agent context from `.claude/agents/builder.md`
2. Read GDD for feature specification in `documentation/gdd/`
3. Check `.claude/context/current-sprint.md` for task details
4. Check `documentation/architecture/SYSTEMS.md` for related implementations
5. Implement feature following Builder constraints
6. Write handoff notes to `.claude/context/handoff.md`
7. Update `.claude/context/current-sprint.md` status

## Usage Examples

```bash
# Implement a specific GDD feature
claude --system-prompt .claude/agents/builder.md -p "Implement the sauce power bar interaction per GDD section 6.3"

# Implement based on sprint task
claude --system-prompt .claude/agents/builder.md -p "Implement TASK-005 from current-sprint.md"
```

## Expected Output

- Working GDScript implementation
- Updated handoff.md with implementation notes
- Updated current-sprint.md with task status
- Any new systems documented in SYSTEMS.md
