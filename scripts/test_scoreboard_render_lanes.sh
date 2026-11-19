#!/usr/bin/env bash
# test_scoreboard_render_lanes.sh — known pairs for scripts/scoreboard_render.py
# Every case builds its own records in scratch git repos with a bare «remote», so «pushed» is real.
# The two the scoreboard exists for: a planted UNSEALED result must not appear, and a planted NULL must appear.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/fixture_guard_lib.sh"   # scrub inherited GIT_* env first (#1088)
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
R="$ROOT/scripts/scoreboard_render.py"
T="$(mktemp -d "${TMPDIR:-/tmp}/fh_sb_lanes.XXXXXX")"; trap 'rm -rf "$T"' EXIT
FAILED=0; PASSED=0
_pass() { echo "✅ $1"; PASSED=$((PASSED+1)); }
_fail() { echo "❌ $1"; FAILED=1; }
command -v python3 >/dev/null 2>&1 || { echo "NOT EXERCISED: python3 missing (exit 2, not a pass)"; exit 2; }
G() { git -c user.name=lane -c user.email=lane@example.invalid -c commit.gpgsign=false "$@"; }
TS=1700000000
C() {  # commit in repo $1 with message $2 at a strictly increasing time
  TS=$((TS+60)); GIT_AUTHOR_DATE="@$TS +0000" GIT_COMMITTER_DATE="@$TS +0000" G -C "$1" commit -qm "$2"
}
mkrepo() {  # $1 name -> work tree $T/$1 with remote $T/$1.git
  G init -q --bare "$T/$1.git"; G clone -q "$T/$1.git" "$T/$1" 2>/dev/null
  echo seed > "$T/$1/README"; G -C "$T/$1" add README; C "$T/$1" seed; G -C "$T/$1" push -q origin HEAD:main 2>/dev/null
}
sha() { G -C "$1" rev-parse HEAD; }

