#!/usr/bin/env bash
# dotfiles installer
#   - skills/*/            : skills written in this repo (SKILL.md directly inside the folder)
#   - vendor/<repo>/...    : skills from external submodules (registered below)
#   - claude/              : Claude Code agents, roles, hooks, scripts, learnings for the orchestrated workflow
# Usage:
#   ./install.sh            # install
#   ./install.sh --dry-run  # print what would change without changing anything
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

# ── Skill directories per tool ───────────────────────────────
# Claude Code: ~/.claude/skills
# Codex CLI  : ~/.agents/skills   (not ~/.codex/skills)
TARGET_DIRS=(
  "$HOME/.claude/skills"
  "$HOME/.agents/skills"
)

# ── External (submodule) skills: "path relative to repo:link name" ──
# Each path must point at the folder that contains SKILL.md.
VENDOR_SKILLS=(
  "vendor/archify/archify:archify"
  "vendor/eli5/skills/eli5:eli5"
)

PSTACK_DIR="vendor/cursor-plugins/pstack/skills"
PSTACK_PICKS=(
  poteto-mode
  how why architect swarm arena interrogate reflect figure-it-out
  unslop technical-writing no-comments show-me-your-work
  tdd blast-radius correct
  'principle-*'
)

EMIL_SKILLS_DIR="vendor/emil-skills/skills"
EMIL_SKIP=(write-swift)    # skipped when Swift is not used; set to () to link everything

# ── Claude Code orchestration layout (claude/) ───────────────
CLAUDE_DIR="$REPO/claude"
CLAUDE_SKILLS=(orch learn report)   # claude/skills/<name> -> ~/.claude/skills/<name> (Claude only)

# ── Helpers ─────────────────────────────────────────────────
run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] $*"
  else
    "$@"
  fi
}

backup_existing() { # move a real file or folder out of the way
  local dest="$1"
  run mkdir -p "$BACKUP_DIR"
  local name
  name="$(echo "$dest" | sed "s#^$HOME/##; s#/#__#g")"
  run mv "$dest" "$BACKUP_DIR/$name"
  echo "BACKUP $dest -> $BACKUP_DIR/$name"
}

# link_path <source> <destination>: symlink any file or folder, backing up a real one in the way
link_path() {
  local src="$1" dest="$2"
  if [ ! -e "$src" ]; then
    echo "SKIP  source missing: $src" >&2
    return 0
  fi
  run mkdir -p "$(dirname "$dest")"
  if [ -L "$dest" ]; then
    if [ "$(readlink "$dest")" = "$src" ]; then
      echo "OK    $dest (already linked)"
      return 0
    fi
  elif [ -e "$dest" ]; then
    backup_existing "$dest"
  fi
  run ln -sfn "$src" "$dest"
  echo "LINK  $dest -> $src"
}

# link <skill folder> <destination>: like link_path, plus a SKILL.md sanity check
link() {
  local src="$1" dest="$2"
  if [ ! -d "$src" ]; then
    echo "SKIP  source missing: $src" >&2
    return 0
  fi
  if [ ! -f "$src/SKILL.md" ]; then
    echo "WARN  no SKILL.md (is this a skill folder?): $src" >&2
  fi
  link_path "$src" "$dest"
}

# ── 1) Submodules ───────────────────────────────────────────
if [ -f "$REPO/.gitmodules" ]; then
  run git -C "$REPO" submodule update --init --recursive
fi

# ── 2) Skills written here (skills/*/) ──────────────────────
for tool_dir in "${TARGET_DIRS[@]}"; do
  for skill in "$REPO"/skills/*/; do
    [ -d "$skill" ] || continue
    link "${skill%/}" "$tool_dir/$(basename "$skill")"
  done
done

# ── 3) External skills (vendor) ─────────────────────────────
for tool_dir in "${TARGET_DIRS[@]}"; do
  for entry in "${VENDOR_SKILLS[@]}"; do
    link "$REPO/${entry%%:*}" "$tool_dir/${entry#*:}"
  done
done

for tool_dir in "${TARGET_DIRS[@]}"; do
  for pat in "${PSTACK_PICKS[@]}"; do
    for skill in "$REPO/$PSTACK_DIR"/$pat/; do
      [ -d "$skill" ] || continue
      link "${skill%/}" "$tool_dir/$(basename "$skill")"
    done
  done
done

for tool_dir in "${TARGET_DIRS[@]}"; do
  for skill in "$REPO/$EMIL_SKILLS_DIR"/*/; do
    [ -d "$skill" ] || continue
    n="$(basename "$skill")"
    skip=0
    for s in "${EMIL_SKIP[@]}"; do [ "$s" = "$n" ] && skip=1; done
    [ "$skip" -eq 1 ] && continue
    link "${skill%/}" "$tool_dir/$n"
  done
done

# ── 4) Claude Code orchestration layout ─────────────────────
link_path "$CLAUDE_DIR"            "$HOME/.claude/dotfiles"
link_path "$CLAUDE_DIR/CLAUDE.md"  "$HOME/.claude/CLAUDE.md"
link_path "$CLAUDE_DIR/agents"     "$HOME/.claude/agents"
link_path "$CLAUDE_DIR/roles"      "$HOME/.claude/roles"
link_path "$CLAUDE_DIR/learnings"  "$HOME/.claude/learnings"
for s in "${CLAUDE_SKILLS[@]}"; do
  link "$CLAUDE_DIR/skills/$s" "$HOME/.claude/skills/$s"
done

if [ ! -f "$CLAUDE_DIR/local.env" ]; then
  run cp "$CLAUDE_DIR/local.env.example" "$CLAUDE_DIR/local.env"
  echo "INIT  $CLAUDE_DIR/local.env (edit machine-specific values; gitignored)"
fi

# Merge hook registrations into ~/.claude/settings.json. Entries that point into
# ~/.claude/dotfiles/hooks are replaced; everything else (model, other hooks) is kept.
SETTINGS="$HOME/.claude/settings.json"
if [ "$DRY_RUN" -eq 1 ]; then
  echo "[dry-run] merge $CLAUDE_DIR/settings.hooks.json into $SETTINGS"
else
  mkdir -p "$(dirname "$SETTINGS")"
  [ -f "$SETTINGS" ] && cp "$SETTINGS" "$SETTINGS.bak"
  python3 -I - "$SETTINGS" "$CLAUDE_DIR/settings.hooks.json" <<'PY'
import json, sys, os
settings_path, hooks_path = sys.argv[1], sys.argv[2]
settings = {}
if os.path.exists(settings_path):
    with open(settings_path) as f:
        settings = json.load(f)
with open(hooks_path) as f:
    ours = json.load(f)["hooks"]
marker = ".claude/dotfiles/hooks/"
def is_ours(group):
    return any(marker in h.get("command", "") for h in group.get("hooks", []))
merged = settings.get("hooks", {}) or {}
for event, groups in ours.items():
    kept = [g for g in merged.get(event, []) if not is_ours(g)]
    merged[event] = kept + groups
settings["hooks"] = merged
with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)
    f.write("\n")
print(f"MERGE {settings_path} (hooks for {', '.join(ours)})")
PY
fi

echo
echo "Done. Restart Claude Code / Codex so the skills, agents and hooks are picked up."
