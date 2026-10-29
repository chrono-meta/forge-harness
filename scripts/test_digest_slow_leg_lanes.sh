#!/usr/bin/env bash
# test_digest_slow_leg_lanes.sh — digest_slow_leg.py known-pair (thin wrapper; lanes live in the python).
#   RSS + Atom listed then 0 new · missing feed = UNREACHABLE (never 0) · empty feed = PARSE-ZERO
#   · first sighting seeds instead of dumping · youtube RSS dead -> yt-dlp names its transport
#   · both youtube transports dead -> UNREACHABLE · invalid source kind rejected. Offline (file:// + stubs).
# exit: 0 all lanes PASS · 1 a lane failed · 10 harness error (python3 absent)
set -uo pipefail
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
command -v python3 >/dev/null 2>&1 || {
  echo "harness error: python3 absent -- cannot measure. Not a pass." >&2; exit 10; }
python3 "$SRC/digest_slow_leg.py" --self-test
