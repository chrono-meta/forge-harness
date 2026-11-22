#!/usr/bin/env bash
# test_action_yml_lanes.sh — behavioural lanes for action.yml's exit-code mapping.
#
# WHY: `action.yml` is the only place where the gate's SEVEN typed exit codes get turned into a
# GitHub step outcome. That translation is exactly where a typed verdict silently becomes a
# boolean — the failure this repo names in `[[feedback_not_found_is_not_zero_family]]`. Two
# properties carry the weight and neither is visible by reading the YAML:
#   A. an UNKNOWN exit code (a future gate version adding one) must land on HARNESS_ERROR-class
#      handling, never on PASS. A `case` whose `*)` arm is missing would default to... nothing,
#      and `verdict` would be unset — which under `set -u` is a crash, but under a careless edit
#      could become an empty string that matches no fail-on entry and exits 0. That is the leak.
#   B. `reviewed` must be false for every code where no review ran (10 · 11 · 12 · unknown).
#      «did not run» reported as «passed» is the same defect class as a skipped check scored green.
#
# HOW: the mapping is extracted from action.yml and executed as shell — the lanes run the REAL
# case block, not a copy. A copy would drift and every lane would stay green while the shipped
# file rotted (that is `[[feedback_built_but_not_wired]]` wearing a test's clothes).
#
# USAGE: bash scripts/test_action_yml_lanes.sh   → exit 0 all pass · 1 any fail · 10 harness error
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
A="$ROOT/action.yml"
[ -f "$A" ] || { echo "❌ HARNESS: action.yml absent at $A"; exit 10; }
PASS=0; FAIL=0
ok(){ PASS=$((PASS+1)); printf '  ✅ %s\n' "$1"; }
no(){ FAIL=$((FAIL+1)); printf '  ❌ %s\n' "$1"; }
chk(){ if [ "$1" = "0" ]; then ok "$2"; else no "$2"; fi; }

# ── extract the real case block from the shipped file ────────────────────────────────────────
MAP="$(awk '/^ *case "\$rc" in/{f=1} f{print} /^ *esac/{if(f){exit}}' "$A" | sed 's/^ *//')"

# ── D. input defaults must be values the CLI accepts (2026-09-06) ────────────────────────────
# WHY THIS EXISTS. The lanes above test the exit-code MAPPING and nothing else — the header says
# so. Nobody was checking the other direction: that the values this action sends the CLI are
# values the CLI takes. v3.1.0 shipped `level` defaulting to 'standard', which `fh-gate.sh` has
# never accepted; it rejects with ARG_ERROR (11), and ARG_ERROR is in fail-on's own default set.
# So `uses: chrono-meta/forge-harness@v3.1.0` with no `level:` failed the step, and the error
# named an argument the user never set. Found by running the PUBLISHED tarball as a consumer
# would, not by reading either file — which is why the standpoint arm is not optional.
#
# Both sides are extracted from the REAL files. A hard-coded expected value here would drift the
# same way the default did, and this lane would stay green while the shipped file rotted.
_ACTION_LEVEL_DEFAULT="$(awk '
  /^  level:/            {inlvl=1; next}
  inlvl && /^  [a-z-]+:/ {inlvl=0}
  inlvl && /^ *default:/ {gsub(/^ *default: *|""|\x27/,""); print; exit}
' "$A")"
_GATE_SH="$ROOT/scripts/fh-gate.sh"
if [ ! -f "$_GATE_SH" ]; then
  no "D0 HARNESS — scripts/fh-gate.sh absent; cannot learn which levels the CLI accepts"
