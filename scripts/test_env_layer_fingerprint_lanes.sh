#!/usr/bin/env bash
# test_env_layer_fingerprint_lanes.sh — scripts/env_layer_fingerprint.sh 의 앵커.
#
# 이 계기가 주장하는 것은 «두 체크아웃을 대조할 수 있다» 하나다. 그러니 레인이 박아야 하는 것도
# 그 하나다: **층이 있고 없음에 따라 판정과 지문이 실제로 갈리는가.** 「돌긴 돈다」는 앵커가 아니다.
#
# 🟥 계기-오류 팔(L6)이 이 묶음의 핵심이다 — 허브가 아닌 곳을 겨누면 «드리프트 11건»이 아니라
#    rc=2 가 나와야 한다. 그 팔이 없으면 이 계기의 가장 그럴듯한 실패(엉뚱한 cwd 에서 전부
#    ABSENT 를 찍고 보고)가 초록으로 지나간다.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
S=scripts/env_layer_fingerprint.sh
fail=0
_t() { printf '  %-58s' "$1"; }
_ok() { echo "ok"; }
_no() { echo "FAIL — $1"; fail=1; }

echo "── env-layer-fingerprint lanes ──"

[ -x "$S" ] || { echo "FAIL  $S 가 없거나 실행 불가"; exit 1; }

TMP="$(mktemp -d)" || exit 2
trap 'rm -rf "$TMP"' EXIT

mk_hub() {  # mk_hub DIR [full] — READ 층만(=새 클론) 또는 로컬 층까지 채운 허브
  local d="$1"
  mkdir -p "$d/.claude/rules" "$d/.claude/registry" "$d/templates/.git-hooks" "$d/scripts" "$d/tracks/_meta"
  : > "$d/CLAUDE.md"; : > "$d/.claude/rules/fh_4axis_gate.md"
  : > "$d/templates/.git-hooks/pre-commit"; : > "$d/scripts/x.sh"
  git -C "$d" init -q 2>/dev/null
  if [ "${2:-}" = full ]; then
    : > "$d/.claude/rules/.public-surface-patterns"
    : > "$d/.claude/rules/.residency-patterns"
    : > "$d/.claude/registry/LOCAL_SKILL_REGISTRY.md"
    : > "$d/CLAUDE.local.md"
    : > "$d/tracks/_meta/edit_manifest.yaml"
    : > "$d/tracks/_meta/.axes_23_passed_fixture.marker"
    : > "$d/tracks/_meta/reference_next_session_starter.md"
    : > "$d/tracks/_meta/session_fixture.md"
  fi
}

# L1 — 스크립트가 자기 known-pair 를 통과한다 (계기가 교정돼 있나)
_t "L1 selftest (known-pair 분리능)"
if bash "$S" --selftest >/dev/null 2>&1; then _ok; else _no "selftest 실패 — 계기가 교정 안 됨"; fi

# L2 — known-negative: 새 클론 모양이면 ENFORCE·PATTERN 이 ABSENT 이고 rc=1
mk_hub "$TMP/bare"
_t "L2 새 클론 → 로컬 층 ABSENT, rc=1"
out="$(FH_HUB="$TMP/bare" bash "$S" --tsv 2>/dev/null)"; rc=$?
if [ "$rc" -eq 1 ] \
   && printf '%s' "$out" | grep -q '^pattern.psa	PATTERN	ABSENT' \
   && printf '%s' "$out" | grep -q '^hook.pre-commit	ENFORCE	ABSENT'; then _ok
else _no "rc=$rc 이거나 ABSENT 판정이 안 나옴"; fi

# L3 — known-positive: 로컬 층을 채우면 그 칸들이 PRESENT 로 뒤집힌다
mk_hub "$TMP/full" full
_t "L3 로컬 층 채움 → 같은 칸이 PRESENT 로 뒤집힘"
out="$(FH_HUB="$TMP/full" bash "$S" --tsv 2>/dev/null)"
if printf '%s' "$out" | grep -q '^pattern.psa	PATTERN	PRESENT' \
   && printf '%s' "$out" | grep -q '^evidence.marker	EVIDENCE	PRESENT' \
   && printf '%s' "$out" | grep -q '^evidence.card	EVIDENCE	PRESENT'; then _ok
else _no "층을 만들었는데 PRESENT 로 안 바뀜 — 분리 안 됨"; fi

# L4 — 지문이 상태를 나른다: 두 픽스처의 digest 가 달라야 한다
_t "L4 digest 가 두 상태를 구분한다"
d1="$(FH_HUB="$TMP/bare" bash "$S" --digest 2>/dev/null)"
d2="$(FH_HUB="$TMP/full" bash "$S" --digest 2>/dev/null)"
if [ -n "$d1" ] && [ -n "$d2" ] && [ "$d1" != "$d2" ]; then _ok
else _no "digest 가 같거나 비었다 — 대조에 못 쓴다"; fi

