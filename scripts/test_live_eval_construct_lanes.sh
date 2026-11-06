#!/usr/bin/env bash
# test_live_eval_construct_lanes.sh — the live-eval «construct validity» record (2026-11-06).
# Record only: what a probe CLAIMS vs what its pattern can SEE. These lanes pin that the record is carried,
# that a missing or unknown value is UNDECLARED (never read as «same»), that a bad value does not drop the
# probe from the run (scoring is untouched), and that the real probes_live.yaml declares every selected probe.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$HERE/probe_live_eval_lib.py" ] || { echo "HARNESS-ERROR: probe_live_eval_lib.py missing"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/probes.md" <<'EOF'
| ID | Input | Expected | Source | Class |
|---|---|---|---|---|
| `G-A-01` | "안녕" | x | y | mandatory-pass |
| `G-B-01` | "hello there" | x | y | mandatory-pass |
| `G-C-01` | "hi again" | x | y | mandatory-pass |
EOF
cat > "$W/live.yaml" <<'EOF'
probes:
  - id: G-A-01
    polarity: present
    input: "안녕"
    expect_re: "x"
    control_input: "y"
    construct: proxy
    claims: "a claim"
    unseen: "the order"
  - id: G-B-01
    polarity: present
    input: "hello there"
    expect_re: "x"
    control_input: "y"
  - id: G-C-01
    polarity: present
    input: "hi again"
    expect_re: "x"
    control_input: "y"
    construct: obviously-fine
EOF
python3 - "$HERE" "$W" <<'PY'
import sys; sys.path.insert(0, sys.argv[1])
import probe_live_eval_lib as L
W = sys.argv[2]
md, live = L.parse_probes_md(W + "/probes.md"), L.parse_probes_live(W + "/live.yaml")
r = L.build_selection(md, live)
sel = {e["id"]: e for e in r["selected"]}
fails = 0
def lane(name, ok):
    global fails
    print(("  ✅ " if ok else "  ❌ ") + name)
    fails += 0 if ok else 1
lane("K1 a declared probe carries construct/claims/unseen", sel.get("G-A-01", {}).get("construct") == "proxy" and sel["G-A-01"].get("unseen") == "the order")
lane("K2 a probe with no declaration is UNDECLARED, not «same», and is warned about", sel.get("G-B-01", {}).get("construct") == "UNDECLARED" and any("UNDECLARED-CONSTRUCT: G-B-01" in w for w in r["warnings"]))
lane("K3 an unknown value is UNDECLARED with a BAD-CONSTRUCT warning — and the probe still runs", sel.get("G-C-01", {}).get("construct") == "UNDECLARED" and any("BAD-CONSTRUCT: G-C-01" in w for w in r["warnings"]))
md_out = "\n".join(L.render_construct_md(r["selected"]))
lane("K4 the report section counts each class and names what each probe cannot see", "proxy 1 · UNDECLARED 2" in md_out and "| G-A-01 | proxy | a claim | the order |" in md_out)
# K5: the same probes with every construct/claims/unseen line removed select the same ids with identical scoring fields
import re as _re
bare = W + "/bare.yaml"
open(bare, "w").write("\n".join(l for l in open(W + "/live.yaml").read().split("\n") if not _re.match(r"^\s+(construct|claims|unseen):", l)))
rb = L.build_selection(md, L.parse_probes_live(bare))
keys = ("id", "input", "control_input", "polarity", "expect_re", "control_input_b", "advisory_re")
strip = lambda es: [{k: e.get(k) for k in keys} for e in es]
lane("K5 record only — with and without the declarations, the selection and every scoring field are identical", strip(r["selected"]) == strip(rb["selected"]) and [e["id"] for e in r["excluded"]] == [e["id"] for e in rb["excluded"]])
lane("K7 the nightly report itself carries the section (not only the helper)", "## Construct validity (record only" in L.render_report_md(r, None, "2026-11-06"))
real = L.build_selection(L.parse_probes_md(sys.argv[1] + "/../.claude/regression/probes.md"), L.parse_probes_live(sys.argv[1] + "/../.claude/regression/probes_live.yaml"))
und = [e["id"] for e in real["selected"] if e.get("construct") == "UNDECLARED"]
lane("K6 the real probes_live.yaml declares every selected probe (%d selected, undeclared=%s)" % (len(real["selected"]), und or 0), len(real["selected"]) > 0 and not und)
print("live-eval construct lanes: %d passed · %d failed" % (7 - fails, fails))
sys.exit(1 if fails else 0)
PY
