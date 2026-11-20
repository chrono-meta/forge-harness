#!/usr/bin/env bash
# test_codex_launch_guard_lanes.sh — lanes for scripts/codex_launch_guard.sh and the FH callers that start
# codex (finding_fleet.sh codex rows · finding_verifier.sh --family codex · sidecar_calibrate.sh probe).
#
# WHAT IS CHECKED: codex is not started when the prompt (stdin), an argument or the working folder refers
# to a configured company-repo root; it is started — with the prompt intact and its own exit code passed
# back — when nothing does; and an unconfigured list is said out loud, never shown as clean. A FAKE codex
# records whether it started; no real codex runs. The roots used here are temp folders this lane makes.
# WHAT IS NOT CHECKED: a company path the prompt carries in another shape (relative path, file content
# pasted without its path, encoding) — the guard matches root paths as strings, nothing more.
#
# Also checked: a stdin that is open but never ends (an agent background shell's) is refused within the idle
# limit instead of hanging (C12–C12f).
#
# Usage: bash scripts/test_codex_launch_guard_lanes.sh      Exit: 0 all pass · 1 any fail
set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
GUARD="$REPO/scripts/codex_launch_guard.sh"
FLEET="$REPO/scripts/finding_fleet.sh"
VERIFIER="$REPO/scripts/finding_verifier.sh"
D="$(mktemp -d "${TMPDIR:-/tmp}/codexguard.XXXXXX")" || { echo "ENV-BLOCKED: mktemp failed — unmeasured, not a pass"; exit 1; }
trap 'rm -rf "$D"' EXIT
D="$(cd "$D" && pwd -P)"
unset FH_COMPANY_ROOTS FH_COMPANY_ROOTS_FILE
export FH_COMPANY_ROOTS_FILE="$D/no-such-roots-file"   # keep the operator's own list out of these lanes
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ✅ $1"; }
bad() { FAIL=$((FAIL+1)); echo "  ❌ $1"; }

cat > "$D/codex_fake" <<EOF
#!/usr/bin/env bash
cat > "$D/stdin_seen"
printf '%s\n' "\$@" > "$D/argv_seen"
: > "$D/ran"
echo '{"title":"fake","file":"t.py","line":1,"severity":"B","category":"x","detail":"d","defeater":"df","confidence":0.5}'
exit \${FAKE_CODEX_RC:-0}
EOF
chmod +x "$D/codex_fake"
mkdir -p "$D/company/repo-a/src" "$D/public"
ROOT="$D/company/repo-a"
run() { rm -f "$D/ran" "$D/stdin_seen"; out=$("$@" 2>"$D/err"); rc=$?; err=$(cat "$D/err"); }

echo "── guard alone"
run env -u FH_COMPANY_ROOTS bash "$GUARD" "$D/codex_fake" exec - <<< "review this public diff"
if [ "$rc" -eq 0 ] && [ -e "$D/ran" ] && printf '%s' "$err" | grep -q 'not checked'; then ok "C1 no list configured: codex runs, and the guard says «not checked» (not «clean»)"
else bad "C1 unconfigured: rc=$rc ran=$([ -e "$D/ran" ] && echo yes || echo no) err=${err:0:100}"; fi

export FH_COMPANY_ROOTS="$ROOT"
run bash "$GUARD" "$D/codex_fake" exec - <<< "please review $ROOT/src/app.py for bugs"
if [ "$rc" -eq 3 ] && [ ! -e "$D/ran" ] && printf '%s' "$err" | grep -q 'CODEX-REFUSED' && printf '%s' "$err" | grep -q 'prompt'; then ok "C2 company root in the prompt: refused rc=3, codex not started, says «prompt»"
else bad "C2 prompt: rc=$rc ran=$([ -e "$D/ran" ] && echo yes || echo no) err=${err:0:120}"; fi

printf 'diff --git a/x.sh b/x.sh\n+echo hi\n' > "$D/public.diff"
run env FAKE_CODEX_RC=5 bash "$GUARD" "$D/codex_fake" exec --sandbox read-only - < "$D/public.diff"
if [ "$rc" -eq 5 ] && [ -e "$D/ran" ] && cmp -s "$D/stdin_seen" "$D/public.diff" && [ "$(sed -n 2p "$D/argv_seen")" = "--sandbox" ]; then ok "C3 public diff: codex runs with the prompt byte-for-byte and its own rc (5) comes back"
else bad "C3 public: rc=$rc ran=$([ -e "$D/ran" ] && echo yes || echo no) same_stdin=$(cmp -s "$D/stdin_seen" "$D/public.diff" && echo yes || echo no)"; fi

run bash "$GUARD" "$D/codex_fake" exec -C "$ROOT" - <<< "hello"
[ "$rc" -eq 3 ] && [ ! -e "$D/ran" ] && printf '%s' "$err" | grep -q 'argument' && ok "C4 company root in an argument: refused" || bad "C4 argument: rc=$rc err=${err:0:100}"

