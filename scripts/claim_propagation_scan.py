#!/usr/bin/env python3
"""claim_propagation_scan.py — a RETRACTED number that some other file still asserts as live.

WHAT IT CLOSES (measured 2026-09-17, the five-arm retraction, PR #743)
  A numeric claim («2.7 %–13.6 %», «five review arms») was retracted in its canon file and had
  already been copied into two more — the resident CLAUDE.md carried it at two sites. Neither
  existing instrument could see it: scripts/halffix_propagation_scan.sh anchors on identifiers of
  10+ chars or path literals and reads the STAGED DIFF, not a retraction list;
  scripts/novelty_claim_check.sh matches absence/novelty phrases — a different claim class.
  This scanner takes a list of retracted TOKENS and names every file:line that still asserts one
  of them OUTSIDE a retraction context.
  Calibration (prototype, same day): the pre-retraction tree fired 13/13 known sites — both
  CLAUDE.md sites among them; the post-retraction tree fired 0 on CLAUDE.md, every site classified
  as retraction context. The lane suite (scripts/test_claim_propagation_lanes.sh) reconstructs both
  arms as fixture files, so it does not depend on git history at lane time.

WHAT IT DOES NOT DO — read before trusting a 0
  🟥 PROSE-claim retractions are OUT OF SCOPE. Measured 0/8 precision on a prose claim («0 lines
     of validation code»): word tokens that are not a specific figure flood on their own — a flood
     generator, not an instrument. Feed it numbers and short literal phrases only.
  🟥 The ⓑ retraction vocabulary (DEFAULT_MARKERS) is a FROZEN JUDGMENT — the words this repo has
     used to retract things, euphemisms included (`초판`, `replaced`, `the earlier`, `인용하지
     마라`). Ablation: dropping three English euphemisms turned 3 excluded sites LIVE. A retraction
     phrased in wording not on the list is reported LIVE (loud direction); a genuinely live sentence
     that sits within ±200 chars of any marker is excluded (silent direction). Both are properties
     of the vocabulary, not of the corpus. `--markers` overrides it, `--strict-markers` narrows it.
  🟥 EXCLUDED CLASSES are a CLASSIFICATION, not a corpus cut. Two file classes hold the retracted
     figure legitimately: RECORD class — a dated dispatch-log / ledger line is «what was done that
     day», not a claim (`knowledge/shared/learnings/*_log.yaml`); FIXTURE class — a lane suite
     carries the retracted figure as its known-positive by construction (`scripts/test_*_lanes.sh`,
     measured: this scanner's own suite = 44 would-be-LIVE sites). Both are excluded by DEFAULT,
     and exclusion means: the file IS scanned, its would-be-LIVE hits are counted as
     EXCLUDED-FILE — printed in every verdict line, listed by `--show-excluded`, never LIVE and
     never in rc. A first version skipped those files entirely, which HID a live claim sitting in
     an excluded file (cross-family review, 2026-09-17); visible-not-silent is the fix. `--exclude`
     adds patterns; `--no-default-exclude` drops the defaults so those hits count as LIVE.
  🟥 It judges FORM, not truth. A LIVE hit means «this token is asserted here with no retraction
     marker nearby»; the reader decides whether the sentence is the retracted claim. Advisory by
     decision (governor, 2026-09-17): MARK, never BLOCK — not wired into pre-commit.

MECHANISMS (each independently switchable so a known pair can ablate it)
  nfkc      corpus lines, tokens, anchor and marker regexes are NFKC-normalized before matching —
            full-width `２.７％` and `Ｂ－１` become their ASCII forms. Without it a full-width copy
            of a retracted figure is SILENT (cross-family review found exactly that:
            `２.７ % claim-error` → bare=0). Measured scope: the delta is DIGITS and `％`; an
            ideographic / no-break space between token parts is already matched by the FORM's `\\s`
            without NFKC (lane L11r). Side effect, named: snippets print the normalized text
            (`ⓐ`→`a`, `①`→`1`); a regex containing `…` becomes `...`. `--no-nfkc` disables.
  form      token FORM + digit boundary — `2.7 %` matches `2.7%` / `2.7 %`, never `12.7 %` or
            `2.75 %`; a word token needs letter boundaries; parts are joined by optional
            whitespace INCLUDING a line break inside a block. The largest reducer measured
            (naive `2\\.7` = 131 lines → 8). Not switchable: it IS the token.
  ⓐ anchor  a token counts as a CLAIM SITE only if the claims file's anchor regex occurs within ±N
            chars in the same block. Decorative for `%`-bearing tokens, LOAD-BEARING for bare
            numbers — and only with CLAIM-SPECIFIC anchors (오류율|error rate|claim-error|B-1|
            최저|최고 …); generic ones (팔|arm|five) flood on `3/3`.
  ⓑ retract a hit whose ±N-char window, or whose block's caption line, carries a retraction marker
            is RETRACTION-CONTEXT, not live. Removed 15/16 post-retraction sites in calibration.
            The revert probe (lane L7) shows this one is load-bearing, not decorative.
  ⓒ′ form-rule (ON)  a BARE token — no anchor — that is purely numeric is REFUSED: reported with
            its bare counts, never scanned. Rarity today is not specificity (`12/12` was 8 lines
            here and every one unrelated). Loud: rc=3 PARTIAL.
  ⓒ ubiquity (secondary)  a BARE token above the frequency thresholds is REFUSED the same way.
  ⓓ quote   (OFF) a token inside «…» 「…」 “…” "…" `…` is a MENTION. Measured as silent-direction
            (it swallows the known-positive), so it is opt-in only.

COUNTING UNIT — one unit for every column. `bare` = occurrences of the token in block text (the
same text pass 2 classifies), `files` = files with ≥1. For every scanned (non-refused) token:
    bare == LIVE + EXCLUDED-FILE + RETRACTION-CONTEXT + NO-ANCHOR + MENTION        (lane L14)
A first version counted `bare` per LINE and LIVE per BLOCK, so a token wrapped across a line break
or repeated on one line made the two columns disagree (bare=1, LIVE=2).
Unit of context = a BLOCK: a blank-line-delimited paragraph, or one fenced ``` block. Windows are
measured in chars over the flattened block, so a marker one wrapped line above still counts and a
marker at the far end of a 1,500-char table row does not.

CLAIMS FILE   `token<TAB>anchor-regex<TAB>source` per line; `#` comments; empty anchor = bare token.
EXCLUDES      fnmatch against the root-relative path (`/` separators; `*` crosses `/`).

EXIT CODES
   0  scanned, no live propagation          2  LIVE propagation found (ADVISORY — mark, not block)
   3  a token was REFUSED (ⓒ′/ⓒ) and nothing live — PARTIAL scan, NOT a clean-corpus verdict
   4  DEAD CONTROL: zero tokens parsed — distinct from 0 on purpose (not found ≠ 0)
  10  input error (claims file missing · empty corpus)
  EXCLUDED-FILE never changes rc; it is always in the verdict line so it cannot hide.

USAGE
  python3 scripts/claim_propagation_scan.py --claims <tsv> --root <dir> [--paths P ...] [options]
  bash    scripts/test_claim_propagation_lanes.sh          # known pairs + revert probes
Corpus = `git ls-files` under --root when it is a checkout (untracked files are NOT scanned),
else a filesystem walk; `--untracked` forces the walk. `--quiet` keeps the exclusion lines and the
verdict line — those two are never silenced. Python ≥ 3.9, stdlib only.
"""
import argparse
import fnmatch
import glob
import json
import os
import re
import subprocess
import sys
import unicodedata

