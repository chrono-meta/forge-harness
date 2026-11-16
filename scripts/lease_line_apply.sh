#!/usr/bin/env bash
# lease_line_apply.sh — the lease-record channel: a session DRAFTS a lease line, the operator APPLIES it.
#
#   draft  --block "<header text>" --line "<utterance line>" [--why "<question it answers>"]
#          → writes tracks/_meta/lease_drafts/<stamp>.lease  (sessions may run this; it touches no lease)
#   check  <draft>   → read-only: prints the target block and the exact line it would insert, rc 0/4
#   apply  <draft>   → OPERATOR ONLY: shows the diff, asks for a typed confirmation code on the terminal,
#                      then inserts the line just before the block's «제외» line (a timestamped backup first)
#   apply-all        → OPERATOR ONLY: every queued draft in the draft dir at once — shows each (add · already
#                      there · skipped and why), ONE code for the whole batch, one backup, one atomic replace.
#                      Applied drafts (and «already there» ones) move to <draft dir>/applied/; skipped stay queued.
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
# Inside a git worktree the lease and the draft queue still belong to the MAIN checkout: a session working in
# a worktree would otherwise draft into the worktree's copy, and apply-all run from the hub would never see it
# (measured 2026-11-10). The main checkout is the FIRST entry of `git worktree list` — not «the parent of .git»,
# which misses submodule and --separate-git-dir layouts (codex). A bare main entry has no checkout: keep HUB.
_wl="$(git -C "$HUB" worktree list --porcelain 2>/dev/null)" || _wl=""
_main=""; _bare=0
while IFS= read -r _l; do
  [ -z "$_l" ] && break
  case "$_l" in "worktree "*) _main="${_l#worktree }" ;; bare) _bare=1 ;; esac
done <<EOF_WL
$_wl
EOF_WL
# only a real checkout (it holds a «.git» entry): with --separate-git-dir git reports the metadata dir as the
# main entry from a linked worktree, and writing a lease there would be worse than staying put (named residual)
[ -n "$_main" ] && [ "$_bare" -eq 0 ] && [ -e "$_main/.git" ] && HUB="$_main"
LEASE="${FH_LEASE_FILE:-$HUB/CLAUDE.local.md}"
DDIR="${FH_LEASE_DRAFT_DIR:-$HUB/tracks/_meta/lease_drafts}"
cmd="${1:-}"; shift || true

usage() { sed -n '2,11p' "$0"; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "HARNESS-ERROR: python3 missing"; exit 2; }

