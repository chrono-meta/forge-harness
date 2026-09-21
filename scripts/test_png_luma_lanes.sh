#!/usr/bin/env bash
# test_png_luma_lanes.sh — `scripts/png_luma.py` 회귀 앵커.
#
# 왜 `test_map_flash_render_lanes.sh` 안에 안 넣나: 그 레인은 브라우저가 없으면 통째로
# `NOT MEASURED` 로 떨어진다. 휘도계는 **표준 라이브러리만** 쓰므로 어디서든 돈다 — 계기를
# 브라우저 뒤에 숨기면 정작 브라우저 없는 머신(= CI)에서 앵커가 죽는다.
#
# 이 레인이 박는 것 넷:
#   ① 값이 **맞는다** — 알려진 색의 알려진 휘도. 특히 L5 는 Rec.601 가중을 박는다(단순
#      평균이면 85.00 이 나오는 자리라, 가중이 빠지면 조용히 «그럴듯한» 값이 된다)
#   ② **메타모픽** — 같은 그림을 필터 0~4 다섯 방식으로 인코딩해도 휘도가 같다. 언필터링
#      분기 넷이 여기서만 실행된다(TR 29119-11 오라클: `metamorphic`)
#   ③ 모르는 포맷·부재가 **0 으로 접히지 않는다** — 전부 rc=2([[feedback_not_found_is_not_zero_family]])
#   ④ 🟥 **되돌림** — 가중을 죽이면 **정확히 L5 만** 빨개지는가([[feedback_anchor_can_be_decorative]])
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SC="$HERE/png_luma.py"
PASS=0; FAIL=0
ok(){ PASS=$((PASS+1)); printf '  ✅ %s\n' "$1"; }
no(){ FAIL=$((FAIL+1)); printf '  ❌ %s — %s\n' "$1" "${2:-}"; }
echo "── test_png_luma_lanes ──"

[ -f "$SC" ] || { no "L0 휘도계 존재" "$SC"; echo "FAILED=1"; exit 1; }
command -v python3 >/dev/null 2>&1 || { no "L0 python3" "표준 라이브러리 전용인데 인터프리터가 없다"; echo "FAILED=1"; exit 1; }

D="$(mktemp -d)"
trap '/bin/rm -rf "$D"' EXIT

# ── 픽스처: 이 파일이 스스로 만든다. 체크인된 PNG 는 바이트가 왜 그런지 아무도 못 읽는다 ──
python3 - "$D" <<'PYEOF'
import os, struct, sys, zlib
D = sys.argv[1]
os.makedirs(os.path.join(D, 'frames'), exist_ok=True)
os.makedirs(os.path.join(D, 'empty'), exist_ok=True)

def chunk(kind, body):
    return struct.pack('>I', len(body)) + kind + body + struct.pack('>I', zlib.crc32(kind + body) & 0xffffffff)

def write(path, w, h, color, depth, scanlines, interlace=0):
    ihdr = struct.pack('>IIBBBBB', w, h, depth, color, 0, 0, interlace)
    with open(path, 'wb') as fh:
        fh.write(b'\x89PNG\r\n\x1a\n')
        fh.write(chunk(b'IHDR', ihdr))
        fh.write(chunk(b'IDAT', zlib.compress(b''.join(scanlines))))
        fh.write(chunk(b'IEND', b''))

def solid(path, w, h, color, pixel):
    ch = len(pixel)
    row = bytes(pixel) * w
    write(path, w, h, color, 8, [b'\x00' + row] * h)

solid(os.path.join(D, 'black.png'),   8, 8, 2, (0, 0, 0))
solid(os.path.join(D, 'white.png'),   8, 8, 2, (255, 255, 255))
solid(os.path.join(D, 'gray128.png'), 8, 8, 0, (128,))
solid(os.path.join(D, 'red.png'),     8, 8, 2, (255, 0, 0))
solid(os.path.join(D, 'alpha0.png'),  8, 8, 6, (255, 255, 255, 0))

