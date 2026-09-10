#!/usr/bin/env python3
"""R1·R2·R4·R5·P1·P3 의 known-pair pptx 를 **테스트 시점에** 만든다 — 레포에 커밋하지 않는다.

🟥 R3 는 여기서 안 만든다. 선두 줄 판별이 절대좌표(LEAD_MAX_Y·LEAD_MIN_CX)와 srgbClr 런 구조에
   기대므로, 검출기 가정에 맞춰 python-pptx 로 «생성»한 픽스처는 검출기 자신을 검증 못 한다
   (자기참조). 대신 실물 구조를 그대로 2장으로 줄인 `fixture_R3_positive.pptx` ·
   `fixture_R3_negative.pptx` 를 쓴다(이 디렉터리에 실물로 있다).

슬라이드 크기는 원 코퍼스와 같은 1920pt 계열(24,384,000 × 13,716,000 EMU)로 맞춘다 — P1/P3 는
상대좌표 비교라 크기 자체는 판정에 안 들어가지만, R1/R3 의 `LEAD_MIN_CX`(12,000,000 EMU) 가
«슬라이드 절반 폭» 정도를 가정하므로 실물 규모에서 벗어나면 그 가정을 검증 못 한다.
"""
import os
from pptx import Presentation
from pptx.util import Emu, Pt
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN
from pptx.enum.shapes import MSO_CONNECTOR
from pptx.enum.dml import MSO_LINE_DASH_STYLE as MSO_LINE

SLIDE_W, SLIDE_H = Emu(24384000), Emu(13716000)
ACCENT = RGBColor(0xFA, 0xE1, 0x00)


def _new_deck():
    prs = Presentation()
    prs.slide_width, prs.slide_height = SLIDE_W, SLIDE_H
    return prs


def _blank(prs):
    return prs.slides.add_slide(prs.slide_layouts[6])


def _box(slide, name, x, y, w, h, text=None, accent=False):
    tb = slide.shapes.add_textbox(Emu(x), Emu(y), Emu(w), Emu(h))
    tb.name = name
    if text is not None:
        p = tb.text_frame.paragraphs[0]
        r = p.add_run()
        r.text = text
        if accent:
            r.font.color.rgb = ACCENT
    return tb


def _notes(slide, text):
    slide.notes_slide.notes_text_frame.text = text


# ── R1 orphan-connective ─────────────────────────────────────────────────────
# 제목은 폭을 좁혀 lead 자격에서 뺀다(LEAD_MIN_CX=12,000,000 미만) — 선두 줄만 lead 로 잡히게.
def r1(path, positive):
    prs = _new_deck()
    s0 = _blank(prs)
    _box(s0, 'title0', 100000, 100000, 5000000, 500000, '첫 장')
    prev_body = ('오늘은 깃허브 사용법을 설명합니다' if not positive
                 else '오늘은 배포 절차를 설명합니다')
    _box(s0, 'body0', 100000, 2000000, 8000000, 800000, prev_body)
    s1 = _blank(prs)
    _box(s1, 'title1', 100000, 100000, 5000000, 500000, '둘째 장')
    _box(s1, 'lead1', 100000, 900000, 14000000, 900000, '그러나 깃허브는 막을 자리를 줄 뿐입니다')
    _box(s1, 'body1', 100000, 2500000, 8000000, 800000, '본문 내용입니다')
    prs.save(path)


# ── R2 enum-dropped ──────────────────────────────────────────────────────────
def r2(path, positive):
    prs = _new_deck()
    s0 = _blank(prs)
    _box(s0, 'enum0', 100000, 100000, 14000000, 900000,
         '① 속도 개선 ② 품질 향상 ③ 비용 절감')
    s1 = _blank(prs)
    _box(s1, 'title1', 100000, 100000, 14000000, 900000, '이 셋 중 무엇이 가장 중요한가')
    body = ('① 속도 ② 품질 ③ 비용을 함께 고려합니다' if not positive
            else '속도와 품질과 비용을 함께 고려합니다')
    _box(s1, 'body1', 100000, 2000000, 14000000, 900000, body)
    prs.save(path)


