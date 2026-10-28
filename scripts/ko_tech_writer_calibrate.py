#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""ko_tech_writer_calibrate.py — `ko-tech-writer` Step 2 / Step 4-b 스캔의 **판별력** known-pair.

왜 파이썬인가 (엔진 선택은 취향이 아니라 실측 결과다)
─────────────────────────────────────────────────────────
`SKILL.md` Step 4 가 허용 엔진을 명시한다: *"유니코드 인식 엔진(ripgrep · GNU grep UTF-8
로케일 · Python `re` — **`grep -P` 는 예외**)"*. 초판은 `rg` 로 고정했고 **CI 에서 죽었다** —
ubuntu-latest 에 ripgrep 이 없다(2026-08-17 실측, `HARNESS ERROR ... exited 10`).
같은 실행에서 이식성 린트도 걸렸다: 셸 파일 안의 `[가-힣]` 문자 범위는
**GNU grep C 로케일에서 exit 2 로 죽고 그 결과가 «무매치» 로 읽힌다** — 즉 fail-open.

Python `re` 는 ⓐ 세 허용 엔진 중 **어디에나 있는 유일한 것**이고 ⓑ 유니코드를 기본으로
인식하며 ⓒ 패턴이 셸 밖으로 나가 로케일 문제를 구조적으로 없앤다. **격하가 아니라
정본이 이미 허용한 등가 엔진으로의 이동**이다.

무엇을 주고 무엇을 안 주는가 — 섞지 마라
─────────────────────────────────────────────────────────
  준다     각 스캔이 **양성을 잡고 음성을 안 잡는가**(=판별력). 재현 커맨드와 실행 출력.
  안 준다  그 스캔이 **임의 문서에서 잔여 0건인가**. 그건 문서마다 따로 재는 것이다.
           ⇒ 이걸 통과했다고 «Step 2 잔여 0» 을 주장하면
              `harness_terminal_correlation_and_recommendations.md` 의 강등 사유가 그대로 재발한다.

사용: python3 ko_tech_writer_calibrate.py            (보정)
      python3 ko_tech_writer_calibrate.py --scan 문서.md   (같은 레인·필터로 문서 스캔, 줄\t레인\t본문)
      python3 ko_tech_writer_calibrate.py --check-rewrite --original 원문.md --rewrite 개고.md [--keep 목록.txt] [--listed C9,C15]
        (개고 사후 점검: 남길 곳 · 확인할 곳 · 고칠 곳 세 칸. 발상 출처: 우아콘26 세션 «AI야, 네 글 너무 AI티 나» 의 사후 Eval 3분류. 구현은 이 레포 것)

exit: 0 전 레인 판별 · 1 판별 실패(--check-rewrite 에서는 어느 칸이든 FAIL 또는 UNSURE) · 2 --check-rewrite 에서 FAIL 은 없으나 남길 곳 목록이 없어 UNMEASURED(픽스처 부재 포함 — known_unclosed.md 가 없으면 1) · 3 --scan 대상에 안 닫힌 블록 · 10 harness error(입력 오류)
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
FIX = os.path.join(HERE, "..", "plugins", "fh-commons", "skills", "ko-tech-writer", "fixtures")
POS = os.path.join(FIX, "known_positive.md")
UNC = os.path.join(FIX, "known_unclosed.md")
NEG = os.path.join(FIX, "known_negative.md")

