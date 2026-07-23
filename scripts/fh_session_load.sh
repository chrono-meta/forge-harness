#!/usr/bin/env bash
# fh_session_load.sh — Mode D SessionStart companion-store freshness load (mechanical).
#
# WHY: the session-start companion-store load (refresh the private companion store + read its
# INDEX + card-vs-commit freshness) is documented in CLAUDE.local.md / modes_and_value.md
# §Session-start freshness as PROSE. Prose is salience-dependent: when the operator opens a
# session with an immediate task, the load silently does not fire and the agent operates on
# stale local memory. (Measured miss 2026-07-05: stale sidecar-tool version + a missed standing
# instruction, both because the companion refresh was skipped on task-first entry.) A
# SessionStart hook fires BEFORE the first user turn regardless of what the user types — so it
# closes the salience gap mechanically. This is the deferred hook in operational_adaptation.md
# §Guards whose measured revisit-trigger has now fired.
#
# WHAT: refresh the companion store, then emit a SHORT, IMPERATIVE freshness delta to stdout.
# A SessionStart hook's stdout is injected into the session context, so this block becomes
# unavoidable context the agent sees at turn 0.
#
# Graceful: if no companion store is configured (non-Mode-D user / ephemeral clone), emit
# nothing and exit 0 — this hook is a silent no-op outside Mode D. Offline-safe: refresh
# failure never blocks the session.
#
# Config (operator-local, opt-in): register in .claude/settings.local.json SessionStart and pass
# the companion-store path via the BE_DIR env in that gitignored registration (the public script
# hard-codes no private path). HUB_DIR overrides the hub path. Never commit the registration to
# the public settings.json — the hook is Mode-D-only.

set -uo pipefail

FH="${HUB_DIR:-${CLAUDE_PROJECT_DIR:-$HOME/projects/forge-harness}}"

# ── frontier-digest: 부재를 0으로 읽지 않는다 ────────────────────────────────────
# 왜: digest 는 launchd 로 매일 09:00 에 돌지만 **31회 중 6회(19%) 산출물 없이 끝났다**
# (2026-07-21 실측: exit 1 / 재시도 후에도 없음 / Attempt 에서 hang — 세 형태).
# 그런데 세션 시작은 "있으면 읽는다"만 했다 → **실패가 '오늘은 뉴스 없음'으로 읽혔다.**
# 부재와 실패는 0이 아니다. 로그가 있는데 산출물이 없으면 그건 부재가 아니라 FAILED 다.
# Portable mtime (epoch). GNU-first: on GNU/coreutils `stat -f %m` exits 0 with filesystem-format
# output (never reaching a BSD fallback), so probe `stat -c %Y` FIRST — on BSD/macOS it errors and
# falls through to `-f %m`. Always echoes a numeric value (0 on total failure) so `-gt` never breaks.
# (codex cross-family review 2026-07-05 [MED]: BSD-first order silently mis-parsed on GNU.)
_mtime() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0; }

_FD_LOG="$FH/tracks/_meta/logs/frontier_digest_$(date +%Y_%m_%d).log"
_FD_LOCK="$FH/tracks/_meta/logs/.frontier_digest.lock"
# 스케줄 전 부재 ≠ 실패: 잡은 launchd 로 09:00 에 돈다(com.forge-harness.frontier-digest.plist).
# 2026-07-23 08:07 세션이 "잡이 안 돌았을 수 있다" 경고를 받았고 잡은 09:00 에 정상 완주 —
# 경고가 나중에 읽히면 오보처럼 보인다. 그래서 ① 스케줄 전엔 경고하지 않고 ② 모든 분기에
# 발화 시각을 스탬프하고 ③ 러너 생존 신호(로그 갱신 or 락)가 있는 동안은 실패 판정을 보류한다.
_FD_SCHED=900                              # 09:00, HHMM 를 10진 정수로
_FD_NOW="${FD_NOW_HHMM:-$(date +%H%M)}"    # FD_NOW_HHMM = known-pair 캘리브레이션 전용(숫자 4자리만)
_FD_STAMP="$(date +%H:%M) 기준"
# 존재 판정은 러너 digest_ready 와 동일 술어(glob + -size +1k). 정확명 [ -f ] 는 러너와 관대함이
# 갈린다 — partial 파일(>0 <1k)이 성공으로 오독되고, suffix 착지가 영구 오경보가 된다
# (divergent-leniency: 같은 상태를 두 술어가 다르게 읽으면 한쪽 결과가 무음으로 샌다).
_fd_ready() { find "$FH/tracks/_meta" -maxdepth 1 -name "frontier_digest_$(date +%Y_%m_%d)*.md" -size +1k 2>/dev/null | grep -q .; }
if _fd_ready; then
  :
