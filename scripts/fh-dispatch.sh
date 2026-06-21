#!/usr/bin/env bash
# FH headless dispatch → Operator Container (Phase 1a).
# The governor (interactive CC session) stays on the HOST (option 1); this is the bridge that
# routes a HEADLESS job (codex exec, gate runs, file work) into the reproducible fh-operator image.
# Stateless container, stateful mounts — the container dies after each job; code/data/auth live on
# the host and are bind-mounted in. AUTH is runtime-mounted, never baked into the image.
#
# Usage:
#   scripts/fh-dispatch.sh codex exec --skip-git-repo-check "your prompt"
#   scripts/fh-dispatch.sh 'bash scripts/count_check.sh'      # any headless command
#
# Boundary (do NOT dispatch here — host-bound): agy -p (Mach-O native), live-surface
# (claude-in-chrome / computer-use / Playwright-display), and quench/sim Agent-tool dispatches.
set -uo pipefail
IMG="fh-operator:latest"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Optional companion store: mounted only when BE_DIR is exported (set it in your local env,
# e.g. CLAUDE.local.md / a private env file). No default path is baked in — keeps this public
# script free of any operator-specific companion-store name or home path.
BE="${BE_DIR:-}"

command -v docker >/dev/null 2>&1 || { echo "fh-dispatch: docker not found — install/start OrbStack"; exit 1; }
docker image inspect "$IMG" >/dev/null 2>&1 || {
  echo "fh-dispatch: image $IMG missing — build it:"
  echo "  docker build -f templates/docker/Dockerfile.operator -t $IMG ."
  exit 1
}

# Compose the command from args (passed to the bash entrypoint as a single -c string).
CMD="$*"
[ -n "$CMD" ] || { echo "fh-dispatch: no command given"; exit 2; }

# Mounts: code+gates+hooks (rw — gates/manifest write), codex auth (rw — codex writes session
# state under ~/.codex), companion store (rw, only if BE_DIR set). Add more auth (~/.config/gh,
# ~/.npmrc) as Phase 1 grows.
BE_MOUNT=()
[ -n "$BE" ] && BE_MOUNT=(-v "$BE":/work/companion-store)
# Empty-array expansion is written bash-3.2-safe (macOS host bash + set -u): the
# ${arr[@]+"${arr[@]}"} form expands to nothing when unset instead of erroring.
docker run --rm \
  -v "$REPO":/work/forge-harness \
  -v "$HOME/.codex":/root/.codex \
  ${BE_MOUNT[@]+"${BE_MOUNT[@]}"} \
  -w /work/forge-harness \
  "$IMG" -c "$CMD"