# ── R4 screen-heavy (자기 분포 P90, N=12) ────────────────────────────────────
# 🟥 negative 는 «값을 살짝 낮춘 아웃라이어」가 아니라 **전부 동값**으로 짠다 — N=12 처럼 작은
#    표본에서는 살짝 낮춰도 sorted 순서상 «둘째로 큰 값」이 바뀌어 p90 인덱스가 다른 정상값을
#    가리키고, 그 값이 다시 «최댓값이라 p90 초과」가 되는 자기충족 오탐이 난다(실측으로 확인).
#    전부 동값이면 어떤 값도 p90 을 **엄격히** 못 넘어(같음은 초과가 아니다) 후보가 구조적으로 0.
def r4(path, positive):
    prs = _new_deck()
    for i in range(12):
        s = _blank(prs)
        n = 500 if (positive and i == 6) else 30
        _box(s, f'body{i}', 100000, 100000, 14000000, 900000, '가' * n)
    prs.save(path)


# ── R5 read-load (신규 글자 ÷ 발화 초, 자기 분포 P90, N=12) ─────────────────
# 같은 이유로 negative 는 «전부 동일 비율」로 짠다(위 R4 와 같은 원리).
def r5(path, positive):
    """정상 슬라이드: 신규 64자 · 발화 12초(64/5.36≈12) → 비율 5.33.
    아웃라이어(positive 만, 7번째 장): 신규 150자 · 발화 5초(27/5.36≈5) → 비율 30.0."""
    prs = _new_deck()
    for i in range(12):
        s = _blank(prs)
        if positive and i == 6:
            _box(s, 'body_outlier', 100000, 100000, 14000000, 2000000,
                 '완전히새로운화면내용' * 15)  # 150자, 이전 장과 겹치지 않는 새 문자열
            _notes(s, '가' * 27)              # round(27/5.36) = 5초
        else:
            # 접두 2자리 인덱스로 매 장을 다르게 만든다(집합 차집합 비교라 «신규»로 잡히려면
            # 이전 장과 텍스트가 겹치면 안 된다) — 나머지 62자는 동일해 길이는 항상 64자다
            _box(s, f'body{i}', 100000, 100000, 14000000, 2000000, f'{i:02d}' + '가' * 62)
            _notes(s, '가' * 64)              # round(64/5.36) = 12초
    prs.save(path)


# ── P1 build-jitter (같은 이름 도형, 연속 4장) ───────────────────────────────
def p1(path):
    """4장 · 이름 «gate_bar» 공유. 쌍(1→2)=임계 안 소폭 이동(뜸) · (2→3)=임계 밖 큰 이동(안 뜸) ·
    (3→4)=무이동(안 뜸). compared=3 이어야 «비교 안 함»이 아니다."""
    prs = _new_deck()
    xs = [1000000, 1030000, 6030000, 6030000]  # +30,000(JIT 200,000 안) · +5,000,000(밖) · +0
    for x in xs:
        s = _blank(prs)
        _box(s, 'gate_bar', x, 2000000, 1000000, 500000, '게이트 막대')
    prs.save(path)


# ── P3 adjacency (오른끝 ↔ 왼끝) ─────────────────────────────────────────────
def p3(path):
    """slide1 = 임계 안 어긋남(뜸) · slide2 = 정확히 맞닿음(0, 안 뜸) + 임계 밖 큰 틈(안 뜸)."""
    prs = _new_deck()
    s1 = _blank(prs)
    _box(s1, 'stub_a', 1000000, 2000000, 1000000, 500000, 'A')     # 오른끝 2,000,000
    _box(s1, 'bar_b', 2020000, 2000000, 1000000, 500000, 'B')      # 왼끝 2,020,000 · 틈 20,000(<ALN)
    s2 = _blank(prs)
    _box(s2, 'stub_c', 1000000, 2000000, 1000000, 500000, 'C')     # 오른끝 2,000,000
    _box(s2, 'bar_d', 2000000, 2000000, 1000000, 500000, 'D')      # 왼끝 2,000,000 · 틈 0 (맞닿음)
    _box(s2, 'stub_e', 1000000, 4000000, 1000000, 500000, 'E')     # 오른끝 2,000,000
    _box(s2, 'bar_f', 3000000, 4000000, 1000000, 500000, 'F')      # 왼끝 3,000,000 · 틈 1,000,000(>ALN)
    prs.save(path)


