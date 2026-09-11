#!/usr/bin/env python3
"""P4 attr-consistency — **덱 자신의 분포가 판정 기준이다.**

## 왜 이 레인이 생겼나 (2026-09-10, 실사고에서 역산)

「120장 전수 육안 검수를 했다」고 보고했는데 운영자가 *"전체적으로 제대로 본 게 맞는지 심히
의심된다"* 고 했고, **측정이 운영자 쪽이 맞다는 것을 보였다** — 그 뒤 이 방식으로 스캔하자
눈으로도 운영자 지적으로도 안 나온 결함이 **5건** 나왔다:

    s54  같은 장 안에서 같은 종류 점선이 1.0pt 와 3.0pt
    s58·59  노란 점선 박스의 위/아래 여백이 0.55" 와 1.20"
    s59  좌우 대칭 한 쌍이 30pt ↔ 32pt
    s70  「반박」 32pt ↔ 거울 자리 「나온 것」 28pt
    s29  열 제목 28↔32 · 1행 32↔26

🟥 **원인은 성실함이 아니라 «누가 채점표를 썼나»였다.** 나는 내가 만든 체크리스트로 나를
채점했고, 그러면 내가 안 적은 축은 구조적으로 안 보인다. ⇒ 이 레인은 채점표를 **저자에게서
덱 자신에게** 옮긴다: 임계를 코드에 박지 않고, **같은 역할의 도형들이 실제로 무슨 값을 쓰고
있는가**를 덱에서 뽑아 그 안의 «혼자 다른 것»만 낸다.

## 형태 — 축 넷이 전부 같은 한 문장이다

    «덱 자신이 정의하는 역할 키»로 묶고 → 그 무리 안에서 «한 속성»이 갈리는 것을 낸다

      dash    키=(장, 점선 종류)          속성=선 굵기      「같은 점선인데 굵기가 다르다」
      algn    키=(장, 폭, y)              속성=정렬 방식    「같은 줄인데 정렬이 다르다」
      mirror  키=(장, y, 화면 중심 거울)  속성=글자 크기    「좌우 대칭인데 크기가 다르다」
      echo    키=같은 문장(덱 전체)       속성=글자 크기·x  「같은 말인데 매번 다르게 생겼다」

축을 늘리는 것이 **코드가 아니라 표 한 줄**이 되도록 이 모양으로 짰다. `echo` 는 나머지 셋과
달리 **장을 가로지르는** 키를 쓴다 — 같은 문장이 여러 장에 나올 때 크기·자리가 갈리는가.
(실측: 방법론 이름 (a)(b)(c) 셋이 8장에 걸쳐 **네 가지 배치**로 나온다.)

## 🟥 정직한 한계 — 인용 전에 읽어라

- **이 레인은 «다르다»만 본다. «틀렸다»는 안 본다.** 크기 대비가 강조를 나르는 자리는 정상이고
  (실측: s6/s7 의 44↔32pt 는 빌드 강조 교체다), 그건 `attr_consistency.intended` 로 **선언**한다 —
  기계는 «선언되었나»만 보고 «옳은가»는 안 본다(CLAUDE.md §Mechanization Boundary).
- **advisory 고정.** 오탐의 최저비용 무마가 «다른 쪽을 같이 맞춰 버리는 것»이라, 종료코드에
  태우면 덱을 평평하게 미는 압력이 된다. 후보를 내고 **판정은 사람이 한다.**
- **정렬·거울 축은 키가 엄격해서(정확히 같은 폭·같은 y) 못 보는 자리가 많다.** 한 픽셀 어긋난
  «같은 줄»은 이 레인에 안 잡힌다. 좁아진 것이지 닫힌 게 아니다.
- **크기 축은 명시 `sz` 만 읽는다.** 플레이스홀더/테마에서 물려받는 크기는 XML 에 안 적히므로
  **UNMEASURED 다, 「같다」가 아니다.** 그런 도형은 통째로 뺀다.
- **n=1 코퍼스(120장 한국어 덱)에서 벼려졌다.** 다른 덱에 옮기면 거울 허용 오차와
  `min_echo_chars` 를 자기 분포에서 다시 재라.
"""
import zipfile, re, os, collections, html

