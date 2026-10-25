#!/usr/bin/env bash
# dotfiles 스킬 설치 스크립트
#   - skills/*/            : 직접 만든 스킬 (SKILL.md가 폴더 바로 아래에 있음)
#   - vendor/<repo>/...    : 외부 submodule 안의 스킬 (아래 VENDOR_SKILLS에 등록)
# 사용법:
#   ./install.sh            # 설치
#   ./install.sh --dry-run  # 실제 변경 없이 무엇을 할지만 출력
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

# ── 스킬을 연결할 도구별 디렉토리 ─────────────────────────────
# Claude Code: ~/.claude/skills
# Codex CLI  : ~/.agents/skills   (~/.codex/skills 아님)
TARGET_DIRS=(
  "$HOME/.claude/skills"
  "$HOME/.agents/skills"
)

# ── 외부(submodule) 스킬 목록: "repo 기준 상대경로:링크이름" ──
# SKILL.md가 들어있는 폴더를 가리켜야 합니다.
VENDOR_SKILLS=(
  "vendor/archify/archify:archify"
  "vendor/eli5/skills/eli5:eli5"
)

PSTACK_DIR="vendor/cursor-plugins/pstack/skills"
PSTACK_PICKS=(
  poteto-mode
  how why architect swarm arena interrogate reflect figure-it-out
  unslop technical-writing no-comments show-me-your-work
  'principle-*'
)

# ── 유틸 ───────────────────────────────────────────────────
run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] $*"
  else
    "$@"
  fi
}

# link <원본> <대상>
link() {
  local src="$1" dest="$2"

  if [ ! -d "$src" ]; then
    echo "SKIP  원본 없음: $src" >&2
    return 0
  fi
  if [ ! -f "$src/SKILL.md" ]; then
    echo "WARN  SKILL.md 없음 (스킬 폴더가 맞는지 확인): $src" >&2
  fi

  run mkdir -p "$(dirname "$dest")"

  if [ -L "$dest" ]; then
    # 이미 같은 곳을 가리키면 그대로 둠
    if [ "$(readlink "$dest")" = "$src" ]; then
      echo "OK    $dest (이미 연결됨)"
      return 0
    fi
  elif [ -e "$dest" ]; then
    # 실제 파일/폴더가 있으면 백업 (skills 폴더 밖으로 옮겨서 스킬로 오인되지 않게 함)
    run mkdir -p "$BACKUP_DIR"
    local name
    name="$(echo "$dest" | sed "s#^$HOME/##; s#/#__#g")"
    run mv "$dest" "$BACKUP_DIR/$name"
    echo "BACKUP $dest -> $BACKUP_DIR/$name"
  fi

  run ln -sfn "$src" "$dest"
  echo "LINK  $dest -> $src"
}

# ── 1) submodule 초기화 ────────────────────────────────────
if [ -f "$REPO/.gitmodules" ]; then
  run git -C "$REPO" submodule update --init --recursive
fi

# ── 2) 직접 만든 스킬 (skills/*/) ──────────────────────────
for tool_dir in "${TARGET_DIRS[@]}"; do
  for skill in "$REPO"/skills/*/; do
    [ -d "$skill" ] || continue
    link "${skill%/}" "$tool_dir/$(basename "$skill")"
  done
done

# ── 3) 외부 스킬 (vendor) ──────────────────────────────────
for tool_dir in "${TARGET_DIRS[@]}"; do
  for pat in "${PSTACK_PICKS[@]}"; do
    for skill in "$REPO/$PSTACK_DIR"/$pat/; do
      [ -d "$skill" ] || continue
      link "${skill%/}" "$tool_dir/$(basename "$skill")"
    done
  done
done

echo
echo "완료. Claude Code / Codex를 새로 시작하면 스킬이 인식됩니다."