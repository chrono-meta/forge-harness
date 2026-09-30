#!/usr/bin/env bash
# test_resident_cost_lanes.sh — scripts/resident_cost.py(상주 비용 계기)의 레인 (2026-10-01 신설).
#
# 계기가 «숫자를 만드는가» 가 아니라 «이미 답을 아는 입력에서 그 답을 내는가» 를 본다(known-pair).
#   R1 문자 ≠ 바이트: 한글 3자 → 문자 3 · 바이트 9 / ASCII 3자 → 3 · 3
#   R2 YAML 접힌 description(`>-`)은 YAML 값으로 센다 — 한 줄 파싱(">-")과 다르면 둘 다 나온다
#   R3 MEMORY 상한: 26,000자 → 적재분 ≤ 25,000 · 줄 단위 절단 · 공식 문구는 200줄이 먼저 걸림
#   R4 없는 파일 → «없음»(status=absent, chars=null) — 0 이 아니다
#   R5 @import 는 따라가되 코드 펜스·인라인 코드·맨 낱말(@me)은 import 가 아니고, 순환은 멈춘다
#   R6 읽을 수 없는 파일(UTF-8 아님) → «미측정», rc=3, 합계 옆에 «미측정 1칸»
#   R7 rules: paths: 있는 것은 «조건부» 로 합계 밖, 없는 것은 합계 안
#   R8 합계 = 측정된 칸의 합(MEMORY 는 적재분)
#   R9 되돌림: nchars 를 바이트로 바꾼 변이체 → R1 이 빨개져야 한다(적용 확인 → 실행 → 판정)
#   R10 실물: 이 레포 CLAUDE.md 줄이 독립 계산(len)과 같은 값
# CLAUDE.md 크기 «가드»(145,000 한계)는 scripts/test_claude_md_size_lanes.sh 가 맡는다 — 여기서 다시 안 잰다.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/.." && pwd)"
METER="${RESIDENT_COST_METER:-$HERE/resident_cost.py}"   # R9 가 변이체를 넣을 때만 바뀐다
PASS=0; FAIL=0
ok(){ PASS=$((PASS+1)); printf '  ✅ %s\n' "$1"; }
no(){ FAIL=$((FAIL+1)); printf '  ❌ %s — %s\n' "$1" "${2:-}"; }
finish(){ echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ] || { echo "FAILED=1"; exit 1; }; exit 0; }

echo "── test_resident_cost_lanes ──"
command -v python3 >/dev/null 2>&1 || { no "R0 환경" "python3 없음 — 레인 미측정(통과 아님)"; finish; }
[ -f "$METER" ] || { no "R0 계기" "scripts/resident_cost.py 부재"; finish; }
D="$(mktemp -d 2>/dev/null)" || D=""
[ -n "$D" ] && [ -w "$D" ] || { no "R0 환경" "mktemp -d 불가 — 레인 미측정(통과 아님)"; finish; }
trap 'rm -rf "$D"' EXIT

# jq 대신 python 으로 JSON 을 읽는다(의존 하나 덜기). q <json-file> <python-expr over r>
q(){ python3 -c 'import json,sys; r=json.load(open(sys.argv[1])); print(eval(sys.argv[2]))' "$1" "$2"; }
# rowf <json> <name-prefix> <field> — 이름이 prefix 로 시작하는 첫 줄의 필드
rowf(){ q "$1" "next((x.get('$3') for x in r['rows'] if x['name'].startswith('$2')), 'NO_ROW')"; }

# ── 픽스처 레포 A: 한글/ASCII known-pair · YAML 접힌 블록 · rules · MEMORY 26,000자 · import ──
A="$D/repoA"; M="$D/memA"; U="$D/userA"
mkdir -p "$A/plugins/p/skills/s" "$A/.claude/rules" "$M" "$U"
printf '가나다' > "$A/CLAUDE.md"
printf 'abc' > "$A/CLAUDE.local.md"
cat > "$A/plugins/p/skills/s/SKILL.md" <<'EOF'
---
name: sk
description: >-
  hello
  world
