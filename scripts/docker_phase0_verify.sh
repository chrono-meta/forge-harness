#!/usr/bin/env bash
# Phase 0 — gates-in-container immutability proof (FH Docker Track 2).
# Builds the Operator image, runs the gate scripts BOTH in-container and on the host,
# and diffs the verdict lines. PASS = identical verdicts → BSD↔GNU WOMBAT is closed for gates.
# Prereq: Docker/OrbStack running. Run from the forge-harness repo root.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || { echo "PHASE0: cannot cd to repo root"; exit 1; }
REPO="$PWD"
IMG="fh-operator:latest"

command -v docker >/dev/null 2>&1 || { echo "PHASE0: docker not found — install OrbStack/Docker first"; exit 1; }
docker info >/dev/null 2>&1 || { echo "PHASE0: docker daemon not reachable — start OrbStack/Docker"; exit 1; }

echo "== build Operator image (host arch) =="
docker build -f templates/docker/Dockerfile.operator -t "$IMG" . || { echo "PHASE0: build FAILED"; exit 1; }

# The three gates whose verdict must be platform-invariant.
GATES=("bash scripts/count_check.sh" "bash scripts/selfcheck.sh" "bash templates/regression_guard.sh")

# Canonical terminal verdict per gate (the decisive summary line + exit code) — NOT a tail-window,
# which mis-fires when a gate (e.g. selfcheck) emits another gate's lines internally.
verdict_of() {
  local out="$1"
  local v e
  v=$(echo "$out" | grep -iE 'COUNT-CHECK: (PASS|FAIL)|SELFCHECK: (PASS|FAIL)|safe to merge|BLOCKED|M-tier blockers:' | tail -2 | tr '\n' ' ' | tr -s ' ')
  e=$(echo "$out" | grep -oE 'EXIT:[0-9]+' | tail -1)
  echo "${v}| ${e}"
}

pass=0; fail=0
for g in "${GATES[@]}"; do
  echo "== gate: $g =="
  host_out=$(eval "$g" 2>&1; echo "EXIT:$?")
  # mount the repo read-only into the container; gates only read.
  cont_out=$(docker run --rm -v "$REPO":/work/forge-harness:ro -w /work/forge-harness "$IMG" \
               -c "$g" 2>&1; echo "EXIT:$?")
  host_verdict=$(verdict_of "$host_out")
  cont_verdict=$(verdict_of "$cont_out")
  if [ "$host_verdict" = "$cont_verdict" ]; then
    echo "  ✅ IMMUTABLE — host == container"
    echo "$host_verdict" | sed 's/^/     /'
    pass=$((pass+1))
  else
    echo "  ❌ DRIFT — host != container (WOMBAT not closed for this gate)"
    echo "  --- host ---";      echo "$host_verdict" | sed 's/^/     /'
    echo "  --- container ---"; echo "$cont_verdict" | sed 's/^/     /'
    fail=$((fail+1))
  fi
done

echo "=================================================="
if [ "$fail" -eq 0 ]; then
  echo "PHASE 0 PASS — $pass/$pass gates immutable host↔container. Track 2 earns its place."
  echo "Next: commit Dockerfile+script (4-axis gate) → Phase 1 (headless dispatch in-container)."
  exit 0
else
  echo "PHASE 0 DRIFT — $fail gate(s) differ. Inspect the drift before committing the image."
  exit 1
fi
