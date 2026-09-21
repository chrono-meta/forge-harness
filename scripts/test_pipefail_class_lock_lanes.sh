#!/usr/bin/env bash
# test_pipefail_class_lock_lanes.sh — «생산자 | 조기종료 소비자» 를 **클래스로** 잠근다.
#
# 왜 이 파일이 따로 있나: PR #785 는 실사고 한 자리(`sync_to_be_lanes.sh:579`)를 고치고
# `test_pipefail_sigpipe_lanes.sh` 로 **그 자리**를 지켰다. 그 레인은 새로 들어오는 같은 형태를
# 구조적으로 못 본다. 같은 날 이 레포에서 **손 열거가 세 번 놓쳤다**(브래킷 린트 11중 1 ·
# #784 의 8→9 · #785 자신의 전수표). ⇒ 잠금은 «목록» 이 아니라 **«0 곳인가»** 여야 한다.
# 본보기 = `test_locale_invariance_lanes.sh` 의 L14f.
#
# 🟥 잠금이 걸리는 자리는 «레포 전체 0» 이 아니라 **«이 변경이 새 사례를 들여오는가 = 0»** 이다.
#    레포는 오늘 VULN>0 이고(L9 가 그 수를 출력한다), 만족 불가능한 요구를 게이트로 걸면
#    override 를 훈련시킨다(CLAUDE.md §Mechanization Boundary). 기존 부채는 거버너가 별건으로 다룬다.
#
# 🟥 이 파일은 **탐지만** 검증한다. 찾은 취약형을 고치는 것은 별 커밋이다 — 한 커밋에 탐지와
#    수리를 섞으면 레인이 자기 수리를 못 본다([[feedback_lane_vocabulary_blind_to_its_own_fix]]).
set -uo pipefail
export LC_ALL=C
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
SCAN="$REPO/scripts/pipefail_earlyexit_scan.sh"
PASS=0; FAIL=0; UNMEASURED=0
ok(){ PASS=$((PASS+1)); printf '  ✅ %s\n' "$1"; }
no(){ FAIL=$((FAIL+1)); printf '  ❌ %s — %s\n' "$1" "${2:-}"; }
um(){ UNMEASURED=$((UNMEASURED+1)); printf '  ⬜ %s — %s\n' "$1" "${2:-}"; }
echo "── test_pipefail_class_lock_lanes ──"
D="$(mktemp -d)"; trap '/bin/rm -rf "$D"' EXIT
[ -x "$SCAN" ] || { no "L-pre 스캐너 부재" "$SCAN"; echo "PASS=$PASS FAIL=$FAIL"; exit 1; }

# 픽스처: 매치 1 행 + 이후 ~300 KB. 64 KiB 버퍼에 못 들어가므로 생산자는 **반드시** 블록된다.
# 확률 레인은 그 자신이 flaky 가 되므로 쓰지 않는다.
{ echo "NEEDLE"; head -c 300000 /dev/zero | tr '\0' 'x' | fold -w 100; } > "$D/over.txt"
{ echo "NEEDLE"; echo small; } > "$D/under.txt"
_sz(){ wc -c < "$1" | tr -d ' '; }
[ "$(_sz "$D/over.txt")" -gt 65536 ] \
  && ok "L0 픽스처가 파이프 버퍼(65536 B)를 넘는다 ($(_sz "$D/over.txt") B)" \
  || no "L0 픽스처" "$(_sz "$D/over.txt") B — 안 넘으면 아래 known-positive 가 뜨지 않는다"

