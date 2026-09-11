#!/usr/bin/env python3
"""P1·P3 — 도형 배치 검사 둘. the private companion store's origin script (lane_geometry.py(2026-09-04,
36p 사고에서 역산)를 preprep 관례로 이식한 것 — 로직은 그대로다.
정본: `tracks-meta/fh_signal_2026-09-04_preprep-evolution.md` §2.

  P1 build-jitter   같은 이름의 도형이 «연속한 두 장»에서 조금 다른 자리에 있다
                    → 넘길 때 튄다. 실사고: 노란 게이트 막대가 직전 장 대비 35,000 EMU 밀려
                      회색 연결선과 겹쳤다. 큰 차이는 «의도한 이동»이라 제외한다.
  P3 adjacency      한 도형의 «오른쪽 끝»과 다른 도형의 «왼쪽 끝»이 맞닿으려다 어긋났다
                    → 실제 결함이 이 형태였다(회색 스텁 끝 ↔ 막대 시작, 35,000 겹침).

🟥 **P2(near-miss, 같은 종류 모서리끼리만 대조)는 미포함이다 — 채택하지 않는다.** 실사고가
   못 잡히는 이유가 설계 근거였다: 실제 결함은 「회색 스텁 오른쪽 끝 ↔ 막대 왼쪽 끝」이라는
   **다른 종류** 모서리의 인접 관계인데, P2 는 왼↔왼·오른↔오른만 봐서 구조적으로 못 잡는다.
   그 관계는 P3 가 이미 덮는다. 새 레인을 짤 때 «같은 종류끼리»가 기본값이라는 것을 의심하라.

🟥 둘 다 advisory. 임계는 사람이 정한다(기본 JIT=200,000 EMU · ALN=63,500 EMU=5pt ·
   1pt=12,700 EMU). `surfaces.yaml` 의 `geometry.jitter_emu` / `geometry.align_emu` 로 바꾼다.
🟥 «차이 0» 은 정상이고 «차이 큼» 도 정상이다. 이 검사가 보는 것은 그 사이뿐이다.

## 🟥 목록으로 읽지 마라 — 델타로 읽어라

실측: P3 는 원 코퍼스에서 기저 오탐이 76건이다(아이콘 무리 내부 · 맵 라벨의 «의도된» 겹침).
그 목록에서 진짜를 골라낼 방법이 없다. 그런데 편집 전/후를 대조하면 **차이가 정확히 그
한 줄**이었다. ⇒ 절대 목록은 회귀 도구로 못 쓰고 **편집 전후 델타는 정확하다.**
`surfaces.yaml` 의 `geometry.baseline`(이전 판 pptx 경로)이 있으면 이 레인은 델타 모드로 돈다
— 「지금 몇 건이냐」가 아니라 «내가 방금 뭘 어긋냈냐»를 묻는 회귀 도구다.

## 🟥 P1 이 «비교 안 함»을 «튐 없음»으로 속일 수 있는 자리 (계기 결함, 미리 적는다)

`shapes()` 는 **한 장 안에서 이름이 겹치는 도형을 통째로 버린다**(`len(v) == 1` 만 남긴다) —
겹치는 이름끼리는 대조할 대상을 하나로 못 정하기 때문이다. python-pptx 기본 이름
(`TextBox 1` 류)은 장마다 새로 매겨져 **이름이 우연히 안 겹칠 수 있고**, 대조 자체가 0건이
되는 입력에서도 「후보 0건」이 똑같이 출력된다 — 그 0 은 **「튐 없음」이 아니라 「비교 안 함」**
이다(이 저장소가 이름 붙인 「레인이 초록인 이유는 셋」의 ②). ⇒ `scan()` 은 **비교된 도형-쌍
수**를 항상 같이 낸다 — 0 이면 UNMEASURED 로 읽어야 한다는 뜻이다.

## 🟥 이름만으로는 «같은 도형»이 아니다 — 다만 **버리는 게 아니라 신뢰도를 갈라야 한다**

위 절이 «대조 못 한 것»(0건)을 걱정했다면 이 절은 그 반대 — **틀린 것끼리 대조한 것**이다.
서로 다른 도해가 `a-b1` · `TextBox 208xx` 같은 **범용 이름을 재사용**하므로, 이름이 같다고
같은 도형이 아니다. 실측(120장 한국어 덱, 2026-09-10): 이름이 맞은 **824 쌍** 중

    이름+글자 일치  425 (52%)   ← 같은 도형이라 말할 근거가 둘
    이름만 같음      65 ( 8%)   ← 다른 내용이 같은 이름을 입었다. **대조 자체가 틀렸다** → 제외
    양쪽 글자 없음  334 (40%)   ← 막대·선·아이콘. 결박할 근거가 **이름뿐**이다

🟥 **그래서 처방이 「이름 AND 글자로 좁힌다」가 아니다 — 그건 한 번 틀렸다.** 2026-09-10 에
그렇게 좁혀 놓고 원적 사건 재현 프로브를 돌렸더니 **P1 이 존재하는 이유였던 그 결함이
사라졌다**: 35p→36p 의 게이트 막대 `s5017`(x −35,000 EMU, 회색 연결선과 겹침)은 **글자가 없는
도형**이라 좁힌 결박이 통째로 잘라냈다. 오탐을 없애면서 자기 known-positive 를 같이 죽인 것이다
([[feedback_deletion_beats_repair_dead_filter]] 의 반대 방향 — 이번엔 필터가 진짜를 죽였다).

⇒ **셋을 신뢰도로 가른다. 버리는 것은 하나뿐이다.**

    bound      이름+글자 일치 → 후보로 낸다 (근거 둘)
    name_only  양쪽 글자 없음 → **후보로 내되 «이름만»이라고 이름표를 붙인다** (근거 하나)
    mismatch   글자가 다름     → 제외. 이것만이 실제로 틀린 결박이다

`compared=824` 라는 한 숫자를 안 쓰는 이유가 이것이다 — 그 숫자는 「824 쌍을 봤다」로 읽히지만
셋의 성격이 전부 다르다. 🟥 **`bound` 든 `name_only` 든 0 이면 「튐 없음」이 아니라 UNMEASURED 다.**

## 🟥 그리고 이 레인은 «의도된 연출»과 «사고»를 못 가른다 — 판단은 사람이 선언한다

실사고(2026-09-10): 49p→50p 에서 격리 막대가 10.24pt 두꺼워지는 것은 「격리가 세지는」
**연출**이었는데 이 레인이 튐으로 냈고, 그것을 «고쳤다가» 운영자 지적으로 되돌렸다.
🟥 **휴리스틱으로 못 가른다** — 임계의 전제가 「큰 변화는 의도다」인데 그 연출은 임계(15.7pt)
바로 아래에 있었다. ⇒ 기계는 «선언되었나»만 보고 «옳은가»는 안 본다(CLAUDE.md
§Mechanization Boundary — 채널은 굳히고 판단은 안 굳힌다).

`surfaces.yaml` 의 `geometry.intended` 에 선언한다:

    geometry:
      intended:
        - slides: [49, 50]
          shapes: ["s7215", "s7217"]
          attrs:  [x, cx]                 # 🟥 «바뀐 속성 집합»까지 정확히 일치해야 면제된다
          why:    "격리 막대 얇음→두꺼움. 「격리가 세지는」 연출"

🟥 **면제는 도형이 아니라 «그 변화»에 걸린다.** 이름만으로 면제하면 그 도형이 나중에 진짜로
튈 때 조용히 삼킨다 — 이 저장소가 이름 붙인 「ACK 를 손실 내용에 결박하라」와 같은 자리다.
선언한 것 말고 **다른 속성이 바뀌면 그대로 뜬다.** `why` 가 비면 면제가 아니라 **오류**다.
🟥 그리고 면제된 것은 **«면제됨»으로 출력한다** — 조용히 사라지면 다음 감사자가 그 연출을
다시 «발견»한다(§방법론 ⓕ 「알고도 남긴 것」).
"""
import zipfile, re, os, collections, html

