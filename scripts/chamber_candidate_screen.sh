#!/usr/bin/env bash
# chamber_candidate_screen.sh — chamber-candidate discovery ENTRANCE filter (reinvention-risk first-pass).
#
# ROLE (no-reinvention — this is NOT asset-placement-gate/harness-doctor reinvented):
#   asset-placement-gate + harness-doctor are SKILLs (judged review processes run on a FINISHED asset).
#   This is a cheap MECHANICAL first-pass run on a one-line candidate SIGNAL, at the discovery entrance,
#   BEFORE an expensive chamber run. It screens, it does not adjudicate. Design home: the 2-family-verified
#   `tracks/_meta/fh_signal_2026-07-14_self-dev.md` (candidate discovery, design v2).
#
# WHAT IT IS AND IS NOT (signal v2 §설계 교훈 — do not overclaim):
#   - grep is a FIRST-PASS, not a verdict. A DUPLICATE-CANDIDATE result is a flag for HITL KILL review,
#     never an automatic KILL. grep-CLEAR does NOT mean "no reinvention" — lexical grep misses
#     semantic/renamed/capability-level duplication (the design's own evidence: chamber run #2's step-4
#     reinvention had NO lexical overlap and was caught by the in-chamber persona sim, not grep).
#   - Therefore the honest routing is: DUPLICATE-CANDIDATE → HITL KILL review · REVIEW/CLEAR → still send
#     to the chamber, where the persona sim is the BACKSTOP for the classes grep cannot see.
#   - The in-chamber Emission-Gate overlap grep (skeleton step 5) STAYS. This entrance screen is an
#     ADDITION (cheap early cull of obvious lexical dups), not a REPLACEMENT for it.
#
# DEGRADE (fail-visible, never silent-clean): if an inventory source can't be read, it says so and biases
#   toward REVIEW — it never reports CLEAR off a partial scan (that would be the silent-clean hole the
#   design warns about).
#
# Usage:  bash scripts/chamber_candidate_screen.sh "candidate name + one-line description / keywords"
#   exit 0 = screen ran (verdict in output: CLEAR|REVIEW|DUPLICATE-CANDIDATE)
#   exit 2 = harness error (no candidate text / repo not found) — NOT a clean pass

set -uo pipefail

# FH root = the script's OWN location (scripts/..), NOT the cwd's git repo. This screener scans FH's
# asset inventory; resolving FH from `git rev-parse` (cwd-dependent) meant running it from a mapped field
# repo (qasp/pmh) pointed FH at that repo → plugins/ absent → partial inventory → silent CLEAR. Anchoring
# to the script path makes the inventory cwd-independent. (Axis-2 challenger HIGH, 2026-07-14.)
FH="$(cd "$(dirname "$0")/.." && pwd)"
# assert this really is the FH root before trusting a scan off it — else fail-closed (harness error, not CLEAR)
if [ ! -d "$FH/plugins" ] || [ ! -d "$FH/knowledge/shared/harness-core" ]; then
  echo "❌ FH root not found at '$FH' (plugins/ or knowledge/shared/harness-core missing) — cannot screen. Run from the FH repo." >&2
  exit 2
fi
CAND="${*:-}"
if [ -z "$CAND" ]; then
  echo "❌ no candidate text. Usage: $0 \"name + description / keywords\"" >&2
  exit 2
fi

