#!/usr/bin/env python3
"""section_ref_check.py — every §N / Sec. N / 섹션 N / N절 / 부록 N / Appendix X / K.n cross-reference resolves to a heading.

WHAT IT CLOSES (measured 2026-09-17, paper-2 draft)
  A paper renumbers its sections during a rewrite and the cross-references keep the old numbers; a
  section is deleted and `§3.7` still points at it; a pointer says «부록 3 §10» and no such thing
  exists (the draft itself records one of these: «초판이 「부록 3 §10」이라고 적었고 그 번호는
  없다»). The governor checked this by hand. This tool parses every heading (`#`…`######`) into an
  anchor and every cross-reference in the body into a key, and names each ref that does not resolve,
  with its line — DANGLING (parent exists) is kept apart from DANGLING (no such top-level), because
  the first is usually a missing sub-heading and the second a wrong number.

WHAT IT DOES NOT DO — read before trusting a 0
  🟥 Heading-defined anchors ONLY. A paper that defines «부록 1…7» in a pointer TABLE, or a
     numbered paragraph without a heading, is reported DANGLING for those refs. That is a finding
     about the paper's shape, not a false positive — but `--define '부록 1'` declares such an anchor
     explicitly (printed in the header, never implicit).
  🟥 A ref into ANOTHER document («RESULT §12», «Workbook 부록 B») is DANGLING here by construction:
     this tool sees one corpus. `--external REGEX` classifies a ref whose same-line ±80-char window
     matches REGEX as EXTERNAL — listed, not counted — and the regex is printed. Off by default:
     the loud direction is the safe one, and the snippet beside each DANGLING row shows the context.
  🟥 Exact key match. `§3.2` does not resolve to `### 3.2b`, `K.2` does not resolve to `## Appendix K`
     — both are DANGLING (parent exists). `--parent-resolves` makes any ref with an existing ancestor
     resolve: ABLATION ONLY (revert probe); it turns the instrument into «the chapter exists».
  🟥 Only the spellings listed under GRAMMAR are refs — that list is GENERATED from the regex source,
     so it cannot drift from what is scanned. A spelling outside it (`Sect. 3`, `chapter 3`, `제3장`)
     is not scanned and does not dangle; cross-family review (codex, 2026-09-17) found `Sec. 9.4` /
     `Section 3.2` / `섹션 8.1` outside the first version's grammar, so a body written that way was
     rc=0 without a single ref read. `--no-alt-spellings` reproduces that arm (ABLATION ONLY).
     `N절` with a bare integer is ambiguous with a count: `0절` is never a ref (sections are 1-based;
     «관련연구 0절로» measured as a count), `3절로 나눴다` still reads as §3 — loud direction.
  🟥 Refs are read from body lines that are not headings, code fences included (a fenced quote that
     cites a section is still a pointer a reader will follow). `§F_r2ctrl`-style tokens (no digit
     after §) are not refs. `§4-1` reads as `§4` and `§3.2 — 0.017` as `§3.2` (a range needs `~` or
     an EN dash, or a second `§` after a hyphen / EM dash: `§12~§21` · `§3.1–3.2` · `§3 — §4`).

GRAMMAR
  heading  `## 3. Method` · `### 4.2 …` · `#### 9.4.1 …` · `### 2.3b …` · `### §3.3-b …` · `## 부록 8 —`
           · `## Appendix K` · `### K.2 …` · `## A.6 …`      (an unnumbered heading defines nothing)
  ref      {SPELLINGS}
           · `부록 8` `부록 B` `Appendix K` `Appendix 3` · `K.2` `A.6.2.7` (a capital letter, a dot,
           digits — not preceded by a letter)
  map      `--map 3=4,3.3=1.5,부록 3=부록 A` — a ref still under an OLD number is STALE-OLD (rc=1),
           whether or not the old number happens to resolve today.

EXIT CODES
   0  every ref resolves (EXTERNAL refs listed, not counted)
   1  DANGLING or STALE-OLD refs present
   4  DEAD CONTROL: zero cross-references found — distinct from 0 on purpose (headings are printed)
  10  input error (file missing · zero numbered headings, so every ref would dangle — not a verdict)

USAGE
  python3 scripts/section_ref_check.py --body <md...> [--define REF ...] [--external REGEX]
                                       [--map old=new,...] [--show-resolved] [--list-headings] [--json]
  bash    scripts/test_paper_integrity_lanes.sh          # known pairs + revert probes
Python ≥ 3.9, stdlib only.
"""
import argparse
import json
import re
import sys
import unicodedata

