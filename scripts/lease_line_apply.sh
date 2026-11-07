#!/usr/bin/env bash
# lease_line_apply.sh — the lease-record channel: a session DRAFTS a lease line, the operator APPLIES it.
#
#   draft  --block "<header text>" --line "<utterance line>" [--why "<question it answers>"]
#          → writes tracks/_meta/lease_drafts/<stamp>.lease  (sessions may run this; it touches no lease)
#   check  <draft>   → read-only: prints the target block and the exact line it would insert, rc 0/4
#   apply  <draft>   → OPERATOR ONLY: shows the diff, asks for a typed confirmation code on the terminal,
#                      then inserts the line just before the block's «제외» line (a timestamped backup first)
#
# WHY (AQ-20261107-11, brief §G3). On 2026-11-07 the auto-mode classifier refused a session's own write of
# a lease line into CLAUDE.local.md twice. It was right to: a session writing the record of its own
# permission is the self-report residual that file already names. So the record moves to a channel the
# session can prepare but not complete — the operator types the confirmation.
#
# WHAT «OPERATOR ONLY» MEANS HERE — and what it does not. `apply` refuses when CLAUDECODE is set (every
# Claude Code shell sets it) and when there is no terminal to read the code from. 🟥 Named residual: both are
# evadable by an agent that unsets the variable and fakes a terminal (e.g. `script`). The closing direction
# is outside this file: a permission DENY rule for `Bash(*lease_line_apply.sh apply*)` in the operator's
# settings, and later a FoD card (real OS input). This script makes the honest path the easy one; it is
# not a lock. It never edits anything but the lease file, and never without the backup.
# Named residual: the lease is re-hashed right before the atomic replace, but an editor that writes in
# the few milliseconds between that check and os.replace() is overwritten — nothing here holds a lock
# other writers honour (macOS ships no flock CLI, and an editor would not take it).
#
# Env: FH_LEASE_FILE (default $HUB/CLAUDE.local.md) · FH_LEASE_DRAFT_DIR (default $HUB/tracks/_meta/lease_drafts)
# Exit: 0 ok · 2 usage · 3 refused (agent shell / no terminal / wrong code) · 4 target block or «제외» line
#       not found, or the line is already there · 5 write failed (lease restored from backup)
set -uo pipefail

HUB="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || echo "$HOME/projects/forge-harness")}"
LEASE="${FH_LEASE_FILE:-$HUB/CLAUDE.local.md}"
DDIR="${FH_LEASE_DRAFT_DIR:-$HUB/tracks/_meta/lease_drafts}"
cmd="${1:-}"; shift || true

usage() { sed -n '2,8p' "$0"; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "HARNESS-ERROR: python3 missing"; exit 2; }

# plan <draft> → prints «LINE<TAB>N» where N is the 1-based line to insert before, or an error and rc 4
plan() {
  python3 - "$LEASE" "$1" <<'PY'
import sys
lease, draft = sys.argv[1], sys.argv[2]
import re
BAD = re.compile(r"[\t\r\v\f\x1c-\x1e\x85\u2028\u2029]")
d = {}
try:
    raw = open(draft, encoding="utf-8", newline="").read()   # no universal newlines: a CR must stay visible
except Exception as e:
    print(f"ERROR: cannot read draft ({e})"); sys.exit(4)
for ln in raw.split("\n"):
    if not ln:
        continue
    k, _, v = ln.partition(": ")
    if k not in ("block", "line", "why"):
        print(f"ERROR: unknown draft key «{k[:20]}»"); sys.exit(4)
    if k in d:
        print(f"ERROR: duplicate draft key «{k}»"); sys.exit(4)
    if BAD.search(v):
        print(f"ERROR: «{k}» holds a tab or a line separator"); sys.exit(4)
    d[k] = v
if not d.get("block") or not d.get("line"):
    print("ERROR: draft needs «block: …» and «line: …»"); sys.exit(4)
try:
    lines = open(lease, encoding="utf-8", newline="").read().split("\n")   # same parsing as the write step
except Exception as e:
    print(f"ERROR: cannot read lease file ({e})"); sys.exit(4)
heads = [i for i, l in enumerate(lines) if l.startswith("## ") and d["block"] in l]
if len(heads) != 1:
    print(f"ERROR: block header containing «{d['block']}» matched {len(heads)} times (need exactly 1)"); sys.exit(4)
h = heads[0]
end = next((i for i in range(h + 1, len(lines)) if lines[i].startswith("## ")), len(lines))
excl = [i for i in range(h + 1, end) if lines[i].startswith("제외")]
if len(excl) != 1:
    print(f"ERROR: «제외» line inside that block matched {len(excl)} times (need exactly 1)"); sys.exit(4)
text = d["line"].strip()
if not text.startswith("추가 utterance"):
    print("ERROR: line must start with «추가 utterance»"); sys.exit(4)
new = " " * 12 + text
if any(l.strip() == text for l in lines[h:end]):
    print("ERROR: that line is already in the block"); sys.exit(4)
print(lines[h])
print(f"insert before L{excl[0] + 1}: {lines[excl[0]][:60]}")
print(f"+ {new}")
print(f"PLAN\t{excl[0] + 1}\t{new}")
PY
}

