#!/usr/bin/env python3
"""citation_key_check.py — every citation key a paper USES is DEFINED, and every DEFINED key is USED.

WHAT IT CLOSES (measured 2026-09-17, paper-2 draft, the night the sister paper had been rejected by
arXiv for 11/17 reference mismatches)
  The governor had to check citation-key integrity BY HAND with ad-hoc python. Two live defects that
  night: `[EBP18]` was cited in §9.4 and had NO row in the references table (a PHANTOM), and `[MF24]`
  was cited where the table's row read `[MF22]` — the arXiv-posting year had been used as the key
  while the journal year is 2022 (a NEAR-MISS: same letters, different year). A plain used-vs-defined
  diff reports that second case as one phantom PLUS one orphan and never says they are the same key,
  so a renumbering can silently orphan the row and phantom the citation at once. This tool pairs them.

WHAT IT DOES NOT DO — read before trusting a 0
  🟥 It checks KEY integrity, not bibliographic truth. A key that is used and defined can still point
     at a row whose title, year, venue or DOI is wrong — that is `phantom-quench` / the refs table's
     own «확인» column, not this tool.
  🟥 Keys inside code spans (`[K26]`, fenced blocks) are MENTIONS, not citations — a paper's own
     «citation verification» table names keys that way. They are counted separately and printed, never
     silently dropped; `--count-code` turns them into usages if a body really cites in code style.
  🟥 A definition row is recognised ONLY by the house table shape: the row's FIRST cell is `[KEY]`
     (`| [C70] | Chow … |`, bold allowed). A bibliography written as a list is invisible → rc=10, not
     «all phantom». The whole definition row is excluded from usage counting, so a paper that carries
     its own table in the body still works (the row's note column is not scanned for usages).
  🟥 Grouped citations `[C70, EW10, T24]` are split on `,` / `;`; every element that fully matches the
     key grammar counts. An element that does not (`[C70, p. 41]` → `p. 41`) is ignored, not reported.
  🟥 Keys in a --refs file OUTSIDE its definition rows are NOT usages unless that file is also passed
     as --body (the drop-in prior-art section is both a body and the table — pass it as both).

KEY GRAMMAR (house style)   [A-Z][A-Za-z]{0,6}\\d{2}[a-z]?     e.g. [C70] [EBP18] [BES26a] [OCR26]
NEAR-MISS                   two DIFFERENT keys with the same letter prefix (case-insensitive), where at
                            least one side is PHANTOM or ORPHAN — [MF24]↔[MF22], [BES26]↔[BES26a].
                            Two keys both used and both defined are two papers, not a near-miss.
                            `--no-near-miss` disables the pairing (ablation / revert probe).

EXIT CODES
   0  scanned, every used key defined, every defined key used (orphans listed but not counted)
   1  PHANTOM (used, undefined) or DUP-DEF (one key defined twice)
   2  no phantom, but ORPHAN keys present and --strict-orphans was given
   4  DEAD CONTROL: the body yields ZERO citation usages — a paper with no citations is not
      «clean», it is unscanned (mentions-only counts as zero). Distinct from 0 on purpose.
  10  input error (file missing / unreadable · 0 definition rows parsed from the references table)

USAGE
  python3 scripts/citation_key_check.py --body <md...> [--refs <md...>] [--strict-orphans]
                                        [--count-code] [--no-near-miss] [--json]
  bash    scripts/test_paper_integrity_lanes.sh          # known pairs + revert probe
Python ≥ 3.9, stdlib only.
"""
import argparse
import json
import os
import re
import sys
import unicodedata