EMU_IN = 914400.0
EMU_PT = 12700.0
AXES = ('dash', 'algn', 'mirror', 'echo')


# ── 추출 ─────────────────────────────────────────────────────────────────────

def _slide_order(z):
    # 🟥 속성 순서에 기대지 않는다 — `<p:sldId r:id="rId1" id="256"/>` 도 실물이다(codex 감사 09-11).
    #    Id/Target 도 각각 뽑는다. 못 푸는 r:id 는 조용히 빠지지 않고 KeyError 로 올라간다.
    rels = {}
    for tag in re.findall(r'<Relationship\b[^>]*>', z.read('ppt/_rels/presentation.xml.rels').decode('utf-8')):
        mid = re.search(r'\bId="([^"]+)"', tag); mt = re.search(r'\bTarget="slides/slide(\d+)\.xml"', tag)
        if mid and mt:
            rels[mid.group(1)] = mt.group(1)
    lst = re.search(r'<p:sldIdLst\b[^>]*>(.*?)</p:sldIdLst>',
                    z.read('ppt/presentation.xml').decode('utf-8'), re.S).group(1)
    return [int(rels[r]) for r in re.findall(r'<p:sldId\b[^>]*\br:id="([^"]+)"', lst)]


def _xfrm(b):
    """(x, y, cx, cy) — <a:off>/<a:ext> 속성 순서에 기대지 않는다(R4 A5). 없으면 None."""
    off = re.search(r'<a:off\b[^>]*>', b); ext = re.search(r'<a:ext\b[^>]*>', b)
    if not (off and ext):
        return None
    try:
        return tuple(int(re.search(r'\b%s="(-?\d+)"' % k, tag).group(1))
                     for k, tag in (('x', off.group(0)), ('y', off.group(0)), ('cx', ext.group(0)), ('cy', ext.group(0))))
    except AttributeError:
        return None


def _slide_size_in(z):
    tag = re.search(r'<p:sldSz\b[^>]*>', z.read('ppt/presentation.xml').decode('utf-8'))   # R5 A4: 속성 순서 무관
    cx = re.search(r'\bcx="(\d+)"', tag.group(0)) if tag else None
    cy = re.search(r'\bcy="(\d+)"', tag.group(0)) if tag else None
    return (int(cx.group(1)) / EMU_IN, int(cy.group(1)) / EMU_IN) if (cx and cy) else (13.333, 7.5)


