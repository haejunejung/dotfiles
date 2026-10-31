# Global instructions (from dotfiles)

This machine runs the orchestrated workflow described in `~/.claude/dotfiles/README.md`.

- Task work lives in `.orch/tasks/<task-id>/` inside each repository. Files are the handoff between roles; do not paste them into chat.
- Front stage (Main, PM, Architect) talks with the user and ends with the user approving gate G1, which freezes `plan.lock.md`. Back stage (Developer, Designer, Reviewer A/B/C, QA, Doc Writer) runs as subagents from the orchestrator and never edits the plan.
- Slash commands: `/orch` (tasks and gates), `/learn` (self-improvement), `/report` (final report).
- When the user corrects you or states a standing preference, it is a learning: use `/learn` behavior and append it to the inbox rather than relying on memory alone.
- Every turn that changes task files ends with the fixed block: Summary / Changes / Open items / Not verified.

Promoted global rules:
@learnings/global.md