WS = r"[\s   ]*"   # whitespace incl. NBSP / thin / narrow-NBSP — `2.7 %`, `2.7%`, `2.7 %` are one token

DEFAULT_MARKERS = (
    r"철회|RETRACT|retract|withdraw|supersed|replaced|초판|종전|옛|the earlier|no longer|~~|"
    r"defective|obsolete|폐기|인용하지 마라|do not cite|used to (read|say|cite)"
)
STRICT_MARKERS = r"철회|RETRACT|retract|withdrawn|superseded|~~"

# Excluded CLASSES (pattern, label). Files matching these are scanned; their would-be-LIVE hits are
# counted as EXCLUDED-FILE. See the header: record class (a ledger line is a record, not a claim) and
# fixture class (a lane suite carries the retracted figure as its known-positive by construction).
DEFAULT_EXCLUDES = [
    ("knowledge/shared/learnings/*_log.yaml", "record class"),
    ("scripts/test_*_lanes.sh", "fixture class"),
]

NFKC_ON = True   # ablation switch — `--no-nfkc` turns it off; lane L11's revert probe flips this line in a copy

QUOTE_RE = re.compile(r"«[^»\n]{0,300}»|「[^」\n]{0,300}」|“[^”\n]{0,300}”|\"[^\"\n]{0,300}\"|`[^`\n]{0,300}`")
NUMERIC_FORM_RE = re.compile(r"[\d.,/%\s–—-]+")