def _shapes(z, sn):
    """한 장의 도형 전부. 🟥 lane_geometry.shapes() 와 달리 **이름 중복도 버리지 않는다** —
    이 레인은 «같은 이름을 짝지어 대조»하는 게 아니라 «한 장 안의 분포»를 보기 때문이다."""
    x = z.read('ppt/slides/slide%d.xml' % sn).decode('utf-8')
    out = []
    for m in re.finditer(r'<p:(sp|cxnSp|pic)\b[^>]*>.*?</p:\1>', x, re.S):   # R3 A6
        b = m.group(0)
        nm = re.search(r'name="([^"]*)"', b)
        o = _xfrm(b)   # R4 A5: 속성 순서 무관
        if not (nm and o):
            continue
        ln = re.search(r'<a:ln([^>]*)>(.*?)</a:ln>', b, re.S)
        lnw = None
        if ln:
            w = re.search(r'\sw="(\d+)"', ln.group(1))
            if w:
                lnw = round(int(w.group(1)) / EMU_PT, 2)
        dash = re.search(r'prstDash val="([^"]+)"', ln.group(2)) if ln else None
        # 🟥 눈에 보이는 런의 크기만 — endParaRPr(문단 끝 메타)는 화면에 없다. 그리고 2850 은 28 이 아니라
        #    28.5 다: 정수 나눗셈이 28 vs 28.5 를 같다고 봤다(codex 09-11).
        b_vis = re.sub(r'<a:endParaRPr\b[^>]*/>|<a:endParaRPr\b.*?</a:endParaRPr>', '', b, flags=re.S)
        # R2 A9: 순서·중복을 보존한다 — 좌 28/32 ↔ 우 32/28 을 «같은 집합» 으로 접지 않는다
        szs = tuple(int(v) / 100 for v in re.findall(r'<a:rPr\b[^>]*\bsz="(\d+)"', b_vis))
        # R3 A10: 크기는 «글자 구간» 에 붙는다 — 런 단위 튜플은 AB@28+CD@28 을 ABCD@28 과 다르게(오탐),
        #    AB@28+CD@32 를 A@28+BCD@32 와 같게(미탐) 읽었다. 인접 같은 크기 런을 합친 (글자수, 크기) 구간으로.
        spans = []
        for rm in re.finditer(r'<a:(?:r|fld)\b[^>]*>(.*?)</a:(?:r|fld)>', b_vis, re.S):   # R4 A4: 필드 런도 글자다
            rb = rm.group(1)
            szm = re.search(r'<a:rPr\b[^>]*\bsz="(\d+)"', rb)
            sz = int(szm.group(1)) / 100 if szm else None
            ln_ = len(html.unescape(''.join(re.findall(r'<a:t\b[^>]*>([^<]*)</a:t>', rb))))
            if ln_ == 0:
                continue
            if spans and spans[-1][1] == sz:
                spans[-1] = (spans[-1][0] + ln_, sz)
            else:
                spans.append((ln_, sz))
        spans = tuple(spans)
        out.append(dict(
            slide=sn, name=nm.group(1),
            x=o[0] / EMU_IN, y=o[1] / EMU_IN,
            w=o[2] / EMU_IN, h=o[3] / EMU_IN,
            szs=szs,                                  # () 이면 명시 크기 없음 → UNMEASURED
            # 문단 정렬은 <a:pPr algn> 뿐이다 — <a:ln algn="ctr"> 는 선의 정렬이라 다른 것(codex 09-11)
            # R3 A11: 문단마다 자리를 남긴다 — 정렬이 없는 문단은 '(기본)' 슬롯(있는 것만 모으면 위치가 지워진다)
            algn=tuple((re.search(r'<a:pPr\b[^>]*\balgn="([^"]+)"', pm) or [None, '(기본)'])[1]
                       for pm in re.findall(r'<a:p\b[^>]*>.*?</a:p>', b, re.S)) or ('(기본)',),
            spans=spans,
            lnw=lnw, dash=dash.group(1) if dash else None,
            # R2 A8: 런 경계는 글자가 아니다 — 문단 안 런은 '' 로, 문단 사이만 ' ' 로 잇는다
            text=re.sub(r'\s+', ' ', ' '.join(
                html.unescape(''.join(re.findall(r'<a:t\b[^>]*>([^<]*)</a:t>', pm))) for pm in re.findall(r'<a:p\b[^>]*>.*?</a:p>', b, re.S)
            )).strip()))   # R3 A12: &amp; 와 &#38; 는 같은 글자
    return out


def load(path):
    z = zipfile.ZipFile(path)
    order = _slide_order(z)
    sw, _sh = _slide_size_in(z)
    S = [_shapes(z, sn) for sn in order]
    # 🟥 «몇 장» 은 발표 순서(위치)지 파일 번호가 아니다 — slide9.xml 이 1번째면 1p 다(codex 09-11).
    #    echo 축과 면제 조회가 a['slide'] 를 쓰므로 여기서 위치로 바꾼다.
    for pos, sh in enumerate(S, 1):
        for sp in sh:
            sp['slide'] = pos
    return S, sw


# ── 면제 채널 (P1 과 같은 규율: 선언되었나만 본다 · 사유 필수 · 조용히 안 삼킨다) ──────

