#!/usr/bin/env bash
# Hand work to another role's herdr pane in the same task worktree, so roles never ask the user to relay messages.
#   orch-handoff.sh <role> <message>      role: main | pm | architect | orch
# Finds the herdr agent named <role> whose cwd is inside this worktree and submits <message> as a prompt.
# Exit 0: delivered. Exit 2: not inside herdr or no such pane; the message is printed so the caller can tell the user.
set -euo pipefail

DOT="${DOTFILES_CLAUDE:-$HOME/.claude/dotfiles}"
. "$DOT/hooks/lib.sh"
role="${1:-}"; msg="${2:-}"
[ -n "$role" ] && [ -n "$msg" ] || { sed -n '2,5p' "$0"; exit 1; }

REPO="$(git rev-parse --show-toplevel)"

fallback() { echo "handoff to '$role' not delivered ($1). Send this to the $role pane:"; echo "  $msg"; exit 2; }
[ "${HERDR_ENV:-}" = "1" ] || fallback "not inside a herdr pane"

pane="$(herdr agent list | python3 -I -c 'import sys,json,os
role, repo = sys.argv[1], os.path.realpath(sys.argv[2])
for a in json.load(sys.stdin)["result"]["agents"]:
    cwd = os.path.realpath(a.get("cwd") or "")
    if a.get("name") == role and (cwd == repo or cwd.startswith(repo + os.sep)):
        print(a["pane_id"]); break' "$role" "$REPO" 2>/dev/null || true)"
[ -n "$pane" ] || fallback "no '$role' agent in this worktree"

herdr agent prompt "$pane" "$msg" >/dev/null || fallback "herdr agent prompt failed"
log_event "Handoff" "$role" "" "$pane $msg"
echo "handed to $role ($pane)"
