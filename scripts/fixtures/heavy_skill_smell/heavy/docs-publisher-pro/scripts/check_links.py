#!/usr/bin/env python3
# Relative links in docs/*.md must point to existing files; #anchors must match a heading in the target.
# rc 0 all good, 1 broken links listed, 2 could not read the folder.
import os, re, sys
root = sys.argv[1] if len(sys.argv) > 1 else "docs"
if not os.path.isdir(root):
    print("UNMEASURED: no folder %s" % root); sys.exit(2)
def slug(h): return re.sub(r"[^a-z0-9 -]", "", h.lower()).strip().replace(" ", "-")
bad = []
for d, _, fs in os.walk(root):
    for f in fs:
        if not f.endswith(".md"):
            continue
        p = os.path.join(d, f)
        for m in re.finditer(r"\]\(([^)#:]+\.md)?(#[^)]+)?\)", open(p, encoding="utf-8").read()):
            target = os.path.normpath(os.path.join(d, m.group(1))) if m.group(1) else p
            if not os.path.exists(target):
                bad.append("%s -> %s (missing file)" % (p, m.group(1))); continue
            if m.group(2):
                heads = [slug(h) for h in re.findall(r"^#+\s+(.*)$", open(target, encoding="utf-8").read(), re.M)]
                if m.group(2)[1:] not in heads:
                    bad.append("%s -> %s%s (missing anchor)" % (p, m.group(1) or "", m.group(2)))
for b in bad:
    print("BROKEN " + b)
sys.exit(1 if bad else 0)
