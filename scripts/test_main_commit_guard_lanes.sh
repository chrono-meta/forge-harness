#!/usr/bin/env bash
# test_main_commit_guard_lanes.sh — known pair for scripts/main_commit_guard.sh and its wiring in
# templates/.git-hooks/pre-commit. Runs in disposable clones — never touches this checkout.
#
# UNIT (the script alone, branch injected via MAIN_GUARD_BRANCH):
#   U1 main → rc=1 · U2 master → rc=1 · U3 feature branch → rc=0, silent · U4 HEAD (detached) → rc=0
#   U5 main + MAIN_COMMIT_OK=1 → rc=0 AND one log line appended (override is recorded, not just allowed)
# REAL HOOK (shallow clone, hook installed, output discriminated by the guard's own tag — the clone
# carries no marker/manifest, so OTHER axes block every commit and rc is not this lane's signal):
#   H1 FH asset staged on main            → «[main-commit]» ❌ line   (the fixed case)
#   H2 NON-FH file staged on main         → no guard line             (scope: FH assets only)
#   H3 FH asset staged on a feature branch → no guard line            (control: not unconditional)
#   H4 FH asset on main + MAIN_COMMIT_OK=1 → override line            (channel works through the hook)
# REVERT: the hook with the guard call removed must turn H1 red — else H1 is decoration.
# Usage: bash scripts/test_main_commit_guard_lanes.sh [--hook <path>]
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$ROOT/templates/.git-hooks/pre-commit"; [ "${1:-}" = "--hook" ] && HOOK="$2"
G="$ROOT/scripts/main_commit_guard.sh"
pass=0; fail=0
ok(){ printf '  ✅ %s\n' "$1"; pass=$((pass+1)); }
no(){ printf '  ❌ %s\n' "$1"; fail=$((fail+1)); }
[ -f "$G" ] || { echo "FAIL  subject absent: $G"; exit 1; }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT

echo "[main-commit-guard] unit"
mkdir -p "$T/u" && cd "$T/u" && git init -q 2>/dev/null
for b in main master; do
  out=$(MAIN_GUARD_BRANCH=$b EVIDENCE_ROOT="$T/u" bash "$G" 2>&1); rc=$?
  { [ "$rc" = 1 ] && printf '%s' "$out" | grep -q '\[main-commit\]'; } && ok "U $b → rc=1, names itself" || no "U $b → rc=$rc [$out]"
done
out=$(MAIN_GUARD_BRANCH=feat/x EVIDENCE_ROOT="$T/u" bash "$G" 2>&1); rc=$?
{ [ "$rc" = 0 ] && [ -z "$out" ]; } && ok "U3 feature branch → rc=0, silent" || no "U3 feature → rc=$rc [$out]"
out=$(MAIN_GUARD_BRANCH=HEAD EVIDENCE_ROOT="$T/u" bash "$G" 2>&1); rc=$?
[ "$rc" = 0 ] && ok "U4 detached HEAD (rebase/bisect) → rc=0" || no "U4 detached → rc=$rc"
out=$(MAIN_COMMIT_OK=1 MAIN_GUARD_BRANCH=main EVIDENCE_ROOT="$T/u" bash "$G" 2>&1); rc=$?
n=$(grep -c 'MAIN_COMMIT_OK override' "$T/u/tracks/_meta/.main_commit_override_log" 2>/dev/null); n=${n:-0}
{ [ "$rc" = 0 ] && [ "$n" = 1 ]; } && ok "U5 MAIN_COMMIT_OK=1 → rc=0 and logged once" || no "U5 override rc=$rc log=$n"

hook_case(){ # $1 label  $2 hook  $3 branch  $4 file-to-stage  $5 want(GUARD|NONE|OVERRIDE)  [$6 env]
  local label="$1" hook="$2" br="$3" f="$4" want="$5" envv="${6:-}" got out
  rm -rf "$T/r"; git clone -q --depth 1 "file://$ROOT" "$T/r" 2>/dev/null || { no "$label — clone failed"; return; }
  ( cd "$T/r" && git config user.email t@t && git config user.name t \
      && mkdir -p .git/hooks && cp "$hook" .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit \
      && cp "$G" scripts/main_commit_guard.sh \
      && git checkout -q -B "$br" ) || { no "$label — setup failed"; return; }   # the clone starts on the SOURCE's HEAD, not main
  mkdir -p "$T/r/$(dirname "$f")"; printf 'lane probe\n' >> "$T/r/$f"
  out=$(cd "$T/r" && git add "$f" && env $envv FH_SKIP_GATE_AXES=1 git commit -qm probe 2>&1)
  if printf '%s' "$out" | grep -q '❌ \[main-commit\]'; then got=GUARD
  elif printf '%s' "$out" | grep -q 'MAIN_COMMIT_OK=1 (logged)'; then got=OVERRIDE
  else got=NONE; fi
  [ "$got" = "$want" ] && ok "$label → $got" || { no "$label → $got (expected $want)"; printf '%s\n' "$out" | grep -E 'main-commit|FH 4-Axis|No FH' | head -3 | sed 's/^/       /'; }
}
if [ ! -e "$ROOT/.git" ]; then   # installed package: nothing to clone — say so, never fold into PASS
  echo "  ⏭️  SKIP (PASS 아님) — hook/revert arms need a git checkout to clone; this tree has no .git"
  echo "[main-commit-guard] $pass passed, $fail failed (hook arms skipped)"; [ "$fail" -eq 0 ]; exit $?
fi
echo "[main-commit-guard] real hook: $HOOK"
hook_case "H1 FH asset on main"               "$HOOK" main       scripts/lane_probe.sh GUARD
hook_case "H2 non-FH file on main"            "$HOOK" main       lane_probe.txt        NONE
hook_case "H3 FH asset on a feature branch"   "$HOOK" feat/lane  scripts/lane_probe.sh NONE
hook_case "H4 FH asset on main + override"    "$HOOK" main       scripts/lane_probe.sh OVERRIDE "MAIN_COMMIT_OK=1"

echo "[main-commit-guard] revert probe"
M="$T/hook_mutant"; sed 's#bash "\$MCG"#true#' "$HOOK" > "$M"
if cmp -s "$HOOK" "$M"; then no "REVERT mutant did not apply (sed matched nothing) — HARNESS-ERROR, not a pass"
else
  f0=$fail; hook_case "REVERT guard call removed → H1 must go red" "$M" main scripts/lane_probe.sh GUARD >/dev/null
  if [ "$fail" -gt "$f0" ]; then fail=$f0; ok "REVERT without the call, H1 no longer blocks — the lane measures the wiring"
  else no "REVERT H1 still GUARD with the call removed — H1 is decoration"; fi
fi
echo "[main-commit-guard] $pass passed, $fail failed"; [ "$fail" -eq 0 ]
