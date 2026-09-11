#!/usr/bin/env python3
"""L14 screen-parity — **원고의 화면 블록(🖥)과 덱 화면이 갈렸나.**

## 왜 이 레인이 없었나, 그리고 왜 그게 이상한가 (2026-09-10)

이 하네스의 정체는 «표면 사이»다 — SKILL 첫 절이 그렇게 적는다. 그런데 **가장 큰 쌍이
비어 있었다**: `surfaces.yaml` 이 원고를 «화면 문자열의 정본»(`canonical_for: [화면 문자열]`)
이라고 선언해 놓고, **그 선언을 집행하는 레인이 하나도 없었다.**

실사고(같은 날): 운영자가 PowerPoint 에서 직접 **7곳**을 고쳤다 — 라벨 두 종류를 지우고
세 구간의 문장을 손봤다. **`preprep` 은 `rc=0` 을 냈다.** 덱은 새 문장을, 원고는 옛 문장을
들고 있는 채로 통과한 것이다.
🟥 「선언은 있는데 소비처가 0」 — 이 저장소가 이름 붙인 반쪽 외부화 그대로다.

## 무엇을 재나

    원고 단위 i 의 🖥 블록 줄들   ↔   덱 i 번째 장의 화면 문자열들

공백을 지우고 대조해서 **짝이 없는 줄**을 낸다. 🟥 그리고 «없는 줄»과 «문구만 다른 줄»을
**갈라서** 낸다 — 합치면 계기가 거짓말한다:

    🗑/➕ 짝 없음   한쪽에만 있고 비슷한 상대가 아예 없다 → 진짜 드리프트 후보
    ✏️ 문구 다름   비슷한 상대가 있다(기본 유사도 0.60) → 손질했는데 한쪽만 반영

## 🟥 advisory 고정이고, 그 이유가 실측에 있다

이 덱(120장, 손질을 여러 차례 거친 상태)에서 **짝 없음 53줄 · 문구 다름 38줄**이 뜬다.
원고 🖥 블록은 화면의 «모든» 도형을 적는 자리가 아니라 사람이 적는 요약이라, 아이콘 라벨·
보조 문구가 구조적으로 빠진다. ⇒ **후보 0 을 목표로 삼으면 오독이다.** L8·L11 과 같은
성격이고, 종료코드에 태우면 최저비용 무마가 «원고를 화면에 맞춰 기계적으로 덮어쓰는 것»이
되어 정본이 산출물을 따라가는 역전이 난다.

⚠️ **매핑은 순서다** — 원고 i 번째 단위 ↔ 덱 i 번째 장. 개수가 다르면 통째로 **UNMEASURED**
로 내고 아무것도 대조하지 않는다(어긋난 채 짝지으면 전량 오탐이 된다).
"""
import html, re, os, zipfile, difflib, collections

def manuscript_screens(path):
    """(순서대로의 [(단위id, [화면줄…])], 총 단위 수)"""
    s = open(path, encoding='utf-8').read()
    out = []
    for blk in re.split(r'^###\s+', s, flags=re.M)[1:]:
        head = blk.split('\n', 1)[0]                      # R8 B12: 단위 id 는 «제목 줄» 안에서만 — '·' 가 없으면 블록 전체가 id 가 됐다
        uid = re.split(r'\s*·', head, 1)[0].strip() or '(제목 없음)'
        # 🖥 는 U+1F5A5 뒤에 변이 선택자(U+FE0F)나 공백이 붙어 올 수 있다 — 그 변이를 못 읽으면
        #    «단위 0» 이 되고 «어긋남 0» 으로 접힌다(codex 09-11)
        m = re.search(r'🖥\ufe0f?[ \t]*\n(.*?)(?=\n🗣|\Z)', blk, re.S)
        lines = [l.strip() for l in (m.group(1).split('\n') if m else []) if l.strip()]
        out.append((uid, lines))
    return out


def deck_screens(path):
    """장별 [문단 텍스트 …] (평평하게). 🟥 deprecated — 이 결과를 compare() 에 «deck_groups 없이» 넘기면
    조용히 1단계로 돌아 다문단 도형마다 오탐이 난다(덱 세션 실측 09-11: 279 vs 48). 새 호출자는
    deck_screens_grouped() 를 쓰고 compare(..., deck_groups=groups) 로 불러라."""
    return [[t for shp in sl for t in shp] for sl in deck_screens_grouped(path)]


def deck_screens_grouped(path):
    """장별 [[도형의 문단 …] …] — 🟥 원고 🖥 는 «도형 단위» 로 쓰이고 덱은 «문단 단위» 로 읽힌다.
    알갱이가 다른 채 짝지으면 다문단 도형마다 1+N 건 오탐이 난다(실측 47 → 279). 그래서 도형 경계를
    같이 넘겨 compare 가 두 단계로 맞춘다. 2026-09-11: 정규식 독자 → oox(트리). 표 셀 문단 포함."""
    import oox as _oox
    z = zipfile.ZipFile(path)
    out = []
    for sn in _oox.slide_order(z):
        shapes = []
        for s in _oox.walk_slide(z, sn):
            paras = _oox.para_texts(s['paras'])
            if paras:
                shapes.append(paras)
        out.append(shapes)
    return out