elif [ "$((10#$_FD_NOW))" -lt "$_FD_SCHED" ]; then
  echo "ℹ️  [frontier-digest] 오늘 digest 는 09:00 예정 — 아직 전이다($_FD_STAMP). 부재는 정상."
elif [ -f "$_FD_LOG" ]; then
  _FD_LOG_AGE=$(( $(date +%s) - $(_mtime "$_FD_LOG") ))
  # 러너 생존 신호 2종 — 어느 쪽이든 있으면 FAILED 대신 보류:
  #   ① 로그 최근 갱신(임계 2100s > 러너 최장 침묵창 = watchdog 1800s)
  #   ② 락 존재이면서 비-stale — stale 임계는 러너 자신의 락-브레이크 술어(-mmin +240)와 동일.
  #      락은 슬립-복귀 직후(로그는 오래됐지만 러너가 살아 재개하는 케이스)를 커버한다.
  _FD_ALIVE=""
  if [ -d "$_FD_LOCK" ] && [ -z "$(find "$_FD_LOCK" -maxdepth 0 -mmin +240 2>/dev/null)" ]; then
    _FD_ALIVE="락 존재"
  fi
  [ "$_FD_LOG_AGE" -lt 2100 ] && _FD_ALIVE="${_FD_ALIVE:+$_FD_ALIVE · }로그 ${_FD_LOG_AGE}s 전 갱신"
  if [ -n "$_FD_ALIVE" ]; then
    echo "ℹ️  [frontier-digest] 잡이 아직 돌고 있는 중일 수 있다($_FD_STAMP, $_FD_ALIVE) — 실패 판정 보류, 나중에 재확인."
  else
    echo "⚠️  [frontier-digest] 오늘 잡은 돌았는데 **산출물이 없다**($_FD_STAMP) — 부재가 아니라 실패다."
    echo "    마지막 로그: $(tail -1 "$_FD_LOG" 2>/dev/null | cut -c1-90)"
    echo "    → 수동 재실행하거나 실패 원인을 보라. '오늘은 뉴스 없음'으로 읽지 말 것."
  fi
else
  echo "⚠️  [frontier-digest] 스케줄(09:00) 지났는데 로그도 산출물도 없다($_FD_STAMP) — 잡이 아예 안 돌았을 수 있다(launchd 확인)."
fi
BE="${BE_DIR:-}"   # companion-store path — supplied by the gitignored hook registration; no public default.

# Non-Mode-D / no companion store → silent no-op (this is the majority path for public users).
[ -d "$BE/.git" ] || exit 0

# (_mtime is defined above the frontier-digest block — single definition, both sections use it.)

# 1) Refresh the companion store — fail-fast, never block the first turn, never mutate into a
#    merge/conflict. (codex cross-family review 2026-07-05 [HIGH]/[MED].)
#    - fail-fast env: no credential/SSH/host-key prompts can hang SessionStart.
#    - fetch + merge --ff-only: a fast-forward is the only safe hook mutation; a diverged companion
#      simply does not advance (no merge commit, no conflict state left behind) and we say so.
export GIT_TERMINAL_PROMPT=0
export GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new}"

# Hard wall-clock deadline on the ONLY network step. ConnectTimeout bounds the handshake, but a
# slow/stalled TRANSFER after connect has no bound — measured 2026-07-12: SessionStart worst-case
# 17.5s with 2 hook-timeout kills, all attributable to the fetch. perl-alarm is the portable
# watchdog (macOS ships no coreutils `timeout`); on overrun the fetch dies and the offline branch
# reports honestly. FH_FETCH_DEADLINE overrides (seconds). If perl is absent the wrapper degrades
# to running the command with NO deadline — a missing watchdog must never become a permanently
# skipped fetch misreported as "offline" (challenger catch 2026-07-12).
if command -v perl >/dev/null 2>&1; then
  _deadline() { perl -e 'alarm shift @ARGV; exec @ARGV' "$@"; }
else
  _deadline() { shift; "$@"; }
fi
PULL_NOTE=""
if _deadline "${FH_FETCH_DEADLINE:-8}" git -C "$BE" fetch --quiet >/dev/null 2>&1; then
  if git -C "$BE" merge --ff-only --quiet >/dev/null 2>&1; then
    PULL_NOTE="fetched + fast-forwarded"
  else
    PULL_NOTE="fetched but NOT fast-forward (companion diverged — read local + newest remote)"
  fi
else
  PULL_NOTE="fetch skipped (offline or deadline hit — read local state)"
fi

