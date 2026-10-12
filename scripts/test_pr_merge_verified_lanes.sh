#!/usr/bin/env bash
# test_pr_merge_verified_lanes.sh — anchor for scripts/pr_merge_verified.sh (the merge-path wiring of
# post_squash_verify.sh). Hermetic: a local bare "origin" and a fake `gh` on PATH; no network.
#
# The load-bearing lanes are the REFUSALS: a refusal must happen BEFORE the merge, so each refusal
# lane also asserts the fake gh never received `pr merge` (a merge log that stays empty).
set -uo pipefail
cd "$(dirname "$0")/.."
SC="$PWD/scripts/pr_merge_verified.sh"
[ -f "$SC" ] || { echo "🟥 HARNESS-ERROR: target missing ($SC)" >&2; exit 9; }

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ✅ %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  ❌ %s\n' "$1"; }
T=$(mktemp -d "${TMPDIR:-/tmp}/pmv-lane-XXXXXX"); trap 'rm -rf "$T"' EXIT INT TERM
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

# setup <name> : bare origin with main(a,b) + feat(a2,b2); a clone at $T/<name>/work
setup() {
  local d="$T/$1"; mkdir -p "$d"
  git init -q --bare -b main "$d/origin.git"
  git clone -q "$d/origin.git" "$d/seed" 2>/dev/null
  printf 'a1\n' > "$d/seed/a"; printf 'b1\n' > "$d/seed/b"
  git -C "$d/seed" add -A; git -C "$d/seed" commit -qm init --no-verify; git -C "$d/seed" push -q origin HEAD:main
  git -C "$d/seed" switch -qc feat; printf 'a2\n' > "$d/seed/a"; printf 'b2\n' > "$d/seed/b"
  git -C "$d/seed" commit -qam feat --no-verify; git -C "$d/seed" push -q origin feat
  git clone -q "$d/origin.git" "$d/work" 2>/dev/null; git -C "$d/work" fetch -q origin feat
  printf '%s' "$(git -C "$d/seed" rev-parse feat)" > "$d/head.oid"
}
# fake gh. Behaviour knobs via files in $D: view_fail · merge_fail · drop_b
mkgh() {
  local D="$1"; mkdir -p "$D/bin"
  cat > "$D/bin/gh" <<EOF
#!/bin/sh
D="$D"
case "\$1 \$2" in
  "pr view")
    [ -f "\$D/view_fail" ] && exit 1
    [ -f "\$D/view_fail_after_merge" ] && [ -s "\$D/merge.log" ] && exit 1
    case "\$*" in
      *state,headRefOid*)
        if [ -f "\$D/merge.oid" ] && [ ! -f "\$D/queued" ]; then
          if [ -f "\$D/stuck" ]; then echo "OPEN \$(cat "\$D/head.oid")"
          elif [ -f "\$D/lag" ] && [ "\$(wc -l < "\$D/lag")" -lt 2 ]; then echo x >> "\$D/lag"; echo "OPEN \$(cat "\$D/head.oid")"
          elif [ -f "\$D/other_head" ]; then echo "MERGED 0000000000000000000000000000000000000000"
          else echo "MERGED \$(cat "\$D/head.oid")"; fi
        elif [ -f "\$D/closed" ]; then echo "CLOSED \$(cat "\$D/head.oid")"
        else echo "OPEN \$(cat "\$D/head.oid")"; fi ;;
      *headRefOid*) cat "\$D/head.oid"; echo ;;
      *state*) if [ -f "\$D/merge.oid" ] && [ ! -f "\$D/queued" ]; then echo MERGED; else echo OPEN; fi ;;
      *mergeCommit*) if [ -f "\$D/queued" ]; then echo null; else cat "\$D/merge.oid" 2>/dev/null; echo; fi ;; esac ;;
  "pr merge")
    echo "\$*" >> "\$D/merge.log"
    [ -f "\$D/merge_fail" ] && exit 1
    case "\$*" in *--match-head-commit*) mh=\$(echo "\$*" | sed 's/.*--match-head-commit \([0-9a-f]*\).*/\1/')
      [ -f "\$D/moved" ] && { echo "Head branch was modified" >&2; exit 1; }
      [ "\$mh" = "\$(cat "\$D/head.oid")" ] || exit 1 ;; esac
    [ -f "\$D/queued" ] && { git -C "\$D/seed" rev-parse HEAD > "\$D/merge.oid"; exit 0; }
    git -C "\$D/seed" switch -q main && git -C "\$D/seed" merge --squash -q feat >/dev/null 2>&1
    [ -f "\$D/drop_b" ] && git -C "\$D/seed" checkout -q HEAD -- b
    git -C "\$D/seed" commit -qm squash --no-verify && git -C "\$D/seed" push -q origin main
    git -C "\$D/seed" rev-parse HEAD > "\$D/merge.oid"
    [ -f "\$D/local_fail" ] && { echo "fatal: 'main' is already used by worktree" >&2; exit 1; }
    exit 0 ;;
  *) exit 2 ;;
