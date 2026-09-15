#!/usr/bin/env bash
# test_utterance_intake_lanes.sh — known pair for the «받는 절반»(operator utterance → record) channel.
#
# WHAT THIS GUARDS. FH 의 «질문하기» 엔진은 묻는 절반만 배선돼 있고 **받는 절반이 산문이다**
# (`fh_three_layer_canon.md §2`: *"이 엔진의 수용 절반이 비어 있다"*). 계기는 둘 다 이미 있었는데
# 서로 안 이어져 있었다:
#   · `compaction_probe.sh seal`  전사본 → 운영자 발화 축자 원장 (있음)
#   · `utterance_landing_check.sh` 손으로 쓴 probes.tsv → 기록 파일 grep (있음, **호출부 0**)
# probes.tsv 를 만드는 기계가 없어서 두 번째는 사람이 손으로 짜야 했고, 그래서 안 돌았다.
# `utterance_intake.sh` 가 그 사이를 잇고 `session_close_check.sh ①-f` 가 그걸 부른다.
#
# 🟥 이 스위트가 지키는 불변식 넷 — 넷 다 «미측정을 0 으로 접지 마라» 의 사례다:
#   ⓐ 미착지는 rc=1 · 계기 사망은 rc=10 — **뭉치면 「기록하라」와 「프로브를 고쳐라」가 안 갈린다**
#   ⓑ 전사본 부재 → UNMEASURED(rc≠0). 「전부 착지」가 **아니다**
#   ⓒ 추출 발화 0 건 → UNMEASURED. 빈 프로브 세트는 합격이 아니다
#   ⓓ seal 출력은 리팩터 전후로 **바이트 동일**해야 한다 — 공용화가 기존 원장을 조용히 바꾸면
#      그건 「미측정을 0 으로」의 사촌인 «재생성이 커밋된 의도를 지운다» 다
#
# 🟥 음성 컨트롤이 왜 필요한가. `utterance_landing_check.sh` 의 CONTROL 은 **양성만** 있다
#   ("착지가 확실한 것이 안 잡히면 계기 사망"). 그건 「계기가 죽었나」만 재고 「계기가 아무거나
#   다 잡나」는 못 잰다 — `[[feedback_control_presence_is_not_discrimination]]`. 그래서 이 래퍼가
#   **없어야 마땅한 무작위 토큰**을 넣고, 그게 잡히면 rc=10 을 낸다. L5/L5b 가 그 known pair 다.
#
# HERMETIC: 픽스처는 전부 mktemp 아래. 실 전사본도 실 tracks/ 도 읽지 않는다.
#
# 종료코드는 selfcheck.sh 규약: 0 pass · 2 주체 부재 · 10 이 스위트 자신의 setup 실패.

set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/fixture_guard_lib.sh"
cd "$(dirname "$0")/.." || exit 1
ROOT="$(pwd -P)"
SUT="$ROOT/scripts/utterance_intake.sh"
EXTRACT="$ROOT/scripts/transcript_utterances.py"
PROBE="$ROOT/scripts/compaction_probe.sh"
CLOSE="$ROOT/scripts/session_close_check.sh"
PASS=0; FAIL=0
ok() { echo "✅ $1"; PASS=$((PASS+1)); }
ng() { echo "❌ $1"; FAIL=$((FAIL+1)); }

# 주체 부재는 «통과» 가 아니다 — skipped is not passed.
for _s in "$SUT" "$EXTRACT"; do
  [ -f "$_s" ] || { echo "ⓘ ${_s##*/} absent — subject missing when we looked (NOT a pass)"; exit 2; }
done
[ -f "$PROBE" ] || { echo "ⓘ compaction_probe.sh absent (NOT a pass)"; exit 2; }

T="$(fh_fixture_root "$(mktemp -d 2>/dev/null)")" || { echo "ⓘ mktemp failed — this suite's own setup broke (NOT a pass)"; exit 10; }
: "${T:?fixture root unset}"
trap 'rm -rf "$T"' EXIT INT TERM

TODAY="$(date +%Y-%m-%d)"

# ── 픽스처 전사본 ────────────────────────────────────────────────────────────
# 발화 4 (착지 2 · 미착지 1 · 짧음 1) + tool_result 1 + 슬래시 커맨드 1 + assistant 1
mk_transcript() {  # $1=경로
  cat > "$1" <<'JSONL'
{"type":"user","timestamp":"2026-09-05T01:00:00.000Z","message":{"content":"앞으로 무인 잡은 plist 에 모델을 핀하는 걸 원칙으로 하자"}}
{"type":"user","timestamp":"2026-09-05T01:01:00.000Z","message":{"content":[{"type":"tool_result","content":"툴출력본문 재규어호루라기"}]}}
{"type":"user","timestamp":"2026-09-05T01:02:00.000Z","message":{"content":"/clear 슬래시커맨드본문 도롱뇽부표"}}
{"type":"assistant","timestamp":"2026-09-05T01:03:00.000Z","message":{"content":"응답"}}
{"type":"user","timestamp":"2026-09-05T01:04:00.000Z","message":{"content":"ㄱㄱ"}}
{"type":"user","timestamp":"2026-09-05T01:05:00.000Z","message":{"content":[{"type":"text","text":"등급 기댓값은 분기마다 다시 세우자 이번 분기는 인큐베이터를 과녁으로"},{"type":"image","source":{"type":"base64"}}]}}
{"type":"user","timestamp":"2026-09-05T01:06:00.000Z","message":{"content":"이폴트 추천은 세션 시작에 한 번만 띄우고 반복하지 마라 두번은 소음이다"}}
JSONL
}

# 기록 픽스처: 1번(plist 모델 핀)과 3번(등급 기댓값)만 착지. 4번(이폴트 추천)은 미착지.
# 양성 컨트롤(오늘 날짜)이 반드시 들어 있어야 한다.
mk_record() {  # $1=경로
  cat > "$1" <<REC
# fh_completed_${TODAY}.md

- ✅ 무인 잡 plist 에 모델을 핀했다 — launchd 3종 전부
- ✅ 등급 기댓값을 분기 단위로 재정의 — 인큐베이터 과녁 선언
REC
}

mk_transcript "$T/tr.jsonl"
mk_record "$T/rec.md"

# ── L1 착지 2 · 미착지 1 · rc=1 ──────────────────────────────────────────────
OUT1="$(bash "$SUT" "$T/tr.jsonl" "$T/rec.md" 2>&1)"; RC1=$?
case "$RC1" in 1) ok "L1 미착지가 있으면 rc=1" ;; *) ng "L1 rc=$RC1 (기대 1)"; echo "$OUT1" | sed 's/^/     /' ;; esac
case "$OUT1" in *"착지 2"*) ok "L1b 착지 2 건으로 센다" ;; *) ng "L1b 착지 수가 2 가 아니다"; echo "$OUT1" | sed 's/^/     /' ;; esac
case "$OUT1" in *"미착지 1"*) ok "L1c 미착지 1 건으로 센다" ;; *) ng "L1c 미착지 수가 1 이 아니다" ;; esac

# ── L2 미착지 목록이 **정확히 그 발화**를 가리킨다 ───────────────────────────
case "$OUT1" in *"이폴트 추천"*) ok "L2 미착지 목록에 그 발화가 나온다" ;; *) ng "L2 미착지 발화가 목록에 없다" ;; esac
# known-negative: 착지한 발화는 미착지 목록에 없어야 한다. 목록 절만 잘라서 본다.
LIST1="$(printf '%s\n' "$OUT1" | sed -n '/미착지 목록/,$p')"
case "$LIST1" in *"등급 기댓값"*) ng "L2b 착지한 발화가 미착지 목록에 섞였다" ;; *) ok "L2b 착지한 발화는 목록에 없다 (known-negative)" ;; esac

