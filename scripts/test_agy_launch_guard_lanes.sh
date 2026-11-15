#!/usr/bin/env bash
# test_agy_launch_guard_lanes.sh — lanes for scripts/agy_launch_guard.sh and the three FH callers that
# launch agy (finding_fleet.sh default fleet · finding_verifier.sh --family gemini · sidecar_calibrate.sh).
#
# WHAT IS CHECKED: that no FH caller starts agy unless FH_AGY_ISOLATION is exactly `container` or
# `os-user`, that a refused launch is visible (AGY-REFUSED on stderr, non-zero), and that with the marker
# the call goes through with its arguments intact. Every lane uses a FAKE agy that only records that it
# was started — no real agy runs here.
# WHAT IS NOT CHECKED: whether the isolation the marker names is real. The marker is self-declared;
# no lane here can see a container or an OS user. Doc snippets (steel-quench / sim-conductor) that show
# `agy -p` are prose, not scripts, and are outside the static scan in G9.
#
# Usage: bash scripts/test_agy_launch_guard_lanes.sh      Exit: 0 all pass · 1 any fail
set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
GUARD="$REPO/scripts/agy_launch_guard.sh"
FLEET="$REPO/scripts/finding_fleet.sh"
VERIFIER="$REPO/scripts/finding_verifier.sh"
CAL="$REPO/scripts/sidecar_calibrate.sh"
D="$(mktemp -d "${TMPDIR:-/tmp}/agyguard.XXXXXX")" || { echo "ENV-BLOCKED: mktemp failed — unmeasured, not a pass"; exit 1; }
trap 'rm -rf "$D"' EXIT
unset FH_AGY_ISOLATION
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ✅ $1"; }
bad() { FAIL=$((FAIL+1)); echo "  ❌ $1"; }

# Fake agy: records that it started (and its argv, one per line), prints one JSONL finding / one word.
mkfake() { # $1 = path  $2 = sentinel
  cat > "$1" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$@" > "$2"
cat >/dev/null 2>&1 || true
echo '{"title":"fake finding","file":"t.py","line":1,"severity":"B","category":"x","detail":"d","defeater":"df","confidence":0.5}'
EOF
  chmod +x "$1"
}
mkfake "$D/agy_fake" "$D/ran"
# Hermetic floor: a recording `agy` on the underlying PATH. If interception ever breaks, a bare `agy`
# lands here (recorded in ran_host) instead of on a real CLI. Every lane also asserts it never started.
mkdir -p "$D/hostbin"; mkfake "$D/hostbin/agy" "$D/ran_host"
export PATH="$D/hostbin:$PATH"
printf 'def f():\n    return 1\n' > "$D/t.py"

echo "── guard alone"
# G1 no marker → refused, fake never started
rm -f "$D/ran"
out=$(bash "$GUARD" "$D/agy_fake" -p "hello" < /dev/null 2>&1); rc=$?
if [ "$rc" -eq 3 ] && [ ! -e "$D/ran" ] && printf '%s' "$out" | grep -q 'AGY-REFUSED'; then ok "G1 no marker: rc=3, AGY-REFUSED, agy not started"
else bad "G1 no marker: rc=$rc ran=$([ -e "$D/ran" ] && echo yes || echo no) out=${out:0:120}"; fi

# G2 marker=container → started, argv intact (an argument with spaces survives as one)
rm -f "$D/ran"
FH_AGY_ISOLATION=container bash "$GUARD" "$D/agy_fake" -p "two words" --mode plan < /dev/null >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 0 ] && [ -e "$D/ran" ] && [ "$(sed -n 2p "$D/ran")" = "two words" ] && [ "$(wc -l < "$D/ran" | tr -d ' ')" = 4 ]; then
  ok "G2 container: started, argv intact"
else bad "G2 container: rc=$rc argv=$(tr '\n' '|' < "$D/ran" 2>/dev/null)"; fi

# G3 marker=os-user → started
rm -f "$D/ran"
FH_AGY_ISOLATION=os-user bash "$GUARD" "$D/agy_fake" -p x < /dev/null >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] && [ -e "$D/ran" ] && ok "G3 os-user: started" || bad "G3 os-user: rc=$rc"

