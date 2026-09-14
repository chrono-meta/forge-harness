#!/usr/bin/env bash
# remote_marker_gate.sh — «플로어 없는 채널» 에서 온 FH 자산 변경이 4축 마커를 **들고 왔나**.
#
# ## 왜 있나 (2026-09-14 실측, 2/2)
#
# 4축 게이트의 기계 플로어는 `templates/.git-hooks/pre-commit` 이고, 그 증거(마커)는
# `tracks/**` 에 산다 — **gitignored 다.** 저작 노드가 이 레포의 작업 트리면 그게 맞다:
# 마커는 로컬에 남고 사람이 읽는다.
#
# 🟥 **그런데 원격 자율 노드는 작업 트리가 휘발한다.** 클라우드 세션이 `claude/*` 브랜치를
#    열고 FH 자산을 커밋하면, 훅이 그쪽에서 돌았든 안 돌았든 **마커는 그 체크아웃과 함께
#    사라진다.** 그리고 CI 필수 체크(`validate`)는 gitignored 파일을 **구조적으로 못 본다.**
#    ⇒ 마커 없는 FH 자산 커밋이 **초록으로** main 에 들어온다.
#
# 실측 (2026-09-14, `claude/` 접두사 머지 PR 전수):
#   #675 (09-07) → knowledge/shared/harness-core/field_verdict_crossfamily_gate.md · 마커 없음
#   #716 (09-14) → plugins/fh-meta/skills/asset-placement-gate/SKILL.md          · 마커 없음
#   2/2. 그리고 이 채널은 **주간 캐이던스로 매주 돈다**(self_evolution_routine.md §5) —
#   「한 번 났다」가 아니라 설계상 매주 나는 구멍이다.
#
# ## 이 검사가 «안» 하는 것 — 경계를 먼저 적는다
#
# 🟥 **형식만 본다. 값의 진위도, enum 멤버십도 안 본다.**
#    enum 정본은 `templates/.git-hooks/pre-commit` 의 `validate_{crossfamily,standpoint,…}_leg`
#    이고 그건 **저작 노드에서** 돈다. 여기서 그 로직을 다시 쓰면 관대함이 갈린 정규화 두 벌이
#    되고, 한쪽만 통과하는 입력이 무음으로 샌다. 그래서 **안 옮긴다.**
#    여기서 주장하는 것은 오직 «기록이 채널을 타고 왔나» — 존재·타입·비공허다.
#    (CLAUDE.md §Mechanization Boundary: 채널은 짓고, 판정은 안 굳힌다.)
#
# 🟥 **그리고 이건 «훅이 돌았다»의 증거가 아니다.** 옮긴 마커와 지어낸 마커는 바이트가 같다.
#    닫는 것은 «조용한 부재» 뿐이고, 그건 지금 0층이라 그것만으로도 값이 있다.
#
# ## 과차단 안 한다 — 채널로 스코핑한다
#
# 이 검사는 **로컬 플로어가 닿지 않는 채널에만** 건다. 보통 브랜치(사람이 이 레포 작업
# 트리에서 커밋)는 pre-commit 이 이미 마커를 하드 차단하므로 여기서 또 물으면
# **만족 불가능한 이중 요구**가 되고(마커는 gitignored 라 PR 본문에 없다) 그건 override 를
# 훈련시킨다. ⇒ 보통 브랜치는 `SKIP (로컬 플로어 관할)`.
#
# 종료코드:  0 = PASS 또는 SKIP  ·  1 = 마커가 안 왔다  ·  10 = HARNESS-ERROR(계기 고장)
#
# 환경변수:
#   RMG_HEAD_REF    git 범위의 끝점 ref  (기본: 현재 브랜치)
#   RMG_CHANNEL_NAME 채널 판정에 쓸 «브랜치 이름» (기본: RMG_HEAD_REF)
#                    🟥 둘을 갈라 둔 이유는 실사용에서 나왔다: `pull_request` 이벤트의 체크아웃은
#                    머지 ref 라 브랜치 이름이 로컬에 없고, 채널 이름은 `github.head_ref` 로만 온다.
#                    하나로 묶어 뒀더니 실물 PR 재현이 **전부 SKIP** 으로 떨어졌다(조용한 통과).
#   RMG_BASE_REF    비교 기준           (기본: origin/main)
#   RMG_BODY_FILE   PR 본문이 담긴 파일 (선택 — 없으면 커밋 메시지만 본다)
#   RMG_CHANNEL_RE  플로어 없는 채널 패턴 (기본: '^claude/')
#   RMG_GUARD_FILE  GUARD_PATHSPEC 정본  (기본: templates/regression_guard.sh)
set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT" || exit 10

