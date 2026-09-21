#!/usr/bin/env python3
"""png_luma.py — PNG 한 장의 평균 휘도(0~255). 표준 라이브러리만 쓴다.

왜 손으로 디코딩하나: 이 값을 쓰는 레인(`test_map_flash_render_lanes.sh`)은 «깜빡임이
실제로 보이나»를 재는 자리라 소비자 설치본에서도 돌아야 하는데, Pillow·numpy 를 요구하면
그 설치본 대부분에서 **레인이 통째로 안 돈다**. 안 도는 검사는 초록도 빨강도 아니다.

용법:
  python3 scripts/png_luma.py <file.png>            # 한 장
  python3 scripts/png_luma.py --dir <디렉터리>       # f*.png / p*.png 전부, 한 줄씩
  python3 scripts/png_luma.py --min <디렉터리>       # 최솟값 하나만
지원: 8-bit gray / RGB / gray+A / RGBA, 인터레이스 없음. 그 밖이면 rc=2 로 죽는다
(모르는 포맷을 0 으로 접지 않는다 — «미측정 ≠ 0»).
"""
import glob
import os
import struct
import sys
import zlib

CHANNELS = {0: 1, 2: 3, 4: 2, 6: 4}


def _rows(path):
    data = open(path, 'rb').read()
    if data[:8] != b'\x89PNG\r\n\x1a\n':
        raise ValueError(f'{path}: not a PNG')
    idat, i = b'', 8
    width = height = depth = color = interlace = None
    while i + 8 <= len(data):
        (length,) = struct.unpack('>I', data[i:i + 4])
        kind, body = data[i + 4:i + 8], data[i + 8:i + 8 + length]
        if kind == b'IHDR':
            width, height, depth, color, _, _, interlace = struct.unpack('>IIBBBBB', body[:13])
        elif kind == b'IDAT':
            idat += body
        elif kind == b'IEND':
            break
        i += 12 + length
    if depth != 8 or interlace != 0 or color not in CHANNELS:
        raise ValueError(f'{path}: unsupported PNG (depth={depth} color={color} interlace={interlace})')
    raw = zlib.decompress(idat)
    ch = CHANNELS[color]
    stride, out, prev, pos = width * ch, [], bytearray(width * ch), 0
    for _ in range(height):
        ftype, pos = raw[pos], pos + 1
        line = bytearray(raw[pos:pos + stride])
        pos += stride
        if ftype == 1:
            for x in range(ch, stride):
                line[x] = (line[x] + line[x - ch]) & 255
        elif ftype == 2:
            for x in range(stride):
                line[x] = (line[x] + prev[x]) & 255
        elif ftype == 3:
            for x in range(stride):
                left = line[x - ch] if x >= ch else 0
                line[x] = (line[x] + ((left + prev[x]) >> 1)) & 255
        elif ftype == 4:
            for x in range(stride):
                a = line[x - ch] if x >= ch else 0
                b = prev[x]
                c = prev[x - ch] if x >= ch else 0
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                pred = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[x] = (line[x] + pred) & 255
        elif ftype != 0:
            raise ValueError(f'{path}: unknown filter type {ftype}')
        out.append(bytes(line))
        prev = line
    return width, height, ch, out


def luma(path):
    """Rec.601 평균 휘도. 알파는 무시한다 — 스크린캐스트 프레임은 불투명이다."""
    _, _, ch, rows = _rows(path)
    total = count = 0
    for row in rows:
        for off in range(0, len(row), ch):
            if ch >= 3:
                total += (row[off] * 299 + row[off + 1] * 587 + row[off + 2] * 114) // 1000
            else:
                total += row[off]
            count += 1
    return total / max(count, 1)


def _listing(directory):
    files = sorted(glob.glob(os.path.join(directory, 'f*.png')) +
                   glob.glob(os.path.join(directory, 'p*.png')))
    if not files:
        print(f'no frames under {directory}', file=sys.stderr)
        sys.exit(2)
    return files


def main(argv):
    if len(argv) == 3 and argv[1] == '--dir':
        for f in _listing(argv[2]):
            print(f'{os.path.basename(f)} {luma(f):.2f}')
    elif len(argv) == 3 and argv[1] == '--min':
        print(f'{min(luma(f) for f in _listing(argv[2])):.2f}')
    elif len(argv) == 3 and argv[1] == '--spread':
        vals = [luma(f) for f in _listing(argv[2])]
        print(f'{max(vals) - min(vals):.3f}')
    elif len(argv) == 2:
        print(f'{luma(argv[1]):.2f}')
    else:
        print(__doc__, file=sys.stderr)
        sys.exit(2)


if __name__ == '__main__':
    try:
        main(sys.argv)
    except (ValueError, OSError) as exc:
        print(f'png_luma: {exc}', file=sys.stderr)
        sys.exit(2)
