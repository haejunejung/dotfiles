---
name: orch
description: Drive the orchestrated task workflow. /orch init sets up .orch and .learnings in the repo; /orch new <slug> creates a task folder; /orch lock <id> snapshots the approved plan (gate G1); /orch run <id> runs the back stage (developer, 3 reviewers, qa, doc-writer) as the orchestrator; /orch status shows gates. Use when the user mentions a task id, gates, plan.lock or the orchestrator.
argument-hint: init | new <slug> | lock <task-id> | run <task-id> | status [task-id]
disable-model-invocation: true
---

Subcommand and arguments: `$ARGUMENTS`

Scripts live in `~/.claude/dotfiles/scripts/`. Run them with Bash and show the user the output.

- `init` → `~/.claude/dotfiles/scripts/orch-task.sh init`
- `new <slug> [base-ref]` → `~/.claude/dotfiles/scripts/orch-task.sh new <slug> [base-ref]`, then tell the user the task id and that the Main role writes 01-spec.md next.
- `lock <task-id>` → confirm with the user that they approve gate G1 (do not assume), then `~/.claude/dotfiles/scripts/orch-task.sh lock <task-id>`.
- `status [task-id]` → `~/.claude/dotfiles/scripts/orch-task.sh status [task-id]`.
- `run <task-id>` → read `~/.claude/roles/orchestrator.md` in full and follow it for this task id from the current gate onward (derive the gate from `status`). Keep every rule in that file: verbatim saves, round limit, two escalation points, no source edits.

If the subcommand is missing or unknown, print the list above and stop.
