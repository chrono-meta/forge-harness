#!/usr/bin/env python3
"""cartridge_loader.py — core SessionStart hook: put the operator's enabled cartridges into the session.

WHY. A cartridge's skill only helps if the session uses it. Activity cartridges (the request names the job) are
called from their description; method cartridges (they change HOW work is done) were never self-invoked — 0 Skill
calls in 108 sessions with the cartridge installed (fh-cartridges C2) — while the same text injected at session start
by a hook passed 12/12 tasks, off 0/12 (C2c). Modules may not open SessionStart themselves (fh_module_contract §1.5),
so the loader is core-owned: the operator decides what loads, by writing a list.

LIST. One line per cartridge: `<admitted snapshot folder> sha256:<64 hex>`. `#` comments and blank lines are ignored;
a relative folder is relative to the list file; `~` expands. Where it is read from, first hit wins:
  1. $FH_CARTRIDGES_ENABLED
  2. $CLAUDE_PROJECT_DIR/.claude/cartridges.enabled   (else ./.claude/cartridges.enabled)
The operator writes it. Example: templates/cartridges.enabled.example. The digest is the `snapshot_sha256` that
`python3 scripts/cartridge_admit.py <plugin dir> --json --keep-snapshot <dir>` prints on ADMIT.

ONE READ. Each listed folder is read ONCE into memory (regular files only — a symlink or special file anywhere in it
skips the cartridge, as admission does), hashed exactly as cartridge_admit.tree_hash hashes a folder, and the
manifest and entry text are taken from those same bytes. What is injected is what was hashed.

WHAT IS INJECTED. Every `load.entry` file of the cartridge, under one marker line
`[FH cartridge loaded: <plugin> · sha256:<12>]` (plugin = the manifest's name when it is a plain slug, else the folder
name). Manifest prose such as `applies_when` is NOT injected: it is author-written description, never routing
authority. Skipped, one stderr line each: `kind: activity` (it routes itself), digest mismatch, missing folder,
symlink or special file, entry outside the snapshot or missing, entry over MAX_ENTRY_CHARS, total over MAX_TOTAL_CHARS,
a folder over MAX_TREE_BYTES / MAX_TREE_FILES, a malformed line, list lines past MAX_LIST_LINES, anything left when
DEADLINE_S runs out.

EXIT. Always 0 — a session-start hook does not block the session. Nothing to inject = no stdout. No list = nothing
injected and ONE stderr line, not an error. Writes no file (bytecode off: `sys.dont_write_bytecode`; the snippet also
runs `python3 -B`).

NAMED RESIDUALS. ⓐ Trust root: whoever can write the list file, a listed snapshot folder, or this script (it runs from
the project like every FH core hook) can change what loads — the digest pins the content the list names, not who
wrote the list. ⓑ A file swapped between the type check and the read is caught only for the last path component
(O_NOFOLLOW), not for a swapped parent folder. ⓒ cartridge.yaml is read by a small line parser: `plugin:` and
`kind:` as plain scalars (an inline ` # comment` is dropped), `load.entry` as a flow list `[a, b]` or a block list of
unquoted paths; any other shape is reported, never guessed. Standard library only.
"""
import hashlib
import json
import os
import re
import stat
import sys
import time

sys.dont_write_bytecode = True

MAX_ENTRY_CHARS = 20000
MAX_TOTAL_CHARS = 60000
MAX_TREE_BYTES = 2 * 1024 * 1024
MAX_TREE_FILES = 500
MAX_LIST_BYTES = 64 * 1024
MAX_LIST_LINES = 200
DEADLINE_S = 5.0
HEX64 = re.compile(r"^sha256:([0-9a-f]{64})$")
SLUG = re.compile(r"^[a-z0-9][a-z0-9._-]{0,63}$")


class Skip(Exception):
    pass


def say(msg):
    try:
        sys.stderr.write("[cartridge_loader] %s\n" % msg)
    except Exception:  # noqa: BLE001 — a hook must not fail on its own diagnostics
        pass