# ── L3 구조 제외: tool_result 본문·슬래시 커맨드는 프로브가 되지 않는다 ──────
PT="$T/probes_dump.tsv"
FH_INTAKE_DUMP_PROBES="$PT" bash "$SUT" "$T/tr.jsonl" "$T/rec.md" >/dev/null 2>&1
if [ -f "$PT" ]; then
  grep -q "재규어호루라기" "$PT" && ng "L3 tool_result 본문이 프로브가 됐다" || ok "L3 tool_result 제외 (known-negative)"
  grep -q "도롱뇽부표" "$PT" && ng "L3b 슬래시 커맨드가 프로브가 됐다" || ok "L3b 슬래시 커맨드 제외 (known-negative)"
  # ── L4 짧은 발화 제외 ──
  grep -qE $'^TARGET\t.*ㄱㄱ' "$PT" && ng "L4 짧은 발화가 프로브가 됐다" || ok "L4 짧은 발화(<20자) 제외"
  # known-positive: 덤프가 비어 있지 않다 — 위 세 줄이 «빈 파일이라 통과» 가 아님을 증명한다
  # 🟥 `grep -c ... || echo 0` 은 무매치일 때 0 을 두 번 낸다 — 계기 자신에게 난 같은 결함이다.
  # TARGET 은 토큰마다 한 행이다(#idx.k/n) — 발화 수는 고유 idx 로 센다
  NT=$(grep $'^TARGET\t' "$PT" 2>/dev/null | sed -n 's/.*#\([0-9][0-9]*\)\.[0-9]*\/[0-9]* .*/\1/p' | sort -u | grep -c .); case "$NT" in ''|*[!0-9]*) NT=0 ;; esac
  [ "${NT:-0}" -eq 3 ] && ok "L4b TARGET 발화 3 건 (덤프가 공허하지 않다 — known-positive)" \
                       || ng "L4b TARGET 발화 $NT 건 (기대 3) — 위 known-negative 셋이 빈 집합 통과일 수 있다"
  # known-positive: 음성 컨트롤 행이 실제로 생성된다
  grep -q "^NEGATIVE" "$PT" && ok "L4c 음성 컨트롤 행이 생성된다" || ng "L4c 음성 컨트롤 행이 없다"
  grep -q "^CONTROL" "$PT" && ok "L4d 양성 컨트롤 행이 생성된다" || ng "L4d 양성 컨트롤 행이 없다"
else
  ng "L3/L4 프로브 덤프가 안 나왔다 (FH_INTAKE_DUMP_PROBES 미지원)"
fi

# ── L5 음성 컨트롤이 기록에 있으면 rc=10 (계기 사망) ─────────────────────────
cp "$T/rec.md" "$T/rec_neg.md"
printf '\n무작위토큰 FHNEGZZTEST9 가 기록에 섞여 있다\n' >> "$T/rec_neg.md"
OUT5="$(FH_INTAKE_NEG_TOKEN=FHNEGZZTEST9 bash "$SUT" "$T/tr.jsonl" "$T/rec_neg.md" 2>&1)"; RC5=$?
case "$RC5" in 10) ok "L5 음성 컨트롤 적발 → rc=10 (계기 사망)" ;; *) ng "L5 rc=$RC5 (기대 10)"; echo "$OUT5" | sed 's/^/     /' ;; esac
# 🟥 known-negative — 같은 토큰을 주입해도 기록에 **없으면** 10 이 아니어야 한다.
#    이게 없으면 L5 는 「무조건 10 을 내는 계기」와 구분되지 않는다.
OUT5B="$(FH_INTAKE_NEG_TOKEN=FHNEGZZTEST9 bash "$SUT" "$T/tr.jsonl" "$T/rec.md" 2>&1)"; RC5B=$?
[ "$RC5B" != "10" ] && ok "L5b 토큰이 기록에 없으면 rc≠10 (known-negative)" || { ng "L5b 토큰 부재인데도 rc=10"; echo "$OUT5B" | sed 's/^/     /'; }

# ── L6 양성 컨트롤 — 「날짜가 내용에 없다」로 죽으면 안 된다 (sim 이 잡은 넷째) ─────
# 🟥 초판 컨트롤은 «오늘 날짜» 였고 «오늘자 기록엔 오늘 날짜가 있다» 를 가정했다. 거짓이다 —
#    날짜는 파일명에 있지 내용에 있을 의무가 없다. 실측(2026-09-05 sim, WRITECTL 팔): 플로어
#    티어가 만든 `fh_completed_2026-09-05.md` 내용은 한 줄이고 날짜 문자열이 없다.
#    그러면 정상 마감마다 rc=10 거짓 경보가 뜨고, 그 소음이 ❌ 줄을 스킵하게 만든다.
#    ⇒ 컨트롤을 기록 «내용»에서 뽑는다. 아래가 그 known pair 다.
printf '오늘 날짜 문자열이 없는 기록 파일이다 이폴트 추천 등급 기댓값 무인 잡 인큐베이터\n' > "$T/rec_nodate.md"
OUT6="$(bash "$SUT" "$T/tr.jsonl" "$T/rec_nodate.md" 2>&1)"; RC6=$?
[ "$RC6" != "10" ] && ok "L6 날짜가 내용에 없어도 계기가 안 죽는다 (rc=$RC6, 거짓 경보 방지)" \
                   || { ng "L6 날짜 부재만으로 rc=10 — 정상 마감에 거짓 경보"; echo "$OUT6" | sed 's/^/     /'; }
# known-negative 짝: 기록에서 토큰을 못 뽑으면(사실상 빈 기록) **반드시** rc=10 이어야 한다.
printf '\n' > "$T/rec_empty.md"
OUT6B="$(bash "$SUT" "$T/tr.jsonl" "$T/rec_empty.md" 2>&1)"; RC6B=$?
case "$RC6B" in 10) ok "L6b 컨트롤을 못 뽑으면 rc=10 (계기 사망)" ;; *) ng "L6b rc=$RC6B (기대 10)"; echo "$OUT6B" | sed 's/^/     /' ;; esac
case "$OUT6B" in *"전부 착지"*) ng "L6c 계기 사망인데 «전부 착지» 를 인쇄했다" ;; *) ok "L6c 계기 사망일 때 착지 판정을 인쇄하지 않는다" ;; esac
# 파생 컨트롤이 **실제로 생성**되는지 — 이름표만 있고 값이 없으면 위 셋이 공허해진다
FH_INTAKE_DUMP_PROBES="$T/p6.tsv" bash "$SUT" "$T/tr.jsonl" "$T/rec.md" >/dev/null 2>&1
grep -q "기록파생" "$T/p6.tsv" 2>/dev/null && ok "L6d 파생 양성 컨트롤 행이 생성된다" || ng "L6d 파생 컨트롤 행이 없다"

# ── L7 전사본 부재 → UNMEASURED, rc≠0, 「전부 착지」 금지 ────────────────────
OUT7="$(bash "$SUT" "$T/NOPE.jsonl" "$T/rec.md" 2>&1)"; RC7=$?
[ "$RC7" -ne 0 ] && ok "L7 전사본 부재 → rc=$RC7 (0 아님)" || ng "L7 전사본 부재인데 rc=0"
case "$OUT7" in *UNMEASURED*) ok "L7b 전사본 부재가 UNMEASURED 로 라벨된다" ;; *) ng "L7b UNMEASURED 라벨이 없다"; echo "$OUT7" | sed 's/^/     /' ;; esac
case "$OUT7" in *"전부 착지"*) ng "L7c 부재를 «전부 착지» 로 접었다" ;; *) ok "L7c 부재를 0 으로 접지 않는다" ;; esac

