#!/usr/bin/env bash
# FH DLP security-filter (Docker Track 2, Phase 1b) — local-LLM redaction before frontier.
#
# WHY: sending confidential RAW (payment-network architecture, internal IPs, account ids) straight
# to a frontier model is a DLP leak. This filter routes RAW through a LOCAL Ollama model to produce
# an ABSTRACTED version, and emits it ONLY if a mechanical literal scan confirms the must-redact
# patterns are absent (fail-closed).
#
# THE DOWNSTREAM-UNCORRECTABLE GUARD: Opus/Codex never see the raw (that is the whole point), so a
# bad abstraction can NEVER be caught downstream — the governor cross-check is blind here. Therefore
# the quality gate cannot be "trust the (small, local) model" — it is a MECHANICAL post-scan that
# blocks the output if any known-secret pattern survived. The model abstracts; the grep guarantees.
#
# Usage:
#   REDACT_PATTERNS='sk-[A-Za-z0-9]+|10\.0\.[0-9.]+|acct-[0-9]+' scripts/dlp-filter.sh raw.txt > safe.txt
#   printf '%s' "$RAW" | REDACT_PATTERNS='...' scripts/dlp-filter.sh -
#
# Env:
#   OLLAMA_HOST     default host.docker.internal:11434 (OrbStack host gateway from the container).
#                   Point at a heavier node's Tailscale IP for 70B-vs-32B calibration (carry #1).
#   OLLAMA_MODEL    default gemma4:e2b-it-qat (local filter-tier; calibration swaps this).
#   REDACT_PATTERNS extended-regex of literals that MUST NOT survive into output (fail-closed gate).
#                   REQUIRED — with no pattern there is no mechanical guarantee, so the filter refuses.
#   KEEP_PATTERNS   optional extended-regex of structural markers that SHOULD survive (warn if gone —
#                   over-redaction signal; the abstraction must keep enough meaning to be useful).
#
# Exit: 0 = abstracted + gate PASS (output on stdout) · 2 = usage error · 3 = BLOCKED (a redact
#       pattern survived — output withheld, never sent onward) · 4 = Ollama unreachable.
set -uo pipefail

HOSTPORT="${OLLAMA_HOST:-host.docker.internal:11434}"
MODEL="${OLLAMA_MODEL:-gemma4:e2b-it-qat}"
SRC="${1:-}"
[ -n "$SRC" ] || { echo "dlp-filter: need a file arg or '-' for stdin" >&2; exit 2; }
[ -n "${REDACT_PATTERNS:-}" ] || {
  echo "dlp-filter: REDACT_PATTERNS is required — without it the mechanical gate has nothing to" >&2
  echo "            enforce and the filter would be trust-the-model only (the failure this guards)." >&2
  exit 2; }

if [ "$SRC" = "-" ]; then RAW="$(cat)"; else RAW="$(cat "$SRC")"; fi
[ -n "$RAW" ] || { echo "dlp-filter: empty input" >&2; exit 2; }

# reachability check (fail-closed: cannot abstract → do NOT pass raw onward)
curl -s --max-time 6 "http://${HOSTPORT}/api/tags" >/dev/null 2>&1 || {
  echo "dlp-filter: Ollama unreachable at ${HOSTPORT} — refusing (raw never leaves)" >&2; exit 4; }

PROMPT="You are a strict DLP redaction filter. Rewrite the text below so it preserves its TECHNICAL
MEANING and STRUCTURE, but replace every concrete confidential identifier — API keys/tokens, internal
hostnames, IP addresses, account numbers, person names, company-internal codenames — with a generic
placeholder of the form <REDACTED:type>. Do not add commentary. Output ONLY the rewritten text.

TEXT:
${RAW}"

# build the request with jq (safe JSON encoding of the prompt), deterministic decoding.
REQ="$(jq -n --arg m "$MODEL" --arg p "$PROMPT" \
        '{model:$m, prompt:$p, stream:false, options:{temperature:0}}')"
RESP="$(curl -s --max-time 120 "http://${HOSTPORT}/api/generate" -d "$REQ" 2>/dev/null)"
OUT="$(printf '%s' "$RESP" | jq -r '.response // empty' 2>/dev/null)"
[ -n "$OUT" ] || { echo "dlp-filter: model returned no abstraction — refusing (raw never leaves)" >&2; exit 4; }

# ── MECHANICAL GATE (the downstream-uncorrectable guard) ─────────────────────
# A must-redact literal surviving into the abstraction = BLOCK. The output is withheld; raw never
# proceeds. This is the guarantee that does NOT depend on the small model getting it right.
if printf '%s' "$OUT" | grep -qiE "$REDACT_PATTERNS"; then
  echo "dlp-filter: BLOCKED — a must-redact pattern survived the abstraction; output withheld." >&2
  echo "            (the local model under-redacted; raw is NOT forwarded to the frontier.)" >&2
  exit 3
fi

# preservation warning (over-redaction signal — non-blocking)
if [ -n "${KEEP_PATTERNS:-}" ] && ! printf '%s' "$OUT" | grep -qiE "$KEEP_PATTERNS"; then
  echo "dlp-filter: WARN — expected structural marker (KEEP_PATTERNS) missing; possible over-redaction." >&2
fi

printf '%s\n' "$OUT"
