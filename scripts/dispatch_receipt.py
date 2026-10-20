#!/usr/bin/env python3
"""dispatch_receipt.py — the governor's own receipt for edit work a dispatched agent says it did.

Why (2026-10-20): an agent's hand-back («committed 7f2acd2, 11 files, tests green») is a claim. CLAUDE.md §Agent Dispatch
says a sidecar's findings stay evidence until the governor closes each against a mechanical anchor — for EDIT work there was
no anchor, so the close step read the agent's own summary. Outside anchors for the same gap: arXiv:2610.15459 and «report ≠
change» (frontier digest 2026-10-20). This prints what the repository says, measured by the governor, and with a claim
compares it with the files the agent named.

Usage: python3 scripts/dispatch_receipt.py <repo-or-worktree> <base-ref> [--claimed a,b,...] [--claimed-file F] [--head REF]
  --claimed       comma-separated paths. An empty entry, a duplicate or a path with leading/trailing space is REFUSED (rc 2):
                  a claim is never silently rewritten. Paths containing a comma need --claimed-file.
  --claimed-file  one path per line (or NUL-separated if the file contains NUL bytes), same refusal rules.
Prints head sha · branch · commits base..head · per-path line (sha256 prefix of the blob at head, «deleted», «submodule <sha>»,
«symlink <sha>») · uncommitted(tracked) / untracked counts.
Exit: 0 = receipt printed and the claim (if any) equals the changed set exactly · 1 = claim differs (named both ways), or tracked
changes are not committed · 2 = usage / malformed claim · 10 = harness error (any git call failed, base is not an ancestor of head).
🟥 Rename detection is OFF: a move lists both the old and the new path — every affected path, independent of git config.
🟥 «0 paths» is not a pass when a claim names files: rc 1.
🟥 Named residual (codex R3, rounds capped there): the receipt overrides the git settings that changed its answer in review
   (GIT_* env, replace refs, diff.relative, ignoreSubmodules, fileMode, quotePath) and measures from the top level. It still
   trusts the rest of the repository's own config and hooks-free plumbing; it is a receipt for cooperative dispatch, not a
   sandbox for a hostile repository.
"""
import hashlib, os, subprocess, sys

# 🟥 codex R3: inherited GIT_DIR / GIT_WORK_TREE / GIT_INDEX_FILE … would make it measure another repository — drop every GIT_*
#    variable, then set only what the receipt needs. Replacement refs off: the printed sha must be the measured history.
ENV = {k: v for k, v in os.environ.items() if not k.startswith("GIT_")}
ENV.update(GIT_OPTIONAL_LOCKS="0", GIT_TERMINAL_PROMPT="0", GIT_LITERAL_PATHSPECS="1", GIT_NO_REPLACE_OBJECTS="1", LC_ALL="C")


class HarnessError(Exception):
    pass


def git(repo, *args):
    r = subprocess.run(["git", "-C", repo, "-c", "core.fsmonitor=false", "-c", "core.quotePath=false",
                        "-c", "diff.ignoreSubmodules=none", "-c", "status.showUntrackedFiles=normal",
                        "-c", "diff.relative=false", "-c", "core.fileMode=true", *args],
                       capture_output=True, env=ENV)
    if r.returncode != 0:
        raise HarnessError("git %s failed (rc=%d): %s" % (" ".join(args[:2]), r.returncode,
                                                          r.stderr.decode("utf-8", "replace").strip()[:200]))
    return r.stdout


def usage(msg):
    print("usage: dispatch_receipt.py <repo-or-worktree> <base-ref> [--claimed a,b] [--claimed-file F] [--head REF]", file=sys.stderr)
    if msg:
        print("  " + msg, file=sys.stderr)
    return 2


def parse_claim(entries, origin):
    """→ (set of paths, error or None). Nothing is normalised: an ambiguous entry is an error, not a guess."""
    seen = []
    for e in entries:
        if e == "":
            return None, "empty entry in %s (a trailing or doubled separator?)" % origin
        if e != e.strip():
            return None, "entry with leading/trailing space in %s: %r — say exactly which path" % (origin, e)
        if e in seen:
            return None, "duplicate entry in %s: %r" % (origin, e)
        seen.append(e)
    return set(seen), None


