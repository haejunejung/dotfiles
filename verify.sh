#!/usr/bin/env bash
# dotfiles가 만든 스킬 symlink를 정적으로 검증한다.
#   - 링크가 깨지지 않았는지
#   - SKILL.md가 있고 frontmatter에 name, description이 있는지
#   - frontmatter name이 폴더명과 같은지 (다르면 WARN)
#   - SKILL.md가 언급하는 playbooks/ references/ scripts/ assets/ 파일이 실제로 있는지
# 사용법: ./verify.sh
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIRS=("$HOME/.claude/skills" "$HOME/.agents/skills")
fail=0

# 본문 속 예시 문장이 만든 오탐 목록. "스킬이름:참조경로" 형식.
IGNORE_REFS=(
  "show-me-your-work:scripts/snapshot.sh"
)

bad()  { echo "FAIL  $*"; fail=1; skill_fail=1; }
warn() { echo "WARN  $*"; }
ok()   { echo "OK    $*"; }

# frontmatter(첫 --- 와 다음 --- 사이)만 출력
frontmatter() {
  awk 'NR==1 && $0 != "---" {exit} NR>1 && $0 == "---" {exit} NR>1 {print}' "$1"
}

for d in "${DIRS[@]}"; do
  echo "== $d"
  if [ ! -d "$d" ]; then
    fail=1
    echo "FAIL  디렉토리 없음"
    continue
  fi

  for link in "$d"/*; do
    [ -L "$link" ] || continue
    target="$(readlink "$link")"
    case "$target" in
      "$REPO"/*) ;;      # dotfiles가 관리하는 링크만 검사
      *) continue ;;
    esac
    name="$(basename "$link")"
    skill_fail=0

    if [ ! -e "$link" ]; then
      bad "$name: 깨진 링크 -> $target (submodule 초기화 여부 확인)"
      continue
    fi
    skill_md="$link/SKILL.md"
    if [ ! -f "$skill_md" ]; then
      bad "$name: SKILL.md 없음"
      continue
    fi

    meta="$(frontmatter "$skill_md")"
    echo "$meta" | grep -q '^name:'        || bad "$name: frontmatter에 name 없음"
    echo "$meta" | grep -q '^description:' || bad "$name: frontmatter에 description 없음"

    fm_name="$(echo "$meta" | sed -n 's/^name:[[:space:]]*//p' | head -1 | tr -d "\"'")"
    if [ -n "$fm_name" ] && [ "$fm_name" != "$name" ]; then
      warn "$name: frontmatter name='$fm_name' (폴더명과 다름, 에이전트가 인식하는 이름 확인 필요)"
    fi

    missing="$(grep -oE '(playbooks|references|scripts|assets)/[A-Za-z0-9._/-]+\.[A-Za-z0-9]+' "$skill_md" \
      | sort -u \
      | while read -r ref; do [ -e "$link/$ref" ] || echo "$ref"; done)"

    for ig in "${IGNORE_REFS[@]}"; do
      if [ "${ig%%:*}" = "$name" ] && [ -n "$missing" ]; then
        missing="$(echo "$missing" | grep -vxF "${ig#*:}" || true)"
      fi
    done

    if [ -n "$missing" ]; then
      while read -r ref; do bad "$name: 참조 파일 없음 $ref"; done <<< "$missing"
    fi

    [ "$skill_fail" -eq 0 ] && ok "$name"
  done
done

echo
if [ "$fail" -eq 0 ]; then
  echo "정적 검증 통과. 이제 각 에이전트에서 실제 동작을 확인하세요."
else
  echo "실패 항목이 있습니다. 위 FAIL 줄을 먼저 해결하세요."
  exit 1
fi