else
  # the validation line is the single source of truth for the accepted set
  _ACCEPTED="$(grep -oE '"\$GATE_LEVEL" != "[a-z]+"' "$_GATE_SH" | grep -oE '"[a-z]+"$' | tr -d '"' | sort -u | tr '\n' ' ')"
  [ -n "$_ACCEPTED" ] && ok "D0 extracted the CLI's accepted level set from fh-gate.sh: [$_ACCEPTED]" \
                      || no "D0 could not extract an accepted-level set from fh-gate.sh (instrument dead — the check below would pass vacuously)"
  case " $_ACCEPTED " in
    *" $_ACTION_LEVEL_DEFAULT "*) ok "D1 action.yml level default ('$_ACTION_LEVEL_DEFAULT') is a value the CLI accepts" ;;
    *) no "D1 action.yml level default ('$_ACTION_LEVEL_DEFAULT') is NOT in the CLI's accepted set [$_ACCEPTED] — every step that does not override level: will exit ARG_ERROR" ;;
  esac
  # control: the check must reject a value the CLI does not take. If this passes, D1 proves nothing.
  case " $_ACCEPTED " in
    *" standard "*) no "D2 control dead — 'standard' appears accepted, so D1 cannot discriminate" ;;
    *) ok "D2 control — the same test rejects 'standard' (the value v3.1.0 shipped), so D1 discriminates" ;;
  esac

  # D3/D4 — the SAME check for `backend`, because closing the instance and leaving the class open
  # is how this defect comes back wearing a different input's name. `backend` is the other
  # enum-shaped input the action forwards; `model` (free-form, empty = backend default) and
  # `timeout` (numeric, matches the gate's own 120) have no closed set to drift against, so they
  # are deliberately not lanes — an assertion with nothing to assert is decoration.
  _ACTION_BACKEND_DEFAULT="$(awk '
    /^  backend:/           {inb=1; next}
    inb && /^  [a-z-]+:/    {inb=0}
    inb && /^ *default:/    {gsub(/^ *default: *|""|\x27/,""); print; exit}
  ' "$A")"
  _ACCEPTED_BE="$(grep -oE "must be '[a-z]+', '[a-z]+', '[a-z]+', or '[a-z]+'" "$_GATE_SH" \
                   | grep -oE "'[a-z]+'" | tr -d "'" | sort -u | tr '\n' ' ')"
  if [ -z "$_ACCEPTED_BE" ]; then
    no "D3 could not extract the accepted backend set from fh-gate.sh (instrument dead — D4 would pass vacuously)"
  else
    ok "D3 extracted the CLI's accepted backend set: [$_ACCEPTED_BE]"
    case " $_ACCEPTED_BE " in
      *" $_ACTION_BACKEND_DEFAULT "*) ok "D4 action.yml backend default ('$_ACTION_BACKEND_DEFAULT') is a value the CLI accepts" ;;
      *) no "D4 action.yml backend default ('$_ACTION_BACKEND_DEFAULT') is NOT in [$_ACCEPTED_BE]" ;;
    esac
    case " $_ACCEPTED_BE " in
      *" anthropic "*) no "D5 control dead — a non-existent backend appears accepted" ;;
      *) ok "D5 control — the same test rejects 'anthropic' (a plausible-but-wrong value), so D4 discriminates" ;;
    esac
  fi
fi

# D6 — the Marketplace listing form caps `description` at under 125 characters and REFUSES to
# publish above it. Measured 2026-09-07 on the v3.1.1 release form: "Description must be less than
# 125 characters" at 155 chars. Nothing here checked it, so the limit surfaced only at the publish
# step — after the tag and the release already existed, which is the expensive place to learn it.
# The cap is GitHub's, not ours, so it is a constant here by necessity; that is named, not hidden.
_DESC="$(python3 - "$A" <<'PY' 2>/dev/null
import sys, yaml, io
print(yaml.safe_load(io.open(sys.argv[1], encoding="utf-8")).get("description", ""))
PY
)"
_DESC_LEN=${#_DESC}
if [ "$_DESC_LEN" -eq 0 ]; then
  no "D6 could not read action.yml description (instrument dead — the length check below is vacuous)"
else
  [ "$_DESC_LEN" -lt 125 ] \
    && ok "D6 description is $_DESC_LEN chars (< 125, the Marketplace listing cap)" \
    || no "D6 description is $_DESC_LEN chars — the Marketplace form refuses to publish at 125 or more"
fi



[ -n "$MAP" ] || { echo "❌ HARNESS: could not extract the case block from action.yml"; exit 10; }
printf '%s' "$MAP" | grep -q 'esac' || { echo "❌ HARNESS: extracted block has no esac (truncated)"; exit 10; }

verdict_for(){ # $1 = rc → prints "verdict reviewed"
  rc="$1"; verdict=""; reviewed=""
  eval "$MAP"
  printf '%s %s' "${verdict:-<UNSET>}" "${reviewed:-<UNSET>}"
}

echo "── L1 documented exit codes map to their documented verdict ──"
while read -r rc want_v want_r; do
  got="$(verdict_for "$rc")"
  [ "$got" = "$want_v $want_r" ]; chk $? "rc=$rc → $want_v (reviewed=$want_r) [got: $got]"
done <<'CASES'
0 PASS true
1 PENDING true
2 BLOCKED true
3 ESCALATE true
10 HARNESS_ERROR false
11 ARG_ERROR false
12 DRY_RUN false
CASES

echo "── L2 KNOWN-NEGATIVE: an undocumented exit code is never PASS and never reviewed=true ──"
for rc in 4 5 9 13 42 127 255; do
  got="$(verdict_for "$rc")"; v="${got%% *}"; r="${got##* }"
  { [ "$v" != "PASS" ] && [ "$v" != "PENDING" ] && [ "$v" != "<UNSET>" ] && [ "$r" = "false" ]; }
  chk $? "rc=$rc → $v (reviewed=$r) — not a pass, not unset"
done

echo "── L3 the mapping is TOTAL: no rc leaves verdict unset (the silent-green hole) ──"
_unset=0
for rc in $(seq 0 20) 42 100 127 255; do
  got="$(verdict_for "$rc")"; case "$got" in "<UNSET>"*) _unset=$((_unset+1)) ;; esac
