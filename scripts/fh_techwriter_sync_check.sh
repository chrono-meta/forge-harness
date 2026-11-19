#!/usr/bin/env bash
# fh_techwriter_sync_check.sh [COPY_DIR] — is the published copy of ko-tech-writer still what FH exports?
#
# WHY: ko-tech-writer's canon lives here; a separate repository (fh-techwriter) carries a GENERATED copy,
# rebuilt by that repository's own `scripts/regen_from_fh.sh`. Nothing on this side noticed when the canon
# changed, so the copy could fall behind silently. That repository's `check_fh_sync.sh` compares only the
# files the copy already tracks, so a file FH ADDS to the export never shows up there.
#
# WHAT: runs FH's own `fh_module_check.py export` on THIS tree (the same command the regen script runs),
# then compares the result, file by file and in both directions, with the copy's COMMITTED tree (HEAD;
# uncommitted edits in the copy are not counted — what was pushed is what readers get):
#   DRIFT    path exists on both sides, contents differ
#   MISSING  FH exports it, the copy does not have it
#   EXTRA    the copy has it under an exported folder, FH no longer exports it
# On a difference it prints the regen command for a HUMAN to run. It never writes to, commits in or pushes
# the copy — publishing that repository stays a human step.
#
# COPY_DIR defaults to $FH_TECHWRITER_HOME, then $HOME/projects/fh-techwriter when that exists — an env var
# alone is the shape that left test_preprep_drift_anchor SKIPPED for weeks because nobody set it. It must be a
# git checkout; its origin URL is printed, so a comparison against some other clone (a lab fork) is visible.
# exit: 0 in sync · 1 differs (each file named) · 2 UNMEASURED (no copy, not a git checkout, export failed)
#   2 is never "in sync": an absent or unreadable copy has not been compared.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST=plugins/fh-commons/skills/ko-tech-writer/fh-module.yaml
COPY="${1:-${FH_TECHWRITER_HOME:-}}"
[ -z "$COPY" ] && [ -d "$HOME/projects/fh-techwriter" ] && COPY="$HOME/projects/fh-techwriter"
[ -n "$COPY" ] || { echo "UNMEASURED: no copy given (pass a checkout, set FH_TECHWRITER_HOME, or clone it to $HOME/projects/fh-techwriter) — not compared"; exit 2; }
COPY="$(cd "$COPY" 2>/dev/null && pwd)" || { echo "UNMEASURED: copy not found at ${1:-$FH_TECHWRITER_HOME} — not compared"; exit 2; }
head="$(git -C "$COPY" rev-parse --verify -q HEAD)" || { echo "UNMEASURED: $COPY is not a git checkout with a commit — not compared"; exit 2; }
# A folder INSIDE some other checkout would read that checkout's tree (cross-family R4) — the copy must be the top.
top="$(git -C "$COPY" rev-parse --show-toplevel 2>/dev/null)"; top="$(cd "$top" 2>/dev/null && pwd -P)"
[ -n "$top" ] && [ "$top" = "$(cd "$COPY" && pwd -P)" ] || { echo "UNMEASURED: $COPY is not the top of its git checkout (top: ${top:-none}) — not compared"; exit 2; }

tmp="$(mktemp -d "${TMPDIR:-/tmp}/fh_tw_sync.XXXXXX")" || { echo "UNMEASURED: no temp dir"; exit 2; }
trap 'rm -rf "$tmp"' EXIT
( cd "$ROOT" && python3 scripts/fh_module_check.py export "$MANIFEST" --out "$tmp/out" --repo . ) >"$tmp/export.log" 2>&1 || {
  tail -5 "$tmp/export.log"; echo "UNMEASURED: FH export failed — not compared"; exit 2; }
# This script compares newline-separated path lists, so a name with a newline or a tab cannot be compared
# faithfully (it would split into other paths and could even match them — cross-family R3). Refuse it.
nbad=$(cd "$tmp/out" && find . -type f \( -path $'*\n*' -o -path $'*\t*' \) | grep -c .)
[ "$nbad" -eq 0 ] || { echo "UNMEASURED: $nbad exported file name(s) contain a newline or tab — not compared"; exit 2; }
exported="$(cd "$tmp/out" && find . -type f | sed 's|^\./||' | LC_ALL=C sort)"
[ -n "$exported" ] || { echo "UNMEASURED: FH export produced no files — not compared"; exit 2; }

