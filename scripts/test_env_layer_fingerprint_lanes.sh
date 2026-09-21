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

echo "── $([ "$fail" -eq 0 ] && echo 'all lanes ok' || echo 'FAILURES above') ──"
exit "$fail"
