#!/usr/bin/env bash
# Task folder helper for the orchestrated workflow.
#   orch-task.sh init                 create .orch/ and .learnings/ in the current repo
#   orch-task.sh new <slug> [base]    create .orch/tasks/<id>/ from templates (base ref defaults to current branch's upstream or main)
#   orch-task.sh lock <task-id>       snapshot 02-plan.md + 04-architecture.md into plan.lock.md (gate G1)
#   orch-task.sh status [task-id]     show gate status derived from the files
set -euo pipefail

DOT="${DOTFILES_CLAUDE:-$HOME/.claude/dotfiles}"
TPL="$DOT/templates/task"
REPO="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
TASKS="$REPO/.orch/tasks"

die() { echo "error: $*" >&2; exit 1; }

render() { # render <template> <dest> KEY=VALUE...
  local src="$1" dest="$2"; shift 2
  local content; content="$(cat "$src")"
  for kv in "$@"; do
    local k="${kv%%=*}" v="${kv#*=}"
    content="${content//\{\{$k\}\}/$v}"
  done
  printf '%s\n' "$content" > "$dest"
}

cmd_init() {
  mkdir -p "$TASKS" "$REPO/.learnings/inbox"
  [ -f "$REPO/.orch/README.md" ] || cat > "$REPO/.orch/README.md" <<'MD'
# .orch

Task folders for the orchestrated workflow (see ~/.claude/dotfiles/README.md).
Each task: `.orch/tasks/<task-id>/` with 01-spec.md ... 09-report.md and plan.lock.md.
MD
  [ -f "$REPO/.learnings/README.md" ] || cat > "$REPO/.learnings/README.md" <<'MD'
# .learnings

Append-only learning inbox, one file per machine (`inbox/<machine>.md`), captured by hooks and `/learn`.
Promotion to CLAUDE.md or .claude/rules/ goes through the `reflector` agent and the user's approval.
MD
  echo "initialized $REPO/.orch and $REPO/.learnings"
}

cmd_new() {
  local slug="${1:-}"; [ -n "$slug" ] || die "usage: orch-task.sh new <slug> [base-ref]"
  [ -d "$TASKS" ] || cmd_init >/dev/null
  local base="${2:-}"
  if [ -z "$base" ]; then
    base="$(git -C "$REPO" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
    [ -n "$base" ] || base="$(git -C "$REPO" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##' || true)"
    [ -n "$base" ] || base="main"
  fi
  local id="$(date +%Y%m%d)-$slug"
  local dir="$TASKS/$id"
  [ -e "$dir" ] && die "task exists: $dir"
  mkdir -p "$dir/00-evidence"
  local today; today="$(date +%Y-%m-%d)"
  for f in README.md 00-log.md 01-spec.md 02-plan.md 03-pm-review.md 04-architecture.md scope-changes.md; do
    render "$TPL/$f" "$dir/$f" "TASK_ID=$id" "SLUG=$slug" "DATE=$today" "BASE_REF=$base"
  done
  echo "$id"
  echo "created $dir (base_ref=$base)" >&2
}

cmd_lock() {
  local id="${1:-}"; [ -n "$id" ] || die "usage: orch-task.sh lock <task-id>"
  local dir="$TASKS/$id"; [ -d "$dir" ] || die "no such task: $dir"
  [ -f "$dir/02-plan.md" ] || die "missing 02-plan.md"
  [ -f "$dir/04-architecture.md" ] || die "missing 04-architecture.md (Architect must finish before lock)"
  if [ -f "$dir/plan.lock.md" ]; then
    local n=1; while [ -f "$dir/plan.lock.$n.md" ]; do n=$((n+1)); done
    mv "$dir/plan.lock.md" "$dir/plan.lock.$n.md"
    echo "previous lock kept as plan.lock.$n.md" >&2
  fi
  local sha_plan sha_arch rev user
  sha_plan="$(shasum -a 256 "$dir/02-plan.md" | cut -d' ' -f1)"
  sha_arch="$(shasum -a 256 "$dir/04-architecture.md" | cut -d' ' -f1)"
  rev="$(sed -n 's/^revision:[[:space:]]*//p' "$dir/02-plan.md" | head -1)"
  user="$(git -C "$REPO" config user.name 2>/dev/null || whoami)"
  {
    printf -- '---\nlocked_at: %s\nlocked_by: %s\nplan_revision: %s\nplan_sha256: %s\narchitecture_sha256: %s\n---\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$user" "${rev:-?}" "$sha_plan" "$sha_arch"
    printf '# plan.lock · %s\n\nThis file is a snapshot taken when the user approved gate G1. It is never edited. Scope changes after this point go to `scope-changes.md` and require a new lock.\n\n' "$id"
    cat "$dir/02-plan.md"; printf '\n---\n\n'; cat "$dir/04-architecture.md"
  } > "$dir/plan.lock.md"
  sed -i '' 's/^status:.*/status: locked/' "$dir/README.md" 2>/dev/null || true
  printf '%s · G1 · PASS · round 0 · plan locked by %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$user" >> "$dir/00-log.md"
  echo "locked: $dir/plan.lock.md"
}

gate_line() { # gate_line <label> <file> <pattern>
  local label="$1" file="$2" pat="$3"
  if [ ! -f "$file" ]; then printf '  %-22s -\n' "$label"; return; fi
  local v; v="$(grep -m1 -E "$pat" "$file" | sed 's/^[^:]*:[[:space:]]*//' || true)"
  case "$v" in *" | "*) v="(template, not written yet)" ;; esac
  printf '  %-22s %s\n' "$label" "${v:-written}"
}

cmd_status() {
  local ids=("$@")
  [ ${#ids[@]} -gt 0 ] || ids=($(ls "$TASKS" 2>/dev/null || true))
  [ ${#ids[@]} -gt 0 ] || { echo "no tasks in $TASKS"; return; }
  for id in "${ids[@]}"; do
    local d="$TASKS/$id"; [ -d "$d" ] || { echo "$id: not found"; continue; }
    echo "$id"
    gate_line "G0 pm-review"    "$d/03-pm-review.md"   '^Verdict:'
    gate_line "G1 plan.lock"    "$d/plan.lock.md"      '^locked_at:'
    gate_line "G2 impl-notes"   "$d/05-impl-notes.md"  '^Test result:'
    gate_line "G3 review-a"     "$d/07-review-a.md"    '^Verdict:'
    gate_line "G3 review-b"     "$d/07-review-b.md"    '^Verdict:'
    gate_line "G3 review-c"     "$d/07-review-c.md"    '^Verdict:'
    gate_line "G4 qa"           "$d/08-qa.md"          '^Result:'
    gate_line "G5 report"       "$d/09-report.md"      '^- Result:'
  done
}

case "${1:-}" in
  init)   cmd_init ;;
  new)    shift; cmd_new "$@" ;;
  lock)   shift; cmd_lock "$@" ;;
  status) shift; cmd_status "$@" ;;
  *) sed -n '2,6p' "$0"; exit 1 ;;
esac
