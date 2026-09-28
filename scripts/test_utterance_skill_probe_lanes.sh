#!/usr/bin/env bash
# Known-pair lanes for scripts/utterance_skill_probe.sh (identity ④ measurement channel).
#
# 🟥 WHAT THESE PIN, and why each one is load-bearing:
#   SAFE-1/2  the probe injects NOTHING on stdout and always exits 0. PreToolUse stdout is parsed
#             as JSON by Claude Code; a stray byte there is a live hazard on every skill call.
#   DISC      the utterance/internal discriminator actually discriminates — without the induced=no
#             arm, "everything is utterance-induced" would look identical to a working probe.
#   CONSUME   one utterance marks only the FIRST skill. This is what structurally excludes the
#             over-firing that `prior_art_prompt.sh`'s own header warns is unrecoverable
#             («금지로 읽히면 무시당한다» — once dismissed, always dismissed).
#   ISOLATE   the operator runs parallel sessions on one checkout. A shared token would let session
#             A's utterance be consumed by session B's skill call and FABRICATE rows. This arm is
#             the reason the token is session-keyed at all.
#   CTRL      a non-Skill tool writes no row — proves rows are selected by tool_name, not emitted
#             for everything that passes through.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
P="$ROOT/scripts/utterance_skill_probe.sh"
PASS=0; FAIL=0
ok(){ printf '  ✅ %s\n' "$1"; PASS=$((PASS+1)); }
no(){ printf '  ❌ %s\n' "$1"; FAIL=$((FAIL+1)); }

[ -f "$P" ] || { echo "FAIL  subject 부재: $P — ④ 계측 채널이 사라졌다"; exit 1; }

T=$(mktemp -d); trap '_k=$(cat "$T/decider_calls.pid" 2>/dev/null); [ -n "$_k" ] && kill "$_k" 2>/dev/null; rm -rf "$T"' EXIT
mkdir -p "$T/tracks/_meta"
LOG="$T/tracks/_meta/utterance_skill_probe.log"
run(){ CLAUDE_PROJECT_DIR="$T" TMPDIR="$T" bash "$P" "$@"; }
mark(){ printf '{"session_id":"%s"}' "$1" | run --mark; }
call(){ printf '{"tool_name":"%s","session_id":"%s","tool_input":{"skill":"%s"}}' "${3:-Skill}" "$1" "$2" | run --check; }
# 🟥 NO `|| echo 0` HERE. `grep -c` PRINTS "0" and EXITS 1 on no-match, so the fallback appends a
# SECOND line, the value becomes "0\n0", and `[ -eq ]` dies with 'integer expression expected' —
# on stderr only, so the guarded branch is silently skipped. That is the pipefail-fallback disarm
# ([[feedback_pipefail_fallback_disarms_guard]]) that scripts/session_close_check.sh documents and
# the scanner's S5 probe exists to catch. First draft of THIS file used `|| echo 0` and the CTRL
# lane died in exactly that way — written down rather than quietly corrected, because knowing the
# class did not prevent it. Capture, then sanitize.
_num(){ local n; n=$(grep -c "$1" "$LOG" 2>/dev/null); n=${n:-0}
        case "$n" in *[!0-9]*) n=0 ;; esac; printf '%s' "$n"; }
rows(){ _num "skill=$1 "; }
ind(){ local n; n=$(grep "skill=$1 " "$LOG" 2>/dev/null | grep -c "induced=$2"); n=${n:-0}
       case "$n" in *[!0-9]*) n=0 ;; esac; printf '%s' "$n"; }

echo "utterance-skill probe known-pair"

# SAFE — the two properties that make this safe to wire at all
out=$(call sX s_safe); rc=$?
[ -z "$out" ] && ok "SAFE-1 stdout is empty (PreToolUse parses stdout as JSON)" \
              || no "SAFE-1 probe wrote to stdout: [$out] — this corrupts the hook contract"
[ "$rc" = "0" ] && ok "SAFE-2 exit 0" || no "SAFE-2 exit $rc (must never be non-zero)"
printf 'not json at all' | run --check >/dev/null 2>&1; rc=$?
[ "$rc" = "0" ] && ok "SAFE-3 unparseable input still exits 0" || no "SAFE-3 exit $rc on junk input"

# DISC / CONSUME — the discriminator and the once-per-utterance property
call sA s_noMark >/dev/null
[ "$(ind s_noMark no)" -eq 1 ] && ok "DISC-neg no token → induced=no" || no "DISC-neg expected induced=no"
mark sA; call sA s_marked >/dev/null
[ "$(ind s_marked YES)" -eq 1 ] && ok "DISC-pos after a mark → induced=YES" || no "DISC-pos expected induced=YES"
call sA s_second >/dev/null
[ "$(ind s_second no)" -eq 1 ] && ok "CONSUME second skill of the same utterance → induced=no" \
                               || no "CONSUME token was not consumed — this is the over-fire path"

