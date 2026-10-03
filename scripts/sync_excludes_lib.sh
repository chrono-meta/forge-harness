#!/usr/bin/env bash
# sync_excludes_lib.sh — SOURCED by sync-to-be.sh and sync-from-be.sh. Defines one function.
#
# fh_load_sync_excludes FILE
#   Reads scripts/sync_excludes.txt (format in that file's header) into the array SYNC_EXCLUDES.
#   rc 0 = loaded (≥1 entry). rc 1 = refused; the reason is in FH_SYNC_EXCLUDES_ERR.
#   The CALLER picks its own exit code — the two scripts give exit codes different meanings
#   (sync-to-be's 10 is "not my hub" and its Stop hook stamps 10 as a quiet success, so a broken
#   list must not reuse it there).
#
# No eval, no sourcing of the list, no pipes: `while IFS= read -r`. The list is DATA.
# The allowed-character set is spelled out letter by letter on purpose: bracket RANGES (A-Z) and
# classes ([:alnum:]) follow the locale, so the same file could pass under one locale and fail
# under another (Hangul counts as alnum in a UTF-8 locale and not in C). An explicit set does not move.
# bash 3.2 compatible; safe under `set -euo pipefail` (no command here fails on the normal path).

_FH_SX_OK='abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._*-'

fh_load_sync_excludes() {
  local _f="$1" _line _e _b _n=0
  SYNC_EXCLUDES=()
  FH_SYNC_EXCLUDES_ERR=""
  if [ -z "$_f" ] || [ ! -f "$_f" ]; then
    FH_SYNC_EXCLUDES_ERR="exclusion list not found: ${_f:-<empty path>}"
    return 1
  fi
  if [ ! -r "$_f" ]; then
    FH_SYNC_EXCLUDES_ERR="exclusion list not readable: $_f"
    return 1
  fi
  # NUL bytes are refused BEFORE reading (2026-10-03 round 4, codex B). bash 3.2's `read` drops
  # everything after a NUL on that line, so `.pend<NUL>ing` would load as `.pend` — a valid-looking
  # entry that excludes nothing (measured: `.pending` leaked). Compare the byte count with NULs
  # removed; any difference = a NUL. If tr/wc are missing the counts differ or are empty → refuse.
  local _sz _sz_nonul
  _sz="$(wc -c < "$_f" 2>/dev/null | tr -d ' ')"
  _sz_nonul="$(LC_ALL=C tr -d '\000' < "$_f" 2>/dev/null | wc -c | tr -d ' ')"
  if [ -z "$_sz" ] || [ "$_sz" != "$_sz_nonul" ]; then
    FH_SYNC_EXCLUDES_ERR="exclusion list contains a NUL byte (or could not be measured): $_f"
    return 1
  fi
  while IFS= read -r _line || [ -n "$_line" ]; do
    _n=$((_n + 1))
    # trim leading / trailing whitespace (a CR from a CRLF file is whitespace → trimmed)
    _e="${_line#"${_line%%[![:space:]]*}"}"
    _e="${_e%"${_e##*[![:space:]]}"}"
    case "$_e" in
      '') continue ;;
      '#'*) continue ;;
    esac
    _b="${_e%/}"
    # `.` / `..` (and `./` `../`) name the current/parent directory — the tar fallback then archives
    # nothing (agy C). An entry of only `*` excludes every name. Both are refused as entries.
    case "$_b" in
      .|..) _b="" ;;     # force the refusal below
      *[!*]*) ;;         # has a character other than `*` → checked by the character set below
      *) _b="" ;;        # empty or only `*` → force the refusal below
    esac
    case "$_b" in
      ''|*[!$_FH_SX_OK]*)
        FH_SYNC_EXCLUDES_ERR="$_f:$_n: invalid entry «${_e}» (allowed: [A-Za-z0-9._*-]+ with at most one trailing /; not «.» «..» or only «*»; no inline comments)"
        SYNC_EXCLUDES=()
        return 1 ;;
    esac
    SYNC_EXCLUDES+=("$_e")
  done < "$_f"
  if [ "${#SYNC_EXCLUDES[@]}" -eq 0 ]; then
    FH_SYNC_EXCLUDES_ERR="exclusion list has no entries: $_f"
    return 1
  fi
  return 0
}