# ── L1 런타임 known-POSITIVE — 🟥 «뚫리는 표기» 로 짓는다 ────────────────────────
# 조기종료 소비자는 `grep -q` 하나가 아니다. 가장 쉬운 표기만 잡는 스캐너는 나머지를 못 잡으므로,
# 먼저 «어느 표기가 실제로 뒤집히나» 를 런타임으로 확정하고 그 목록을 정적 스캔에 요구한다.
_flip(){ local n=0 i; for i in 1 2 3 4 5; do ( set -uo pipefail; eval "$1" ) >/dev/null 2>&1 || n=$((n+1)); done; echo "$n"; }
_pos_forms=(
  'sed -n "1,\$p" "$D/over.txt" | grep -q NEEDLE'
  'cat "$D/over.txt" | grep -q NEEDLE'
  'cat "$D/over.txt" | tr x y | grep -q NEEDLE'
  'cat "$D/over.txt" | grep -Eq NEEDLE'
  'cat "$D/over.txt" | grep -m1 NEEDLE'
  'cat "$D/over.txt" | head -1'
  'cat "$D/over.txt" | sed 1q'
  'cat "$D/over.txt" | awk "/NEEDLE/{exit}"'
  'printf "%s" "$(cat "$D/over.txt")" | grep -q NEEDLE'
)
_bad=""
for _f in "${_pos_forms[@]}"; do
  _n="$(_flip "$_f")"; [ "$_n" -eq 5 ] || _bad="$_bad [$_f→$_n/5]"
done
[ -z "$_bad" ] \
  && ok "L1 런타임 known-positive: 취약 표기 ${#_pos_forms[@]} 종이 전부 5/5 뒤집힌다 (매치했는데 rc≠0)" \
  || no "L1 런타임 known-positive" "안 뒤집힌 표기 —$_bad. 계기가 결함을 못 만들면 아래 초록은 증거가 아니다"

# ── L2 런타임 known-NEGATIVE — 과차단 방지. 컨트롤 값을 출력에 찍는다 ─────────────
# 🟥 이 줄이 없으면 이 레인은 「파이프는 다 나쁘다」가 된다. 판별자는 «크기» 가 아니라 «잔여 바이트».
_neg_forms=(
  'grep -q NEEDLE "$D/over.txt"'
  'cat "$D/over.txt" | grep -c NEEDLE'
  'sed -n "1,\$p" "$D/under.txt" | grep -q NEEDLE'
  'cat "$D/over.txt" | sed -n "1p" | { read -r _x; }'
  'cat "$D/over.txt" | grep -c NEEDLE | grep -q 1'
  'cat "$D/over.txt" | tail -n 1 | grep -q x'
  'head -1 "$D/over.txt" | grep -q NEEDLE'
)
_nb=""; _nvals=""
for _f in "${_neg_forms[@]}"; do
  _n="$(_flip "$_f")"; _nvals="$_nvals $_n"; [ "$_n" -eq 0 ] || _nb="$_nb [$_f→$_n/5]"
done
[ -z "$_nb" ] \
  && ok "L2 런타임 known-negative: 안전 표기 ${#_neg_forms[@]} 종이 전부 0/5 (컨트롤 값:$_nvals)" \
  || no "L2 과차단" "뒤집힌 안전 표기 —$_nb (컨트롤 값:$_nvals)"

# ── L3/L4/L5 정적 스캐너의 자가 교정(known-pair)이 살아 있는가 ────────────────────
_ST="$(/bin/bash "$SCAN" selftest 2>&1)"; _STRC=$?
_kp="$(printf '%s\n' "$_ST" | /usr/bin/awk -F'\t' '/KNOWN-POSITIVE/{print $2}')"
_kn="$(printf '%s\n' "$_ST" | /usr/bin/awk -F'\t' '/KNOWN-NEGATIVE/{print $2}')"
_np="$(printf '%s\n' "$_ST" | /usr/bin/awk -F'\t' '/NO-PIPEFAIL/{print $2}')"
case "$_kp" in '11/11 caught') ok "L3 정적 known-positive 11/11 (직접·중간필터·함수생산자·번들플래그·줄바꿈파이프·백슬래시연속·head·sed q·awk exit·printf+치환·\$( ) 안의 파이프)";;
  *) no "L3 정적 known-positive" "$_kp — 못 잡는 표기가 있으면 «0 곳» 은 무의미하다";; esac
case "$_kn" in '0 false positives'*) ok "L4 정적 known-negative 오탐 0 (파일직접·grep -c·차폐·리터럴 printf)";;
  *) no "L4 정적 known-negative" "$_kn";; esac
