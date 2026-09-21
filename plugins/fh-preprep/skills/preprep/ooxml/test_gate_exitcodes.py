#!/usr/bin/env python3
"""test_gate_exitcodes.py — gate.py 종료코드 계약의 known-pair.

🟥 재는 것은 «결함을 찾나»가 아니라 **«판정불가를 발견으로 렌더하지 않나»**다.
   실사고(2026-09-21): 정본 v1.4 에 `docProps/app.xml` 이 없어 게이트가 FileNotFoundError 로
   죽으면서 **rc=1(발견)** 을 냈다. 한 줄도 검사하지 못한 상태가 「결함을 찾았다」로 읽혔다.

   양팔은 **한 변수만 다르다** — 같은 덱에서 `docProps/app.xml` 하나를 뺐나 넣었나.
   컨트롤이 «볼 게 없어서» 조용한 것이 아님을 P1 에서 확인한다(장 수가 같다).

    python3 test_gate_exitcodes.py        # 전 팔 실행. 종료코드 0 통과 / 1 실패

의존: python-pptx (픽스처를 그때그때 굽는다 — 바이너리를 레포에 안 둔다,
      `fixtures/mk_slide_fixtures.py` 와 같은 관례).
"""
import os, sys, shutil, zipfile, subprocess, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
GATE = os.path.join(HERE, 'gate.py')

def build_tree(dest):
    """python-pptx 로 빈 덱을 굽고 풀어서 «정상 트리»를 만든다."""
    from pptx import Presentation
    pptx = os.path.join(dest, 'probe.pptx')
    prs = Presentation()
    prs.slides.add_slide(prs.slide_layouts[6])   # 빈 레이아웃
    prs.save(pptx)
    tree = os.path.join(dest, 'tree')
    with zipfile.ZipFile(pptx) as z: z.extractall(tree)
    return tree

def ensure_app_xml(tree, n_slides=1):
    """app.xml 을 **항상 다시 쓴다** — 컨트롤 팔이 깨끗해야 하기 때문이다.

    🟥 이 함수가 원래는 «없으면 만든다» 였는데, 그러면 컨트롤이 rc=1 로 떨어졌다.
       원인이 곧 체크리스트 §F5 다: **python-pptx 의 기본 템플릿이 자기 app.xml 을 통짜로
       물려준다** — 1장짜리 덱인데 `<Slides>` 는 템플릿 값이라 ④ 가 정확히 그걸 잡는다.
       즉 컨트롤의 실패는 게이트의 결함이 아니라 **참인 발견**이었다. 그래서 억누르는 대신
       **팔을 제대로 굽는다** — 부재 축 하나만 남기려면 나머지가 참이어야 한다.
    """
    p = os.path.join(tree, 'docProps', 'app.xml')
    os.makedirs(os.path.dirname(p), exist_ok=True)
    open(p, 'w', encoding='utf-8').write(
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties"'
        ' xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">'
        '<Slides>%d</Slides><Notes>%d</Notes>'
        '<TitlesOfParts><vt:vector size="%d" baseType="lpstr">%s</vt:vector></TitlesOfParts>'
        '</Properties>' % (n_slides, n_slides, n_slides, '<vt:lpstr>p</vt:lpstr>' * n_slides))
    return True

def run_gate(tree):
    r = subprocess.run([sys.executable, GATE, tree], capture_output=True, text=True)
    return r.returncode, (r.stdout + r.stderr)