def _intent_index(intended):
    idx, errs = collections.defaultdict(list), []
    for n, e in enumerate(intended or [], 1):
        if not isinstance(e, dict):
            errs.append(f'attr_consistency.intended[{n}] : 매핑이 아니다 — 면제 안 함')
            continue
        ax, sl = e.get('axis'), e.get('slides') or []
        why = (e.get('why') or '').strip()
        if ax not in AXES:
            errs.append(f'attr_consistency.intended[{n}] : axis 가 {AXES} 중 하나여야 한다 — 면제 안 함')
            continue
        if not sl:
            errs.append(f'attr_consistency.intended[{n}] : slides 가 비었다 — 면제 안 함')
            continue
        if not isinstance(sl, list) or (e.get('shapes') is not None and not isinstance(e.get('shapes'), list)):
            errs.append(f'attr_consistency.intended[{n}] : slides·shapes 는 목록이어야 한다 (문자열 "ab" 는 a·b 로 읽힌다) — 면제 안 함')   # R3 A9
            continue
        if not all(isinstance(v, int) and not isinstance(v, bool) for v in sl):
            errs.append(f'attr_consistency.intended[{n}] : slides 원소는 정수여야 한다 (받은 값 {sl!r} — 1.9·true 는 1 이 아니다) — 면제 안 함')   # R4 A7
            continue
        if not why:
            errs.append(f'attr_consistency.intended[{n}] : 🟥 why 가 비었다 — 사유 없는 면제는 오류다')
            continue
        for s in sl:
            idx[(ax, int(s))].append((tuple(sorted(e.get('shapes') or [])), why, n))
    return idx, errs


AMBIG = '\u2205'   # «같은 장 안에 같은 이름 둘» — 선언으로 못 가르는 표식(R5 A6). 어떤 선언과도 안 맞는다.


def _mark_ambig(names_by_slide):
    """[(slide, name) …] → 이름 목록. 한 장 안에서 이름이 겹치면 AMBIG 를 덧붙여 면제를 막는다."""
    seen = collections.Counter(names_by_slide)
    names = [n for _s, n in names_by_slide]
    if any(c > 1 for c in seen.values()):
        names.append(AMBIG)
    return names


def _why_all(idx, axis, slide, names):
    """이 장·축·도형 집합에 걸리는 «모든» 선언 [(why, n) …]. R3 B14: 첫 선언만 고르면 순서 의존이 된다.
    R5 A6: 같은 이름이 둘이면 «어느 것» 인지 선언으로 못 가른다 — 면제 불가(집합화가 셋째 도형을 지웠다)."""
    if AMBIG in names:
        return []
    got = sorted(set(names))
    return [(why, n) for want, why, n in idx.get((axis, int(slide)), []) if not want or list(want) == got]


def _why(idx, axis, slide, names):
    """면제는 «축 + 장 + 도형 집합»에 걸린다. `shapes` 를 안 적으면 그 장의 그 축 전체."""
    r = _why_all(idx, axis, slide, names)
    return r[0] if r else None


# ── 축 넷 ────────────────────────────────────────────────────────────────────

def ax_dash(S, sw, cfg):
    """같은 장 안에서 «같은 종류 점선»의 굵기가 갈리는가."""
    for sn, sh in enumerate(S, 1):
        g = collections.defaultdict(dict)
        for a in sh:
            if a['dash'] and a['lnw'] is not None:
                g[a['dash']].setdefault(a['lnw'], []).append(a['name'])
        for d, byw in g.items():
            if len(byw) > 1:
                detail = ' ↔ '.join(f"{w}pt({','.join(n[:10] for n in ns[:2])})"
                                    for w, ns in sorted(byw.items()))
                yield sn, _mark_ambig([(sn, n) for ns in byw.values() for n in ns]), \
                    f"{sn:>3}p [dash]   «{d}» 굵기가 갈린다 — {detail}"


def ax_algn(S, sw, cfg):
    """같은 장에서 «같은 폭 · 같은 y»(= 한 줄)인데 정렬 방식이 갈리는가."""
    for sn, sh in enumerate(S, 1):
        rows = collections.defaultdict(list)
        for a in sh:
            if a['text']:                      # 글자 있는 도형만이 «정렬»을 가진다 — 크기가 상속이어도 정렬은 있다
                rows[(round(a['w'], 2), round(a['y'], 1))].append(a)
        for (w, y), v in rows.items():
            if len(v) > 1 and len({a['algn'] for a in v}) > 1:
                detail = ' · '.join(f"{a['name'][:12]}={'/'.join(a['algn'])}" for a in v)
                yield sn, _mark_ambig([(sn, a['name']) for a in v]), \
                    f"{sn:>3}p [algn]   폭 {w}\" y {y}\" 한 줄인데 정렬이 갈린다 — {detail}"


def _size_seq(spans):
    return tuple(sz for _n, sz in spans)


