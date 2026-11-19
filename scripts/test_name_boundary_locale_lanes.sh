#!/usr/bin/env bash
# test_name_boundary_locale_lanes.sh — "$NAME" directly followed by a non-ASCII character.
#
# Under a UTF-8 locale on macOS (ko_KR.UTF-8 and en_US.UTF-8 both; measured 2026-11-13 with
# /bin/bash 3.2 and Homebrew bash 5), bash reads the following multibyte character's bytes as part
# of the variable name: "lease «$LEASE" + "»" written together → `LEASE<bytes>: unbound variable`, rc 127. Only LC_ALL=C
# is safe. Linux CI never shows it, so the static lane (B1–B3) is what keeps it fixed there.
#
#   B1  scanner red on a planted  "$V" + "»" written together (known-positive)
#   B2  scanner green on          "${V}»"      (known-negative)
#   B3  every tracked shell file (*.sh + shebang shell files) has 0 code-line hits
#   B4  behaviour: /bin/bash + ko_KR.UTF-8 runs the pr_merge_verified lanes (lease path S1–S3)
#       to rc 0 with no "unbound variable" — only where that locale exists, else a named SKIP
#       (a SKIP is not a pass). B4c checks the locale really triggers the defect (control).
. "$(dirname "${BASH_SOURCE[0]}")/fixture_guard_lib.sh"   # scrub inherited GIT_* env first (#1088)
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
SCAN=scripts/shell_name_boundary_scan.sh
P=0; F=0; K=0
ok()  { echo "  ✅ $*"; P=$((P+1)); }
bad() { echo "  ❌ $*"; F=$((F+1)); }
skip(){ echo "  ⏭️  SKIP $* (not a pass)"; K=$((K+1)); }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT

printf '#!/usr/bin/env bash\necho "lease \302\253$LEASE\302\273"\n' > "$T/pos.sh"
printf '#!/usr/bin/env bash\necho "lease \302\253${LEASE}\302\273"\n' > "$T/neg.sh"
printf '#!/usr/bin/env bash\necho "start\n# $C\302\273 inside a string\n"\n' > "$T/hash.sh"