mkrepo a; A="$T/a"
# sealed WIN: prereg pushed, then result pushed
echo "prereg one" > "$A/p1.md"; G -C "$A" add p1.md; C "$A" p1; S1=$(sha "$A"); G -C "$A" push -q origin HEAD:main
printf '| arm | k |\n| bare | 2/10 |\n| tool | 9/10 |\n' > "$A/r1.md"; G -C "$A" add r1.md; C "$A" r1; G -C "$A" push -q origin HEAD:main
# planted NULL, sealed: NO-DIFFERENCE must appear
echo "prereg null" > "$A/p2.md"; G -C "$A" add p2.md; C "$A" p2; S2=$(sha "$A"); G -C "$A" push -q origin HEAD:main
printf '| bare | 5/10 |\n| tool | 5/10 |\n' > "$A/r2.md"; G -C "$A" add r2.md; C "$A" r2; G -C "$A" push -q origin HEAD:main
# planted UNSEALED: prereg and result in one commit
echo "prereg late" > "$A/p3.md"; printf '| bare | 1/10 |\n| tool | 10/10 |\n' > "$A/r3.md"; G -C "$A" add p3.md r3.md; C "$A" p3r3; S3=$(sha "$A"); G -C "$A" push -q origin HEAD:main
# result appended to the prereg file later (one-file record)
echo "prereg inline" > "$A/p4.md"; G -C "$A" add p4.md; C "$A" p4; S4=$(sha "$A"); G -C "$A" push -q origin HEAD:main
printf '\n## Result\n| bare | 3/10 |\n' >> "$A/p4.md"; G -C "$A" add p4.md; C "$A" p4res; G -C "$A" push -q origin HEAD:main
# seal that was never pushed: on a local-only branch
G -C "$A" switch -q -c local-only; echo "unpushed" > "$A/p5.md"; G -C "$A" add p5.md; C "$A" p5; S5=$(sha "$A"); G -C "$A" switch -q main 2>/dev/null || G -C "$A" switch -q -
printf '| bare | 4/10 |\n' > "$A/r5.md"; G -C "$A" add r5.md; C "$A" r5; G -C "$A" push -q origin HEAD:main
# squash shape: seal and result on a pushed feature branch; main gets one squashed commit with both
G -C "$A" switch -q -c feat; echo "prereg sq" > "$A/p6.md"; G -C "$A" add p6.md; C "$A" p6; S6=$(sha "$A")
printf '| bare | 6/10 |\n' > "$A/r6.md"; G -C "$A" add r6.md; C "$A" r6; G -C "$A" push -q origin feat
G -C "$A" switch -q main 2>/dev/null || G -C "$A" switch -q -
G -C "$A" merge -q --squash feat >/dev/null 2>&1; C "$A" squash; G -C "$A" push -q origin HEAD:main
# a pushed seal on a side branch that the result does not descend from (not an ancestor)
G -C "$A" switch -q -c side; echo "prereg side" > "$A/p8.md"; G -C "$A" add p8.md; C "$A" p8; S8=$(sha "$A"); G -C "$A" push -q origin side
G -C "$A" switch -q main 2>/dev/null || G -C "$A" switch -q -
printf '| bare | 2/9 |\n' > "$A/r8.md"; G -C "$A" add r8.md; C "$A" r8; G -C "$A" push -q origin HEAD:main
# a quote written after the seal, then edited away from the result at the ref
echo "prereg edit" > "$A/p9.md"; G -C "$A" add p9.md; C "$A" p9; S9=$(sha "$A"); G -C "$A" push -q origin HEAD:main
printf '| bare | 3/9 |\n' > "$A/r9.md"; G -C "$A" add r9.md; C "$A" r9; G -C "$A" push -q origin HEAD:main
printf '| bare | 4/9 |\n' > "$A/r9.md"; G -C "$A" add r9.md; C "$A" r9edit; G -C "$A" push -q origin HEAD:main
echo "prereg frac" > "$A/p10.md"; G -C "$A" add p10.md; C "$A" p10; S10=$(sha "$A"); G -C "$A" push -q origin HEAD:main
printf '| bare | 12/100 |\n| tool | 9/10 = 90%% (60–98) |\n' > "$A/r10.md"; G -C "$A" add r10.md; C "$A" r10; G -C "$A" push -q origin HEAD:main
# decimal denominator, and a result ref that exists only locally
echo "prereg dec" > "$A/p11.md"; G -C "$A" add p11.md; C "$A" p11; S11=$(sha "$A"); G -C "$A" push -q origin HEAD:main
printf '| bare | 2/10.5 |\n' > "$A/r11.md"; G -C "$A" add r11.md; C "$A" r11; G -C "$A" push -q origin HEAD:main
G -C "$A" switch -q -c local-result; printf '| bare | 2/10.5 |\n| extra | 1/2 |\n' > "$A/r11.md"; G -C "$A" add r11.md; C "$A" r11local
G -C "$A" switch -q main 2>/dev/null || G -C "$A" switch -q -
G -C "$A" fetch -q origin

# cross-repo: seal in repo b; one result after it, one before it
mkrepo b; B="$T/b"
printf '| bare | 7/10 |\n' > "$A/r7early.md"; G -C "$A" add r7early.md; C "$A" r7early; G -C "$A" push -q origin HEAD:main
echo "prereg x" > "$B/px.md"; G -C "$B" add px.md; C "$B" px; SX=$(sha "$B"); G -C "$B" push -q origin HEAD:main
printf '| bare | 8/10 |\n' > "$A/r7late.md"; G -C "$A" add r7late.md; C "$A" r7late; G -C "$A" push -q origin HEAD:main
G -C "$A" fetch -q origin; G -C "$B" fetch -q origin

