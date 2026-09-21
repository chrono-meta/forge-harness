#!/usr/bin/env bash
# env_layer_fingerprint.sh — 같은 저장소의 두 체크아웃을 **나란히 놓을 수 있게** 만드는 계기.
#
# ## 왜 있나 (2026-09-21 실측, 클라우드 클론 ↔ 운영자 맥)
#
# FH 는 «읽는 층»과 «막는 층»이 서로 다른 수송로로 다닌다:
#   읽는 층 — CLAUDE.md · knowledge/ · scripts/ · templates/.git-hooks/ 의 **소스** → git 으로 간다
#   막는 층 — core.hooksPath 배선 · 실행 가능한 훅 · settings*.json 등록 → **git 으로 안 간다**
#   기록 층 — tracks/_meta 의 마커·매니페스트·카드                      → gitignored, 안 간다
#   패턴 층 — .public-surface-patterns · .residency-patterns · CLAUDE.local.md → 안 간다
#
# 그래서 새 클론은 **규율을 전부 읽고 게이트는 하나도 못 돌리는 상태**가 기본값이다. 그리고 그
# 상태가 조용하다 — 새 클론에서 `git commit` 은 그냥 성공한다. 4축 게이트가 통과한 것이 아니라
# **돌지 않은 것**인데, 출력이 같다(둘 다 무음). 2026-09-21 실측: 이 클론에서 FH 자산을 스테이징
# 하고 커밋했을 때 훅이 없으면 무음 통과, `core.hooksPath` 한 줄을 잡자 같은 커밋이 Axis 2+3 ·
# Axis 4 로 차단됐다. 바뀐 것은 코드가 아니라 **배선 한 줄**이다.
#
# ## 무엇을 재나 — «있고 없음»이고 값이 아니다
#
# 층별로 PRESENT / ABSENT / UNMEASURED 세 값만 낸다. 🟥 **값은 절대 안 싣는다** — 이 출력은
# 스레드·PR·이슈에 붙여서 두 체크아웃을 대조하라고 만든 것이라, 운영자 사설 리터럴이 실리면
# 그 자체가 §Pre-Publish Surface Gate 가 막는 유출이 된다. 그래서 경로와 판정만 낸다.
#
# 🟥 **UNMEASURED 는 ABSENT 가 아니다.** 판정할 계기가 없는 칸(예: python3 없이 settings 등록
# 여부)은 「없음」이 아니라 「못 쟀음」으로 남는다 — `not found` ≠ `0` (CLAUDE.md §Instrument
# Calibration). 그 둘을 접으면 안 돈 검사가 초록으로 읽힌다.
#
# ## 계기 자체의 known-pair — READ 층이 내장 대조군이다
#
# READ 층(tracked 자산)은 **어느 체크아웃에서든 PRESENT 여야 한다.** 거기가 ABSENT 로 나오면
# 드리프트가 아니라 **계기를 엉뚱한 디렉터리에 겨눈 것**이므로 rc=2(계기 오류)로 끝낸다.
# 전부 ABSENT 를 찍고 「드리프트가 크다」고 보고하는 실패 모드를 구조적으로 막는다.
# `--selftest` 는 합성 픽스처 두 개(빈 허브 / 층을 채운 허브)로 분리능을 직접 보인다.
#
# ## 이 스크립트가 아닌 것
#
# `scripts/fh_node_check.sh` 와 역할이 다르다. 그쪽은 **한 머신의 바닥이 깔렸나**를 세션 시작에
# 알리는 탐지기고(산문 권고, 항상 exit 0, 상태는 머신-로컬), 이쪽은 **두 체크아웃을 대조할 수
# 있는 형태**를 낸다. 겹치는 칸(훅 실행 가능 여부)은 있지만 목적이 다르다 — 저쪽은 알리고,
# 이쪽은 **diff 가 되게** 한다. 이 스크립트는 어떤 훅에도 배선돼 있지 않다: 게이트가 아니라 계기다.
#
# ## 사용
#   bash scripts/env_layer_fingerprint.sh              # 사람이 읽는 표
#   bash scripts/env_layer_fingerprint.sh --digest     # 한 줄 — 두 쪽에서 찍어 비교
#   bash scripts/env_layer_fingerprint.sh --tsv        # id<TAB>layer<TAB>verdict<TAB>consequence
#   bash scripts/env_layer_fingerprint.sh --selftest   # known-pair 분리능 확인
#   FH_HUB=/path/to/other/checkout bash scripts/env_layer_fingerprint.sh
#
# rc: 0 = 모든 층 PRESENT · 1 = 하나 이상 ABSENT/UNMEASURED(드리프트 있음) · 2 = 계기 오류
# 레인: scripts/test_env_layer_fingerprint_lanes.sh (selfcheck.sh 에서 실행)

