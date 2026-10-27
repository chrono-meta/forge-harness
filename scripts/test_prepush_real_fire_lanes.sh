#!/usr/bin/env bash
# test_prepush_real_fire_lanes.sh — does git ACTUALLY run the pre-push hook, with the ref lines its header claims,
# for every destructive push the header says it covers? And does the remote stay untouched when it blocks?
#
# ── WHY THIS FILE EXISTS ─────────────────────────────────────────────────────────────────────────
# templates/.git-hooks/pre-push claims (header, «honest scope») to cover: remote branch deletion · tag / notes ref
# deletion · force / non-fast-forward push · implicit deletes from `git push --mirror` / `--prune`.
# scripts/test_prepush_destructive_lanes.sh anchors the hook's VERDICT by printing synthetic ref lines into its stdin.
# Nothing measured the other half: that git invokes the hook for each of those operations and hands it those lines.
# A sibling harness lost 366 protected files to exactly that gap (2026-10-23, reported back to this hub): a guard's header said
# «only this hook sees fast-forward merges», and a scratch-repo count showed the hook fired 0 times on
# `git merge --ff-only`. A claim about WHEN a hook fires is a claim about git, and only running git measures it.
#
# Each lane runs a real `git push` from a clone (core.hooksPath → a wrapper that counts calls and records stdin, then
# execs the real hook) to a real bare remote, and asserts three things: the hook fired, its stdin carried the ref line
# the claim depends on, and the remote ref is unchanged after the block. L0 is the control: with no hook wired, the
# same delete succeeds — so «remote unchanged» is something these lanes can see fail.
#
# Usage: bash scripts/test_prepush_real_fire_lanes.sh   → exit 0 all lanes hold · 1 a lane failed · 2 setup failed
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/fixture_guard_lib.sh"   # 픽스처는 실레포에 쓰지 않는다

REPO_ROOT="${FH_TEST_SUBJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
HOOK_SRC="$REPO_ROOT/templates/.git-hooks/pre-push"
DEF_SRC="$REPO_ROOT/.claude/rules/.public-surface-patterns.defaults"
[ -f "$HOOK_SRC" ] || { echo "HARNESS_ERROR — pre-push hook not found at $HOOK_SRC (subject absent; NOT a pass)"; exit 2; }

WORK="$(fh_fixture_root "$(mktemp -d)")" || exit 2
: "${WORK:?fixture root unset — refusing to run git in cwd}"
trap 'rm -rf "$WORK"' EXIT
PASSED=0; FAILED=0
ok()  { PASSED=$((PASSED + 1)); echo "  ✅ $1"; }
bad() { FAILED=$((FAILED + 1)); echo "  ❌ $1"; }

