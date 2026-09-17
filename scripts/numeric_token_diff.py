#!/usr/bin/env python3
"""numeric_token_diff.py — did a rewrite / shrink pass DROP a number, or INVENT one?

WHAT IT CLOSES (measured 2026-09-17, paper-2 DRAFT → SUBMISSION shrink)
  A shrink pass rewrites prose, and a number that lived only in a deleted sentence leaves with it —
  silently, because nothing diffs the NUMBERS of two documents, only their lines. The governor did
  this by hand with ad-hoc python. This tool extracts the MULTISET of numeric tokens on each side and
  names every token that is only-in-before (DROPPED / REDUCED) or only-in-after (INVENTED /
  INCREASED), with its count on both sides and the first line it appears on.

WHAT IT DOES NOT DO — read before trusting a 0
  🟥 It compares TOKENS, not claims. `92.6%` surviving the rewrite does not mean it still says what
     it said; a number that moved from one claim to another is invisible here. Identity of form only.
  🟥 `0.80` and `0.8` are DIFFERENT tokens (precision is content); `2,880` and `2880` are the SAME
     (thousands separators are stripped). `95 %`, `95%`, `95 %` (NBSP) are one token `95%`.
  🟥 Section numbers are NOT numbers: `§3.2`, `§3.1–3.2`, `Sec. 9.4`, `Section 3`, `섹션 8.1`, `3.2절`,
     `부록 8`, `Appendix 3`, `K.2`, `A.6.2.7`, a heading's own numbering (`### 4.2 …`) and a list
     marker (`1. `) are blanked BEFORE extraction — those are section_ref_check.py's domain (same
     cross-reference grammar). Version-like strings (`2.7.1`, `12.7.3`) yield nothing by the
     digit-boundary rule below.
  🟥 A number glued to a Latin letter (`v3`, `F_r2ctrl`, `A26`) is an identifier, not a claim, and is
     skipped. A HYPHENATED CHAIN is judged as a whole (`--hyphen-rule word`, default): a chain that
     carries a Latin letter anywhere is an identifier and sheds NO token (`s43681-022-00171-7`,
     `GHSA-2026-1234`, `A-6`, `PREREG_ADDENDUM_2026-09-10`); a chain of pure digits is a RANGE and
     keeps EVERY segment (`3-5` → 3 and 5, `12-25` → 12 and 25, `40-75` → 40 and 75), so a shrink pass
     that erases the upper bound is a DROPPED, not a silent identical. 🟥 The 2026-09-17 rule blocked
     any `<alnum>-` before a number — measured by cross-family review (codex) as a silent false
     negative: «range 3-5 only» → «range 3 only» was IDENTICAL rc=0. It survives only as the ablation
     arm `--hyphen-rule alnum`. `100-1` (NIST AI 100-1) is now two tokens — the price of the fix.
     A number after a Hangul syllable (`8케이스`, `제3장`) is kept. `.5` (leading-dot decimal) is kept
     as `5`. A SIGN glued to the number is part of it (`−196` · `-196` · `–196` → `-196`) when nothing
     word-like precedes it — so `−196` → `196` is a DROPPED + INVENTED pair, not IDENTICAL (v19; codex
     round 17 fixture, silent in v1–v18 and documented as such — the reader sees the sign). `3-5` is
     still a range (the `-` follows a digit); `- 196` (a list marker) is not a sign. Ablation arm:
     `--no-sign`. Numbers inside code spans / fences ARE
     tokens (a DOI or a quoted `p<0.001` that disappears is still a drop).
  🟥 Multiset semantics by default: a common small integer (`3`) that appears 12× before and 9×
     after is reported as REDUCED. That is correct and noisy — `--distinct` compares sets instead
     (a token is DROPPED only when it vanishes entirely), and `--allow` justifies specific tokens.

DIGIT BOUNDARY (the discipline of scripts/claim_propagation_scan.py `compile_token`, applied to
extraction): a token may not be preceded by a digit, `digit.` or `digit,`, and may not be followed
by a digit, `.digit` or `,ddd`. So `2.7` is never produced from `2.75` or `12.7` (greedy match) and
nothing is produced from `2.7.1` or `12.7.3` (every start position is either digit-dot-preceded or
dot-digit-followed). `--no-digit-boundary` removes the lookarounds (ablation / revert probe): then
`2.7.1` yields `2.7` and `1`, `12.7.3` yields `12.7` and `3`, and `2,880` also sheds `880`.

TOKEN FORMS   2880 · 2.7 · 92.6% · 12/12 · p=0.019 · p<0.001 · n=6 · 2026-09-12 (a date is one token)

ALLOW FILE    one `token<TAB>reason` per line, `#` comments. A line WITHOUT a reason is rejected
              (rc=10) — an allow entry is a decision, and a bare token is a silencer.

EXIT CODES
   0  identical multisets (or every difference allowed)
   1  a token was DROPPED or REDUCED (before > after) — possibly with INVENTED ones too
   2  only INVENTED / INCREASED tokens (after > before)
   4  DEAD CONTROL: BOTH sides yield zero numeric tokens — distinct from 0 on purpose
  10  input error (file missing · allow file rejected)

USAGE
  python3 scripts/numeric_token_diff.py --before <md...> --after <md...> [--allow <tsv>] [--distinct]
                                        [--limit N] [--hyphen-rule word|alnum|off]
                                        [--no-digit-boundary] [--json]
  bash    scripts/test_paper_integrity_lanes.sh          # known pairs + revert probes
Python ≥ 3.9, stdlib only.
"""
import argparse
import json
import re
import sys
from collections import Counter

