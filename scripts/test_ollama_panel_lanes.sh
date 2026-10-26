#!/usr/bin/env bash
# test_ollama_panel_lanes.sh — hermetic known pairs for the ollama panel leg of sidecar_calibrate.sh
#
# Hermetic by construction: every lane runs against a stub HTTP server on loopback. No network, no
# spend, no dependence on a node being powered on — the same property the CLI lanes get from stub
# binaries. A calibrator whose own tests need the thing it calibrates cannot fail honestly.
#
# WHAT MAKES THIS LEG DIFFERENT FROM codex/agy, AND WHY IT NEEDED ITS OWN LANES
#   The CLI legs anchor PIN-OK on the model's SELF-REPORT. That anchor is invalid here and the
#   measurement says so: asked which model it was, `gpt-oss:20b` answered "The underlying model is
#   GPT-4 (likely)" (2026-07-31). Open-weight models do not reliably know their own name, so a
#   self-report anchor would mark an EXACT pin as UNTRUSTED and drop it from the panel — an
#   instrument that cannot separate known-positive from known-negative on its target. The anchor is
#   therefore the SERVER's response envelope: a server-side fact, not a model's claim.
#   Lane S2 is the reason that distinction has teeth — it is the agy failure in this protocol's
#   spelling: the server quietly answers as a different model than the one pinned.

set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CAL="$ROOT/scripts/sidecar_calibrate.sh"
pass=0; fail=0
# PORT — asked of the OS, not hardcoded (2026-10-26). It was `${FH_LANE_PORT:-18011}`, and 18011
# is machine-global: a TCP port is not scoped to a checkout. Two copies of this suite running in
# DIFFERENT trees on one machine both try to bind it; the loser's stub dies with "Address already in
# use", every lane in the losing run then talks to the WINNER's stub, and the verdicts come back as
# an unreproducible mix that reads exactly like a flake — measured 2026-10-26, when this suite and
# three others only ever went red under concurrent load and passed 3/3 standalone in both trees.
# The lesson generalizes past this file: a fixture keyed on a machine-global name (a port, a
# /proc-wide process pattern, a fixed /tmp path) is not hermetic however hermetic its logic is.
# FH_LANE_PORT still wins when set — an operator pinning a port has a reason, and overriding them
# would trade one surprise for another.
_free_port() { # a port the OS says is free right now: bind :0, read it back, release it
  python3 -c 'import socket
s=socket.socket(); s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()'
}
# A released ephemeral port can be taken in the window before the stub binds it — rare, and the
# honest answer to rare is a retry that NAMES itself, not a lane failure that looks like a defect
# in the subject. start_stub re-picks on each attempt when the port was not pinned.
PORT="${FH_LANE_PORT:-}"
[ -n "$PORT" ] || PORT="$(_free_port)"
PORT_PINNED=0; [ -n "${FH_LANE_PORT:-}" ] && PORT_PINNED=1
SRV_PID=""

# `wait` after the kill, so bash reaps the child quietly instead of printing "Terminated: 15" into
# the lane output — a harness that litters CI logs teaches people to stop reading them.
stop_stub() {
  [ -n "$SRV_PID" ] || return 0
  kill "$SRV_PID" 2>/dev/null
  wait "$SRV_PID" 2>/dev/null
  SRV_PID=""
}
trap 'stop_stub' EXIT

# The stub is written to a file so the heredoc cannot collide with the lane script's own quoting.
STUB="$(mktemp -d)/stub.py"
cat > "$STUB" <<'PY'
import json, sys, time
from http.server import BaseHTTPRequestHandler, HTTPServer
PORT = int(sys.argv[1]); MODE = sys.argv[2]