# ── P1/P3 --baseline 델타 쌍 ──────────────────────────────────────────────────
def geometry_baseline_pair(base_path, edited_path):
    """base = 깨끗한 2장(후보 0). edited = 2장째 도형 하나를 소폭(30,000 EMU) 옮긴 사본
    (새 P1 후보 정확히 1건)."""
    prs = _new_deck()
    s1 = _blank(prs)
    _box(s1, 'gate_bar', 1000000, 2000000, 1000000, 500000, '게이트')
    s2 = _blank(prs)
    _box(s2, 'gate_bar', 1000000, 2000000, 1000000, 500000, '게이트')
    prs.save(base_path)

    prs2 = _new_deck()
    t1 = _blank(prs2)
    _box(t1, 'gate_bar', 1000000, 2000000, 1000000, 500000, '게이트')
    t2 = _blank(prs2)
    _box(t2, 'gate_bar', 1030000, 2000000, 1000000, 500000, '게이트')  # +30,000 EMU
    prs2.save(edited_path)


# ── P1 결박 (이름 AND 글자) known-pair ───────────────────────────────────────
def p1_binding(path):
    """네 도형 전부 **같은 크기의 소폭 이동**(+30,000 EMU, JIT 안)을 한다 — 즉 기하만 보면
    넷 다 후보다. 갈리는 것은 **결박 가능성**뿐이다:

      bound_bar   양쪽 글자 같음        → bound.     후보로 뜬다
      silent_bar  양쪽 글자 없음        → name_only. 🟥 **후보로 뜬다** — 막대·선이 여기 산다.
                                           P1 의 원적 사건이 바로 이 부류라 잘라내면 안 된다
      remix_bar   양쪽 글자 다름        → mismatch.  다른 내용이 같은 이름을 입었다 → 제외
      halftext    한쪽만 글자 있음      → mismatch.  같은 이유로 제외

    🟥 이 픽스처의 핵심은 «이동량이 넷 다 같다»는 것이다 — 결박 규칙 말고는 변수가 없으므로
       임계·이동량이 아니라 **결박 규칙만** 재는 계기가 된다."""
    prs = _new_deck()
    for k in (0, 1):
        s = _blank(prs)
        d = 30000 * k
        _box(s, 'bound_bar',  1000000 + d, 1000000, 900000, 400000, '같은 막대')
        _box(s, 'remix_bar',  1000000 + d, 2000000, 900000, 400000, '앞 도해' if k == 0 else '뒤 도해')
        _box(s, 'silent_bar', 1000000 + d, 3000000, 900000, 400000, None)
        _box(s, 'halftext',   1000000 + d, 4000000, 900000, 400000, None if k == 0 else '뒤늦은 글자')
    prs.save(path)


def p1_intended(path):
    """선언 면제(`geometry.intended`) known-pair. 두 도형이 **같은 소폭 이동**을 한다.

      staged_bar   x 와 cx 가 함께 바뀐다  → `attrs: [x, cx]` 선언과 정확히 일치 → 면제 대상
      stray_bar    y 만 바뀐다             → 선언과 속성이 다르다 → **면제되면 안 된다**

    🟥 둘째가 이 픽스처의 요점이다 — 면제를 «도형 이름»에 걸면 stray 도 삼켜진다."""
    prs = _new_deck()
    s1 = _blank(prs)
    _box(s1, 'staged_bar', 1000000, 1000000, 900000, 400000, '격리')
    _box(s1, 'stray_bar',  1000000, 3000000, 900000, 400000, '옆칸')
    s2 = _blank(prs)
    _box(s2, 'staged_bar', 970000, 1000000, 1030000, 400000, '격리')   # x -30,000 · cx +130,000
    _box(s2, 'stray_bar',  1000000, 3030000, 900000, 400000, '옆칸')   # y +30,000 뿐
    prs.save(path)