def ax_mirror(S, sw, cfg):
    """좌우 대칭 쌍(같은 y · 화면 중심 기준 거울)의 글자 크기가 갈리는가."""
    tol = float(cfg.get('mirror_tol_in', 0.4))
    cx0 = sw / 2.0
    for sn, sh in enumerate(S, 1):
        A = [a for a in sh if a['szs'] and a['w'] < sw * 0.9]
        for i, a in enumerate(A):
            for b in A[i + 1:]:
                if abs(a['y'] - b['y']) > 0.05:
                    continue
                ca, cb = a['x'] + a['w'] / 2, b['x'] + b['w'] / 2
                if abs((ca - cx0) + (cb - cx0)) > tol:      # 거울 자리인가
                    continue
                if abs(ca - cb) < 1.0:                      # 너무 붙어 있으면 쌍이 아니다
                    continue
                # R4 B8: 거울 쌍은 글자가 다른 게 정상이라 «글자 수» 는 비교 대상이 아니다 — 크기 «순열» 만.
                # R5 A5: 단, 글자가 «같으면» 구간 전체를 비교한다(AB@28+CD@32 vs A@28+BCD@32 — B 가 커졌다)
                differs = (a['spans'] != b['spans']) if a['text'] == b['text'] else (_size_seq(a['spans']) != _size_seq(b['spans']))
                if differs:
                    yield sn, _mark_ambig([(sn, a['name']), (sn, b['name'])]), (
                        f"{sn:>3}p [mirror] 좌우 대칭인데 크기가 갈린다 — "
                        f"{a['name'][:12]} {'/'.join(map(str, a['szs']))}pt «{a['text'][:14]}» ↔ "
                        f"{b['name'][:12]} {'/'.join(map(str, b['szs']))}pt «{b['text'][:14]}»")


def ax_echo(S, sw, cfg):
    """**장을 가로지르는 축** — 같은 문장이 여러 장에서 다른 크기·다른 x 로 나오는가.

    🟥 «같은 말을 할 때 같은 자리에 있는가»는 넘길 때만 보이고 한 장짜리 렌더에는 구조적으로
       안 나타난다(SKILL §방법론 ⓑ). 실측: 방법론 이름 셋이 8장에 네 가지 배치로 나왔다."""
    mn = int(cfg.get('min_echo_chars', 8))
    byt = collections.defaultdict(list)
    for sh in S:
        for a in sh:
            t = a['text']
            if a['szs'] and len(t) >= mn:
                byt[t].append(a)
    for t, v in sorted(byt.items()):
        slides = sorted({a['slide'] for a in v})
        if len(slides) < 2:
            continue
        szset = {a['spans'] for a in v}   # R3 A10: 구간 단위
        xset = {round(a['x'], 1) for a in v}
        if len(szset) < 2 and len(xset) < 2:
            continue
        what = []
        if len(szset) > 1:
            what.append('크기 ' + ' ↔ '.join('+'.join(f'{n_}자@{sz}pt' for n_, sz in s) for s in sorted(szset, key=str)))
        if len(xset) > 1:
            what.append('x ' + ' ↔ '.join(f'{x}"' for x in sorted(xset)))
        yield tuple(slides), _mark_ambig([(a['slide'], a['name']) for a in v]), (   # R2 A7 · R5 A6(장 안 중복만 모호)
            f"{'·'.join(str(s) for s in slides[:6])}p [echo]   «{t[:30]}» 가 "
            f"{len(slides)}장에서 갈린다 — {' · '.join(what)}")


AXIS_FN = {'dash': ax_dash, 'algn': ax_algn, 'mirror': ax_mirror, 'echo': ax_echo}


# ── 진입점 ───────────────────────────────────────────────────────────────────