# G4 near-miss values → refused (a truthy word is not an isolation statement)
for v in 1 yes true Container "container " none ""; do
  rm -f "$D/ran"
  FH_AGY_ISOLATION="$v" bash "$GUARD" "$D/agy_fake" -p x < /dev/null >/dev/null 2>&1; rc=$?
  if [ "$rc" -eq 3 ] && [ ! -e "$D/ran" ]; then ok "G4 value '$v': refused"; else bad "G4 value '$v': rc=$rc started=$([ -e "$D/ran" ] && echo yes || echo no)"; fi
done

# G5 no binary given → usage, nothing started
bash "$GUARD" < /dev/null >/dev/null 2>&1; rc=$?
[ "$rc" -eq 2 ] && ok "G5 no args: rc=2" || bad "G5 no args: rc=$rc"

echo "── finding_fleet.sh default fleet (gemini row)"
cat > "$D/codex_fake" <<'EOF'
#!/usr/bin/env bash
cat >/dev/null 2>&1 || true
echo '{"title":"codex finding","file":"t.py","line":1,"severity":"B","category":"x","detail":"d","defeater":"df","confidence":0.5}'
EOF
chmod +x "$D/codex_fake"
# G6 no marker → gemini member not started and recorded as failed with the refusal; codex still runs
rm -f "$D/ran"
FH_CODEX_BIN="$D/codex_fake" FH_AGY_BIN="$D/agy_fake" bash "$FLEET" "$D/t.py" --out "$D/f6" < /dev/null > "$D/f6.out" 2>&1; rc=$?
if [ ! -e "$D/ran" ] && grep -qs 'AGY-REFUSED' "$D/f6/err_gemini_security.txt" && [ "$rc" -eq 0 ]; then
  ok "G6 fleet no marker: gemini refused (err file), codex member kept rc=0"
else bad "G6 fleet no marker: rc=$rc agy_started=$([ -e "$D/ran" ] && echo yes || echo no) err=$(head -c 120 "$D/f6/err_gemini_security.txt" 2>/dev/null)"; fi
# G7 control — with the marker the same fleet DOES start the fake (the lane can see a start)
rm -f "$D/ran"
FH_AGY_ISOLATION=container FH_CODEX_BIN="$D/codex_fake" FH_AGY_BIN="$D/agy_fake" bash "$FLEET" "$D/t.py" --out "$D/f7" < /dev/null > "$D/f7.out" 2>&1; rc=$?
[ -e "$D/ran" ] && [ "$rc" -eq 0 ] && ok "G7 fleet with marker: gemini member started (control alive)" || bad "G7 fleet with marker: rc=$rc started=$([ -e "$D/ran" ] && echo yes || echo no)"

# G7b round 2 without the marker (reusing G7's round-1 findings) → not started, refusal in the r2 err file
rm -f "$D/ran"
FH_CODEX_BIN="$D/codex_fake" FH_AGY_BIN="$D/agy_fake" bash "$FLEET" "$D/t.py" --out "$D/f7b" --reuse-r1 "$D/f7" --round2 < /dev/null > "$D/f7b.out" 2>&1
if [ ! -e "$D/ran" ] && grep -qs 'AGY-REFUSED' "$D/f7b/err2_gemini_security.txt"; then ok "G7b fleet round 2 no marker: gemini refused"
else bad "G7b fleet round 2 no marker: started=$([ -e "$D/ran" ] && echo yes || echo no) err=$(head -c 120 "$D/f7b/err2_gemini_security.txt" 2>/dev/null)"; fi
# G7c control — round 2 with the marker starts it
rm -f "$D/ran"
FH_AGY_ISOLATION=container FH_CODEX_BIN="$D/codex_fake" FH_AGY_BIN="$D/agy_fake" bash "$FLEET" "$D/t.py" --out "$D/f7c" --reuse-r1 "$D/f7" --round2 < /dev/null > "$D/f7c.out" 2>&1
[ -e "$D/ran" ] && ok "G7c fleet round 2 with marker: started (control alive)" || bad "G7c fleet round 2 with marker: not started"
# G7d custom table rows that reach agy by NAME, in shapes a word match misses (redirection glued to the
#     name, behind `env`, AGY_BIN behind `env`) → refused without the marker; G7e same rows with it → started.
#     The real binary is FH_AGY_BIN (the fake); the shim on PATH is what a bare `agy` resolves to.
n=0
for row in 'agy -p "$(cat PROMPT_FILE)"' 'agy</dev/null -p hello' 'env agy -p hello' 'env AGY_BIN -p hello'; do
  n=$((n+1)); printf 'gemini|security|%s\n' "$row" > "$D/direct$n.tbl"
  rm -f "$D/ran"
  FH_AGY_BIN="$D/agy_fake" bash "$FLEET" "$D/t.py" --out "$D/f7d$n" --fleet "$D/direct$n.tbl" < /dev/null > "$D/f7d$n.out" 2>&1
  if [ ! -e "$D/ran" ] && grep -qs 'AGY-REFUSED' "$D/f7d$n/err_gemini_security.txt"; then ok "G7d row [$row]: refused without marker"
  else bad "G7d row [$row]: started=$([ -e "$D/ran" ] && echo yes || echo no)"; fi
  rm -f "$D/ran"
  FH_AGY_ISOLATION=os-user FH_AGY_BIN="$D/agy_fake" bash "$FLEET" "$D/t.py" --out "$D/f7e$n" --fleet "$D/direct$n.tbl" < /dev/null > "$D/f7e$n.out" 2>&1
  [ -e "$D/ran" ] && ok "G7e row [$row]: started with marker (control alive)" || bad "G7e row [$row]: not started with marker ($(head -c 100 "$D/f7e$n/err_gemini_security.txt" 2>/dev/null))"
