#!/usr/bin/env bash
# Phase 1b — DLP security-filter in-container (FH Docker Track 2).
# Proves the local-LLM redaction path: container → local Ollama → abstracted output, gated by a
# MECHANICAL must-redact scan (fail-closed). Uses SYNTHETIC fake secrets only (public-safe).
#
# Checks:
#   0  container → Ollama reachable (api/tags via host gateway)
#   1  abstraction smoke — synthetic confidential sample: gate PASSES (exit 0), the fake secret
#      tokens are ABSENT from output, and structural meaning is PRESERVED (KEEP marker survives)
#   2  fail-closed proof — REDACT_PATTERNS set to words guaranteed to survive → gate BLOCKS (exit 3),
#      proving the mechanical guard withholds output when redaction is incomplete (the
#      downstream-uncorrectable guarantee — does NOT depend on the model getting it right)
# Prereq: Docker/OrbStack running; a local Ollama with OLLAMA_MODEL (default gemma4:e2b-it-qat).
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || { echo "PHASE1b: cannot cd to repo root"; exit 1; }
REPO="$PWD"
IMG="fh-operator:latest"
MODEL="${OLLAMA_MODEL:-gemma4:e2b-it-qat}"
# OLLAMA_HOST is a one-var swap between filter tiers: the host gateway (a small local model) or a
# heavier node's Tailscale IP (the 70B-vs-32B calibration of carry #1). Default = OrbStack gateway.
HOSTPORT="${OLLAMA_HOST:-host.docker.internal:11434}"

command -v docker >/dev/null 2>&1 || { echo "PHASE1b: docker not found — install OrbStack/Docker"; exit 1; }
docker info >/dev/null 2>&1 || { echo "PHASE1b: docker daemon not reachable — start OrbStack/Docker"; exit 1; }

dr() { docker run --rm -v "$REPO":/work/forge-harness -w /work/forge-harness \
         -e "OLLAMA_MODEL=$MODEL" -e "OLLAMA_HOST=$HOSTPORT" "$IMG" -c "$1" 2>&1; }

fail=0

echo "== check 0: container → Ollama reachable (host=$HOSTPORT model=$MODEL) =="
if dr "curl -s --max-time 6 http://$HOSTPORT/api/tags | jq -e '.models|length>=0' >/dev/null && echo OK" | grep -q OK; then
  echo "   ✅ Ollama reachable from container"
else
  echo "   ❌ Ollama unreachable from container — start Ollama or fix OLLAMA_HOST=$HOSTPORT"; fail=$((fail+1))
fi

# Synthetic confidential sample — deliberately FICTIONAL: RFC5737 documentation IP (192.0.2.x) +
# RFC2606 reserved domain (example.internal) + obviously-fake tokens. Never resembles a real asset.
SAMPLE='The orders service authenticates with key sk-TEST-abc123 against host svc.example.internal (192.0.2.7) and retries 3 times on timeout for record id rec-00012345.'
REDACT='sk-[A-Za-z0-9-]+|svc\.example\.internal|192\.0\.2\.[0-9]+|rec-[0-9]+'

echo "== check 1: abstraction smoke (secrets removed, structure kept) =="
OUT=$(dr "printf '%s' '$SAMPLE' | REDACT_PATTERNS='$REDACT' KEEP_PATTERNS='orders|retr|timeout' bash scripts/dlp-filter.sh - ; echo EXIT:\$?")
echo "$OUT" | sed 's/^/     /'
ex=$(echo "$OUT" | grep -oE 'EXIT:[0-9]+' | tail -1 | cut -d: -f2)
body=$(echo "$OUT" | grep -v 'EXIT:')
if [ "${ex:-1}" = "0" ] \
   && ! printf '%s' "$body" | grep -qiE "$REDACT" \
   && printf '%s' "$body" | grep -qiE 'settlement|retr|timeout'; then
  echo "   ✅ abstracted: fake secrets absent + structure preserved + gate PASS"
else
  echo "   ❌ smoke failed (exit=${ex:-?}; secrets-absent or structure-kept check failed)"; fail=$((fail+1))
fi

echo "== check 2: fail-closed proof (a surviving redact pattern must BLOCK) =="
# 'orders' WILL survive any reasonable abstraction → the gate must withhold output (exit 3).
OUT2=$(dr "printf '%s' '$SAMPLE' | REDACT_PATTERNS='orders|service' bash scripts/dlp-filter.sh - ; echo EXIT:\$?")
ex2=$(echo "$OUT2" | grep -oE 'EXIT:[0-9]+' | tail -1 | cut -d: -f2)
echo "$OUT2" | grep -iE 'BLOCKED|EXIT:' | sed 's/^/     /'
if [ "${ex2:-0}" = "3" ]; then
  echo "   ✅ gate failed CLOSED — output withheld when a redact pattern survived"
else
  echo "   ❌ gate did NOT block (exit=${ex2:-?}) — fail-closed guarantee broken"; fail=$((fail+1))
fi

echo "=================================================="
if [ "$fail" -eq 0 ]; then
  echo "PHASE 1b PASS — DLP filter abstracts in-container + mechanical gate fails closed."
  echo "Next: 70B-vs-32B calibrate-first (carry #1) — swap OLLAMA_HOST to a heavier node, measure"
  echo "      abstraction quality (entity/constraint preservation) at each tier."
  exit 0
else
  echo "PHASE 1b FAIL — $fail check(s) failed. Inspect before committing."
  exit 1
fi
