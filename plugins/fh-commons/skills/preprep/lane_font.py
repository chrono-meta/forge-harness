#!/usr/bin/env python3
"""L15 — 서체 일관성: 이 덱이 «자기 템플릿이 정한 서체»를 벗어난 자리를 찾는다 (2026-09-11 신설).

WHY: preprep 은 지금까지 **글자의 배치**(P1/P3 기하)와 **말의 정합**(L1·L5·L8·R1~R5)을 봤지,
**무슨 서체로 찍혔는지**는 어느 레인도 안 봤다. 그런데 발표 템플릿을 주는 조직은 거의 항상
서체를 규정하고(배포 템플릿이 테마·마스터에 그 서체를 박아 둔다), 서체 이탈은 렌더링에서만
드러나 **사람이 눈으로 훑기 전에는 안 보인다** — 정확히 기계가 대신해야 할 부류다.

🟥 **이 레인의 난점은 검출이 아니라 «상속과 저작의 분리»다.** 실측이 그것을 강제했다
(2026-09-11, 실제 발표 덱 120장 — 조직 배포 템플릿 기반):

    순진하게 세면          Helvetica Neue 85건  → 「서체 위반 85건」
    영역을 갈라 세면        그 85건은 전부 ppt/slideMasters/ 안에 있다
    공식 템플릿과 대조하면   가이드 v2.0 의 마스터에도 **정확히 같은 85건**이 있다 (해시 동일)

즉 **저자는 그 글자를 찍은 적이 없다.** 배포된 템플릿에 원래 들어 있던 것이고, 그걸 위반으로
세면 오탐률이 100% 인 레인이 된다(진짜 이탈은 그 덱에 6건뿐이었다 — 37p 코드 데모의 Roboto
Mono, 그리고 그건 «의도»였다). ⇒ 판별자는 **영역 + 템플릿 해시 대조**이지 서체 이름이 아니다.

판정 구조 (엄격한 순서):
    ① 영역 분리   slides/ = 저자가 찍은 것 · slideLayouts·slideMasters·theme = 템플릿 상속
    ② 템플릿 대조 `fonts.template` 이 선언돼 있으면 그 부품들의 해시를 맞춘다
                  · 동일 → 그 영역의 서체는 **상속분**, 판정 대상 아님 (노트로만)
                  · 다름 → **저자가 템플릿을 건드렸다** = 그건 진짜 판정 대상이다
    ③ 허용 집합   `fonts.allow` 선언 우선. 없으면 **템플릿 자신의 slides/ 분포에서 유도**한다
                  (「내 체크리스트가 아니라 덱 자신의 분포가 기준」 — attr 계열과 같은 규율)
    ④ 테마 참조   `+mn-lt`/`+mj-ea` 류는 테마를 타고 풀린다. 그 자체는 서체가 아니므로
                  **테마의 실제 서체**를 허용 집합에 대고 본다. 테마가 벗어나 있으면 그 참조
                  전부가 벗어난 것이고, 테마 한 곳만 지적한다(장마다 중복 지적하지 않는다)

🟥 **0 은 통과가 아니다.** 서체 토큰을 하나도 못 읽었으면 추출이 죽은 것이고 UNMEASURED 다.
   같은 이유로 «대조한 부품 수»를 항상 같이 낸다 — 0 이면 대조를 안 한 것이다.

🟥 **면제는 «선언»으로만 된다** (surfaces.yaml `fonts.intended`, 다른 레인과 같은 관례).
   코드 화면의 고정폭 서체처럼 «알고도 남긴 것»은 why 와 함께 적는다. 안 적으면 다음 감사자가
   그것을 다시 «발견»하고 «고친다» — 이 코퍼스가 2026-09-10 에 실제로 그렇게 고쳤다가
   운영자 지적으로 되돌렸다.

🟥 **이 레인이 구조적으로 못 보는 것**: ⓐ 이미지에 구워진 글자 ⓑ 폰트가 설치돼 있는지
   (파일은 이름만 적는다 — 없는 서체는 렌더러가 조용히 대체한다) ⓒ 같은 가족의 굵기 변형이
   실제로 존재하는지. 셋 다 **파일 밖**의 사실이라 여기서 0 으로 세지 않는다.
"""
import os
import re
import zipfile
import hashlib
import collections

