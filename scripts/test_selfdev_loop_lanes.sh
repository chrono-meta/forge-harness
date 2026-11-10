#!/usr/bin/env bash
# test_selfdev_loop_lanes.sh — EXECUTES scripts/selfdev_loop.sh's merge pass, hermetically.
# A fixture «live» repo (with a local bare origin), a fake `gh` on PATH that answers by --json field,
# SELFDEV_DRY_RUN=1 (no build, no merge — the pass prints WOULD MERGE / HOLD into the report).
# Why this file exists: the loop's merge pass is the one place an unattended change can reach main;
# until 2026-11-04 it had only been dry-run by hand with no open PR, i.e. never exercised at all
# (CI new-code-anchor: «MENTION_ONLY»). Each lane is one condition the policy says must HOLD,
# with LP1 as the positive control that the same fixture CAN reach WOULD MERGE. LP12/LP13: SELFDEV_NO_MERGE=1
# stops a passing PR at ELIGIBLE and still holds a failing one. LP20/LP21 (2026-11-10 watchdog kill): a killed
# build's unpushed commits are named STRANDED; the builder prompt names the watchdog's own limit.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for f in selfdev_loop.sh selfdev_queue.py selfdev_merge_tier.sh; do
  [ -f "$HERE/$f" ] || { echo "HARNESS-ERROR: $HERE/$f missing"; exit 2; }
done
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
pass=0; fail=0
# the stub builders finish at once; a 20 s watchdog poll per build run cost the file > 300 s in CI
export SELFDEV_POLL=1
ok()  { pass=$((pass+1)); echo "  ✅ $1"; }
bad() { fail=$((fail+1)); echo "  ❌ $1"; }
DATE="$(date +%Y-%m-%d)"
REQ='레인 하나 더 달자'
OID_A=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa

# setup <id> — builds $W/<id>/{origin.git,live,clone,bin,knobs}
setup() {
  local D="$W/$1"; mkdir -p "$D/knobs" "$D/bin" "$D/clone/tracks/_meta"
  git init -q --bare "$D/origin.git"
  git clone -q "$D/origin.git" "$D/live" 2>/dev/null
  ( cd "$D/live" && git config user.email t@t && git config user.name t \
    && mkdir -p scripts tracks/_meta && echo x > README.md && git add README.md \
    && git commit -qm init && git push -q origin HEAD:main 2>/dev/null )
  cp "$HERE/selfdev_loop.sh" "$HERE/selfdev_queue.py" "$HERE/selfdev_merge_tier.sh" "$D/live/scripts/"
  printf 'print("# correction moments — stub")\n' > "$D/live/scripts/correction_moments.py"
  printf '%s\n%s\n| 1 | 11-01 | %s | 🟡PARTIAL | x | 레인 미작성 | 이월 |\n' \
    '| # | 시각 | 발화(요지) | 상태 | 증거 | 사유 / 남은 것 | 제안(이번 세션 vs 이월) |' '|---|---|---|---|---|---|---|' "$REQ" \
    > "$D/live/tracks/_meta/session_checklist_${DATE}_x.md"
  printf 'crossfamily: panel(codex) — residency=CLEAN(files=1) · evidence=SHARED(diff) · R1 0\n' \
    > "$D/clone/tracks/_meta/.axes_23_passed_auto_selfdev-x_${DATE}.marker"
  # default knobs = everything the policy wants
  printf 'seed: human\nrequest: «%s»\nwhat changed: a lane\n' "$REQ" > "$D/knobs/body"
  printf 'pass\npass\n' > "$D/knobs/checks"
  printf 'ADDED\tdocs/x.md\t3\t0\n' > "$D/knobs/files"
  echo "$OID_A" > "$D/knobs/oid1"; echo "$OID_A" > "$D/knobs/oid2"
  cat > "$D/bin/gh" <<GH
#!/usr/bin/env bash
K="$D/knobs"
[ -f "\$K/fail_list" ] && [ "\$1 \$2" = "pr list" ] && exit 1
json=""; prev=""
for a in "\$@"; do [ "\$prev" = "--json" ] && json="\$a"; prev="\$a"; done
case "\$1 \$2|\$json" in
  "pr list|number,headRefName") echo 5 ;;
  "pr checks|bucket") cat "\$K/checks" ;;
  "pr view|headRefOid")
     n=\$(cat "\$K/n" 2>/dev/null || echo 0); n=\$((n+1)); echo \$n > "\$K/n"; cat "\$K/oid1" ;;
  "pr view|headRefOid,body") cat "\$K/oid2"; cat "\$K/body" ;;
  "pr view|body,headRefName") cat "\$K/body" ;;
  "pr view|headRefName") echo auto/selfdev-x ;;
  "pr view|files") cat "\$K/files" ;;
  *) echo "fake gh: unhandled \$*" >&2; exit 3 ;;