E() {  # id outcome prereg_repo prereg_path seal result_repo result_path ref quote_json arms_json [value]
  local v=""; [ -n "${11:-}" ] && v=", \"value\": \"${11}\""
  printf '{"id":"%s","group":"g","measure":"m %s","outcome":"%s","model":"x","date":"d","prereg":{"repo":"%s","path":"%s","seal":"%s"},"result":{"repo":"%s","path":"%s","ref":"%s"},"quote":%s,"arms":%s%s}' \
    "$1" "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9" "${10}" "$v"
}
ENTRIES=$(printf '%s,' \
  "$(E sealed-win WIN a p1.md "$S1" a r1.md origin/main '"| bare | 2/10 |\n| tool | 9/10 |"' '[{"label":"bare","k":2,"n":10},{"label":"tool","k":9,"n":10}]')" \
  "$(E planted-null NO-DIFFERENCE a p2.md "$S2" a r2.md origin/main '"| bare | 5/10 |\n| tool | 5/10 |"' '[{"label":"bare","k":5,"n":10},{"label":"tool","k":5,"n":10}]')" \
  "$(E planted-unsealed WIN a p3.md "$S3" a r3.md origin/main '"| bare | 1/10 |\n| tool | 10/10 |"' '[{"label":"bare","k":1,"n":10},{"label":"tool","k":10,"n":10}]')" \
  "$(E appended-result CEILING a p4.md "$S4" a p4.md origin/main '"| bare | 3/10 |"' '[{"label":"bare","k":3,"n":10}]')" \
  "$(E unpushed-seal WIN a p5.md "$S5" a r5.md origin/main '"| bare | 4/10 |"' '[{"label":"bare","k":4,"n":10}]')" \
  "$(E squash-shape WIN a p6.md "$S6" a r6.md origin/main '"| bare | 6/10 |"' '[{"label":"bare","k":6,"n":10}]')" \
  "$(E forged-quote WIN a p1.md "$S1" a r1.md origin/main '"| bare | 2/10 |\n| tool | 10/10 |"' '[{"label":"tool","k":10,"n":10}]')" \
  "$(E kn-not-in-quote WIN a p1.md "$S1" a r1.md origin/main '"| bare | 2/10 |"' '[{"label":"tool","k":9,"n":10}]')" \
  "$(E value-not-in-quote WIN a p1.md "$S1" a r1.md origin/main '"| bare | 2/10 |"' '[]' "9 of 10")" \
  "$(E value-in-quote NOT-DETECTED a p1.md "$S1" a r1.md origin/main '"| bare | 2/10 |"' '[]' "2/10")" \
  "$(E bad-outcome PASS a p1.md "$S1" a r1.md origin/main '"| bare | 2/10 |"' '[]' "2/10")" \
  "$(E company-repo WIN co p1.md "$S1" a r1.md origin/main '"| bare | 2/10 |"' '[]' "2/10")" \
  "$(E pattern-hit WIN a p1.md "$S1" a r1.md origin/main '"| bare | 2/10 |"' '[]' "2/10")" \
  "$(E seal-other-file WIN a p2.md "$S1" a r1.md origin/main '"| bare | 2/10 |"' '[]' "2/10")" \
  "$(E cross-repo-early WIN b px.md "$SX" a r7early.md origin/main '"| bare | 7/10 |"' '[]' "7/10")" \
  "$(E cross-repo-late CLAIM-NOT-SUPPORTED b px.md "$SX" a r7late.md origin/main '"| bare | 8/10 |"' '[]' "8/10")" \
  "$(E pooled-check WIN a p1.md "$S1" a r1.md origin/main '"| bare | 2/10 |"' '[]' "2/10")" \
  "$(E abbrev-same-commit WIN a p3.md "${S3:0:9}" a r3.md origin/main '"| bare | 1/10 |\n| tool | 10/10 |"' '[{"label":"tool","k":10,"n":10}]')" \
  "$(E frac-inside-number WIN a p10.md "$S10" a r10.md origin/main '"| bare | 12/100 |"' '[{"label":"bare","k":2,"n":10}]')" \
  "$(E alias-same-repo WIN a2 p8.md "$S8" a r8.md origin/main '"| bare | 2/9 |"' '[]' "2/9")" \
  "$(E empty-prereg-path WIN a "" "$S1" a r1.md origin/main '"| bare | 2/10 |"' '[]' "2/10")" \
  "$(E local-result-ref WIN a p11.md "$S11" a r11.md local-result '"| bare | 2/10.5 |"' '[]' "2/10.5")" \
  "$(E decimal-denominator WIN a p11.md "$S11" a r11.md origin/main '"| bare | 2/10.5 |"' '[{"label":"bare","k":2,"n":10}]')" \
  "$(E pipe-in-label WIN a p1.md "$S1" a r1.md origin/main '"| bare | 2/10 |"' '[{"label":"x | 99/100 | WIN","k":2,"n":10}]')" \
  "$(E zero-denominator WIN a p1.md "$S1" a r1.md origin/main '"| bare | 2/10 |\n| tool | 9/10 |"' '[{"label":"empty","k":0,"n":0},{"label":"bare","k":2,"n":10}]')" \
  "$(E glob-prereg-path WIN a "p1*.md" "$S1" a r1.md origin/main '"| bare | 2/10 |"' '[]' "2/10")" \
  "$(E side-seal WIN a p8.md "$S8" a r8.md origin/main '"| bare | 2/9 |"' '[]' "2/9")" \
  "$(E edited-away WIN a p9.md "$S9" a r9.md origin/main '"| bare | 3/9 |"' '[]' "3/9")" \
  | sed 's/,$//')
