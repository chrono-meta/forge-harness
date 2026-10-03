#!/usr/bin/env bash
# test_skill_canon_preload_lanes.sh — field_canon_preload.sh 의 «스킬-정본» 분기 앵커.
#
# 이 분기가 존재하는 이유(실측 2026-08-28): 어느 세션이 preprep 의 정본 파일을 **하나도 안
# 열고 44판을 구웠고**, 선 굵기 토큰 위반이 388/907(43%) 났다. 자산이 없어서가 아니라
# **안 읽혀서**다. 훅은 이미 있었고 preprep 이 커버리지 경계 밖이었다.
#
# 재는 것 넷:
#   S1 발화        발표 어휘가 오면 preprep 정본을 띄우나
#   S2 오탐 0      무관한 프롬프트에는 조용한가
#   S3 파일 이름   «정본을 읽어라» 훈계가 아니라 **파일 이름 + 줄 수**를 내나
#                  🟥 이게 없으면 원 훅이 자기 헤더에서 금지한 «일반 훈계»가 된다
#   S4 세션 1회    두 번째 호출은 조용한가 (반복 알림은 무시를 학습시킨다)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$HERE/scripts/field_canon_preload.sh"
PASS=0; FAIL=0
ok(){ echo "  ✅ $1"; PASS=$((PASS+1)); }
ng(){ echo "  ❌ $1"; FAIL=$((FAIL+1)); }
[ -f "$HOOK" ] || { echo "  ❌ INSTRUMENT ERROR — 훅 부재: $HOOK"; exit 1; }

SD=$(mktemp -d); trap 'rm -rf "$SD"' EXIT
# 🟥 `CLAUDE_PROJECT_DIR` 을 «반드시» 준다. 안 주면 훅이 `$HOME/projects/forge-harness` 로
#    떨어지는데 CI 러너엔 그 경로가 없어 **조용히 침묵**한다 — 로컬 4/4 · CI 2/4 가 그렇게 났다.
#    S2·S4 는 아무것도 안 나와도 통과하는 검사라, 그 조합이 «훅이 통째로 안 돈다»의 서명이다.
run(){ rm -rf "$SD/s"; mkdir -p "$SD/s"
       CLAUDE_PROJECT_DIR="$HERE" FIELD_CANON_SENTINEL_DIR="$SD/s" bash "$HOOK" <<EOF 2>&1
{"prompt":"$1"}
EOF
}

pos=$(run "발표 자료 만들어줘")
neg=$(run "오늘 날씨 어때")
echo "$pos" | grep -q "skill-canon" && ok "S1 발화: 발표 어휘 → preprep 정본 안내" \
                                    || ng "S1 미발화 — 배선 안 된 코드는 산문이다"
# 🟥 S0 먼저 — «훅이 아예 안 돈다» 를 S2·S4 가 조용히 통과시키는 구멍을 막는다.
#    둘은 «아무 출력도 없음» 에서도 초록이라, 그 조합만으로는 침묵과 정상을 못 가른다.
[ -n "$pos" ] && ok "S0 훅이 출력을 냈다 (침묵을 통과로 안 읽는다)" \
              || ng "S0 훅이 아무것도 안 냈다 — 환경(CLAUDE_PROJECT_DIR)이나 배선을 봐라"
echo "$neg" | grep -q "skill-canon" && ng "S2 오탐: 무관한 프롬프트에도 뜬다" \
                                    || ok "S2 오탐 0"
echo "$pos" | grep -qE "presentation_checklist\.md \([0-9]+줄\)" \
  && ok "S3 파일 이름 + 줄 수를 낸다 (일반 훈계가 아니다)" \
  || ng "S3 실패 — 파일을 안 짚으면 «정본을 읽어라» 훈계이고, 그건 이 훅이 금지한 형태다"

rm -rf "$SD/t"; mkdir -p "$SD/t"
CLAUDE_PROJECT_DIR="$HERE" FIELD_CANON_SENTINEL_DIR="$SD/t" bash "$HOOK" <<'EOF' >/dev/null 2>&1
{"prompt":"발표 준비"}
EOF
again=$(CLAUDE_PROJECT_DIR="$HERE" FIELD_CANON_SENTINEL_DIR="$SD/t" bash "$HOOK" <<'EOF' 2>&1
{"prompt":"발표 준비"}
EOF
)
echo "$again" | grep -q "skill-canon" && ng "S4 재나그: 두 번째도 뜬다 — 무시를 학습시킨다" \
                                      || ok "S4 세션당 1회"