KEY = r"[A-Z][A-Za-z]{0,6}\d{2}[a-z]?"
KEY_RE = re.compile(r"^" + KEY + r"$")
# 🟥 v3 (codex round 2, 2026-09-18): `[BAD–26]` — letters, a Unicode dash, digits — is a citation the
# reader SEES and the table cannot match, and v2 skipped it silently because it failed KEY_RE. A key
# with any dash/underscore between letters and year is MALFORMED: reported and counted, never
# normalized away (a typo the reader sees is a defect even when a human would guess the row).
MALFORMED_RE = re.compile(r"^[A-Z][A-Za-z]{0,6}[\-‐‑‒–—−_]\d{2}[a-z]?$")
# v10 (codex round 9): `[mf22]` — key-shaped but case-mismatched — cannot match the house table either
CASE_RE = re.compile(r"^[A-Za-z]{1,7}[\-‐‑‒–—−_]?\d{2}[A-Za-z]?$")   # v11: `[BES26A]` too
BRACKET_RE = re.compile(r"\[([^\[\]\n]{1,160})\]")
# v7 (codex round 6): a definitions table inside a blockquote (`> | [KEY] | … |`) is still the visible table
DEF_ROW_RE = re.compile(r"^\s*(?:>\s*)*\|\s*(?:\*\*)?\[(" + KEY + r")\](?:\*\*)?\s*\|")
CODE_SPAN_RE = re.compile(r"`[^`\n]*`")
LETTERS_RE = re.compile(r"^([A-Za-z]+)\d{2}[a-z]?$")


def letters(key):
    m = LETTERS_RE.match(key)
    return m.group(1).lower() if m else key.lower()


def _elements(text):
    """Bracket elements, NFKC-normalized (`［ＭＦ22］`-style full-width forms read as ASCII)."""
    for m in BRACKET_RE.finditer(unicodedata.normalize("NFKC", text)):
        for el in re.split(r"[,;&、·]|\s+and\s+", m.group(1)):   # v14: `[AB24 & ZZ99]` · `[AB24 and ZZ99]` · v17: `[AB24、ZZ99]` · v18: `[AB24 · ZZ99]`
            yield el.strip()


def keys_in(text):
    """Every key cited in `text`: single `[K26]` and grouped `[C70, EW10]` brackets."""
    return [el for el in _elements(text) if KEY_RE.match(el)]


def malformed_in(text):
    """Citation-shaped bracket elements that are NOT keys (`[BAD–26]`, `[MF-22]`, `[GE_17]`, `[mf22]`)."""
    return [el for el in _elements(text) if not KEY_RE.match(el) and (MALFORMED_RE.match(el) or CASE_RE.match(el))]


CODE_SPAN_MASK_RE = re.compile(r"`[^`\n]*`")


FENCE_RE = re.compile(r"^(?:>\s*)*(`{3,}|~{3,})(.*)$")


def _fence_step(line, fence):
    """→ (fence_after, on_fence_line). `fence` = (char, opener length) while inside a fenced block, else
    None. v9 (codex round 8) — CommonMark: a closer uses the same char, is at least as long as the
    opener and carries nothing but spaces after it (a 3-tick line does not close a 4-tick fence); a
    `> ` prefix is allowed (a fence inside a blockquote). Kept byte-identical across the three tools."""
    m = FENCE_RE.match(line.lstrip())
    if fence is None:
        return ((m.group(1)[0], len(m.group(1))), True) if m else (None, False)
    if m and m.group(1)[0] == fence[0] and len(m.group(1)) >= fence[1] and not m.group(2).strip():
        return None, True
    return fence, False