case "$_np" in 0*) ok "L5 컨트롤: pipefail 없는 파일은 0 곳 (pipefail 이 전제조건임을 증명)";;
  *) no "L5 컨트롤" "$_np — pipefail 무관하게 짖으면 전제조건 서술이 틀렸다";; esac
[ "$_STRC" -eq 0 ] || no "L5b selftest rc" "rc=$_STRC"

# ── L6/L7 되돌림 프로브 — 🟥 앵커가 장식일 수 있다 ───────────────────────────────
# 3단: ① 변이가 실제로 적용됐나 ② 그 변이가 known-positive 적발을 **떨어뜨리나** ③ 원본 무손상.
# 사본에 변이를 걸므로 ③ 은 원본 해시 대조로 확인한다(제자리 편집 금지 —
# [[feedback_editing_a_running_bash_script_corrupts_it]]).
_H0="$(shasum "$SCAN" | /usr/bin/awk '{print $1}')"
_catch(){ /bin/bash "$1" selftest 2>&1 | /usr/bin/awk -F'\t' '/KNOWN-POSITIVE/{print $2}'; }

# L6 — 소비자 플래그 판별(q/m/l/L)을 죽인다. 이것이 죽으면 조기종료를 아예 못 알아본다.
/usr/bin/sed 's/\*q\*) echo "grep -q"; return;;/*ZZUNMATCHABLEZZ*) echo "grep -q"; return;;/' "$SCAN" > "$D/mut6.sh"
if ! /usr/bin/grep -q 'ZZUNMATCHABLEZZ' "$D/mut6.sh"; then
  no "L6a 되돌림 미적용" "sed 가 아무것도 안 바꿨다 — L6b 는 증거가 아니다"
else
  ok "L6a 되돌림 적용됨 (grep 의 q 플래그 판별을 무력화)"
  _c6="$(_catch "$D/mut6.sh")"
  case "$_c6" in '11/11 caught') no "L6b 장식" "q 판별을 죽였는데도 11/11 이다 — 이 레인은 아무것도 안 잠그고 있다";;
    *) ok "L6b 죽이면 적발이 떨어진다: $_c6 (≠11/11 — 판별 코드가 하중을 진다)";; esac
fi

# L7 — `$(` 가 인용 문맥을 새로 여는 처리를 죽인다. 이것이 죽으면 `x="$(cmd | grep -q …)"` 를
#      «인용부호 안이라 파이프가 아니다» 로 읽어 **조용히** 놓친다(실제로 겪은 회귀다).
/usr/bin/sed 's/if(c2=="\$(" \&\& sq==0){ cd++;/if(0){ cd++;/' "$SCAN" > "$D/mut7.sh"
if ! /usr/bin/grep -q 'if(0){ cd++;' "$D/mut7.sh"; then
  no "L7a 되돌림 미적용" "sed 가 아무것도 안 바꿨다 — L7b 는 증거가 아니다"
else
  ok "L7a 되돌림 적용됨 (\$( 의 인용문맥 리셋을 무력화)"
  # 🟥 이 프로브가 초판에서 **실패했고, 그게 옳았다** — 당시 known-pair 에는 파이프가 `$( )`
  #    *안*에 있는 변종이 없어서 이 코드를 죽여도 적발이 안 떨어졌다. V11 이 그래서 추가됐다.
  _c7="$(_catch "$D/mut7.sh")"
  case "$_c7" in '11/11 caught') no "L7b 장식" "\$( 문맥 리셋을 죽였는데도 11/11 이다";;
    *) ok "L7b 죽이면 적발이 떨어진다: $_c7 (명령치환 안의 파이프를 놓치기 시작한다)";; esac
fi
[ "$(shasum "$SCAN" | /usr/bin/awk '{print $1}')" = "$_H0" ] \
  && ok "L8 복원 확인: 원본 스캐너가 프로브 전후로 바이트 동일 ($_H0)" \
  || no "L8 복원" "원본이 변했다 — 프로브가 대상을 오염시켰다"

