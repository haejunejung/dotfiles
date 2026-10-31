#!/usr/bin/env bash
# Static verification of what install.sh created.
#   - skill symlinks are not broken
#   - SKILL.md exists and its frontmatter has name and description
#   - frontmatter name matches the folder name (WARN otherwise)
#   - files that SKILL.md references under playbooks/ references/ scripts/ assets/ exist
#   - claude/ layout: agents, roles, skills, hooks, scripts are linked, executable and registered
# Usage: ./verify.sh
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIRS=("$HOME/.claude/skills" "$HOME/.agents/skills")
fail=0

# False positives caused by example sentences in a skill body. Format "skill:referenced-path".
IGNORE_REFS=(
  "show-me-your-work:scripts/snapshot.sh"
)

bad()  { echo "FAIL  $*"; fail=1; skill_fail=1; }
warn() { echo "WARN  $*"; }
ok()   { echo "OK    $*"; }

# Print the frontmatter (between the first --- and the next ---) only
frontmatter() {
  awk 'NR==1 && $0 != "---" {exit} NR>1 && $0 == "---" {exit} NR>1 {print}' "$1"
}

check_skill_dir() { # check_skill_dir <skills dir>
  local d="$1"
  echo "== $d"
  if [ ! -d "$d" ]; then
    fail=1
    echo "FAIL  directory missing"
    return
  fi

  for link in "$d"/*; do
    [ -L "$link" ] || continue
    target="$(readlink "$link")"
    case "$target" in
      "$REPO"/*) ;;      # only links managed by this repo
      *) continue ;;
    esac
    name="$(basename "$link")"
    skill_fail=0

    if [ ! -e "$link" ]; then
      bad "$name: broken link -> $target (are submodules initialized?)"
      continue
    fi
    skill_md="$link/SKILL.md"
    if [ ! -f "$skill_md" ]; then
      bad "$name: SKILL.md missing"
      continue
    fi

    meta="$(frontmatter "$skill_md")"
    echo "$meta" | grep -q '^name:'        || bad "$name: frontmatter has no name"
    echo "$meta" | grep -q '^description:' || bad "$name: frontmatter has no description"

    fm_name="$(echo "$meta" | sed -n 's/^name:[[:space:]]*//p' | head -1 | tr -d "\"'")"
    if [ -n "$fm_name" ] && [ "$fm_name" != "$name" ]; then
      warn "$name: frontmatter name='$fm_name' differs from the folder name (check which name the agent sees)"
    fi

    # References must start a path segment; "~/.claude/dotfiles/scripts/x.sh" is not a skill-relative reference.
    missing="$(grep -oE '(^|[^/A-Za-z0-9_.-])(playbooks|references|scripts|assets)/[A-Za-z0-9._/-]+\.[A-Za-z0-9]+' "$skill_md" \
      | sed -E 's/^[^A-Za-z]//' \
      | sort -u \
      | while read -r ref; do [ -e "$link/$ref" ] || echo "$ref"; done)"

    for ig in "${IGNORE_REFS[@]}"; do
      if [ "${ig%%:*}" = "$name" ] && [ -n "$missing" ]; then
        missing="$(echo "$missing" | grep -vxF "${ig#*:}" || true)"
      fi
    done

    if [ -n "$missing" ]; then
      while read -r ref; do bad "$name: referenced file missing $ref"; done <<< "$missing"
    fi

    [ "$skill_fail" -eq 0 ] && ok "$name"
  done
}

for d in "${DIRS[@]}"; do check_skill_dir "$d"; done

# ── claude/ layout ───────────────────────────────────────────
echo "== claude layout"
skill_fail=0
for pair in \
  "$HOME/.claude/dotfiles:$REPO/claude" \
  "$HOME/.claude/CLAUDE.md:$REPO/claude/CLAUDE.md" \
  "$HOME/.claude/agents:$REPO/claude/agents" \
  "$HOME/.claude/roles:$REPO/claude/roles" \
  "$HOME/.claude/learnings:$REPO/claude/learnings"; do
  dest="${pair%%:*}" src="${pair#*:}"
  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ] && [ -e "$dest" ]; then ok "$dest"; else bad "$dest should link to $src"; fi
done

for f in "$REPO"/claude/agents/*.md; do
  n="$(basename "$f" .md)"; meta="$(frontmatter "$f")"
  echo "$meta" | grep -q "^name: $n\$"    || bad "agent $n: frontmatter name must be '$n'"
  echo "$meta" | grep -q '^description:' || bad "agent $n: description missing"
  echo "$meta" | grep -qE '^model: (sonnet|opus|haiku|fable|inherit|claude-)' || bad "agent $n: model missing or invalid"
done
for r in main pm architect orchestrator; do
  [ -f "$REPO/claude/roles/$r.md" ] && ok "role $r" || bad "role $r.md missing"
done
for s in "$REPO"/claude/hooks/*.sh "$REPO"/claude/scripts/*.sh; do
  [ -x "$s" ] || bad "not executable: $s"
  bash -n "$s" 2>/dev/null || bad "syntax error: $s"
done
python3 -I -c 'import json,sys; json.load(open(sys.argv[1]))' "$REPO/claude/settings.hooks.json" 2>/dev/null || bad "settings.hooks.json is not valid JSON"
if [ -f "$HOME/.claude/settings.json" ]; then
  grep -q '.claude/dotfiles/hooks/' "$HOME/.claude/settings.json" && ok "hooks registered in ~/.claude/settings.json" || bad "hooks not merged into ~/.claude/settings.json (run ./install.sh)"
else
  bad "~/.claude/settings.json missing"
fi
[ -f "$REPO/claude/local.env" ] && ok "claude/local.env present" || warn "claude/local.env missing (install.sh creates it from local.env.example)"

echo
if [ "$fail" -eq 0 ]; then
  echo "Static verification passed. Now confirm real behavior inside each agent."
else
  echo "There are failures. Fix the FAIL lines above first."
  exit 1
fi