esac
GH
  chmod +x "$D/bin/gh"
}
run() { # <id> [VAR=value ...] → $RC, $REP (report text)
  local D="$W/$1"; shift
  OUT=$(cd "$D/live" && env PATH="$D/bin:$PATH" SELFDEV_DRY_RUN=1 FH_SELFDEV_DIR="$D/clone" "$@" \
        bash scripts/selfdev_loop.sh 2>&1); RC=$?
  REP="$(cat "$D/live/tracks/_meta/selfdev/report_$DATE.md" 2>/dev/null)"
}
expect() { # <lane label> <needle in report>
  if [ "$RC" -eq 0 ] && printf '%s\n' "$REP" | grep -qF -- "$2"; then ok "$1"
  else bad "$1 (rc=$RC, want «$2»)"; printf '%s\n' "$REP" "$OUT" | tail -6 | sed 's/^/       /'; fi
}

setup p1; run p1; expect "LP1 control: every condition met → WOULD MERGE" "#5 WOULD MERGE"
setup p2; printf 'seed: human\nrequest: «레인»\n' > "$W/p2/knobs/body"; run p2
expect "LP2 request is a fragment of the operator row → HOLD" "request-not-in-queue"
setup p3; printf 'seed: candidate (digest)\n' > "$W/p3/knobs/body"; run p3
expect "LP3 machine-proposed candidate → HOLD" "seed-candidate"
setup p4; printf 'pass\nskipping\n' > "$W/p4/knobs/checks"; run p4
expect "LP4 a skipped check is not a pass → HOLD" "ci-fail-or-skipped"
setup p5; ( cd "$W/p5/live" && git commit -q --allow-empty -m 'Revert "selfdev: x"' && git push -q origin HEAD:main 2>/dev/null ); run p5
expect "LP5 operator revert of a selfdev merge → DEMOTED, HOLD" "demoted"
setup p6; printf 'MODIFIED\ttemplates/.git-hooks/pre-commit\t2\t0\n' > "$W/p6/knobs/files"; run p6
expect "LP6 forbidden path → HOLD via tier" "tier:HOLD"
setup p7; : > "$W/p7/knobs/fail_list"; run p7
if [ "$RC" -eq 2 ] && printf '%s\n' "$REP" | grep -qF 'HARNESS-ERROR'; then ok "LP7 open-PR listing fails → rc 2 HARNESS-ERROR, not «no PRs»"
else bad "LP7 (rc=$RC)"; printf '%s\n' "$REP" | tail -3 | sed 's/^/       /'; fi
setup p8; echo bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb > "$W/p8/knobs/oid2"; run p8
expect "LP8 head moved between the checks and the final snapshot → HOLD" "head moved during checks"
setup p9; rm -f "$W/p9/clone/tracks/_meta/".axes_23_passed_*; run p9
expect "LP9 no 4-axis marker for the branch → HOLD" "no-marker"
setup p10; printf 'crossfamily: DEGRADED_SINGLE_FAMILY — codex down\n' > "$W/p10/clone/tracks/_meta/.axes_23_passed_auto_selfdev-x_${DATE}.marker"; run p10
expect "LP10 cross-family degraded → HOLD" "crossfamily-not-panel"
setup p11; printf 'seed: human\nrequest: «%s»\n' "$REQ" > "$W/p11/knobs/body"; printf 'seed: human\nrequest: «다른 요청»\n' > "$W/p11/b2"
#   body edited after the first read: the final snapshot carries a different request
cp "$W/p11/b2" "$W/p11/knobs/body2"; sed -i.bak 's#"pr view|headRefOid,body") cat "$K/oid2"; cat "$K/body" ;;#"pr view|headRefOid,body") cat "$K/oid2"; cat "$K/body2" ;;#' "$W/p11/bin/gh"
grep -q 'body2' "$W/p11/bin/gh" || { echo "HARNESS-ERROR: LP11 fixture edit did not apply"; exit 2; }
run p11; expect "LP11 request changed at the final snapshot → HOLD" "request changed or unauthorized"

