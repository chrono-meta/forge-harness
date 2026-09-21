#!/usr/bin/env python3
"""docs/map 의 archify 산출 HTML 에 붙이는 재생성-후 후처리 — 두 가지를 하고 하나를 지킨다.

  (1) reader-width floor  뷰어의 `MIN_READER_WIDTH = 960` 상수를 뷰포트 비례 하한으로 바꾼다.
      archify 뷰어는 «스크롤 없이 다 담기» 를 목표로 폭을 줄이는데, 세로 예산이 모자라면
      1728px 화면에서도 960px 로 바닥을 친다(실측 2026-09-06: 1728×950 → 960). 지도는
      «한 화면에 담기» 보다 «넓게 읽기» 가 목적이라 하한을 화면 비례로 올린다.
      실측 효과(1728×950, fh_process): 960 → 1382.  가로 오버플로 없음(1280×800 → 1216).

  (2) SVG 재생성      HTML 안의 유일한 <svg> + 뷰어 <style> 을 심은 정적 벡터를 다시 만든다.
      기존 커밋본 두 장(fh_trust.dataflow.svg · fh_assets.architecture.svg)에 대해
      바이트 동일 재현을 known-pair 로 확인하고 만든 추출기다.

  (3) 깜빡임 계약 검사  재생성된 HTML 이 «깜빡임 억제» 두 가지를 아직 들고 있나만 본다(쓰지 않는다).
      ⓐ 첫 페인트 전 테마 해소 — `<html data-theme=…>` 로 시작하는 문서는 `<body>` **앞에서**
        테마를 확정해야 한다. 안 그러면 라이트 선호 사용자에게 어두운 한 프레임이 스친다.
      ⓑ 펄스 기본 정지 — `.pulse-dot` 에 애니메이션을 **거는** 규칙은 셀렉터에
        `data-motion-capable` 게이트를 달고 있어야 한다. 게이트 없이 걸리면 부팅 중에도
        reduced-motion 에서도 점이 깜빡인다.
      🟥 **둘 다 «있으면 검사, 없으면 통과»다.** 문서가 `data-theme` 를 아예 안 쓰거나 점을
      뛰게 하는 규칙이 아예 없으면 깜빡일 것도 없다 — 없는 것을 요구하면 다른 archify
      다이어그램 종류를 과차단하고, 과차단은 override 를 훈련시킨다(CLAUDE.md §Integration branch).
      🟥 그리고 이 검사는 «실제로 안 깜빡인다» 의 증거가 아니다 — **기록의 형태**만 본다.
      실물은 사람이 라이트 모드로 하드 리로드해서 눈으로 본다(`docs/map/FH_MAP.md` §그림·재생성).

fail-closed: 기대한 리터럴이 없으면(렌더러 버전 드리프트) 종료코드 3 으로 멈춘다 —
조용히 «패치할 게 없었다» 로 넘어가면 다음 발행이 옛 동작으로 나간다.

  usage: map_postprocess.py <file.html> [...]   실제 적용
         map_postprocess.py --check <file.html> [...]   적용 여부만 보고(쓰기 없음)
exit: 0 적용/이미적용  ·  3 리터럴 부재(드리프트)  ·  4 인자/파일 오류
"""
import re
import sys

OLD = 'var MIN_READER_WIDTH = 960;'
NEW = ('var MIN_READER_WIDTH = Math.min(1440, '
       'Math.max(960, Math.round(window.innerWidth * 0.80)));')

# ── 깜빡임 억제 계약 (검사만 한다 — 이 스크립트는 이걸 고치지 않는다) ───────────
# 리터럴 출처: archify 2.17.0-dev.1 산출본(docs/map/*.html, PR #720 에 실려 들어왔다).
THEME_DECL = re.compile(r'<html\b[^>]*\bdata-theme\s*=', re.I)
# 따옴표 종류는 렌더러 취향이라 둘 다 받는다 — 픽스처가 큰따옴표로 쓰여 L1 이 빨개진 자리다.
THEME_APPLY = re.compile(r'''setAttribute\(\s*['"]data-theme['"]''')
MOTION_GATE = 'data-motion-capable'
PULSE_SEL = '.pulse-dot'
PULSE_HIT = re.compile(r'\.pulse-dot\b')
ANIM_DECL = re.compile(r'\banimation(?:-name)?\s*:\s*([^;}]+)')
STYLE_BLOCK = re.compile(r'<style[^>]*>(.*?)</style>', re.S)


def pulse_rules(css: str):
    """`.pulse-dot` 가 실제로 받는 규칙을 (셀렉터 조각, 본문) 으로 돌려준다.

    🟥 CSS 한 벌을 `([^{}]*)\\.pulse-dot…` 로 훑지 않는다 — 그 모양은 문서 길이에 제곱으로
    드는 역추적을 만든다(실측: 734 KB 한 장에 22 초, 세 장이면 한 번 돌릴 때마다 1 분).
    리터럴을 먼저 선형으로 찾고 그 주변만 잘라 본다.
    """
    out, seen = [], set()
    for m in PULSE_HIT.finditer(css):
        brace = css.find('{', m.end())
        if brace < 0 or brace in seen:
            continue                      # 한 규칙이 `.pulse-dot` 을 여러 번 담아도 한 번만 본다
        seen.add(brace)
        head = max(css.rfind('}', 0, m.start()), css.rfind('{', 0, m.start()))
        selectors = css[head + 1:brace]
        close = css.find('}', brace + 1)
        body = css[brace + 1:close] if close > 0 else css[brace + 1:]
        # 🟥 조각을 «첫 하나» 로 접지 않는다 — `html[…capable] .pulse-dot, .pulse-dot { … }` 처럼
        #    한 목록 안에 게이트 있는 조각과 없는 조각이 같이 있으면 앞엣것만 보고 통과한다.
        parts = [part.strip() for part in selectors.split(',') if PULSE_SEL in part]
        for part in (parts or [selectors.strip()]):
            out.append((part, body))
    return out