out=$(bash "$SCAN" --nonascii-only "$T/pos.sh"); rc=$?
{ [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'pos.sh:2'; } && ok "B1 planted unbraced V + » → hit at pos.sh:2, rc 1" || bad "B1 rc=$rc out=$out"

out=$(bash "$SCAN" --nonascii-only "$T/neg.sh"); rc=$?
[ "$rc" -eq 0 ] && ok "B2 \"\${V}»\" → 0 hits, rc 0" || bad "B2 rc=$rc out=$out"
out=$(bash "$SCAN" --nonascii-only "$T/hash.sh"); rc=$?
[ "$rc" -eq 1 ] && ok "B2h a «#» line inside a multi-line string is still scanned (it runs) → hit" || bad "B2h rc=$rc out=$out"
out=$(bash "$SCAN" --nonascii-only 2>&1); rc=$?
[ "$rc" -eq 2 ] && ok "B2e the mode flag with no files → rc 2, never «0 hits»" || bad "B2e rc=$rc out=$out"

# B3's corpus: `git ls-files` in a checkout, `find` where there is no checkout. This suite SHIPS, and
# the tree an npm consumer receives has no .git — measured 2026-11-16 in the extracted npm pack
# (clean-room audit round 9), where the two `git ls-files` calls printed a fatal each and the lane
# then read `files=0 rc=123` and went red THREE times about a scanner that is sound. The real corpus
# is the whole point of B3 (the header says so: the static lane is what keeps this fixed on Linux),
# so it falls back to a file walk rather than folding to a pass or skipping the lane.
# 🟥 `--is-inside-work-tree` is the WRONG test here and a blind reader of this change caught it: an
# extracted tarball under someone's node_modules is inside THEIR work tree, so `git ls-files` would
# answer with their repo's files and B3 would scan a corpus that is not this package's. The test is
# therefore "this directory IS the top of a checkout".
if [ "$(git rev-parse --show-toplevel 2>/dev/null)" = "$PWD" ]; then
  corpus=checkout
  sh_files=$(git ls-files '*.sh'); gl1=$?
  all_files=$(git ls-files); gl2=$?
  if [ "$gl1" -ne 0 ] || [ "$gl2" -ne 0 ]; then
    corpus=BROKEN
    bad "B3 git ls-files failed inside a checkout (rc $gl1/$gl2) — file list incomplete, so B3 measured nothing"
  fi
else
  corpus=walk
  # no .git: list the tree itself. Prune the directories a packed install carries that are not this
  # repo's own shell code, so the count means the same thing it means in a checkout.
  sh_files=$(find . -type d \( -name node_modules -o -name .git \) -prune -o -type f -name '*.sh' -print | sed 's|^\./||')
  all_files=$(find . -type d \( -name node_modules -o -name .git \) -prune -o -type f -print | sed 's|^\./||')
fi
if [ "$corpus" != BROKEN ]; then
files=$(printf '%s\n' "$sh_files"; printf '%s\n' "$all_files" | grep -v '\.sh$' | while IFS= read -r f; do
  [ -f "$f" ] && head -1 "$f" | grep -qE '^#!.*(bash|/sh)( |$)' && printf '%s\n' "$f"; done)
n=$(printf '%s\n' "$files" | grep -c .)
if [ "$n" -le 100 ]; then
  # a working file list that is this short is not this repo's shell set, so the lane has no corpus to
  # judge — named, and not a pass.
  skip "B3 — only $n shell files found via $corpus; too few to be this repo's shell set, so nothing was scanned"
else
  out=$(printf '%s\n' "$files" | tr '\n' '\0' | xargs -0 bash "$SCAN" --nonascii-only); rc=$?
  [ "$rc" -eq 0 ] && ok "B3 $n shell files ($corpus) → 0 code-line hits" \
    || bad "B3 files=$n rc=$rc ($corpus) — brace them as \${NAME}:"$'\n'"$(printf '%s' "$out" | grep '🟥' | head -20)"
fi
fi

LOCALES=$(locale -a 2>/dev/null)   # captured first: grep -q under pipefail would SIGPIPE locale -a into a false SKIP
if [ -x /bin/bash ] && printf "%s\n" "$LOCALES" | grep -iE '^ko_KR\.utf-?8$' >/dev/null; then
  shape=$(printf 'set -u; V=ok; echo "$V\302\273"')   # built from bytes so B3 does not flag this file
  c=$(env LANG=ko_KR.UTF-8 LC_ALL=ko_KR.UTF-8 /bin/bash -c "$shape" 2>&1); crc=$?
  if [ "$crc" -ne 0 ]; then
    ok "B4c control: the unbraced shape dies under /bin/bash + ko_KR.UTF-8 (rc $crc)"
    mkdir -p "$T/pin" && ln -s /bin/bash "$T/pin/bash"   # the lanes call PATH «bash» — pin it to /bin/bash too
    o=$(env PATH="$T/pin:$PATH" LANG=ko_KR.UTF-8 LC_ALL=ko_KR.UTF-8 /bin/bash scripts/test_pr_merge_verified_lanes.sh 2>&1); r=$?
    { [ "$r" -eq 0 ] && ! grep -qE 'unbound variable|바인딩 해제' <<<"$o"; } \
      && ok "B4 pr_merge_verified lanes under /bin/bash + ko_KR.UTF-8 → rc 0, no unbound variable" \
      || bad "B4 rc=$r"$'\n'"$(printf '%s' "$o" | grep -E 'unbound|바인딩|❌' | head -5)"
  else
    skip "B4 — this /bin/bash does not show the defect under ko_KR.UTF-8 (control rc 0), so B4 would prove nothing"
  fi
else
  skip "B4 — no /bin/bash or no ko_KR.UTF-8 locale here"
fi

echo "PASS $P · FAIL $F · SKIP $K"
[ "$F" -eq 0 ]
