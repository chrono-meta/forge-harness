#!/usr/bin/env python3
"""R1~R5 · P1/P3 self-test — known-pair 계량 + 실물 재현.

exit 0 = 전부 통과 · 1 = 실패 있음 · 2 = 픽스처 생성 불가(python-pptx 부재 등, UNMEASURED)

구성:
  ① known-pair — `fixtures/mk_slide_fixtures.py` 로 R1·R2·R4·R5·P1·P3 를 테스트 시점에 만든다
     (R3 는 예외 — 실물 구조 2장을 줄인 `fixtures/fixture_R3_{positive,negative}.pptx` 를 쓴다.
     선두 줄 판별이 절대좌표·srgbClr 런 구조에 기대므로, 검출기 가정대로 «생성»한 픽스처는
     검출기 자신을 검증 못 한다 — 자기참조. `tracks-meta` 원장이 지목한 방침)
  ② --baseline 델타 모드 — 편집 전/후 한 쌍에서 새 어긋남 1건만 잡히는지
  ③ 실물 재현 — 실제 백업 pptx(환경변수 PREPREP_REAL_CORPUS 가 가리키는 디렉터리, 있을 때만)에 돌려 원장이 인용한 실사고 4+1건이
     그대로 뜨는지 확인한다. 그 코퍼스가 없는 머신에서는 SKIP(«통과»로 세지 않는다).
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, 'fixtures'))

PASS, FAIL, SKIP = 0, 0, 0


def ok(msg):
    global PASS
    PASS += 1
    print('  ✅', msg)


def ng(msg):
    global FAIL
    FAIL += 1
    print('  ❌', msg)


def sk(msg):
    global SKIP
    SKIP += 1
    print('  ⏭ ', msg, '— SKIPPED (PASS 아님)')


def codes_of(deck_path, LSR):
    deck = LSR.Deck(deck_path)
    F = LSR.analyze(deck)
    return F, {k for k, _, _ in F}


def run_known_pairs(fx_dir):
    print('\n[1] known-pair — R1·R2·R4·R5·P1·P3 (생성 픽스처) + R3 (실물 픽스처)')
    import lane_slide_relations as LSR
    import lane_geometry as LG

    # R1
    _, cp = codes_of(os.path.join(fx_dir, 'r1_pos.pptx'), LSR)
    _, cn = codes_of(os.path.join(fx_dir, 'r1_neg.pptx'), LSR)
    ok('R1 known-positive 검출') if 'R1' in cp else ng(f'R1 known-positive 미검출 ({cp})')
    ok('R1 known-negative 무검출') if 'R1' not in cn else ng(f'R1 known-negative에서 오탐 ({cn})')

    # R2
    _, cp = codes_of(os.path.join(fx_dir, 'r2_pos.pptx'), LSR)
    _, cn = codes_of(os.path.join(fx_dir, 'r2_neg.pptx'), LSR)
    ok('R2 known-positive 검출') if 'R2' in cp else ng(f'R2 known-positive 미검출 ({cp})')
    ok('R2 known-negative 무검출') if 'R2' not in cn else ng(f'R2 known-negative에서 오탐 ({cn})')

    # R3 — 실물 픽스처 (자기참조 회피)
    r3p = os.path.join(HERE, 'fixtures', 'fixture_R3_positive.pptx')
    r3n = os.path.join(HERE, 'fixtures', 'fixture_R3_negative.pptx')
    if os.path.exists(r3p) and os.path.exists(r3n):
        _, cp = codes_of(r3p, LSR)
        _, cn = codes_of(r3n, LSR)
        ok('R3 known-positive(실물 2장) 검출') if 'R3' in cp else ng(f'R3 known-positive 미검출 ({cp})')
        ok('R3 known-negative(실물 2장) 무검출') if 'R3' not in cn else ng(f'R3 known-negative에서 오탐 ({cn})')
    else:
        sk('R3 known-pair — fixture_R3_{positive,negative}.pptx 없음')

    # R4
    Fp, cp = codes_of(os.path.join(fx_dir, 'r4_pos.pptx'), LSR)
    Fn, cn = codes_of(os.path.join(fx_dir, 'r4_neg.pptx'), LSR)
    ok('R4 known-positive 검출(아웃라이어 500자)') if 'R4' in cp else ng(f'R4 known-positive 미검출 ({cp})')
    ok('R4 known-negative 무검출(동값 분포)') if 'R4' not in cn else ng(f'R4 known-negative에서 오탐 ({cn})')

    # R5
    Fp, cp = codes_of(os.path.join(fx_dir, 'r5_pos.pptx'), LSR)
    Fn, cn = codes_of(os.path.join(fx_dir, 'r5_neg.pptx'), LSR)
    ok('R5 known-positive 검출(비율 30.0)') if 'R5' in cp else ng(f'R5 known-positive 미검출 ({cp})')
    ok('R5 known-negative 무검출(동일 비율)') if 'R5' not in cn else ng(f'R5 known-negative에서 오탐 ({cn})')

    # P1 — 3팔(임계 안 소폭 이동은 뜬다 · 임계 밖 큰 이동은 안 뜬다 · 무이동은 안 뜬다)
    lines, stats, _sup, _err = LG.collect_lines(os.path.join(fx_dir, 'p1.pptx'), 200000, 63500)
    p1_lines = [l for l in lines if 'gate_bar' in l]
    bound = stats.get('bound', 0)
    ok(f'P1 결박된 도형-쌍 {bound} > 0 (비교 안함 아님)') if bound > 0 else ng('P1 bound=0 — UNMEASURED')
    ok(f'P1 후보 정확히 1건(임계 안 이동만)') if len(p1_lines) == 1 else ng(f'P1 후보 {len(p1_lines)}건 (want 1) — {p1_lines}')
    if p1_lines:
        ok('P1 유일 후보가 정확히 (1→2p) 소폭 이동 — 큰 이동(2→3p)·무이동(3→4p)은 안 뜬다') \
            if '1p→2' in p1_lines[0].replace(' ', '') else ng(f'P1 후보가 엉뚱한 쌍을 가리킨다 {p1_lines}')

    # P1-결박 — 🟥 넷이 **같은 이동량**이라 결박 규칙만 재는 계기다(임계·이동량은 변수가 아니다)
    lb, sb, _s, _e = LG.collect_lines(os.path.join(fx_dir, 'p1_binding.pptx'), 200000, 63500)
    hit = {n for n in ('bound_bar', 'remix_bar', 'silent_bar', 'halftext')
           if any(n in l for l in lb)}
    ok('P1 결박 known-negative — 글자가 «다른» 쌍은 후보에서 빠진다(대조 자체가 틀렸다)') \
        if hit == {'bound_bar', 'silent_bar'} \
        else ng(f'P1 후보가 {sorted(hit)} (want bound_bar+silent_bar) — 결박 규칙이 어긋났다')
    ok('🟥 P1 known-positive — 글자 없는 도형(막대·선)이 «후보로» 남는다') \
        if 'silent_bar' in hit else ng('glyph 없는 도형이 잘렸다 — P1 원적 사건이 이 부류다')
    ok('   그리고 그 줄은 [이름만 결박] 이름표를 달아 근거가 하나뿐임을 드러낸다') \
        if any('silent_bar' in l and '이름만' in l for l in lb) \
        else ng(f'name_only 후보에 이름표가 없다 — bound 와 구분 안 된다 ({lb})')
    ok(f'P1 결박 내역이 셋으로 갈린다 (bound={sb.get("bound",0)} · name_only={sb.get("name_only",0)} · mismatch={sb.get("mismatch",0)})') \
        if sb.get('bound', 0) >= 1 and sb.get('name_only', 0) >= 1 and sb.get('mismatch', 0) >= 2 \
        else ng(f'결박 내역이 셋으로 안 갈린다 — {sb}')

    # P1-선언면제 — 면제는 «도형»이 아니라 «그 변화»에 걸려야 한다
    p1i = os.path.join(fx_dir, 'p1_intended.pptx')
    decl = [{'slides': [1, 2], 'shapes': ['staged_bar', 'stray_bar'],
             'attrs': ['x', 'cx'], 'why': '격리 막대 얇음→두꺼움 연출'}]
    li, _st, sup, errs = LG.collect_lines(p1i, 200000, 63500, decl)
    ok('면제 known-positive — 선언과 속성이 일치하는 staged_bar 는 후보에서 빠진다') \
        if not any('staged_bar' in l for l in li) else ng(f'staged_bar 가 면제 안 됨 — {li}')
    ok('면제된 것이 «사라지지» 않고 suppressed 로 사유와 함께 나온다') \
        if any('staged_bar' in l and '격리 막대' in l for l in sup) \
        else ng(f'면제가 조용히 사라졌다 — suppressed={sup}')
    ok('🟥 면제 known-negative — 같은 이름을 선언했어도 «다른 속성»이 바뀐 stray_bar 는 그대로 뜬다') \
        if any('stray_bar' in l for l in li) \
        else ng('stray_bar 가 삼켜졌다 — 면제가 그 변화가 아니라 도형 이름에 걸려 있다')
    ok('선언 오류 0건(정상 선언)') if not errs else ng(f'정상 선언에서 오류 {errs}')
    _l2, _s2, sup2, errs2 = LG.collect_lines(p1i, 200000, 63500,
                                             [dict(decl[0], why='   ')])
    ok('🟥 why 가 빈 선언은 «면제»가 아니라 «오류»다 — 사유 없는 면제는 채널을 지운다') \
        if errs2 and not sup2 else ng(f'why 공백인데 면제됨 (errs={errs2}, sup={sup2})')

    # P1-뒤집힘 — 🟥 상자 기하가 한 EMU도 안 바뀐다. 변수는 flipH 하나뿐이다.
    #    자리만 보는 계기는 여기서 «어긋남 0» 을 낸다(2026-09-10 실사고의 모양).
    lf, sf, _s, _e = LG.collect_lines(os.path.join(fx_dir, 'p1_flip.pptx'), 200000, 63500)
    ok('🟥 P1 뒤집힘 known-positive — 자리가 같아도 방향이 바뀌면 뜬다') \
        if sf.get('flipped', 0) == 1 and any('turned' in l and '뒤집힘' in l for l in lf) \
        else ng(f'뒤집힘 미검출 — 방향이 계기 밖이다 (stats={sf})')
    ok('P1 뒤집힘 known-negative — 양쪽 무플립인 도형은 안 뜬다(과차단 컨트롤)') \
        if not any('steady' in l for l in lf) else ng(f'steady 오탐 — {lf}')

    # L14 screen-parity — 덱은 한 벌, 원고만 두 벌(한 변수)
    import lane_screen_parity as SP
    deck = SP.deck_screens(os.path.join(fx_dir, 'sp_deck.pptx'))
    a_ok, w_ok, _ = SP.compare(SP.manuscript_screens(os.path.join(fx_dir, 'sp_ok.md')), deck)
    a_bad, w_bad, _ = SP.compare(SP.manuscript_screens(os.path.join(fx_dir, 'sp_bad.md')), deck)
    ok('L14 known-negative — 원고와 덱이 같으면 조용하다') \
        if not a_ok and not w_ok else ng(f'같은 한 쌍에서 오탐 (짝없음={a_ok}, 문구={w_ok})')
    sides = {x[2] for x in a_bad}
    ok('L14 known-positive — 양쪽 방향의 «짝 없는 줄» 을 다 잡는다(원고에만·화면에만)') \
        if sides == {'원고에만', '화면에만'} else ng(f'한 방향만 잡는다 — {sides}')
    ok('🟥 L14 — «짝 없음» 과 «문구만 다름» 을 갈라서 낸다(합치면 계기가 거짓말한다)') \
        if len(a_bad) == 2 and len(w_bad) == 1 else ng(f'분류 이상 (짝없음 {len(a_bad)}, 문구 {len(w_bad)})')
    man_short = SP.manuscript_screens(os.path.join(fx_dir, 'sp_ok.md'))[:1]
    cfg = {'surfaces_by_id': {'built_deck': {'path': os.path.join(fx_dir, 'sp_deck.pptx')},
                              'script': {'path': os.path.join(fx_dir, 'sp_ok.md'),
                                         'canonical_for': ['화면 문자열']}}}
    _f, n14 = SP.scan(cfg, '.')
    ok('L14 scan() 래퍼가 표면 선언에서 원고를 찾아 돈다') \
        if any('screen-parity' in x and '짝 없는 줄 0' in x for x in n14) else ng(f'scan() 이상 — {n14}')

    # P3
    lines3, _s3, _u3, _e3 = LG.collect_lines(os.path.join(fx_dir, 'p3.pptx'), 200000, 63500)
    p3_lines = [l for l in lines3 if 'stub' in l]
    ok('P3 후보 정확히 1건(임계 안 틀/겹침만)') if len(p3_lines) == 1 else ng(f'P3 후보 {len(p3_lines)}건 (want 1) — {p3_lines}')

    # P4 attr-consistency — 축 넷 각각 known-pair.
    # 🟥 두 팔의 도형 수·이름·자리가 같고 «갈리는 값 하나»만 다르다 — negative 가 «볼 게 없어서»
    #    조용한 것이면 죽은 컨트롤이라 아무것도 못 잰다.
    import lane_attr_consistency as AC
    lp, _sp, ep, stp = AC.collect(os.path.join(fx_dir, 'p4_pos.pptx'), {})
    ln_, _sn, en, stn = AC.collect(os.path.join(fx_dir, 'p4_neg.pptx'), {})
    ok('P4 선언 오류 0건(양팔)') if not ep and not en else ng(f'P4 선언 오류 pos={ep} neg={en}')
    ok(f'P4 컨트롤 살아 있음 — 양팔 도형 수 동일 ({stp.get("shapes")} = {stn.get("shapes")}) '
       f'· 크기 읽힌 도형 {stp.get("sized")}개') \
        if stp.get('shapes') == stn.get('shapes') and stp.get('sized', 0) >= 6 \
        else ng(f'P4 컨트롤 비대칭/미측정 — pos={stp} neg={stn}')
    for ax, label in (('dash', '같은 점선 굵기 갈림'), ('algn', '한 줄 정렬 갈림'),
                      ('mirror', '좌우 대칭 크기 갈림'), ('echo', '같은 문장 크기 갈림')):
        ok(f'P4 {ax} known-positive 검출 ({label})') if stp.get(ax, 0) >= 1 \
            else ng(f'P4 {ax} known-positive 미검출 — {lp}')
        ok(f'P4 {ax} known-negative 무검출') if stn.get(ax, 0) == 0 \
            else ng(f'P4 {ax} known-negative 오탐 — {ln_}')
    # 면제 채널 — P1 과 같은 규율(축+장에 걸린다 · 사유 필수 · 조용히 안 삼킨다)
    lm, sm, em, _ = AC.collect(os.path.join(fx_dir, 'p4_pos.pptx'),
                               {'intended': [{'axis': 'mirror', 'slides': [1],
                                              'why': '빌드 강조 교체 — 크기가 강조를 나른다'}]})
    ok('P4 면제 known-positive — 선언한 축(mirror)만 빠지고 사유와 함께 나온다') \
        if any('mirror' in l and '빌드 강조' in l for l in sm) \
        and not any('[mirror]' in l for l in lm) else ng(f'P4 면제 이상 — sup={sm}')
    ok('🟥 P4 면제 known-negative — 선언 안 한 축(dash·algn·echo)은 그대로 뜬다') \
        if all(any(f'[{a}]' in l for l in lm) for a in ('dash', 'algn', 'echo')) \
        else ng(f'다른 축까지 삼켜졌다 — {lm}')
    _l, _s, ew, _st = AC.collect(os.path.join(fx_dir, 'p4_pos.pptx'),
                                 {'intended': [{'axis': 'mirror', 'slides': [1], 'why': ''}]})
    ok('🟥 P4 why 빈 선언은 면제가 아니라 오류다') if ew else ng('why 공백인데 통과')


def _shrink_deck(src, dst, drop_last, consistent):
    """장을 덜어낸 사본. `consistent=True` 면 sldIdLst 도 같이 줄인다(«의도한 삭제»),
    False 면 파일만 줄인다(**2026-09-10 실사고 형태** — 목록은 120인데 파일이 102)."""
    import zipfile, re
    zi = zipfile.ZipFile(src)
    names = [n for n in zi.namelist() if re.match(r'ppt/slides/slide\d+\.xml$', n)]
    keep_n = len(names) - drop_last
    drop = set(sorted(names, key=lambda n: int(re.search(r'(\d+)', n).group(1)))[keep_n:])
    zo = zipfile.ZipFile(dst, 'w', zipfile.ZIP_DEFLATED)
    for n in zi.namelist():
        if n in drop:
            continue
        data = zi.read(n)
        if consistent and n == 'ppt/presentation.xml':
            x = data.decode('utf-8')
            m = re.search(r'<p:sldIdLst>(.*?)</p:sldIdLst>', x, re.S)
            ids = re.findall(r'<p:sldId\b[^>]*/>', m.group(1))
            x = x.replace(m.group(1), ''.join(ids[:keep_n]), 1)
            data = x.encode('utf-8')
        # «의도한 삭제» 는 관계·Content_Types 도 같이 지운다 — 파워포인트가 그렇게 저장한다(2026-09-11: zip 수준 관계 검사가
        #    끊긴 관계를 잡게 되자 이 픽스처가 «깨진 패키지» 로 읽혔다. 픽스처가 실물 형태가 아니었던 것)
        if consistent and n == 'ppt/_rels/presentation.xml.rels':
            x = data.decode('utf-8')
            for dn in drop:
                x = re.sub(r'<Relationship\b[^>]*Target="%s"[^>]*/>' % re.escape(dn.replace('ppt/', '')), '', x)
            data = x.encode('utf-8')
        if consistent and n == '[Content_Types].xml':
            x = data.decode('utf-8')
            for dn in drop:
                x = re.sub(r'<Override\b[^>]*PartName="/%s"[^>]*/>' % re.escape(dn), '', x)
            data = x.encode('utf-8')
        zo.writestr(n, data)
    zo.close()
    return keep_n


def run_safe_install(fx_dir):
    """산출물 무결성 게이트 — 🟥 2026-09-10 실사고(120장 정본이 102장으로 덮임)의 회귀 앵커."""
    print('\n[2-b] safe_install — 산출물 무결성 게이트 (실사고 회귀 앵커)')
    import subprocess, shutil, zipfile, re
    here = os.path.join(HERE, 'safe_install.py')
    if not os.path.exists(here):
        return ng('safe_install.py 없음 — NOT_WIRED (0 아님)')
    src = os.path.join(fx_dir, 'p1.pptx')          # 4장짜리 정상 pptx
    dest = os.path.join(fx_dir, 'si_dest.pptx')
    shutil.copyfile(src, dest)

    def run(cand, *extra):
        r = subprocess.run([sys.executable, here, cand, dest, *extra],
                           capture_output=True, text=True)
        return r.returncode, r.stdout + r.stderr

    def slides(p):
        return len([n for n in zipfile.ZipFile(p).namelist()
                    if re.match(r'ppt/slides/slide\d+\.xml$', n)])

    # known-negative — 멀쩡한 후보는 통과해야 한다(컨트롤: 이게 막히면 계기가 과차단이다)
    rc, out = run(src, '--dry-run')
    ok('known-negative — 정상 후보는 통과한다') if rc == 0 else ng(f'정상 후보를 막았다 (rc={rc})\n{out}')

    # known-positive ① — 실사고 형태: 파일만 잘리고 sldIdLst 는 그대로
    trunc = os.path.join(fx_dir, 'si_truncated.pptx')
    _shrink_deck(src, trunc, 2, consistent=False)
    rc, out = run(trunc)
    # 2026-09-11: rels 그래프 검증이 앞서 걸린다(목록이 가리키는 슬라이드가 zip 에 없다) — 어느 쪽이든 «구조 사유로 거부»
    ok('🟥 실사고 재현 — 파일 수 ↔ sldIdLst 어긋남을 막는다') \
        if rc == 1 and ('어긋난다' in out or 'zip 에 없다' in out) else ng(f'실사고를 안 막았다 (rc={rc})\n{out}')

    # known-positive ② — 목록까지 일관되게 줄어든 «축소». ④ 축소 규칙만 재는 팔이다
    small = os.path.join(fx_dir, 'si_small.pptx')
    _shrink_deck(src, small, 2, consistent=True)
    rc, out = run(small)
    ok('축소는 기본 거부한다(비가역 표면은 fail-closed)') \
        if rc == 1 and '줄었다' in out else ng(f'축소가 그냥 통과했다 (rc={rc})\n{out}')
    rc, out = run(small, '--allow-shrink')
    ok('🟥 --allow-shrink 만으로는 안 된다 — 사유가 없으면 거부') \
        if rc == 1 else ng(f'사유 없는 축소가 통과했다 (rc={rc})\n{out}')
    rc, out = run(small, '--allow-shrink', '--why', '38p 의도 삭제')
    ok('사유를 적은 명시 축소는 통과한다') if rc == 0 else ng(f'명시 축소를 막았다 (rc={rc})\n{out}')

    # known-positive ③ — 깨진 zip
    corrupt = os.path.join(fx_dir, 'si_corrupt.pptx')
    with open(src, 'rb') as f, open(corrupt, 'wb') as g:
        g.write(f.read(2048))
    shutil.copyfile(src, dest)
    rc, out = run(corrupt)
    ok('깨진 zip 을 막는다') if rc == 1 else ng(f'깨진 zip 이 통과했다 (rc={rc})\n{out}')

    # 🟥 그리고 «막았다»가 «정본이 안 바뀌었다»와 같은 말인지 따로 확인한다
    #    (막았다고 말하면서 이미 덮어썼을 수 있다 — 판정과 부작용은 다른 것이다)
    ok(f'거부된 동안 정본이 그대로 {slides(dest)}장') if slides(dest) == slides(src) \
        else ng(f'거부했는데 정본이 {slides(dest)}장으로 바뀌었다 — 부작용이 새고 있다')

    # ── 2026-09-11 codex 감사 S5 + B2 (설치 표면) — 각각 known-pair ───────────────────
    def rewrite(src_p, dst_p, fn):
        zi = zipfile.ZipFile(src_p); zo = zipfile.ZipFile(dst_p, 'w', zipfile.ZIP_DEFLATED)
        for n in zi.namelist():
            d = zi.read(n)
            if n == 'ppt/presentation.xml':
                d = fn(d.decode('utf-8')).encode('utf-8')
            zo.writestr(n, d)
        zo.close()
    shutil.copyfile(src, dest)
    # S1 목록이 비어 있어도 «검사 생략» 이 아니다
    empty_lst = os.path.join(fx_dir, 'si_emptylist.pptx')
    rewrite(src, empty_lst, lambda x: re.sub(r'(<p:sldIdLst\b[^>]*>).*?(</p:sldIdLst>)', r'\1\2', x, flags=re.S))
    rc, out = run(empty_lst)
    ok('S1 sldIdLst 가 비면 거부한다(0 은 «생략» 이 아니다)') if rc == 1 and '어긋난다' in out \
        else ng(f'빈 목록이 통과했다 (rc={rc})\n{out}')
    # S2 같은 장을 두 번 가리키는 목록
    dup_lst = os.path.join(fx_dir, 'si_dup.pptx')
    def _dup(x):
        m = re.search(r'<p:sldIdLst\b[^>]*>(.*?)</p:sldIdLst>', x, re.S)
        ids = re.findall(r'<p:sldId\b[^>]*/>', m.group(1))
        return x.replace(m.group(1), ids[0] + ''.join(ids[1:-1]) + ids[0], 1)   # 마지막을 첫 장 중복으로
    rewrite(src, dup_lst, _dup)
    rc, out = run(dup_lst)
    ok('S2 같은 장을 두 번 가리키는 목록을 거부한다') if rc == 1 and ('중복' in out or '어긋난다' in out) \
        else ng(f'중복 참조가 통과했다 (rc={rc})\n{out}')
    # S3 기존본을 못 읽으면 반영하지 않는다
    with open(dest, 'wb') as g:
        g.write(b'not a zip')
    rc, out = run(src)
    still = open(dest, 'rb').read() == b'not a zip'
    ok('S3 못 읽는 기존본 위에는 덮어쓰지 않는다(UNMEASURED ≠ 통과)') if rc == 1 and still \
        else ng(f'못 읽는 기존본을 덮었다 (rc={rc}, unchanged={still})\n{out}')
    shutil.copyfile(src, dest)
    # S4 `--why --allow-shrink` — 플래그를 사유로 먹지 않는다
    rc, out = run(small, '--why', '--allow-shrink')
    ok('S4 --why 뒤에 플래그가 오면 사유가 아니다(거부)') if rc != 0 and slides(dest) == slides(src) \
        else ng(f'플래그가 사유로 통했다 (rc={rc})\n{out}')
    # B2 `--expect 2` 가 앞에 와도 후보로 안 읽힌다
    r = subprocess.run([sys.executable, here, '--expect', '2', src, dest], capture_output=True, text=True)
    ok('B2 --expect 값이 후보로 오파싱되지 않는다') if r.returncode == 1 and '--expect' in r.stdout \
        else ng(f'옵션 파싱 오류 (rc={r.returncode})\n{r.stdout}{r.stderr}')
    # S5/B1 반영은 «검사한 바이트» 를 옆에 쓴 뒤 교체 — 임시 파일이 남지 않고 정본 해시 = 후보 해시
    rc, out = run(src)
    import hashlib
    same = hashlib.sha256(open(src, 'rb').read()).digest() == hashlib.sha256(open(dest, 'rb').read()).digest()
    ok('S5 반영 후 정본 바이트 == 후보 바이트 · 임시 파일 없음') \
        if rc == 0 and same and not os.path.exists(dest + '.safe_install.tmp') \
        else ng(f'반영 경로 이상 (rc={rc} same={same})\n{out}')

    # ── R2 (codex 09-11 13:04) 설치 표면 S4 ──
    def rezip(src_p, dst_p, fn_map):
        """fn_map: {zip이름: (새이름 or None, bytes 변환 fn or None)}. 나머지는 그대로."""
        zi = zipfile.ZipFile(src_p); zo = zipfile.ZipFile(dst_p, 'w', zipfile.ZIP_DEFLATED)
        for n in zi.namelist():
            d = zi.read(n)
            if n in fn_map:
                nn, fn = fn_map[n]
                if fn: d = fn(d)
                n = nn or n
            zo.writestr(n, d)
        zo.close()
    # S1 기존본의 슬라이드 부품 이름이 관례 밖(page1.xml) → 0장으로 접혀 축소가 통과하던 구멍: 기존본 불일치는 거부
    odd_dest = os.path.join(fx_dir, 'si_odd_dest.pptx')
    names = [n for n in zipfile.ZipFile(src).namelist() if re.match(r'ppt/slides/slide\d+\.xml$', n)]
    ren = {n: (n.replace('slide', 'page'), None) for n in names}
    ren['ppt/_rels/presentation.xml.rels'] = (None, lambda d: d.replace(b'slides/slide', b'slides/page'))
    ren['[Content_Types].xml'] = (None, lambda d: d.replace(b'slides/slide', b'slides/page'))
    rezip(src, odd_dest, ren)
    shutil.copyfile(odd_dest, dest)
    rc, out = run(small)
    still_odd = zipfile.ZipFile(dest).namelist() == zipfile.ZipFile(odd_dest).namelist()
    ok('S1 기존본을 못 세면(부품 이름 관례 밖) 축소 후보를 거부하고 덮지 않는다') if rc == 1 and still_odd \
        else ng(f'세지 못한 기존본 위에 축소가 통과했다 (rc={rc} unchanged={still_odd})\n{out}')
    shutil.copyfile(src, dest)
    # S3 rels 가 슬라이드 아닌 부품(theme)을 가리켜도 «zip 에 있다» 로 통과하던 구멍
    theme_cand = os.path.join(fx_dir, 'si_theme_target.pptx')
    def _retarget(d):
        x = d.decode('utf-8'); first = re.search(r'Target="slides/slide\d+\.xml"', x).group(0)
        return x.replace(first, 'Target="theme/theme1.xml"', 1).encode('utf-8')
    rezip(src, theme_cand, {'ppt/_rels/presentation.xml.rels': (None, _retarget)})
    rc, out = run(theme_cand)
    ok('S3 sldId 가 슬라이드 아닌 부품을 가리키면 거부한다') if rc == 1 and '슬라이드 부품이 아니다' in out \
        else ng(f'theme 을 가리키는 목록이 통과했다 (rc={rc})\n{out}')
    # S4 r:id 없는 sldId 항목은 계수에서 사라지지 않는다
    norid = os.path.join(fx_dir, 'si_norid.pptx')
    rezip(src, norid, {'ppt/presentation.xml': (None, lambda d: d.replace(b'</p:sldIdLst>', b'<p:sldId id="999"/></p:sldIdLst>'))})
    rc, out = run(norid)
    ok('S4 r:id 없는 sldId 항목은 거부 사유가 된다') if rc == 1 and 'r:id 가 없다' in out \
        else ng(f'r:id 없는 항목이 통과했다 (rc={rc})\n{out}')
    # S2 정본 경로가 심링크면 거부 · 임시 파일은 mkstemp(고유) — 예측 가능한 .tmp 이름을 미리 심어도 정본은 무사
    link_dest = os.path.join(fx_dir, 'si_link_dest.pptx')
    if os.path.lexists(link_dest): os.remove(link_dest)
    os.symlink(dest, link_dest)
    r = subprocess.run([sys.executable, here, src, link_dest], capture_output=True, text=True)
    planted = dest + '.safe_install.tmp'
    if os.path.lexists(planted): os.remove(planted)
    os.symlink(dest, planted)
    before = open(dest, 'rb').read()
    rc2, out2 = run(src)
    after = open(dest, 'rb').read()
    ok('S2 심링크 정본 거부(rc=1) · 심어둔 .tmp 심링크가 있어도 정본 바이트는 후보와 같다(고유 임시 파일)') \
        if r.returncode == 1 and '심링크' in r.stdout and rc2 == 0 and after == open(src, 'rb').read() \
        else ng(f'S2 link rc={r.returncode} · planted rc={rc2} same={after == open(src, "rb").read()}\n{r.stdout}{out2}')
    os.remove(planted); os.remove(link_dest)

    # ── R3 (codex 09-11 13:1x) 설치 표면 S5 — python-pptx 오라클 + 두 제공자 합의 ──
    # S1 접두 q: + 부품 이름 관례 밖 기존본 — 구조 계수 0/0/0 인데 pptx 는 2장 → 불일치 → 거부(0장으로 접히지 않는다)
    q_dest = os.path.join(fx_dir, 'si_qprefix_dest.pptx')
    def _q(d):
        return d.replace(b'<p:', b'<q:').replace(b'</p:', b'</q:').replace(b'xmlns:p=', b'xmlns:q=')
    qm = dict(ren); qm['ppt/presentation.xml'] = (None, _q)
    rezip(src, q_dest, qm)
    shutil.copyfile(q_dest, dest)
    rc, out = run(small)
    ok('S1 접두 q:·부품 이름 관례 밖 기존본 → 두 제공자 불일치로 거부(축소 미통과)') if rc == 1 and '불일치' in out or (rc == 1 and '못 읽는다' in out) \
        else ng(f'q: 기존본 위에 축소가 통과했다 (rc={rc})\n{out}')
    shutil.copyfile(src, dest)
    # S2 깨진 슬라이드 XML (zip CRC 는 정상) → pptx 파싱 실패 → 거부
    broken = os.path.join(fx_dir, 'si_broken_slide.pptx')
    rezip(src, broken, {names[0]: (None, lambda d: b'<broken')})
    rc, out = run(broken)
    ok('S2 깨진 슬라이드 XML(zip 정상) 은 거부된다(pptx 오라클)') if rc == 1 and '못 읽는다' in out else ng(f'깨진 슬라이드가 통과했다 (rc={rc})\n{out}')
    # S3 TargetMode=External 관계 → 거부
    ext = os.path.join(fx_dir, 'si_external_rel.pptx')
    def _ext(d):
        x = d.decode('utf-8'); m = re.search(r'<Relationship\b[^>]*Target="slides/slide\d+\.xml"[^>]*/>', x).group(0)
        return x.replace(m, m[:-2] + ' TargetMode="External"/>', 1).encode('utf-8')
    rezip(src, ext, {'ppt/_rels/presentation.xml.rels': (None, _ext)})
    rc, out = run(ext)
    ok('S3 External 관계는 슬라이드가 아니다 — 거부') if rc == 1 else ng(f'External 관계가 통과했다 (rc={rc})\n{out}')
    # S5 끊긴 심링크 정본 → 거부(첫 설치로 흐르지 않는다)
    dang = os.path.join(fx_dir, 'si_dangling.pptx')
    if os.path.lexists(dang): os.remove(dang)
    os.symlink(os.path.join(fx_dir, 'no_such_target.pptx'), dang)
    r = subprocess.run([sys.executable, here, src, dang], capture_output=True, text=True)
    ok('S5 끊긴 심링크 정본은 거부(rc=1) · 링크 그대로') if r.returncode == 1 and os.path.islink(dang) and not os.path.exists(dang) \
        else ng(f'끊긴 심링크에 설치됐다 (rc={r.returncode} islink={os.path.islink(dang)} exists={os.path.exists(dang)})')
    os.remove(dang)
    # S4 검사 뒤 정본이 바뀌면 중단 — 정본 교체를 «후보 파일 자체를 정본으로 두는» 순간에 잡기 어렵다 → 계기 함수로 잰다:
    #    d_hash 를 검사 후 바꾸는 대신, 정본에 «검사 전» 1장·«설치 직전» 다른 바이트를 쓰는 레이스를 monkeypatch 로 재현
    import importlib.util
    spec = importlib.util.spec_from_file_location('safe_install_mod', here); SI = importlib.util.module_from_spec(spec); spec.loader.exec_module(SI)
    race_dest = os.path.join(fx_dir, 'si_race_dest.pptx'); shutil.copyfile(small, race_dest)
    _orig_mkstemp = SI.tempfile.mkstemp
    def _racy_mkstemp(*a, **k):
        shutil.copyfile(src, race_dest)          # 다른 손이 4장짜리로 덮는다 — 이제 1장 후보는 «축소» 다
        return _orig_mkstemp(*a, **k)
    SI.tempfile.mkstemp = _racy_mkstemp
    import io as _io, contextlib
    buf = _io.StringIO()
    with contextlib.redirect_stdout(buf):
        rc4 = SI.main(['safe_install.py', small, race_dest])
    SI.tempfile.mkstemp = _orig_mkstemp
    ok('S4 검사 뒤 정본이 바뀌면 중단(rc=1) · 4장 정본 보존') if rc4 == 1 and slides(race_dest) == slides(src) and '바뀌었다' in buf.getvalue() \
        else ng(f'S4 rc={rc4} dest={slides(race_dest)}장\n{buf.getvalue()}')

    # ── R4 (codex 09-11 18:02) 설치 표면 ──
    # S1 nvSpPr 없는 도형(파서가 도형 «수» 만 세면 통과) → 도형 하나하나를 읽어 거부
    noname = os.path.join(fx_dir, 'si_noname_shape.pptx')
    def _strip_nv(d):
        return re.sub(rb'<p:nvSpPr>.*?</p:nvSpPr>', b'', d, count=1, flags=re.S)
    rezip(src, noname, {names[0]: (None, _strip_nv)})
    rc, out = run(noname)
    ok('S1 nvSpPr 없는 도형은 오라클이 거부한다') if rc == 1 and '못 읽는다' in out else ng(f'깨진 도형이 통과했다 (rc={rc})\n{out}')
    # S2 같은 게이트 둘이 동시에 돌면 직렬화된다 — 잠금 안에서 두 번째가 «바뀐 정본» 을 본다
    import threading, fcntl
    lock_dest = os.path.join(fx_dir, 'si_lock_dest.pptx'); shutil.copyfile(small, lock_dest)
    lock_path = lock_dest + '.safe_install.lock'
    lf = os.open(lock_path, os.O_RDWR | os.O_CREAT, 0o600); fcntl.flock(lf, fcntl.LOCK_EX)
    res = {}
    def _worker():
        r = subprocess.run([sys.executable, here, small, lock_dest], capture_output=True, text=True); res['rc'] = r.returncode; res['out'] = r.stdout
    th = threading.Thread(target=_worker); th.start(); th.join(1.5)
    blocked_while_held = th.is_alive()
    shutil.copyfile(src, lock_dest)          # 잠금을 쥔 «다른 설치» 가 4장으로 바꿨다
    fcntl.flock(lf, fcntl.LOCK_UN); os.close(lf); th.join(30)
    ok('S2 잠금 대기 중이던 설치가 «바뀐 정본(4장)» 을 보고 축소로 거부한다 (대기=%s)' % blocked_while_held) \
        if blocked_while_held and res.get('rc') == 1 and slides(lock_dest) == slides(src) and '줄었다' in res.get('out', '') \
        else ng(f'S2 blocked={blocked_while_held} rc={res.get("rc")} dest={slides(lock_dest)}장\n{res.get("out","")[:300]}')

    # ── R5 (codex 09-11 18:13) 설치 표면 ──
    # S1 그룹 안의 깨진 도형(nvSpPr 없음) — 실물 pptx 를 python-pptx 로 만들어(그룹+텍스트박스) XML 을 깬다
    from pptx import Presentation as _Pres
    from pptx.util import Inches as _In
    gp = os.path.join(fx_dir, 'si_group_src.pptx'); prs = _Pres(); sl = prs.slides.add_slide(prs.slide_layouts[6])
    grp = sl.shapes.add_group_shape(); tb = grp.shapes.add_textbox(_In(1), _In(1), _In(2), _In(1)); tb.text_frame.text = 'child'
    prs.save(gp)
    g_dest = os.path.join(fx_dir, 'si_group_dest.pptx'); shutil.copyfile(gp, g_dest)
    gbad = os.path.join(fx_dir, 'si_group_bad.pptx')
    gnames = [n for n in zipfile.ZipFile(gp).namelist() if re.match(r'ppt/slides/slide\d+\.xml$', n)]
    rezip(gp, gbad, {gnames[0]: (None, lambda d: re.sub(rb'<p:sp>\s*<p:nvSpPr>.*?</p:nvSpPr>', b'<p:sp>', d, count=1, flags=re.S))})
    r = subprocess.run([sys.executable, here, gbad, g_dest], capture_output=True, text=True)
    r_ok = subprocess.run([sys.executable, here, gp, g_dest, '--dry-run'], capture_output=True, text=True)
    ok('S1 그룹 자식의 nvSpPr 결손 → 거부 · 정상 그룹 덱 컨트롤 통과') if r.returncode == 1 and '못 읽는다' in r.stdout and r_ok.returncode == 0 \
        else ng(f'S1 bad rc={r.returncode} ctrl rc={r_ok.returncode}\n{r.stdout[:200]}{r_ok.stdout[:200]}')
    # S2 그림 부품이 zip 에서 빠진 덱 → 거부
    pp = os.path.join(fx_dir, 'si_pic_src.pptx'); prs = _Pres(); sl = prs.slides.add_slide(prs.slide_layouts[6])
    png = os.path.join(fx_dir, 'dot.png')
    from PIL import Image as _Img
    _Img.new('RGB', (2, 2), (255, 0, 0)).save(png)          # 손으로 친 hex 는 PIL verify 를 못 넘겼다 — 실물 PNG 로
    sl.shapes.add_picture(png, _In(1), _In(1)); prs.save(pp)
    p_dest = os.path.join(fx_dir, 'si_pic_dest.pptx'); shutil.copyfile(pp, p_dest)
    pbad = os.path.join(fx_dir, 'si_pic_bad.pptx')
    zi = zipfile.ZipFile(pp); zo = zipfile.ZipFile(pbad, 'w', zipfile.ZIP_DEFLATED)
    for n in zi.namelist():
        if not n.startswith('ppt/media/'): zo.writestr(n, zi.read(n))
    zo.close()
    r = subprocess.run([sys.executable, here, pbad, p_dest], capture_output=True, text=True)
    r_ok = subprocess.run([sys.executable, here, pp, p_dest, '--dry-run'], capture_output=True, text=True)
    ok('S2 그림 부품 결손 → 거부 · 정상 그림 덱 컨트롤 통과') if r.returncode == 1 and '못 읽는다' in r.stdout and r_ok.returncode == 0 \
        else ng(f'S2 bad rc={r.returncode} ctrl rc={r_ok.returncode}\n{r.stdout[:200]}{r_ok.stdout[:200]}')

    # ── R6 (codex 09-11 23:07) 설치 표면 ──
    # S2 이미지 바이트가 깨졌는데 zip CRC 는 정상 → PIL 디코드에서 거부
    pbad2 = os.path.join(fx_dir, 'si_pic_badbytes.pptx')
    zi = zipfile.ZipFile(pp); zo = zipfile.ZipFile(pbad2, 'w', zipfile.ZIP_DEFLATED)
    for n in zi.namelist():
        zo.writestr(n, b'not an image' if n.startswith('ppt/media/') else zi.read(n))
    zo.close()
    r = subprocess.run([sys.executable, here, pbad2, p_dest], capture_output=True, text=True)
    ok('S2b 깨진 이미지 바이트(CRC 정상) → 거부') if r.returncode == 1 and '못 읽는다' in r.stdout else ng(f'S2b rc={r.returncode}\n{r.stdout[:200]}')
    # S1 차트 부품 결손 → 관계 걷기에서 거부 (python-pptx 로 차트 덱을 만든다)
    from pptx.chart.data import CategoryChartData as _CD
    from pptx.enum.chart import XL_CHART_TYPE as _XL
    cp = os.path.join(fx_dir, 'si_chart_src.pptx'); prs = _Pres(); sl = prs.slides.add_slide(prs.slide_layouts[6])
    cd = _CD(); cd.categories = ['a', 'b']; cd.add_series('s', (1, 2)); sl.shapes.add_chart(_XL.COLUMN_CLUSTERED, _In(1), _In(1), _In(4), _In(3), cd); prs.save(cp)
    c_dest = os.path.join(fx_dir, 'si_chart_dest.pptx'); shutil.copyfile(cp, c_dest)
    cbad = os.path.join(fx_dir, 'si_chart_bad.pptx')
    zi = zipfile.ZipFile(cp); zo = zipfile.ZipFile(cbad, 'w', zipfile.ZIP_DEFLATED)
    for n in zi.namelist():
        if not n.startswith('ppt/charts/'): zo.writestr(n, zi.read(n))
    zo.close()
    r = subprocess.run([sys.executable, here, cbad, c_dest], capture_output=True, text=True)
    r_ok = subprocess.run([sys.executable, here, cp, c_dest, '--dry-run'], capture_output=True, text=True)
    ok('S1b 차트 부품 결손 → 거부 · 정상 차트 덱 컨트롤 통과') if r.returncode == 1 and '못 읽는다' in r.stdout and r_ok.returncode == 0 \
        else ng(f'S1b bad rc={r.returncode} ctrl rc={r_ok.returncode}\n{r.stdout[:200]}{r_ok.stdout[:200]}')


def _mini_deck(path, slides_xml, sld_attr_order='id-first', rel_attr_order='id-first'):
    """최소 pptx. slides_xml = [슬라이드 본문 XML …] (발표 순서). 속성 순서를 골라 «순서에 기댄 정규식»을 잡는다."""
    import zipfile
    z = zipfile.ZipFile(path, 'w', zipfile.ZIP_DEFLATED)
    z.writestr('[Content_Types].xml', '<Types/>')
    ids, rels = [], []
    for i, body in enumerate(slides_xml, 1):
        fn = 'slides/slide%d.xml' % (len(slides_xml) + 1 - i)   # 파일 번호를 «거꾸로» — 위치 ≠ 파일번호
        rid = 'rId%d' % i
        ids.append('<p:sldId id="%d" r:id="%s"/>' % (255 + i, rid) if sld_attr_order == 'id-first'
                   else '<p:sldId r:id="%s" id="%d"/>' % (rid, 255 + i))
        rels.append('<Relationship Id="%s" Target="%s"/>' % (rid, fn) if rel_attr_order == 'id-first'
                    else '<Relationship Target="%s" Id="%s"/>' % (fn, rid))
        z.writestr('ppt/' + fn, '<p:sld xmlns:p="p" xmlns:a="a"><p:cSld><p:spTree>%s</p:spTree></p:cSld></p:sld>' % body)
    z.writestr('ppt/presentation.xml', '<p:presentation><p:sldSz cx="12192000" cy="6858000"/><p:sldIdLst>%s</p:sldIdLst></p:presentation>' % ''.join(ids))
    z.writestr('ppt/_rels/presentation.xml.rels', '<Relationships>%s</Relationships>' % ''.join(rels))
    z.close()


def _sp(name, x, y, cx, cy, text='', sz=None, extra='', algn=None, ln=''):
    rpr = ('<a:rPr sz="%d"/>' % sz) if sz else '<a:rPr/>'
    ppr = ('<a:pPr algn="%s"/>' % algn) if algn else ''
    return ('<p:sp><p:nvSpPr><p:cNvPr id="1" name="%s"/></p:nvSpPr><p:spPr><a:xfrm%s><a:off x="%d" y="%d"/>'
            '<a:ext cx="%d" cy="%d"/></a:xfrm>%s</p:spPr><p:txBody><a:p>%s<a:r>%s<a:t>%s</a:t></a:r></a:p></p:txBody></p:sp>'
            % (name, extra, x, y, cx, cy, ln, ppr, rpr, text))


def run_codex_audit_regressions(fx_dir):
    print('\n[2-c] 2026-09-11 codex 감사 A 회귀 — 레인 셋(geometry · attr · screen-parity)')
    import lane_geometry as LG, lane_attr_consistency as LA, lane_screen_parity as LS
    # A1 속성 순서 — sldId r:id 가 앞에 와도 두 장 다 읽는다 (세 레인 공통 _order)
    for order in ('id-first', 'rid-first'):
        d = os.path.join(fx_dir, 'ma_%s.pptx' % order)
        _mini_deck(d, [_sp('A', 0, 0, 100, 100, 'one'), _sp('B', 0, 0, 100, 100, 'two')], order, 'target-first' if order == 'rid-first' else 'id-first')
        n_g = len(LG.load_slides(d)); n_a = len(LA.load(d)[0]); n_s = len(LS.deck_screens(d))
        ok('A1 %s: geometry %d · attr %d · parity %d 장 (2 기대)' % (order, n_g, n_a, n_s)) if (n_g, n_a, n_s) == (2, 2, 2) \
            else ng('A1 %s: 속성 순서에 따라 장이 사라진다 — geometry %d attr %d parity %d' % (order, n_g, n_a, n_s))
    # A2 flipH="true" 도 방향으로 읽는다
    d = os.path.join(fx_dir, 'ma_flip.pptx')
    _mini_deck(d, [_sp('arrow', 0, 0, 100, 100, extra=' flipH="true"'), _sp('arrow', 0, 0, 100, 100, extra=' flipH="1"')])
    fl = [s['arrow'][5] for s in LG.load_slides(d)]
    ok('A2 flipH="true" 와 "1" 이 같은 방향 값(H)') if fl == ['H', 'H'] else ng('A2 flip 추출 %r (want [H, H])' % fl)
    # A3 geometry.intended 끝점 검증 — [1, 99] · [1, "x"] 는 오류, [1, 2] 만 면제
    idx, errs = LG._intent_index([{'slides': [1, 99], 'shapes': ['s'], 'attrs': ['x'], 'why': 'w'},
                                  {'slides': [1, 'x'], 'shapes': ['s'], 'attrs': ['x'], 'why': 'w'},
                                  {'slides': [1, 2], 'shapes': ['s'], 'attrs': ['x'], 'why': 'w'}])
    ok('A3 intended 끝점: 비연속·비정수 2건 오류 · [1,2] 1건 등재') if len(errs) == 2 and len(idx) == 1 \
        else ng('A3 intended 끝점 검증 — errs=%d idx=%d' % (len(errs), len(idx)))
    # A4 mirror: 2800 vs 2850 은 다르다 · endParaRPr 는 안 센다
    d = os.path.join(fx_dir, 'ma_mirror.pptx')
    body = (_sp('L', 914400, 914400, 3657600, 914400, 'left', 2800) +
            _sp('R', 7620000, 914400, 3657600, 914400, 'right', 2850).replace('</a:p>', '<a:endParaRPr sz="2800"/></a:p>'))
    _mini_deck(d, [body])
    S, sw = LA.load(d)
    ok('A4 크기 소수 보존 + endParaRPr 제외: %s vs %s' % (S[0][0]['szs'], S[0][1]['szs'])) \
        if S[0][0]['szs'] == (28.0,) and S[0][1]['szs'] == (28.5,) else ng('A4 szs = %r / %r' % (S[0][0]['szs'], S[0][1]['szs']))
    # A5 algn: 문단 정렬만 · 크기 상속이어도 정렬은 대조된다 · ln algn 은 무시
    d = os.path.join(fx_dir, 'ma_algn.pptx')
    body = (_sp('a', 0, 914400, 3657600, 914400, 'x', algn='l', ln='<a:ln algn="ctr"><a:solidFill/></a:ln>') +
            _sp('b', 5000000, 914400, 3657600, 914400, 'y', algn='r', ln='<a:ln algn="ctr"><a:solidFill/></a:ln>'))
    _mini_deck(d, [body])
    S, sw = LA.load(d)
    hits = list(LA.ax_algn(S, sw, {}))
    ok('A5 pPr 정렬 l/r 이 갈림으로 잡힌다(크기 상속·ln algn 무시)') if len(hits) == 1 and S[0][0]['algn'] == ('l',) \
        else ng('A5 algn 축 — hits=%d algn=%r' % (len(hits), S[0][0]['algn']))
    # A6 장 번호 = 발표 위치 (파일 번호가 거꾸로인 덱)
    d = os.path.join(fx_dir, 'ma_pos.pptx')
    _mini_deck(d, [_sp('t', 0, 0, 100, 100, 'same sentence here', 2800), _sp('t', 0, 0, 100, 100, 'same sentence here', 3200)])
    S, sw = LA.load(d)
    ok('A6 a[slide] 가 발표 위치 [1, 2] (파일 번호 [2, 1] 아님)') if [s[0]['slide'] for s in S] == [1, 2] \
        else ng('A6 slide 번호 %r' % [s[0]['slide'] for s in S])
    # A7 🖥️(FE0F) 변이 · 다중성 · 엔티티 · 문단 경계
    mp = os.path.join(fx_dir, 'ma_man.md')
    with open(mp, 'w', encoding='utf-8') as f:
        f.write('### U1 · x\n🖥️\nR&D\nTitle\nTitle\n🗣\n말\n')
    man = LS.manuscript_screens(mp)
    ok('A7-1 🖥️ 변이 선택자 뒤의 줄을 읽는다(3줄)') if man and len(man[0][1]) == 3 else ng('A7-1 원고 파싱 %r' % man)
    d = os.path.join(fx_dir, 'ma_par.pptx')
    body = ('<p:sp><p:nvSpPr><p:cNvPr id="1" name="g"/></p:nvSpPr><p:txBody><a:p><a:r><a:rPr/><a:t>R&amp;D</a:t></a:r></a:p>'
            '<a:p><a:r><a:rPr/><a:t>Title</a:t></a:r></a:p></p:txBody></p:sp>')
    _mini_deck(d, [body])
    deck = LS.deck_screens(d)
    ok('A7-2 문단 단위 추출 + 엔티티 해제: %r' % deck[0]) if deck[0] == ['R&D', 'Title'] else ng('A7-2 deck lines %r' % deck[0])
    absent, wording, st = LS.compare(man, deck)
    ok('A7-3 다중성 보존 — 원고 Title×2 vs 덱 Title×1 → 짝 없는 줄 1') if len(absent) == 1 and len(wording) == 0 \
        else ng('A7-3 absent=%r wording=%r' % (absent, wording))

    # A8 알갱이 불일치(덱 세션 실측 47→279) — 원고는 도형 단위, 덱은 문단 단위. 2단계 대조가 «같은 도형의 문단 join» 을 짝으로 본다
    mp2 = os.path.join(fx_dir, 'ma_man2.md')
    with open(mp2, 'w', encoding='utf-8') as f:
        f.write('### U1 · x\n🖥\n1.무엇이 문제였나 2.무엇을 만들었나 3.무엇을 가져가나\n🗣\n말\n')
    d2 = os.path.join(fx_dir, 'ma_multi.pptx')
    body3 = ('<p:sp><p:nvSpPr><p:cNvPr id="1" name="g"/></p:nvSpPr><p:txBody>'
             '<a:p><a:r><a:rPr/><a:t>1.무엇이 문제였나</a:t></a:r></a:p>'
             '<a:p><a:r><a:rPr/><a:t>2.무엇을 만들었나</a:t></a:r></a:p>'
             '<a:p><a:r><a:rPr/><a:t>3.무엇을 가져가나</a:t></a:r></a:p></p:txBody></p:sp>')
    _mini_deck(d2, [body3])
    man2 = LS.manuscript_screens(mp2); grp = LS.deck_screens_grouped(d2); deck2 = [[t for sh_ in sl for t in sh_] for sl in grp]
    a1, w1, st1 = LS.compare(man2, deck2)                       # 1단계만 — 오탐 형태 재현(1 원고-only + 3 화면-only)
    a2, w2, st2 = LS.compare(man2, deck2, deck_groups=grp)      # 2단계
    ok('A8 다문단 도형: 1단계만이면 짝없음 %d(오탐, stage=1 표기) · 2단계면 0 (join 1건, stage=2)' % len(a1)) \
        if len(a1) == 4 and len(a2) == 0 and st2.get('joined') == 1 and st1.get('stage') == 1 and st2.get('stage') == 2 \
        else ng('A8 a1=%d a2=%d joined=%r stage=%r/%r' % (len(a1), len(a2), st2.get('joined'), st1.get('stage'), st2.get('stage')))
    # A8 컨트롤 — 덱에서 문단 하나가 정말 빠지면 2단계로도 안 맞아야 한다(join 이 원고 줄과 달라진다)
    d3 = os.path.join(fx_dir, 'ma_multi_missing.pptx')
    _mini_deck(d3, [body3.replace('<a:p><a:r><a:rPr/><a:t>2.무엇을 만들었나</a:t></a:r></a:p>', '')])
    grp3 = LS.deck_screens_grouped(d3); deck3 = [[t for sh_ in sl for t in sh_] for sl in grp3]
    a3, w3, st3 = LS.compare(man2, deck3, threshold=0.90, deck_groups=grp3)
    ok('A8 컨트롤 — 문단 소실 덱은 2단계로도 짝없음/문구차이로 남는다') if (len(a3) + len(w3)) >= 1 \
        else ng('A8 컨트롤 — 문단이 빠졌는데 0 (a3=%r w3=%r)' % (a3, w3))
    # A9 죽은 선언 — 아무것도 안 거는 intended 항목이 🟥 로 보고된다 (geometry · attr 둘 다)
    dg = os.path.join(fx_dir, 'ma_dead_geo.pptx')
    _mini_deck(dg, [_sp('bar', 914400, 914400, 100000, 100000, 'x'), _sp('bar', 914400 + 20000, 914400, 100000, 100000, 'x')])
    S_g = LG.load_slides(dg)
    _l, _st, sup, errs = LG.p1_lines(S_g, 200000, [
        {'slides': [1, 2], 'shapes': ['bar'], 'attrs': ['x'], 'why': '산 선언'},
        {'slides': [1, 2], 'shapes': ['ghost'], 'attrs': ['y'], 'why': '죽은 선언'}])
    dead = [e for e in errs if '죽은 선언' in e]
    ok('A9 geometry: 산 선언 1 면제 · 죽은 선언 1 보고 (%s)' % (dead[0][:40] if dead else '-')) \
        if len(sup) == 1 and len(dead) == 1 and 'intended[2]' in dead[0] else ng('A9 geometry sup=%d errs=%r' % (len(sup), errs))
    S_a, sw_a = LA.load(os.path.join(fx_dir, 'ma_algn.pptx'))
    _l2, sup2, errs2, st2 = LA.collect(os.path.join(fx_dir, 'ma_algn.pptx'), {
        'intended': [{'axis': 'algn', 'slides': [1], 'why': '산 선언'}, {'axis': 'dash', 'slides': [1], 'why': '죽은 선언'}]})
    dead2 = [e for e in errs2 if '죽은 선언' in e]
    ok('A9 attr: 산 선언 1 면제 · 죽은 선언 1 보고') if len(sup2) == 1 and len(dead2) == 1 and 'intended[2]' in dead2[0] \
        else ng('A9 attr sup=%d errs=%r' % (len(sup2), errs2))

    # ── R2 (codex 09-11 13:04) 레인 A5–A10 · B11–B12 ──
    mp3 = os.path.join(fx_dir, 'r2_man.md')
    def _man(lines):
        with open(mp3, 'w', encoding='utf-8') as f:
            f.write('### U1 · x\n🖥\n' + '\n'.join(lines) + '\n🗣\n말\n')
        return LS.manuscript_screens(mp3)
    def _shape(*paras):
        return ('<p:sp><p:nvSpPr><p:cNvPr id="1" name="g"/></p:nvSpPr><p:txBody>' +
                ''.join('<a:p><a:r><a:rPr/><a:t>%s</a:t></a:r></a:p>' % t for t in paras) + '</p:txBody></p:sp>')
    def _cmp(man, deck_path, **kw):
        grp = LS.deck_screens_grouped(deck_path); dk = [[t for sh_ in sl for t in sh_] for sl in grp]
        return LS.compare(man, dk, deck_groups=grp, **kw)
    # A5 유사 join 은 조용히 사라지지 않는다 — 문구 차이로 남는다
    d = os.path.join(fx_dir, 'r2_fuzzy.pptx'); _mini_deck(d, [_shape('Revenue', 'grew')])
    a5, w5, st5 = _cmp(_man(['Revenue fell']), d)
    ok('A5 유사 join → 문구 차이 1(짝없음 0, joined 1)') if len(w5) == 1 and len(a5) == 0 and st5['joined'] == 1 \
        else ng('A5 a=%r w=%r st=%r' % (a5, w5, st5))
    # B11 1단계에서 일부가 맞았어도 나머지를 잇는다
    d = os.path.join(fx_dir, 'r2_partial.pptx'); _mini_deck(d, [_shape('Title', 'Alpha', 'Beta')])
    a11, w11, st11 = _cmp(_man(['Title', 'AlphaBeta']), d)
    ok('B11 부분 일치 뒤 나머지 join → 어긋남 0') if not a11 and not w11 and st11['joined'] == 1 \
        else ng('B11 a=%r w=%r st=%r' % (a11, w11, st11))
    # B12 중복 문단이 크래시 대신 어긋남으로
    d = os.path.join(fx_dir, 'r2_dup.pptx'); _mini_deck(d, [_shape('X', 'X')])
    try:
        a12, w12, st12 = _cmp(_man(['X', 'XX']), d)
        ok('B12 중복 문단: 크래시 없이 어긋남 %d' % (len(a12) + len(w12))) if (len(a12) + len(w12)) >= 1 \
            else ng('B12 중복 문단이 0 어긋남 (a=%r w=%r)' % (a12, w12))
    except Exception as e:
        ng('B12 크래시 %s: %s' % (type(e).__name__, e))
    # A10 표(graphicFrame) 글자도 화면이다
    d = os.path.join(fx_dir, 'r2_table.pptx')
    tbl = ('<p:graphicFrame><p:nvGraphicFramePr><p:cNvPr id="2" name="tbl"/></p:nvGraphicFramePr><a:graphic><a:graphicData>'
           '<a:tbl><a:tr><a:tc><a:txBody><a:p><a:r><a:rPr/><a:t>Unreported change</a:t></a:r></a:p></a:txBody></a:tc></a:tr></a:tbl>'
           '</a:graphicData></a:graphic></p:graphicFrame>')
    _mini_deck(d, [_shape('Title') + tbl])
    a10, w10, st10 = _cmp(_man(['Title']), d)
    ok('A10 표 글자가 «화면에만» 으로 잡힌다') if any(x[2] == '화면에만' and 'Unreported' in x[3] for x in a10) \
        else ng('A10 표 글자 미추출 a=%r' % a10)
    # A6 delta() 의 선언 오류는 현재본의 것
    dg_b = os.path.join(fx_dir, 'r2_geo_base.pptx'); dg_c = os.path.join(fx_dir, 'r2_geo_cur.pptx')
    _mini_deck(dg_b, [_sp('box', 914400, 914400, 100000, 100000, 'x'), _sp('box', 914400 + 10000, 914400, 100000, 100000, 'x')])
    _mini_deck(dg_c, [_sp('box', 914400, 914400, 100000, 100000, 'x'), _sp('box', 914400, 914400, 100000, 100000, 'x')])
    _n, _g, _sb, _sc, _sup, errs6 = LG.delta(dg_b, dg_c, 200000, 63500,
                                             [{'slides': [1, 2], 'shapes': ['box'], 'attrs': ['x'], 'why': 'w'}])
    ok('A6 delta: 현재본에서 죽은 선언이 보고된다') if any('죽은 선언' in e for e in errs6) \
        else ng('A6 delta errs=%r' % errs6)
    # A7 echo 면제는 그룹의 모든 장이 선언돼야
    d = os.path.join(fx_dir, 'r2_echo.pptx')
    _mini_deck(d, [_sp('label', 0, 0, 100, 100, 'same sentence here', 2800), _sp('label', 0, 0, 100, 100, 'same sentence here', 3200),
                   _sp('label', 0, 0, 100, 100, 'same sentence here', 4400)])
    l7, sup7, e7, st7 = LA.collect(d, {'axes': ['echo'], 'intended': [{'axis': 'echo', 'slides': [1, 2], 'shapes': ['label'], 'why': 'w'}]})
    l7b, sup7b, e7b, st7b = LA.collect(d, {'axes': ['echo'], 'intended': [{'axis': 'echo', 'slides': [1, 2, 3], 'shapes': ['label'], 'why': 'w'}]})
    ok('A7 echo: [1,2] 만 선언 → 후보로 남음(1) · [1,2,3] 선언 → 면제(0)') if len(l7) == 1 and len(sup7) == 0 and len(l7b) == 0 and len(sup7b) == 1 \
        else ng('A7 partial: lines=%d sup=%d · full: lines=%d sup=%d' % (len(l7), len(sup7), len(l7b), len(sup7b)))
    # A8 런 경계는 글자가 아니다
    d = os.path.join(fx_dir, 'r2_runs.pptx')
    two_runs = ('<p:sp><p:nvSpPr><p:cNvPr id="1" name="t"/></p:nvSpPr><p:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="100" cy="100"/></a:xfrm></p:spPr>'
                '<p:txBody><a:p><a:r><a:rPr sz="3200"/><a:t>Alpha</a:t></a:r><a:r><a:rPr sz="3200"/><a:t>BetaGamma</a:t></a:r></a:p></p:txBody></p:sp>')
    _mini_deck(d, [_sp('t', 0, 0, 100, 100, 'AlphaBetaGamma', 2800), two_runs])
    S8, _ = LA.load(d)
    ok('A8 두 런 «Alpha»+«BetaGamma» = «AlphaBetaGamma» (공백 삽입 없음)') if S8[1][0]['text'] == 'AlphaBetaGamma' \
        else ng('A8 text=%r' % S8[1][0]['text'])
    # A9 순서 보존 — 좌 28/32 ↔ 우 32/28 은 다르다
    d = os.path.join(fx_dir, 'r2_order.pptx')
    def _two(name, x, s1, s2):
        return ('<p:sp><p:nvSpPr><p:cNvPr id="1" name="%s"/></p:nvSpPr><p:spPr><a:xfrm><a:off x="%d" y="914400"/><a:ext cx="3657600" cy="914400"/></a:xfrm></p:spPr>'
                '<p:txBody><a:p><a:r><a:rPr sz="%d"/><a:t>Alpha</a:t></a:r><a:r><a:rPr sz="%d"/><a:t>Beta</a:t></a:r></a:p></p:txBody></p:sp>' % (name, x, s1, s2))
    _mini_deck(d, [_two('L', 914400, 2800, 3200) + _two('R', 7620000, 3200, 2800)])
    S9, sw9 = LA.load(d)
    hits9 = list(LA.ax_mirror(S9, sw9, {}))
    ok('A9 mirror: (28,32) vs (32,28) 가 갈림으로 잡힌다') if len(hits9) == 1 and S9[0][0]['szs'] == (28.0, 32.0) \
        else ng('A9 hits=%d szs=%r/%r' % (len(hits9), S9[0][0]['szs'], S9[0][1]['szs']))

    # ── R3 (codex 09-11 13:1x) 레인 A6–A12 · B13–B14 ──
    # A6 여는 태그에 속성이 있어도 도형이다 (셋 다)
    d = os.path.join(fx_dir, 'r3_attr_tag.pptx')
    _mini_deck(d, [_sp('h', 0, 0, 100, 100, 'Hidden by parser').replace('<p:sp>', '<p:sp useBgFill="1">')])
    n_g = len(LG.load_slides(d)[0]); n_a = len(LA.load(d)[0][0]); n_s = len(LS.deck_screens(d)[0])
    ok('A6 <p:sp useBgFill="1"> — geometry %d · attr %d · parity %d (전부 1)' % (n_g, n_a, n_s)) if (n_g, n_a, n_s) == (1, 1, 1) \
        else ng('A6 속성 있는 여는 태그에서 도형 소실 g=%d a=%d s=%d' % (n_g, n_a, n_s))
    # A7 geometry: 런이 갈려도 같은 글자면 결박되고 flip 이 보고된다
    d = os.path.join(fx_dir, 'r3_geo_runs.pptx')
    split_run = ('<p:sp><p:nvSpPr><p:cNvPr id="1" name="arrow"/></p:nvSpPr><p:spPr><a:xfrm flipH="1"><a:off x="0" y="0"/><a:ext cx="100" cy="100"/></a:xfrm></p:spPr>'
                 '<p:txBody><a:p><a:r><a:rPr/><a:t>AB</a:t></a:r><a:r><a:rPr/><a:t>CD</a:t></a:r></a:p></p:txBody></p:sp>')
    _mini_deck(d, [_sp('arrow', 0, 0, 100, 100, 'ABCD'), split_run])
    l7, st7, _s, _e = LG.p1_lines(LG.load_slides(d), 200000)
    ok('A7 geometry: AB+CD 런이 ABCD 로 결박되고 뒤집힘 1건 보고') if any('뒤집힘' in l for l in l7) and st7.get('mismatch', 0) == 0 \
        else ng('A7 lines=%r stats=%r' % (l7, st7))
    # A8 delta 신원 — 앞 16자가 같은 두 이름을 합치지 않는다
    db = os.path.join(fx_dir, 'r3_delta_b.pptx'); dc = os.path.join(fx_dir, 'r3_delta_c.pptx')
    A = 'abcdefghijklmnopA'; B = 'abcdefghijklmnopB'
    # B 는 멀리(x=5,000,000) 둔다 — 겹치면 P3 인접 후보가 델타에 섞인다(계기가 아니라 픽스처의 문제)
    _mini_deck(db, [_sp(A, 0, 0, 100, 100, 'x') + _sp(B, 5000000, 0, 100, 100, 'x'), _sp(A, 10, 0, 100, 100, 'x') + _sp(B, 5000000, 0, 100, 100, 'x')])
    _mini_deck(dc, [_sp(A, 0, 0, 100, 100, 'x') + _sp(B, 5000000, 0, 100, 100, 'x'), _sp(A, 0, 0, 100, 100, 'x') + _sp(B, 5000010, 0, 100, 100, 'x')])
    new8, gone8, *_ = LG.delta(db, dc, 200000, 63500)
    ok('A8 delta: 새 1 · 사라짐 1 (이름 전체가 신원)') if len(new8) == 1 and len(gone8) == 1 else ng('A8 new=%d gone=%d' % (len(new8), len(gone8)))
    # A9 문자열 shapes 선언은 오류 (geometry · attr)
    _i9, e9 = LG._intent_index([{'slides': [1, 2], 'shapes': 'ab', 'attrs': ['x'], 'why': 'w'}])
    _i9b, e9b = LA._intent_index([{'axis': 'dash', 'slides': [1], 'shapes': 'ab', 'why': 'w'}])
    ok('A9 shapes:"ab" → geometry·attr 둘 다 선언 오류(면제 0)') if len(e9) == 1 and not _i9 and len(e9b) == 1 and not _i9b \
        else ng('A9 geo errs=%r idx=%r · attr errs=%r idx=%r' % (e9, dict(_i9), e9b, dict(_i9b)))
    # A10 구간: AB@28+CD@32 vs A@28+BCD@32 는 다르다 · ABCD@28 vs AB@28+CD@28 은 같다
    def _runs(name, x, *runs):
        return ('<p:sp><p:nvSpPr><p:cNvPr id="1" name="%s"/></p:nvSpPr><p:spPr><a:xfrm><a:off x="%d" y="914400"/><a:ext cx="3657600" cy="914400"/></a:xfrm></p:spPr>'
                '<p:txBody><a:p>%s</a:p></p:txBody></p:sp>' % (name, x, ''.join('<a:r><a:rPr sz="%d"/><a:t>%s</a:t></a:r>' % (sz, t) for t, sz in runs)))
    d = os.path.join(fx_dir, 'r3_spans.pptx')
    # 장 1: t=AB@28+CD@32 · u=ABCD@28 · 장 2: t=A@28+BCD@32 · u=AB@28+CD@28 → echo 는 t 만(1건), u 는 같은 구간이라 0
    _mini_deck(d, [_runs('t', 0, ('ABCDEFGH', 2800), ('IJKLMNOP', 3200)) + _runs('u', 5000000, ('QRSTUVWXQRSTUVWX', 2800)),
                   _runs('t', 0, ('ABCDEFG', 2800), ('HIJKLMNOP', 3200)) + _runs('u', 5000000, ('QRSTUVWX', 2800), ('QRSTUVWX', 2800))])
    S10, sw10 = LA.load(d)
    sp_t1, sp_u1, sp_t2, sp_u2 = S10[0][0]['spans'], S10[0][1]['spans'], S10[1][0]['spans'], S10[1][1]['spans']
    e10 = list(LA.ax_echo(S10, sw10, {}))
    ok('A10 구간: t %s≠%s → echo 1 · u 같은 구간 → 0 (echo 총 %d)' % (sp_t1, sp_t2, len(e10))) \
        if sp_t1 != sp_t2 and sp_u1 == sp_u2 == ((16, 28.0),) and len(e10) == 1 and 'ABCDEFGH' in e10[0][2] and 'u' not in [n for _s, ns, _l in e10 for n in ns] \
        else ng('A10 t=%r/%r u=%r/%r echo=%r' % (sp_t1, sp_t2, sp_u1, sp_u2, [l for _s, _n, l in e10]))
    # A11 정렬 슬롯: [ctr, 기본] vs [기본, ctr] 는 다르다
    def _paras(name, x, *al):
        return ('<p:sp><p:nvSpPr><p:cNvPr id="1" name="%s"/></p:nvSpPr><p:spPr><a:xfrm><a:off x="%d" y="914400"/><a:ext cx="3657600" cy="914400"/></a:xfrm></p:spPr><p:txBody>%s</p:txBody></p:sp>'
                % (name, x, ''.join('<a:p>%s<a:r><a:rPr/><a:t>p</a:t></a:r></a:p>' % ('<a:pPr algn="%s"/>' % a_ if a_ else '') for a_ in al)))
    d = os.path.join(fx_dir, 'r3_algn_slots.pptx'); _mini_deck(d, [_paras('a', 0, 'ctr', None) + _paras('b', 5000000, None, 'ctr')])
    S11, sw11 = LA.load(d)
    ok('A11 정렬 슬롯 %s vs %s → 갈림 1' % (S11[0][0]['algn'], S11[0][1]['algn'])) if S11[0][0]['algn'] != S11[0][1]['algn'] and len(list(LA.ax_algn(S11, sw11, {}))) == 1 \
        else ng('A11 algn=%r/%r' % (S11[0][0]['algn'], S11[0][1]['algn']))
    # A12 엔티티 동치: &amp; 와 &#38; 는 같은 문장
    d = os.path.join(fx_dir, 'r3_entity.pptx')
    _mini_deck(d, [_sp('e', 0, 0, 100, 100, 'Research &amp; Development', 2800), _sp('e', 0, 0, 100, 100, 'Research &#38; Development', 3200)])
    S12, sw12 = LA.load(d)
    ok('A12 &amp;/&#38; 같은 키 → echo 크기 갈림 1') if len(list(LA.ax_echo(S12, sw12, {}))) == 1 else ng('A12 texts=%r' % [S12[0][0]['text'], S12[1][0]['text']])
    # B13 도형 전체 정확 join 을 먼저 소비 — 원고 AB·ABX ↔ 도형 [AB,X]·[A,B] → 0
    d = os.path.join(fx_dir, 'r3_greedy.pptx'); _mini_deck(d, [_shape('AB', 'X') + _shape('A', 'B')])
    a13, w13, st13 = _cmp(_man(['AB', 'ABX']), d)
    ok('B13 정확 도형 join 우선 → 어긋남 0') if not a13 and not w13 else ng('B13 a=%r w=%r' % (a13, w13))
    # B14 부분 선언이 완전 선언을 가리지 않는다(순서 무관)
    d = os.path.join(fx_dir, 'r3_echo_order.pptx')
    _mini_deck(d, [_sp('label', 0, 0, 100, 100, 'same sentence here', 2800), _sp('label', 0, 0, 100, 100, 'same sentence here', 3200)])
    decl = [{'axis': 'echo', 'slides': [1], 'shapes': ['label'], 'why': '부분'}, {'axis': 'echo', 'slides': [1, 2], 'shapes': ['label'], 'why': '완전'}]
    l14a, s14a, e14a, _ = LA.collect(d, {'axes': ['echo'], 'intended': decl})
    l14b, s14b, e14b, _ = LA.collect(d, {'axes': ['echo'], 'intended': list(reversed(decl))})
    ok('B14 [부분,완전]·[완전,부분] 둘 다 면제 1 · 후보 0') if len(s14a) == 1 and len(s14b) == 1 and not l14a and not l14b \
        else ng('B14 a: sup=%d lines=%d · b: sup=%d lines=%d · errs=%r' % (len(s14a), len(l14a), len(s14b), len(l14b), e14a))

    # ── R4 (codex 09-11 18:02) 레인 A3–A7 · B8 ──
    # A3 ⓪ 에서 통째로 소비된 도형은 ② 가 다시 못 빌린다 — 원고 AB·AB ↔ 도형 [A,B]·[A]·[B] → 둘째 AB 는 짝 없음
    d = os.path.join(fx_dir, 'r4_owner.pptx'); _mini_deck(d, [_shape('A', 'B') + _shape('A') + _shape('B')])
    a3, w3, st3 = _cmp(_man(['AB', 'AB']), d)
    ok('A3 도형 소유권: 둘째 AB 는 짝 없음(absent %d · joined %d)' % (len(a3), st3['joined'])) if len(a3) == 1 and st3['joined'] == 1 \
        else ng('A3 a=%r w=%r st=%r' % (a3, w3, st3))
    # A4 <a:fld> 런의 크기도 구간에 들어간다
    def _fld(name, x, sz):
        return ('<p:sp><p:nvSpPr><p:cNvPr id="1" name="%s"/></p:nvSpPr><p:spPr><a:xfrm><a:off x="%d" y="914400"/><a:ext cx="3657600" cy="914400"/></a:xfrm></p:spPr>'
                '<p:txBody><a:p><a:fld id="{x}" type="slidenum"><a:rPr sz="%d"/><a:t>7</a:t></a:fld></a:p></p:txBody></p:sp>' % (name, x, sz))
    d = os.path.join(fx_dir, 'r4_fld.pptx'); _mini_deck(d, [_fld('L', 914400, 2800) + _fld('R', 7620000, 3200)])
    S4, sw4 = LA.load(d)
    ok('A4 fld 런 구간 %s vs %s → mirror 1' % (S4[0][0]['spans'], S4[0][1]['spans'])) if S4[0][0]['spans'] == ((1, 28.0),) and len(list(LA.ax_mirror(S4, sw4, {}))) == 1 \
        else ng('A4 spans=%r/%r' % (S4[0][0]['spans'], S4[0][1]['spans']))
    # A5 <a:off y= x=> 순서 — geometry·attr 둘 다 도형을 잃지 않는다
    d = os.path.join(fx_dir, 'r4_offorder.pptx')
    swapped = _sp('m', 35000, 0, 100, 100, 'x').replace('<a:off x="35000" y="0"/>', '<a:off y="0" x="35000"/>')
    _mini_deck(d, [_sp('m', 0, 0, 100, 100, 'x'), swapped])
    l5, st5, _s, _e = LG.p1_lines(LG.load_slides(d), 200000)
    n_a5 = len(LA.load(d)[0][1])
    ok('A5 off 속성 순서 뒤집혀도 geometry 후보 1 · attr 도형 1') if len(l5) == 1 and n_a5 == 1 else ng('A5 geo=%r attr=%d' % (l5, n_a5))
    # A6 geometry 엔티티 동치 — R&amp;D 와 R&#38;D 는 같은 글자로 결박
    d = os.path.join(fx_dir, 'r4_geo_entity.pptx'); _mini_deck(d, [_sp('e', 0, 0, 100, 100, 'R&amp;D'), _sp('e', 35000, 0, 100, 100, 'R&#38;D')])
    l6, st6, _s, _e = LG.p1_lines(LG.load_slides(d), 200000)
    ok('A6 geometry: 엔티티 표기가 달라도 결박(mismatch 0) · 후보 1') if len(l6) == 1 and st6.get('mismatch', 0) == 0 else ng('A6 lines=%r st=%r' % (l6, st6))
    # A7 slides 원소 1.9 · true 는 오류
    _i7, e7 = LA._intent_index([{'axis': 'dash', 'slides': [1.9], 'why': 'w'}, {'axis': 'dash', 'slides': [True], 'why': 'w'}])
    ok('A7 slides [1.9]·[true] → 선언 오류 2 · 면제 0') if len(e7) == 2 and not _i7 else ng('A7 errs=%r idx=%r' % (e7, dict(_i7)))
    # B8 mirror: 글자 수 다른 AB / ABCDE 같은 28pt → 후보 0 · (28,32)/(32,28) 는 여전히 1
    d = os.path.join(fx_dir, 'r4_mirror_len.pptx')
    _mini_deck(d, [_sp('L', 914400, 914400, 3657600, 914400, 'AB', 2800) + _sp('R', 7620000, 914400, 3657600, 914400, 'ABCDE', 2800)])
    S8, sw8 = LA.load(d)
    S9b, sw9b = LA.load(os.path.join(fx_dir, 'r2_order.pptx'))
    ok('B8 mirror: 글자 수만 다른 쌍 0 · 크기 순열 다른 쌍 1') if len(list(LA.ax_mirror(S8, sw8, {}))) == 0 and len(list(LA.ax_mirror(S9b, sw9b, {}))) == 1 \
        else ng('B8 len-only=%d order=%d' % (len(list(LA.ax_mirror(S8, sw8, {}))), len(list(LA.ax_mirror(S9b, sw9b, {})))))

    # ── R5 (codex 09-11 18:13) 레인 A3–A7 ──
    # A3 그룹 xfrm 의 flipH 가 자식에 합성된다
    d = os.path.join(fx_dir, 'r5_grpflip.pptx')
    child = _sp('arrow', 0, 0, 100, 100, 'x')
    grp_flipped = ('<p:grpSp><p:nvGrpSpPr><p:cNvPr id="9" name="g"/></p:nvGrpSpPr><p:grpSpPr><a:xfrm flipH="1"><a:off x="0" y="0"/><a:ext cx="100" cy="100"/>'
                   '<a:chOff x="0" y="0"/><a:chExt cx="100" cy="100"/></a:xfrm></p:grpSpPr>' + child + '</p:grpSp>')
    grp_plain = grp_flipped.replace('<a:xfrm flipH="1">', '<a:xfrm>')
    _mini_deck(d, [grp_plain, grp_flipped])
    l3, st3, _s, _e = LG.p1_lines(LG.load_slides(d), 200000)
    ok('A3 그룹 뒤집힘이 자식에 합성 → 뒤집힘 1건') if any('뒤집힘' in l for l in l3) else ng('A3 lines=%r st=%r' % (l3, st3))
    # A4 sldSz 속성 순서 뒤집혀도 폭 20.0 (기본값 13.333 로 안 떨어진다)
    d = os.path.join(fx_dir, 'r5_sldsz.pptx'); _mini_deck(d, [_sp('a', 0, 0, 100, 100, 'x')])
    import zipfile
    zi = zipfile.ZipFile(d); data = {n: zi.read(n) for n in zi.namelist()}; zi.close()
    data['ppt/presentation.xml'] = data['ppt/presentation.xml'].replace(b'<p:sldSz cx="12192000" cy="6858000"/>', b'<p:sldSz cy="6858000" cx="18288000"/>')
    zo = zipfile.ZipFile(d, 'w'); [zo.writestr(n, v) for n, v in data.items()]; zo.close()
    _S4, sw4b = LA.load(d)
    ok('A4 sldSz cy·cx 순서 → 폭 %.1f (20.0)' % sw4b) if abs(sw4b - 20.0) < 0.01 else ng('A4 sw=%r' % sw4b)
    # A5 같은 글자면 구간 전체 비교 — AB@28+CD@32 vs A@28+BCD@32 (B 가 커졌다) → mirror 1
    d = os.path.join(fx_dir, 'r5_sametext.pptx')
    _mini_deck(d, [_runs('L', 914400, ('AB', 2800), ('CD', 3200)) + _runs('R', 7620000, ('A', 2800), ('BCD', 3200))])
    S5, sw5 = LA.load(d)
    ok('A5 같은 글자·다른 경계 → mirror 1') if len(list(LA.ax_mirror(S5, sw5, {}))) == 1 else ng('A5 spans=%r/%r' % (S5[0][0]['spans'], S5[0][1]['spans']))
    # A6 한 장에 같은 이름 둘 — 선언 ["A","B"] 가 셋째 A 를 같이 면제하지 못한다
    d = os.path.join(fx_dir, 'r5_dupname.pptx')
    def _ln(name, x, w_emu, dash='dash'):
        return ('<p:sp><p:nvSpPr><p:cNvPr id="1" name="%s"/></p:nvSpPr><p:spPr><a:xfrm><a:off x="%d" y="0"/><a:ext cx="100" cy="100"/></a:xfrm>'
                '<a:ln w="%d"><a:prstDash val="%s"/></a:ln></p:spPr><p:txBody><a:p><a:r><a:rPr/><a:t>l</a:t></a:r></a:p></p:txBody></p:sp>' % (name, x, w_emu, dash))
    _mini_deck(d, [_ln('A', 0, 12700) + _ln('B', 1000000, 25400) + _ln('A', 2000000, 63500)])
    l6, s6, e6, _ = LA.collect(d, {'axes': ['dash'], 'intended': [{'axis': 'dash', 'slides': [1], 'shapes': ['A', 'B'], 'why': 'w'}]})
    _mini_deck(d, [_ln('A', 0, 12700) + _ln('B', 1000000, 25400)])
    l6b, s6b, e6b, _ = LA.collect(d, {'axes': ['dash'], 'intended': [{'axis': 'dash', 'slides': [1], 'shapes': ['A', 'B'], 'why': 'w'}]})
    # 두 번째 팔: shapes 없는 «그 장 전체» 선언도 이름이 겹치는 그룹은 못 면제한다(AMBIG 가드의 고유 몫)
    _mini_deck(d, [_ln('A', 0, 12700) + _ln('B', 1000000, 25400) + _ln('A', 2000000, 63500)])
    l6c, s6c, e6c, _ = LA.collect(d, {'axes': ['dash'], 'intended': [{'axis': 'dash', 'slides': [1], 'why': 'w'}]})
    ok('A6 같은 이름 둘 → 면제 안 됨(후보 1, 장 전체 선언도 1) · 이름 유일 컨트롤 → 면제 1') \
        if len(l6) == 1 and not s6 and not l6b and len(s6b) == 1 and len(l6c) == 1 and not s6c \
        else ng('A6 dup: lines=%d sup=%d · uniq: lines=%d sup=%d · whole-slide: lines=%d sup=%d' % (len(l6), len(s6), len(l6b), len(s6b), len(l6c), len(s6c)))
    # A7 <a:t xmlns:a=…> 도 글자다 (parity · attr · geometry)
    d = os.path.join(fx_dir, 'r5_xmlns_t.pptx')
    _mini_deck(d, [_sp('u', 0, 0, 100, 100, 'UNLISTED').replace('<a:t>', '<a:t xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">')])
    t_par = LS.deck_screens(d)[0]; t_attr = LA.load(d)[0][0][0]['text']; t_geo = LG.load_slides(d)[0]['u'][4]
    ok('A7 xmlns 붙은 <a:t>: parity %r · attr %r · geo %r' % (t_par, t_attr, t_geo)) if t_par == ['UNLISTED'] and t_attr == 'UNLISTED' and t_geo == 'UNLISTED' \
        else ng('A7 par=%r attr=%r geo=%r' % (t_par, t_attr, t_geo))

    # ── R6 (codex 09-11 23:07) 레인 — 정규식 독자 → oox 트리 독자 교체의 회귀 ──
    def _grp(inner, flip='', off=(0, 0), ext=(100, 100), choff=(0, 0), chext=(100, 100)):
        xf = '<a:xfrm%s><a:off x="%d" y="%d"/><a:ext cx="%d" cy="%d"/><a:chOff x="%d" y="%d"/><a:chExt cx="%d" cy="%d"/></a:xfrm>' % (
            (' flipH="1"' if flip == 'H' else ''), off[0], off[1], ext[0], ext[1], choff[0], choff[1], chext[0], chext[1])
        return '<p:grpSp><p:nvGrpSpPr><p:cNvPr id="9" name="g"/></p:nvGrpSpPr><p:grpSpPr>%s</p:grpSpPr>%s</p:grpSp>' % (xf, inner)
    # A3 중첩 그룹: 안쪽 그룹의 flipH 가 화살표에 합성 · 바깥 그룹 flip 은 «안쪽 그룹 뒤의 형제» 에도 합성
    child = _sp('arrow', 0, 0, 100, 100, 'x'); sib = _sp('sib', 0, 0, 100, 100, 'y')
    d = os.path.join(fx_dir, 'r6_nested.pptx')
    _mini_deck(d, [_grp(_grp(child) + sib), _grp(_grp(child, flip='H') + sib)])
    l3, st3, _s, _e = LG.p1_lines(LG.load_slides(d), 200000)
    d2 = os.path.join(fx_dir, 'r6_nested_outer.pptx')
    _mini_deck(d2, [_grp(_grp(child) + sib), _grp(_grp(child) + sib, flip='H')])
    l3b, _st, _s, _e = LG.p1_lines(LG.load_slides(d2), 200000)
    ok('A3 중첩: 안쪽 flip → arrow 뒤집힘 1 · 바깥 flip → arrow·sib 둘 다 뒤집힘') \
        if sum('뒤집힘' in l and 'arrow' in l for l in l3) == 1 and sum('뒤집힘' in l for l in l3b) == 2 \
        else ng('A3 inner=%r outer=%r' % (l3, l3b))
    # A4 그룹 이동이 자식 절대 좌표에 합성 — geometry 후보 1 · attr x 가 달라져 echo 후보 1
    d = os.path.join(fx_dir, 'r6_grpmove.pptx')
    _mini_deck(d, [_grp(_sp('t', 0, 0, 100, 100, 'same sentence here', 2800), off=(0, 0)), _grp(_sp('t', 0, 0, 100, 100, 'same sentence here', 2800), off=(35000, 0))])
    l4, st4, _s, _e = LG.p1_lines(LG.load_slides(d), 200000)
    S4, sw4 = LA.load(d)
    e4 = list(LA.ax_echo(S4, sw4, {}))
    d = os.path.join(fx_dir, 'r6_grpmove_big.pptx')
    _mini_deck(d, [_grp(_sp('t', 0, 0, 100, 100, 'same sentence here', 2800), off=(0, 0)), _grp(_sp('t', 0, 0, 100, 100, 'same sentence here', 2800), off=(914400, 0))])
    S4b, sw4b = LA.load(d); e4b = list(LA.ax_echo(S4b, sw4b, {}))
    ok('A4 그룹 이동 35000 EMU → geometry 후보 1 (%s) · 1인치 이동 → echo x 갈림 1' % (len(l4),)) \
        if len(l4) == 1 and abs(S4[1][0]['x'] - 35000 / 914400) < 1e-6 and len(e4b) == 1 and len(e4) == 0 \
        else ng('A4 geo=%r x2=%r echo35k=%d echo1in=%d' % (l4, S4[1][0]['x'], len(e4), len(e4b)))
    # A5 같은 장 «다른 자리» 의 같은 이름이 거울 면제를 막는다
    d = os.path.join(fx_dir, 'r6_dup_elsewhere.pptx')
    _mini_deck(d, [_sp('A', 914400, 914400, 3657600, 914400, 'left', 2800) + _sp('B', 7620000, 914400, 3657600, 914400, 'right', 3200) + _sp('A', 0, 5000000, 100, 100, 'else')])
    l5, s5, e5, _ = LA.collect(d, {'axes': ['mirror'], 'intended': [{'axis': 'mirror', 'slides': [1], 'shapes': ['A', 'B'], 'why': 'w'}]})
    ok('A5 다른 자리의 같은 이름 A → 거울 면제 안 됨(후보 1)') if len(l5) == 1 and not s5 else ng('A5 lines=%d sup=%d' % (len(l5), len(s5)))
    # A6 <q:sldId xmlns:q=…> 도 슬라이드다 — 세 레인 모두 3장
    d = os.path.join(fx_dir, 'r6_qsld.pptx'); _mini_deck(d, [_sp('a', 0, 0, 100, 100, 'FIRST'), _sp('b', 0, 0, 100, 100, 'HIDDEN'), _sp('c', 0, 0, 100, 100, 'THIRD')])
    zi = zipfile.ZipFile(d); data = {n: zi.read(n) for n in zi.namelist()}; zi.close()
    import re
    pres = data["ppt/presentation.xml"].decode(); ids = re.findall(r'<p:sldId [^>]*/>', pres)
    pres = pres.replace(ids[1], ids[1].replace('<p:sldId ', '<q:sldId xmlns:q="http://schemas.openxmlformats.org/presentationml/2006/main" '), 1)
    data['ppt/presentation.xml'] = pres.encode()
    zo = zipfile.ZipFile(d, 'w'); [zo.writestr(n, v) for n, v in data.items()]; zo.close()
    n6 = (len(LG.load_slides(d)), len(LA.load(d)[0]), len(LS.deck_screens(d)))
    ok('A6 q:sldId — geometry·attr·parity 전부 3장 %s' % (n6,)) if n6 == (3, 3, 3) else ng('A6 %r' % (n6,))
    # B7 공백 길이 차이는 크기 차이가 아니다 — "A  B" vs "A B" 28pt → mirror 0
    d = os.path.join(fx_dir, 'r6_ws.pptx')
    _mini_deck(d, [_sp('L', 914400, 914400, 3657600, 914400, 'A  B', 2800) + _sp('R', 7620000, 914400, 3657600, 914400, 'A B', 2800)])
    S7, sw7 = LA.load(d)
    ok('B7 공백 길이만 다른 거울 쌍 → 후보 0 (spans %s/%s)' % (S7[0][0]['spans'], S7[0][1]['spans'])) if len(list(LA.ax_mirror(S7, sw7, {}))) == 0 \
        else ng('B7 spans=%r/%r' % (S7[0][0]['spans'], S7[0][1]['spans']))


def run_r7_regressions(fx_dir):
    """R7 (codex 2026-09-11, commit 1551a4b) — 3S·4A·1B 각각 known-pair. 되돌림 프로브는 세션 마커에 기록."""
    print('\n[2-d] R7 codex 감사 회귀 — S1 rels 철자 · S2 r:embed 참조 · S3 잘린 JPEG · A4 flip 반사 · A5 AlternateContent · A6 공백 크기 · A7 자리표시자 중복 · B8 xmlns 공백')
    import subprocess, shutil, zipfile, re, io
    import lane_geometry as LG
    import lane_attr_consistency as LA
    import oox
    here = os.path.join(HERE, 'safe_install.py')
    src = os.path.join(fx_dir, 'p1.pptx')
    dest = os.path.join(fx_dir, 'r7_dest.pptx')

    def run(cand):
        shutil.copyfile(src, dest)
        r = subprocess.run([sys.executable, here, cand, dest, '--dry-run'], capture_output=True, text=True)
        return r.returncode, r.stdout + r.stderr

    def rewrite(src_p, dst_p, part, fn):
        zi = zipfile.ZipFile(src_p); zo = zipfile.ZipFile(dst_p, 'w', zipfile.ZIP_DEFLATED)
        for n in zi.namelist():
            d = zi.read(n)
            if n == part:
                d = fn(d)
            zo.writestr(n, d)
        zo.close()

    # ── S1 rels 를 `<q:Relationship xmlns:q=…>` + 홑따옴표로 다시 쓴 뒤 대상을 끊는다 ──
    rels_part = 'ppt/slides/_rels/slide1.xml.rels'
    def _requote(d, break_target):
        x = d.decode('utf-8')
        x = re.sub(r'<Relationship\b', '<q:Relationship xmlns:q="http://schemas.openxmlformats.org/package/2006/relationships"', x)
        x = re.sub(r'\b(Id|Type|Target)="([^"]*)"', lambda m: "%s='%s'" % (m.group(1), m.group(2)), x)
        if break_target:
            x = x.replace("Target='../slideLayouts/", "Target='../slideLayouts/NOPE_", 1)
        return x.encode('utf-8')
    ok_p = os.path.join(fx_dir, 'r7_s1_ok.pptx'); rewrite(src, ok_p, rels_part, lambda d: _requote(d, False))
    bad_p = os.path.join(fx_dir, 'r7_s1_bad.pptx'); rewrite(src, bad_p, rels_part, lambda d: _requote(d, True))
    rc_ok, out_ok = run(ok_p); rc_bad, out_bad = run(bad_p)
    ok('S1 q:Relationship+홑따옴표 — 멀쩡하면 통과(rc=0) · 대상 끊기면 거부(끊긴 관계)') \
        if rc_ok == 0 and rc_bad == 1 and '끊긴 관계' in out_bad else ng('S1 ok=%s bad=%s\n%s\n%s' % (rc_ok, rc_bad, out_ok[-300:], out_bad[-300:]))

    # ── S2 슬라이드 XML 이 r:id="rId999" 를 참조하는데 rels 에 없다 ──
    slide_part = 'ppt/slides/slide1.xml'
    def _hlink(rid):
        def f(d):
            x = d.decode('utf-8')
            x = re.sub(r'<p:cNvPr ([^>]*?)/>', r'<p:cNvPr \1><a:hlinkClick r:id="%s"/></p:cNvPr>' % rid, x, count=1)
            return x.encode('utf-8')
        return f
    existing = re.search(r'Id="(rId\d+)"', zipfile.ZipFile(src).read(rels_part).decode()).group(1)
    ok_p = os.path.join(fx_dir, 'r7_s2_ok.pptx'); rewrite(src, ok_p, slide_part, _hlink(existing))
    bad_p = os.path.join(fx_dir, 'r7_s2_bad.pptx'); rewrite(src, bad_p, slide_part, _hlink('rId999'))
    rc_ok, out_ok = run(ok_p); rc_bad, out_bad = run(bad_p)
    ok('S2 r:id 참조 — 실재 rId 통과 · rId999 거부(끊긴 참조)') \
        if rc_ok == 0 and rc_bad == 1 and '끊긴 참조' in out_bad else ng('S2 ok=%s bad=%s\n%s\n%s' % (rc_ok, rc_bad, out_ok[-300:], out_bad[-300:]))

    # ── S3 잘린 JPEG — verify() 는 통과시키고 load() 만 죽는 형태 ──
    try:
        from PIL import Image
        from pptx import Presentation
        from pptx.util import Inches
    except ImportError as e:
        sk('S3 PIL/python-pptx 부재: %s' % e)
    else:
        jpg = os.path.join(fx_dir, 'r7.jpg')
        Image.new('RGB', (256, 256), (200, 30, 30)).save(jpg, 'JPEG', quality=95)
        prs = Presentation(src); prs.slides[0].shapes.add_picture(jpg, Inches(1), Inches(1)); pic_p = os.path.join(fx_dir, 'r7_s3_ok.pptx'); prs.save(pic_p)
        media = [n for n in zipfile.ZipFile(pic_p).namelist() if n.startswith('ppt/media/')]
        assert len(media) == 1, media
        bad_p = os.path.join(fx_dir, 'r7_s3_bad.pptx'); rewrite(pic_p, bad_p, media[0], lambda d: d[: len(d) // 2])
        with Image.open(io.BytesIO(zipfile.ZipFile(bad_p).read(media[0]))) as im:
            try:
                im.verify(); v_ok = True
            except Exception:
                v_ok = False
        rc_ok, out_ok = run(pic_p); rc_bad, out_bad = run(bad_p)
        ok('S3 잘린 JPEG — verify() 는 통과(%s, 컨트롤: 이 레인이 재는 구멍이 실재) · 설치는 거부 · 온전한 그림은 통과' % v_ok) \
            if v_ok and rc_ok == 0 and rc_bad == 1 else ng('S3 verify=%s ok=%s bad=%s\n%s' % (v_ok, rc_ok, rc_bad, out_bad[-400:]))

    # ── A4 그룹 flipH 가 자식 «자리» 를 반사한다 — 단일 · 중첩 · rot 잔여 ──
    def _grp(inner, flip='', off=(0, 0), ext=(1000, 1000), choff=(0, 0), chext=(1000, 1000), rot=None):
        xf = '<a:xfrm%s%s><a:off x="%d" y="%d"/><a:ext cx="%d" cy="%d"/><a:chOff x="%d" y="%d"/><a:chExt cx="%d" cy="%d"/></a:xfrm>' % (
            (' flipH="1"' if flip == 'H' else ''), (' rot="%d"' % rot if rot else ''), off[0], off[1], ext[0], ext[1], choff[0], choff[1], chext[0], chext[1])
        return '<p:grpSp><p:nvGrpSpPr><p:cNvPr id="9" name="g"/></p:nvGrpSpPr><p:grpSpPr>%s</p:grpSpPr>%s</p:grpSp>' % (xf, inner)
    ch = _sp('c', 0, 0, 100, 100, 'x')
    d = os.path.join(fx_dir, 'r7_flip.pptx')
    _mini_deck(d, [_grp(ch, flip='H'),                                                   # 단일: x 0 → 900
                   _grp(_grp(ch, ext=(500, 500), chext=(500, 500)), flip='H'),           # 중첩(바깥 flip): 안쪽 상자 500~1000, 내부도 거울 → 900
                   _grp(ch, rot=5400000),                                                # rot 잔여
                   _grp(ch)])                                                            # 컨트롤: 0
    z = zipfile.ZipFile(d); order = oox.slide_order(z)                     # _mini_deck 은 파일 번호를 거꾸로 매긴다 — 발표 순서로 읽는다
    xs = [[s_['x'] for s_ in oox.walk_slide(z, fn)] for fn in order]
    rot_flag = oox.walk_slide(z, order[2])[0].get('rot_unmeasured'); rot_ctrl = oox.walk_slide(z, order[3])[0].get('rot_unmeasured')
    ok('A4 flipH 반사 — 단일 %s · 중첩 %s · 컨트롤 %s · rot 잔여 표시 %s/%s' % (xs[0], xs[1], xs[3], rot_flag, rot_ctrl)) \
        if xs[0] == [900] and xs[1] == [900] and xs[3] == [0] and rot_flag and not rot_ctrl \
        else ng('A4 xs=%r rot=%s/%s' % (xs, rot_flag, rot_ctrl))

    # ── A5 mc:AlternateContent — Choice 안의 도형을 세고, Choice 없으면 Fallback ──
    alt = ('<mc:AlternateContent xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006">'
           '<mc:Choice Requires="x">%s</mc:Choice><mc:Fallback>%s</mc:Fallback></mc:AlternateContent>')
    d = os.path.join(fx_dir, 'r7_alt.pptx')
    _mini_deck(d, [alt % (_sp('choice', 0, 0, 100, 100, 'a'), _sp('fallback', 0, 0, 100, 100, 'b')),
                   alt.replace('<mc:Choice Requires="x">%s</mc:Choice>', '') % (_sp('fallback', 0, 0, 100, 100, 'b'),)])
    z = zipfile.ZipFile(d); order = oox.slide_order(z)
    n1 = [s_['name'] for s_ in oox.walk_slide(z, order[0])]; n2 = [s_['name'] for s_ in oox.walk_slide(z, order[1])]
    ok('A5 AlternateContent — Choice 도형 %s · Fallback 만이면 %s' % (n1, n2)) if n1 == ['choice'] and n2 == ['fallback'] else ng('A5 %r %r' % (n1, n2))

    # ── A6 공백 «런» 의 크기 변화가 숨지 않는다 — B7(공백 길이만 다름=0)은 유지 ──
    def _runs(name, x, runs):
        body = ''.join('<a:r><a:rPr sz="%d"/><a:t>%s</a:t></a:r>' % (sz, t) for t, sz in runs)
        return ('<p:sp><p:nvSpPr><p:cNvPr id="1" name="%s"/></p:nvSpPr><p:spPr><a:xfrm><a:off x="%d" y="914400"/>'
                '<a:ext cx="3657600" cy="914400"/></a:xfrm></p:spPr><p:txBody><a:p>%s</a:p></p:txBody></p:sp>' % (name, x, body))
    d = os.path.join(fx_dir, 'r7_ws_size.pptx')
    _mini_deck(d, [_runs('L', 914400, [('abc', 2800), (' ', 3200), ('def', 2800)]) + _runs('R', 7620000, [('abc def', 2800)]),
                   _runs('L', 914400, [('A  B', 2800)]) + _runs('R', 7620000, [('A B', 2800)])])
    S, sw = LA.load(d)
    m = list(LA.ax_mirror(S, sw, {}))
    # 🟥 R8 A4 로 뒤집음: 공백은 크기를 갖지 않는다(앞 글자 상속) — 32pt 공백 «런» 은 이 레인이 못 본다(잔여, 이름으로).
    #    R7 의 기대값((3,28),(1,32),(3,28) · 후보 1) 은 실물 런 분할에서 오탐을 냈다(Opus R8 A4 실행 프로브).
    ok('A6(R8 역전) 32pt 공백 런 → 상속 (7,28) · 후보 0 · 공백 길이만 다름 → 0 · spans %s' % (S[0][0]['spans'],)) \
        if len(m) == 0 and S[0][0]["spans"] == ((7, 28.0),) and S[1][0]['spans'] == S[1][1]['spans'] \
        else ng('A6 m=%r spans=%r/%r' % (m, S[0][0]['spans'], S[1][0]['spans']))

    # ── A7 xfrm 없는 자리표시자와 같은 이름 → 살아남은 도형이 dup ──
    ph = '<p:sp><p:nvSpPr><p:cNvPr id="2" name="A"/><p:nvPr><p:ph type="title"/></p:nvPr></p:nvSpPr><p:spPr/><p:txBody><a:p><a:r><a:t>t</a:t></a:r></a:p></p:txBody></p:sp>'
    d = os.path.join(fx_dir, 'r7_ph_dup.pptx')
    _mini_deck(d, [ph + _sp('A', 914400, 914400, 100, 100, 'x'), _sp('A', 914400, 914400, 100, 100, 'x')])
    S, _ = LA.load(d)
    ok('A7 자리표시자(xfrm 없음)와 겹치는 이름 → dup=%s · 홀로면 %s' % (S[0][0]['dup'], S[1][0]['dup'])) \
        if len(S[0]) == 1 and S[0][0]['dup'] and not S[1][0]['dup'] else ng('A7 %r' % (S,))

    # ── B8 `xmlns:p = "…"` (= 양옆 공백) 도 선언이다 — 주입이 중복 속성을 만들면 안 된다 ──
    d = os.path.join(fx_dir, 'r7_xmlns_ws.pptx'); _mini_deck(d, [_sp('a', 0, 0, 100, 100, 'x')])
    d2 = os.path.join(fx_dir, 'r7_xmlns_ws2.pptx')
    rewrite(d, d2, 'ppt/slides/slide1.xml', lambda b: b.replace(b'xmlns:p="p"', b'xmlns:p = "p"', 1))
    try:
        n8 = len(oox.walk_slide(zipfile.ZipFile(d2), 1)); err = None
    except Exception as e:
        n8, err = None, e
    ok('B8 xmlns:p = "…" 공백 선언 → 파싱 1 도형') if n8 == 1 else ng('B8 n=%r err=%r' % (n8, err))


def run_r8_regressions(fx_dir):
    """R8 (Opus 팔, 2026-09-12, commit 4f738ad) — 1S·4A·7B 각각 known-pair."""
    print('\n[2-e] R8 Opus 감사 회귀 — S1 사후검증 실패 rc=3+복원 · A2 분류 실패≠결함 · A3 intended 원소형 · A4 공백/br 상속 · A5 flip 면제 · B6 빈 Choice · B7 절대 Target · B8 ppt/ 밖 r:id · B9 attrs 문자열 · B10 주석 뒤 루트 · B11 배율 미정의 · B12 제목 줄 id')
    import subprocess, shutil, zipfile, re, io, os as _os
    import lane_geometry as LG
    import lane_attr_consistency as LA
    import lane_screen_parity as LS
    import oox
    import safe_install as SI
    here = os.path.join(HERE, 'safe_install.py')
    src = os.path.join(fx_dir, 'p1.pptx')

    def rewrite(src_p, dst_p, part, fn, add=None):
        zi = zipfile.ZipFile(src_p); zo = zipfile.ZipFile(dst_p, 'w', zipfile.ZIP_DEFLATED)
        for n in zi.namelist():
            d = zi.read(n)
            if n == part:
                d = fn(d)
            zo.writestr(n, d)
        for n, d in (add or {}).items():
            zo.writestr(n, d)
        zo.close()

    def run(cand, dest, *extra):
        r = subprocess.run([sys.executable, here, cand, dest, *extra], capture_output=True, text=True)
        return r.returncode, r.stdout + r.stderr

    # ── S1: os.replace 직후 다른 손이 정본을 건드리면 → rc=3 + 이전 정본 복원 ──
    dest = os.path.join(fx_dir, 'r8_s1_dest.pptx'); shutil.copyfile(src, dest)
    prev = open(dest, 'rb').read()
    small = os.path.join(fx_dir, 'si_small.pptx')      # [2-b] 가 만든 3장 축소본
    real_replace = _os.replace
    hit = {'n': 0}
    def evil_replace(a, b):
        real_replace(a, b)
        if b == dest and hit['n'] == 0:          # 첫 교체(설치) 직후 한 번만 — 복원 교체는 건드리지 않는다
            hit['n'] += 1
            with open(b, 'ab') as g:
                g.write(b'corrupt')
    _os.replace = evil_replace
    try:
        import contextlib
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            rc = SI.main(['safe_install', small, dest, '--allow-shrink', '--why', 'test'])
    finally:
        _os.replace = real_replace
    after = open(dest, 'rb').read()
    ok('S1 사후검증 실패 → rc=%s(3) · 이전 정본 복원 %s' % (rc, after == prev)) if rc == 3 and after == prev \
        else ng('S1 rc=%r restored=%r\n%s' % (rc, after == prev, buf.getvalue()[-300:]))
    shutil.copyfile(src, dest)
    rc, out = run(small, dest, '--allow-shrink', '--why', 'ctrl')
    ok('S1 컨트롤 — 정상 축소 반영 rc=0') if rc == 0 else ng('S1 ctrl rc=%s\n%s' % (rc, out[-200:]))

    # ── A2: prstGeom 없는 합법 p:sp (python-pptx shape_type NotImplementedError) 는 결함이 아니다 ──
    noprst = os.path.join(fx_dir, 'r8_noprst.pptx')
    def _strip_prst(d):
        x = d.decode('utf-8')
        x2 = re.sub(r'<a:prstGeom\b.*?</a:prstGeom>', '', x, count=1, flags=re.S)
        x2 = x2.replace(' txBox="1"', '', 1)     # 자리표시자도 글상자도 아닌 «맨» p:sp — python-pptx 가 분류 못 하는 조합
        assert x2 != x, 'fixture: prstGeom 없음'
        return x2.encode('utf-8')
    rewrite(src, noprst, 'ppt/slides/slide1.xml', _strip_prst)
    try:
        from pptx import Presentation as _P
        sh0 = [s_ for s_ in _P(noprst).slides[0].shapes][0]
        try:
            sh0.shape_type; nie = False
        except NotImplementedError:
            nie = True
    except Exception as e:
        nie = None
    dest2 = os.path.join(fx_dir, 'r8_a2_dest.pptx'); shutil.copyfile(noprst, dest2)
    rc_c, out_c = run(noprst, dest2, '--dry-run')          # 후보가 그 도형을 품음
    rc_d, out_d = run(src, dest2, '--dry-run')             # 정본이 그 도형을 품음 — 교착이던 자리
    ok('A2 prstGeom 없는 도형(python-pptx NotImplementedError=%s) — 후보 rc=%s · 정본 rc=%s (둘 다 0)' % (nie, rc_c, rc_d)) \
        if nie and rc_c == 0 and rc_d == 0 else ng('A2 nie=%r cand=%s dest=%s\n%s' % (nie, rc_c, rc_d, (out_c + out_d)[-300:]))

    # ── A3: intended shapes 원소가 섞이면 «그 항목만» 오류, 레인은 산다 ──
    idx3, errs3 = LA._intent_index([{'axis': 'dash', 'slides': [1], 'shapes': ['A', 1], 'why': 'r'},
                                    {'axis': 'dash', 'slides': [1], 'shapes': ['B'], 'why': 'r'}])
    ok('A3 shapes=["A",1] → 오류 1 · 정상 항목은 색인됨 %s' % (dict(idx3),)) \
        if len(errs3) == 1 and ('dash', 1) in idx3 and len(idx3[('dash', 1)]) == 1 else ng('A3 errs=%r idx=%r' % (errs3, dict(idx3)))

    # ── A4: 런 경계 공백 · <a:br/> 는 크기 차이가 아니다 ──
    def _runs(name, x, runs):
        body = ''.join(('<a:br/>' if t == '\n' else '<a:r><a:rPr sz="%d"/><a:t>%s</a:t></a:r>' % (sz, t)) for t, sz in runs)
        return ('<p:sp><p:nvSpPr><p:cNvPr id="1" name="%s"/></p:nvSpPr><p:spPr><a:xfrm><a:off x="%d" y="914400"/>'
                '<a:ext cx="3657600" cy="914400"/></a:xfrm></p:spPr><p:txBody><a:p>%s</a:p></p:txBody></p:sp>' % (name, x, body))
    d = os.path.join(fx_dir, 'r8_ws.pptx')
    _mini_deck(d, [_runs('T', 914400, [('abc ', 2800), ('def gh', 3200)]), _runs('T', 914400, [('abc', 2800), (' def gh', 3200)]),
                   _runs('T', 914400, [('abc', 2800), ('\n', None), ('def', 2800)]), _runs('T', 914400, [('abc def', 2800)]),
                   _runs('T', 914400, [('abc ', 2800), ('def gh', 3600)])])         # 컨트롤: 같은 글자, 진짜 크기 갈림(32→36)
    S, sw = LA.load(d)
    e_all = list(LA.ax_echo(S, sw, {}))
    sp = [S[i][0]['spans'] for i in range(5)]
    ok('A4 경계 공백 %s=%s · br %s=%s · 컨트롤(진짜 갈림) echo 후보 %d' % (sp[0], sp[1], sp[2], sp[3], len(e_all))) \
        if sp[0] == sp[1] == ((4, 28.0), (6, 32.0)) and sp[2] == sp[3] == ((7, 28.0),) and sp[4] == ((4, 28.0), (6, 36.0)) and len(e_all) >= 1 and not any('None' in str(l) for l in e_all) \
        else ng('A4 spans=%r echo=%r' % (sp, e_all))

    # ── A5: 뒤집힘을 attrs:[flip] 로 면제 · 선언 없으면 후보 · 다른 속성만 선언하면 안 맞음 ──
    Sf = [{'s1': (0, 0, 100, 100, 't', '', None)}, {'s1': (0, 0, 100, 100, 't', 'H', None)}]
    l_none, _st, sup_none, err_none = LG.p1_lines(Sf, 200000)
    l_dec, _st, sup_dec, err_dec = LG.p1_lines(Sf, 200000, [{'slides': [1, 2], 'shapes': ['s1'], 'attrs': ['flip'], 'why': '반전 연출'}])
    l_wrong, _st, sup_w, err_w = LG.p1_lines(Sf, 200000, [{'slides': [1, 2], 'shapes': ['s1'], 'attrs': ['x'], 'why': '엉뚱'}])
    ok('A5 flip 면제 — 선언 없음 후보 %d · [flip] 선언 후보 %d/면제 %d/오류 %d · [x] 선언 후보 %d/죽은 선언 %d' % (len(l_none), len(l_dec), len(sup_dec), len(err_dec), len(l_wrong), len(err_w))) \
        if len(l_none) == 1 and len(l_dec) == 0 and len(sup_dec) == 1 and not err_dec and len(l_wrong) == 1 and len(err_w) == 1 \
        else ng('A5 none=%r dec=%r/%r/%r wrong=%r/%r' % (l_none, l_dec, sup_dec, err_dec, l_wrong, err_w))

    # ── B6: 빈 <mc:Choice/> 는 Fallback 이 아니다 ──
    alt_empty = ('<mc:AlternateContent xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006">'
                 '<mc:Choice Requires="x"/><mc:Fallback>%s</mc:Fallback></mc:AlternateContent>')
    d = os.path.join(fx_dir, 'r8_alt_empty.pptx'); _mini_deck(d, [alt_empty % _sp('FB', 0, 0, 100, 100, 'b')])
    n6 = [s_['name'] for s_ in oox.walk_slide(zipfile.ZipFile(d), 1)]
    ok('B6 빈 Choice → 도형 %s (Fallback 안 걸음)' % (n6,)) if n6 == [] else ng('B6 %r' % (n6,))

    # ── B7: 절대 Target(/ppt/slides/slide1.xml) — slide_order · safe_install 둘 다 ──
    absr = os.path.join(fx_dir, 'r8_abs.pptx')
    rewrite(src, absr, 'ppt/_rels/presentation.xml.rels', lambda b: b.replace(b'Target="slides/', b'Target="/ppt/slides/'))
    assert b'/ppt/slides/' in zipfile.ZipFile(absr).read('ppt/_rels/presentation.xml.rels')
    try:
        n7 = len(oox.slide_order(zipfile.ZipFile(absr))); e7 = None
    except Exception as e:
        n7, e7 = None, e
    dest7 = os.path.join(fx_dir, 'r8_b7_dest.pptx'); shutil.copyfile(src, dest7)
    rc7, out7 = run(absr, dest7, '--dry-run')
    ok('B7 절대 Target — slide_order %s장 · safe_install rc=%s' % (n7, rc7)) if n7 == 4 and rc7 == 0 else ng('B7 n=%r err=%r rc=%s\n%s' % (n7, e7, rc7, out7[-200:]))

    # ── B8: ppt/ 밖 부품의 끊긴 r:id 도 거부 ──
    cust = ('<?xml version="1.0"?><Properties xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
            '<x r:id="rIdNOPE"/></Properties>').encode()
    outside = os.path.join(fx_dir, 'r8_outside.pptx'); rewrite(src, outside, None, None, add={'docProps/custom.xml': cust})
    dest8 = os.path.join(fx_dir, 'r8_b8_dest.pptx'); shutil.copyfile(src, dest8)
    rc8, out8 = run(outside, dest8, '--dry-run')
    ok('B8 docProps/custom.xml 의 끊긴 r:id → 거부 rc=%s' % rc8) if rc8 == 1 and '끊긴 참조' in out8 else ng('B8 rc=%s\n%s' % (rc8, out8[-200:]))

    # ── B9: attrs 문자열 → 오류 ──
    idx9, err9 = LG._intent_index([{'slides': [1, 2], 'shapes': ['s1'], 'attrs': 'xy', 'why': '연출'}])
    ok('B9 attrs="xy" 문자열 → 오류 1 · 색인 0') if len(err9) == 1 and not idx9 else ng('B9 idx=%r err=%r' % (dict(idx9), err9))

    # ── B10: 루트 앞 주석 안의 태그 ──
    try:
        r10 = oox.parse_xml('<!-- <p:ghost/> --><p:sld xmlns:q="Q"><p:x/></p:sld>'); ok10 = oox.local(r10.tag) == 'sld'
    except Exception as e:
        ok10 = e
    ok('B10 주석 뒤 루트 파싱') if ok10 is True else ng('B10 %r' % (ok10,))

    # ── B11: ext 없는 flip 그룹 → geo_unmeasured · geometry 통계 unmeasured ──
    xf_noext = '<a:xfrm flipH="1"><a:off x="0" y="0"/><a:chOff x="0" y="0"/><a:chExt cx="1000" cy="1000"/></a:xfrm>'
    grp = '<p:grpSp><p:nvGrpSpPr><p:cNvPr id="9" name="g"/></p:nvGrpSpPr><p:grpSpPr>%s</p:grpSpPr>%s</p:grpSp>' % (xf_noext, _sp('c', 100, 0, 50, 50, 'x'))
    d = os.path.join(fx_dir, 'r8_noext.pptx'); _mini_deck(d, [grp, grp])
    w11 = oox.walk_slide(zipfile.ZipFile(d), 1)
    _l, st11, _s, _e = LG.p1_lines(LG.load_slides(d), 200000)
    ok('B11 ext 없는 그룹 → geo_unmeasured=%s · geometry stats unmeasured=%s (bound 0)' % (w11[0].get('geo_unmeasured'), st11.get('unmeasured'))) \
        if w11 and w11[0].get('geo_unmeasured') is True and st11.get('unmeasured') == 1 and not st11.get('bound') else ng('B11 w=%r st=%r' % (w11, st11))

    # ── B12: '·' 없는 제목 — id 는 제목 줄 한 줄 ──
    man = os.path.join(fx_dir, 'r8_man.md')
    open(man, 'w', encoding='utf-8').write('### u1 · 첫 단위\n🖥\n한 줄\n🗣 말\n### u2 제목에 점 없음\n🖥\n두 줄\n🗣 말\n')
    units = LS.manuscript_screens(man)
    ok('B12 단위 id %s (한 줄, 블록 전체 아님)' % ([u for u, _ in units],)) if len(units) == 2 and '\n' not in units[1][0] and units[1][0].startswith('u2') \
        else ng('B12 %r' % (units,))


def run_baseline_delta(fx_dir):
    print('\n[2] --baseline 델타 모드 — 편집 전/후 한 쌍')
    import lane_geometry as LG
    new, gone, st_b, st_c, _sup, _err = LG.delta(os.path.join(fx_dir, 'geo_base.pptx'),
                                                 os.path.join(fx_dir, 'geo_edited.pptx'), 200000, 63500)
    ok('델타 새 어긋남 정확히 1건') if len(new) == 1 else ng(f'델타 새 어긋남 {len(new)}건 (want 1)')
    ok('델타 사라진 어긋남 0건(깨끗한 기준본)') if len(gone) == 0 else ng(f'델타 사라진 어긋남 {len(gone)}건 (want 0)')
    cb, cc = st_b.get('bound', 0), st_c.get('bound', 0)
    ok(f'기준본 결박 {cb} > 0 · 현재본 결박 {cc} > 0') if cb > 0 and cc > 0 \
        else ng(f'기준본/현재본 결박 0 있음 — UNMEASURED (bound_b={cb}, bound_c={cc})')
    # scan(cfg, root) 래퍼로도 동일하게 도는지 확인 (preprep.py 가 실제로 부르는 경로)
    cfg = {'surfaces_by_id': {'built_deck': {'path': os.path.join(fx_dir, 'geo_edited.pptx')}},
           'geometry': {'baseline': os.path.join(fx_dir, 'geo_base.pptx')}}
    fP, nP = LG.scan(cfg, '.')
    ok('scan(cfg, root) 래퍼가 델타 모드로 도고 새 어긋남 1건을 notes 에 낸다') \
        if any('새 어긋남 1건' in n for n in nP) else ng(f'scan() 델타 출력 이상 — {nP}')


REAL_BASE = os.environ.get('PREPREP_REAL_CORPUS', '')  # 기본값 없음 — 다른 머신에서 거짓 SKIP 방지(SKIP != PASS)
REAL_TARGETS = [
    ('ifkakao26_slides_v1.3_pre-engine-strip_20260904_210857.pptx', 'R1', 40,
     '선두 줄이 «그러나»로 뒤집는데'),
    ('ifkakao26_slides_v1.3_pre-40p_20260904_213452.pptx', 'R2', 41,
     '«이 셋/세 가지»라 부르는데 번호가 없다'),
    ('ifkakao26_slides_v1.3_pre-38trim_20260904_210428.pptx', 'R4', 38,
     '화면 250자'),
    ('ifkakao26_slides_v1.3_pre-40p_20260904_213452.pptx', 'R5', 112,
     '29.2자/초'),
]


def run_real_corpus():
    print('\n[3] 실물 재현 (PREPREP_REAL_CORPUS 백업, 있을 때만) — 원장이 인용한 실사고 4+1건')
    if not os.path.isdir(REAL_BASE):
        sk(f'실물 코퍼스 미지정/미존재({REAL_BASE or "PREPREP_REAL_CORPUS unset"}) — SKIP, 통과 아님')
        return
    import lane_slide_relations as LSR
    import lane_geometry as LG
    for fname, code, want_page, want_sub in REAL_TARGETS:
        p = os.path.join(REAL_BASE, fname)
        if not os.path.exists(p):
            sk(f'{fname} 없음 — 재현 건너뜀')
            continue
        deck = LSR.Deck(p)
        F = LSR.analyze(deck)
        hit = [x for x in F if x[0] == code and abs(x[1] - want_page) <= 1 and want_sub in x[2]]
        ok(f'{code} 실물 재현 — {fname} 약 {want_page}p — {hit[0][2][:60] if hit else ""}') \
            if hit else ng(f'{code} 실물 미재현 — {fname}')

    # P1/P3 36p (보너스 확인 — 원장이 명시적으로 요구한 4건에는 없지만 신호 자체의 원적 사건)
    align36 = os.path.join(REAL_BASE, 'ifkakao26_slides_v1.3_pre-align36_222442.pptx')
    if os.path.exists(align36):
        lines, st, _sp, _er = LG.collect_lines(align36, 200000, 63500)
        hit_p1 = any('s5017' in l and '35000' in l and '35p' in l.replace(' ', '') for l in lines)
        hit_p3 = any('s5016' in l and 's5017' in l and '35000' in l for l in lines)
        # 🟥 결박을 좁힌 뒤에도 **원적 사건이 그대로 잡히는가**. 이 줄이 빨개지면 좁힌 것이
        #    오탐만이 아니라 진짜까지 잘라냈다는 뜻이다(다시 넓히든, 사각으로 이름을 붙이든).
        ok(f'P1 실물 재현 — 35p→36p s5017 x -35,000 (결박 {st.get("bound",0)}쌍)') \
            if hit_p1 else ng(f'P1 실물 미재현 — 🟥 결박 축소가 원적 사건을 잘랐는지 확인하라 ({st})')
        ok('P3 실물 재현 — 36p s5016→s5017 겹침 35,000') if hit_p3 else ng('P3 실물 미재현')
    else:
        sk('ifkakao26_slides_v1.3_pre-align36_222442.pptx 없음 — P1/P3 보너스 재현 건너뜀')


def main():
    try:
        import mk_slide_fixtures
    except ImportError as e:
        print(f'❌ python-pptx 또는 픽스처 모듈 부재 — UNMEASURED: {e}')
        return 2
    import tempfile
    fx_dir = tempfile.mkdtemp(prefix='preprep_lanes_rp_')
    mk_slide_fixtures.build_all(fx_dir)
    print(f'픽스처 생성: {fx_dir}')

    run_known_pairs(fx_dir)
    run_safe_install(fx_dir)
    run_codex_audit_regressions(fx_dir)
    run_r7_regressions(fx_dir)
    run_r8_regressions(fx_dir)
    run_baseline_delta(fx_dir)
    run_real_corpus()

    print(f'\n결과: {PASS} passed · {FAIL} failed · {SKIP} skipped (skip != pass)')
    return 1 if FAIL else 0


if __name__ == '__main__':
    sys.exit(main())
