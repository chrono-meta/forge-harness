#!/usr/bin/env python3
# Known pair for check_refs.py: one input that must pass (rc 0), one that must fail (rc 1), plus unreadable (rc 2).
import os, subprocess, sys, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
CHECK = os.path.join(HERE, "check_refs.py")
LOG = "a1b2c3 feat: export button (#12)\nd4e5f6 fix: crash on empty list (#15)\n"
def run(notes, log=LOG):
    d = tempfile.mkdtemp()
    n, l = os.path.join(d, "notes.md"), os.path.join(d, "log.txt")
    open(n, "w").write(notes); open(l, "w").write(log)
    return subprocess.run([sys.executable, CHECK, n, l], capture_output=True, text=True)
cases = [
    ("pass: every cited PR is in the log", run("- Export button (#12)\n- Crash fix (#15)\n"), 0, ""),
    ("fail: #99 is not in the log", run("- Export button (#12)\n- Ghost (#99)\n"), 1, "MISSING #99"),
]
bad = 0
for name, r, rc, needle in cases:
    ok = r.returncode == rc and needle in r.stdout
    bad += not ok
    print("%s %s (rc=%d)" % ("PASS" if ok else "FAIL", name, r.returncode))
r = subprocess.run([sys.executable, CHECK, "/nonexistent/notes.md", "/nonexistent/log.txt"], capture_output=True, text=True)
ok = r.returncode == 2; bad += not ok
print("%s unreadable input is UNMEASURED (rc=%d)" % ("PASS" if ok else "FAIL", r.returncode))
sys.exit(1 if bad else 0)
