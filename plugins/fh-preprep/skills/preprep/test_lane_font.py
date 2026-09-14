#!/usr/bin/env python3
"""L15 font self-test — known-pair + 뮤턴트.

exit 0 = 전부 통과 · 1 = 실패 있음 · 2 = 픽스처 생성 불가 (UNMEASURED, 통과 아님)

🟥 이 레인이 반드시 증명해야 하는 것은 «이탈을 잡는다»가 아니라 **«상속분을 안 잡는다»** 다.
   순진한 구현은 마스터에 상속된 서체를 위반으로 세고, 실측 코퍼스에서 그 오탐이 85건이었다.
   그래서 known-negative 는 «서체가 하나뿐인 덱»이 아니라 **«마스터에 이질 서체가 있지만
   템플릿과 동일한 덱»** 이다 — 그게 실제로 틀렸던 자리다.

   K1 known-negative  마스터에 Helvetica 상속 + slides 는 허용 서체만      → finding 0
   K2 known-positive  K1 과 한 글자만 다르다: 한 런의 서체를 이탈로 바꿈    → finding 1
   K3 뮤턴트(마스터)   마스터를 템플릿과 다르게 만든다                      → 갈라짐이 보고된다
   K4 테마 이탈        테마 자체가 허용 밖                                  → 테마 1건만, 장마다 아님
   K5 선언 면제        K2 의 그 이탈을 fonts.intended 로 선언               → finding 0, 노트에 «면제됨»
   K6 미선언 degrade   template·allow 둘 다 없음                            → NOT_CONFIGURED, PASS 아님
   K7 빈 추출 degrade  slides 에 서체 토큰 0                                → UNMEASURED, 「이탈 없음」 아님
"""
import os
import re
import sys
import shutil
import zipfile
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import lane_font  # noqa: E402

PASS = FAIL = 0


def ok(m):
    global PASS
    PASS += 1
    print('  ✅', m)


def bad(m):
    global FAIL
    FAIL += 1
    print('  ❌', m)


# ── 최소 pptx 를 손으로 짓는다 (python-pptx 없이 — 의존을 늘리지 않는다) ────────────
CT = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-'
      'officedocument.presentationml.presentation.main+xml"/></Types>')