# (라벨, 패턴) — Step 2 의 5클래스 + Step 4-b 의 2패턴.
# 🟥 여기 패턴과 SKILL.md 코드블록의 패턴은 **서로 다른 문자열이다**(예: C1 은 `" — "` 양쪽
#    공백형인데 SKILL.md 는 그 형태를 금지한다). 이 스위트가 초록이어도 **SKILL.md 쪽 패턴이
#    보정된 것은 아니다.** 두 벌인 상태이고, 그 사실이 SKILL.md §Step 2-a 에도 적혀 있다.
#
# ⚠️ 아래 판정의 인용문은 **사문(死文)이다** — 2026-08-25 에 SKILL.md 에서 삭제됐다.
#    그 파일은 이제 「앞 몇 줄」식 위치 열거를 안 쓰고 표의 `check-class` 열로 채점한다
#    (위치 서술이 행 추가 때마다 조용히 어긋났다). 판정 자체는 유효하므로 남긴다.
#    🟥 **「둘뿐」도 2026-08-25 부로 그 시점 상태다** — 같은 날 SKILL.md 코드블록에 C2(용어-머리)
#    패턴이 실렸다. C4 는 여전히 이 파일에만 있다(아래 참조).
#
# 🟥 정본의 분류가 과장이라는 것이 첫 캘리브레이션에서 드러났다. SKILL.md 는
#    "앞 다섯 줄은 기계 검출 가능" 이라 적었는데, **당시 grep 을 싣고 있던 것은
#    C1(줄표)·C5(소유 직역) 둘뿐**이고 C2·C3·C4 의 «검출 힌트» 칸은 산문 서술이었다.
#    특히 C4 는 «서술어 없는 마침» 이라는 서술뿐 패턴이 없다 — 지금도 그렇다.
LANES = [
    ("C1 줄표 이어붙임", r"(다|것|음) — "),
    ("C2 용어-머리", r"^\s*[-*]\s+\*\*[^*]+\*\* — "),
    ("C3 콜론 나열투", r"[가-힣]은: "),
    # C4: SKILL.md 에 패턴이 없다. 아래는 **후보 검출**이지 판정이 아니다
    # (SKILL.md 자신의 규율: "grep은 후보를 표시할 뿐, 남길지 판정은 문맥으로").
    # 닫힌 명사 어휘라 **recall 이 낮다** — 낮은 쪽이 과차단보다 안전한 방향이고,
    # 넓히려면 어휘를 늘리는 게 아니라 형태소 분석이 필요하다.
    ("C4 조각문(후보·닫힌 어휘)", r"(층|것|점|축|건|뿐|바|셈)\.\s*(<!--|$)"),
    # 갖추다(절차를 갖춘 검토)는 «have» 직역이 아니다 — `갖(?!추|춘|출…)` 로 뺐다 (갖춘·갖출·갖춰 형태 포함 — 첫판 `갖(?!추)` 는 «갖춘» 을 못 뺐다)(tuning doc 1건에서 2건 오탐, 보고치·n=1·독립 아님).
    ("C5 소유 직역", r"(을|를) ?(갖(?!추|춘|출|춤|춰|췄|춥)|가지(?!런|각|치))"),   # 가지런히·가지각색·가지치기 는 소유가 아니다(2축 리뷰 B1)
    ("C6 전칭 어휘", r"전부|모두|하나도|전혀|일절|예외 없이"),
    ("C6b 부정형 전칭", r"(안|못) ?(했|만들|나오|잡히)|지 않았(다|습니다)"),
    # ── 측정 클래스 (2026-10-17 수확 §4 (내부 기록) 에서 보정한 정규식)
    # 🟥 아래 히트는 전부 «후보»다. 운영자 손편집이 이 패턴들과 반대로 간 사례가 있다(그것을 등).
    ("C7 겹화살괄호·낫표(Y1/Y2)", r"[«»「」『』]", "skipfig"),
    ("C8 절 기호(Y3)", r"§"),
    # 부정 목록: 안 되/된/됩/됨/돼/함 는 정상 용례(tuning doc 1건에서 오탐 4건 전부 이 형태, 보고치·n=1·독립 아님). 그림/코드 블록 안은 편집 대상 밖.
    ("C9 안/못+동사(N3·후보·노이즈 큼)", r"(?<![가-힣])(안|못) (?!(?:되|돼|됩니다|됩니까|된다|된|됨|됐다|됐습니다|되는|되나|되면|돼요|함|함으로|함을|함이|함은|함과)(?![가-힣]))[가-힣]{1,6}", "candidate", "skipfig", "neg=1"),
    ("C10 구어 이유 어미(N4)", r"(니까요|고요|거든요|달라도요)[*.\s]*(<!--.*)?$"),
    ("C11 당신·필요로(N5)", r"당신|필요로\s*(합|하|한)"),
    ("C12 라틴 뒤 조사 띄어쓰기(N9)", r"[A-Za-z0-9)`]\s(는|은|이|가|을|를|로|로는|의|에서|에)(?![가-힣])", "skipfig"),
    # ── 2026-10-17 저녁 운영자 교정 N14·N15. 합성어/복합어로만 좁혔다(일상어 겹침은 레인에서 뺌)
    ("C13 내부 합성어(N14)", r"공격 배터리|이긴 기록|열화 방향 렌즈"),
    ("C14 시험→테스트 복합어(N15)", r"(?<![가-힣])시험\s?(환경|결과|케이스|코드|자동화|하네스|통과)"),
    # ── 경동사 «내다» 후보 (S23 변종). 🟥 UNCALIBRATED: 「판정을 내리다」는 관용구라 «내는» 도 정상 용례가 많다 → 과차단이 예상 결과.
    #    판별력을 주장하지 않는다. 잡는 형태 둘: 따옴표 명사+를 냈다 / 판정을 내는.
    ("C15 경동사 내다(후보·UNCALIBRATED)", r"['’”」»』\"`]\s?(을|를) (냈|낸|내는|낼|냅)|판정을 (냈|낸|내는|낼|냅)", "candidate", "uncalibrated", "neg=1"),
    # ── AI티 후보 클래스 C17~C21 (우아콘26 세션 «AI티 패턴» 목록에서 온 후보. 🟥 운영자 교정 쌍 없음 — 구성한 쌍으로만 판별을 잰다, 실문서 정밀도 UNMEASURED)
    ("C17 가운뎃점 밀도(한 줄 3개 이상·후보)", r"(?:·[^·\n]*){3}"),
    ("C18 대조형 «X가 아니라 Y입니다» 문말(후보)", r"[이가] 아니라 [^.\n]{1,50}(입니다|이다)[.\s]*(<!--.*)?$"),
    ("C19 분열문 «~할 점은 ~입니다»(후보)", r"(할|둘|볼) 점은 [^.\n]*(입니다|이다)"),
    ("C20 소제목 과밀(연속 3절 이상이 단락 2개 이하·후보)", None, "hdens"),
    ("C21 뻔한 추상 표현(닫힌 어휘·후보)", r"생각의 근육|배움의 리듬|켜켜이|장면을 포착|손에 쥐여? ?주"),
    # ── S7 내부 조어 후보 추출기 (함수 lane — 줄 패턴이 아니라 문서 전체를 본다)
    ("C16 내부 조어 후보(S7·후보)", None, "s7"),
]

# ── 줄 필터: 그림/차트 블록·코드 펜스 안의 줄은 편집 대상이 아니다 (lane 4번째 인자 "skipfig")
# 상태기계다: 펜스는 ``` 와 ~~~ 를 따로 닫고, [그림: …] 은 대괄호 깊이로 닫는다(`[그림: x[0] y]` 가 일찍 안 닫힌다).
# 🟥 안 닫힌 블록은 EOF 까지 문서를 삼킨다 → 통계에 open_fence/open_fig 로 남기고 scan 모드가 경고 + 비0 종료.
FIG_OPEN = re.compile(r"\[(?:그림|차트):")


