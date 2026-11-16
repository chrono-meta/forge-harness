#!/usr/bin/env python3
"""builder_card_files_check.py — after a builder dispatch, did the change stay inside the card's file roles?

WHY (AQ-20261104-3 + AQ-20261105-3, material candidate FH-6). A builder's Context Card states its
constraints in prose («do not touch the hooks»). Prose cannot be compared with what the builder did.
This types the constraint into four file roles and compares them with the changed-file list:

    files:
      editable:     scripts/foo.py            the builder may change these
      required:     scripts/test_foo_lanes.sh the builder must change or create these
      inspect-only: CLAUDE.md                 may be read, must not change
      protected:    templates/.git-hooks/**   must not change (the case the check exists for)

Source of the roles: arXiv:2611.01265 (pilot, n=40 — weak evidence, so this ships as a record check
with no effect claim). Source of «who runs it»: arXiv:2611.05094 — an orchestrator that checked its own
blocks recorded out-of-scope changes in 11 of 247 checks; the file-list check belongs to a hook or a
sidecar, not to the author. Both are digest citations (frontier_digest 2026-11-04 / 11-05).

WHAT IT ASSERTS — a property of the record (CLAUDE.md §Mechanization Boundary), not a judgment:
  changed ∩ protected = ∅ · changed ∩ inspect-only = ∅ · changed ⊆ editable ∪ required · every
  required pattern matches ≥1 changed path. A path that matches several roles takes the strictest:
  protected > inspect-only > required > editable.

EMPTY INPUT IS NOT A PASS (feedback_not_found_is_not_zero_family, 7th face). A card with no
`files:` block, no editable/required role, or no protected role is HARNESS-ERROR: «∩ protected = ∅»
over an empty protected set is true for every diff. A key inside the block that is not exactly one of
the four roles (`read-only:`, `Protected:`, `protect:`) is HARNESS-ERROR too — a typo must not drop a
role silently, even when a correct line is also present.

CHANGED FILES = what the builder left, committed or not: `git diff --name-only <base>` (tracked, against
the working tree) ∪ `git diff --cached <base>` (the index — a staged edit whose file was restored on
disk) ∪ untracked files (`git ls-files --others --exclude-standard`); NUL-separated, renames on both
sides, submodule gitlinks never ignored by config. Or `--changed FILE` (one path per line) for a list taken elsewhere. Counts are printed every
run, so a check that saw 0 changed paths says so.

Usage: builder_card_files_check.py --card CARD (--repo DIR --base REF | --changed FILE) [--json]
Exit:  0 CLEAN · 1 VIOLATION · 2 HARNESS-ERROR (never a pass)

NAMED RESIDUALS: ⓐ it checks paths, not content — a builder that edits an editable file in a way the
card forbids passes. ⓑ git-ignored files the builder wrote are invisible (exclude-standard). ⓒ the
record is only as independent as whoever runs this: run it from the governor or a sidecar against
the builder's tree, never inside the builder's own turn.
"""
import argparse, json, re, subprocess, sys

ROLES = ("protected", "inspect-only", "required", "editable")          # strictest first
NEAR = re.compile(r"^\s*-?\s*([A-Za-z][\w .-]*?)\s*[:：]", re.UNICODE)


class HarnessError(Exception):
    pass


def glob_re(pat):
    """`**` any depth, `*` / `?` within one segment, trailing `/` = whole directory."""
    if pat.endswith("/"):
        pat += "**"
    tail = ""
    if pat.endswith("/**"):          # «dir/» and «dir/**» also match the entry «dir» itself (a gitlink, a deleted dir)
        pat, tail = pat[:-3], "(?:/.*)?"
    out, i = "", 0
    while i < len(pat):
        if pat.startswith("**/", i):
            out += "(?:.*/)?"; i += 3
        elif pat.startswith("**", i):
            out += ".*"; i += 2
        elif pat[i] == "*":
            out += "[^/]*"; i += 1
        elif pat[i] == "?":
            out += "[^/]"; i += 1
        else:
            out += re.escape(pat[i]); i += 1
    return re.compile(out + tail + r"\Z", re.DOTALL)   # a newline in a name must not escape protected (codex R2)


def parse_card(text):
    """{role: [pattern]} from the first `files:` block (indented lines under it)."""
    lines = text.splitlines()
    heads = [i for i, l in enumerate(lines) if re.match(r"^\s*files\s*[:：]", l)]
    if not heads:
        raise HarnessError("card has no `files:` block — nothing typed to check against")
    if len(heads) > 1:      # a second block would be read by nobody (codex R1)
        raise HarnessError("card has %d `files:` blocks — exactly one is allowed" % len(heads))
    start = heads[0]
    if not re.match(r"^\s*files\s*:\s*$", lines[start]):
        raise HarnessError("`files:` header must stand alone on its line: %r" % lines[start].strip())
    indent = len(lines[start]) - len(lines[start].lstrip())
    roles = {r: [] for r in ROLES}
    for l in lines[start + 1:]:
        if not l.strip():
            continue        # a blank line does not end the block — only a dedent does (codex R1)
        if len(l) - len(l.lstrip()) <= indent:
            break
        m = re.match(r"^\s*-?\s*(protected|inspect-only|required|editable):\s*(\S.*?)\s*$", l)
        if m:
            roles[m.group(1)].append(m.group(2))
            continue
        k = NEAR.match(l)
        raise HarnessError("unknown key in files block: %r — roles are exactly %s"
                           % (k.group(1) if k else l.strip(), ", ".join(ROLES)))
    if not roles["protected"]:
        raise HarnessError("card declares no protected path — «changed ∩ protected = ∅» would pass for any diff")
    if not (roles["editable"] or roles["required"]):
        raise HarnessError("card declares no editable or required path — every change would read as undeclared")
    return roles