done
# G7d-r2 a by-name row in ROUND 2 without the marker → refused (refusal text in the r2 err file);
#        G7e-r2 same with the marker → started. Round-1 findings come from G7's run.
printf 'gemini|security|%s\n' 'agy -p "$(cat PROMPT_FILE)"' > "$D/direct_r2.tbl"
# --reuse-r1 takes the fleet from the round-1 dir, so round 1 runs with THIS table (marker on, r1 only)
FH_AGY_ISOLATION=container FH_AGY_BIN="$D/agy_fake" bash "$FLEET" "$D/t.py" --out "$D/f7r1d" --fleet "$D/direct_r2.tbl" --r1-only < /dev/null > /dev/null 2>&1
rm -f "$D/ran"
FH_AGY_BIN="$D/agy_fake" bash "$FLEET" "$D/t.py" --out "$D/f7dr2" --reuse-r1 "$D/f7r1d" --round2 < /dev/null > "$D/f7dr2.out" 2>&1
if [ ! -e "$D/ran" ] && grep -qs 'AGY-REFUSED' "$D/f7dr2/err2_gemini_security.txt"; then ok "G7d-r2 by-name row in round 2: refused without marker"
else bad "G7d-r2 by-name row in round 2: started=$([ -e "$D/ran" ] && echo yes || echo no) err=$(head -c 100 "$D/f7dr2/err2_gemini_security.txt" 2>/dev/null)"; fi
rm -f "$D/ran"
FH_AGY_ISOLATION=container FH_AGY_BIN="$D/agy_fake" bash "$FLEET" "$D/t.py" --out "$D/f7er2" --reuse-r1 "$D/f7r1d" --round2 < /dev/null > "$D/f7er2.out" 2>&1
[ -e "$D/ran" ] && ok "G7e-r2 by-name row in round 2 with marker: started (control alive)" || bad "G7e-r2 by-name row in round 2 with marker: not started"
# G7j an exported shell function named agy does not outrank the shim
agy() { : > "$D/ran_func"; }; export -f agy
rm -f "$D/ran" "$D/ran_func"
FH_AGY_BIN="$D/agy_fake" bash "$FLEET" "$D/t.py" --out "$D/f7j" --fleet "$D/direct1.tbl" < /dev/null > "$D/f7j.out" 2>&1
unset -f agy
if [ ! -e "$D/ran_func" ] && [ ! -e "$D/ran" ] && grep -qs 'AGY-REFUSED' "$D/f7j/err_gemini_security.txt"; then ok "G7j exported agy function: shim still wins, refused"
else bad "G7j exported agy function: func_ran=$([ -e "$D/ran_func" ] && echo yes || echo no)"; fi
# G14a hermetic floor so far — no unmarked lane above reached the underlying-PATH agy (G7k below starts it on purpose)
[ ! -e "$D/ran_host" ] && ok "G14a underlying-PATH agy not started by G1–G7j" || bad "G14a underlying-PATH agy was started before G7k — interception broke"
# G7k FH_AGY_BIN given as a bare name resolves once (no shim loop) — with the marker the PATH agy starts
rm -f "$D/ran_host"
FH_AGY_ISOLATION=container FH_CODEX_BIN="$D/codex_fake" FH_AGY_BIN=agy bash "$FLEET" "$D/t.py" --out "$D/f7k" < /dev/null > "$D/f7k.out" 2>&1 &
kpid=$!; k=0; while kill -0 "$kpid" 2>/dev/null && [ "$k" -lt 30 ]; do sleep 1; k=$((k+1)); done
if kill -0 "$kpid" 2>/dev/null; then kill "$kpid" 2>/dev/null; bad "G7k bare FH_AGY_BIN: still running after 30s (shim loop)"
elif [ -e "$D/ran_host" ]; then ok "G7k bare FH_AGY_BIN=agy: resolved to the PATH binary once"
else bad "G7k bare FH_AGY_BIN=agy: PATH agy never started"; fi
rm -f "$D/ran_host"
# G7h over-block control — a codex row whose TEXT mentions agy is not refused
printf 'codex|logic|%s\n' 'CODEX_BIN exec "review agy behavior"' > "$D/text.tbl"
FH_CODEX_BIN="$D/codex_fake" bash "$FLEET" "$D/t.py" --out "$D/f7i" --fleet "$D/text.tbl" < /dev/null > "$D/f7i.out" 2>&1; rc=$?
if [ "$rc" -eq 0 ] && ! grep -qs 'AGY-REFUSED' "$D/f7i/err_codex_logic.txt"; then ok "G7h codex row mentioning agy in text: runs (no over-block)"
else bad "G7h codex row mentioning agy in text: rc=$rc"; fi
# G7f a row that quotes the token ("AGY_BIN") still names one command (with the marker it starts)
printf 'gemini|security|%s\n' '"AGY_BIN" -p "$(cat PROMPT_FILE)"' > "$D/quoted.tbl"
rm -f "$D/ran"
FH_AGY_ISOLATION=container FH_AGY_BIN="$D/agy_fake" bash "$FLEET" "$D/t.py" --out "$D/f7f" --fleet "$D/quoted.tbl" < /dev/null > "$D/f7f.out" 2>&1
[ -e "$D/ran" ] && ok "G7f quoted \"AGY_BIN\" row: started with the marker" || bad "G7f quoted \"AGY_BIN\" row: not started ($(head -c 120 "$D/f7f/err_gemini_security.txt" 2>/dev/null))"
# G7g scripts installed under a directory whose name holds `&` and the text PROMPT_FILE: no marker → refused,
#     marker → started (a pasted path could otherwise background the launch or be rewritten)
W="$D/a&agy&PROMPT_FILE"; mkdir -p "$W"; cp "$FLEET" "$GUARD" "$W/"
rm -f "$D/ran"
FH_CODEX_BIN="$D/codex_fake" FH_AGY_BIN="$D/agy_fake" bash "$W/finding_fleet.sh" "$D/t.py" --out "$D/f7g" < /dev/null > "$D/f7g.out" 2>&1
g1=$([ -e "$D/ran" ] && echo started || echo not-started)
rm -f "$D/ran"
FH_AGY_ISOLATION=container FH_CODEX_BIN="$D/codex_fake" FH_AGY_BIN="$D/agy_fake" bash "$W/finding_fleet.sh" "$D/t.py" --out "$D/f7h" < /dev/null > "$D/f7h.out" 2>&1
g2=$([ -e "$D/ran" ] && echo started || echo not-started)
[ "$g1" = not-started ] && [ "$g2" = started ] && ok "G7g odd install path: refused without marker, started with it" || bad "G7g odd install path: without=$g1 with=$g2"