class Blocks(object):
    def __init__(self):
        self.fence = None      # "`" | "~" | None
        self.fence_line = 0
        self.depth = 0         # [그림: 대괄호 깊이
        self.fig_line = 0
        self.total = self.skipped = 0


def _strip(line, st, n):
    """st 상태로 line 을 도려낸 나머지를 돌려준다."""
    ls = line.lstrip()
    if st.fence:
        if ls.startswith(st.fence * 3):
            st.fence = None
        return ""
    if st.depth == 0 and (ls.startswith("```") or ls.startswith("~~~")):
        st.fence, st.fence_line = ls[0], n
        return ""
    out, pos = [], 0
    while True:
        if st.depth > 0:
            while pos < len(line) and st.depth > 0:
                if line[pos] == "[":
                    st.depth += 1
                elif line[pos] == "]":
                    st.depth -= 1
                pos += 1
            if st.depth > 0:
                return "".join(out)
        m = FIG_OPEN.search(line, pos)
        if not m:
            out.append(line[pos:])
            return "".join(out)
        out.append(line[pos:m.start()])
        st.depth, st.fig_line, pos = 1, n, m.end()


def iter_lines(lines, skipfig, st):
    for i, raw in enumerate(lines, 1):
        line = raw.rstrip("\n")
        st.total += 1
        if skipfig:
            kept = _strip(line, st, i)
            if kept != line:
                st.skipped += 1
            line = kept
        yield i, line


def read_lines(path):
    with open(path, encoding="utf-8") as fh:
        return fh.read().split("\n")


def scan_lines(path, skipfig=False, st=None):
    """(줄번호, 줄) 를 낸다. skipfig 면 펜스 · [그림:/차트: …] 블록(여러 줄 포함)을 줄에서 도려낸다. 통계는 st 에."""
    return iter_lines(read_lines(path), skipfig, st or Blocks())


def unclosed(st):
    out = []
    if st.fence:
        out.append("code fence (%s) opened at line %d" % (st.fence * 3, st.fence_line))
    if st.depth > 0:
        out.append("[그림:/차트: block opened at line %d" % st.fig_line)
    return out


# ── S7 후보 추출기. 낱말 판정이 아니라 «첫 등장에 풀이가 있나» 만 본다. 히트는 전부 후보.
# 널리 알려진 약어는 독자층에 따라 다르다 — 기본 목록은 기술 독자 기준이고 문서마다 고쳐라(독자층 눈금이 먼저).
# `--scan FILE --s7-common LIST` 로 통째 교체한다(줄당 하나, # 주석). 기본 목록은 고정이고 픽스처가 항목 하나(MCP)를 못 박는다.
S7_COMMON = {"AI", "API", "URL", "HTTP", "HTTPS", "JSON", "YAML", "CLI", "CI", "CD", "PR", "UI", "UX",
             "LLM", "SQL", "HTML", "CSS", "OS", "ID", "QA", "PDF", "CPU", "GPU", "UTF", "SDK", "MCP"}
ACRO = re.compile(r"(?<![A-Za-z0-9])[A-Z]{2,}[A-Z0-9]*(?![A-Za-z])")
HEADING = re.compile(r"^\s{0,3}#{1,6}\s")
COMMENT = re.compile(r"<!--.*?-->", re.S)


def has_gloss(term, line, heading):
    """첫 등장 줄에 풀이가 있나. 괄호 풀이 TERM(한글…) / 한글(TERM) / TERM = / TERM은·는 … 입니다.
    제목 줄은 «제목 안에» 풀이가 있어야 한다 — 뒤 본문의 정의는 «정의 전에 제목에 썼다» 를 지우지 않는다."""
    t = re.escape(term)
    if re.search(t + r"\s?\([^)]*[가-힣][^)]*\)", line):
        return True
    if re.search(t + r"\s?\(\s?[A-Za-z][A-Za-z-]+(\s+[A-Za-z-]+)+\s?\)", line):   # CORS(Cross-Origin Resource Sharing) — 영문 풀이도 풀이다(2축 리뷰 B3)
        return True
    if re.search(r"[가-힣][가-힣 ]{1,30}\(\s?" + t + r"\s?\)", line):
        return True
    if re.search(t + r"\s?=\s?(?![0-9])", line):   # TTL=60 은 값이지 풀이가 아니다
        return True
    # 정의형: «TERM이란/란 …», 뜻·약자·줄임말을 말하는 «TERM은/는 …», 또는 설명이 6자 이상인 «TERM은/는 … 입니다»
    #   («RBAC은 필수입니다» 처럼 술어가 짧으면 정의가 아니다 — 2축 리뷰 B3. 의미 판정이라 후보 레인의 절충이다)
    if not heading and (re.search(t + r"(이란|란)\s", line)
                        or re.search(t + r"(은|는)[^.]{0,60}(약자|줄임말|뜻합니다|뜻한다|의미합니다|의미한다|말합니다|가리킵니다|가리킨다)", line)
                        or re.search(t + r"(은|는)\s[^.]{6,60}(입니다|이다)", line)):
        return True
    return False


def load_common(path):
    with open(path, encoding="utf-8") as fh:
        return {l.split("#")[0].strip() for l in fh if l.split("#")[0].strip()}