run bash -c 'cd "$1" && bash "$2" "$3" exec - <<< "hello"' _ "$ROOT/src" "$GUARD" "$D/codex_fake"
[ "$rc" -eq 3 ] && [ ! -e "$D/ran" ] && printf '%s' "$err" | grep -q 'working folder' && ok "C5 working folder inside a company root: refused" || bad "C5 cwd: rc=$rc err=${err:0:100}"

echo "── stdin that never ends (an agent background shell's stdin: open, not a terminal)"
# Known pair: on the guard before 2026-11-20 C12 does not return until the writer goes away (a plain `cat`
# read stdin), and then codex starts — red on «returned within 10 s» and on «not started».
# The writer holds a FIFO open for 20 s; each lane kills it afterwards.
mkfifo "$D/fifo"
# The guard runs under a 15 s watchdog, so a guard that waits forever turns these lanes red instead of hanging them.
command -v perl >/dev/null 2>&1 || bad "C12* not measured: perl (the watchdog) is missing"
held() {   # held <writer command...> — guard reads a FIFO the writer keeps open; sets rc, err, secs
  bash -c 'exec "$@"' _ "$@" > "$D/fifo" & local wpid=$!
  local t0=$SECONDS
  run env FH_GUARD_STDIN_IDLE_S=2 perl -e 'alarm 15; exec @ARGV' bash "$GUARD" "$D/codex_fake" exec - < "$D/fifo"
  secs=$((SECONDS - t0)); kill "$wpid" 2>/dev/null; wait "$wpid" 2>/dev/null
}
held sleep 20
if [ "$rc" -eq 3 ] && [ ! -e "$D/ran" ] && [ "$secs" -le 10 ] && printf '%s' "$err" | grep -q 'CODEX-REFUSED' && printf '%s' "$err" | grep -q 'never ended'; then ok "C12 open stdin, nothing sent: refused rc=3 within ${secs} s, codex not started"
else bad "C12 open stdin: rc=$rc secs=$secs ran=$([ -e "$D/ran" ] && echo yes || echo no) err=${err:0:120}"; fi

held bash -c 'printf "review this public diff\n"; exec sleep 20'
if [ "$rc" -eq 3 ] && [ ! -e "$D/ran" ] && [ "$secs" -le 10 ]; then ok "C12b part of a prompt, then open and silent: refused, the partial prompt is not passed on"
else bad "C12b partial prompt: rc=$rc secs=$secs ran=$([ -e "$D/ran" ] && echo yes || echo no)"; fi

printf 'slow but ending\n' > "$D/slow.expect"
rm -f "$D/ran" "$D/stdin_seen"
out=$( { sleep 1; printf 'slow but ending\n'; } | FH_GUARD_STDIN_IDLE_S=3 bash "$GUARD" "$D/codex_fake" exec - 2>"$D/err"); rc=$?
if [ "$rc" -eq 0 ] && [ -e "$D/ran" ] && cmp -s "$D/stdin_seen" "$D/slow.expect"; then ok "C12c a slow writer that ends inside the idle limit: codex runs with the prompt intact (control alive)"
else bad "C12c slow writer: rc=$rc ran=$([ -e "$D/ran" ] && echo yes || echo no) err=$(head -c 120 "$D/err")"; fi

bad_lim=""
for v in soon 00 0 99999999999999999999 86401; do
  run env FH_GUARD_STDIN_IDLE_S="$v" bash "$GUARD" "$D/codex_fake" exec - <<< "hello"
  { [ "$rc" -eq 3 ] && [ ! -e "$D/ran" ] && printf '%s' "$err" | grep -q "FH_GUARD_STDIN_IDLE_S='$v' is not"; } || bad_lim="$bad_lim idle=$v:rc=$rc"
done
run env FH_GUARD_STDIN_MAX_S=0 bash "$GUARD" "$D/codex_fake" exec - <<< "hello"
{ [ "$rc" -eq 3 ] && [ ! -e "$D/ran" ] && printf '%s' "$err" | grep -q "FH_GUARD_STDIN_MAX_S='0' is not"; } || bad_lim="$bad_lim max=0:rc=$rc"
[ -z "$bad_lim" ] && ok "C12d a malformed, zero or out-of-range limit is a refusal by name, not a default (soon · 00 · 0 · 20 digits · 86401 · max 0)" || bad "C12d limits:$bad_lim"

