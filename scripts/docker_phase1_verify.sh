#!/usr/bin/env bash
# Phase 1a — headless codex dispatch in-container (FH Docker Track 2).
# Builds the (Phase 1) Operator image and proves the dispatch toolchain works in-container.
#
# HONEST SCOPE (governor note): codex is an LLM — its OUTPUT is non-deterministic, so unlike Phase 0
# (gate verdicts) we do NOT diff host vs container output. Phase 1a proves two narrower, real things:
#   (1) toolchain reproducibility — pinned codex version, host == container (the immutability claim)
#   (2) auth + network reach in-container — a headless `codex exec` with runtime-mounted ~/.codex
#       returns exit 0 and non-empty output (proves the stateless-container / mounted-auth design works)
# Prereq: Docker/OrbStack running; ~/.codex/auth.json present. Run from forge-harness repo root.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || { echo "PHASE1: cannot cd to repo root"; exit 1; }
REPO="$PWD"
IMG="fh-operator:latest"
PIN="0.139.0"

command -v docker >/dev/null 2>&1 || { echo "PHASE1: docker not found — install OrbStack/Docker"; exit 1; }
docker info >/dev/null 2>&1 || { echo "PHASE1: docker daemon not reachable — start OrbStack/Docker"; exit 1; }
[ -f "$HOME/.codex/auth.json" ] || { echo "PHASE1: ~/.codex/auth.json missing — codex not authed on host"; exit 1; }

echo "== build Operator image (Phase 1 — codex baked) =="
docker build -f templates/docker/Dockerfile.operator -t "$IMG" . || { echo "PHASE1: build FAILED"; exit 1; }

fail=0

echo "== check 1: toolchain reproducibility (pinned codex version, host == container) =="
host_ver=$(codex --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
cont_ver=$(docker run --rm "$IMG" -c "codex --version" 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
echo "   host=$host_ver  container=$cont_ver  pin=$PIN"
if [ "$cont_ver" = "$PIN" ] && [ "$host_ver" = "$cont_ver" ]; then
  echo "   ✅ codex version pinned + immutable host↔container"
else
  echo "   ❌ version mismatch (pin=$PIN host=$host_ver container=$cont_ver)"
  fail=$((fail+1))
fi

echo "== check 2: auth + network reach in-container (headless codex exec, mounted ~/.codex) =="
# trivial deterministic-shaped prompt; we assert exit 0 + non-empty, NOT exact text.
smoke=$(docker run --rm \
          -v "$REPO":/work/forge-harness \
          -v "$HOME/.codex":/root/.codex \
          -w /work/forge-harness \
          "$IMG" -c "codex exec --skip-git-repo-check 'Reply with exactly: OK' 2>&1; echo EXIT:\$?")
echo "$smoke" | tail -6 | sed 's/^/     /'
sexit=$(echo "$smoke" | grep -oE 'EXIT:[0-9]+' | tail -1 | cut -d: -f2)
if [ "${sexit:-1}" = "0" ] && [ -n "$(echo "$smoke" | grep -iE 'OK|codex')" ]; then
  echo "   ✅ codex ran headless in-container with mounted auth (exit 0)"
else
  echo "   ❌ codex dispatch failed in-container (exit=${sexit:-?}) — check auth mount / network"
  fail=$((fail+1))
fi

echo "=================================================="
if [ "$fail" -eq 0 ]; then
  echo "PHASE 1a PASS — codex dispatch reproducible + working in-container. fh-dispatch.sh ready."
  echo "Next: Phase 1b (DLP security-filter path: container → Ollama@Tailscale, raw→abstract only)."
  exit 0
else
  echo "PHASE 1a FAIL — $fail check(s) failed. Inspect before committing."
  exit 1
fi