def norm(s):
    """NFKC-normalize when enabled — applied to corpus lines, tokens, anchor and marker regexes alike."""
    return unicodedata.normalize("NFKC", s) if NFKC_ON else s


def compile_token(tok):
    """Token FORM: literal parts joined by optional whitespace, with digit / letter / hangul boundaries."""
    t = norm(tok.strip())
    parts = re.split(r"\s+", t)
    pat = WS.join(re.escape(p) for p in parts)
    first, last = t[0], t[-1]
    pre = post = ""
    if first.isdigit():
        pre = r"(?<![\d.])"
    elif re.match(r"[A-Za-z]", first):
        pre = r"(?<![A-Za-z])"
    elif re.match(r"[가-힣]", first):
        pre = r"(?<![가-힣])"
    if last.isdigit():
        post = r"(?!\d)(?!\.\d)"
    elif re.match(r"[A-Za-z]", last):
        post = r"(?![A-Za-z])"
    return re.compile(pre + pat + post)


def read_claims(path):
    claims = []
    with open(path, encoding="utf-8") as fh:
        for raw in fh:
            line = raw.rstrip("\n")
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            cols = line.split("\t")
            tok = cols[0].strip()
            anchor = norm(cols[1].strip()) if len(cols) > 1 else ""
            src = cols[2].strip() if len(cols) > 2 else ""
            if not tok:
                continue
            claims.append({"token": tok, "anchor": anchor, "source": src, "re": compile_token(tok),
                           "anchor_re": re.compile(anchor) if anchor else None})
    return claims


def list_corpus(root, paths, tracked):
    files = []
    if tracked and os.path.isdir(os.path.join(root, ".git")):
        cmd = ["git", "-C", root, "ls-files", "--"] + (paths or ["."])
        out = subprocess.run(cmd, capture_output=True, text=True, check=False).stdout
        files = [os.path.join(root, f) for f in out.splitlines() if f]
    else:
        for b in (paths or ["."]):
            p = os.path.join(root, b)
            if os.path.isfile(p):
                files.append(p)
            elif os.path.isdir(p):
                for d, dirs, fs in os.walk(p):
                    dirs[:] = [x for x in dirs if x != ".git"]   # prune only .git itself, never .github
                    for f in fs:
                        files.append(os.path.join(d, f))
            else:
                files.extend(glob.glob(os.path.join(root, b)))   # README* etc.
    out = []
    for f in sorted(set(files)):
        try:
            with open(f, "rb") as fh:
                head = fh.read(8192)
        except OSError:
            continue
        if b"\0" in head:
            continue
        out.append(f)
    return out


def rel_of(f, root):
    return os.path.relpath(f, root).replace(os.sep, "/")


