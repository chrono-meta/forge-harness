#!/usr/bin/env python3
"""claim_precision_report.py — completion-claim record counter (read-only, no verdict).

Origin: frontier digest 2026-11-11, arXiv:2611.10063 («completion-claim precision»).

What it counts, over existing request-checklist result sheets
(`tracks/_meta/session_checklist_<date>_<session>.md`):

  N  rows whose 상태 reads DONE in some sheet of a session
  M  of those, rows that a LATER sheet of the same session shows with a
     non-DONE 상태 the status enum can read (downgraded / reopened in the record). Sticky:
     a still-later DONE does not erase the reopening.
  B  of those (not in M), rows the NEWEST sheet of the session did not
     re-judge: 상태 empty there, a value outside the status enum (e.g. «—»),
     or the row is absent from it. That is a channel gap, NOT a correction,
     and it is printed apart so «not re-judged» never reads as «still DONE».

Unreadable sheets are listed and do not count toward «measured».
Channels: only sessions with 2+ readable sheets can show a later re-judgment. Sessions
with a single sheet are listed as NOT MEASURED (their M is unknown, not 0).
Corrections made only in conversation, PRs or later sessions with a different
session id are not in these sheets and are named as an unread channel.

It reports record properties only — no ratio threshold, no pass/fail.
Rows are keyed by (시각, first 40 chars of 발화); a key seen twice in one sheet
is counted once and reported as a collision.

rc: 0 report printed · 10 no sheets found · 2 usage error.
"""
import argparse
import collections
import glob
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import session_checklist as sc  # single source for table parsing + status enum

NAME_RE = re.compile(r"session_checklist_(\d{4}-\d\d-\d\d)_(.+)\.md$")


def row_keys(path):
    """Yield (key, status_keys_or_None) for every 상태-table row of one sheet."""
    tables, rc = sc.load_tables(path)
    if not tables:
        return
    for header, rows in tables:
        idx = [sc.find_header_index(header, n) for n in ("상태", "시각", "발화")]
        if any(i is None or i < 0 for i in idx):
            continue
        si, ti, ui = idx
        for r in rows:
            if len(r) <= max(idx):
                continue
            yield (r[ti].strip(), r[ui].strip()[:40]), sc.classify_status(r[si]), r[si].strip()


def classify_or_none(raw):
    """True only for a cell the status enum can read and that is not DONE-only-absent."""
    return sc.classify_status(raw)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--dir", required=True, help="folder holding session_checklist_*.md")
    ap.add_argument("--show", type=int, default=10, help="list up to N reopened rows")
    a = ap.parse_args(argv)

    by = collections.defaultdict(list)
    for f in sorted(glob.glob(os.path.join(a.dir, "session_checklist_*.md"))):
        m = NAME_RE.search(os.path.basename(f))
        if m:
            by[m.group(2)].append((m.group(1), f))
    if not by:
        print("claim-precision: sheets=0 — NOT MEASURED (no session_checklist_*.md in %s)" % a.dir)
        return 10

    n = m_ = b = coll = 0
    measured, single, unparsed = [], [], []
    shown = []
    for sid, sheets in sorted(by.items()):
        parsed = []
        for date, f in sheets:
            tables, rc = sc.load_tables(f)
            if not tables or rc is not None or next(row_keys(f), None) is None:
                # no table, or a table without 상태/시각/발화 rows: nothing measurable in this sheet
                unparsed.append(os.path.basename(f))   # a sheet we could not read is NOT a clean sheet
                continue
            parsed.append((date, f))
        if len(parsed) < 2:
            single.append(sid)
            continue
        measured.append(sid)
        done_at = {}      # key -> date first seen DONE
        reopened = {}     # key -> (date, raw) first later non-empty non-DONE — sticky, a later DONE never erases it
        last_date = parsed[-1][0]
        in_last = {}      # key -> raw 상태 in the newest parsed sheet
        for date, f in parsed:
            seen_here = set()
            for key, st, raw in row_keys(f):
                if key in seen_here:
                    coll += 1
                    continue
                seen_here.add(key)
                is_done = bool(st) and "DONE" in st
                if date == last_date:
                    in_last[key] = raw
                if key in done_at and date != done_at[key] and not is_done and st:   # st None = blank or a cell outside the enum («—»)
                    reopened.setdefault(key, (date, raw))
                if is_done and key not in done_at:
                    done_at[key] = date
        n += len(done_at)
        for key, (date, raw) in reopened.items():
            m_ += 1
            if len(shown) < a.show:
                shown.append((sid, key, done_at[key], date, raw))
        # B: DONE rows the newest sheet did not re-judge — row blank there, or row absent from it.
        for key, d0 in done_at.items():
            if key in reopened or d0 == last_date:
                continue
            if not classify_or_none(in_last.get(key, "")):
                b += 1

    print("claim-precision: sessions=%d measured=%d not-measured(<2 readable sheets)=%d"
          % (len(by), len(measured), len(single)))
    print("  N done-rows=%d · M later reopened (non-DONE in the enum)=%d · B not re-judged in newest sheet (blank, absent or outside the enum)=%d · key collisions=%d"
          % (n, m_, b, coll))
    print("  channels read: session_checklist sheets of %s" % (", ".join(measured) or "—"))
    print("  NOT MEASURED: sessions with <2 readable sheets %s · unreadable sheets %s · corrections outside "
          "these sheets (conversation, PRs, other session ids)" % (", ".join(single) or "—", ", ".join(unparsed) or "—"))
    for sid, key, d0, d1, raw in shown:
        print("  ↩︎ %s %s «%s» DONE@%s → %s@%s" % (sid, key[0], key[1], d0, raw, d1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