def s7_candidates(path, common=None, st=None):
    """[(용어, 줄번호, 종류)] — 종류: heading-before-gloss(제목 첫 등장·제목 안 풀이 없음) · unglossed-first-use.
    다른 레인과 같은 블록 필터(펜스·그림)를 쓴다."""
    common = S7_COMMON if common is None else common
    text = open(path, encoding="utf-8").read()
    text = COMMENT.sub(lambda m: re.sub(r"[^\n]", " ", m.group(0)), text)  # 줄번호 보존
    seen, out = set(), []
    for i, line in iter_lines(text.split("\n"), True, st or Blocks()):
        heading = bool(HEADING.match(line))
        # 코드 스팬 · URL 안의 대문자는 독자 어휘가 아니다(2축 리뷰 B2) — 같은 길이의 공백으로 지워 위치를 보존한다
        scan = re.sub(r"`[^`]*`|https?://\S+", lambda mm: " " * len(mm.group(0)), line)
        for m in ACRO.finditer(scan):
            term = m.group(0)
            if term in seen or term in common or term.rstrip("0123456789") in common:   # HTTP2 → HTTP
                continue
            seen.add(term)
            if not has_gloss(term, line, heading):
                out.append((term, i, "heading-before-gloss" if heading else "unglossed-first-use"))
    return out


def heading_dense(path, common=None, st=None):
    """C20: 소제목이 단락 2개 이하마다 붙은 절이 3개 이상 연달아 나오는 구간. [(제목, 줄번호, 종류)] — 후보 전용.
    단락 = 빈 줄로 갈린 비어 있지 않은 덩어리. 펜스·그림 블록·HTML 주석은 단락이 아니다."""
    text = open(path, encoding="utf-8").read()
    text = COMMENT.sub(lambda m: re.sub(r"[^\n]", " ", m.group(0)), text)
    secs, cur, para = [], None, False
    for i, line in iter_lines(text.split("\n"), True, st or Blocks()):
        if HEADING.match(line):
            if cur:
                secs.append(cur)
            cur, para = [i, line.strip(), 0], False
        elif line.strip():
            if cur and not para:
                cur[2] += 1
            para = True
        else:
            para = False
    if cur:
        secs.append(cur)
    out, run = [], []
    for sec in secs + [None]:
        if sec is not None and sec[2] <= 2:
            run.append(sec)
            continue
        if len(run) >= 3:
            out.extend((r[1], r[0], "sparse-section run of %d" % len(run)) for r in run)
        run = []
    return out


# 함수형 레인 레지스트리: 플래그 -> f(path, common) -> [(키, 줄번호, 종류)]
FUNC_LANES = {"s7": lambda path, common=None: s7_candidates(path, common),
              "hdens": lambda path, common=None: heading_dense(path)}


# 절대 잡히면 안 되는 토큰 — 「늘 잡는다」를 내는 죽은 계기 배제용
NEVER = r"ZZZ_absent_token_ZZZ"


def count(path, pattern, skipfig=False):
    """패턴에 매칭되는 **줄 수**. 파일 부재는 예외로 올린다(무음 0 금지)."""
    rx = re.compile(pattern, re.MULTILINE)
    return sum(1 for _, line in scan_lines(path, skipfig) if rx.search(line))


def scan(path, common=None):
    """문서 스캔 모드: 전 레인(+S7)을 같은 필터로 돌려 (rows, stats) 를 낸다 — 레인 정의의 단일 소스.
    stats = 레인별 Blocks 중 skipfig 레인의 것(모든 skipfig 레인이 같은 상태기계라 하나면 충분)."""
    rows, st = [], Blocks()
    for lane in LANES:
        label, pat, flags = lane[0], lane[1], lane[2:]
        fl = [f for f in flags if f in FUNC_LANES]
        if fl:
            for term, i, kind in FUNC_LANES[fl[0]](path, common):
                rows.append((label, i, "%s [%s]" % (term, kind)))
            continue
        rx = re.compile(pat)
        sk = "skipfig" in flags
        lst = Blocks()
        for i, line in scan_lines(path, sk, lst):
            if rx.search(line):
                rows.append((label, i, line.strip()))
        if sk:
            st = lst
    return rows, st


# ── 개고 사후 점검 (--check-rewrite) — 세 칸: 남길 곳 · 확인할 곳 · 고칠 곳.
# 🟥 기계가 하는 것은 «기록의 속성» 뿐이다: 목록에 적힌 구절이 개고에 남았나 · 숫자 집합이 움직였나 · 발화한 클래스가 줄었나.
#    무엇을 남길지의 «선정» 은 판단이고 개고 전에 사람/모델이 --keep 목록으로 적는다. 목록이 없으면 그 칸은 UNMEASURED(0 아님).
#    한글 수사(세 배)·표로 된 수치는 못 잡는다 — Step 4 의 눈 판정 잔여로 간다.
VAGUE = ("대폭", "크게", "많이", "상당히", "대거", "급격히", "훨씬", "현저히")
# 수치 토큰 = 숫자 + (천·만·억·조) + 단위. 단위를 떼어 비교하면 «3배 → 3천 배», «12% → 12배» 가 통과한다.
# 원칙(R2 교차검토 후 뒤집음): 점검기는 영리하려 들지 않는다. 확신이 없으면 UNSURE 를 낸다 — 통과가 아니다(exit 1, «사람이 볼 곳»).
# 정규화는 NFKC + 연속 공백 한 칸뿐이다. 목록 기호 제거·단위 정규화·0 정리는 하지 않는다(각각이 새 구멍이었다).
# 수치 토큰 = [부호] 숫자([.,] 묶음) + 바로 뒤 최대 4자(단위·자릿수어)를 그대로. «1.0 vs 1.00», «30 ms vs 30ms» 처럼 표기만 달라도 NEW/LOST 로 뜬다 — 표기만 달라도 사람이 본다(닫힌 방향의 비용).
NUMRX = re.compile(r"[+\-\u2212]?\d+(?:[.,]\d+)*[\w%]{0,4}")


