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
          theme_xml=None, pres_xml=None, layout_xml=None):
    with zipfile.ZipFile(path, 'w', zipfile.ZIP_DEFLATED) as z:
        z.writestr('[Content_Types].xml', CT)
        z.writestr('ppt/presentation.xml', pres_xml or PRES)
        z.writestr('ppt/_rels/presentation.xml.rels', PRES_RELS)
        z.writestr('ppt/slides/slide1.xml', slide(slide_runs))
        z.writestr('ppt/slideMasters/slideMaster1.xml', master(master_font))
        z.writestr('ppt/theme/theme1.xml', theme_xml or theme(theme_font))
        if layout_xml is not None:
            z.writestr('ppt/slideLayouts/slideLayout1.xml', layout_xml)
    return path


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
        (ok if [x for x in f4 if x[1] == 'font-theme']
         else bad)('K4: 테마 이탈이 테마 1건으로 보고된다')

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

        # K12 [A3+오탐] 렌더 안 되는 둘은 잡으면 안 된다 — 빈 런 · endParaRPr
        k12 = build(os.path.join(d, 'k12.pptx'),
                    [run('본문', 'Brand Display Bold'), empty_run('Comic Sans MS'),
                     end_para('Papyrus')])
        f12, _ = lane_font.scan(cfg_for(k12, tpl, GOOD), d)
        (ok if not f12
         else bad)(f'K12 [A3]: 빈 런·endParaRPr 는 렌더 안 되므로 이탈 아님 (실제 {len(f12)}건)')

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
