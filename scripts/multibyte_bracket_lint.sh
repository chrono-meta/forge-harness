#!/usr/bin/env bash
# multibyte_bracket_lint.sh — 셸 브래킷 표현 안의 멀티바이트 문자를 막는다.
#
# THE DEFECT (2026-09-21 하루에 세 자리에서 실측)
#   POSIX 브래킷 표현 `[...]` / `[^...]` 은 로케일이 UTF-8 이 아닐 때 **바이트 집합으로 퇴화**한다.
#   `LANG` 이 안 걸린 셸(베어 컨테이너 · CI 러너 · **그리고 운영자 맥의 기본 셸** — 실측:
#   `LANG` unset → `LC_CTYPE="C"`)에서 `—`(E2 80 94)나 `①`(E2 91 A0)을 브래킷에 넣으면,
#   정규식은 그 **선두 바이트 0xE2** 에 걸린다. 같은 바이트를 공유하는 다른 문자까지 함께.
#
#   실측된 세 자리, 방향이 **제각각**이라 한 방향으로 못 읽는다:
#     `[:—-]` / `[^:—-]*`  영혼 복붙 검사   → BLOCK 이 PASS 로 샌다        (fail-OPEN)
#     `[^[:alnum:]«]*`      soul_check       → 순한글 줄이 통째로 먹힌다    (fail-OPEN)
#     `[^ⓕ]*`               axes-run         → 채워진 필드가 빈칸으로 읽힌다 (과차단)
#     `[^”]{2,}`            below-floor-ack  → **양방향**(아래 §양방향)
#
#   🟥 **`bash -n` 은 전부 통과한다.** 이것은 문법 오류가 아니라 의미 변화다.
#
# WHY A LINT AND NOT A LIST OF FIXES
#   같은 클래스를 2026-08-30 에 한 번 고쳤다(`tr -d '[:space:].·—-]'` 자리). 훅 주석이 그 함정을
#   적어 두기까지 했는데, **열 줄 아래의 `sed` 자리는 그대로 남아 오늘까지 왔다.** 그리고 오늘
#   이 자리들을 «전수 열거» 하려던 첫 계기가 11 중 1 을 놓쳤다 — 정규식이 `[:alnum:]` 의 첫 `]`
#   에서 끊겨서, 하필 실측된 fail-OPEN 자리를 못 봤다. 사람이 세면 빠지고, 세는 계기도 빠진다.
#   그래서 처방은 목록이 아니라 **열두 번째가 생기는 순간 빨개지는 것**이다.
#
# SCOPE — 의도적으로 좁다
#   기본 대상은 **게이트 파일**(`templates/.git-hooks/*`)뿐이다. 거기서의 결함은 BLOCK/PASS 를
#   바꾸지만, 레인 파일에서의 같은 결함은 레인이 빨개져서 드러난다 — 심각도가 다르다.
#   🟥 **남은 표면을 숨기지 않고 이름으로 남긴다**: 같은 스캔을 레포 전체에 돌리면 셸 파일에
#   100자리 넘게 나온다(측정 2026-09-21). 그것은 **미측정**이지 무결이 아니다. 넓히려면 인자로
#   파일을 주면 된다. 파이썬은 대상이 아니다 — `re` 는 바이트-로케일 방식이 아니라 해당 없다.
#
# NOT EVERY HIT IS A LIVE BUG — 그리고 그렇게 말하지 않는다
#   `[^—-]*` 두 자리는 오늘 재보니 두 로케일에서 **같은 출력**을 냈다(뒤따르는 `(—|--)` 교차가
#   우연히 받쳐 준다). 이 린트는 그것도 잡는다. 「지금 깨졌다」가 아니라 **「우연히 맞는 구성이라
#   조용히 바뀔 수 있다」** 이고, 고치는 값이 한 줄이라 그 교환이 성립한다. 판정 문구도 그렇게 적는다.
#
# 처방: 브래킷 대신 **교차(alternation)** 를 쓴다.   `[:—-]` → `(:|—|-)`   `[^”]` → `[^"]` 또는 명시 교차
#
# Usage:   bash scripts/multibyte_bracket_lint.sh [FILE...]
#          bash scripts/multibyte_bracket_lint.sh --selftest
# Exit:    0 = 깨끗 · 1 = 적발 · 2 = 계기 오류(부재·읽기 실패 — 「통과」가 아니다)

set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

SELFTEST=0
FILES=()
for a in "$@"; do
  case "$a" in
    --selftest) SELFTEST=1 ;;
    -*) echo "unknown flag: $a" >&2; exit 2 ;;
    *) FILES+=("$a") ;;
  esac
done

command -v python3 >/dev/null 2>&1 || { echo "❌ INSTRUMENT ERROR — python3 없음. 부재는 통과가 아니다"; exit 2; }