# L5 — 값 유출 금지: 출력에 파일 «내용»이 실리면 안 된다 (PR·스레드에 붙이는 산출물이다)
_t "L5 출력에 파일 내용이 안 실린다"
printf 'SECRET_TOKEN_DO_NOT_LEAK\n' > "$TMP/full/.claude/rules/.public-surface-patterns"
printf 'ANOTHER_SECRET_LITERAL\n' > "$TMP/full/CLAUDE.local.md"
out="$(FH_HUB="$TMP/full" bash "$S" 2>&1; FH_HUB="$TMP/full" bash "$S" --digest 2>&1; FH_HUB="$TMP/full" bash "$S" --tsv 2>&1)"
if printf '%s' "$out" | grep -q 'SECRET_TOKEN_DO_NOT_LEAK\|ANOTHER_SECRET_LITERAL'; then
  _no "gitignored 파일의 내용이 출력에 실렸다 — 유출"
else _ok; fi

# L6 — 계기-오류 팔: 허브가 아닌 곳을 겨누면 rc=2 (드리프트로 보고하면 안 된다)
_t "L6 허브 아닌 곳 → rc=2 (드리프트 아님)"
mkdir -p "$TMP/nothub"
FH_HUB="$TMP/nothub" bash "$S" >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 2 ]; then _ok; else _no "rc=$rc — 엉뚱한 디렉터리를 드리프트로 보고한다"; fi

# L7 — 되돌림 프로브: READ 행 하나를 지우면 L6 과 같은 계기-오류로 떨어져야 한다
#      («이 판정이 정말 READ 층을 보고 나오나»를 보이는 팔 — 없으면 L6 이 우연히 맞을 수 있다)
_t "L7 되돌림 — READ 자산 삭제 시 rc=2 로 전환"
rm -f "$TMP/full/CLAUDE.md"
FH_HUB="$TMP/full" bash "$S" >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 2 ]; then _ok; else _no "rc=$rc — READ 층 무결성이 판정에 안 걸려 있다"; fi

# L8 — tracked 파일 FP 앵커: tracks/ 에 **tracked** 파일만 있으면 evidence.tracks 는 ABSENT.
#      (2026-08-30 온보딩 분기 FP 와 같은 클래스 — 동봉 파일을 «기록 있음»으로 읽으면 안 된다)
_t "L8 tracked-only tracks/ → evidence.tracks ABSENT"
mk_hub "$TMP/tracked"
mkdir -p "$TMP/tracked/tracks/_contrib"
: > "$TMP/tracked/tracks/_contrib/shipped.md"
git -C "$TMP/tracked" add -A >/dev/null 2>&1
out="$(FH_HUB="$TMP/tracked" bash "$S" --tsv 2>/dev/null)"
if printf '%s' "$out" | grep -q '^evidence.tracks	EVIDENCE	ABSENT'; then _ok
else _no "동봉된 tracked 파일을 세션 기록으로 읽는다 — FP"; fi

# ── L9 — 지문은 셸 소스를 담지 않는다. **설치된 모든 bash 에서** ─────────────────────────
#   실사고 2026-09-21: `$(case … esac)` 가 bash 3.2(macOS 기본 /bin/bash)에서 런타임에 깨져
#   값 자리로 셸 소스가 새어 들어갔고, **rc=0 으로 끝났다.** 같은 커밋이 맥에서 fa28bfdfb139,
#   컨테이너(5.3)에서 ab16518d1dc4 — 즉 이 계기가 존재 이유인 지문 대조에서 **없는 드리프트를
#   만든다.** 종료코드로는 안 잡히므로 **내용**을 본다. bash 판본마다 따로 돈다: 한 판본만
#   돌리면 그 판본에서만 나는 결함이 구조적으로 안 보인다(그게 이 사고의 형태였다).
for _b in /bin/bash /opt/homebrew/bin/bash /usr/local/bin/bash; do
  [ -x "$_b" ] || continue
  _bv="$("$_b" -c 'echo "${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}"' 2>/dev/null)"
  _t "L9 모든 층 상태가 닫힌 집합 안 (bash $_bv)"
  #   🟥 «셸 소스처럼 보이는 낱말»을 금지어로 세지 않는다 — 금지어 목록은 미래의 정당한 문구에
  #      오탐하고, 새어 나오는 형태가 바뀌면 조용히 놓친다. 대신 **긍정 단언**을 한다:
  #      모든 행의 상태 칸은 PRESENT·ABSENT·UNMEASURED 셋 중 하나여야 한다. 셸 소스가 값 자리로
  #      들어오면 그 집합 밖이라 반드시 걸린다.
  _tsv="$("$_b" "$S" --tsv 2>/dev/null)"
  if [ -z "$_tsv" ]; then
    _no "bash $_bv 에서 --tsv 가 비었다 — 판정 불가(계기 오류)"
  else
    # 첫 행은 헤더(`id / layer / verdict`)다 — 상태 칸이 아니므로 제외한다. 안 빼면
    # 깨끗한 트리가 영원히 빨간, 그냥 과차단이다(초판이 그렇게 틀렸다).
    _bad="$(printf '%s\n' "$_tsv" | awk -F'\t' 'NR>1 && NF>=3 && $3!="PRESENT" && $3!="ABSENT" && $3!="UNMEASURED" {print $1"="$3}')"
    _rows="$(printf '%s\n' "$_tsv" | awk -F'\t' 'NR>1 && NF>=3' | grep -c . || true)"
    if [ "${_rows:-0}" -lt 10 ]; then
      _no "bash $_bv 에서 행이 $_rows 개뿐 — 층 표가 깨졌다(계기 오류)"
    elif [ -n "$_bad" ]; then
      _no "bash $_bv 상태 칸이 닫힌 집합 밖: $(printf '%s' "$_bad" | head -2 | tr '\n' ' ')"
    else
      _ok
    fi
  fi
