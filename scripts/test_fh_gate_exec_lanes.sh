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
#   X21 six lanes the change adds, cap 6                → base lanes run first (A), the biting cap is a B
#   X22 red lane, base copy cannot be built             → B «not compared», never A
#   X23 six trivially edited lanes, cap 6               → the untouched guard lane still runs → A
#   O1–O14 base overlay (Lean RFC item 2): the BASE version of each lane file the change edits or deletes runs on the
#       change; red here and green at base → B with escalate:true (never A); red at base too → C; could not compare → B.
#       O1 loosened lane · O2 strengthened · O3 untouched · O4 renamed subject · O5 deleted lane · O6 red at base · O7 plan
#       · O8 self-restoring lane · O9 tab in name · O10 lane → symlink · O11 base-copy tamper · O12 base = HEAD
#       · O13 patch tamper · O14 base lane was a symlink
#   L7  red at base and red after the change (X2 · O6) → still C, and named «attribution undecided» in the finding,
#       the E1 detail and the provenance record; an A (X1) carries no such name
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

# ── X21 (G3): six lanes the change adds cannot push a base lane past the cap; the cap that bites is a B ──────────────
R="$TMPROOT/x21"; mkrepo "$R" 'echo ok'; B=$(g -C "$R" rev-parse HEAD)
printf '#!/usr/bin/env bash\necho broken\n' > "$R/scripts/foo.sh"
for i in 1 2 3 4 5 6; do printf '#!/usr/bin/env bash\n# names foo.sh\nexit 0\n' > "$R/scripts/test_pad${i}_lanes.sh"; done
g -C "$R" add -A; g -C "$R" commit -qm "break foo + pad lanes"
FH_GATE_MAX_LANES=6 run_exec x21 "$R" "$B"
if [ "$(q x21 '[.findings[]|select(.grade=="A" and .location=="bash scripts/test_foo_lanes.sh")]|length')" = 1 ] \
   && [ "$(q x21 '[.findings[]|select(.grade=="B" and .location=="(lane cap)")]|length')" = 1 ]; then
  ok "X21 lanes the change adds go after base lanes: the real lane still runs (A), and the biting cap is a B"
else bad "X21 cap ordering" "$(head -c 700 "$TMPROOT/x21.json")"; fi
# ── X22 (G4): a lane red now whose base copy cannot be built → B «not compared», never A ─────────────────────────────
# the red lane itself plants a file where the base copy would be cloned, so the clone fails
R="$TMPROOT/x22"; mkrepo "$R" 'echo ok'; B=$(g -C "$R" rev-parse HEAD)
printf '#!/usr/bin/env bash\necho broken\n' > "$R/scripts/foo.sh"
printf '#!/usr/bin/env bash\n: > ../base\nexit 1\n' > "$R/scripts/test_foo_lanes.sh"; g -C "$R" commit -qam change
run_exec x22 "$R" "$B"
# (the change also edits the lane, so the base overlay adds its own finding — X22 reads only the E1 lane run)
if [ "$(q x22 '[.findings[]|select(.source=="E1" and (.location|startswith("base version of")|not))]|map(.grade)|join(",")')" = B ] && qm x22 '.findings[0].title' 'base copy could not be built'; then
  ok "X22 base copy cannot be built → B «not compared», not A"
else bad "X22 base copy failure" "$(head -c 600 "$TMPROOT/x22.json")"; fi
# ── X23 (G3, codex R1): touching six existing lanes cannot push the untouched guard lane past the cap ───────────────
R="$TMPROOT/x23"; mkrepo "$R" 'echo ok'
for i in 1 2 3 4 5 6; do printf '#!/usr/bin/env bash\n# names foo.sh\nexit 0\n' > "$R/scripts/test_aa${i}_lanes.sh"; done
g -C "$R" add -A; g -C "$R" commit -qm "more lanes"; B=$(g -C "$R" rev-parse HEAD)
printf '#!/usr/bin/env bash\necho broken\n' > "$R/scripts/foo.sh"
for i in 1 2 3 4 5 6; do printf '# touched\n' >> "$R/scripts/test_aa${i}_lanes.sh"; done; g -C "$R" commit -qam "break foo + touch lanes"
FH_GATE_MAX_LANES=6 run_exec x23 "$R" "$B"
if [ "$(q x23 '[.findings[]|select(.grade=="A" and .location=="bash scripts/test_foo_lanes.sh")]|length')" = 1 ]; then
  ok "X23 six trivially edited lanes do not push the untouched guard lane past the cap → A"