setup p12; run p12 SELFDEV_NO_MERGE=1
if [ "$RC" -eq 0 ] && printf '%s\n' "$REP" | grep -qF '#5 ELIGIBLE (no-merge mode' && ! printf '%s\n' "$REP" | grep -qE 'WOULD MERGE|MERGED'; then
  ok "LP12 no-merge mode: the same fixture as LP1 stops at ELIGIBLE, never WOULD MERGE"
else bad "LP12 (rc=$RC)"; printf '%s\n' "$REP" | tail -4 | sed 's/^/       /'; fi
setup p13; printf 'seed: candidate\n' > "$W/p13/knobs/body"; run p13 SELFDEV_NO_MERGE=1
expect "LP13 no-merge mode does not skip the checks: a candidate is still HOLD, not ELIGIBLE" "seed-candidate"

# real-run lanes (DRY=0): the merge helper is a stub that records its call. The clone is a git dir with an
# untracked marker, i.e. dirty → the loop skips the build (no claude call) and still runs the merge pass.
realrun() { # <id> [VAR=value ...]
  local D="$W/$1"; shift
  git -C "$D/clone" init -q
  printf '#!/usr/bin/env bash\necho called >> "%s/merge_called"; echo "stub merge"\n' "$D" > "$D/live/scripts/pr_merge_verified.sh"
  OUT=$(cd "$D/live" && env PATH="$D/bin:$PATH" SELFDEV_DRY_RUN=0 FH_SELFDEV_DIR="$D/clone" "$@" \
        bash scripts/selfdev_loop.sh 2>&1); RC=$?
  REP="$(cat "$D/live/tracks/_meta/selfdev/report_$DATE.md" 2>/dev/null)"
}
setup p14; realrun p14 SELFDEV_NO_MERGE=1
if [ "$RC" -eq 0 ] && printf '%s\n' "$REP" | grep -qF '#5 ELIGIBLE (no-merge mode' && [ ! -e "$W/p14/merge_called" ]; then
  ok "LP14 real run, no-merge: ELIGIBLE and the merge helper is never called"
else bad "LP14 (rc=$RC, called=$([ -e "$W/p14/merge_called" ] && echo yes || echo no))"; printf '%s\n' "$REP" "$OUT" | tail -5 | sed 's/^/       /'; fi
setup p15; realrun p15
if [ -e "$W/p15/merge_called" ]; then ok "LP15 control: the same real run without the switch DOES call the merge helper (LP14 can see a call)"
else bad "LP15 (merge helper not called — LP14 would be blind)"; printf '%s\n' "$REP" | tail -4 | sed 's/^/       /'; fi
setup p16; realrun p16 SELFDEV_NO_MERGE=yes
if printf '%s\n' "$REP" | grep -qF '#5 ELIGIBLE (no-merge mode' && [ ! -e "$W/p16/merge_called" ]; then ok "LP16 any value other than 0 means no-merge (yes)"
else bad "LP16"; fi

