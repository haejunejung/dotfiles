#!/usr/bin/env bash
# PostToolUse (Write|Edit): when a review or QA file lands with REJECT or FAIL, record it as a learning entry.
. "$(dirname "$0")/lib.sh"; read_hook_json
path="$(jf tool_input.file_path)"; cwd="$(jf cwd)"
[ -n "$path" ] || exit 0
case "$path" in
  */.orch/tasks/*/07-review-*.md|*/.orch/tasks/*/08-qa.md) ;;
  *) exit 0 ;;
esac
[ -f "$path" ] || exit 0
task="$(printf '%s' "$path" | sed -n 's#.*/\.orch/tasks/\([^/]*\)/.*#\1#p')"
file="$(basename "$path")"
verdict="$(grep -m1 -E '^(Verdict|Result):' "$path" | sed 's/^[^:]*:[[:space:]]*//')"
case "$verdict" in REJECT*|FAIL*) ;; *) exit 0 ;; esac
src="reviewer"; [ "$file" = "08-qa.md" ] && src="qa"
# Blocking findings or failures: lines marked [BLOCKING] or the Open items bullets.
findings="$(grep -E '\[BLOCKING\]' "$path" | head -5)"
[ -n "$findings" ] || findings="$(awk '/^## Open items/{f=1;next} /^## /{f=0} f && /^- /' "$path" | head -5)"
inbox="$(project_inbox "$cwd")"; [ -n "$inbox" ] || exit 0
proj="$(basename "$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || echo "$cwd")")"
append_learning "$inbox" "$src" medium "$proj" "$task" "$file: $verdict"$'\n'"$findings" "$path"
log_event LearningCaptured "" "" "$src $verdict $task/$file"
exit 0
