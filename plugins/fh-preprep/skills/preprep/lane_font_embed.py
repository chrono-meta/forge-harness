"""lane_font_embed.py — L15-b: **쓰는 서체를 덱이 들고 다니나.**

🟥 L15(lane_font.py)가 «서체가 템플릿 집합을 벗어났나»를 보는 반면, 이 레인은
   «그 서체가 **발표장 PC 에 있다고 가정하고 있나**»를 본다. 둘은 다른 실패를 잡는다.

SKILL §L15 는 *「그 서체가 **설치돼 있는지**(파일은 이름만 적고, 없으면 렌더러가 조용히
대체한다)」* 를 **구조적으로 못 보는 것 셋** 중 하나로 적어 두고 «파일 밖의 사실이라 0 으로
세지 않는다» 고 했다. 맞다 — 그러나 **임베드 여부는 파일 «안»의 사실이다.**
설치 여부는 못 봐도 **«설치에 기대고 있나»는 잰다.** 이 레인이 그 절반을 닫는다.

재는 것
    `ppt/presentation.xml` 의 `<p:embeddedFont>` 집합  ⊇  `ppt/slides/*.xml` 이 부르는
    서체 집합(`a:latin` · `a:ea`, 테마 참조 `+mn-*`/`+mj-*` 는 theme 에서 풀어서 포함)

🟥 **이 축은 «부재가 곧 결함»이다 — 임베드 0 은 UNMEASURED 가 아니라 FAIL 이다.**
   다른 레인의 «부재 ↔ 0» 규율과 방향이 반대인 이유: 여기서 재는 것은 «측정할 수 있었나»가
   아니라 «덱이 무엇을 들고 다니나»이고, 아무것도 안 들고 다니는 것은 **측정된 사실**이다.

면제는 선언으로만 — `surfaces.yaml`:

    fonts:
      embed_exempt:
        - fonts: ["Arial"]
          why:   "시스템 기본 서체 — 어느 PC에나 있다"

🟥 `why` 가 비면 «면제»가 아니라 **오류**다(SKILL §방법론 ⓕ ②). 면제된 것은 «면제됨»으로
   출력된다 — 조용히 사라지면 다음 감사자가 다시 «발견»한다(ⓕ ③).

실사고(2026-09-21): 한 덱이 **안 쓰는 서체 하나를 임베드하고, 실제로 쓰는 둘을 안 넣은**
채로 제출됐다 — `slides/` 의 `a:latin` 분포가 A 1,744회 · B 118회 · C 3회인데 임베드 목록은
«C 와, 분포에 0회인 D» 였다. 외부 디자인 검수에서 7종 전량 임베드로 바뀌었다.
"""

import os
import re
import zipfile
from collections import Counter

_THEME_REF = re.compile(r'^\+(mj|mn)-(lt|ea|cs)$')


def embedded_fonts(z):
    """(가족 이름 집합, 가족→선언된 스타일들, 참조가 끊긴 가족)"""
    try:
        pres = z.read('ppt/presentation.xml').decode('utf-8', 'replace')
    except KeyError:
        return set(), {}, []
    try:
        rels = z.read('ppt/_rels/presentation.xml.rels').decode('utf-8', 'replace')
    except KeyError:
        rels = ''
    rel_targets = {}
    for tag in re.findall(r'<Relationship\b[^>]*>', rels):
        i = re.search(r'\bId="([^"]+)"', tag)
        t = re.search(r'\bTarget="([^"]+)"', tag)
        if i and t:
            rel_targets[i.group(1)] = t.group(1)
    names = z.namelist()
    fams, styles, dangling = set(), {}, []
    for blk in re.findall(r'<p:embeddedFont>.*?</p:embeddedFont>', pres, re.S):
        m = re.search(r'<p:font\b[^>]*\btypeface="([^"]*)"', blk)
        if not m:
            continue
        fam = m.group(1)
        fams.add(fam)
        st = []
        for sm in re.finditer(r'<p:(regular|bold|italic|boldItalic)\b[^>]*r:id="([^"]+)"', blk):
            st.append(sm.group(1))
            tgt = rel_targets.get(sm.group(2))
            if tgt:
                part = os.path.normpath(os.path.join('ppt', tgt)).replace(os.sep, '/')
                if part not in names:
                    dangling.append((fam, sm.group(1), part))
        styles[fam] = st
    return fams, styles, dangling


