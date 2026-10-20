#!/usr/bin/env bash
# test_dispatch_receipt_lanes.sh — lanes for scripts/dispatch_receipt.py (governor's receipt for dispatched edit work).
# Each lane builds a throwaway git repo under mktemp. Exit: 0 all lanes pass · 1 a lane failed · 10 harness error.
# codex 2026-10-20 R1 shaped the second half: quoted paths, renames, submodules, swallowed tool errors, rewritten claims, and a
# revert probe that runs the mismatch lanes themselves against a mutant (they must go red there).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
R="$HERE/dispatch_receipt.py"
[ -r "$R" ] || { echo "HARNESS-ERROR: $R missing"; exit 10; }
command -v python3 >/dev/null || { echo "HARNESS-ERROR: python3 missing"; exit 10; }
T=$(mktemp -d) || exit 10; trap 'rm -rf "$T"' EXIT
FAIL=0
TOOL=$R
check(){ local want=$1 pat=$2; shift 2; local out rc
  out=$(python3 "$TOOL" "$@" 2>&1); rc=$?
  [ "$rc" = "$want" ] && { [ -z "$pat" ] || grep -qE -- "$pat" <<<"$out"; }; }   # here-string, not a pipe: grep -q + pipefail = SIGPIPE flip
lane(){ local name=$1; shift
  if check "$@"; then echo "  ✅ $name"; else echo "  ❌ $name — want rc=$1 /$2/"; local o; o=$(python3 "$TOOL" "${@:3}" 2>&1); sed -n '1,8s/^/      /p' <<<"$o"; FAIL=1; fi; }

mk(){ local d="$T/$1"; mkdir -p "$d"; git -C "$d" init -q; git -C "$d" config user.email t@t; git -C "$d" config user.name t
  git -C "$d" config commit.gpgsign false; echo base > "$d/base.txt"; echo old > "$d/old.txt"; git -C "$d" add base.txt old.txt
  git -C "$d" commit -qm base; echo "$d"; }

echo "── dispatch_receipt lanes ──"
A=$(mk a); echo x > "$A/a.txt"; echo y > "$A/sp ace.txt"; git -C "$A" add a.txt "sp ace.txt"; git -C "$A" commit -qm work
lane "L1 claimed = changed → match"                 0  'CLAIMED-MATCHES: 2'             "$A" HEAD~1 --claimed "a.txt,sp ace.txt"
lane "L2 claimed a path that did not change"        1  '^  b\.txt$'                     "$A" HEAD~1 --claimed "a.txt,sp ace.txt,b.txt"
lane "L3 changed a path the claim left out"         1  '^  sp ace\.txt$'                "$A" HEAD~1 --claimed "a.txt"
lane "L4 no claim: receipt only"                    0  'commits=1 paths=2'              "$A" HEAD~1
lane "L4b per-path hash line"                       0  '^  path  [0-9a-f]{16} +a\.txt$' "$A" HEAD~1
B=$(mk b)
lane "L5 nothing changed but paths claimed → rc 1"  1  'CLAIMED-NOT-CHANGED:'           "$B" HEAD --claimed "a.txt"
lane "L5b nothing changed, nothing claimed"         0  'paths=0'                        "$B" HEAD
echo dirty >> "$B/base.txt"
lane "L6 uncommitted tracked change"                1  'NOT-COMMITTED: 1'               "$B" HEAD
lane "L7 unresolvable base → harness error"         10 'HARNESS-ERROR'                  "$A" no-such-ref
lane "L8 not a directory → harness error"           10 'not a directory'                "$T/nope" HEAD
lane "L9 usage"                                     2  'usage:'                         "$A"
lane "L9b unknown option"                           2  'usage:'                         "$A" HEAD --bogus
# ── codex R1 cases ──
C=$(mk c); git -C "$C" mv old.txt new.txt; git -C "$C" commit -qm mv
lane "R1 a rename lists BOTH paths (claiming only the new one is rc 1)" 1 '^  old\.txt$' "$C" HEAD~1 --claimed "new.txt"
lane "R1b claiming both sides of the move matches"   0  'CLAIMED-MATCHES: 2'            "$C" HEAD~1 --claimed "new.txt,old.txt"
D=$(mk d); printf 'z\n' > "$D/$(printf 'nl\nname')"; git -C "$D" add -A; git -C "$D" commit -qm nl
git -C "$D" -c core.quotePath=true diff --name-only HEAD~1 HEAD > "$T/claim_quoted"     # git's own quoted spelling, taken from git
grep -qx '"nl\\nname"' "$T/claim_quoted" || { echo "HARNESS-ERROR: fixture is not git's quoted spelling: $(cat "$T/claim_quoted")"; exit 10; }
lane "R2 git's quoted spelling of a newline path is not that path" 1 'CLAIMED-NOT-CHANGED' "$D" HEAD~1 --claimed-file "$T/claim_quoted"
printf 'nl\nname\0' > "$T/claim_nul"
lane "R2b the real newline path (NUL-separated claim) matches" 0 'CLAIMED-MATCHES: 1'   "$D" HEAD~1 --claimed-file "$T/claim_nul"
lane "R3 a claim with a stray space is refused, not rewritten" 2 'leading/trailing space' "$A" HEAD~1 --claimed " a.txt,sp ace.txt"
lane "R3b an empty entry (trailing comma) is refused" 2 'empty entry'                   "$A" HEAD~1 --claimed "a.txt,sp ace.txt,"
lane "R3c a duplicate entry is refused"              2  'duplicate'                     "$A" HEAD~1 --claimed "a.txt,a.txt"
E=$(mk e); S=$(mk sub); git -C "$E" -c protocol.file.allow=always submodule add -q "$S" sm 2>/dev/null; git -C "$E" commit -qm sm
lane "R4 a submodule is shown as a submodule, not hashed as a blob" 0 '^  path  submodule [0-9a-f]{12} +sm$' "$E" HEAD~1
SIDE=$(git -C "$A" commit-tree "HEAD~1^{tree}" -p HEAD~1 -m side)      # same repo, diverged: not an ancestor of HEAD
lane "R5 base not an ancestor of head → harness error" 10 'not an ancestor'             "$A" "$SIDE"
lane "R5b (a foreign sha is unresolvable here)"      10 'HARNESS-ERROR'                 "$A" 0000000000000000000000000000000000000001

