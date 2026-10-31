---
name: learn
description: Self-improvement loop. /learn <text> records an explicit lesson or preference in the append-only inbox; /learn promote runs the reflector to propose rules from the inbox as a diff; /learn review runs the reflector in prune mode; /learn sync commits and pushes the global learnings in dotfiles. Use when the user corrects you and wants it remembered, or asks to review or promote learnings.
argument-hint: <lesson text> | promote | review | sync
---

Arguments: `$ARGUMENTS`

Inbox files are append-only, one per machine. Project inbox: `.learnings/inbox/<machine>.md` (only in repos that ran `/orch init`). Global inbox: `~/.claude/dotfiles/learnings/inbox/<machine>.md`.

- `promote` → call the `reflector` subagent with mode `promote`. Show its proposal unchanged. Apply nothing yourself; if the user accepts a proposal, make exactly that edit to the named file (project `CLAUDE.md` or `.claude/rules/<topic>.md`, or `~/.claude/dotfiles/learnings/global.md`), keeping the `[date] rule. Why: ... Evidence: ...` form and marking replaced rules `superseded YYYY-MM-DD` instead of deleting them.
- `review` → call `reflector` with mode `review`. Same handling.
- `sync` → `~/.claude/dotfiles/scripts/learn-sync.sh push`.
- anything else → it is a lesson. Decide the scope: project inbox when the lesson is about this codebase and the repo has `.learnings/`, otherwise the global inbox. Append one entry with Bash:

```
~/.claude/dotfiles/hooks/lib.sh is sourceable; use:
. ~/.claude/dotfiles/hooks/lib.sh && append_learning "<inbox file>" user high "<project>" "<task-id or ->" "<lesson text>" "user, /learn"
```

Then confirm in one line which file received it. Do not rewrite the user's words; store them as given, trimmed.