else bad "X23 touched-lane ordering" "$(head -c 700 "$TMPROOT/x23.json")"; fi
# X23b the same on a large change (8000 more changed paths after the edited lanes): the «is this lane edited» test must
#      not die by SIGPIPE under pipefail and file an edited lane as untouched (codex R2)
mkdir -p "$R/zz"; ( cd "$R/zz" && i=0; while [ "$i" -lt 8000 ]; do : > "f$i"; i=$((i + 1)); done )
FH_GATE_MAX_LANES=6 run_exec x23b "$R" "$B"
if [ "$(q x23b '[.findings[]|select(.grade=="A" and .location=="bash scripts/test_foo_lanes.sh")]|length')" = 1 ]; then
  ok "X23b on a change with 8000 more paths the edited lanes are still ordered after the guard → A"
else bad "X23b large change ordering" "$(head -c 500 "$TMPROOT/x23b.json")"; fi

# ── O1–O14: base overlay (Lean RFC item 2) — red here + green at base is B with escalate:true («B!»), never A; the base version of a lane file the change edits or deletes, run on the change's tree ───
ovl_q() { q "$1" '[.findings[]|select(.location|startswith("base version of"))]|map(.grade + (if .escalate == true then "!" else "" end))|join(",")'; }
# O1 (a) the change breaks foo AND loosens its lane so it passes → E1 green, base overlay A
R="$TMPROOT/o1"; mkrepo "$R" 'echo ok'; B=$(g -C "$R" rev-parse HEAD)
printf '#!/usr/bin/env bash\necho broken\n' > "$R/scripts/foo.sh"
printf '#!/usr/bin/env bash\nbash scripts/foo.sh >/dev/null\necho "PASS foo"\n' > "$R/scripts/test_foo_lanes.sh"; g -C "$R" commit -qam "loosen"
run_exec o1 "$R" "$B"
if [ "$(ovl_q o1)" = "B!" ] && [ "$(q o1 '[.findings[]|select(.location=="bash scripts/test_foo_lanes.sh")]|length')" = 0 ] \
   && qm o1 '.findings[0].title' 'base version is red on this tree' && qm o1 '.e1.detail' 'base overlay: 1 .* 1 red here'; then
  ok "O1 lane loosened + code broken → the change's own lane is green, its base version is B with escalate (never A)"
else bad "O1 loosened lane → A" "$(head -c 600 "$TMPROOT/o1.json")"; fi
# O2 (b) the change strengthens the lane; code correct → no finding
R="$TMPROOT/o2"; mkrepo "$R" 'echo ok'; B=$(g -C "$R" rev-parse HEAD)
printf '#!/usr/bin/env bash\nout=$(bash scripts/foo.sh)\n[ -n "$out" ] || exit 1\n[ "$out" = ok ] || { echo "FAIL foo printed: $out"; exit 1; }\necho "PASS foo"\n' > "$R/scripts/test_foo_lanes.sh"; g -C "$R" commit -qam "strengthen"
run_exec o2 "$R" "$B"
if [ "$(q o2 '.findings|length')" = 0 ] && qm o2 '.e1.detail' 'base overlay: 1 .* 0 red here, 0 red at base too, 0 could not run'; then
  ok "O2 lane strengthened, code correct → base version green, no finding"
else bad "O2 strengthened lane → none" "$(head -c 600 "$TMPROOT/o2.json")"; fi
# O3 (c) no lane file touched → no overlay at all (detail as before)
R="$TMPROOT/o3"; mkrepo "$R" 'echo ok'; B=$(g -C "$R" rev-parse HEAD)
printf '#!/usr/bin/env bash\n# still fine\necho ok\n' > "$R/scripts/foo.sh"; g -C "$R" commit -qam change
run_exec o3 "$R" "$B"
if [ "$(q o3 '.findings|length')" = 0 ] && ! qm o3 '.e1.detail' 'overlay' && qm o3 '.e1.detail' '^ran 1 lane\(s\), discovered — 0 red, 0 red before, 0 did not finish'; then
  ok "O3 no lane file touched → no overlay, detail unchanged"