_scan() { # $@ = files ; prints "path:line:fragment" per hit ; rc 0 always (판정은 호출부)
  python3 - "$@" <<'PY'
import sys, re, io, os
# POSIX 클래스 [:name:] 를 먼저 소비한다. 안 그러면 `[^[:alnum:]«]` 의 첫 `]` 에서 끊겨
# 하필 멀티바이트가 든 브래킷을 놓친다 — 2026-09-21 에 실제로 그렇게 한 자리를 놓쳤다.
RX = re.compile(r'\[\^?\]?(?:\[:[a-z]+:\]|[^]\n])*\]')
for p in sys.argv[1:]:
    if not os.path.isfile(p):
        print("MISSING\t%s" % p); continue
    try:
        lines = io.open(p, encoding='utf-8', errors='strict').read().split('\n')
    except Exception as e:
        print("UNREADABLE\t%s\t%s" % (p, e)); continue
    for i, l in enumerate(lines, 1):
        if l.lstrip().startswith('#'):   # 주석은 코드가 아니다
            continue
        for m in RX.finditer(l):
            frag = m.group(0)
            if any(ord(c) > 127 for c in frag):
                print("HIT\t%s\t%d\t%s" % (p, i, frag))
PY
}

# ── 계기 교정 — 알려진 쌍. 이 린트가 «무엇이든 잡는» 것도 «아무것도 못 잡는» 것도 아님을 보인다 ──
_calibrate() {
  local d rc_pos rc_neg
  d=$(mktemp -d) || return 2
  # known-POSITIVE: 실측된 결함 형태 그대로(브래킷 안 em-dash)
  printf '%s\n' 'x=$(printf %s "$l" | sed -E "s/^[^:—-]*[:—-]//")' > "$d/bad.sh"
  # known-NEGATIVE: 같은 일을 교차로 쓴 것 + 순-ASCII 브래킷 + 멀티바이트가 든 **주석**
  {
    printf '%s\n' 'x=$(printf %s "$l" | sed -E "s/^(:|—|-)*//")'
    printf '%s\n' 'y=$(printf %s "$l" | grep -oE "[A-Za-z0-9_]+")'
    printf '%s\n' '# 주석 안의 [^—-] 는 코드가 아니다'
  } > "$d/good.sh"
  rc_pos=$(_scan "$d/bad.sh"  | grep -c '^HIT' || true)
  rc_neg=$(_scan "$d/good.sh" | grep -c '^HIT' || true)
  rm -rf "$d"
  [ "${rc_pos:-0}" -ge 1 ] || { echo "❌ INSTRUMENT ERROR — 알려진 양성을 못 잡는다 (hits=$rc_pos)"; return 2; }
  [ "${rc_neg:-0}" -eq 0 ] || { echo "❌ INSTRUMENT ERROR — 알려진 음성에서 $rc_neg 건 오탐"; return 2; }
  return 0
}

if [ "$SELFTEST" = 1 ]; then
  echo "── multibyte-bracket lint · selftest ──"
  if _calibrate; then echo "✅ known-pair 분리 (양성 잡고 음성 안 잡는다)"; exit 0; else exit 2; fi
fi

_calibrate || exit 2

if [ "${#FILES[@]}" -eq 0 ]; then
  # 기본 대상 = 게이트. 글롭이 안 맞으면 리터럴이 루프에 들어오므로 존재 검사를 건다.
  for f in templates/.git-hooks/*; do [ -f "$f" ] && FILES+=("$f"); done
fi
[ "${#FILES[@]}" -gt 0 ] || { echo "❌ INSTRUMENT ERROR — 대상 파일이 0개다. 부재는 통과가 아니다"; exit 2; }

OUT=$(_scan "${FILES[@]}")
if printf '%s\n' "$OUT" | grep -qE '^(MISSING|UNREADABLE)'; then
  printf '%s\n' "$OUT" | grep -E '^(MISSING|UNREADABLE)' | while IFS=$'\t' read -r k p rest; do
    echo "❌ INSTRUMENT ERROR — $k: $p ${rest:-}"
  done
  exit 2
fi

HITS=$(printf '%s\n' "$OUT" | grep -c '^HIT' || true)
if [ "${HITS:-0}" -eq 0 ]; then
  echo "✅ multibyte-bracket lint: ${#FILES[@]} 파일, 브래킷 안 멀티바이트 0건"
  exit 0
fi

echo "❌ multibyte-bracket lint — $HITS 건. 브래킷은 비-UTF-8 로케일에서 **바이트 집합**이 된다."
printf '%s\n' "$OUT" | grep '^HIT' | while IFS=$'\t' read -r _ p n frag; do
  printf '   %s:%s   %s\n' "$p" "$n" "$frag"
done
echo "   처방: 브래킷 대신 교차를 써라 —  [:—-] → (:|—|-)   ·   [^”] → [^\"] 또는 명시 교차"
echo "   🟥 「지금 깨졌다」가 아니라 「로케일이 바뀌면 조용히 바뀐다」이다. 방향은 자리마다 다르고,"
echo "      오늘 실측된 셋은 fail-OPEN 둘 · 과차단 하나였다."
exit 1