# ── fixture: bare remote with main · feat · old (merged into main) · uniq (one commit off main) · tag v1 · notes ─────
# The hook allows deleting a fully merged branch by design (pre-push «SAFE: fully merged … allowed») and holds one
# with unique work — so the delete lanes target `uniq`, and deleting `old` is a known-negative (fires, passes).
setup() {   # $1 = name; wires the hook unless $2 = nohook
  local d="$WORK/$1"
  mkdir -p "$d" || return 1
  git init -q --bare "$d/remote.git" || return 1
  git -C "$d/remote.git" symbolic-ref HEAD refs/heads/main || return 1
  mkdir -p "$d/seed" && (
    cd "$d/seed" || exit 1
    git init -q && git symbolic-ref HEAD refs/heads/main && git config user.email t@example.com && git config user.name t || exit 1
    printf 'base\n' > a.txt && git add a.txt && git commit -qm base || exit 1
    git branch old && git branch feat && git tag v1 || exit 1
    git notes add -m n HEAD || exit 1
    git switch -q -c uniq && printf 'u\n' > u.txt && git add u.txt && git commit -qm uniq && git switch -q main || exit 1
    git switch -q feat && printf 'f1\n' > f.txt && git add f.txt && git commit -qm f1 || exit 1
    git push -q "$d/remote.git" main old feat uniq v1 refs/notes/commits 2>/dev/null || exit 1
  ) || return 1
  git clone -q "$d/remote.git" "$d/clone" 2>/dev/null || return 1
  (
    cd "$d/clone" || exit 1
    git config user.email t@example.com && git config user.name t || exit 1
    git fetch -q origin 'refs/notes/*:refs/notes/*' 'refs/tags/*:refs/tags/*' || exit 1
    git branch -q --track feat origin/feat 2>/dev/null; git branch -q --track old origin/old 2>/dev/null; git branch -q --track uniq origin/uniq 2>/dev/null; true
  ) || return 1
  if [ "${2:-}" != nohook ]; then
    mkdir -p "$d/clone/.claude/rules" "$d/clone/scripts" "$d/hooks" || return 1
    [ -f "$DEF_SRC" ] && cp "$DEF_SRC" "$d/clone/.claude/rules/.public-surface-patterns.defaults"
    [ -f "$REPO_ROOT/scripts/psa_scan_lib.sh" ] && cp "$REPO_ROOT/scripts/psa_scan_lib.sh" "$d/clone/scripts/psa_scan_lib.sh"
    cp "$HOOK_SRC" "$d/hooks/pre-push.real" || return 1
    # wrapper: count the call, keep a copy of stdin, then hand the same bytes to the real hook
    cat > "$d/hooks/pre-push" <<EOF
#!/usr/bin/env bash
echo x >> "$d/fired"
tee "$d/stdin.\$(wc -l < "$d/fired" | tr -d ' ')" | bash "$d/hooks/pre-push.real" "\$@"
exit \${PIPESTATUS[1]}
EOF
    chmod +x "$d/hooks/pre-push" || return 1
    git -C "$d/clone" config core.hooksPath "$d/hooks" || return 1
  fi
  : > "$d/fired"
  printf '%s' "$d"
}
remote_ref() { git -C "$1/remote.git" rev-parse -q --verify "$2" 2>/dev/null || echo ABSENT; }
fired()      { wc -l < "$1/fired" | tr -d ' '; }
stdin_has()  { grep -qE "$2" "$1"/stdin.* 2>/dev/null; }   # no pipe: grep -q exiting early cannot SIGPIPE a producer (downstream report 2026-10-27)

# run_lane <name> <ref-to-watch> <stdin-regex> <push args...>
run_lane() {
  local name="$1" ref="$2" rx="$3"; shift 3
  local d; d=$(setup "$name") || { echo "  ⛔ SETUP FAILED ($name) — HARNESS_ERROR, not a pass"; exit 2; }
  local before; before=$(remote_ref "$d" "$ref")
  [ "$before" = ABSENT ] && { echo "  ⛔ SETUP: $ref missing on the remote before the lane ($name)"; exit 2; }
  ( cd "$d/clone" && env -u DESTRUCTIVE_OP_OK -u MAIN_PUSH_OK git push "$@" >/dev/null 2>&1 ); local rc=$?
  local after; after=$(remote_ref "$d" "$ref")
  local f; f=$(fired "$d")
  if [ "$f" -ge 1 ] && stdin_has "$d" "$rx" && [ "$rc" -ne 0 ] && [ "$after" = "$before" ]; then
    ok "$name — hook fired ${f}× · stdin carried the claimed ref line · push refused · $ref unchanged"
  else
    bad "$name — fired=$f stdin_match=$(stdin_has "$d" "$rx" && echo yes || echo no) push_rc=$rc $ref: $before → $after"
  fi
}

ZERO40='0{40}'
echo "pre-push real-fire lanes (subject: $HOOK_SRC)"

# L0 control — no hook wired: the same remote delete goes through. Without this, «remote unchanged» could be a property
# of the fixture (e.g. a push that never reached the remote) rather than of the hook.
d0=$(setup L0 nohook) || { echo "  ⛔ SETUP FAILED (L0)"; exit 2; }
( cd "$d0/clone" && git push origin --delete old >/dev/null 2>&1 )
[ "$(remote_ref "$d0" refs/heads/old)" = ABSENT ] && ok "L0 control — no hook: the delete reaches the remote (the lanes can see a real change)" \
  || bad "L0 control — without a hook the delete did NOT land: the fixture cannot show a hook's effect"