else bad "O3 untouched lanes → as today" "$(q o3 '.e1.detail')"; fi
# O4 the change renames the subject and updates its lane; the base lane cannot find its subject → B «could not run»
R="$TMPROOT/o4"; mkrepo "$R" 'echo ok'
printf '#!/usr/bin/env bash\n[ -f scripts/foo.sh ] || { echo "HARNESS-ERROR: scripts/foo.sh missing"; exit 2; }\n[ "$(bash scripts/foo.sh)" = ok ] || exit 1\n' > "$R/scripts/test_foo_lanes.sh"; g -C "$R" commit -qam "guarded lane"; B=$(g -C "$R" rev-parse HEAD)
g -C "$R" mv scripts/foo.sh scripts/bar.sh
printf '#!/usr/bin/env bash\n[ -f scripts/bar.sh ] || { echo "HARNESS-ERROR: scripts/bar.sh missing"; exit 2; }\n[ "$(bash scripts/bar.sh)" = ok ] || exit 1\n' > "$R/scripts/test_foo_lanes.sh"; g -C "$R" add -A; g -C "$R" commit -qm rename
run_exec o4 "$R" "$B"
if [ "$(ovl_q o4)" = B ] && qm o4 '.findings[0].title' 'could not run on this tree \(rc 2\)'; then
  ok "O4 subject renamed → the base lane cannot run here → B «could not run» (no escalate), never silent"
else bad "O4 rename → B" "$(head -c 600 "$TMPROOT/o4.json")"; fi
# O5 the change deletes the lane and breaks foo → no lane is discovered, the base version still runs → A
R="$TMPROOT/o5"; mkrepo "$R" 'echo ok'; B=$(g -C "$R" rev-parse HEAD)
printf '#!/usr/bin/env bash\necho broken\n' > "$R/scripts/foo.sh"; g -C "$R" rm -q scripts/test_foo_lanes.sh; g -C "$R" commit -qam "drop lane"
run_exec o5 "$R" "$B"
if [ "$(ovl_q o5)" = "B!" ] && [ "$(q o5 '.e1.status')" = ran ] && qm o5 '.findings[0].title' 'deleted by this change'; then
  ok "O5 lane deleted + code broken → the base version runs anyway → B escalate"
else bad "O5 deleted lane → A" "$(head -c 600 "$TMPROOT/o5.json")"; fi
# O6 the base lane was red at base too → C, not A
R="$TMPROOT/o6"; mkrepo "$R" 'echo broken'; B=$(g -C "$R" rev-parse HEAD)
printf '# edited\n' >> "$R/scripts/test_foo_lanes.sh"; g -C "$R" commit -qam "touch lane"
run_exec o6 "$R" "$B"
if [ "$(ovl_q o6)" = C ]; then ok "O6 base version red at base too → C"
else bad "O6 red before → C" "$(head -c 600 "$TMPROOT/o6.json")"; fi
# O7 --plan names the overlay, runs nothing
run_exec o7 "$TMPROOT/o1" "$(g -C "$TMPROOT/o1" rev-parse HEAD~1)" --plan
if [ "$(q o7 '.e1.status')" = planned ] && qm o7 '.e1.detail' 'would also run the base version of 1 lane file' && [ "$(q o7 '.findings|length')" = 0 ]; then
  ok "O7 --plan lists the base overlay, runs nothing"