HEAD_REF="${RMG_HEAD_REF:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null)}"
BASE_REF="${RMG_BASE_REF:-origin/main}"
CHANNEL_NAME="${RMG_CHANNEL_NAME:-$HEAD_REF}"
CHANNEL_RE="${RMG_CHANNEL_RE:-^claude/}"
GUARD_FILE="${RMG_GUARD_FILE:-templates/regression_guard.sh}"
BODY_FILE="${RMG_BODY_FILE:-}"

say(){ printf '%s\n' "$*"; }

# ── 1. 채널 판정 ──────────────────────────────────────────────────────────────
if [ -z "$CHANNEL_NAME" ]; then
  say "❌ HARNESS-ERROR — 채널 이름이 비었다(detached HEAD 에서 RMG_CHANNEL_NAME 미지정)."
  say "   🟥 이름을 못 읽은 것을 «채널 아님» 으로 렌더하지 않는다."
  exit 10
fi
if ! printf '%s' "$CHANNEL_NAME" | /usr/bin/grep -qE "$CHANNEL_RE"; then
  say "⏭️  SKIP — '$CHANNEL_NAME' 는 플로어 없는 채널이 아니다(패턴 $CHANNEL_RE)."
  say "     로컬 pre-commit 4축 게이트가 관할한다. 여기서 또 묻지 않는다(이중 요구 금지)."
  exit 0
fi
say "📡 플로어 없는 채널: $CHANNEL_NAME  (git 범위: $BASE_REF..$HEAD_REF)"

# ── 2. FH 자산을 건드렸나 — 경로 목록은 «정본에서 뽑는다», 다시 안 적는다 ──────
#    GUARD_PATHSPEC 은 templates/regression_guard.sh 가 정본이고 4축 자산 목록에 맞춰
#    이미 두 번 보정된 배열이다. 여기 복사본을 두면 갈린다.
if [ ! -r "$GUARD_FILE" ]; then
  say "❌ HARNESS-ERROR — 경로 정본을 못 읽는다: $GUARD_FILE"
  say "   🟥 이건 «자산 0개» 가 아니다. 미측정을 통과로 렌더하지 않는다."
  exit 10
fi
PATHSPEC=$(awk '/^GUARD_PATHSPEC=\(/{f=1;next} f&&/^\)/{exit} f' "$GUARD_FILE" \
           | sed -E "s/#.*$//" | sed -E "s/^[[:space:]]*'//; s/'[[:space:]]*$//" \
           | /usr/bin/grep -vE '^[[:space:]]*$')
NPAT=$(printf '%s\n' "$PATHSPEC" | /usr/bin/grep -c . 2>/dev/null)
NPAT=${NPAT:-0}
if [ "$NPAT" -lt 5 ]; then
  say "❌ HARNESS-ERROR — GUARD_PATHSPEC 추출이 $NPAT 개다(5 미만)."
  say "   정본의 배열 표기가 바뀌었거나 파서가 깨졌다. 조용히 «자산 없음» 으로 넘기지 않는다."
  exit 10
fi

git rev-parse --verify -q "$BASE_REF" >/dev/null 2>&1 || {
  say "❌ HARNESS-ERROR — 기준 ref 를 못 찾는다: $BASE_REF (얕은 클론이면 fetch 먼저)"
  exit 10
}

# 🟥 «변경 0» 의 두 얼굴을 가른다 — 2026-09-14 실물 재현에서 실제로 걸렸다.
#    이미 머지된 head 를 그 base 와 비교하면 merge-base 가 head 자신이라 diff 가 **비고**,
#    검사기는 그걸 «FH 자산 미접촉» 으로 렌더한다. 「자산이 없다」와 「비교가 성립 안 한다」가
#    같은 0 으로 보이는 자리다([[feedback_not_found_is_not_zero_family]]).
_h=$(git rev-parse --verify -q "$HEAD_REF^{commit}" 2>/dev/null)
_b=$(git rev-parse --verify -q "$BASE_REF^{commit}" 2>/dev/null)
# 동일 커밋이면 «변경 없음» 이 정직한 답이다(막 자른 브랜치). 과차단 금지 — 아래 퇴화 판정은
# **진부분집합**(head 가 base 보다 «뒤처진» 경우)에만 건다.
if [ -n "$_h" ] && [ "$_h" != "$_b" ] && git merge-base --is-ancestor "$HEAD_REF" "$BASE_REF" 2>/dev/null; then
  say "❌ HARNESS-ERROR — head($HEAD_REF) 가 이미 base($BASE_REF) 의 조상이다. 비교가 성립 안 한다."
  say "   🟥 이 상태의 «변경 0» 은 «자산 미접촉» 이 아니다. 통과로 렌더하지 않는다."
  say "   (머지된 PR 을 사후 재현하려면 base 를 그 시점으로: RMG_BASE_REF=<head>^ )"
  exit 10
fi