APP = r"(?:부록|Appendix|APPENDIX|appendix)"
NUMKEY = r"\d+(?:\.\d+)*(?:-?[a-z])?"
# ── Section spellings: ONE source. The prefix tuple builds the regexes AND the printed list. ────
# Longest first inside the alternation (`Section` before `Sec.` before `Sec`).
# v6 (codex round 5): plural / lowercase English forms were outside the grammar, so `sections 3.1 - 3.3`
# was not even scanned. Longest first inside the alternation (`Sections` before `Section`).
SECTION_PREFIXES = ("§", "Sections", "Section", "sections", "section", "Sec.", "Sec", "섹션")
SECTION_SUFFIXES = ("절",)          # `3.2절` — digits glued to the suffix, no space
RANGE_EXAMPLES = ("§12~§21", "§3.1–3.2", "§3 — §4", "Section 1.1-1.3")
RANGE_INTERIOR_CAP = 50             # `§1~§999` is not expanded — a cap, printed when hit


def section_prefix_regex(prefixes):
    return r"(?<![A-Za-z])(?:" + "|".join(re.escape(p) for p in prefixes) + r")"


def build_ref_regexes(alt_spellings, compact_range=True):
    """→ (section_re, suffix_re_or_None). `alt_spellings=False` keeps only `§` (ablation arm);
    `compact_range=False` drops the `1.1-1.3` ASCII-hyphen form (ablation arm)."""
    prefixes = SECTION_PREFIXES if alt_spellings else ("§",)
    # A range is `§12~§21` / `§3.1–3.2` (tilde or EN dash, optional second §) or `§3 - §4` /
    # `§3 — §4` (hyphen / EM dash ONLY when a second § follows). `§3.2 — 0.017` is a section
    # followed by a number, not a range — measured on the 2026-09-17 draft («§0.017»).
    # 🟥 v3 (codex round 2, 2026-09-18): `Section 1.1-1.3` — a COMPACT ASCII hyphen straight into a
    # digit — was read as `§1.1` alone, so a missing upper endpoint was silent. It is a range only when
    # both sides share the same parent and ascend (`1.1-1.3` yes · `2026-09-10` no — refs_in() enforces that).
    # 🟥 v6 (codex round 5): the SPACED ASCII hyphen `Section 3.1 - 3.3` was outside that form and read
    # as `§3.1` alone. Spaces around the hyphen are now allowed; the same-parent + ascending guard is what
    # keeps `§3.2 - 0.017` (parent 3 vs 0) a section followed by a number. EM/EN dashes are unchanged.
    # v14 (codex round 13): prose ranges `Sections 6.1 through 6.3` · `§3.1 to 3.3` go through the same expansion
    range_forms = r"\s*[~–]\s*§?|\s*[—-]\s*§|\s+(?:through|thru|to)\s+§?" + (r"|\s*-\s*(?=\d)" if compact_range else "")
    # v16 (codex round 15): ONE range tail — numeric second end, or a suffix-only second end (`3.2a-c`) — shared by
    # the primary ref, the slash continuation and the plural-list continuation, so a shorthand that the primary
    # ref reads is read in every position.
    range_tail = (r"(?:(?:(?:" + range_forms + r")\s*(?P<num2>\d+(?:\.\d+)*)(?P<suf2>-?[a-z])?|\s*[-–]\s*(?P<suf2o>[a-z]))"
                  r"(?![A-Za-z0-9])(?!\.\d))?")
    section_re = re.compile(
        section_prefix_regex(prefixes)
        + r"\s*(?P<num>\d+(?:\.\d+)*)(?P<suf>-?[a-z])?(?![A-Za-z0-9])(?!\.\d)" + range_tail)
    # (v15, codex round 14: `§3.2a-c` — a suffix-only second endpoint means «same number, that suffix»)
    # v9 (codex round 8): a slash continuation may itself carry a range — `§3.1/3.2-3.4` names §3.3 too;
    # v10 (round 9): spaces around the slash (`§3.1 / 3.2`) are allowed
    slash_re = re.compile(r"\s*/\s*(?P<num>\d+(?:\.\d+)*)(?P<suf>-?[a-z])?(?![A-Za-z0-9])(?!\.\d)" + range_tail)
    # v11 (codex round 10): after a PLURAL prefix (`Sections 3.1 and 3.2` · `sections 3.1, 3.2 and 3.4-3.6`)
    # the list continues — comma / semicolon / and / or / & / 및, Oxford `, and` too (v13·v14) — each item through the same range grammar. Singular
    # prefixes do not continue (`§3.1, 12 cases` names no §12).
    cont_re = re.compile(
        r"(?:\s*[,;]\s*(?:and\s+|or\s+|&\s*|및\s*)?|\s+(?:and|or)\s+|\s*&\s*|\s*및\s*)(?P<num>\d+(?:\.\d+)*)(?P<suf>-?[a-z])?(?![A-Za-z0-9])(?!\.\d)"
        + range_tail)
    suffix_re = None
    if alt_spellings:
        # `N절` with a bare integer is ambiguous with a COUNT («관련연구 0절로 내는 것» = zero sections,
        # measured on the 2026-09-17 prior-art section). Sections are 1-based, so a leading 0 is never
        # a ref; a count with N ≥ 1 («3절로 나눴다») still reads as a ref — loud direction, the snippet
        # beside the row settles it.
        suffix_re = re.compile(r"(?<![\d.A-Za-z])(?P<num>(?!0)\d+(?:\.\d+)*)(?P<suf>-?[a-z])?(?:"
                               + "|".join(re.escape(s) for s in SECTION_SUFFIXES) + r")")
    return section_re, suffix_re, slash_re, cont_re


