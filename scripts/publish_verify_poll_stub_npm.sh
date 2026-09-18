#!/usr/bin/env bash
# publish_verify_poll_stub_npm.sh — realistic stand-in for `npm view <pkg>@<version> version`.
#
# Shape pulled from the real artifact, not a mental model: a version that is not yet visible on
# the registry produces EMPTY STDOUT + NONZERO EXIT (this is the documented real shape — the
# original publish.yml comment names it exactly: E404 "No match found for version 3.1.0"). This
# stub reproduces that shape rather than the easier-to-fake "prints a different version number"
# shape, because `npm view name@EXACT_VERSION` targets one exact version, not "latest" — so a
# not-yet-propagated version 404s, it does not resolve to a stale different version.
#
# Env:
#   STUB_TARGET_VERSION       the version that eventually becomes visible
#   STUB_CALLS_UNTIL_VISIBLE  1-based call count at which it starts succeeding (default 1 = always)
#   STUB_COUNTER_FILE         path to a persistent counter (required — subprocess-per-call)
set -euo pipefail
: "${STUB_TARGET_VERSION:?STUB_TARGET_VERSION required}"
: "${STUB_COUNTER_FILE:?STUB_COUNTER_FILE required}"
threshold="${STUB_CALLS_UNTIL_VISIBLE:-1}"

if [ ! -f "$STUB_COUNTER_FILE" ]; then echo 0 > "$STUB_COUNTER_FILE"; fi
n=$(cat "$STUB_COUNTER_FILE")
n=$((n + 1))
echo "$n" > "$STUB_COUNTER_FILE"

# args: view <pkg>@<version> version
if [ "$n" -ge "$threshold" ]; then
  echo "$STUB_TARGET_VERSION"
  exit 0
else
  # real npm view on an absent exact version: empty stdout, error text on stderr, exit 1
  echo "npm ERR! code E404" >&2
  exit 1
fi
