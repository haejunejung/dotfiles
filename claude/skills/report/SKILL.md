---
name: report
description: Produce or refresh the final task report (09-report.md) for a task id. Collects evidence (git diff stats, test output, gate log) with orch-evidence.sh and calls the doc-writer subagent, which writes from evidence only. Use when the user asks for the report, the summary of a finished task, or to regenerate 09-report.md.
argument-hint: <task-id> [base-ref]
disable-model-invocation: true
---

Arguments: `$ARGUMENTS` (task id, optional base ref).

1. Run `~/.claude/dotfiles/scripts/orch-evidence.sh <task-id> [base-ref]` and show its file list.
2. Check that `07-review-a.md`, `07-review-b.md`, `07-review-c.md` and `08-qa.md` exist. If any is missing, say which gate has not run and stop; the report must not be written from a partial run unless the user says so explicitly.
3. Call the `doc-writer` subagent with the task id and base ref. It writes `09-report.md`.
4. Print the "At a glance" block and the "Needs your decision" list from the report, and the report path. Nothing else.