WS = "[\\s   ]*"
NUM = r"\d{1,3}(?:,\d{3})+(?:\.\d+)?|\d+(?:\.\d+)?"
PREFIX = r"(?:(?P<pre>p|n|N|k|CI|df|α|β)" + WS + r"(?P<op>=|<|>|≤|≥|≈)" + WS + r")?"
# v19 (codex round 17 fixture): a sign glued to the number — ASCII hyphen-minus, U+2212 MINUS, U+2013 EN DASH —
# is part of the token ONLY when what precedes it is nothing, whitespace, an opening bracket, or an operator —
# so `3-5` / `3–5` stay ranges, `x-5` stays an identifier, and a truncated DOI `…-00191-3` (the real paper,
# measured) stays the fragment `00191` it was; `(?=\d)` keeps a list marker `- 196` and a spaced dash `– 5` out.
SIGN = r"(?P<sign>(?<![^\s(\[{=<>≤≥≈:;,|/])[-−–](?=\d))?"
TAIL = r"(?:" + WS + r"(?P<pct>%)|/(?P<den>\d+(?:\.\d+)?)(?!\d)(?!\.\d))?"
# Left boundary: not glued to a Latin letter or digit, not `digit.` / `digit,` (a fraction or
# thousands tail). Right boundary: not followed by a digit, `.digit` or `,ddd`.
LEFT = r"(?<![A-Za-z\d])(?<!\d\.)(?<!\d,)"
LEFT_ALNUM_HYPHEN = r"(?<![A-Za-z0-9]-)"     # the 2026-09-17 rule — ablation arm only (see header)
RIGHT = r"(?!\d)(?!\.\d)(?!,\d{3})"
DATE = r"(?P<date>\d{4}-\d{2}-\d{2})(?!\d)"
EXP = r"(?P<exp>[eE][+-]?\d+(?![A-Za-z])|[⁰¹²³⁴⁵⁶⁷⁸⁹⁻⁺]+|\^[+-]?\d+)?"
SUPER = str.maketrans("⁰¹²³⁴⁵⁶⁷⁸⁹⁻⁺", "0123456789-+")
FULLWIDTH = str.maketrans("０１２３４５６７８９％．，＋－", "0123456789%.,+-")
SCI_CHAIN_RE = re.compile(r"^\d+(?:\.\d+)?[eE][+-]?\d+$")
HEADING_NUM_RE = re.compile(r"^(#{1,6}\s+)(?:§\s*)?(?:\d+(?:\.\d+)*(?:-?[a-z])?[.)]?|[A-Z](?:\.\d+)+|(?:부록|Appendix)\s*\S+)(?=\s|$)")
LIST_RE = re.compile(r"^(\s*)\d+[.)]\s")
# Cross-references are section_ref_check.py's domain — removed BEFORE extraction so `§3.1–3.2`,
# `Sec. 9.4`, `섹션 8.1`, `3.2절`, `부록 8`, `Appendix K.2`, `A.6.2.7` never shed a numeric token
# (same grammar as that tool).
SECTION_PREFIXES = ("§", "Sections", "Section", "sections", "section", "Sec.", "Sec", "섹션")   # in step with section_ref_check.py (v6)
XREF_RE = re.compile(
    r"(?<![A-Za-z])(?:" + "|".join(re.escape(p) for p in SECTION_PREFIXES) + r")"
    r"\s*\d+(?:\.\d+)*(?:-?[a-z])?(?:(?:\s*[~–]\s*§?|\s*[—-]\s*§)\s*\d+(?:\.\d+)*(?:-?[a-z])?)?"
    r"|(?<![\d.A-Za-z])\d+(?:\.\d+)*(?:-?[a-z])?절"
    r"|(?:부록|Appendix|APPENDIX|appendix)\s*(?:\d+|[A-Z])(?:\.\d+(?:\.\d+)*)?(?![A-Za-z0-9])"
    r"|(?<![A-Za-z0-9.§])[A-Z]\.\d+(?:\.\d+)*(?![A-Za-z0-9])")
