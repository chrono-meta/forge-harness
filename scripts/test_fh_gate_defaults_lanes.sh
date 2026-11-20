#!/usr/bin/env bash
# test_fh_gate_defaults_lanes.sh — what fh-gate does when the caller opts into nothing (3.45.0).
#
# WHY. #1147 made /code-review the default review on the claude backend, added an «elephant» pass at level full and
# an execution layer (E1 runs the repository's own lanes) — all on by default. Whether a headless `/code-review` (or
# the absorbed FH pass) returns the structured object the gate needs was never measured, and the GitHub Action always
# passed FH_TIMEOUT=120. Published as is, a consumer who changed nothing could get exit 10 on every run, and E1 would
# start executing their repository's code. So until those paths are measured, the default is the 3.44.0 review:
#   D1  claude backend, nothing set, level full → fh-legacy · no elephant call · E0/E1 «NOT RUN (off by default …)»
#   D2  codex backend, nothing set → fh-legacy (not the absorbed pass, not labelled fallback)
#   D3  FH_REVIEWER=code-review (opt-in) → the /code-review call is made
#   D4  FH_REVIEWER=fh (opt-in) → the absorbed pass is made
#   D5  FH_GATE_ELEPHANT=auto at level full (opt-in) → the elephant pass is made
#   D6  FH_GATE_EXEC=on (opt-in) → E1 is not «NOT RUN (off by default …)»
#   D8  cross with nothing set → the legs say the execution layer is off by default (cross-family R1)
#   D9  --help names fh-legacy as the default reviewer
#   D7  action.yml does not put FH_TIMEOUT in the step env; it exports it only when the `timeout` input (default '') is non-empty
#       (known pair: the shipped file passes; a planted «FH_TIMEOUT: ${{ inputs.timeout }}» env line is caught)
# Token-free: claude and codex are stubs that answer by request kind and log what they were asked.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/fixture_guard_lib.sh"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE="$HERE/fh-gate.sh"; ACTION="$HERE/../action.yml"
TMPROOT=$(mktemp -d "${TMPDIR:-/tmp}/fh_gate_defaults_XXXXXX")
trap 'rm -rf "$TMPROOT"' EXIT
export FH_RECORD_BASE="$TMPROOT/records"; mkdir -p "$FH_RECORD_BASE"
unset FH_REVIEWER FH_GATE_ELEPHANT FH_GATE_EXEC FH_TIMEOUT FH_GATE_LEVEL
pass=0; fail=0
ok()  { printf 'PASS  %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf 'FAIL  %s — %s\n' "$1" "$2"; fail=$((fail + 1)); }
g() { git -c user.name=t -c user.email=t@t -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@"; }

FAKEBIN="$TMPROOT/bin"; mkdir -p "$FAKEBIN"
cat > "$FAKEBIN/claude" <<'FAKE'
#!/usr/bin/env bash
in=$(cat); args=" $* "; kind=legacy
case "$args" in *"/code-review "*) kind=cr ;; esac
case "$in" in *"FH ELEPHANT PASS"*) kind=ele ;; *"FH REVIEW PASS"*) kind=abs ;; esac
: > "${LOGDIR:-/tmp}/claude_${kind}.called"
empty='{"status":"SUCCESS","findings":[]}'
case "$kind" in legacy) p="$FAKE_PAYLOAD" ;; *) p="$empty" ;; esac
printf '{"is_error":false,"subtype":"success","structured_output":%s}\n' "$p"
FAKE
cat > "$FAKEBIN/codex" <<'FAKE'
#!/usr/bin/env bash
out=""; while [ $# -gt 0 ]; do case "$1" in -o) out="$2"; shift 2 ;; *) shift ;; esac; done
in=$(cat); kind=legacy
case "$in" in *"FH ELEPHANT PASS"*) kind=ele ;; *"FH REVIEW PASS"*) kind=abs ;; esac
: > "${LOGDIR:-/tmp}/codex_${kind}.called"
empty='{"status":"SUCCESS","findings":[]}'
case "$kind" in legacy) p="$FAKE_PAYLOAD" ;; *) p="$empty" ;; esac
[ -n "$out" ] && printf '%s' "$p" > "$out"
exit 0
FAKE
chmod +x "$FAKEBIN/claude" "$FAKEBIN/codex"
export PATH="$FAKEBIN:$PATH"
export FAKE_PAYLOAD='{"status":"SUCCESS","verdict":"PASS","findings_count":0,"findings_a":0,"findings_b":0,"findings":[]}'

