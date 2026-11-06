#!/usr/bin/env python3
"""convergence_verdict.py — the convergence-loop verdict, by program (convergence-loop SKILL.md §Convergence Judgment ·
steel-quench §Convergence Criteria).

  Converged = the LAST round found no new S/A (or no new FAIL) AND nothing was fixed in response to it,
              AND at least two rounds ran (one clean round is only «provisionally passed»).

Why a program: a marker's `axis2-rounds:` line is «recorded-by-convention, validated by nothing» (fh_4axis_gate.md),
and the rule says to mechanize on the first recurrence of a false convergence claim. The 2026-11-06 corpus scan found
markers that wrote «R1 [new=0, fixed=0] → converged» — one round, claimed converged — more than once.

Modes
  --rounds "<vector>"      judge one vector (exit 0 CONVERGED · 1 NOT-CONVERGED or PROVISIONAL · 2 UNMEASURED/unparsed)
  --scan-markers <dir>     audit every `axis2-rounds:` line in <dir>/.axes_23_passed_*.marker: the vector's verdict
                           vs what the line CLAIMS («converged» written when the vector does not support it).
                           exit 0 no false claim · 1 at least one false claim · 2 nothing readable.
                           [--since YYYY-MM-DD] limits by the date in the marker file name.

Vector shapes read (anything else is UNPARSED — never guessed):
  R1 [new=3, fixed=3] → R2 [new=0, fixed=0]          (fixed is the count of repairs made in response to that round)
  R1 S1A2B3 → R2 S0A0B0                               (counts of new S/A/B[/C] findings; repairs unknown, so a round with
                                                       any finding and no explicit «fixed» is UNMEASURED for repairs —
                                                       only an all-zero round is clean-with-no-repairs by construction)
Advisory audit only: it never edits a marker and is not wired into the commit hook (that hook is a gate path).
"""
import argparse
import glob
import os
import re
import sys

ROUND = re.compile(r"\bR(\d+)\b")
# a round segment must START with exactly one shape; a note after a count is only «(…)» (so «0.5» is not «0»)
SEG_NEWFIX = re.compile(r"^\s*\[\s*new\s*=\s*(\d+)(?:\s*\([^)]*\))?\s*,\s*fixed\s*=\s*(\d+)(?:\s*\([^)]*\))?\s*\]")
SEG_SAB = re.compile(r"^\s+((?:[SABC]\d+){2,4})(?![\w.])")
REPAIR_WORDS = re.compile(r"fix|repair|수리|반영|고침|고쳤", re.I)
CLAIM_EN = re.compile(r"(?<![A-Za-z])converged(?![A-Za-z])", re.I)
NEG_EN = re.compile(r"(?:\bnot|n't|\bnever|\bun|\bnon)[\s-]*(?:yet[\s-]*)?$", re.I)
CLAIM_KO = re.compile(r"(?:→|=>|->)\s*(?:완전\s*)?수렴(?!\s*(?:안|못|실패|하지|아님|불가))|수렴\s*(?:했|함\b|됨|완료|판정\s*[:=]?\s*(?:통과|OK))")
CONVERGED, NOT_CONVERGED, PROVISIONAL, UNMEASURED = "CONVERGED", "NOT-CONVERGED", "PROVISIONAL", "UNMEASURED"
RC = {CONVERGED: 0, NOT_CONVERGED: 1, PROVISIONAL: 1, UNMEASURED: 2}   # the module contract allows 0/1/2 only; one clean round is not yet a pass


def parse(vector):
    """→ list of rounds [{n, new, fixed (None = unknown)}], "partial" when a round is present but in no known shape
    (or the shapes are mixed), or None when the vector names no round at all. A round that does not parse is never
    skipped — skipping it would let the rounds before it decide the verdict (codex R1)."""
    marks = list(ROUND.finditer(vector))
    if not marks:
        return None
    rounds, shapes = [], set()
    for i, m in enumerate(marks):
        seg = vector[m.end(): marks[i + 1].start() if i + 1 < len(marks) else len(vector)]
        nf = SEG_NEWFIX.match(seg)
        if nf:
            rest = seg[nf.end():]
            # codex R2: a second shape in the same round, or repairs written outside the counts, is not «one shape»
            if SEG_NEWFIX.search(rest.lstrip()) or re.search(r"\[\s*new\s*=|(?:^|\s)(?:[SABC]\d+){2,4}\b", rest) or REPAIR_WORDS.search(rest):
                return "partial"
            shapes.add("newfix")
            rounds.append({"n": int(m.group(1)), "new": int(nf.group(1)), "fixed": int(nf.group(2))})
            continue
        sab = SEG_SAB.match(seg)
        if sab:
            keys = re.findall(r"([SABC])(\d+)", sab.group(1))
            if len({k for k, _ in keys}) != len(keys):
                return "partial"            # «S1S0A0» — a repeated key would overwrite a count
            c = {k: int(v) for k, v in keys}
            if not {"S", "A"} <= set(c):
                return "partial"            # codex R2: «B0C0» says nothing about S/A — absent is not zero
            if re.search(r"\[\s*new\s*=|(?:^|\s)(?:[SABC]\d+){2,4}\b", seg[sab.end():]):
                return "partial"
            total = sum(c.values())
            if REPAIR_WORDS.search(seg[sab.end():]):
                fixed = None                # repairs mentioned but not as a count this tool can read
            else:
                fixed = 0 if total == 0 else None
            shapes.add("sab")
            rounds.append({"n": int(m.group(1)), "new": c.get("S", 0) + c.get("A", 0), "all": total, "fixed": fixed})
            continue
        return "partial"
    if len(shapes) > 1:
        return "partial"
    return rounds