# ── P4 attr-consistency known-pair ───────────────────────────────────────────
def _sized(slide, name, x, y, w, h, text, pt, algn=None):
    """명시 `sz` 를 가진 상자. 🟥 P4 의 크기 축은 명시 sz 만 읽으므로 픽스처도 명시해야 한다
    — 상속 크기로 만들면 known-positive 가 UNMEASURED 로 새서 계기가 죽는다."""
    tb = slide.shapes.add_textbox(Emu(x), Emu(y), Emu(w), Emu(h))
    tb.name = name
    p = tb.text_frame.paragraphs[0]
    if algn is not None:
        p.alignment = algn
    r = p.add_run()
    r.text = text
    r.font.size = Pt(pt)
    return tb


def _dashed(slide, name, x, y, w, pt_w, dash):
    ln = slide.shapes.add_connector(MSO_CONNECTOR.STRAIGHT, Emu(x), Emu(y), Emu(x + w), Emu(y))
    ln.name = name
    ln.line.width = Pt(pt_w)
    ln.line.dash_style = dash
    return ln


def p4(path, positive):
    """축 넷을 한 벌로. positive 는 넷 다 갈리고, negative 는 **같은 구조로 전부 일치**한다.

    🟥 negative 를 «도형을 뺀 것»으로 만들지 않는다 — 그러면 「안 떴다」가 「볼 게 없었다」와
       구분이 안 되고(이 저장소가 이름 붙인 「레인이 초록인 이유는 셋」의 ②), 죽은 컨트롤이 된다.
       두 팔의 도형 수·이름·자리는 같고 **갈리는 값 하나씩만** 다르다."""
    prs = _new_deck()
    s = _blank(prs)
    # dash — 같은 종류 점선 두 개, 굵기만 갈린다
    _dashed(s, 'rule_a', 1000000, 1000000, 6000000, 1.0, MSO_LINE.DASH)
    _dashed(s, 'rule_b', 1000000, 1600000, 6000000, 3.0 if positive else 1.0, MSO_LINE.DASH)
    # algn — 같은 폭·같은 y 한 줄, 정렬만 갈린다
    _sized(s, 'row_l', 2000000, 4000000, 5000000, 800000, '왼쪽 칸', 24, PP_ALIGN.LEFT)
    _sized(s, 'row_r', 9000000, 4000000, 5000000, 800000, '오른 칸', 24,
           PP_ALIGN.CENTER if positive else PP_ALIGN.LEFT)
    # mirror — 화면 중심 기준 거울(폭 5,000,000 · 중심 ±5,192,000), 크기만 갈린다
    _sized(s, 'mir_l', 4000000, 8000000, 5000000, 800000, '만든 쪽', 32, PP_ALIGN.CENTER)
    _sized(s, 'mir_r', 15384000, 8000000, 5000000, 800000, '받는 쪽',
           28 if positive else 32, PP_ALIGN.CENTER)
    # echo — 둘째 장에 같은 문장, 크기만 갈린다
    _sized(s, 'echo_1', 2000000, 11000000, 9000000, 800000, '되돌릴 수 없는 곳', 32, PP_ALIGN.LEFT)
    s2 = _blank(prs)
    _sized(s2, 'echo_2', 2000000, 11000000, 9000000, 800000, '되돌릴 수 없는 곳',
           26 if positive else 32, PP_ALIGN.LEFT)
    prs.save(path)


# ── P1 뒤집힘 known-pair ─────────────────────────────────────────────────────
def p1_flip(path):
    """두 장 · 상자 기하는 **한 EMU도 안 바뀐다**. 바뀌는 것은 flipH 하나뿐이다.

    🟥 이 픽스처의 요점: 자리·크기만 보는 계기는 여기서 «어긋남 0» 을 낸다.
       실사고가 정확히 그 모양이었다(화살표가 반대를 가리키는데 델타가 0건).
       `steady` 는 양쪽 다 무플립이라 뜨면 안 된다(과차단 컨트롤)."""
    from pptx.enum.shapes import MSO_CONNECTOR as _C
    prs = _new_deck()
    for k in (0, 1):
        s = _blank(prs)
        a = s.shapes.add_connector(_C.STRAIGHT, Emu(2000000), Emu(2000000),
                                   Emu(2800000), Emu(2800000))
        a.name = 'turned'
        if k == 1:                      # 자리는 그대로, 방향만 뒤집는다
            a._element.spPr.xfrm.set('flipH', '1')
        b = s.shapes.add_connector(_C.STRAIGHT, Emu(6000000), Emu(2000000),
                                   Emu(6800000), Emu(2800000))
        b.name = 'steady'
    prs.save(path)


