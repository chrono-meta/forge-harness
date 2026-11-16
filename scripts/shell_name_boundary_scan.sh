#!/usr/bin/env bash
# 셸 «이름 경계» 스캐너 — 변수 전개에서 «어디까지가 이름인가»를 셸이 나와 다르게 읽는 자리.
#
# 🟥 왜 있나. 2026-08-31 하루에 **세 번** 나왔고 셋 다 자력 적발이 아니었다:
#   ① zsh  "$ref:scripts/x"   콜론 뒤를 «modifier» 로 먹는다 — 에러가 아니라 «다른 유효 문자열»
#   ② zsh  set -- $pair       인용 없는 전개가 리스트가 안 된다 — 여러 낱말이 한 낱말로
#   ③ bash "$V" 바로 뒤 » 꼴  다국어 문자가 «변수명»에 붙는다 — 이름 `V»` → unbound variable
#   공통형: **셸이 이름 경계를 다르게 읽는데 그게 조용하다**(①은 완전 무음, ③만 시끄럽다).
#
# ⚠️ **이 스캐너는 셋 중 «둘»만 덮는다** — ①과 ③. ②(단어분할)는 문법이 아니라 «의도»라
#    정적으로 못 가른다. 안 덮는 것을 덮는 척하지 않는다.
# ⚠️ 주석 안의 히트도 «보고한다» — 제외하면 진짜를 놓치는 쪽으로 기운다. 사람이 판정해라.
#
# --nonascii-only : ③ 만 본다(주석 줄도 본다 — 여러 줄 문자열·heredoc 안의 «#» 줄은 실행되는 글이라
#    «주석처럼 보이는 줄» 을 빼면 진짜를 놓친다, 2026-11-13 교차 계열 지적) — selfcheck 레인(test_name_boundary_locale_lanes.sh)이
#    출하 셸 전체에 거는 모드. ③ 은 맥 기본 UTF-8 로캘(ko_KR · en_US)에서 bash 3.2 와 bash 5 둘 다
#    rc 127 로 죽인다(2026-11-13 실측, LC_ALL=C 만 무사) — 리눅스 CI 는 이 얼굴을 못 본다.
set -uo pipefail
[ $# -gt 0 ] || { echo "usage: shell_name_boundary_scan.sh [--nonascii-only] <file...>"; exit 2; }
python3 - "$@" <<'PY'
import re,sys,io
CODE_ONLY = len(sys.argv)>1 and sys.argv[1]=='--nonascii-only'
if CODE_ONLY: del sys.argv[1]
if len(sys.argv)<2: print("usage: shell_name_boundary_scan.sh [--nonascii-only] <file...> — no files given (nothing scanned)"); sys.exit(2)
NONASCII=re.compile(r'\$[A-Za-z_][A-Za-z0-9_]*(?=[^\x00-\x7F])')   # ③
MODIFIER=re.compile(r'"\$[A-Za-z_][A-Za-z0-9_]*:')                  # ① (중괄호 없는 "$V:...")
hits=0
for f in sys.argv[1:]:
    try: s=io.open(f,encoding='utf-8').read()
    except Exception as e: print("  ⚠️ 읽기 실패 %s: %s (미검사 — 통과 아님)"%(f,e)); hits+=1; continue
    for i,l in enumerate(s.split('\n'),1):
        for m in NONASCII.finditer(l):
            print("  🟥 %s:%d [비-ASCII가 이름에 붙음] %s → %s"%(f,i,m.group(0),l.strip()[:64])); hits+=1
        for m in ([] if CODE_ONLY else MODIFIER.finditer(l)):
            print("  🟥 %s:%d [zsh modifier 로 먹힐 수 있음] %s → %s"%(f,i,m.group(0),l.strip()[:64])); hits+=1
print("  히트 %d 건  (0 이면 이 두 얼굴은 없다 — 나머지 하나는 이 계기가 «안 본다»)"%hits)
sys.exit(1 if hits else 0)
PY