# `word` hyphen rule: a hyphenated chain is judged as a whole.
HYPHEN_CHAIN_RE = re.compile(r"(?<![A-Za-z0-9_])[A-Za-z0-9_]+(?:-[A-Za-z0-9_]+)+(?![A-Za-z0-9_])")
LATIN_RE = re.compile(r"[A-Za-z]")


def build_regex(boundary, hyphen_rule, sign=True):
    left = LEFT if boundary else r"(?<![A-Za-z])"
    if hyphen_rule == "alnum":
        left += LEFT_ALNUM_HYPHEN
    right = RIGHT if boundary else r""
    # v13 (codex round 12): an EXPONENT is part of the number — `2e6`, `2.5E-3`, `10⁶`, `10⁻³`, `10^6` — so a
    # changed magnitude is a changed token (v12 reduced `2e6` and `2e5` both to `2`).
    # v19: a glued sign is part of the number (`--no-sign` = the v1–v18 reading, ablation arm).
    sgn = SIGN if sign else r"(?P<sign>)"
    return re.compile(left + r"(?:" + DATE + r"|" + PREFIX + sgn + r"(?P<num>" + NUM + r")" + EXP + right + TAIL + r")")


def normalise(m):
    if m.group("date"):
        return m.group("date")
    num = m.group("num").replace(",", "")
    if m.group("exp"):
        e = m.group("exp")
        num += ("e" + e[1:].lstrip("+")) if e[0] in "eE" else ("^" + e.translate(SUPER).lstrip("^").lstrip("+"))
    tok = ("-" + num) if m.group("sign") else num
    if m.group("pre"):
        tok = m.group("pre") + m.group("op") + num
    if m.group("pct"):
        tok += "%"
    elif m.group("den"):
        tok += "/" + m.group("den")
    return tok


def blank(m):
    return " " * (m.end() - m.start())


def strip_structure(line, hyphen_rule):
    """Remove a heading's own numbering, a list marker, every cross-reference and (word rule) every
    letter-bearing hyphenated chain — structure and identifiers, not claims. Replacement is by
    equal-length blanks so match offsets still index the original line."""
    m = HEADING_NUM_RE.match(line)
    if m:
        line = line[:len(m.group(1))] + " " * (m.end() - len(m.group(1))) + line[m.end():]
    m = LIST_RE.match(line)
    if m:
        line = " " * m.end() + line[m.end():]
    line = XREF_RE.sub(blank, line)
    if hyphen_rule == "word":
        line = HYPHEN_CHAIN_RE.sub(lambda x: blank(x) if LATIN_RE.search(x.group(0)) and not SCI_CHAIN_RE.match(x.group(0)) else x.group(0), line)
    return line


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


