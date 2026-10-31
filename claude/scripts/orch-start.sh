#!/usr/bin/env bash
# Start a task workspace in herdr: one git worktree, one workspace, three front-stage Claude panes (main, pm, architect)
# and one back-stage orchestrator pane. Run this from inside a herdr-managed pane.
#   orch-start.sh <task-slug> [--base <ref>] [--front-model opus] [--pm-model sonnet] [--orch-model sonnet] [--dry-run]
# Each pane runs: claude --model <m> --append-system-prompt-file ~/.claude/roles/<role>.md
set -euo pipefail

DOT="${DOTFILES_CLAUDE:-$HOME/.claude/dotfiles}"
[ -f "$DOT/local.env" ] && . "$DOT/local.env"
slug="${1:-}"; [ -n "$slug" ] || { sed -n '2,5p' "$0"; exit 1; }; shift
base="main"; front_model="${ORCH_FRONT_MODEL:-opus}"; pm_model="${ORCH_PM_MODEL:-sonnet}"; orch_model="${ORCH_ORCH_MODEL:-sonnet}"; dry=0
while [ $# -gt 0 ]; do
  case "$1" in
    --base) base="$2"; shift 2 ;;
    --front-model) front_model="$2"; shift 2 ;;
    --pm-model) pm_model="$2"; shift 2 ;;
    --orch-model) orch_model="$2"; shift 2 ;;
    --dry-run) dry=1; shift ;;
    *) echo "unknown option: $1" >&2; exit 1 ;;
  esac
done

REPO="$(git rev-parse --show-toplevel)"
branch="task/$slug"
wt_path="$(dirname "$REPO")/$(basename "$REPO")--$slug"

run() { if [ "$dry" -eq 1 ]; then echo "[dry-run] $*"; else "$@"; fi; }
jget() { python3 -I -c 'import sys,json; d=json.load(sys.stdin)
for k in sys.argv[1].split("."):
    d=d[k]
print(d)' "$1"; }

if [ "$dry" -eq 0 ] && [ "${HERDR_ENV:-}" != "1" ]; then
  echo "not inside a herdr pane (HERDR_ENV != 1). Use --dry-run to print the commands." >&2; exit 1
fi

echo "task: $slug · branch: $branch · worktree: $wt_path · base: $base"

# 1) worktree + workspace
if [ "$dry" -eq 1 ]; then
  echo "[dry-run] herdr worktree create --cwd $REPO --branch $branch --base $base --path $wt_path --label $slug --no-focus --json"
  ws="w?"; root_pane="w?:p?"
else
  out="$(herdr worktree create --cwd "$REPO" --branch "$branch" --base "$base" --path "$wt_path" --label "$slug" --no-focus --json)"
  ws="$(printf '%s' "$out" | jget result.workspace.workspace_id 2>/dev/null || printf '%s' "$out" | jget result.workspace)"
  root_pane="$(printf '%s' "$out" | jget result.root_pane.pane_id 2>/dev/null || printf '%s' "$out" | jget result.root_pane)"
fi
echo "workspace: $ws · root pane: $root_pane"

# 2) task folder in the worktree
if [ "$dry" -eq 1 ]; then echo "[dry-run] (cd $wt_path && $DOT/scripts/orch-task.sh new $slug $base)"; task_id="$(date +%Y%m%d)-$slug"
else task_id="$(cd "$wt_path" && "$DOT/scripts/orch-task.sh" new "$slug" "$base")"; fi
echo "task id: $task_id"

# 3) panes: root=main, right=pm, down-right=architect, down-left=orchestrator
split() { # split <pane> <direction> -> new pane id
  if [ "$dry" -eq 1 ]; then echo "[dry-run] herdr pane split --pane $1 --direction $2 --cwd $wt_path --no-focus" >&2; echo "w?:p?"; return; fi
  herdr pane split --pane "$1" --direction "$2" --cwd "$wt_path" --no-focus | jget result.pane.pane_id
}
pm_pane="$(split "$root_pane" right)"
arch_pane="$(split "$pm_pane" down)"
orch_pane="$(split "$root_pane" down)"

start() { # start <name> <pane> <model> <role>
  run herdr agent start "$1" --kind claude --pane "$2" --timeout 60000 -- \
    --model "$3" --append-system-prompt-file "$HOME/.claude/roles/$4.md"
}
start main      "$root_pane" "$front_model" main
start pm        "$pm_pane"   "$pm_model"    pm
start architect "$arch_pane" "$front_model" architect
start orch      "$orch_pane" "$orch_model"  orchestrator

cat <<MSG

ready. In the 'main' pane start with:
  Task $task_id. Read .orch/tasks/$task_id/README.md and begin the spec with me.
When plan.lock.md exists, prompt the 'orch' pane with:
  /orch run $task_id
MSG