# 테마 참조 토큰 — 서체 이름이 아니라 «테마를 보라»는 지시다
THEME_REF = re.compile(r'^\+(mn|mj)-(lt|ea|cs)$')

AREA_SLIDES = 'slides'
AREA_INHERIT = ('slideLayouts', 'slideMasters', 'theme')


# 🟥 **속성 순서를 가정하지 않는다 — 이 레인이 세 번 같은 자리에서 샜다.**
#    `<a:latin typeface="X"/>` 만 가정한 패턴은 `<a:latin pitchFamily="34" charset="0"
#    typeface="X"/>` 를 **통째로 놓친다**(실측 재현, cross-family R3-2 지목). OOXML 은 속성
#    순서를 강제하지 않고 PowerPoint 는 실제로 pitchFamily/charset 을 앞에 붙인다.
#    같은 부류가 `presentation.xml.rels`(Id↔Target 순서)에서도 났다 — 그래서 한 군데씩 깁지
#    않고 **태그를 먼저 잡고 속성은 그 안에서 따로 읽는** 형태로 통일한다.
_FONT_TAG = re.compile(r'<a:(latin|ea|cs)\b([^>]*?)/?>')
_ATTR = re.compile(r'(\w+)="([^"]*)"')


def font_refs(xml):
    """[(슬롯, 서체이름)] — 속성 순서와 무관하게 읽는다. typeface 가 없는 태그는 건너뛴다."""
    out = []
    for m in _FONT_TAG.finditer(xml):
        a = dict(_ATTR.findall(m.group(2)))
        tf = a.get('typeface')
        if tf:
            out.append((m.group(1), tf))
    return out


def font_names(xml):
    """서체 이름만 (슬롯 무시)."""
    return [t for _, t in font_refs(xml)]


_PART = re.compile(r'ppt/(slides|slideLayouts|slideMasters|theme)/[^/]+\.xml$')


def _parts(z):
    """{영역: {부품경로: sha256[:16]}}"""
    out = collections.defaultdict(dict)
    for n in z.namelist():
        m = _PART.match(n)
        if m:
            out[m.group(1)][n] = hashlib.sha256(z.read(n)).hexdigest()[:16]
    return out


def _typefaces(z, name):
    """한 부품이 쓰는 서체 이름들 (등장 순서 유지, 중복 포함)."""
    return font_names(z.read(name).decode('utf-8', 'replace'))


def theme_fonts(z):
    """테마가 정한 major/minor 서체 집합. 테마가 없으면 빈 집합."""
    got = set()
    for n in z.namelist():
        if re.match(r'ppt/theme/theme\d+\.xml$', n):
            x = z.read(n).decode('utf-8', 'replace')
            for tag in ('majorFont', 'minorFont'):
                m = re.search(r'<a:%s>.*?</a:%s>' % (tag, tag), x, re.S)
                if m:
                    # 🟥 `<a:font script="Hans" typeface="SimSun"/>` 류 **보조 스크립트 폴백은
                    #    제외**한다. 테마가 정한 «본 서체»는 latin/ea/cs 셋이고, script 폴백은
                    #    해당 문자가 없으면 렌더되지 않는다 — 넣으면 SimSun·Mangal 이 위반으로
                    #    뜬다(agy 3.8 지적 R2-4. 이 코퍼스엔 폴백이 0개라 재현은 안 됐고,
                    #    Office 기본 테마에는 흔하다 — 미재현을 부재로 읽지 않는다).
                    got |= {t for t in font_names(m.group(0))
                            if t and not THEME_REF.match(t)}
    return got


