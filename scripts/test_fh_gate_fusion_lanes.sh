#!/usr/bin/env bash
# test_fh_gate_fusion_lanes.sh — lanes for fh-gate's opt-in /code-review review stage (FH_REVIEWER=code-review) and its
# merge with the execution layer. Token-free: `claude` and `codex` are stubs on PATH.
#
#   F1  FH_REVIEWER=code-review calls «/code-review medium» (quick) / «high» (full) with a schema, read-only tools
#   F2  Important + Nit → PENDING (exit 1), grades B and C, the summary carried verbatim
#   F3  Nit + Pre-existing only → PASS (exit 0)
#   F4  no structured object → 10, no fallback to another reviewer
#   F5  a severity outside the label set → 10
#   F5b keys outside the schema (top level or in a finding) → 10
#   F6  status ERROR → 10
#   F7  FH_REVIEWER=fh-legacy → the older FH pass (its prompt on stdin, its verdict)
#   F8  codex backend with FH_REVIEWER=fh → the absorbed FH pass, not labelled fallback (it was asked for)
#   F9  FH_REVIEWER=code-review on codex → 11
#   F10 FH_REVIEWER / FH_GATE_EXEC outside their sets → 11
#   F11 a change that turns its lane red, /code-review with no finding → BLOCKED (2), finding source E1
#   F12 dry run → 12, the reviewer is not called, E1 «planned»
#   F13 FH_GATE_EXEC=off → E0/E1 lines say NOT RUN (FH_GATE_EXEC=off)
#   F14 cross with FH_REVIEWER=code-review → the codex leg gets the goldfish pass, labelled fallback; both lines kept;
#       the execution layer runs once
#   F15 /code-review call fails (rc ≠ 0) → 10
#   F16 /code-review runs in the repository root even when fh-gate is called from a subfolder
#   F17 a Nit-only review cannot be lifted to PASS past a red lane, and a C lane note does not move PASS
#
# Run: bash scripts/test_fh_gate_fusion_lanes.sh
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/fixture_guard_lib.sh"   # scrub inherited GIT_* env first (#1088)
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE="$HERE/fh-gate.sh"
TMPROOT=$(mktemp -d "${TMPDIR:-/tmp}/fh_gate_fusion_XXXXXX")
trap 'rm -rf "$TMPROOT"' EXIT
export CODEX_HOME="$TMPROOT/codexhome-none"   # fh-gate reads the codex user config (provider guard): not the runner's
export FH_RECORD_BASE="$TMPROOT/records"; mkdir -p "$FH_RECORD_BASE"
# These lanes exercise the opt-in review and execution layer (3.45.0: defaults are fh-legacy · exec off · elephant
# off — pinned by test_fh_gate_defaults_lanes.sh). Each lane that needs otherwise sets its own value.
export FH_REVIEWER=code-review FH_GATE_EXEC=on
pass=0; fail=0
ok()  { printf 'PASS  %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf 'FAIL  %s — %s\n' "$1" "$2"; fail=$((fail + 1)); }
g() { git -c user.name=t -c user.email=t@t -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@"; }

FAKEBIN="$TMPROOT/bin"; mkdir -p "$FAKEBIN"
cat > "$FAKEBIN/claude" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$@" >> "${ARGV_LOG:-/dev/null}"   # append: one gate run may call the backend more than once
pwd -P > "${PWD_LOG:-/dev/null}"
in=$(cat); printf '%s\n' "$in" > "${STDIN_LOG:-/dev/null}"
[ -n "${FAKE_RC:-}" ] && exit "$FAKE_RC"
case "$in" in *"FH ELEPHANT PASS"*|*"FH REVIEW PASS"*)
  printf '{"is_error":false,"subtype":"success","structured_output":{"status":"SUCCESS","findings":[]}}\n'; exit 0 ;; esac
if [ -n "${FAKE_ENVELOPE:-}" ]; then printf '%s\n' "$FAKE_ENVELOPE"; exit 0; fi
cr="${FAKE_CR:-}"; [ -n "$cr" ] || cr='{"status":"SUCCESS","findings":[]}'
case " $* " in
  *"/code-review "*) printf '{"is_error":false,"subtype":"success","structured_output":%s}\n' "$cr" ;;
  *) printf '{"is_error":false,"subtype":"success","structured_output":%s}\n' "$FAKE_PAYLOAD" ;;
