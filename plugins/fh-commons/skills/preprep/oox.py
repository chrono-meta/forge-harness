#!/usr/bin/env python3
"""oox — 세 레인(geometry · attr_consistency · screen_parity)이 공유하는 OOXML 독자.

🟥 왜 있나 (2026-09-11, codex cross-family R1~R6 — 여섯 라운드 연속): 각 레인이 정규식으로 XML 을 읽었고
   매 라운드 같은 부류가 S/A 를 냈다 — 속성 순서(`<a:off y= x=>`·`<p:sldId r:id= id=>`·`<p:sldSz cy= cx=>`),
   접두 변이(`<q:sldId xmlns:q=…>`), 여는 태그의 속성(`<p:sp useBgFill>`), 엔티티(`&amp;` vs `&#38;`),
   중첩 그룹의 변환(flip·이동)이 자식에 안 붙음. 「조이지 말고 줄여라」— 정규식을 지우고 **트리로 읽는다**.
   태그는 지역명(local-name)으로 맞춘다: 실물의 `p:`/`a:` 도, 레인 픽스처의 가짜 접두(`xmlns:p="p"`)도 같이 읽힌다.
   그룹은 grpSpPr/xfrm(off·ext·chOff·chExt·flipH/V) 을 **재귀로 합성**해 자식 좌표를 절대 EMU 로 낸다.

이 파일은 정규식을 «안» 쓴다(접두 결박 한 줄 제외). 도형의 «무엇»(이름·좌표·flip·문단·런·선)만 낸다 —
판정은 각 레인의 몫이다.
"""
import re, zipfile, xml.etree.ElementTree as ET

_PREFIX_RE = re.compile(r'\b(p|a|r):')


def parse_xml(s):
    """XML 문자열 → 루트. 레인 픽스처처럼 접두가 «선언 없이» 쓰인 문서도 읽는다(루트에 임시 결박)."""
    if isinstance(s, bytes):
        s = s.decode('utf-8', 'replace')
    m = None
    for m_ in re.finditer(r'<!--.*?-->|<\?.*?\?>|<!\[CDATA\[.*?\]\]>|<([A-Za-z_][\w.-]*:)?[A-Za-z_][\w.-]*\b[^>]*>', s, re.S):   # R8 B10: 주석·PI 안의 태그는 루트가 아니다
        if not m_.group(0).startswith(('<!--', '<?', '<![CDATA[')):
            m = m_
            break
    if m:
        head = m.group(0)
        need = [p for p in ('p', 'a', 'r') if not re.search(r'xmlns:%s\s*=' % p, head) and re.search(r'\b%s:' % p, s)]   # R7 B8: `xmlns:p = "…"` 도 선언이다
        if need:
            inj = ''.join(' xmlns:%s="urn:fh-unbound-%s"' % (p, p) for p in need)
            s = s[:m.start()] + head[:-1].rstrip('/') + inj + ('/>' if head.endswith('/>') else '>') + s[m.end():]
    return ET.fromstring(s)


def local(tag):
    return tag.rsplit('}', 1)[-1] if '}' in tag else tag.split(':', 1)[-1]


def attr(el, name):
    """지역명으로 속성 찾기 — `r:id` 든 `{ns}id` 든."""
    for k, v in el.attrib.items():
        if local(k) == name:
            return v
    return None


def children(el, name):
    return [c for c in el if local(c.tag) == name]


def child(el, name):
    cs = children(el, name)
    return cs[0] if cs else None


def find_desc(el, name):
    for d in el.iter():
        if d is not el and local(d.tag) == name:
            return d
    return None


# ── 발표 순서 ─────────────────────────────────────────────────────────────

def slide_order(z):
    """[슬라이드 파일 번호 …] 발표 순서. 못 푸는 r:id 는 KeyError 로 올라간다(조용히 안 빠진다)."""
    rels = {}
    for rel in parse_xml(z.read('ppt/_rels/presentation.xml.rels')).iter():
        if local(rel.tag) != 'Relationship':
            continue
        tgt = attr(rel, 'Target') or ''
        if tgt.startswith('/'):                                        # R8 B7: OPC 절대 Target
            tgt = tgt[len('/ppt/'):] if tgt.startswith('/ppt/') else tgt.lstrip('/')
        m = re.fullmatch(r'slides/slide(\d+)\.xml', tgt)
        if m and attr(rel, 'Id'):
            rels[attr(rel, 'Id')] = int(m.group(1))
    pres = parse_xml(z.read('ppt/presentation.xml'))
    lst = find_desc(pres, 'sldIdLst')
    out = []
    for sid in (list(lst) if lst is not None else []):
        if local(sid.tag) != 'sldId':
            continue
        rid = attr(sid, 'id') if attr(sid, 'id') and not str(attr(sid, 'id')).isdigit() else None
        # r:id 와 id 가 둘 다 «id» 지역명이다 — 숫자가 아닌 쪽이 관계 id
        for k, v in sid.attrib.items():
            if local(k) == 'id' and not str(v).isdigit():
                rid = v
        out.append(rels[rid])
    return out