def judge(vector):
    """→ (verdict, reason)"""
    rounds = parse(vector)
    if rounds == "partial":
        return UNMEASURED, "a round is not in one known shape (each R<n> needs [new=, fixed=] or S#A#B#, one shape for all)"
    if not rounds:
        return UNMEASURED, "no round vector in a known shape (R<n> [new=, fixed=] or R<n> S#A#B#)"
    nums = [r["n"] for r in rounds]
    if nums != sorted(nums) or len(set(nums)) != len(nums):
        return UNMEASURED, f"round numbers out of order or repeated: {nums}"
    last = rounds[-1]
    if last["new"] > 0:
        return NOT_CONVERGED, f"last round R{last['n']} found {last['new']} new"
    if last["fixed"] is None:
        return UNMEASURED, f"last round R{last['n']}: findings {last.get('all')} or repairs mentioned, and no fixed= count to read"
    if last["fixed"] > 0:
        return NOT_CONVERGED, f"last round R{last['n']} triggered {last['fixed']} fix(es) — the fixes are unverified"
    if len(rounds) < 2:
        return PROVISIONAL, "one clean round — «provisionally passed» only (convergence-loop condition 3: at least 2 rounds)"
    return CONVERGED, f"R{last['n']} clean with no repairs after {len(rounds)} rounds"


def claims_converged(text):
    """True when the line says «converged» anywhere not negated («not yet converged», «unconverged»), or says it in
    Korean («→ 수렴», «수렴 완료/했/됨») without «안/못/하지 않/아님»."""
    for m in CLAIM_EN.finditer(text):
        if not NEG_EN.search(text[max(0, m.start() - 12):m.start()]):
            return True
    return bool(CLAIM_KO.search(text))


def scan(directory, since=None):
    rows, unreadable = [], 0
    for path in sorted(glob.glob(os.path.join(directory, ".axes_23_passed_*.marker"))):
        m = re.search(r"_(\d{4}-\d{2}-\d{2})\.marker$", path)
        if since and (not m or m.group(1) < since):
            continue
        try:
            with open(path, encoding="utf-8") as f:
                lines = [l for l in f if l.startswith("axis2-rounds:")]
        except (OSError, UnicodeDecodeError):
            unreadable += 1
            continue
        for line in lines[:1]:   # the hook reads the first line only; so do we
            vec = line.split(":", 1)[1].strip()
            v, why = judge(vec)
            rows.append({"marker": os.path.basename(path), "verdict": v, "why": why,
                         "claimed": claims_converged(vec), "vector": vec})
    return rows, unreadable


def main(argv):
    ap = argparse.ArgumentParser(description="convergence verdict from a round vector")
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--rounds")
    g.add_argument("--scan-markers")
    ap.add_argument("--since")
    try:
        a = ap.parse_args(argv)
    except SystemExit:
        return 2
    if a.rounds is not None:
        v, why = judge(a.rounds)
        print(f"{v}: {why}")
        return RC[v]
    if not os.path.isdir(a.scan_markers):
        print(f"UNMEASURED: {a.scan_markers} is not a directory")
        return 2
    rows, unreadable = scan(a.scan_markers, a.since)
    if not rows:
        print(f"UNMEASURED: no readable axis2-rounds line in {a.scan_markers}" + (f" since {a.since}" if a.since else ""))
        return 2
    tally = {}
    for r in rows:
        tally[r["verdict"]] = tally.get(r["verdict"], 0) + 1
    # a claim the vector contradicts (not converged / one round) is false; a claim on an unreadable vector is unauditable
    false_claims = [r for r in rows if r["claimed"] and r["verdict"] in (NOT_CONVERGED, PROVISIONAL)]
    unauditable = [r for r in rows if r["claimed"] and r["verdict"] == UNMEASURED]
    print(f"convergence audit · {len(rows)} markers with axis2-rounds · " + " · ".join(f"{k} {v}" for k, v in sorted(tally.items()))
          + (f" · unreadable {unreadable}" if unreadable else ""))
    print(f"claimed «converged» but the vector contradicts it: {len(false_claims)} · claimed on a vector this tool cannot read: {len(unauditable)}")
    for r in false_claims:
        print(f"  - {r['marker']}: {r['verdict']} — {r['why']}\n      «{r['vector'][:160]}»")
    # an audit that could not read some lines is not a clean audit (codex R1): false claim → 1, else anything unread → 2
    if false_claims:
        return 1
    return 2 if (unauditable or unreadable) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
