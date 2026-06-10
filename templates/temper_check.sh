#!/usr/bin/env bash
# temper_check.sh — Wave-T (Temper) step T-1: complexity delta of a quench.
# Measures how much complexity a steel-quench ADDED to a markdown asset
# (pre-quench baseline → post-convergence). It is a MEASUREMENT, not a detector
# (don't-overbuild guard: no judgment engine here — T-3 verdict is human/LLM).
#
# Usage:  temper_check.sh <repo> <file-rel-path> <pre-quench-ref> [<post-ref>]
#   <post-ref> default = working tree.
# See plugins/fh-meta/skills/steel-quench/SKILL.md §Wave-T.
set -euo pipefail

repo="${1:?repo path}"; file="${2:?file rel path}"; pre="${3:?pre-quench ref}"; post="${4:-}"

metrics() {  # reads text on stdin → "lines sections steps tables fences crossrefs"
  local t prose; t="$(cat)"
  # sections/steps/tables count PROSE only — lines inside ``` fences are code
  # (bash comments `# ...` would otherwise inflate Δsections; found run #4, install-wizard)
  prose="$(printf '%s\n' "$t" | awk '/^[[:space:]]*```/{f=!f;next} !f')"
  local lines sections steps tables fences crossrefs
  lines=$(printf '%s\n' "$t" | wc -l | tr -d ' ')
  sections=$(printf '%s\n' "$prose" | grep -cE '^#{1,6} ' || true)
  steps=$(printf '%s\n' "$prose" | grep -cE '^[[:space:]]*([0-9]+\.|[-*] )' || true)
  tables=$(printf '%s\n' "$prose" | grep -cE '^\|' || true)
  fences=$(( $(printf '%s\n' "$t" | grep -c '```' || true) / 2 ))
  crossrefs=$(printf '%s\n' "$t" | grep -oE '\]\(|\[\[' | wc -l | tr -d ' ')
  echo "$lines $sections $steps $tables $fences $crossrefs"
}

pre_txt=$(git -C "$repo" show "$pre:$file")
if [ -n "$post" ]; then post_txt=$(git -C "$repo" show "$post:$file"); else post_txt=$(cat "$repo/$file"); fi

read -r l0 s0 p0 t0 f0 x0 <<<"$(printf '%s' "$pre_txt"  | metrics)"
read -r l1 s1 p1 t1 f1 x1 <<<"$(printf '%s' "$post_txt" | metrics)"

printf '\n=== Wave-T complexity delta — %s ===\n' "$file"
printf 'baseline: %s   post: %s\n\n' "$pre" "${post:-<working>}"
printf '%-12s %6s %6s %8s\n' metric pre post Δ
for row in "lines $l0 $l1" "sections $s0 $s1" "steps $p0 $p1" "tables $t0 $t1" "fences $f0 $f1" "cross-refs $x0 $x1"; do
  set -- $row; printf '%-12s %6s %6s %+8d\n' "$1" "$2" "$3" "$(( $3 - $2 ))"
done

dx=$(( x1 - x0 )); dp=$(( p1 - p0 ))
printf '\n-- T-3 heuristic flags (review, not auto-reject) --\n'
[ "$dx" -gt "$dp" ] && printf '  ⚠ Δcross-refs(%+d) > Δsteps(%+d): quench added wiring, not function?\n' "$dx" "$dp" || true
[ "$(( s1 - s0 ))" -gt 0 ] && printf '  ⚠ %+d new section(s): confirm each fixes a flaw, not just defends a Wave finding\n' "$(( s1 - s0 ))" || true
printf '\nNext: run harness-doctor on post asset for absolute tier (T-2), then record τ verdict (PASS / FAIL + named construct)\n'
