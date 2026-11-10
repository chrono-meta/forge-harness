#!/usr/bin/env bash
# selfdev_loop.sh — the unattended FH self-dev loop, run in its OWN clone, never the shared checkout.
#
# WHY (operator, 2026-11-04 — CLAUDE.local.md §FH 자체개발 자율화, lease → 2027-02-04):
# «운영자는 일반 사용자처럼 FH 를 쓰고 … FH 를 사용하는 시간과 자체개발하는 시간을 분리». The
# predecessor (frontier_digest_autopilot.sh Stage 2) ran inside the shared checkout and therefore had
# to skip whenever that checkout was dirty — measured: the last 25 of its 32 daily logs (2026-10-11 →
# 2026-11-04) say «Stage 2 SKIPPED: working tree is dirty». A loop that is built but never runs is the
# built-but-not-wired failure. A dedicated clone removes the reason to skip: nobody else works there.
#
# ONE RUN =
#   ① ensure the clone ($FH_SELFDEV_DIR, default ~/projects/fh-selfdev) exists, is clean, is on main
#      at origin/main; hooks wired (core.hooksPath templates/.git-hooks). Dirty clone → no build this
#      run (a previous run left work; never discard it), merge pass still runs.
#   ② queue: scripts/selfdev_queue.py reads the LIVE checkout's records (checklist open rows ·
#      absorption queue · card [planned] · digest candidates · correction moments) → queue_<date>.md
#   ③ build: one headless `claude -p` in the clone picks ≤ $SELFDEV_MAX_ITEMS items, one PR each,
#      through the normal 4-axis gate + cross-family. PR title prefix «selfdev: », branch
#      auto/selfdev-<date>-<n>. It never merges.
#   ④ merge pass over every open auto/selfdev-* PR — AUTO only if ALL hold, else HOLD with the reason:
#        CI all pass · PR body «seed: human» AND its «request: «…»» text is a seed=human row of a queue
#        this loop wrote (the builder's word alone is not enough) · the clone's marker for that branch
#        has «crossfamily: panel(» · scripts/selfdev_merge_tier.sh says AUTO · not DEMOTED.
#      AUTO → scripts/pr_merge_verified.sh (squash + post-merge verify). HOLD → morning report line.
#   ⑤ report: tracks/_meta/selfdev/report_<date>.md in the live checkout.
#
# DEMOTION (goal-quench §Autonomy Ladder (d) — rollback feeds demotion): any commit on origin/main in
#   the last $SELFDEV_DEMOTE_DAYS days whose subject starts «Revert "selfdev:» → every PR is HOLD until
#   the operator removes the demotion by saying so (the revert ages out of the window, or
#   SELFDEV_DEMOTE_DAYS=0 for one run). The operator reverting an auto-merge is the strongest signal
#   this loop gets; it must cost autonomy, not be absorbed.
#
# NEVER: npm publish · tag push · delete · history rewrite · force push · writes to ~/.claude · FoD or
#   qasp repos · company data. These are outside the operator's grant and outside this clone; the
#   prompt says so, the 3.37.0 destructive-op hook blocks the destructive half under
#   bypassPermissions, and pre-push blocks main. Named residual (carried from the autopilot header,
#   rails ⑤ ⑥): bypassPermissions is not a sandbox, and digest text is untrusted input to the builder.
#   The merge decision is NOT the builder's — it is ④, mechanical, after the fact.
#
# ENV  SELFDEV_ALLOW_API_KEY(unset = the builder runs without ANTHROPIC_API_KEY) · FH_SELFDEV_DIR · SELFDEV_MAX_ITEMS(2) · SELFDEV_MAX_OPEN(2) · SELFDEV_CI_WAIT(1800s)
#      SELFDEV_BUILD_TIMEOUT(2700s) · SELFDEV_POLL(20s watchdog poll) · SELFDEV_DEMOTE_DAYS(30) · SELFDEV_DRY_RUN(0: 1 = no build, no
#      merge — print what would happen) · SELFDEV_NO_MERGE(0: any other value = build and open PRs as
#      usual, but never merge — a PR that passes every check is reported ELIGIBLE for the operator to merge) ·
#      FD_MODEL (pinned by the plist) · FD_CLAUDE_BIN
# RC   0 run completed (HOLDs are normal outcomes) · 2 HARNESS-ERROR (could not set up / read state)

