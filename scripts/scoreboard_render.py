#!/usr/bin/env python3
"""scoreboard_render.py <entries.json> [--out FILE] [--exclude-patterns FILE] — render a measurement scoreboard.

WHY: a page that shows «what a person gets from FH / FoD» as percentages is only worth reading if no number on it
was picked by hand and every kind of outcome shows — wins, no difference, not detected, ceiling, claim not supported.
So this script does not take numbers on trust. Each entry in the index names a sealed pre-registration and a result
file, and carries the k/n it claims plus an exact quote from the result. A row is rendered only if all of this holds:

  SEAL     the pre-registration commit is on a remote branch of its repo, and came before the result (repos are
           compared by their real path, not by their key in the index):
           same repo -> it is a strict ancestor of the commit that first wrote the quoted result text
           (git log -S; a result appended to the pre-registration file later counts from that later commit);
           different repos -> its commit time is earlier than that commit's time (named residual: commit times
           can be set by hand; ancestry cannot be checked across repositories).
  ANCHOR   the quote occurs verbatim in the result file at the stated ref, and every declared «k/n» occurs in the quote,
           written «k/n» or «k of n» (an arm may instead carry a printed «value» such as 0.417, which must occur in the
           quote as a whole number; an entry without arms shows a «value» that must itself occur in the quote). The seal
           commit must touch the named pre-registration file.
  OUTCOME  one of WIN · NO-DIFFERENCE · NOT-DETECTED · CEILING · CLAIM-NOT-SUPPORTED — the result's pre-registered
           decision. A number that comes from a section the result itself marks exploratory carries «exploratory: true»
           and outcome EXPLORATORY; it is rendered in its own section and never counted with the decisions.
  NOT COMPANY  the entry's repo is not marked company, and no exclude pattern matches its paths or quote.

  PUSHED   the result commit is on a remote branch too: a public page does not cite an unpushed result.
  CI       a CI is shown only if the entry carries one that occurs in the quote.
Named residual: the result's first commit is searched on the ref and on every remote branch (a squash-merged main has
no ancestry back to the seal). A different branch that carried the same quote earlier can make a valid row fail —
the error is toward excluding, never toward showing.

Anything that fails is listed under «excluded» with its reason — never rendered as a row, never silently dropped.
Rows are grouped by the measure they report; the page never pools unlike measures into one headline percentage.
A CI is shown only where the result reports one; this script computes none.

exit: 0 rendered · 2 UNMEASURED (unreadable index, a repo path missing, git unavailable). An excluded row is not
an error; it is shown as excluded.
"""
import json
import os
import re
import subprocess
import sys

OUTCOMES = ("WIN", "NO-DIFFERENCE", "NOT-DETECTED", "CEILING", "CLAIM-NOT-SUPPORTED")
EXPLORATORY = "EXPLORATORY"   # not a decision: its own section, never in the outcome counts
LABEL = {"WIN": "win", "NO-DIFFERENCE": "NO DIFFERENCE", "NOT-DETECTED": "NOT-DETECTED", "CEILING": "CEILING",
         "CLAIM-NOT-SUPPORTED": "claim not supported"}


def die(msg):
    print(f"UNMEASURED: {msg}")
    sys.exit(2)


def git(repo, *args):
    try:
        # --literal-pathspecs: a named path is that file, never a glob (cross-family R3: «p*.md» matched public.md)
        p = subprocess.run(["git", "-C", repo, "--literal-pathspecs", *args], capture_output=True, text=True,
                           stdin=subprocess.DEVNULL)
    except OSError as e:
        die(f"git could not run ({type(e).__name__})")
    return p.returncode, p.stdout.strip()


def num_in(lit, text):
    """A printed number (or k/n pair) as a whole: «2/10» not inside «12/100» or «2/10.5», «0.41» not inside «0.417»
    (cross-family R1)."""
    return re.search(r"(?<![\d.+\-−])" + re.escape(lit) + r"(?!\d|\.\d)", text) is not None   # not «-0.417» either


VALUE_SHAPE = re.compile(r"[-−+]?\d+(?:\.\d+)?%?")   # a printed number, nothing that can span two quotes
EXPLORE_HEAD = re.compile(r"exploratory|탐색", re.I)


