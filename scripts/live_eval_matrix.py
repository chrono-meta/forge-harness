#!/usr/bin/env python3
"""live_eval_matrix.py — per-probe verdicts across every nightly live-eval report, read once.

Why (frontier digest 2026-11-12, arXiv:2611.13709): a pooled pass rate such as 0.8 can hide a
probe that has never passed. probe_live_eval.sh already compares each report with the one before it
(`moved since previous`). It does not show the whole history: which probes always pass, which never
did, and which flip back and forth. This reads every live_eval_<YYYY-MM-DD>.md in a folder and
prints a probe × date matrix plus four lists:
  always-pass   — every scored report says PASS (scored = PASS or FAIL)
  never-pass    — every scored report says FAIL
  mixed         — both PASS and FAIL appear
  too-few       — fewer than 2 scored reports, so no bin applies (an absence is not a bin)

Record only. It prints record properties (counts and lists) and no verdict. No threshold, and the
exit code ignores the bins. Whether a never-pass probe means a dead rule or a broken probe is a
human judgment. UNCALIBRATED, FAILED-TO-RUN and rows whose verdict is outside the enum are counted in their own columns and are never
counted as FAIL. A probe that did not run did not fail.

Parsing reuses probe_live_eval_lib.parse_prev_report (single source for the run-table shape).

Usage:
  live_eval_matrix.py [--dir <folder>]   # default <repo>/tracks/_meta (the reports are gitignored)
exit: 0 printed · 10 input error (folder missing)
"""
import glob
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import probe_live_eval_lib as L  # noqa: E402

NAME = re.compile(r"^live_eval_(\d{4}-\d{2}-\d{2})\.md$")
OUT_OF_ENUM = "OUT-OF-ENUM"  # row present, verdict cell outside the run-table enum (not scored, not absent)
SHORT = {L.PASS: "P", L.FAIL: "F", L.UNCALIBRATED: "U", L.FAILED_TO_RUN: "R", "UNKNOWN-ID": "?", OUT_OF_ENUM: "N"}


def collect(folder):
    """-> (dates, {date: {id: verdict}}, unreadable[names]). Files are matched by exact name only;
    stratify/RESULT files and other suffixes are not run tables of this shape and are skipped."""
    reports, unreadable = {}, []
    for p in sorted(glob.glob(os.path.join(folder, "live_eval_*.md"))):
        m = NAME.match(os.path.basename(p))
        if not m:
            continue
        rows = L.parse_prev_report(p)
        if rows is None:
            unreadable.append(os.path.basename(p))
        else:
            reports[m.group(1)] = rows
    # parse_prev_report keeps only enum verdicts. A known probe row whose verdict cell is outside the
    # enum (measured 2026-11-13: «NOT-LIVE-MEASURABLE (…)» in 60+ real reports) would otherwise print
    # as absent, which claims the probe was not in that report when it was there but not scored.
    ids = {i for r in reports.values() for i in r}
    for d, rows in reports.items():
        text = L._read_text(os.path.join(folder, "live_eval_%s.md" % d)) or ""
        for line in text.splitlines():
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            if line.startswith("|") and len(cells) >= 2 and cells[0] in ids and cells[0] not in rows:
                rows[cells[0]] = OUT_OF_ENUM
    return sorted(reports), reports, unreadable


def bins(dates, reports):
    ids = sorted({i for d in dates for i in reports[d]})
    out = {"always-pass": [], "never-pass": [], "mixed": [], "too-few": []}
    detail = {}
    for i in ids:
        seq = [reports[d].get(i) for d in dates]
        scored = [v for v in seq if v in (L.PASS, L.FAIL)]
        p, f = scored.count(L.PASS), scored.count(L.FAIL)
        other = sum(1 for v in seq if v is not None and v not in (L.PASS, L.FAIL))
        absent = seq.count(None)
        if len(scored) < 2:
            b = "too-few"
        elif f == 0:
            b = "always-pass"
        elif p == 0:
            b = "never-pass"
        else:
            b = "mixed"
        out[b].append(i)
        detail[i] = {"seq": seq, "pass": p, "fail": f, "other": other, "absent": absent, "bin": b}
    return out, detail


def render(folder, dates, reports, unreadable):
    lines = ["live-eval matrix (record only — no verdict, exit code ignores bins)",
             "folder: %s" % folder,
             "reports read: %d%s" % (len(dates), (" (%s .. %s)" % (dates[0], dates[-1])) if dates else ""),
             "reports unreadable or without a run table: %d%s" % (
                 len(unreadable), (" — " + ", ".join(unreadable)) if unreadable else "")]
    if not dates:
        lines.append("no readable report — nothing to bin (not measured, not zero)")
        return "\n".join(lines)
    b, detail = bins(dates, reports)
    lines.append("legend: P=PASS F=FAIL U=UNCALIBRATED R=FAILED-TO-RUN ?=UNKNOWN-ID N=row present, verdict outside the enum .=absent from that report")
    lines.append("")
    w = max(len(i) for i in detail)
    for i in sorted(detail):
        d = detail[i]
        cells = "".join(SHORT.get(v, "?") if v is not None else "." for v in d["seq"])
        lines.append("%-*s  %s  pass=%d fail=%d not-scored=%d absent=%d  %s" % (
            w, i, cells, d["pass"], d["fail"], d["other"], d["absent"], d["bin"]))
    lines.append("")
    for k in ("always-pass", "never-pass", "mixed", "too-few"):
        lines.append("%s: %d%s" % (k, len(b[k]), (" — " + ", ".join(b[k])) if b[k] else ""))
    return "\n".join(lines)


def main(argv):
    folder = os.path.join(os.path.dirname(HERE), "tracks", "_meta")
    if len(argv) >= 2 and argv[0] == "--dir":
        folder = argv[1]
    elif argv:
        sys.stderr.write("usage: live_eval_matrix.py [--dir <folder>]\n")
        return 10
    if not os.path.isdir(folder):
        sys.stderr.write("folder not found: %s\n" % folder)
        return 10
    dates, reports, unreadable = collect(folder)
    print(render(folder, dates, reports, unreadable))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