EMU_PT = 12700


def _xfrm(b):
    """(x, y, cx, cy) — <a:off>/<a:ext> 의 속성 순서에 기대지 않는다. 없으면 None."""
    off = re.search(r'<a:off\b[^>]*>', b); ext = re.search(r'<a:ext\b[^>]*>', b)
    if not (off and ext):
        return None
    try:
        return tuple(int(re.search(r'\b%s="(-?\d+)"' % k, tag).group(1))
                     for k, tag in (('x', off.group(0)), ('y', off.group(0)), ('cx', ext.group(0)), ('cy', ext.group(0))))
    except AttributeError:
        return None


def shapes(z, sn):
    """한 슬라이드의 도형을 {이름: (x,y,cx,cy,text,flip)} 로. 이름 중복은 대조 못 하니 뺀다.

    🟥 `flip` 은 2026-09-10 에 더했다. 그 전까지 이 레인은 x·y·cx·cy 만 읽었고, 그래서
       **같은 상자에서 방향만 뒤집힌 도형을 «동일»로 판정했다.** 실사고: 화살표 셋의 자리를
       거울로 맞추면서 flipH 가 엉뚱한 도형에 남아 바깥 화살표 둘이 상자 «바깥쪽»을 가리켰는데
       (모이는 그림이 벌어지는 그림이 됐다) 델타가 「새 어긋남 0건」을 냈다. 사람이 눈으로 잡았다.
    """
    x = z.read('ppt/slides/slide%d.xml' % sn).decode('utf-8')
    out = {}
    for m in re.finditer(r'<p:(sp|cxnSp)\b[^>]*>.*?</p:\1>', x, re.S):   # R3 A6: 여는 태그에 속성이 있어도 도형이다
        b = m.group(0)
        nm = re.search(r'name="([^"]*)"', b)
        # R4 A5: 속성 순서는 기하가 아니다 — off/ext 를 각각 찾고 x·y·cx·cy 를 따로 뽑는다
        o = _xfrm(b)
        if not (nm and o):
            continue
        # R3 A7: 런 경계는 글자가 아니다(attr 레인과 같은 규칙) — 문단 안 '' · 문단 사이 ' '
        t = re.sub(r'\s+', ' ', ' '.join(html.unescape(''.join(re.findall(r'<a:t>([^<]*)</a:t>', pm)))   # R4 A6: &amp; == &#38;
                                          for pm in re.findall(r'<a:p\b[^>]*>.*?</a:p>', b, re.S))).strip()
        flip = ''.join(k for k in ('H', 'V') if re.search(r'\bflip%s="(1|true)"' % k, b))   # "true" 도 참이다(python-pptx 실물)
        out.setdefault(nm.group(1), []).append((o[0], o[1], o[2], o[3], t, flip))
    return {k: v[0] for k, v in out.items() if len(v) == 1}


