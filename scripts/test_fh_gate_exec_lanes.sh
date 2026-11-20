#!/usr/bin/env bash
# test_fh_gate_exec_lanes.sh — known-pair lanes for fh-gate's execution layer (scripts/fh_gate_exec.sh).
#
# Each lane builds a scratch git repo, makes a change, runs the execution layer against it and checks
# the JSON it returns. Token-free: no model is called anywhere in this file.
#
#   X1  a change that turns its lane red              → one A finding from E1
#   X2  a lane that was red before the change too     → C, not A
#   X3  a change whose lane stays green               → no finding, «1 lane, 0 red»
#   X4  a change no lane names                        → E1 NOT RUN (no target lane), no finding
#   X5  a lane that does not finish in time           → B «did not finish», never green
#   X6  a change that adds a pipefail early-exit pipe → one B finding from E0
#   X7  lanes run in a copy                           → the work tree is untouched
#   X8  an uncommitted change (HEAD = base)           → the copy carries it; its lane goes red → A
#   X9  --plan                                        → lanes are listed, not run
#   X10 nested gates inside a lane                    → the lane sees FH_GATE_EXEC=off
#   X11 FH_GATE_LANES (declared lanes)                → run even when discovery finds none
#   X12 not a git repository                          → NOT RUN with the reason, exit 0
#   X13 a base ref that does not exist                → NOT RUN with the reason and a B finding, exit 0
#   X14 more lanes than FH_GATE_MAX_LANES             → capped, and the detail says so
#   X15 the scanner's own self-test fails             → B «instrument error», never «0 new»
#   X16 under a cap, the lane named after the changed file is kept over one that only mentions it
#   X17 red after the change, base run does not finish  → B «not compared», never C
#   X18 a lane file name with shell syntax in it         → run as a path; its spelling runs nothing
#   X19 no temporary folder can be made                  → B «could not run», never a silent NOT RUN
#   X20 a declared lane that is new with the change, red → A, not «red before»
#
# Run: bash scripts/test_fh_gate_exec_lanes.sh
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/fixture_guard_lib.sh"   # scrub inherited GIT_* env first (#1088)
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXEC="$HERE/fh_gate_exec.sh"
TMPROOT=$(mktemp -d "${TMPDIR:-/tmp}/fh_gate_exec_lanes_XXXXXX")
trap 'rm -rf "$TMPROOT"' EXIT
pass=0; fail=0

