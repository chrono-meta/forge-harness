#!/usr/bin/env python3
"""session_ledger_read.py — the root session reads the shared session ledger.

  session_ledger_read.py [--ledger <path>] [--expect <id,id,...>] [--full]

Prints the latest line per (session, task) and, per kind, a table. With --expect (the sessions the root
started) every expected session that wrote NOTHING is printed as a NOT-WRITTEN row and counted:
«N sessions expected, M wrote». A silent session must never read as «no problem».
Without --expect the expected set is UNKNOWN and the reader says so — it cannot count silence.

Ledger: --ledger, else $FH_SESSION_LEDGER, else <main checkout>/tracks/_meta/session_ledger/ledger.tsv
(writer: scripts/session_ledger_write.sh — same closed state sets are re-checked here, so a hand-edited
or truncated line is MALFORMED, not silently dropped).

Exit: 0 read, every expected session wrote, no malformed line
      3 malformed line(s) present (they are listed, never skipped silently)
      4 ledger missing or empty (printed as such — «no ledger» is not «nothing happening»)
      6 some expected session(s) wrote nothing
      (when several apply: 4 first, then 3, then 6)
This reader asserts what the ledger SAYS. Whether a done/landing line is true is the root's source check
(open the PR / head / path named in evidence) — this script does not and cannot do that.
"""
import argparse, os, re, subprocess, sys

STATES = {
    "board": {"planned", "in_progress", "blocked", "done", "abandoned"},
    "note": {"info", "finding", "risk"},
    "landing": {"pr_open", "merged", "committed", "file_written", "unmeasured"},
}
TS = re.compile(r"^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$")
SID = re.compile(r"^[A-Za-z0-9._-]{1,80}$")
TASK = re.compile(r"^[a-z0-9][a-z0-9._-]{0,63}$")
TOK = re.compile(r"^(pr=#[0-9]+|(head|commit)=[0-9a-f]{7,40}|path=[^/].*|repo=[A-Za-z0-9._-]+/[A-Za-z0-9._-]+|none=.+)$")
CTRL = re.compile(r"[\x00-\x1f\x7f]")
HARD = re.compile(r"^(pr|head|commit|path)=")


def default_ledger():
    if os.environ.get("FH_SESSION_LEDGER"):
        return os.environ["FH_SESSION_LEDGER"]
    hub = os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()
    try:
        out = subprocess.run(["git", "-C", hub, "worktree", "list", "--porcelain"],
                             capture_output=True, text=True).stdout.splitlines()
        if out and out[0].startswith("worktree ") and not (len(out) > 1 and out[1] == "bare"):
            main = out[0][len("worktree "):]
            if os.path.exists(os.path.join(main, ".git")):
                hub = main
    except OSError:
        pass
    return os.path.join(hub, "tracks", "_meta", "session_ledger", "ledger.tsv")


def check(fields):
    if len(fields) != 7:
        return f"{len(fields)} fields (want 7)"
    if any(CTRL.search(f) for f in fields): return "control character in a field"
    ts, sid, task, kind, state, ev, _text = fields
    if not TS.match(ts): return "bad timestamp"
    if not SID.match(sid): return "bad session id"
    if not TASK.match(task): return "bad task slug"
    if kind not in STATES: return f"unknown kind {kind!r}"
    if state not in STATES[kind]: return f"state {state!r} not allowed for {kind}"
    toks = [t for t in ev.split(" ") if t]  # ASCII space only — same as the writer's bash IFS (tab/newline are refused)
    for t in toks:
        if not TOK.match(t) or (t.startswith("path=") and ".." in t[5:].split("/")): return f"bad evidence token {t!r}"
    need = (kind == "board" and state == "done") or (kind == "landing" and state != "unmeasured")
    if need and not any(HARD.match(t) for t in toks): return f"{kind}/{state} without pr/head/commit/path"
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ledger")
    ap.add_argument("--expect", default="")
    ap.add_argument("--full", action="store_true", help="print every valid line, not only the latest")
    a = ap.parse_args()
    path = a.ledger or default_ledger()
    expect = [s for s in a.expect.split(",") if s]
    print(f"ledger: {path}")

    if not os.path.isfile(path) or os.path.getsize(path) == 0:
        print("STATUS: NO-LEDGER-LINES — " + ("file missing" if not os.path.isfile(path) else "file empty"))
        print("  this is «nobody wrote», not «nothing is happening».")
        if expect:
            print(f"  expected sessions: {len(expect)} · wrote: 0 · NOT-WRITTEN: {', '.join(expect)}")
        else:
            print("  expected set: UNKNOWN (no --expect) — silent sessions cannot be counted")
        return 4

    rows, bad = [], []
    with open(path, "rb") as f:
        for n, raw in enumerate(f, 1):
            try:
                line = raw.decode("utf-8")
            except UnicodeDecodeError:
                bad.append((n, "not utf-8", raw[:80])); continue
            if not line.endswith("\n"):
                bad.append((n, "no trailing newline (truncated write?)", line[:80])); continue
            fields = line[:-1].split("\t")
            why = check(fields)
            if why:
                bad.append((n, why, line[:80].rstrip())); continue
            rows.append((n, *fields))

    latest, counts = {}, {}
    for r in rows:
        key = (r[2], r[3], r[4])  # session, task, kind
        latest[key] = r           # file order = write order (append-only); later line wins
        counts[key] = counts.get(key, 0) + 1

    shown = rows if a.full else sorted(latest.values(), key=lambda r: (r[2], r[3], r[4]))
    print(f"{'session':<22} {'task':<24} {'kind':<8} {'state':<12} {'lines':>5}  {'ts':<20} evidence | text")
    for r in shown:
        n, ts, sid, task, kind, state, ev, text = r
        c = counts[(sid, task, kind)]
        print(f"{sid:<22} {task:<24} {kind:<8} {state:<12} {c:>5}  {ts:<20} {ev or '-'} | {text or ''}")

    wrote = sorted({r[2] for r in rows})
    silent = [s for s in expect if s not in wrote]
    for s in silent:
        print(f"{s:<22} {'-':<24} {'-':<8} {'NOT-WRITTEN':<12} {0:>5}  {'-':<20} (no line in the ledger)")
    if expect:
        print(f"SESSIONS: {len(expect)} expected · {len(expect) - len(silent)} wrote · "
              f"{len(silent)} NOT-WRITTEN" + (f" ({', '.join(silent)})" if silent else ""))
        extra = [s for s in wrote if s not in expect]
        if extra:
            print(f"  also wrote (not in --expect): {', '.join(extra)}")
    else:
        print(f"SESSIONS: expected set UNKNOWN (no --expect) · {len(wrote)} wrote — silent sessions cannot be counted")
    print(f"LINES: {len(rows)} valid · {len(bad)} MALFORMED")
    for n, why, txt in bad:
        print(f"  MALFORMED line {n}: {why} :: {txt!r}")

    if bad:
        return 3
    if silent:
        return 6
    return 0


if __name__ == "__main__":
    sys.exit(main())