set -u
LIVE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLONE="${FH_SELFDEV_DIR:-$HOME/projects/fh-selfdev}"
MAX_ITEMS="${SELFDEV_MAX_ITEMS:-2}"
MAX_OPEN="${SELFDEV_MAX_OPEN:-2}"
CI_WAIT="${SELFDEV_CI_WAIT:-1800}"
BUILD_TIMEOUT="${SELFDEV_BUILD_TIMEOUT:-2700}"
# watchdog poll interval: a finished build is noticed at the next poll, so lanes with an instant stub
# builder set 1 (16 build runs × 20 s pushed the lane file past CI's 300 s budget, 2026-11-10)
POLL="${SELFDEV_POLL:-20}"; case "$POLL" in ''|*[!0-9]*|0) POLL=20 ;; esac
DEMOTE_DAYS="${SELFDEV_DEMOTE_DAYS:-30}"
DRY="${SELFDEV_DRY_RUN:-0}"
# fail-closed: only an unset/empty value or a literal 0 allows merging — «true», «yes», « 1» all mean
# no-merge (codex R1: a typo must never turn merging back on)
case "${SELFDEV_NO_MERGE:-0}" in 0|'') NO_MERGE=0 ;; *) NO_MERGE=1 ;; esac
CLAUDE_BIN="${FD_CLAUDE_BIN:-$(command -v claude || echo "$HOME/.local/bin/claude")}"
REPO_SLUG="chrono-meta/forge-harness"
DATE="$(date +%Y-%m-%d)"
OUT="$LIVE/tracks/_meta/selfdev"
REPORT="$OUT/report_$DATE.md"
QUEUE="$OUT/queue_$DATE.md"
mkdir -p "$OUT" "$LIVE/tracks/_meta/logs"
LOG="$LIVE/tracks/_meta/logs/selfdev_loop_$DATE.log"

say() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG"; }
rep() { echo "$*" >> "$REPORT"; }
# replace the value of any paid-access variable the builder was given with *** in its output file, so
# the log and the report never carry it (only reachable with SELFDEV_ALLOW_API_KEY=1 — otherwise the
# builder never had the value). Every non-empty value, longest first (an overlapping shorter one must not
# leave the rest of a longer one behind); a redaction that cannot run withholds the output (codex R2).
redact_bout() {
  [ -s "$BOUT" ] || return 0
  python3 - "$BOUT" ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN <<'PY' || { echo "[builder output withheld — redaction failed]" > "$BOUT"; say "WARN: could not redact the builder output — withheld"; }
import os, sys
p = sys.argv[1]
vals = [os.environ.get(n, "") for n in sys.argv[2:]]
vals = sorted({v for v in vals if v}, key=len, reverse=True)
if vals:
    t = open(p, encoding="utf-8", errors="replace").read()
    for v in vals:
        t = t.replace(v, "***")
    open(p, "w", encoding="utf-8").write(t)
PY
}

LOCK="$OUT/.lock"
# lock = a dir holding the owner's PID. A lock whose PID is gone (SIGKILL, reboot) is reclaimed —
# otherwise one crash would make every later night exit 0 as «another run» forever (codex R1 #8).
if ! mkdir "$LOCK" 2>/dev/null; then
  owner="$(cat "$LOCK/pid" 2>/dev/null)"
  if [ -n "$owner" ] && kill -0 "$owner" 2>/dev/null; then
    say "another selfdev run (pid $owner) holds $LOCK — exiting (contention, not a failure)"; exit 0
  fi
  say "stale lock (owner pid ${owner:-unknown} not alive) — reclaiming"
  rm -f "$LOCK/pid"; rmdir "$LOCK" 2>/dev/null
  mkdir "$LOCK" 2>/dev/null || { say "HARNESS-ERROR: cannot take $LOCK"; exit 2; }
fi
echo $$ > "$LOCK/pid"
trap 'rm -f "$LOCK/pid"; rmdir "$LOCK" 2>/dev/null' EXIT

[ -f "$REPORT" ] || printf '# self-dev loop — %s\n\n' "$DATE" > "$REPORT"
rep "## run $(date '+%H:%M') · clone=$CLONE · dry=$DRY · no_merge=$NO_MERGE"

