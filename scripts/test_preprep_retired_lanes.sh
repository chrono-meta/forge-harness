#!/usr/bin/env bash
# test_preprep_retired_lanes.sh — L1-c 폐어(retired) 갈래의 회귀 앵커.
#
# 실사고: 리뷰가 명시적으로 걷어낸 「재다」가 4개월 뒤 재유입됐고 **아무 검사도 안 울렸다**
# (운영자가 잡았다). jargon_terms=조어→풀이, banned=수치 인용 금지라 «걷어낸 말» 자리가 없었다.
#
# 재는 것 넷:
#   R1 판별력   폐어가 산출물에 «쓰이면» RETIRED 로 잡나
#   R2 오탐 0   대체어로 바꾸면 조용한가
#   R3 자기신고 🟥 «「재다」는 걷어낸 낱말이다» 라고 «적은» 줄은 위반이 아니라 mention 인가
#              — 이게 없으면 폐어 원장이 자기를 위반으로 신고한다
#   R4 처방     대체어를 finding 에 싣나 (처방 없는 판정은 절반이다)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$HERE/plugins/fh-preprep/skills/preprep"
PASS=0; FAIL=0
ok(){ echo "  ✅ $1"; PASS=$((PASS+1)); }
ng(){ echo "  ❌ $1"; FAIL=$((FAIL+1)); }
command -v python3 >/dev/null 2>&1 || {
  echo "  ⚠️  UNMEASURED — python3 unavailable; retired lanes NOT run (this is not a pass)"
  echo "retired lanes: SKIPPED (not passed)"; exit 0; }

out=$(cd "$SKILL" && python3 - <<'PY' 2>&1
import sys, os, json, yaml, tempfile
sys.path.insert(0, '.')
import preprep as P
spec = {'banned': [], 'conditional': [], 'retired': [
    {'id': 'measure-verb', 'literals': ['재다'], 'replacement': '측정하다',
     'why': '리뷰가 걷어낸 어휘', 'retired_by': 'review', 'retired_at': '2026-08-25'}]}
d = tempfile.mkdtemp(); sp = os.path.join(d, 't.yaml')
yaml.safe_dump(spec, open(sp, 'w', encoding='utf-8'), allow_unicode=True)
cfg = {'canon_terms': sp, 'canon_ledger': os.path.join(d, 'absent.md')}
r = {}
for k, body in (('use', '🗣\n> 그것을 재다 보면 압니다.\n'),
                ('repl', '🗣\n> 그것을 측정하다 보면 압니다.\n'),
                ('ment', '> 🚫 「재다」는 걷어낸 낱말이다. 쓰지 마라.\n')):
    f, _ = P.lane_canon(cfg, '.', {'s': (body, 'markdown')}, {'s': {'spoken': True}})
    r[k] = {'tags': [x[1] for x in f], 'msg': ' '.join(x[4] for x in f if x[1] == 'RETIRED')}
print(json.dumps(r, ensure_ascii=False))
PY
); rc=$?
[ $rc -eq 0 ] || { echo "  ❌ INSTRUMENT ERROR — lane_canon 실행 실패 (rc=$rc): $out"; exit 1; }
g(){ python3 -c "import json,sys;d=json.loads(sys.argv[1]);print(d[sys.argv[2]][sys.argv[3]])" "$out" "$1" "$2"; }

[ "$(g use tags)" = "['RETIRED']" ] && ok "R1 판별력: 폐어 재유입을 RETIRED 로 잡는다" \
  || ng "R1 판별력 없음: $(g use tags)"
[ "$(g repl tags)" = "[]" ] && ok "R2 오탐 0: 대체어로 바꾸면 조용" || ng "R2 오탐: $(g repl tags)"
[ "$(g ment tags)" = "['mention']" ] && ok "R3 자기신고 방지: 폐어를 «적은» 줄은 mention" \
  || ng "R3 실패: $(g ment tags) — 폐어 원장이 자기를 위반으로 신고한다"
case "$(g use msg)" in *측정하다*) ok "R4 처방: 대체어를 finding 에 싣는다" ;;
                       *) ng "R4 실패 — 처방 없는 판정이다: $(g use msg)" ;; esac


# ── C 갈래 (2026-09-13 신설) — 설정을 못 읽은 것이 «발견» 으로 나가지 않나 ─────────────
#
# 실사고: `python3 preprep.py` 를 인자 없이 돌리면 **트레이스백으로 죽고 rc=1** 이었다.
# 이 도구의 선언(SKILL.md:164)은 「0 통과 · 1 발견 · 2 판정불가(계기오류/미측정)」이므로
# 🟥 **1 은 「뭔가 찾았다」** 다 — 즉 「한 줄도 못 쟀다」가 「발견 있음」과 **같은 값**으로 나갔고
# 부르는 쪽이 둘을 못 갈랐다. Done-When #1(「종료코드가 0/1/2 로 확정」)이 잡으라는 바로 그것이다.
#
# 여기서 재는 것: 설정 부재·깨짐·계약 미달 셋이 전부 **2** 로 확정되나, 그리고 정상 설정은
# 여전히 2 가 «아닌» 값을 내나(컨트롤 — 항상 2 면 판별력이 0 이다).
PP="$HERE/plugins/fh-preprep/skills/preprep/preprep.py"
CT=$(mktemp -d); trap 'rm -rf "$CT"' EXIT

_rc(){ ( cd "$CT" && python3 "$PP" "$1" >/dev/null 2>&1 ); printf '%s' "$?"; }

C1=$(_rc "$CT/does_not_exist.yaml")
[ "$C1" = "2" ] && ok "C1 설정 부재 → rc=2 (판정불가 · 발견 아님)"                 || ng "C1 설정 부재가 rc=$C1 — «발견 있음»(1)이나 트레이스백과 안 갈린다"

printf 'root: [ unclosed
' > "$CT/broken.yaml"
C2=$(_rc "$CT/broken.yaml")
[ "$C2" = "2" ] && ok "C2 YAML 깨짐 → rc=2" || ng "C2 깨진 설정이 rc=$C2"

printf '' > "$CT/empty.yaml"
C3=$(_rc "$CT/empty.yaml")
[ "$C3" = "2" ] && ok "C3 빈 설정(파싱은 됨 · 계약 미달) → rc=2"                 || ng "C3 빈 설정이 rc=$C3 — 「돌았는데 발견 0」으로 읽힌다"

# 🟥 컨트롤 — 정상 설정에서는 2 가 «안» 나와야 한다. 안 그러면 위 셋은 아무것도 증명 못 한다.
# 🟥 `kind` 가 빠지면 도구가 **옳게** «기계 어댑터 없음 → UNMEASURED → rc=2» 를 낸다.
#    초판 픽스처가 그걸 빠뜨려 컨트롤이 죽었고(정상 설정도 2) C1~C3 이 아무것도 증명하지
#    못했다 — 컨트롤이 대상과 같이 죽으면 차이가 사라진다. 도구가 아니라 픽스처가 틀렸다.
printf 'root: %s
surfaces:
  - id: s1
    path: deck.md
    kind: markdown
' "$CT" > "$CT/ok.yaml"
printf '# 제목
본문 한 줄.
' > "$CT/deck.md"
C4=$(_rc "$CT/ok.yaml")
[ "$C4" != "2" ] && ok "C4 컨트롤: 정상 설정은 2 가 아니다 (실측 rc=$C4) — 판별력 있음"                  || ng "C4 컨트롤 죽음: 정상 설정도 rc=2 — 위 셋은 아무것도 증명하지 않는다"

echo "retired + config-verdict lanes: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
