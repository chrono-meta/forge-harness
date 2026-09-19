#!/usr/bin/env bash
# prless_delta_scan.sh — «커밋은 됐는데 착륙 경로에 안 올라간» 델타를 센다.
#
# ## 왜 있나 (2026-09-16 명명 · 2026-09-19 실측 후 배선)
#
# 마감 체인 ①-b 는 `gh pr list --author @me --state open` 로 **열린 PR** 을 훑는다.
# 그 스윕의 정의상 **PR 이 애초에 없는 브랜치는 구조적으로 안 보인다** — 정확한 계기일수록
# 자기 정의 밖을 안 본다. 실제 피해: PR 없이 26일 떠 있던 브랜치의 수리가 격리된 동안
# main 은 죽은 추출 패턴을 계속 지시했다(`fh_signal_2026-09-16_prless-branch-blindspot.md`).
#
# 🟥 **이 계기는 «세는 것» 이지 «치우는 것» 이 아니다.** 브랜치 삭제는 Destructive-Op 게이트의
#    관할이고 여기서는 아무것도 지우지 않는다. 출력은 advisory 이며 커밋/푸시를 막지 않는다.
#
# ## 🟥 판별의 핵심 — squash 잔재를 «고유 델타» 로 오분류하지 않는 것
#
# 이 레포는 squash 머지를 쓴다. 그래서 브랜치의 커밋 해시는 머지 후에도 main 에 **없다** —
# `git log origin/main..<branch>` 나 `git cherry` 의 per-commit 비교는 이미 착륙한 브랜치를
# 전부 «미착륙» 으로 보고한다(2026-09-16 실측: `predelete_check.sh` 가 23 중 19 를 REVIEW).
#
# 판별자는 **브랜치 델타 «전체» 를 한 장의 패치로 본 patch-id** 다. squash 머지는 정확히 그
# 한 장을 main 에 심으므로 patch-id 가 일치한다. 실측(2026-09-19, 이 레포):
#
#     feat/verify-coverage-and-seeded  16 commits ahead · per-commit 15 «미착륙» · 합본 patch-id 일치 → 착륙함
#     bench/f-arm-target                1 commit  ahead · per-commit  1 «미착륙» · 합본 patch-id 불일치 → 진짜 고유 델타
#
# ⚠️ 한계, 이름으로 남긴다: squash 시 충돌 해소·리베이스가 끼면 합본 patch-id 가 달라져
#    **착륙한 브랜치가 고유 델타로 보고된다**(과탐지 방향). 부족 탐지가 아니라 과탐지로
#    기울인 것은 의도다 — advisory 이므로 과탐지는 한 줄 더 읽는 비용이고, 미탐지는
#    이 계기가 존재하는 이유를 없앤다.
#
# ## 부재 ≠ 0
# `gh` 가 없거나 PR 조회가 실패하면 **rc=2 UNMEASURED** 다. 「PR 이 없다 → 전부 고발」 도,
# 「조회 실패 → 깨끗함」 도 아니다.
#
# 사용:
#   bash scripts/prless_delta_scan.sh                 # origin/main 기준 전수
#   bash scripts/prless_delta_scan.sh --min-age-days 3
#   bash scripts/prless_delta_scan.sh --quiet          # 발견만 출력
#
# 환경변수(레인/오프라인용):
#   PRLESS_BASE=origin/main      기준 ref
#   PRLESS_PR_JSON=<path>        `gh pr list --json number,state,headRefName` 산출을 파일에서 읽는다
#   PRLESS_REPO=<path>           대상 레포(기본: cwd)
#
# 종료코드: 0 발견 없음 · 1 발견 있음(advisory) · 2 UNMEASURED/계기 오류
set -uo pipefail

MIN_AGE_DAYS=0
QUIET=0
while [ $# -gt 0 ]; do
  case "$1" in
    --min-age-days) MIN_AGE_DAYS="${2:-0}"; shift 2 ;;
    --quiet) QUIET=1; shift ;;
    -h|--help) sed -n '2,45p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

REPO="${PRLESS_REPO:-$PWD}"
cd "$REPO" 2>/dev/null || { echo "🟥 repo 없음: $REPO — 계기 오류" >&2; exit 2; }
git rev-parse --git-dir >/dev/null 2>&1 || { echo "🟥 git 레포가 아니다: $REPO — 계기 오류" >&2; exit 2; }