# planpy one  <lease> <draft>                       → prints «PLAN<TAB>N<TAB>line» or an error and rc 4
# planpy many <lease> <snap|-> <code|-> <draft>...  → one plan over the whole batch, each draft against the lease
#   AS CHANGED BY the drafts before it (two drafts for one block both land, in order). Per draft: ADD (would insert)
#   · DONE (its line is already there — counts as applied) · SKIP (malformed / block not found — left in place).
#   Prints «CODE<TAB>xxxx» over the batch. With snap and code given it WRITES: re-hash, recompute, the code must
#   still match, then one atomic replace. One parser for both modes (two copies would drift apart).
planpy() {
  python3 - "$@" <<'PY'
import hashlib, os, re, sys, tempfile
mode = sys.argv[1]
BAD = re.compile(r"[\t\r\v\f\x1c-\x1e\x85  ]")

class Bad(Exception):
    pass

SEEN = {}   # draft path → sha256 of the exact bytes parsed (the batch moves a draft only if it is still these bytes)

def parse(draft):
    d = {}
    try:
        b = open(draft, "rb").read()
        SEEN[draft] = hashlib.sha256(b).hexdigest()
        raw = b.decode("utf-8")   # no universal newlines: a CR must stay visible
    except Exception as e:
        raise Bad(f"cannot read draft ({e})")
    for ln in raw.split("\n"):
        if not ln:
            continue
        k, _, v = ln.partition(": ")
        if k not in ("block", "line", "why"):
            raise Bad(f"unknown draft key «{k[:20]}»")
        if k in d:
            raise Bad(f"duplicate draft key «{k}»")
        if BAD.search(v):
            raise Bad(f"«{k}» holds a tab or a line separator")
        d[k] = v
    if not d.get("block") or not d.get("line"):
        raise Bad("draft needs «block: …» and «line: …»")
    return d

def place(lines, d):
    """→ (header index, insert index, new line); insert index None when the line is already there."""
    heads = [i for i, l in enumerate(lines) if l.startswith("## ") and d["block"] in l]
    if len(heads) != 1:
        raise Bad(f"block header containing «{d['block']}» matched {len(heads)} times (need exactly 1)")
    h = heads[0]
    end = next((i for i in range(h + 1, len(lines)) if lines[i].startswith("## ")), len(lines))
    excl = [i for i in range(h + 1, end) if lines[i].startswith("제외")]
    if len(excl) != 1:
        raise Bad(f"«제외» line inside that block matched {len(excl)} times (need exactly 1)")
    text = d["line"].strip()
    if not text.startswith("추가 utterance"):
        raise Bad("line must start with «추가 utterance»")
    if any(l.strip() == text for l in lines[h:end]):
        return h, None, text
    return h, excl[0], " " * 12 + text

def read_lease(p):
    data = open(p, "rb").read()
    return data, data.decode("utf-8").split("\n")   # same parsing as the write step

if mode == "one":
    lease, draft = sys.argv[2], sys.argv[3]
    try:
        d = parse(draft)
        try:
            _, lines = read_lease(lease)
        except Exception as e:
            raise Bad(f"cannot read lease file ({e})")
        h, at, new = place(lines, d)
        if at is None:
            raise Bad("that line is already in the block")
    except Bad as e:
        print(f"ERROR: {e}"); sys.exit(4)
    print(lines[h])
    print(f"insert before L{at + 1}: {lines[at][:60]}")
    print(f"+ {new}")
    print(f"PLAN\t{at + 1}\t{new}")
    sys.exit(0)

lease, snap, want = sys.argv[2], sys.argv[3], sys.argv[4]
drafts = sys.argv[5:]
try:
    data, lines = read_lease(lease)
except Exception as e:
    print(f"ERROR: cannot read lease file ({e})"); sys.exit(4)
if snap != "-" and hashlib.sha256(data).hexdigest() != snap:
    print("ERROR: the lease file changed since it was planned"); sys.exit(3)
added, done = [], []
for dr in drafts:
    name = os.path.basename(dr)
    try:
        d = parse(dr)
        h, at, new = place(lines, d)
    except Bad as e:
        print(f"SKIP\t{name}\t{e}"); continue
    if at is None:
        done.append(f"{name}\t{lines[h]}\t{new}"); print(f"DONE\t{name}\t{new}"); continue
    print(f"ADD\t{name}\t{lines[h][:50]}\t{new}")
    added.append(f"{name}\t{lines[h]}\tL{at + 1}\t{new}")   # the code covers WHERE, not only what
    lines.insert(at, new)
if not added and not done:
    print("NOTHING"); sys.exit(4)
batch = "\n".join(added) + "\n--\n" + "\n".join(done)
code = hashlib.sha256(batch.encode("utf-8")).hexdigest()[:4]
print(f"CODE\t{code}")
if want == "-":
    sys.exit(0)
if want != code:
    print("ERROR: the batch changed since the code was shown"); sys.exit(3)
if added:
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(os.path.abspath(lease)), prefix=".lease.")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write("\n".join(lines))
        os.chmod(tmp, os.stat(lease).st_mode & 0o7777)
        if hashlib.sha256(open(lease, "rb").read()).hexdigest() != snap:   # last re-hash before the replace
            os.unlink(tmp); print("ERROR: the lease file changed while writing"); sys.exit(3)
        os.replace(tmp, lease)
    except SystemExit:
        raise
    except Exception as e:
        try: os.unlink(tmp)
        except OSError: pass
        print(f"ERROR: write failed ({e})"); sys.exit(5)
for dr in drafts:
    nm = os.path.basename(dr)
    if any(x == nm or x.startswith(nm + "\t") for x in done) or any(x.startswith(nm + "\t") for x in added):
        print(f"MOVE\t{nm}\t{SEEN.get(dr, '')}")
print("WROTE")
PY
}

