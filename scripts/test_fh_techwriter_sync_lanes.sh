#!/usr/bin/env bash
# test_fh_techwriter_sync_lanes.sh — known pairs for scripts/fh_techwriter_sync_check.sh
# The copy under test is built from FH's own export of THIS tree and committed to a scratch git repo, so
# the in-sync arm and every differing arm share one source; each differing arm changes exactly one thing.
# Nothing here touches a real fh-techwriter checkout (HOME is a scratch dir and FH_TECHWRITER_HOME is unset).
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/fixture_guard_lib.sh"   # scrub inherited GIT_* env first (#1088)
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHK="$ROOT/scripts/fh_techwriter_sync_check.sh"
T="$(mktemp -d "${TMPDIR:-/tmp}/fh_tw_lanes.XXXXXX")"; trap 'rm -rf "$T"' EXIT
FAILED=0; PASSED=0
_pass() { echo "✅ $1"; PASSED=$((PASSED+1)); }
_fail() { echo "❌ $1"; FAILED=1; }
G() { git -c user.name=lane -c user.email=lane@example.invalid -c commit.gpgsign=false "$@"; }
_run() {  # $1=label $2=expected rc $3=expected line (fixed string, '' = none) ; rest = command
  local label="$1" erc="$2" eline="$3"; shift 3
  local out rc; out="$(env -u FH_TECHWRITER_HOME HOME="$T/home" "$@" 2>&1)"; rc=$?
  if [ "$rc" != "$erc" ]; then _fail "$label — rc $rc, expected $erc"; printf '%s\n' "$out" | tail -5 | sed 's/^/     /'; return; fi
  if [ -n "$eline" ] && ! grep -qF -- "$eline" <<< "$out"; then
    _fail "$label — rc $rc ok, but no line [$eline]"; printf '%s\n' "$out" | tail -5 | sed 's/^/     /'; return; fi
  _pass "$label (rc $rc${eline:+, $eline})"
}
mkdir -p "$T/home"
command -v python3 >/dev/null 2>&1 || { echo "NOT EXERCISED: python3 missing (exit 2, not a pass)"; exit 2; }

# A copy repo made from the export of THIS tree.
_mkcopy() {  # $1=dir [$2=FH root to export from, default this tree]
  ( cd "${2:-$ROOT}" && python3 scripts/fh_module_check.py export plugins/fh-commons/skills/ko-tech-writer/fh-module.yaml --out "$1" --repo . ) >"$T/export.log" 2>&1 \
    || { echo "NOT EXERCISED: FH export failed in this tree"; tail -5 "$T/export.log"; exit 2; }
  printf 'generated from forge-harness %s (test)\n' "$(printf '%040d' 0)" > "$1/GENERATED_FROM_FH.txt"
  echo "repo-owned" > "$1/README.md"
  G -C "$1" init -q && G -C "$1" add -A && G -C "$1" commit -qm seed
}
SK=plugins/fh-commons/skills/ko-tech-writer

C1="$T/c1"; _mkcopy "$C1"
_run "S1 copy equals FH's export → IN-SYNC"                         0 "IN-SYNC" bash "$CHK" "$C1"

C2="$T/c2"; _mkcopy "$C2"; echo "edited in the copy" >> "$C2/$SK/SKILL.md"; G -C "$C2" commit -qam drift
_run "S2 one exported file differs → DRIFT names it"                1 "DRIFT    $SK/SKILL.md" bash "$CHK" "$C2"

C3="$T/c3"; _mkcopy "$C3"; G -C "$C3" rm -q "$SK/fixtures/known_positive.md"; G -C "$C3" commit -qm missing
_run "S3 a file FH exports is absent in the copy → MISSING"         1 "MISSING  $SK/fixtures/known_positive.md" bash "$CHK" "$C3"

C4="$T/c4"; _mkcopy "$C4"; echo old > "$C4/$SK/retired.md"; G -C "$C4" add "$SK/retired.md"; G -C "$C4" commit -qm extra
_run "S4 the copy keeps a file FH no longer exports → EXTRA"        1 "EXTRA    $SK/retired.md" bash "$CHK" "$C4"

C5="$T/c5"; _mkcopy "$C5"; echo "uncommitted" >> "$C5/$SK/SKILL.md"
_run "S5 an uncommitted edit in the copy is not what readers get → IN-SYNC" 0 "IN-SYNC" bash "$CHK" "$C5"

C6="$T/c6"; _mkcopy "$C6"; echo "repo-owned change" >> "$C6/README.md"; G -C "$C6" commit -qam readme
_run "S6 a change outside the exported paths is not drift → IN-SYNC" 0 "IN-SYNC" bash "$CHK" "$C6"

