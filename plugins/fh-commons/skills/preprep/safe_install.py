#!/usr/bin/env python3
"""산출물 무결성 게이트 — **편집 결과를 정본에 반영하기 전에** 확인한다.

## 왜 있나 (2026-09-10 실사고)

pptx 편집 스크립트가 `assert len(paras) == 3` 에서 죽었는데 **뒤따르는 `cp` 가 그대로 돌아**
120장짜리 정본을 **102장으로 잘린 파일**이 덮었다. git 에서 복구했다.

🟥 근본 원인은 assert 가 아니다 — **«만들기»와 «설치»가 한 호출에 묶여 있었다.** 앞이 실패해도
   뒤가 도는 형태이고, 셸에서 `;` 로 이은 줄은 전부 이 형태다. 그래서 처방은 «assert 를 더 잘
   쓰자»가 아니라 **설치를 별도 단계로 떼고, 그 단계가 스스로 대상을 검사하게 하는 것**이다.
   ([[feedback_recover_and_destroy_never_in_one_call]] 와 같은 축 — 회수와 파괴를 안 묶는다.)

## 무엇을 보나

    ① 후보가 실재하고 비어 있지 않은가
    ② 열리는 zip 인가 · `testzip()` 이 통과하는가 (잘린 파일이 여기서 걸린다)
    ③ pptx 필수 부품이 있는가 (`[Content_Types].xml` · `ppt/presentation.xml` · 그 .rels)
    ④ 장 수가 **기존본보다 줄지 않았는가** — 🟥 이것이 그 사고를 잡는 줄이다
    ⑤ `ppt/slides/*.xml` 파일 수 · `sldIdLst` 항목 수 · **rels 로 실제 닿는 서로 다른 슬라이드 수**
       가 **셋 다 같은가** (목록만 잘린 형태 · 같은 장을 두 번 가리키는 형태 · 끊긴 rels 를 잡는다)
    ⑥ **검사한 바이트가 곧 설치되는 바이트**다 — 후보를 한 번 읽어 그 바이트로 검사·해시·쓰기를
       전부 하고, 옆의 임시 파일에 쓴 뒤 해시를 다시 확인하고 나서야 정본 자리에 넣는다
       (복사 중 잘려도 정본은 무사하고, 검사 뒤 후보가 바뀌어도 바뀐 바이트는 안 들어간다)

🟥 **줄어드는 것이 항상 오류는 아니다** — 일부러 장을 뺄 수 있다. 그때는 `--allow-shrink` 를
   **명시**한다. 기본값을 「거부」로 두는 이유는 이 표면이 «되돌리기 어려운 쪽»이기 때문이다
   (CLAUDE.md §Irreversibility Gates — 비가역 표면은 fail-closed).
🟥 **기존본을 못 읽으면 반영하지 않는다** — 축소 여부를 판정할 수 없는데 덮어쓰는 것은
   «미측정을 통과로 접는 것»이다. 기존본이 아예 없을 때만 첫 설치로 진행한다.
⚠️ 이 게이트는 **구조**만 본다. 내용이 옳은지는 안 본다 — 120장이 그대로 120장이면서 전부
   빈 장이 된 경우는 통과한다. 좁아진 것이지 닫힌 게 아니다. 그 자리는 레인과 렌더가 본다.

## 쓰는 법

    python3 safe_install.py <후보> <정본>              # 검사하고 통과하면 반영
    python3 safe_install.py <후보> <정본> --dry-run    # 검사만
    python3 safe_install.py <후보> <정본> --expect 120 # 장 수를 못 박는다
    python3 safe_install.py <후보> <정본> --allow-shrink --why "38p 삭제"

종료코드  0 반영함 · 1 거부(반영 안 함) · 2 판정불가(계기 오류·인자 오류 — PASS 아님)
          · 3 🟥 반영«했는데» 사후 검증 실패 — 정본이 바뀌었다. 이전 정본 바이트를 되돌려 놓았는지는 메시지에 적힌다(R8 S1)
"""
import sys, os, re, io, zipfile, hashlib, argparse, posixpath, tempfile, fcntl
import xml.etree.ElementTree as _ET
_REL_NS = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'


def _local(tag):
    return tag.rsplit('}', 1)[-1] if '}' in tag else tag.split(':', 1)[-1]


def _attr(el, name):
    for k, v in el.attrib.items():
        if _local(k) == name:
            return v
    return None
try:
    from pptx import Presentation as _Presentation   # 🟥 R3: 손으로 짠 XML 계수는 S 를 세 라운드째 냈다(접두 q:·깨진 XML·External rel).