def strip_html_comments(text):
    """v6 (codex round 5): text inside `<!-- … -->` is invisible to the reader, so it is neither a defect
    nor an anchor. 🟥 v7 (codex round 6): the v6 regex strip ERASED PROSE between a `<!--` and a `-->`
    that sat inside code spans or fenced blocks — a delimiter inside code is a literal. 🟥 v8 (codex
    round 7): the same for `~~~` fences and 4-space / tab INDENTED code blocks (a block starts after a
    blank line and runs while lines stay indented). v9: fences go through _fence_step (opener length ·
    blockquote prefix). Fences and indented code are left untouched, code spans are masked before a
    delimiter is looked for. Line numbers are preserved; comment text becomes spaces. Kept
    byte-identical in the three tools (lanes L11l / L11o / L11q pin all three)."""
    out, fence, in_comment, prev_blank, prev_code = [], None, False, True, False
    for line in text.split("\n"):
        if in_comment:
            j = line.find("-->")
            if j < 0:
                out.append(" " * len(line))
                continue
            line, in_comment = " " * (j + 3) + line[j + 3:], False
        s = line.strip()
        fence, on_fence = _fence_step(line, fence)
        if on_fence or fence is not None:
            out.append(line)
            prev_blank, prev_code = False, False
            continue
        indented = (line.startswith("    ") or line.startswith("\t")) and (prev_blank or prev_code)
        if indented:
            out.append(line)
            prev_blank, prev_code = False, True
            continue
        prev_blank, prev_code = (s == ""), False
        masked = CODE_SPAN_MASK_RE.sub(lambda m: " " * len(m.group(0)), line)
        res, pos = [], 0
        while True:
            i = masked.find("<!--", pos)
            if i < 0:
                res.append(line[pos:])
                break
            res.append(line[pos:i])
            j = line.find("-->", i + 4)
            if j < 0:
                res.append(" " * (len(line) - i))
                in_comment = True
                break
            res.append(" " * (j + 3 - i))
            pos = j + 3
        out.append("".join(res))
    return "\n".join(out)


