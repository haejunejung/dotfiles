#!/usr/bin/env bash
# Pretty-print the local hook event feed for a tail pane.
#   orch-tail.sh            follow ~/.claude/orch-events.jsonl
#   orch-tail.sh --last 50  print the last N events and exit
set -uo pipefail
. "$(dirname "$0")/../hooks/lib.sh"
LOG="$EVENT_LOG"
touch "$LOG"
fmt='import sys,json
for line in sys.stdin:
    try: e=json.loads(line)
    except Exception: continue
    t=e.get("ts","")[11:19]; ev=e.get("event","?"); ag=e.get("agent") or ""
    tool=e.get("tool") or ""; d=e.get("detail") or ""
    print(f"{t} {ev:<14} {ag:<12} {tool:<10} {d}"[:160], flush=True)'
if [ "${1:-}" = "--last" ]; then tail -n "${2:-50}" "$LOG" | python3 -I -c "$fmt"; else tail -n 20 -f "$LOG" | python3 -I -c "$fmt"; fi