class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def _send(self, obj, code=200):
        b = json.dumps(obj).encode()
        self.send_response(code); self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(b))); self.end_headers(); self.wfile.write(b)
    def do_GET(self):
        if self.path == "/api/version":
            if MODE == "notollama": self._send({"error": "not found"}, 404); return
            if MODE == "fake200":   # answers 200 to everything, but is not Ollama
                b = b"<html>ok</html>"
                self.send_response(200); self.send_header("Content-Type", "text/html")
                self.send_header("Content-Length", str(len(b))); self.end_headers(); self.wfile.write(b); return
            self._send({"version": "stub"})
        elif self.path == "/api/tags":
            if MODE == "tags500": self._send({"error": "listing failed"}, 500); return
            if MODE == "tagsdrop": self.close_connection = True; return
            self._send({"models": [{"name": "stub-model:1b"}]})
        else: self._send({}, 404)
    def do_POST(self):
        n = int(self.headers.get("Content-Length", 0))
        req = json.loads(self.rfile.read(n) or b"{}")
        m = req.get("model", "")
        if m.startswith("fh-calib-nonexistent"):
            # BOGUS control. 'accept' mode is the dangerous server: it serves SOMETHING for a name
            # that cannot exist, so the pin is never validated at all.
            if MODE == "accept": self._send({"model": m, "response": "PASS"})
            elif MODE == "ctl500": self._send({"error": "llama runner crashed"}, 500)
            else: self._send({"error": f"model '{m}' not found"})
            return
        # Real Ollama refuses with a 4xx + {"error": ...}. The G1 incident (2026-09-24) was exactly
        # these two bodies rendered as UNREACHABLE because `curl -sf` threw them away.
        if MODE == "notfound":
            self._send({"error": f"model '{m}' not found"}, 404); return
        if MODE == "invalid":
            self._send({"error": "invalid model name"}, 400); return
        if MODE == "srv500":
            self._send({"error": "llama runner process has terminated"}, 500); return
        if MODE == "drop":        # no HTTP answer at all -> curl http_code 000 (empty reply)
            self.close_connection = True; return
        if MODE == "fake200":     # echoes the pin — would be PIN-OK if the host were trusted
            self._send({"model": m, "response": "PASS"}); return
        if MODE == "stall":       # full-looking JSON, but Content-Length promises more; then hang
            b = json.dumps({"model": m, "response": "PASS"}).encode()
            self.send_response(200); self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(b) + 64)); self.end_headers()
            self.wfile.write(b); self.wfile.flush(); time.sleep(6); return
        if MODE == "substitute":  # the agy failure, in this protocol
            self._send({"model": "some-other-model:9b", "response": "PASS"}); return
        if MODE == "starved":     # reasoning model spent the whole budget thinking
            self._send({"model": m, "response": "", "thinking": "x" * 780}); return
        if MODE == "prose":       # cannot carry a machine-read verdict
            self._send({"model": m, "response": "Well, I would say this looks like a PASS overall."}); return
        self._send({"model": m, "response": "PASS"})
HTTPServer(("127.0.0.1", PORT), H).serve_forever()
PY
# shellcheck disable=SC2016
start_stub() {
  local _try
  for _try in 1 2 3; do
    stop_stub
    [ "$_try" -eq 1 ] || [ "$PORT_PINNED" -eq 1 ] || PORT="$(_free_port)"
    python3 "$STUB" "$PORT" "$1" >/dev/null 2>&1 &
    SRV_PID=$!
    for _ in $(seq 1 40); do
      # Ready = ANY HTTP answer, not a 2xx: the notollama mode answers /api/version with a 404 on
      # purpose, and `-f` would read that as "stub never came up".
      _c="$(curl -s -o /dev/null --max-time 1 -w '%{http_code}' "http://127.0.0.1:$PORT/api/version" 2>/dev/null)"
      [ "${_c:-000}" != "000" ] && return 0
      # The stub process being GONE is a different fact from "not ready yet", and waiting out the
      # remaining 10 s on a dead process is how a bind collision used to present as a timeout.
      kill -0 "$SRV_PID" 2>/dev/null || break
      sleep 0.25
    done
    [ "$PORT_PINNED" -eq 1 ] && break
    echo "  ⚠️  stub did not come up on port $PORT (attempt $_try/3) — re-picking a free port" >&2
  done
  return 1
}

# expect <label> <mode> <expect-in-panel: YES|NO> [needle] [forbid]
#   forbid — a string that must NOT appear. A needle alone passes when the right label AND the wrong
#   one are both printed; the G1 lanes need "MODEL-ERROR and NOT UNREACHABLE", not just the former.
#   MODELS (env) overrides FH_OLLAMA_MODELS for the input-contract lanes; unset = the usual pin.
expect() {
  local label="$1" mode="$2" want="$3" needle="${4:-}" forbid="${5:-}" out inpanel forbidden=0
  start_stub "$mode" || { printf '  ❌ %-44s stub failed to start\n' "$label"; fail=$((fail+1)); return; }
  out=$( FH_OLLAMA_HOST="http://127.0.0.1:$PORT" FH_OLLAMA_MODELS="${MODELS-stub-model:1b}" \
         FH_OLLAMA_GEN_TIMEOUT="${GEN_TIMEOUT:-240}" bash "$CAL" --only ollama --quiet 2>&1 )
  stop_stub
  if printf '%s' "$out" | grep -q 'PANEL:.*ollama:stub-model:1b'; then inpanel=YES; else inpanel=NO; fi
  if [ -n "$forbid" ]; then case "$out" in *"$forbid"*) forbidden=1 ;; esac; fi
  if [ "$inpanel" = "$want" ] && [ "$forbidden" -eq 0 ] && { [ -z "$needle" ] || printf '%s' "$out" | grep -q "$needle"; }; then
    printf '  ✅ %-44s in-panel=%s\n' "$label" "$inpanel"; pass=$((pass+1))
  else
    printf '  ❌ %-44s in-panel=%s (expected %s%s%s)\n' "$label" "$inpanel" "$want" "${needle:+, needle '$needle'}" "${forbid:+, forbid '$forbid'}"
    printf '     out: %s\n' "$(printf '%s' "$out" | head -4)"; fail=$((fail+1))
  fi
}