echo "── finding_verifier.sh --family gemini"
printf '%s\n' '{"id":"x1","title":"t","file":"t.py","line":1,"severity":"B","category":"x","detail":"d","defeater":"df","confidence":0.5}' > "$D/claims.jsonl"
# G8 no marker → not started, non-zero
rm -f "$D/ran"
FH_AGY_BIN="$D/agy_fake" bash "$VERIFIER" --family gemini --target "$D/t.py" < "$D/claims.jsonl" > "$D/v8.out" 2> "$D/v8.err"; rc=$?
if [ ! -e "$D/ran" ] && [ "$rc" -ne 0 ]; then ok "G8 verifier no marker: agy not started, rc=$rc"
else bad "G8 verifier no marker: rc=$rc started=$([ -e "$D/ran" ] && echo yes || echo no)"; fi
# G9 control — with the marker the verifier starts it
rm -f "$D/ran"
FH_AGY_ISOLATION=container FH_AGY_BIN="$D/agy_fake" bash "$VERIFIER" --family gemini --target "$D/t.py" < "$D/claims.jsonl" >/dev/null 2>&1
[ -e "$D/ran" ] && ok "G9 verifier with marker: started (control alive)" || bad "G9 verifier with marker: not started"

echo "── sidecar_calibrate.sh --only agy"
mkdir -p "$D/bin"; mkfake "$D/bin/agy" "$D/ran"
# G10 no marker → the PATH agy is not started; the row is not PINNED/PASS
rm -f "$D/ran"
c_out=$(PATH="$D/bin:$PATH" bash "$CAL" --only agy 2>&1 < /dev/null)
if [ ! -e "$D/ran" ] && printf '%s' "$c_out" | grep -qE '^agy +REFUSED' && ! printf '%s' "$c_out" | grep -qE '^agy +.*REACHABLE'; then ok "G10 calibrate no marker: agy not started, row says REFUSED (not REACHABLE)"
else bad "G10 calibrate no marker: started=$([ -e "$D/ran" ] && echo yes || echo no) out=$(printf '%s' "$c_out" | grep -m1 '^agy' | cut -c1-120)"; fi
# G11 control — with the marker the probe starts the PATH agy
rm -f "$D/ran"
FH_AGY_ISOLATION=container PATH="$D/bin:$PATH" bash "$CAL" --only agy >/dev/null 2>&1 < /dev/null
[ -e "$D/ran" ] && ok "G11 calibrate with marker: started (control alive)" || bad "G11 calibrate with marker: not started"