# The copy's side: everything committed under the folders the export owns, plus the single exported files.
roots="$(printf '%s\n' "$exported" | awk -F/ '
  /^plugins\/fh-commons\/skills\/ko-tech-writer\// { print "plugins/fh-commons/skills/ko-tech-writer"; next }
  /^\.fh-export\// { print ".fh-export"; next }
  { print }' | LC_ALL=C sort -u)"
# Read the copy's tree with its rc checked: a failed read is UNMEASURED, never "every file MISSING" (cross-family R1).
# core.quotePath=false: without it git quotes non-ASCII names, and an identical Korean-named file would show up as
# both MISSING and EXTRA (R2). A tab or newline in a name is still quoted — that errs toward DIFFERS, not IN-SYNC.
copyfiles="$(printf '%s\n' "$roots" | tr '\n' '\0' | xargs -0 git -C "$COPY" -c core.quotePath=false ls-tree -r --name-only "$head" -- 2>"$tmp/lstree.err")" || {
  head -3 "$tmp/lstree.err"; echo "UNMEASURED: could not read the copy's tree at $head — not compared"; exit 2; }
copyfiles="$(printf '%s\n' "$copyfiles" | LC_ALL=C sort -u)"

n=0; drift=0; missing=0; extra=0
while IFS= read -r p; do
  n=$((n+1))
  if ! grep -qxF -- "$p" <<< "$copyfiles"; then echo "MISSING  $p"; missing=$((missing+1)); continue; fi
  git -C "$COPY" show "$head:$p" > "$tmp/copyfile" 2>/dev/null || { echo "UNMEASURED: could not read $p from the copy at $head — not compared"; exit 2; }
  cmp -s "$tmp/copyfile" "$tmp/out/$p" || { echo "DRIFT    $p"; drift=$((drift+1)); }
done <<< "$exported"
while IFS= read -r p; do
  [ -n "$p" ] || continue
  grep -qxF -- "$p" <<< "$exported" || { echo "EXTRA    $p"; extra=$((extra+1)); }
done <<< "$copyfiles"

# No pipes into early-exit readers here or below (pipefail × SIGPIPE class lock): here-strings and bash regex.
genfile="$(git -C "$COPY" show "$head:GENERATED_FROM_FH.txt" 2>/dev/null)"
gen=""; [[ "${genfile%%$'\n'*}" =~ [0-9a-f]{40} ]] && gen="${BASH_REMATCH[0]}"
echo "fh-techwriter sync: fh=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo '?') copy=$COPY@$(git -C "$COPY" rev-parse --short "$head") origin=$(git -C "$COPY" remote get-url origin 2>/dev/null || echo none) generated_from=${gen:-unknown} exported=$n drift=$drift missing=$missing extra=$extra"
if [ $((drift+missing+extra)) -eq 0 ]; then echo "IN-SYNC"; exit 0; fi
# The comparison used THIS working tree; the regen script exports a REF. Say which tree was compared, so a
# difference that exists only here (an unmerged branch, uncommitted edits) is not "fixed" by regenerating main.
dirty=0
while IFS= read -r p; do   # an exported file that is untracked, or differs from HEAD, in this tree
  [ -e "$ROOT/$p" ] || continue   # .fh-export/* is written by the export itself; it has no source file here
  if ! git -C "$ROOT" ls-files --error-unmatch -- "$p" >/dev/null 2>&1 || ! git -C "$ROOT" diff --quiet HEAD -- "$p" 2>/dev/null; then dirty=$((dirty+1)); fi
done <<< "$exported"
echo "DIFFERS — compared this working tree (HEAD $(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo '?'), $dirty uncommitted exported file(s))."
echo "  Regenerate in the copy once the change is on origin/main (a human step; review, commit and push there yourself):"
echo "  bash \"$COPY/scripts/regen_from_fh.sh\" \"$ROOT\" origin/main"
exit 1