def slide_size(z):
    """(cx, cy) EMU. 없으면 None."""
    pres = parse_xml(z.read('ppt/presentation.xml'))
    sz = find_desc(pres, 'sldSz')
    if sz is None or attr(sz, 'cx') is None or attr(sz, 'cy') is None:
        return None
    return int(attr(sz, 'cx')), int(attr(sz, 'cy'))


# ── 변환 합성 ─────────────────────────────────────────────────────────────

class _T:
    """그룹 변환의 «사슬». 자식 좌표 → (chOff 빼고 × scale) → 이 그룹 자신의 flip 으로 상자 안에서 반사 → off 더해
    부모 좌표 → 부모에게 같은 절차. 반사를 **각 단계에서** 하므로 바깥 그룹의 flip 이 안쪽 그룹의 내부 배치까지 거울로
    옮긴다(R7 A4 — 초판은 표식만 XOR 하고 자리를 안 옮겨 «이동» 이 사라졌다).
    회전(rot)은 합성하지 않는다 — 사슬 어딘가에 rot 가 있으면 `rot_unmeasured` 로 이름을 남긴다(잔여)."""
    __slots__ = ('parent', 'ox', 'oy', 'sx', 'sy', 'chx', 'chy', 'gcx', 'gcy', 'own', 'flips', 'rot_unmeasured', 'geo_unmeasured')

    def __init__(self):
        self.parent = None
        self.ox = self.oy = 0; self.sx = self.sy = 1.0; self.chx = self.chy = 0; self.gcx = self.gcy = 0
        self.own = set(); self.flips = set(); self.rot_unmeasured = False; self.geo_unmeasured = False

    def _apply_f(self, x, y, cx, cy):
        if self.parent is None:
            return (x, y, cx, cy)
        lx, ly = (x - self.chx) * self.sx, (y - self.chy) * self.sy
        w, h = cx * self.sx, cy * self.sy
        if 'H' in self.own:
            lx = self.gcx - lx - w
        if 'V' in self.own:
            ly = self.gcy - ly - h
        return self.parent._apply_f(self.ox + lx, self.oy + ly, w, h)

    def apply(self, x, y, cx, cy):
        return tuple(int(round(v)) for v in self._apply_f(x, y, cx, cy))

    def then(self, xfrm):
        """이 변환 «안» 의 그룹 xfrm 을 합성한 새 변환."""
        t = _T()
        t.parent = self
        off, ext, choff, chext = (child(xfrm, n) for n in ('off', 'ext', 'chOff', 'chExt'))
        gx, gy = (int(attr(off, 'x') or 0), int(attr(off, 'y') or 0)) if off is not None else (0, 0)
        gcx, gcy = (int(attr(ext, 'cx') or 0), int(attr(ext, 'cy') or 0)) if ext is not None else (0, 0)
        cx0, cy0 = (int(attr(choff, 'x') or 0), int(attr(choff, 'y') or 0)) if choff is not None else (gx, gy)
        ccx, ccy = (int(attr(chext, 'cx') or 0), int(attr(chext, 'cy') or 0)) if chext is not None else (gcx, gcy)
        t.ox, t.oy = gx, gy                        # 부모 좌표계 값 그대로 — 부모 변환은 사슬이 통과시킨다
        t.sx = (gcx / ccx) if ccx else 1.0
        t.sy = (gcy / ccy) if ccy else 1.0
        t.chx, t.chy = cx0, cy0
        t.gcx, t.gcy = gcx, gcy                    # 이 그룹 상자(부모 좌표계 크기) — 자식 반사의 기준
        for k in ('H', 'V'):
            if attr(xfrm, 'flip' + k) in ('1', 'true'):
                t.own.add(k)
        t.flips = set(self.flips) ^ t.own
        t.rot_unmeasured = self.rot_unmeasured or attr(xfrm, 'rot') not in (None, '0')
        # R8 B11: ext 또는 chExt 가 0/부재인 그룹은 배율이 정의되지 않는다 — «안 움직였다» 로 접지 말고 이름으로 남긴다
        t.geo_unmeasured = self.geo_unmeasured or not (gcx and gcy and ccx and ccy)
        return t


def _xfrm_of(el):
    """도형 요소의 xfrm — spPr/grpSpPr/graphicFrame 의 p:xfrm 중 첫 것."""
    for d in el.iter():
        if d is not el and local(d.tag) == 'xfrm':
            return d
    return None