# ── ① clone ───────────────────────────────────────────────────────────────
BUILD=1
if [ ! -d "$CLONE/.git" ]; then
  url="$(git -C "$LIVE" remote get-url origin 2>/dev/null)" || { say "HARNESS-ERROR: no origin in $LIVE"; rep "- HARNESS-ERROR: no origin"; exit 2; }
  if [ "$DRY" = 1 ]; then
    say "dry-run: would clone $url → $CLONE"; rep "- dry-run: clone absent, would create"; BUILD=0
  else
    git clone -q "$url" "$CLONE" || { say "HARNESS-ERROR: clone failed"; rep "- HARNESS-ERROR: clone failed"; exit 2; }
    git -C "$CLONE" config core.hooksPath templates/.git-hooks
    say "cloned $url → $CLONE"
  fi
fi
if [ -d "$CLONE/.git" ]; then
  if [ -n "$(git -C "$CLONE" status --porcelain 2>/dev/null)" ]; then
    BUILD=0; say "clone dirty — a previous run left work; no build this run"; rep "- HOLD build: clone dirty (left as is)"
  elif [ "$DRY" != 1 ]; then
    git -C "$CLONE" fetch -q origin && git -C "$CLONE" switch -q main && git -C "$CLONE" merge -q --ff-only origin/main \
      || { BUILD=0; say "clone could not fast-forward main — no build"; rep "- HOLD build: clone main not fast-forwardable"; }
    # the commit gate's Axis 4 reads a gitignored manifest — seed it from the live checkout
    mkdir -p "$CLONE/tracks/_meta"
    [ -f "$LIVE/tracks/_meta/edit_manifest.yaml" ] && cp "$LIVE/tracks/_meta/edit_manifest.yaml" "$CLONE/tracks/_meta/edit_manifest.yaml"
  fi
fi

# ── demotion ──────────────────────────────────────────────────────────────
DEMOTED=0
case "$DEMOTE_DAYS" in ''|*[!0-9]*) DEMOTED=1; DEMOTE_DAYS=0; say "DEMOTED — SELFDEV_DEMOTE_DAYS not a number"; rep "- DEMOTED (every PR HOLD): SELFDEV_DEMOTE_DAYS not a number" ;; esac   # codex R2
if [ "$DEMOTE_DAYS" -gt 0 ]; then
  # an unreadable history is not «no revert» — fetch or log failure demotes this run (codex R1 #2)
  if ! git -C "$LIVE" fetch -q origin 2>/dev/null || ! hist="$(git -C "$LIVE" log origin/main --since="$DEMOTE_DAYS days ago" --format='%h %s' 2>/dev/null)"; then
    DEMOTED=1; say "DEMOTED — could not read origin/main history (fetch/log failed)"; rep "- DEMOTED (every PR HOLD): origin/main history unreadable this run"
  fi
  rv="$(printf '%s\n' "${hist:-}" | grep -F 'Revert "selfdev:')"
  if [ -n "$rv" ]; then
    DEMOTED=1; say "DEMOTED — operator reverted a selfdev merge within $DEMOTE_DAYS days"
    rep "- DEMOTED (every PR HOLD): $(echo "$rv" | head -3 | tr '\n' ';')"
  fi
fi

# ── ② queue ───────────────────────────────────────────────────────────────
python3 "$LIVE/scripts/selfdev_queue.py" --live "$LIVE" --date "$DATE" > "$QUEUE"
qrc=$?
if [ ! -s "$QUEUE" ]; then
  say "HARNESS-ERROR: queue empty (rc=$qrc)"; rep "- HARNESS-ERROR: queue not written"; exit 2
fi
rep "- queue: $(grep -E '^## ' "$QUEUE" | sed 's/^## //' | tr '\n' ';') (rc=$qrc)"

# ── ③ build ───────────────────────────────────────────────────────────────
open_auto() {
  gh pr list -R "$REPO_SLUG" --state open --limit 200 --json number,headRefName \
    -q '[.[] | select(.headRefName | startswith("auto/selfdev-"))] | .[].number' 2>/dev/null
}
OPEN_NOW="$(open_auto)"; orc=$?
if [ $orc -ne 0 ]; then
  BUILD=0; say "cannot list open PRs — not measurable is not zero; no build"; rep "- HOLD build: gh pr list failed"