PRES = ('<p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        '<p:sldIdLst><p:sldId id="256" r:id="rId1"/></p:sldIdLst></p:presentation>')
PRES_RELS = ('<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
             '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/'
             '2006/relationships/slide" Target="slides/slide1.xml"/></Relationships>')


def theme_with_fallback(font, fb='SimSun'):
    """Office 테마가 흔히 들고 있는 «보조 스크립트 폴백» 이 섞인 테마."""
    return ('<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">'
            '<a:themeElements><a:fontScheme name="x">'
            f'<a:majorFont><a:latin typeface="{font}"/><a:ea typeface="{font}"/>'
            f'<a:font script="Hans" typeface="{fb}"/></a:majorFont>'
            f'<a:minorFont><a:latin typeface="{font}"/><a:ea typeface="{font}"/>'
            f'<a:font script="Hans" typeface="{fb}"/></a:minorFont>'
            '</a:fontScheme></a:themeElements></a:theme>')


def run_attrs_first(text, font):
    """`<a:latin pitchFamily="34" charset="0" typeface="X"/>` — PowerPoint 가 실제로 쓰는 형태."""
    return (f'<a:r><a:rPr lang="ko-KR">'
            f'<a:latin pitchFamily="34" charset="0" typeface="{font}"/></a:rPr>'
            f'<a:t>{text}</a:t></a:r>')


# 🟥 Target 이 Id 보다 «앞에» 오는 rels. OOXML 이 허용하고, 가정하면 rels 가 통째로 빈 dict 가
#    되어 장 순서가 파일명 순으로 조용히 대체된다(장 번호 어긋남 → 면제가 엉뚱한 장에 걸린다).
PRES_RELS_REVERSED = (
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Target="slides/slide1.xml" Id="rId1" '
    'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide"/>'
    '</Relationships>')


def para_default_nested(font):
    """`defRPr` 에 **자식이 있는** 형태 — 비탐욕 정규식이 여기서 끊겼다."""
    return ('<a:pPr><a:defRPr sz="1800"><a:solidFill><a:srgbClr val="000000"/></a:solidFill>'
            f'<a:latin typeface="{font}"/></a:defRPr></a:pPr>')


def theme(font):
    return ('<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">'
            '<a:themeElements><a:fontScheme name="x">'
            f'<a:majorFont><a:latin typeface="{font}"/><a:ea typeface="{font}"/></a:majorFont>'
            f'<a:minorFont><a:latin typeface="{font}"/><a:ea typeface="{font}"/></a:minorFont>'
            '</a:fontScheme></a:themeElements></a:theme>')


def run(text, font=None):
    rpr = f'<a:rPr lang="ko-KR"><a:latin typeface="{font}"/></a:rPr>' if font else '<a:rPr lang="ko-KR"/>'
    return f'<a:r>{rpr}<a:t>{text}</a:t></a:r>'


def fld(text, font):
    """`<a:fld>` — 장 번호·바닥글. 런이 아니지만 글자가 찍힌다."""
    return (f'<a:fld id="x" type="slidenum"><a:rPr lang="ko-KR">'
            f'<a:latin typeface="{font}"/></a:rPr><a:t>{text}</a:t></a:fld>')


def para_default(font):
    """`defRPr` — 박스 전체를 선택해 바꾸면 런이 아니라 여기 남는다."""
    return f'<a:pPr><a:defRPr><a:latin typeface="{font}"/></a:defRPr></a:pPr>'


def end_para(font):
    """`endParaRPr` — 빈 문단의 끝 서식. **렌더되는 글자가 없다** → 이탈이 아니다."""
    return f'<a:endParaRPr lang="ko-KR"><a:latin typeface="{font}"/></a:endParaRPr>'


def empty_run(font):
    """글자를 지우고 남은 찌꺼기 런 — 렌더되지 않으므로 이탈이 아니다."""
    return f'<a:r><a:rPr lang="ko-KR"><a:latin typeface="{font}"/></a:rPr><a:t></a:t></a:r>'


def slide(runs):
    return ('<p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" '
            'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">'
            '<p:cSld><p:spTree><p:sp><p:nvSpPr><p:cNvPr id="2" name="body"/></p:nvSpPr>'
            f'<p:txBody><a:p>{"".join(runs)}</a:p></p:txBody></p:sp></p:spTree></p:cSld></p:sld>')


def master(font):
    """마스터에 «이질 서체»를 넣는다 — 실사고가 정확히 이 형태였다(Helvetica Neue 85건)."""
    return ('<p:sldMaster xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" '
            'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">'
            f'<p:txStyles><a:lvl1pPr><a:defRPr><a:latin typeface="{font}"/></a:defRPr>'
            '</a:lvl1pPr></p:txStyles></p:sldMaster>')


# 🟥 `r:id` 가 `id` 보다 **앞에** 오는 형태. OOXML 이 허용하고, 초판 정규식은 여기서
#    빈 리스트를 냈다(예외도 안 나서 폴백조차 안 탔다 → 0건 PASS).
PRES_RID_FIRST = (
    '<p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" '
    'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
    '<p:sldIdLst><p:sldId r:id="rId1" id="256"/></p:sldIdLst></p:presentation>')


def build(path, slide_runs, master_font='Helvetica Neue', theme_font='Brand Display Bold',
          theme_xml=None, pres_xml=None, layout_xml=None, rels_xml=None):
    with zipfile.ZipFile(path, 'w', zipfile.ZIP_DEFLATED) as z:
        z.writestr('[Content_Types].xml', CT)
        z.writestr('ppt/presentation.xml', pres_xml or PRES)
        z.writestr('ppt/_rels/presentation.xml.rels', rels_xml or PRES_RELS)
        z.writestr('ppt/slides/slide1.xml', slide(slide_runs))
        z.writestr('ppt/slideMasters/slideMaster1.xml', master(master_font))
        z.writestr('ppt/theme/theme1.xml', theme_xml or theme(theme_font))
        if layout_xml is not None:
            z.writestr('ppt/slideLayouts/slideLayout1.xml', layout_xml)
    return path


# 🟥 장 순서를 실제로 재려면 **2장 이상이면서 발표순 ≠ 파일명순** 이어야 한다.
#    1장짜리로는 파일명 순 폴백과 정상 경로가 같은 답을 내서 «초록인 이유»를 구분할 수 없다 —
#    R3-4 레인이 그래서 엉뚱한 이유로 초록이었고, 4라운드가 그 뒤의 진짜 결함(r:id 파싱)을 잡았다.
# 🟥 **그런데 4라운드가 그 자리에 놓은 2장 픽스처도 안 꼬여 있었다**(5라운드 실측, 자력 적발 0 —
#    되돌림 프로브와 cross-family(codex)가 «독립적으로» 같은 것을 지목했다). 옛 판은
#    `rId2→slide1 · rId1→slide2` 라 **발표순이 [slide1, slide2] = 파일명순**이었다. 그래서
#    `_ATTR` 의 네임스페이스 수리(R4-1)를 **통째로 되돌려도 self-test 가 30/30 초록**이었다.
#    지금은 `rId2→slide2` 로 묶어 **발표순 [slide2, slide1] ≠ 파일명순 [slide1, slide2]** 다.
#    같은 되돌림에 이제 이 레인이 적색이 된다(BASE «slides 2» → MUT «slides 1»).
PRES_2 = ('<p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" '
          'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
          '<p:sldIdLst><p:sldId id="256" r:id="rId2"/><p:sldId id="257" r:id="rId1"/>'
          '</p:sldIdLst></p:presentation>')
# rId2→slide2, rId1→slide1 : 발표 1장 = slide2.xml, 발표 2장 = slide1.xml.
# 파일명 순 폴백이면 순서가 뒤집혀 장 번호가 어긋나고 면제가 엉뚱한 장에 걸린다.
PRES_RELS_2 = ('<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
               '<Relationship Id="rId2" Target="slides/slide2.xml" '
               'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide"/>'
               '<Relationship Id="rId1" Target="slides/slide1.xml" '
               'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide"/>'
               '</Relationships>')
# 🟥 R3-4 전용 — 위와 같은 꼬임에 **Target 이 Id 보다 앞에** 온다. 둘을 같이 걸어야
#    «rels 속성 순서»의 수리가 되돌려질 때 적색이 된다(1장짜리로는 폴백과 같은 답).
PRES_RELS_2_TARGET_FIRST = (
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Target="slides/slide2.xml" Id="rId2" '
    'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide"/>'
    '<Relationship Target="slides/slide1.xml" Id="rId1" '
    'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide"/>'
    '</Relationships>')


def build2(path, runs1, runs2, tpl_theme='Brand Display Bold', rels_xml=None):
    """2장 덱. **발표순** 1장=runs1 · 2장=runs2.

    🟥 파일명순은 그 반대다 — runs1 은 `slide2.xml`, runs2 는 `slide1.xml` 에 들어간다.
       그래야 «장 순서를 못 읽고 파일명 순으로 떨어지는» 결함이 **관측 가능한 차이**를 낸다.
    """
    with zipfile.ZipFile(path, 'w', zipfile.ZIP_DEFLATED) as z:
        z.writestr('[Content_Types].xml', CT)
        z.writestr('ppt/presentation.xml', PRES_2)
        z.writestr('ppt/_rels/presentation.xml.rels', rels_xml or PRES_RELS_2)
        z.writestr('ppt/slides/slide2.xml', slide(runs1))
        z.writestr('ppt/slides/slide1.xml', slide(runs2))
        z.writestr('ppt/slideMasters/slideMaster1.xml', master('Helvetica Neue'))
        z.writestr('ppt/theme/theme1.xml', theme(tpl_theme))
    return path


def slot_run(text, font, slot):
    """`<a:ea>` / `<a:cs>` 슬롯에만 서체가 있는 런 — 한중일·아랍 문자의 글꼴 자리."""
    return (f'<a:r><a:rPr lang="ko-KR"><a:{slot} typeface="{font}"/></a:rPr>'
            f'<a:t>{text}</a:t></a:r>')


def comment_run(text, font):
    """**주석 처리된 런** — 도형을 통째로 주석으로 남긴 형태. 어디서도 렌더되지 않는다.

    🟥 픽스처는 «뚫리는 표기»여야 한다. 벌거벗은 `<!-- <a:latin .../> -->` 로는 이 레인이
       못 판별한다 — 그건 런 밖이라 `_occurrences` 가 어차피 안 본다(주석 제거를 되돌려도
       초록이었다, 5라운드 자기 되돌림 실측). 런 «안»에 넣어야 주석 제거가 하중을 진다
       ([[feedback_fixture_must_use_the_breaking_spelling]]).
    """
    return (f'<!-- <a:r><a:rPr lang="ko-KR"><a:latin typeface="{font}"/></a:rPr>'
            f'<a:t>{text}</a:t></a:r> -->')


def sym_run(font):
    """`<a:sym>` — 기호 글꼴 슬롯. 실물 덱에 157개 있었다."""
    return (f'<a:r><a:rPr lang="ko-KR"><a:sym typeface="{font}"/></a:rPr>'
            f'<a:t>기호</a:t></a:r>')


def run_xmlspace(text, font):
    """`<a:t xml:space="preserve">` — 앞뒤 공백이 있으면 PowerPoint 가 붙인다."""
    return (f'<a:r><a:rPr lang="ko-KR"><a:latin typeface="{font}"/></a:rPr>'
            f'<a:t xml:space="preserve"> {text} </a:t></a:r>')


def cfg_for(deck, tpl=None, allow=None, intended=None):
    c = {'surfaces_by_id': {'built_deck': {'path': os.path.basename(deck)}}, 'fonts': {}}
    if tpl:
        c['fonts']['template'] = os.path.basename(tpl)
    if allow:
        c['fonts']['allow'] = allow
    if intended:
        c['fonts']['intended'] = intended
    return c


def main():
    d = tempfile.mkdtemp(prefix='lanefont_')
    try:
        GOOD = ['Brand Display Bold', 'Brand Text Regular']
        tpl = build(os.path.join(d, 'tpl.pptx'),
                    [run('템플릿 본문', 'Brand Display Bold')])

        # K1 — 마스터 상속 이질 서체가 있어도 저자 이탈은 0
        k1 = build(os.path.join(d, 'k1.pptx'), [run('본문', 'Brand Display Bold')])
        f, n = lane_font.scan(cfg_for(k1, tpl, GOOD), d)
        (ok if not f else bad)(f'K1 known-negative: 상속 Helvetica 있어도 finding {len(f)} (0 이어야)')
        (ok if any('상속 확인' in x for x in n) else bad)('K1: 상속 확인 노트가 나온다')

        # K2 — 한 런만 이탈시킨다 (K1 과 단일 변수)
        k2 = build(os.path.join(d, 'k2.pptx'),
                   [run('본문', 'Brand Display Bold'), run('코드', 'Comic Sans MS')])
        f2, _ = lane_font.scan(cfg_for(k2, tpl, GOOD), d)
        (ok if len(f2) == 1 and 'Comic Sans MS' in f2[0][3]
         else bad)(f'K2 known-positive: 이탈 1건 잡힌다 (실제 {len(f2)})')

        # K3 — 마스터를 템플릿과 다르게: 갈라짐이 보고돼야 한다
        k3 = build(os.path.join(d, 'k3.pptx'), [run('본문', 'Brand Display Bold')],
                   master_font='Papyrus')
        _, n3 = lane_font.scan(cfg_for(k3, tpl, GOOD), d)
        (ok if any('갈라진 부품' in x for x in n3)
         else bad)('K3 뮤턴트: 템플릿에서 갈라진 마스터가 보고된다')

        # K4 — 테마 자체가 이탈. 장마다가 아니라 테마 1건으로
        k4 = build(os.path.join(d, 'k4.pptx'), [run('본문', 'Brand Display Bold')],
                   theme_font='Papyrus')
        f4, _ = lane_font.scan(cfg_for(k4, tpl, GOOD), d)
        # 🟥 5라운드(codex) 지적 — 옛 판은 «있다»만 봤다. 이름이 «테마 **1건**으로»인데
        #    2건이 나와도 초록이었다(중복 지적을 심어 실측: 30/30 그대로). 개수를 박는다.
        _f4t = [x for x in f4 if x[1] == 'font-theme']
        (ok if len(_f4t) == 1 and not [x for x in f4 if x[1] == 'font']
         else bad)(f'K4: 테마 이탈이 테마 «1건»으로만 보고된다 (theme={len(_f4t)} · slide={len([x for x in f4 if x[1] == "font"])})')

        # K5 — 선언 면제
        f5, n5 = lane_font.scan(
            cfg_for(k2, tpl, GOOD,
                    intended=[{'fonts': ['Comic Sans MS'], 'why': '코드 화면 고정폭'}]), d)
        (ok if not f5 and any('면제됨' in x for x in n5)
         else bad)(f'K5: 선언 면제되면 finding 0 + «면제됨» 노트 (실제 {len(f5)})')

        # K6 — 미선언 degrade
        f6, n6 = lane_font.scan({'surfaces_by_id': {'built_deck': {'path': 'k1.pptx'}}}, d)
        (ok if not f6 and any('NOT_CONFIGURED' in x for x in n6)
         else bad)('K6: template·allow 미선언 → NOT_CONFIGURED (PASS 아님)')

        # K7 — 서체 토큰 0 → UNMEASURED
        k7 = build(os.path.join(d, 'k7.pptx'), [run('본문')])
        f7, n7 = lane_font.scan(cfg_for(k7, tpl, GOOD), d)
        (ok if not f7 and any('UNMEASURED' in x for x in n7)
         else bad)('K7: 서체 토큰 0 → UNMEASURED («이탈 없음» 아님)')

        # K8 — 가족 단위 허용: 「Brand Display」 선언이 Bold 변형을 덮는다
        f8, _ = lane_font.scan(cfg_for(k1, tpl, ['Brand Display']), d)
        (ok if not f8 else bad)('K8: 가족 이름만 선언해도 굵기 변형이 허용된다')

        # K8b — 역방향 누수: allow=["Arial Black"] 이 tf="Arial" 을 열면 안 된다
        (ok if not lane_font._allowed('Arial', ['Arial Black'])
         else bad)('K8b: 허용은 «가족→변형» 한 방향뿐 (역방향 누수 없음)')

        # ── 아래 넷은 cross-family(agy 3.1 Pro) 지적으로 닫은 구멍이다 ──────────
        # K9 [S1] 마스터를 변조해 금지 서체를 꽂으면 — 노트가 아니라 finding 이어야 한다
        k9 = build(os.path.join(d, 'k9.pptx'), [run('본문', 'Brand Display Bold')],
                   master_font='Comic Sans MS')
        f9, _ = lane_font.scan(cfg_for(k9, tpl, GOOD), d)
        (ok if [x for x in f9 if x[1] == 'font-inherited-drift']
         else bad)(f'K9 [S1]: 변조된 마스터의 금지 서체가 finding 으로 뜬다 (실제 {len(f9)}건)')

        # K10 [S2] 박스 전체 서체 변경(런이 아니라 defRPr 에 남는다)
        k10 = build(os.path.join(d, 'k10.pptx'),
                    [para_default('Comic Sans MS') + run('본문', 'Brand Display Bold')])
        f10, _ = lane_font.scan(cfg_for(k10, tpl, GOOD), d)
        (ok if [x for x in f10 if 'Comic Sans' in x[3]]
         else bad)('K10 [S2]: 단락 기본서식(defRPr)의 이탈이 잡힌다')

        # K11 [S3] `<a:fld>` 안의 이탈
        k11 = build(os.path.join(d, 'k11.pptx'),
                    [run('본문', 'Brand Display Bold'), fld('12', 'Comic Sans MS')])
        f11, _ = lane_font.scan(cfg_for(k11, tpl, GOOD), d)
        (ok if [x for x in f11 if 'Comic Sans' in x[3]]
         else bad)('K11 [S3]: 장 번호 필드(a:fld)의 이탈이 잡힌다')

        # K12 [A3] 빈 런은 렌더 안 되므로 이탈이 아니다
        # 🟥 5라운드(codex) 지적으로 **쪼갰다** — 옛 판은 빈 런과 endParaRPr 을 한 픽스처에
        #    넣고 `not f12` 만 봤다. 통과가 둘 중 어느 쪽에 귀속되는지 알 수 없었다.
        k12 = build(os.path.join(d, 'k12.pptx'),
                    [run('본문', 'Brand Display Bold'), empty_run('Comic Sans MS')])
        f12, _ = lane_font.scan(cfg_for(k12, tpl, GOOD), d)
        (ok if not f12
         else bad)(f'K12 [A3]: 빈 런은 렌더 안 되므로 이탈 아님 (실제 {len(f12)}건)')
        # K12b endParaRPr 단독 — 같은 이유로 따로 잰다
        k12b = build(os.path.join(d, 'k12b.pptx'),
                     [run('본문', 'Brand Display Bold'), end_para('Papyrus')])
        f12b, _ = lane_font.scan(cfg_for(k12b, tpl, GOOD), d)
        (ok if not f12b
         else bad)(f'K12b: 빈 문단 endParaRPr 은 렌더 안 되므로 이탈 아님 (실제 {len(f12b)}건)')

        # K13 [R2-3, 1라운드 A2 되돌림] 템플릿 마스터가 쓰는 서체여도 **finding 은 남는다**.
        #     억제하면 저자가 Office 기본값(Arial·Calibri)으로 본문을 찍어도 종료코드가 안 움직인다.
        k13 = build(os.path.join(d, 'k13.pptx'),
                    [run('본문', 'Brand Display Bold'), run('각주', 'Helvetica Neue')])
        f13, n13 = lane_font.scan(cfg_for(k13, tpl, GOOD), d)
        (ok if len(f13) == 1 and '템플릿 자신의 마스터' in f13[0][4]
         else bad)(f'K13 [R2-3]: 템플릿도 쓰는 이름이어도 finding 유지 + 맥락 주석 (실제 {len(f13)}건)')

        # ── R2: 2라운드(agy 3.8 Flash High)가 새로 문 여섯 ──────────────────────
        # R2-1 [S] 자식 있는 defRPr — 비탐욕 정규식이 첫 self-closing 에서 끊겼다
        r1 = build(os.path.join(d, 'r1.pptx'),
                   [para_default_nested('Comic Sans MS') + run('본문', 'Brand Display Bold')])
        fr1, _ = lane_font.scan(cfg_for(r1, tpl, GOOD), d)
        (ok if [x for x in fr1 if 'Comic Sans' in x[3]]
         else bad)('R2-1 [S]: 자식 있는 defRPr 의 서체를 조용히 버리지 않는다')

        # R2-2 [S] `r:id` 가 앞에 오는 presentation.xml → 0장 = UNMEASURED, PASS 아님
        r2 = build(os.path.join(d, 'r2.pptx'), [run('코드', 'Comic Sans MS')],
                   pres_xml=PRES_RID_FIRST)
        fr2, _ = lane_font.scan(cfg_for(r2, tpl, GOOD), d)
        (ok if [x for x in fr2 if 'Comic Sans' in x[3]]
         else bad)('R2-2 [S]: 속성 순서가 달라도 장을 읽는다(빈 order 로 조용히 통과 안 함)')

        # R2-4 [A] 테마의 보조 스크립트 폴백(SimSun)은 위반이 아니다
        r4 = build(os.path.join(d, 'r4.pptx'), [run('본문', 'Brand Display Bold')],
                   theme_xml=theme_with_fallback('Brand Display Bold'))
        fr4, _ = lane_font.scan(cfg_for(r4, tpl, GOOD), d)
        (ok if not [x for x in fr4 if x[1] == 'font-theme']
         else bad)('R2-4 [A]: 테마 script 폴백(SimSun)을 위반으로 세지 않는다')

        # R2-5 [A] 면제도 가족 단위 — "Roboto Mono" 선언이 "Roboto Mono Bold" 를 덮는다
        r5 = build(os.path.join(d, 'r5.pptx'),
                   [run('본문', 'Brand Display Bold'), run('$ git', 'Roboto Mono Bold')])
        fr5, _ = lane_font.scan(
            cfg_for(r5, tpl, GOOD,
                    intended=[{'fonts': ['Roboto Mono'], 'why': '코드 화면'}]), d)
        (ok if not fr5 else bad)(f'R2-5 [A]: 면제도 가족 단위 (실제 {len(fr5)}건)')

        # R2-6 [A] 레이아웃이 갈라져도 «원래 있던» 서체는 이탈이 아니다 — 새로 들인 것만
        LAY_T = ('<p:sldLayout xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" '
                 'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">'
                 '<a:latin typeface="Helvetica Neue"/></p:sldLayout>')
        LAY_D = LAY_T.replace('</p:sldLayout>', '<a:ext cx="1"/></p:sldLayout>')   # 크기만 바뀜
        tpl6 = build(os.path.join(d, 'tpl6.pptx'), [run('본문', 'Brand Display Bold')],
                     layout_xml=LAY_T)
        r6 = build(os.path.join(d, 'r6.pptx'), [run('본문', 'Brand Display Bold')],
                   layout_xml=LAY_D)
        fr6, _ = lane_font.scan(cfg_for(r6, tpl6, GOOD), d)
        (ok if not [x for x in fr6 if x[1] == 'font-inherited-drift']
         else bad)(f'R2-6 [A]: 갈라진 부품의 «원래» 서체는 이탈 아님 (실제 {len(fr6)}건)')

        # ── R3: 3라운드가 문 넷 ────────────────────────────────────────────────
        # R3-2 [S] 속성이 typeface 앞에 오면 서체를 통째로 놓쳤다
        r3a = build(os.path.join(d, 'r3a.pptx'),
                    [run('본문', 'Brand Display Bold'), run_attrs_first('코드', 'Comic Sans MS')])
        f3a, _ = lane_font.scan(cfg_for(r3a, tpl, GOOD), d)
        (ok if [x for x in f3a if 'Comic Sans' in x[3]]
         else bad)('R3-2 [S]: 속성 순서와 무관하게 서체를 읽는다')

        # R3-4 [S/A] rels 의 Id/Target 순서가 뒤집혀도 장 순서를 읽는다
        # 🟥 5라운드 교체 — 옛 판은 **1장 픽스처**라 파일명 순 폴백과 정상 경로가 같은 답
        #    («slides 1»)을 냈다. rels 수리를 되돌려도 초록이었다(실측). 2장 + 꼬임 +
        #    Target-before-Id 로 바꿔 **되돌리면 «slides 1» 로 어긋나게** 만든다.
        r3b = build2(os.path.join(d, 'r3b.pptx'),
                     [run('본문', 'Brand Display Bold')], [run('코드', 'Comic Sans MS')],
                     rels_xml=PRES_RELS_2_TARGET_FIRST)
        f3b, n3b = lane_font.scan(cfg_for(r3b, tpl, GOOD), d)
        (ok if [x for x in f3b if 'slides 2' in x[2]]
         else bad)(f'R3-4 [S]: rels 속성 순서가 달라도 장 번호가 맞다 ({[x[2] for x in f3b]})')

        # R3-3 [A] 테마 이탈도 선언 면제를 존중한다
        r3c = build(os.path.join(d, 'r3c.pptx'), [run('본문', 'Brand Display Bold')],
                    theme_font='Papyrus')
        f3c, _ = lane_font.scan(
            cfg_for(r3c, tpl, GOOD, intended=[{'fonts': ['Papyrus'], 'why': '테마 기본값 승인'}]), d)
        (ok if not [x for x in f3c if x[1] == 'font-theme']
         else bad)('R3-3 [A]: 테마 이탈도 fonts.intended 를 존중한다')

        # R3-5 [A] 갈라진 부품의 endParaRPr 은 렌더 안 되므로 이탈이 아니다
        LAY_T2 = ('<p:sldLayout xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" '
                  'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">'
                  '<a:latin typeface="Helvetica Neue"/></p:sldLayout>')
        LAY_D2 = LAY_T2.replace('</p:sldLayout>',
                                '<a:p><a:endParaRPr><a:latin typeface="Papyrus"/></a:endParaRPr>'
                                '</a:p></p:sldLayout>')
        tpl3 = build(os.path.join(d, 'tpl3.pptx'), [run('본문', 'Brand Display Bold')],
                     layout_xml=LAY_T2)
        r3d = build(os.path.join(d, 'r3d.pptx'), [run('본문', 'Brand Display Bold')],
                    layout_xml=LAY_D2)
        f3d, _ = lane_font.scan(cfg_for(r3d, tpl3, GOOD), d)
        (ok if not [x for x in f3d if x[1] == 'font-inherited-drift']
         else bad)('R3-5 [A]: 갈라진 부품의 endParaRPr 은 이탈이 아니다')

        # ── R4: 4라운드가 문 넷 (그중 하나는 R3 수리가 심은 결함이다) ──────────────
        # R4-1 [S] `r:id` 네임스페이스 접두사 — 장 순서가 파일명 순으로 조용히 떨어졌다.
        #      2장 덱으로 «순서»를 실제로 검증한다(1장짜리로는 폴백과 구분 불가 → R3-4 의 교훈)
        r41 = build2(os.path.join(d, 'r41.pptx'),
                     [run('본문', 'Brand Display Bold')],
                     [run('코드', 'Comic Sans MS')])
        f41, _ = lane_font.scan(cfg_for(r41, tpl, GOOD), d)
        (ok if [x for x in f41 if 'slides 2' in x[2]]
         else bad)(f'R4-1 [S]: r:id 를 읽어 발표순 2장으로 잡는다 (실제 {[x[2] for x in f41]})')
        # 컨트롤 — 면제를 «2장»에 걸면 먹고, 1장에 걸면 안 먹어야 한다
        f41b, _ = lane_font.scan(
            cfg_for(r41, tpl, GOOD, intended=[{'slides': [2], 'fonts': ['Comic Sans MS'],
                                               'why': '2장 면제'}]), d)
        f41c, _ = lane_font.scan(
            cfg_for(r41, tpl, GOOD, intended=[{'slides': [1], 'fonts': ['Comic Sans MS'],
                                               'why': '1장 면제'}]), d)
        (ok if not f41b and f41c
         else bad)(f'R4-1 컨트롤: 면제가 «발표순» 장 번호를 따른다 (2장면제={len(f41b)} 1장면제={len(f41c)})')

        # R4-2 [S] `<a:t xml:space="preserve">` 를 못 읽어 런을 통째로 건너뛰었다
        r42 = build(os.path.join(d, 'r42.pptx'),
                    [run('본문', 'Brand Display Bold'), run_xmlspace('코드', 'Comic Sans MS')])
        f42, _ = lane_font.scan(cfg_for(r42, tpl, GOOD), d)
        (ok if [x for x in f42 if 'Comic Sans' in x[3]]
         else bad)('R4-2 [S]: xml:space 속성이 붙은 a:t 도 읽는다')

        # R4-3 [S] 템플릿의 endParaRPr 잔재가 허용 집합으로 «승격»되면 안 된다
        tpl43 = build(os.path.join(d, 'tpl43.pptx'),
                      [run('본문', 'Brand Display Bold'), end_para('Comic Sans MS')])
        r43 = build(os.path.join(d, 'r43.pptx'),
                    [run('본문', 'Brand Display Bold'), run('코드', 'Comic Sans MS')])
        f43, _ = lane_font.scan(cfg_for(r43, tpl43), d)   # allow 미선언 → 템플릿에서 유도
        (ok if [x for x in f43 if 'Comic Sans' in x[3]]
         else bad)('R4-3 [S]: 템플릿의 렌더 안 되는 끝 서식은 허용으로 승격되지 않는다')

        # R4-4 [S] `<a:sym>` 기호 글꼴 슬롯
        r44 = build(os.path.join(d, 'r44.pptx'),
                    [run('본문', 'Brand Display Bold'), sym_run('Wingdings')])
        f44, _ = lane_font.scan(cfg_for(r44, tpl, GOOD), d)
        (ok if [x for x in f44 if 'Wingdings' in x[3]]
         else bad)('R4-4 [S]: a:sym 기호 슬롯의 이탈도 잡는다')

        # ── R5: 5라운드 (cross-family codex + 되돌림 프로브) ────────────────────
        # R5-1 [S] 템플릿의 «렌더 안 되는» 토큰이 허용 집합으로 승격되면 안 된다.
        #      4라운드가 endParaRPr 한 자리만 깁었고, 같은 뿌리의 다른 자리가 남아 있었다:
        #      글자 없는 빈 런 · XML 주석. 유도를 판정과 같은 함수(`_occurrences`)로 통일했다.
        tpl51 = build(os.path.join(d, 'tpl51.pptx'),
                      [run('본문', 'Brand Display Bold'), empty_run('Comic Sans MS')])
        r51 = build(os.path.join(d, 'r51.pptx'),
                    [run('본문', 'Brand Display Bold'), run('코드', 'Comic Sans MS')])
        f51, _ = lane_font.scan(cfg_for(r51, tpl51), d)      # allow 미선언 → 템플릿에서 유도
        (ok if [x for x in f51 if 'Comic Sans' in x[3]]
         else bad)(f'R5-1 [S]: 템플릿의 «빈 런» 서체는 허용으로 승격되지 않는다 (실제 {len(f51)}건)')
        # R5-1 컨트롤 — 템플릿이 그 서체를 **실제로 찍으면** 허용이 맞다(과교정 방지)
        tpl51c = build(os.path.join(d, 'tpl51c.pptx'),
                       [run('본문', 'Brand Display Bold'), run('코드', 'Comic Sans MS')])
        f51c, _ = lane_font.scan(cfg_for(r51, tpl51c), d)
        (ok if not f51c
         else bad)(f'R5-1 컨트롤: 템플릿이 실제로 찍는 서체는 허용된다 (실제 {len(f51c)}건)')
        # R5-1b [S] 주석 안의 서체 선언도 승격되면 안 된다 — 어디서도 렌더되지 않는다
        tpl51b = build(os.path.join(d, 'tpl51b.pptx'),
                       [comment_run('주석 처리된 도형', 'Comic Sans MS'), run('본문', 'Brand Display Bold')])
        f51b, _ = lane_font.scan(cfg_for(r51, tpl51b), d)
        (ok if [x for x in f51b if 'Comic Sans' in x[3]]
         else bad)(f'R5-1b [S]: 템플릿 주석의 서체는 허용으로 승격되지 않는다 (실제 {len(f51b)}건)')
        # R5-1c 판정 쪽에서도 주석은 안 센다 (같은 규칙이 양쪽에 걸린다 — 비대칭 재발 방지)
        r51c = build(os.path.join(d, 'r51c.pptx'),
                     [run('본문', 'Brand Display Bold'), comment_run('주석 처리된 도형', 'Papyrus')])
        f51d, _ = lane_font.scan(cfg_for(r51c, tpl, GOOD), d)
        (ok if not f51d
         else bad)(f'R5-1c: 덱 쪽 주석도 이탈로 세지 않는다 (실제 {len(f51d)}건)')

        # R5-3 [S] `ea`/`cs` 슬롯 — 1라운드(A1)가 연 자리인데 **레인이 없었다**.
        #      `_FONT_TAG` 에서 `ea|cs` 를 빼도 self-test 가 30/30 초록이었다(되돌림 실측).
        r53 = build(os.path.join(d, 'r53.pptx'),
                    [run('본문', 'Brand Display Bold'), slot_run('한자', 'Comic Sans MS', 'ea')])
        f53, _ = lane_font.scan(cfg_for(r53, tpl, GOOD), d)
        (ok if [x for x in f53 if 'Comic Sans' in x[3] and 'ea' in x[4]]
         else bad)(f'R5-3 [S]: a:ea 슬롯의 이탈도 잡고 슬롯 이름을 낸다 (실제 {len(f53)}건)')
        r53b = build(os.path.join(d, 'r53b.pptx'),
                     [run('본문', 'Brand Display Bold'), slot_run('نص', 'Papyrus', 'cs')])
        f53b, _ = lane_font.scan(cfg_for(r53b, tpl, GOOD), d)
        (ok if [x for x in f53b if 'Papyrus' in x[3] and 'cs' in x[4]]
         else bad)(f'R5-3b [S]: a:cs 슬롯의 이탈도 잡는다 (실제 {len(f53b)}건)')

        # R5-4 [A] 차트·SmartArt — 렌더되지만 `slides/` 밖이라 안 읽는다.
        #      5라운드(codex) 지목: 옛 판은 그 상태에서 «이탈 0종» 을 자신 있게 찍었다.
        #      스캔 범위를 넓히는 것은 별도 작업이고, 여기서 닫는 것은 **0 으로 렌더하지 않기**다.
        CHART = ('<c:chartSpace xmlns:c="http://schemas.openxmlformats.org/drawingml/2006/chart" '
                 'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><c:chart><c:title>'
                 '<c:tx><c:rich><a:p><a:r><a:rPr><a:latin typeface="Comic Sans MS"/></a:rPr>'
                 '<a:t>차트 제목</a:t></a:r></a:p></c:rich></c:tx></c:title></c:chart></c:chartSpace>')
        r54 = build(os.path.join(d, 'r54.pptx'), [run('본문', 'Brand Display Bold')])
        with zipfile.ZipFile(r54, 'a', zipfile.ZIP_DEFLATED) as _z:
            _z.writestr('ppt/charts/chart1.xml', CHART)
        f54, n54 = lane_font.scan(cfg_for(r54, tpl, GOOD), d)
        (ok if any('안 읽는' in x and 'UNMEASURED' in x for x in n54)
         else bad)('R5-4 [A]: 안 읽는 부품(차트)에 서체가 있으면 UNMEASURED 로 센다')
        # R5-4 컨트롤 — 그런 부품이 없으면 그 노트는 안 나온다 (계기가 «항상 찍는» 게 아니다)
        f54b, n54b = lane_font.scan(cfg_for(build(os.path.join(d, 'r54b.pptx'),
                                                  [run('본문', 'Brand Display Bold')]),
                                            tpl, GOOD), d)
        (ok if not any('안 읽는' in x for x in n54b)
         else bad)('R5-4 컨트롤: 그런 부품이 없으면 노트도 없다')

        # R5-5 [S] 작은따옴표 속성 — XML 이 허용한다. 못 읽으면 «부분 추출 실패»가
        #      다른 런 덕에 UNMEASURED 도 못 타고 자신 있는 «이탈 0종» 으로 나간다.
        r55 = build(os.path.join(d, 'r55.pptx'),
                    [run('본문', 'Brand Display Bold'),
                     "<a:r><a:rPr lang=\'ko-KR\'><a:latin typeface=\'Comic Sans MS\'/>"
                     "</a:rPr><a:t>코드</a:t></a:r>"])
        f55, _ = lane_font.scan(cfg_for(r55, tpl, GOOD), d)
        (ok if [x for x in f55 if 'Comic Sans' in x[3]]
         else bad)(f'R5-5 [S]: 작은따옴표 속성의 서체도 읽는다 (실제 {len(f55)}건)')

        # R5-6 [A] DrawingML 을 `a` 아닌 접두사로 묶은 장 — 못 읽는다. 0 이 아니라 «못 쟀다».
        FOREIGN = ('<p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" '
                   'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
                   'xmlns:dm="http://schemas.openxmlformats.org/drawingml/2006/main">'
                   '<p:cSld><p:spTree><p:sp><p:txBody><a:p>'
                   '<a:r><a:rPr><a:latin typeface="Brand Display Bold"/></a:rPr><a:t>ok</a:t></a:r>'
                   '<dm:r><dm:rPr><dm:latin typeface="Comic Sans MS"/></dm:rPr>'
                   '<dm:t>bad</dm:t></dm:r>'
                   '</a:p></p:txBody></p:sp></p:spTree></p:cSld></p:sld>')
        r56 = os.path.join(d, 'r56.pptx')
        with zipfile.ZipFile(r56, 'w', zipfile.ZIP_DEFLATED) as _z:
            _z.writestr('[Content_Types].xml', CT)
            _z.writestr('ppt/presentation.xml', PRES)
            _z.writestr('ppt/_rels/presentation.xml.rels', PRES_RELS)
            _z.writestr('ppt/slides/slide1.xml', FOREIGN)
            _z.writestr('ppt/slideMasters/slideMaster1.xml', master('Helvetica Neue'))
            _z.writestr('ppt/theme/theme1.xml', theme('Brand Display Bold'))
        f56, n56 = lane_font.scan(cfg_for(r56, tpl, GOOD), d)
        (ok if any('접두사' in x and 'UNMEASURED' in x for x in n56)
         else bad)('R5-6 [A]: `a` 아닌 DrawingML 접두사는 UNMEASURED 로 센다 («이탈 0» 아님)')
        # R5-6 컨트롤 — 평범한 장에서는 그 노트가 안 나온다
        _, n56b = lane_font.scan(cfg_for(k1, tpl, GOOD), d)
        (ok if not any('접두사' in x for x in n56b)
         else bad)('R5-6 컨트롤: `a:` 만 쓰는 장에는 그 노트가 없다')

        # R2-6b 대조 — 갈라진 부품에 «새로» 들인 서체는 여전히 잡힌다 (과교정 방지)
        LAY_NEW = LAY_T.replace('</p:sldLayout>', '<a:latin typeface="Papyrus"/></p:sldLayout>')
        r6b = build(os.path.join(d, 'r6b.pptx'), [run('본문', 'Brand Display Bold')],
                    layout_xml=LAY_NEW)
        fr6b, _ = lane_font.scan(cfg_for(r6b, tpl6, GOOD), d)
        (ok if [x for x in fr6b if x[1] == 'font-inherited-drift']
         else bad)('R2-6b 과교정 방지: 갈라진 부품에 새로 들인 서체는 잡는다')
    finally:
        shutil.rmtree(d, ignore_errors=True)

    print(f'\nL15 font self-test — PASS {PASS} · FAIL {FAIL}')
    return 1 if FAIL else 0


if __name__ == '__main__':
    sys.exit(main())