except Exception:                                    #    실제 파서를 오라클로 세우고, 내 계수는 그것과 «맞아야 하는» 두 번째 제공자로 둔다.
    _Presentation = None

REQUIRED = ('[Content_Types].xml', 'ppt/presentation.xml', 'ppt/_rels/presentation.xml.rels')
SLIDE_RE = re.compile(r'^ppt/slides/slide\d+\.xml$')


def probe_bytes(data):
    """(slide_files, sldIdLst_count, reached_distinct) 또는 예외.
    🟥 셋을 따로 세는 것이 요점이다 — 파일·목록·관계 그래프는 서로 다른 실패를 낸다."""
    with zipfile.ZipFile(io.BytesIO(data)) as z:
        bad = z.testzip()
        if bad is not None:
            raise ValueError(f'zip 안의 «{bad}» 가 깨져 있다')
        names = set(z.namelist())
        missing = [r for r in REQUIRED if r not in names]
        if missing:
            raise ValueError(f'pptx 필수 부품 없음: {missing}')
        files = sorted(n for n in names if SLIDE_RE.match(n))
        pres = z.read('ppt/presentation.xml').decode('utf-8', 'replace')
        lst = re.search(r'<p:sldIdLst\b[^>]*>(.*?)</p:sldIdLst>', pres, re.S)
        entries = re.findall(r'<p:sldId\b[^>]*>', lst.group(1)) if lst else []
        rids = []
        for ent in entries:
            m = re.search(r'\br:id="([^"]+)"', ent)
            if not m:
                raise ValueError(f'sldId 항목에 r:id 가 없다: {ent[:60]}')   # R2 S4: r:id 없는 항목이 계수에서 사라졌다
            rids.append(m.group(1))
        rels = z.read('ppt/_rels/presentation.xml.rels').decode('utf-8', 'replace')
        # 속성 순서에 안 기댄다 — Id 와 Target 을 각각 뽑는다
        rel_map = {}
        for tag in re.findall(r'<Relationship\b[^>]*>', rels):
            mid = re.search(r'\bId="([^"]+)"', tag); mt = re.search(r'\bTarget="([^"]+)"', tag)
            if mid and mt:
                if re.search(r'\bTargetMode="External"', tag):
                    rel_map[mid.group(1)] = '<external:%s>' % mt.group(1)   # R3 S3: 외부 관계는 슬라이드가 아니다
                    continue
                _t = mt.group(1)
                rel_map[mid.group(1)] = posixpath.normpath(_t.lstrip('/')) if _t.startswith('/') else posixpath.normpath(posixpath.join('ppt', _t))   # R8 B7: 절대 Target
        reached = []
        for rid in rids:
            tgt = rel_map.get(rid)
            if tgt is None:
                raise ValueError(f'sldId r:id={rid} 가 rels 에 없다 (끊긴 관계)')
            if tgt not in names:
                raise ValueError(f'sldId r:id={rid} → {tgt} 가 zip 에 없다')
            if not SLIDE_RE.match(tgt):
                raise ValueError(f'sldId r:id={rid} → {tgt} 는 슬라이드 부품이 아니다')   # R2 S3: zip 에 «있다» ≠ 슬라이드다
            reached.append(tgt)
        dup = len(reached) - len(set(reached))
        if dup:
            raise ValueError(f'sldIdLst 가 같은 슬라이드를 {dup}회 중복해 가리킨다')
    n_struct = (len(files), len(rids), len(set(reached)))
    # 오라클: python-pptx 가 «읽어서» 세는 장 수 — 깨진 슬라이드 XML·외부 관계·다른 접두는 여기서 예외로 올라온다
    if _Presentation is None:
        raise ValueError('python-pptx 가 없다 — 오라클 없이는 판정불가')
    prs = _Presentation(io.BytesIO(data))
    n_pptx = 0
    def _walk(shapes):
        for shp in shapes:
            _ = (shp.shape_id, shp.name, shp.element)      # R4 S1: 도형 하나하나 — nvSpPr 없는 도형은 여기서 죽는다
            # R8 A2: «분류» 는 검사가 아니다 — prstGeom 없는 합법 p:sp 에 python-pptx 가 NotImplementedError 를 낸다.
            #    분류 실패는 결함이 아니므로 삼키고, 그룹 판별은 분류가 아니라 태그로 한다.
            try:
                _ = shp.shape_type
            except NotImplementedError:
                pass
            if shp.element.tag.rsplit('}', 1)[-1] == 'grpSp':   # GROUP — R5 S1: 자식도 같은 검사(그룹 안의 깨진 도형)
                _walk(shp.shapes)
    for sl in prs.slides:
        _walk(sl.shapes)
        n_pptx += 1
    # 🟥 R6 S1/S2: 종류별 검사(그림 13번만)는 차트·자리표시자 그림(14번)·깨진 이미지 바이트를 놓쳤다.
    #    «부품과 관계 전부» 를 걷는다 — 끊긴 관계는 여기서 KeyError, 이미지는 PIL 로 실제 디코드.
    if not (n_struct[0] == n_struct[1] == n_struct[2] == n_pptx):
        raise ValueError(f'구조 계수 파일/목록/도달 {n_struct} 와 python-pptx 장 수 {n_pptx} 가 어긋난다 — 두 제공자가 불일치')
    _verify_rels_in_zip(names, z_bytes=data)   # R6 S1: python-pptx 는 끊긴 관계를 로드 시 조용히 버린다 — zip 수준에서 센다
    _verify_package(prs)
    return files, len(rids), len(set(reached))


