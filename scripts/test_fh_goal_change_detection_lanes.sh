#!/usr/bin/env bash
# Known-pair lane for fh-goal's change detection.
#
# 🟥 WHAT THIS EXISTS TO STOP (2026-08-26, cross-family/codex finding):
#   `git` present + a real repo does NOT mean `diff`/`status` SUCCEEDS. Before this lane,
#   a FAILING `git status` produced an empty TARGET_FILES, which the skip-branch could not
#   tell apart from "nothing changed" → `exit 0` → **fh-gate never ran, caller read it as a
#   clean run**. fh-goal.sh already named that exact class in a comment and had closed it for
#   the "no git at all" branch only.
#
# The pair:
#   ARM A (known-positive) git status FAILS         → MUST exit 10  ← red before the fix
#   ARM B (known-negative) git status OK, no output → MUST exit 0   (genuinely nothing changed)
#   ARM C (control)        git status OK, one file  → MUST reach fh-gate (proves A/B are not
#                                                     just "everything exits early")
# Without ARM C, A and B both pass on a script that never gets to the gate at all.
. "$(dirname "${BASH_SOURCE[0]}")/fixture_guard_lib.sh"   # scrub inherited GIT_* env first (#1088)
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${FH_GOAL_UNDER_TEST:-$ROOT/scripts/fh-goal.sh}"
PASS=0; FAIL=0
ok(){ printf '  ✅ %s\n' "$1"; PASS=$((PASS+1)); }
no(){ printf '  ❌ %s\n' "$1"; FAIL=$((FAIL+1)); }

FIX=$(mktemp -d); trap 'rm -rf "$FIX"' EXIT
mkdir -p "$FIX/bin" "$FIX/work"

# --- git shim: real enough to pass the GIT_OK probe, scriptable for diff/status -------------
cat > "$FIX/bin/git" <<'GIT'
#!/usr/bin/env bash
# args may be prefixed with -C <dir> and -c <key=value> (fh-goal passes -c core.quotePath=false)
while [[ "${1:-}" == "-C" || "${1:-}" == "-c" ]]; do shift 2; done
case "${1:-}" in
  rev-parse)
    case "${2:-}" in
      --git-dir) echo ".git"; exit 0 ;;
      HEAD)      echo "0000000000000000000000000000000000000000"; exit 0 ;;
    esac
    exit 0 ;;
  diff)   exit "${FAKE_GIT_DIFF_RC:-0}" ;;
  status)
    if [[ "${FAKE_GIT_STATUS_RC:-0}" -ne 0 ]]; then exit "${FAKE_GIT_STATUS_RC}"; fi
    [[ -n "${FAKE_GIT_STATUS_OUT:-}" ]] && printf '%s\n' "$FAKE_GIT_STATUS_OUT"
    exit 0 ;;
esac
exit 0
GIT
chmod +x "$FIX/bin/git"

# --- backend stub: fh-goal requires the CLI on PATH and pipes a prompt into it --------------
printf '#!/usr/bin/env bash\ncat >/dev/null\necho "stub backend output"\nexit 0\n' > "$FIX/bin/codex"
chmod +x "$FIX/bin/codex"

run_arm() {  # $1=label  $2..=env assignments ; prints rc
  env PATH="$FIX/bin:$PATH" FH_BACKEND=codex FH_TIMEOUT=20 "${@:2}" \
      bash "$TARGET" --prompt "noop" --root "$FIX/work" >"$FIX/out" 2>"$FIX/err"
  echo $?
}

echo "fh-goal change-detection known-pair (target: $TARGET)"

# ARM A — the defect
RC=$(run_arm A FAKE_GIT_STATUS_RC=128 FAKE_GIT_DIFF_RC=128)
if [[ "$RC" == "10" ]] && grep -q "cannot detect changed files" "$FIX/err"; then
  ok "ARM A known-positive: git failure → exit 10, fail-closed"
else
  no "ARM A known-positive: expected rc=10 + 'cannot detect changed files', got rc=$RC"
  sed -n 1,6p "$FIX/err" | sed 's/^/       /'
fi

# ARM B — genuinely clean
RC=$(run_arm B FAKE_GIT_STATUS_RC=0 FAKE_GIT_STATUS_OUT=)
if [[ "$RC" == "0" ]] && grep -q "no changed files detected" "$FIX/err"; then
  ok "ARM B known-negative: clean tree → exit 0 (skip is legitimate here)"
else
  no "ARM B known-negative: expected rc=0 + 'no changed files detected', got rc=$RC"
  sed -n 1,6p "$FIX/err" | sed 's/^/       /'
fi

# ARM C — control: proves the script can actually REACH the gate
RC=$(run_arm C FAKE_GIT_STATUS_RC=0 FAKE_GIT_STATUS_OUT=" M probe_file.txt")
if grep -q "running fh-gate on" "$FIX/err"; then
  ok "ARM C control: changed file → reaches fh-gate (instrument is alive)"
else
  no "ARM C control: never reached fh-gate — ARM A/B results are UNINTERPRETABLE (rc=$RC)"
  sed -n 1,6p "$FIX/err" | sed 's/^/       /'
fi

# ARM D — real git, a Korean-named untracked file: fh-goal must hand fh-gate the name itself, not git's quoted
# octal form («"\355\225…"») — 2026-11-19, the same defect fh-gate had with core.quotePath.
if command -v git >/dev/null 2>&1; then
  mkdir -p "$FIX/realbin" "$FIX/realwork"; cp "$FIX/bin/codex" "$FIX/realbin/codex"
  git -C "$FIX/realwork" init -q; echo seed > "$FIX/realwork/README"   # a HEAD for fh-goal's diff to start from
  git -C "$FIX/realwork" add README; git -C "$FIX/realwork" -c user.name=lane -c user.email=lane@example.invalid commit -qm seed
  echo "본문" > "$FIX/realwork/한글문서.md"
  # run from inside the scratch repo: fh-goal takes the work tree from the caller's folder
  ( cd "$FIX/realwork" && env PATH="$FIX/realbin:$PATH" FH_BACKEND=codex FH_TIMEOUT=20 \
      bash "$TARGET" --prompt "noop" --root "$FIX/realwork" ) >"$FIX/out" 2>"$FIX/err"
  if grep -qF "running fh-gate on 한글문서.md" "$FIX/err"; then
    ok "ARM D real git: a Korean file name reaches fh-gate as itself"
  else
    no "ARM D real git: the Korean name did not reach fh-gate as itself"
    grep -m2 "running fh-gate on\|no changed files" "$FIX/err" | sed 's/^/       /'
  fi
else
  echo "  ⬜ ARM D NOT RUN: no git on PATH — not a pass"
fi

echo "fh-goal change-detection: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]] || exit 1