# ── codex R2 cases ──
F=$(mk f); S2=$(mk sub2); git -C "$F" -c protocol.file.allow=always submodule add -q "$S2" sm 2>/dev/null; git -C "$F" commit -qm sm
echo more > "$S2/m.txt"; git -C "$S2" add m.txt; git -C "$S2" commit -qm m; git -C "$F/sm" pull -q 2>/dev/null; git -C "$F" add sm; git -C "$F" commit -qm bump
git -C "$F" config diff.ignoreSubmodules all
lane "R6 repo config diff.ignoreSubmodules=all cannot hide a gitlink bump" 1 '^  sm$'    "$F" HEAD~1 --claimed "x.txt"
G=$(mk g); git -C "$G" update-index --assume-unchanged base.txt; echo edited >> "$G/base.txt"
lane "R7 an assume-unchanged edit makes «committed» unprovable" 1 'UNPROVABLE-CLEAN: 1'   "$G" HEAD
printf 'a.txt\n\n' > "$T/claim_dbl"
lane "R8 a doubled trailing terminator is an empty entry"   2  'empty entry'              "$A" HEAD~1 --claimed-file "$T/claim_dbl"
printf 'a.txt\n' > "$T/claim_one"
lane "R9 a duplicate across --claimed and --claimed-file is refused" 2 'across claim options' "$A" HEAD~1 --claimed "a.txt,sp ace.txt" --claimed-file "$T/claim_one"
lane "R9b … and across two --claimed options"              2  'across claim options'     "$A" HEAD~1 --claimed "a.txt" --claimed "a.txt"

# ── codex R3 cases ──
H=$(mk h); mkdir -p "$H/sub"; echo s > "$H/sub/in.txt"; git -C "$H" add sub/in.txt; git -C "$H" commit -qm sub; echo o >> "$H/old.txt"; git -C "$H" commit -qam outside
git -C "$H" config diff.relative true
lane "R10 run from a subdirectory with diff.relative=true still sees the outside change" 1 '^  old\.txt$' "$H/sub" HEAD~1 --claimed "x.txt"
I=$(mk i); echo y > "$I/z.txt"; git -C "$I" add z.txt; git -C "$I" commit -qm z
if out=$(GIT_DIR="$B/.git" GIT_WORK_TREE="$B" python3 "$R" "$I" HEAD~1 --claimed "z.txt" 2>&1) && grep -q 'CLAIMED-MATCHES: 1' <<<"$out"; then
  echo "  ✅ R11 inherited GIT_DIR/GIT_WORK_TREE do not redirect the measurement"
else echo "  ❌ R11 inherited GIT_DIR redirected the receipt"; sed -n '1,5s/^/      /p' <<<"$out"; FAIL=1; fi

# ── revert probe: neuter the claimed-vs-actual comparison; the mismatch lanes (L2, L3, L5, R1) must go RED on the mutant ──
M="$T/mut.py"; sed 's/missing, extra = sorted(claim - actual), sorted(actual - claim)/missing, extra = [], []/' "$R" > "$M"
if grep -q 'missing, extra = \[\], \[\]' "$M"; then
  TOOL=$M; red=0
  check 1 '^  b\.txt$' "$A" HEAD~1 --claimed "a.txt,sp ace.txt,b.txt" || red=$((red+1))
  check 1 '^  sp ace\.txt$' "$A" HEAD~1 --claimed "a.txt" || red=$((red+1))
  check 1 'CLAIMED-NOT-CHANGED:' "$B" HEAD --claimed "a.txt" || red=$((red+1))
  check 1 '^  old\.txt$' "$C" HEAD~1 --claimed "new.txt" || red=$((red+1))
  TOOL=$R
  if [ "$red" = 4 ]; then echo "  ✅ RV comparison off → 4/4 mismatch lanes red on the mutant"
  else echo "  ❌ RV only $red/4 mismatch lanes went red on the mutant — they do not measure the comparison"; FAIL=1; fi
else echo "  ❌ RV mutation did not apply (HARNESS-ERROR in the probe)"; FAIL=1; fi

[ "$FAIL" = 0 ] && echo "── all lanes ok ──"
exit "$FAIL"
