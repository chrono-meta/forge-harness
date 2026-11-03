#!/usr/bin/env bash
# card_status_tags.sh — ⑤-S: does every «다음에 볼 것» item in the newest session-card block carry
# exactly one status tag? ADVISORY: never blocks, never changes a close verdict.
#
# Why (2026-11-03, borrowed from pstack's recall tags): card items are free prose, and the next
# session has to re-derive each item's state — «merged» read as «open PR», a verified-but-uncommitted
# fix read as done. A one-word tag makes the state a typed property of the record (present · from a
# closed set), which is what a check may assert; whether the tag is TRUE stays judgment.
#
# Tag set (closed): merged · open-pr · in-flight · uncommitted · reverted · planned · operator · held
# Item form:        "N. [tag] text"   (the tag is the first thing after "N. ")
#
# usage: card_status_tags.sh [card]   (default: tracks/_meta/reference_next_session_starter.md)
# exit:  0 = measured (tagged or not — advisory) · 3 = NOT MEASURED (no card / no section)
set -u
FH="$(cd "$(dirname "$0")/.." && pwd)"
CARD="${1:-$FH/tracks/_meta/reference_next_session_starter.md}"
TAGS='merged|open-pr|in-flight|uncommitted|reverted|planned|operator|held'

if [ ! -f "$CARD" ]; then
  echo "⬜ ⑤-S status tags NOT MEASURED — card not found"
  exit 3
fi

# Newest block = from line 1 to the first «---» line; the section = «## 🌅» up to the next «## ».
section=$(awk '/^---[[:space:]]*$/ {exit} /^## / {insec = ($0 ~ /^## 🌅/); next} insec' "$CARD")
if ! awk '/^---[[:space:]]*$/ {exit} /^## 🌅/ {f=1} END {exit !f}' "$CARD"; then
  echo "⬜ ⑤-S status tags NOT MEASURED — newest card block has no «## 🌅» section"
  exit 3
fi

items=$(printf '%s\n' "$section" | grep -E '^[0-9]+\. ' || true)
total=$(printf '%s\n' "$items" | grep -c -E '^[0-9]+\. ' || true)
if [ "$total" -eq 0 ]; then
  # An empty set is not «all tagged» — say it is empty.
  echo "⬜ ⑤-S status tags: 0 items in «🌅» — nothing to check (not a pass)"
  exit 0
fi
good=$(printf '%s\n' "$items" | grep -c -E "^[0-9]+\. \[($TAGS)\] " || true)
bad=$((total - good))
if [ "$bad" -eq 0 ]; then
  echo "✅ ⑤-S status tags: $good/$total «🌅» items tagged"
else
  echo "⚠️  ⑤-S status tags: $bad/$total «🌅» items lack a tag from [$TAGS] (advisory)"
  printf '%s\n' "$items" | grep -v -E "^[0-9]+\. \[($TAGS)\] " | cut -c1-90 | sed 's/^/     ↳ /'
fi
exit 0