def _occurrences(xml, where):
    """한 부품 XML 에서 (서체, 슬롯, 텍스트, 출처) 를 뽑는다.

    🟥 **`<a:r>` 만 보면 새는 자리가 셋이다** (cross-family agy 지적 S2·S3, 2026-09-11):
      · `<a:fld>`   — 장 번호·바닥글·날짜. 자기 rPr 과 `<a:t>` 를 갖는데 런이 아니다
      · `defRPr`    — 텍스트 박스 전체를 선택해 서체를 바꾸면 **런에 안 남고 여기 남는다**.
                      실측: 이 코퍼스에 115건 있었다(전부 테마 참조라 무해했을 뿐이다)
      · `lstStyle`  — 목록 수준별 기본. defRPr 과 같은 경로로 잡힌다
    🟥 **`endParaRPr` 은 일부러 뺀다** — 빈 문단의 «끝 서식»이라 **렌더되는 글자가 없다**.
       실측으로 오탐을 냈다: 같은 문구인 49p/50p 가 endParaRPr 62pt 하나 때문에 «크기가
       달라졌다»로 떴다(2026-09-11). 있지도 않은 글자의 서체는 이탈이 아니다.
    """
    out = []
    # ① 런과 필드 — 찍힌 글자가 있다
    for tag in ('r', 'fld'):
        for m in re.finditer(r'<a:%s[ >].*?</a:%s>' % (tag, tag), xml, re.S):
            b = m.group(0)
            txt = re.sub(r'\s+', ' ', ''.join(re.findall(r'<a:t>([^<]*)</a:t>', b))).strip()
            # 🟥 글자가 없는 런은 건너뛴다 — 지우고 남은 찌꺼기 속성이라 렌더되지 않는다
            #    (agy 지적 A3). «해결이 불가능한 지적»은 지적이 아니라 소음이다.
            if not txt:
                continue
            for slot, tf in font_refs(b):
                out.append((tf, slot, txt, 'run' if tag == 'r' else 'field'))
    # ② 단락/목록 기본 서식 — 글자는 상속되므로 렌더된다
    # 🟥 비탐욕 `.*?(?:/>|</a:defRPr>)` 는 **첫 자식 self-closing 태그에서 끊긴다.**
    #    `<a:defRPr sz="1800"><a:solidFill><a:srgbClr val="0"/></a:solidFill>
    #     <a:latin typeface="Comic Sans MS"/></a:defRPr>` 에서 매치가
    #    `…<a:srgbClr val="0"/>` 까지만 잡혀 **서체를 조용히 버린다** — 실측 재현,
    #    fail-open 이다(cross-family agy 3.8 지적 R2-1). 자기닫힘과 여는-태그를 갈라 처리한다.
    for m in re.finditer(r'<a:defRPr\b[^>]*/>', xml):
        for slot, tf in font_refs(m.group(0)):
            out.append((tf, slot, '', 'para-default'))
    for m in re.finditer(r'<a:defRPr\b[^>]*(?<!/)>(.*?)</a:defRPr>', xml, re.S):
        for slot, tf in font_refs(m.group(1)):
            out.append((tf, slot, '', 'para-default'))
    return out


def slide_runs(z):
    """[(장 인덱스 1-base, 서체, 슬롯, 텍스트, 출처)] — slides/ 안에서 «명시된» 서체만."""
    try:
        pres = z.read('ppt/presentation.xml').decode('utf-8', 'replace')
        # 🟥 Id 와 Target 의 순서를 가정하지 않는다 — 가정하면 rels 가 통째로 빈 dict 가 되고
        #    장 순서가 파일명 순으로 조용히 대체돼 「N번째 장」이 어긋난다(R3-4).
        rels = {}
        for rm in re.finditer(r'<Relationship\b[^>]*/?>',
                              z.read('ppt/_rels/presentation.xml.rels').decode('utf-8', 'replace')):
            a = dict(_ATTR.findall(rm.group(0)))
            tgt = re.search(r'slides/slide(\d+)\.xml$', a.get('Target', ''))
            if a.get('Id') and tgt:
                rels[a['Id']] = tgt.group(1)
        lst = re.search(r'<p:sldIdLst>.*?</p:sldIdLst>', pres, re.S).group(0)
        # 🟥 속성 순서를 가정하지 않는다. 초판은 `id="\d+" r:id=` 라 **`r:id` 가 앞에 오면
        #    findall 이 빈 리스트를 내고 예외도 안 난다** → order=[] → rows=[] → 0건 PASS.
        #    파서가 조용히 아무것도 못 읽는 형태라 fail-open 이었다(agy 3.8 지적 R2-2).
        order = []
        for sm in re.finditer(r'<p:sldId\b[^>]*/?>', lst):
            rid = dict(_ATTR.findall(sm.group(0))).get('r:id')
            if rid and rid in rels:
                order.append(int(rels[rid]))
        if not order:
            raise ValueError('sldIdLst 에서 장 순서를 못 읽었다')
    except Exception:
        # 순서를 못 읽어도 «못 읽었다»로 끝내지 않는다 — 파일명 순으로라도 센다(번호는 근사).
        order = sorted(int(re.search(r'slide(\d+)', n).group(1)) for n in z.namelist()
                       if re.match(r'ppt/slides/slide\d+\.xml$', n))
    rows = []
    for i, sn in enumerate(order, 1):
        x = z.read('ppt/slides/slide%d.xml' % sn).decode('utf-8', 'replace')
        for tf, slot, txt, src in _occurrences(x, 'slide'):
            rows.append((i, tf, slot, txt, src))
    return rows, len(order)


