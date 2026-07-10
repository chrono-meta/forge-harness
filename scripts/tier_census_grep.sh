#!/usr/bin/env bash
# tier_census_grep.sh — word-boundary tier-reference census helper (Sonnet-Floor Doctrine).
#
# WHY (origin: fh_signal_2026-07-10_session — Sonnet full-loop probe): the naive census pattern
# `opus|sonnet|haiku|floor|tier|model:` false-positives heavily ("frontier" matches `tier`,
# "floors" prose, method-sense "model"). The probe self-corrected, but per the doctrine's own
# prescription ladder (step 1: mechanize) the discipline belongs in a script, not re-derived
# per session. Built 2026-07-10 on operator instruction (evidence-threshold overridden by
# explicit "complete it" — recorded, not silent).
#
# WHAT: emits candidate tier-reference hits with word-boundary patterns, one line per hit
# (file:line:text), for the auditor to CLASSIFY per sonnet_floor_doctrine.md's table
# (trust-floor / availability-gate / advisory / N-A). The script finds candidates; the
# classification stays a judged step with the doctrine table as its anchor.
#
# Sense-filter hints (printed, not auto-applied — de-noising must never hide a real gate):
#   - "frontier|multi-tier|C-tier|A/B-tier" → usually N/A (different axis: content/data tiers)
#   - "hub model|mental model|data model"   → usually N/A (methodology sense of "model")
#   - execution tier S/M/L/XL               → N/A (token budget, not model tier — fh_detail_protocols)
#
# Usage: bash scripts/tier_census_grep.sh <file> [file...]     Exit: 0 always (census, not gate)

set -uo pipefail

if [ $# -eq 0 ]; then
  echo "usage: bash scripts/tier_census_grep.sh <file> [file...]" >&2
  exit 0
fi

PATTERN='\b(opus|sonnet|haiku|fable)\b|\bfloor(-status|-tier|s)?\b|\btiers?\b|(^|[^a-zA-Z])model:'

for f in "$@"; do
  if [ ! -f "$f" ]; then
    echo "── $f: NOT FOUND (phantom input — check the path) ──"
    continue
  fi
  echo "── census candidates: $f ──"
  # -P where available (GNU/pcre); BSD grep on macOS supports -E word boundaries via [[:<:]] —
  # portable route: grep -nEi with \b works on GNU; on BSD use perl fallback.
  if echo x | grep -P 'x' >/dev/null 2>&1; then
    grep -nPi "$PATTERN" "$f" || echo "   (0 candidates)"
  else
    # 0-hit에도 "(0 candidates)"를 찍는다 — GNU 분기와 출력 대칭 (pmh-parity 포트가 잡은 갭, 역이식 2026-07-10)
    hits=$(perl -ne 'print "$.:$_" if /\b(opus|sonnet|haiku|fable)\b|\bfloor(-status|-tier|s)?\b|\btiers?\b|(^|[^a-zA-Z])model:/i' "$f")
    if [ -n "$hits" ]; then printf '%s\n' "$hits"; else echo "   (0 candidates)"; fi
  fi
done

cat <<'HINTS'
── classify each hit per sonnet_floor_doctrine.md (trust-floor / availability-gate / advisory / N-A) ──
   N/A sense hints (verify, don't auto-drop): frontier·C-tier·A/B-tier (content-tier axis) ·
   "hub/mental/data model" (methodology sense) · S/M/L/XL execution tier (token budget, not model).
HINTS
exit 0