else bad "O7 plan" "$(q o7 '.e1.detail')"; fi
# O8 the edited lane restores its own base copy when E1 runs it, then exits 0 — the overlay list was made before
#     any lane ran, so the base version still runs → A (codex R1)
R="$TMPROOT/o8"; mkrepo "$R" 'echo ok'; B=$(g -C "$R" rev-parse HEAD)
printf '#!/usr/bin/env bash\necho broken\n' > "$R/scripts/foo.sh"
printf '#!/usr/bin/env bash\ngit checkout -q HEAD~1 -- scripts/test_foo_lanes.sh 2>/dev/null\nexit 0\n' > "$R/scripts/test_foo_lanes.sh"; g -C "$R" commit -qam "self-restoring lane"
run_exec o8 "$R" "$B"
if [ "$(ovl_q o8)" = "B!" ]; then ok "O8 a lane that restores its base copy while E1 runs it is still overlaid → B escalate"
else bad "O8 self-restoring lane" "$(head -c 600 "$TMPROOT/o8.json")"; fi
# O9 an edited lane whose name holds a tab (git quotes it) → B, never skipped (codex R1)
R="$TMPROOT/o9"; mkrepo "$R" 'echo ok'
printf '#!/usr/bin/env bash\nexit 0\n' > "$R/scripts/test_a	b_lanes.sh"; g -C "$R" add -A; g -C "$R" commit -qm tabbed; B=$(g -C "$R" rev-parse HEAD)
printf '# edit\n' >> "$R/scripts/test_a	b_lanes.sh"; g -C "$R" commit -qam edit
run_exec o9 "$R" "$B"
if [ "$(q o9 '[.findings[]|select(.location=="(base overlay)" and .grade=="B")]|length')" = 1 ]; then ok "O9 a tab in an edited lane's name → B, not skipped"
else bad "O9 tabbed lane name" "$(head -c 600 "$TMPROOT/o9.json")"; fi
# O10 the change turns the lane into a symlink to foo.sh → writing the base lane there would overwrite foo.sh → B (codex R1)
R="$TMPROOT/o10"; mkrepo "$R" 'echo ok'; B=$(g -C "$R" rev-parse HEAD)
g -C "$R" rm -q scripts/test_foo_lanes.sh; ln -s foo.sh "$R/scripts/test_foo_lanes.sh"; g -C "$R" add -A; g -C "$R" commit -qm "lane → symlink"
run_exec o10 "$R" "$B"
if [ "$(ovl_q o10)" = B ] && qm o10 '[.findings[]|select(.location|startswith("base version of"))][0].title' 'symlink'; then
  ok "O10 a lane turned into a symlink → B (the base lane is not written through it)"
else bad "O10 symlinked lane" "$(head -c 600 "$TMPROOT/o10.json")"; fi
# O11 a declared E1 command rewrites the lane inside the shared base copy → the overlay uses its own fresh base copy,
#     so a real regression stays A, not C (codex R1)
R="$TMPROOT/o11"; mkrepo "$R" 'echo ok'; B=$(g -C "$R" rev-parse HEAD)
printf '#!/usr/bin/env bash\necho broken\n' > "$R/scripts/foo.sh"
printf '#!/usr/bin/env bash\necho PASS\n' > "$R/scripts/test_foo_lanes.sh"; g -C "$R" commit -qam "loosen"
FH_GATE_LANES="printf 'exit 1\n' > scripts/test_foo_lanes.sh; exit 1" run_exec o11 "$R" "$B"
if [ "$(ovl_q o11)" = "B!" ]; then ok "O11 an E1 command that rewrites the base copy's lane does not turn the overlay's B escalate into C"
else bad "O11 base copy tamper" "$(head -c 600 "$TMPROOT/o11.json")"; fi
# O12 base = HEAD, the change is uncommitted; red at base too → C. The base copy must be the base commit alone, not
#     HEAD + the uncommitted patch (that would run the loosened lane and say A) (codex R2)
R="$TMPROOT/o12"; mkrepo "$R" 'echo broken'; B=$(g -C "$R" rev-parse HEAD)
printf '#!/usr/bin/env bash\necho PASS\n' > "$R/scripts/test_foo_lanes.sh"
run_exec o12 "$R" "$B"
if [ "$(ovl_q o12)" = C ]; then ok "O12 uncommitted lane edit with base = HEAD → the base copy has no patch → C"
else bad "O12 base copy carries the patch" "$(head -c 600 "$TMPROOT/o12.json")"; fi
# O13 an edited lane that, while E1 runs it, empties the files next to its copy (the old list file, the patch) →
#     the overlay still runs (the list is in memory) and a tampered patch is B, never silent (codex R2)
R="$TMPROOT/o13"; mkrepo "$R" 'echo ok'; B=$(g -C "$R" rev-parse HEAD)
printf '#!/usr/bin/env bash\necho broken\n' > "$R/scripts/foo.sh"
printf '#!/usr/bin/env bash\n: > ../overlay_lanes 2>/dev/null; : > ../overlay.patch 2>/dev/null; exit 0\n' > "$R/scripts/test_foo_lanes.sh"
run_exec o13 "$R" "$B"
if [ "$(ovl_q o13)" = B ] && qm o13 '.e1.detail' 'base overlay: 1 '; then ok "O13 a lane that tampers with files next to its copy → the overlay still runs; tampered patch → B"
else bad "O13 tamper" "$(head -c 700 "$TMPROOT/o13.json")"; fi
# O14 the base lane was a symlink to a real lane script; the change replaces it with a loosened file and breaks foo →
#     the link is put back and the real lane runs → A, not a spurious B (codex R2)
R="$TMPROOT/o14"; mkrepo "$R" 'echo ok'
g -C "$R" mv scripts/test_foo_lanes.sh scripts/real_check.sh; ln -s real_check.sh "$R/scripts/test_foo_lanes.sh"; g -C "$R" add -A; g -C "$R" commit -qm "lane is a link"; B=$(g -C "$R" rev-parse HEAD)
rm "$R/scripts/test_foo_lanes.sh"; printf '#!/usr/bin/env bash\necho PASS\n' > "$R/scripts/test_foo_lanes.sh"
printf '#!/usr/bin/env bash\necho broken\n' > "$R/scripts/foo.sh"; g -C "$R" add -A; g -C "$R" commit -qm "loosen"
run_exec o14 "$R" "$B"
if [ "$(ovl_q o14)" = "B!" ]; then ok "O14 a base lane that was a symlink is restored as a link → B escalate"
else bad "O14 base symlink lane" "$(head -c 700 "$TMPROOT/o14.json")"; fi

