#!/usr/bin/env python3
"""test_lane_font_embed.py — L15-b known-pair.

🟥 양팔은 **한 변수만 다르다** — 쓰는 서체를 `presentation.xml` 이 임베드 선언했나 안 했나.
   컨트롤이 «볼 게 없어서» 조용한 게 아님을 확인한다: 두 팔의 슬라이드 수·서체 사용
   런 수가 같고, 갈리는 것은 `<p:embeddedFont>` 블록 하나뿐이다.

   서체 이름은 **합성**이다(AcmeSans/AcmeSerif/AcmeMono). 실물 덱의 서체 이름을 픽스처에
   박지 않는다 — 공개 자산에 현장 식별자를 남기지 않는 규율이다.

    python3 test_lane_font_embed.py     # 0 통과 / 1 실패
"""
import os, sys, zipfile, tempfile, shutil

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import lane_font_embed as L   # noqa: E402

CT = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Default Extension="fntdata" ContentType="application/x-fontdata"/></Types>')

RELS = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide1.xml"/>'
        '<Relationship Id="rF1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/font" Target="fonts/font1.fntdata"/>'
        '</Relationships>')

def slide(n_latin, n_ea):
    runs = ''.join('<a:r><a:rPr><a:latin typeface="AcmeSans"/><a:ea typeface="AcmeSerif"/></a:rPr>'
                   '<a:t>x</a:t></a:r>' for _ in range(n_latin))
    return ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" '
            'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">'
            '<p:cSld><p:spTree><p:sp><p:txBody><a:p>' + runs +
            '</a:p></p:txBody></p:sp></p:spTree></p:cSld></p:sld>')

def presentation(embed):
    blk = ''
    if embed:
        blk = ('<p:embeddedFontLst>'
               '<p:embeddedFont><p:font typeface="AcmeSans"/><p:regular r:id="rF1"/></p:embeddedFont>'
               '<p:embeddedFont><p:font typeface="AcmeSerif"/><p:regular r:id="rF1"/></p:embeddedFont>'
               '</p:embeddedFontLst>')
    return ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" '
            'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
            '<p:sldIdLst><p:sldId id="256" r:id="rId1"/></p:sldIdLst>' + blk +
            '</p:presentation>')

def build(path, embed, extra_unused=False):
    pres = presentation(embed)
    if extra_unused:
        pres = pres.replace('</p:embeddedFontLst>',
                            '<p:embeddedFont><p:font typeface="AcmeMono"/>'
                            '<p:regular r:id="rF1"/></p:embeddedFont></p:embeddedFontLst>')
    with zipfile.ZipFile(path, 'w', zipfile.ZIP_DEFLATED) as z:
        z.writestr('[Content_Types].xml', CT)
        z.writestr('ppt/presentation.xml', pres)
        z.writestr('ppt/_rels/presentation.xml.rels', RELS)
        z.writestr('ppt/slides/slide1.xml', slide(12, 12))
        z.writestr('ppt/fonts/font1.fntdata', b'\x00' * 8)

def run(path, cfg_extra=None):
    cfg = {'surfaces_by_id': {'built_deck': {'path': path}}}
    if cfg_extra: cfg.update(cfg_extra)
    return L.scan(cfg, '/')

def main():
    tmp = tempfile.mkdtemp(prefix='fontembed_pair_')
    fails = []
    def chk(name, cond, extra=''):
        print('  %s %s %s' % ('✅' if cond else '❌', name, extra))
        if not cond: fails.append(name)
    try:
        good = os.path.join(tmp, 'embedded.pptx');  build(good, True)
        bad  = os.path.join(tmp, 'bare.pptx');      build(bad,  False)
        # 컨트롤 생존: 두 팔의 사용 분포가 같아야 한다
        import zipfile as _z
        u_g, _, _ = L.used_fonts(_z.ZipFile(good))
        u_b, _, _ = L.used_fonts(_z.ZipFile(bad))
        print('L15-b font-embed known-pair')
        chk('컨트롤 생존 (양팔 사용 분포 동일)', u_g == u_b and sum(u_g.values()) > 0,
            '사용 %d런' % sum(u_g.values()))

        fB, nB = run(good); fA, nA = run(bad)
        chk('B 임베드한 덱 → 발견 0', not fB, '(%d건)' % len(fB))
        chk('A 같은 덱, 임베드 선언만 뺌 → 발견', bool(fA), '(%d건)' % len(fA))
        chk('A 가 «임베드 0 은 FAIL» 이라고 말한다',
            any('UNMEASURED 가 아니라' in x for x in fA))
        chk('A 가 서체 이름과 런 수를 댄다',
            any('AcmeSans' in x and '회' in x for x in fA))

        # 면제: why 있으면 면제, 없으면 오류
        fE, nE = run(bad, {'fonts': {'embed_exempt': [
            {'fonts': ['AcmeSans', 'AcmeSerif'], 'why': '시스템 기본 서체'}]}})
        chk('C 면제 선언(why 있음) → 발견 0', not fE, '(%d건)' % len(fE))
        chk('C 면제된 것이 «면제됨»으로 출력된다',
            any('면제됨' in x for x in nE))
        fW, _ = run(bad, {'fonts': {'embed_exempt': [{'fonts': ['AcmeSans']}]}})
        chk('D why 없는 면제 → 면제가 아니라 «오류»',
            any('`why` 가 없다' in x for x in fW))

        # 임베드했지만 안 쓰는 서체는 노트로만
        un = os.path.join(tmp, 'unused.pptx'); build(un, True, extra_unused=True)
        fU, nU = run(un)
        chk('E 임베드했지만 미사용 → 발견 아님(노트)',
            not fU and any('0회인 서체' in x for x in nU))

        print('PASS' if not fails else 'FAIL · ' + ', '.join(fails))
        return 1 if fails else 0
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

if __name__ == '__main__':
    sys.exit(main())