def _order(z):
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


def load_slides(path):
    z = zipfile.ZipFile(path)
    return [shapes(z, sn) for sn in _order(z)]


LAB = ['x', 'y', 'cx', 'cy']


def _intent_index(intended):
    """`geometry.intended` 선언을 조회용으로 편다.

    반환: ({(prev_slide, shape_name): [(frozenset(attrs), why), …]}, errors)
    🟥 `why` 가 비었거나 필드가 빠진 항목은 **면제하지 않고 오류로 낸다** — 사유 없는 면제는
       이 채널이 존재하는 이유(누가·왜 남겼나)를 지운다."""
    idx, errs = collections.defaultdict(list), []
    for n, e in enumerate(intended or [], 1):
        if not isinstance(e, dict):
            errs.append(f'geometry.intended[{n}] : 매핑이 아니다 — 면제 안 함')
            continue
        sl, sh = e.get('slides') or [], e.get('shapes') or []
        if not isinstance(sh, list) or not isinstance(sl, list):
            errs.append(f'geometry.intended[{n}] : shapes·slides 는 목록이어야 한다 (문자열 "ab" 는 a·b 두 도형으로 읽힌다) — 면제 안 함')   # R3 A9
            continue
        at, why = e.get('attrs') or [], (e.get('why') or '').strip()
        if len(sl) != 2 or not sh or not at:
            errs.append(f'geometry.intended[{n}] : slides(2개)·shapes·attrs 가 모두 있어야 한다 — 면제 안 함')
            continue
        # 🟥 면제는 «그 변화» 에 걸린다 — 변화는 i→i+1 사이에 있으므로 두 끝점이 모두 정수이고
        #    연속이어야 한다. [1, 99] 나 [1, "garbage"] 가 1→2 의 변화를 면제하던 구멍(codex 09-11).
        if not all(isinstance(v, int) and not isinstance(v, bool) for v in sl) or sl[1] != sl[0] + 1:
            errs.append(f'geometry.intended[{n}] : slides 는 연속한 두 정수 [i, i+1] 이어야 한다 (받은 값 {sl!r}) — 면제 안 함')
            continue
        bad = [a for a in at if a not in LAB]
        if bad:
            errs.append(f'geometry.intended[{n}] : attrs 에 모르는 이름 {bad} (x·y·cx·cy 뿐) — 면제 안 함')
            continue
        if not why:
            errs.append(f'geometry.intended[{n}] : 🟥 why 가 비었다 — 사유 없는 면제는 오류다, 면제 안 함')
            continue
        for name in sh:
            idx[(int(sl[0]), name)].append((frozenset(at), why, n))
    return idx, errs