BASE="${PRLESS_BASE:-origin/main}"
git rev-parse --verify --quiet "$BASE" >/dev/null || { echo "🟥 기준 ref 없음: $BASE — UNMEASURED" >&2; exit 2; }

# ── PR 목록 (없으면 UNMEASURED, 0 아님) ───────────────────────────────────────
PRJSON=$(mktemp); trap 'rm -f "$PRJSON" "${PIDMAP:-}" "${REFLIST:-}" 2>/dev/null' EXIT
if [ -n "${PRLESS_PR_JSON:-}" ]; then
  [ -f "$PRLESS_PR_JSON" ] || { echo "🟥 PRLESS_PR_JSON 파일 없음: $PRLESS_PR_JSON — UNMEASURED" >&2; exit 2; }
  cat "$PRLESS_PR_JSON" > "$PRJSON"
else
  command -v gh >/dev/null 2>&1 || { echo "🟥 gh 없음 — PR 커버리지 UNMEASURED (0 으로 읽지 마라)" >&2; exit 2; }
  if ! gh pr list --state all --limit 2000 --json number,state,headRefName > "$PRJSON" 2>/dev/null; then
    echo "🟥 gh pr list 실패 — UNMEASURED (0 으로 읽지 마라)" >&2; exit 2
  fi
fi
# 형식 확인 — 빈 파일/깨진 JSON 을 «PR 0건» 으로 읽지 않는다
python3 - "$PRJSON" <<'PY' || { echo "🟥 PR 목록 파싱 실패 — UNMEASURED" >&2; exit 2; }
import json,sys
d=json.load(open(sys.argv[1]))
assert isinstance(d,list)
PY

pr_for() {  # headRefName -> "#N:STATE" 또는 "NONE"
  python3 - "$1" "$PRJSON" <<'PY'
import json,sys
name=sys.argv[1]; d=json.load(open(sys.argv[2]))
h=[x for x in d if x.get('headRefName')==name]
print("NONE" if not h else "#%s:%s" % (max(h,key=lambda x:x['number'])['number'], max(h,key=lambda x:x['number'])['state']))
PY
}

# ── 브랜치 수집 (base/HEAD 계열·gh-pages 제외) ────────────────────────────────
# 🟥 bash 3.2 (macOS 기본) — `mapfile` 이 없고, `set -u` 에서 빈 배열 "${a[@]}" 는 치명적이다.
#    그래서 배열이 아니라 임시 파일로 받는다. [[feedback_bash32_empty_array_under_set_u_is_fatal]]
REFLIST=$(mktemp)
# 🟥 `(HEAD detached at …)` 를 브랜치로 읽지 않는다 — detached HEAD 에서 `git branch` 가 뱉는
#    의사 항목이고, 그대로 두면 merge-base 가 안 잡혀 **가짜 UNRELATED_HISTORY 발견**이 된다.
#    (이 계기의 자기 레인이 잡았다 — 2026-09-19, L12 가 앵커다.)
{ git branch --format='%(refname:short)'; git branch -r --format='%(refname:short)'; } 2>/dev/null \
  | grep -v '^(' \
  | grep -vE '^(origin|gh-pages|origin/gh-pages|origin/HEAD)$' \
  | grep -vxF "${BASE#origin/}" | grep -vxF "$BASE" | sort -u > "$REFLIST"
REFCOUNT=$(grep -c . "$REFLIST" || true)
[ "${REFCOUNT:-0}" -gt 0 ] || { echo "ℹ️  비교할 브랜치 없음 (base=$BASE)"; exit 0; }

# ── main 쪽 patch-id 맵을 «한 번만» 만든다 (가장 오래된 merge-base 부터) ───────
OLDEST=""
while read -r r; do
  [ -n "$r" ] || continue
  mb=$(git merge-base "$BASE" "$r" 2>/dev/null) || continue
  [ -n "$mb" ] || continue
  if [ -z "$OLDEST" ] || git merge-base --is-ancestor "$mb" "$OLDEST" 2>/dev/null; then OLDEST="$mb"; fi
done < "$REFLIST" 
PIDMAP=$(mktemp)
if [ -n "$OLDEST" ]; then
  git log --format=%H "$OLDEST..$BASE" 2>/dev/null | while read -r c; do
    git show "$c" 2>/dev/null | git patch-id --stable 2>/dev/null | cut -d' ' -f1
  done | grep -v '^$' | sort -u > "$PIDMAP"
