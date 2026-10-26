#!/usr/bin/env bash
# abstract_consult_check.py 레인 — 아는 쌍(걸려야 할 질문 / 통과해야 할 질문)을 같은 실행에 둔다.
# 🟥 게이트는 «막나» 와 «정상 질문을 안 막나» 를 같이 잰다 — 역할로 바꾼 질문까지 막으면 이 길은 쓸모가 없다.
# 사전은 픽스처다(/usr/share/dict/words 가 없는 CI 에서도 같은 판정). 실제 사전 · 실제 레포 과차단 비율은 D2 가 잰다.
# rc 계약: 0 = clean · 1 = hit · 3 = NOT SCANNED
set -uo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
C="$HERE/abstract_consult_check.py"
T=$(mktemp -d -t acc.XXXXXX) || exit 3
trap 'rm -rf "$T"' EXIT
PASS=0; FAIL=0
chk() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); printf '  ✅ %-58s %s\n' "$1" "$2"; else FAIL=$((FAIL+1)); printf '  ❌ %-58s got=%s want=%s\n' "$1" "$2" "$3"; fi; }

R="$T/repo"; mkdir -p "$R/src"
git -C "$R" init -q -b main
cat > "$R/src/settle.py" <<'EOF'
import requests
ZQPAY_HOST = "pg-settle-01.shop.internal"
def processPayment(order):
    return requests.post("https://" + ZQPAY_HOST + "/zqpayGateway/approve", json={"order": order, "retry": 3})
    if order is None: return retry(order, safe)
ALT = "settle.internal"
EOF
echo 'VelnoraKey = 1' > "$R/src/secret.py"
python3 -c "import sys; open(sys.argv[1],'w').write('QuorvexId = 1\n' + 'x = 1\n' * 400000)" "$R/big.txt"
echo '{}' > "$R/config.json"
printf 'MSGS = ["tHe", "bE", "iT"]\nusingMappedValues = 1\nnumericWhitespaceTable = 2\nmapness = 3\nmappes = 4\nEDGE = "getSetGetSetGetSetGetSetGetSetGetSet.internal"\n' > "$R/src/strings.py"
ln -s /private/QorvianLink/settings.py "$R/linked.py"
git -C "$R" add -A
git -C "$R" -c user.name="Jimin Parkova" -c user.email="jparkova@shop.example" commit -qm init
echo "# notes" > "$R/NOTES.md"; git -C "$R" add NOTES.md
git -C "$R" -c user.name="test" -c user.email="test@t" commit -qm notes
echo "# more" >> "$R/NOTES.md"; git -C "$R" add NOTES.md
git -C "$R" -c user.name="Sora M. Kitavane" -c user.email="sk@shop.example" commit -qm more

cat > "$T/dict" <<'EOF'
a
about
approval
approve
call
shop
external
gate
gateway
handle
host
how
import
internal
is
order
park
payment
post
process
request
retry
return
safe
safely
service
settle
should
slow
test
the
this
timeout
way
why
wrapper
write
around
fail
none
notes
use
map
value
EOF
printf '#!/bin/bash\necho "  ✅ outbound clean" >&2\nexit 0\n' > "$T/g0.sh"
printf '#!/bin/bash\nexit 1\n' > "$T/g1.sh"
printf '#!/bin/bash\nexit 3\n' > "$T/g3.sh"
printf '#!/bin/bash\n[ "${OUTBOUND_QUERY_OK:-0}" = 1 ] && { echo "  ✅ outbound clean" >&2; exit 0; }\nexit 1\n' > "$T/gok.sh"
: > "$T/gempty.sh"