echo "[ollama-panel] known pairs (hermetic stub server)"
expect "S1 envelope matches pin, verdict parses" ok         YES "PIN-OK(envelope)"
expect "S2 server substitutes a DIFFERENT model" substitute NO  "UNTRUSTED-PIN"
expect "S3 empty answer (budget starvation)"     starved    NO  "larger FH_OLLAMA_NUM_PREDICT"
expect "S4 prose answer cannot carry a verdict"  prose      NO  "VERDICT-UNPARSEABLE"
expect "S5 server accepts a bogus model name"    accept     YES "accepts-bogus"

# ── G1 (2026-09-24): a server that ANSWERS with a refusal is not an unreachable server ─────────
# The known-positive for UNREACHABLE is S7 (no HTTP answer); the known-negatives are S8/S9 (a real
# 4xx body). Reverting `_http` to `curl -sf` turns S8/S9 red and leaves S7 green — the revert probe.
expect "S7 no HTTP answer (connection dropped)"  drop       NO  "UNREACHABLE-THIS-RUN" "MODEL-ERROR"
expect "S8 404 model not found → MODEL-ERROR"    notfound   NO  "MODEL-ERROR(model 'stub-model:1b' not found)" "UNREACHABLE"
expect "S9 400 invalid model name → MODEL-ERROR" invalid    NO  "MODEL-ERROR(invalid model name)" "UNREACHABLE"
expect "S10 500 from server → SERVER-ERROR"      srv500     NO  "SERVER-ERROR(http 500" "UNREACHABLE"
expect "S11 non-Ollama host → HOST-ERROR"        notollama  NO  "HOST-ERROR" "ABSENT"
MODELS="" expect "S12 /api/tags 500 ≠ empty listing"  tags500   NO  "model list UNMEASURED" "no models listed"

# ── cross-family review 2026-09-26: four more places where a non-answer read as an answer ──────
expect "S15 any-200 host is not Ollama → HOST-ERROR" fake200 NO  "not the Ollama shape" "PIN-OK"
expect "S16 control 5xx is not rejection"        ctl500     YES "control: unmeasured" "rejects-bogus"
MODELS="" expect "S17 tags 000 does not claim REACHABLE"   tagsdrop NO  "model list UNMEASURED (tags call got no HTTP answer" "REACHABLE"
GEN_TIMEOUT=2 \
  expect "S18 200 then mid-body stall → UNMEASURED" stall   NO  "UNMEASURED-THIS-RUN (http 200" "PIN-OK"
MODELS=" , " \
  expect "S19 explicit-but-empty list → INPUT-ERROR" ok     NO  "no model names after trimming" "PIN-OK"

# ── FH_OLLAMA_MODELS contract: comma-separated. Inner whitespace is rejected, not guessed. ─────
MODELS="stub-model:1b other:2b" \
  expect "S13 space-separated list → INPUT-ERROR" ok        NO  "did you mean: FH_OLLAMA_MODELS=\"stub-model:1b,other:2b\"" "UNREACHABLE"
MODELS=" stub-model:1b , " \
  expect "S14 padding around commas is trimmed"   ok        YES "PIN-OK(envelope)" "INPUT-ERROR"