# ── L8 추출 발화 0 건 → UNMEASURED (빈 프로브 세트는 합격이 아니다) ─────────
cat > "$T/tr_short.jsonl" <<'JSONL'
{"type":"user","timestamp":"2026-09-05T01:00:00.000Z","message":{"content":"ㄱㄱ"}}
{"type":"user","timestamp":"2026-09-05T01:01:00.000Z","message":{"content":"응 좋아"}}
JSONL
OUT8="$(bash "$SUT" "$T/tr_short.jsonl" "$T/rec.md" 2>&1)"; RC8=$?
[ "$RC8" -ne 0 ] && ok "L8 발화 0 건 → rc=$RC8 (0 아님)" || ng "L8 발화 0 건인데 rc=0"
case "$OUT8" in *UNMEASURED*) ok "L8b 발화 0 건이 UNMEASURED 로 라벨된다" ;; *) ng "L8b UNMEASURED 라벨이 없다"; echo "$OUT8" | sed 's/^/     /' ;; esac

# ── L9 transcript_utterances.py --min-chars known pair ──────────────────────
# 🟥 문턱은 실측으로 골랐다 — 설계안의 40 이 아니라 **20** 이다. 이 레포 전사본 전수
#   (2026-09-05, 봉투/툴결과 제외 후 3191 발화)에서 30–39 자 구간에 하중 지는 발화가 산다:
#   «그리고 입장리뷰는 정적 동적 모두 수행해야해» · «4는 초록으로 올리도록 하자» — 한글은
#   자당 정보량이 커서 40 자 바닥은 **교리 발화를 조용히 버린다**(위험한 방향).
#   20 = 853 건 제외 · 2338 건 보존. 아래 두 줄이 그 문턱의 known pair 다.
N0=$(python3 "$EXTRACT" "$T/tr.jsonl" --min-chars 0  2>/dev/null | grep -c .); case "$N0" in ''|*[!0-9]*) N0=0 ;; esac
N20=$(python3 "$EXTRACT" "$T/tr.jsonl" --min-chars 20 2>/dev/null | grep -c .); case "$N20" in ''|*[!0-9]*) N20=0 ;; esac
[ "${N0:-0}" -eq 4 ] && ok "L9 --min-chars 0 → 4 발화 (known-positive)" || ng "L9 --min-chars 0 → $N0 (기대 4)"
[ "${N20:-0}" -eq 3 ] && ok "L9b --min-chars 20 → 3 발화 (필터가 실제로 거른다)" || ng "L9b --min-chars 20 → $N20 (기대 3)"
# 출력 형식: n<TAB>ts<TAB>text
python3 "$EXTRACT" "$T/tr.jsonl" --min-chars 0 2>/dev/null | head -1 | grep -qE $'^1\t2026-09-05T01:00:00' \
  && ok "L9c tsv 형식이 n<TAB>ts<TAB>text" || ng "L9c tsv 형식이 어긋난다"

# ── L10 seal 출력 골든 — 공용화가 기존 원장을 바꾸지 않았다 ─────────────────
bash "$PROBE" seal --transcript "$T/tr.jsonl" --dir "$T/seal" >/dev/null 2>&1
SF="$(ls "$T/seal"/seal_*.md 2>/dev/null | head -1)"
if [ -n "$SF" ]; then
  sed -n '/^## 운영자 발화/,/^## 이 세션이 건드린/p' "$SF" | sed '$d' > "$T/seal_block.txt"
  cat > "$T/seal_expect.txt" <<'GOLD'
## 운영자 발화 (이 세션)
1. 앞으로 무인 잡은 plist 에 모델을 핀하는 걸 원칙으로 하자
2. ㄱㄱ
3. 등급 기댓값은 분기마다 다시 세우자 이번 분기는 인큐베이터를 과녁으로
4. 이폴트 추천은 세션 시작에 한 번만 띄우고 반복하지 마라 두번은 소음이다

합계: 4건
제외: tool_result 1 · 메타/커맨드 1 · 텍스트없음 0

GOLD
  if diff -u "$T/seal_expect.txt" "$T/seal_block.txt" >"$T/seal_diff.txt" 2>&1; then
    ok "L10 seal 발화 블록이 골든과 바이트 동일"
  else
    ng "L10 seal 발화 블록이 골든과 다르다"; sed 's/^/     /' "$T/seal_diff.txt" | head -20
  fi
else
  ng "L10 seal 파일이 안 생겼다"
fi

# ── L11 compaction_probe.sh --self-test 초록 유지 ───────────────────────────
if bash "$PROBE" --self-test >/dev/null 2>&1; then ok "L11 compaction_probe --self-test 초록"; else ng "L11 compaction_probe --self-test 실패"; fi

# ── L12 되돌림 컨트롤 — 배선이 장식이 아니다 ────────────────────────────────
# 실레포를 안 건드리고, compaction_probe.sh 만 스크래치 트리로 복사해 REPO_ROOT 를 옮긴다.
# 추출기가 **없으면** seal 이 파싱 실패로 떨어져야 한다 = seal 이 정말 그 파일을 통해 돈다.
mkdir -p "$T/mirror/scripts"
cp "$PROBE" "$T/mirror/scripts/compaction_probe.sh"
bash "$T/mirror/scripts/compaction_probe.sh" seal --transcript "$T/tr.jsonl" --dir "$T/seal_rv" >/dev/null 2>&1
SFR="$(ls "$T/seal_rv"/seal_*.md 2>/dev/null | head -1)"
if [ -n "$SFR" ] && grep -q "앞으로 무인 잡은 plist" "$SFR"; then
  ng "L12 추출기가 없는데도 발화가 실렸다 — seal 이 그 파일을 통해 돌지 않는다(배선 장식)"
else
  ok "L12 추출기 제거 → seal 발화 블록이 죽는다 (되돌림 컨트롤)"
fi
# known-positive 짝: 같은 미러에 추출기를 넣으면 살아난다
cp "$EXTRACT" "$T/mirror/scripts/transcript_utterances.py"
bash "$T/mirror/scripts/compaction_probe.sh" seal --transcript "$T/tr.jsonl" --dir "$T/seal_rv2" >/dev/null 2>&1
SFR2="$(ls "$T/seal_rv2"/seal_*.md 2>/dev/null | head -1)"
if [ -n "$SFR2" ] && grep -q "앞으로 무인 잡은 plist" "$SFR2"; then
  ok "L12b 추출기 복원 → 발화가 다시 실린다 (복원 확인 — L12 가 미러 자체의 사망이 아님)"
else
  ng "L12b 추출기를 복원했는데도 발화가 안 실린다 — L12 는 미러 결함이지 되돌림 증거가 아니다"
fi

