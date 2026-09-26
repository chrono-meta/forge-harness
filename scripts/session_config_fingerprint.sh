#!/usr/bin/env bash
# session_config_fingerprint.sh — snapshot the session's config files at start, compare at close.
#
# WHY (2026-09-26, measured on this repo): a sub-agent's measurement run (empty work-dir path →
# `cd "" ` succeeded in place) overwrote this checkout's
# .claude/settings.json and CLAUDE.md mid-session, and FH did not notice. The settings file is
# gitignored (no `git status`, no `git checkout` undo), and the only existing guard —
# sim_isolated_run.sh — compares ~/.claude/settings.json mtime around ITS OWN runs, nothing else.
# So a silent config rewrite by anything else in the session had no detector at all.
#
# WHAT: `snap` records sha256 + mtime of six files (below) into a gitignored snapshot with the
# session id. `compare` recomputes and NAMES every file that changed. It is ADVISORY by design —
# a session may legitimately change its own settings — so it never blocks; it makes a change
# visible, and says where the recovery procedure lives.
#
# Files: <FH>/.claude/settings.json · <FH>/.claude/settings.local.json · <FH>/CLAUDE.local.md ·
#        <FH>/CLAUDE.md (tracked, but an overwrite target on 2026-09-26) ·
#        <HOME>/.claude/settings.json · <HOME>/.claude/CLAUDE.md
#
# 🟥 No snapshot → NOT MEASURED, never «no change». A compare against nothing is not a zero.
# READ-ONLY on every file it fingerprints; writes only its own snapshot file.
#
# Usage:
#   bash scripts/session_config_fingerprint.sh snap    [--fh DIR] [--home DIR] [--out FILE] [--source SRC]
#   bash scripts/session_config_fingerprint.sh compare [--fh DIR] [--home DIR] [--out FILE]
#   --source clear|compact keeps an existing snapshot of the SAME session (a /clear or compaction
#   is the same session continuing — re-snapping there would erase the evidence).
#   Exit (compare): 0 unchanged · 1 changed (advisory) · 3 NOT MEASURED · 2 usage
#   Exit (snap):    0 written or kept · 3 could not write · 2 usage
set -uo pipefail

MODE="${1:-}"; shift 2>/dev/null || true
FH="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
H="${HOME:-}"
OUT=""
SRC="unknown"
while [ $# -gt 0 ]; do
  case "$1" in
    --fh)     [ -n "${2:-}" ] || { echo "usage: --fh needs a path" >&2; exit 2; }; FH="$2"; shift 2 ;;
    --home)   [ -n "${2:-}" ] || { echo "usage: --home needs a path" >&2; exit 2; }; H="$2"; shift 2 ;;
    --out)    [ -n "${2:-}" ] || { echo "usage: --out needs a path" >&2; exit 2; }; OUT="$2"; shift 2 ;;
    --source) SRC="${2:-unknown}"; shift 2 ;;
    *) echo "usage: unknown argument: $1" >&2; exit 2 ;;
  esac
done
[ -n "$OUT" ] || OUT="$FH/tracks/_meta/.session_config_fingerprint"
SID="${CLAUDE_CODE_SESSION_ID:-pid-${PPID:-$$}}"

_mtime() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo "?"; }
_hash() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" 2>/dev/null | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" 2>/dev/null | awk '{print $1}'
  else cksum "$1" 2>/dev/null | awk '{print "cksum-"$1"-"$2}'; fi
}
# label<TAB>path — labels are what the report prints, so they never carry an absolute home path.
_targets() {
  printf 'repo:.claude/settings.json\t%s\n'       "$FH/.claude/settings.json"
  printf 'repo:.claude/settings.local.json\t%s\n' "$FH/.claude/settings.local.json"
  printf 'repo:CLAUDE.local.md\t%s\n'             "$FH/CLAUDE.local.md"
  printf 'repo:CLAUDE.md\t%s\n'                   "$FH/CLAUDE.md"
  printf 'home:~/.claude/settings.json\t%s\n'     "$H/.claude/settings.json"
  printf 'home:~/.claude/CLAUDE.md\t%s\n'         "$H/.claude/CLAUDE.md"
}
# one line per target: label<TAB>state<TAB>hash<TAB>mtime   (state PRESENT|ABSENT|UNREADABLE)
_measure() {
  _targets | while IFS="$(printf '\t')" read -r label path; do
    if [ ! -e "$path" ]; then printf '%s\tABSENT\t-\t-\n' "$label"
    elif [ ! -r "$path" ]; then printf '%s\tUNREADABLE\t-\t-\n' "$label"
    else
      h="$(_hash "$path")"
      if [ -n "$h" ]; then printf '%s\tPRESENT\t%s\t%s\n' "$label" "$h" "$(_mtime "$path")"
      else printf '%s\tUNREADABLE\t-\t-\n' "$label"; fi
    fi
  done
}