ok()  { printf 'PASS  %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf 'FAIL  %s — %s\n' "$1" "$2"; fail=$((fail + 1)); }

g() { git -c user.name=t -c user.email=t@t -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@"; }

# mkrepo <dir> <foo.sh body> — scripts/foo.sh + a lane that asserts it prints «ok»
mkrepo() {
  local d="$1" body="$2"
  mkdir -p "$d/scripts"
  g -C "$d" init -q -b main
  printf '#!/usr/bin/env bash\n%s\n' "$body" > "$d/scripts/foo.sh"
  cat > "$d/scripts/test_foo_lanes.sh" <<'LANE'
#!/usr/bin/env bash
out=$(bash scripts/foo.sh)
[ "$out" = ok ] || { echo "FAIL foo printed: $out"; exit 1; }
echo "PASS foo"
LANE
  printf 'readme\n' > "$d/README.md"
  g -C "$d" add -A && g -C "$d" commit -q -m base
}

# run_exec <name> <repo> <base> [args...] — stores JSON in $TMPROOT/<name>.json, rc in $RC
run_exec() {
  local name="$1" repo="$2" base="$3"; shift 3
  bash "$EXEC" "$repo" "$base" "$@" > "$TMPROOT/$name.json" 2> "$TMPROOT/$name.err" < /dev/null
  RC=$?
}
q() { jq -r "$2" "$TMPROOT/$1.json" 2>/dev/null; }
# qm <name> <jq expr> <ERE> [i] — the field matches; no `q … | grep -q` (an early-exit consumer under pipefail is the very
# class E0 scans for, and the class lock counts its shape)
qm() { local v; v=$(q "$1" "$2"); if [ "${4:-}" = i ]; then v=$(printf '%s' "$v" | tr '[:upper:]' '[:lower:]'); fi; [[ "$v" =~ $3 ]]; }

[ -f "$EXEC" ] || { echo "FAIL  fh_gate_exec.sh missing"; echo "exec lanes: 0 passed, 1 failed"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "FAIL  jq missing — the execution layer needs it"; exit 1; }

# ── X1 ─────────────────────────────────────────────────────────────────────────────────────────
R="$TMPROOT/x1"; mkrepo "$R" 'echo ok'; B=$(g -C "$R" rev-parse HEAD)
printf '#!/usr/bin/env bash\necho broken\n' > "$R/scripts/foo.sh"; g -C "$R" commit -qam change
run_exec x1 "$R" "$B"
if [ "$RC" -eq 0 ] && [ "$(q x1 '[.findings[]|select(.grade=="A" and .source=="E1")]|length')" = 1 ] \
   && [ "$(q x1 '.e1.status')" = ran ]; then ok "X1 change turns its lane red → one A from E1"
else bad "X1 change turns its lane red → one A from E1" "rc=$RC $(head -c 400 "$TMPROOT/x1.json")"; fi

# ── X2 ─────────────────────────────────────────────────────────────────────────────────────────
R="$TMPROOT/x2"; mkrepo "$R" 'echo broken'; B=$(g -C "$R" rev-parse HEAD)
printf '#!/usr/bin/env bash\n# a comment\necho broken\n' > "$R/scripts/foo.sh"; g -C "$R" commit -qam change
run_exec x2 "$R" "$B"
if [ "$(q x2 '[.findings[]|select(.source=="E1")]|map(.grade)|join(",")')" = C ]; then ok "X2 red before the change too → C, not A"
else bad "X2 red before the change too → C, not A" "$(head -c 400 "$TMPROOT/x2.json")"; fi

# ── X3 ─────────────────────────────────────────────────────────────────────────────────────────
R="$TMPROOT/x3"; mkrepo "$R" 'echo ok'; B=$(g -C "$R" rev-parse HEAD)
printf '#!/usr/bin/env bash\n# still fine\necho ok\n' > "$R/scripts/foo.sh"; g -C "$R" commit -qam change
run_exec x3 "$R" "$B"
if [ "$(q x3 '.findings|length')" = 0 ] && qm x3 '.e1.detail' '1 lane.* 0 red'; then ok "X3 lane stays green → no finding, «1 lane … 0 red»"
else bad "X3 lane stays green → no finding" "$(head -c 400 "$TMPROOT/x3.json")"; fi

# ── X4 ─────────────────────────────────────────────────────────────────────────────────────────
R="$TMPROOT/x4"; mkrepo "$R" 'echo ok'; B=$(g -C "$R" rev-parse HEAD)
printf 'readme 2\n' > "$R/README.md"; g -C "$R" commit -qam change
run_exec x4 "$R" "$B"
if [ "$(q x4 '.e1.status')" = not-run ] && qm x4 '.e1.detail' 'no target lane' && [ "$(q x4 '.findings|length')" = 0 ]; then
  ok "X4 no lane names the change → E1 NOT RUN (no target lane)"
else bad "X4 no lane names the change → E1 NOT RUN" "$(head -c 400 "$TMPROOT/x4.json")"; fi

# ── X5 ─────────────────────────────────────────────────────────────────────────────────────────
R="$TMPROOT/x5"; mkrepo "$R" 'echo ok'; B=$(g -C "$R" rev-parse HEAD)
printf '#!/usr/bin/env bash\nsleep 6\necho ok\n' > "$R/scripts/foo.sh"; g -C "$R" commit -qam change
FH_LANE_TIMEOUT=1 run_exec x5 "$R" "$B"
if [ "$(q x5 '[.findings[]|select(.grade=="B" and .source=="E1")]|length')" = 1 ] && qm x5 '.findings[0].title' 'did not finish' i; then
  ok "X5 lane does not finish in time → B, never green"
else bad "X5 lane does not finish in time → B" "$(head -c 400 "$TMPROOT/x5.json")"; fi

# ── X6 ─────────────────────────────────────────────────────────────────────────────────────────
skip=0
if [ ! -f "$HERE/pipefail_earlyexit_scan.sh" ]; then
  # the npm package does not ship the class scanner (scripts/package_coverage_check.sh says why); E0 then
  # reports «NOT RUN (scanner not shipped here)», which X15's sibling path covers
  printf 'SKIP  X6 pipefail scanner not shipped in this install — not a pass\n'; skip=1
else
R="$TMPROOT/x6"; mkrepo "$R" 'echo ok'; B=$(g -C "$R" rev-parse HEAD)
printf '#!/usr/bin/env bash\nset -o pipefail\nif cat "$1" | grep -q needle; then echo found; fi\n' > "$R/scripts/bar.sh"
g -C "$R" add scripts/bar.sh; g -C "$R" commit -qm change
run_exec x6 "$R" "$B"
if [ "$(q x6 '[.findings[]|select(.grade=="B" and .source=="E0")]|map(.location)|join(",")')" = scripts/bar.sh ] \
   && qm x6 '.findings[0].evidence' 'grep -q needle' && [ "$(q x6 '.e0.status')" = ran ]; then
  ok "X6 change adds a pipefail early-exit pipe → one B from E0"
else bad "X6 change adds a pipefail early-exit pipe → one B from E0" "$(head -c 500 "$TMPROOT/x6.json")"; fi
fi

# ── X7 ─────────────────────────────────────────────────────────────────────────────────────────
R="$TMPROOT/x7"; mkrepo "$R" 'echo ok'; B=$(g -C "$R" rev-parse HEAD)
printf '#!/usr/bin/env bash\ntouch touched_by_lane\necho ok\n' > "$R/scripts/foo.sh"; g -C "$R" commit -qam change
run_exec x7 "$R" "$B"
if [ "$(q x7 '.e1.status')" = ran ] && [ ! -e "$R/touched_by_lane" ] && [ -z "$(g -C "$R" status --porcelain)" ]; then
  ok "X7 lanes run in a copy → the work tree is untouched"
else bad "X7 lanes run in a copy" "touched=$([ -e "$R/touched_by_lane" ] && echo yes || echo no) status=$(g -C "$R" status --porcelain | head -3)"; fi

# ── X8 ─────────────────────────────────────────────────────────────────────────────────────────
R="$TMPROOT/x8"; mkrepo "$R" 'echo ok'; B=$(g -C "$R" rev-parse HEAD)
printf '#!/usr/bin/env bash\necho broken\n' > "$R/scripts/foo.sh"   # left uncommitted
run_exec x8 "$R" "$B"
if [ "$(q x8 '[.findings[]|select(.grade=="A" and .source=="E1")]|length')" = 1 ]; then ok "X8 uncommitted change is what the copy tests → A"
else bad "X8 uncommitted change is what the copy tests → A" "$(head -c 400 "$TMPROOT/x8.json")"; fi

# ── X9 ─────────────────────────────────────────────────────────────────────────────────────────
R="$TMPROOT/x9"; mkrepo "$R" 'echo ok'; B=$(g -C "$R" rev-parse HEAD)
printf '#!/usr/bin/env bash\ntouch "%s/x9_ran"\necho ok\n' "$TMPROOT" > "$R/scripts/foo.sh"; g -C "$R" commit -qam change
run_exec x9 "$R" "$B" --plan
if [ ! -e "$TMPROOT/x9_ran" ] && qm x9 '.e1.detail' 'would run 1 lane' && [ "$(q x9 '.findings|length')" = 0 ]; then
  ok "X9 --plan lists the lanes and runs none"
else bad "X9 --plan lists the lanes and runs none" "ran=$([ -e "$TMPROOT/x9_ran" ] && echo yes || echo no) $(head -c 300 "$TMPROOT/x9.json")"; fi

# ── X10 ────────────────────────────────────────────────────────────────────────────────────────
R="$TMPROOT/x10"; mkrepo "$R" 'echo ok'; B=$(g -C "$R" rev-parse HEAD)
printf '#!/usr/bin/env bash\nprintf %%s "${FH_GATE_EXEC:-unset}" > "%s/x10_env"\necho ok\n' "$TMPROOT" > "$R/scripts/foo.sh"; g -C "$R" commit -qam change
run_exec x10 "$R" "$B"
if [ "$(cat "$TMPROOT/x10_env" 2>/dev/null)" = off ]; then ok "X10 a lane sees FH_GATE_EXEC=off (nested gates do not re-run the layer)"
else bad "X10 a lane sees FH_GATE_EXEC=off" "got: $(cat "$TMPROOT/x10_env" 2>/dev/null || echo missing)"; fi

# ── X11 ────────────────────────────────────────────────────────────────────────────────────────
R="$TMPROOT/x11"; mkrepo "$R" 'echo broken'; B=$(g -C "$R" rev-parse HEAD)
printf 'readme 2\n' > "$R/README.md"; g -C "$R" commit -qam change
FH_GATE_LANES='bash scripts/test_foo_lanes.sh' run_exec x11 "$R" "$B"
if [ "$(q x11 '.e1.status')" = ran ] && qm x11 '.e1.detail' 'declared' && [ "$(q x11 '[.findings[]|select(.source=="E1")]|length')" = 1 ]; then
  ok "X11 declared lanes run even when discovery finds none"
else bad "X11 declared lanes run" "$(head -c 400 "$TMPROOT/x11.json")"; fi

# ── X12 ────────────────────────────────────────────────────────────────────────────────────────
mkdir -p "$TMPROOT/x12"
run_exec x12 "$TMPROOT/x12" HEAD
if [ "$RC" -eq 0 ] && [ "$(q x12 '.e1.status')" = not-run ] && qm x12 '.e1.detail' 'not a git'; then ok "X12 not a git repository → NOT RUN with the reason"
else bad "X12 not a git repository → NOT RUN" "rc=$RC $(head -c 300 "$TMPROOT/x12.json")"; fi

# ── X13 ────────────────────────────────────────────────────────────────────────────────────────
R="$TMPROOT/x13"; mkrepo "$R" 'echo ok'
run_exec x13 "$R" no-such-ref
if [ "$RC" -eq 0 ] && [ "$(q x13 '.e0.status')" = not-run ] && qm x13 '.e0.detail' 'no-such-ref' \
   && [ "$(q x13 '[.findings[]|select(.grade=="B" and .source=="exec")]|length')" = 1 ]; then ok "X13 base ref missing → NOT RUN naming the ref, and a B (could not run ≠ not applicable)"
else bad "X13 base ref missing → NOT RUN" "rc=$RC $(head -c 300 "$TMPROOT/x13.json")"; fi

# ── X14 ────────────────────────────────────────────────────────────────────────────────────────
R="$TMPROOT/x14"; mkrepo "$R" 'echo ok'
for i in 2 3; do cp "$R/scripts/test_foo_lanes.sh" "$R/scripts/test_foo${i}_lanes.sh"; done
g -C "$R" add -A; g -C "$R" commit -qm more; B=$(g -C "$R" rev-parse HEAD)
printf '#!/usr/bin/env bash\n# touch\necho ok\n' > "$R/scripts/foo.sh"; g -C "$R" commit -qam change
FH_GATE_MAX_LANES=2 run_exec x14 "$R" "$B"
if qm x14 '.e1.detail' 'capped' && qm x14 '.e1.detail' '2 lane'; then ok "X14 more lanes than the cap → capped, and the detail says so"
else bad "X14 lane cap is stated" "$(head -c 400 "$TMPROOT/x14.json")"; fi

# ── X16 ────────────────────────────────────────────────────────────────────────────────────────
# Under a cap, the lane named after the changed file outranks a lane that only mentions it (aaa_* sorts first).
R="$TMPROOT/x16"; mkrepo "$R" 'echo ok'
printf '#!/usr/bin/env bash\n# mentions foo.sh only\nexit 0\n' > "$R/scripts/test_aaa_lanes.sh"
g -C "$R" add -A; g -C "$R" commit -qm more; B=$(g -C "$R" rev-parse HEAD)
printf '#!/usr/bin/env bash\n# touch\necho ok\n' > "$R/scripts/foo.sh"; g -C "$R" commit -qam change
FH_GATE_MAX_LANES=1 run_exec x16 "$R" "$B" --plan
if qm x16 '.e1.detail' 'test_foo_lanes.sh' && ! qm x16 '.e1.detail' 'test_aaa_lanes.sh'; then
  ok "X16 under a cap, the lane named after the changed file is kept"
else bad "X16 cap keeps the lane named after the file" "$(q x16 '.e1.detail')"; fi

# ── X17 ────────────────────────────────────────────────────────────────────────────────────────
R="$TMPROOT/x17"; mkrepo "$R" 'sleep 8; echo ok'; B=$(g -C "$R" rev-parse HEAD)
printf '#!/usr/bin/env bash\necho broken\n' > "$R/scripts/foo.sh"; g -C "$R" commit -qam change
FH_LANE_TIMEOUT=2 run_exec x17 "$R" "$B"
if [ "$(q x17 '[.findings[]|select(.source=="E1")]|map(.grade)|join(",")')" = B ] && qm x17 '.findings[0].title' 'not compared'; then
  ok "X17 red after, base run did not finish → B «not compared», never C"
else bad "X17 base did not finish → B" "$(head -c 400 "$TMPROOT/x17.json")"; fi

# ── X18 ────────────────────────────────────────────────────────────────────────────────────────
R="$TMPROOT/x18"; mkrepo "$R" 'echo ok'; B=$(g -C "$R" rev-parse HEAD)
LN='scripts/test_$(touch PWNED)_lanes.sh'
printf '#!/usr/bin/env bash\necho fine\n' > "$R/$LN"; g -C "$R" add -A; g -C "$R" commit -qm change
run_exec x18 "$R" "$B"
# (no `find | grep -q`: under pipefail an early-exit consumer can turn a found PWNED into a false green — the class E0 scans for)
PW=$(find "$TMPROOT" -name PWNED -print 2>/dev/null)
if [ "$(q x18 '.e1.status')" = ran ] && [ -z "$PW" ] && [ "$(q x18 '.findings|length')" = 0 ]; then
  ok "X18 a lane file name with shell syntax runs as a path, its spelling runs nothing"
else bad "X18 lane name is not code" "pwned=${PW:-none} $(head -c 300 "$TMPROOT/x18.json")"; fi

# ── X19 ────────────────────────────────────────────────────────────────────────────────────────
R="$TMPROOT/x19"; mkrepo "$R" 'echo ok'; B=$(g -C "$R" rev-parse HEAD)
printf '#!/usr/bin/env bash\n# touch\necho ok\n' > "$R/scripts/foo.sh"; g -C "$R" commit -qam change
TMPDIR="$TMPROOT/no/such/dir" run_exec x19 "$R" "$B"
if [ "$RC" -eq 0 ] && [ "$(q x19 '[.findings[]|select(.grade=="B" and .source=="exec")]|length')" = 1 ] && [ "$(q x19 '.e1.status')" = not-run ]; then
  ok "X19 no temporary folder → B «could not run», not a silent NOT RUN"
else bad "X19 mktemp fails → B" "rc=$RC $(head -c 300 "$TMPROOT/x19.json")"; fi

# ── X20 ────────────────────────────────────────────────────────────────────────────────────────
R="$TMPROOT/x20"; mkrepo "$R" 'echo ok'; B=$(g -C "$R" rev-parse HEAD)
printf '#!/usr/bin/env bash\necho red; exit 1\n' > "$R/scripts/new_check.sh"; g -C "$R" add -A; g -C "$R" commit -qm change
FH_GATE_LANES='bash scripts/new_check.sh' run_exec x20 "$R" "$B"
if [ "$(q x20 '[.findings[]|select(.source=="E1")]|map(.grade)|join(",")')" = A ]; then ok "X20 a declared lane new with this change, red → A (not «red before»)"
else bad "X20 new declared lane → A" "$(head -c 400 "$TMPROOT/x20.json")"; fi

# ── X15 ────────────────────────────────────────────────────────────────────────────────────────
# A scanner whose own known pair fails must not report «0 new». The fake scanner below exits 2 the way
# pipefail_earlyexit_scan.sh does when its self-test fails.
R="$TMPROOT/x15"; mkrepo "$R" 'echo ok'; B=$(g -C "$R" rev-parse HEAD)
printf '#!/usr/bin/env bash\n# touch\necho ok\n' > "$R/scripts/foo.sh"; g -C "$R" commit -qam change
FAKESCAN="$TMPROOT/fake_scan.sh"; printf '#!/usr/bin/env bash\necho "INSTRUMENT ERROR" >&2\nexit 2\n' > "$FAKESCAN"
FH_GATE_E0_SCANNER="$FAKESCAN" run_exec x15 "$R" "$B"
if [ "$(q x15 '[.findings[]|select(.grade=="B" and .source=="E0")]|length')" = 1 ] && qm x15 '.e0.detail' 'instrument error' i; then
  ok "X15 scanner self-test fails → B «instrument error», not «0 new»"
else bad "X15 scanner instrument error → B" "$(head -c 400 "$TMPROOT/x15.json")"; fi

echo "exec lanes: $pass passed, $fail failed$([ "${skip:-0}" -gt 0 ] && printf ', %s skipped (not a pass)' "$skip")"
[ "$fail" -eq 0 ]