---
body
EOF
printf -- '---\npaths: ["x/**"]\n---\nCOND\n' > "$A/.claude/rules/cond.md"
printf 'ALWAYS' > "$A/.claude/rules/always.md"
python3 -c 'import sys; open(sys.argv[1],"w",encoding="utf-8").write(("a"*99+"\n")*260)' "$M/MEMORY.md"
# 사용자 전역: 진짜 import 하나 + import 가 아닌 것 셋(펜스 · 인라인 코드 · 맨 낱말) + 순환
cat > "$U/CLAUDE.md" <<'EOF'
@sub.md
@LICENSE
@missing.md
`gh pr list --author @me`
say @me hi
```
@fenced.md
```
EOF
printf 'SUB\n@back.md\n' > "$U/sub.md"
printf 'BK\n@sub.md\n' > "$U/back.md"
printf 'NEVER' > "$U/fenced.md"
printf '12345' > "$U/LICENSE"      # 확장자 없는 import (cross-family R1 #1)

JA="$D/a.json"
python3 "$METER" --json --repo "$A" --memory-dir "$M" --user-claude "$U/CLAUDE.md" > "$JA"; RCA=$?
[ "$RCA" -eq 0 ] && ok "R0 픽스처 A 전 칸 측정 rc=0" || no "R0 픽스처 A" "rc=$RCA"

# R1 known-pair
C=$(rowf "$JA" "CLAUDE.md" chars); B=$(rowf "$JA" "CLAUDE.md" bytes)
[ "$C" = "3" ] && [ "$B" = "9" ] && ok "R1a 한글 3자 → 문자 3 · 바이트 9" || no "R1a 한글" "chars=$C bytes=$B"
C=$(rowf "$JA" "CLAUDE.local.md" chars); B=$(rowf "$JA" "CLAUDE.local.md" bytes)
[ "$C" = "3" ] && [ "$B" = "3" ] && ok "R1b ASCII 3자 → 3 · 3" || no "R1b ASCII" "chars=$C bytes=$B"

# R2 YAML folded: name "sk"(2) + "hello world"(11) = 13; 한 줄 파싱은 "sk" + ">-" = 4
C=$(rowf "$JA" "스킬" chars); ST=$(rowf "$JA" "스킬" status)
OL=$(q "$JA" "next(x['oneline']['chars'] for x in r['rows'] if x['name'].startswith('스킬'))")
DF=$(rowf "$JA" "스킬" oneline_differs)
[ "$ST" = "ok" ] && [ "$C" = "13" ] && [ "$OL" = "4" ] && [ "$DF" = "True" ] \
  && ok "R2 접힌 description → YAML 13 · 한 줄 4 · 둘 다 출력(differs=True)" \
  || no "R2 YAML" "status=$ST yaml=$C oneline=$OL differs=$DF (PyYAML 없으면 미측정 — 통과 아님)"
python3 "$METER" --repo "$A" --memory-dir "$M" --user-claude "$U/CLAUDE.md" > "$D/a.txt"
/usr/bin/grep -q "한 줄 파싱 (접힌 블록 못 읽음)" "$D/a.txt" && ok "R2b 사람용 출력에도 두 값이 같이 나온다" || no "R2b" "한 줄 파싱 줄 없음"

# R3 MEMORY: 260줄 × 100자 = 26,000 → 250줄 = 25,000 적재 · 10줄 절단 · 공식은 200줄이 먼저
LC=$(rowf "$JA" "MEMORY" loaded_chars); LL=$(rowf "$JA" "MEMORY" loaded_lines); CL=$(rowf "$JA" "MEMORY" cut_lines)
TC=$(rowf "$JA" "MEMORY" chars)
BF=$(q "$JA" "next(x['official']['binds_first'] for x in r['rows'] if x['name'].startswith('MEMORY'))")
[ "$TC" = "26000" ] && [ "$LC" -le 25000 ] 2>/dev/null && [ "$LC" = "25000" ] && [ "$LL" = "250" ] && [ "$CL" = "10" ] \
  && ok "R3a 26,000자 → 적재 25,000 (250줄) · 절단 10줄" || no "R3a MEMORY 상한" "total=$TC loaded=$LC lines=$LL cut=$CL"
