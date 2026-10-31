# claude/

Everything Claude Code needs for the orchestrated workflow and the self-improvement loop. `install.sh` links this folder to `~/.claude/dotfiles` and its parts to the places Claude Code reads.

| Path | Linked to | Purpose |
|---|---|---|
| `CLAUDE.md` | `~/.claude/CLAUDE.md` | Global instructions; imports `learnings/global.md` |
| `agents/` | `~/.claude/agents` | Back-stage subagents: developer, designer, reviewer-a/b/c, qa, doc-writer, reflector |
| `roles/` | `~/.claude/roles` | Front-stage session prompts: main, pm, architect; back-stage: orchestrator. Used with `claude --append-system-prompt-file` |
| `skills/` | `~/.claude/skills/{orch,learn,report}` | Slash commands `/orch`, `/learn`, `/report` |
| `hooks/` | via `~/.claude/dotfiles/hooks` | Session start sync, learning capture, local event feed |
| `scripts/` | via `~/.claude/dotfiles/scripts` | Task folders, plan lock, evidence, herdr workspace start, learnings sync |
| `templates/task/` | - | Files copied into `.orch/tasks/<id>/` |
| `learnings/` | `~/.claude/learnings` | Promoted global rules and per-machine global inbox |
| `settings.hooks.json` | merged into `~/.claude/settings.json` | Hook registration |
| `local.env.example` | copy to `local.env` (gitignored) | Machine-specific values |

Skill access by role (all optional, invoked only when the situation calls for it):

- developer, reviewer-a/b/c, qa: pstack skills (`architect`, `how`, `why`, `tdd`, `blast-radius`, `show-me-your-work`, `no-comments`, `interrogate`, `principle-*`).
- designer: Emil Kowalski's skills (`emil-design-eng`, `animate`, `animate-expo`, `review-animations`, `apple-design`, `mobile-native`, `animation-performance`, `break-ui`, ...). Reviewer C and QA may use the review-oriented ones for the UX lens.
- doc-writer: `archify` for diagrams or a shareable page, `eli5` when the report audience is non-technical, `technical-writing`, `unslop`.
- reflector: `reflect`, `correct`, `unslop`.
