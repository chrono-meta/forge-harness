#!/usr/bin/env bash
# cartridge_loader.sh — the SessionStart entry point for scripts/cartridge_loader.py.
# install-wizard registers FH hooks by their `scripts/<name>.sh` path (its merge keys on that form), so the hook
# calls this wrapper. It runs the loader without writing bytecode and always exits 0: a session start is never
# blocked, even when python3 is missing (one stderr line instead). The hook's stdin is passed through untouched.
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! command -v python3 >/dev/null 2>&1; then
  echo "[cartridge_loader] python3 not found — nothing injected" >&2
  exit 0
fi
python3 -B "$here/cartridge_loader.py"
exit 0
