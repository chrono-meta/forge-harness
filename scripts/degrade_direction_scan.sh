#!/usr/bin/env bash
# degrade_direction_scan.sh — mechanical pre-screen for the "default-toward-PASS" smell
#
# The correlated blind spot measured 2026-07-03 across 3 harnesses (qasp/the-bible/pmh):
#   "When a verdict surface cannot mechanically ground its judgment, it defaults toward
#    PASS instead of safe-fail." Same-family review (even frontier + target-tier sim)
#   shares the author's optimistic reading of that discretion and misses it; a
#   different-family auditor catches it. This script is the cheap MECHANICAL pre-screen
#   that runs BEFORE the cross-family pass — it flags the code shapes where a permissive
#   value lands on an unconstrained branch, so the reviewer's attention goes there first.
#
# IT IS A REVIEW SURFACE, NOT A HARD GATE. Grep-heuristic → false positives are expected.
# A hit means "prove this is not default-toward-PASS", not "this is a bug". It never
# blocks a commit on its own (advisory exit code). The terminal verdict is the
# cross-family adversarial review + governor source-grounding, never this scan alone.
# (Irreversibility-gate note: because it is advisory, a degraded/empty run is a no-op,
#  not a free pass — the cross-family review is the load-bearing check it feeds.)
#
# Usage:
#   bash scripts/degrade_direction_scan.sh [path ...]        # scan dirs/files (default: .)
#   git diff --name-only main..HEAD -- '*.py' | xargs bash scripts/degrade_direction_scan.sh
# Exit:  0 = no smells found; 2 = smells found (ADVISORY signal — do not hard-block on it)
set -uo pipefail

TARGETS=("$@")
[ ${#TARGETS[@]} -eq 0 ] && TARGETS=(".")

# Permissive values a verdict/gate surface must never land on by *default* / fall-through.
PASS='(True|"PASS"|'"'"'PASS'"'"'|"ALLOW"|'"'"'ALLOW'"'"'|"OK"|'"'"'OK'"'"'|"VALID"|'"'"'VALID'"'"'|"GRANTED"|'"'"'GRANTED'"'"'|"PASSED"|'"'"'PASSED'"'"'|allow|ALLOW)'

# Collect target files. Scannable = py + sh (the smell probes are Python-shaped but bash surfaces —
# incl. this gate's own pre-push/pre-commit-hook trigger category — must not be invisibly dropped).
# Anything else is tracked as UNSCANNABLE so a load-bearing surface in another language is reported
# as "not covered", never silently folded into an "advisory clean" (M#2, steel-quench 2026-07-03).
FILES=(); UNSCANNABLE=()
for t in "${TARGETS[@]}"; do
  if [ -d "$t" ]; then
    while IFS= read -r f; do FILES+=("$f"); done < <(find "$t" -type f \( -name '*.py' -o -name '*.sh' \) 2>/dev/null)
  elif [ -f "$t" ]; then
    case "$t" in
      *.py|*.sh) FILES+=("$t") ;;
      *) UNSCANNABLE+=("$t") ;;
    esac
  fi