def theme_map(z):
    """테마 참조(`+mn-ea` 등)를 실제 서체 이름으로 푸는 표."""
    out = {}
    for n in z.namelist():
        if not re.match(r'ppt/theme/theme\d+\.xml$', n):
            continue
        x = z.read(n).decode('utf-8', 'replace')
        for grp, key in (('majorFont', 'mj'), ('minorFont', 'mn')):
            g = re.search(r'<a:%s>(.*?)</a:%s>' % (grp, grp), x, re.S)
            if not g:
                continue
            for tag, slot in (('latin', 'lt'), ('ea', 'ea'), ('cs', 'cs')):
                t = re.search(r'<a:%s\b[^>]*typeface="([^"]*)"' % tag, g.group(1))
                if t and t.group(1):
                    out.setdefault('+%s-%s' % (key, slot), t.group(1))
        break
    return out


def used_fonts(z):
    """slides/ 가 실제로 부르는 서체 → 횟수. 테마 참조는 풀어서 넣는다.

    🟥 `a:sym`·`a:cs` 는 안 센다 — 한국어 덱에서 렌더를 지는 것은 `a:latin`·`a:ea` 다.
       그 둘은 **UNMEASURED 로 노트에 적는다**(0 으로 접지 않는다)."""
    tm = theme_map(z)
    used, unresolved, sym_cs = Counter(), Counter(), Counter()
    for n in sorted(z.namelist()):
        if not re.match(r'ppt/slides/slide\d+\.xml$', n):
            continue
        x = z.read(n).decode('utf-8', 'replace')
        for tag in ('latin', 'ea'):
            for tf in re.findall(r'<a:%s\b[^>]*typeface="([^"]*)"' % tag, x):
                if not tf:
                    continue
                if _THEME_REF.match(tf):
                    r = tm.get(tf)
                    if r:
                        used[r] += 1
                    else:
                        unresolved[tf] += 1
                else:
                    used[tf] += 1
        for tag in ('sym', 'cs'):
            for tf in re.findall(r'<a:%s\b[^>]*typeface="([^"]*)"' % tag, x):
                if tf and not _THEME_REF.match(tf):
                    sym_cs[tf] += 1
    return used, unresolved, sym_cs


def _norm(s):
    return re.sub(r'\s+', ' ', (s or '')).strip().lower()


def _exempt_rules(cfg):
    """(정규화된 이름 → why, 오류 메시지들)"""
    spec = (cfg.get('fonts') or {})
    out, errs = {}, []
    for r in (spec.get('embed_exempt') or []):
        why = (r or {}).get('why')
        fonts = (r or {}).get('fonts') or []
        if not why:
            errs.append('L15-b font-embed : 🟥 `embed_exempt` 에 `why` 가 없다(%s) — '
                        '사유 없는 면제는 이 채널의 존재 이유를 지운다. **면제가 아니라 오류로 낸다**'
                        % (', '.join(map(str, fonts)) or '대상 미기재'))
            continue
        for f in fonts:
            out[_norm(f)] = why
    return out, errs


def _family_of(tf):
    """가족 단위 비교 — 굵기 변형(Bold/Light/…)을 가족으로 접는다."""
    return re.sub(r'\s+(bold|semibold|extrabold|black|light|thin|medium|regular|italic|oblique)$',
                  '', _norm(tf)).strip()