fi
NOW=$(date +%s)
FINDINGS=0
printf '%-50s %-7s %-5s %-22s %s\n' BRANCH KIND AGE VERDICT PR
printf '%-50s %-7s %-5s %-22s %s\n' "$(printf '%.0s-' {1..50})" ------- ----- ---------------------- --
while read -r r; do
  [ -n "$r" ] || continue
  name="${r#origin/}"
  kind=local; case "$r" in origin/*) kind=remote ;; esac
  mb=$(git merge-base "$BASE" "$r" 2>/dev/null) || mb=""
  ctime=$(git log -1 --format=%ct "$r" 2>/dev/null || echo "$NOW")
  age=$(( (NOW - ctime) / 86400 ))

  if [ -z "$mb" ]; then
    verdict=UNRELATED_HISTORY
  else
    ahead=$(git rev-list --count "$BASE..$r" 2>/dev/null || echo 0)
    if [ "$ahead" -eq 0 ]; then
      verdict=NO_DELTA
    elif [ "$(git rev-parse "$mb^{tree}")" = "$(git rev-parse "$r^{tree}")" ]; then
      verdict=NO_DELTA
    else
      pid=$(git diff "$mb..$r" 2>/dev/null | git patch-id --stable 2>/dev/null | cut -d' ' -f1)
      if [ -z "$pid" ]; then
        verdict=PATCHID_UNAVAILABLE       # 계기 미상 — CLEAN 으로 접지 않는다
      elif grep -qxF "$pid" "$PIDMAP" 2>/dev/null; then
        verdict=SQUASH_IN_BASE            # 합본이 base 에 있다 → 착륙함
      else
        # per-commit 도 전부 base 에 있으면 리베이스/체리픽 잔재
        uniq=0
        while read -r c; do
          [ -n "$c" ] || continue
          cp=$(git show "$c" 2>/dev/null | git patch-id --stable 2>/dev/null | cut -d' ' -f1)
          [ -n "$cp" ] && grep -qxF "$cp" "$PIDMAP" 2>/dev/null || uniq=$((uniq+1))
        done < <(git rev-list "$BASE..$r" 2>/dev/null)
        if [ "$uniq" -eq 0 ]; then verdict=COMMITS_IN_BASE; else verdict=UNIQUE_DELTA; fi
      fi
    fi
  fi

  pr=$(pr_for "$name")
  # 고유 델타일 때만 PR 커버리지를 묻는다
  if [ "$verdict" = "UNIQUE_DELTA" ]; then
    case "$pr" in
      NONE)       verdict=DELTA_NO_PR ;;
      *:OPEN)     verdict=DELTA_PR_OPEN ;;       # ①-b 가 이미 본다
      *:MERGED)   verdict=DELTA_AFTER_MERGED_PR ;;  # PR 은 머지됐는데 델타가 남았다
      *:CLOSED)   verdict=DELTA_PR_CLOSED ;;     # 안 머지되고 닫혔다
    esac
  fi

  case "$verdict" in
    DELTA_NO_PR|DELTA_AFTER_MERGED_PR|DELTA_PR_CLOSED|PATCHID_UNAVAILABLE|UNRELATED_HISTORY)
      if [ "$age" -ge "$MIN_AGE_DAYS" ]; then
        FINDINGS=$((FINDINGS+1))
        printf '🟥 %-47s %-7s %-5s %-22s %s\n' "$r" "$kind" "${age}d" "$verdict" "$pr"
      fi ;;
    *)
      [ "$QUIET" -eq 1 ] || printf '   %-47s %-7s %-5s %-22s %s\n' "$r" "$kind" "${age}d" "$verdict" "$pr" ;;
  esac
done < "$REFLIST"

echo
if [ "$FINDINGS" -gt 0 ]; then
  echo "🟥 착륙 경로에 없는 델타 $FINDINGS 건 (advisory — 막지 않는다)"
  echo "   DELTA_NO_PR           PR 이 아예 없다 — ①-b 스윕의 정의 밖"
  echo "   DELTA_AFTER_MERGED_PR PR 은 머지됐는데 브랜치에 델타가 남았다(부분 머지)"
  echo "   DELTA_PR_CLOSED       PR 이 머지 없이 닫혔다 — 의도일 수 있다, 확인은 사람 몫"
  echo "   🟥 처분(삭제)은 이 계기의 일이 아니다 — Destructive-Op 게이트로 가라"
  exit 1
fi
echo "✅ 착륙 경로 밖 델타 없음 (base=$BASE · 브랜치 ${REFCOUNT}개)"
exit 0
