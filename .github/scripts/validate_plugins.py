import json
import sys
from pathlib import Path

required = ["name", "version", "description", "author", "engines"]
author_fields = ["name", "email"]
placeholder_markers = ["contributor@example.com", "harness-contributor"]

failures = []

for path in sorted(Path("plugins").glob("*/.claude-plugin/plugin.json")):
    print(f"Checking {path}...")
    with open(path) as fp:
        p = json.load(fp)

    missing = [k for k in required if k not in p]
    if missing:
        failures.append(f"FAIL {path}: missing fields {missing}")
        continue

    for af in author_fields:
        if af not in p.get("author", {}):
            failures.append(f"FAIL {path}: author.{af} missing")

    if "claudeCode" not in p.get("engines", {}):
        failures.append(f"FAIL {path}: engines.claudeCode missing")

    raw = json.dumps(p)
    for m in placeholder_markers:
        if m in raw:
            failures.append(f"FAIL {path}: placeholder value '{m}' still present")

    if not failures:
        print(f"PASS {path}")

if failures:
    for f in failures:
        print(f)
    sys.exit(1)