# ── L14 screen-parity known-pair ─────────────────────────────────────────────
def screen_parity(deck_path, man_ok, man_bad):
    """덱 2장 + 원고 두 벌. 🟥 덱은 **한 벌만** 만든다 — 원고만 바꿔서 「원고 쪽이 갈렸다」를
    한 변수로 재기 위해서다(덱까지 같이 바꾸면 무엇이 신호인지 못 가른다).

      man_ok   덱과 완전히 같다                      → 짝 없음 0 · 문구 다름 0
      man_bad  ① 「사라진 줄」 을 원고만 들고 있다     → 짝 없음 (원고에만)
               ② 「받아들인다」 를 덱만 들고 있다      → 짝 없음 (화면에만)
               ③ 「증거 없이 반박을 믿는 셈이다」 ↔ 덱 「…믿는 셈」 → 문구 다름
    """
    prs = _new_deck()
    s1 = _blank(prs)
    _box(s1, 'h1', 1000000, 500000, 14000000, 800000, '첫 장 제목')
    _box(s1, 'b1', 1000000, 2000000, 14000000, 800000, '증거 없이 반박을 믿는 셈')
    s2 = _blank(prs)
    _box(s2, 'h2', 1000000, 500000, 14000000, 800000, '둘째 장 제목')
    _box(s2, 'b2', 1000000, 2000000, 14000000, 800000, '받아들인다')
    prs.save(deck_path)

    open(man_ok, 'w', encoding='utf-8').write(
        '### S1 · 첫 장 제목\n🖥\n첫 장 제목\n증거 없이 반박을 믿는 셈\n🗣\n말.\n\n'
        '### S2 · 둘째 장 제목\n🖥\n둘째 장 제목\n받아들인다\n🗣\n말.\n')
    open(man_bad, 'w', encoding='utf-8').write(
        '### S1 · 첫 장 제목\n🖥\n첫 장 제목\n증거 없이 반박을 믿는 셈이다\n사라진 줄\n🗣\n말.\n\n'
        '### S2 · 둘째 장 제목\n🖥\n둘째 장 제목\n🗣\n말.\n')


def build_all(outdir):
    os.makedirs(outdir, exist_ok=True)
    r1(os.path.join(outdir, 'r1_pos.pptx'), True)
    r1(os.path.join(outdir, 'r1_neg.pptx'), False)
    r2(os.path.join(outdir, 'r2_pos.pptx'), True)
    r2(os.path.join(outdir, 'r2_neg.pptx'), False)
    r4(os.path.join(outdir, 'r4_pos.pptx'), True)
    r4(os.path.join(outdir, 'r4_neg.pptx'), False)
    r5(os.path.join(outdir, 'r5_pos.pptx'), True)
    r5(os.path.join(outdir, 'r5_neg.pptx'), False)
    p1(os.path.join(outdir, 'p1.pptx'))
    p1_binding(os.path.join(outdir, 'p1_binding.pptx'))
    p1_intended(os.path.join(outdir, 'p1_intended.pptx'))
    p1_flip(os.path.join(outdir, 'p1_flip.pptx'))
    screen_parity(os.path.join(outdir, 'sp_deck.pptx'),
                  os.path.join(outdir, 'sp_ok.md'),
                  os.path.join(outdir, 'sp_bad.md'))
    p3(os.path.join(outdir, 'p3.pptx'))
    p4(os.path.join(outdir, 'p4_pos.pptx'), True)
    p4(os.path.join(outdir, 'p4_neg.pptx'), False)
    geometry_baseline_pair(os.path.join(outdir, 'geo_base.pptx'),
                            os.path.join(outdir, 'geo_edited.pptx'))
    return outdir


if __name__ == '__main__':
    import sys, tempfile
    d = sys.argv[1] if len(sys.argv) > 1 else tempfile.mkdtemp(prefix='preprep_fixtures_')
    build_all(d)
    print('built into', d)