def flash_contract(html: str):
    """어긋난 항목을 문장으로 돌려준다. 빈 리스트 = 계약 충족(또는 해당 없음)."""
    bad = []
    if THEME_DECL.search(html):
        m = THEME_APPLY.search(html)
        i_theme = m.start() if m else -1
        i_body = html.find('<body')
        if i_theme < 0:
            bad.append('<html data-theme> is declared but setAttribute(data-theme) never runs — '
                       'the declared theme is the only one a reader gets')
        elif 0 <= i_body < i_theme:
            # 🟥 기준은 <body> 이지 <head> 안의 <style> 이 아니다. 머리의 스타일은 아무것도
            #    안 그리고, 그 뒤에 인라인 스크립트가 와도 페인트는 여전히 그 스크립트 뒤다.
            #    <style> 을 기준으로 두면 무해한 렌더러 변경을 막는다(과차단 → override 훈련).
            bad.append('theme is applied only after <body> starts — the first frame can paint '
                       'with the declared (dark) theme before the reader preference lands')
    # 🟥 «어느 규칙이 점을 **뛰게 하나**» 만 본다 — 정지시키는 규칙이 몇 개든 세지 않는다.
    #    초판은 «게이트 없는 규칙 중 하나라도 animation: none 이면 통과» 였고, 되돌림 프로브가
    #    그것을 공허하게 통과시켰다: reduced-motion 미디어쿼리 안의 `animation: none !important`
    #    가 기본 규칙 대신 그 조건을 채워서, 기본값을 `pulse 2s infinite` 로 바꿔도 초록이었다.
    css = '\n'.join(STYLE_BLOCK.findall(html))
    for selector, body in pulse_rules(css):
        runs = [v.strip() for v in ANIM_DECL.findall(body)
                if v.strip() and not v.strip().startswith('none')]
        if runs and MOTION_GATE not in selector:
            where = selector or '(no selector — the default rule)'
            bad.append(f'a .pulse-dot rule starts an animation without the {MOTION_GATE} '
                       f'gate: {where} {{ animation: {runs[0]} }} — the dot blinks before '
                       'the motion governor boots, and keeps blinking under reduced-motion')
    return bad


def build_svg(html: str) -> str:
    styles = re.findall(r'<style[^>]*>(.*?)</style>', html, re.S)
    if len(styles) != 1:
        raise ValueError(f'expected exactly 1 <style> block, got {len(styles)}')
    m = re.search(r'<svg\b.*?</svg>', html, re.S)
    if not m:
        raise ValueError('no <svg> block found')
    svg = m.group(0).replace('<svg ', '<svg xmlns="http://www.w3.org/2000/svg" ', 1)
    tag_end = svg.index('>') + 1
    return ('<?xml version="1.0" encoding="UTF-8"?>\n'
            + svg[:tag_end] + '<style><![CDATA[\n' + styles[0] + '\n]]></style>'
            + svg[tag_end:])


def process(path: str, check_only: bool) -> int:
    try:
        html = open(path, encoding='utf-8').read()
    except OSError as exc:
        print(f'ERROR  {path}: {exc}', file=sys.stderr)
        return 4
    has_old, has_new = OLD in html, NEW in html
    problems = []
    if not has_old and not has_new:
        problems.append('neither the original nor the patched reader-width literal is '
                        'present — archify version drift')
    problems += flash_contract(html)
    if problems:
        for p in problems:
            print(f'DRIFT  {path}: {p}', file=sys.stderr)
        print(f'DRIFT  {path}: patch NOT applied, nothing written', file=sys.stderr)
        return 3
    if check_only:
        print(f'{"PATCHED" if has_new else "UNPATCHED"}  {path}')
        return 0
    patched = html.replace(OLD, NEW) if has_old else html
    svg_path = re.sub(r'\.html$', '.svg', path)
    # 쓰기 전에 둘 다 만들어 둔다 — 중간에 실패하면 «반쯤 적용된 트리»가 남고,
    # 특히 open(...,'w') 은 예외가 나기 전에 이미 대상을 0바이트로 잘라 놓는다(L6 가 잡았다).
    try:
        svg = build_svg(patched)
    except ValueError as exc:
        print(f'ERROR  {svg_path}: {exc} — nothing written', file=sys.stderr)
        return 3
    if has_old:
        open(path, 'w', encoding='utf-8').write(patched)
        print(f'PATCH  {path}: reader-width floor -> viewport-proportional')
    else:
        print(f'SKIP   {path}: already patched (idempotent)')
    open(svg_path, 'w', encoding='utf-8').write(svg)
    print(f'SVG    {svg_path}')
    return 0


def main(argv):
    check_only = '--check' in argv
    files = [a for a in argv if not a.startswith('--')]
    if not files:
        print(__doc__, file=sys.stderr)
        return 4
    worst = 0
    for path in files:
        worst = max(worst, process(path, check_only))
    return worst


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