# ── 메타모픽 원본: 같은 그림, 필터 다섯 가지 ──────────────────────────────────────
W = H = 8
BPP = 3
raw = [bytes(((x * 31 + y * 17) % 256) for x in range(W) for _ in range(BPP)) for y in range(H)]

def paeth(a, b, c):
    pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
    return a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)

def encode(ftype):
    out, prev = [], bytes(W * BPP)
    for line in raw:
        enc = bytearray(len(line))
        for x in range(len(line)):
            a = line[x - BPP] if x >= BPP else 0
            b = prev[x]
            c = prev[x - BPP] if x >= BPP else 0
            if ftype == 0:   enc[x] = line[x]
            elif ftype == 1: enc[x] = (line[x] - a) & 255
            elif ftype == 2: enc[x] = (line[x] - b) & 255
            elif ftype == 3: enc[x] = (line[x] - ((a + b) >> 1)) & 255
            else:            enc[x] = (line[x] - paeth(a, b, c)) & 255
        out.append(bytes([ftype]) + bytes(enc))
        prev = line
    return out

for f in range(5):
    write(os.path.join(D, 'filt%d.png' % f), W, H, 2, 8, encode(f))

# ── 계기 사망 픽스처: 전부 rc=2 여야 한다 ────────────────────────────────────────
write(os.path.join(D, 'depth16.png'), 2, 2, 0, 16, [b'\x00' + b'\x00\x80' * 2] * 2)
write(os.path.join(D, 'interlaced.png'), 2, 2, 2, 8, [b'\x00' + b'\x40' * 6] * 2, interlace=1)
write(os.path.join(D, 'palette.png'), 2, 2, 3, 8, [b'\x00\x00\x00'] * 2)
open(os.path.join(D, 'notpng.txt'), 'w').write('이건 PNG 가 아니다\n')

# --dir/--min/--spread 용: 이름이 f*.png 여야 _listing 이 집는다
for name, pix in (('f01.png', (16, 16, 16)), ('f02.png', (200, 200, 200)), ('f03.png', (96, 96, 96))):
    solid(os.path.join(D, 'frames', name), 4, 4, 2, pix)
PYEOF
[ $? -eq 0 ] || { no "L0 픽스처 생성" "자기 인코더가 죽었다 — 아래 레인은 증거가 아니다"; echo "FAILED=1"; exit 1; }

_luma(){ python3 "$SC" "$D/$1" 2>&1; }
_expect(){ # 이름 파일 기대값
  local got; got="$(_luma "$2")"
  [ "$got" = "$3" ] && ok "$1 ($2 → $3)" || no "$1" "$2 → '$got' (기대 $3)"
}

# ── 값 레인 ────────────────────────────────────────────────────────────────────
OUT=$(python3 -c "import py_compile,sys; py_compile.compile(sys.argv[1], doraise=True)" "$SC" 2>&1); RC=$?
[ "$RC" -eq 0 ] && ok "L1 구문" || no "L1 구문" "$OUT"
_expect "L2 검정 RGB"        black.png   "0.00"
_expect "L3 흰색 RGB"        white.png   "255.00"
_expect "L4 회색 8-bit gray" gray128.png "128.00"
# 🟥 판별 레인: 단순 평균이면 85.00 이 나온다. 76.00 이어야 Rec.601 가중이 살아 있는 것.
_expect "L5 순수 빨강 → Rec.601 76.00 (단순 평균이면 85.00)" red.png "76.00"
_expect "L6 알파는 무시한다" alpha0.png  "255.00"

# ── L7 메타모픽: 같은 그림, 다섯 인코딩 ─────────────────────────────────────────
BASE="$(_luma filt0.png)"
case "$BASE" in
  0.00|255.00|*[!0-9.]*) no "L7 원본 퇴화" "filt0 = '$BASE' — 단색이면 언필터링 분기를 안 가른다" ;;
  *) ok "L7a 원본이 단색이 아니다 (filt0 = $BASE)" ;;