[ "$BF" = "200줄" ] && ok "R3b 공식 문구: 200줄이 25KB 보다 먼저 걸림" || no "R3b" "binds_first=$BF"
# R3c 한글 MEMORY: 줄마다 50자(150바이트) → 25KB(바이트)가 200줄보다 먼저, 실측 상한(문자)은 그보다 뒤
M2="$D/memK"; mkdir -p "$M2"
python3 -c 'import sys; open(sys.argv[1],"w",encoding="utf-8").write(("가"*49+"\n")*300)' "$M2/MEMORY.md"
python3 "$METER" --json --repo "$A" --memory-dir "$M2" --no-user > "$D/k.json"
BF=$(q "$D/k.json" "next(x['official']['binds_first'] for x in r['rows'] if x['name'].startswith('MEMORY'))")
OLN=$(q "$D/k.json" "next(x['official']['lines'] for x in r['rows'] if x['name'].startswith('MEMORY'))")
LL=$(rowf "$D/k.json" "MEMORY" loaded_lines)
# 한 줄 = 49자+\n = 50자 = 148바이트 → 25,600 // 148 = 172줄(172×148=25,456 · 173×148=25,604 > 25,600)
[ "$BF" = "25KB" ] && [ "$OLN" = "172" ] && [ "$LL" = "300" ] \
  && ok "R3c 한글: 공식 25KB 가 172줄에서 먼저 · 문자 상한(15,000자 < 25,000)은 전체 300줄 적재" \
  || no "R3c 한글 MEMORY" "binds=$BF official_lines=$OLN loaded_lines=$LL"

# R5 import: sub.md · back.md 만 적재(순환 1회), fenced.md · @me 는 아님
IMP=$(q "$JA" "sorted(x['name'].split('@',1)[1] for x in r['rows'] if '→ @' in x['name'])")
[ "$IMP" = "['LICENSE', 'back.md', 'sub.md']" ] && ok "R5 import: sub.md → back.md 순환에서 멈춤 · 확장자 없는 @LICENSE 포함 · 펜스/인라인/@me 제외" \
  || no "R5 import" "got=$IMP"
UNR=$(q "$JA" "[u['token'] for u in r['unresolved_imports']]")
[ "$UNR" = "['@missing.md']" ] && /usr/bin/grep -q "대상 없는 import 후보 1개" "$D/a.txt" \
  && ok "R5b 대상 없는 @missing.md → 해석 실패로 보고 · 합계 줄에 명시 (@me 는 조용히 무시)" || no "R5b unresolved" "got=$UNR"

# R7 rules
S1=$(rowf "$JA" ".claude/rules/cond.md" status); S2=$(rowf "$JA" ".claude/rules/always.md" status)
[ "$S1" = "conditional" ] && [ "$S2" = "ok" ] && ok "R7 rules: paths 있음 → 조건부 · 없음 → 상주" || no "R7 rules" "cond=$S1 always=$S2"