# S6 — absence must be MEASURED, never assumed. No server at the host at all.
# The dead host used to be `$((PORT+7))`, which is arithmetic on an assumption: PORT+7 is free
# because nobody is expected to be there. On a busy machine somebody is, and then this lane asserts
# ABSENT against a host that answers and goes red for a reason that has nothing to do with the
# subject. Ask the OS for a port and then CHECK it is silent — the lane's own premise, measured.
_dead_port=""
for _ in 1 2 3; do
  _p="$(_free_port)"
  [ "$(curl -s -o /dev/null --max-time 1 -w '%{http_code}' "http://127.0.0.1:$_p/api/version" 2>/dev/null)" = "000" ] \
    && { _dead_port="$_p"; break; }
done
if [ -z "$_dead_port" ]; then
  # UNMEASURED, not a pass and not a failure of the subject: three ports in a row answered, so this
  # lane never got the silent host its premise needs. Counted as a failure because an unmeasured
  # known pair proves nothing — the same rule the suites around this one already follow.
  printf '  ❌ %-44s UNMEASURED: could not obtain a silent port (3 tries)\n' "S6 no server at host"
  fail=$((fail+1))
else
out=$( FH_OLLAMA_HOST="http://127.0.0.1:$_dead_port" bash "$CAL" --only ollama --quiet 2>&1 )
if printf '%s' "$out" | grep -q 'ABSENT — no server at the configured host'; then
  printf '  ✅ %-44s reported ABSENT\n' "S6 no server at host"; pass=$((pass+1))
else
  printf '  ❌ %-44s (expected a measured ABSENT line)\n' "S6 no server at host"
  printf '     out: %s\n' "$(printf '%s' "$out" | head -3)"; fail=$((fail+1))
fi
fi

# ── S20 (2026-10-26) — the known pair for the port repair itself ───────────────────────────────
# The defect this suite shipped with was not in its logic: PORT was the fixed 18011, so two copies
# running in different trees on one machine fought over one socket. That is only a repair if the
# collision is REAL and the repair survives it, so this lane holds a port open and asks both
# questions against the live code rather than against my description of it.
echo "── S20 port is not machine-global ──"
_hold_out="$(mktemp)"; _held=""
python3 -c 'import socket,sys,time
s=socket.socket(); s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(("127.0.0.1", 0)); s.listen(1)
print(s.getsockname()[1], flush=True)
time.sleep(45)' > "$_hold_out" 2>/dev/null &
_hold_pid=$!
for _ in $(seq 1 40); do _held="$(head -1 "$_hold_out" 2>/dev/null)"; [ -n "$_held" ] && break; sleep 0.25; done
_saved_port="$PORT"; _saved_pinned="$PORT_PINNED"
if [ -z "$_held" ]; then
  # UNMEASURED: no holder, so neither arm below means anything. Counted, for the same reason S6's
  # unmeasured arm is counted — a known pair that did not run is not a known pair that passed.
  printf '  ❌ %-44s UNMEASURED: could not hold a port open\n' "S20 occupied-port known pair"
  fail=$((fail+1))
else
  # known-POSITIVE: the collision is real. Pin the stub to the held port and the stub cannot come
  # up. If this arm ever passes, binding a busy port stopped failing and the lane below proves
  # nothing — so the positive control is what keeps the negative one honest.
  PORT="$_held"; PORT_PINNED=1
  if start_stub ok 2>/dev/null; then
    printf '  ❌ %-44s a stub came up on an OCCUPIED port — the control is broken\n' "S20a known-positive"
    fail=$((fail+1))
  else
    printf '  ✅ %-44s a pinned, occupied port really does stop the stub\n' "S20a known-positive"
    pass=$((pass+1))
  fi
  stop_stub
  # known-NEGATIVE: with the port NOT pinned, the same occupied port is simply not chosen — which
  # is the whole repair. The old `${FH_LANE_PORT:-18011}` form had no way to express this.
  PORT_PINNED=0; PORT="$_held"
  if start_stub ok && [ "$PORT" != "$_held" ]; then
    printf '  ✅ %-44s unpinned: picked %s instead of the occupied port\n' "S20b known-negative" "$PORT"
    pass=$((pass+1))
  else
    printf '  ❌ %-44s unpinned run did not route around the occupied port (port=%s)\n' "S20b known-negative" "$PORT"
    fail=$((fail+1))
  fi
  stop_stub
fi
kill "$_hold_pid" 2>/dev/null; wait "$_hold_pid" 2>/dev/null
rm -f "$_hold_out"
PORT="$_saved_port"; PORT_PINNED="$_saved_pinned"

echo
if [ "$fail" -eq 0 ]; then
  echo "[ollama-panel] ✅ all $pass known pairs hold"; exit 0
else
  echo "[ollama-panel] ❌ $fail/$((pass+fail)) lanes failed"; exit 1
fi
