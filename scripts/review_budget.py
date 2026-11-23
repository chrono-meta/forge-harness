#!/usr/bin/env python3
"""review_budget.py — one line for the morning report: «auto-merged N · operator-unread N».

Why: a night of autonomous work can merge more than a person reads. This counts, from records only,
how many PRs were merged in the window and how many of those no operator utterance ever named.
It is a record property, not a judgment: it never says whether a merge was right, and it blocks nothing.

Inputs (the caller chooses the window by choosing what to pass):
  --selfdev-report FILE   self-dev loop report(s); a line «#N MERGED (auto» is a merge. HOLD, refused and
                          other lines are not.
  --merged N[,N...]       PR numbers the caller merged in the window by other routes (e.g. a root session
                          merging under a night lease). Counted once even when a report also lists them.
  --lease FILE            lease record(s). Only lines containing «utterance» are operator records, and only
                          the part before «⇒» counts (the operator's words and the question they answered;
                          what follows «⇒» is the recorder's scope note).
  --checklist FILE        request-checklist sheet(s). Only the 발화 (utterance) cell of a table row counts.

Definition printed with the line:
  auto-merged     = PRs merged in the window (report «MERGED (auto» lines ∪ --merged)
  operator-unread = auto-merged PRs whose number (#N, whole number) appears in no operator record above

Named residuals:
  - The number match is repo-blind: «FoD #384» on an utterance line also marks FH #384 read. This errs
    toward «read», so the unread count is a lower bound.
  - Records are read as they are at run time; an utterance written after the merge still counts as read.
  - An operator may have read a PR without saying its number; that is not in the records and counts unread.
  - A checklist 발화 cell holding a message from another session is skipped, not counted as the operator's.

rc: 0 line printed · 2 a record could not be read («not measured», never 0) or bad arguments.
"""
import argparse
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import session_checklist as sc  # single source for checklist table parsing

MERGED_RE = re.compile(r"^\s*-\s*#(\d+)\s+MERGED \(auto", re.M)  # the loop's own line shape only (codex R1: a quoted
# «#N MERGED (auto» inside a HOLD/refused line is not a merge)


def num_re(n):
    return re.compile(r"(?<![0-9])#%d(?![0-9])" % n)


def read(path):
    with open(path, encoding="utf-8") as fh:
        return fh.read()


def utterance_texts_lease(text):
    for line in text.splitlines():
        if "utterance" in line.lower():
            yield line.split("⇒", 1)[0]


# A 발화 cell that is a message from another session (the hook channel records those as rows too) is not the
# operator's words. Measured 2026-11-23: one checklist carried 383 such rows, and one of them named a PR.
PEER_PREFIXES = ("<cross-session-message", "<agent-message")
PEER_BANNER = "Another Claude session sent a message:"   # same rule as session_checklist.py's peer test


def is_peer_message(cell):
    c = cell.strip()
    if c.startswith(PEER_PREFIXES):
        return True
    return c.startswith(PEER_BANNER) and ("<agent-message" in c or "<cross-session-message" in c)


def utterance_cells_checklist(path):
    """발화 cells of every 상태 table, through session_checklist's single parser (no second normalizer).
    Returns (cells, None) or (None, reason) — a sheet with no 상태 table or no data rows is not measured."""
    tables, rc = sc.load_tables(path)
    if rc is not None or not tables:
        return None, "no readable 상태 table" if rc in (None, 10) else "상태 table with no data rows"
    cells = []
    for header, rows in tables:
        ui = sc.find_header_index(header, "발화")
        if ui is None or ui < 0:
            return None, "no single 발화 column"
        cells.extend(r[ui] for r in rows if len(r) > ui and not is_peer_message(r[ui]))
    return cells, None


def main(argv=None):
    ap = argparse.ArgumentParser(description="One line for the morning report: auto-merged N · operator-unread N.")
    ap.add_argument("--selfdev-report", action="append", default=[])
    ap.add_argument("--merged", action="append", default=[])
    ap.add_argument("--lease", action="append", default=[])
    ap.add_argument("--checklist", action="append", default=[])
    a = ap.parse_args(argv)

    merged = set()
    for chunk in a.merged:
        for part in chunk.split(","):
            part = part.strip().lstrip("#")
            if not part:
                continue
            if not part.isdigit():
                print(f"review budget: not measured — bad --merged value «{part}»", file=sys.stderr)
                return 2
            merged.add(int(part))

    unreadable = []
    texts = []
    for kind, paths in (("report", a.selfdev_report), ("lease", a.lease), ("checklist", a.checklist)):
        for p in paths:
            if kind == "checklist":
                # session_checklist reads with errors="replace"; a strict read first keeps a bad byte from
                # passing as text (codex R1)
                try:
                    read(p)
                except (OSError, UnicodeDecodeError) as e:
                    unreadable.append(f"{os.path.basename(p)} ({e.__class__.__name__})")
                    continue
                cells, why = utterance_cells_checklist(p)
                if cells is None:
                    unreadable.append(f"{os.path.basename(p)} ({why})")
                    continue
                texts.append((kind, cells))
                continue
            try:
                t = read(p)
            except (OSError, UnicodeDecodeError) as e:
                unreadable.append(f"{os.path.basename(p)} ({e.__class__.__name__})")
                continue
            texts.append((kind, t))
    if unreadable:
        print("review budget: not measured — unreadable record(s): " + ", ".join(unreadable))
        return 2
    if not a.lease and not a.checklist:
        print("review budget: not measured — no operator record given (--lease or --checklist)")
        return 2

    operator = []
    for kind, t in texts:
        if kind == "report":
            merged.update(int(m) for m in MERGED_RE.findall(t))
        elif kind == "lease":
            operator.extend(utterance_texts_lease(t))
        else:
            operator.extend(t)

    unread = sorted(n for n in merged if not any(num_re(n).search(u) for u in operator))
    line = f"review budget: auto-merged {len(merged)} · operator-unread {len(unread)}"
    if unread:
        line += " — unread: " + " ".join(f"#{n}" for n in unread)
    print(line)
    print("  definition: auto-merged = «#N MERGED (auto» lines in the self-dev reports given ∪ --merged; "
          "operator-unread = of those, numbers named on no «utterance» lease line (before «⇒») and in no "
          "checklist 발화 cell. A record property, not a judgment.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