def _norm(t):
    return re.sub(r'\s', '', t)


def compare(man, deck, threshold=0.60, skip=(), deck_groups=None):
    """(absent, wording, stats) — 🟥 둘을 합치지 않는다.
    deck_groups 가 있으면 2단계: ① 문단 단위로 맞추고 ② 남은 원고 줄을 «같은 도형의 남은 문단 join»
    과 한 번 더 맞춘 뒤에야 짝 없음으로 낸다(원고는 도형 단위로 쓰인 면이다 — 덱 세션 실측 09-11)."""
    absent, wording = [], []
    joined_hits = 0
    if deck_groups is None:
        # 🟥 같은 얼굴로 다른 동작을 내지 않는다 — 1단계로 도는 것은 stats 에도, stderr 에도 남긴다
        import sys
        print('lane_screen_parity.compare: deck_groups 없음 — 1단계(문단 평면)만 돈다. '
              '다문단 도형은 오탐이 난다. deck_screens_grouped() 를 넘겨라', file=sys.stderr)
    for i, (uid, mlines) in enumerate(man):
        if uid in skip:
            continue
        M = [_norm(t) for t in mlines]
        D = [_norm(t) for t in deck[i]]
        # 🟥 다중성을 보존한다 — 원고에 «Title» 이 둘이고 덱에 하나면 하나가 짝이 없다(집합은 그걸 지운다)
        # R2 B12: 다중성은 Counter 로 — 같은 문단이 둘이면 둘 다 세고, 둘 다 빼야 한다(list.remove 는 크래시)
        pool = collections.Counter(t for t in D if t)
        M = [t for t in M if t]
        # ⓪ R3 B13: «도형 전체 join 이 원고 줄과 정확히 같은» 짝을 먼저 소비한다 — 문단 단위가 먼저 먹으면
        #    (원고 AB·ABX ↔ 도형 [AB,X]·[A,B]) 옳은 배정이 막힌다.
        consumed_shapes = set()   # R4 A3: ⓪ 에서 통째로 소비된 도형은 ② 가 다시 빌리지 못한다
        if deck_groups is not None:
            for si, paras in enumerate(deck_groups[i]):
                ps = [_norm(p) for p in paras if _norm(p)]
                if len(ps) < 2 or not all(pool[p] > 0 for p in ps):
                    continue
                j = ''.join(ps)
                if j in M:
                    M.remove(j)
                    for p in ps:
                        pool[p] -= 1
                    joined_hits += 1
                    consumed_shapes.add(si)
        only_m = []
        for t in M:
            if pool[t] > 0:
                pool[t] -= 1
            else:
                only_m.append(t)
        # ② 도형 단위 재대조 — 남은 원고 줄이 «어느 도형의 «아직 짝 없는» 문단을 이어 붙인 것» 이면 짝이다
        #    (R2 B11: 1단계에서 일부가 맞았어도 나머지를 잇는다). 🟥 R2 A5: 정확 일치만 «조용히» 사라진다 —
        #    유사 일치는 문구 차이로 남긴다(맞춘 것과 다른 것을 같은 얼굴로 내지 않는다).
        if deck_groups is not None and only_m:
            for si, paras in enumerate(deck_groups[i]):
                if si in consumed_shapes:
                    continue
                avail = collections.Counter(pool)
                ps = []
                for p in (_norm(p) for p in paras):
                    if p and avail[p] > 0:
                        avail[p] -= 1
                        ps.append(p)
                if len(ps) < 2:
                    continue
                j = ''.join(ps)
                hit = next((t for t in only_m if t == j), None)
                fuzzy = None
                if hit is None:
                    cand = max(((difflib.SequenceMatcher(None, t, j).ratio(), t) for t in only_m), default=(0.0, None))
                    if cand[0] >= threshold:
                        hit, fuzzy = cand[1], cand[0]
                if hit is not None:
                    only_m.remove(hit)
                    for p in ps:
                        pool[p] -= 1
                    joined_hits += 1
                    consumed_shapes.add(si)
                    if fuzzy is not None:
                        wording.append((i + 1, uid, hit, j, fuzzy))
        for t in only_m:
            best = max(((difflib.SequenceMatcher(None, t, c).ratio(), c) for c in pool.elements()),
                       default=(0.0, None))
            if best[0] >= threshold:
                pool[best[1]] -= 1
                wording.append((i + 1, uid, t, best[1], best[0]))
            else:
                absent.append((i + 1, uid, '원고에만', t))
        for t in pool.elements():
            absent.append((i + 1, uid, '화면에만', t))
    slides = {a[0] for a in absent} | {w[0] for w in wording}
    return absent, wording, {'units': len(man), 'slides_touched': len(slides), 'joined': joined_hits,
                             'stage': 2 if deck_groups is not None else 1}