# ISOLATE — parallel sessions must not eat each other's token
mark sA; call sB s_peer >/dev/null
[ "$(ind s_peer no)" -eq 1 ] && ok "ISOLATE peer session does not consume this session's token" \
                             || no "ISOLATE peer consumed the token — rows would be fabricated"
call sA s_mine >/dev/null
[ "$(ind s_mine YES)" -eq 1 ] && ok "ISOLATE the owner's token survived the peer call" \
                              || no "ISOLATE owner's token was destroyed by a peer"

# CTRL — rows are selected, not emitted for everything
call sA s_bash Bash >/dev/null
[ "$(rows s_bash)" -eq 0 ] && ok "CTRL a non-Skill tool writes no row" || no "CTRL logged a non-Skill tool"

# CTRL-2 — a missing log dir must not break the caller (degrade = do nothing, never fail)
out=$(CLAUDE_PROJECT_DIR="$T/nosuchroot" TMPDIR="$T" bash "$P" --check <<<'{"tool_name":"Skill","tool_input":{}}'); rc=$?
{ [ -z "$out" ] && [ "$rc" = "0" ]; } && ok "CTRL-2 unwritable/absent log root → silent no-op, exit 0" \
                                      || no "CTRL-2 broke on an absent log root (stdout=[$out] rc=$rc)"

# ── ROUTE SHADOW (2026-09-28) — off by default · detached · never on stdout · pinned to the Mac node ──
#   R-OFF    FH_ROUTE_SHADOW unset → the decider is called ZERO times, even when it is present.
#   R-ON     set → exactly one call; hook stdout stays empty; exit 0; argv pins qwen3:8b on `mac`
#            (never the GPU node); the utterance arrives on the decider's stdin.
#   R-FAIL   decider exits non-zero · decider absent → hook still exit 0 and silent.
#   R-JOIN   the induced --check row carries mark=<t> equal to the <t> in the decider's --id.
#   R-REVERT a mutant that lets the decider write to the hook's stdout (the injection path) must turn
#            R-ON's stdout check red — else that check is decoration.
DEC_DIR="$T/tracks/_meta/local_decider_2026-09-26"; mkdir -p "$DEC_DIR"
CALLS="$T/decider_calls"
cat > "$DEC_DIR/local_decide.py" <<'STUB'
import os, sys
body = sys.stdin.read()
with open(os.environ["STUB_CALLS"], "a") as f:
    f.write(" ".join(sys.argv[1:]) + " |nodes=" + os.environ.get("LOCAL_DECIDER_NODES", "") + " |stdin=" + body + "\n")
print('{"choice":"STUB_ON_STDOUT"}')
sys.exit(int(os.environ.get("STUB_RC", "0")))
STUB
umark(){ printf '{"session_id":"%s","prompt":"%s"}' "$1" "$2" | CLAUDE_PROJECT_DIR="$T" TMPDIR="$T" STUB_CALLS="$CALLS" bash "${3:-$P}" --mark; }
ncalls(){ local n; n=$(grep -c . "$CALLS" 2>/dev/null); n=${n:-0}; case "$n" in *[!0-9]*) n=0 ;; esac; printf '%s' "$n"; }
waitcalls(){ local i=0; while [ "$i" -lt 50 ] && [ "$(ncalls)" -lt "$1" ]; do sleep 0.1; i=$((i+1)); done; }

rm -f "$CALLS"
out=$(env -u FH_ROUTE_SHADOW bash -c 'printf "{\"session_id\":\"rOff\",\"prompt\":\"hi\"}" | CLAUDE_PROJECT_DIR="$1" TMPDIR="$1" STUB_CALLS="$2" bash "$3" --mark' _ "$T" "$CALLS" "$P"); rc=$?
sleep 1
{ [ "$(ncalls)" -eq 0 ] && [ -z "$out" ] && [ "$rc" = 0 ]; } && ok "R-OFF unset → decider called 0 times" \
  || no "R-OFF decider ran without FH_ROUTE_SHADOW (calls=$(ncalls) stdout=[$out] rc=$rc)"

rm -f "$CALLS"
out=$(FH_ROUTE_SHADOW=1 LOCAL_DECIDER_NODES="mac=http://gpu-host:11434,gpu=http://gpu-host:11434" umark rOn "그래프 루프 돌릴까"); rc=$?
waitcalls 1
{ [ -z "$out" ] && [ "$rc" = 0 ]; } && ok "R-ON stdout empty · exit 0 (nothing reaches the session)" \
  || no "R-ON hook leaked to stdout or failed: [$out] rc=$rc"
[ "$(ncalls)" -eq 1 ] && ok "R-ON exactly one background call" || no "R-ON calls=$(ncalls) (want 1)"
grep -q -- '--model qwen3:8b --node mac' "$CALLS" 2>/dev/null && ! grep -q -- 'gpu' "$CALLS" 2>/dev/null \
  && grep -q -- '|nodes=mac=http://127.0.0.1:11434 |' "$CALLS" 2>/dev/null \
  && ok "R-ON pinned to qwen3:8b on mac=localhost — an inherited LOCAL_DECIDER_NODES cannot redirect it" \
  || no "R-ON node/model pin broken: $(cat "$CALLS" 2>/dev/null)"