def p1_lines(S, JIT, intended=None):
    """build-jitter 후보.

    반환: (lines, stats, suppressed, errors)
      stats  = {'bound', 'name_only', 'mismatch'} — 🟥 셋을 한 숫자로 접지 않는다.
               `bound`/`name_only` 가 둘 다 0 이면 «튐 없음»이 아니라 UNMEASURED 다.
      lines  = 후보. `name_only` 결박은 줄 끝에 **[이름만]** 이 붙는다 — 성격이 다르니
               같은 목록에 두되 같은 것처럼 읽히면 안 된다.
      suppressed = `geometry.intended` 로 면제된 줄 (조용히 버리지 않고 같이 낸다)"""
    idx, errors = _intent_index(intended)
    declared = {n for v in idx.values() for _a, _w, n in v}
    hits = collections.Counter()
    lines, suppressed = [], []
    stats = collections.Counter()
    for i in range(1, len(S)):
        for nm, cur in S[i].items():
            prv = S[i - 1].get(nm)
            if not prv:
                continue
            # 🟥 이름은 결박의 «필요조건»이다. 글자는 근거를 하나 더 얹을 뿐이고,
            #    글자가 없다고 도형이 없는 게 아니다 — 잘라내면 원적 사건이 죽는다(위 절).
            if cur[4] != prv[4]:
                stats['mismatch'] += 1        # 다른 내용이 같은 이름을 입었다 → 결박 자체가 틀렸다
                continue
            weak = not cur[4]                 # 양쪽 다 글자 없음 → 근거가 이름 하나뿐
            stats['name_only' if weak else 'bound'] += 1
            # 🟥 뒤집힘은 «근사»가 아니다 — 임계와 무관하게 낸다. 상자가 한 EMU도 안 움직여도
            #    화면에서는 화살표가 반대를 가리킨다.
            if cur[5] != prv[5]:
                lines.append(f"   {i:>3}p→{i+1:<3}p {nm} 🟥 뒤집힘 "
                             f"«{prv[5] or '없음'}» → «{cur[5] or '없음'}»  "
                             f"— 자리는 그대로여도 방향이 바뀐다  "
                             + ('[이름만 결박]' if weak else f'«{cur[4][:20]}»'))
                stats['flipped'] += 1
            d = [cur[k] - prv[k] for k in range(4)]
            mx = max(abs(v) for v in d)
            if not (0 < mx <= JIT):
                continue
            moved_set = frozenset(LAB[k] for k in range(4) if d[k])
            moved = ' · '.join(f'{LAB[k]} {d[k]:+d}' for k in range(4) if d[k])
            line = (f"   {i:>3}p→{i+1:<3}p {nm} {moved}  ({mx/EMU_PT:.2f}pt)  "   # R3 A8: 줄이 곧 신원 — 이름을 자르면 델타가 두 도형을 합친다
                    + ('[이름만 결박 — 글자 없는 도형]' if weak else f'«{cur[4][:26]}»'))
            hit = next(((w, n) for a, w, n in idx.get((i, nm), []) if a == moved_set), None)
            if hit is not None:
                suppressed.append(line + f"   ← 선언된 연출: {hit[0]}")
                hits[hit[1]] += 1
            else:
                lines.append(line)
    # 🟥 아무것도 안 거는 선언은 «알고 남긴 것» 이 아니라 «알던 것이 틀린 것» 이다 — 출력이 같으면
    #    구분이 안 된다(덱 세션 실측 09-11: 유령 후보에 why 를 붙여 선언해 둔 것이 수리 뒤 죽어 있었다).
    for n in sorted(declared):
        if hits.get(n, 0) == 0:
            errors.append(f'geometry.intended[{n}] : 🟥 죽은 선언 — 이 덱에서 아무 변화도 면제하지 않는다(가리키는 변화가 없다). 지우거나 고쳐라')
    return lines, dict(stats), suppressed, errors