# The real trigger: FH's canon changes, the copy does not. A scratch clone of THIS tree's committed state
# plus the two files under test (they may not be committed yet), then one edit to the canon there.
F="$T/fh"; git clone -q --local --no-hardlinks "$ROOT" "$F" 2>/dev/null || { echo "NOT EXERCISED: cannot clone this tree"; exit 2; }
cp "$CHK" "$F/scripts/"
# The copy is built from the SAME clone before the edit, so only the edit can differ (cross-family R1: a copy
# built from this working tree made S7 depend on uncommitted edits elsewhere).
C7="$T/c7"; _mkcopy "$C7" "$F"
_run "S7a control: the clone before the edit → IN-SYNC"             0 "IN-SYNC" bash "$F/scripts/fh_techwriter_sync_check.sh" "$C7"
echo "a new line in the canon" >> "$F/$SK/SKILL_detail.md"
_run "S7 FH's canon changed, the copy did not → DRIFT, regen command shown" 1 "regen_from_fh.sh" bash "$F/scripts/fh_techwriter_sync_check.sh" "$C7"
_run "S7b … and it names the file, and says 1 uncommitted exported file" 1 "DRIFT    $SK/SKILL_detail.md" bash "$F/scripts/fh_techwriter_sync_check.sh" "$C7"
_run "S7c … the summary says what was compared"                     1 "1 uncommitted exported file(s)" bash "$F/scripts/fh_techwriter_sync_check.sh" "$C7"
# A non-ASCII exported name (this is a Korean writing skill) must compare as itself, not as a quoted path (R2).
F2="$T/fh2"; git clone -q --local --no-hardlinks "$ROOT" "$F2" 2>/dev/null; cp "$CHK" "$F2/scripts/"
echo "예시" > "$F2/$SK/fixtures/예시_샘플.md"; G -C "$F2" add "$SK/fixtures/예시_샘플.md"; G -C "$F2" commit -qm hangul
C9="$T/c9"; _mkcopy "$C9" "$F2"
_run "S8 a Korean-named exported file, identical on both sides → IN-SYNC" 0 "IN-SYNC" bash "$F2/scripts/fh_techwriter_sync_check.sh" "$C9"
# A newline in an exported name cannot be compared on newline-separated lists → UNMEASURED, never IN-SYNC (R3).
F3="$T/fh3"; git clone -q --local --no-hardlinks "$ROOT" "$F3" 2>/dev/null; cp "$CHK" "$F3/scripts/"
nl="$F3/$SK/fixtures/a
b.md"; echo x > "$nl"; G -C "$F3" add -- "$nl"; G -C "$F3" commit -qm newline
_run "U6 an exported name with a newline → UNMEASURED" 2 "contain a newline or tab" bash "$F3/scripts/fh_techwriter_sync_check.sh" "$C1"
# A newline in a DIRECTORY name, not just a file name (R4).
F4="$T/fh4"; git clone -q --local --no-hardlinks "$ROOT" "$F4" 2>/dev/null; cp "$CHK" "$F4/scripts/"
nd="$F4/$SK/fixtures/d
e"; mkdir -p "$nd"; echo x > "$nd/f.md"; G -C "$F4" add -- "$nd/f.md"; G -C "$F4" commit -qm newline-dir
_run "U7 an exported DIRECTORY name with a newline → UNMEASURED" 2 "contain a newline or tab" bash "$F4/scripts/fh_techwriter_sync_check.sh" "$C1"
# A folder inside another checkout (here: C1's skill folder) must not be read as that checkout (R4).
_run "U8 the copy path is a subfolder of a checkout → UNMEASURED" 2 "is not the top of its git checkout" bash "$CHK" "$C1/$SK"
# An unreadable copy tree must not read as «every file MISSING» (cross-family R1).
C8="$T/c8"; _mkcopy "$C8"; tobj=$(G -C "$C8" rev-parse "HEAD^{tree}"); rm -f "$C8/.git/objects/${tobj:0:2}/${tobj:2}"
_run "U5 the copy's tree object is unreadable → UNMEASURED, not MISSING" 2 "UNMEASURED: could not read the copy's tree" bash "$CHK" "$C8"

# UNMEASURED arms — none of them may read as in sync.
_run "U1 no copy anywhere → UNMEASURED"                             2 "UNMEASURED" bash "$CHK"
_run "U2 copy path does not exist → UNMEASURED"                     2 "UNMEASURED" bash "$CHK" "$T/nope"
mkdir -p "$T/plain"; cp -R "$C1/." "$T/plain/"; rm -rf "$T/plain/.git"
_run "U3 copy is not a git checkout → UNMEASURED"                   2 "UNMEASURED" bash "$CHK" "$T/plain"
E="$T/fh_broken"; git clone -q --local --no-hardlinks "$ROOT" "$E" 2>/dev/null; cp "$CHK" "$E/scripts/"
printf 'not: [a manifest\n' > "$E/$SK/fh-module.yaml"
_run "U4 FH export fails → UNMEASURED, not IN-SYNC"                 2 "UNMEASURED: FH export failed" bash "$E/scripts/fh_techwriter_sync_check.sh" "$C1"

# Default location — an env var nobody sets is how a sibling anchor stayed SKIPPED for weeks.
mkdir -p "$T/home/projects"; cp -R "$C1" "$T/home/projects/fh-techwriter"
_run "D1 no argument, no env → falls back to \$HOME/projects/fh-techwriter" 0 "/home/projects/fh-techwriter@" bash "$CHK"
_run "D2 the env var wins over the default"                         1 "DRIFT    $SK/SKILL.md" env FH_TECHWRITER_HOME="$C2" bash "$CHK"

# Writes nothing to the copy.
before="$(cd "$C2" && git status --porcelain; git rev-parse HEAD)"
env -u FH_TECHWRITER_HOME HOME="$T/home" bash "$CHK" "$C2" >/dev/null 2>&1
after="$(cd "$C2" && git status --porcelain; git rev-parse HEAD)"
[ "$before" = "$after" ] && _pass "W1 the check leaves the copy's HEAD and status unchanged" || _fail "W1 the check changed the copy"

echo "──────────────────────────────────────────────"
if [ "$FAILED" -ne 0 ]; then echo "FH-TECHWRITER SYNC LANES: FAIL ($PASSED passed)"; exit 1; fi
echo "FH-TECHWRITER SYNC LANES: PASS ($PASSED/$PASSED)"; exit 0