# LP17: a clean clone lets the build start; a builder that is not logged in must be NAMED in the report
setup p17; D17="$W/p17"; rm -rf "$D17/clone"; git clone -q "$D17/origin.git" "$D17/clone" 2>/dev/null
printf '#!/usr/bin/env bash\necho "Not logged in · Please run /login"; exit 1\n' > "$D17/bin/claude-stub"; chmod +x "$D17/bin/claude-stub"
for authed in 0 1; do
  [ "$authed" = 1 ] && printf '#!/usr/bin/env bash\necho "built nothing"; exit 0\n' > "$D17/bin/claude-stub"
  rm -f "$D17/live/tracks/_meta/selfdev/report_$DATE.md"
  rm -rf "$D17/clone"; git clone -q "$D17/origin.git" "$D17/clone" 2>/dev/null   # fresh clone: the fixture has no .gitignore, so the first run's queue copy would leave it dirty
  OUT=$(cd "$D17/live" && env PATH="$D17/bin:$PATH" SELFDEV_DRY_RUN=0 SELFDEV_NO_MERGE=1 FH_SELFDEV_DIR="$D17/clone" FD_CLAUDE_BIN="$D17/bin/claude-stub" \
        bash scripts/selfdev_loop.sh 2>&1); RC=$?
  REP="$(cat "$D17/live/tracks/_meta/selfdev/report_$DATE.md" 2>/dev/null)"
  if [ "$authed" = 0 ]; then
    if printf '%s\n' "$REP" | grep -q 'build finished' && printf '%s\n' "$REP" | grep -q 'builder not logged in'; then a17=1; else a17=0; printf '%s\n' "$REP" "$OUT" | tail -5 | sed 's/^/       /'; fi
  else
    if printf '%s\n' "$REP" | grep -q 'build finished' && ! printf '%s\n' "$REP" | grep -q 'builder not logged in'; then b17=1; else b17=0; fi
  fi
done
rm -f "$D17/live/tracks/_meta/logs/selfdev_loop_$DATE.log"
if [ "${a17:-0}" = 1 ] && [ "${b17:-0}" = 1 ]; then ok "LP17 «Not logged in» builder is named HARNESS-ERROR; a builder that ran is not (control)"
else bad "LP17 (not-logged-in named=${a17:-?} · control clean=${b17:-?})"; fi

# LP18: a build that opens no PR must say WHY in the report (the builder's own words); a build that
# opens one reports its number and no «no PR» block (control). The fake gh lists from a knob file the
# builder stub may rewrite — the before/after listings are what the loop compares.
setup p18; D18="$W/p18"
#   the post-build count asks for number,headRefName,createdAt (all states); the fake answers from a knob
#   the builder stub may rewrite (it ignores -q, so the knob holds the already-filtered numbers)
sed -i.bak 's#"pr list|number,headRefName") echo 5 ;;#"pr list|number,headRefName") echo 5 ;;\
  "pr list|number,headRefName,createdAt") cat "$K/list" 2>/dev/null ;;#' "$D18/bin/gh"