def _text_of(el):
    return ''.join(el.itertext())


def _paras(el):
    """[{'algn': str|None, 'runs': [(text, sz_pt|None)]}] — 문단 단위, endParaRPr 제외, fld 포함."""
    out = []
    for p in el.iter():
        if local(p.tag) != 'p':
            continue
        ppr = child(p, 'pPr')
        algn = attr(ppr, 'algn') if ppr is not None else None
        runs = []
        for r in p:
            if local(r.tag) in ('r', 'fld'):
                rpr = child(r, 'rPr')
                sz = int(attr(rpr, 'sz')) / 100 if (rpr is not None and attr(rpr, 'sz')) else None
                t = ''.join(x.text or '' for x in r.iter() if local(x.tag) == 't')
                runs.append((t, sz))
            elif local(r.tag) == 'br':
                runs.append(('\n', None))
        out.append({'algn': algn, 'runs': runs})
    return out


def walk_slide(z, sn):
    """한 슬라이드의 «화면에 놓이는» 도형 전부(그룹은 풀어서, 좌표는 절대 EMU 로 합성).
    반환: [{'name','kind','x','y','cx','cy','flip','paras','ln_w','dash','in_group'} …] 문서 순서."""
    root = parse_xml(z.read('ppt/slides/slide%d.xml' % sn))
    tree = find_desc(root, 'spTree')
    if tree is None:
        return []
    out = []
    _walk(tree, _T(), out, False)
    return out


def _walk(container, T, out, in_group):
    for el in container:
        kind = local(el.tag)
        if kind == 'AlternateContent':                       # R7 A5: mc:AlternateContent — Choice(없으면 Fallback) 안으로
            c = child(el, 'Choice')                          # R8 B6: 빈 <mc:Choice/> 는 «아무것도 안 그림» 이지 Fallback 이 아니다 — Element 진리값은 길이다
            alt = c if c is not None else child(el, 'Fallback')
            if alt is not None:
                _walk(alt, T, out, in_group)
            continue
        if kind == 'grpSp':
            gpr = child(el, 'grpSpPr')
            xf = child(gpr, 'xfrm') if gpr is not None else None
            _walk(el, T.then(xf) if xf is not None else T, out, True)
            continue
        if kind not in ('sp', 'cxnSp', 'pic', 'graphicFrame'):
            continue
        nv = None
        for d in el:
            if local(d.tag).startswith('nv') and local(d.tag).endswith('Pr'):
                nv = d
        cnv = child(nv, 'cNvPr') if nv is not None else None
        name = attr(cnv, 'name') if cnv is not None else None
        xf = _xfrm_of(el)
        geo = None
        if xf is not None:
            off, ext = child(xf, 'off'), child(xf, 'ext')
            if off is not None and ext is not None and all(attr(off, k) is not None for k in ('x', 'y')) and all(attr(ext, k) is not None for k in ('cx', 'cy')):
                geo = T.apply(int(attr(off, 'x')), int(attr(off, 'y')), int(attr(ext, 'cx')), int(attr(ext, 'cy')))
        flips = set(T.flips)
        if xf is not None:
            for k in ('H', 'V'):
                if attr(xf, 'flip' + k) in ('1', 'true'):
                    flips ^= {k}
        ln = None
        spr = child(el, 'spPr')
        if spr is not None:
            ln = child(spr, 'ln')
        ln_w = int(attr(ln, 'w')) if (ln is not None and attr(ln, 'w')) else None
        dash_el = child(ln, 'prstDash') if ln is not None else None
        dash = attr(dash_el, 'val') if dash_el is not None else None
        # 문단: txBody 의 것 + 표(graphicFrame) 셀의 것
        paras = []
        tx = child(el, 'txBody')
        if tx is not None:
            paras = _paras(tx)
        elif kind == 'graphicFrame':
            paras = _paras(el)
        out.append(dict(name=name, kind=kind, x=geo[0] if geo else None, y=geo[1] if geo else None,
                        cx=geo[2] if geo else None, cy=geo[3] if geo else None,
                        flip=''.join(k for k in ('H', 'V') if k in flips), paras=paras,
                        ln_w=ln_w, dash=dash, in_group=in_group, rot_unmeasured=T.rot_unmeasured, geo_unmeasured=T.geo_unmeasured))


def para_texts(paras):
    """문단 텍스트 목록(런 '' 로 이어붙임, 공백 정규화, 빈 문단 제외)."""
    res = []
    for p in paras:
        t = re.sub(r'\s+', ' ', ''.join(t for t, _ in p['runs'])).strip()
        if t:
            res.append(t)
    return res


def shape_text(paras):
    return ' '.join(para_texts(paras))