def _norm(text):
    import unicodedata
    return re.sub(r"\s+", " ", unicodedata.normalize("NFKC", text)).strip()


def _full(path):
    """NFKC + 공백 한 칸. 코드 펜스·인라인 코드·주석·목록 기호를 건드리지 않는다 — 수치·모호 표현·남길 곳은 전부 본다."""
    return _norm(open(path, encoding="utf-8").read())


def _numtoks(text):
    from collections import Counter
    return Counter(re.sub(r"(?<=\d),(?=\d{3})", "", m.group(0)) for m in NUMRX.finditer(text))


def check_rewrite(orig_path, rw_path, keep_path=None, listed=()):
    """{칸: (상태, [항목…])}. 상태: PASS · FAIL · UNSURE(사람이 볼 곳) · UNMEASURED. 키 구절이 원문에 없거나 비어 있거나 입력 파일이 비면 ValueError."""
    o, r = _full(orig_path), _full(rw_path)
    if not o or not r:
        raise ValueError("empty original or rewrite file")
    nows = lambda t: re.sub(r"\s+", "", t)
    # ① 남길 곳 — 정확 부분문자열 → OK · 공백을 지워야만 찾으면 UNSURE · 아니면 DROPPED
    keep = []
    if keep_path:
        for raw in open(keep_path, encoding="utf-8").read().split("\n"):
            if raw.strip() and not raw.lstrip().startswith("#"):
                ph, _, why = raw.partition("\t")
                if not _norm(ph):
                    raise ValueError("empty keep phrase in row %r" % raw)
                keep.append((_norm(ph), why.strip()))
    items, bad, unsure = [], False, False
    for ph, why in keep:
        if nows(ph) not in nows(o):
            raise ValueError("keep phrase not in the original: %r" % ph)
        if ph in r:
            items.append("KEEP-OK %s" % ph)
        elif nows(ph) in nows(r):
            items.append("KEEP-UNSURE %s (found only with whitespace removed -- a person looks)" % ph)
            unsure = True
        elif why:
            items.append("KEEP-LISTED %s -- %s" % (ph, why))
        else:
            items.append("KEEP-DROPPED %s" % ph)
            bad = True
    keep_state = "UNMEASURED" if not keep else ("FAIL" if bad else "UNSURE" if unsure else "PASS")
    if not keep:
        items.append("NO-KEEP-LIST (not measured; this is not a pass)")
    # ② 확인할 곳 — 다중집합 비교, 코드 안 수치도 센다
    to, tr = _numtoks(o), _numtoks(r)
    items2, bad2 = [], False
    for t in sorted((tr - to).elements()):
        items2.append("NUMBER-NEW %s" % t)
        bad2 = True
    for t in sorted((to - tr).elements()):
        items2.append("NUMBER-LOST %s" % t)
        bad2 = True
    for t in sorted((to & tr).elements()):
        items2.append("NUMBER-KEPT %s" % t)
    for v in VAGUE:
        if v in o:
            if v in r:
                items2.append("VAGUE-KEPT %s" % v)
            elif v in listed:
                items2.append("VAGUE-LISTED %s (author decision via --listed)" % v)
            else:
                # 모호 수량은 본문에 그대로 둔다 — 자리표시자나 숫자로 바꾸는 것도 소실이다. 면죄는 --listed 로 이름을 적는 것(저자 결정)뿐.
                items2.append("VAGUE-LOST %s (removed from the body; only --listed excuses it)" % v)
                bad2 = True
    # ③ 고칠 곳
    def per_lane(path):
        out = {}
        for label, _, _ in scan(path)[0]:
            out[label.split()[0]] = out.get(label.split()[0], 0) + 1
        return out
    lo, lr = per_lane(orig_path), per_lane(rw_path)
    items3, bad3 = [], False
    for lid in sorted(set(lo) | set(lr), key=lambda x: int(re.sub(r"\D", "", x))):
        a, b = lo.get(lid, 0), lr.get(lid, 0)
        tag = "FIXED" if a and not b else "REDUCED" if a > b > 0 else "SAME" if a and a == b else "WORSE" if a and b > a else "NEW"
        if tag in ("SAME", "WORSE", "NEW", "REDUCED") and lid not in listed:
            bad3 = True
            tag += "-UNLISTED"
        elif tag in ("SAME", "WORSE", "NEW", "REDUCED"):
            tag += "-LISTED"
        items3.append("%s %s %d->%d" % (tag, lid, a, b))
    if not lo:
        items3.append("NO-CLASS-FIRED in the original (nothing to resolve)")
    return {"keep": (keep_state, items), "verify": ("FAIL" if bad2 else "PASS", items2),
            "fix": ("FAIL" if bad3 else "PASS", items3)}