esac
EOF
  chmod +x "$D/bin/gh"
}
run() { local D="$1"; shift; OUT=$(cd "$D/work" && PATH="$D/bin:$PATH" PMV_RETRY_SLEEP=0 bash "$SC" "$@" 2>&1); RC=$?; }
merged() { [ -s "$1/merge.log" ]; }
GOOD='grep -q a2 a && grep -q b2 b && echo instrument-ok'

printf '── pr_merge_verified ──\n'

setup ok; mkgh "$T/ok"; run "$T/ok" 7 --rerun "$GOOD"
{ [ "$RC" -eq 0 ] && printf '%s' "$OUT" | grep -q 'merged and verified'; } \
  && ok "L1 merge + verify → rc=0" || { bad "L1 happy path rc=$RC"; printf '%s\n' "$OUT" | tail -6; }

setup nore; mkgh "$T/nore"; run "$T/nore" 7
{ [ "$RC" -eq 2 ] && ! merged "$T/nore"; } && ok "L2 no --rerun → rc=2 and merge NEVER called" \
  || bad "L2 no --rerun rc=$RC merged=$(merged "$T/nore" && echo yes || echo no)"

setup mf; mkgh "$T/mf"; : > "$T/mf/merge_fail"; run "$T/mf" 7 --rerun "$GOOD"
[ "$RC" -eq 5 ] && ok "L3 merge fails → rc=5" || bad "L3 merge failure rc=$RC"

setup drop; mkgh "$T/drop"; : > "$T/drop/drop_b"; run "$T/drop" 7 --rerun 'grep -q a2 a && echo a-ok'
{ [ "$RC" -eq 1 ] && printf '%s' "$OUT" | grep -q 'IS MERGED but verification FAILED'; } \
  && ok "L4 squash dropped a file → rc=1 · says the merge stands" || { bad "L4 dropped file rc=$RC"; printf '%s\n' "$OUT" | tail -5; }

setup bad; mkgh "$T/bad"; run "$T/bad" 7x --rerun "$GOOD"
{ [ "$RC" -eq 2 ] && ! merged "$T/bad"; } && ok "L5 non-numeric PR → rc=2, no merge" || bad "L5 non-numeric PR rc=$RC"

setup vf; mkgh "$T/vf"; : > "$T/vf/view_fail"; run "$T/vf" 7 --rerun "$GOOD"
{ [ "$RC" -eq 4 ] && ! merged "$T/vf"; } && ok "L6 PR head unreadable → rc=4 BEFORE merge" \
  || bad "L6 head unreadable rc=$RC merged=$(merged "$T/vf" && echo yes || echo no)"

setup triv; mkgh "$T/triv"; run "$T/triv" 7 --rerun 'true'
# 🟥 the refusal must come BEFORE the merge — first draft refused it only after merging (rc=4 post-merge)
{ [ "$RC" -eq 3 ] && ! merged "$T/triv"; } \
  && ok "L7 trivial --rerun → rc=3 BEFORE merge (merge never called)" \
  || bad "L7 trivial rerun rc=$RC merged=$(merged "$T/triv" && echo yes || echo no)"

# ── cross-family W1 (codex/gpt-5.5) ──
# L8 the merge is pinned to the RECORDED head: gh gets --match-head-commit <oid>; a moved head → no merge (rc=5)
grep -q -- "--match-head-commit $(cat "$T/ok/head.oid")" "$T/ok/merge.log" \
  && ok "L8a merge call carries --match-head-commit <recorded head>" || bad "L8a merge not pinned to the recorded head: $(cat "$T/ok/merge.log")"
setup mv; mkgh "$T/mv"; : > "$T/mv/moved"; run "$T/mv" 7 --rerun "$GOOD"
[ "$RC" -eq 5 ] && ok "L8b head moved after recording → GitHub refuses, rc=5 (nothing merged)" || bad "L8b moved head rc=$RC"
# L9 merge accepted but not completed (queue / API lag: mergeCommit null) → rc=6, never «merged and verified», never «the merge stands»
setup q; mkgh "$T/q"; : > "$T/q/queued"; run "$T/q" 7 --rerun "$GOOD"
{ [ "$RC" -eq 6 ] && ! printf '%s' "$OUT" | grep -q 'merged and verified\|IS MERGED'; } \
  && ok "L9 merge queued / not completed → rc=6, reported as NOT verified" || { bad "L9 queued merge rc=$RC"; printf '%s\n' "$OUT" | tail -3; }