case "$MODE" in
  snap)
    if [ -f "$OUT" ]; then
      prev_sid="$(sed -n '/^session=/{s/^session=//p;q;}' "$OUT" 2>/dev/null)"
      case "$SRC" in
        clear|compact) if [ "$prev_sid" = "$SID" ]; then exit 0; fi ;;
      esac
    fi
    mkdir -p "$(dirname "$OUT")" 2>/dev/null
    tmp="$OUT.tmp.$$"
    { printf 'session=%s\nat=%s\nsource=%s\n' "$SID" "$(date +%s)" "$SRC"; _measure; } > "$tmp" 2>/dev/null \
      && mv "$tmp" "$OUT" 2>/dev/null && exit 0
    rm -f "$tmp" 2>/dev/null; exit 3 ;;
  compare)
    if [ ! -r "$OUT" ]; then
      echo "⚠️  config fingerprint NOT MEASURED — no session-start snapshot ($(basename "$OUT"))."
      echo "     No snapshot is not «no change». The snap runs from scripts/fh_session_load.sh at SessionStart."
      exit 3
    fi
    snap_sid="$(sed -n '/^session=/{s/^session=//p;q;}' "$OUT")"
    now="$(_measure)"
    changed=""; n=0; touched=""
    while IFS="$(printf '\t')" read -r label state hash mt; do
      [ -n "$label" ] || continue
      old="$(awk -F'\t' -v l="$label" '$1==l {print $2"\t"$3"\t"$4; exit}' "$OUT")"
      if [ -z "$old" ]; then changed="$changed
     ↳ $label — not in snapshot (NOT MEASURED)"; n=$((n+1)); continue; fi
      old_state="${old%%	*}"; _rest="${old#*	}"; old_hash="${_rest%%	*}"; old_mt="${_rest#*	}"
      if [ "$state" = UNREADABLE ] || [ "$old_state" = UNREADABLE ]; then
        changed="$changed
     ↳ $label — unreadable now or at start (NOT MEASURED)"; n=$((n+1))
      elif [ "$state" != "$old_state" ]; then
        changed="$changed
     ↳ $label — $old_state → $state"; n=$((n+1))
      elif [ "$hash" != "$old_hash" ]; then
        changed="$changed
     ↳ $label — content changed"; n=$((n+1))
      elif [ "$state" = PRESENT ] && [ "$mt" != "$old_mt" ]; then
        # 🟥 2026-09-26 (cross-family): mtime was snapped and never compared. Decision: the content
        # hash is the verdict (a rewrite with identical bytes restores nothing and loses nothing),
        # but a touch is still a sign something wrote there — so it is REPORTED separately and
        # NOT counted as a change. Folding it into «changed» would cry wolf on every editor save;
        # dropping it would hide the one trace a same-bytes rewrite leaves.
        touched="$touched
     ↳ $label — touched (내용 동일, mtime only)"
      fi
    done <<EOF_NOW
$now
EOF_NOW
    note=""
    [ "$snap_sid" = "$SID" ] || note=" (snapshot belongs to session $snap_sid, not this one — baseline may be older)"
    if [ "$n" -eq 0 ]; then
      echo "✅ config fingerprint: none of the 6 config files changed since session start$note"
      [ -z "$touched" ] || echo "     ⓘ written without content change (advisory, not counted):$touched"
      exit 0
    fi
    echo "⚠️  config fingerprint: $n config file(s) changed since session start$note$changed"
    [ -z "$touched" ] || echo "     ⓘ written without content change (advisory, not counted):$touched"
    echo "     Intended change → ignore. Not yours → back it up now and recover per"
    echo "     knowledge/shared/harness-core/checkout_layer_drift.md §Config-Overwrite-Recovery"
    exit 1 ;;
  *) sed -n '2,30p' "$0"; exit 2 ;;
esac