done

# ── L9b — 되돌림 프로브: 깨지는 형태를 되돌리면 L9 이 실제로 빨개지나 ──────────────────
#   L9 이 «어떤 이유로든 초록»이 되는 것을 막는 팔이다. bash 3.x 가 없는 환경(리눅스 CI)에서는
#   이 결함을 재현할 수 없으므로 **UNMEASURED 로 말하고 통과시킨다** — 「못 쟀다」를 「깨끗하다」로
#   접지 않는다(부재≠0). 3.x 가 있으면 반드시 적색이어야 한다.
#   🟥 **이름으로 남기는 잔여 (cross-family 지적, 2026-09-21)**: 그래서 이 회귀 팔의 강제력은
#      **bash 3.x 가 있는 호스트에만** 있다. CI 는 리눅스/bash 5 라 L9b 가 거기서 영원히
#      UNMEASURED 이고, L9 도 그 호스트에서는 애초에 안 깨지는 판본만 잰다. 즉 이 결함 클래스의
#      실질 게이트는 **운영자 맥의 로컬 실행**이지 CI 가 아니다. 닫으려면 CI 에 macOS 잡이나
#      bash-3 컨테이너가 필요하고, 그건 이 PR 범위 밖이라 안 했다.
_t "L9b 되돌림 — \$(case) 복원 시 bash 3.x 에서 적색"
_B3=""
for _b in /bin/bash /usr/bin/bash; do
  [ -x "$_b" ] || continue
  [ "$("$_b" -c 'echo ${BASH_VERSINFO[0]}' 2>/dev/null)" = "3" ] && { _B3="$_b"; break; }
done
if [ -z "$_B3" ]; then
  echo "UNMEASURED — bash 3.x 없음(이 결함은 여기서 재현 불가). PASS 아님"
else
  MUT="$TMP/mutant.sh"
  python3 - "$S" "$MUT" <<'PY'
import io,sys,re
src=io.open(sys.argv[1],encoding='utf-8').read()
new,_n=re.subn(
  r'  local _tracks_state\n  case "\$untracked_tracks" in\n.*?\n  esac\n'
  r'  add_row evidence\.tracks EVIDENCE "\$_tracks_state" \\\n',
  '  add_row evidence.tracks EVIDENCE \\\\\n'
  '    "$(case "$untracked_tracks" in\n'
  "         UNMEASURABLE) printf 'UNMEASURED' ;;\n"
  "         0) printf 'ABSENT' ;;\n"
  "         *) printf 'PRESENT' ;;\n"
  '       esac)" \\\n',
  src, flags=re.S)
# 🟥 치환이 «정확히 한 번» 일어났는지 못박는다. 횟수를 안 보면, 형식이 조금 바뀌어 정규식이
#    빗나가도 원본이 그대로 뮤턴트로 복사되고 레인은 엉뚱한 산출물을 잰다.
if _n != 1:
    sys.stderr.write("SUBN=%d\n" % _n); sys.exit(3)
io.open(sys.argv[2],'w',encoding='utf-8').write(new)
PY
  _mutrc=$?
  if [ "$_mutrc" -ne 0 ]; then
    _no "계기 오류 — 뮤턴트 치환이 정확히 1회가 아니었다(rc=$_mutrc). 이 팔은 공허했을 것"
  elif ! grep -q '\$(case' "$MUT" 2>/dev/null; then
    _no "계기 오류 — 뮤턴트에 \$(case) 가 안 들어갔다. 이 팔은 공허하게 통과했을 것"
  elif ! "$_B3" -n "$MUT" 2>/dev/null; then
    _no "계기 오류 — 뮤턴트가 파싱조차 안 된다. 그 침묵은 아무 뜻이 없다"
  else
    # L9 과 **같은 판정식**을 쓴다 — 프로브가 다른 잣대로 재면 L9 을 앵커한 게 아니다.
    _tm="$("$_B3" "$MUT" --tsv 2>/dev/null)"
    _badm="$(printf '%s\n' "$_tm" | awk -F'\t' 'NR>1 && NF>=3 && $3!="PRESENT" && $3!="ABSENT" && $3!="UNMEASURED" {print $1}')"
    if [ -n "$_badm" ]; then _ok
    else _no "뮤턴트가 닫힌 집합 안의 상태만 냈다 — L9 이 이 결함에 결박돼 있지 않다"; fi
  fi
fi

echo "── $([ "$fail" -eq 0 ] && echo 'all lanes ok' || echo 'FAILURES above') ──"
exit "$fail"