# ── L13 session_close_check.sh 가 ①-f 를 **실행**한다 (mention 아님) ────────
# 🟥 ①-e 가 아니다 — 그 라벨은 stray-path 가 이미 쓰고 있다(session_close_check.sh:690).
#    임무 진단이 «①-e 는 없다» 고 적었는데 거짓이었고, 이 레인이 «배선 전인데 초록» 으로 잡았다.
if [ -f "$CLOSE" ]; then
  # 🟥 도구를 **설치해서** 돌린다 — 없으면 «skipped, not passed» 로 빠져 배선 자체를 못 잰다.
  #    fakerepo 는 실 전사본 slug 와 안 겹치므로 결과는 결정적으로 UNMEASURED(전사본 부재)다.
  mkdir -p "$T/fakerepo/scripts" && ( cd "$T/fakerepo" && git init -q . 2>/dev/null && git config user.email l@example.invalid && git config user.name lane )
  cp "$SUT" "$EXTRACT" "$ROOT/scripts/utterance_landing_check.sh" "$ROOT/scripts/branch_claim.sh" "$T/fakerepo/scripts/" 2>/dev/null
  OUT13="$(FH_PEER_SOCK_DIR="$T/nosock" bash "$CLOSE" "$T/fakerepo" 2>&1)"
  case "$OUT13" in *"①-f"*) ok "L13 close check 가 ①-f 를 인쇄한다 (실행 확인)" ;; *) ng "L13 close check 출력에 ①-f 가 없다" ;; esac
  # 🟥 «utterance_intake.sh 없음 … UNMEASURED» 분기도 ①-f+UNMEASURED 를 찍는다 — 그 분기로 통과하면
  #    «설치돼서 돌았다» 가 아니라 «없어서 건너뛰었다» 다(codex #9). 설치 분기의 문구를 요구한다.
  case "$OUT13" in
    *"utterance_intake.sh 없음"*) ng "L13b 스크립트를 설치했는데 «없음» 분기로 갔다 (실행이 아니라 skip)" ;;
    *"①-f UNMEASURED"*) ok "L13b 설치 분기에서 ①-f 가 UNMEASURED 로 뜬다 (전사본 부재 / 세션 미상)" ;;
    *) ng "L13b ①-f 가 설치 분기의 UNMEASURED 로 라벨되지 않는다" ;;
  esac
else
  ng "L13 session_close_check.sh 부재"
fi

# ── L14/L15 첫 실사용이 잡은 둘 (2026-09-05) ────────────────────────────────
# 실 전사본에 처음 돌리자 두 결함이 즉시 나왔다 — 레인 29개도 cross-family 도 못 잡던 것들이다
# ([[feedback_adversarial_review_not_substitute_for_first_use]]):
#   ⓐ peer 알림 · 무인 실행 · 이미지 마커가 «운영자 발화» 로 세어졌다
#   ⓑ 라벨에 머신 고유 절대경로(`/var/folders/3h/…`)가 그대로 찍혔다 = 사설 토큰 유출 채널
cat > "$T/tr_sys.jsonl" <<'JSONL'
{"type":"user","timestamp":"2026-09-05T02:00:00.000Z","message":{"content":"[Cross-session delivery notice] peer 세션이 보낸 알림이지 운영자 발화가 아니다"}}
{"type":"user","timestamp":"2026-09-05T02:01:00.000Z","message":{"content":"[automated-run: launchd] 무인 실행 프리앰블이지 운영자 발화가 아니다"}}
{"type":"user","timestamp":"2026-09-05T02:02:00.000Z","message":{"content":"[Image: source: /var/folders/3h/deadbeefcafe/T/shot.png]"}}
{"type":"user","timestamp":"2026-09-05T02:03:00.000Z","message":{"content":"[Image #3] 레드팀 블루팀을 나눠서 단계별로 돌리는 기법을 우리도 쓰는지 궁금하다"}}
JSONL
OUT14="$(FH_INTAKE_DUMP_PROBES="$T/p14.tsv" bash "$SUT" "$T/tr_sys.jsonl" "$T/rec.md" 2>&1)"
if [ -f "$T/p14.tsv" ]; then
  N14=$(grep $'^TARGET\t' "$T/p14.tsv" 2>/dev/null | sed -n 's/.*#\([0-9][0-9]*\)\.[0-9]*\/[0-9]* .*/\1/p' | sort -u | grep -c .); case "$N14" in ''|*[!0-9]*) N14=0 ;; esac
  [ "$N14" -eq 1 ] && ok "L14 시스템 마커 3 건 제외 · 실발화 1 건만 프로브가 된다" \
                   || ng "L14 TARGET $N14 건 (기대 1)"
  grep -q "Cross-session" "$T/p14.tsv" && ng "L14b peer 알림이 프로브가 됐다" || ok "L14b peer 알림 제외 (known-negative)"
  grep -q "automated-run\|launchd" "$T/p14.tsv" && ng "L14c 무인 실행 프리앰블이 프로브가 됐다" || ok "L14c 무인 실행 제외 (known-negative)"
  # known-positive: 마커만 벗기고 **뒤의 실발화는 살린다** — 통째로 버리는 것과 다르다
  grep -q "레드팀" "$T/p14.tsv" && ok "L14d [Image #N] 뒤의 실발화는 살아남는다 (known-positive)" \
                                || ng "L14d 마커 벗기기가 실발화까지 버렸다"
  # ── L15 사설 토큰 마스킹 ──
  grep -q "var/folders\|deadbeefcafe" "$T/p14.tsv" && ng "L15 머신 고유 임시경로가 프로브에 남았다" \
                                                   || ok "L15 임시경로가 마스킹된다"
else
  ng "L14/L15 프로브 덤프가 안 나왔다"
fi
# 🟥 컨트롤: 플래그를 **안 주면** 안 걸러져야 한다. 안 그러면 «원래부터 안 잡히는 입력» 을
#    필터의 공로로 오귀속한다. seal 이 바이트 동일한 이유가 정확히 이것이다.
NRAW=$(python3 "$EXTRACT" "$T/tr_sys.jsonl" --min-chars 20 2>/dev/null | grep -c .); case "$NRAW" in ''|*[!0-9]*) NRAW=0 ;; esac
NSTR=$(python3 "$EXTRACT" "$T/tr_sys.jsonl" --min-chars 20 --strip-system-markers 2>/dev/null | grep -c .); case "$NSTR" in ''|*[!0-9]*) NSTR=0 ;; esac
[ "$NRAW" -eq 4 ] && ok "L15b 플래그 없으면 4 건 전부 통과 (known-negative — 필터가 기본 OFF)" \
                  || ng "L15b 플래그 없이 $NRAW 건 (기대 4) — seal 경로가 이미 오염됐다"
[ "$NSTR" -eq 1 ] && ok "L15c 플래그를 주면 1 건 (필터가 실제로 거른다)" || ng "L15c 플래그 켜고 $NSTR 건 (기대 1)"
# 🟥 홈 경로 마스킹 — HOME 은 러너마다 다르니 값이 아니라 **부재**를 잰다.
printf '%s\n' '{"type":"user","timestamp":"2026-09-05T03:00:00.000Z","message":{"content":"'"$HOME"'/projects/secretrepo 아래 파일을 손봐야 하는데 어떻게 할까 고민이다"}}' > "$T/tr_home.jsonl"
FH_INTAKE_DUMP_PROBES="$T/p15.tsv" bash "$SUT" "$T/tr_home.jsonl" "$T/rec.md" >/dev/null 2>&1
if [ -f "$T/p15.tsv" ]; then
  grep -qF -- "$HOME/projects/secretrepo" "$T/p15.tsv" && ng "L15d 홈 절대경로가 프로브에 남았다" \
                                                       || ok "L15d 홈 절대경로가 마스킹된다"
  grep -q "secretrepo" "$T/p15.tsv" && ok "L15e known-positive: 그 발화 자체는 잡혔다 (빈 파일 통과 아님)" \
                                    || ng "L15e 그 발화가 아예 안 잡혔다 — L15d 는 공허한 통과다"
else
  ng "L15d/e 프로브 덤프가 안 나왔다"
fi