def p3_lines(S, ALN):
    """adjacency 후보 — A 오른쪽 끝 ↔ B 왼쪽 끝, 세로로 겹치는 띠에 있을 때만."""
    lines = []
    for i, sh in enumerate(S):
        items = [(nm, v) for nm, v in sh.items() if v[2] > 0 and v[3] > 0]
        for a in range(len(items)):
            for b in range(len(items)):
                if a == b:
                    continue
                na, va = items[a]
                nb, vb = items[b]
                oy = min(va[1] + va[3], vb[1] + vb[3]) - max(va[1], vb[1])
                if oy <= 0:
                    continue
                gap = vb[0] - (va[0] + va[2])  # A 오른쪽 → B 왼쪽
                if 0 < abs(gap) <= ALN:
                    kind = '겹침' if gap < 0 else '틈'
                    lines.append(f"   {i+1:>3}p {na} 오른끝 → {nb} 왼끝  "
                                 f"{kind} {abs(gap):>6} EMU ({abs(gap)/EMU_PT:.2f}pt)")
    return lines


def collect_lines(path, JIT, ALN, intended=None):
    """(lines, stats, suppressed, errors) — P1+P3 합친 후보 줄과 P1 의 결박 내역."""
    S = load_slides(path)
    l1, stats, suppressed, errors = p1_lines(S, JIT, intended)
    l3 = p3_lines(S, ALN)
    return l1 + l3, stats, suppressed, errors


def _fmt_stats(stats):
    """🟥 세 숫자를 한 줄로 묶되 **합치지는 않는다** — 성격이 셋 다 다르다."""
    b, w, m = (stats.get('bound', 0), stats.get('name_only', 0), stats.get('mismatch', 0))
    s = f"이름+글자 {b}쌍 · 이름만(글자 없는 도형) {w}쌍 · 글자 불일치 {m}쌍 제외"
    if stats.get('flipped'):
        s += f" · 🟥 뒤집힘 {stats['flipped']}건"
    if not (b or w):
        s += ' — 🟥 결박 0 이면 「튐 없음」이 아니라 UNMEASURED 다'
    return s


