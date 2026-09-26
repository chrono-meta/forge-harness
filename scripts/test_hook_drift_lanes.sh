#!/usr/bin/env bash
# test_hook_drift_lanes.sh — lanes for scripts/hook_drift_check.sh and its consumer, ④-e of
# scripts/session_close_check.sh. Fixtures only (mktemp): never reads or writes the operator's
# real ~/.claude or this repo's gitignored settings.
#
# The defect these lanes pin (2026-09-26): ④-e treated «a SubagentStop hook exists» as «the tally
# is measured». An install still carrying the pre-2026-09-25 INLINE hook passed that test while
# over-counting. The revert probe at the end puts the presence grep back and requires the lane to
# go red on exactly that fixture — otherwise this file would be green whether or not the fix exists.
#
# Runs under bash 3.2 (/bin/bash) and bash 5.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
SUBJ="$ROOT/scripts/hook_drift_check.sh"
CLOSE="$ROOT/scripts/session_close_check.sh"
T="$(mktemp -d 2>/dev/null || mktemp -d -t hookdrift)"
[ -n "$T" ] && [ -d "$T" ] || { echo "HARNESS-ERROR: mktemp failed"; exit 2; }
trap 'chmod -R u+rw "$T" 2>/dev/null; rm -rf "$T"' EXIT
pass=0; fail=0
chk() { if [ "$1" -eq 0 ]; then echo "  ✅ $2"; pass=$((pass+1)); else echo "  ❌ $2"; fail=$((fail+1)); fi; }

[ -f "$SUBJ" ] || { echo "HARNESS-ERROR: subject missing: $SUBJ"; exit 2; }
PY="$(command -v python3 2>/dev/null || echo /usr/bin/python3)"