done
[ "$_unset" -eq 0 ]; chk $? "0 of 28 sampled codes leave verdict unset (found $_unset)"

echo "── L4 CONTROL: a mutated mapping without the catch-all IS caught (the lane can fail) ──"
_MUT="$(printf '%s' "$MAP" | grep -v '^\*)')"
verdict_mut(){ rc="$1"; verdict=""; reviewed=""; eval "$_MUT"; printf '%s' "${verdict:-<UNSET>}"; }
[ "$(verdict_mut 42)" = "<UNSET>" ]; chk $? "catch-all removed → rc=42 leaves verdict unset (control is alive)"
[ "$(verdict_mut 0)" = "PASS" ]; chk $? "…and the mutant still maps documented codes (mutation is surgical)"

echo "── L5 action.yml's documented codes match scripts/fh-gate.sh's exit contract ──"
G="$ROOT/scripts/fh-gate.sh"
if [ -f "$G" ]; then
  _gate_codes="$(grep -oE '^#   [0-9]+ +—' "$G" | grep -oE '[0-9]+' | sort -un | tr '\n' ' ')"
  _act_codes="$(printf '%s' "$MAP" | grep -oE '^[0-9]+\)' | grep -oE '[0-9]+' | sort -un | tr '\n' ' ')"
  [ -n "$_gate_codes" ]; chk $? "CONTROL: the gate's exit contract was actually parsed (got: $_gate_codes)"
  [ "$_gate_codes" = "$_act_codes" ]; chk $? "every documented gate code has an action arm [gate: $_gate_codes | action: $_act_codes]"
else
  echo "  ⬜ L5 SKIPPED (not PASS) — scripts/fh-gate.sh absent, contract un-cross-checked"
fi

echo "── L6 fail-on default is fail-closed: every non-reviewed verdict is in it ──"
_failon="$(grep -A3 "^  fail-on:" "$A" | grep "default:" | sed "s/.*default: *'//; s/'.*//")"
[ -n "$_failon" ]; chk $? "CONTROL: fail-on default parsed (got: $_failon)"
for v in BLOCKED ESCALATE HARNESS_ERROR ARG_ERROR DRY_RUN UNKNOWN; do
  case ",$_failon," in *",$v,"*) ok "fail-on default contains $v" ;; *) no "fail-on default is MISSING $v — that verdict would exit 0" ;; esac
done
for v in PASS PENDING; do
  case ",$_failon," in *",$v,"*) no "fail-on default contains $v (over-blocks a reviewed pass)" ;; *) ok "fail-on default correctly omits $v" ;; esac
done