# L1 known-negative — an ordinary fast-forward push of a feature branch fires the hook and is NOT refused
d1=$(setup L1) || { echo "  ⛔ SETUP FAILED (L1)"; exit 2; }
before1=$(remote_ref "$d1" refs/heads/feat)
( cd "$d1/clone" && git switch -q feat && printf 'f2\n' >> f.txt && git commit -qam f2 && env -u DESTRUCTIVE_OP_OK git push -q origin feat >/dev/null 2>&1 ); rc1=$?
if [ "$(fired "$d1")" -ge 1 ] && [ "$rc1" -eq 0 ] && [ "$(remote_ref "$d1" refs/heads/feat)" != "$before1" ]; then
  ok "L1 known-negative — fast-forward feature push: hook fired, push accepted, remote advanced"
else
  bad "L1 known-negative — fired=$(fired "$d1") rc=$rc1 (a plain ff push must pass; otherwise every block below is uninformative)"
fi

# L2b known-negative — deleting a FULLY MERGED branch fires the hook and is allowed (by design: nothing unique is lost)
d2b=$(setup L2b) || { echo "  ⛔ SETUP FAILED (L2b)"; exit 2; }
( cd "$d2b/clone" && env -u DESTRUCTIVE_OP_OK git push origin --delete old >/dev/null 2>&1 ); rc2b=$?
if [ "$(fired "$d2b")" -ge 1 ] && stdin_has "$d2b" "^\(delete\) ${ZERO40} refs/heads/old " && [ "$rc2b" -eq 0 ] && [ "$(remote_ref "$d2b" refs/heads/old)" = ABSENT ]; then
  ok "L2b known-negative — merged branch delete: hook fired with the (delete) line and allowed it (SAFE)"
else
  bad "L2b known-negative — fired=$(fired "$d2b") rc=$rc2b (a fully merged delete is allowed by design)"
fi
run_lane "L2 unmerged branch delete (--delete)" refs/heads/uniq  "^\(delete\) ${ZERO40} refs/heads/uniq "     origin --delete uniq
run_lane "L3 unmerged branch delete (:ref)"     refs/heads/uniq  "^\(delete\) ${ZERO40} refs/heads/uniq "     origin :uniq
run_lane "L4 tag delete"                        refs/tags/v1     "^\(delete\) ${ZERO40} refs/tags/v1 "        origin :refs/tags/v1
run_lane "L5 notes ref delete"                  refs/notes/commits "^\(delete\) ${ZERO40} refs/notes/commits " origin :refs/notes/commits

# L6 force / non-fast-forward: rewrite feat locally, then force-push
d6=$(setup L6) || { echo "  ⛔ SETUP FAILED (L6)"; exit 2; }
before6=$(remote_ref "$d6" refs/heads/feat)
( cd "$d6/clone" && git switch -q feat && git reset -q --hard HEAD~1 && printf 'rewritten\n' > r.txt && git add r.txt && git commit -qm rewrite \
  && env -u DESTRUCTIVE_OP_OK git push -f origin feat >/dev/null 2>&1 ); rc6=$?
if [ "$(fired "$d6")" -ge 1 ] && stdin_has "$d6" "^refs/heads/feat [0-9a-f]{40} refs/heads/feat ${before6}" && [ "$rc6" -ne 0 ] && [ "$(remote_ref "$d6" refs/heads/feat)" = "$before6" ]; then
  ok "L6 force push — hook fired · stdin carried the old remote tip · refused · feat unchanged"
else
  bad "L6 force push — fired=$(fired "$d6") rc=$rc6 feat: $before6 → $(remote_ref "$d6" refs/heads/feat)"
fi