esac
_SAME=1
for f in 1 2 3 4; do
  V="$(_luma "filt$f.png")"
  [ "$V" = "$BASE" ] || { no "L7b 필터 $f" "$V ≠ $BASE — 언필터링 분기 $f 가 깨졌다"; _SAME=0; }
done
[ "$_SAME" -eq 1 ] && ok "L7b 필터 0~4 다섯 인코딩이 같은 휘도 ($BASE)"

# ── CLI 레인 ───────────────────────────────────────────────────────────────────
OUT=$(python3 "$SC" --dir "$D/frames" 2>&1); RC=$?
[ "$RC" -eq 0 ] && [ "$(printf '%s\n' "$OUT" | wc -l)" -eq 3 ] \
  && ok "L8 --dir 세 프레임을 한 줄씩" || no "L8 --dir" "rc=$RC · $OUT"
OUT=$(python3 "$SC" --min "$D/frames" 2>&1)
[ "$OUT" = "16.00" ] && ok "L9 --min 최솟값 16.00" || no "L9 --min" "'$OUT' (기대 16.00)"
OUT=$(python3 "$SC" --spread "$D/frames" 2>&1)
[ "$OUT" = "184.000" ] && ok "L10 --spread 진폭 184.000" || no "L10 --spread" "'$OUT' (기대 184.000)"

# ── 계기 사망 레인: 전부 rc=2. «모르겠다» 가 0 으로 접히면 깜빡임이 조용히 통과한다 ──
_dies(){ python3 "$SC" "$2" >/dev/null 2>&1; local rc=$?
  [ "$rc" -eq 2 ] && ok "$1 (rc=2)" || no "$1" "rc=$rc — 미측정이 0 으로 접혔다"; }
_dies "L11 PNG 가 아닌 파일"      "$D/notpng.txt"
_dies "L12 없는 파일"             "$D/nonexistent.png"
_dies "L13 16-bit 심도"           "$D/depth16.png"
_dies "L14 인터레이스"            "$D/interlaced.png"
_dies "L15 팔레트(color type 3)"  "$D/palette.png"
python3 "$SC" --min "$D/empty" >/dev/null 2>&1; RC=$?
[ "$RC" -eq 2 ] && ok "L16 빈 디렉터리 --min (rc=2)" || no "L16 빈 디렉터리" "rc=$RC"
python3 "$SC" >/dev/null 2>&1; RC=$?
[ "$RC" -eq 2 ] && ok "L17 인자 없음 (rc=2)" || no "L17 인자 없음" "rc=$RC"

# ── L18 되돌림: 가중을 죽이면 L5 만 빨개지나 ────────────────────────────────────
# [[feedback_anchor_can_be_decorative]] — 적용확인 → 실행 → 복원 3단.
MUT="$D/mutant.py"
sed 's/\* 299 + row\[off + 1\] \* 587 + row\[off + 2\] \* 114) \/\/ 1000/* 1000 + row[off + 1] * 1000 + row[off + 2] * 1000) \/\/ 3000/' "$SC" > "$MUT"
if /usr/bin/grep -q '\* 1000 + row\[off + 1\] \* 1000' "$MUT"; then
  ok "L18a 돌연변이 적용됨 (Rec.601 → 단순 평균)"
  M_RED="$(python3 "$MUT" "$D/red.png" 2>&1)"
  M_GRAY="$(python3 "$MUT" "$D/gray128.png" 2>&1)"
  [ "$M_RED" = "85.00" ] && ok "L18b 가중을 죽이면 빨강이 85.00 (= L5 가 장식이 아니다)" \
    || no "L18b 되돌림" "빨강 '$M_RED' — L5 가 이 돌연변이를 못 잡는다"
  [ "$M_GRAY" = "128.00" ] && ok "L18c 회색은 그대로 128.00 (돌연변이가 전부를 빨갛게 만들지 않는다)" \
    || no "L18c 과차단" "회색 '$M_GRAY'"
else
  no "L18a 돌연변이 미적용" "sed 가 아무것도 안 바꿨다 — 아래 되돌림 판정은 증거가 아니다"
fi

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || { echo "FAILED=1"; exit 1; }
exit 0