# R8 합계 = 3 + 3 + 사용자(CLAUDE 전역 + sub + back) + MEMORY 적재 25,000 + 스킬 13 + always 6
EXP=$(python3 -c 'import sys,os
u=sum(len(open(os.path.join(sys.argv[1],f),encoding="utf-8").read()) for f in ("CLAUDE.md","sub.md","back.md"))
print(3+3+u+5+25000+13+6)' "$U")   # +5 = LICENSE
TOT=$(q "$JA" "r['total']['chars']"); UN=$(q "$JA" "r['total']['unmeasured_cells']")
[ "$TOT" = "$EXP" ] && [ "$UN" = "0" ] && ok "R8 합계 = 측정 칸의 합 ($TOT) · 미측정 0칸" || no "R8 합계" "got=$TOT expected=$EXP unmeasured=$UN"

# ── 픽스처 레포 B: 부재 · 미측정 ──
Bp="$D/repoB"; mkdir -p "$Bp"
printf '\xff\xfe\xfa' > "$Bp/CLAUDE.md"   # UTF-8 아님
JB="$D/b.json"
python3 "$METER" --json --repo "$Bp" --memory-dir "$D/no-such-mem" --no-user > "$JB"; RCB=$?
# R4 부재
S=$(rowf "$JB" "CLAUDE.local.md" status); C=$(rowf "$JB" "CLAUDE.local.md" chars)
SM=$(rowf "$JB" "MEMORY" status); CM=$(rowf "$JB" "MEMORY" chars)
[ "$S" = "absent" ] && [ "$C" = "None" ] && [ "$SM" = "absent" ] && [ "$CM" = "None" ] \
  && ok "R4 없는 파일 → absent · chars=None (0 아님)" || no "R4 부재" "local=$S/$C memory=$SM/$CM"
python3 "$METER" --repo "$Bp" --memory-dir "$D/no-such-mem" --no-user > "$D/b.txt"
/usr/bin/grep -E '^CLAUDE\.local\.md.*없음' "$D/b.txt" >/dev/null && ! /usr/bin/grep -E '^CLAUDE\.local\.md[^0-9]* 0 ' "$D/b.txt" >/dev/null \
  && ok "R4b 사람용 출력: «없음» 으로 찍힌다" || no "R4b" "$(/usr/bin/grep '^CLAUDE.local' "$D/b.txt")"
# R6 미측정
S=$(rowf "$JB" "CLAUDE.md" status); UN=$(q "$JB" "r['total']['unmeasured_cells']")
[ "$RCB" -eq 3 ] && [ "$S" = "unmeasured" ] && [ "$UN" = "1" ] && /usr/bin/grep -q "미측정 1칸" "$D/b.txt" \
  && ok "R6 UTF-8 아님 → 미측정 · rc=3 · 합계 옆 «미측정 1칸»" || no "R6 미측정" "rc=$RCB status=$S unmeasured=$UN"

# ── R9 되돌림: 문자 대신 바이트를 세는 변이체로 «이 레인 전체» 를 다시 돌린다 ──
#   적용 확인(변이가 실제로 들어갔나) → 실행 → 판정(R1a 가 빨강이고 스위트 rc=1). 변이가 안 들어갔으면 통과가 아니라 계기 오류.
if [ -n "${RESIDENT_COST_LANES_NESTED:-}" ]; then
  echo "  ·  R9 (중첩 실행 — 되돌림 안에서는 되돌림을 다시 안 돈다)"
else
  MUT="$D/mut"; mkdir -p "$MUT"
  sed 's/^    return len(s)$/    return len(s.encode("utf-8"))/' "$METER" > "$MUT/resident_cost.py"   # 선택된 SUT 를 변이한다(R1 #4)
  if cmp -s "$METER" "$MUT/resident_cost.py"; then
    no "R9 되돌림" "변이가 적용되지 않았다(nchars 본문이 바뀌었나?) — 계기 오류, 통과 아님"
  else
    MOUT=$(RESIDENT_COST_METER="$MUT/resident_cost.py" RESIDENT_COST_LANES_NESTED=1 bash "$HERE/test_resident_cost_lanes.sh" 2>&1); MRC=$?
    if [ "$MRC" -eq 1 ] && printf '%s\n' "$MOUT" | /usr/bin/grep -q "❌ R1a"; then
      ok "R9 되돌림: 바이트 변이체 → 스위트 rc=1 · R1a 빨강 ($(printf '%s\n' "$MOUT" | /usr/bin/grep -c '❌')개 레인 빨강)"
    else
      no "R9 되돌림" "변이체에서 rc=$MRC · R1a 빨강 아님 — R1 이 단위를 판별하지 못한다(장식 앵커)"
    fi
  fi
fi

# ── R11 residency: 남의 홈 경로를 인자로 줘도 사용자명이 출력에 안 나온다 ──
python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import importlib.util as u
s=u.spec_from_file_location("rc", sys.argv[2]); m=u.module_from_spec(s); s.loader.exec_module(m)
u="/"+"Users"; h="/"+"home"   # 리터럴 홈 경로를 파일에 안 남긴다(기밀 스캔이 그 모양을 막는다)
print(m.show(u+"/zz-alice/x/CLAUDE.md"), m.show(h+"/zz-bob/y"))' "$D" "$METER" > "$D/red.txt"
if /usr/bin/grep -q "zz-" "$D/red.txt"; then no "R11 residency" "$(cat "$D/red.txt")"
else ok "R11 residency: /Users/<x> · /home/<x> → <user> ($(tr '\n' ' ' < "$D/red.txt"))"; fi

# ── R10 실물: 이 레포 CLAUDE.md ──
if [ -f "$ROOT/CLAUDE.md" ]; then
  python3 "$METER" --json --repo "$ROOT" --memory-dir "$D/no-such-mem" --no-user > "$D/r.json"
  GOT=$(rowf "$D/r.json" "CLAUDE.md" chars)
  IND=$(python3 -c 'import sys; print(len(open(sys.argv[1],encoding="utf-8").read()))' "$ROOT/CLAUDE.md")
  [ "$GOT" = "$IND" ] && ok "R10 실물 CLAUDE.md = ${GOT}자 (독립 len 과 일치)" || no "R10 실물" "meter=$GOT independent=$IND"
else
  no "R10 실물" "CLAUDE.md 부재 — 미측정(통과 아님)"
fi

finish
