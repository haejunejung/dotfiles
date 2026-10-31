# learnings

- `global.md`: promoted rules, loaded into every Claude Code session through `~/.claude/CLAUDE.md`.
- `inbox/<machine>.md`: raw, append-only global entries captured by hooks or `/learn` when the current repo has no `.learnings/` of its own. One file per machine so two computers never conflict on merge.

Flow: capture (hooks, `/learn`) → inbox → `/learn promote` (reflector proposes a diff) → user applies → `/learn sync` (commit and push) → next session on any machine loads it.