echo "── L7 inputs reach the run script as env data, not as substituted shell text (2026-11-22) ──"
# WHY. GitHub substitutes `${{ inputs.X }}` into the run: script as TEXT before bash sees it, so a
# caller-controlled value (a file list built from a PR, say) containing `"; cmd; "` runs `cmd` in the
# workflow (GitHub's own hardening guide: pass untrusted values through `env:`). Found in the 3.45.0
# security review (LOW — the caller writes these inputs, but `files` is often derived from PR data).
# HOW. L7b imitates that substitution: every `${{ inputs.X }}` in the run block is replaced by the
# value as text, every env: entry is exported as data, `npx` is a stub, and one input carries a
# payload that touches a file. The file must not appear. L7c is the control: the same run with one
# env reference turned back into an inline expression must create it.
_RUNBLK="$(awk '/^      run: \|/{f=1; next} f && /^    - /{exit} f{print}' "$A" | sed 's/^        //')"
_ENVBLK="$(awk '/^      env:/{f=1; next} f && /^      [a-z-]+:/{exit} f{print}' "$A" | sed 's/^ *//')"
[ -n "$_RUNBLK" ] && [ -n "$_ENVBLK" ]; chk $? "L7-0 CONTROL: run and env blocks extracted (run $(printf '%s\n' "$_RUNBLK" | wc -l | tr -d ' ') lines)"
# Any expression form counts — `inputs.x`, `inputs['x']`, `github.event…`, `steps…`: each is pasted as text.
_inline="$(printf '%s\n' "$_RUNBLK" | grep -c '\${{' || true)"
[ "$_inline" -eq 0 ]; chk $? "L7a no \${{ … }} expression of any form inside the run script (found $_inline)"
_L7T="$(mktemp -d "${TMPDIR:-/tmp}/action_yml_l7_XXXXXX")"
mkdir -p "$_L7T/bin"; printf '#!/bin/sh\nexit 0\n' > "$_L7T/bin/npx"; chmod +x "$_L7T/bin/npx"
# simulate <run script file> — GitHub-style text substitution of inputs, env as data, stub npx
_l7_sim(){
  python3 - "$1" "$_L7T" <<'PY'
import re, sys, os, subprocess
run = open(sys.argv[1], encoding="utf-8").read(); tmp = sys.argv[2]
pwn = os.path.join(tmp, "PWNED")
vals = {"files": 'a.sh"; touch "' + pwn + '"; echo "', "level": "light", "version": "latest",
        "dry-run": "false", "fail-on": "BLOCKED", "backend": "claude", "model": "", "timeout": ""}
sub = lambda m: vals.get(m.group(1), "")
env = dict(os.environ, PATH=os.path.join(tmp, "bin") + ":" + os.environ["PATH"],
           GITHUB_OUTPUT=os.path.join(tmp, "out"), GITHUB_STEP_SUMMARY=os.path.join(tmp, "sum"))
for line in open(os.path.join(tmp, "envblk"), encoding="utf-8"):
    m = re.match(r"([A-Z_]+):\s*(.*)$", line.strip())
    if m: env[m.group(1)] = re.sub(r"\$\{\{\s*inputs\.([a-z-]+)\s*\}\}", sub, m.group(2))
script = re.sub(r"\$\{\{\s*inputs\.([a-z-]+)\s*\}\}", sub, run)
if "${{" in script:  # an expression form this simulator does not substitute: not measured, never «clean»
    print("UNMEASURED"); sys.exit(0)
subprocess.run(["bash", "-c", script], env=env, cwd=tmp, capture_output=True)
print("PWNED" if os.path.exists(pwn) else "clean")
PY
}
printf '%s\n' "$_ENVBLK" > "$_L7T/envblk"
printf '%s\n' "$_RUNBLK" > "$_L7T/run.sh"
[ "$(_l7_sim "$_L7T/run.sh")" = "clean" ]; chk $? "L7b a files input carrying '\"; touch …; \"' stays data — no command runs"
rm -f "$_L7T/PWNED"
sed 's/"\$FH_ACTION_FILES"/"${{ inputs.files }}"/' "$_L7T/run.sh" > "$_L7T/run_ctl.sh"
if cmp -s "$_L7T/run.sh" "$_L7T/run_ctl.sh"; then
  no "L7c CONTROL dead — the run script has no \"\$FH_ACTION_FILES\" to turn back into an inline expression"
else
  [ "$(_l7_sim "$_L7T/run_ctl.sh")" = "PWNED" ]; chk $? "L7c CONTROL: the same payload through an inline \${{ inputs.files }} runs the command (the lane can fail)"
fi
rm -rf "$_L7T"