def spellings_text(alt_spellings):
    prefixes = SECTION_PREFIXES if alt_spellings else ("§",)
    forms = [p + ("" if p == "§" else " ") + "N" for p in prefixes]
    if alt_spellings:
        forms += ["N" + s for s in SECTION_SUFFIXES]
    return " · ".join("`%s`" % f for f in forms) + " (N = 3 · 3.2 · 9.4.1 · 2.3b · 3.3-b; N절 needs N ≥ 1 — `0절` is a count; ranges " \
        + " · ".join("`%s`" % r for r in RANGE_EXAMPLES) + ")" + ("" if alt_spellings else "  [ABLATION: alt spellings off]")


HEADING_RE = re.compile(r"^(#{1,6})\s+(.*?)\s*$")
H_SECTION_RE = re.compile(r"^(?:" + section_prefix_regex(SECTION_PREFIXES) + r"\s*)?(?P<num>\d+(?:\.\d+)*)(?P<suf>-?[a-z])?(?=[.)]?(?:\s|$))")
H_APPENDIX_RE = re.compile(r"^" + APP + r"\s*(?P<app>\d+|[A-Z])(?:\.(?P<sub>\d+(?:\.\d+)*))?(?![A-Za-z0-9])")
H_LETTER_RE = re.compile(r"^(?P<let>[A-Z])\.(?P<sub>\d+(?:\.\d+)*)(?=[.)]?(?:\s|$))")
R_APPENDIX_RE = re.compile(APP + r"\s*(?P<app>\d+|[A-Za-z])(?:\.(?P<sub>\d+(?:\.\d+)*))?(?![A-Za-z0-9])(?!\.\d)")   # v17: `appendix k.2` too
R_LETTER_RE = re.compile(r"(?<![A-Za-z0-9.§])(?P<let>[A-Z])\.(?P<sub>\d+(?:\.\d+)*)(?![A-Za-z0-9])(?!\.\d)")
TOKEN_PREFIX_RE = r"(?:(?:" + "|".join(re.escape(p) for p in SECTION_PREFIXES) + r")\s*)?"


def _nfkc(s):
    return unicodedata.normalize("NFKC", s)


# v18 (codex round 17, fixtures run by the author after the sidecar hit its quota): full-width ASCII (U+FF01–FF5E)
# and the ideographic space are the reader's ASCII — mapped per character (length-preserving) before a line
# is scanned for headings or refs, so `Appendix Ｋ` keys as K and `## Appendix Ｋ` defines it.
FULLWIDTH = {c: c - 0xFEE0 for c in range(0xFF01, 0xFF5F)}
FULLWIDTH[0x3000] = 0x20


def _fw(line):
    return line.translate(FULLWIDTH)


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