# bash 3.2 + set -u 에서 빈 배열 전개는 치명적이라 관용구로 받는다
SPEC_ARGS=()
while IFS= read -r p; do [ -n "$p" ] && SPEC_ARGS+=("$p"); done <<EOF
$PATHSPEC
EOF
# 🟥 `...HEAD` 가 아니라 `..."$HEAD_REF"` 다. 초판이 리터럴 HEAD 를 썼고 **레인 10개가 다
#    통과했다** — 레인은 체크아웃한 브랜치를 그대로 HEAD_REF 로 줘서 둘이 늘 같았기 때문이다.
#    실물 PR 을 사후 재현할 때(체크아웃은 내 브랜치, 과녁은 fetch 한 ref) 처음 갈라졌고,
#    5개짜리 diff 가 93개로 나왔다. 첫 실사용이 레인이 못 본 것을 잡은 자리다.
CHANGED=$(git diff --name-only "$BASE_REF"..."$HEAD_REF" -- ${SPEC_ARGS[@]+"${SPEC_ARGS[@]}"} 2>/dev/null)
NCH=$(printf '%s\n' "$CHANGED" | /usr/bin/grep -c . 2>/dev/null); NCH=${NCH:-0}

if [ "$NCH" -eq 0 ]; then
  say "✅ PASS — FH 자산을 건드리지 않았다 (패턴 $NPAT 개 대조, 일치 0)."
  exit 0
fi
say "📄 FH 자산 $NCH 개를 건드렸다:"
printf '%s\n' "$CHANGED" | sed 's/^/     /'

# ── 3. 기록면 = 커밋 메시지 (+ 선택적 PR 본문) ────────────────────────────────
RECORD=$(git log --format='%B' "$BASE_REF".."$HEAD_REF" 2>/dev/null)
if [ -n "$BODY_FILE" ] && [ -r "$BODY_FILE" ]; then
  RECORD="$RECORD
$(cat "$BODY_FILE")"
  say "📝 기록면: 커밋 메시지 + PR 본문($BODY_FILE)"
else
  say "📝 기록면: 커밋 메시지만 (PR 본문 미제공)"
fi

# ── 4. 필수 필드 — 존재 + 비공허 ──────────────────────────────────────────────
#    고르는 기준: pre-commit 이 **하드 차단**하는 축(crossfamily · standpoint)과,
#    «어느 축을 돌렸나» 를 적는 자리(axes-run). oracle 은 훅에서 형식만 보므로 여기서도
#    형식만 — 없으면 실패가 아니라 경고다(훅과 강도를 맞춘다).
MISSING=""
VACUOUS=""
for field in "axes-run" "crossfamily" "standpoint"; do
  line=$(printf '%s\n' "$RECORD" | /usr/bin/grep -m1 -E "^[[:space:]]*${field}:" 2>/dev/null)
  if [ -z "$line" ]; then
    MISSING="$MISSING $field"
    continue
  fi
  val=$(printf '%s' "$line" | sed -E "s/^[[:space:]]*${field}:[[:space:]]*//")
  # 비공허 = 값이 있고, 자리표시자가 아니다
  case "$val" in
    ""|"<"*|"TODO"*|"todo"*|"n/a"|"N/A"|"-") VACUOUS="$VACUOUS $field" ;;
  esac
done

if [ -n "$MISSING" ] || [ -n "$VACUOUS" ]; then
  say ""
  say "❌ FAIL — 플로어 없는 채널이 FH 자산을 바꾸면서 4축 마커를 안 들고 왔다."
  [ -n "$MISSING" ] && say "   없는 필드 :$MISSING"
  [ -n "$VACUOUS" ] && say "   공허한 필드:$VACUOUS (자리표시자는 기록이 아니다)"
  say ""
  say "   처방 — 마커 본문을 **커밋 메시지에** 싣는다(tracks/ 는 gitignored 라 안 따라온다):"
  say "     axes-run: ⓐ=… ⓑ=→standpoint ⓒ=… ⓓ=… ⓔ=… ⓕ=…"
  say "     crossfamily: DEGRADED_PANEL_UNUSED — <무엇을 탐침했고 왜 안 썼나>"
  say "     standpoint: not-applicable — <무엇을 확인해서 대상이 없다고 봤나>"
  say ""
  say "   🟥 이 검사는 **형식만** 본다 — 값이 참인지는 안 본다(그건 사람 몫으로 남은 자리다)."
  say "   정본: CLAUDE.md §FH Improvement 4-Axis Auto-Gate · .claude/rules/fh_4axis_gate.md"
  exit 1
fi

say ""
say "✅ PASS — 마커 3필드가 커밋 기록에 실려 왔다 (axes-run · crossfamily · standpoint)."
say "   🟥 형식만 확인했다. 값의 진위와 «훅이 실제로 돌았나» 는 **안 닫혔다** —"
say "      옮긴 마커와 지어낸 마커는 바이트가 같다. 닫은 것은 «조용한 부재» 하나다."
exit 0