# pattern-hit and pooled-check differ only by measure text; the pattern file matches «pattern-hit»
# CI entries are appended raw: one whose CI is in the quote, one whose CI is not
ENTRIES="$ENTRIES,$(printf '{"id":"ci-in-quote","group":"g","measure":"m ci-in-quote","outcome":"WIN","model":"x","date":"d","prereg":{"repo":"a","path":"p10.md","seal":"%s"},"result":{"repo":"a","path":"r10.md","ref":"origin/main"},"quote":"| tool | 9/10 = 90%% (60–98) |","arms":[{"label":"tool","k":9,"n":10}],"ci":"60–98"}' "$S10")"
ENTRIES="$ENTRIES,$(printf '{"id":"ci-not-in-quote","group":"g","measure":"m ci-not-in-quote","outcome":"WIN","model":"x","date":"d","prereg":{"repo":"a","path":"p10.md","seal":"%s"},"result":{"repo":"a","path":"r10.md","ref":"origin/main"},"quote":"| tool | 9/10 = 90%% (60–98) |","arms":[{"label":"tool","k":9,"n":10}],"ci":"50–99"}' "$S10")"
cat > "$T/idx.json" <<EOF
{"title":"t","repos":{"a":{"path":"$A"},"a2":{"path":"$A"},"b":{"path":"$B"},"co":{"path":"$A","company":true}},
 "groups":{"g":"Group"},"slots":[{"group":"g","measure":"reserved slot"},{"group":"only-slot","measure":"lonely slot"}],"entries":[$ENTRIES]}
EOF
printf 'HIGH\tpattern-hit\n' > "$T/pat"
out=$(python3 "$R" "$T/idx.json" --exclude-patterns "$T/pat" 2>"$T/err"); rc=$?
[ "$rc" = 0 ] || { echo "$out" | tail -5; cat "$T/err"; _fail "render rc=$rc"; }

row() { grep -F "| m $1 |" <<< "$out"; }
exc() { grep -F "| $1 |" <<< "$(sed -n '/## Excluded/,$p' <<< "$out")"; }
shown() { local r; r=$(row "$1"); if [ -n "$r" ]; then _pass "$2"; else _fail "$2 — not rendered ($(exc "$1"))"; fi; }
gone()  { local r; r=$(row "$1"); if [ -z "$r" ] && grep -qF -- "$3" <<< "$(exc "$1")"; then _pass "$2"; else _fail "$2 — rendered=${r:+yes} reason=[$(exc "$1")]"; fi; }