grep -q 'createdAt") cat' "$D18/bin/gh" || { echo "HARNESS-ERROR: LP18 fixture edit did not apply"; exit 2; }
for opens in 0 1; do
  : > "$D18/knobs/list"
  if [ "$opens" = 0 ]; then
    printf '#!/usr/bin/env bash\necho "[02:30:01] timestamped builder line"\necho "No PR this run. AQ-9 is already shipped in #1025."\nexit 0\n' > "$D18/bin/claude-stub"
  else
    printf '#!/usr/bin/env bash\necho 77 > "%s/knobs/list"\necho "opened one"\nexit 0\n' "$D18" > "$D18/bin/claude-stub"
  fi
  chmod +x "$D18/bin/claude-stub"
  rm -f "$D18/live/tracks/_meta/selfdev/report_$DATE.md" "$D18/live/tracks/_meta/logs/selfdev_loop_$DATE.log"
  rm -rf "$D18/clone"; git clone -q "$D18/origin.git" "$D18/clone" 2>/dev/null
  OUT=$(cd "$D18/live" && env PATH="$D18/bin:$PATH" SELFDEV_DRY_RUN=0 SELFDEV_NO_MERGE=1 FH_SELFDEV_DIR="$D18/clone" FD_CLAUDE_BIN="$D18/bin/claude-stub" \
        bash scripts/selfdev_loop.sh 2>&1); RC=$?
  REP="$(cat "$D18/live/tracks/_meta/selfdev/report_$DATE.md" 2>/dev/null)"
  if [ "$opens" = 0 ]; then
    if printf '%s\n' "$REP" | grep -qF -- '- PRs opened this run: 0' && printf '%s\n' "$REP" | grep -qF '  > No PR this run. AQ-9 is already shipped in #1025.' \
       && printf '%s\n' "$REP" | grep -qF '  > [02:30:01] timestamped builder line'; then a18=1
    else a18=0; printf '%s\n' "$REP" "$OUT" | tail -6 | sed 's/^/       /'; fi
  else
    if printf '%s\n' "$REP" | grep -qF -- '- PRs opened this run: 1 (#77 )' && ! printf '%s\n' "$REP" | grep -qF 'no PR —'; then b18=1
    else b18=0; printf '%s\n' "$REP" "$OUT" | tail -6 | sed 's/^/       /'; fi
  fi
done
if [ "${a18:-0}" = 1 ] && [ "${b18:-0}" = 1 ]; then ok "LP18 a quiet build carries the builder's reason into the report; a build that opened #77 is counted, no «no PR» block (control)"
else bad "LP18 (reason carried=${a18:-?} · control=${b18:-?})"; fi

# LP19: subscription only — a key in the caller's env never reaches the builder unless the switch keeps
# it; the report says which happened and never prints the value. Control arms: switch on → the builder
# sees the key and the report says «bills the API»; no key at all → no NOTE line.
setup p19; D19="$W/p19"
sed -i.bak 's#"pr list|number,headRefName") echo 5 ;;#"pr list|number,headRefName") echo 5 ;;\
  "pr list|number,headRefName,createdAt") : ;;#' "$D19/bin/gh"