def list_path():
    env = os.environ.get("FH_CARTRIDGES_ENABLED")
    if env:
        return env
    base = os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()
    return os.path.join(base, ".claude", "cartridges.enabled")


def read_regular(path, limit):
    """Bytes of a regular file, opened without following a final symlink and without blocking on a FIFO."""
    fd = os.open(path, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0) | getattr(os, "O_NONBLOCK", 0))
    try:
        st = os.fstat(fd)
        if not stat.S_ISREG(st.st_mode):
            raise Skip("not a regular file")
        if st.st_size > limit:
            raise Skip("%d bytes, over the %d-byte limit" % (st.st_size, limit))
        chunks, n = [], 0
        while True:
            b = os.read(fd, 65536)
            if not b:
                break
            n += len(b)
            if n > limit:
                raise Skip("grew past the %d-byte limit while reading" % limit)
            chunks.append(b)
        return b"".join(chunks)
    finally:
        os.close(fd)


def capture(root, deadline):
    """Read the folder once: {relpath: bytes} for files, plus its digest computed exactly as
    cartridge_admit.tree_hash does (same entry order, same record format). Symlinks / special files → Skip."""
    items = []
    for base, dirs, files in os.walk(root):
        for n in dirs + files:
            p = os.path.join(base, n)
            st = os.lstat(p)
            if stat.S_ISLNK(st.st_mode):
                raise Skip("contains a symlink (%s) — admission forbids them" % os.path.relpath(p, root))
            if stat.S_ISDIR(st.st_mode):
                items.append((os.path.relpath(p, root), "d"))
            elif stat.S_ISREG(st.st_mode):
                items.append((os.path.relpath(p, root), "f"))
            else:
                raise Skip("contains a special file (%s)" % os.path.relpath(p, root))
    items.sort()
    files = [r for r, k in items if k == "f"]
    if len(files) > MAX_TREE_FILES:
        raise Skip("%d files, over the %d-file limit" % (len(files), MAX_TREE_FILES))
    h, data, total = hashlib.sha256(), {}, 0
    for rel, kind in items:
        if time.monotonic() > deadline:
            raise Skip("ran out of time while reading")
        content = b""
        if kind == "f":
            content = read_regular(os.path.join(root, rel), MAX_TREE_BYTES - total)
            total += len(content)
            data[rel] = content
        name = rel.encode("utf-8", "surrogateescape")
        h.update(kind.encode() + len(name).to_bytes(8, "big") + name + len(content).to_bytes(8, "big") + content)
    return h.hexdigest(), data


def scalar(lines, key):
    for ln in lines:
        m = re.match(r"^%s:\s*(.*?)\s*$" % re.escape(key), ln)
        if m:
            v = re.sub(r"\s+#.*$", "", m.group(1)).strip()
            if len(v) >= 2 and v[0] == v[-1] and v[0] in "\"'":
                v = v[1:-1]
            return v
    return None


def entries(lines):
    """load.entry as a list of strings, or None when the shape is not one this parser reads."""
    for i, ln in enumerate(lines):
        if re.match(r"^load:\s*(#.*)?$", ln.rstrip()):
            for j in range(i + 1, len(lines)):
                sub = lines[j]
                if sub and not sub.startswith((" ", "\t")):
                    return None
                m = re.match(r"^\s+entry:\s*\[(.*)\]\s*(#.*)?$", sub)
                if m:
                    items = [x.strip() for x in m.group(1).split(",") if x.strip()]
                    return None if any(c in x for x in items for c in "\"'[]{}#") else items
                if re.match(r"^\s+entry:\s*(#.*)?$", sub):
                    out = []
                    for k in range(j + 1, len(lines)):
                        mm = re.match(r"^\s+-\s+(.+?)\s*$", lines[k])
                        if not mm:
                            break
                        item = re.sub(r"\s+#.*$", "", mm.group(1)).strip()
                        if any(c in item for c in "\"'[]{}"):
                            return None
                        out.append(item)
                    return out or None
            return None
    return None