# ── S5~S9 (2026-10-03, 2라운드 갱신) — 부분 일치 오탐: «덱」⊂«코덱스」 실측 ──────────────────
# 처방은 «알려진 오탐 낱말을 지운 뒤 bash 부분 일치」다(1라운드 python 왼쪽 경계는 버렸다 — 훅 주석).
# 🟥 양성은 «덱」을 **고립**시킨다 — 다른 트리거(발표·슬라이드·장표…)가 없는 문장만 쓴다. «발표 덱
#    만들자」는 «발표」가 먼저 맞아 «덱」 판정을 못 잰다(agy C 지목, 1라운드 레인이 그 형태였다).
# 🟥 `run … | grep -q` 로 쓰지 마라 — pipefail 아래서 grep -q 가 첫 일치에 파이프를 닫으면 훅이
#    SIGPIPE(141)로 죽고 파이프라인 전체가 «실패」가 된다. 즉 **양성일수록 빨갛게** 나온다(1라운드에
#    이 레인을 처음 쓸 때 실측: 양성 7개가 전부 ❌). 출력을 먼저 받아 두고 그걸 grep 한다.
# 3라운드: «덱스」 지우기가 죽였던 합성어 셋(피치덱스토리라인 · 투자덱스타일 · IR덱스케치)을 양성에 추가.
for _p in "덱 다듬어줘" "이 덱 순서 바꾸자" "(덱) 마지막 장" "투자덱 검토" "IR덱 봐줘" "A덱 순서" "제안덱 초안" "피치덱 봐줘" "피치덱스토리라인 잡자" "투자덱스타일 통일" "IR덱스케치 보자" "Keynote 파일 열어" "the PRESENTATION is tomorrow"; do
  _o=$(run "$_p"); printf '%s\n' "$_o" | grep -q "skill-canon" && ok "S5 양성: «${_p}」 → 발화" \
                                    || ng "S5 미발화: «${_p}」 — 오탐 지우기가 진짜 덱까지 죽였다"
done
# 명명된 잔여(3라운드): «덱스터」 같은 «덱」으로 시작하는 다른 낱말은 뜬다 — 관측 0 이라 목록에 없다.
for _p in "코덱스처럼 해줘" "인덱스 다시 빌드" "코덱 설정 바꿔" "knowledge representation 정리" "Knowledge REPRESENTATION"; do
  _o=$(run "$_p"); printf '%s\n' "$_o" | grep -q "skill-canon" && ng "S6 오탐: «${_p}」 에도 «발표 작업이 언급됐다」가 뜬다" \
                                    || ok "S6 음성: «${_p}」 → 조용"
done
# S7 control — S6 의 «조용」이 훅이 죽어서가 아님을 같은 실행 경로에서 보인다(같은 run 함수,
#    같은 환경, 프롬프트만 다름). 이게 없으면 S6 은 «훅 사망」에서도 초록이다.
_c=$(run "코덱스처럼 해줘, 그리고 덱 다듬어줘")
echo "$_c" | grep -q "skill-canon" && ok "S7 control: 같은 문장에 진짜 «덱」이 있으면 뜬다 (S6 의 침묵은 지우기 덕이다)" \
                                   || ng "S7 control 실패 — S6 의 «조용」이 지우기 덕인지 사망 덕인지 못 가른다"