def _verify_rels_in_zip(names, z_bytes):
    """모든 *.rels 의 내부 Target 이 zip 안에 실재해야 한다(차트·미디어·자리표시자 그림 전부)."""
    # R7 S1: 정규식이 아니라 트리로 읽는다 — `<q:Relationship>`·홑따옴표 속성도 관계다
    with zipfile.ZipFile(io.BytesIO(z_bytes)) as z:
        rel_ids = {}                                             # 부품 → 그 부품 rels 의 Id 집합 (R7 S2)
        for n in names:
            if not n.endswith('.rels'):
                continue
            base = posixpath.dirname(posixpath.dirname(n))          # ppt/slides/_rels/slide1.xml.rels → ppt/slides
            src_part = posixpath.join(base, posixpath.basename(n)[:-len('.rels')]) if posixpath.basename(n) != '.rels' else ''
            ids = set()
            for rel in _ET.fromstring(z.read(n)).iter():
                if _local(rel.tag) != 'Relationship':
                    continue
                if _attr(rel, 'Id'):
                    ids.add(_attr(rel, 'Id'))
                if _attr(rel, 'TargetMode') == 'External':
                    continue
                tgt = _attr(rel, 'Target')
                if not tgt:
                    continue
                path = posixpath.normpath(tgt.lstrip('/')) if tgt.startswith('/') else posixpath.normpath(posixpath.join(base, tgt))
                if path not in names:
                    raise ValueError(f'{n}: 관계 대상 {path} 가 zip 에 없다 (끊긴 관계)')
            rel_ids[src_part] = ids
        # R7 S2: 부품 XML 이 참조하는 r:… 속성(embed·link·id …)은 전부 그 부품 rels 에 있어야 한다
        for n in names:
            if not n.endswith('.xml') or '/_rels/' in n or n == '[Content_Types].xml':   # R8 B8: ppt/ 밖 부품(docProps …)도 r:* 를 쓴다
                continue
            try:
                root = _ET.fromstring(z.read(n))
            except _ET.ParseError:
                continue                                          # XML 자체는 오라클(python-pptx)이 판정한다
            refs = set()
            for el in root.iter():
                for k, v in el.attrib.items():
                    if k.startswith('{' + _REL_NS + '}') and v:
                        refs.add(v)
            missing = sorted(refs - rel_ids.get(n, set()))
            if missing:
                raise ValueError(f'{n}: 관계 id {missing} 를 참조하는데 rels 에 없다 (끊긴 참조)')


def _verify_package(prs):
    """패키지의 모든 부품을 읽고, 모든 내부 관계의 대상이 실재하며, 이미지 부품이 디코드되는지 확인한다."""
    pkg = prs.part.package
    seen = 0
    for part in pkg.iter_parts():
        _ = part.blob                       # 부품 바이트가 실제로 읽힌다
        seen += 1
        for rel in part.rels.values():
            if rel.is_external:
                continue
            _ = rel.target_part             # 끊긴 관계 → KeyError
        ct = str(getattr(part, 'content_type', '') or '')
        if ct.startswith('image/') and ct not in ('image/svg+xml', 'image/x-emf', 'image/x-wmf', 'image/emf', 'image/wmf'):
            try:
                from PIL import Image
            except Exception:
                raise ValueError('PIL 이 없다 — 이미지 부품을 검증할 수 없어 판정불가')
            with Image.open(io.BytesIO(part.blob)) as im:
                im.verify()                 # 헤더·구조
            with Image.open(io.BytesIO(part.blob)) as im:
                im.load()                   # R7 S3: verify() 는 픽셀을 안 푼다 — 잘린 JPEG 는 load() 에서 죽는다
    if seen == 0:
        raise ValueError('패키지 부품 0 — 판정불가')


