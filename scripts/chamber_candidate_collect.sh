#!/usr/bin/env bash
# chamber_candidate_collect.sh — chamber candidate discovery: 6-source converge → dedup → rank → screen.
#
# The second half of the discovery entrance (the first half = chamber_candidate_screen.sh, the reinvention
# first-pass). Design home: tracks/_meta/fh_signal_2026-07-14_self-dev.md (design v2, 2-family verified).
#
# WHAT IT DOES: pulls candidate signals from the 6 sources, deduplicates the same gap arriving multiple
# ways (2-family finding: harvest-loop/fh_signal/UAP observe the SAME session → triple-listing), ranks by
# source-diversity + frequency, and runs each survivor through the reinvention screener. Output = a ranked
# candidate queue for the operator's HITL "run the chamber?" decision (judged uncertainty/failure-cost
# filters stay with the human — this tool does the mechanizable converge/dedup/rank/screen).
#
# CANDIDATE-EMISSION CONVENTION (why a convention, not source-specific parsing): the 2-family review
# flagged per-source parsing as fragile/hand-wave. So a source declares a candidate with ONE robust line:
#     CHAMBER-CANDIDATE: <one-line description of the capability/project to incubate>
# Any of the 6 sources adds this line when it surfaces something chamber-worthy. Sources adopt it
# incrementally — until they do, the queue is honestly SPARSE (the design's "6-source volume = n=0,
# measured only after wiring"; this tool IS that wiring, and its first run measures the volume).
#
# NOT MECHANIZED HERE (stays judged/HITL, by design): uncertainty + failure-cost filters (operator judges
# the ranked survivors); chamber injection (goal-quench budget gate + HITL). This tool ranks; it does not
# admit. A high rank is a suggestion, never an auto-run.
#
# Usage:  bash scripts/chamber_candidate_collect.sh [--min-jaccard N]   (default 50)
#   exit 0 = ran (ranked queue on stdout; empty queue is a valid honest result)
#   exit 2 = harness error (FH root not found)

set -uo pipefail

FH="$(cd "$(dirname "$0")/.." && pwd)"
if [ ! -d "$FH/tracks/_meta" ] || [ ! -d "$FH/plugins" ]; then
  echo "❌ FH root not found at '$FH' — run from the FH repo." >&2
  exit 2
fi
SCREEN="$FH/scripts/chamber_candidate_screen.sh"
MINJ=50
[ "${1:-}" = "--min-jaccard" ] && MINJ="${2:-50}"
case "$MINJ" in ''|*[!0-9]*) echo "❌ --min-jaccard must be an integer 0-100 (got '$MINJ')" >&2; exit 2 ;; esac