def headings(body):
    """(offset, level, text) for every markdown heading: ATX (up to 3 spaces of indent) and setext (=== / ---)."""
    out, pos, prev = [], 0, None
    for line in body.splitlines(keepends=True):
        m = re.match(r" {0,3}(#{1,6})(?:[ \t]+(.*?))?[ \t#]*$", line.rstrip("\r\n"))
        if m:
            out.append((pos, len(m.group(1)), m.group(2) or ""))
            prev = None
        elif prev is not None and re.fullmatch(r" {0,3}(=+|-+)[ \t]*", line.rstrip("\r\n")):
            out.append((prev[0], 1 if "=" in line else 2, prev[1].strip()))
            prev = None
        else:
            stripped = line.strip()
            prev = (pos, stripped) if stripped and not stripped.startswith("|") else None
        pos += len(line)
    return out


def exploratory_at(heads, offset):
    """Is the nearest heading before offset, or any shallower ancestor of it, marked exploratory?"""
    level = 7
    for off, lv, text in reversed([h for h in heads if h[0] < offset]):
        if lv < level:
            if EXPLORE_HEAD.search(text):
                return True
            level = lv
    return False


def under_exploratory_heading(body, quote):
    """True if any occurrence of the quote starts under, ends under, or crosses a heading that the result itself
    marks exploratory — such a number is not a pre-registered decision, whatever the index says."""
    heads, start = headings(body), 0
    while (i := body.find(quote, start)) != -1:
        j = i + len(quote)
        if exploratory_at(heads, i + 1) or exploratory_at(heads, j) or \
                any(i <= off < j and EXPLORE_HEAD.search(text) for off, _, text in heads):
            return True
        start = i + 1
    return False


def frac_in(k, n, text):
    """k/n as a whole number pair, written «k/n» or «k of n» (results print both)."""
    return num_in(f"{k}/{n}", text) or num_in(f"{k} of {n}", text)


def first_quote(repo, ref, path, quote):
    """The oldest commit, on ref or any remote branch, that introduced the quoted text into path — when the result was
    written down. Remote branches count because a squash-merged main has no ancestry back to the seal; the feature
    branch that carried the run does."""
    rc, out = git(repo, "log", "-S", quote, "--format=%H %ct", "--date-order", ref, "--remotes", "--", path)
    if rc != 0 or not out:
        return None, None
    sha, ct = out.splitlines()[-1].split()
    return sha, int(ct)


def commit_time(repo, sha):
    rc, out = git(repo, "show", "-s", "--format=%ct", sha)
    return int(out) if rc == 0 and out.isdigit() else None


def on_remote(repo, sha):
    rc, out = git(repo, "branch", "-r", "--contains", sha)
    return rc == 0 and bool(out.strip())