def skey(num, suf):
    # NFKC: `§１.２` (full-width digits, codex round 3) keys the same as `## 1.2`; display keeps the raw text
    return "S:" + _nfkc(num) + (suf or "")


def akey(app, sub):
    return "A:" + _nfkc(app).upper() + (("." + _nfkc(sub)) if sub else "")     # v17: prose `appendix k.2` keys as K.2


def show(key):
    ns, rest = key.split(":", 1)
    if ns == "S":
        return "§" + rest
    if rest.isdigit():
        return "부록 " + rest
    if "." in rest:
        return rest                    # K.2
    return "Appendix " + rest          # K


def parse_heading_key(text):
    t = text.strip().lstrip("*_ ").strip()
    # v7 (codex round 6): `## **3.2** Middle` renders as a numbered heading — drop emphasis glued to the number
    t = re.sub(r"^(\S+?)[*_]{1,3}(?=\s|$)", r"\1", t)
    m = H_APPENDIX_RE.match(t)
    if m:
        return akey(m.group("app"), m.group("sub"))
    m = H_SECTION_RE.match(t)
    if m:
        return skey(m.group("num"), m.group("suf"))
    m = H_LETTER_RE.match(t)
    if m:
        return akey(m.group("let"), m.group("sub"))
    return None


def parse_ref_token(text):
    """One ref-shaped string (`3.2`, `§3.2`, `Sec. 3.2`, `3.2절`, `부록 3`, `K`, `K.2`, `Appendix K`) → key or None."""
    t = text.strip()
    m = re.fullmatch(TOKEN_PREFIX_RE + r"(?P<num>\d+(?:\.\d+)*)(?P<suf>-?[a-z])?(?:" + "|".join(SECTION_SUFFIXES) + r")?", t)
    if m:
        return skey(m.group("num"), m.group("suf"))
    m = re.fullmatch(APP + r"\s*(?P<app>\d+|[A-Za-z])(?:\.(?P<sub>\d+(?:\.\d+)*))?", t)
    if m:
        return akey(m.group("app"), m.group("sub"))
    m = re.fullmatch(r"(?P<let>[A-Z])(?:\.(?P<sub>\d+(?:\.\d+)*))?", t)
    if m:
        return akey(m.group("let"), m.group("sub"))
    return None


def _parent_last(num):
    """`3.2.4` → (`3.2`, `4`) · `12` → (``, `12`)."""
    return (num.rsplit(".", 1)[0], num.rsplit(".", 1)[1]) if "." in num else ("", num)


def _range_refs(n1, s1, n2, s2, sep, rng, start, expand_interior, cap, cap_verdict):
    """The second endpoint of a range plus its interiors (or one UNCHECKED row) → [(key, display, start)];
    [] when the compact-hyphen guard rejects the second number (`Sec. 2026-09-10` is a date)."""
    if "." in n1 and "." not in n2 and "§" not in sep and not s1 and not s2:
        n2 = n1.rsplit(".", 1)[0] + "." + n2      # v15 (codex round 14): `Sections 3.1-3` is the sibling shorthand 3.1–3.3
    (p1, a), (p2, b) = _parent_last(n1), _parent_last(n2)
    if sep == "-" and not (s1 or s2) and (p1 != p2 or not (a.isdigit() and b.isdigit() and int(a) < int(b))):
        return []                          # compact form = same parent AND ascending (numeric ends only; `§3.2a-c` is a suffix range)
    out = [(skey(n2, s2 or None), "§" + n2 + s2, start)]
    if not expand_interior:
        return out
    # Which interiors a range names is decided by its FORM, and only four forms are enumerable:
    #   same parent, integer ends       `§1.1–1.3`  → §1.2          (v3, codex round 2)
    #   same number, letter suffixes    `§3.2a–3.2c` → §3.2b         (v4, codex round 3)
    #   parent to its own child         `§3~§3.2`   → §3.1          (v5, codex round 4)
    #   number to its own suffix        `§3.2–3.2b` → §3.2a         (v5 — a suffix is a child of its number)
    # 🟥 v5: every OTHER form with a range separator (`§3.2a-3.3` · `§3.2a–3.3c` · `§3~§4.2`) used to
    # check its endpoints and say clean — the interior was not unchecked by accident but by having no
    # definition, and rc=0 hid that. It is now an UNCHECKED row (DANGLING-class, the key can never
    # resolve) unless --no-unchecked-verdict; the cap hit (v4) is the same row with a different reason.
    inner_keys, why = None, None
    if p1 == p2 and not s1 and not s2 and a.isdigit() and b.isdigit() and int(a) < int(b):
        inner_keys = [((p1 + "." if p1 else "") + str(k), None) for k in range(int(a) + 1, int(b))]
    elif n1 == n2 and s1 and s2 and s1[-1] < s2[-1]:
        style = "-" if s1.startswith("-") else ""
        inner_keys = [(n1, style + chr(c)) for c in range(ord(s1[-1]) + 1, ord(s2[-1]))]
    elif n1 == n2 and not s1 and s2:
        style = "-" if s2.startswith("-") else ""
        inner_keys = [(n1, style + chr(c)) for c in range(ord("a"), ord(s2[-1]))]
    elif not s1 and not s2 and p2 == n1 and b.isdigit() and int(b) >= 1:
        inner_keys = [(n1 + "." + str(k), None) for k in range(1, int(b))]
    else:
        why = "mixed form — no defined interior"
    # span = sections from the first end to the last (`§1–5` spans 4), the number --help promises
    if inner_keys is not None and len(inner_keys) + 1 > cap:
        why = "span > %d — --range-cap N to expand" % cap
    if why is not None:
        if cap_verdict:
            out.append((skey(n1 + "~" + n2, None), "%s (interior UNCHECKED: %s)" % (rng, why), start))
        else:
            print("⚠️ range %s — %s — interior NOT expanded (ABLATION: --no-unchecked-verdict)" % (rng, why), file=sys.stderr)
        return out
    for inner, suf in inner_keys:
        out.append((skey(inner, suf), "§%s%s (interior of %s)" % (inner, suf or "", rng), start))
    return out