esac
FAKE
cat > "$FAKEBIN/codex" <<'FAKE'
#!/usr/bin/env bash
out=""
while [ $# -gt 0 ]; do case "$1" in -o) out="$2"; shift 2 ;; *) shift ;; esac; done
in=$(cat); printf '%s\n' "$in" > "${CODEX_STDIN_LOG:-/dev/null}"
p="$FAKE_PAYLOAD"
case "$in" in *"FH REVIEW PASS"*|*"FH ELEPHANT PASS"*) p='{"status":"SUCCESS","findings":[]}' ;; esac
[ -n "$out" ] && printf '%s' "$p" > "$out"
exit 0
FAKE
chmod +x "$FAKEBIN/claude" "$FAKEBIN/codex"
export PATH="$FAKEBIN:$PATH"
export FAKE_PAYLOAD='{"status":"SUCCESS","verdict":"PASS","findings_count":0,"findings_a":0,"findings_b":0,"findings":[]}'

# a repo with one change on a branch (scripts/foo.sh + its lane), so auto-detect has files
REPO="$TMPROOT/repo"; mkdir -p "$REPO/scripts/sub"
g -C "$REPO" init -q -b main
printf '#!/usr/bin/env bash\necho ok\n' > "$REPO/scripts/foo.sh"
printf '#!/usr/bin/env bash\n[ "$(bash scripts/foo.sh)" = ok ] || { echo "FAIL foo"; exit 1; }\necho PASS\n' > "$REPO/scripts/test_foo_lanes.sh"
g -C "$REPO" add -A; g -C "$REPO" commit -qm base
g -C "$REPO" checkout -qb feat
printf '#!/usr/bin/env bash\n# harmless\necho ok\n' > "$REPO/scripts/foo.sh"; g -C "$REPO" commit -qam harmless

# gate <name> [env...] — run fh-gate in $REPO (or $RUN_DIR), stdout/err to files, rc in $RC
gate() {
  local name="$1"; shift
  ( cd "${RUN_DIR:-$REPO}" && env "$@" bash "$GATE" ) > "$TMPROOT/$name.out" 2> "$TMPROOT/$name.err" < /dev/null
  RC=$?
}
has() { grep -qF -- "$2" "$TMPROOT/$1.out"; }

CR_IMP_NIT='{"status":"SUCCESS","findings":[{"file":"scripts/foo.sh","line":2,"severity":"important","summary":"Off-by-one «exact» text — kept: $x `y`","failure_scenario":"input 0 crashes"},{"file":"scripts/foo.sh","line":0,"severity":"nit","summary":"naming","failure_scenario":""}]}'
CR_NIT_PRE='{"status":"SUCCESS","findings":[{"file":"a","line":1,"severity":"nit","summary":"n","failure_scenario":""},{"file":"b","line":3,"severity":"pre_existing","summary":"p","failure_scenario":"old"}]}'

# F1
gate f1 FH_GATE_EXEC=off ARGV_LOG="$TMPROOT/f1.argv"
gate f1b FH_GATE_EXEC=off FH_GATE_LEVEL=full ARGV_LOG="$TMPROOT/f1b.argv"
if [ "$RC" -eq 0 ] && grep -qx '/code-review medium' "$TMPROOT/f1.argv" && grep -qx '/code-review high' "$TMPROOT/f1b.argv" \
   && grep -qx -- '--json-schema' "$TMPROOT/f1.argv" && grep -q 'Write,Edit' "$TMPROOT/f1.argv" \
   && has f1 'FH_GATE_REVIEWER: /code-review medium (built-in)'; then
  ok "F1 FH_REVIEWER=code-review calls /code-review (medium quick · high full), schema, read-only tools"
else bad "F1 /code-review opt-in" "rc=$RC argv=$(tr '\n' ' ' < "$TMPROOT/f1.argv" 2>/dev/null)"; fi

# F2
gate f2 FH_GATE_EXEC=off FAKE_CR="$CR_IMP_NIT"
if [ "$RC" -eq 1 ] && has f2 'FH_GATE_VERDICT: PENDING' && has f2 'FH_FINDINGS_B: 1' && has f2 'FH_FINDINGS_COUNT: 2' \
   && has f2 'title: "Off-by-one «exact» text — kept: $x `y`"' && has f2 'location: "scripts/foo.sh:2"'; then
  ok "F2 Important + Nit → PENDING, B + C, summary verbatim"
else bad "F2 Important + Nit → PENDING" "rc=$RC $(head -c 600 "$TMPROOT/f2.out")"; fi

