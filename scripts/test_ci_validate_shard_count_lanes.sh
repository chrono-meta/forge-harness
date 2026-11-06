#!/usr/bin/env bash
# test_ci_validate_shard_count_lanes.sh — EXECUTES the `validate` job's «Every selfcheck shard passed» step,
# extracted verbatim from .github/workflows/validate.yml, under `bash -e` (GitHub's default shell for `run:`),
# with a fake `gh` that answers the jobs listing from a scripted sequence.
# Why: #1029's validate went red twice on «selfcheck legs 3/3 → 2/2, expected 4» while all 4 legs had succeeded
# — the jobs listing lagged behind `needs`. The step now re-queries while the listing is incomplete (short, or a
# null conclusion), capped, and never on a recorded failure. Each lane is one listing sequence.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WF="${VALIDATE_WF:-$HERE/../.github/workflows/validate.yml}"
[ -f "$WF" ] || { echo "HARNESS-ERROR: $WF missing"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
python3 - "$WF" > "$W/step.sh" <<'PY' || { echo "HARNESS-ERROR: could not extract the step"; exit 2; }
# plain-text extraction (no PyYAML on every runner): the «run: |» block of the named step = the lines after it
# that are indented deeper than the «run:» key, de-indented by the first line's indent
import sys
L = open(sys.argv[1]).read().split("\n")
hits = [i for i, l in enumerate(L) if l.strip() == "- name: Every selfcheck shard passed"]
assert len(hits) == 1, "step not found exactly once"
i = hits[0] + 1
while not L[i].strip().startswith("run: |"):
    assert L[i].strip() and not L[i].strip().startswith("- "), "no run block in the step"
    i += 1
key = len(L[i]) - len(L[i].lstrip()); body = []
for l in L[i + 1:]:
    if l.strip() and len(l) - len(l.lstrip()) <= key: break
    body.append(l)
ind = min(len(l) - len(l.lstrip()) for l in body if l.strip())
print("\n".join(l[ind:] for l in body))
PY
grep -q 'selfcheck legs' "$W/step.sh" || { echo "HARNESS-ERROR: extracted step looks wrong"; exit 2; }
mkdir -p "$W/bin"
cat > "$W/bin/gh" <<'GH'
#!/usr/bin/env bash
n=$(cat "$SEQ/n" 2>/dev/null || echo 0); n=$((n+1)); echo $n > "$SEQ/n"
# the call itself must be the one the step means: this run ATTEMPT's jobs, every page, the shard-name filter
[ "$1 $2" = "api repos/o/r/actions/runs/1/attempts/1/jobs" ] || { echo "fake gh: wrong endpoint: $*" >&2; exit 9; }
case " $* " in *" --paginate "*) ;; *) echo "fake gh: no --paginate" >&2; exit 9 ;; esac
case "$*" in *'.jobs[] | select(.name | startswith("selfcheck (shard ")) | .conclusion'*) ;; *) echo "fake gh: jq filter changed" >&2; exit 9 ;; esac
f="$SEQ/r$n"; [ -f "$f" ] || f="$(ls "$SEQ"/r* | sort -V | tail -1)"   # past the script: repeat the last answer
[ "$(head -1 "$f")" = "FAIL" ] && exit 1
cat "$f"
GH
chmod +x "$W/bin/gh"
pass=0; fail=0
ok()  { pass=$((pass+1)); echo "  ✅ $1"; }
bad() { fail=$((fail+1)); echo "  ❌ $1"; }
# lane <label> <want rc 0|1> <want calls|-> <response>... (each response: legs separated by «,», empty = no legs)
lane() {
  local label="$1" want="$2" wcalls="$3"; shift 3
  local S="$W/seq_$((pass+fail))"; mkdir -p "$S"; local i=0
  for r in "$@"; do i=$((i+1)); printf '%s\n' "$r" | tr ',' '\n' > "$S/r$i"; done
  out=$(env PATH="$W/bin:$PATH" SEQ="$S" SHARDS_RESULT=success EXPECTED_SHARDS=4 SHARD_REQUERY_SLEEP=0 \
        GITHUB_REPOSITORY=o/r GITHUB_RUN_ID=1 GITHUB_RUN_ATTEMPT=1 bash -e "$W/step.sh" 2>&1); rc=$?
  local calls; calls=$(cat "$S/n" 2>/dev/null || echo 0)
  local got=0; [ "$rc" -ne 0 ] && got=1
  if [ "$got" = "$want" ] && { [ "$wcalls" = - ] || [ "$calls" = "$wcalls" ]; }; then ok "$label (rc=$rc, calls=$calls)"
  else bad "$label (rc=$rc want=$want, calls=$calls want=$wcalls)"; printf '%s\n' "$out" | tail -4 | sed 's/^/       /'; fi
}
S4=success,success,success,success
lane "V1 control: 4/4 success on the first listing → pass, one call" 0 1 "$S4"
lane "V2 #1029 shape: listing short twice, then complete → pass after re-query" 0 3 success,success,success success,success "$S4"
lane "V3 a null conclusion is incomplete, not a failure → re-query → pass" 0 2 success,success,success,null "$S4"
lane "V4 a recorded failure is judged at once (no re-query) → fail" 1 1 success,success,success,failure
lane "V5 listing stays short past the cap → fail-closed after 1+6 calls" 1 7 success,success,success
lane "V6 more legs than expected → fail, no re-query" 1 1 "$S4,success"
lane "V7 listing call fails → fail" 1 1 FAIL
lane "V8 cancelled leg → fail, no re-query" 1 1 success,success,success,cancelled
lane "V9 a failure in a SHORT listing is judged at once — a later 4/4 must not wash it out (codex R1)" 1 1 success,failure "$S4"
lane "V10 a failure beside a null is judged at once" 1 1 success,success,null,failure "$S4"
lane "V11 an empty listing re-queries under bash -e (not an early exit) → pass" 0 2 "" "$S4"
lane "V12 all-null listing (0 successes) re-queries → pass" 0 2 null,null,null,null "$S4"
[ $((pass+fail)) -eq 12 ] || { echo "HARNESS-ERROR: counted $((pass+fail)) lanes, expected 12"; exit 2; }
echo "ci validate shard-count lanes: $pass passed · $fail failed"
[ "$fail" -eq 0 ]