def refs_in(line, rxs):
    """→ [(key, display, start)] for every cross-reference on a non-heading line. `display` keeps the
    spelling as written (`Sec. 9.4`, `3.2절`) so the reader sees what the reader will see."""
    section_re, suffix_re, slash_re, cont_re, expand_interior, cap, cap_verdict = rxs
    out = []
    for m in section_re.finditer(line):
        end1 = m.end("suf") if m.group("suf") else m.end("num")
        n1, s1 = _nfkc(m.group("num")), m.group("suf") or ""
        out.append((skey(m.group("num"), m.group("suf")), line[m.start():end1], m.start()))
        pos = end1
        if m.group("num2") or m.group("suf2o"):
            if m.group("suf2o"):           # v15: `§3.2a-c` → second endpoint = same number, suffix c (style of the first)
                n2, s2 = n1, ("-" if s1.startswith("-") else "") + m.group("suf2o")
                sep = line[end1:m.start("suf2o")].strip()
            else:
                n2, s2 = _nfkc(m.group("num2")), m.group("suf2") or ""
                sep = line[end1:m.start("num2")].strip()
            out += _range_refs(n1, s1, n2, s2, sep, line[m.start():m.end()].strip(), m.start(), expand_interior, cap, cap_verdict)
            pos = m.end()                  # v12 (codex round 11): a plural list may continue AFTER a range item
        # v7 (codex round 6): `§3.1/3.2` names two sections; a bare integer after the slash is a sibling
        # when the first is dotted (`§3.1/2` → §3.2). v9 (round 8): the slash side may carry a range.
        plural = line[m.start():m.start("num")].strip().lower().startswith("sections")
        while True:
            sm = slash_re.match(line, pos) or (cont_re.match(line, pos) if plural else None)
            if not sm:
                break
            n = _nfkc(sm.group("num"))
            if "." not in n and "." in n1:
                n = n1.rsplit(".", 1)[0] + "." + n
            s = sm.group("suf") or ""
            endn = sm.end("suf") if sm.group("suf") else sm.end("num")
            out.append((skey(n, s or None), "§%s%s (in %s)" % (n, s, line[m.start():endn]), m.start()))
            if sm.group("num2") or sm.group("suf2o"):
                if sm.group("suf2o"):
                    n2, s2, sep = n, ("-" if s.startswith("-") else "") + sm.group("suf2o"), line[endn:sm.start("suf2o")].strip()
                else:
                    n2, s2, sep = _nfkc(sm.group("num2")), sm.group("suf2") or "", line[endn:sm.start("num2")].strip()
                out += _range_refs(n, s, n2, s2, sep, line[m.start():sm.end()].strip(), m.start(), expand_interior, cap, cap_verdict)
            pos = sm.end()
    if suffix_re is not None:
        for m in suffix_re.finditer(line):
            out.append((skey(m.group("num"), m.group("suf")), m.group(0), m.start()))
    spans = []
    for m in R_APPENDIX_RE.finditer(line):
        out.append((akey(m.group("app"), m.group("sub")), m.group(0), m.start()))
        out += _letter_range(line, m, m.group("app"), m.group("sub")) if expand_interior else []
        spans.append((m.start(), m.end()))
    for m in R_LETTER_RE.finditer(line):
        if any(a <= m.start() < b for a, b in spans):
            continue                       # v18: `Appendix K.1` is one ref, not `Appendix K.1` + `K.1`
        out.append((akey(m.group("let"), m.group("sub")), m.group(0), m.start()))
        out += _letter_range(line, m, m.group("let"), m.group("sub")) if expand_interior else []
    return out