echo "── L8 a file list that reads as a help or version flag is not a pass (2026-11-22) ──"
# WHY. fh-gate printed help and exited 0 for `fh-gate -h <level> <caller>`; the Action always passes three
# arguments and maps exit 0 to PASS with reviewed=true — so `files: -h` (a file literally named so, or a list
# built from PR data) gave an unreviewed PASS (3.47.0 security review, MEDIUM-1). Help and version are now
# honoured only alone. HOW. The run block runs with env as data and an `npx` stub that hands its arguments
# to the real scripts/fh-gate.sh, under the action's real default fail-on; the verdict is read from GITHUB_OUTPUT
# and the step's own exit code is checked. L8b: a normal three-argument call still reaches the gate (dry-run → 12).
# L8-ctl: `fh-gate -h` alone still prints help and exits 0. Named residual: a plain CI step that calls
# `fh-gate "$FILES"` with ONE argument cannot be told from an intended `fh-gate -h` — FILES=-h still exits 0 there.
if [ -f "$G" ] && [ -n "$_RUNBLK" ] && [ -n "$_ENVBLK" ]; then
  _L8T="$(mktemp -d "${TMPDIR:-/tmp}/action_yml_l8_XXXXXX")"
  mkdir -p "$_L8T/bin"
  printf '#!/usr/bin/env bash\nwhile [ $# -gt 0 ] && [ "$1" != fh-gate ]; do shift; done; shift\nexec bash "$L8_GATE" "$@"\n' > "$_L8T/bin/npx"
  chmod +x "$_L8T/bin/npx"
  printf '%s\n' "$_ENVBLK" > "$_L8T/envblk"
  printf '%s\n' "$_RUNBLK" > "$_L8T/run.sh"
  _l8_run(){  # $1 = files input · $2 = dry-run → prints «verdict=… reviewed=… step_rc=…»; fail-on is the real default
    python3 - "$_L8T" "$1" "$G" "$_failon" "${2:-false}" <<'PY'
import re, sys, os, subprocess
tmp, files, gate, failon, dry = sys.argv[1:6]
vals = {"files": files, "level": "quick", "version": "latest", "dry-run": dry,
        "fail-on": failon, "backend": "claude", "model": "", "timeout": ""}
out = os.path.join(tmp, "out"); open(out, "w").close()
env = dict(os.environ, PATH=os.path.join(tmp, "bin") + ":" + os.environ["PATH"], L8_GATE=gate,
           GITHUB_OUTPUT=out, GITHUB_STEP_SUMMARY=os.path.join(tmp, "sum"))
for line in open(os.path.join(tmp, "envblk"), encoding="utf-8"):
    m = re.match(r"([A-Z_]+):\s*(.*)$", line.strip())
    if m: env[m.group(1)] = re.sub(r"\$\{\{\s*inputs\.([a-z-]+)\s*\}\}", lambda x: vals.get(x.group(1), ""), m.group(2))
p = subprocess.run(["bash", os.path.join(tmp, "run.sh")], env=env, cwd=tmp, capture_output=True, timeout=60)
kv = dict(l.split("=", 1) for l in open(out).read().split() if "=" in l)
print("verdict=%s reviewed=%s step_rc=%d" % (kv.get("verdict", "NONE"), kv.get("reviewed", "NONE"), p.returncode))
PY
  }
  for _f in -h --help -V --version; do
    _r="$(_l8_run "$_f")"
    case "$_r" in
      "verdict=ARG_ERROR reviewed=false step_rc=1") ok "L8a files: '$_f' → $_r (not a pass; the step fails under the default fail-on)" ;;
      *) no "L8a files: '$_f' → $_r — an unreviewed run must not read as PASS" ;;
    esac
  done
  # L8b: a normal three-argument call is NOT rejected — the same path with a real file and dry-run reaches the
  # gate's dry-run exit (12), so L8a is not «every multi-argument call returns 11».
  printf 'echo hi\n' > "$_L8T/a.sh"
  _r="$(_l8_run a.sh true)"
  case "$_r" in
    "verdict=DRY_RUN reviewed=false step_rc=1") ok "L8b CONTROL files: 'a.sh' + dry-run → $_r (the three-argument path still reaches the gate)" ;;
    *) no "L8b CONTROL files: 'a.sh' + dry-run → $_r" ;;
  esac
  _hl="$(bash "$G" -h 2>/dev/null)"; _hrc=$?; _hl="${_hl%%$'\n'*}"
  if [ "$_hrc" -eq 0 ] && case "$_hl" in "fh-gate "*) true ;; *) false ;; esac; then
    ok "L8-ctl fh-gate -h alone still prints help (exit 0)"
  else
    no "L8-ctl fh-gate -h alone gave rc=$_hrc '$_hl'"
  fi
  rm -rf "$_L8T"
else
  echo "  ⬜ L8 SKIPPED (not PASS) — scripts/fh-gate.sh or the run block is absent here"
fi

echo ""
echo "── action.yml lanes: $PASS passed · $FAIL failed ──"
[ "$FAIL" -eq 0 ]
