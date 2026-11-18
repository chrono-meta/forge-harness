#!/usr/bin/env python3
# Every (#N) cited in the notes must appear in the git log text. rc 0 all found, 1 missing, 2 unreadable.
import re, sys
try:
    notes = open(sys.argv[1], encoding="utf-8").read()
    log = open(sys.argv[2], encoding="utf-8").read()
except (IndexError, OSError) as e:
    print("UNMEASURED: %s" % e); sys.exit(2)
missing = sorted(set(re.findall(r"\(#(\d+)\)", notes)) - set(re.findall(r"#(\d+)", log)), key=int)
for n in missing:
    print("MISSING #%s" % n)
sys.exit(1 if missing else 0)