def drifted_occurrences(z, drifted, zt=None):
    """템플릿에서 갈라진 상속 부품의 서체 — **저자가 손댄 것이므로 판정 대상이다.**

    🟥 이게 없으면 fail-open 이다(cross-family agy 지적 S1): 저자가 마스터를 열어 금지 서체를
    꽂아도 `slides/` 만 읽는 추출기는 못 보고, 해시 대조는 «갈라짐 1» 이라는 **노트**만 냈다.
    노트는 종료코드를 안 움직인다 ⇒ 0건 PASS 로 뚫린다.

    🟥 **그 부품의 «원래 서체»는 빼고 낸다.** 안 그러면 저자가 레이아웃에서 도형 크기만
    바꿔도 해시가 갈라지고, 그 부품에 원래 있던 템플릿 서체 전부가 «이탈»로 쏟아진다
    (agy 3.8 지적 R2-6). 갈라진 것은 부품이지 그 안의 모든 서체가 아니다 —
    판정 대상은 **저자가 그 부품에 새로 들인 서체**뿐이다."""
    rows = []
    for area, name in drifted:
        try:
            x = z.read(name).decode('utf-8', 'replace')
        except Exception:
            continue
        before = set()
        if zt is not None:
            try:
                before = set(font_names(re.sub(
                    r'<a:endParaRPr\b[^>]*(?:/>|>.*?</a:endParaRPr>)', '',
                    zt.read(name).decode('utf-8', 'replace'), flags=re.S)))
            except Exception:
                before = set()      # 템플릿에 없던 부품(신설) — 전부가 새 것이다
        # 🟥 렌더되지 않는 자리는 여기서도 안 센다 — `_occurrences` 만 엄격하고 여기는
        #    파일 전체를 훑으면, 빈 문단의 `endParaRPr` 하나로 갈라짐 오탐이 난다(R3-5).
        scanned = re.sub(r'<a:endParaRPr\b[^>]*(?:/>|>.*?</a:endParaRPr>)', '', x, flags=re.S)
        for slot, tf in font_refs(scanned):
            if not THEME_REF.match(tf) and tf not in before:
                rows.append((area, name, tf, slot))
    return rows


def _allow_from_template(zt):
    """템플릿의 slides/ 가 실제로 쓰는 서체 = 허용 집합. 「덱 자신의 분포가 기준」.

    🟥 **마스터·레이아웃은 일부러 안 넣는다.** 넣으면 상속된 잠재 기본값(이 코퍼스의
    Helvetica Neue)까지 «규정된 서체»가 되어 탐지력이 깎인다. 대신 `_template_own_fonts()`
    가 그 집합을 따로 들고, 거기 있는 서체의 지적은 **finding 이 아니라 노트로 강등**한다
    (cross-family agy 지적 A2 — 오탐이되, 허용으로 승격시킬 일은 아니다)."""
    got = set()
    for n in zt.namelist():
        if re.match(r'ppt/slides/slide\d+\.xml$', n):
            got |= {t for t in _typefaces(zt, n) if t and not THEME_REF.match(t)}
    return got | theme_fonts(zt)


