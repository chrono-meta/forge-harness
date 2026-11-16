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

sh_files=$(git ls-files '*.sh') || bad "B3 git ls-files '*.sh' failed — file list incomplete"
all_files=$(git ls-files) || bad "B3 git ls-files failed — file list incomplete"
files=$(printf '%s\n' "$sh_files"; printf '%s\n' "$all_files" | grep -v '\.sh$' | while IFS= read -r f; do
  [ -f "$f" ] && head -1 "$f" | grep -qE '^#!.*(bash|/sh)( |$)' && printf '%s\n' "$f"; done)
n=$(printf '%s\n' "$files" | grep -c .)
out=$(printf '%s\n' "$files" | tr '\n' '\0' | xargs -0 bash "$SCAN" --nonascii-only); rc=$?
{ [ "$rc" -eq 0 ] && [ "$n" -gt 100 ]; } && ok "B3 $n tracked shell files → 0 code-line hits" \
  || bad "B3 files=$n rc=$rc — brace them as \${NAME}:"$'\n'"$(printf '%s' "$out" | grep '🟥' | head -20)"

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