shown sealed-win      "K1 sealed result renders"
shown planted-null    "K2 planted NULL (NO DIFFERENCE) renders — nulls are not dropped"
grep -qF "NO DIFFERENCE" <<< "$(row planted-null)" && _pass "K2b … with its outcome word" || _fail "K2b planted null lost its outcome word"
gone planted-unsealed "K3 planted UNSEALED result (same commit as prereg) does not render" "same commit"
shown appended-result "K4 result appended to the prereg file later renders (sealed by the earlier commit)"
gone unpushed-seal    "K5 seal never pushed does not render" "on no remote branch"
shown squash-shape    "K6 squash-merged main renders via the pushed feature branch"
gone forged-quote     "K7 quote not in the result file does not render" "not found"
gone kn-not-in-quote  "K8 declared k/n absent from the quote does not render" "not in the quote"
gone value-not-in-quote "K9 a value that is not in the quote does not render" "not a substring"
shown value-in-quote  "K9b a value that is in the quote renders"
gone bad-outcome      "K10 unknown outcome word does not render" "is not one of"
gone company-repo     "K11 a company-marked repo does not render" "company record"
gone pattern-hit      "K12 an exclude-pattern match does not render" "exclude pattern"
gone seal-other-file  "K13 a seal that does not touch the prereg file does not render" "does not touch"
gone cross-repo-early "K14 cross-repo: result written before the seal does not render" "not earlier"
shown cross-repo-late "K15 cross-repo: result written after the seal renders"
gone side-seal        "K19 a pushed seal the result does not descend from does not render" "not an ancestor"
gone edited-away      "K20 a quote later edited out of the result at the ref does not render" "not found verbatim"
gone abbrev-same-commit "K21 an abbreviated seal that is the result's own commit does not render" "same commit"
gone frac-inside-number "K22 a declared 2/10 found only inside 12/100 does not render" "not in the quote"
shown ci-in-quote     "K23 a CI that occurs in the quote renders"
gone ci-not-in-quote  "K24 a CI that is not in the quote does not render" "CI shown is not in the quote"
gone alias-same-repo  "K26 two index keys for one repo still get the ancestry check" "not an ancestor"
gone empty-prereg-path "K27 an empty pre-registration path does not render" "is empty"
gone local-result-ref "K28 a result ref that exists only locally does not render" "not on a remote branch"
gone decimal-denominator "K29 a declared 2/10 found only as 2/10.5 does not render" "not in the quote"
prow=$(row pipe-in-label); [ -n "$prow" ] && [ "$(sed 's/\\|//g' <<< "$prow" | tr -cd '|' | wc -c | tr -d ' ')" = 9 ] && _pass "K30 a pipe in index text cannot add table cells" || _fail "K30 pipe escaped badly: [$prow]"
gone zero-denominator "K31 a 0/0 arm does not render (no percentage to show)" "n > 0"
gone glob-prereg-path "K32 a pre-registration path is a file, not a glob" "does not touch"
grep -qF "lonely slot | *result not landed*" <<< "$out" && _pass "K25 a slot whose group has no rows still renders" || _fail "K25 slot-only group dropped"
grep -qF "reserved slot | *result not landed*" <<< "$out" && _pass "K16 a reserved slot renders as pending" || _fail "K16 slot missing"
pct_lines=$(grep -vE '^\|' <<< "$out" | grep -c '%' || true)
[ "$pct_lines" = 0 ] && _pass "K17 no percentage outside table rows (no pooled headline)" || _fail "K17 $pct_lines line(s) with % outside rows"
grep -qE "^Rows by outcome: win [0-9]+ · NO DIFFERENCE [0-9]+ · NOT-DETECTED [0-9]+ · CEILING [0-9]+ · claim not supported [0-9]+ · excluded [0-9]+$" <<< "$out" \
  && _pass "K18 outcome counts line names every outcome, including excluded" || _fail "K18 counts line shape"

# UNMEASURED states
echo "{not json" > "$T/bad.json"; python3 "$R" "$T/bad.json" >/dev/null 2>&1; [ $? = 2 ] && _pass "U1 unreadable index → exit 2" || _fail "U1 unreadable index"
printf '{"repos":{"z":{"path":"%s/nope"}},"entries":[]}' "$T" > "$T/norepo.json"
python3 "$R" "$T/norepo.json" >/dev/null 2>&1; [ $? = 2 ] && _pass "U2 missing repo path → exit 2" || _fail "U2 missing repo"

PY3="$(command -v python3)"
env -i PATH=/nonexistent HOME="$T" "$PY3" "$R" "$T/idx.json" >/dev/null 2>&1; [ $? = 2 ] && _pass "U3 git not on PATH → exit 2, not a traceback" || _fail "U3 git missing"
echo "──────────────────────────────────────────────"
if [ "$FAILED" -ne 0 ]; then echo "SCOREBOARD LANES: FAIL ($PASSED passed)"; exit 1; fi
echo "SCOREBOARD LANES: PASS ($PASSED/$PASSED)"; exit 0
