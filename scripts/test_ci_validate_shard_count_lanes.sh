#!/usr/bin/env bash
# test_ci_validate_shard_count_lanes.sh — EXECUTES the `validate` job's «Every selfcheck shard passed» step from
# .github/workflows/validate.yml under `bash -e` (GitHub's default shell for `run:`), with the leg outputs
# `needs.selfcheck.outputs` would hand it, and checks — as parsed YAML — the wiring that produces and consumes them.
#
# Why the proof changed (2026-11-17): the step used to list this run's jobs with `gh api …/attempts/…/jobs` and the
# job token. A downstream consumer on GitHub Enterprise got HTTP 401 from that call although every leg had passed, so
# their required check could never go green. The proof is now token-free: every leg's LAST step writes its own output
# key `leg_<i>=passed:<i>/<N>`; the step reads `needs.selfcheck.result` and `needs.selfcheck.outputs` only, and
# exactly the N keys must be present with exactly those values. A leg that failed, was cancelled or never got a runner
# writes nothing, so its key is missing and the step is red. There is no «could not check → pass» path.
#
# The wiring lanes enforce ONE canonical spelling (exact expressions, exact recorder command, no step condition).
# An equivalent rewrite (e.g. `toJson`, `if: ${{ success() }}`) fails them on purpose: the runtime lanes only prove
# the canonical form, so any other form must come with its own lane. Token/API checks cover the step's code and the
# step/job/workflow `env` for token names, plus a fake `gh` — not every possible network client.
#
# Not shown here: that GitHub keeps every leg's distinct key in a matrix job's outputs (runner behaviour). This
# repository's own CI shows it — the step is required and goes red if a key is lost.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WF="${VALIDATE_WF:-$HERE/../.github/workflows/validate.yml}"
[ -f "$WF" ] || { echo "HARNESS-ERROR: $WF missing"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT

# Read the workflow as GitHub does (PyYAML; CI installs it in every leg in «Lane-suite runtime prerequisites»).
# Writes: step.sh (the step's run body), n (matrix length), wiring.txt (W-lane verdicts). No PyYAML = HARNESS-ERROR.
python3 - "$WF" "$W" <<'PY'; yrc=$?
import re, sys
try:
    import yaml
except ImportError:
    print("HARNESS-ERROR: PyYAML not importable — this lane reads the workflow as YAML"); sys.exit(2)
wf = yaml.safe_load(open(sys.argv[1], encoding="utf-8")); out = sys.argv[2]
jobs = wf.get("jobs") or {}
sc, va = jobs.get("selfcheck") or {}, jobs.get("validate") or {}
vsts = [x for x in (va.get("steps") or []) if x.get("name") == "Every selfcheck shard passed"]
if len(vsts) != 1:
    print("HARNESS-ERROR: step «Every selfcheck shard passed» not found exactly once in jobs.validate"); sys.exit(2)
vst = vsts[0]
open(out + "/step.sh", "w").write(str(vst.get("run") or ""))
shards = ((sc.get("strategy") or {}).get("matrix") or {}).get("shard")
shards = shards if isinstance(shards, list) and all(type(x) is int for x in shards) else []
open(out + "/n", "w").write(str(len(shards)))
outs = sc.get("outputs") or {}
steps = sc.get("steps") or []
last = steps[-1] if steps else {}
env = vst.get("env") or {}
code = "\n".join(l for l in str(vst.get("run") or "").split("\n") if not l.strip().startswith("#"))
def shell_of(*layers):
    for d in layers:
        dr = ((d or {}).get("defaults") or {}).get("run") if isinstance(d, dict) else None
        if isinstance(dr, dict) and dr.get("shell"): return dr.get("shell")
    return None
tok = lambda d: any(k in (d or {}) for k in ("GH_TOKEN", "GITHUB_TOKEN"))
R = []
def say(i, cond, why): R.append("%s %s" % (i, "ok" if cond else "bad " + why))
say("W2", bool(shards) and sorted(shards) == list(range(1, len(shards) + 1))
    and outs == {"leg_%d" % i: "${{ steps.leg_passed.outputs.leg_%d }}" % i for i in shards},
    "matrix=%s outputs=%s" % (shards, sorted(outs)))
say("W3", str(env.get("EXPECTED_SHARDS")) == str(len(shards)), "EXPECTED_SHARDS=%s matrix=%d" % (env.get("EXPECTED_SHARDS"), len(shards)))
say("W4", last.get("id") == "leg_passed" and "if" not in last and "continue-on-error" not in last and "shell" not in last
    and str(last.get("run") or "").strip() == 'echo "leg_${{ matrix.shard }}=passed:${{ matrix.shard }}/${{ strategy.job-total }}" >> "$GITHUB_OUTPUT"'
    and sum(1 for x in steps if x.get("id") == "leg_passed") == 1,
    "last step id=%s if=%s run=%r" % (last.get("id"), last.get("if"), str(last.get("run") or "")[:60]))
say("W5", env.get("SHARDS_RESULT") == "${{ needs.selfcheck.result }}" and env.get("LEGS_JSON") == "${{ toJSON(needs.selfcheck.outputs) }}"
    and not (tok(env) or tok(va.get("env")) or tok(wf.get("env"))) and not re.search(r"\bgh\s|curl|wget|api\.github", code)
    and "actions" not in (va.get("permissions") or {}),
    "SHARDS_RESULT=%r LEGS_JSON=%r" % (env.get("SHARDS_RESULT"), env.get("LEGS_JSON")))
say("W6", bool(steps) and "continue-on-error" not in sc and not any("continue-on-error" in x for x in steps),
    "continue-on-error on the selfcheck job or one of its steps")
# W7 (codex R3): the proof must actually run, fail the job when it fails, and run in the shell this lane uses.
say("W7", "if" not in vst and "continue-on-error" not in vst and "shell" not in vst and "continue-on-error" not in va
    and shell_of(va, wf) in (None, "bash") and va.get("if") == "${{ always() }}" and va.get("needs") in ("selfcheck", ["selfcheck"]),
    "step if=%r continue-on-error=%r shell=%r · job if=%r needs=%r" % (vst.get("if"), vst.get("continue-on-error"), vst.get("shell") or shell_of(va, wf), va.get("if"), va.get("needs")))
open(out + "/wiring.txt", "w").write("\n".join(R) + "\n")
PY
[ "$yrc" -eq 0 ] || exit 2
N="$(cat "$W/n")"; { [ -s "$W/step.sh" ] && [ "$N" -ge 1 ]; } 2>/dev/null || { echo "HARNESS-ERROR: no step body or matrix length (N=$N)"; exit 2; }

# A fake `gh` that fails loudly: the token-free step must never call it.
mkdir -p "$W/bin"
printf '#!/usr/bin/env bash\necho "fake gh called: $*" >&2\necho called >> "%s/gh_calls"\nexit 1\n' "$W" > "$W/bin/gh"
chmod +x "$W/bin/gh"

pass=0; fail=0
ok()  { pass=$((pass+1)); echo "  ✅ $1"; }
bad() { fail=$((fail+1)); echo "  ❌ $1"; }
# legs <N> <mutation> — the outputs map the step would receive, built for the workflow's own N (codex R3: a fixed 4
# let an «if n == 5: pass» regression through after the matrix grew).
legs() { python3 - "$1" "$2" <<'PY'
import json, sys
n, m = int(sys.argv[1]), sys.argv[2]
d = {"leg_%d" % i: "passed:%d/%d" % (i, n) for i in range(1, n + 1)}
if m == "drop_last": d.pop("leg_%d" % n)
elif m == "empty_last": d["leg_%d" % n] = ""
elif m == "dup_first": d["leg_%d" % n] = "passed:1/%d" % n
elif m == "wrong_total": d = {k: v.rsplit("/", 1)[0] + "/%d" % (n - 1) for k, v in d.items()}
elif m == "extra": d["leg_%d" % (n + 1)] = "passed:%d/%d" % (n + 1, n)
elif m == "extra_empty": d["leg_%d" % (n + 1)] = ""
elif m == "extra_null": d["leg_%d" % (n + 1)] = None
print(json.dumps(d))
PY
}
# lane <label> <want rc 0|1> <SHARDS_RESULT> <LEGS_JSON>
lane() {
  local label="$1" want="$2" result="$3" legs="$4" out rc got=0
  out=$(env PATH="$W/bin:$PATH" SHARDS_RESULT="$result" LEGS_JSON="$legs" EXPECTED_SHARDS="$N" bash -e "$W/step.sh" 2>&1); rc=$?
  [ "$rc" -ne 0 ] && got=1
  if [ "$got" = "$want" ]; then ok "$label (rc=$rc)"
  else bad "$label (rc=$rc want=$want)"; printf '%s\n' "$out" | tail -4 | sed 's/^/       /'; fi
}
FULL="$(legs "$N" none)"
lane "V1 control: $N/$N legs recorded, result success → pass" 0 success "$FULL"
lane "V2 N-1: the last leg wrote nothing (failed/cancelled before its last step) → block" 1 success "$(legs "$N" drop_last)"
lane "V3 a key present but empty is missing, not passed → block" 1 success "$(legs "$N" empty_last)"
lane "V4 duplicate index: the last leg's key carries leg 1's label (that leg unproven) → block" 1 success "$(legs "$N" dup_first)"
lane "V5 total mismatch: legs say /$((N-1)) while $N are expected → block" 1 success "$(legs "$N" wrong_total)"
lane "V6 an unexpected extra key (matrix grew, EXPECTED_SHARDS not) → block" 1 success "$(legs "$N" extra)"
lane "V6b an unexpected extra key with an empty value is still unexpected → block" 1 success "$(legs "$N" extra_empty)"
lane "V6c an unexpected extra key with a null value is still unexpected → block" 1 success "$(legs "$N" extra_null)"
lane "V7 result failure even with every key → block" 1 failure "$FULL"
lane "V8 result cancelled → block" 1 cancelled "$FULL"
lane "V9 result skipped → block" 1 skipped "$FULL"
lane "V10 no outputs at all (empty map) → block" 1 success '{}'
lane "V11 unreadable outputs: empty string → block" 1 success ''
lane "V11b unreadable outputs: not JSON → block" 1 success 'not json'
lane "V11c unreadable outputs: a list → block" 1 success '["passed:1/1"]'
if [ -f "$W/gh_calls" ]; then bad "V12 the step called gh — the proof must be token-free"; else ok "V12 no lane called gh"; fi

while read -r id verdict rest; do
  case "$id" in
    W2) msg="matrix list is 1..N and the job declares exactly one leg_<i> output per entry" ;;
    W3) msg="EXPECTED_SHARDS equals the matrix length" ;;
    W4) msg="the selfcheck job's LAST step writes leg_<shard>=passed:<shard>/<total>, unconditionally" ;;
    W5) msg="the aggregate step reads needs.selfcheck.* and carries no token, gh/curl/wget call or actions permission" ;;
    W6) msg="no selfcheck step (or the job) has continue-on-error" ;;
    W7) msg="the aggregate step always runs, fails the job, in bash; validate keeps if: always() over needs: selfcheck" ;;
    *) continue ;;
  esac
  if [ "$verdict" = ok ]; then ok "$id $msg"; else bad "$id $msg — $rest"; fi
done < "$W/wiring.txt"

[ $((pass+fail)) -eq 22 ] || { echo "HARNESS-ERROR: counted $((pass+fail)) lanes, expected 22"; exit 2; }
echo "ci validate shard-count lanes: $pass passed · $fail failed"
[ "$fail" -eq 0 ]