elif [ "$(printf '%s\n' "$OPEN_NOW" | grep -c .)" -ge "$MAX_OPEN" ]; then
  BUILD=0; rep "- HOLD build: $(printf '%s\n' "$OPEN_NOW" | grep -c .) selfdev PR(s) open ≥ $MAX_OPEN"
fi

if [ "$BUILD" = 1 ] && [ "$DRY" != 1 ]; then
  cp "$QUEUE" "$CLONE/tracks/_meta/selfdev_queue_$DATE.md"
  PROMPT="[automated-run: launchd, unattended — no human present. You are the FH self-dev loop, running in a dedicated clone ($CLONE), never the operator's checkout.]

Read tracks/_meta/selfdev_queue_$DATE.md. Pick at most $MAX_ITEMS items and make one PR per item. Prefer seed=human rows with owner=session. Skip: owner=operator rows; items about FoD, qasp or any other repository; anything needing deletion, publishing, a tag, settings under ~/.claude, credentials or company data. The one exception is a seed=ablation row: its PR may remove exactly the measured section named in the row — nothing else — and that PR is never auto-merged. A quiet run with no PR is a correct outcome — never manufacture a change.

TIME: this whole run is killed at ${BUILD_TIMEOUT} seconds from its start, and anything not pushed by then is reported as stranded, not shipped. Do not run the full scripts/selfcheck.sh here — it takes longer than this run on this machine, and CI runs it sharded on every PR. Locally run only the lane suites your change touches (scripts/test_*_lanes.sh named for the files you edited, or the --self-test of a script you edited), in the foreground. Do not start a background task and wait for its notice. Push and open the PR as soon as the commit gate and those lanes pass; the PR body names which lanes ran locally and that the full suite is left to CI.

For each item: read the rule files the change touches first (CLAUDE.md says which). Branch auto/selfdev-$DATE-<n> from main. Run the FH 4-axis gate as .claude/rules/fh_4axis_gate.md specifies — real lanes, a real marker, an edit_manifest entry — and a cross-family review through fh-meta:auto-decorrelation; record crossfamily: panel(...) honestly or a DEGRADED value. If the change touches an irreversible or load-bearing surface (git hooks, gate/verdict code, publish/delete paths), still open the PR but say so in its first line — it will wait for the operator.

PR: title starts with «selfdev: ». Body has these lines verbatim-shaped:
seed: human        (only for a seed=human row) followed by
request: «<the row's 발화 text exactly as it appears in the queue>»
— or seed: candidate (with the source) for anything else. Then what changed, what was measured, what was not.