def _resolve(root, p):
    return os.path.normpath(os.path.join(root, os.path.expanduser(p)))


def scan(cfg, root):
    """preprep.py 진입점. 🟥 **advisory 고정** — findings 를 안 낸다."""
    by_id = cfg.get('surfaces_by_id') or {}
    deck_s = by_id.get('built_deck')
    if not deck_s:
        return [], ['L14 screen-parity : built_deck 미선언 — NOT_CONFIGURED (0 아님)']
    # 원고 표면 = interslide.manuscript 가 가리키는 것 (없으면 화면 정본을 선언한 표면)
    mid = ((cfg.get('interslide') or {}).get('manuscript')
           or next((k for k, v in by_id.items()
                    if '화면 문자열' in (v.get('canonical_for') or [])), None))
    if not mid or mid not in by_id:
        return [], ['L14 screen-parity : 화면 문자열의 정본 표면이 선언되지 않았다 '
                    '— NOT_CONFIGURED (0 아님). `interslide.manuscript` 또는 '
                    "`canonical_for: [화면 문자열]` 로 지정해라"]
    mp, dp = _resolve(root, by_id[mid]['path']), _resolve(root, deck_s['path'])
    for p, lab in ((mp, '원고'), (dp, '덱')):
        if not os.path.exists(p):
            return [], ['L14 screen-parity : %s 실물 없음(%s) — UNMEASURED (0 아님)' % (lab, p)]
    spec = cfg.get('screen_parity') or {}
    try:
        man = manuscript_screens(mp)
        groups = deck_screens_grouped(dp)
        deck = [[t for shp in sl for t in shp] for sl in groups]
    except Exception as e:
        return [], ['L14 screen-parity : 계기 오류(%s: %s) — UNMEASURED (0 아님)'
                    % (type(e).__name__, e)]
    # 🟥 어긋난 채 짝지으면 전량 오탐이다. 개수가 다르면 아무것도 대조하지 않는다.
    if len(man) != len(deck):
        return [], ['L14 screen-parity : 원고 단위 %d개 ↔ 덱 %d장 — 개수가 달라 순서 매핑을 '
                    '못 세운다. UNMEASURED (0 아님, 「어긋남 없음」 아님)' % (len(man), len(deck))]
    absent, wording, st = compare(man, deck,
                                  float(spec.get('wording_threshold', 0.60)),
                                  set(spec.get('skip_units') or ()), deck_groups=groups)
    notes = ['L14 screen-parity : 짝 없는 줄 %d · 문구만 다른 줄 %d '
             '(단위 %d · 어긋난 장 %d · 도형 join 으로 맞춘 원고 줄 %d) — 🟥 advisory. 원고 🖥 는 화면의 «모든» 도형을 적는 '
             '자리가 아니라 사람이 적는 요약이라 후보 0 이 목표가 아니다'
             % (len(absent), len(wording), st['units'], st['slides_touched'], st.get('joined', 0))]
    for sn, uid, side, t in absent[:int(spec.get('max_show', 24))]:
        notes.append('   🗑 %3dp %-7s %s : «%s»' % (sn, uid, side, t[:50]))
    if len(absent) > int(spec.get('max_show', 24)):
        notes.append('   … 짝 없는 줄 %d개 더' % (len(absent) - int(spec.get('max_show', 24))))
    for sn, uid, a, b, r in wording[:int(spec.get('max_show_wording', 8))]:
        notes.append('   ✏️ %3dp %-7s 원고 «%s»' % (sn, uid, a[:44]))
        notes.append('        %s 화면 «%s»  (닮음 %.2f)' % (' ' * 12, b[:44], r))
    if len(wording) > int(spec.get('max_show_wording', 8)):
        notes.append('   … 문구만 다른 줄 %d개 더' % (len(wording) - int(spec.get('max_show_wording', 8))))
    return [], notes


if __name__ == '__main__':
    import sys
    man = manuscript_screens(sys.argv[1])
    deck = deck_screens(sys.argv[2])
    if len(man) != len(deck):
        print('🟥 단위 %d ↔ 장 %d — UNMEASURED' % (len(man), len(deck)))
        raise SystemExit(2)
    a, w, st = compare(man, deck)
    print('짝 없음 %d · 문구 다름 %d · %s' % (len(a), len(w), st))
    for sn, uid, side, t in a:
        print('  🗑 %3dp %-7s %s «%s»' % (sn, uid, side, t[:56]))
    for sn, uid, x, y, r in w:
        print('  ✏️ %3dp %-7s %.2f\n       원고 «%s»\n       화면 «%s»' % (sn, uid, r, x[:56], y[:56]))
