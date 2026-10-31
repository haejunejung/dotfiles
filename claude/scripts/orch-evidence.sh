#!/usr/bin/env bash
# Collect mechanical evidence for the Doc Writer into .orch/tasks/<task-id>/00-evidence/.
#   orch-evidence.sh <task-id> [base-ref] [test-command...]
# Produces: diff.stat, diff.numstat, files.txt, test-output.txt (if a test command is given or found in 05-impl-notes.md), rounds.tsv (from 00-log.md)
set -uo pipefail

id="${1:-}"; [ -n "$id" ] || { echo "usage: orch-evidence.sh <task-id> [base-ref] [test-command...]" >&2; exit 1; }
REPO="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
dir="$REPO/.orch/tasks/$id"; [ -d "$dir" ] || { echo "no such task: $dir" >&2; exit 1; }
base="${2:-$(sed -n 's/^base_ref:[[:space:]]*//p' "$dir/README.md" | head -1)}"
[ -n "$base" ] || base="main"
out="$dir/00-evidence"; mkdir -p "$out"

{
  echo "# generated $(date -u +%Y-%m-%dT%H:%M:%SZ) · base=$base · head=$(git -C "$REPO" rev-parse --short HEAD)"
  git -C "$REPO" diff --stat "$base"...HEAD
  git -C "$REPO" diff --stat HEAD   # uncommitted work, if any
} > "$out/diff.stat" 2>&1
git -C "$REPO" diff --numstat "$base"...HEAD > "$out/diff.numstat" 2>&1
{ git -C "$REPO" diff --name-only "$base"...HEAD; git -C "$REPO" diff --name-only HEAD; } | sort -u > "$out/files.txt"

shift 2 2>/dev/null || shift $# 2>/dev/null
test_cmd="$*"
if [ -z "$test_cmd" ] && [ -f "$dir/05-impl-notes.md" ]; then
  test_cmd="$(sed -n 's/^Test command:[[:space:]]*`\(.*\)`.*/\1/p' "$dir/05-impl-notes.md" | head -1)"
fi
if [ -n "$test_cmd" ]; then
  {
    echo "# $ $test_cmd"
    (cd "$REPO" && bash -c "$test_cmd") 2>&1 | tail -n 200
    echo "# exit=${PIPESTATUS[0]}"
  } > "$out/test-output.txt"
else
  echo "# no test command found; Doc Writer must report tests as not verified" > "$out/test-output.txt"
fi

[ -f "$dir/00-log.md" ] && grep -E '· G[0-9] ·' "$dir/00-log.md" | sed 's/ · /\t/g' > "$out/rounds.tsv"
echo "evidence written to $out"
ls -1 "$out"