Never run gh pr merge, never push to main, never force-push, never tag. The merge decision is made after you, mechanically, not by you."
  # the builder's output goes to its own file first (its evidence, not mixed with the loop's [hh:mm:ss]
  # lines), then is appended to the log once the build ends
  BOUT="$OUT/build_${DATE}_$(date +%H%M%S).out"; : > "$BOUT"   # per run: a same-day rerun must not overwrite an earlier report's evidence (codex R2)
  # cutoff 5 min before the build: the host clock vs GitHub's createdAt may disagree (codex R2); the
  # selfdev-<date> branch prefix below keeps an earlier day's PR out of the window
  bstart="$(python3 -c 'import datetime as d;print((d.datetime.now(d.timezone.utc)-d.timedelta(minutes=5)).strftime("%Y-%m-%dT%H:%M:%SZ"))' 2>/dev/null)" \
    || bstart="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  say "build start (timeout ${BUILD_TIMEOUT}s, model ${FD_MODEL:-default})"
  # Subscription only (2026-11-07, video digest _dN-RMh0Tl0 candidate 3): launchd hands the builder no
  # ANTHROPIC_API_KEY, so spend 0 held — but only by accident of the environment. A manual run from a
  # shell that exports the key would bill the API. Unset it for the builder unless the operator says
  # otherwise, and say which happened. The value itself is never printed.
  # codex R1: the key is not the only paid path — a bearer token and the cloud-provider selectors are too.
  PAID_VARS="ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN CLAUDE_CODE_USE_BEDROCK CLAUDE_CODE_USE_VERTEX CLAUDE_CODE_USE_FOUNDRY"
  STRIP_KEY=1; [ "${SELFDEV_ALLOW_API_KEY:-}" = 1 ] && STRIP_KEY=
  paid_set=""; unset_args=""
  for v in $PAID_VARS; do
    [ -n "$(printenv "$v" 2>/dev/null)" ] && paid_set="$paid_set $v"
    unset_args="$unset_args -u $v"
  done
  if [ -n "$paid_set" ]; then
    if [ -n "$STRIP_KEY" ]; then rep "- NOTE:${paid_set} was set in the caller's env — unset for the builder (subscription only; SELFDEV_ALLOW_API_KEY=1 keeps it)"
    else rep "- NOTE:${paid_set} kept (SELFDEV_ALLOW_API_KEY=1) — this build bills the API, not the subscription"; fi
  fi
  # names only, never values; with the switch on, the builder's own output is redacted below (codex R1)
  # shellcheck disable=SC2086  # unset_args is a fixed list of «-u NAME» pairs, split on purpose
  ( cd "$CLONE" && env ${STRIP_KEY:+$unset_args} "$CLAUDE_BIN" -p "$PROMPT" --permission-mode bypassPermissions ${FD_MODEL:+--model "$FD_MODEL"} ) > "$BOUT" 2>&1 &
  pid=$!; deadline=$((SECONDS + BUILD_TIMEOUT))
  while kill -0 "$pid" 2>/dev/null && [ "$SECONDS" -lt "$deadline" ]; do sleep "$POLL" & wait $!; done
  if kill -0 "$pid" 2>/dev/null; then
    pkill -P "$pid" 2>/dev/null; kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null
    redact_bout
    cat "$BOUT" >> "$LOG" 2>/dev/null
    rep "- build killed by watchdog (${BUILD_TIMEOUT}s)"
  else
    wait "$pid"; brc=$?; rep "- build finished (rc=$brc)"
    redact_bout
    cat "$BOUT" >> "$LOG" 2>/dev/null
    # a builder that never logged in finishes fast and quietly — name it, it is not «nothing to do»
    # (2026-11-05 supervised run: env without USER → keychain lookup failed → «Not logged in»)
    if grep -q 'Not logged in' "$BOUT" 2>/dev/null; then
      rep "- HARNESS-ERROR: builder not logged in (claude -p printed «Not logged in» — check USER/HOME in the plist)"
    fi
  fi
  # How many PRs did this build open, and if none, WHY — in the builder's own words.
  # 2026-11-06: the first real night opened 0 PRs and the report said only «build finished (rc=0)»;
  # the builder's reasons (nothing eligible, item by item) sat in the log alone. A quiet night is a
  # correct outcome, but the report must say which kind of quiet it was.
  # count by creation time across ALL states (a PR opened then closed during the build still counts),
  # selfdev branches only (codex R1: an open-only before/after diff misses those and miscounts reopens)
  created="$(gh pr list -R "$REPO_SLUG" --state all --limit 200 --json number,headRefName,createdAt \
    -q "[.[] | select((.headRefName | startswith(\"auto/selfdev-$DATE\")) and .createdAt >= \"$bstart\")] | .[].number" 2>/dev/null)"; crc=$?
  if [ $crc -ne 0 ]; then
    rep "- PRs opened this run: UNMEASURED (gh pr list failed after the build)"
  else
    opened="$(printf '%s\n' "$created" | grep . | sed 's/^/#/' | tr '\n' ' ')"
    nopen="$(printf '%s' "$opened" | wc -w | tr -d ' ')"
    rep "- PRs opened this run: $nopen${opened:+ ($opened)}"
    if [ "$nopen" = 0 ]; then
      # the builder's account = everything it printed during this build, last 40 non-blank lines, each ≤ 300 chars
      acct="$(grep -v '^[[:space:]]*$' "$BOUT" 2>/dev/null | tail -40 | cut -c1-300)"
      if [ -n "$acct" ]; then
        rep "- no PR — the builder's own account (last 40 lines of $BOUT):"
        printf '%s\n' "$acct" | sed 's/^/  > /' >> "$REPORT"
      else
        rep "- no PR — the builder printed nothing: reason UNMEASURED (check $LOG)"
      fi
    fi
  fi
  git -C "$CLONE" switch -q main 2>/dev/null
elif [ "$DRY" = 1 ]; then
  rep "- dry-run: build skipped"
fi

if [ -d "$CLONE/.git" ]; then
  # Work the builder committed but never pushed is invisible after the switch back to main above: the
  # next night starts clean and the report would only say «0 PRs». 2026-11-10: the watchdog killed the
  # build mid-wait and two commits sat on a local auto/selfdev-* branch with no line anywhere. Name them.
  # Runs every night the clone exists, build or not — a dirty clone or the open-PR cap skips the build,
  # and must not also hide the work (codex R2). Not pushed or deleted here — the operator decides; this only makes them visible.
  # Every auto/selfdev-* branch, not only today's: a condition is reported every night until it is
  # resolved, and a commit a surviving grandchild made after this scan shows up the next night (codex R1).
  # «Unpushed» = reachable from the branch but from no origin ref — the same set the log lines print (codex R1).
  for br in $(git -C "$CLONE" for-each-ref --format='%(refname:short)' "refs/heads/auto/selfdev-*" 2>/dev/null); do
    ahead="$(git -C "$CLONE" rev-list --count "$br" --not --remotes=origin 2>/dev/null)"
    if [ -z "$ahead" ]; then rep "- STRANDED? $br in $CLONE: unpushed count UNMEASURED (rev-list failed)"
    elif [ "$ahead" -gt 0 ]; then
      rep "- STRANDED: $br in $CLONE has $ahead unpushed commit(s) — not shipped, not deleted:"
      git -C "$CLONE" log --format='    %h %s' -n 5 "$br" --not --remotes=origin >> "$REPORT" 2>/dev/null
    fi
  done
fi

# ── ④ merge pass ──────────────────────────────────────────────────────────
# the exact 발화 text of each seed=human row, one per line — the PR's «request:» must EQUAL one of
# these (grep -x), not merely appear inside one: containment would let a two-word fragment of any
# operator request launder a candidate into the auto tier (degrade_direction_scan C:substring-grounding).
# exact row texts from the queue tool itself — no delimiter stripping on the rendered markdown,
# which cut «Do X · owner=operator please» down to «Do X» (codex R2)
human_rows="$(python3 "$LIVE/scripts/selfdev_queue.py" --live "$LIVE" --emit-human 2>/dev/null)" || human_rows=""
# a failed listing is not «no open PRs» (codex R1 #7)
MERGE_LIST="$(open_auto)" || { say "HARNESS-ERROR: cannot list open selfdev PRs for the merge pass"; rep "- HARNESS-ERROR: merge pass could not list PRs"; exit 2; }
for pr in $MERGE_LIST; do
  reasons=""
  # bind every check below to ONE head commit; re-read just before merging (codex R1 #5)
  head_oid="$(gh pr view "$pr" -R "$REPO_SLUG" --json headRefOid -q .headRefOid 2>/dev/null)"
  [ -z "$head_oid" ] && reasons="$reasons head-unreadable"
  # CI — wait for pending, bounded
  waited=0
  while :; do
    ci="$(gh pr checks "$pr" -R "$REPO_SLUG" --json bucket -q '.[].bucket' 2>/dev/null)"; circ=$?
    # partial stdout from a failed call is not CI evidence (codex R2); gh exits 8 while checks pend
    if [ -z "$ci" ] || { [ $circ -ne 0 ] && [ $circ -ne 8 ]; }; then reasons="$reasons ci-unreadable(rc=$circ)"; break; fi
    if printf '%s\n' "$ci" | grep -qvE '^pass$'; then   # «skipping» is not «pass» (codex R1 #1)
      if printf '%s\n' "$ci" | grep -qE '^(fail|cancel|skipping)$'; then reasons="$reasons ci-fail-or-skipped"; break; fi
      if [ "$waited" -ge "$CI_WAIT" ] || [ "$DRY" = 1 ]; then reasons="$reasons ci-pending"; break; fi
      sleep 60; waited=$((waited + 60)); continue
    fi
    break
  done
  body="$(gh pr view "$pr" -R "$REPO_SLUG" --json body,headRefName -q '.body' 2>/dev/null)"
  head="$(gh pr view "$pr" -R "$REPO_SLUG" --json headRefName -q '.headRefName' 2>/dev/null)"
  if printf '%s\n' "$body" | grep -qE '^seed: human'; then
    req="$(printf '%s\n' "$body" | sed -nE 's/^request: «(.*)»[[:space:]]*$/\1/p' | head -1)"
    if [ -z "$req" ]; then reasons="$reasons seed-human-without-request"
    elif ! printf '%s\n' "$human_rows" | grep -qxF -- "$req"; then reasons="$reasons request-not-in-queue"; fi
  else
    reasons="$reasons seed-candidate"
  fi
  mk="$(ls "$CLONE"/tracks/_meta/.axes_23_passed_"$(printf '%s' "$head" | tr '/' '_')"_*.marker 2>/dev/null | tail -1)"
  if [ -z "$mk" ]; then reasons="$reasons no-marker"
  elif ! grep -qE '^crossfamily: panel\(' "$mk"; then reasons="$reasons crossfamily-not-panel"; fi
  tier_out="$(bash "$LIVE/scripts/selfdev_merge_tier.sh" --pr "$pr" --repo "$REPO_SLUG" 2>&1)"; trc=$?
  [ $trc -ne 0 ] && reasons="$reasons tier:$(printf '%s\n' "$tier_out" | tail -1 | sed 's/TIER=//')"
  [ "$DEMOTED" = 1 ] && reasons="$reasons demoted"

  if [ -n "$reasons" ]; then
    rep "- #$pr HOLD:$reasons"
    printf '%s\n' "$tier_out" | grep '^reason:' | sed 's/^/    /' >> "$REPORT"
    continue
  fi
  # final snapshot: head AND body read together; the authorization is re-checked on it (codex R2 —
  # a body edited after the first read must not ride on the old check)
  snap="$(gh pr view "$pr" -R "$REPO_SLUG" --json headRefOid,body -q '.headRefOid + "\n" + .body' 2>/dev/null)"
  now_oid="$(printf '%s\n' "$snap" | head -1)"
  if [ "$now_oid" != "$head_oid" ]; then rep "- #$pr HOLD: head moved during checks ($head_oid → ${now_oid:-?})"; continue; fi
  req2="$(printf '%s\n' "$snap" | sed -nE 's/^request: «(.*)»[[:space:]]*$/\1/p' | head -1)"
  if [ "$req2" != "$req" ] || ! printf '%s\n' "$human_rows" | grep -qxF -- "$req2"; then rep "- #$pr HOLD: request changed or unauthorized at final snapshot"; continue; fi
  # PR-only mode: the first real nights open PRs and stop here; the operator picks merges in the morning
  if [ "$NO_MERGE" = 1 ]; then rep "- #$pr ELIGIBLE (no-merge mode — every check passed; operator merges, head $head_oid)"; continue; fi
  if [ "$DRY" = 1 ]; then rep "- #$pr WOULD MERGE (dry-run, head $head_oid)"; continue; fi
  added_lanes="$(gh pr view "$pr" -R "$REPO_SLUG" --json files -q '.files[] | select(.changeType=="ADDED") | .path' 2>/dev/null | grep -E '^scripts/test_.*\.sh$')"
  if [ -n "$added_lanes" ]; then rerun="for l in $(echo $added_lanes); do bash \$l || exit 1; done"
  else rerun="git show --stat --format=%s HEAD"; fi   # docs-only: a carry check, not an exercise (named residual)
  if mo="$(bash "$LIVE/scripts/pr_merge_verified.sh" "$pr" --rerun "$rerun" --repo "$CLONE" --expect-head "$head_oid" --lease 'selfdev standing 2026-11-04 → 2027-02-04' 2>&1)"; then
    rep "- #$pr MERGED (auto) — $(printf '%s\n' "$mo" | tail -1)"
  else
    rep "- #$pr merge attempt FAILED — $(printf '%s\n' "$mo" | tail -2 | tr '\n' ' ')"
  fi
done

# signals the builder wrote inside the clone come home
for s in "$CLONE"/tracks/_meta/fh_signal_"$DATE"_*.md; do [ -f "$s" ] && cp -n "$s" "$LIVE/tracks/_meta/"; done
say "done — report $REPORT"
exit 0