done
if [ ${#FILES[@]} -eq 0 ]; then
  if [ ${#UNSCANNABLE[@]} -gt 0 ]; then
    echo "degrade-scan: ${#UNSCANNABLE[@]} changed file(s) are OUTSIDE the scannable set (py/sh) — NOT scanned, NOT 'clean':"
    printf '  (unscannable) %s\n' "${UNSCANNABLE[@]}"
    echo "A load-bearing surface in another language must go straight to cross-family review."
    exit 2   # advisory non-clean — an orchestrator keying on exit code must not read this as clean
  fi
  echo "degrade-scan: no scannable (py/sh) target files"; exit 0
fi

hits=0
emit() { printf '  %s:%s\n    [%s] %s\n' "$1" "$2" "$3" "$4"; hits=$((hits+1)); }

for f in "${FILES[@]}"; do
  # Probe A — except/else/finally block returning a permissive value within 2 lines.
  #   The classic "swallow the error → report success". A safe-fail returns BLOCK/None/raise.
  while IFS= read -r line; do
    ln="${line%%:*}"
    emit "$f" "$ln" "A:except/else→PASS" "permissive return on an error/fall-through branch — safe-fail must return BLOCK/None or re-raise"
  done < <(grep -nE -A2 '^[[:space:]]*(except([[:space:]][^:]*)?|else|finally)[[:space:]]*:' "$f" 2>/dev/null \
           | grep -E "return[[:space:]]+$PASS([[:space:],)]|$)" | grep -oE '^[0-9]+' | sort -u | sed 's/$/:/')

  # Probe B — dict default / setdefault to a permissive value (unknown key → PASS).
  while IFS= read -r m; do
    emit "$f" "${m%%:*}" "B:default→PASS" "unknown-key default is permissive — unenumerated case should default to safe-fail"
  done < <(grep -nE "(\.get\([^,]+,[[:space:]]*$PASS[[:space:])]|setdefault\([^,]+,[[:space:]]*$PASS[[:space:])])" "$f" 2>/dev/null)

  # Probe C — substring membership on a grounding/verdict/state line (loose match, not exact).
  #   `if tok in text` masks paid⊂prepaid / 완료⊂미완료. Exact/word-boundary is the safe form.
  while IFS= read -r m; do
    emit "$f" "${m%%:*}" "C:substring-grounding" "substring 'in' on a verdict/state/present line — use exact or word-boundary match, not containment"
  done < <(grep -nE '\b(verdict|present|ground|state|match|expected|assert)\w*\b' "$f" 2>/dev/null \
           | grep -vE ':[[:space:]]*(#|//|from |import )' | grep -vE '#[[:space:]]*noqa[:[:space:]]*degrade' \
           | grep -E '[^._a-zA-Z]in[[:space:]]' | grep -vE '\bfor\b|__contains__|not in|in \(|in \[|in \{|in range|in enumerate|in [A-Z_]+\b' \
           | grep -oE '^[0-9]+' | sed 's/$/:/')

  # Probe C2 — bare `VAR in VAR` in an if/return/assert/while context, WITHOUT a grounding keyword.
  #   Probe C is keyword-gated (low-noise) and therefore misses the doc's own headline example
  #   `tok in text` (paid⊂prepaid) when the variables aren't named verdict/state (M#4, steel-quench).
  #   C2 closes that: simple var-in-var (not a collection literal / range / for) = a likely
  #   containment check that should be exact/word-boundary if it grounds a verdict. Higher noise; advisory.
  while IFS= read -r m; do
    emit "$f" "${m%%:*}" "C2:substring-boolean" "bare 'X in Y' in if/return/assert — if this grounds a presence/verdict check, use exact/word-boundary match, not containment"
  done < <(grep -nE '^[[:space:]]*(if|elif|return|assert|while)[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]+in[[:space:]]+[A-Za-z_][A-Za-z0-9_.]*[[:space:]]*[:)]?[[:space:]]*$' "$f" 2>/dev/null \
           | grep -vE '\bfor\b|in range|in enumerate|not in' \
           | grep -vE '\b(verdict|present|ground|state|match|expected)\w*\b')

  # Probe E — negated-falsy guard returning permissive (dominance-benchmark round-2 f2 class): an error
  # SENTINEL (None / {} / "" / []) is falsy, so `if not X: return <PASS>` treats "the check errored / never
  # ran" identically to "the check ran and found nothing clean". Distinguish errored from clean before allowing.
  while IFS= read -r ln; do
    emit "$f" "$ln" "E:falsy-sentinel→PASS" "negated-falsy guard returns permissive — a falsy error sentinel (None/{}/'') masquerades as 'clean'; a gate must distinguish 'errored/absent' from 'verified clean'"
  done < <(grep -nE -A2 '^[[:space:]]*if[[:space:]]+not[[:space:]]+[A-Za-z_][A-Za-z0-9_.]*[[:space:]]*:' "$f" 2>/dev/null \
           | grep -E "return[[:space:]]+$PASS([[:space:],)]|$)" | grep -oE '^[0-9]+' | sort -u | sed 's/$/:/')

  # Probe F — positional field-select from a split result feeding a decision (round-2 c3 class): taking the
  # decision from `parts[-1]`/`parts[0]` of an attacker-influenceable split lets a crafted field (e.g. a
  # signed DENY whose free-form comment ends "::ALLOW") negate the verdict. Validate structure, don't select by position.
  if grep -qE '\.r?split\(' "$f" 2>/dev/null; then
    while IFS= read -r m; do
      emit "$f" "${m%%:*}" "F:split-positional-verdict" "decision taken by position ([-1]/[0]) from a split result — an attacker-controlled trailing/leading field can negate the verdict; validate structure, don't select by position"
    done < <(grep -nE '\[[[:space:]]*-?[01][[:space:]]*\]' "$f" 2>/dev/null \
             | grep -iE 'decision|verdict|allow|deny|approv|grant|status|result|policy')
  fi
done

echo "----"
[ ${#UNSCANNABLE[@]} -gt 0 ] && printf 'note: %s changed file(s) outside py/sh — NOT covered by this scan (send to cross-family directly).\n' "${#UNSCANNABLE[@]}"
if [ "$hits" -gt 0 ]; then
  echo "degrade-scan: $hits smell(s) — ADVISORY. Each = 'prove this is not default-toward-PASS'."
  echo "Terminal verdict = cross-family adversarial review (auto-decorrelation), not this scan."
  exit 2
fi
# Scope-honest clean message (M#2): "clean" means only "no py/sh-pattern smells in the SCANNED set" —
# it does NOT assert the changed load-bearing surface is safe (other languages, non-code surfaces,
# and the lint's own recall gaps are out of scope). The load-bearing check is the cross-family review.
echo "degrade-scan: no default-toward-PASS smells in ${#FILES[@]} scanned py/sh file(s) — does NOT cover other languages / non-code surfaces / the cross-family check (advisory)."
exit 0