# L7 --prune: a branch deleted locally disappears on the remote through a refspec push with --prune
d7=$(setup L7) || { echo "  ⛔ SETUP FAILED (L7)"; exit 2; }
before7=$(remote_ref "$d7" refs/heads/uniq)
( cd "$d7/clone" && git branch -q -D uniq && env -u DESTRUCTIVE_OP_OK git push --prune origin 'refs/heads/*:refs/heads/*' >/dev/null 2>&1 ); rc7=$?
if [ "$(fired "$d7")" -ge 1 ] && stdin_has "$d7" "^\(delete\) ${ZERO40} refs/heads/uniq " && [ "$rc7" -ne 0 ] && [ "$(remote_ref "$d7" refs/heads/uniq)" = "$before7" ]; then
  ok "L7 --prune — the implicit delete reached the hook as a (delete) line · refused · uniq unchanged"
else
  bad "L7 --prune — fired=$(fired "$d7") rc=$rc7 uniq: $before7 → $(remote_ref "$d7" refs/heads/uniq)"
fi

# L8 --mirror: a mirror push from a clone missing `uniq` locally would delete it on the remote
d8=$(setup L8) || { echo "  ⛔ SETUP FAILED (L8)"; exit 2; }
before8=$(remote_ref "$d8" refs/heads/uniq)
( cd "$d8/clone" && git branch -q -D uniq && git update-ref -d refs/remotes/origin/uniq && env -u DESTRUCTIVE_OP_OK git push --mirror origin >"$d8/push.out" 2>&1 ); rc8=$?
if [ "$(fired "$d8")" -ge 1 ] && [ "$rc8" -ne 0 ] && [ "$(remote_ref "$d8" refs/heads/uniq)" = "$before8" ] \
   && grep -q "refs/heads/uniq — REVIEW" "$d8/push.out"; then   # the refusal must be the uniq verdict, not any refusal (cross-family R1)
  ok "L8 --mirror — hook fired · refused · uniq unchanged (stdin carried: $(cat "$d8"/stdin.* 2>/dev/null | awk '{print $1" "$3}' | paste -sd',' - | cut -c1-120))"
else
  bad "L8 --mirror — fired=$(fired "$d8") rc=$rc8 uniq: $before8 → $(remote_ref "$d8" refs/heads/uniq)" ; echo "     stdin the hook got:"; sed "s/^/       /" "$d8"/stdin.* 2>/dev/null; echo "     push output (tail):"; tail -12 "$d8/push.out" | sed "s/^/       /"
fi

# L8-ctl — no hook: the same mirror push really deletes `uniq` (so L8's «unchanged» is the hook's doing)
d8x=$(setup L8x nohook) || { echo "  ⛔ SETUP FAILED (L8x)"; exit 2; }
( cd "$d8x/clone" && git branch -q -D uniq && git update-ref -d refs/remotes/origin/uniq && git push --mirror origin >/dev/null 2>&1 )
[ "$(remote_ref "$d8x" refs/heads/uniq)" = ABSENT ] && ok "L8-ctl — no hook: the mirror push deletes uniq on the remote" \
  || bad "L8-ctl — without a hook the mirror push did NOT delete uniq: L8 cannot show the hook's effect"

# L8d — abbreviated option: git accepts `--mir` for --mirror
d8d=$(setup L8d) || { echo "  ⛔ SETUP FAILED (L8d)"; exit 2; }
before8d=$(remote_ref "$d8d" refs/heads/uniq)
( cd "$d8d/clone" && git branch -q -D uniq && git update-ref -d refs/remotes/origin/uniq && env -u DESTRUCTIVE_OP_OK git push --mir origin >"$d8d/push.out" 2>&1 ); rc8d=$?
if [ "$rc8d" -ne 0 ] && [ "$(remote_ref "$d8d" refs/heads/uniq)" = "$before8d" ] && grep -q "refs/heads/uniq — REVIEW" "$d8d/push.out"; then
  ok "L8d --mir (abbreviation) — detected as a mirror push · uniq held"
