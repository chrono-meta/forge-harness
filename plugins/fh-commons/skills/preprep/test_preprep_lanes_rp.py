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
    ok('A8 다문단 도형: 1단계만이면 짝없음 %d(오탐) · 2단계면 0 (join 1건)' % len(a1)) \
        if len(a1) == 4 and len(a2) == 0 and st2.get('joined') == 1 else ng('A8 a1=%d a2=%d joined=%r' % (len(a1), len(a2), st2.get('joined')))
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
    run_baseline_delta(fx_dir)
    run_real_corpus()

    print(f'\n결과: {PASS} passed · {FAIL} failed · {SKIP} skipped (skip != pass)')
    return 1 if FAIL else 0


if __name__ == '__main__':
    sys.exit(main())