def classify_excludes(files, root, patterns):
    """→ (labels: rel → class label, per_pattern: [(pattern, label, [rels])]). No file is dropped."""
    labels = {}
    per_pattern = []
    for pat, label in patterns:
        matched = []
        for f in files:
            rel = rel_of(f, root)
            if fnmatch.fnmatchcase(rel, pat):
                matched.append(rel)
                labels.setdefault(rel, label)
        per_pattern.append((pat, label, matched))
    return labels, per_pattern


def load_lines(f):
    try:
        with open(f, encoding="utf-8", errors="replace") as fh:
            return [norm(l) for l in fh.read().split("\n")]   # per line, so line numbers stay exact
    except OSError:
        return None


def split_blocks(lines):
    """Blocks = list of (lineno, text) lists; blank-line paragraphs, or one fenced ``` block each."""
    blocks, cur, in_fence = [], [], False
    for i, l in enumerate(lines, 1):
        s = l.strip()
        if s.startswith("```"):
            if in_fence:
                cur.append((i, l)); blocks.append(cur); cur = []; in_fence = False
            else:
                if cur:
                    blocks.append(cur); cur = []
                in_fence = True; cur.append((i, l))
            continue
        if in_fence:
            cur.append((i, l)); continue
        if s == "":
            if cur:
                blocks.append(cur); cur = []
            continue
        cur.append((i, l))
    if cur:
        blocks.append(cur)
    return blocks


def block_text(block):
    text = "\n".join(l for _, l in block)
    offsets, pos = [], 0
    for _, l in block:
        offsets.append(pos)
        pos += len(l) + 1
    return text, offsets


def line_of(offsets, block, off):
    idx = 0
    for k, o in enumerate(offsets):
        if o <= off:
            idx = k
        else:
            break
    return block[idx][0], idx


def caption_line(block):
    """First content line of the block (for a fence: the first line after ```)."""
    if block and block[0][1].strip().startswith("```") and len(block) > 1:
        return block[1][1]
    return block[0][1] if block else ""


def in_scope_text(text, offsets, block, m, scope, nchars):
    if scope == "line":
        _, idx = line_of(offsets, block, m.start())
        return block[idx][1]
    if scope == "block":
        return text
    a = max(0, m.start() - nchars)
    b = min(len(text), m.end() + nchars)
    return text[a:b]