else
  bad "L8d --mir — rc=$rc8d uniq: $before8d → $(remote_ref "$d8d" refs/heads/uniq)"; tail -6 "$d8d/push.out" | sed 's/^/       /'
fi

# L8e — git itself refuses `--no-mirror <refspec>` when remote.<name>.mirror is set (measured: «--mirror can't be combined
# with refspecs»), so the hook does not treat --no-mirror as overriding the config. This lane pins git's refusal: if a
# future git accepts it, the hook's «config ⇒ mirror» rule needs revisiting and this lane goes red to say so.
d8e=$(setup L8e) || { echo "  ⛔ SETUP FAILED (L8e)"; exit 2; }
( cd "$d8e/clone" && { git config remote.origin.mirror true && git switch -q feat && printf 'f3\n' >> f.txt && git commit -qam f3 \
  && env -u DESTRUCTIVE_OP_OK git push --no-mirror origin feat; } >"$d8e/push.out" 2>&1 ); rc8e=$?
if [ "$rc8e" -ne 0 ] && grep -q "can't be combined with refspecs" "$d8e/push.out" && [ "$(fired "$d8e")" -eq 0 ]; then
  ok "L8e git refuses --no-mirror <refspec> under a mirror config (before any hook runs) — config ⇒ mirror stays safe"
else
  bad "L8e git's behaviour changed — rc=$rc8e fired=$(fired "$d8e"): revisit the hook's config ⇒ mirror rule"; tail -4 "$d8e/push.out" | sed 's/^/       /'
fi

# L8b known-negative — a mirror push that deletes nothing (every remote branch/tag/note exists locally) is not refused
d8b=$(setup L8b) || { echo "  ⛔ SETUP FAILED (L8b)"; exit 2; }
( cd "$d8b/clone" && env -u DESTRUCTIVE_OP_OK git push --mirror origin >"$d8b/push.out" 2>&1 ); rc8b=$?
if [ "$(fired "$d8b")" -ge 1 ] && [ "$rc8b" -eq 0 ] && [ "$(remote_ref "$d8b" refs/heads/uniq)" != ABSENT ]; then
  ok "L8b known-negative — mirror push with nothing to delete: hook fired, push accepted"
else
  bad "L8b known-negative — fired=$(fired "$d8b") rc=$rc8b (a mirror push that deletes nothing must pass)"; tail -8 "$d8b/push.out" | sed 's/^/       /'
fi

# L8c — mirror by CONFIG (remote.origin.mirror=true, plain `git push`): no --mirror on any command line
d8c=$(setup L8c) || { echo "  ⛔ SETUP FAILED (L8c)"; exit 2; }
before8c=$(remote_ref "$d8c" refs/heads/uniq)
( cd "$d8c/clone" && git config remote.origin.mirror true && git branch -q -D uniq && git update-ref -d refs/remotes/origin/uniq \
  && env -u DESTRUCTIVE_OP_OK git push origin >"$d8c/push.out" 2>&1 ); rc8c=$?
if [ "$(fired "$d8c")" -ge 1 ] && [ "$rc8c" -ne 0 ] && [ "$(remote_ref "$d8c" refs/heads/uniq)" = "$before8c" ] \
   && grep -q "refs/heads/uniq — REVIEW" "$d8c/push.out"; then
  ok "L8c mirror by config — hook fired · refused · uniq unchanged"
else
  bad "L8c mirror by config — fired=$(fired "$d8c") rc=$rc8c uniq: $before8c → $(remote_ref "$d8c" refs/heads/uniq)"; tail -8 "$d8c/push.out" | sed 's/^/       /'
fi
# Not measured here (named): a mirror push whose `git ls-remote` fails while the push itself would work — the hook
# blocks it (MIRROR_UNREADABLE), but no fixture makes ls-remote fail without also failing the push.

echo "── pre-push real-fire: $PASSED passed, $FAILED failed ──"
[ "$FAILED" -eq 0 ]