# F3
gate f3 FH_GATE_EXEC=off FAKE_CR="$CR_NIT_PRE"
if [ "$RC" -eq 0 ] && has f3 'FH_GATE_VERDICT: PASS' && has f3 'FH_FINDINGS_COUNT: 2'; then ok "F3 Nit + Pre-existing only → PASS"
else bad "F3 Nit + Pre-existing → PASS" "rc=$RC $(head -c 400 "$TMPROOT/f3.out")"; fi

# F4
gate f4 FH_GATE_EXEC=off FAKE_ENVELOPE='{"is_error":false,"subtype":"success","result":"8 findings, most severe first: ..."}'
if [ "$RC" -eq 10 ]; then ok "F4 no structured object → 10 (no fallback)"; else bad "F4 no structured object → 10" "rc=$RC"; fi

# F5
gate f5 FH_GATE_EXEC=off FAKE_CR='{"status":"SUCCESS","findings":[{"file":"a","line":1,"severity":"critical","summary":"s","failure_scenario":""}]}'
if [ "$RC" -eq 10 ]; then ok "F5 severity outside the label set → 10"; else bad "F5 severity outside set → 10" "rc=$RC"; fi

# F5b — keys outside the schema (top level or in a finding) → 10
gate f5b FH_GATE_EXEC=off FAKE_CR='{"status":"SUCCESS","findings":[],"extra":true}'; r1=$RC
gate f5c FH_GATE_EXEC=off FAKE_CR='{"status":"SUCCESS","findings":[{"file":"a","line":1,"severity":"nit","summary":"s","failure_scenario":"","verdict":"PASS"}]}'; r2=$RC
if [ "$r1" -eq 10 ] && [ "$r2" -eq 10 ]; then ok "F5b keys outside the schema → 10"; else bad "F5b extra keys → 10" "top=$r1 finding=$r2"; fi

# F6
gate f6 FH_GATE_EXEC=off FAKE_CR='{"status":"ERROR","findings":[]}'
if [ "$RC" -eq 10 ]; then ok "F6 status ERROR → 10"; else bad "F6 status ERROR → 10" "rc=$RC"; fi

# F7
gate f7 FH_GATE_EXEC=off FH_REVIEWER=fh-legacy STDIN_LOG="$TMPROOT/f7.stdin" \
  FAKE_PAYLOAD='{"status":"SUCCESS","verdict":"PENDING","findings_count":1,"findings_a":0,"findings_b":1,"findings":[{"grade":"B","location":"x","title":"t","evidence":"e","fix":"f"}]}'
if [ "$RC" -eq 1 ] && grep -q 'FH GOVERNANCE GATE' "$TMPROOT/f7.stdin" && has f7 'FH_GATE_REVIEWER: fh-legacy'; then
  ok "F7 FH_REVIEWER=fh-legacy → the older FH pass"
else bad "F7 FH_REVIEWER=fh-legacy → FH pass" "rc=$RC"; fi

# F8
gate f8 FH_GATE_EXEC=off FH_BACKEND=codex FH_REVIEWER=fh CODEX_STDIN_LOG="$TMPROOT/f8.stdin"
if [ "$RC" -eq 0 ] && has f8 'FH_GATE_REVIEWER: fh — goldfish pass' && ! has f8 'fallback' && grep -q 'FH REVIEW PASS' "$TMPROOT/f8.stdin"; then
  ok "F8 codex + FH_REVIEWER=fh → the absorbed FH pass, not labelled fallback"
else bad "F8 codex + fh" "rc=$RC $(grep REVIEWER "$TMPROOT/f8.out")"; fi

# F9
gate f9 FH_GATE_EXEC=off FH_BACKEND=codex FH_REVIEWER=code-review
if [ "$RC" -eq 11 ]; then ok "F9 FH_REVIEWER=code-review on codex → 11"; else bad "F9 code-review on codex → 11" "rc=$RC"; fi

# F10
gate f10a FH_REVIEWER=bogus; r1=$RC
gate f10b FH_GATE_EXEC=maybe; r2=$RC
if [ "$r1" -eq 11 ] && [ "$r2" -eq 11 ]; then ok "F10 FH_REVIEWER / FH_GATE_EXEC outside their sets → 11"
else bad "F10 bad values → 11" "reviewer=$r1 exec=$r2"; fi