def load_one(folder, want, deadline):
    if not os.path.isdir(folder):
        raise Skip("is not a folder")
    got, data = capture(folder, deadline)
    if got != want:
        raise Skip("digest mismatch (listed %s…, folder %s…)" % (want[:12], got[:12]))
    if "cartridge.yaml" not in data:
        raise Skip("has no cartridge.yaml")
    try:
        man = data["cartridge.yaml"].decode("utf-8").splitlines()
    except UnicodeDecodeError:
        raise Skip("cartridge.yaml is not UTF-8")
    name = scalar(man, "plugin") or ""
    plugin = name if SLUG.match(name) else os.path.basename(folder)
    if (scalar(man, "kind") or "").lower() == "activity":
        raise Skip("is kind: activity — it routes itself from its description; not injected")
    ents = entries(man)
    if not ents:
        raise Skip("load.entry missing or in a shape this loader does not read")
    texts = []
    for e in ents:
        rel = os.path.normpath(e)
        if os.path.isabs(e) or rel.startswith(".."):
            raise Skip("entry %s is outside the snapshot" % e)
        if rel not in data:
            raise Skip("entry %s is not a file in the snapshot" % e)
        try:
            t = data[rel].decode("utf-8")
        except UnicodeDecodeError:
            raise Skip("entry %s is not UTF-8" % e)
        if len(t) > MAX_ENTRY_CHARS:
            raise Skip("entry %s is %d chars, over the %d-char cap" % (e, len(t), MAX_ENTRY_CHARS))
        texts.append(t)
    return "[FH cartridge loaded: %s · sha256:%s]\n%s" % (plugin, want[:12], "\n".join(texts))


def main():
    deadline = time.monotonic() + DEADLINE_S
    lp = list_path()
    if not os.path.lexists(lp):
        say("no enabled list at %s — nothing injected" % lp)
        return 0
    try:
        raw = read_regular(lp, MAX_LIST_BYTES).decode("utf-8").splitlines()
    except (OSError, UnicodeDecodeError, Skip) as e:
        say("enabled list %s unreadable (%s) — nothing injected" % (lp, e if isinstance(e, Skip) else type(e).__name__))
        return 0

    blocks, total, loaded, counted = [], 0, set(), 0
    for n, line in enumerate(raw, 1):
        s = line.strip()
        if not s or s.startswith("#"):
            continue
        counted += 1
        if counted > MAX_LIST_LINES:
            say("more than %d entries — line %d and after skipped" % (MAX_LIST_LINES, n))
            break
        if time.monotonic() > deadline:
            say("ran out of time — line %d and after skipped" % n)
            break
        parts = s.rsplit(None, 1)
        if len(parts) != 2 or not HEX64.match(parts[1]):
            say("line %d malformed (want «<folder> sha256:<64 hex>») — skipped" % n)
            continue
        folder = os.path.expanduser(parts[0])
        if not os.path.isabs(folder):
            folder = os.path.join(os.path.dirname(os.path.abspath(lp)), folder)
        folder = os.path.abspath(folder)
        if folder in loaded:
            continue                       # dedupe successful loads only: a stale line never hides a good one
        try:
            block = load_one(folder, HEX64.match(parts[1]).group(1), deadline)
        except Skip as e:
            say("line %d: %s %s — skipped" % (n, folder, e))
            continue
        except OSError as e:
            say("line %d: %s could not be read (%s) — skipped" % (n, folder, type(e).__name__))
            continue
        if total + len(block) > MAX_TOTAL_CHARS:
            say("line %d: %s would take the session over the %d-char total — skipped" % (n, folder, MAX_TOTAL_CHARS))
            continue
        total += len(block)
        loaded.add(folder)
        blocks.append(block)

    if blocks:
        out = {"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": "\n\n".join(blocks)}}
        sys.stdout.write(json.dumps(out, ensure_ascii=False) + "\n")
    return 0


if __name__ == "__main__":
    try:
        rc = main()
    except Exception as e:  # noqa: BLE001 — never block a session start; say what happened
        say("internal error %s: %s — nothing injected" % (type(e).__name__, e))
        rc = 0
    sys.exit(rc)
