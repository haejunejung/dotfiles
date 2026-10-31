# dotfiles

Skills, agents, hooks and scripts for Claude Code (and skills for Codex CLI), kept in one repo so every machine behaves the same.

```
./install.sh            # link everything into ~/.claude and ~/.agents, merge hooks into ~/.claude/settings.json
./install.sh --dry-run  # show what would change
./verify.sh             # static checks on the result
```

## What is here

| Path | Content |
|---|---|
| `skills/` | Skills written in this repo (none yet) |
| `vendor/` | Git submodules: `archify`, `eli5`, `cursor-plugins` (pstack), `emil-skills` |
| `claude/` | The orchestrated workflow and self-improvement loop for Claude Code (see `claude/README.md`) |
| `install.sh`, `verify.sh` | Linker and checker |

Linked skills: `archify`, `eli5`, a curated set of pstack skills (`poteto-mode`, `how`, `why`, `architect`, `swarm`, `arena`, `interrogate`, `reflect`, `figure-it-out`, `unslop`, `technical-writing`, `no-comments`, `show-me-your-work`, `tdd`, `blast-radius`, `correct`, `principle-*`), and Emil Kowalski's design-engineering skills (all except `write-swift`).

## The workflow in one paragraph

A task starts cheap and ends expensive. In the **front stage** three interactive sessions (Main, PM, Architect) turn the user's request into `01-spec.md`, `02-plan.md`, `03-pm-review.md` and `04-architecture.md` inside `.orch/tasks/<task-id>/`. When the user approves (gate G1) the plan is frozen into `plan.lock.md`. The **back stage** is one orchestrator session that calls subagents in order: Developer (G2), three Reviewers with different lenses who must all approve (G3, at most 3 fix rounds), QA on the platforms the change impact requires (G4), and the Doc Writer who writes `09-report.md` from evidence only (G5). The Designer is consulted through the orchestrator when the Developer hits a motion, haptics or UX question. Every role ends with Summary / Changes / Open items / Not verified.

```
user ──► Main ──► PM ──► Architect ──► [G1: user approves, plan.lock.md]
                                              │
            orchestrator ─► developer ─► reviewer-a/b/c ─► qa ─► doc-writer ─► 09-report.md
                               ▲  ◄── designer (relay)   │  (REJECT: ≤3 rounds)
                               └─────────────────────────┘  (FAIL: back to G3)
```

## Roles, models, tools

| Role | File | Model | Tools |
|---|---|---|---|
| Main | `claude/roles/main.md` (session) | opus via `--model` | read, write task docs |
| PM | `claude/roles/pm.md` (session) | sonnet | read, write `03-pm-review.md` |
| Architect | `claude/roles/architect.md` (session) | opus | read, write `04-architecture.md` |
| Orchestrator | `claude/roles/orchestrator.md` (session) | sonnet | Agent calls, saves reports, never edits source |
| developer | `claude/agents/developer.md` | sonnet | Read, Edit, Write, Bash, Skill |
| designer | `claude/agents/designer.md` | sonnet | Read, Grep, Glob, Skill (read-only) |
| reviewer-a | correctness, tests | sonnet | read-only + Bash for diff and tests |
| reviewer-b | structure vs `04-architecture.md` | opus (experiment) | read-only |
| reviewer-c | security, performance, platform UX, impact class | sonnet | read-only |
| qa | runs the change on required platforms | sonnet | read-only + Bash |
| doc-writer | `09-report.md` from evidence | sonnet | read + Write |
| reflector | promotion proposals for learnings | sonnet | read-only |

Models are the initial hypothesis from the plan; adjust per role in the agent frontmatter and in `claude/local.env` for sessions. Do not set `CLAUDE_CODE_SUBAGENT_MODEL` (since Claude Code 2.1.251 frontmatter wins anyway, but the force variant would override).

## Running a task

Inside a herdr pane, from the repository:

```
~/.claude/dotfiles/scripts/orch-start.sh <slug>          # worktree + workspace + 4 claude panes
```

Or by hand in any terminal:

```
/orch init                              # once per repo: .orch/ and .learnings/
/orch new <slug>                        # task folder from templates
claude --model opus   --append-system-prompt-file ~/.claude/roles/main.md
claude --model sonnet --append-system-prompt-file ~/.claude/roles/pm.md
claude --model opus   --append-system-prompt-file ~/.claude/roles/architect.md
/orch lock <task-id>                    # after the user approves G1
claude --model sonnet --append-system-prompt-file ~/.claude/roles/orchestrator.md
/orch run <task-id>                     # back stage, automatic
/report <task-id>                       # regenerate the report if needed
/orch status                            # gates derived from files
```

One task = one git worktree = one herdr workspace. Project-level `.claude/agents/<name>.md` overrides the global agent with the same name.

## Self-improvement

- Capture is deterministic (hooks), promotion is manual (user approval):
  - `UserPromptSubmit` hook records prompts that look like a correction or a standing rule (`confidence=candidate`).
  - `PostToolUse` hook records reviewer `REJECT` and QA `FAIL` files as entries.
  - `/learn <text>` records an explicit lesson (`confidence=high`).
- Entries go to `.learnings/inbox/<machine>.md` in the repo (append-only, one file per machine, so two computers never conflict), or to `claude/learnings/inbox/<machine>.md` when the repo has not opted in.
- `/learn promote` runs the `reflector` agent, which proposes a diff. The user applies it to `CLAUDE.md`, `.claude/rules/`, or `claude/learnings/global.md` (global, loaded by every session through `~/.claude/CLAUDE.md`).
- Rules carry a date, a why and evidence, and are superseded rather than deleted. `global.md` is capped at 80 rules; `/learn review` proposes retirements.
- `/learn sync` commits and pushes the global file; the `SessionStart` hook pulls it quietly on the next machine.

## Observability

- herdr sidebar shows pane state. Install the Claude Code integration with `herdr integration install claude`.
- Hooks append one JSON line per event to `~/.claude/orch-events.jsonl` (local only). Tail it in a pane with `~/.claude/dotfiles/scripts/orch-tail.sh`.
- Gate decisions are in `.orch/tasks/<id>/00-log.md`; mechanical evidence for the report is in `00-evidence/` (`orch-evidence.sh`).

## Verified against Claude Code 2.1.314 (2026-10-30)

- Subagents may spawn subagents up to three levels deep; the Designer relay through the orchestrator is kept anyway so read-only roles stay read-only.
- `--agent`, `--model`, `--append-system-prompt-file` exist. Agent frontmatter `model` beats `CLAUDE_CODE_SUBAGENT_MODEL` since 2.1.251.
- Hook events used here: `SessionStart`, `UserPromptSubmit`, `PostToolUse`, `SubagentStart`, `SubagentStop`, `Stop`. `SessionStart` stdout becomes context.
- Commands and skills are unified; the three slash commands are skills under `claude/skills/`.
- Auto memory lives under `~/.claude/projects/<project>/memory/` and is not synced; cross-machine learnings use the file flow above.