def check(e, repos, patterns):
    """Return None if the entry may be rendered, else the reason it is excluded."""
    for k in ("id", "group", "measure", "outcome", "model", "date", "prereg", "result", "quote"):
        if not e.get(k):
            return f"missing field {k}"
    if e.get("exploratory") is True:
        if e["outcome"] != EXPLORATORY:
            return f"an exploratory entry carries outcome {EXPLORATORY}, not {e['outcome']!r} (it is not a decision)"
    elif e["outcome"] not in OUTCOMES:
        return f"outcome {e['outcome']!r} is not one of {', '.join(OUTCOMES)}" + (
            " (EXPLORATORY needs «exploratory: true»)" if e["outcome"] == EXPLORATORY else "")
    pr, rs = e["prereg"], e["result"]
    for side in (pr, rs):
        r = repos.get(side.get("repo"))
        if r is None:
            return f"unknown repo {side.get('repo')!r}"
        if r.get("company"):
            return "company record (excluded at the source)"
    quotes = e["quote"] if isinstance(e["quote"], list) else [e["quote"]]
    if not all(isinstance(q, str) and q.strip() for q in quotes):
        return "empty quote"
    text_for_scan = " ".join([pr.get("path", ""), rs.get("path", ""), e["measure"], *quotes])
    for pat in patterns:
        if pat.search(text_for_scan):
            return "matches an exclude pattern (company or private token)"
    if not pr.get("path") or not rs.get("path") or not rs.get("ref"):
        return "pre-registration path, result path or result ref is empty"
    prepo, rrepo = repos[pr["repo"]]["path"], repos[rs["repo"]]["path"]
    same_repo = os.path.realpath(prepo) == os.path.realpath(rrepo)   # identity, not the index key
    # SEAL
    seal = pr.get("seal")
    if not seal:
        return "no seal commit named"
    rc, full = git(prepo, "rev-parse", "--verify", "-q", f"{seal}^{{commit}}")
    if rc != 0 or not full:
        return f"seal {seal} not found in {pr['repo']}"
    seal = full                            # an abbreviated hash or a ref would defeat the same-commit test
    if not on_remote(prepo, seal):
        return f"seal {seal[:9]} is on no remote branch (not pushed)"
    if not git(prepo, "show", "--name-only", "--format=", seal, "--", pr.get("path", ""))[1]:
        return f"seal {seal[:9]} does not touch the pre-registration file {pr.get('path')}"
    for q in quotes:                      # the seal must come before every quoted result line
        rsha, rct = first_quote(rrepo, rs["ref"], rs["path"], q)
        if rsha is None:
            return f"quote not found in the history of {rs['path']} at {rs['ref']}"
        if not on_remote(rrepo, rsha):
            return "result commit is on no remote branch"
        if same_repo:
            if seal == rsha:
                return "pre-registration and result appear in the same commit (no seal)"
            if git(prepo, "merge-base", "--is-ancestor", seal, rsha)[0] != 0:
                return "seal is not an ancestor of the result commit"
        else:
            st = commit_time(prepo, seal)
            if st is None or st >= rct:
                return "seal commit is not earlier than the result commit"
    rc, refsha = git(rrepo, "rev-parse", "--verify", "-q", f"{rs['ref']}^{{commit}}")
    if rc != 0 or not on_remote(rrepo, refsha):
        return f"result ref {rs['ref']} is not on a remote branch (a public page cites no unpushed result)"
    # ANCHOR
    rc, body = git(rrepo, "show", f"{rs['ref']}:{rs['path']}")
    if rc != 0:
        return "result file unreadable at ref"
    if any(q not in body for q in quotes):
        return "quote not found verbatim in the result file"
    joined = "\n".join(quotes)
    if e.get("exploratory") is not True and any(under_exploratory_heading(body, q) for q in quotes):
        return "quote sits under a heading the result marks exploratory — flag the entry «exploratory: true»"
    for arm in e.get("arms", []):
        if "value" in arm and "k" not in arm and "n" not in arm:
            v = arm["value"]
            if not isinstance(v, str) or not VALUE_SHAPE.fullmatch(v):
                return f"arm {arm.get('label')!r} value must be a printed number"
            if not any(num_in(v, q) for q in quotes):
                return f"declared value {v} ({arm.get('label')}) not in the quote as a whole number"
            continue
        if not isinstance(arm.get("k"), int) or not isinstance(arm.get("n"), int) or arm["n"] <= 0 or arm["k"] < 0:
            return f"arm {arm.get('label')!r} needs whole numbers with n > 0 (a 0/0 has no percentage)"
        if not any(frac_in(arm["k"], arm["n"], q) for q in quotes):
            return f"declared {arm['k']}/{arm['n']} ({arm['label']}) not in the quote"
    if e.get("ci") and not any(e["ci"] in q for q in quotes):
        return "the CI shown is not in the quote (this script computes none and copies none it cannot find)"
    if not e.get("arms"):
        if not e.get("value") or not any(e["value"] in q for q in quotes):
            return "no k/n arms, and the displayed value is not a substring of the quote"
    return None


def cell(v):
    """Index text goes into a markdown table: a pipe or a newline must not open a new cell (cross-family R2)."""
    return str(v).replace("\\", "\\\\").replace("|", "\\|").replace("\r", " ").replace("\n", " ")


def fmt_arms(e):
    out = []
    for a in e.get("arms", []):
        if "k" not in a:
            out.append(f"{cell(a['label'])} {cell(a['value'])}")
            continue
        pct = 100.0 * a["k"] / a["n"] if a["n"] else 0.0
        out.append(f"{cell(a['label'])} {a['k']}/{a['n']} ({pct:.0f}%)")
    return " vs ".join(out) if out else cell(e.get("value", ""))


def link(side):
    return cell(f"`{side['repo']}:{side['path']}`" + (f" @{side['seal'][:9]}" if side.get("seal") else f" @{side['ref']}"))


