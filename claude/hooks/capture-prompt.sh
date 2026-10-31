#!/usr/bin/env bash
# UserPromptSubmit: record prompts that look like an explicit correction or standing preference.
# Only clear signals are captured, and they are marked confidence=candidate; the reflector decides.
. "$(dirname "$0")/lib.sh"; read_hook_json
prompt="$(jf prompt)"; cwd="$(jf cwd)"
[ -n "$prompt" ] || exit 0
case "$prompt" in /*) exit 0 ;; esac   # slash commands are never learnings
# English and Korean correction markers.
if printf '%s' "$prompt" | grep -qiE "(don'?t |do not |never |always |instead of |stop (doing|using)|that'?s wrong|not what i|from now on|in the future|rule:|하지 ?마|하지 ?말|대신에?|항상 |앞으로는?|틀렸|잘못됐|그렇게 하지)"; then
  inbox="$(project_inbox "$cwd")"; [ -n "$inbox" ] || inbox="$GLOBAL_INBOX_DIR/$MACHINE.md"
  proj="$(basename "$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || echo "$cwd")")"
  short="$(printf '%s' "$prompt" | tr '\n' ' ' | cut -c1-500)"
  append_learning "$inbox" user candidate "$proj" "" "$short" "user prompt, session $(jf session_id)"
  log_event LearningCaptured "" "" "user candidate -> $inbox"
fi
exit 0