kinds() { python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(",".join(sorted({h["kind"] for h in d.get(sys.argv[2],[])})))' "$T/out" "$1"; }
run() { # run <question> [extra args...] → rc
  local q=$1; shift
  printf '%s' "$q" > "$T/q"
  python3 "$C" check --repo "$R" --question-file "$T/q" --dict "$T/dict" --guard "$T/g0.sh" --ledger "$T/ledger.jsonl" "$@" >"$T/out" 2>"$T/err"
  echo $?
}

echo "── 통과해야 할 것(과차단 컨트롤) ──"
chk "A1 역할로 바꾼 질문 → clean"  "$(run 'How should a retry wrapper around an external payment approval call handle timeouts?')" 0
chk "A5n 산문 «process payment» → clean"  "$(run 'how to process payment safely')" 0
chk "A7n 한 낱말 작성자 «test» 는 사전 낱말을 막지 않는다"  "$(run 'test the gate')" 0
chk "A7n2 굴절형(requests · returns) → clean"  "$(run 'the service returns none when requests time out')" 0

echo "── 걸려야 할 것 ──"
chk "A2 불투명 식별자 그대로"  "$(run 'Why does zqpayGateway approve fail')" 1
chk "A3 대소문자 · 띄어 쓴 불투명 식별자"  "$(run 'the ZQPAY gate way returns 500')" 1
chk "A4 불투명 조각 하나만(zqpay)"  "$(run 'the zqpay service is slow')" 1
chk "A5 낱말 합성 식별자 → 막지 않고 flags(compound)"  "$(run 'processPayment returns None')/$(kinds flags)" "0/compound"
chk "A6 호스트명을 띄어 씀"  "$(run 'host pg settle 01 shop internal is slow')" 1
chk "A6b 호스트명 그대로"  "$(run 'host pg-settle-01.shop.internal is slow')" 1
chk "A7 작성자 이름(여러 낱말)"  "$(run 'Jimin Parkova wrote this')" 1
chk "A7b 작성자 메일"  "$(run 'ask jparkova@shop.example about it')" 1
chk "A8 원문 코드 조각(이름 섞임)"  "$(run 'return requests.post("https://" + ZQPAY_HOST')" 1

echo "── codex R1 (2026-10-26) ──"
rm "$R/src/secret.py"     # 작업 트리에서만 지움 — 추적 파일의 이름은 마지막 커밋본에서 읽어야 한다
chk "X1 합성 식별자 대문자 · 밑줄 표기 → flags"  "$(run 'PROCESSPAYMENT returns None')$(kinds flags)/$(run 'process_payment returns None')$(kinds flags)" "0compound/0compound"
chk "X2 불투명 이름의 복수형"  "$(run 'Why do zqpays fail?')" 1
chk "X3 순서를 바꾼 작성자 이름"  "$(run 'Parkova, Jimin wrote this; is the approach safe?')" 1
chk "X4 두 조각 호스트명"  "$(run 'Why is host SETTLE.INTERNAL slow?')" 1
chk "X4n 파일 이름(config.json)은 호스트 · 합성 · flags 어디에도 안 든다"  "$(run 'why is config.json slow')/$(kinds hits)/$(kinds flags)" "0//"
chk "X5 작업 트리에서 지운 추적 파일 속 이름"  "$(run 'Why does VelnoraKey fail?')" 1
chk "X5b 1MiB 넘는 파일 앞부분 속 이름"  "$(run 'Why does QuorvexId fail?')" 1
git -C "$R" checkout -q -- src/secret.py
run 'Why does zqpay fail?' >/dev/null
chk "X6 원장에 레포 경로를 평문으로 안 쓴다"  "$(grep -cF "$R" "$T/ledger.jsonl")" 0
X7RC=$(run 'how should we handle it?    if order is None: return retry(order, safe)')
chk "X7 원문 조각(L3)만으로 걸린다 — 종료 코드와 걸린 층"  "$X7RC/$(python3 -c 'import json,sys; print(",".join(sorted({h["layer"]+":"+h["kind"] for h in json.load(open(sys.argv[1]))["hits"]})))' "$T/out")" "1/L3:verbatim"
echo "── codex R2 (2026-10-26) ──"
chk "Y1 추적 중인 심볼릭 링크의 대상 경로 속 이름"  "$(run 'Why does QorvianLink fail?')" 1
chk "Y2 빈 가드 파일 → NOT SCANNED"  "$(run 'How should a retry wrapper handle timeouts?' --guard "$T/gempty.sh")" 3
chk "Y3 가운데 이니셜을 뺀 작성자 이름"  "$(run 'Sora Kitavane wrote this; is the approach safe?')" 1

echo "── D2A 과차단 · 회피 (2026-10-26, RESULTS_D2A.md) ──"
chk "Z1 표준 라이브러리 어휘(numeric · whitespace) → clean"  "$(run 'a numeric whitespace table maps each code point')" 0
chk "Z1n 같은 질문, 표준 라이브러리 어휘 끔 → hit(컨트롤)"  "$(run 'a numeric whitespace table maps each code point' --no-stdlib-vocab)" 1
chk "Z2 레포의 짧은 합성(tHe · bE · iT)은 flags 에도 없다"  "$(run 'it is to be the one that fails')/$(kinds flags)" "0/"
chk "Z3 굴절형(using · mapped) → 막지 않음"  "$(run 'using mapped values fails' --no-stdlib-vocab)" 0
chk "Z4 다른 낱말에 붙여 쓴 불투명 이름(ZqpayClient) — 걸린 종류까지"  "$(run 'ZqpayClient fails')/$(kinds hits)" "1/opaque"
chk "Z5 글자마다 띄어 쓴 불투명 이름(7자) — 걸린 종류까지"  "$(run 'v e l n o r a fails')/$(kinds hits)" "1/opaque-split"
echo "── codex R1 (precision, 2026-10-26) ──"
chk "W1 긴 camel 호스트명 그대로"  "$(run 'Why is getSetGetSetGetSetGetSetGetSetGetSet.internal slow?')" 1
chk "W3 파생 접미로 지어낸 이름(mapness)은 공개 낱말이 아니다"  "$(run 'Why does mapness fail?' --no-stdlib-vocab)" 1
mkdir -p "$T/cache"
# 경로를 레인 안에서 직접 계산한다 — 검사기 함수로 계산하면 그 함수가 없는 옛 코드에서 오염이 엉뚱한 자리에 쓰여 레인이 장식이 된다
CP=$(python3 -c 'import hashlib,os,sys,sysconfig; std=sysconfig.get_paths()["stdlib"]; print(os.path.join(sys.argv[1], "fh-abstract-consult", "stdlib-%s.json" % hashlib.sha256((std + sys.version).encode()).hexdigest()[:16]))' "$T/cache")
mkdir -p "$(dirname "$CP")"
python3 -c 'import json,sys; json.dump(["zqpay"] + ["word"] * 1500, open(sys.argv[1], "w"))' "$CP"
chk "W2 중복으로 부풀린 캐시를 믿지 않는다(zqpay 그대로 걸림)"  "$(XDG_CACHE_HOME="$T/cache" run 'Why does zqpay fail?')" 1
chk "W2b 캐시를 다시 지었다(출처 · 버전 · 해시 칸까지)"  "$(python3 -c 'import hashlib,json,sys,sysconfig; d=json.load(open(sys.argv[1])); w=d.get("words",[]); print(d.get("std")==sysconfig.get_paths()["stdlib"] and d.get("version")==sys.version and d.get("sha")==hashlib.sha256("\n".join(w).encode()).hexdigest() and len(set(w))==len(w)>1000 and "zqpay" not in w)' "$CP")" True
chk "W4 자음 겹침을 아무 접미에나 쓰지 않는다(mappes)"  "$(run 'Why does mappes fail?' --no-stdlib-vocab)" 1
run 'processPayment returns None' >/dev/null
chk "Z6 원장의 flags 는 해시만(이름 · token 칸 없음)"  "$(tail -1 "$T/ledger.jsonl" | python3 -c 'import json,sys; f=json.load(sys.stdin)["flags"]; print(len(f), all(set(x)=={"layer","kind","sha256"} for x in f))')" "1 True"

echo "── L1 운영자 리터럴 가드 ──"
chk "A9 가드 rc1 → hit"  "$(run 'How should a retry wrapper handle timeouts?' --guard "$T/g1.sh")" 1
chk "A9b 가드 rc3 → NOT SCANNED"  "$(run 'How should a retry wrapper handle timeouts?' --guard "$T/g3.sh")" 3
chk "A9c 가드 없음 → NOT SCANNED"  "$(run 'How should a retry wrapper handle timeouts?' --guard "$T/nope.sh")" 3
chk "A9d OUTBOUND_QUERY_OK=1 이 가드를 통과시키지 못한다" \
  "$(OUTBOUND_QUERY_OK=1 run 'How should a retry wrapper handle timeouts?' --guard "$T/gok.sh")" 1

echo "── L1 실물 가드(패턴 픽스처 주입) ──"
printf 'HIGH\tZZFIXTURETOKEN\n' > "$T/defaults"; printf 'HIGH\tZZOVERRIDETOKEN\n' > "$T/override"
chk "A13 실물 가드 · override 리터럴 → hit" \
  "$(PSA_DEFAULTS_FILE="$T/defaults" PSA_OVERRIDE_FILE="$T/override" run 'why does ZZOVERRIDETOKEN time out' --guard "$HERE/outbound_query_guard.sh")" 1
chk "A13n 실물 가드 · 깨끗한 질문 → clean" \
  "$(PSA_DEFAULTS_FILE="$T/defaults" PSA_OVERRIDE_FILE="$T/override" run 'How should a retry wrapper handle timeouts?' --guard "$HERE/outbound_query_guard.sh")" 0

echo "── 미측정 = 막음 ──"
chk "A10 사전 없음"  "$(run 'How should a retry wrapper handle timeouts?' --dict "$T/nodict")" 3
mkdir -p "$T/notgit"
chk "A10b git 레포 아님"  "$(printf 'x' > "$T/q"; python3 "$C" check --repo "$T/notgit" --question-file "$T/q" --dict "$T/dict" --guard "$T/g0.sh" --no-ledger >/dev/null 2>&1; echo $?)" 3
mkdir -p "$T/empty"; git -C "$T/empty" init -q
chk "A10c 추적 파일 0"  "$(printf 'x' > "$T/q"; python3 "$C" check --repo "$T/empty" --question-file "$T/q" --dict "$T/dict" --guard "$T/g0.sh" --no-ledger >/dev/null 2>&1; echo $?)" 3
mkdir -p "$T/plain"; git -C "$T/plain" init -q; echo "the gate is safe" > "$T/plain/notes"; git -C "$T/plain" add -A
chk "A10e 비공개 후보 이름 0 개(사전 낱말뿐) → NOT SCANNED"  "$(printf 'x' > "$T/q"; python3 "$C" check --repo "$T/plain" --question-file "$T/q" --dict "$T/dict" --guard "$T/g0.sh" --no-ledger >/dev/null 2>&1; echo $?)" 3
chk "A10d 빈 질문"  "$(run '   ')" 3
chk "A11b 공개 말뭉치 경로 없음"  "$(run 'How should a retry wrapper handle timeouts?' --public-corpus "$T/nopub")" 3

echo "── 공개 말뭉치 ──"
mkdir -p "$T/pub"; echo 'zqpayGateway = 1' > "$T/pub/x.py"
chk "A11 공개 말뭉치에 있는 이름은 비공개 실체로 안 친다"  "$(run 'Why does zqpayGateway approve fail' --public-corpus "$T/pub")" 0
chk "A11n 말뭉치에 없는 이름은 그대로 걸린다"  "$(run 'host pg settle 01 shop internal is slow' --public-corpus "$T/pub")" 1

echo "── 원장 ──"
: > "$T/ledger.jsonl"
run 'Why does zqpayGateway approve fail' >/dev/null
HID=$(python3 -c "import json;print(json.load(open('$T/out'))['id'])")
run 'How should a retry wrapper around an external payment approval call handle timeouts?' >/dev/null
CID=$(python3 -c "import json;print(json.load(open('$T/out'))['id'])")
chk "A12 걸린 질문의 이름 · 본문이 원장에 없다"  "$(grep -ci 'zqpay' "$T/ledger.jsonl")" 0
chk "A12b 깨끗한 질문은 본문을 남긴다"  "$(grep -c 'retry wrapper around' "$T/ledger.jsonl")" 1
chk "A12c 원장 권한 600"  "$(stat -c '%a' "$T/ledger.jsonl" 2>/dev/null || stat -f '%Lp' "$T/ledger.jsonl")" 600
d() { python3 "$C" "$@" --ledger "$T/ledger.jsonl" >/dev/null 2>&1; echo $?; }
chk "A12d 걸린 질문을 «보냄» 으로 기록 → 거부"  "$(d decide --id "$HID" --decision sent)" 1
chk "A12e 없는 id → 거부"  "$(d decide --id nope --decision dropped)" 1
chk "A12f 보냄 기록 없이 재현 결과 → 거부"  "$(d replay --id "$CID" --rc 0)" 1
chk "A12g 깨끗한 질문 «보냄»"  "$(d decide --id "$CID" --decision sent)" 0
chk "A12h 보낸 뒤 재현 결과"  "$(d replay --id "$CID" --rc 0)" 0

echo
echo "abstract_consult_check lanes: $PASS passed · $FAIL failed"
[ "$FAIL" -eq 0 ]