def main(argv):
    if not argv or argv[0] in ("-h", "--help"):
        print(__doc__); return 0
    try:
        idx = json.load(open(argv[0], encoding="utf-8"))
    except (OSError, ValueError) as e:
        die(f"index unreadable ({type(e).__name__})")
    out_path = None
    patterns = []
    if "--out" in argv:
        out_path = argv[argv.index("--out") + 1]
    if "--exclude-patterns" in argv:
        pf = argv[argv.index("--exclude-patterns") + 1]
        try:
            for line in open(pf, encoding="utf-8"):
                line = line.rstrip("\n")
                if not line.strip() or line.lstrip().startswith("#"):
                    continue
                pat = line.split("\t", 1)[-1]
                patterns.append(re.compile(pat, re.I))
        except (OSError, re.error) as e:
            die(f"exclude patterns unreadable ({type(e).__name__})")
    repos = {}
    for k, v in idx.get("repos", {}).items():
        p = os.path.expanduser(os.path.expandvars(v.get("path", "")))
        if not os.path.isdir(p):
            die(f"repo {k} not found at {p}")
        repos[k] = dict(v, path=p)
    try:
        if subprocess.run(["git", "--version"], capture_output=True).returncode != 0:
            die("git unavailable")
    except OSError:
        die("git unavailable")
    shown, excluded = [], []
    for e in idx.get("entries", []):
        why = check(e, repos, patterns)
        (excluded if why else shown).append((e, why))
    groups = idx.get("groups") or {}
    used = {e["group"] for e, _ in shown} | {s.get("group") for s in idx.get("slots", [])}
    order = list(groups) + sorted(g for g in used - set(groups) if g)
    L = [f"# {idx.get('title', 'Measurement scoreboard')}", "",
         "> Generated by `scripts/scoreboard_render.py` from sealed measurement records. Do not edit by hand.",
         "> A row appears only if its pre-registration was pushed before the result, and its numbers are quoted",
         "> verbatim from that result. Every outcome shows; unlike measures are never pooled into one figure.", ""]
    explore = [e for e, _ in shown if e.get("exploratory") is True]
    shown = [(e, w) for e, w in shown if e.get("exploratory") is not True]
    counts = {o: 0 for o in OUTCOMES}
    for e, _ in shown:
        counts[e["outcome"]] += 1
    L.append("Rows by outcome: " + " · ".join(f"{LABEL[o]} {counts[o]}" for o in OUTCOMES)
             + f" · exploratory {len(explore)} · excluded {len(excluded)}")
    L.append("")
    for g in order:
        rows = [e for e, _ in shown if e["group"] == g]
        slots = [s for s in idx.get("slots", []) if s.get("group") == g]
        if not rows and not slots:
            continue
        L += [f"## {groups.get(g, g)}", "",
              "| Measure | Result | 95% CI | Outcome | Model | Date | Pre-registration | Result file |",
              "|---|---|---|---|---|---|---|---|"]
        for s in slots:
            L.append(f"| {cell(s['measure'])} | *result not landed* | — | pending | — | — | — | — |")
        for e in rows:
            ci = cell(e.get("ci") or "CI not computed")
            L.append(f"| {cell(e['measure'])} | {fmt_arms(e)} | {ci} | {LABEL[e['outcome']]} | {cell(e['model'])} | {cell(e['date'])} "
                     f"| {link(e['prereg'])} | {link(e['result'])} |")
        L.append("")
    if explore:
        L += ["## Exploratory (not a pre-registered decision)", "",
              "> Numbers the result itself marks exploratory. They are quoted and sealed like the rows above, but no",
              "> decision rule was set for them in advance, so they carry no outcome and are not in the counts.", "",
              "| Measure | Result | 95% CI | Group | Model | Date | Pre-registration | Result file |",
              "|---|---|---|---|---|---|---|---|"]
        for e in explore:
            ci = cell(e.get("ci") or "CI not computed")
            L.append(f"| {cell(e['measure'])} | {fmt_arms(e)} | {ci} | {cell(groups.get(e['group'], e['group']))} "
                     f"| {cell(e['model'])} | {cell(e['date'])} | {link(e['prereg'])} | {link(e['result'])} |")
        L.append("")
    if excluded:
        L += ["## Excluded (not rendered)", "", "| Entry | Reason |", "|---|---|"]
        for e, why in excluded:
            L.append(f"| {cell(e.get('id', '?'))} | {cell(why)} |")
        L.append("")
    page = "\n".join(L)
    if out_path:
        open(out_path, "w", encoding="utf-8").write(page)
    else:
        print(page)
    print(f"scoreboard: rendered {len(shown)} · exploratory {len(explore)} · excluded {len(excluded)} · " +
          " · ".join(f"{o} {counts[o]}" for o in OUTCOMES), file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