def scan(cfg, root):
    """preprep.py 진입점. (findings, notes)"""
    deck_s = (cfg.get('surfaces_by_id') or {}).get('built_deck')
    if not deck_s:
        return [], ['L15-b font-embed : built_deck 미선언 — NOT_CONFIGURED (0 아님)']
    deck = os.path.normpath(os.path.join(root, os.path.expanduser(deck_s['path'])))
    if not os.path.exists(deck):
        return [], ['L15-b font-embed : built_deck 실물 없음(%s) — UNMEASURED (0 아님)' % deck]

    try:
        z = zipfile.ZipFile(deck)
        emb, styles, dangling = embedded_fonts(z)
        used, unresolved, sym_cs = used_fonts(z)
    except Exception as e:
        return [], ['L15-b font-embed : 계기 오류(%s: %s) — UNMEASURED (0 아님)'
                    % (type(e).__name__, e)]

    findings, notes = [], []
    exempt, errs = _exempt_rules(cfg)
    findings += errs

    if not used:
        notes.append('L15-b font-embed : `slides/` 에서 읽은 서체 토큰 0 — 🟥 UNMEASURED, '
                     '「임베드 완전」이 아니다')
        return findings, notes

    emb_fams = {_family_of(f) for f in emb}
    missing = Counter()
    exempted = Counter()
    for tf, c in used.items():
        fam = _family_of(tf)
        if fam in emb_fams or _norm(tf) in {_norm(f) for f in emb}:
            continue
        if _norm(tf) in exempt or fam in {_family_of(k) for k in exempt}:
            exempted[tf] += c
            continue
        missing[tf] += c

    if missing:
        findings.append(
            'L15-b font-embed : **임베드 없이 이름만 부른 서체 %d종 / 런 %d회** — '
            '이 서체가 없는 PC에서는 렌더러가 **조용히 대체**한다(대체는 파일에 안 남는다). '
            '해당: %s' % (len(missing), sum(missing.values()),
                         ' · '.join('%s(%d회)' % (t, c) for t, c in missing.most_common())))
        if not emb:
            findings.append(
                'L15-b font-embed : 🟥 **임베드가 0 종이다.** 이 축에서 0 은 UNMEASURED 가 아니라 '
                'FAIL 이다 — 덱이 아무것도 들고 다니지 않는다는 것은 «못 쟀다»가 아니라 «잰 사실»이다')

    # 🟥 임베드했는데 안 쓰는 것 — 목록이 손으로 채워졌다는 신호다(실사고의 절반)
    unused = sorted(f for f in emb if _family_of(f) not in {_family_of(u) for u in used})
    if unused:
        notes.append('L15-b font-embed : ⓘ 임베드했지만 `slides/` 분포에 0회인 서체 — '
                     + ' · '.join(unused)
                     + '. 자체로는 결함이 아니지만, **쓰는 것이 빠진 것과 같이 나오면** 그 목록은 '
                       '실사용에서 유도된 게 아니라 손으로 채워진 것이다')

    for fam, style, part in dangling:
        findings.append('L15-b font-embed : 선언된 임베드의 실물이 없다 — %s/%s → %s '
                        '(선언만 있고 부품이 없으면 임베드가 아니다)' % (fam, style, part))

    notes.append('L15-b font-embed : 임베드 %d종 · `slides/` 사용 %d종 / 런 %d회 — %s'
                 % (len(emb), len(used), sum(used.values()),
                    'FAIL %d종 미임베드' % len(missing) if missing else '전량 임베드됨'))
    for fam in sorted(emb):
        st = styles.get(fam) or []
        if st and 'bold' not in st and any(_family_of(u) == _family_of(fam) and
                                           _norm(u) != _norm(fam) for u in used):
            notes.append('   ⓘ %s — 임베드된 스타일이 %s 뿐인데 이 가족의 변형을 쓴다. '
                         '변형은 렌더러가 합성할 수 있고 그 결과는 파일에 안 남는다 (UNMEASURED)'
                         % (fam, '/'.join(st)))
    for tf, c in exempted.most_common():
        notes.append('   면제됨 %s (%d회) — %s' % (tf, c, exempt.get(_norm(tf))
                                                 or exempt.get(_family_of(tf), '')))
    if unresolved:
        notes.append('L15-b font-embed : 🟥 테마 참조를 못 푼 토큰 — '
                     + ' · '.join('%s(%d)' % kv for kv in unresolved.most_common())
                     + ' — 그 자리의 실제 서체는 UNMEASURED (0 아님)')
    if sym_cs:
        notes.append('L15-b font-embed : ⓘ `a:sym`/`a:cs` 로만 지정된 서체 %d종 — 이 레인은 '
                     '`a:latin`·`a:ea` 만 판정한다. 그 자리는 UNMEASURED (0 아님)' % len(sym_cs))
    return findings, notes
