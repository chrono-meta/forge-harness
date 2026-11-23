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

rc: 0 line printed · 2 a record could not be read («not measured», never 0) or bad arguments.
"""
import argparse
import os
import re
import sys

MERGED_RE = re.compile(r"#(\d+)\s+MERGED \(auto")


def num_re(n):
    return re.compile(r"(?<![0-9])#%d(?![0-9])" % n)


def read(path):
    with open(path, encoding="utf-8") as fh:
        return fh.read()


def utterance_texts_lease(text):
    for line in text.splitlines():
        if "utterance" in line.lower():
            yield line.split("⇒", 1)[0]


def find_header_index(cells, name):
    for i, c in enumerate(cells):
        if c.strip().startswith(name):
            return i
    return None


def utterance_texts_checklist(text):
    ui = None
    for line in text.splitlines():
        s = line.strip()
        if not s.startswith("|"):
            ui = None if not s else ui
            continue
        cells = s.strip("|").split("|")
        if ui is None:
            ui = find_header_index(cells, "발화")
            continue
        if set(s.replace("|", "").strip()) <= set("-: "):
            continue
        if ui < len(cells):
            yield cells[ui]


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
            operator.extend(utterance_texts_checklist(t))

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