WORK="${TMPDIR:-/tmp}/cand_collect.$$"
# fail-CLOSED on workdir failure (Axis-2 challenger MED): an unwritable TMPDIR must NOT masquerade as the
# design's valid "honest-empty queue" — a genuine infra failure and "no markers surfaced" are otherwise
# indistinguishable. Route infra failure to exit 2 (harness error), never to green-empty.
mkdir -p "$WORK" 2>/dev/null || { echo "❌ cannot create workdir under '${TMPDIR:-/tmp}' — cannot collect (NOT an empty queue)" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
RAW="$WORK/raw"; : > "$RAW" 2>/dev/null || { echo "❌ cannot write workfile (NOT an empty queue)" >&2; exit 2; }

# --- LAYER 1: 6-source converge. Each source = a label + a glob; grep the convention line. ---
# (source label · file glob) — sources that don't exist yet simply contribute nothing (fail-visible below).
_pull() { # $1=source-label  $2..=files
  local label="$1"; shift
  local f
  for f in "$@"; do
    [ -f "$f" ] || continue
    # convention line: "CHAMBER-CANDIDATE: <desc>" (case-insensitive marker, desc after the colon)
    grep -inE '^[[:space:]]*CHAMBER-CANDIDATE:' "$f" 2>/dev/null \
      | sed -E 's/^[0-9]+:[[:space:]]*CHAMBER-CANDIDATE:[[:space:]]*//I' \
      | while IFS= read -r desc; do
          [ -n "$desc" ] && printf '%s\t%s\n' "$label" "$desc" >> "$RAW"
        done
  done
}
SRC_SEEN=0
for spec in \
  "harness-doctor:$FH/tracks/_meta/*harness_doctor*.md" \
  "harvest-loop:$FH/tracks/_audit/*.md" \
  "fh-signal:$FH/tracks/_meta/fh_signal_*.md" \
  "field-harvest:$FH/tracks/_contrib/*.md" \
  "frontier-digest:$FH/tracks/_meta/frontier_digest_*.md" \
  "uap:$FH/tracks/_meta/user_adaptation_profile.md" ; do
  label="${spec%%:*}"; glob="${spec#*:}"
  # word-split the glob deliberately (globbing); nullglob-safe via the -f check in _pull
  files=$(ls $glob 2>/dev/null || true)
  [ -n "$files" ] && SRC_SEEN=$((SRC_SEEN+1))
  # shellcheck disable=SC2086
  _pull "$label" $files
done

NRAW=$(grep -c . "$RAW" 2>/dev/null); NRAW=${NRAW:-0}
echo "── chamber candidate collect ──"
echo "sources present: $SRC_SEEN/6 · raw candidate markers found: $NRAW"
if [ "$NRAW" -eq 0 ]; then
  echo "queue EMPTY — no 'CHAMBER-CANDIDATE:' markers in any source yet (convention not adopted / nothing surfaced)."
  echo "  This is an honest result, not an error: the discovery volume is n=0 until sources emit the marker."
  echo "  (Add 'CHAMBER-CANDIDATE: <desc>' to a harness-doctor / fh_signal / frontier-digest / harvest entry.)"
  exit 0
fi

# --- keyword signature per candidate (for dedup) ---
STOP='^(that|this|from|into|over|when|what|will|your|there|their|then|than|with|chamber|candidate|skill|agent|tool|does|done|after|before|which|about|through)$'
_sig() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9가-힣' ' ' | tr -s ' ' '\n' \
         | awk 'length($0)>=4' | grep -vE "$STOP" | sort -u; }
# kill-side signature for the seen-filter: keeps 2+ char tokens (a slug's meaningful short tokens like
# "qa"/"ui" are dropped by _sig's ≥4 filter → an all-short slug yields an EMPTY sig → kkn=0 → the old
# match never fired → a KILLed candidate re-entered the queue SILENTLY, Axis-2 MED-3b). Drops stopwords only.
_ksig() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9가-힣' ' ' | tr -s ' ' '\n' \
          | awk 'length($0)>=2' | grep -vE "$STOP" | sort -u; }

# --- LAYER 2: dedup by greedy jaccard clustering ---
# cluster files: $WORK/cluster.N holds "source<TAB>desc" lines; $WORK/sig.N holds the union keyword sig.
NC=0
idx=0
while IFS=$'\t' read -r label desc; do
  idx=$((idx+1))
  _sig "$desc" > "$WORK/candsig.$idx"
  merged=0
  c=1
  while [ "$c" -le "$NC" ]; do
    inter=$(comm -12 "$WORK/sig.$c" "$WORK/candsig.$idx" 2>/dev/null | grep -c . || true)
    union=$(sort -u "$WORK/sig.$c" "$WORK/candsig.$idx" 2>/dev/null | grep -c . || true)
    jac=0; [ "${union:-0}" -gt 0 ] && jac=$(( inter * 100 / union ))
    if [ "$jac" -ge "$MINJ" ]; then
      printf '%s\t%s\n' "$label" "$desc" >> "$WORK/cluster.$c"
      sort -u "$WORK/sig.$c" "$WORK/candsig.$idx" > "$WORK/sig.$c.tmp" && mv "$WORK/sig.$c.tmp" "$WORK/sig.$c"
      merged=1; break
    fi
    c=$((c+1))
  done
  if [ "$merged" -eq 0 ]; then
    NC=$((NC+1))
    printf '%s\t%s\n' "$label" "$desc" > "$WORK/cluster.$NC"
    cp "$WORK/candsig.$idx" "$WORK/sig.$NC"
  fi
done < "$RAW"

# --- seen-filter: pull already-KILLed candidates from the G4 run ledger so a re-listed marker for a
# candidate the chamber already killed does NOT re-enter the main queue (the run-#3 real-use gap). It is
# EXCLUDED from the ranked queue but SURFACED in a trailing section (re-emit trigger visibility — a KILL
# is revisitable once its measured observation lands, so we don't silently erase it). Degrade: no ledger
# → no seen-filter (fail-visible; equals the pre-seen behavior, safe). ---
LEDGER="$FH/tracks/_chamber/INDEX.md"
KILLED="$WORK/killed"; : > "$KILLED"
if [ -f "$LEDGER" ]; then
  # KILL rows: a run-log table data row (`| #N | date | candidate | VERDICT | ... |`) whose VERDICT
  # field ($5) says KILL. Scope the KILL test to the verdict field — NOT a whole-line grep, which would
  # match "kill" inside "skill" in any row's carry-text (Axis-2 HIGH-1: an EMIT row folding a sliver
  # "into goal-quench skill" would be misread as KILL). Candidate = $4; strip backticks/asterisks/space.
  awk -F'|' '$0 ~ /^\| *#/ && NF>=5 && toupper($5) ~ /KILL/ {print $4}' "$LEDGER" 2>/dev/null \
    | sed 's/[`*]//g; s/^ *//; s/ *$//' | grep -v '^$' >> "$KILLED"
fi
NKILL=$(grep -c . "$KILLED" 2>/dev/null); NKILL=${NKILL:-0}
SEENOUT="$WORK/seen_out"; : > "$SEENOUT"

# --- LAYER 2: rank each cluster = source-diversity*2 + frequency; then screen for reinvention ---
RANKED="$WORK/ranked"; : > "$RANKED"
c=1
while [ "$c" -le "$NC" ]; do
  freq=$(grep -c . "$WORK/cluster.$c" 2>/dev/null); freq=${freq:-0}
  ndiv=$(cut -f1 "$WORK/cluster.$c" | sort -u | grep -c . || true)
  srcs=$(cut -f1 "$WORK/cluster.$c" | sort -u | paste -sd, -)
  rep=$(head -1 "$WORK/cluster.$c" | cut -f2-)
  score=$(( ndiv * 2 + freq ))
  # seen-filter: does this candidate match an already-KILLed ledger entry? Two decorrelated tests, either
  # sufficient: (1) kill-name keyword recall ≥60% (the common multi-token case); (2) normalized-substring
  # fallback — the flattened slug (alnum-only, ≥5 chars) appearing in the flattened candidate — which
  # closes the all-short-token silent-re-entry hole (MED-3b) that recall alone leaves open. Residual
  # (documented, accepted): a paraphrased re-listing (router→routing) can still under-recall (MED-4), and
  # a generic slug can over-exclude — but over-exclusion is VISIBLE in the SEEN-KILLED section (operator
  # catches a wrong match), whereas silent re-entry was invisible. Visible-imprecise ≻ silent-miss.
  if [ "$NKILL" -gt 0 ]; then
    _ksig "$rep" > "$WORK/repsig"
    repflat=$(printf '%s' "$rep" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9')
    seen_match=""
    while IFS= read -r kname; do
      [ -z "$kname" ] && continue
      _ksig "$kname" > "$WORK/ksig"
      kkn=$(grep -c . "$WORK/ksig" 2>/dev/null || true); kkn=${kkn:-0}
      matched=0; [ "$kkn" -gt 0 ] && matched=$(comm -12 "$WORK/ksig" "$WORK/repsig" 2>/dev/null | grep -c . || true)
      kpct=0; [ "$kkn" -gt 0 ] && kpct=$(( matched * 100 / kkn ))
      kflat=$(printf '%s' "$kname" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9')
      if [ "$kkn" -gt 0 ] && [ "$kpct" -ge 60 ]; then seen_match="$kname"; break; fi
      if [ "${#kflat}" -ge 5 ] && printf '%s' "$repflat" | grep -qF "$kflat"; then seen_match="$kname"; break; fi
    done < "$KILLED"
    if [ -n "$seen_match" ]; then
      printf '%s\t%s\n' "$seen_match" "$rep" >> "$SEENOUT"
      c=$((c+1)); continue
    fi
  fi
  # reinvention first-pass on the representative description. Capture BOTH the verdict AND the matched
  # anchor the screener already emits ("top asset overlap: X") so a DUPLICATE-CANDIDATE is ACTIONABLE
  # ("DUP:skill:goal-quench") instead of a uniform non-discriminating flag (Axis-2 challenger Axis-5).
  verdict="?"
  if [ -x "$SCREEN" ] || [ -f "$SCREEN" ]; then
    sout=$(bash "$SCREEN" "$rep" 2>/dev/null)
    verdict=$(printf '%s\n' "$sout" | grep -oE 'VERDICT: [A-Z-]+' | head -1 | sed 's/VERDICT: //')
    [ -z "$verdict" ] && verdict="?"
    if [ "$verdict" = "DUPLICATE-CANDIDATE" ]; then
      anchor=$(printf '%s\n' "$sout" | grep -oE 'top asset overlap: [^ ]+' | head -1 | sed 's/top asset overlap: //')
      [ -n "$anchor" ] && verdict="DUP:$anchor"
    fi
  fi
  printf '%03d\t%s\t%s\t%s\t%s\n' "$score" "$ndiv" "$srcs" "$verdict" "$rep" >> "$RANKED"
  c=$((c+1))
done

echo "deduped candidates: $NC (from $NRAW raw markers)"
echo ""
printf '%-5s  %-6s  %-24s  %-18s  %s\n' "SCORE" "SRCS" "SOURCES" "REINVENTION" "CANDIDATE"
printf '%-5s  %-6s  %-24s  %-18s  %s\n' "-----" "------" "------------------------" "------------------" "---------"
sort -rn "$RANKED" | while IFS=$'\t' read -r score ndiv srcs verdict rep; do
  # drop leading zeros for display
  printf '%-5d  %-6d  %-24s  %-18s  %s\n' "$((10#$score))" "$ndiv" "$srcs" "$verdict" "$rep"
done
echo ""
echo "NOTE: SCORE = source-diversity×2 + frequency. REINVENTION is a first-pass flag (DUPLICATE-CANDIDATE"
echo "= HITL KILL review, not auto-drop). Uncertainty/failure-cost stay JUDGED — operator picks which"
echo "survivors actually enter the chamber (goal-quench budget gate + HITL). This tool ranks; it never admits."

# seen-filter trailing section: candidates the G4 ledger already KILLed are shown here (NOT in the ranked
# queue) so a re-listed marker does not silently re-enter the chamber, yet the KILL stays visible (a KILL
# is revisitable once its re-emit trigger lands — see the run's EMISSION_VERDICT for that condition).
if [ -s "$SEENOUT" ]; then
  echo ""
  echo "SEEN-KILLED — excluded from the queue (G4 ledger $LEDGER already KILLed these):"
  while IFS=$'\t' read -r kn rep; do
    [ -z "$rep" ] && continue
    echo "  · \"$rep\"  ↔ killed as \"$kn\"  (재등재 스킵; re-emit only when that run's trigger condition is met)"
  done < "$SEENOUT"
elif [ ! -f "$LEDGER" ]; then
  echo ""
  echo "SEEN-FILTER: skipped — no G4 ledger at $LEDGER (fail-visible; no seen-exclusion applied this run)."
fi
exit 0