grep -q 'createdAt") :' "$D19/bin/gh" || { echo "HARNESS-ERROR: LP19 fixture edit did not apply"; exit 2; }
printf '#!/usr/bin/env bash\nif [ -n "${ANTHROPIC_API_KEY:-}" ]; then echo "builder saw key: yes"; else echo "builder saw key: no"; fi\nif [ -n "${ANTHROPIC_AUTH_TOKEN:-}" ]; then echo "builder saw token: yes"; else echo "builder saw token: no"; fi\necho "env dump: ${ANTHROPIC_API_KEY:-} / ${ANTHROPIC_AUTH_TOKEN:-}"\nexit 0\n' > "$D19/bin/claude-stub"; chmod +x "$D19/bin/claude-stub"
FAKE=lane-fake-value-19
for arm in strip keep none token overlap; do
  rm -f "$D19/live/tracks/_meta/selfdev/report_$DATE.md" "$D19/live/tracks/_meta/logs/selfdev_loop_$DATE.log"
  rm -rf "$D19/clone"; git clone -q "$D19/origin.git" "$D19/clone" 2>/dev/null
  case "$arm" in
    strip) KEYENV="ANTHROPIC_API_KEY=$FAKE SELFDEV_ALLOW_API_KEY=" ;;   # codex R1: never inherit the switch from the caller
    token) KEYENV="ANTHROPIC_AUTH_TOKEN=$FAKE SELFDEV_ALLOW_API_KEY=" ;;
    overlap) KEYENV="ANTHROPIC_API_KEY=$FAKE ANTHROPIC_AUTH_TOKEN=$FAKE-tail-secret SELFDEV_ALLOW_API_KEY=1" ;;   # codex R2: longest first
    keep)  KEYENV="ANTHROPIC_API_KEY=$FAKE SELFDEV_ALLOW_API_KEY=1" ;;
    none)  KEYENV="SELFDEV_ALLOW_API_KEY=" ;;
  esac
  OUT=$(cd "$D19/live" && env -u ANTHROPIC_API_KEY -u ANTHROPIC_AUTH_TOKEN PATH="$D19/bin:$PATH" SELFDEV_DRY_RUN=0 SELFDEV_NO_MERGE=1 FH_SELFDEV_DIR="$D19/clone" FD_CLAUDE_BIN="$D19/bin/claude-stub" \
        $KEYENV bash scripts/selfdev_loop.sh 2>&1); RC=$?
  REP="$(cat "$D19/live/tracks/_meta/selfdev/report_$DATE.md" 2>/dev/null)"
  ALL="$(printf '%s\n' "$REP"; cat "$D19/live/tracks/_meta/logs/selfdev_loop_$DATE.log" 2>/dev/null)"
  leak=0; printf '%s\n' "$ALL" "$OUT" | grep -qE "$FAKE|tail-secret" && leak=1
  case "$arm" in
    strip) printf '%s\n' "$ALL" | grep -qF 'builder saw key: no' && printf '%s\n' "$REP" | grep -qF 'unset for the builder (subscription only' && [ "$leak" = 0 ] && s19=1 || { s19=0; printf '%s\n' "$REP" | tail -6 | sed 's/^/       /'; } ;;
    keep)  printf '%s\n' "$ALL" | grep -qF 'builder saw key: yes' && printf '%s\n' "$ALL" | grep -qF 'env dump: *** / ' && printf '%s\n' "$REP" | grep -qF 'this build bills the API' && [ "$leak" = 0 ] && k19=1 || { k19=0; printf '%s\n' "$REP" | tail -6 | sed 's/^/       /'; } ;;
    none)  printf '%s\n' "$ALL" | grep -qF 'builder saw key: no' && ! printf '%s\n' "$REP" | grep -qF 'ANTHROPIC_API_KEY' && n19=1 || { n19=0; printf '%s\n' "$REP" | tail -6 | sed 's/^/       /'; } ;;
    overlap) printf '%s\n' "$ALL" | grep -qF 'env dump: *** / ***' && [ "$leak" = 0 ] && o19=1 || { o19=0; printf '%s\n' "$ALL" | grep 'env dump' | sed 's/^/       /'; } ;;
    token) printf '%s\n' "$ALL" | grep -qF 'builder saw token: no' && printf '%s\n' "$REP" | grep -qF -- '- NOTE: ANTHROPIC_AUTH_TOKEN was set' && [ "$leak" = 0 ] && t19=1 || { t19=0; printf '%s\n' "$REP" | tail -6 | sed 's/^/       /'; } ;;
  esac
done
if [ "${s19:-0}" = 1 ] && [ "${k19:-0}" = 1 ] && [ "${n19:-0}" = 1 ] && [ "${t19:-0}" = 1 ] && [ "${o19:-0}" = 1 ]; then ok "LP19 a caller's ANTHROPIC_API_KEY / ANTHROPIC_AUTH_TOKEN is unset for the builder and named (value never printed); SELFDEV_ALLOW_API_KEY=1 keeps it, says «bills the API» and the builder's own echo of it is redacted (control); no key → no line (control)"
else bad "LP19 (strip=${s19:-?} · keep=${k19:-?} · none=${n19:-?} · token=${t19:-?} · overlap=${o19:-?})"; fi

# LP20: 2026-11-10 — the watchdog killed a build that had committed on auto/selfdev-<date>-1 but not
# pushed; the report said only «0 PRs». A killed build with unpushed commits must name the branch and
# the commit; the control arm pushes the same branch first and must carry no STRANDED line.
setup p20; D20="$W/p20"
sed -i.bak 's#"pr list|number,headRefName") echo 5 ;;#"pr list|number,headRefName") echo 5 ;;\
  "pr list|number,headRefName,createdAt") : ;;#' "$D20/bin/gh"