# ── L16 슬래시 커맨드 vs 절대경로 발화 (첫 실사용이 잡은 셋째) ──────────────
# 옛 규칙 `startswith('/')` 은 «/Users/…/OT.pptx.pdf 이건 발표자 ot자료인데…» 를 커맨드로
# 오분류해 **무음 삭제**했다. 실측: `/` 접두 28 건 중 13 건(46%)이 경로형 실발화.
cat > "$T/tr_slash.jsonl" <<'JSONL'
{"type":"user","timestamp":"2026-09-05T04:00:00.000Z","message":{"content":"/compact"}}
{"type":"user","timestamp":"2026-09-05T04:01:00.000Z","message":{"content":"/install-wizard --dry-run 으로 먼저 돌려보고 결과를 보자 그 다음에 결정하면 된다"}}
{"type":"user","timestamp":"2026-09-05T04:02:00.000Z","message":{"content":"/srv/tester/Downloads/발표자료.pdf 이건 발표자 오티 자료인데 이걸 기준으로 초안을 잡자"}}
JSONL
NS_OFF=$(python3 "$EXTRACT" "$T/tr_slash.jsonl" --min-chars 20 2>/dev/null | grep -c .); case "$NS_OFF" in ''|*[!0-9]*) NS_OFF=0 ;; esac
NS_ON=$(python3 "$EXTRACT" "$T/tr_slash.jsonl" --min-chars 20 --strip-system-markers 2>/dev/null | grep -c .); case "$NS_ON" in ''|*[!0-9]*) NS_ON=0 ;; esac
[ "$NS_OFF" -eq 0 ] && ok "L16 플래그 없으면 셋 다 커맨드로 제외 (옛 규칙 = seal 경로, 컨트롤)" \
                    || ng "L16 플래그 없이 $NS_OFF 건 남았다 (기대 0) — seal 행동이 바뀌었다"
[ "$NS_ON" -eq 1 ] && ok "L16b 플래그를 주면 경로형 실발화 1 건만 살아난다" || ng "L16b 플래그 켜고 $NS_ON 건 (기대 1)"
python3 "$EXTRACT" "$T/tr_slash.jsonl" --min-chars 20 --strip-system-markers 2>/dev/null | grep -q "발표자 오티" \
  && ok "L16c 살아난 것이 **경로형 실발화** 다 (known-positive)" || ng "L16c 엉뚱한 것이 살아났다"
python3 "$EXTRACT" "$T/tr_slash.jsonl" --min-chars 20 --strip-system-markers 2>/dev/null | grep -q "install-wizard" \
  && ng "L16d 진짜 슬래시 커맨드가 살아남았다" || ok "L16d 진짜 슬래시 커맨드는 여전히 제외 (known-negative)"

# ── L17 압축 이어붙임 프리앰블 (첫 실사용이 잡은 다섯째) ────────────────────
# 대괄호로 시작하지 않아 L14 규칙이 **구조적으로** 못 잡는다. 실측 21 건, 실전 미착지 목록에 등장.
cat > "$T/tr_cont.jsonl" <<'JSONL'
{"type":"user","timestamp":"2026-09-05T05:00:00.000Z","message":{"content":"This session is being continued from a previous conversation that ran out of context. The summary below covers the earlier portion."}}
{"type":"user","timestamp":"2026-09-05T05:01:00.000Z","message":{"content":"이건 진짜 운영자 발화다 등급 기댓값을 분기마다 다시 세우자고 했던 그 이야기"}}
JSONL
NC_ON=$(python3 "$EXTRACT" "$T/tr_cont.jsonl" --min-chars 20 --strip-system-markers 2>/dev/null | grep -c .); case "$NC_ON" in ''|*[!0-9]*) NC_ON=0 ;; esac
NC_OFF=$(python3 "$EXTRACT" "$T/tr_cont.jsonl" --min-chars 20 2>/dev/null | grep -c .); case "$NC_OFF" in ''|*[!0-9]*) NC_OFF=0 ;; esac
[ "$NC_ON" -eq 1 ] && ok "L17 압축 프리앰블 제외 · 실발화 1 건만 남는다" || ng "L17 플래그 켜고 $NC_ON 건 (기대 1)"
[ "$NC_OFF" -eq 2 ] && ok "L17b 플래그 없으면 둘 다 통과 (컨트롤 — seal 행동 불변)" || ng "L17b 플래그 없이 $NC_OFF 건 (기대 2)"
python3 "$EXTRACT" "$T/tr_cont.jsonl" --min-chars 20 --strip-system-markers 2>/dev/null | grep -q "등급 기댓값" \
  && ok "L17c 남은 것이 실발화다 (known-positive)" || ng "L17c 실발화까지 버렸다"

# ── L18 ①-f **행복 경로** — 전사본과 기록이 다 있을 때 실제로 판정까지 간다 ────
# 🟥 L13/L13b 는 UNMEASURED 가지만 잰다. 그것만 있으면 «①-f 가 늘 UNMEASURED 를 내는 블록» 과
#    구분이 안 된다 — 존재 확인이지 판별력 확인이 아니다
#    (`[[feedback_control_presence_is_not_discrimination]]`).
if [ -f "$CLOSE" ] && [ -d "$T/fakerepo" ]; then
  mkdir -p "$T/fakerepo/tracks/_meta" "$T/trdir"
  # 오늘자 기록 — 착지 1 · 미착지 1 이 되게 만든다
  { echo "# fh_completed_$TODAY.md"; echo "- ✅ 무인 잡 plist 에 모델을 핀했다 — launchd 3종 전부"; } \
    > "$T/fakerepo/tracks/_meta/fh_completed_$TODAY.md"
  mk_transcript "$T/trdir/LANESESSION.jsonl"
  OUT18="$(FH_PEER_SOCK_DIR="$T/nosock" FH_CLAIM_TEST=1 FH_CLAIM_SESSION=LANESESSION \
           FH_TRANSCRIPT_DIR="$T/trdir" bash "$CLOSE" "$T/fakerepo" 2>&1)"; RC18=$?
  case "$OUT18" in *"①-f 미착지 발화가 있다"*) ok "L18 ①-f 가 실제로 판정까지 간다 (미착지 분기)" ;;
    *) ng "L18 ①-f 가 판정 분기에 도달하지 못했다"; printf '%s\n' "$OUT18" | grep -A4 "①-f" | sed 's/^/     /' ;; esac
  case "$OUT18" in *"이폴트 추천"*) ok "L18b 미착지 발화가 마감 출력에 그대로 뜬다" ;; *) ng "L18b 미착지 목록이 마감 출력에 없다" ;; esac
  # 🟥 advisory 다 — ①-f 때문에 close check 가 «VIOLATIONS» 로 뒤집히면 안 된다.
  #    그러면 정상 마감이 막히고 그게 --no-verify 를 훈련시킨다.
  case "$OUT18" in *"①-f"*) _seen=1 ;; *) _seen=0 ;; esac
  OUT18B="$(FH_PEER_SOCK_DIR="$T/nosock" FH_CLAIM_TEST=1 FH_CLAIM_SESSION=NOSUCHSESSION \
            FH_TRANSCRIPT_DIR="$T/trdir" bash "$CLOSE" "$T/fakerepo" 2>&1)"; RC18B=$?
  V18=$(printf '%s\n' "$OUT18"  | grep -c '^❌'); case "$V18"  in ''|*[!0-9]*) V18=0 ;; esac
  V18B=$(printf '%s\n' "$OUT18B" | grep -c '^❌'); case "$V18B" in ''|*[!0-9]*) V18B=0 ;; esac
  [ "$V18" -eq "$V18B" ] && ok "L18c ①-f 는 ❌ 개수를 늘리지 않는다 (advisory — 미착지 유무로 불변)" \
                         || ng "L18c ①-f 가 close check 판정을 바꿨다 (미착지 $V18 vs 전사본없음 $V18B)"
  [ "$_seen" -eq 1 ] && ok "L18d known-positive: 그 실행에 ①-f 가 실제로 있었다" || ng "L18d ①-f 자체가 안 떴다 — L18c 는 공허하다"
  # ❌ 개수만 보면 «같은 출력 + exit 1» 회귀를 못 잡는다(codex #8) — exit code 도 같아야 advisory 다
  [ "${RC18:-x}" = "${RC18B:-y}" ] && ok "L18e ①-f 는 close check exit code 도 바꾸지 않는다 (rc $RC18 = $RC18B)" \
                                    || ng "L18e exit code 가 달라졌다 (미착지 $RC18 vs 전사본없음 $RC18B)"
  # L13c — 스크립트가 없으면 «없음 — skipped, not passed» 로 표시된다 (L13b 의 반대쪽)
  rm -f "$T/fakerepo/scripts/utterance_intake.sh"
  OUT13C="$(FH_PEER_SOCK_DIR="$T/nosock" FH_CLAIM_TEST=1 FH_CLAIM_SESSION=LANESESSION \
            FH_TRANSCRIPT_DIR="$T/trdir" bash "$CLOSE" "$T/fakerepo" 2>&1)"
  case "$OUT13C" in *"utterance_intake.sh 없음"*) ok "L13c 스크립트 부재 → «없음 — skipped, not passed» (known-negative)" ;; *) ng "L13c 부재를 표시하지 않는다" ;; esac