def delta(base_path, cur_path, JIT, ALN, intended=None):
    """편집 전/후 델타 — 절대 목록이 아니라 **차이**로 읽는 용법(정확했던 것). P3 는 SYS 를 안 쓰니
    양쪽에 같은 규칙을 그대로 적용하면 된다(계기 자기결함이 P2 전용이라 여기 안 옮는다)."""
    bl, st_b, sup_b, _err_b = collect_lines(base_path, JIT, ALN, intended)
    cur, st_c, sup_c, err_c = collect_lines(cur_path, JIT, ALN, intended)
    b = set(bl)
    new = [l for l in cur if l not in b]
    gone = [l for l in bl if l not in set(cur)]
    # R2 A6: 선언 오류(죽은 선언 포함)는 «현재본» 의 것과 같이 나가야 한다 — 기준본 것을 내던 것은 다른 덱의 답
    return new, gone, st_b, st_c, sup_c, err_c


def _resolve(root, p):
    return os.path.normpath(os.path.join(root, os.path.expanduser(p)))


def scan(cfg, root):
    """preprep.py 가 부르는 레인 진입점. (findings, notes) — 🟥 **advisory 고정**:
    호출자는 findings 를 버리고 notes 만 취한다(L8·L11 관례)."""
    deck_s = (cfg.get('surfaces_by_id') or {}).get('built_deck')
    if not deck_s:
        return [], ['P1/P3 geometry : built_deck 미선언 — NOT_CONFIGURED (0 아님)']
    deck = _resolve(root, deck_s['path'])
    if not os.path.exists(deck):
        return [], [f'P1/P3 geometry : built_deck 실물 없음({deck}) — UNMEASURED (0 아님)']
    spec = cfg.get('geometry') or {}
    JIT = int(spec.get('jitter_emu', 200000))
    ALN = int(spec.get('align_emu', 63500))
    base_p = spec.get('baseline')
    intended = spec.get('intended') or []
    notes = []

    def _tail(suppressed, errors):
        """면제·선언 오류는 **항상 같이 낸다** — 조용히 사라진 면제가 §방법론 ⓕ 의 사고다."""
        out = []
        for e in errors:
            out.append('   🟥 ' + e)
        for l in suppressed:
            out.append('   ~ (면제)' + l.strip())
        if suppressed:
            out.append(f'   ~ 선언된 연출 {len(suppressed)}건을 면제했다 — 「없다」가 아니라 「알고 남겼다」')
        return out

    if base_p:
        base = _resolve(root, base_p)
        if not os.path.exists(base):
            return [], [f'P1/P3 geometry : baseline 실물 없음({base}) — UNMEASURED (0 아님)']
        try:
            new, gone, st_b, st_c, sup, err = delta(base, deck, JIT, ALN, intended)
        except Exception as e:
            return [], [f'P1/P3 geometry : 계기 오류({type(e).__name__}: {e}) — UNMEASURED (0 아님)']
        notes.append(f'P1/P3 geometry(델타) : 기준 {os.path.basename(base)} 대비 '
                     f'새 어긋남 {len(new)}건 · 사라진 어긋남 {len(gone)}건 🟥 advisory')
        notes.append(f'   P1 결박(기준) : {_fmt_stats(st_b)}')
        notes.append(f'   P1 결박(현재) : {_fmt_stats(st_c)}')
        for l in new:
            notes.append('   + ' + l.strip())
        for l in gone:
            notes.append('   - ' + l.strip())
        return [], notes + _tail(sup, err)

    try:
        lines, stats, sup, err = collect_lines(deck, JIT, ALN, intended)
    except Exception as e:
        return [], [f'P1/P3 geometry : 계기 오류({type(e).__name__}: {e}) — UNMEASURED (0 아님)']
    notes.append(f'P1/P3 geometry(목록) : 후보 {len(lines)}건 — 🟥 절대 목록으로 읽지 마라, '
                 f'P3 기저 오탐이 코퍼스마다 수십 건일 수 있다(원 코퍼스 실측 76건). '
                 f'`geometry.baseline` 을 쓰는 편집-델타 용법이 정확하다')
    notes.append(f'   P1 결박 : {_fmt_stats(stats)}')
    for l in lines:
        notes.append(l)
    return [], notes + _tail(sup, err)