def _template_own_fonts(zt):
    """템플릿의 마스터·레이아웃이 쓰는 서체 — «저자가 만든 것은 아닌» 이름들."""
    got = set()
    for n in zt.namelist():
        if re.match(r'ppt/(slideMasters|slideLayouts)/[^/]+\.xml$', n):
            got |= {t for t in _typefaces(zt, n) if t and not THEME_REF.match(t)}
    return got


def _norm(s):
    return re.sub(r'\s+', ' ', s).strip().lower()


def _allowed(tf, allow):
    """가족 단위 비교 — 「Brand Display」가 허용이면 「Brand Display Bold」도 허용이다.

    🟥 **한 방향뿐이다.** 초판은 `na.startswith(n + ' ')` 도 함께 봤는데, 그러면
    allow=["Arial Black"] 일 때 tf="Arial" 이 통과한다 — **구체적인 파생 하나만 허용했는데
    상위 가족 전체가 열리는** 역방향 누수다(cross-family agy 지적 B2, 실측 재현).
    허용은 «가족 → 변형» 으로만 내려간다."""
    n = _norm(tf)
    for a in allow:
        na = _norm(a)
        if n == na or n.startswith(na + ' '):
            return True
    return False


def _intended(cfg):
    """[(슬라이드집합|None, 서체목록|None, why)] — 선언된 면제."""
    out = []
    for e in ((cfg.get('fonts') or {}).get('intended') or []):
        out.append((set(e.get('slides') or []) or None,
                    list(e.get('fonts') or []) or None,
                    e.get('why') or '(사유 미기재)'))
    return out


def _exempt(slide, tf, rules):
    """면제도 **가족 단위**다 — `_allowed` 와 같은 규칙을 쓴다.

    🟥 초판은 정확 일치였다. 그러면 `intended: ["Roboto Mono"]` 를 선언해도
    `Roboto Mono Bold` 는 면제가 안 되어, **선언을 해놓고도 지적이 남는다**
    (agy 3.8 지적 R2-5). 허용과 면제가 같은 의미의 «가족»을 서로 다르게 읽으면
    선언하는 사람이 그 차이를 알 길이 없다."""
    for slides, fonts, why in rules:
        if slides is not None and slide not in slides:
            continue
        if fonts is not None and not _allowed(tf, fonts):
            continue
        return why
    return None