def sha_bytes(data):
    return hashlib.sha256(data).hexdigest()


def parse(argv):
    ap = argparse.ArgumentParser(prog='safe_install.py', add_help=False)
    ap.add_argument('cand'); ap.add_argument('dest')
    ap.add_argument('--dry-run', action='store_true')
    ap.add_argument('--expect', type=int, default=None)
    ap.add_argument('--allow-shrink', action='store_true')
    ap.add_argument('--why', default='')
    try:
        ns = ap.parse_args(argv[1:])
    except SystemExit:
        print(__doc__.split('## 쓰는 법')[1]); return None
    # 🟥 `--why --allow-shrink` 처럼 다음 플래그를 값으로 먹은 경우 — 사유가 아니다
    if ns.why.startswith('--'):
        print(f'🟥 --why 의 값이 플래그처럼 보인다({ns.why!r}) — 사유가 아니다 — 판정불가'); return None
    return ns


def main(argv):
    ns = parse(argv)
    if ns is None:
        return 2
    cand, dest = ns.cand, ns.dest

    if not os.path.exists(cand) or os.path.getsize(cand) == 0:
        print(f'🟥 후보가 없거나 비었다: {cand} — 반영 안 함')
        return 1
    # R4 S2: 검사와 교체 사이의 창은 «잠금» 으로만 닫힌다 — 같은 게이트를 쓰는 다른 설치는 여기서 직렬화된다.
    #    🟥 잔여(이름으로): 이 잠금을 안 쓰는 임의의 쓰기 주체(cp·에디터)는 못 막는다. 그건 파일시스템의 성질이다.
    lock_path = dest + '.safe_install.lock'
    lock_fd = os.open(lock_path, os.O_RDWR | os.O_CREAT, 0o600)
    try:
        fcntl.flock(lock_fd, fcntl.LOCK_EX)
        return _install_locked(ns, cand, dest)
    finally:
        fcntl.flock(lock_fd, fcntl.LOCK_UN)
        os.close(lock_fd)