def git(repo, *args):
    """NUL-separated output: quoted / escaped names (core.quotepath, tabs, newlines) never reach the matcher (codex R1)."""
    r = subprocess.run(["git", "-C", repo] + list(args), capture_output=True)
    if r.returncode != 0:
        raise HarnessError("git %s failed (rc %d): %s" % (" ".join(args), r.returncode,
                           r.stderr.decode("utf-8", "replace").strip()[:200]))
    return [x.decode("utf-8", "surrogateescape") for x in r.stdout.split(b"\0") if x]


def changed_from_git(repo, base):
    top = subprocess.run(["git", "-C", repo, "rev-parse", "--show-toplevel"], capture_output=True, text=True)
    if top.returncode != 0:
        raise HarnessError("not a git work tree: %s" % repo)
    repo = top.stdout.strip()        # collect from the root: a subdirectory + diff.relative hides the rest (codex R2)
    git(repo, "rev-parse", "--verify", "--quiet", base + "^{commit}")
    hidden = [l[2:] for l in git(repo, "ls-files", "-z", "-v") if l[:1].islower() or l[:1] == "S"]
    if hidden:                       # assume-unchanged / skip-worktree: diff cannot see edits to these (codex R2)
        raise HarnessError("%d tracked path(s) carry assume-unchanged/skip-worktree — the diff cannot see them: %s"
                           % (len(hidden), ", ".join(hidden[:5])))
    common = ["--name-only", "-z", "--no-renames", "--no-relative", "--ignore-submodules=none"]
    worktree = git(repo, "diff", *common, base)                  # base → working tree
    index = git(repo, "diff", "--cached", *common, base)         # base → index: a staged edit hidden by a restored file
    untracked = git(repo, "ls-files", "-z", "--others", "--exclude-standard")
    return sorted(set(worktree) | set(index) | set(untracked))


def check(roles, changed):
    comp = {r: [(p, glob_re(p)) for p in roles[r]] for r in ROLES}
    viol, hit_required = [], set()
    for path in changed:
        role = next((r for r in ROLES if any(rx.match(path) for _, rx in comp[r])), None)
        if role == "required":
            hit_required.update(p for p, rx in comp["required"] if rx.match(path))
        if role in ("protected", "inspect-only"):      # FH6-PROTECTED-CHECK
            viol.append(("touched-" + role, path))
        elif role is None:
            viol.append(("undeclared", path))
    for p in roles["required"]:
        if p not in hit_required:
            viol.append(("required-missing", p))
    return viol


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--card", required=True)
    ap.add_argument("--repo"); ap.add_argument("--base"); ap.add_argument("--changed")
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args(argv)
    res = {"verdict": None, "counts": {}, "violations": []}
    try:
        try:
            roles = parse_card(open(a.card, encoding="utf-8").read())
        except OSError as e:
            raise HarnessError("card unreadable: %s" % e)
        if a.changed and (a.repo or a.base):
            raise HarnessError("give --changed OR --repo/--base, not both")
        if a.changed:
            try:
                changed = sorted({l.rstrip("\r\n") for l in open(a.changed, encoding="utf-8", newline="")
                                  if l.rstrip("\r\n")})   # never strip spaces: «safe » is not «safe» (codex R1)
            except OSError as e:
                raise HarnessError("changed list unreadable: %s" % e)
            bad = [c for c in changed if c.startswith("/") or any(seg in (".", "..", "") for seg in c.split("/"))]
            if bad:              # «./hooks/x» or «a/../hooks/x» would slip past «hooks/**» (codex R2)
                raise HarnessError("changed list has non-canonical paths (absolute, ./, ../ or //): %s" % ", ".join(bad[:5]))
        elif a.repo and a.base:
            changed = changed_from_git(a.repo, a.base)
        else:
            raise HarnessError("need --changed FILE or both --repo and --base")
        res["counts"] = dict({r: len(roles[r]) for r in ROLES}, changed=len(changed))
        res["violations"] = [{"kind": k, "path": p} for k, p in check(roles, changed)]
        res["verdict"] = "VIOLATION" if res["violations"] else "CLEAN"
    except HarnessError as e:
        res["verdict"], res["error"] = "HARNESS-ERROR", str(e)
    if a.json:
        print(json.dumps(res, ensure_ascii=False))
    else:
        c = res["counts"]
        if c:
            print("card: " + " · ".join("%s=%d" % (r, c[r]) for r in ROLES) + " · changed=%d" % c["changed"])
        for v in res["violations"]:
            print("%s: %s" % (v["kind"], v["path"]))
        if "error" in res:
            print("error: " + res["error"])
        print("VERDICT=" + res["verdict"])
    return {"CLEAN": 0, "VIOLATION": 1}.get(res["verdict"], 2)


if __name__ == "__main__":
    sys.exit(main())