grep -q -- '--task route' "$CALLS" 2>/dev/null && grep -q '|stdin=그래프 루프 돌릴까' "$CALLS" 2>/dev/null \
  && ok "R-ON route task · utterance on stdin" || no "R-ON task/stdin wrong: $(cat "$CALLS" 2>/dev/null)"

call rOn s_joined >/dev/null
_id=$(grep -o -- '--id rOn:[0-9T:.-]*' "$CALLS" 2>/dev/null | head -1); _id=${_id#--id rOn:}
_mk=$(grep 'skill=s_joined ' "$LOG" 2>/dev/null | grep -o 'mark=[0-9T:.-]*' | head -1); _mk=${_mk#mark=}
{ [ -n "$_id" ] && [ "$_id" = "$_mk" ]; } && ok "R-JOIN check row mark= equals the decider id time ($_mk)" \
  || no "R-JOIN join key broken: id=[$_id] mark=[$_mk]"

rm -f "$CALLS"
out=$(FH_ROUTE_SHADOW=1 STUB_RC=1 umark rFail "x"); rc=$?; waitcalls 1
{ [ -z "$out" ] && [ "$rc" = 0 ]; } && ok "R-FAIL decider exits 1 → hook exit 0, silent" || no "R-FAIL [$out] rc=$rc"
mv "$DEC_DIR/local_decide.py" "$DEC_DIR/away.py"
out=$(FH_ROUTE_SHADOW=1 umark rAbsent "x"); rc=$?
{ [ -z "$out" ] && [ "$rc" = 0 ]; } && ok "R-FAIL decider absent → hook exit 0, silent" || no "R-FAIL(absent) [$out] rc=$rc"
mv "$DEC_DIR/away.py" "$DEC_DIR/local_decide.py"

# R-BLOCK — a decider that never reads stdin + a prompt far above any pipe buffer must not stall the hook
cat > "$DEC_DIR/local_decide.py" <<'STUB2'
import os, sys, time
open(os.environ["STUB_CALLS"], "a").write("slow\n")
open(os.environ["STUB_CALLS"] + ".pid", "w").write(str(os.getpid()))
time.sleep(30)
STUB2
BIG=$(head -c 300000 /dev/zero | tr '\0' 'a')
rm -f "$CALLS"; _t0=$(date +%s)
out=$(printf '{"session_id":"rBig","prompt":"%s"}' "$BIG" | FH_ROUTE_SHADOW=1 CLAUDE_PROJECT_DIR="$T" TMPDIR="$T" STUB_CALLS="$CALLS" bash "$P" --mark 2>/dev/null >/dev/null & _p=$!; i=0; while kill -0 "$_p" 2>/dev/null && [ "$i" -lt 100 ]; do sleep 0.1; i=$((i+1)); done; kill -0 "$_p" 2>/dev/null && { kill "$_p"; echo HUNG; } || echo DONE)
waitcalls 1
{ [ "$out" = "DONE" ] && [ "$(ncalls)" -ge 1 ]; } && ok "R-BLOCK 300KB prompt + non-reading decider → hook returns within 10s" \
  || no "R-BLOCK hook stalled on the decider ([$out], calls=$(ncalls))"
_sp=$(cat "$CALLS.pid" 2>/dev/null); [ -n "$_sp" ] && kill "$_sp" 2>/dev/null
mv "$DEC_DIR/local_decide.py" "$DEC_DIR/slow.py"
cat > "$DEC_DIR/local_decide.py" <<'STUB3'
import os, sys
body = sys.stdin.read()
with open(os.environ["STUB_CALLS"], "a") as f:
    f.write(" ".join(sys.argv[1:]) + " |nodes=" + os.environ.get("LOCAL_DECIDER_NODES", "") + " |stdin=" + body + "\n")
print('{"choice":"STUB_ON_STDOUT"}')
STUB3

# R-REVERT — 4 steps: build mutant · confirm it applied · run · expect the R-ON check to go red
M="$T/probe_mutant.sh"
sed 's/stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL/stdout=None, stderr=None/' "$P" > "$M"
if cmp -s "$P" "$M"; then
  no "R-REVERT mutant did not apply (sed matched nothing) — HARNESS-ERROR, not a pass"
else
  rm -f "$CALLS"
  out=$(FH_ROUTE_SHADOW=1 umark rMut "x" "$M"); waitcalls 1
  case "$out" in
    *STUB_ON_STDOUT*) ok "R-REVERT injecting mutant is caught — R-ON's stdout check is live" ;;
    *) no "R-REVERT mutant leaked nothing to stdout — the stdout check cannot see injection ([$out])" ;;
  esac
fi

echo "utterance-skill probe: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