grep -q 'createdAt") :' "$D20/bin/gh" || { echo "HARNESS-ERROR: LP20 fixture edit did not apply"; exit 2; }
#   arms (codex R1): olddate = a stranded branch from an earlier night is still named (a late commit, or
#   one the operator has not acted on, must not age out) · otherref = the commit is on origin under
#   another branch name → not stranded (count against every origin ref, not one)
for arm in strand pushed olddate otherref; do
  BR="auto/selfdev-$DATE-1"; [ "$arm" = olddate ] && BR="auto/selfdev-2026-01-01-1"
  push=""
  [ "$arm" = pushed ] && push="git push -q origin HEAD 2>/dev/null"
  [ "$arm" = otherref ] && push="git push -q origin HEAD:refs/heads/elsewhere 2>/dev/null"
  cat > "$D20/bin/claude-stub" <<STUB
#!/usr/bin/env bash
git switch -q -c $BR && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m 'docs: lane-20 stranded work'
$push
echo "Waiting for the selfcheck completion notice."
exec sleep 120
STUB
  chmod +x "$D20/bin/claude-stub"
  rm -f "$D20/live/tracks/_meta/selfdev/report_$DATE.md" "$D20/live/tracks/_meta/logs/selfdev_loop_$DATE.log"
  rm -rf "$D20/clone"; git clone -q "$D20/origin.git" "$D20/clone" 2>/dev/null
  for b in $(git -C "$D20/origin.git" for-each-ref --format='%(refname:short)' refs/heads); do [ "$b" = main ] || git -C "$D20/origin.git" branch -q -D "$b"; done
  OUT=$(cd "$D20/live" && env PATH="$D20/bin:$PATH" SELFDEV_DRY_RUN=0 SELFDEV_NO_MERGE=1 SELFDEV_BUILD_TIMEOUT=2 FH_SELFDEV_DIR="$D20/clone" FD_CLAUDE_BIN="$D20/bin/claude-stub" \
        bash scripts/selfdev_loop.sh 2>&1); RC=$?
  REP="$(cat "$D20/live/tracks/_meta/selfdev/report_$DATE.md" 2>/dev/null)"
  case "$arm" in
    strand|olddate)
      if printf '%s\n' "$REP" | grep -qF 'build killed by watchdog (2s)' \
         && printf '%s\n' "$REP" | grep -qF -- "- STRANDED: $BR in $D20/clone has 1 unpushed commit(s)" \
         && printf '%s\n' "$REP" | grep -qF 'docs: lane-20 stranded work'; then r=1
      else r=0; printf '%s\n' "$REP" "$OUT" | tail -8 | sed 's/^/       /'; fi ;;
    *)
      if printf '%s\n' "$REP" | grep -qF 'build killed by watchdog (2s)' && ! printf '%s\n' "$REP" | grep -qF 'STRANDED'; then r=1
      else r=0; printf '%s\n' "$REP" | tail -6 | sed 's/^/       /'; fi ;;
  esac
  eval "r20_$arm=$r"
done
#   arm dirty (codex R2): a dirty clone skips the build — the stranded branch from an earlier night must
#   still be named on that night, not only on nights that build
rm -f "$D20/live/tracks/_meta/selfdev/report_$DATE.md"
rm -rf "$D20/clone"; git clone -q "$D20/origin.git" "$D20/clone" 2>/dev/null
( cd "$D20/clone" && git switch -q -c auto/selfdev-2026-01-02-1 && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m 'docs: lane-20 dirty-night work' && git switch -q main && echo x > untracked.txt )
OUT=$(cd "$D20/live" && env PATH="$D20/bin:$PATH" SELFDEV_DRY_RUN=0 SELFDEV_NO_MERGE=1 FH_SELFDEV_DIR="$D20/clone" FD_CLAUDE_BIN="$D20/bin/claude-stub" \
      bash scripts/selfdev_loop.sh 2>&1); RC=$?