def scan(claims, files, root, excluded, args):
    marker_re = re.compile(norm(args.markers))
    per_token = {c["token"]: {"token": c["token"], "anchor": c["anchor"], "source": c["source"],
                              "bare": 0, "bare_files": set(), "live": [], "excluded_file": [],
                              "retraction": [], "no_anchor": [], "mention": [], "refused": ""} for c in claims}
    # one read per file; blocks are the unit for BOTH passes (bare and classification)
    docs = []
    for f in files:
        lines = load_lines(f)
        if lines is None:
            continue
        rel = rel_of(f, root)
        blocks = []
        for b in split_blocks(lines):
            text, offsets = block_text(b)
            blocks.append((b, text, offsets, caption_line(b)))
        docs.append((rel, excluded.get(rel, ""), blocks))
    # pass 1 — bare occurrences (report columns + ⓒ), same regex on the same block text as pass 2
    for rel, _, blocks in docs:
        for c in claims:
            n = sum(sum(1 for _ in c["re"].finditer(text)) for _, text, _, _ in blocks)
            if n:
                rec = per_token[c["token"]]
                rec["bare"] += n
                rec["bare_files"].add(rel)
    # ⓒ′ FORM rule first (primary), ⓒ frequency guard second — both only for BARE tokens.
    for c in claims:
        rec = per_token[c["token"]]
        if c["anchor"]:
            continue
        if not args.no_form_rule and NUMERIC_FORM_RE.fullmatch(norm(c["token"])) is not None:
            rec["refused"] = "form"
        elif not args.no_ubiquity and (rec["bare"] > args.ubiquity_max_occ
                                       or len(rec["bare_files"]) > args.ubiquity_max_files):
            rec["refused"] = "ubiquity"
    # pass 2 — classification
    for rel, exlabel, blocks in docs:
        for block, text, offsets, cap in blocks:
            quotes = [(q.start(), q.end()) for q in QUOTE_RE.finditer(text)] if args.quote_excl else []
            for c in claims:
                rec = per_token[c["token"]]
                if rec["refused"]:
                    continue
                for m in c["re"].finditer(text):
                    ln, _ = line_of(offsets, block, m.start())
                    sa, sb = max(0, m.start() - 70), min(len(text), m.end() + 70)
                    hit = {"file": rel, "line": ln, "snippet": text[sa:sb].replace("\n", "⏎"), "why": ""}
                    # ⓓ
                    if quotes and any(a <= m.start() and m.end() <= b for a, b in quotes):
                        hit["why"] = "ⓓ inside quote span"; rec["mention"].append(hit); continue
                    # ⓑ
                    if not args.no_retraction_context:
                        win = in_scope_text(text, offsets, block, m, args.retraction_scope, args.retraction_chars)
                        mm = marker_re.search(win)
                        if mm:
                            hit["why"] = "ⓑ marker in window: " + mm.group(0); rec["retraction"].append(hit); continue
                        if args.retraction_scope != "line":
                            mc = marker_re.search(cap)
                            if mc:
                                hit["why"] = "ⓑ marker in block caption: " + mc.group(0); rec["retraction"].append(hit); continue
                    # ⓐ
                    if c["anchor_re"] is not None and not args.no_anchor:
                        win = in_scope_text(text, offsets, block, m, args.anchor_scope, args.anchor_chars)
                        am = c["anchor_re"].search(win)
                        if not am and args.anchor_scope != "line":
                            am = c["anchor_re"].search(cap)
                        if not am:
                            hit["why"] = "ⓐ no anchor in window"; rec["no_anchor"].append(hit); continue
                        hit["why"] = "ⓐ anchor: " + am.group(0)
                    # would be LIVE — an excluded-class file classifies it EXCLUDED-FILE instead (counted, shown, never rc)
                    if exlabel:
                        hit["why"] = "EXCLUDED-FILE · " + exlabel + ((" · " + hit["why"]) if hit["why"] else "")
                        rec["excluded_file"].append(hit); continue
                    rec["live"].append(hit)
    return per_token


def print_exclusions(per_pattern, no_default):
    if not per_pattern:
        print("  excluded: (none — --no-default-exclude; record- and fixture-class hits count as LIVE)")
        return
    width = max(len(p) for p, _, _ in per_pattern)
    for pat, label, rels in per_pattern:
        tag = "[--exclude]" if label == "--exclude" else "[default · %s]" % label
        shown = ", ".join(rels) if len(rels) <= 5 else "%s, … (+%d)" % (", ".join(rels[:5]), len(rels) - 5)
        print("  excluded: %-*s  %-26s → %d file%s%s" % (width, pat, tag, len(rels),
              "" if len(rels) == 1 else "s", (": " + shown) if rels else ""))