set -uo pipefail

FH="${FH_HUB:-${HUB_DIR:-${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}}}"
MODE="table"
case "${1:-}" in
  --digest)   MODE="digest" ;;
  --tsv)      MODE="tsv" ;;
  --selftest) MODE="selftest" ;;
  --help|-h)  sed -n '2,40p' "$0"; exit 0 ;;
  "")         : ;;
  *) echo "unknown argument: $1 (try --help)" >&2; exit 2 ;;
esac

ROWS=""        # id<TAB>group<TAB>verdict<TAB>consequence
add_row() { ROWS="${ROWS}${1}	${2}	${3}	${4}
"; }

# _exists PATH → PRESENT|ABSENT   (파일이든 디렉터리든)
_exists() { [ -e "$1" ] && printf 'PRESENT' || printf 'ABSENT'; }

# ─────────────────────────────────────────────────────────────────────────────
# probe_hub HUB — 모든 행을 ROWS 에 채운다. 인자를 받으므로 selftest 가 픽스처에 겨눌 수 있다.
# ─────────────────────────────────────────────────────────────────────────────
probe_hub() {
  local H="$1"
  ROWS=""

  # ── READ 층 — tracked. 내장 대조군: 여기가 ABSENT 면 드리프트가 아니라 계기 오류다 ──────
  add_row read.doctrine   READ "$(_exists "$H/CLAUDE.md")" \
    "상주 규율 — 없으면 겨눈 곳이 FH 허브가 아니다"
  add_row read.gatespec   READ "$(_exists "$H/.claude/rules/fh_4axis_gate.md")" \
    "4축 게이트 정본 — 마커 필드 정의가 여기 산다"
  add_row read.hooksrc    READ "$(_exists "$H/templates/.git-hooks/pre-commit")" \
    "훅 **소스** — git 으로 오지만, 와 있는 것과 배선된 것은 다르다"
  add_row read.scripts    READ \
    "$([ -d "$H/scripts" ] && [ "$(find "$H/scripts" -maxdepth 1 -name '*.sh' 2>/dev/null | wc -l | tr -d ' ')" -gt 0 ] && printf 'PRESENT' || printf 'ABSENT')" \
    "scripts/ 본체 — 계기들이 사는 곳"

  # ── ENFORCE 층 — 막는 층. git 으로 오지 않는다 ────────────────────────────────
  # 설정 키가 아니라 **실행 가능한 훅**을 본다: core.hooksPath 가 안 잡혀 있어도 .git/hooks 에
  # 실물이 있으면 정상 설치고, 잡혀 있는데 가리키는 곳이 비면 깨진 설치다(키만 보면 초록).
  local h p verdict
  for h in pre-commit pre-push; do
    p="$(git -C "$H" rev-parse --git-path "hooks/$h" 2>/dev/null)"
    verdict=ABSENT
    if [ -n "$p" ]; then
      case "$p" in /*) : ;; *) p="$H/$p" ;; esac
      if [ -x "$p" ]; then
        if grep -q 'FH 4-Axis\|FH_SESSION_CLOSE\|DESTRUCTIVE_OP_OK' "$p" 2>/dev/null; then
          verdict=PRESENT
        else
          verdict=UNMEASURED   # 훅은 있는데 FH 게이트가 아니다 — 다른 프레임워크가 쥐고 있다
        fi
      fi
    fi
    add_row "hook.$h" ENFORCE "$verdict" \
      "$([ "$h" = pre-commit ] \
         && printf '없으면 4축 게이트가 안 돈다 — 커밋이 **무음으로 성공**한다' \
         || printf '없으면 Destructive-Op / 마감 게이트가 안 돈다 — 푸시가 무음으로 성공한다')"
  done

  # SessionStart 등록. python3 가 없으면 «없음»이 아니라 «못 쟀음»이다.
  local reg=ABSENT
  if ! command -v python3 >/dev/null 2>&1; then
    reg=UNMEASURED
  else
    python3 - "$H" <<'PY' && reg=PRESENT
import json, os, sys
hub = sys.argv[1]
for p in (os.path.join(hub, ".claude", "settings.local.json"),
          os.path.join(hub, ".claude", "settings.json"),
          os.path.expanduser("~/.claude/settings.json")):
    try:
        groups = json.load(open(p)).get("hooks", {}).get("SessionStart", [])
    except Exception:
        continue
    if any(g.get("hooks") for g in groups):
        sys.exit(0)
sys.exit(1)
PY
  fi
  add_row hook.sessionstart ENFORCE "$reg" \
    "없으면 turn-0 로드(신선도·env-delta·node floor)가 안 뜬다"

  # ── EVIDENCE 층 — gitignored 기록. 게이트가 **읽는** 입력이다 ──────────────────
  add_row evidence.manifest EVIDENCE "$(_exists "$H/tracks/_meta/edit_manifest.yaml")" \
    "Axis 4 입력 — 없으면 훅이 배선된 쪽에서만 FAIL 이 뜬다"
  add_row evidence.marker EVIDENCE \
    "$([ "$(find "$H/tracks/_meta" -maxdepth 1 -name '.axes_23_passed_*' 2>/dev/null | wc -l | tr -d ' ')" -gt 0 ] && printf 'PRESENT' || printf 'ABSENT')" \
    "Axis 2+3 입력 — 마커는 브랜치·날짜별이라 한쪽에만 산다"
  add_row evidence.card EVIDENCE "$(_exists "$H/tracks/_meta/reference_next_session_starter.md")" \
    "세션 카드 — 없으면 마감 ⑤ 와 온보딩 «returning» 판정의 입력이 없다"
  # 🟥 «tracks 에 파일이 있나» 로 세면 안 된다 — tracks/_contrib/** 와 일부 _meta 파일은
  #    **tracked** 라 새 클론에도 딸려 온다. 그걸 세면 갓 클론한 허브가 「기록이 있다」로 읽히고,
  #    그것이 CLAUDE.md 가 이름으로 적어 둔 온보딩 분기 FP 와 같은 오류다(2026-08-30 실측).
  #    그래서 **git 이 추적하지 않는 파일만** 센다 = 이 체크아웃에서만 사는 기록.
  local untracked_tracks=0
  if git -C "$H" rev-parse --git-dir >/dev/null 2>&1; then
    # 전체 파일 수 − tracked 파일 수. `ls-files --others` 의 ignored/non-ignored 플래그 조합에
    # 기대지 않는다: 두 부류 모두 «이 체크아웃에만 사는 것»이라 합쳐서 세야 맞다.
    _all="$(find "$H/tracks" -type f ! -name '.gitkeep' 2>/dev/null | grep -c . || true)"
    _trk="$(git -C "$H" ls-files -- tracks 2>/dev/null | grep -vc '\.gitkeep$' || true)"
    untracked_tracks=$(( _all - _trk )); [ "$untracked_tracks" -lt 0 ] && untracked_tracks=0
  else
    # git 이 아니면 «없음»이 아니라 «못 쟀음» — 픽스처/비-git 디렉터리를 0 으로 접지 않는다.
    untracked_tracks=UNMEASURABLE
  fi
  # 🟥 `case` 를 명령치환 `$( )` 안에 두지 마라. bash 3.2 (macOS 기본 /bin/bash) 는 그 안을
  #    런타임에 다시 파싱하면서 깨지고, `bash -n` 은 통과한다. 깨진 결과는 중단이 아니라
  #    **값 자리에 셸 소스가 들어간 채 rc=0** 이다 — 즉 같은 커밋이 플랫폼마다 다른 지문을 낸다.
  #    이 계기의 용도가 두 체크아웃의 지문 대조라서, 그 형태는 여기서 결함이다. 레인 L9/L9b.
  local _tracks_state
  case "$untracked_tracks" in
    UNMEASURABLE) _tracks_state=UNMEASURED ;;
    0)            _tracks_state=ABSENT ;;
    *)            _tracks_state=PRESENT ;;
  esac
  add_row evidence.tracks EVIDENCE "$_tracks_state" \
    "이 체크아웃에만 사는 세션 기록 — 인사 분기와 recall 이 읽는 코퍼스"

  # ── PATTERN 층 — gitignored 리터럴. **조용히 커버리지를 깎는다** ───────────────
  add_row pattern.psa PATTERN "$(_exists "$H/.claude/rules/.public-surface-patterns")" \
    "없으면 기밀성 스캔이 defaults-only 로 돈다 — 회사명·실명 클래스 UNSCANNED"
  add_row pattern.residency PATTERN "$(_exists "$H/.claude/rules/.residency-patterns")" \
    "없으면 상주 유입 게이트가 줄어든 패턴셋으로 돈다"
  add_row pattern.registry PATTERN "$(_exists "$H/.claude/registry/LOCAL_SKILL_REGISTRY.md")" \
    "없으면 Cross-Project Skill Bus 가 제안할 목록이 비어 있다"
  add_row pattern.localmd PATTERN "$(_exists "$H/CLAUDE.local.md")" \
    "없으면 레지스터 핀·디스패치 리스가 없다 → 디스패치는 NOT RECORDED(건별 승인)"
}

# ─────────────────────────────────────────────────────────────────────────────
verdict_of() { printf '%s\n' "$ROWS" | awk -F'\t' -v k="$1" '$1==k{print $3}'; }
count_of()   { printf '%s\n' "$ROWS" | awk -F'\t' -v v="$1" '$3==v' | grep -c . ; }

# READ 층 무결성 = 계기 교정. 하나라도 ABSENT 면 겨눈 곳이 틀렸다.
read_layer_broken() {
  printf '%s\n' "$ROWS" | awk -F'\t' '$2=="READ" && $3!="PRESENT"' | grep -q .
}

digest_line() {
  local body
  body="$(printf '%s\n' "$ROWS" | awk -F'\t' 'NF{printf "%s=%s;", $1, $3}')"
  local sum
  # GNU 먼저, macOS 폴백 — 반대로 두면 GNU 에서 shasum 이 없을 때만 도는 게 아니라
  # 있을 때도 mac 경로를 타서 포맷이 갈린다.
  sum="$(printf '%s' "$body" | sha256sum 2>/dev/null || printf '%s' "$body" | shasum -a 256 2>/dev/null || printf 'UNMEASURED  -')"
  printf 'fh-layers v1 %s %s\n' "$(printf '%s' "$sum" | awk '{print substr($1,1,12)}')" "$body"
}

emit_table() {
  local present absent unmeasured
  present="$(count_of PRESENT)"; absent="$(count_of ABSENT)"; unmeasured="$(count_of UNMEASURED)"
  echo "══ FH 층 지문 — 두 체크아웃을 나란히 놓으라고 만든 표 ══"
  echo "hub        : $FH"
  echo "head       : $(git -C "$FH" rev-parse --short HEAD 2>/dev/null || echo UNMEASURED)  branch: $(git -C "$FH" branch --show-current 2>/dev/null || echo UNMEASURED)"
  echo "node       : ${FH_MACHINE_ID:-$(hostname -s 2>/dev/null || echo unknown)}"
  echo ""
  printf '  %-9s %-20s %-11s %s\n' "층" "항목" "판정" "ABSENT 이면 무엇이 달라지나"
  printf '  %-9s %-20s %-11s %s\n' "───" "──────────────────" "─────────" "──────────────────────────────"
  local g last=""
  for g in READ ENFORCE EVIDENCE PATTERN; do
    printf '%s\n' "$ROWS" | awk -F'\t' -v g="$g" '$2==g' | while IFS=$'\t' read -r id grp v cons; do
      [ -n "$id" ] || continue
      case "$v" in
        PRESENT)    mark="✅ PRESENT" ;;
        ABSENT)     mark="❌ ABSENT " ;;
        *)          mark="⚠️  UNMEASURED" ;;
      esac
      printf '  %-9s %-20s %-11s %s\n' "$grp" "$id" "$mark" "$cons"
    done
  done
  echo ""
  echo "  합계: PRESENT $present · ABSENT $absent · UNMEASURED $unmeasured"
  echo "  $(digest_line)"
  echo ""
  if [ "$absent" -eq 0 ] && [ "$unmeasured" -eq 0 ]; then
    echo "  ✅ 이 체크아웃에는 네 층이 다 깔려 있다."
  else
    echo "  ⚠️  층이 빠져 있다 — 이 체크아웃과 다른 체크아웃은 **같은 커밋에 다른 판정**을 낸다."
    echo "     ENFORCE 가 비면 게이트가 «통과»한 게 아니라 **안 돈 것**이고, 출력은 둘 다 무음이다."
    echo "     PATTERN 이 비면 스캔은 돌지만 커버리지가 줄어든 채 초록을 낸다."
    echo "     🟥 UNMEASURED 는 ABSENT 가 아니다 — 못 잰 칸이지 없는 칸이 아니다."
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# --selftest — known-pair. 합성 픽스처 둘로 분리능을 **보인다**(주장하지 않는다).
# ─────────────────────────────────────────────────────────────────────────────
if [ "$MODE" = "selftest" ]; then
  TMP="$(mktemp -d 2>/dev/null)" || { echo "SELFTEST rc=2 — mktemp 실패(계기 오류)"; exit 2; }
  trap 'rm -rf "$TMP"' EXIT
  rc=0

  # known-negative: READ 층만 있고 로컬 층이 전부 빈 허브 = 새 클론
  NEG="$TMP/neg"
  mkdir -p "$NEG/.claude/rules" "$NEG/templates/.git-hooks" "$NEG/scripts" "$NEG/tracks/_meta"
  : > "$NEG/CLAUDE.md"; : > "$NEG/.claude/rules/fh_4axis_gate.md"
  : > "$NEG/templates/.git-hooks/pre-commit"; : > "$NEG/scripts/x.sh"
  probe_hub "$NEG"
  if read_layer_broken; then
    echo "FAIL  selftest: known-negative 픽스처의 READ 층이 깨졌다 — 픽스처 오류"; rc=1
  fi
  neg_absent="$(count_of ABSENT)"
  if [ "$neg_absent" -lt 6 ]; then
    echo "FAIL  selftest: 빈 허브인데 ABSENT 가 $neg_absent 개뿐 — 계기가 부재를 못 본다"; rc=1
  fi
  neg_digest="$(digest_line)"

  # known-positive: 로컬 층을 실제로 채운 허브
  POS="$TMP/pos"
  cp -R "$NEG" "$POS"
  mkdir -p "$POS/.claude/registry"
  : > "$POS/.claude/rules/.public-surface-patterns"
  : > "$POS/.claude/rules/.residency-patterns"
  : > "$POS/.claude/registry/LOCAL_SKILL_REGISTRY.md"
  : > "$POS/CLAUDE.local.md"
  : > "$POS/tracks/_meta/edit_manifest.yaml"
  : > "$POS/tracks/_meta/.axes_23_passed_fixture.marker"
  : > "$POS/tracks/_meta/reference_next_session_starter.md"
  probe_hub "$POS"
  pos_absent="$(count_of ABSENT)"
  if [ "$pos_absent" -ge "$neg_absent" ]; then
    echo "FAIL  selftest: 층을 채웠는데 ABSENT 가 안 줄었다 ($neg_absent → $pos_absent) — 분리 안 됨"; rc=1
  fi
  for k in pattern.psa pattern.localmd evidence.manifest evidence.marker evidence.card; do
    [ "$(verdict_of "$k")" = "PRESENT" ] || { echo "FAIL  selftest: $k 를 만들었는데 PRESENT 가 아니다"; rc=1; }
  done
  pos_digest="$(digest_line)"
  [ "$neg_digest" = "$pos_digest" ] && { echo "FAIL  selftest: 두 픽스처의 digest 가 같다 — 지문이 상태를 안 나른다"; rc=1; }

  # 계기-오류 팔: READ 층이 없는 디렉터리를 겨누면 rc=2 여야 한다
  probe_hub "$TMP/nonexistent-hub"
  read_layer_broken || { echo "FAIL  selftest: 빈 디렉터리를 겨눴는데 READ 층이 깨진 것으로 안 잡힌다"; rc=1; }

  if [ "$rc" -eq 0 ]; then
    echo "SELFTEST PASS — known-pair 분리 확인 (빈 허브 ABSENT $neg_absent → 채운 허브 $pos_absent), 계기-오류 팔 정상"
  fi
  exit "$rc"
fi

# ─────────────────────────────────────────────────────────────────────────────
probe_hub "$FH"

if read_layer_broken; then
  echo "❌ 계기 오류 — READ 층(tracked 자산)이 비어 있다: '$FH' 는 FH 허브가 아니다." >&2
  echo "   드리프트로 보고하지 마라. FH_HUB 를 허브 루트로 겨누고 다시 돌려라." >&2
  exit 2
fi

case "$MODE" in
  digest) digest_line ;;
  tsv)    printf 'id\tlayer\tverdict\tconsequence\n'; printf '%s' "$ROWS" ;;
  *)      emit_table ;;
esac

[ "$(count_of ABSENT)" -eq 0 ] && [ "$(count_of UNMEASURED)" -eq 0 ] && exit 0
exit 1