def rw_edge_cases():
    """[(이름, 통과여부)] — --check-rewrite 의 경계 사례(R1 교차검토). 각 사례는 기대한 칸의 상태까지 단언한다."""
    import tempfile
    out = []
    with tempfile.TemporaryDirectory() as d:
        def w(name, text):
            fp = os.path.join(d, name)
            with open(fp, "w", encoding="utf-8") as fh:
                fh.write(text)
            return fp

        def run(o, r, keep=None, listed=()):
            try:
                return check_rewrite(w("o.md", o), w("r.md", r), w("k.txt", keep) if keep is not None else None, listed)
            except ValueError:
                return "ERR"

        def v(res, kind=None):
            if res == "ERR":
                return "ERR"
            st, items = res["verify"]
            return st if kind is None else (st, any(x.startswith(kind) for x in items))

        out.append(("S1 unit 3배 -> 3천 배 fails (NUMBER-NEW/LOST)", v(run("속도는 3배 빨라졌습니다.", "속도는 3천 배 빨라졌습니다."), "NUMBER-") == ("FAIL", True)))
        out.append(("S1 unit 12% -> 12배 fails", v(run("오류율은 12% 입니다.", "오류율은 12배 입니다.")) == "FAIL"))
        out.append(("S1 control: same number tokens in another order pass", v(run("오류율은 12% 입니다. 지연은 30ms 입니다.", "지연은 30ms 입니다. 오류율은 12% 입니다.")) == "PASS"))
        out.append(("S2 number inside a fenced block is seen", v(run("본문\n```\nx = 1\n```\n", "본문\n```\nx = 2\n```\n"), "NUMBER-") == ("FAIL", True)))
        out.append(("S3 empty keep phrase is a harness error", run("본문입니다.", "본문입니다.", "\t사유\n") == "ERR"))
        out.append(("S3 empty rewrite is a harness error", run("본문입니다.", "   \n") == "ERR"))
        out.append(("S3 empty original is a harness error", run("", "본문입니다.") == "ERR"))
        saved, rcs = sys.stderr, []
        sys.stderr = open(os.devnull, "w")
        try:
            rcs = [check_main(["--original", w("o.md", "가"), "--rewrite", w("r.md", "가"), "--listed"]),
                   check_main(["--original", w("o.md", "가"), "--rewrite", w("r.md", "가"), "--keep"]),
                   check_main(["--original", w("o.md", "가"), "--rewrite"])]
        finally:
            sys.stderr.close()
            sys.stderr = saved
        out.append(("S4 a flag missing its value exits 10", rcs == [10, 10, 10]))
        ph = run("처리 시간이 크게 줄었습니다.", "처리 시간이 [확인 필요: 전후 수치] 줄었습니다.")
        far = run("처리 시간이 대폭 줄었습니다.\n다른 문장입니다.", "처리 시간이 줄었습니다.\n다른 문장은 확인 필요.")
        listed_ok = run("처리 시간이 크게 줄었습니다.", "처리 시간이 줄었습니다.", listed=("크게",))
        out.append(("S5 a placeholder replacing a vague word is VAGUE-LOST", v(ph, "VAGUE-LOST") == ("FAIL", True)))
        out.append(("S5 a marker elsewhere does not excuse VAGUE-LOST", v(far, "VAGUE-LOST") == ("FAIL", True)))
        out.append(("S5 control: naming the word in --listed excuses it", v(listed_ok) == "PASS"))
        out.append(("A1 a wrap inside a Korean word is KEEP-UNSURE (not PASS, not DROPPED)", run("요술램프 같은 도구입니다.", "요술\n램프 같은 도구입니다.", "요술램프\n")["keep"][0] == "UNSURE"))
        out.append(("A2 1.0 vs 1.00 shows as NEW/LOST (a person looks)", v(run("정확도 1.0 입니다.", "정확도 1.00 입니다.")) == "FAIL"))
        out.append(("A2 control: 1,000 == 1000 and full-width digits normalise by NFKC/commas", v(run("건수 1,000건 １２건", "건수 1000건 12건")) == "PASS"))
        # R2 (codex): 정규화 수리가 만든 구멍 다섯 — 각 사례는 PASS 로 끝나면 안 된다
        k = run("데이터가 쌓입니다.", "데이터 가공이 쌓입니다.", "데이터가\n")
        out.append(("R2-1 keep across a word boundary is UNSURE, never PASS", k != "ERR" and k["keep"][0] == "UNSURE"))
        out.append(("R2-2 a fabricated line-start number fails", v(run("1. 첫째\n2. 둘째\n", "999. 첫째\n2. 둘째\n")) == "FAIL"))
        out.append(("R2-3 a dropped sign (3 vs -3) fails", v(run("변화량은 3 입니다.", "변화량은 -3 입니다.")) == "FAIL"))
        out.append(("R2-4 a detached unit (30ms vs 30  ms) fails", v(run("지연은 30ms 입니다.", "지연은 30  ms 입니다.")) == "FAIL"))
        k5 = run("ABC 도구를 씁니다.", "ABC 도구를 씁니다.", "ＡＢＣ\n")
        out.append(("R2-5 keep phrases are NFKC-normalised like the documents", k5 != "ERR" and k5["keep"][0] == "PASS"))
        same = run("지연은 30ms 입니다. 크게 줄었습니다.", "지연은 30ms 입니다. 크게 줄었습니다.", "크게 줄었습니다\n")
        out.append(("R2 control: identical text passes every bucket", same != "ERR" and all(same[b][0] == "PASS" for b in same)))
    return out


BUCKET_KO = {"keep": "남길 곳", "verify": "확인할 곳", "fix": "고칠 곳"}