LETTER_RANGE_RE = re.compile(r"\s*[-–~]\s*(?:(?:부록|Appendix|APPENDIX|appendix)\s*)?(?:(?P<let>[A-Za-z])\.)?(?P<sub>\d+)(?![A-Za-z0-9.])")


def _letter_range(line, m, let, sub):
    """v18: `Appendix K.1-K.3` · `K.1–3` name the interior K.2 (same letter, integer ends). Other forms are endpoints only."""
    if not sub or "." in sub or not sub.isdigit():
        return []
    r = LETTER_RANGE_RE.match(line, m.end())
    if not r or (r.group("let") and r.group("let").upper() != let.upper()):
        return []
    a, b = int(sub), int(r.group("sub"))
    rng = line[m.start():r.end()].strip()
    out = [(akey(let, r.group("sub")), "%s.%s (in %s)" % (let.upper(), r.group("sub"), rng), m.start())]
    if a < b:
        out += [(akey(let, str(k)), "%s.%d (interior of %s)" % (let.upper(), k, rng), m.start()) for k in range(a + 1, b)]
    return out


def ancestors(key):
    ns, rest = key.split(":", 1)
    out = []
    base = re.sub(r"-?[a-z]$", "", rest)
    if base != rest:
        out.append(ns + ":" + base)
    parts = base.split(".")
    while len(parts) > 1:
        parts = parts[:-1]
        out.append(ns + ":" + ".".join(parts))
    return out


def is_under(key, old):
    if key == old:
        return True
    if not key.startswith(old):
        return False
    rest = key[len(old):]
    return rest.startswith(".") or rest.startswith("-") or re.fullmatch(r"[a-z]", rest) is not None


