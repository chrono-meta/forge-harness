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
PORT="${FH_LANE_PORT:-18011}"
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
  stop_stub
  python3 "$STUB" "$PORT" "$1" >/dev/null 2>&1 &
  SRV_PID=$!
  for _ in $(seq 1 40); do
    # Ready = ANY HTTP answer, not a 2xx: the notollama mode answers /api/version with a 404 on
    # purpose, and `-f` would read that as "stub never came up".
    _c="$(curl -s -o /dev/null --max-time 1 -w '%{http_code}' "http://127.0.0.1:$PORT/api/version" 2>/dev/null)"
    [ "${_c:-000}" != "000" ] && return 0
    sleep 0.25
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
out=$( FH_OLLAMA_HOST="http://127.0.0.1:$((PORT+7))" bash "$CAL" --only ollama --quiet 2>&1 )
if printf '%s' "$out" | grep -q 'ABSENT — no server at the configured host'; then
  printf '  ✅ %-44s reported ABSENT\n' "S6 no server at host"; pass=$((pass+1))
else
  printf '  ❌ %-44s (expected a measured ABSENT line)\n' "S6 no server at host"
  printf '     out: %s\n' "$(printf '%s' "$out" | head -3)"; fail=$((fail+1))
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "[ollama-panel] ✅ all $pass known pairs hold"; exit 0
else
  echo "[ollama-panel] ❌ $fail/$((pass+fail)) lanes failed"; exit 1
fi