def _install_locked(ns, cand, dest):
    # ⑥ 한 번 읽는다 — 이 바이트가 검사되고, 이 바이트가 설치된다
    with open(cand, 'rb') as f:
        data = f.read()
    try:
        c_files, c_listed, c_reached = probe_bytes(data)
    except Exception as e:
        print(f'🟥 후보를 못 읽는다 ({type(e).__name__}: {e}) — 반영 안 함')
        return 1

    print(f'후보 : {cand}')
    print(f'       슬라이드 파일 {len(c_files)}개 · sldIdLst 항목 {c_listed}개 · rels 도달 {c_reached}개')
    # ⑤ 셋이 같아야 한다 — 목록이 0 이어도 «검사 생략» 이 아니라 «어긋남» 이다
    if not (len(c_files) == c_listed == c_reached):
        print(f'🟥 파일 수({len(c_files)}) · 목록 수({c_listed}) · 도달 수({c_reached}) 가 어긋난다 — 반영 안 함')
        return 1
    if len(c_files) == 0:
        print('🟥 슬라이드가 0장인 덱 — 반영 안 함')
        return 1

    # ── 기존본과의 비교 ────────────────────────────────────────────────────────
    # R3 S5: 끊긴 심링크는 exists() 가 False 라 «첫 설치» 로 흘렀다 — 링크 여부는 존재와 무관하게 먼저 본다
    if os.path.islink(dest):
        print(f'🟥 정본 경로가 심링크다({dest}) — 반영 안 함')
        return 1
    d_hash = None
    if os.path.exists(dest):
        try:
            with open(dest, 'rb') as f:
                d_bytes = f.read()
            d_hash = sha_bytes(d_bytes)
            d_files, d_listed, d_reached = probe_bytes(d_bytes)
        except Exception as e:
            # 🟥 축소 판정을 못 하는데 덮어쓰면 «미측정 → 통과» 다. 거부.
            print(f'🟥 기존본을 못 읽는다 ({type(e).__name__}: {e}) — 축소 여부 판정 불가 — 반영 안 함')
            return 1
        if not (len(d_files) == d_listed == d_reached):
            # R2 S1: 기존본이 «구조적으로 안 세어지면»(예: 슬라이드 부품 이름이 관례 밖) 0장으로 접혀 축소가 통과했다
            print(f'🟥 기존본의 파일 수({len(d_files)}) · 목록 수({d_listed}) · 도달 수({d_reached}) 가 어긋난다 — 축소 여부 판정 불가 — 반영 안 함')
            return 1
        print(f'정본 : {dest}\n       슬라이드 {len(d_files)}개')
        if len(c_files) < len(d_files):
            if not ns.allow_shrink:
                print(f'🟥 장이 {len(d_files)} → {len(c_files)} 로 **줄었다**. '
                      f'의도한 것이면 --allow-shrink --why "<사유>" 로 명시하라 — 반영 안 함')
                return 1
            if not ns.why.strip():
                print('🟥 --allow-shrink 에는 --why 가 필요하다 — 사유 없는 축소는 거부 — 반영 안 함')
                return 1
            print(f'⚠️ 축소를 명시 승인으로 반영한다 ({len(d_files)} → {len(c_files)}): {ns.why}')
    else:
        print(f'⚠️ 정본이 아직 없다({dest}) — 장 수 대조 UNMEASURED (첫 설치로 진행, 비교 대상 없음)')

    if ns.expect is not None and len(c_files) != ns.expect:
        print(f'🟥 --expect {ns.expect} 인데 후보는 {len(c_files)}장 — 반영 안 함')
        return 1

    if ns.dry_run:
        print('✅ 검사 통과 — --dry-run 이라 반영은 안 했다')
        return 0

    # ⑥ 검사한 바이트를 «옆에» 쓰고 확인한 뒤에 정본 자리에 넣는다 — 정본은 마지막 순간까지 무사하다
    src_hash = sha_bytes(data)
    # R2 S2: 예측 가능한 임시 경로는 미리 심어 둔 심링크가 정본을 가리킬 수 있다 — mkstemp(O_EXCL) 로 «내 것» 만 연다
    fd, tmp = tempfile.mkstemp(prefix=os.path.basename(dest) + '.safe_install.', dir=os.path.dirname(os.path.abspath(dest)) or '.')
    try:
        with os.fdopen(fd, 'wb') as f:
            f.write(data)
        with open(tmp, 'rb') as f:
            if sha_bytes(f.read()) != src_hash:
                print('🟥 임시 파일 해시가 다르다 — 쓰기 실패. 정본은 건드리지 않았다')
                return 1
        # R3 S4: 검사한 정본이 «지금도 그 정본» 인가 — 그 사이 다른 손이 덮었으면 축소 판정이 낡았다. 중단.
        if os.path.islink(dest):
            print('🟥 정본 경로가 그 사이 심링크가 됐다 — 반영 안 함'); return 1
        now_hash = sha_bytes(open(dest, 'rb').read()) if os.path.exists(dest) else None
        if now_hash != d_hash:
            print('🟥 정본이 검사 뒤에 바뀌었다(다른 쓰기) — 판정이 낡았다 — 반영 안 함. 다시 돌려라')
            return 1
        os.replace(tmp, dest)
    finally:
        if os.path.exists(tmp):
            os.remove(tmp)
    with open(dest, 'rb') as f:
        if sha_bytes(f.read()) != src_hash:
            # R8 S1: 여기서 rc=1(«반영 안 함») 을 내면 호출자가 복구를 건너뛴다 — 정본은 이미 바뀌었다.
            #    이전 정본 바이트가 손에 있으면 되돌려 놓고, 종료코드는 «반영했는데 실패» 로 따로 낸다.
            if d_hash is not None:
                try:
                    fd2, tmp2 = tempfile.mkstemp(prefix=os.path.basename(dest) + '.safe_install.restore.', dir=os.path.dirname(os.path.abspath(dest)) or '.')
                    with os.fdopen(fd2, 'wb') as g:
                        g.write(d_bytes)
                    os.replace(tmp2, dest)
                    restored = sha_bytes(open(dest, 'rb').read()) == d_hash
                except Exception as e:
                    restored = False
                print(f'🟥 반영 후 해시가 다르다 — 정본이 바뀌었다. 이전 정본({d_hash[:16]}…) 복원 {"성공" if restored else "실패 — 즉시 손으로 확인하라"}')
            else:
                print('🟥 반영 후 해시가 다르다 — 첫 설치라 되돌릴 이전 정본이 없다. 즉시 손으로 확인하라')
            return 3
    print(f'✅ 반영함 — {len(c_files)}장 · sha256 {src_hash[:16]}…')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