else
  ng "L18 fakerepo 준비 안 됨"
fi

# ── L19 발화 판정은 토큰 과반 — 주제어 하나가 겹친다고 착지가 아니다 (codex #1) ──
cat > "$T/tr19.jsonl" <<'JSONL'
{"type":"user","timestamp":"2026-09-05T05:00:00.000Z","message":{"content":"쿠버네티스 배포는 승인자두명 카나리지표 장애예산 셋이 모두 맞을 때만 열자"}}
JSONL
printf '%s\n' '- 오늘 쿠버네티스 버전만 확인했다 (주제어 하나만 겹친다 — 정책은 안 적혔다)' > "$T/rec19a.md"
OUT19="$(bash "$SUT" "$T/tr19.jsonl" "$T/rec19a.md" 2>&1)"; RC19=$?
[ "$RC19" -eq 1 ] && ok "L19 주제어 하나만 겹치면 미착지 (rc=1)" || { ng "L19 rc=$RC19 (기대 1) — 낱말 하나로 착지 처리"; echo "$OUT19" | sed 's/^/     /'; }
case "$OUT19" in *"쿠버네티스 배포는"*) ok "L19b 그 발화가 미착지 목록에 있다" ;; *) ng "L19b 미착지 목록에 없다" ;; esac
printf '%s\n' '- 배포 정책: 승인자두명 확인 + 카나리지표 통과 + 장애예산 잔여 — 셋 다 맞을 때만' > "$T/rec19b.md"
OUT19B="$(bash "$SUT" "$T/tr19.jsonl" "$T/rec19b.md" 2>&1)"; RC19B=$?
[ "$RC19B" -eq 0 ] && ok "L19c CONTROL 토큰 3 중 2 이상 겹치면 착지 (rc=0)" || { ng "L19c rc=$RC19B (기대 0)"; echo "$OUT19B" | sed 's/^/     /'; }

# ── L20 프로브불가 발화는 «못 쟀다» — 미착지 0 이어도 rc=0 이 아니다 (codex #2) ──
cat > "$T/tr20.jsonl" <<'JSONL'
{"type":"user","timestamp":"2026-09-05T05:10:00.000Z","message":{"content":"그리고 그러니까 그래서 그러면 그런데 이렇게 그렇게 어떻게 하지만 그러나 마찬가지 이야기"}}
{"type":"user","timestamp":"2026-09-05T05:11:00.000Z","message":{"content":"앞으로 무인 잡은 plist 에 모델을 핀하는 걸 원칙으로 하자"}}
JSONL
OUT20="$(bash "$SUT" "$T/tr20.jsonl" "$T/rec.md" 2>&1)"; RC20=$?
[ "$RC20" -eq 1 ] && ok "L20 프로브불가 1 + 착지 1 → rc=1 (미측정은 착지가 아니다)" || { ng "L20 rc=$RC20 (기대 1)"; echo "$OUT20" | sed 's/^/     /'; }
case "$OUT20" in *"프로브불가 1 건"*) ok "L20b 프로브불가 발화가 목록으로 뜬다" ;; *) ng "L20b 프로브불가 목록이 없다" ;; esac
case "$OUT20" in *"착지 1 · 미착지 0"*) ok "L20c CONTROL 다른 발화는 착지로 센다 (rc=1 이 미착지 탓이 아님)" ;; *) ng "L20c 착지/미착지 계수가 기대와 다르다"; echo "$OUT20" | sed 's/^/     /' ;; esac

# ── L21 라벨·프로브의 사설 토큰 마스킹은 $HOME 만이 아니다 (codex #5) ──
cat > "$T/tr21.jsonl" <<'JSONL'
{"type":"user","timestamp":"2026-09-05T05:20:00.000Z","message":{"content":"/srv/bob/projects/acme-secret/prod.env 에 있는 DB_HOST=db01.internal 값을 기록하지 말고 비교만 해줘"}}
JSONL
OUT21="$(FH_INTAKE_DUMP_PROBES="$T/p21.tsv" bash "$SUT" "$T/tr21.jsonl" "$T/rec.md" 2>&1)"
if [ -f "$T/p21.tsv" ]; then
  for _tok in bob acme-secret prod.env db01 internal; do
    grep -q -- "$_tok" "$T/p21.tsv" && ng "L21 사설 토큰 '$_tok' 이 프로브/라벨에 남았다" || ok "L21 '$_tok' 마스킹"
  done
  printf '%s\n' "$OUT21" | grep -q -- "acme-secret\|db01" && ng "L21b 출력(미착지 목록)에 사설 토큰이 찍혔다" || ok "L21b 출력에도 없다"
  grep -q "기록하지" "$T/p21.tsv" && ok "L21c known-positive: 그 발화 자체는 프로브가 됐다" || ng "L21c 발화가 아예 안 잡혔다 — L21 은 공허하다"
else
  ng "L21 프로브 덤프가 안 나왔다"
fi

# ── L22 기록이 짧아 양성 컨트롤을 못 만들면 UNMEASURED(rc=10), 착지 판정 없음 (codex #7) ──
printf '%s\n' '하네스 배선 착지' > "$T/rec22.md"
OUT22="$(bash "$SUT" "$T/tr.jsonl" "$T/rec22.md" 2>&1)"; RC22=$?
[ "$RC22" -eq 10 ] && ok "L22 컨트롤 재료 없음 → rc=10" || { ng "L22 rc=$RC22 (기대 10)"; echo "$OUT22" | sed 's/^/     /'; }
case "$OUT22" in *"양성 컨트롤 토큰을 못 뽑았다"*) ok "L22b 사유가 «컨트롤 재료 없음» 으로 명명된다 (계기 사망과 구분)" ;; *) ng "L22b 사유 문구 없음" ;; esac
case "$OUT22" in *"전부 착지"*) ng "L22c 컨트롤 없이 «전부 착지» 를 찍었다" ;; *) ok "L22c 착지 판정을 내지 않는다" ;; esac