REPO="$TMPROOT/repo"; mkdir -p "$REPO/scripts"
g -C "$REPO" init -q -b main
printf '#!/usr/bin/env bash\necho ok\n' > "$REPO/scripts/foo.sh"; g -C "$REPO" add -A; g -C "$REPO" commit -qm "add foo"
g -C "$REPO" checkout -qb feat
printf '#!/usr/bin/env bash\necho ok two\n' > "$REPO/scripts/foo.sh"; g -C "$REPO" commit -qam "change foo"

gate() {   # gate <name> [env...]
  local name="$1"; shift
  mkdir -p "$TMPROOT/$name"
  ( cd "$REPO" && env LOGDIR="$TMPROOT/$name" "$@" bash "$GATE" ) > "$TMPROOT/$name.out" 2> "$TMPROOT/$name.err" < /dev/null
  RC=$?
}
has()    { grep -qF -- "$2" "$TMPROOT/$1.out"; }
called() { [ -e "$TMPROOT/$1/$2.called" ]; }

gate d1 FH_GATE_LEVEL=full
if [ "$RC" -eq 0 ] && has d1 'FH_GATE_REVIEWER: fh-legacy' && called d1 claude_legacy && ! called d1 claude_cr \
   && ! called d1 claude_abs && ! called d1 claude_ele && has d1 'FH_GATE_E1: not-run — NOT RUN (off by default' \
   && has d1 'FH_GATE_ELEPHANT: not-run — NOT RUN (off by default'; then
  ok "D1 claude, nothing set, level full → fh-legacy · no /code-review · no elephant · E1 off by default"
else bad "D1 claude defaults" "rc=$RC $(grep -E 'REVIEWER|ELEPHANT|E1' "$TMPROOT/d1.out" | tr '\n' '|') calls=$(ls "$TMPROOT/d1" | tr '\n' ' ')"; fi

gate d2 FH_BACKEND=codex
if [ "$RC" -eq 0 ] && has d2 'FH_GATE_REVIEWER: fh-legacy' && ! has d2 'fallback' && called d2 codex_legacy && ! called d2 codex_abs; then
  ok "D2 codex, nothing set → fh-legacy, not the absorbed pass, not labelled fallback"
else bad "D2 codex default" "rc=$RC $(grep REVIEWER "$TMPROOT/d2.out") calls=$(ls "$TMPROOT/d2" | tr '\n' ' ')"; fi

gate d3 FH_REVIEWER=code-review
if [ "$RC" -eq 0 ] && called d3 claude_cr && has d3 'FH_GATE_REVIEWER: /code-review'; then ok "D3 FH_REVIEWER=code-review (opt-in) → the /code-review call is made"
else bad "D3 code-review opt-in" "rc=$RC $(grep REVIEWER "$TMPROOT/d3.out") calls=$(ls "$TMPROOT/d3" | tr '\n' ' ')"; fi

gate d4 FH_REVIEWER=fh
if [ "$RC" -eq 0 ] && called d4 claude_abs && has d4 'FH_GATE_REVIEWER: fh — goldfish pass'; then ok "D4 FH_REVIEWER=fh (opt-in) → the absorbed pass is made"
else bad "D4 fh opt-in" "rc=$RC $(grep REVIEWER "$TMPROOT/d4.out") calls=$(ls "$TMPROOT/d4" | tr '\n' ' ')"; fi

gate d5 FH_GATE_LEVEL=full FH_GATE_ELEPHANT=auto
if [ "$RC" -eq 0 ] && called d5 claude_ele && has d5 'FH_GATE_ELEPHANT: ran'; then ok "D5 FH_GATE_ELEPHANT=auto at full (opt-in) → the elephant pass is made"
else bad "D5 elephant opt-in" "rc=$RC $(grep ELEPHANT "$TMPROOT/d5.out") calls=$(ls "$TMPROOT/d5" | tr '\n' ' ')"; fi