def scan(cfg, root):
    """preprep.py 진입점. (findings, notes)

    findings 는 **저자가 찍은 이탈**만 태운다. 상속분·선언된 면제는 노트로만 나간다."""
    deck_s = (cfg.get('surfaces_by_id') or {}).get('built_deck')
    if not deck_s:
        return [], ['L15 font : built_deck 미선언 — NOT_CONFIGURED (0 아님)']
    deck = os.path.normpath(os.path.join(root, os.path.expanduser(deck_s['path'])))
    if not os.path.exists(deck):
        return [], [f'L15 font : built_deck 실물 없음({deck}) — UNMEASURED (0 아님)']

    spec = cfg.get('fonts') or {}
    tpl_p = spec.get('template')
    allow = [a for a in (spec.get('allow') or []) if a]
    notes = []
    tpl_own = set()          # 템플릿의 마스터·레이아웃이 쓰는 서체 (finding 에 주석으로 실린다)
    ztpl = None              # 템플릿 zip — 갈라진 부품의 «원래 서체» 차분에 쓴다

    try:
        z = zipfile.ZipFile(deck)
        rows, nslides = slide_runs(z)
        parts = _parts(z)
        th = theme_fonts(z)
    except Exception as e:
        return [], [f'L15 font : 계기 오류({type(e).__name__}: {e}) — UNMEASURED (0 아님)']

    # ── ② 템플릿 대조 ──────────────────────────────────────────────────────────
    inherited_ok = set()          # 상속분으로 확인된 영역
    drifted = []                  # 템플릿에서 갈라진 부품
    if tpl_p:
        tpl = os.path.normpath(os.path.join(root, os.path.expanduser(tpl_p)))
        if not os.path.exists(tpl):
            notes.append(f'L15 font : template 실물 없음({tpl}) — 상속 판정 UNMEASURED (0 아님). '
                         f'상속 영역의 서체는 «판정 안 함»이 아니라 «못 쟀음»이다')
        else:
            try:
                zt = zipfile.ZipFile(tpl)
                ztpl = zt
                tp = _parts(zt)
                for area in AREA_INHERIT:
                    mine, theirs = parts.get(area, {}), tp.get(area, {})
                    if not mine:
                        continue
                    same = [k for k, v in mine.items() if theirs.get(k) == v]
                    diff = [k for k, v in mine.items() if k in theirs and theirs[k] != v]
                    new = [k for k in mine if k not in theirs]
                    if len(same) == len(mine):
                        inherited_ok.add(area)
                    drifted += [(area, k) for k in diff + new]
                    notes.append(f'L15 font : {area} 부품 {len(mine)} — 템플릿과 동일 {len(same)} · '
                                 f'갈라짐 {len(diff)} · 템플릿에 없음 {len(new)}')
                tpl_own = _template_own_fonts(zt)
                if not allow:
                    allow = sorted(_allow_from_template(zt))
                    notes.append('L15 font : allow 미선언 — 템플릿 자신의 분포에서 유도했다 '
                                 f'({len(allow)}가족: ' + ' · '.join(allow[:6])
                                 + (' …' if len(allow) > 6 else '') + ')')
            except Exception as e:
                notes.append(f'L15 font : template 읽기 오류({type(e).__name__}: {e}) — '
                             f'상속 판정 UNMEASURED (0 아님)')
    else:
        notes.append('L15 font : template 미선언 — 상속분을 저자 이탈과 **구분할 수 없다**. '
                     '이 상태의 판정은 마스터 상속 서체를 위반으로 셀 수 있다(실측 오탐 85건). '
                     'surfaces.yaml 에 `fonts.template` 로 배포 템플릿을 대라')

    if not allow:
        return [], notes + ['L15 font : 허용 서체 집합이 비었다(allow 미선언 + template 미선언) — '
                            'NOT_CONFIGURED (0 아님)']

    # ── ③ 판정 ────────────────────────────────────────────────────────────────
    rules = _intended(cfg)
    seen = collections.Counter()
    findings = []
    offenders = collections.defaultdict(list)     # 서체 → [(장, 슬롯, 텍스트, 출처)]
    exempted = collections.Counter()
    demoted = collections.Counter()               # 템플릿 자신이 쓰는 서체 (A2)
    for slide, tf, slot, txt, src in rows:
        seen[tf] += 1
        if THEME_REF.match(tf):
            continue
        if _allowed(tf, allow):
            continue
        why = _exempt(slide, tf, rules)
        if why:
            exempted[(tf, why)] += 1
            continue
        offenders[tf].append((slide, slot, txt, src))
        if tf in tpl_own:
            demoted[tf] += 1        # 억제가 아니라 «주석» 이다 — 아래 finding 문구에 실린다

    if not seen:
        return [], notes + [f'L15 font : slides/ {nslides}장에서 서체 토큰 0건 — UNMEASURED '
                            f'(0 아님. 추출이 죽어도 0 이 나온다)']

    # 테마가 허용 밖이면 장마다 지적하지 않고 테마 한 곳만 — 참조는 전부 거기서 온다
    # 🟥 테마 이탈도 `fonts.intended` 를 존중한다 — 런과 갈라짐은 면제를 보는데 테마만
    #    안 보면, 같은 선언이 자리에 따라 먹기도 하고 안 먹기도 한다(R3-3).
    #    슬라이드 번호가 없는 자리이므로 «슬라이드 무관» 선언(slides 미지정)만 적용된다.
    bad_theme = sorted(t for t in th
                       if not _allowed(t, allow) and not _exempt(None, t, rules))
    if bad_theme and 'theme' not in inherited_ok:
        findings.append(('built_deck', 'font-theme', 'ppt/theme',
                         ' · '.join(bad_theme),
                         '테마 서체가 허용 집합 밖이다 — `+mn-*`/`+mj-*` 참조가 전부 이걸 탄다'))

    # 🟥 갈라진 상속 부품의 서체 — 저자가 템플릿을 손댄 것이므로 **판정 대상**이다(S1).
    #    이게 없으면 「마스터를 열어 금지 서체를 꽂는」 경로가 통째로 fail-open 이었다.
    if drifted:
        dr = drifted_occurrences(z, drifted, ztpl)
        dbad = collections.defaultdict(set)
        for area, name, tf, slot in dr:
            if not _allowed(tf, allow) and not _exempt(0, tf, rules):
                dbad[tf].add(name.split('/')[-1])
        for tf, names in sorted(dbad.items()):
            findings.append(('built_deck', 'font-inherited-drift',
                             ' · '.join(sorted(names)[:4]), tf,
                             '템플릿에서 **갈라진** 상속 부품이 허용 밖 서체를 쓴다 — '
                             '상속분이 아니라 저자가 손댄 것이므로 판정한다'))

    for tf, hits in sorted(offenders.items(), key=lambda kv: -len(kv[1])):
        pages = sorted({p for p, _, _, _ in hits})
        slots = sorted({sl for _, sl, _, _ in hits})
        srcs = sorted({sc for _, _, _, sc in hits})
        samp = next((t for _, _, t, _ in hits if t), '')
        findings.append(('built_deck', 'font', 'slides ' + ','.join(str(p) for p in pages[:8])
                         + (' …' if len(pages) > 8 else ''),
                         tf,
                         f'허용 집합 밖 서체 {len(hits)}회 / {len(pages)}장 · 슬롯 {"/".join(slots)}'
                         + f' · 출처 {"/".join(srcs)}'
                         + (' · ⓘ 이 이름은 **템플릿 자신의 마스터/레이아웃에도 있다**'
                            '(Office 기본값일 수 있다 — 그래도 «규정된 본문 서체»는 아니므로 지적한다)'
                            if tf in tpl_own else '')
                         + (f' · 예: «{samp[:34]}»' if samp else '')
                         + ' — 🟥 슬롯이 `ea`/`cs` 뿐이면 그 문자가 없을 때 렌더되지 않을 수 있다'
                           '(사람이 판정한다). 의도라면 `fonts.intended` 에 why 와 함께 선언해라'))

    notes.append(f'L15 font : slides/ {nslides}장 · 명시 서체 {len(rows)}회 · 서체 {len(seen)}종 · '
                 f'허용 {len(allow)}가족 · 이탈 {len(offenders)}종 · 선언 면제 {sum(exempted.values())}회 · '
                 f'그중 템플릿 자신도 쓰는 이름 {sum(demoted.values())}회'
                 + ('' if rows else ' — 🟥 0 이면 UNMEASURED, 「이탈 없음」이 아니다'))
    if inherited_ok:
        notes.append('L15 font : 상속 확인(템플릿과 해시 동일) — ' + ' · '.join(sorted(inherited_ok))
                     + ' 의 서체는 저자 산물이 아니므로 판정하지 않는다')
    for (tf, why), c in exempted.most_common():
        notes.append(f'   면제됨 {tf} ({c}회) — {why}')
    for tf, c in demoted.most_common():
        notes.append(f'   ⓘ {tf} ({c}회) — 템플릿 자신의 마스터/레이아웃에도 있는 이름이다. '
                     f'🟥 **억제하지 않는다**: 1라운드에서 이것을 노트로 «강등»했다가 2라운드가 '
                     f'fail-open 으로 지목했다 — 템플릿 레이아웃은 쓰이지도 않는 자리에 Office '
                     f'기본값(Arial·Calibri)을 흔히 들고 있어서, 강등하면 저자가 그 이름으로 '
                     f'본문을 찍어도 종료코드가 안 움직인다. 지적은 남기고 맥락만 붙인다')
    for area, k in drifted[:8]:
        notes.append(f'   🟥 템플릿에서 갈라진 부품: {k} — 여기 서체는 **저자 책임**이다')
    return findings, notes