# ── L9 델타 잠금 — «0 곳인가» 가 실제로 걸리는 자리 ───────────────────────────────
# 임시 git 레포를 세워서, 새 취약형이 들어온 커밋을 실제로 rc=1 로 막는지 본다.
G="$D/g"; mkdir -p "$G/scripts"
( cd "$G" && git init -q . && git config user.email t@t && git config user.name t ) || um "L9 준비" "git init 실패"
if [ -d "$G/.git" ]; then
  printf '#!/usr/bin/env bash\nset -uo pipefail\nif grep -q NEEDLE big.txt; then :; fi\n' > "$G/scripts/x.sh"
  ( cd "$G" && git add scripts/x.sh && git commit -qm base ) >/dev/null 2>&1
  _B="$( cd "$G" && git rev-parse HEAD )"
  # known-NEGATIVE: 안전한 줄만 더한 변경은 통과해야 한다 (과차단 방지)
  printf 'if grep -q OTHER big.txt; then :; fi\n' >> "$G/scripts/x.sh"
  _O="$(PIPESCAN_REPO="$G" /bin/bash "$SCAN" changed "$_B" 2>&1)"; _R=$?
  [ "$_R" -eq 0 ] && ok "L9a 델타 known-negative: 안전한 줄만 더한 변경은 통과 (rc=0)" \
                  || no "L9a 델타 과차단" "rc=$_R — $(printf '%s' "$_O" | tr '\n' ' ' | cut -c1-120)"
  # known-POSITIVE: 취약형을 들여오면 막아야 한다
  printf 'if cat big.txt | tr a b | grep -q NEEDLE; then :; fi\n' >> "$G/scripts/x.sh"
  _O="$(PIPESCAN_REPO="$G" /bin/bash "$SCAN" changed "$_B" 2>&1)"; _R=$?
  if [ "$_R" -eq 1 ] && printf '%s' "$_O" | /usr/bin/grep -q 'scripts/x.sh'; then
    ok "L9b 델타 known-positive: 새 취약형이 들어오면 rc=1 이고 파일을 이름으로 댄다"
  else
    no "L9b 델타 잠금" "rc=$_R — $(printf '%s' "$_O" | tr '\n' ' ' | cut -c1-140)"
  fi
  # 🟥 줄이 밀린 것을 «새 결함» 으로 읽으면 리팩터가 게이트에 걸린다 — 원문 대조임을 못 박는다.
  ( cd "$G" && git checkout -q -- scripts/x.sh ) 2>/dev/null
  { echo '# a new leading comment that shifts every line'; cat "$G/scripts/x.sh"; } > "$G/scripts/x.new" \
    && mv "$G/scripts/x.new" "$G/scripts/x.sh"
  _O="$(PIPESCAN_REPO="$G" /bin/bash "$SCAN" changed "$_B" 2>&1)"; _R=$?
  [ "$_R" -eq 0 ] && ok "L9c 줄번호만 밀린 변경은 통과 (판정은 줄번호가 아니라 원문 기준)" \
                  || no "L9c 줄밀림 오차단" "rc=$_R"
fi

# ── L10 레포 부채 — 정보용. 🟥 절대 차단하지 않는다(만족 불가능한 요구 = override 훈련) ──
_RO="$(/bin/bash "$SCAN" 2>&1 || true)"
_V="$(printf '%s\n' "$_RO" | /usr/bin/sed -n 's/.*VULN  *= *\([0-9][0-9]*\).*/\1/p' | head -1)"
if [ -n "$_V" ]; then
  echo "  ℹ️  L10 레포 현재 부채: VULN=$_V 곳 (이 레인은 이 수를 **차단하지 않는다** — 거버너 별건)"
else
  um "L10 부채 계수" "전수 출력에서 VULN 수를 못 읽었다"
fi