# refuse an agent shell and a run with no terminal; on success fd 3 is the terminal
operator_gate() {
  if [ -n "${CLAUDECODE+x}" ]; then
    echo "REFUSED: this is an agent shell (CLAUDECODE is set). The session drafts; the operator applies"
    echo "         from their own terminal. See the header for what this check does and does not prove."
    exit 3
  fi
  if ! { exec 3<>/dev/tty; } 2>/dev/null; then
    echo "REFUSED: no terminal to read the confirmation code from"; exit 3
  fi
}
# an applied draft moves to applied/ so apply-all does not offer it again (a failed move is said, not fatal:
# next time the draft shows as «already in the lease» and moves then)
mark_applied() {
  case "$1" in "$DDIR"/*) ;; *) return 0 ;; esac
  mkdir -p "$DDIR/applied" && mv "$1" "$DDIR/applied/" 2>/dev/null \
    || echo "note: could not move $1 to $DDIR/applied/ — it will show as already applied next time"
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
    out="$(planpy one "$LEASE" "$1")"; rc=$?
    printf '%s\n' "$out" | grep -v $'^PLAN\t'
    exit "$rc" ;;
  apply)
    [ -f "${1:-}" ] || usage
    operator_gate
    snap="$(shasum -a 256 "$LEASE" 2>/dev/null | cut -c1-64)"
    dsnap="$(shasum -a 256 "$1" 2>/dev/null | cut -c1-64)"
    out="$(planpy one "$LEASE" "$1")"; rc=$?
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
    # the draft is marked applied only if it is still the one that was written (edited during the prompt → stays queued)
    if [ "$(shasum -a 256 "$1" 2>/dev/null | cut -c1-64)" = "$dsnap" ]; then mark_applied "$1"
    else echo "note: the draft changed while the prompt was open — left in the queue"; fi
    exit 0 ;;
  apply-all)
    [ $# -eq 0 ] || usage
    operator_gate
    drafts=()
    # only names the draft command makes (letters, digits, . _ -): a tab or newline in a name would forge a record
    # in the tab/newline protocol below (codex R2) — such a file is named and left alone
    for f in "$DDIR"/*.lease; do
      [ -f "$f" ] || continue
      case "${f##*/}" in *[!A-Za-z0-9._-]*) echo "  ! skipped a draft with an unexpected file name (left in place)"; continue ;; esac
      drafts+=("$f")
    done
    [ "${#drafts[@]}" -gt 0 ] || { echo "no queued drafts in $DDIR"; exec 3<&-; exit 0; }
    snap="$(shasum -a 256 "$LEASE" 2>/dev/null | cut -c1-64)"
    [ -n "$snap" ] || { echo "ERROR: cannot read the lease file $LEASE"; exit 4; }
    out="$(planpy many "$LEASE" - - "${drafts[@]}")"; rc=$?
    # show every draft: what would be added, what is already there, what is skipped and why
    printf '%s\n' "$out" | awk -F'\t' '
      $1=="ADD"  { printf "  + %s\n      into %s\n      %s\n", $2, $3, $4 }
      $1=="DONE" { printf "  = %s — already in the lease (counts as applied)\n", $2 }
      $1=="SKIP" { printf "  ! %s — skipped, left in the queue: %s\n", $2, $3 }
      $1 ~ /^ERROR/ || $1=="NOTHING" { print }'
    [ "$rc" -eq 0 ] || { exec 3<&-; [ "$rc" -eq 4 ] && echo "nothing to apply"; exit "$rc"; }
    code="$(printf '%s\n' "$out" | awk -F'\t' '$1=="CODE"{print $2}')"
    n_add="$(printf '%s\n' "$out" | grep -c $'^ADD\t')"; n_done="$(printf '%s\n' "$out" | grep -c $'^DONE\t')"
    printf 'Type %s to apply this batch (%s line(s) into %s, %s already there): ' "$code" "$n_add" "$LEASE" "$n_done" >&3
    IFS= read -r typed <&3; typed="${typed%$'\r'}"
    exec 3<&-
    [ -n "$code" ] && [ "$typed" = "$code" ] || { echo "REFUSED: code did not match — nothing written"; exit 3; }
    now="$(shasum -a 256 "$LEASE" 2>/dev/null | cut -c1-64)"
    [ "$snap" = "$now" ] || { echo "REFUSED: the lease file changed while waiting — run apply-all again"; exit 3; }
    bak="$(mktemp "$LEASE.bak.$(date +%Y%m%dT%H%M%S).XXXXXX")" && cp -p "$LEASE" "$bak" \
      || { echo "ERROR: backup failed — nothing written"; exit 5; }
    wout="$(planpy many "$LEASE" "$snap" "$code" "${drafts[@]}")"; wrc=$?
    wrote=0; case $'\n'"$wout"$'\n' in *$'\nWROTE\n'*) wrote=1 ;; esac   # no pipe: grep -q under pipefail can SIGPIPE
    if [ "$wrc" -ne 0 ] || [ "$wrote" -ne 1 ]; then
      printf '%s\n' "$wout" | grep '^ERROR' ; echo "REFUSED/ERROR (rc=$wrc) — the lease file was not replaced (backup $bak)"
      [ "$wrc" -ne 0 ] && exit "$wrc"; exit 5
    fi
    # only the drafts the WRITE pass counted move; a SKIP stays queued
    # move only a draft that is still the bytes the write pass applied (edited since → stays queued, codex R2)
    printf '%s\n' "$wout" | awk -F'\t' '$1=="MOVE"{print $2 "\t" $3}' | while IFS=$'\t' read -r nm sh; do
      if [ -n "$sh" ] && [ "$(shasum -a 256 "$DDIR/$nm" 2>/dev/null | cut -c1-64)" = "$sh" ]; then mark_applied "$DDIR/$nm"
      else echo "note: $nm changed after it was applied — left in the queue"; fi
    done
    echo "applied: $n_add written · $n_done already there · backup $bak"
    exit 0 ;;
  *) usage ;;
esac