# C12f a writer that keeps sending a little and never ends: the idle limit never fires, the total one does.
FH_GUARD_STDIN_MAX_S=3 held bash -c 'while :; do printf x; sleep 0.5; done'
if [ "$rc" -eq 3 ] && [ ! -e "$D/ran" ] && [ "$secs" -le 10 ] && printf '%s' "$err" | grep -q 'had not ended after 3 s'; then ok "C12f a trickling writer that never ends: refused on the total limit within ${secs} s"
else bad "C12f trickle: rc=$rc secs=$secs ran=$([ -e "$D/ran" ] && echo yes || echo no) err=${err:0:120}"; fi


# C6 the same root written another way: /private stripped (macOS /tmp = /private/tmp) and ~ for $HOME
case "$ROOT" in
  /private/*) alt="${ROOT#/private}"
    run bash "$GUARD" "$D/codex_fake" exec - <<< "look at $alt/src"
    [ "$rc" -eq 3 ] && [ ! -e "$D/ran" ] && ok "C6a root written without /private: refused" || bad "C6a /private form: rc=$rc" ;;
  *) echo "  ➖ C6a /private form not applicable (temp root is not under /private)" ;;
esac
HROOT="$HOME/.fh-codex-guard-lane-$$"
run env FH_COMPANY_ROOTS="$HROOT" bash "$GUARD" "$D/codex_fake" exec - <<< "see ~/.fh-codex-guard-lane-$$/x"
[ "$rc" -eq 3 ] && [ ! -e "$D/ran" ] && ok "C6b root under HOME written with ~: refused" || bad "C6b ~ form: rc=$rc"

# C7 the list can come from a file (one path per line, # comments) instead of the environment
printf '# lane roots\n\n%s\n' "$ROOT" > "$D/roots"
run env -u FH_COMPANY_ROOTS FH_COMPANY_ROOTS_FILE="$D/roots" bash "$GUARD" "$D/codex_fake" exec - <<< "check $ROOT/src"
[ "$rc" -eq 3 ] && [ ! -e "$D/ran" ] && ok "C7 roots from a file: refused" || bad "C7 roots file: rc=$rc err=${err:0:100}"
# C7b a near-miss path (root name as a prefix of another folder) is NOT a match
run bash "$GUARD" "$D/codex_fake" exec - <<< "check $D/company/repo-ab/src"
[ "$rc" -eq 0 ] && [ -e "$D/ran" ] && ok "C7b ${ROOT##*/}b is not ${ROOT##*/}: runs (no prefix over-block)" || bad "C7b near-miss: rc=$rc"

# C7c a list file that exists but cannot be read is a refusal, not «unconfigured»
mkdir -p "$D/unreadable_roots"   # a directory where a file is expected: open() fails with an error other than not-found
run env -u FH_COMPANY_ROOTS FH_COMPANY_ROOTS_FILE="$D/unreadable_roots" bash "$GUARD" "$D/codex_fake" exec - <<< "hello"
[ "$rc" -eq 3 ] && [ ! -e "$D/ran" ] && printf '%s' "$err" | grep -q 'cannot be read' && ok "C7c unreadable roots file: refused (not «not checked»)" || bad "C7c unreadable list: rc=$rc err=${err:0:100}"

echo "── callers"
printf 'def f():\n    return "%s/src"\n' "$ROOT" > "$D/t_company.py"
printf 'def f():\n    return 1\n' > "$D/t_public.py"
printf 'codex|logic|CODEX_BIN exec -\n' > "$D/codex.tbl"
rm -f "$D/ran"
FH_CODEX_BIN="$D/codex_fake" bash "$FLEET" "$D/t_company.py" --out "$D/f1" --fleet "$D/codex.tbl" < /dev/null > "$D/f1.out" 2>&1
if [ ! -e "$D/ran" ] && grep -qs 'CODEX-REFUSED' "$D/f1/err_codex_logic.txt"; then ok "C8 fleet codex row on a file that names a company root: refused"
else bad "C8 fleet company: started=$([ -e "$D/ran" ] && echo yes || echo no)"; fi
rm -f "$D/ran"
FH_CODEX_BIN="$D/codex_fake" bash "$FLEET" "$D/t_public.py" --out "$D/f2" --fleet "$D/codex.tbl" < /dev/null > "$D/f2.out" 2>&1
[ -e "$D/ran" ] && ok "C8b fleet codex row on a public file: runs (control alive)" || bad "C8b fleet public: not started"
printf 'codex|logic|codex exec -\n' > "$D/byname.tbl"
mkdir -p "$D/bin"; cp "$D/codex_fake" "$D/bin/codex"
rm -f "$D/ran"
PATH="$D/bin:$PATH" FH_CODEX_BIN="$D/codex_fake" bash "$FLEET" "$D/t_company.py" --out "$D/f3" --fleet "$D/byname.tbl" < /dev/null > "$D/f3.out" 2>&1
[ ! -e "$D/ran" ] && ok "C8c fleet row calling codex by name on a company file: refused" || bad "C8c by name: started"
# C8d round 2: round-1 findings from a public file, round 2 aimed at a company file — still refused
FH_CODEX_BIN="$D/codex_fake" bash "$FLEET" "$D/t_public.py" --out "$D/f4r1" --fleet "$D/codex.tbl" --r1-only < /dev/null > /dev/null 2>&1
rm -f "$D/ran"
FH_CODEX_BIN="$D/codex_fake" bash "$FLEET" "$D/t_company.py" --out "$D/f4r2" --reuse-r1 "$D/f4r1" --round2 < /dev/null > "$D/f4r2.out" 2>&1
if [ ! -e "$D/ran" ] && grep -qs 'CODEX-REFUSED' "$D/f4r2/err2_codex_logic.txt"; then ok "C8d fleet round 2 on a company file: refused"
else bad "C8d round 2: started=$([ -e "$D/ran" ] && echo yes || echo no) r2err=$(head -c 80 "$D/f4r2/err2_codex_logic.txt" 2>/dev/null)"; fi
# C8e a guard refusal seen through sidecar_wait is HARNESS-ERROR (nothing was reviewed), not COMPLETE
SW="$REPO/scripts/sidecar_wait.sh"
rm -f "$D/ran"
printf 'review %s/src\n' "$ROOT" | SIDECAR_POLL=1 bash "$SW" "$D/sw.out" 20 -- bash "$GUARD" "$D/codex_fake" exec - > "$D/sw.txt" 2>&1; swrc=$?
grep -q 'SIDECAR_VERDICT=HARNESS-ERROR.*reason=guard-refused' "$D/sw.txt" && [ "$swrc" -eq 3 ] && [ ! -e "$D/ran" ] \
  && ok "C8e guard refusal through sidecar_wait: HARNESS-ERROR reason=guard-refused (rc 3)" || bad "C8e sidecar_wait: rc=$swrc verdict=$(grep -m1 SIDECAR_VERDICT "$D/sw.txt")"
printf '%s\n' '{"id":"x1","title":"t","file":"t.py","line":1,"severity":"B","category":"x","detail":"d","defeater":"df","confidence":0.5}' > "$D/claims.jsonl"
rm -f "$D/ran"
FH_CODEX_BIN="$D/codex_fake" bash "$VERIFIER" --family codex --target "$D/t_company.py" < "$D/claims.jsonl" > "$D/v1.out" 2> "$D/v1.err"; vrc=$?
[ ! -e "$D/ran" ] && [ "$vrc" -ne 0 ] && ok "C9 verifier --family codex on a company file: not started (rc=$vrc)" || bad "C9 verifier company: rc=$vrc started=$([ -e "$D/ran" ] && echo yes || echo no)"
rm -f "$D/ran"
FH_CODEX_BIN="$D/codex_fake" bash "$VERIFIER" --family codex --target "$D/t_public.py" < "$D/claims.jsonl" > /dev/null 2>&1
[ -e "$D/ran" ] && ok "C9b verifier on a public file: runs (control alive)" || bad "C9b verifier public: not started"

echo "── static"
# C10 shipped scripts start codex only through the guard. Comment lines are skipped; lanes and the guard
#     itself are excluded. Residual: a launch assembled from pieces is not seen by a line scan.
hits=$(cd "$REPO/scripts" && grep -nE '(^|[[:space:](="])("?\$\{?CODEX\}?"?|codex)[[:space:]]+exec([[:space:]]|$)' \
        $(ls *.sh | grep -vE '^(test_|codex_launch_guard\.sh$|docker_phase1_verify\.sh$|fh-goal\.sh$|fh-gate\.sh$|fh-run\.sh$)') 2>/dev/null | grep -vE ':[0-9]+:[[:space:]]*#' | grep -v 'CODEX_GUARD' || true)
# Excluded by name, on purpose:
#  · docker_phase1_verify.sh — runs codex INSIDE a container with a fixed «reply OK» prompt; no file of
#    this machine can reach that call.
#  · fh-goal.sh · fh-gate.sh · fh-run.sh — runtime adapters: codex there is the user's chosen agent doing
#    the user's own work, not a verifier arm handed someone else's material. Guarding them would block a
#    consumer whose organisation allows codex. This guard covers verifier arms only.
[ -z "$hits" ] && ok "C10 no shipped script starts codex around the guard" || { bad "C10 unguarded codex launch(es):"; printf '      %s\n' "$hits"; }
printf 'out=$(codex exec -)\n' > "$D/probe.sh"
grep -qE '(^|[[:space:](="])("?\$\{?CODEX\}?"?|codex)[[:space:]]+exec([[:space:]]|$)' "$D/probe.sh" && ok "C11 static pattern sees a known unguarded line (control alive)" || bad "C11 static pattern blind"

echo
echo "codex launch guard lanes: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
