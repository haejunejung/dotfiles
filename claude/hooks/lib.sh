#!/usr/bin/env bash
# Shared helpers for hooks. Hooks must never block Claude: always exit 0, keep work tiny, write locally only.
DOT="${DOTFILES_CLAUDE:-$HOME/.claude/dotfiles}"
[ -f "$DOT/local.env" ] && . "$DOT/local.env"
MACHINE="${MACHINE_NAME:-$(hostname -s)}"
EVENT_LOG="${ORCH_EVENT_LOG:-$HOME/.claude/orch-events.jsonl}"
GLOBAL_INBOX_DIR="$DOT/learnings/inbox"

# Read stdin JSON once into $HOOK_JSON.
read_hook_json() { HOOK_JSON="$(cat 2>/dev/null || true)"; }

# jf <dotted.key> -> value (empty if missing). Uses python3; never raises.
jf() {
  printf '%s' "$HOOK_JSON" | python3 -I -c 'import sys,json
try:
    d=json.load(sys.stdin)
    for k in sys.argv[1].split("."):
        d=d[k] if isinstance(d,dict) else ""
    print(d if isinstance(d,str) else json.dumps(d))
except Exception:
    print("")' "$1" 2>/dev/null
}

# Project inbox path if the cwd's repo opted in (has .learnings/), else empty.
project_inbox() {
  local cwd="$1" root
  root="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || true)"
  [ -n "$root" ] && [ -d "$root/.learnings" ] && { mkdir -p "$root/.learnings/inbox"; echo "$root/.learnings/inbox/$MACHINE.md"; }
}

# append_learning <inbox-file> <source> <confidence> <project> <task> <text> <evidence>
append_learning() {
  local file="$1" src="$2" conf="$3" proj="$4" task="$5" text="$6" ev="$7"
  mkdir -p "$(dirname "$file")"
  [ -f "$file" ] || printf '# Learning inbox · %s\n\nAppend-only. Promote with `/learn promote` (reflector proposes, you apply).\n\n' "$MACHINE" > "$file"
  {
    printf '## %s · source=%s · confidence=%s · project=%s · task=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$src" "$conf" "${proj:-?}" "${task:--}"
    printf '%s\n' "$text"
    [ -n "$ev" ] && printf 'evidence: %s\n' "$ev"
    printf '\n'
  } >> "$file"
}

log_event() { # log_event <event> <agent> <tool> <detail>
  python3 -I -c 'import sys,json,datetime
print(json.dumps({"ts":datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),"event":sys.argv[1],"agent":sys.argv[2],"tool":sys.argv[3],"detail":sys.argv[4][:300]}))' \
    "$1" "$2" "$3" "$4" >> "$EVENT_LOG" 2>/dev/null || true
}