def check_main(args):
    opts, it = {}, iter(args)
    for a in it:
        if a in ("--original", "--rewrite", "--keep", "--listed"):
            val = next(it, None)
            if val is None or val.startswith("--"):
                sys.stderr.write("usage error: %s needs a value\n" % a)
                return 10
            opts[a] = val
        else:
            opts["bad"] = a
    if "bad" in opts or not opts.get("--original") or not opts.get("--rewrite"):
        sys.stderr.write("usage: ko_tech_writer_calibrate.py --check-rewrite --original F --rewrite F [--keep LIST] [--listed C9,C15]\n")
        return 10
    listed = tuple(x.strip() for x in (opts.get("--listed") or "").split(",") if x.strip())
    try:
        res = check_rewrite(opts["--original"], opts["--rewrite"], opts.get("--keep"), listed)
    except (OSError, UnicodeDecodeError, ValueError) as e:
        sys.stderr.write("harness error: %s\n" % e)
        return 10
    for k in ("keep", "verify", "fix"):
        state, items = res[k]
        print("BUCKET %s(%s) %s" % (BUCKET_KO[k], k, state))
        for x in items:
            print("  " + x)
    states = [res[k][0] for k in res]
    return 1 if ("FAIL" in states or "UNSURE" in states) else 2 if "UNMEASURED" in states else 0


def scan_main(args):
    """--scan FILE [--s7-common LIST]. 입력 오류는 stderr + 10, 안 닫힌 블록은 경고 + 3."""
    path = common_path = None
    it = iter(args)
    for a in it:
        if a == "--s7-common":
            common_path = next(it, None)
            if not common_path:
                sys.stderr.write("usage error: --s7-common needs a file\n")
                return 10
        elif path is None and not a.startswith("--"):
            path = a
        else:
            sys.stderr.write("usage: ko_tech_writer_calibrate.py --scan FILE [--s7-common LIST]\n")
            return 10
    if path is None:
        sys.stderr.write("usage: ko_tech_writer_calibrate.py --scan FILE [--s7-common LIST]\n")
        return 10
    try:
        common = load_common(common_path) if common_path else None
        rows, st = scan(path, common)
    except (OSError, UnicodeDecodeError) as e:
        sys.stderr.write("harness error: cannot scan %s: %s\n" % (path, e))
        return 10
    print("scanned: %s %d lines" % (path, st.total))
    print("s7-common: %s (%d entries)" % (common_path or "default", len(common if common is not None else S7_COMMON)))
    print("skipped: %d lines (fence/fig); filter applies to C7, C9, C12, C16 only" % st.skipped)
    for label, i, text in rows:
        print("%d\t%s\t%s" % (i, label, text[:200]))
    bad = unclosed(st)
    if bad:
        for b in bad:
            sys.stderr.write("WARNING unclosed block at EOF: %s -- everything after it was skipped; C7/C9/C12/C16 results are NOT valid\n" % b)
        return 3
    return 0