def collect(path, cfg):
    """(lines, suppressed, errors, stats)"""
    S, sw = load(path)
    idx, errors = _intent_index(cfg.get('intended'))
    want = [a for a in (cfg.get('axes') or AXES) if a in AXIS_FN]
    unknown = [a for a in (cfg.get('axes') or []) if a not in AXIS_FN]
    errors += [f'attr_consistency.axes : 모르는 축 «{a}» — 무시 (있는 축: {AXES})' for a in unknown]
    lines, suppressed = [], []
    stats = collections.Counter()
    # 명시 크기가 없는 도형은 크기 축에서 UNMEASURED — 0 으로 접지 않고 센다
    stats['shapes'] = sum(len(sh) for sh in S)
    stats['sized'] = sum(1 for sh in S for a in sh if a['szs'])
    hits = collections.Counter()
    for ax in want:
        for slide, names, line in AXIS_FN[ax](S, sw, cfg):
            slides_all = list(slide) if isinstance(slide, tuple) else [slide]
            # 그룹이 여러 장에 걸치면(echo) 전부 «같은 선언 n» 에 걸려야 면제 — R3 B14: 장마다 첫 선언을 고르지 말고
            # 장 전체에 공통인 n 을 찾는다(부분 선언이 완전 선언을 가리지 않게)
            per = [dict((n_, w_) for w_, n_ in _why_all(idx, ax, sl_, names)) for sl_ in slides_all]
            common = set(per[0]) if per else set()
            for d_ in per[1:]:
                common &= set(d_)
            hit = (per[0][min(common)], min(common)) if common else None
            if hit is not None:
                suppressed.append(line + f'   ← 선언: {hit[0]}')
                stats['suppressed'] += 1
                hits[hit[1]] += 1
            else:
                lines.append(line)
                stats[ax] += 1
    # 🟥 죽은 선언 보고 — 아무 후보도 안 거는 intended 항목(덱 세션 실측 09-11: 유령 후보에 붙은 why)
    for n in sorted({n for v in idx.values() for _w, _y, n in v}):
        if hits.get(n, 0) == 0:
            errors.append(f'attr_consistency.intended[{n}] : 🟥 죽은 선언 — 이 덱에서 아무 후보도 면제하지 않는다. 지우거나 고쳐라')
            stats['dead_intended'] += 1
    return lines, suppressed, errors, dict(stats)


def _resolve(root, p):
    return os.path.normpath(os.path.join(root, os.path.expanduser(p)))


def scan(cfg, root):
    """preprep.py 가 부르는 레인 진입점. 🟥 **advisory 고정** — findings 를 안 낸다."""
    deck_s = (cfg.get('surfaces_by_id') or {}).get('built_deck')
    if not deck_s:
        return [], ['P4 attr-consistency : built_deck 미선언 — NOT_CONFIGURED (0 아님)']
    deck = _resolve(root, deck_s['path'])
    if not os.path.exists(deck):
        return [], [f'P4 attr-consistency : built_deck 실물 없음({deck}) — UNMEASURED (0 아님)']
    spec = cfg.get('attr_consistency') or {}
    try:
        lines, sup, errs, st = collect(deck, spec)
    except Exception as e:
        return [], [f'P4 attr-consistency : 계기 오류({type(e).__name__}: {e}) — UNMEASURED (0 아님)']
    per = ' · '.join(f'{a} {st.get(a, 0)}' for a in AXES if a in (spec.get('axes') or AXES))
    notes = [f'P4 attr-consistency : 후보 {len(lines)}건 ({per}) — 🟥 advisory, '
             f'«다르다»지 «틀렸다»가 아니다. 판정은 사람이 한다',
             f'   대상 도형 {st.get("shapes", 0)}개 중 명시 크기 있는 것 {st.get("sized", 0)}개 '
             f'— 나머지는 크기 축에서 UNMEASURED (0 아님)']
    notes += ['   ' + l for l in lines]
    notes += ['   🟥 ' + e for e in errs]
    notes += ['   ~ (면제)' + l for l in sup]
    if sup:
        notes.append(f'   ~ 선언된 것 {len(sup)}건을 면제했다 — 「없다」가 아니라 「알고 남겼다」')
    return [], notes


if __name__ == '__main__':
    import sys, json
    p = sys.argv[1]
    conf = json.loads(sys.argv[2]) if len(sys.argv) > 2 else {}
    L, SU, ER, ST = collect(p, conf)
    print(f'후보 {len(L)}건 · 면제 {len(SU)} · 선언오류 {len(ER)} · {ST}')
    for l in L:
        print('  ', l)
    for e in ER:
        print('  🟥', e)
    for s in SU:
        print('  ~', s)