# F11 — a change that turns its lane red
g -C "$REPO" checkout -q -b red main
printf '#!/usr/bin/env bash\necho broken\n' > "$REPO/scripts/foo.sh"; g -C "$REPO" commit -qam red
gate f11
if [ "$RC" -eq 2 ] && has f11 'FH_GATE_VERDICT: BLOCKED' && has f11 'source: "E1"' && has f11 'FH_GATE_E1: ran — ran 1 lane(s)'; then
  ok "F11 lane turned red by the change, clean review → BLOCKED from E1"
else bad "F11 red lane → BLOCKED" "rc=$RC $(head -c 700 "$TMPROOT/f11.out") $(tail -c 300 "$TMPROOT/f11.err")"; fi

# F12
rm -f "$TMPROOT/f12.argv"
gate f12 FH_DRY_RUN=1 ARGV_LOG="$TMPROOT/f12.argv"
if [ "$RC" -eq 12 ] && [ ! -e "$TMPROOT/f12.argv" ] && has f12 'FH_GATE_E1: planned — would run 1 lane(s)'; then
  ok "F12 dry run → 12, reviewer not called, E1 planned"
else bad "F12 dry run" "rc=$RC called=$([ -e "$TMPROOT/f12.argv" ] && echo yes || echo no) $(grep E1 "$TMPROOT/f12.out")"; fi

# F13
gate f13 FH_GATE_EXEC=off
if has f13 'FH_GATE_E0: not-run — NOT RUN (FH_GATE_EXEC=off)' && has f13 'FH_GATE_E1: not-run — NOT RUN (FH_GATE_EXEC=off)'; then
  ok "F13 FH_GATE_EXEC=off → NOT RUN lines"
else bad "F13 exec off lines" "$(grep -E 'E0|E1' "$TMPROOT/f13.out")"; fi

# F14 — cross: the red lane is seen once, both reviewer lines are kept
gate f14 FH_BACKEND=cross
if [ "$RC" -eq 2 ] && has f14 '# FH_GATE_REVIEWER: /code-review' && has f14 '(fallback — /code-review unavailable on codex)' \
   && has f14 '# FH_GATE_E1: not-run — NOT RUN (FH_GATE_EXEC=off)' && [ "$(grep -c 'source: "E1"' "$TMPROOT/f14.out")" -eq 1 ]; then
  ok "F14 cross keeps both reviewer lines; execution layer runs once"
else bad "F14 cross" "rc=$RC $(grep -E 'REVIEWER|E1|source' "$TMPROOT/f14.out" | head -8)"; fi

# F15
g -C "$REPO" checkout -q feat
gate f15 FH_GATE_EXEC=off FAKE_RC=1
if [ "$RC" -eq 10 ]; then ok "F15 /code-review call fails → 10"; else bad "F15 call fails → 10" "rc=$RC"; fi

# F16
RUN_DIR="$REPO/scripts/sub" gate f16 FH_GATE_EXEC=off PWD_LOG="$TMPROOT/f16.pwd"
if [ "$(cat "$TMPROOT/f16.pwd" 2>/dev/null)" = "$(cd "$REPO" && pwd -P)" ]; then ok "F16 /code-review runs in the repository root"
else bad "F16 cwd = repo root" "got $(cat "$TMPROOT/f16.pwd" 2>/dev/null)"; fi

# F17 — Nit-only review + red lane stays BLOCKED; a lane red before the change too (C) leaves PASS alone
g -C "$REPO" checkout -q red
gate f17a FAKE_CR="$CR_NIT_PRE"
g -C "$REPO" checkout -q -b prered red
printf '#!/usr/bin/env bash\n# still broken\necho broken\n' > "$REPO/scripts/foo.sh"; g -C "$REPO" commit -qam again
gate f17b FH_GATE_BASE=red
if [ "$(sed -n 1p "$TMPROOT/f17a.out" >/dev/null; grep -c 'FH_GATE_VERDICT: BLOCKED' "$TMPROOT/f17a.out")" -eq 1 ] \
   && has f17b 'FH_GATE_VERDICT: PASS' && has f17b 'grade: C'; then
  ok "F17 Nit-only cannot lift a red lane to PASS; a pre-existing red (C) leaves PASS"
else bad "F17 merge rule" "a=$(grep VERDICT "$TMPROOT/f17a.out") b=$(grep -m4 -E 'VERDICT|grade' "$TMPROOT/f17b.out")"; fi

echo "fusion lanes: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