echo "── static: no shipped script launches agy around the guard"
# G12 every line in scripts/*.sh (not lanes, not the guard) that starts agy with a prompt/mode flag must
#     go through the guard. Comment lines are skipped. Known residual: a launch built from pieces
#     (variables, eval of a table row other than AGY_BIN) is not seen by a line scan.
hits=$(cd "$REPO/scripts" && grep -nE '(^|[[:space:]("=])("?\$\{?AGY\}?"?|agy)[[:space:]]+(-p|--print|--prompt|--mode|-i)([[:space:]]|$)' \
        $(ls *.sh | grep -vE '^(test_|agy_launch_guard\.sh$)') 2>/dev/null \
        | grep -vE ':[0-9]+:[[:space:]]*#' | grep -v 'AGY_GUARD' || true)
if [ -z "$hits" ]; then ok "G12 static scan: no unguarded agy launch in shipped scripts"
else bad "G12 static scan: unguarded launch(es):"; printf '      %s\n' "$hits"; fi
# G13 control for G12 — the same pattern DOES see an unguarded line
printf 'out=$(agy -p "$1")\n' > "$D/probe.sh"
grep -qE '(^|[[:space:]("=])("?\$\{?AGY\}?"?|agy)[[:space:]]+(-p|--print|--prompt|--mode|-i)([[:space:]]|$)' "$D/probe.sh" \
  && ok "G13 static pattern sees a known unguarded line (control alive)" || bad "G13 static pattern blind to a known unguarded line"

# G7l exported agy function AND bare FH_AGY_BIN AND marker — still resolves to the PATH binary (no loop)
agy() { : > "$D/ran_func"; }; export -f agy
rm -f "$D/ran_host" "$D/ran_func"
FH_AGY_ISOLATION=container FH_CODEX_BIN="$D/codex_fake" FH_AGY_BIN=agy bash "$FLEET" "$D/t.py" --out "$D/f7l" < /dev/null > "$D/f7l.out" 2>&1 &
kpid=$!; k=0; while kill -0 "$kpid" 2>/dev/null && [ "$k" -lt 30 ]; do sleep 1; k=$((k+1)); done
unset -f agy
if kill -0 "$kpid" 2>/dev/null; then kill "$kpid" 2>/dev/null; bad "G7l exported function + bare name: still running after 30s (loop)"
elif [ -e "$D/ran_host" ] && [ ! -e "$D/ran_func" ]; then ok "G7l exported function + bare name: PATH agy started once, function ignored"
else bad "G7l exported function + bare name: host=$([ -e "$D/ran_host" ] && echo yes || echo no) func=$([ -e "$D/ran_func" ] && echo yes || echo no)"; fi
rm -f "$D/ran_host"
# G14b hermetic floor after G7k — the lanes after it (verifier, calibrate, static) did not reach it either
[ ! -e "$D/ran_host" ] && ok "G14b underlying-PATH agy not started after G7k" || bad "G14b underlying-PATH agy was started after G7k"
echo
echo "agy launch guard lanes: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