# ── 2026-10-12 misreport: gh exits non-zero AFTER the server merged (local branch cleanup failed) ──
# L10 GitHub says MERGED → never «nothing merged»; verification still runs to rc=0
setup lf; mkgh "$T/lf"; : > "$T/lf/local_fail"; run "$T/lf" 7 --rerun "$GOOD"
{ [ "$RC" -eq 0 ] && printf '%s' "$OUT" | grep -q 'merged and verified' && ! printf '%s' "$OUT" | grep -q 'nothing merged'; } \
  && ok "L10 gh non-zero after server merge → re-queried MERGED, verified rc=0" || { bad "L10 local-cleanup failure rc=$RC"; printf '%s\n' "$OUT" | tail -4; }
# L11 gh non-zero AND state unreadable → rc=4 «outcome UNKNOWN», never «nothing merged» — both with and
#     without a real server merge behind the failure
setup lu; mkgh "$T/lu"; : > "$T/lu/merge_fail"; : > "$T/lu/view_fail_after_merge"; run "$T/lu" 7 --rerun "$GOOD"
{ [ "$RC" -eq 4 ] && printf '%s' "$OUT" | grep -q 'UNKNOWN' && ! printf '%s' "$OUT" | grep -q 'nothing merged'; } \
  && ok "L11a gh fails (no merge) + state unreadable → rc=4 UNKNOWN" || { bad "L11a rc=$RC"; printf '%s\n' "$OUT" | tail -3; }
setup lu2; mkgh "$T/lu2"; : > "$T/lu2/local_fail"; : > "$T/lu2/view_fail_after_merge"; run "$T/lu2" 7 --rerun "$GOOD"
{ [ "$RC" -eq 4 ] && printf '%s' "$OUT" | grep -q 'UNKNOWN' && ! printf '%s' "$OUT" | grep -q 'nothing merged'; } \
  && ok "L11b server merged, gh fails, state unreadable → rc=4 UNKNOWN" || { bad "L11b rc=$RC"; printf '%s\n' "$OUT" | tail -3; }
# L12 verification still bites on the recovered path: local_fail + a squash that dropped b → rc=1
setup lfd; mkgh "$T/lfd"; : > "$T/lfd/local_fail"; : > "$T/lfd/drop_b"; run "$T/lfd" 7 --rerun 'grep -q a2 a && echo a-ok'
{ [ "$RC" -eq 1 ] && printf '%s' "$OUT" | grep -q 'IS MERGED but verification FAILED'; } \
  && ok "L12 recovered path still verifies: dropped file → rc=1" || { bad "L12 rc=$RC"; printf '%s\n' "$OUT" | tail -3; }
# L13 state lags (OPEN, OPEN, then MERGED) → re-reads, verified rc=0
setup lag; mkgh "$T/lag"; : > "$T/lag/local_fail"; : > "$T/lag/lag"; run "$T/lag" 7 --rerun "$GOOD"
{ [ "$RC" -eq 0 ] && printf '%s' "$OUT" | grep -q 'merged and verified'; } \
  && ok "L13 OPEN→MERGED lag after gh failure → bounded re-read, rc=0" || { bad "L13 rc=$RC"; printf '%s\n' "$OUT" | tail -3; }
# L14 MERGED from a head other than the recorded one → rc=4, NOT verified
setup oh; mkgh "$T/oh"; : > "$T/oh/local_fail"; : > "$T/oh/other_head"; run "$T/oh" 7 --rerun "$GOOD"
{ [ "$RC" -eq 4 ] && printf '%s' "$OUT" | grep -q 'not the recorded' && ! printf '%s' "$OUT" | grep -q 'merged and verified'; } \
  && ok "L14 MERGED from a different head → rc=4 NOT verified" || { bad "L14 rc=$RC"; printf '%s\n' "$OUT" | tail -3; }
# L15 CLOSED (unmerged) after gh failure → rc=5
setup cl; mkgh "$T/cl"; : > "$T/cl/merge_fail"; : > "$T/cl/closed"; run "$T/cl" 7 --rerun "$GOOD"
{ [ "$RC" -eq 5 ] && printf '%s' "$OUT" | grep -q 'reports CLOSED (read 1 time' && ! printf '%s' "$OUT" | grep -q 'nothing merged'; } \
  && ok "L15 gh fails, PR CLOSED → rc=5 · actual read count" || { bad "L15 rc=$RC"; printf '%s\n' "$OUT" | tail -2; }
# L16 residual made visible: server merged but state stays OPEN through every re-read → rc=5 reported as
#     «NOT observed» with a re-check hint — never as «nothing merged»
setup st; mkgh "$T/st"; : > "$T/st/local_fail"; : > "$T/st/stuck"; run "$T/st" 7 --rerun "$GOOD"
{ [ "$RC" -eq 5 ] && printf '%s' "$OUT" | grep -q 'NOT observed' && printf '%s' "$OUT" | grep -q 'read 3 time' && ! printf '%s' "$OUT" | grep -q 'nothing merged'; } \
  && ok "L16 stale OPEN through all re-reads → rc=5 «NOT observed», no false «nothing merged»" || { bad "L16 rc=$RC"; printf '%s\n' "$OUT" | tail -2; }

printf 'PASS %d · FAIL %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
