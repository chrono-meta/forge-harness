#!/usr/bin/env bash
# session_ledger_write.sh — a work session appends ONE typed line to the shared session ledger.
#
#   session_ledger_write.sh --session <id> --task <slug> --kind board|note|landing --state <state>
#                           [--evidence "pr=#12 head=abc1234 path=scripts/x.sh"] [--text "<one line>"]
#
# WHY. The thin root session learns a child session's progress only from turn-end notices and SendMessage;
# after compaction it loses them and must re-read transcripts. The ledger is the durable channel: children
# write here, the root reads (session_ledger_read.py). SendMessage stays for «blocked» only.
# The ledger does NOT replace the root's source check — FH has no machine grader, so the root still opens
# the PR / file the evidence names. Evidence tokens exist so that check is mechanical.
#
# WHERE. Inside a git worktree the ledger belongs to the MAIN checkout (first `git worktree list` entry, same
# resolution as lease_line_apply.sh #1070), so a worktree session and the root see one file:
#   $HUB/tracks/_meta/session_ledger/ledger.tsv   (gitignored — tracks/**)    override: FH_SESSION_LEDGER
#
# FORMAT (TSV, append-only, one line per call):  ts  session  task  kind  state  evidence  text
# Closed state sets (free prose only in --text, never in state):
#   board   : planned · in_progress · blocked · done · abandoned
#   note    : info · finding · risk
#   landing : pr_open · merged · committed · file_written · unmeasured
# «unmeasured» is a state, not an absence: it says «I did not check», which a missing line cannot say.
# Evidence tokens (space separated): pr=#<n> · head=<7-40 hex> · commit=<7-40 hex> · path=<relative path>
#   · repo=<owner/name> · none=<reason>. board done / every landing state except unmeasured need at least one
#   of pr= head= commit= path=.
# Exit: 0 written · 2 usage / invalid value (nothing written) · 5 write failed
set -uo pipefail

usage() { sed -n '2,25p' "$0"; exit 2; }
die() { echo "REFUSED: $*" >&2; exit 2; }

session="" task="" kind="" state="" evidence="" text=""
while [ $# -gt 0 ]; do
  case "$1" in -h|--help) usage ;; esac
  [ $# -ge 2 ] || die "$1 needs a value"
  case "$1" in
    --session) session="${2:-}"; shift 2 ;;
    --task) task="${2:-}"; shift 2 ;;
    --kind) kind="${2:-}"; shift 2 ;;
    --state) state="${2:-}"; shift 2 ;;
    --evidence) evidence="${2:-}"; shift 2 ;;
    --text) text="${2:-}"; shift 2 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[ -n "$session" ] && [ -n "$task" ] && [ -n "$kind" ] && [ -n "$state" ] || usage
for v in "$session" "$task" "$kind" "$state" "$evidence" "$text"; do
  case "$v" in *[[:cntrl:]]*) die "control character (tab/newline/CR/...) in a value" ;; esac
done
[[ "$session" =~ ^[A-Za-z0-9._-]{1,80}$ ]] || die "session id must be [A-Za-z0-9._-]{1,80}"
[[ "$task" =~ ^[a-z0-9][a-z0-9._-]{0,63}$ ]] || die "task must be a lowercase slug"

case "$kind" in
  board)   allowed="planned in_progress blocked done abandoned" ;;
  note)    allowed="info finding risk" ;;
  landing) allowed="pr_open merged committed file_written unmeasured" ;;
  *) die "kind must be board|note|landing" ;;
esac
okstate=0; for a in $allowed; do [ "$state" = "$a" ] && okstate=1; done
[ "$okstate" -eq 1 ] || die "state '$state' not in {$allowed} for kind=$kind"

hard=0
set -f   # split on spaces, never glob-expand a token against the current directory
for tok in $evidence; do
  case "$tok" in
    pr=\#*)   [[ "$tok" =~ ^pr=#[0-9]+$ ]] || die "bad token: $tok"; hard=1 ;;
    head=*|commit=*) [[ "$tok" =~ ^(head|commit)=[0-9a-f]{7,40}$ ]] || die "bad token: $tok"; hard=1 ;;
    path=*)   p="${tok#path=}"; [ -n "$p" ] && [ "${p#/}" = "$p" ] || die "path must be relative: $tok"
              case "/$p/" in */../*) die "path must not contain ..: $tok" ;; esac; hard=1 ;;
    repo=*)   [[ "$tok" =~ ^repo=[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ ]] || die "bad token: $tok" ;;
    none=*)   [ -n "${tok#none=}" ] || die "none= needs a reason" ;;
    *) die "unknown evidence token: $tok (pr= head= commit= path= repo= none=)" ;;
  esac
done
set +f
need=0
[ "$kind" = board ] && [ "$state" = done ] && need=1
[ "$kind" = landing ] && [ "$state" != unmeasured ] && need=1
[ "$need" -eq 1 ] && [ "$hard" -eq 0 ] && die "$kind/$state needs evidence: pr= head= commit= or path="

if [ -n "${FH_SESSION_LEDGER:-}" ]; then
  LEDGER="$FH_SESSION_LEDGER"
else
  HUB="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
  _wl="$(git -C "$HUB" worktree list --porcelain 2>/dev/null)" || _wl=""
  _main="$(printf '%s\n' "$_wl" | sed -n '1s/^worktree //p')"
  printf '%s\n' "$_wl" | sed -n '2p' | grep -qx bare || { [ -n "$_main" ] && [ -e "$_main/.git" ] && HUB="$_main"; }
  LEDGER="$HUB/tracks/_meta/session_ledger/ledger.tsv"
fi

mkdir -p "$(dirname "$LEDGER")" || exit 5
ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
line="$(printf '%s\t%s\t%s\t%s\t%s\t%s\t%s' "$ts" "$session" "$task" "$kind" "$state" "$evidence" "$text")"
# ≤ 500 bytes so the append is a single write() (PIPE_BUF-sized) — longer lines could interleave with a peer
[ "$(printf '%s\n' "$line" | wc -c)" -le 500 ] || die "line over 500 bytes — shorten --text/--evidence (point to a file with path=)"
# one write() of a short line to an O_APPEND file: concurrent writers do not interleave within it
printf '%s\n' "$line" >> "$LEDGER" || exit 5
echo "ledger: $LEDGER"
echo "wrote: $line"