# ── L23 런타임이 isMeta/isSidechain 으로 표시한 레코드는 발화가 아니다 (codex #4) ──
cat > "$T/tr23.jsonl" <<'JSONL'
{"type":"user","isMeta":true,"timestamp":"2026-09-05T05:30:00.000Z","message":{"content":"작업 큐 알림 재시도 필요 메타표시레코드 본문이다 발화가 아니다"}}
{"type":"user","isSidechain":true,"timestamp":"2026-09-05T05:31:00.000Z","message":{"content":"사이드체인 서브에이전트 대화 본문이다 운영자 발화가 아니다"}}
{"type":"user","timestamp":"2026-09-05T05:32:00.000Z","message":{"content":"같은 문장인데 표시가 없는 이 줄은 운영자 발화라 남아야 한다"}}
JSONL
N23=$(python3 "$EXTRACT" "$T/tr23.jsonl" --min-chars 20 2>/dev/null | grep -c .); case "$N23" in ''|*[!0-9]*) N23=0 ;; esac
[ "$N23" -eq 1 ] && ok "L23 isMeta·isSidechain 레코드 제외 · 표시 없는 1 건만 남는다" || ng "L23 $N23 건 (기대 1)"
python3 "$EXTRACT" "$T/tr23.jsonl" --min-chars 20 2>/dev/null | grep -q "표시가 없는" && ok "L23b known-positive: 남은 것이 표시 없는 발화다" || ng "L23b 표시 없는 발화까지 버렸다"
python3 "$EXTRACT" "$T/tr23.jsonl" --min-chars 20 2>/dev/null | grep -q "메타표시레코드\|사이드체인" && ng "L23c 표시된 레코드가 살아남았다" || ok "L23c 표시된 레코드는 없다 (known-negative)"

# ── L24  키 선택: 별칭 + 길이 대역 (2026-09-16) ──────────────────────────────
# WHY. 「가장 긴 토큰 3 개」 휴리스틱이 **붙여쓴 절**을 키로 고른다 — 절은 정의상 가장 길고
# 기록에 축자로 다시 나올 확률은 가장 낮다. 09-15 전사본 실측에서 미착지 고유 키 59 중
# ~42(71%)가 이 부류였고, 09-15 기록이 스스로 지목한 「음차 별칭」은 2~3(5%)뿐이었다.
# 그래서 수리는 두 축이다: ⓐ 표기 별칭(교대) ⓑ 한글 키 길이 대역 + 삼켜진 고유명사 꺼내기.
# 🟥 두 축이 **같이** 있어야 듣는다 — 각각은 ⌈n/2⌉ 를 못 넘긴다(한쪽만 켜면 키 3 중 1).
_probes() {  # $1=발화 텍스트 → probes 의 TARGET 패턴들(한 줄에 하나)
  printf '1\t2026-09-16T00:00:00Z\t%s\n' "$1" \
    | "$SUT_PROBE_RUNNER" 2>/dev/null | awk -F'\t' '$1=="TARGET"{print $2}'
}
# mkprobes.py 를 SUT 에서 **그대로 뽑아** 돌린다 — 두 번째 사본을 쓰면 관대함이 갈린다
# ([[feedback_divergent_leniency_duplicate_normalizers]]).
awk "/^  cat > \"\\\$_py\" <<'PY'\$/{f=1;next} /^PY\$/{f=0} f" "$SUT" > "$T/mkprobes_sut.py"
if [ ! -s "$T/mkprobes_sut.py" ]; then
  echo "❌ L24-setup mkprobes.py 추출 실패 — SUT 의 heredoc 앵커가 바뀌었다 (계기 오류)"
  FAIL=$((FAIL+1))