# 2) Session card date (the pointer the operator's close chain writes last).
CARD="$FH/tracks/_meta/reference_next_session_starter.md"
CARD_EPOCH=0
[ -f "$CARD" ] && CARD_EPOCH="$(_mtime "$CARD")"

# 3) Companion files NEWER than the card, in the surfaces that carry landed results/handoffs.
#    (paper-signals = completed experiments; handoff = cross-session/cross-machine; tracks-meta
#    = synced session meta.) These are exactly what a stale card fails to point at.
NEWER=""
for sub in paper-signals handoff tracks-meta digests; do
  d="$BE/$sub"
  [ -d "$d" ] || continue
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    fe="$(_mtime "$f")"
    if [ "${fe:-0}" -gt "${CARD_EPOCH:-0}" ]; then
      NEWER="${NEWER}  - ${f#$BE/}\n"
    fi
  done <<EOF
$(find "$d" -type f -name '*.md' -maxdepth 2 2>/dev/null)
EOF
done

# 3b) Handoff/signal STATUS map — mtime-INDEPENDENT (patched 2026-07-10).
#     WHY: the NEWER-than-card list (step 3) has a permanent blind spot — a status stamp
#     (DONE/SUPERSEDED/RESOLVED) can land in the companion store, then the card gets rewritten
#     WITHOUT reconciling that item; from then on the stamped file is "older than the card"
#     forever and step 3 never surfaces it again. (Measured miss 2026-07-10: a Qwen heavy
#     handoff stamped DONE 07-09 stayed listed as "awaiting RUN" in the card through a later
#     card rewrite — company sessions push results to the companion store but never run the
#     local close chain, so the card's ⑤ update is the ONLY reconcile point and it was prose.)
#     FIX: emit ALL frontmatter status lines from handoff/ + paper-signals/ every session,
#     regardless of mtime, so the turn-0 agent can mechanically cross-check card carry items.
STATUS_MAP=""
for sub in handoff paper-signals; do
  d="$BE/$sub"
  [ -d "$d" ] || continue
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    s="$(head -15 "$f" 2>/dev/null | grep -iE '^ *status:' | head -1 | sed 's/^ *//')"
    [ -n "$s" ] || continue
    # Match on the status VALUE's leading word only — a substring match anywhere in the line
    # false-positives on prose like "Remaining for DONE:" inside a PARTIAL status.
    v="$(printf '%s' "$s" | sed -E 's/^[Ss][Tt][Aa][Tt][Uu][Ss]: *//')"
    case "$v" in
      DONE*|SUPERSEDED*|RESOLVED*|CLOSED*) STATUS_MAP="${STATUS_MAP}  - ${f#$BE/} → ${s}\n" ;;
    esac
  done <<EOF
$(find "$d" -type f -name '*.md' -maxdepth 2 2>/dev/null)
EOF
done

# 4) INDEX.md live pointers (the operator's wiki TOC — read-first per CLAUDE.local.md).
INDEX_HEAD=""
if [ -f "$BE/INDEX.md" ]; then
  INDEX_HEAD="$(grep -iE 'live pointer|Live pointers' -A 8 "$BE/INDEX.md" 2>/dev/null | head -10)"
fi

# 5) Emit the freshness block (short + imperative). Only speak if there is something to say.
{
  echo "🔄 [FH SessionStart] companion-store freshness — $PULL_NOTE."
  if [ -n "$NEWER" ]; then
    echo "⚠️ NEWER THAN SESSION CARD — READ THESE BEFORE ACTING (card may be stale):"
    printf "%b" "$NEWER"
  else
    echo "   (no companion files newer than the session card)"
  fi
  if [ -n "$STATUS_MAP" ]; then
    echo "── handoff/signal STATUS map (mtime-independent — closed items) ──"
    printf "%b" "$STATUS_MAP"
    echo "→ CROSS-CHECK: any item above that the session card still lists as open/awaiting = stale card line. Fix it in this session's card update (⑤)."
  fi
  if [ -n "$INDEX_HEAD" ]; then
    echo "── INDEX.md live pointers ──"
    echo "$INDEX_HEAD"
  fi
  echo "Reminder: this is the Mode D auto-read (CLAUDE.local.md §Session-start companion load) —"
  echo "it fires even when the first user message is a task. Do not treat 'pulled' as 'read'."
} 2>/dev/null

# 6) Substrate-jump detection (structure-enforcing — version drift lives outside any session's
#    context boundary; silent when nothing changed). Detector, never a gate.
[ -x "$FH/scripts/substrate_jump_detector.sh" ] && bash "$FH/scripts/substrate_jump_detector.sh" "$FH" 2>/dev/null

exit 0
