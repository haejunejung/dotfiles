#!/usr/bin/env bash
# Sync the global learnings that live in the dotfiles repo.
#   learn-sync.sh pull   fast-forward the dotfiles repo (quiet, never blocks on failure)
#   learn-sync.sh push   commit claude/learnings/** and push
set -uo pipefail
DOT="${DOTFILES_CLAUDE:-$HOME/.claude/dotfiles}"
REPO="$(cd -P "$DOT" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null || true)"   # -P resolves the ~/.claude/dotfiles symlink
[ -n "$REPO" ] || { echo "dotfiles repo not found via $DOT" >&2; exit 1; }

case "${1:-}" in
  pull)
    if git -C "$REPO" diff --quiet && git -C "$REPO" diff --cached --quiet; then
      timeout 15 git -C "$REPO" pull --ff-only --quiet 2>/dev/null || echo "learn-sync: pull skipped (offline or diverged)" >&2
    else
      echo "learn-sync: pull skipped (dotfiles has local changes)" >&2
    fi ;;
  push)
    cd "$REPO"
    git add claude/learnings
    if git diff --cached --quiet; then echo "nothing to sync"; exit 0; fi
    git commit -q -m "learn: sync global learnings from $(hostname -s)" && git push -q && echo "pushed"
    ;;
  *) echo "usage: learn-sync.sh pull|push" >&2; exit 1 ;;
esac