def main():
    tmp = tempfile.mkdtemp(prefix='gate_pair_')
    try:
        tree = build_tree(tmp)
        n = len([f for f in os.listdir(os.path.join(tree, 'ppt', 'slides'))
                 if f.startswith('slide') and f.endswith('.xml')])
        ensure_app_xml(tree, n)

        # ── ARM B (known-negative / 컨트롤): 부품이 다 있다 → 0 이어야 한다
        rc_b, out_b = run_gate(tree)

        # ── ARM A (known-positive): app.xml 하나만 뺀다 → 2 여야 한다 (1 이면 회귀)
        armA = tree + '_noapp'
        shutil.copytree(tree, armA)
        os.remove(os.path.join(armA, 'docProps', 'app.xml'))
        n_a = len([f for f in os.listdir(os.path.join(armA, 'ppt', 'slides'))
                   if f.startswith('slide') and f.endswith('.xml')])
        rc_a, out_a = run_gate(armA)

        # ── ARM C: 트리 자체가 없다 → 2 (예전엔 1 이었다)
        rc_c, out_c = run_gate(os.path.join(tmp, 'nope'))

        # ── ARM D/E: C1 기준선 «덱별» 계약 ─────────────────────────────────
        # 🟥 재는 것: 전역 기준선으로 «늘었다»를 판정하지 않나. 실사고 — 외부 디자인 검수본에서
        #    「토큰 밖 8종」이 떴는데 직전 판과 선굵기 히스토그램이 사실상 같았다. 저쪽 탓이
        #    아니라 기준선이 이 덱 것이 아니었다. 그 수치는 인용되면 안 되는 값이었다.
        armD = tree + '_c1'
        shutil.copytree(tree, armD)
        sp = os.path.join(armD, 'ppt', 'slides', 'slide1.xml')
        x = open(sp, encoding='utf-8').read()
        # 토큰(12700/38100/88900/177800) 밖 굵기를 하나 심는다
        NS = 'http://schemas.openxmlformats.org/drawingml/2006/main'
        inj = ('<p:sp><p:nvSpPr><p:cNvPr id="99" name="c1probe"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>'
               '<p:spPr><a:xfrm xmlns:a="%s"><a:off x="0" y="0"/><a:ext cx="100000" cy="100000"/></a:xfrm>'
               '<a:prstGeom xmlns:a="%s" prst="rect"><a:avLst/></a:prstGeom>'
               '<a:ln xmlns:a="%s" w="31750"/></p:spPr>'
               '<p:txBody><a:bodyPr xmlns:a="%s"/><a:lstStyle xmlns:a="%s"/>'
               '<a:p xmlns:a="%s"/></p:txBody></p:sp>' % ((NS,)*6))
        x = x.replace('</p:spTree>', inj + '</p:spTree>', 1)
        open(sp, 'w', encoding='utf-8').write(x)
        env_nolocal = {k: v for k, v in os.environ.items() if k != 'PREPREP_C1_BASELINE'}
        rd = subprocess.run([sys.executable, GATE, armD], capture_output=True, text=True, env=env_nolocal)
        rc_d, out_d = rd.returncode, rd.stdout + rd.stderr
        # E: 이 덱의 기준선을 박고 다시 → 0
        subprocess.run([sys.executable, GATE, armD, '--write-c1-baseline'],
                       capture_output=True, text=True, env=env_nolocal)
        re_ = subprocess.run([sys.executable, GATE, armD], capture_output=True, text=True, env=env_nolocal)
        rc_e, out_e = re_.returncode, re_.stdout + re_.stderr

        fails = []
        def chk(name, got, want, out, extra=''):
            good = (got == want)
            print('  %s %-34s rc=%s (기대 %s) %s' % ('✅' if good else '❌', name, got, want, extra))
            if not good:
                fails.append(name)
                print('     ↳ 출력:', ' / '.join(out.strip().splitlines()[-3:]))

        print('gate.py 종료코드 known-pair')
        print('  컨트롤 생존 확인: 양팔 슬라이드 수 %d == %d' % (n, n_a))
        if n != n_a: fails.append('control-parity')
        chk('B 정상 덱 (부품 전부)',            rc_b, 0, out_b)
        chk('A app.xml 하나만 뺌',              rc_a, 2, out_a, '← 1 이면 «판정불가가 발견으로» 회귀')
        chk('C 작업 트리 자체가 없음',          rc_c, 2, out_c, '← 1 이면 회귀')
        chk('D 토큰밖 굵기 + 기준선 미교정',     rc_d, 2, out_d, '← 1 이면 남의 기준선으로 «발견»을 낸 것')
        chk('E 같은 덱, 기준선 박은 뒤',         rc_e, 0, out_e, '← 컨트롤: 교정하면 조용해진다')
        if 'UNCALIBRATED' not in out_d:
            fails.append('D-wording'); print('  ❌ D 팔 출력에 UNCALIBRATED 가 없다')
        else:
            print('  ✅ D 팔이 UNCALIBRATED 로 말하고 «인용하지 마라»를 적는다')
        if 'UNMEASURED' not in out_a:
            fails.append('A-wording'); print('  ❌ A 팔 출력에 UNMEASURED 가 없다')
        else:
            print('  ✅ A 팔이 UNMEASURED 로 말한다')

        print(('PASS' if not fails else 'FAIL · ' + ', '.join(fails)))
        return 1 if fails else 0
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

if __name__ == '__main__':
    sys.exit(main())