REP="$(cat "$D20/live/tracks/_meta/selfdev/report_$DATE.md" 2>/dev/null)"
if printf '%s\n' "$REP" | grep -qF 'HOLD build: clone dirty' && ! printf '%s\n' "$REP" | grep -qF 'build killed' \
   && printf '%s\n' "$REP" | grep -qF -- "- STRANDED: auto/selfdev-2026-01-02-1 in $D20/clone has 1 unpushed commit(s)"; then r20_dirty=1
else r20_dirty=0; printf '%s\n' "$REP" "$OUT" | tail -8 | sed 's/^/       /'; fi
if [ "${r20_strand:-0}" = 1 ] && [ "${r20_pushed:-0}" = 1 ] && [ "${r20_olddate:-0}" = 1 ] && [ "${r20_otherref:-0}" = 1 ] && [ "${r20_dirty:-0}" = 1 ]; then ok "LP20 a killed build's unpushed commits are named STRANDED with branch and subject, an earlier night's too, also on a night the dirty clone skips the build; the same branch pushed, or the commit pushed under another name → no STRANDED line (controls)"
else bad "LP20 (strand=${r20_strand:-?} · pushed=${r20_pushed:-?} · olddate=${r20_olddate:-?} · otherref=${r20_otherref:-?} · dirty=${r20_dirty:-?})"; fi

# LP21: the time limit the builder is told must BE the watchdog's limit, and the builder is told not to
# run the full suite (11-10: it ran selfcheck.sh, >30 min here, into a 2700s watchdog it never saw).
setup p21; D21="$W/p21"
sed -i.bak 's#"pr list|number,headRefName") echo 5 ;;#"pr list|number,headRefName") echo 5 ;;\
  "pr list|number,headRefName,createdAt") : ;;#' "$D21/bin/gh"
grep -q 'createdAt") :' "$D21/bin/gh" || { echo "HARNESS-ERROR: LP21 fixture edit did not apply"; exit 2; }
printf '#!/usr/bin/env bash\nprintf "%%s" "$2" > "%s/prompt"\nexit 0\n' "$D21" > "$D21/bin/claude-stub"; chmod +x "$D21/bin/claude-stub"
for t in 1234 777; do
  rm -f "$D21/prompt" "$D21/live/tracks/_meta/selfdev/report_$DATE.md"
  rm -rf "$D21/clone"; git clone -q "$D21/origin.git" "$D21/clone" 2>/dev/null
  OUT=$(cd "$D21/live" && env PATH="$D21/bin:$PATH" SELFDEV_DRY_RUN=0 SELFDEV_NO_MERGE=1 SELFDEV_BUILD_TIMEOUT=$t FH_SELFDEV_DIR="$D21/clone" FD_CLAUDE_BIN="$D21/bin/claude-stub" \
        bash scripts/selfdev_loop.sh 2>&1); RC=$?
  P="$(cat "$D21/prompt" 2>/dev/null)"
  if [ -n "$P" ] && printf '%s' "$P" | grep -qF "killed at $t seconds" && printf '%s' "$P" | grep -qF 'Do not run the full scripts/selfcheck.sh'; then eval "ok21_$t=1"
  else eval "ok21_$t=0"; printf '%s\n' "${P:-<no prompt captured>}" | head -3 | sed 's/^/       /'; fi
done
if [ "${ok21_1234:-0}" = 1 ] && [ "${ok21_777:-0}" = 1 ]; then ok "LP21 the builder prompt names the watchdog's own limit (1234 and 777 both follow SELFDEV_BUILD_TIMEOUT) and forbids the full selfcheck"
else bad "LP21 (1234=${ok21_1234:-?} · 777=${ok21_777:-?})"; fi

[ $((pass+fail)) -eq 21 ] || { echo "HARNESS-ERROR: counted $((pass+fail)) lanes, expected 21"; exit 2; }
echo "selfdev_loop lanes: $pass passed · $fail failed"
[ "$fail" -eq 0 ]