# --- keyword extraction: lowercase, split on non-alnum, keep tokens length>=4, drop stopwords ---
STOP='^(that|this|from|into|over|runs|when|what|will|your|there|their|then|than|with|chamber|candidate|skill|agent|tool|does|done|after|before|which|about|through)$'
KW=$(printf '%s' "$CAND" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9가-힣' ' ' | tr -s ' ' '\n' \
     | awk 'length($0)>=4' | grep -vE "$STOP" | sort -u)
NKW=$(printf '%s\n' "$KW" | grep -c . || true)
if [ "${NKW:-0}" -eq 0 ]; then
  echo "⚠️  candidate yielded 0 usable keywords → REVIEW (cannot screen; send to chamber)"
  echo "VERDICT: REVIEW"
  exit 0
fi

# --- build inventory: one line per asset = "path\tsearchable text" ---
# internal: SKILL.md (name+description), agents/*.md (first heading+desc), knowledge shared docs (filename+H1)
# tier0/1: recommended_plugins.md (official/built-in catalog) — closes the frontier-digest external-gap hole
TMP="${TMPDIR:-/tmp}/cand_inv.$$"
: > "$TMP"
INV_OK=1
_add() { # $1=label $2=file : append "label<TAB>lowercased text"
  [ -f "$2" ] || return 0
  local t; t=$(tr '[:upper:]' '[:lower:]' < "$2" | tr -c 'a-z0-9가-힣' ' ' | tr -s ' ')
  printf '%s\t%s\n' "$1" "$t" >> "$TMP"
}
# internal skills + agents — count them; the PRIMARY internal source having 0 hits = partial scan → not CLEAR
NSK=$(find "$FH/plugins" -path '*/skills/*/SKILL.md' 2>/dev/null | grep -c . || true)
NAG=$(find "$FH/plugins" -path '*/agents/*.md' 2>/dev/null | grep -c . || true)
while IFS= read -r f; do _add "skill:$(basename "$(dirname "$f")")" "$f"; done < <(find "$FH/plugins" -path '*/skills/*/SKILL.md' 2>/dev/null)
while IFS= read -r f; do _add "agent:$(basename "$f" .md)" "$f"; done < <(find "$FH/plugins" -path '*/agents/*.md' 2>/dev/null)
# knowledge shared docs (shipped subset)
while IFS= read -r f; do _add "knowledge:$(basename "$f" .md)" "$f"; done < <(find "$FH/knowledge/shared/harness-core" "$FH/knowledge/shared/rules" -name '*.md' 2>/dev/null)
# tier 0/1 catalog
CAT="$FH/knowledge/shared/plugin-catalog/recommended_plugins.md"
if [ -f "$CAT" ]; then _add "tier0/1:official-catalog" "$CAT"; else INV_OK=0; fi
# completeness guard: the PRIMARY internal inventory (skills+agents) must be present. If it's empty, the
# scan is partial and MUST NOT be able to report CLEAR (silent-clean hole — Axis-2 challenger HIGH).
if [ "${NSK:-0}" -eq 0 ] || [ "${NAG:-0}" -eq 0 ]; then INV_OK=0; fi

NASSET=$(grep -c . "$TMP" 2>/dev/null); NASSET=${NASSET:-0}
if [ "$NASSET" -eq 0 ]; then
  echo "❌ inventory empty (could not read plugins/knowledge) → fail-closed REVIEW (NOT clean)"
  echo "VERDICT: REVIEW"
  rm -f "$TMP"; exit 0
fi

# --- score: for each asset, count how many candidate keywords appear; overlap = hits / NKW ---
BEST_ASSET=""; BEST_HITS=0
while IFS=$'\t' read -r label text; do
  hits=0
  while IFS= read -r w; do
    case " $text " in *" $w "*) hits=$((hits+1));; esac
  done <<< "$KW"
  if [ "$hits" -gt "$BEST_HITS" ]; then BEST_HITS=$hits; BEST_ASSET=$label; fi
done < "$TMP"
rm -f "$TMP"

# overlap ratio as integer percent (bash-3.2, no bc)
PCT=$(( BEST_HITS * 100 / NKW ))

echo "── chamber candidate screen ──"
echo "candidate keywords ($NKW): $(printf '%s ' $KW)"
echo "top asset overlap: ${BEST_ASSET:-none}  —  $BEST_HITS/$NKW keywords ($PCT%)"
[ "$INV_OK" -eq 0 ] && echo "⚠️  tier0/1 catalog unreadable — external-ecosystem overlap NOT screened (recall gap; bias toward chamber)"

# thresholds (lexical, deliberately conservative — see header): DUPLICATE needs BOTH >=50% AND >=3 absolute
# hits (a 3-hit floor stops a single generic keyword tripping DUPLICATE at small NKW — Axis-2 challenger
# LOW/MED). REVIEW at >=25%. CLEAR only when the scan was COMPLETE (INV_OK=1) — a partial scan can never
# report CLEAR (silent-clean invariant); it degrades to REVIEW instead.
if [ "$PCT" -ge 50 ] && [ "$BEST_HITS" -ge 3 ]; then
  echo "VERDICT: DUPLICATE-CANDIDATE — strong lexical overlap with '${BEST_ASSET}' ($BEST_HITS hits)."
  echo "  → HITL review for KILL (first-pass flag, NOT an auto-KILL). If overlap is superficial, route to chamber."
elif [ "$PCT" -ge 25 ] || [ "$INV_OK" -eq 0 ]; then
  REASON="partial overlap with '${BEST_ASSET}'"
  [ "$INV_OK" -eq 0 ] && REASON="inventory scan INCOMPLETE (cannot certify CLEAR) — biasing to chamber"
  echo "VERDICT: REVIEW — $REASON. Send to chamber; persona sim adjudicates semantic/capability reinvention."
else
  echo "VERDICT: CLEAR (lexical) — no strong internal/catalog overlap, and inventory scan was complete."
  echo "  ⚠️  lexical-CLEAR ≠ no-reinvention: semantic/renamed/capability-level duplication is invisible to grep."
  echo "      The chamber persona sim is the backstop for those classes (design v2)."
fi
exit 0
