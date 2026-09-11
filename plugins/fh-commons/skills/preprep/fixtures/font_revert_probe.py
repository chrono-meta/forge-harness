#!/usr/bin/env python3
"""L14 되돌림 프로브 — 상속 분리가 하중을 지는지, 그리고 방어가 몇 겹인지.

🟥 **왜 «template 미선언» 조건에서 재는가 (2026-09-11, 이 프로브가 한 번 거짓 적색을 낸 뒤).**
L14 의 오탐 방어는 **둘이고 겹친다**:

    ① 영역 분리   `slide_runs()` 가 애초에 `ppt/slides/` 만 읽는다
    ② A2 강등     템플릿 자신의 마스터·레이아웃이 쓰는 서체는 finding→note 로 내린다

해시가 같은 부품에서는 ②가 ①을 **완전히 덮는다** — 마스터가 템플릿과 동일하면 그 서체는
정의상 «템플릿 자신이 쓰는 서체»이기 때문이다. 그래서 둘 다 켠 채 ①만 죽이면 결과가 안 바뀌고,
프로브는 「분리가 장식이다」라는 **거짓 판정**을 낸다. 실제로 그렇게 빨개졌고, 그때 내린 결론이
「분리를 지워도 된다」였다면 template 미선언 install 전부에서 오탐 85건이 돌아왔을 것이다.

⇒ **컨트롤은 방어를 하나만 남긴 조건에서 건다** — `separation` 은 template 을 빼서 ①만 남긴다.
(이건 이 저장소가 이름 붙인 「레인이 초록인 이유는 셋」의 변종이다 — 여기서는 *적색*인 이유가
계기 쪽에 있었다.)

🟥 **②는 그 뒤 «방어»에서 «주석»으로 강등됐다 (cross-family 2라운드, 같은 날).** 템플릿
레이아웃은 쓰이지도 않는 자리에 Office 기본값(Arial·Calibri)을 흔히 들고 있어서, 그 이름을
노트로 내리면 저자가 그것으로 본문을 찍어도 종료코드가 안 움직인다 — 오탐을 줄이려던 것이
**fail-open** 이었다. 그래서 지금 방어는 ① 하나뿐이고, ②의 자리에는 finding 에 붙는 맥락
주석만 남는다. `annotation` 모드가 **그 주석이 억제로 되돌아가지 않는지**를 고정한다.
(옛 `depth` 모드는 그 되돌림 때 폐기됐다. 낡은 계약을 단언하다 옳게 빨개졌고, 그 적색이
계약이 바뀌었음을 알린 신호였다 — 지우지 말고 교체하는 것이 맞다.)

usage: font_revert_probe.py separation|annotation
"""
import os
import re
import sys
import shutil
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))

import lane_font as L          # noqa: E402
import test_lane_font as T     # noqa: E402


def _widen(z):
    """뮤턴트: 상속 영역까지 판정 대상에 넣는다 = 영역 분리를 죽인다."""
    rows, n = _widen.orig(z)
    for name in z.namelist():
        if re.match(r'ppt/(slideMasters|slideLayouts)/[^/]+\.xml$', name):
            for tf in L._typefaces(z, name):
                if tf and not L.THEME_REF.match(tf):
                    # 🟥 튜플 모양은 slide_runs 의 계약이다 — (장, 서체, 슬롯, 텍스트, 출처).
                    #    계약이 바뀌면 이 프로브가 빨개진다. 빨개지는 것이 옳다.
                    rows.append((0, tf, 'latin', '(상속)', 'inherited'))
    return rows, n


def separation(d):
    """방어 ①만 남긴다 (template 미선언) → 죽이면 오탐이 돌아와야 한다."""
    k1 = T.build(os.path.join(d, 'k1.pptx'), [T.run('본문', 'Brand Display Bold')])
    cfg = T.cfg_for(k1, None, ['Brand Display'])
    base = len(L.scan(cfg, d)[0])
    _widen.orig = L.slide_runs
    L.slide_runs = _widen
    try:
        mut = len(L.scan(cfg, d)[0])
    finally:
        L.slide_runs = _widen.orig
    print('BASE', base, 'MUT', mut)


def annotation(d):
    """템플릿도 쓰는 이름이 **억제되지 않고 finding 으로 남는지** 고정한다.

    저자가 본문에 `Helvetica Neue`(템플릿 마스터에 있는 이름)를 찍은 상황. 억제로 되돌아가면
    FINDING 0 이 나오고, 그것이 2라운드가 지목한 fail-open 이다."""
    tpl = T.build(os.path.join(d, 'tpl.pptx'), [T.run('본문', 'Brand Display Bold')])
    k = T.build(os.path.join(d, 'k.pptx'),
                [T.run('본문', 'Brand Display Bold'), T.run('각주', 'Helvetica Neue')])
    f, _ = L.scan(T.cfg_for(k, tpl, ['Brand Display']), d)
    annotated = sum(1 for x in f if '템플릿 자신의 마스터' in x[4])
    print('FINDING', len(f), 'ANNOTATED', annotated)


if __name__ == '__main__':
    mode = sys.argv[1] if len(sys.argv) > 1 else ''
    fn = {'separation': separation, 'annotation': annotation}.get(mode)
    if not fn:
        print('usage: font_revert_probe.py separation|annotation', file=sys.stderr)
        sys.exit(10)
    d = tempfile.mkdtemp(prefix='fontprobe_')
    try:
        fn(d)
    finally:
        shutil.rmtree(d, ignore_errors=True)