def main():
    if len(sys.argv) > 1:
        if sys.argv[1] == "--scan":
            return scan_main(sys.argv[2:])
        if sys.argv[1] == "--check-rewrite":
            return check_main(sys.argv[2:])
        sys.stderr.write("usage: ko_tech_writer_calibrate.py [--scan FILE [--s7-common LIST] | --check-rewrite ...]\n")
        return 10
    for p in (POS, NEG):
        if not os.path.isfile(p):
            sys.stderr.write("harness error: fixture missing %s\n" % p)
            return 10

    print("engine: python%d.%d re (unicode-aware)"
          % (sys.version_info[0], sys.version_info[1]))
    print("known-positive: %s" % os.path.relpath(POS, os.path.join(HERE, "..")))
    print("known-negative: %s" % os.path.relpath(NEG, os.path.join(HERE, "..")))
    print("")

    npass = nfail = 0
    ncand = []
    for lane in LANES:
        label, pat, flags = lane[0], lane[1], lane[2:]
        candidate = "candidate" in flags
        fl = [f for f in flags if f in FUNC_LANES]
        if candidate or "s7" in flags:
            ncand.append(label.split()[0] + (" UNCALIBRATED" if "uncalibrated" in flags else ""))
        if fl:
            p, n = len(FUNC_LANES[fl[0]](POS)), len(FUNC_LANES[fl[0]](NEG))
            if p >= 1 and n == 0:
                print("OK   %s -- positive %d / negative 0 (discriminates the constructed pair; "
                      "precision on real documents UNMEASURED, hits need per-case judgment)" % (label, p))
                npass += 1
            else:
                print("FAIL %s -- positive %d / negative %d (needs positive >= 1 and negative 0)" % (label, p, n))
                nfail += 1
            continue
        sk = "skipfig" in flags
        p = count(POS, pat, sk)
        n = count(NEG, pat, sk)
        want = [int(f[4:]) for f in flags if f.startswith("neg=")]
        if want and n != want[0]:
            # 후보 레인도 음성 수는 고정한다: 문서화된 과차단 줄 «만» 걸려야 한다. 새 오탐(또는 부정 목록 소실)이 «예상된 과차단» 에 묻히지 않게.
            print("FAIL %s -- negative count %d != documented over-block %d (a new false alarm, or the exclusion was lost)"
                  % (label, n, want[0]))
            nfail += 1
        elif "uncalibrated" in flags:
            if p >= 1 and n >= 1:
                print("OK   %s -- UNCALIBRATED CANDIDATE: positive %d / negative %d (idiom over-block shown; "
                      "no discrimination claimed)" % (label, p, n))
                npass += 1
            else:
                print("FAIL %s -- uncalibrated candidate lane lost its positive or its documented over-block "
                      "(positive %d / negative %d)" % (label, p, n))
                nfail += 1
        elif candidate:
            # 후보 전용 레인: 정상 용례를 잡는 과차단이 **예상된 결과**다. 판별(discriminates)을 주장하지 않는다.
            if p >= 1 and n >= 1:
                print("OK   %s -- CANDIDATE-ONLY: positive %d / negative %d (expected over-block; "
                      "does NOT discriminate, hits need per-case judgment)" % (label, p, n))
                npass += 1
            else:
                print("FAIL %s -- candidate lane lost its documented over-block or positive "
                      "(positive %d / negative %d)" % (label, p, n))
                nfail += 1
        elif p >= 1 and n == 0:
            print("OK   %s -- positive %d / negative 0 (discriminates)" % (label, p))
            npass += 1
        elif p < 1:
            print("FAIL %s -- MISSES the positive (positive %d). A blind instrument." % (label, p))
            nfail += 1
        else:
            print("FAIL %s -- HITS the negative (negative %d). Over-blocks; no discrimination."
                  % (label, n))
            nfail += 1

    # 블록 필터 레인 — 안 닫힌 [그림: 이 «보고» 되는가(양성 픽스처) · 정상 픽스처(~~~ 펜스·중첩 대괄호 포함)는 닫힌 채 끝나는가
    if not os.path.isfile(UNC):
        print("FAIL BLOCK unclosed fixture missing -- %s" % UNC)
        nfail += 1
    else:
        su, sn = Blocks(), Blocks()
        list(scan_lines(UNC, True, su))
        list(scan_lines(NEG, True, sn))
        if unclosed(su) and not unclosed(sn) and sn.skipped >= 1:
            print("OK   BLOCK unclosed-block report -- positive: %s / negative: closed, %d lines skipped (discriminates)"
                  % ("; ".join(unclosed(su)), sn.skipped))
            npass += 1
        else:
            print("FAIL BLOCK unclosed-block report -- positive %r / negative %r (skipped %d)"
                  % (unclosed(su), unclosed(sn), sn.skipped))
            nfail += 1

    # 개고 사후 점검 레인 — 세 쌍이 각자 «자기 칸만» 빨개져야 한다. 컨트롤 값(키 구절·숫자·발화 클래스 수)을 같이 찍는다: 죽은 점검기는 깨끗한 개고의 PASS 와 똑같이 생겼다.
    rwd = os.path.join(FIX, "rewrite_")
    exp = [("clean", ("PASS", "PASS", "PASS")),
           ("drops_metaphor", ("FAIL", "PASS", "PASS")),
           ("invents_number", ("PASS", "FAIL", "PASS"))]
    try:
        for name, want in exp:
            res = check_rewrite(rwd + "original.md", rwd + name + ".md", rwd + "keep.txt")
            got = tuple(res[k][0] for k in ("keep", "verify", "fix"))
            ctl = (sum(1 for x in res["keep"][1] if x.startswith("KEEP-")),
                   sum(1 for x in res["verify"][1] if x.startswith("NUMBER-")),
                   sum(1 for x in res["fix"][1] if x.startswith(("FIXED", "SAME", "NEW", "WORSE", "REDUCED"))))
            if got == want and min(ctl) >= 1:
                print("OK   RW rewrite-check %s -- keep/verify/fix = %s (controls: keep items %d, numbers %d, classes fired %d)"
                      % (name, "/".join(got), ctl[0], ctl[1], ctl[2]))
                npass += 1
            else:
                print("FAIL RW rewrite-check %s -- got %s want %s (controls %s; a control of 0 means the checker saw nothing)"
                      % (name, "/".join(got), "/".join(want), ctl))
                nfail += 1
    except (OSError, ValueError) as e:
        print("FAIL RW rewrite-check -- fixture/keep list problem: %s" % e)
        nfail += 1

    # 개고 점검 R1 교차검토 수리 레인 — 입력 문자열을 임시 파일로 써서 같은 check_rewrite/check_main 을 부른다. 기대는 «그 칸만» 정확히 맞아야 한다.
    for name, ok in rw_edge_cases():
        if ok:
            print("OK   RW2 %s" % name)
            npass += 1
        else:
            print("FAIL RW2 %s" % name)
            nfail += 1

    # META 컨트롤 1 — 없는 토큰이 양쪽 다 0인가 (계기가 «늘 잡는다» 를 내지 않는다)
    if count(POS, NEVER) == 0 and count(NEG, NEVER) == 0:
        print("OK   META control -- an absent token matches nothing in either fixture")
        npass += 1
    else:
        print("FAIL META control -- an absent token matched. Do not trust this suite.")
        nfail += 1

    # META 컨트롤 2 — 두 픽스처가 실제로 다른 파일인가
    with open(POS, encoding="utf-8") as a, open(NEG, encoding="utf-8") as b:
        if a.read() != b.read():
            print("OK   META control -- positive/negative fixtures differ")
            npass += 1
        else:
            print("FAIL META control -- the two fixtures are identical; results are meaningless")
            nfail += 1

    print("")
    if nfail == 0:
        ndisc = npass - len(ncand)
        print("CALIBRATED (%d discriminating incl. 2 meta controls; %d candidate-only: %s) -- Step 2 classes + Step 4-b discriminate; candidate lanes do not."
              % (ndisc, len(ncand), ", ".join(ncand)))
        print("  NOT proven: 'zero residue' in any real document. That is measured per document.")
        print("  C7-C12 positives are the harvest's own 'before' sentences (re-built short); C13-C14 positives are constructed (no harvest pair), so")
        print("  false-positive rate on out-of-distribution text is UNMEASURED. C9 over-blocks by design.")
        print("  Citing this suite as evidence of 'zero residue' reproduces the very downgrade")
        print("  recorded in harness_terminal_correlation_and_recommendations.md.")
        return 0
    print("NOT CALIBRATED (%d/%d failed)" % (nfail, npass + nfail))
    return 1


if __name__ == "__main__":
    sys.exit(main())