gate d6 FH_GATE_EXEC=on
grep '^FH_GATE_E1: ' "$TMPROOT/d6.out" > "$TMPROOT/d6.e1" 2>/dev/null
# the layer ran: E0 says «ran» (the fixture has no target lane, so E1 legitimately says «no target lane found»)
if [ "$RC" -eq 0 ] && has d6 'FH_GATE_E0: ran' && [ -s "$TMPROOT/d6.e1" ] && ! grep -qF 'off by default' "$TMPROOT/d6.e1" && ! grep -qF 'FH_GATE_EXEC=off' "$TMPROOT/d6.e1"; then ok "D6 FH_GATE_EXEC=on (opt-in) → E1 is not «off by default»"
else bad "D6 exec opt-in" "rc=$RC $(grep -E '^FH_GATE_E[01]' "$TMPROOT/d6.out" | tr '\n' '|')"; fi

# D8 — cross with nothing set: the legs report the execution layer «off by default», not «FH_GATE_EXEC=off»
gate d8 FH_BACKEND=cross FH_GATE_CROSS_ALLOW_SINGLE=1
if grep -qF '# FH_GATE_E1: not-run — NOT RUN (off by default' "$TMPROOT/d8.out" && ! grep -qF 'NOT RUN (FH_GATE_EXEC=off)' "$TMPROOT/d8.out"; then
  ok "D8 cross, nothing set → the legs say the execution layer is off by default"
else bad "D8 cross defaults" "rc=$RC $(grep -E 'E1' "$TMPROOT/d8.out" | tr '\n' '|')"; fi

# D9 — --help states the default reviewer the code applies (Area B 3.45.0: --help still said /code-review)
bash "$GATE" --help > "$TMPROOT/help.out" 2>&1
if grep -qF 'FH_REVIEWER=fh-legacy|code-review|fh review stage (default: fh-legacy' "$TMPROOT/help.out" && ! grep -qF 'default on claude: built-in /code-review' "$TMPROOT/help.out"; then
  ok "D9 --help names fh-legacy as the default reviewer"
else bad "D9 --help default reviewer" "$(grep -m2 -F 'FH_REVIEWER' "$TMPROOT/help.out" | tr '\n' '|')"; fi

# D7 — action.yml's step env must not carry FH_TIMEOUT; the run block exports it only from a non-empty input.
envblock() { awk '/^ *env: *$/{e=1; next} e && /^ *run: *\|/{exit} e{print}' "$1"; }
if [ -r "$ACTION" ]; then
  envblock "$ACTION" > "$TMPROOT/env_shipped"
  sed 's/^\( *\)FH_CALLER: github-action$/\1FH_CALLER: github-action\n\1FH_TIMEOUT: ${{ inputs.timeout }}/' "$ACTION" > "$TMPROOT/action_planted.yml"
  envblock "$TMPROOT/action_planted.yml" > "$TMPROOT/env_planted"
  n_ship=$(grep -cE '^ *FH_TIMEOUT:' "$TMPROOT/env_shipped"); n_plant=$(grep -cE '^ *FH_TIMEOUT:' "$TMPROOT/env_planted")
  if [ -s "$TMPROOT/env_shipped" ] && [ "$n_ship" = 0 ] && [ "$n_plant" = 1 ] \
     && grep -qF 'if [ -n "${FH_ACTION_TIMEOUT:-}" ]; then export FH_TIMEOUT="$FH_ACTION_TIMEOUT"; fi' "$ACTION" \
     && grep -qE "^ *default: ''" <<<"$(awk '/^  timeout:/{f=1} f&&/default:/{print; exit}' "$ACTION")"; then
    ok "D7 action.yml: FH_TIMEOUT only from a non-empty timeout input (a planted env line is caught)"
  else bad "D7 action timeout pass-through" "env lines with FH_TIMEOUT: shipped=$n_ship planted=$n_plant"; fi
else bad "D7 action timeout pass-through" "action.yml not readable at $ACTION (not measured)"; fi

echo "fh-gate defaults lanes: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
