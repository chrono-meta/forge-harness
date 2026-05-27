import json
import sys

placeholder_markers = ["contributor@example.com", "harness-contributor"]

with open(".claude-plugin/marketplace.json") as fp:
    m = json.load(fp)

assert "name" in m, "marketplace.json missing 'name'"
assert "owner" in m, "marketplace.json missing 'owner'"
assert "plugins" in m, "marketplace.json missing 'plugins'"

for p in m["plugins"]:
    assert "name" in p and "version" in p and "source" in p, f"plugin entry incomplete: {p}"

raw = json.dumps(m)
for marker in placeholder_markers:
    if marker in raw:
        print(f"FAIL marketplace.json: placeholder '{marker}' still present")
        sys.exit(1)

print("PASS marketplace.json")