case "$cmd" in
  draft)
    block=""; line=""; why=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --block) [ $# -ge 2 ] || usage; block="$2"; shift 2 ;;
        --line)  [ $# -ge 2 ] || usage; line="$2"; shift 2 ;;
        --why)   [ $# -ge 2 ] || usage; why="$2"; shift 2 ;;
        *) usage ;;
      esac
    done
    [ -n "$block" ] && [ -n "$line" ] || usage
    if printf '%s' "$block$line$why" | LC_ALL=C grep -q $'[\t\r\v\f]'; then
      echo "ERROR: no tabs or carriage returns in draft fields"; exit 2; fi
    case "$block$line$why" in *$'\n'*) echo "ERROR: one line each, no newlines"; exit 2 ;; esac
    mkdir -p "$DDIR" || exit 5
    f="$DDIR/$(date +%Y%m%dT%H%M%S)_$$.lease"
    printf 'block: %s\nline: %s\nwhy: %s\n' "$block" "$line" "$why" > "$f" || exit 5
    echo "draft written: $f"
    echo "operator, in your own terminal:  bash scripts/lease_line_apply.sh apply \"$f\""
    exit 0 ;;
  check)
    [ -f "${1:-}" ] || usage
    out="$(plan "$1")"; rc=$?
    printf '%s\n' "$out" | grep -v $'^PLAN\t'
    exit "$rc" ;;
  apply)
    [ -f "${1:-}" ] || usage
    if [ -n "${CLAUDECODE+x}" ]; then
      echo "REFUSED: this is an agent shell (CLAUDECODE is set). The session drafts; the operator applies"
      echo "         from their own terminal. See the header for what this check does and does not prove."
      exit 3
    fi
    if ! { exec 3<>/dev/tty; } 2>/dev/null; then
      echo "REFUSED: no terminal to read the confirmation code from"; exit 3
    fi
    snap="$(shasum -a 256 "$LEASE" 2>/dev/null | cut -c1-64)"
    out="$(plan "$1")"; rc=$?
    printf '%s\n' "$out" | grep -v $'^PLAN\t'
    [ "$rc" -eq 0 ] || exit "$rc"
    at="$(printf '%s\n' "$out" | awk -F'\t' '$1=="PLAN"{print $2}')"
    new="$(printf '%s\n' "$out" | awk -F'\t' '$1=="PLAN"{print $3}')"
    code="$(printf '%s' "$new" | shasum -a 256 | cut -c1-4)"
    printf 'Type %s to write this line into %s: ' "$code" "$LEASE" >&3
    IFS= read -r typed <&3; typed="${typed%$'\r'}"
    exec 3<&-
    [ "$typed" = "$code" ] || { echo "REFUSED: code did not match — nothing written"; exit 3; }
    # the file must still be the one that was planned against (no edit while the prompt was open)
    now="$(shasum -a 256 "$LEASE" 2>/dev/null | cut -c1-64)"
    [ -n "$snap" ] && [ "$snap" = "$now" ] || { echo "REFUSED: the lease file changed while waiting — run apply again"; exit 3; }
    bak="$(mktemp "$LEASE.bak.$(date +%Y%m%dT%H%M%S).XXXXXX")" && cp -p "$LEASE" "$bak" \
      || { echo "ERROR: backup failed — nothing written"; exit 5; }
    # write a sibling temp file, then replace atomically: a failure leaves the lease untouched
    if ! python3 - "$LEASE" "$at" "$new" "$snap" <<'PY'
import hashlib, os, sys, tempfile
p, at, new, snap = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4]
data = open(p, "rb").read()
if hashlib.sha256(data).hexdigest() != snap:
    sys.exit(1)
lines = data.decode("utf-8").split("\n")
lines.insert(at - 1, new)
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(os.path.abspath(p)), prefix=".lease.")
try:
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    os.chmod(tmp, os.stat(p).st_mode & 0o7777)
    os.replace(tmp, p)
except Exception:
    try: os.unlink(tmp)
    except OSError: pass
    raise
PY
    then echo "ERROR: write failed — the lease file was not replaced (backup $bak)"; exit 5; fi
    echo "written at L$at · backup $bak"
    exit 0 ;;
  *) usage ;;
esac