def main(argv):
    if len(argv) < 2:
        return usage("")
    repo, base, rest = argv[0], argv[1], argv[2:]
    head_ref, claim, have_claim = "HEAD", set(), False
    i = 0
    while i < len(rest):
        a = rest[i]
        if a in ("--claimed", "--claimed-file", "--head") and i + 1 >= len(rest):
            return usage("%s needs a value" % a)
        if a == "--head":
            head_ref = rest[i + 1]
        elif a == "--claimed":
            got, err = parse_claim(rest[i + 1].split(","), "--claimed")
            if err:
                return usage(err)
            if claim & got:
                return usage("duplicate entry across claim options: %r" % sorted(claim & got)[0])
            claim |= got; have_claim = True
        elif a == "--claimed-file":
            try:
                raw = open(rest[i + 1], "rb").read().decode("utf-8")
            except (OSError, UnicodeDecodeError) as exc:
                return usage("cannot read --claimed-file: %s" % exc)
            parts = raw.split("\0") if "\0" in raw else raw.split("\n")
            if parts and parts[-1] == "":
                parts.pop()                                   # ONE final terminator is normal; a second one is an empty entry
            got, err = parse_claim(parts, "--claimed-file")
            if err:
                return usage(err)
            if claim & got:
                return usage("duplicate entry across claim options: %r" % sorted(claim & got)[0])
            claim |= got; have_claim = True
        else:
            return usage("unknown argument %r" % a)
        i += 2
    if not os.path.isdir(repo):
        print("HARNESS-ERROR: not a directory: %s" % repo, file=sys.stderr); return 10
    try:
        repo = git(repo, "rev-parse", "--show-toplevel").decode().strip()   # codex R3: a subdirectory must not narrow the diff
        head = git(repo, "rev-parse", "--verify", "--quiet", head_ref + "^{commit}").decode().strip()
        base_sha = git(repo, "rev-parse", "--verify", "--quiet", base + "^{commit}").decode().strip()
        r = subprocess.run(["git", "-C", repo, "merge-base", "--is-ancestor", base_sha, head], capture_output=True, env=ENV)
        if r.returncode == 1:
            raise HarnessError("base %s is not an ancestor of head %s — the receipt would mix unrelated history" % (base_sha[:12], head[:12]))
        if r.returncode != 0:
            raise HarnessError("merge-base failed (rc=%d)" % r.returncode)
        b = subprocess.run(["git", "-C", repo, "symbolic-ref", "--quiet", "--short", "HEAD"], capture_output=True, env=ENV)
        branch = b.stdout.decode().strip() if b.returncode == 0 else "(detached)"
        commits = int(git(repo, "rev-list", "--count", "%s..%s" % (base_sha, head)).decode().strip())
        paths = [p.decode("utf-8", "surrogateescape") for p in
                 git(repo, "diff", "--name-only", "-z", "--no-renames", "--ignore-submodules=none", base_sha, head).split(b"\0") if p]
        lines = []
        for p in paths:
            t = git(repo, "ls-tree", "-z", head, "--", p).split(b"\0")[0]
            if not t:
                prev = git(repo, "ls-tree", "-z", base_sha, "--", p).split(b"\0")[0]
                if not prev:
                    raise HarnessError("path %r is in the diff but in neither tree" % p)
                lines.append(("deleted", p)); continue
            meta, _, _name = t.partition(b"\t")
            mode, typ, obj = meta.decode().split(" ")
            if typ == "commit":
                lines.append(("submodule " + obj[:12], p)); continue
            if typ != "blob":
                raise HarnessError("unexpected object type %s for %r" % (typ, p))
            data = git(repo, "cat-file", "blob", obj)
            tag = hashlib.sha256(data).hexdigest()[:16]
            lines.append((("symlink " if mode == "120000" else "") + tag, p))
        st = git(repo, "status", "--porcelain=v1", "-z", "--untracked-files=normal", "--ignore-submodules=none").split(b"\0")
        # assume-unchanged (h) / skip-worktree (S) entries are invisible to status — count them, they make «committed» unprovable
        hidden = sum(1 for e in git(repo, "ls-files", "-v", "-z").split(b"\0") if e[:1] in (b"h", b"S", b"s"))
        dirty = untracked = 0
        skip = False
        for e in st:
            if skip:
                skip = False; continue
            if not e:
                continue
            code = e[:2]
            if code == b"??":
                untracked += 1
            else:
                dirty += 1
                if code[:1] in (b"R", b"C"):
                    skip = True                                # rename/copy entries carry the source path as the next field
    except HarnessError as exc:
        print("HARNESS-ERROR: %s" % exc, file=sys.stderr); return 10
    print("receipt  repo=%s" % repo)
    print("         head=%s branch=%s base=%s" % (head, branch, base_sha))
    print("         commits=%d paths=%d" % (commits, len(paths)))
    print("         uncommitted(tracked)=%d untracked=%d hidden-from-status=%d" % (dirty, untracked, hidden))
    for tag, p in lines:
        print("  path  %-18s %s" % (tag, p))
    rc = 0
    if dirty:
        print("NOT-COMMITTED: %d tracked path(s) changed but not committed — the receipt covers commits only" % dirty); rc = 1
    if hidden:
        print("UNPROVABLE-CLEAN: %d path(s) marked assume-unchanged/skip-worktree — status cannot show their edits" % hidden); rc = 1
    if have_claim:
        actual = set(paths)
        missing, extra = sorted(claim - actual), sorted(actual - claim)
        if missing:
            print("CLAIMED-NOT-CHANGED:"); [print("  " + p) for p in missing]; rc = 1
        if extra:
            print("CHANGED-NOT-CLAIMED:"); [print("  " + p) for p in extra]; rc = 1
        if not missing and not extra:
            print("CLAIMED-MATCHES: %d path(s)" % len(claim))
    return rc


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except Exception as exc:                                  # an instrument crash is never a pass
        print("HARNESS-ERROR: %s: %s" % (type(exc).__name__, exc), file=sys.stderr)
        sys.exit(10)