# ── L11 «의도된 취약형» 프라그마 — 3팔 known-pair ─────────────────────────────────
# 레인 픽스처는 취약형을 **일부러** 인라인으로 들고 있는데 지어낸 것과 진짜는 바이트가 같다.
# 🟥 사유 없는 프라그마는 면제가 아니다 — 통과 티켓이 되면 복붙으로 번진다.
_L11T="$(mktemp -d)"
printf 'set -o pipefail\ncat "$F" | grep -q NEEDLE\n' > "$_L11T/none.sh"
printf 'set -o pipefail\ncat "$F" | grep -q NEEDLE  # pipefail-intentional: 이건 known-positive 픽스처다\n' > "$_L11T/withreason.sh"
printf 'set -o pipefail\ncat "$F" | grep -q NEEDLE  # pipefail-intentional:\n' > "$_L11T/vacuous.sh"
_v(){ bash "$SCAN" list "$1" 2>/dev/null | /usr/bin/awk -F'\t' 'NR==1{print $1}'; }
[ "$(_v "$_L11T/none.sh")"       = VULN ]        && ok "L11a 프라그마 없음 → VULN (known-negative: 면제가 새지 않는다)" \
  || no "L11a 프라그마 없음" "got=$(_v "$_L11T/none.sh")"
[ "$(_v "$_L11T/withreason.sh")" = INTENTIONAL ] && ok "L11b 사유 있는 프라그마 → INTENTIONAL (known-positive)" \
  || no "L11b 사유 있는 프라그마" "got=$(_v "$_L11T/withreason.sh")"
[ "$(_v "$_L11T/vacuous.sh")"    = VULN ]        && ok "L11c 사유 공허한 프라그마 → 면제 아님 (VULN 유지)" \
  || no "L11c 사유 공허" "got=$(_v "$_L11T/vacuous.sh")"
/bin/rm -rf "$_L11T"

# ── L12 델타 잠금의 «0 곳» 회귀 — 🟥 첫 실사용에서 터진 그 자리 ────────────────────
# 초판은 `grep -vxF … || printf "$NEWV"` 였다. `grep -v` 는 아무 줄도 안 남으면 rc=1 이라,
# **「새 취약형 0 곳」이라는 정답 상황에서** 폴백이 기존 전부를 «새로 들여왔다» 로 보고했다.
# 즉 잠금이 정확히 통과해야 할 때 짖었다. 이 레인은 그 방향을 직접 건다.
_L12T="$(mktemp -d)"
printf 'a\nb\n' > "$_L12T/old.txt"
_add(){ printf '%s\n' "$1" | /usr/bin/grep -vxF -f "$_L12T/old.txt"; echo "rc=$?"; }
case "$(_add "$(printf 'a\nb')")" in
  rc=1) ok "L12a 새것 0 곳 → grep rc=1 (폴백을 달면 여기서 전부가 «새것» 이 된다)" ;;
  *)    no "L12a 새것 0 곳 rc" "got=$(_add "$(printf 'a\nb')")" ;;
esac
case "$(_add "$(printf 'a\nb\nc')")" in
  *c*rc=0) ok "L12b 진짜 새것 → 이름으로 나온다 (known-positive)" ;;
  *)       no "L12b 진짜 새것" "got=$(_add "$(printf 'a\nb\nc')")" ;;
esac
/bin/rm -rf "$_L12T"
# L12c 실물: 이 레포의 지금 상태에서 delta 가 통과해야 한다(기존 부채와 무관하게 산다).
if bash "$SCAN" changed >/dev/null 2>&1; then
  ok "L12c 실물 델타 — 지금 작업트리에서 rc=0 (기존 113 곳이 잠금을 막지 않는다)"
else
  no "L12c 실물 델타" "rc!=0 — 새 취약형이 있거나 폴백 회귀가 돌아왔다"
fi

echo "PASS=$PASS FAIL=$FAIL UNMEASURED=$UNMEASURED"
if [ "$FAIL" -eq 0 ] && [ "$UNMEASURED" -gt 0 ]; then echo "rc=2 (계기 오류: 팔 하나 이상 UNMEASURED)"; exit 2; fi
[ "$FAIL" -eq 0 ] || { echo "FAILED=1"; exit 1; }
exit 0