def main():
    ap = argparse.ArgumentParser(description=__doc__.replace("{SPELLINGS}", spellings_text(True)),
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--body", nargs="+", required=True, metavar="MD", help="body file(s); headings and refs are pooled across them")
    ap.add_argument("--define", action="append", default=[], metavar="REF",
                    help="declare an anchor that is not a heading (e.g. '부록 1'); repeatable, printed")
    ap.add_argument("--external", metavar="REGEX", help="a ref whose same-line ±80-char window matches is EXTERNAL (listed, not counted)")
    ap.add_argument("--map", metavar="OLD=NEW,...", help="renumbering map; refs still under an OLD number are STALE-OLD")
    ap.add_argument("--parent-resolves", action="store_true", help="ABLATION ONLY: a ref resolves if any ancestor heading exists")
    ap.add_argument("--no-alt-spellings", action="store_true",
                    help="ABLATION ONLY: scan `§N` alone — Sec./Section/섹션/N절 refs are not read (the 2026-09-17 v1 arm)")
    ap.add_argument("--no-range-interior", action="store_true",
                    help="ABLATION ONLY: check only a range's two endpoints — `§1.1–1.3` with no §1.2 reads clean (the v2 arm)")
    ap.add_argument("--no-compact-range", action="store_true",
                    help="ABLATION ONLY: `Section 1.1-1.3` (compact ASCII hyphen) is read as §1.1 alone (the v2 arm)")
    ap.add_argument("--range-cap", type=int, default=RANGE_INTERIOR_CAP, metavar="N",
                    help="a range spanning more than N sections is not expanded and becomes a DANGLING-class UNCHECKED row (default %d)" % RANGE_INTERIOR_CAP)
    ap.add_argument("--no-unchecked-verdict", "--no-cap-verdict", dest="no_cap_verdict", action="store_true",
                    help="ABLATION ONLY: a range whose interior cannot be enumerated (cap hit · mixed form) is a stderr "
                         "warning and stays clean (the v3/v4 arm); `--no-cap-verdict` is the older spelling")
    ap.add_argument("--show-resolved", action="store_true", help="also list resolved refs")
    ap.add_argument("--list-headings", action="store_true", help="print every parsed heading anchor")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()
    rxs = build_ref_regexes(not args.no_alt_spellings, not args.no_compact_range) \
        + (not args.no_range_interior, args.range_cap, not args.no_cap_verdict)

    defined, unnumbered, files = {}, 0, {}
    for p in args.body:
        try:
            with open(p, encoding="utf-8", errors="replace") as fh:
                files[p] = strip_html_comments(fh.read()).split("\n")
        except OSError as e:
            print("🟥 cannot read %s: %s" % (p, e), file=sys.stderr)
            return 10
    for p, lines in files.items():
        fence = None                      # v8/v9: ``` and ~~~ fences via _fence_step (opener length · `> ` prefix)
        for i, line in enumerate(lines, 1):
            fence, on_fence = _fence_step(line, fence)
            if on_fence or fence is not None:
                continue
            m = HEADING_RE.match(_fw(line))
            if not m:
                continue
            k = parse_heading_key(m.group(2))
            if k is None:
                unnumbered += 1
            else:
                defined.setdefault(k, []).append((p, i, m.group(2)[:70]))
    flag_defined = []
    for d in args.define:
        k = parse_ref_token(d)
        if k is None:
            print("🟥 --define %r is not a ref-shaped token" % d, file=sys.stderr)
            return 10
        flag_defined.append(k)
        defined.setdefault(k, []).append(("--define", 0, d))
    n_headings = sum(len(v) for v in defined.values()) - len(flag_defined) + unnumbered
    if not defined:
        n_refs_seen = sum(len(refs_in(l, rxs)) for lines in files.values() for l in lines
                          if not HEADING_RE.match(l) and not FENCE_RE.match(l.lstrip()))
        print("🟥 0 numbered headings parsed from %d file(s) (%d unnumbered heading(s)); %d ref(s) seen and NOT reported as "
              "dangling — wrong file or wrong heading shape. rc=10" % (len(files), unnumbered, n_refs_seen))
        return 10

    mapping = []
    if args.map:
        for pair in args.map.split(","):
            if "=" not in pair:
                print("🟥 --map entry %r is not OLD=NEW" % pair, file=sys.stderr)
                return 10
            o, n = pair.split("=", 1)
            ko, kn = parse_ref_token(o), parse_ref_token(n)
            if ko is None or kn is None:
                print("🟥 --map entry %r: not ref-shaped" % pair, file=sys.stderr)
                return 10
            mapping.append((ko, kn))
    ext_re = re.compile(args.external) if args.external else None

    resolved, dangling, stale, external = [], [], [], []
    for p, lines in files.items():
        fence = None
        for i, line in enumerate(lines, 1):
            fence, on_fence = _fence_step(line, fence)
            if on_fence:
                continue
            if fence is None and HEADING_RE.match(line):
                continue                   # the heading's own number is a definition, not a reference
                                           # (a `#` line INSIDE a fence is neither — its refs are scanned)
            for key, disp, pos in refs_in(_fw(line), rxs):
                snippet = line[max(0, pos - 45):pos + 60].strip()
                rec = {"key": key, "ref": disp, "file": p, "line": i, "snippet": snippet}
                old = next((o for o, n in mapping if is_under(key, o)), None)
                if old is not None:
                    rec["old"], rec["new"] = old, dict(mapping)[old]
                    stale.append(rec)
                    continue
                if key in defined:
                    resolved.append(rec)
                    continue
                anc = [a for a in ancestors(key) if a in defined]
                if args.parent_resolves and anc:
                    rec["via_parent"] = anc[0]
                    resolved.append(rec)
                    continue
                if ext_re is not None and ext_re.search(line[max(0, pos - 80):pos + 80]):
                    rec["matched"] = ext_re.search(line[max(0, pos - 80):pos + 80]).group(0)
                    external.append(rec)
                    continue
                rec["parent"] = anc[0] if anc else None
                dangling.append(rec)
    n_refs = len(resolved) + len(dangling) + len(stale) + len(external)
    if n_refs == 0:
        print("⬜ DEAD CONTROL — 0 cross-references found in %d file(s) (%d numbered heading(s) parsed; spellings scanned: %s); nothing was checked. rc=4 (not a clean check)."
              % (len(files), len(defined) - len(flag_defined), spellings_text(not args.no_alt_spellings)))
        return 4
    rc = 1 if (dangling or stale) else 0

    if args.json:
        print(json.dumps({
            "body": args.body, "defined": {k: [{"file": f, "line": n, "text": t} for f, n, t in v] for k, v in sorted(defined.items())},
            "defined_by_flag": flag_defined, "external_regex": args.external, "map": mapping,
            "parent_resolves": args.parent_resolves, "alt_spellings": not args.no_alt_spellings,
            "spellings": spellings_text(not args.no_alt_spellings),
            "dangling": dangling, "stale_old": stale, "external": external, "resolved": resolved,
            "summary": {"headings": n_headings, "numbered": len(defined) - len(flag_defined), "refs": n_refs,
                        "distinct_refs": len({r["key"] for r in resolved + dangling + stale + external}),
                        "dangling": len(dangling), "stale_old": len(stale), "external": len(external),
                        "resolved": len(resolved), "rc": rc},
        }, ensure_ascii=False, indent=1))
        return rc

    print("section-ref check · body=%d file%s · headings=%d (%d numbered anchors · %d unnumbered) · refs=%d (%d distinct)"
          % (len(files), "" if len(files) == 1 else "s", n_headings, len(defined) - len(flag_defined), unnumbered,
             n_refs, len({r["key"] for r in resolved + dangling + stale + external})))
    print("  spellings: %s" % spellings_text(not args.no_alt_spellings))
    print("  mechanisms: exact-match=%s · defined-by-flag=%s · external=%s · map=%s · range-interior=%s · compact-range=%s · range-cap=%d · unchecked-verdict=%s"
          % ("off (ABLATION: parent resolves)" if args.parent_resolves else "on",
             ", ".join(show(k) for k in flag_defined) if flag_defined else "(none)",
             repr(args.external) if args.external else "(none)",
             ", ".join("%s→%s" % (show(o), show(n)) for o, n in mapping) if mapping else "(none)",
             "off (ABLATION)" if args.no_range_interior else "on",
             "off (ABLATION)" if args.no_compact_range else "on",
             args.range_cap, "off (ABLATION)" if args.no_cap_verdict else "on"))
    if args.list_headings:
        for k in sorted(defined, key=lambda x: [(0, int(t)) if t.isdigit() else (1, t) for t in re.split(r"[.:\-]", x)]):
            for f, n, t in defined[k]:
                print("  ▸ %-10s %s:%d  %s" % (show(k), f.split("/")[-1], n, t))
    for r in dangling:
        why = ("parent %s exists" % show(r["parent"])) if r["parent"] else "no such top-level"
        print("  🟥 DANGLING   %-10s %s:%d  (%s)  …%s…" % (r["ref"], r["file"].split("/")[-1], r["line"], why, r["snippet"]))
    for r in stale:
        print("  🟥 STALE-OLD  %-10s %s:%d  (old %s → now %s)  …%s…" % (r["ref"], r["file"].split("/")[-1], r["line"], show(r["old"]), show(r["new"]), r["snippet"]))
    for r in external:
        print("  ⬜ EXTERNAL   %-10s %s:%d  (matched %r)  …%s…" % (r["ref"], r["file"].split("/")[-1], r["line"], r["matched"], r["snippet"]))
    if args.show_resolved:
        for r in resolved:
            print("  ✅ resolved   %-10s %s:%d%s" % (r["ref"], r["file"].split("/")[-1], r["line"],
                  ("  (via parent %s — ABLATION)" % show(r["via_parent"])) if r.get("via_parent") else ""))
    if dangling:
        print("ⓘ a DANGLING ref is a pointer the reader cannot follow; «parent exists» usually means a sub-heading was removed or never written.")
    print("section-ref verdict: DANGLING=%d STALE-OLD=%d EXTERNAL=%d RESOLVED=%d rc=%d"
          % (len(dangling), len(stale), len(external), len(resolved), rc))
    return rc


if __name__ == "__main__":
    sys.exit(main())
