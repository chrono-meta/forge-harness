#!/usr/bin/env python3
"""selfdev_queue.py — one input sheet for the unattended FH self-dev loop.

WHY (operator, 2026-11-04 — CLAUDE.local.md §FH 자체개발 자율화): «운영자는 일반 사용자처럼 FH 를
쓰고, FH 는 주기적으로 쌓인 사용 기록에서 인사이트를 뽑아 자체개선 사이클을 돈다 … 세션에서 «이거
고치자» 했는데 남아 있으면 그것도 모아서». The records already exist, in five places nobody reads
together; this script reads them together. It decides nothing — it lists, with each item's SEED:

  seed=human      the operator's own request, still open in a session checklist. Direction was
                  chosen by a human (goal-quench §Autonomy Ladder — «direction is always human»),
                  so only these may ever reach the auto-merge tier.
  seed=candidate  everything a machine proposed: digest candidates, absorption-queue rows,
                  correction-moment cues, session-card [planned] lines. PR at most; the operator
                  confirms in the morning report. A candidate is not a seed.

Every source prints a count or `UNMEASURED (<reason>)` — an unreadable source is never «0 items»
(feedback_not_found_is_not_zero_family).

USAGE  python3 scripts/selfdev_queue.py --live <forge-harness checkout> [--checklists N] [--date YYYY-MM-DD]
OUTPUT markdown on stdout; rc 0 when every source was read, 3 when ≥1 source is UNMEASURED.
"""
import argparse, datetime, glob, os, re, subprocess, sys

OPEN_MARKS = ("🟡", "⬜", "🔴", "⏸", "❌")


def src_checklists(live, n):
    files = sorted(glob.glob(os.path.join(live, "tracks/_meta/session_checklist_*.md")),
                   key=os.path.getmtime, reverse=True)[:n]
    if not files:
        return None, "no session_checklist_*.md"
    items, seen = [], set()
    for f in files:  # newest first — a row a later checklist inherited is kept once, newest
        for line in open(f, encoding="utf-8", errors="replace"):
            cells = [c.strip() for c in line.split("|")]
            # | # | 시각 | 발화 | 상태 | 증거 | 사유 / 남은 것 | 제안 |
            if len(cells) < 9 or not cells[1] or cells[1] == "#" or set(cells[1]) <= set("-"):
                continue
            status = cells[4]
            # a row closed in a NEWER checklist must not resurface from an older one: record every
            # status as seen, not only open ones
            if cells[3] in seen:
                continue
            seen.add(cells[3])
            if not status.startswith(OPEN_MARKS):
                continue
            owner_operator = bool(re.search(r"운영자|operator", cells[6] + " " + cells[7]))
            items.append({"seed": "human", "src": os.path.basename(f), "status": status,
                          "text": cells[3][:200], "left": cells[6][:200],
                          "owner": "operator" if owner_operator else "session"})
    return items, None


def src_absorption(live):
    p = os.path.join(live, "tracks/_meta/absorption_queue.tsv")
    if not os.path.exists(p):
        return None, "absorption_queue.tsv missing"
    items = []
    for i, line in enumerate(open(p, encoding="utf-8")):
        cols = line.rstrip("\n").split("\t")
        if i == 0 or len(cols) < 6:
            continue
        if cols[5] == "open":
            items.append({"seed": "candidate", "src": cols[0], "text": cols[3][:200], "from": cols[2]})
    return items, None


def src_card(live):
    p = os.path.join(live, "tracks/_meta/reference_next_session_starter.md")
    if not os.path.exists(p):
        return None, "session card missing"
    text = open(p, encoding="utf-8").read()
    first = text.split("\n---\n", 1)[0]  # newest block only
    items = [{"seed": "candidate", "src": "card", "text": m.strip()[:240]}
             for m in re.findall(r"^\s*\d+\.\s*\[planned\](.*)$", first, flags=re.M)]
    return items, None


def src_digest(live, date):
    p = os.path.join(live, "tracks/_meta/frontier_digest_%s.md" % date.replace("-", "_"))
    if not os.path.exists(p):
        return None, "no digest for %s (%s)" % (date, os.path.basename(p))
    text = open(p, encoding="utf-8").read()
    m = re.search(r"^## FH Immediate Application Candidates\s*$(.*?)(?=^## )", text, flags=re.M | re.S)
    if not m:
        return None, "digest has no «FH Immediate Application Candidates» section"
    items = [{"seed": "candidate", "src": os.path.basename(p), "text": b.strip()[:240]}
             for b in re.findall(r"^- (.+)$", m.group(1), flags=re.M)]
    return items, None


def src_corrections(live):
    script = os.path.join(live, "scripts/correction_moments.py")
    if not os.path.exists(script):
        return None, "correction_moments.py missing"
    try:
        out = subprocess.run([sys.executable, script], cwd=live, capture_output=True,
                             text=True, timeout=120)
    except Exception as e:  # report, never swallow into «0»
        return None, "correction_moments.py failed: %s" % e
    if out.returncode != 0 or not out.stdout.strip():
        return None, "correction_moments.py rc=%d, stdout %d bytes" % (out.returncode, len(out.stdout))
    lines = out.stdout.splitlines()
    head = [l for l in lines[:3] if l.strip()]
    return [{"seed": "candidate", "src": "correction_moments", "text": " / ".join(head)[:400]}], None


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--live", required=True)
    ap.add_argument("--checklists", type=int, default=3)
    ap.add_argument("--date", default=datetime.date.today().isoformat())
    ap.add_argument("--emit-human", action="store_true",
                    help="print only the exact text of each open seed=human row, one per line — the "
                         "loop compares a PR's request against these with no delimiter parsing")
    a = ap.parse_args(argv)
    live = os.path.abspath(a.live)
    if a.emit_human:
        items, err = src_checklists(live, a.checklists)
        if err:
            print("UNMEASURED: %s" % err, file=sys.stderr)
            return 3
        for it in items:
            print(it["text"])
        return 0
    sources = [
        ("checklist open rows (operator requests)", src_checklists(live, a.checklists)),
        ("absorption queue (open)", src_absorption(live)),
        ("session card [planned]", src_card(live)),
        ("frontier digest candidates (%s)" % a.date, src_digest(live, a.date)),
        ("correction moments", src_corrections(live)),
    ]
    unmeasured = 0
    print("# self-dev queue — %s\n" % a.date)
    print("seed=human → auto-merge eligible (still subject to selfdev_merge_tier.sh) · "
          "seed=candidate → PR at most, operator confirms · owner=operator rows are the "
          "operator's to do, not the loop's.\n")
    for name, (items, err) in sources:
        if err:
            unmeasured += 1
            print("## %s — UNMEASURED (%s)\n" % (name, err))
            continue
        print("## %s — %d\n" % (name, len(items)))
        for it in items:
            extra = " · owner=%s · %s · 남은 것: %s" % (it["owner"], it["status"], it["left"]) if "owner" in it else ""
            print("- [seed=%s] (%s) %s%s" % (it["seed"], it["src"], it["text"], extra))
        print()
    return 3 if unmeasured else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