# S8 python3 부재 — 판정이 python 에 기대지 않는다(1라운드는 python 실패 시 부분 일치로 폴백해
#    «코덱스」 오탐이 되살아났다 — codex·agy 지목). PATH 에서 python3 만 뺀 심으로 잰다.
#    python 이 없으면 페이로드 파싱도 실패해 프롬프트=원문 JSON 이 되지만, 판정은 그대로여야 한다.
SHIM="$SD/shim"; mkdir -p "$SHIM"
for d in $(printf '%s' "$PATH" | tr ':' ' '); do
  [ -d "$d" ] || continue
  for b in "$d"/*; do [ -e "$b" ] || continue; n="$(basename "$b")"; case "$n" in python3|python3.*) continue;; esac; [ -e "$SHIM/$n" ] || ln -s "$b" "$SHIM/$n" 2>/dev/null; done  # portability-noqa: the [ -e "$b" ] || continue guard is on this same line
done
if PATH="$SHIM" command -v python3 >/dev/null 2>&1; then
  ng "S8 CONTROL: 심 PATH 에 python3 가 남아 있다 — 레인 무효"
else
  ok "S8 CONTROL: 심 PATH 에 python3 가 없다"
  _fb=$(rm -rf "$SD/s"; mkdir -p "$SD/s"; printf '{"prompt":"투자덱 검토"}\n' | PATH="$SHIM" CLAUDE_PROJECT_DIR="$HERE" FIELD_CANON_SENTINEL_DIR="$SD/s" "$SHIM/bash" "$HOOK" 2>&1)
  echo "$_fb" | grep -q "skill-canon" && ok "S8 python 부재 + 진짜 «덱」 → 뜬다" \
                                      || ng "S8 python 부재에서 «덱」이 침묵"
  _fn=$(rm -rf "$SD/s"; mkdir -p "$SD/s"; printf '{"prompt":"코덱스처럼"}\n' | PATH="$SHIM" CLAUDE_PROJECT_DIR="$HERE" FIELD_CANON_SENTINEL_DIR="$SD/s" "$SHIM/bash" "$HOOK" 2>&1)
  echo "$_fn" | grep -q "skill-canon" && ng "S8 python 부재에서 «코덱스」 오탐이 되살아났다 (1라운드 결함)" \
                                      || ok "S8 python 부재 + «코덱스」 → 조용 (판정이 python 에 기대지 않는다)"
fi

# S9 긴 여러 줄 프롬프트 — 1라운드 폴백 `printf | grep -q` 는 첫 줄 일치 뒤 SIGPIPE(141)로 진짜 트리거를
#    놓쳤다(codex 재현: «덱\n」 + x 1,000,000). 픽스처는 파일로 만들고 훅에 리다이렉트한다(레인 쪽 파이프도 없앤다).
_big="$SD/big.json"
python3 -c 'import json,sys; sys.stdout.write(json.dumps({"prompt":"덱 다듬어줘\n"+"x"*1000000}))' > "$_big" 2>/dev/null
if [ -s "$_big" ]; then
  ok "S9 CONTROL: 1MB 여러 줄 픽스처를 만들었다"
  _bo=$(rm -rf "$SD/s"; mkdir -p "$SD/s"; CLAUDE_PROJECT_DIR="$HERE" FIELD_CANON_SENTINEL_DIR="$SD/s" bash "$HOOK" < "$_big" 2>&1)
  case "$_bo" in *skill-canon*) ok "S9 긴 여러 줄 프롬프트 첫 줄의 «덱」 → 발화 (SIGPIPE 로 놓치지 않는다)" ;;
    *) ng "S9 긴 여러 줄 프롬프트에서 진짜 «덱」을 놓쳤다" ;; esac
else
  ng "S9 CONTROL: 픽스처 생성 실패 — 레인 무효"
fi

# S10 상한 — 앞 16,384 자 뒤에만 있는 트리거는 **안 본다**(사양: 무해한 미탐). 같은 픽스처에서 트리거를
#     앞으로 옮기면 뜨는 컨트롤을 둔다(«안 뜸」이 상한 덕임을 가른다).
_cap_tail="$SD/cap_tail.json"; _cap_head="$SD/cap_head.json"
python3 -c 'import json,sys; sys.stdout.write(json.dumps({"prompt":"가"*17000+" 덱 다듬어줘"}))' > "$_cap_tail" 2>/dev/null
python3 -c 'import json,sys; sys.stdout.write(json.dumps({"prompt":"덱 다듬어줘 "+"가"*17000}))' > "$_cap_head" 2>/dev/null
_ct=$(rm -rf "$SD/s"; mkdir -p "$SD/s"; CLAUDE_PROJECT_DIR="$HERE" FIELD_CANON_SENTINEL_DIR="$SD/s" bash "$HOOK" < "$_cap_tail" 2>&1)
_ch=$(rm -rf "$SD/s"; mkdir -p "$SD/s"; CLAUDE_PROJECT_DIR="$HERE" FIELD_CANON_SENTINEL_DIR="$SD/s" bash "$HOOK" < "$_cap_head" 2>&1)
case "$_ch" in *skill-canon*) ok "S10 CONTROL: 같은 길이·같은 낱말을 앞에 두면 뜬다" ;; *) ng "S10 CONTROL 실패 — 아래 «안 뜸」은 증거가 아니다" ;; esac
case "$_ct" in *skill-canon*) ng "S10 상한 뒤(17,000자 뒤)의 «덱」에 떴다 — 상한이 안 걸렸다" ;; *) ok "S10 상한 뒤의 «덱」은 안 본다 (사양 — 무해한 미탐)" ;; esac

# S11 시간 상한 — 오탐 낱말 반복 1MB(«코덱스 」×100,000) 도 훅이 넉넉한 상한 안에 끝난다.
#     2라운드 bash 치환은 이 입력에서 8초를 넘겼다(codex 실측). 상한 3초는 병렬 부하 깜빡임을 피하려고
#     넉넉하게 잡았다(수리 후 실측은 출력에 찍는다). 넘으면 죽이고 실패로 센다(무한 대기 금지).
_rep="$SD/rep.json"
python3 -c 'import json,sys; sys.stdout.write(json.dumps({"prompt":"코덱스 "*100000}))' > "$_rep" 2>/dev/null
_t=$(rm -rf "$SD/s"; mkdir -p "$SD/s"; python3 - "$HOOK" "$_rep" "$HERE" "$SD/s" <<'PYT' 2>&1
import os, subprocess, sys, time
hook, fx, here, sd = sys.argv[1:5]
env = dict(os.environ, CLAUDE_PROJECT_DIR=here, FIELD_CANON_SENTINEL_DIR=sd)
t0 = time.time()
try:
    r = subprocess.run(["bash", hook], stdin=open(fx, "rb"), env=env, capture_output=True, timeout=3.0)
    out = r.stdout.decode("utf-8", "replace")
    # rc 도 본다(4라운드, codex C): 훅이 죽어서 조용한 것과 판정해서 조용한 것을 가른다.
    print("%.2f rc=%d %s" % (time.time() - t0, r.returncode, "FIRED" if "skill-canon" in out else "QUIET"))
except subprocess.TimeoutExpired:
    print("TIMEOUT")
PYT
)
case "$_t" in
  TIMEOUT*) ng "S11 1MB 반복 오탐 입력이 3초 안에 안 끝났다 — 훅이 프롬프트마다 이만큼 막힌다" ;;
  *" rc=0 QUIET") ok "S11 1MB 반복 오탐 입력: ${_t% rc=0 QUIET}초 (상한 3초) · rc=0 · 조용 (오탐 0)" ;;
  *" QUIET") ng "S11 조용했지만 훅 rc≠0 — 판정이 아니라 사망으로 조용했다 (${_t})" ;;
  *" FIRED") ng "S11 시간은 지켰지만 «코덱스」 반복에 발표 안내가 떴다 (${_t})" ;;
  *) ng "S11 계기 오류 — 출력=[${_t}]" ;;
esac

# S10b 상한은 **바이트, 로케일 무관**(4라운드, agy B). 세 경계 픽스처를 UTF-8 · C 두 로케일로 돌린다.
#     ⓐ «덱」(3바이트)이 16,384 바이트에서 정확히 끝남 → 뜬다
#     ⓑ «덱」이 경계에 걸침(앞 2바이트만 창 안) → 안 뜬다 (3라운드 문자 상한이면 UTF-8 에서 떴다 — 되돌림 앵커)
#     ⓒ 앞쪽 «덱」 + 경계에서 한글이 갈림(끝에 잘린 바이트) → 뜬다 (잘린 끝 바이트가 일치를 안 깬다)
python3 - "$SD" <<'PYB' 2>/dev/null
import json, sys
sd = sys.argv[1]
cap = 16384
deck = "덱".encode()
def w(name, b):
    open(f"{sd}/{name}.json", "w").write(json.dumps({"prompt": b.decode("utf-8")}))
w("b_exact", b"a" * (cap - 3) + deck)                 # 덱 ends exactly at the cap
w("b_straddle", b"a" * (cap - 2) + deck)              # only 2 of 3 bytes inside
head = "덱 다듬어줘 ".encode()
pad = cap - len(head) - 1                             # then a 3-byte char cut after its first byte
w("b_partial", head + b"a" * pad + "가가".encode())
PYB
for _loc in en_US.UTF-8 C; do
  for _fx in b_exact:FIRE b_straddle:QUIET b_partial:FIRE; do
    _f="${_fx%%:*}"; _want="${_fx##*:}"
    _o=$(rm -rf "$SD/s"; mkdir -p "$SD/s"; LC_ALL="$_loc" LANG="$_loc" CLAUDE_PROJECT_DIR="$HERE" FIELD_CANON_SENTINEL_DIR="$SD/s" bash "$HOOK" < "$SD/$_f.json" 2>&1)
    case "$_o" in *skill-canon*) _got=FIRE ;; *) _got=QUIET ;; esac
    [ "$_got" = "$_want" ] && ok "S10b ${_loc} ${_f}: ${_got}" || ng "S10b ${_loc} ${_f}: 기대 ${_want}, 실제 ${_got}"
  done
done

# S13 오탐 낱말도 소문자화된다(4라운드, agy B). 훅 사본의 목록에 대문자 낱말 «XPRESENTATIONX」를 넣고,
#     «an xpresentationx thing」 이 조용한지 본다(안 지워지면 «presentation」 트리거가 뜬다).
#     컨트롤: 같은 사본에서 «the presentation」 은 뜬다.
_h13d="$SD/h13"; mkdir -p "$_h13d"; cp "$(dirname "$HOOK")/fh_track_resolve.sh" "$_h13d/" 2>/dev/null
sed 's/^  "representation"  #/  "XPRESENTATIONX"\n  "representation"  #/' "$HOOK" > "$_h13d/field_canon_preload.sh"
if grep -q '^  "XPRESENTATIONX"' "$_h13d/field_canon_preload.sh"; then
  ok "S13 CONTROL: 사본 목록에 대문자 낱말이 들어갔다"
  _a=$(rm -rf "$SD/s"; mkdir -p "$SD/s"; printf '{"prompt":"an xpresentationx thing"}' | CLAUDE_PROJECT_DIR="$HERE" FIELD_CANON_SENTINEL_DIR="$SD/s" bash "$_h13d/field_canon_preload.sh" 2>&1)
  _c=$(rm -rf "$SD/s"; mkdir -p "$SD/s"; printf '{"prompt":"the presentation"}' | CLAUDE_PROJECT_DIR="$HERE" FIELD_CANON_SENTINEL_DIR="$SD/s" bash "$_h13d/field_canon_preload.sh" 2>&1)
  case "$_a" in *skill-canon*) ng "S13 대문자로 등록된 오탐 낱말이 안 지워졌다" ;; *) ok "S13 대문자로 등록된 오탐 낱말도 지워진다" ;; esac
  case "$_c" in *skill-canon*) ok "S13 CONTROL: 같은 사본에서 진짜 트리거는 뜬다" ;; *) ng "S13 CONTROL 실패 — 사본이 안 돈다" ;; esac
else
  ng "S13 CONTROL: 사본 수정 실패 — 레인 무효"
fi

# S12 빈 트리거 — `*""*` 는 모든 문자열에 맞는다. 훅 사본의 트리거 목록에 빈 칸을 끼우고, 무관한
#     프롬프트에 안 뜨는지 본다. 컨트롤: 같은 사본에서 진짜 트리거는 뜬다.
_hc="$SD/hook_empty.sh"
sed 's/^  "발표" "장표"/  "" "발표" "장표"/' "$HOOK" > "$_hc"
if grep -q '^  "" "발표" "장표"' "$_hc"; then
  ok "S12 CONTROL: 사본 트리거 목록에 빈 칸이 들어갔다"
  _e1=$(rm -rf "$SD/s"; mkdir -p "$SD/s"; printf '{"prompt":"오늘 날씨 어때"}' | CLAUDE_PROJECT_DIR="$HERE" FIELD_CANON_SENTINEL_DIR="$SD/s" bash "$_hc" 2>&1)
  _e2=$(rm -rf "$SD/s"; mkdir -p "$SD/s"; printf '{"prompt":"발표 준비"}' | CLAUDE_PROJECT_DIR="$HERE" FIELD_CANON_SENTINEL_DIR="$SD/s" bash "$_hc" 2>&1)
  case "$_e1" in *skill-canon*) ng "S12 빈 트리거가 무관한 프롬프트에 걸렸다" ;; *) ok "S12 빈 트리거는 아무 프롬프트에도 안 걸린다" ;; esac
  case "$_e2" in *skill-canon*) ok "S12 CONTROL: 같은 사본에서 진짜 트리거는 뜬다" ;; *) ng "S12 CONTROL 실패 — 사본이 안 돈다" ;; esac
else
  ng "S12 CONTROL: 사본 수정 실패 — 레인 무효"
fi

echo "skill-canon lanes: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