def extract(paths, rx, hyphen_rule):
    """→ (Counter of tokens, {token: (file, line, snippet) first site}, lines read) — rc=10 shape on error."""
    counts, first, n_lines = Counter(), {}, 0
    for p in paths:
        try:
            with open(p, encoding="utf-8", errors="replace") as fh:
                # a number moved INTO a comment has been dropped from the reader's view (loud)
                lines = strip_html_comments(fh.read()).split("\n")
        except OSError as e:
            return None, "cannot read %s: %s" % (p, e), 0
        n_lines += len(lines)
        for i, raw in enumerate(lines, 1):
            # v17 (codex round 16): full-width digits / percent / dot / comma are the reader's ASCII ones
            # (`９２.６％` = `92.6%`). A per-character map, NOT NFKC — NFKC would also fold `10⁶` to `106`.
            raw = raw.translate(FULLWIDTH)
            line = strip_structure(raw, hyphen_rule)
            for m in rx.finditer(line):
                tok = normalise(m)
                counts[tok] += 1
                if tok not in first:
                    a = max(0, m.start() - 45)
                    first[tok] = (p, i, raw[a:m.end() + 45].strip())
    return counts, first, n_lines


def read_allow(path):
    """→ ({token: reason}, error-or-None). A bare token (no TAB / empty reason) is an error."""
    allow = {}
    try:
        with open(path, encoding="utf-8") as fh:
            for n, raw in enumerate(fh, 1):
                line = raw.rstrip("\n")
                if not line.strip() or line.lstrip().startswith("#"):
                    continue
                if "\t" not in line:
                    return None, "allow file %s:%d — bare token with no reason (expected token<TAB>reason): %r" % (path, n, line)
                tok, reason = line.split("\t", 1)
                tok = tok.strip().replace(",", "").replace(" ", "")
                if not tok or not reason.strip():
                    return None, "allow file %s:%d — empty token or empty reason: %r" % (path, n, line)
                allow[tok] = reason.strip()
    except OSError as e:
        return None, "cannot read allow file %s: %s" % (path, e)
    return allow, None


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--before", nargs="+", required=True, metavar="MD")
    ap.add_argument("--after", nargs="+", required=True, metavar="MD")
    ap.add_argument("--allow", metavar="TSV", help="token<TAB>reason per line — justified differences")
    ap.add_argument("--distinct", action="store_true", help="set semantics: only tokens that vanish / appear entirely")
    ap.add_argument("--limit", type=int, default=0, help="rows printed per class (0 = all)")
    ap.add_argument("--hyphen-rule", choices=["word", "alnum", "off"], default="word",
                    help="word (default): a letter-bearing hyphen chain is an identifier, a pure-digit chain is a range · "
                         "alnum: the 2026-09-17 rule, any <alnum>- blocks the number (ABLATION — silent on `3-5` → `3`) · "
                         "off: no hyphen handling (DOI suffixes shed fragments)")
    ap.add_argument("--no-digit-boundary", action="store_true", help="drop the digit-boundary lookarounds (ablation / revert probe)")
    ap.add_argument("--no-sign", action="store_true", help="the v1–v18 reading: a glued sign is not part of the number (ablation — silent on `−196` → `196`)")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    rx = build_regex(not args.no_digit_boundary, args.hyphen_rule, not args.no_sign)
    allow = {}
    if args.allow:
        allow, err = read_allow(args.allow)
        if err:
            print("🟥 " + err, file=sys.stderr)
            return 10
    b_counts, b_first, b_lines = extract(args.before, rx, args.hyphen_rule)
    if b_counts is None:
        print("🟥 " + b_first, file=sys.stderr)
        return 10
    a_counts, a_first, a_lines = extract(args.after, rx, args.hyphen_rule)
    if a_counts is None:
        print("🟥 " + a_first, file=sys.stderr)
        return 10

    nb, na = sum(b_counts.values()), sum(a_counts.values())
    if nb == 0 and na == 0:
        print("⬜ DEAD CONTROL — 0 numeric tokens on BOTH sides (before: %d line(s), after: %d line(s)); nothing was compared. rc=4 (not identical)."
              % (b_lines, a_lines))
        return 4

    dropped, reduced, invented, increased, allowed = [], [], [], [], []
    for tok in sorted(set(b_counts) | set(a_counts)):
        b, a = b_counts.get(tok, 0), a_counts.get(tok, 0)
        if b == a:
            continue
        if tok in allow:
            allowed.append((tok, b, a, allow[tok]))
            continue
        if a == 0:
            dropped.append((tok, b, a))
        elif b == 0:
            invented.append((tok, b, a))
        elif not args.distinct:
            (reduced if b > a else increased).append((tok, b, a))
    unused_allow = sorted(t for t in allow if b_counts.get(t, 0) == a_counts.get(t, 0))
    for lst in (dropped, reduced, invented, increased):
        lst.sort(key=lambda t: (-abs(t[1] - t[2]), t[0]))
    rc = 1 if (dropped or reduced) else (2 if (invented or increased) else 0)

    def site(tok, side):
        f, n, s = (b_first if side == "b" else a_first)[tok]
        return "%s:%d: %s" % (f.split("/")[-1], n, s)

    if args.json:
        print(json.dumps({
            "before": args.before, "after": args.after, "distinct": args.distinct,
            "digit_boundary": not args.no_digit_boundary, "hyphen_rule": args.hyphen_rule, "sign": not args.no_sign, "allow": args.allow,
            "stats": {"before": {"tokens": nb, "distinct": len(b_counts), "lines": b_lines},
                      "after": {"tokens": na, "distinct": len(a_counts), "lines": a_lines}},
            "dropped": [{"token": t, "before": b, "after": a, "first": site(t, "b")} for t, b, a in dropped],
            "reduced": [{"token": t, "before": b, "after": a, "first_before": site(t, "b")} for t, b, a in reduced],
            "invented": [{"token": t, "before": b, "after": a, "first": site(t, "a")} for t, b, a in invented],
            "increased": [{"token": t, "before": b, "after": a, "first_after": site(t, "a")} for t, b, a in increased],
            "allowed": [{"token": t, "before": b, "after": a, "reason": r} for t, b, a, r in allowed],
            "unused_allow": unused_allow,
            "summary": {"dropped": len(dropped), "reduced": len(reduced), "invented": len(invented),
                        "increased": len(increased), "allowed": len(allowed), "rc": rc},
        }, ensure_ascii=False, indent=1))
        return rc

    print("numeric-token diff · before=%d file%s (%d lines · %d tokens · %d distinct) · after=%d file%s (%d lines · %d tokens · %d distinct)"
          % (len(args.before), "" if len(args.before) == 1 else "s", b_lines, nb, len(b_counts),
             len(args.after), "" if len(args.after) == 1 else "s", a_lines, na, len(a_counts)))
    print("  mechanisms: digit-boundary=%s · hyphen-rule=%s · sign=%s · semantics=%s · allow=%s"
          % ("off" if args.no_digit_boundary else "on", args.hyphen_rule, "off" if args.no_sign else "on",
             "distinct" if args.distinct else "multiset",
             ("%s (%d entries)" % (args.allow, len(allow))) if args.allow else "(none)"))
    if nb == 0 or na == 0:
        print("  ⚠️  one side yielded 0 tokens (before=%d, after=%d) — an empty side is a suspicious input, not a clean diff" % (nb, na))

    def show(label, glyph, rows, side):
        shown = rows if args.limit == 0 else rows[:args.limit]
        for t, b, a in shown:
            print("  %s %-9s %-16s before ×%-3d → after ×%-3d  %s" % (glyph, label, t, b, a, site(t, side)))
        if len(shown) < len(rows):
            print("  … %d more %s row(s) (--limit 0 for all)" % (len(rows) - len(shown), label))

    show("DROPPED", "🟥", dropped, "b")
    show("REDUCED", "🟧", reduced, "b")
    show("INVENTED", "🟦", invented, "a")
    show("INCREASED", "🟦", increased, "a")
    for t, b, a, r in allowed:
        print("  ⬜ ALLOWED   %-16s before ×%-3d → after ×%-3d  reason: %s" % (t, b, a, r))
    for t in unused_allow:
        print("  ⚠️  UNUSED-ALLOW %-13s no difference on this token — the allow entry is stale" % t)
    if rc == 0:
        print("ⓘ IDENTICAL numeric multisets — %d tokens (%d distinct) on each side%s."
              % (nb, len(b_counts), " after %d allowed difference(s)" % len(allowed) if allowed else ""))
    print("numeric-diff verdict: DROPPED=%d REDUCED=%d INVENTED=%d INCREASED=%d ALLOWED=%d rc=%d"
          % (len(dropped), len(reduced), len(invented), len(increased), len(allowed), rc))
    return rc


if __name__ == "__main__":
    sys.exit(main())
