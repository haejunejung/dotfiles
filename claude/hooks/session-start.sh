#!/usr/bin/env bash
# SessionStart: pull dotfiles learnings (quiet), then print a short context line about open tasks and inbox size.
. "$(dirname "$0")/lib.sh"; read_hook_json
cwd="$(jf cwd)"; [ -n "$cwd" ] || cwd="$PWD"
src="$(jf source)"
if [ "$src" = "startup" ] && [ "${LEARN_SYNC_ON_START:-1}" = "1" ]; then
  "$DOT/scripts/learn-sync.sh" pull >/dev/null 2>&1 || true
fi
root="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || true)"
if [ -n "$root" ] && [ -d "$root/.orch/tasks" ]; then
  open="$(ls "$root/.orch/tasks" 2>/dev/null | wc -l | tr -d ' ')"
  inbox="$(cat "$root"/.learnings/inbox/*.md 2>/dev/null | grep -c '^## ' || true)"
  echo "orch: $open task folder(s) in .orch/tasks; $inbox learning entries in .learnings/inbox. Use /orch status, /learn promote."
fi
log_event SessionStart "" "" "source=$src cwd=$cwd"
exit 0