# ── L7 ─────────────────────────────────────────────────────────────────────────────────────────
# Red at base and red after the change does not show the change is harmless — it may break the lane a second way.
# The grade stays C; the case is named, so a reader of the finding, the detail or the record does not read «not ours».
l7_ok=1; l7_why=""
for n in x2 o6; do
  if [ "$n" = x2 ]; then sel='[.findings[]|select(.source=="E1" and (.location|startswith("base version of")|not))]'
  else sel='[.findings[]|select(.location|startswith("base version of"))]'; fi
  [ "$(q "$n" "$sel|map(.grade)|join(\",\")")" = C ] || { l7_ok=0; l7_why="$l7_why $n:grade"; }
  [ "$(q "$n" "$sel|map(.attribution // \"-\")|join(\",\")")" = undecided ] || { l7_ok=0; l7_why="$l7_why $n:field"; }
  qm "$n" "$sel|.[0].title" 'attribution undecided' || { l7_ok=0; l7_why="$l7_why $n:title"; }
  qm "$n" "$sel|.[0].fix" 'attribution undecided' || { l7_ok=0; l7_why="$l7_why $n:fix"; }
  [ "$(q "$n" '[.provenance.attribution_undecided[]?]|length')" -ge 1 ] 2>/dev/null || { l7_ok=0; l7_why="$l7_why $n:prov"; }
done
qm x2 '.e1.detail' 'attribution undecided: 1 ' || { l7_ok=0; l7_why="$l7_why x2:detail"; }
qm o6 '.e1.detail' 'base overlay: [^·]* · attribution undecided: 1 ' || { l7_ok=0; l7_why="$l7_why o6:overlay-detail"; }   # the overlay's own segment
[ "$(q x2 '[.provenance.attribution_undecided[]?|select(.run=="change")]|length')" = 1 ] || { l7_ok=0; l7_why="$l7_why x2:prov-run"; }
[ "$(q o6 '[.provenance.attribution_undecided[]?|select(.run=="base-overlay")]|length')" = 1 ] || { l7_ok=0; l7_why="$l7_why o6:prov-run"; }
# control: an A is not «undecided», and a run with no red/red says nothing
[ "$(q x1 '[.findings[]|select(has("attribution"))]|length')" = 0 ] || { l7_ok=0; l7_why="$l7_why x1:has-field"; }
[ "$(q x1 '[.provenance.attribution_undecided[]?]|length')" = 0 ] || { l7_ok=0; l7_why="$l7_why x1:prov"; }
qm x1 '.e1.detail' 'attribution undecided' && { l7_ok=0; l7_why="$l7_why x1:detail"; }
if [ "$l7_ok" = 1 ]; then ok "L7 red/red stays C and is named «attribution undecided» (finding · detail · provenance); an A is not"
else bad "L7 red/red attribution undecided" "missing:$l7_why"; fi

echo "exec lanes: $pass passed, $fail failed$([ "${skip:-0}" -gt 0 ] && printf ', %s skipped (not a pass)' "$skip")"
[ "$fail" -eq 0 ]