def load(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            return strip_html_comments(fh.read()).split("\n"), None
    except OSError as e:
        return None, str(e)


def scan_body(path, lines, count_code, used, mentions, malformed):
    """Fill used[key] / mentions[key] / malformed[element] with (file, line, snippet) sites. Definition
    rows are skipped. MALFORMED elements are collected from prose only — inside a fence or a code span
    they are text, like every other key there."""
    fence = None                          # v8/v9: ``` and ~~~ fences via _fence_step (opener length · `> ` prefix)
    for i, line in enumerate(lines, 1):
        s = line.strip()
        fence, on_fence = _fence_step(line, fence)
        if on_fence:
            continue
        in_fence = fence is not None
        if not in_fence and DEF_ROW_RE.match(line):
            continue                       # a definition row is not a citation of itself
        snippet = s[:110]
        if in_fence and not count_code:
            for k in keys_in(line):
                mentions.setdefault(k, []).append((path, i, snippet))
            continue
        if count_code:
            prose, code = line, ""
        else:
            prose = CODE_SPAN_RE.sub(" ", line)
            code = " ".join(CODE_SPAN_RE.findall(line))
        for k in keys_in(prose):
            used.setdefault(k, []).append((path, i, snippet))
        for k in malformed_in(prose):
            malformed.setdefault(k, []).append((path, i, snippet))
        for k in keys_in(code):
            mentions.setdefault(k, []).append((path, i, snippet))


def scan_defs(path, lines, defined):
    """🟥 v8 (codex round 7): a `| [KEY] |` row INSIDE a code fence is code, not a definition — v7 counted
    it, so a key whose only «definition» was a quoted table read as defined."""
    fence = None
    for i, line in enumerate(lines, 1):
        fence, on_fence = _fence_step(line, fence)
        if on_fence or fence is not None:
            continue
        m = DEF_ROW_RE.match(line)
        if m:
            defined.setdefault(m.group(1), []).append((path, i))


def near_miss_pairs(phantom, orphan, used, defined):
    problematic = set(phantom) | set(orphan)
    pool = set(used) | set(defined)
    pairs = {}
    for x in sorted(problematic):
        for y in sorted(pool):
            if y == x or letters(x) != letters(y):
                continue
            a, b = sorted((x, y))
            pairs[(a, b)] = True
    return sorted(pairs)


def role(k, phantom, orphan, used, defined):
    tags = []
    if k in phantom:
        tags.append("PHANTOM")
    if k in orphan:
        tags.append("ORPHAN")
    if not tags:
        tags.append("ok")
    if k in used:
        tags.append("used ×%d" % len(used[k]))
    if k in defined:
        tags.append("defined %s" % ", ".join("%s:%d" % (os.path.basename(f), n) for f, n in defined[k]))
    return " · ".join(tags)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--body", nargs="+", required=True, metavar="MD", help="body file(s) whose citations are checked")
    ap.add_argument("--refs", nargs="*", default=[], metavar="MD",
                    help="file(s) carrying the references table (`| [KEY] | … |`); definition rows found in --body files count too")
    ap.add_argument("--strict-orphans", action="store_true", help="a defined-but-unused key fails (rc=2)")
    ap.add_argument("--count-code", action="store_true", help="keys inside code spans / fences count as usages, not mentions")
    ap.add_argument("--no-near-miss", action="store_true", help="disable NEAR-MISS pairing (ablation / revert probe)")
    ap.add_argument("--no-malformed", action="store_true",
                    help="ABLATION ONLY: skip MALFORMED keys (`[BAD–26]`) — the v2 arm, where they read as clean")
    ap.add_argument("--max-sites", type=int, default=6, help="usage sites printed per phantom key (0 = all)")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    files = {}
    for p in list(args.body) + list(args.refs):
        if p in files:
            continue
        lines, err = load(p)
        if lines is None:
            print("🟥 cannot read %s: %s" % (p, err), file=sys.stderr)
            return 10
        files[p] = lines

    used, mentions, defined, malformed = {}, {}, {}, {}
    for p in args.body:
        scan_body(p, files[p], args.count_code, used, mentions, malformed)
    if args.no_malformed:
        malformed = {}
    for p in dict.fromkeys(list(args.refs) + list(args.body)):
        scan_defs(p, files[p], defined)

    if not defined:
        print("🟥 0 definition rows parsed from %s — wrong file or wrong shape (expected a table row whose FIRST "
              "cell is `[KEY]`). %d usage(s) of %d key(s) were seen and are NOT reported as phantom. rc=10"
              % (", ".join(args.refs) if args.refs else "the body (no --refs given)",
                 sum(len(v) for v in used.values()), len(used)))
        return 10
    n_usages = sum(len(v) for v in used.values())
    n_ment = sum(len(v) for v in mentions.values())
    if n_usages == 0 and not malformed:
        print("⬜ DEAD CONTROL — 0 citation usages in %d body file(s) (%d line(s) read; %d mention(s) in code spans "
              "not counted); %d definition(s) present but NOTHING was checked. rc=4 (not a clean check)."
              % (len(args.body), sum(len(files[p]) for p in args.body), n_ment, len(defined)))
        return 4

    phantom = sorted(k for k in used if k not in defined)
    orphan = sorted(k for k in defined if k not in used)
    dup = sorted(k for k, sites in defined.items() if len(sites) > 1)
    mention_only = sorted(k for k in mentions if k not in used and k not in defined)
    bad = sorted(malformed)
    pairs = [] if args.no_near_miss else near_miss_pairs(phantom, orphan, used, defined)
    rc = 1 if (phantom or dup or bad) else (2 if (orphan and args.strict_orphans) else 0)

    if args.json:
        print(json.dumps({
            "body": args.body, "refs": args.refs,
            "count_code": args.count_code, "near_miss_enabled": not args.no_near_miss,
            "used": {k: [{"file": f, "line": n, "snippet": s} for f, n, s in v] for k, v in sorted(used.items())},
            "mentions": {k: [{"file": f, "line": n} for f, n, _ in v] for k, v in sorted(mentions.items())},
            "defined": {k: [{"file": f, "line": n} for f, n in v] for k, v in sorted(defined.items())},
            "phantom": phantom, "orphan": orphan, "dup_def": dup, "mention_only": mention_only,
            "malformed": {k: [{"file": f, "line": n, "snippet": s} for f, n, s in v] for k, v in sorted(malformed.items())},
            "near_miss": [{"a": a, "b": b, "a_role": role(a, phantom, orphan, used, defined),
                           "b_role": role(b, phantom, orphan, used, defined)} for a, b in pairs],
            "summary": {"usages": n_usages, "used_distinct": len(used), "defined": len(defined),
                        "mentions": n_ment, "phantom": len(phantom), "orphan": len(orphan),
                        "near_miss": len(pairs), "dup_def": len(dup), "mention_only": len(mention_only),
                        "malformed": len(bad), "rc": rc},
        }, ensure_ascii=False, indent=1))
        return rc

    print("citation-key check · body=%d file%s (%d usages · %d distinct keys) · refs=%s (%d definitions) · mentions in code=%d%s"
          % (len(args.body), "" if len(args.body) == 1 else "s", n_usages, len(used),
             ", ".join(args.refs) if args.refs else "(body rows)", len(defined), n_ment,
             " (counted as usages: --count-code)" if args.count_code else ""))
    print("  mechanisms: near-miss=%s · code-spans=%s · strict-orphans=%s · malformed=%s"
          % ("off" if args.no_near_miss else "on", "usage" if args.count_code else "mention",
             "on" if args.strict_orphans else "off", "off (ABLATION)" if args.no_malformed else "on"))
    for k in bad:
        sites = malformed[k]
        print("  🟥 MALFORMED  [%s]  cited ×%d — %s — citation-shaped but not a key (dash/underscore between letters and year); no row can match it"
              % (k, len(sites), " · ".join("%s:%d" % (os.path.basename(f), n) for f, n, _ in sites[:args.max_sites or None])))
        print("       …%s…" % sites[0][2])
    for k in phantom:
        sites = used[k]
        shown = sites if args.max_sites == 0 else sites[:args.max_sites]
        where = " · ".join("%s:%d" % (os.path.basename(f), n) for f, n, _ in shown)
        more = "" if len(shown) == len(sites) else " (+%d more)" % (len(sites) - len(shown))
        print("  🟥 PHANTOM    [%s]  used ×%d — %s%s" % (k, len(sites), where, more))
        print("       …%s…" % sites[0][2])
    for k in dup:
        print("  🟥 DUP-DEF    [%s]  defined ×%d — %s" % (k, len(defined[k]),
              " · ".join("%s:%d" % (os.path.basename(f), n) for f, n in defined[k])))
    for k in orphan:
        ment = mentions.get(k, [])
        print("  🟨 ORPHAN     [%s]  defined %s, used ×0%s" % (
            k, " · ".join("%s:%d" % (os.path.basename(f), n) for f, n in defined[k]),
            (" (mentioned ×%d in code: %s)" % (len(ment), " · ".join("%s:%d" % (os.path.basename(f), n) for f, n, _ in ment[:3]))) if ment else ""))
    for a, b in pairs:
        print("  🟧 NEAR-MISS  [%s] (%s) ↔ [%s] (%s) — same letters, different key"
              % (a, role(a, phantom, orphan, used, defined), b, role(b, phantom, orphan, used, defined)))
    for k in mention_only:
        ment = mentions[k]
        print("  ⬜ MENTION-ONLY [%s]  undefined, appears only in code spans ×%d — %s (not a citation; --count-code to count it)"
              % (k, len(ment), " · ".join("%s:%d" % (os.path.basename(f), n) for f, n, _ in ment[:3])))
    if phantom:
        print("ⓘ a PHANTOM key has no row a reader can resolve — this is the class that got the sister paper rejected.")
    if orphan and not args.strict_orphans:
        print("ⓘ ORPHAN keys are listed, not counted (rc unaffected) — --strict-orphans to count them.")
    print("citation-key verdict: PHANTOM=%d ORPHAN=%d NEAR-MISS=%d DUP-DEF=%d MENTION-ONLY=%d MALFORMED=%d rc=%d"
          % (len(phantom), len(orphan), len(pairs), len(dup), len(mention_only), len(bad), rc))
    return rc


if __name__ == "__main__":
    sys.exit(main())
