#!/usr/bin/env bash
# predelete_check.sh — Destructive-Op Gate step 1: enumerate what branch deletion would lose.
# Class: measured (mechanical enumeration) — the verdicts feed the gate's judged recovery step.
# Usage: predelete_check.sh <repo-path> [<base-ref>=origin/main]
# For every remote branch except the base: commits absent from base + paths absent from base.
#   SAFE   — fully merged (0 commits off base)
#   CHECK  — commits off base but 0 unique paths: content may still be NEWER than base on shared
#            files (e.g. an unmerged session card) — needs a content-direction look before delete
#   REVIEW — unique paths exist: recover/integrate BEFORE any deletion
# Exit 1 when any REVIEW exists (blocks a scripted delete chain).
set -u
repo="${1:?repo path}"; base="${2:-origin/main}"
cd "$repo" || exit 2
git fetch origin --quiet 2>/dev/null || true
fail=0
for b in $(git branch -r | grep -vE "origin/(main|HEAD)" | sed 's|origin/||' | tr -d ' '); do
  n=$(git log --oneline "$base..origin/$b" 2>/dev/null | wc -l | tr -d ' ')
  uniq=$(comm -23 <(git ls-tree -r --name-only "origin/$b" 2>/dev/null | sort) \
                  <(git ls-tree -r --name-only "$base" | sort) | wc -l | tr -d ' ')
  if [ "$uniq" -gt 0 ]; then
    echo "REVIEW  $b — unique paths: $uniq, commits off base: $n → recover/integrate BEFORE delete"
    fail=1
  elif [ "$n" -gt 0 ]; then
    echo "CHECK   $b — $n commits off base, 0 unique paths → verify content superseded (newer-version-on-shared-file risk; tip: compare tip date vs base coverage)"
  else
    echo "SAFE    $b — fully merged"
  fi
done
echo "--"
echo "Gate order: enumerate -> recover -> destroy. REVIEW blocks; CHECK needs a judged look; only then delete."
exit $fail
