#!/usr/bin/env bash
# Generic event logger for the local tail pane. Records event name, agent, tool and a short detail. Local file only.
. "$(dirname "$0")/lib.sh"; read_hook_json
ev="$(jf hook_event_name)"; agent="$(jf agent_type)"; tool="$(jf tool_name)"
detail=""
case "$ev" in
  PreToolUse|PostToolUse)
    detail="$(jf tool_input.file_path)"; [ -n "$detail" ] || detail="$(jf tool_input.command | cut -c1-120)"
    [ "$tool" = "Agent" ] && detail="subagent=$(jf tool_input.subagent_type) $(jf tool_input.description)" ;;
  SubagentStart|SubagentStop) detail="agent_id=$(jf agent_id)" ;;
  Stop) detail="turn ended" ;;
esac
log_event "${ev:-?}" "$agent" "$tool" "$detail"
exit 0