else
  SUT_PROBE_RUNNER="$T/run_mkprobes.sh"
  { echo '#!/usr/bin/env bash'; echo "exec python3 \"$T/mkprobes_sut.py\" \"$T/l24.map\""; } > "$SUT_PROBE_RUNNER"
  chmod +x "$SUT_PROBE_RUNNER"

  # L24  별칭이 교대로 나간다 — `데스크탑` 키가 `Desktop` 도 본다
  _probes '클로드 데스크탑앱에서 한번 테스트해봤는데 춘식이 반응이 움직이네' > "$T/l24.out"
  grep -q 'Desktop' "$T/l24.out" \
    && ok "L24 음차 별칭이 교대로 나간다 (데스크탑 → Desktop)" \
    || ng "L24 별칭 교대 없음 — $(tr '\n' ' ' < "$T/l24.out")"

  # L24b known-negative: 별칭표에 없는 일반어는 **맨 토큰 그대로** 나간다.
  #   표를 일반어로 넓히면 우연 일치가 늘고, 이 검사는 advisory 라 거짓 착지가 조용한 쪽이다.
  _probes '오늘은 그 배선을 확실하게 정리하고 나서 넘어가려고 한다 지금' > "$T/l24b.out"
  grep -q '(' "$T/l24b.out" \
    && ng "L24b 일반어에 교대가 붙었다 — 별칭표가 넓다: $(tr '\n' ' ' < "$T/l24b.out")" \
    || ok "L24b known-negative: 별칭 없는 토큰은 맨 토큰 그대로"

  # L24c  붙여쓴 절이 키 1군에서 밀린다 — `이건이미끝난것같은데`(10자) 는 대역 밖
  _probes '이건이미끝난것같은데 담당팀에서 대기실 테스트 돌리는 중이고 배선도 끝났다' > "$T/l24c.out"
  grep -qx '이건이미끝난것같은데' "$T/l24c.out" \
    && ng "L24c 붙여쓴 절이 여전히 1군 키다 — 대역이 안 먹었다" \
    || ok "L24c 붙여쓴 절(10자)이 대역 밖으로 밀린다"

  # L24d  절에 삼켜진 고유명사를 꺼낸다 — `그리고프렌즈온데스크` → `프렌즈온데스크`
  #   🟥 이게 없으면 별칭표가 토큰 경계를 못 넘어 무용지물이 된다(실측 미착지 4 건이 이 모양).
  _probes '그리고프렌즈온데스크 릴리즈는 어제 판이라 다시 구워야 맞을 것 같은데' > "$T/l24d.out"
  grep -q 'friends-on-desk' "$T/l24d.out" \
    && ok "L24d 절에 삼켜진 고유명사를 꺼낸다 (그리고프렌즈온데스크 → 프렌즈온데스크)" \
    || ng "L24d 삼켜진 고유명사 미추출 — $(tr '\n' ' ' < "$T/l24d.out")"

  # L24e  긴 고유명사는 대역 상한의 **예외**다 — `프렌즈온데스크`(7자) 가 죽으면 안 된다.
  #   길이 상한만 두면 실제로 착지하던 키가 같이 죽는다(대역의 부작용, 명시적으로 막는다).
  _probes '프렌즈온데스크 쪽은 그대로 두고 나머지만 먼저 정리하자 오늘은' > "$T/l24e.out"
  grep -q '프렌즈온데스크' "$T/l24e.out" \
    && ok "L24e 별칭 등재 고유명사는 길이 상한 예외 (7자 생존)" \
    || ng "L24e 긴 고유명사가 대역에 죽었다 — $(tr '\n' ' ' < "$T/l24e.out")"

  # L24f  되돌림 프로브 — 별칭표를 비우면 L24/L24d 가 **정확히** 빨개진다.
  #   🟥 앵커가 장식이 아님을 증명하는 유일한 방법이다([[feedback_anchor_can_be_decorative]]).
  # 🟥 뮤테이션은 «텍스트가 바뀌었나» 가 아니라 «의미가 바뀌었나» 로 확인한다.
  #    초판은 `ALIAS = {} or {`(파이썬에서 뒤 딕셔너리로 평가 = **무효 뮤턴트**)를 썼고,
  #    텍스트 grep 은 통과했다. 그때 이 레인이 초록이었던 이유는 앵커가 살아서가 아니라
  #    **대상이 깨져 있어서**였다 — [[feedback_three_reasons_a_lane_is_green]] 의 ②.
  sed 's/^_META = re.compile/ALIAS = {}\'$'\n''_META = re.compile/' "$T/mkprobes_sut.py" > "$T/mkprobes_neutered.py"
  _applied=$(printf '1\t2026-09-16T00:00:00Z\t%s\n' '프렌즈온데스크 쪽은 그대로 두고 나머지만 먼저 정리하자 오늘' \
             | python3 "$T/mkprobes_neutered.py" "$T/l24f0.map" 2>/dev/null | awk -F'\t' '$1=="TARGET"{print $2}')
  case "$_applied" in
    ''|*'friends-on-desk'*) ng "L24f 되돌림 **의미** 적용 실패 — 뮤턴트가 여전히 별칭을 낸다/죽었다 (계기 오류)" ;;
    *)
    _n_out=$(printf '1\t2026-09-16T00:00:00Z\t%s\n' '클로드 데스크탑앱에서 한번 테스트해봤는데 춘식이 반응이 움직이네' \
             | python3 "$T/mkprobes_neutered.py" "$T/l24f.map" 2>/dev/null | awk -F'\t' '$1=="TARGET"{print $2}')
    case "$_n_out" in
      *Desktop*) ng "L24f 별칭표를 비웠는데도 Desktop 이 나온다 — 앵커가 장식이다" ;;
      '')        ng "L24f 뮤턴트가 출력 0 — 되돌림이 스크립트를 죽였다(레인 무효)" ;;
      *)
        # 🟥 L24d 의 되돌림도 같이 본다 (cross-family codex, B2). 초판은 `Desktop` 소멸만 봐서
        #    「삼켜진 고유명사 추출이 죽는가」는 **검증하지 않았다** — 레인 주석이 주장하는 범위와
        #    실제 검사 범위가 어긋난 자리다([[feedback_rule_misdescribes_its_own_machine]]).
        _n_d=$(printf '1\t2026-09-16T00:00:00Z\t%s\n' '그리고프렌즈온데스크 릴리즈는 어제 판이라 다시 구워야 맞을 것 같은데' \
               | python3 "$T/mkprobes_neutered.py" "$T/l24f2.map" 2>/dev/null | awk -F'\t' '$1=="TARGET"{print $2}')
        case "$_n_d" in
          *friends-on-desk*|*'|'*) ng "L24f 뮤턴트인데 삼켜진 고유명사 추출이 살아 있다" ;;
          '')                      ng "L24f 뮤턴트 출력 0 (레인 무효)" ;;
          *) ok "L24f 되돌림: 교대 **와** 삼켜진-고유명사 추출이 함께 사라진다 (앵커 생존)" ;;
        esac
        ;;
    esac
    ;;
  esac

  # L24g  ALIAS 값에 ERE 메타문자가 섞이면 **죽는다** — 조용히 거르지 않는다.
  #   정규식으로 새면 TARGET 의 의미가 바뀌고, 그건 「미착지」가 아니라 계기 고장이다.
  sed "s/^    '오르카':.*/    '오르카': ['or(ca'],/" "$T/mkprobes_sut.py" > "$T/mkprobes_meta.py"
  printf '1\t2026-09-16T00:00:00Z\t%s\n' '오르카 워크트리를 하나 더 띄워서 거기서 돌리자 오늘' \
    | python3 "$T/mkprobes_meta.py" "$T/l24g.map" >/dev/null 2>&1
  [ "$?" -eq 10 ] \
    && ok "L24g ALIAS 에 ERE 메타문자 → rc=10 (계기 고장이지 미착지가 아니다)" \
    || ng "L24g 메타문자가 조용히 통과했다"

  # L24h  A1 회귀 — 포함 일치일 때 **짧은 한글 이름**이 교대에 들어가면 안 된다.
  #   `(데스크탑앱|데스크탑|Desktop)` 은 더 흔한 `데스크탑` 으로 착지를 성립시킨다 =
  #   조용한 거짓 착지. 교대가 날라야 하는 것은 **표기 변형**이지 더 넓은 한국어 낱말이 아니다.
  _probes '클로드 데스크탑앱에서 한번 테스트해봤는데 춘식이 반응이 움직이네' > "$T/l24h.out"
  if grep -q 'Desktop' "$T/l24h.out" && ! grep -qE '\(데스크탑앱\|데스크탑\|' "$T/l24h.out"; then
    ok "L24h A1: 포함 일치 교대에 짧은 한글 이름이 없다 (Desktop 만 더한다)"
  else
    ng "L24h A1 회귀 — $(tr '\n' ' ' < "$T/l24h.out")"
  fi

  # L24i  B1 회귀 — 부분 문자열 충돌. `오픈코드리뷰` 는 `오픈코드`(opencode) 가 아니다.
  #   남는 쪽(`리뷰`)이 허용 접미사가 아니므로 교대를 붙이지 않는다.
  _probes '오픈코드리뷰 기준은 여기서 따로 정하자 오늘 우리끼리' > "$T/l24i.out"
  grep -q 'opencode' "$T/l24i.out" \
    && ng "L24i B1 회귀 — `오픈코드리뷰` 를 opencode 로 오인했다: $(tr '\n' ' ' < "$T/l24i.out")" \
    || ok "L24i B1: 부분 문자열 충돌(오픈코드리뷰)에 교대를 안 붙인다"

  # L24i-b  known-positive 짝 — 허용 접미사는 **여전히 붙어야** 한다. 없으면 L24i 는
  #   「아무것도 안 붙인다」로도 초록이 되어 판별력이 없다.
  _probes '데스크탑앱 쪽 설정만 먼저 보고 나머지는 내일 정리하자 오늘은' > "$T/l24ib.out"
  grep -q 'Desktop' "$T/l24ib.out" \
    && ok "L24i-b known-positive: 허용 접미사(앱)는 여전히 교대가 붙는다" \
    || ng "L24i-b 경계 방어가 정상 파생어까지 죽였다 — $(tr '\n' ' ' < "$T/l24ib.out")"

  # L24j  A2 회귀 — 3 개를 넘겨 잘린 키를 **센다**. 「미측정을 0 으로」 접지 않는다.
  #   대역 정렬이 들어오면서 붙여쓴 하중 절이 체계적으로 잘리게 됐고, 그 드롭이 조용하면
  #   남은 흔한 셋으로 발화가 「착지」로 렌더된다 = 이 수리가 만든 fail-open.
  _drop=$(printf '1\t2026-09-16T00:00:00Z\t%s\n' '절대자동승격하지마라 담당팀 대기실 배선도 테스트 먼저 보자 오늘' \
          | "$SUT_PROBE_RUNNER" 2>&1 >/dev/null | grep -o '키드롭=[0-9]*')
  case "$_drop" in
    키드롭=0|'') ng "L24j A2: 드롭이 0 으로 보고됐다 (조용한 드롭) — [$_drop]" ;;
    *)           ok "L24j A2: 잘린 키를 센다 ($_drop)" ;;
  esac
fi

echo
echo "── utterance-intake lanes: PASS=$PASS FAIL=$FAIL ──"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