mkdir -p "$T/tpl"
cp "$ROOT"/templates/*.json "$T/tpl/" || { echo "HARNESS-ERROR: cannot copy templates"; exit 2; }

# ── fixtures ──
# (a) CURRENT: the template's own SubagentStop block, byte-for-byte
"$PY" - "$ROOT/templates/subagent-tally-hook.json" "$T/current.json" <<'PY' || { echo "HARNESS-ERROR: fixture build"; exit 2; }
import json, sys
d = json.load(open(sys.argv[1]))
json.dump({"hooks": d["hooks"]}, open(sys.argv[2], "w"))
PY
# (b) STALE: the pre-2026-09-25 inline form (date-only append, no script)
cat > "$T/old_inline.json" <<'JSON'
{"hooks":{"SubagentStop":[{"matcher":"","hooks":[{"type":"command","command":"bash -c 'HUB=\"${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel)}\"; T=\"$HUB/tracks/_meta/.subagent_dispatch_tally\"; printf \"%s\\n\" \"$(date +%Y-%m-%d)\" >> \"$T\"; exit 0'","timeout":5}]}]}}
JSON
# (c) matcher drift: same command, different matcher
"$PY" - "$T/current.json" "$T/matcher.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1])); d["hooks"]["SubagentStop"][0]["matcher"] = "general-purpose"
json.dump(d, open(sys.argv[2], "w"))
PY
# (d) unrelated SubagentStop hook only → ABSENT, not STALE (same event is not the same hook)
echo '{"hooks":{"SubagentStop":[{"matcher":"","hooks":[{"type":"command","command":"echo hi"}]}]}}' > "$T/unrelated.json"
# (e) malformed JSON → UNKNOWN
echo '{"hooks": {"SubagentStop": [' > "$T/broken.json"
# (f) template form AND the old inline form installed side by side — CC runs BOTH, old behaviour lives
"$PY" - "$T/current.json" "$T/old_inline.json" "$T/both.json" <<'PY'
import json, sys
cur = json.load(open(sys.argv[1])); old = json.load(open(sys.argv[2]))
cur["hooks"]["SubagentStop"][0]["hooks"] += old["hooks"]["SubagentStop"][0]["hooks"]
json.dump(cur, open(sys.argv[3], "w"))
PY
# (g) an installed hook entry with no command — unidentifiable, so not evidence of absence
echo '{"hooks":{"SubagentStop":[{"matcher":"","hooks":[{"type":"command"}]}]}}' > "$T/nocmd.json"

v() { bash "$SUBJ" --settings "$1" --templates "$T/tpl" --only subagent_tally_hook.sh --verdict 2>/dev/null; }
vr() { bash "$SUBJ" --settings "$1" --templates "$T/tpl" --only subagent_tally_hook.sh --verdict >/dev/null 2>&1; echo $?; }

echo "── verdicts (known pair + the two degrade cases) ──"
[ "$(v "$T/current.json")" = CURRENT ];     chk $? "template-identical hook → CURRENT"
[ "$(vr "$T/current.json")" = 0 ];          chk $? "  … rc 0"
[ "$(v "$T/old_inline.json")" = STALE ];    chk $? "old inline hook → STALE (the defect: presence grep called this installed)"
[ "$(vr "$T/old_inline.json")" = 1 ];       chk $? "  … rc 1"
[ "$(v "$T/matcher.json")" = STALE ];       chk $? "same command, different matcher → STALE"
[ "$(v "$T/unrelated.json")" = ABSENT ];    chk $? "unrelated SubagentStop hook → ABSENT (event match is not identity match)"
[ "$(v "$T/nonexistent.json")" = ABSENT ];  chk $? "no settings file → ABSENT"
[ "$(v "$T/broken.json")" = UNKNOWN ];      chk $? "malformed settings → UNKNOWN (not folded into CURRENT)"
[ "$(vr "$T/broken.json")" = 3 ];           chk $? "  … rc 3"
if [ "$(id -u)" != 0 ]; then
  cp "$T/current.json" "$T/noread.json"; chmod 000 "$T/noread.json"
  [ "$(v "$T/noread.json")" = UNKNOWN ];    chk $? "unreadable settings (mode 000) → UNKNOWN even though its content is CURRENT"
else
  echo "  ⏭️  unreadable lane skipped (running as root — mode 000 is readable; not a pass)"
fi
[ "$(bash "$SUBJ" --settings "$T/current.json" --templates "$T/tpl" --only no_such_hook.sh --verdict 2>/dev/null)" = UNKNOWN ]
chk $? "--only with no matching template entry → UNKNOWN (nothing compared is not CURRENT)"
[ "$(bash "$SUBJ" --settings "$T/current.json" --templates "$T/empty_tpl" --verdict 2>/dev/null)" = UNKNOWN ]
chk $? "no templates found → UNKNOWN"
bash "$SUBJ" --settings "" >/dev/null 2>&1; [ $? -eq 2 ]; chk $? "empty --settings path refused (usage rc 2)"
tbl=$(bash "$SUBJ" --settings "$T/old_inline.json" --templates "$T/tpl" 2>/dev/null)
printf '%s\n' "$tbl" | grep -q '^STALE	SubagentStop	.*re-merge needed'; chk $? "table names the STALE hook and says re-merge"
printf '%s\n' "$tbl" | grep -q 'MODE_D_ONLY not compared'; chk $? "private-path Mode D block is reported as not compared (not silently dropped)"

# ── consumer: ④-e of session_close_check.sh, run on a scratch root ──
mk_root() {  # $1 = root dir, $2 = settings fixture, $3 = close-check script to install
  mkdir -p "$1/scripts" "$1/templates" "$1/.claude"
  cp "$SUBJ" "$1/scripts/"; cp "$3" "$1/scripts/session_close_check.sh"; cp "$T/tpl/"*.json "$1/templates/"
  cp "$2" "$1/.claude/settings.json"
}
# capture first, filter second — a pipe here would let the checker's own failure hide behind grep/head
e_line() { local _o; _o=$(bash "$1/scripts/session_close_check.sh" "$1" 2>&1); awk '/④-e/ && n<3 {print; n++}' <<<"$_o"; }
echo "── duplicate install · malformed entry (cross-family 2026-09-26) ──"
[ "$(v "$T/both.json")" = STALE ]; chk $? "template + old inline installed together → STALE (both run; was CURRENT via any())"
_dup=$(bash "$SUBJ" --settings "$T/both.json" --templates "$T/tpl" --only subagent_tally_hook.sh 2>/dev/null)
printf '%s\n' "$_dup" | grep -q '중복 설치'
chk $? "  … says duplicate install (remove the old entry)"
[ "$(v "$T/nocmd.json")" = UNKNOWN ]; chk $? "installed entry without a command → UNKNOWN (형식 불량), not ABSENT"
# revert probes on the subject itself — each mutation must be confirmed applied, then flip its lane
sed 's/if exact and len(related) <= 1 and len(exact) == 1:/if exact:  # MUTANT-ANY/' "$SUBJ" > "$T/mut_any.sh"
grep -q 'MUTANT-ANY' "$T/mut_any.sh"; chk $? "revert probe (any): mutation applied"
[ "$(bash "$T/mut_any.sh" --settings "$T/both.json" --templates "$T/tpl" --only subagent_tally_hook.sh --verdict 2>/dev/null)" = CURRENT ]
chk $? "revert probe (any): old any() rule calls the duplicate install CURRENT → the STALE lane would be RED"
sed 's/    if ev in inst_bad:/    if False:  # MUTANT-NOBAD/' "$SUBJ" > "$T/mut_bad.sh"
grep -q 'MUTANT-NOBAD' "$T/mut_bad.sh"; chk $? "revert probe (malformed): mutation applied"
[ "$(bash "$T/mut_bad.sh" --settings "$T/nocmd.json" --templates "$T/tpl" --only subagent_tally_hook.sh --verdict 2>/dev/null)" = ABSENT ]
chk $? "revert probe (malformed): without the guard the entry folds to ABSENT → the UNKNOWN lane would be RED"

echo "── consumer ④-e ──"
mk_root "$T/r_old" "$T/old_inline.json" "$CLOSE"
out=$(e_line "$T/r_old")
printf '%s\n' "$out" | grep -q 'NOT MEASURED — 옛 훅'; chk $? "old inline hook → ④-e says NOT MEASURED (옛 훅, re-merge)"
mk_root "$T/r_cur" "$T/current.json" "$CLOSE"
out=$(e_line "$T/r_cur")
printf '%s\n' "$out" | grep -q 'NOT MEASURED'; [ $? -ne 0 ]; chk $? "current hook → ④-e measured (control: the lane can go green)"
mk_root "$T/r_miss" "$T/current.json" "$CLOSE"; rm -f "$T/r_miss/scripts/hook_drift_check.sh"
out=$(e_line "$T/r_miss")
printf '%s\n' "$out" | grep -q 'NOT MEASURED — could not determine'; chk $? "checker missing → NOT MEASURED (not a pass)"

# ── revert probe: put the presence grep back; the old-inline lane must go RED ──
echo "── revert probe ──"
"$PY" - "$CLOSE" "$T/mutant_close.sh" <<'PY'
import re, sys
s = open(sys.argv[1], encoding="utf-8").read()
start = s.index("HOOK_OK=0\nHOOK_STATE=UNKNOWN")
end = s.index("esac\n", s.index("case \"$HOOK_STATE\" in\n  (STALE)")) + len("esac\n")
mut = ('HOOK_OK=0\nif [ -f "$FH/.claude/settings.json" ]; then\n'
       '  grep -q \'"SubagentStop"\' "$FH/.claude/settings.json" 2>/dev/null && HOOK_OK=1\nfi\n'
       '# MUTANT-PRESENCE-GREP\n')
open(sys.argv[2], "w", encoding="utf-8").write(s[:start] + mut + s[end:])
PY
grep -q 'MUTANT-PRESENCE-GREP' "$T/mutant_close.sh"; chk $? "mutation applied (control for the probe itself)"
mk_root "$T/r_mut" "$T/old_inline.json" "$T/mutant_close.sh"
out=$(e_line "$T/r_mut")
printf '%s\n' "$out" | grep -q 'NOT MEASURED'; [ $? -ne 0 ]
chk $? "with the presence grep restored, the old inline hook is treated as measured → the consumer lane above would be RED"

echo
if [ "$fail" -eq 0 ]; then echo "HOOK-DRIFT LANES: PASS ($pass/$pass)"; exit 0; fi
echo "HOOK-DRIFT LANES: FAIL ($fail failed, $pass passed)"; exit 1