def main():
    global NFKC_ON
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--claims", required=True, help="TSV: token<TAB>anchor-regex<TAB>source")
    ap.add_argument("--root", default=".")
    ap.add_argument("--paths", nargs="*", default=None, help="pathspecs under --root (dirs · files · globs)")
    ap.add_argument("--untracked", action="store_true", help="walk the filesystem instead of `git ls-files`")
    ap.add_argument("--exclude", action="append", default=None, metavar="GLOB",
                    help="add an excluded-class pattern (root-relative fnmatch; repeatable); hits there are EXCLUDED-FILE")
    ap.add_argument("--no-default-exclude", action="store_true",
                    help="drop the default classes (%s) — their hits then count as LIVE" % ", ".join(p for p, _ in DEFAULT_EXCLUDES))
    ap.add_argument("--markers", default=DEFAULT_MARKERS, help="ⓑ retraction-marker regex (frozen vocabulary)")
    ap.add_argument("--strict-markers", action="store_true", help="ⓑ narrow vocabulary only: " + STRICT_MARKERS)
    ap.add_argument("--retraction-scope", choices=["line", "chars", "block"], default="chars")
    ap.add_argument("--retraction-chars", type=int, default=200)
    ap.add_argument("--anchor-scope", choices=["line", "chars", "block"], default="chars")
    ap.add_argument("--anchor-chars", type=int, default=200)
    ap.add_argument("--ubiquity-max-occ", type=int, default=20, help="ⓒ: refuse a bare token above this many occurrences")
    ap.add_argument("--ubiquity-max-files", type=int, default=8, help="ⓒ: refuse a bare token present in more files than this")
    ap.add_argument("--no-nfkc", action="store_true", help="disable NFKC normalization (ablation — full-width copies go silent)")
    ap.add_argument("--no-anchor", action="store_true", help="disable ⓐ (ignore anchor regexes)")
    ap.add_argument("--no-retraction-context", action="store_true", help="disable ⓑ (ablation / revert probe)")
    ap.add_argument("--no-form-rule", action="store_true", help="disable ⓒ′ (scan bare numeric tokens)")
    ap.add_argument("--no-ubiquity", action="store_true", help="disable ⓒ (scan bare tokens regardless of frequency)")
    ap.add_argument("--quote-excl", action="store_true", help="enable ⓓ (quoted span = mention)")
    ap.add_argument("--show-excluded", action="store_true",
                    help="also list EXCLUDED-FILE / retraction-context / no-anchor / mention sites as file:line")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--quiet", action="store_true", help="print only the exclusion line(s) and the verdict line")
    args = ap.parse_args()
    if args.strict_markers:
        args.markers = STRICT_MARKERS
    if args.no_nfkc:
        NFKC_ON = False
    excludes = ([] if args.no_default_exclude else list(DEFAULT_EXCLUDES)) + [(p, "--exclude") for p in (args.exclude or [])]

    if not os.path.isfile(args.claims):
        print("🟥 claims file not found: %s" % args.claims, file=sys.stderr); return 10
    claims = read_claims(args.claims)
    root = os.path.abspath(args.root)
    files = list_corpus(root, args.paths, tracked=not args.untracked)
    if not files:
        print("🟥 corpus is empty under %s (paths=%s)" % (root, args.paths), file=sys.stderr); return 10
    excluded, per_pattern = classify_excludes(files, root, excludes)
    # no corpus cut here on purpose — excluded-class files stay in `files` and are scanned (lane L12)
    if not claims:
        print("⬜ DEAD CONTROL — 0 tokens parsed from %s; %d files enumerated but NOTHING was scanned. rc=4 (not a clean scan)."
              % (args.claims, len(files)))
        return 4

    res = scan(claims, files, root, excluded, args)
    n_live = sum(len(r["live"]) for r in res.values())
    n_excl = sum(len(r["excluded_file"]) for r in res.values())
    n_retr = sum(len(r["retraction"]) for r in res.values())
    n_noanc = sum(len(r["no_anchor"]) for r in res.values())
    n_ment = sum(len(r["mention"]) for r in res.values())
    n_ref = sum(1 for r in res.values() if r["refused"])
    rc = 2 if n_live else (3 if n_ref else 0)
    verdict = ("R-claim verdict: LIVE=%d EXCLUDED-FILE=%d RETRACTION-CONTEXT=%d NO-ANCHOR=%d MENTION=%d REFUSED=%d rc=%d"
               % (n_live, n_excl, n_retr, n_noanc, n_ment, n_ref, rc))

    if args.json:
        out = {}
        for k, r in res.items():
            rr = dict(r); rr["bare_files"] = sorted(r["bare_files"])
            out[k] = rr
        print(json.dumps({"files": len(files), "root": root,
                          "excluded": {"patterns": [p for p, _, _ in per_pattern],
                                       "classes": {p: l for p, l, _ in per_pattern},
                                       "files": sorted(excluded)},
                          "mechanisms": {"nfkc": NFKC_ON, "anchor": not args.no_anchor,
                                         "retraction_context": not args.no_retraction_context,
                                         "form_rule": not args.no_form_rule, "ubiquity": not args.no_ubiquity,
                                         "quote": args.quote_excl, "markers": args.markers},
                          "summary": {"live": n_live, "excluded_file": n_excl, "retraction_context": n_retr,
                                      "no_anchor": n_noanc, "mention": n_ment, "refused": n_ref, "rc": rc},
                          "tokens": out}, ensure_ascii=False, indent=1))
        return rc

    if args.quiet:
        print_exclusions(per_pattern, args.no_default_exclude)
        print(verdict)
        return rc

    print("R-claim scan · corpus=%d files%s · root=%s" % (
        len(files), (" (%d in excluded classes — scanned, hits classified EXCLUDED-FILE)" % len(excluded)) if excluded else "", root))
    print_exclusions(per_pattern, args.no_default_exclude)
    print("  mechanisms: nfkc=%s ⓐanchor=%s(%s±%d) ⓑretract=%s(%s±%d%s) ⓒ′form=%s ⓒubiquity=%s(>%d occ|>%d files) ⓓquote=%s" % (
        "on" if NFKC_ON else "off",
        "off" if args.no_anchor else "on", args.anchor_scope, args.anchor_chars,
        "off" if args.no_retraction_context else "on", args.retraction_scope, args.retraction_chars,
        ",strict" if args.strict_markers else "",
        "off" if args.no_form_rule else "on",
        "off" if args.no_ubiquity else "on", args.ubiquity_max_occ, args.ubiquity_max_files,
        "on" if args.quote_excl else "off"))
    print("  %-18s %6s %5s  %8s %6s %7s %6s %5s  %s" % ("token", "bare", "files", "retract", "noanc", "mention", "exclf", "LIVE", "note"))
    for k, r in res.items():
        note = ""
        if r["refused"] == "form":
            note = "REFUSED by ⓒ′ (numeric FORM, no anchor supplied) — NOT scanned"
        elif r["refused"] == "ubiquity":
            note = "REFUSED by ⓒ (ubiquitous, no anchor supplied) — NOT scanned"
        print("  %-18s %6d %5d  %8d %6d %7d %6d %5d  %s" % (k, r["bare"], len(r["bare_files"]),
              len(r["retraction"]), len(r["no_anchor"]), len(r["mention"]), len(r["excluded_file"]), len(r["live"]), note))
    for k, r in res.items():
        for h in r["live"]:
            print("  🟥 LIVE   `%s`  %s:%d  [%s]  …%s…" % (k, h["file"], h["line"], h["why"], h["snippet"][:150]))
    if args.show_excluded:
        for k, r in res.items():
            for h in r["excluded_file"] + r["retraction"] + r["no_anchor"] + r["mention"]:
                print("  ⬜ excl   `%s`  %s:%d  [%s]  …%s…" % (k, h["file"], h["line"], h["why"], h["snippet"][:120]))
    elif n_excl:
        print("ⓘ %d would-be-LIVE hit(s) sit in excluded-class files — counted as EXCLUDED-FILE, not in rc; --show-excluded lists them." % n_excl)
    if n_live:
        print("ⓘ ADVISORY — MARK, DO NOT BLOCK. A LIVE hit is «the retracted token still asserted here», judged by form, not truth.")
    if n_ref:
        print("ⓘ PARTIAL — a REFUSED token was not scanned at all; this output is NOT a clean-corpus verdict for it.")
    print(verdict)
    return rc


if __name__ == "__main__":
    sys.exit(main())
