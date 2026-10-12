#!/usr/bin/env python3
# generated_harness_check.py — 외부 생성기(예: revfactory/harness «하네스 구성해줘»)가 써 넣은
# 하네스를 FH 가 받아서 검사하는 «뒷단» 기계 검사기.
#
# 사용:  python3 scripts/generated_harness_check.py <대상 디렉터리> [--json] [--exclude-skill NAME ...]
#        python3 scripts/generated_harness_check.py --selftest
# 읽는 것: CLAUDE.md · .claude/agents/*.md · .claude/skills/*/SKILL.md ·
#          .claude/settings.json · .claude/settings.local.json
# 생성기 자신의 스킬(harness · harness-evolve)은 검사 대상에서 뺀다(--exclude-skill 로 추가).
#
# 판정 = 종료코드 (출력 파싱 아님):
#   0 PASS          사람 확인 항목 없음 (경고·정보는 있을 수 있다)
#   1 HUMAN_REVIEW  H1/H2 가 하나 이상 — 비가역 권한이 «열려 있다»
#   3 HARNESS_ERROR 대상 없음 · 읽기 실패 · JSON 깨짐 · frontmatter 파싱 실패 ·
#                   검사할 하네스 자체가 없음.  «못 읽음» 을 PASS 나 0건으로 접지 않는다.
#
# 사람 확인:  H1 settings 의 permissions.allow 에 비가역 패턴 · H2 지침 본문이 비가역 동작을
#             «확인 없이/알아서» 류와 같은(또는 바로 다음) 문장에서 허용.
# 경고(rc 무영향): W1 읽기 전용 주장 vs 쓰기·Bash 도구(tools 없음=전부 상속 포함) · W2 tools 줄 없음(전부 상속) · W7 스킬 파일명이 SKILL.md 아님 ·
#             W4 죽은 참조 · W6 스킬 description 비어 있음.
# 정보:       W3 Bash 범위 제한 서술 없음 · W5 Done When 없음(FH 기준, 생성기 결함 아님) ·
#             아직 없는 입출력 경로(자리표시자·디렉터리·_workspace·런타임 산출 파일명).
#
# 🟥 정직한 한계 — 막는 것은 «기록의 형태»이지 의도가 아니다. 전부 정규식이라 우회된다
#    (철자 변형 · 다른 언어 · 두 문장 건너 허용 · 다른 프로그램을 거친 실행 —
#    `xargs git push` · `sh -c '…'` · 스크립트·별칭 — · 따옴표/이스케이프/서브셸 같은 셸 문법 구석).
#    셸 문법 우회는 이름 붙인 잔여다: cross-family 리뷰 R1~R4 가 라운드마다 한 구석씩 찾았고
#    (R5 «회귀만» 에서 0 으로 수렴), «우회를 다 찾는다» 는 정규식 검사기로는 수렴하지 않는다.
#    서브커맨드 판정은 토큰 집합이라 `git log --grep push` 같은 무해 명령도 걸린다 — 의도된 과차단.
#    PASS 는 «사람 확인 항목을 못 찾았다» 일 뿐 «안전하다» 가 아니다. 이 검사기는 사람의 확인을
#    대체하지 않고, 비가역 권한을 열지 말지의 결론은 언제나 사람 몫이다. 부정문 판정(금지문 제외)은
#    «같은 문장 안 부정어» 휴리스틱이라 «하지 않는다고는 하나 결국 한다» 류를 놓칠 수 있다.
#    표준 라이브러리만 사용 (python 3.9 호환).
import fnmatch
import json
import os
import re
import sys

RC_PASS, RC_HUMAN, RC_ERROR = 0, 1, 3

GENERATOR_SKILLS = ("harness", "harness-evolve")

# ── H1: permissions.allow 의 비가역 패턴 ─────────────────────────────────
# (라벨, 정규식) — Bash(...) 안쪽 문자열에 적용한다. 철자가 아니라 «동작» 기준으로 넓게 잡는다.
H1_PATTERNS = [
    ("rm (삭제)",                 r"\brm\b"),
    ("git push",                  r"\bgit\s+push\b"),
    ("git reset --hard",          r"\bgit\s+reset\b.*--hard"),
    ("git branch -d/-D",          r"\bgit\s+branch\b(?:\s+\S+)*\s+(?:-[A-Za-z]*[dD]\b|--delete\b)"),
    ("git clean -f",              r"\bgit\s+clean\b.*-[A-Za-z]*f"),
    ("gh pr merge",               r"\bgh\s+pr\s+merge\b"),
    ("gh repo delete",            r"\bgh\s+repo\s+delete\b"),
    ("npm publish",               r"\bnpm\s+publish\b"),
    ("twine upload",              r"\btwine\s+upload\b"),
    # git/gh/npm/twine 접두 전체 허용(`git:*`, `git *`)은 위 동작들을 간접으로 연다.
    ("광범위 접두 허용",           r"^(?:git|gh|npm|twine)(?:\s+\*|:\*|\*)?$"),
]
_H1_RE = [(lab, re.compile(p)) for lab, p in H1_PATTERNS]


# 비가역 명령 표본 — 허용 항목 안쪽의 `*` 와일드카드를 glob 으로 보고 이 표본 중 하나라도 덮으면 H1.
IRREV_SAMPLES = ["rm x", "rm -rf x", "git push", "git push --force", "git push origin main",
                 "git reset --hard", "git branch -D x", "git branch --delete x", "git clean -fd",
                 "gh pr merge 1", "gh repo delete x", "npm publish", "twine upload x"]
# git 전역 옵션(서브커맨드 앞) — 매칭 전에 걷어낸다: `git -C . push` 가 `git push` 로 읽혀야 한다.
_GIT_GLOBAL_RE = re.compile(
    r"^git((?:\s+(?:-C\s+\S+|-c\s+\S+|--git-dir(?:=|\s+)\S+|--work-tree(?:=|\s+)\S+|"
    r"--no-pager|--paginate|-P|--bare|--no-replace-objects))+)\s+")
_SEG_SPLIT_RE = re.compile(r"&&|\|\||;|\||&|[\r\n]")   # 줄바꿈·단독 & 도 명령 구분자 (codex R4)


def _segments(inner):
    """allow 항목 안쪽 → 명령 «머리» 조각들. `&&`·`||`·`;`·`|` 로 쪼개고 앞쪽 sudo/env/VAR=val 을 걷어낸다.
    (echo rm 의 rm 은 인자라 머리가 아니다 · cd x && rm y 의 rm 은 머리다.)"""
    out = []
    for seg in _SEG_SPLIT_RE.split(inner):
        toks = seg.strip().split()
        while toks and (toks[0] in ("sudo", "env") or re.match(r"^[A-Za-z_]\w*=", toks[0])):
            toks.pop(0)
        if toks and "/" in toks[0]:   # `/usr/bin/git push` · `/bin/rm x` — 경로 머리는 이름으로 본다
            toks[0] = toks[0].rstrip("/").rsplit("/", 1)[-1]
        seg = " ".join(toks)
        while True:
            m = _GIT_GLOBAL_RE.match(seg)
            if not m:
                break
            seg = "git " + seg[m.end():]
        if seg:
            out.append(seg)
    return out


def h1_match(entry):
    """permissions.allow 항목(또는 스킬 allowed-tools 의 Bash 항목) 하나 → 걸린 라벨 또는 None."""
    if not isinstance(entry, str):
        return None
    m = re.match(r"^Bash(?:\((.*)\))?$", entry.strip(), re.S)
    if not m:
        return None
    inner = m.group(1)
    if inner is None or inner.strip() in ("", "*", ":*"):
        return "Bash 전면 허용"
    inner = inner.strip()
    if "*" in inner:   # 와일드카드: 명시 정규식과 별개로, 비가역 표본을 덮는지 본다
        for pat in {inner.replace(":*", "*"), inner.replace(":*", " *")}:
            for smp in IRREV_SAMPLES:
                if fnmatch.fnmatchcase(smp, pat):
                    return "와일드카드가 `%s` 를 덮는다" % smp
    for raw in _SEG_SPLIT_RE.split(inner):
        lab = _indirect_wildcard(raw)
        if lab:
            return lab
    for seg in _segments(inner):
        if "*" in seg:   # 경로 머리를 이름으로 줄인 뒤에도 본다 — `/bin/*` 는 줄이면 `*` (codex R3)
            for pat in {seg.replace(":*", "*"), seg.replace(":*", " *")}:
                for smp in IRREV_SAMPLES:
                    if fnmatch.fnmatchcase(smp, pat):
                        return "와일드카드가 `%s` 를 덮는다" % smp
        for lab, rx in _H1_RE:
            if rx.match(seg):
                return lab
        lab = _tokenset_irreversible(seg)
        if lab:
            return lab
    return None


# 인자를 «명령» 으로 실행하는 머리 (codex 카트리지 R8 · ghc R1). 블록리스트로 옵션을 쫓지 않는다:
# 와일드카드가 있으면 «인터프리터 바로 뒤 고정 스크립트 경로» 형태만 통과, 나머지는 전부 H1.
# 인터프리터 이름의 «단일 출처» — 정규식과 glob 후보가 여기서만 나온다(목록끼리 어긋난 것이 R6·R8·R10 세 번)
_INTERP_BASE = ["sh", "bash", "zsh", "dash", "ksh", "mksh", "fish", "csh", "tcsh", "python", "pypy",
                "node", "nodejs", "deno", "bun", "perl", "ruby", "php", "lua", "luajit", "osascript",
                "npx", "uvx", "pipx", "tclsh", "wish", "expect", "awk", "gawk", "mawk", "nawk",
                "Rscript", "julia", "pwsh", "powershell", "cmd"]
_INTERP_RE = re.compile(r"^(?:%s)[0-9.]*$" % "|".join(map(re.escape, _INTERP_BASE)))   # python3.12 · lua5.4
# 고정 실행 대상 = 경로처럼 생긴 것(`/` 포함 또는 스크립트 확장자) — `deno eval` · `bun exec` 의 낱말은 아니다
_SCRIPT_TARGET_RE = re.compile(r"(?:/|\.(?:py|js|mjs|cjs|ts|sh|bash|zsh|rb|pl|php|lua|R|jl|ps1|tcl|awk)$)")
# 고정 경로 예외가 없는 인터프리터 — awk 계열은 첫 인자가 프로그램 텍스트, 윈도 셸은 `/Command` 처럼
# `/` 로 시작하는 옵션을 받아 경로와 구분이 안 된다(codex R9)
_PROGTEXT_HEADS = {"awk", "gawk", "mawk", "nawk", "pwsh", "powershell", "cmd"}
# `python -m X:*` 예외는 pytest 하나 — 린터도 인자를 코드로 실행한다(pylint --init-hook, codex R4).
# 넓히려면 «인자 코드 실행 없음» 을 보이는 레인부터.
_PY_M_OK = {"pytest"}
_PKG_EXEC_HEADS = {"npx", "uvx", "pipx", "bunx"}
_PKG_MGR_HEADS = {"npm", "pnpm", "yarn", "bun"}   # 서브커맨드 exec·dlx·x 가 옵션 뒤 어디에 있든 실행기
# 뒤따르는 낱말을 명령으로 실행하는 감싸개 — 와일드카드가 «어디에» 있든 임의 명령이다
# (고정 대상을 감싼 `timeout 5 python3 x.py:*` 도 H1 — 비가역 쪽 과차단을 택한다)
_WRAP_HEADS = {"eval", "exec", "xargs", "env", "sudo", "doas", "nohup", "timeout", "command",
               "time", "nice", "watch", "caffeinate", "script", "parallel"}
_GLOB_CANDIDATES = list(dict.fromkeys(
    sorted(_WRAP_HEADS) + _INTERP_BASE + sorted(_PROGTEXT_HEADS | _PKG_MGR_HEADS | _PKG_EXEC_HEADS)))


def _bare(tok):
    t = re.sub(r"(?::\*|\*)$", "", tok).strip("\"'")
    return t.rstrip("/").rsplit("/", 1)[-1] if "/" in t else t


def _indirect_wildcard(raw_seg):
    """원문 조각(sudo/env 를 걷어내기 «전») → 라벨 또는 None."""
    toks = raw_seg.strip().split()
    while toks and re.match(r"^[A-Za-z_]\w*=", toks[0]):
        toks.pop(0)
    if not toks:
        return None
    head = _bare(toks[0])
    raw0 = toks[0].strip("\"'")
    raw0 = raw0[:-2] if raw0.endswith(":*") else raw0
    if re.search(r"[*?\[]", raw0):
        head = raw0.rsplit("/", 1)[-1]   # `py*` · `python[3]` · `python3.1?` — 머리 자체가 glob
    if head == "git" and re.search(r"alias\.[^\s=]*=", raw_seg):
        return "git -c alias 정의 (별칭이 임의 명령을 실행)"
    if "*" not in raw_seg:
        return None
    if re.search(r"[*?\[]", head):   # 머리 자체가 glob — 인터프리터·감싸개 이름을 덮으면 그것과 같다
        # 허용하는 머리 glob 은 «글자 + 끝 `*`» (`ls*` · `npm*`) 하나뿐. `?` · `[` · 중간 `*` 는 무엇을 덮는지
        # 목록으로 판정할 수 없어 바로 H1 이다(`?ython3`, codex R12 — 후보 비교를 조이던 길을 닫는다).
        if not re.fullmatch(r"[^*?\[]+\*", head):
            return "머리 glob `%s` (끝 `*` 접두 형태가 아니다)" % head
        lit = head[:-1]
        hits = [n for n in _GLOB_CANDIDATES
                if n.startswith(lit) or (lit.startswith(n) and re.fullmatch(r"[0-9.]*", lit[len(n):]))]
        for n in hits:   # 덮은 이름 «전부» 를 같은 규칙에 — 하나라도 H1 이면 H1 (재귀는 `:*` 라 끝난다)
            lab = _indirect_wildcard(" ".join([n + ":*"] + toks[1:]))
            if lab:
                return "머리 glob `%s` → %s" % (head, lab)
        return None
    if head in _WRAP_HEADS:
        return "간접 실행 `%s` 와일드카드" % head
    # 패키지 실행기 — 인자로 받은 패키지를 받아 실행한다. 고정 경로 예외가 없다(`npx @babel/node`, codex R5)
    sub = [t.strip("\"'") for t in toks[1:] if not t.startswith("-")]
    sub = [t[:-2] if t.endswith(":*") else t for t in sub]
    fam = re.sub(r"[0-9.]+$", "", head) if _INTERP_RE.match(head) else head   # `awk5` · `npx2` → 계열 이름 (codex R13)
    if fam in _PKG_EXEC_HEADS or (fam in _PKG_MGR_HEADS and any(
            fnmatch.fnmatchcase(e, t) for t in sub for e in ("exec", "dlx", "x"))):
        return "패키지 실행기 `%s` 와일드카드" % head
    if not _INTERP_RE.match(head):
        return None
    # 끝의 `:*` 만 «인자 허용» 접미사다. 맨 `*` 는 대상 안의 glob 이라 남겨서 아래에서 H1 로 본다.
    rest = [(t[:-2] if t.endswith(":*") else t).strip("\"'") for t in toks[1:]]
    if fam in _PROGTEXT_HEADS:
        return "인터프리터 `%s` 와일드카드 (고정 경로 예외 없음)" % head
    if head.startswith("python") and rest[:1] == ["-m"]:
        mod = rest[1] if len(rest) > 1 else ""
        if mod in _PY_M_OK:
            return None
        return "인터프리터 `%s -m %s` 와일드카드 (검토된 모듈 아님)" % (head, mod or "*")
    nxt = rest[0] if rest else ""
    # /dev/stdin · /dev/fd/0 · /proc/self/fd/0 는 경로꼴이지만 «호출자가 넣는 코드» 다(codex 카트리지 R9)
    if not nxt or nxt.startswith("-") or re.search(r"[*?\[]", nxt) or not _SCRIPT_TARGET_RE.search(nxt) \
            or re.match(r"^/(?:dev|proc)/", nxt):
        return "인터프리터 `%s` 와일드카드 (고정 스크립트·모듈이 바로 뒤에 없다)" % head
    return None


def _tokenset_irreversible(seg):
    """서브커맨드 앞 옵션(`git -C. push`, `gh --repo x pr merge`, `npm --registry u publish`)을 옵션
    목록으로 쫓지 않고 «토큰 집합» 으로 본다: 머리가 git/gh/npm/pnpm/yarn/twine 이면 머리 뒤 비-`-` 토큰
    집합 어디에든 비가역 서브커맨드가 있으면 H1.
    🟥 알려진 과차단: `git log --grep push` · `git commit -m push` 도 걸린다 — 비가역 표면이라 그 방향이 맞다."""
    toks = seg.split()
    if not toks:
        return None
    head = re.sub(r"(?::\*|\*)$", "", toks[0])
    raw = [re.sub(r"(?::\*|\*)$", "", t) for t in toks[1:]]
    words = {t for t in raw if t and not t.startswith("-")}
    if head == "git":
        if "push" in words:
            return "git push (토큰 집합)"
        if "reset" in words and "--hard" in raw:
            return "git reset --hard (토큰 집합)"
        if "branch" in words and any(re.match(r"^(?:-[A-Za-z]*[dD]|--delete)$", t) for t in raw):
            return "git branch 삭제 (토큰 집합)"
        if "clean" in words and any(re.match(r"^-[A-Za-z]*f", t) for t in raw):
            return "git clean -f (토큰 집합)"
    elif head == "gh":
        if ("pr" in words and "merge" in words) or ("repo" in words and "delete" in words) \
                or ("release" in words and "delete" in words):
            return "gh 비가역 서브커맨드 (토큰 집합)"
    elif head in ("npm", "pnpm", "yarn"):
        if "publish" in words or (head == "npm" and "unpublish" in words):
            return "%s publish (토큰 집합)" % head
    elif head == "twine":
        if "upload" in words:
            return "twine upload (토큰 집합)"
    return None


def tools_bash_entries(value):
    """frontmatter allowed-tools 값(문자열: 쉼표/공백 구분, [..] 가능) → Bash 항목 리스트."""
    return [t for t in re.findall(r"[A-Za-z_][\w.-]*(?:\([^)]*\))?", value) if t == "Bash" or t.startswith("Bash(")]


# ── H2: 지침 본문의 «확인 없이» 비가역 허용 ──────────────────────────────
IRREV_RE = re.compile(
    r"(?<![A-Za-z])rm(?![A-Za-z])|삭제|지우|지워|덮어|git\s+push|(?<![A-Za-z])push(?![A-Za-z])|푸시|"
    r"force[- ]push|publish|발행|배포|(?<![A-Za-z])merge(?![A-Za-z])|머지|병합|reset\s+--hard|"
    r"(?<![A-Za-z])delete(?![A-Za-z])|(?<![A-Za-z])drop(?![A-Za-z])|(?<![A-Za-z])overwrite", re.I)
# 허용 어휘. «묻지 않고» 처럼 부정어가 허용 표현 안에 들어 있는 것은 부정 판정 전에 먼저 걷어낸다.
PERMIT_RE = re.compile(
    r"확인\s*없이|(?:묻|확인하)지\s*(?:말고|않고)|never\s+ask\b|don'?t\s+ask\b|do\s+not\s+ask\b|no\s+confirmation|알아서|자동으로|[가-힣]도\s*(?:된다|됩니다|됨)|허용했|"
    r"without\s+(?:asking|confirm\w*|approval|prompt\w*|permission)|autonomously|automatically|freely|"
    r"(?:is|are)\s+allowed\s+to|allowed\s+to", re.I)
# 바로 다음 문장까지 보는 «인접» 판정에는 강한 허용 어휘만 쓴다 — 「…해도 된다」는 앞 문장의 동작이
# 아니라 다른 얘기일 수 있어(실물 오탐: «커밋·push) 요청을 받으면 … 사용한다. 단순 질문에는 직접 답해도 된다.»).
STRONG_PERMIT_RE = re.compile(
    r"확인\s*없이|묻지\s*(?:말고|않고)|알아서|"
    r"without\s+(?:asking|confirm\w*|approval|prompt\w*|permission)|autonomously", re.I)
# «허용을 뜻하는 부정 표현» — 부정어처럼 보이지만 금지가 아니다. 부정 판정 전에 문장에서 먼저 지운다.
ALLOW_NEG_RE = re.compile(
    r"확인\s*없이|(?:묻|확인하)지\s*(?:말고|않고)|never\s+ask\b(?:\s+for\s+(?:confirmation|permission|approval))?|"
    r"don'?t\s+ask\b|do\s+not\s+ask\b|no\s+confirmation|without\s+(?:asking|confirm\w*|approval|prompt\w*|permission)", re.I)
NEGATE_RE = re.compile(
    r"하지\s*않|하지\s*말|않는다|않는|않음|않습니다|금지|말\s*것|말라|하지\s*마|허용하지|불가|못\s*한다|안\s*한다|"
    r"never|do\s+not|don't|must\s+not|not\s+allowed|forbidden|prohibit|disallow", re.I)


def _split_units(text):
    """(줄번호, 단위 리스트) — 줄 단위로 끊고, 줄 안에서는 문장부호 뒤 공백으로 다시 끊는다."""
    out = []
    for i, line in enumerate(text.splitlines(), 1):
        parts = [p.strip() for p in re.split(r"(?<=[.!?。])\s+", line) if p.strip()]
        out.append((i, parts))
    return out


def h2_scan(text):
    """text → [(줄, 원문 문장)]. 같은 문장, 또는 같은 줄의 바로 다음 문장에 허용 어휘가 있고
    부정어가 없을 때 걸린다."""
    hits = []
    for lineno, parts in _split_units(text):
        for k, unit in enumerate(parts):
            if not IRREV_RE.search(unit):
                continue
            span = [unit]
            if k + 1 < len(parts):
                span.append(parts[k + 1])
            own = PERMIT_RE.search(unit)
            nxt = len(span) == 2 and STRONG_PERMIT_RE.search(span[1])
            if not own and not nxt:
                continue
            # 부정 판정은 허용 표현을 걷어낸 뒤에 — 「묻지 않고」의 «않고» 가 금지로 읽히지 않게.
            bare_unit = ALLOW_NEG_RE.sub(" ", PERMIT_RE.sub(" ", unit))
            # 비가역 동작이 든 문장 자신이 부정이면 금지문. 허용어가 «다음 문장»에만 있으면 그 문장도 본다.
            if NEGATE_RE.search(bare_unit):
                continue
            if not own and len(span) == 2:
                if NEGATE_RE.search(ALLOW_NEG_RE.sub(" ", PERMIT_RE.sub(" ", span[1]))):
                    continue
            hits.append((lineno, unit))
    return hits


# ── 파서 ─────────────────────────────────────────────────────────────────
class ParseError(Exception):
    pass


def read_text(path):
    try:
        with open(path, "r", encoding="utf-8") as fh:
            return fh.read()
    except (OSError, UnicodeDecodeError) as e:
        raise ParseError("읽기 실패: %s (%s)" % (path, e))


def parse_frontmatter(text, path):
    """→ (dict, {키:줄번호}, 본문 시작 줄번호). 닫는 --- 가 없으면 ParseError."""
    lines = text.lstrip("﻿").splitlines()
    if not lines or lines[0].strip() != "---":
        raise ParseError("frontmatter 없음(첫 줄이 --- 아님): %s" % path)
    end = None
    for i in range(1, len(lines)):
        if lines[i].strip() == "---":
            end = i
            break
    if end is None:
        raise ParseError("frontmatter 닫는 --- 없음: %s" % path)
    fm, where, key = {}, {}, None
    for i in range(1, end):
        ln = lines[i]
        if not ln.strip() or ln.lstrip().startswith("#"):
            continue
        m = re.match(r"^([A-Za-z_][\w-]*):\s*(.*)$", ln)
        if m and not ln.startswith((" ", "\t")):
            key = m.group(1)
            fm[key] = m.group(2).strip()
            where[key] = i + 1
        elif key is not None and ln.startswith((" ", "\t")):
            fm[key] = (fm[key] + " " + ln.strip()).strip()
        else:
            raise ParseError("frontmatter 줄 해석 불가 (%s:%d): %s" % (path, i + 1, ln))
    for k in ("description",):
        if fm.get(k, "") in (">", "|", ">-", "|-"):
            fm[k] = ""
    return fm, where, end + 2


# ── 검사 ─────────────────────────────────────────────────────────────────
DONE_WHEN_RE = re.compile(
    # 출처: templates/regression_guard.sh 의 done_when_pattern
    #       '^##[[:space:]]+(Done When|Completion Criteria)([[:space:]].*)?$'  (ERE → Python 이식)
    # 한글 «완료 조건/기준» 은 이 검사기의 확장이다(그쪽 패턴엔 없다).
    r"^##\s+(?:Done When|Completion Criteria)(?:\s.*)?$|^##\s+완료\s*(?:조건|기준)(?:\s.*)?$", re.M)
RO_CLAIM_RE = re.compile(r"읽기\s*전용|read-?only|수정하지\s*않|변경하지\s*않|(?:파일|코드)[을를]?\s*(?:수정|변경)하지\s*않", re.I)
WRITE_TOOL_RE = re.compile(r"\b(Bash|Edit|Write|NotebookEdit)\b")
BASH_LIMIT_RE = re.compile(r"Bash[^\n]{0,40}(?:제한|범위|만\s|only|한정)|(?:읽기\s*전용|read-?only)[^\n]{0,20}(?:명령|command)", re.I)
FILE_EXT = r"(?:md|py|json|sh|toml|ya?ml|txt|csv|js|ts|html|cfg|ini)"
PLACEHOLDER_RE = re.compile(r"YYYY|MM-?DD|HHMM|\.\.\.|[<>{}*\[\]]|\bxxx\b|NNN", re.I)
ROLE_SUFFIX_RE = re.compile(r"(team|orchestrator|tester|reviewer|developer|testing|review|writer|organizer|qa)$")


class Report:
    def __init__(self, target):
        self.target = target
        self.human, self.warn, self.info, self.errors = [], [], [], []

    def add(self, bucket, rid, path, line, text, detail=""):
        getattr(self, bucket).append({"id": rid, "file": path, "line": line, "text": text, "detail": detail})

    def verdict(self):
        if self.errors:
            return "HARNESS_ERROR", RC_ERROR
        if self.human:
            return "HUMAN_REVIEW", RC_HUMAN
        return "PASS", RC_PASS


def _line_of(raw, needle):
    idx = raw.find(needle)
    return raw.count("\n", 0, idx) + 1 if idx >= 0 else 0


def check(target, exclude_skills=()):
    rep = Report(target)
    if not os.path.isdir(target):
        rep.errors.append({"id": "E1", "file": target, "line": 0, "text": "대상 디렉터리가 없다", "detail": ""})
        return rep
    root = os.path.abspath(target)
    cl = os.path.join(root, ".claude")
    skip = set(GENERATOR_SKILLS) | set(exclude_skills)

    docs = []      # (rel, kind, text, fm, where, body_start)
    all_names, agent_names = set(), set()
    n_target = 0

    def rel(p):
        return os.path.relpath(p, root)

    def load(path, kind):
        try:
            text = read_text(path)
            fm = where = None
            start = 1
            if kind in ("agent", "skill"):
                fm, where, start = parse_frontmatter(text, rel(path))
            docs.append((rel(path), kind, text, fm, where, start))
            return True
        except ParseError as e:
            rep.errors.append({"id": "E2", "file": rel(path), "line": 0, "text": str(e), "detail": ""})
            return False

    def present(path):
        """lexists 로 찾는다 — 깨진 링크·디렉터리를 «없음» 으로 접지 않는다(A6). 일반 파일이 아니면 오류."""
        if not os.path.lexists(path):
            return False
        if not os.path.isfile(path):
            rep.errors.append({"id": "E5", "file": rel(path), "line": 0,
                               "text": "일반 파일이 아니다(깨진 링크·디렉터리 등) — 읽을 수 없음", "detail": ""})
            return False
        return True

    # Claude Code 는 루트 CLAUDE.md 와 .claude/CLAUDE.md 둘 다 프로젝트 지침으로 싣는다 — 둘 다 읽는다.
    _seen_cm = set()   # 한쪽이 다른 쪽을 가리키는 링크면 같은 파일을 두 번 세지 않는다 (codex 회귀 리뷰)
    for cm in (os.path.join(root, "CLAUDE.md"), os.path.join(cl, "CLAUDE.md")):
        if os.path.exists(cm):
            _real = os.path.realpath(cm)
            if _real in _seen_cm:
                continue
            _seen_cm.add(_real)
        if present(cm):
            n_target += 1
            load(cm, "claude_md")
        elif os.path.lexists(cm):
            n_target += 1
    adir = os.path.join(cl, "agents")
    if os.path.isdir(adir):
        for fn in sorted(os.listdir(adir)):
            if fn.endswith(".md"):
                n_target += 1
                agent_names.add(fn[:-3])
                all_names.add(fn[:-3])
                if present(os.path.join(adir, fn)):
                    load(os.path.join(adir, fn), "agent")
    sdir = os.path.join(cl, "skills")
    if os.path.isdir(sdir):
        for d in sorted(os.listdir(sdir)):
            all_names.add(d)                      # 생성기 스킬 이름도 «실재 이름» 집합엔 들어간다
            if d in skip:
                continue
            # 발견은 listdir 기반 대소문자 무시 — macOS(대소문자 무시 FS)에서는 isfile 로 `skill.md` 와
            # `SKILL.md` 를 못 가르고, 리눅스에서는 `SKILL.md` 고정 결합이 `skill.md` 를 «스킬 없음» 으로 놓친다.
            try:
                entries = sorted(os.listdir(os.path.join(sdir, d)))
            except OSError:
                continue
            cands = [e for e in entries if e.lower() == "skill.md"]
            if not cands:
                continue
            actual = "SKILL.md" if "SKILL.md" in cands else cands[0]
            sp = os.path.join(sdir, d, actual)
            n_target += 1
            if actual != "SKILL.md":
                rep.add("warn", "W7", rel(sp), 1, actual,
                        "스킬 정의 파일 이름이 정확히 SKILL.md 가 아님 — 대소문자 구분 파일시스템에서 스킬로 "
                        "로드되지 않을 수 있다(미확인: 이 검사기는 로드 여부를 실행해 확인하지 않았다)")
            if present(sp):
                load(sp, "skill")
    settings = []
    for sn in ("settings.json", "settings.local.json"):
        sp = os.path.join(cl, sn)
        if os.path.lexists(sp):
            n_target += 1
            if not present(sp):
                continue
            try:
                raw = read_text(sp)
                data = json.loads(raw)
            except (ParseError, ValueError) as e:
                rep.errors.append({"id": "E3", "file": rel(sp), "line": 0, "text": "settings 읽기/JSON 실패: %s" % e, "detail": ""})
                continue
            settings.append((rel(sp), raw, data))

    if n_target == 0 and not rep.errors:
        rep.errors.append({"id": "E4", "file": target, "line": 0,
                           "text": "검사할 하네스가 없다 (CLAUDE.md · 에이전트 · 스킬 · settings 전부 없음)", "detail": ""})
    if not rep.errors and not settings and all(not d[2].strip() for d in docs):
        rep.errors.append({"id": "E4", "file": target, "line": 0,
                           "text": "검사할 내용이 없다 (발견된 산출물이 전부 공백뿐)", "detail": ""})
    if rep.errors:
        return rep

    # H1 ─ settings
    for path, raw, data in settings:
        if not isinstance(data, dict):
            rep.errors.append({"id": "E3", "file": path, "line": 0, "text": "settings 최상위가 객체가 아니다", "detail": ""})
            continue
        if "permissions" not in data:
            continue
        perms = data["permissions"]
        if not isinstance(perms, dict):
            rep.errors.append({"id": "E3", "file": path, "line": 0, "text": "permissions 가 객체가 아니다", "detail": ""})
            continue
        if "allow" not in perms:
            continue
        allow = perms["allow"]
        if not isinstance(allow, list):
            rep.errors.append({"id": "E3", "file": path, "line": 0, "text": "permissions.allow 가 배열이 아니다", "detail": ""})
            continue
        if any(not isinstance(e, str) for e in allow):
            rep.errors.append({"id": "E3", "file": path, "line": 0, "text": "permissions.allow 원소가 문자열이 아니다", "detail": ""})
            continue
        for entry in allow:
            lab = h1_match(entry)
            if lab:
                ln = _line_of(raw, json.dumps(entry, ensure_ascii=False)) or _line_of(raw, str(entry))
                rep.add("human", "H1", path, ln, entry, lab)
    if rep.errors:
        return rep

    # S1 ─ 스킬 frontmatter allowed-tools = «묻지 않고 실행» 사전 승인이므로 settings allow 와 같은 판정기.
    #      (에이전트 frontmatter 의 tools 는 «사용 가능한 도구» 목록이지 사전 승인이 아니다 — 맨 Bash 는
    #       아래 W3 정보로 남긴다. 둘을 같은 H1 로 세면 모든 생성 에이전트가 사람 확인이 된다.)
    for path, kind, text, fm, where, start in docs:
        if kind == "skill" and "allowed-tools" in fm:
            for ent in tools_bash_entries(fm["allowed-tools"]):
                lab = h1_match(ent)
                if lab:
                    rep.add("human", "H1", path, where.get("allowed-tools", 1), ent, "스킬 allowed-tools(사전 승인): " + lab)

    # H2 ─ 본문
    for path, kind, text, fm, where, start in docs:
        for ln, sent in h2_scan(text):
            rep.add("human", "H2", path, ln, sent, "비가역 동작을 확인 없이 허용")

    # 에이전트
    for path, kind, text, fm, where, start in docs:
        if kind != "agent":
            continue
        tools = fm.get("tools")
        if tools is None:
            rep.add("warn", "W2", path, 1, "(tools 줄 없음)", "모든 도구 상속")
            m = RO_CLAIM_RE.search(fm.get("description", "") + "\n" + text)
            if m:   # tools 없음 = 모든 도구 상속이므로 «읽기 전용» 주장은 쓰기·Bash 상속과 충돌한다
                mm = RO_CLAIM_RE.search(text)
                ln = text[:mm.start()].count("\n") + 1 if mm else 1
                rep.add("warn", "W1", path, ln, "(tools 줄 없음)", "읽기 전용 주장 vs tools 없음 → 쓰기·Bash 상속")
        else:
            if RO_CLAIM_RE.search(fm.get("description", "") + "\n" + text) and WRITE_TOOL_RE.search(tools):
                m = RO_CLAIM_RE.search(text)
                ln = text[:m.start()].count("\n") + 1 if m else where.get("tools", 1)
                rep.add("warn", "W1", path, ln, "tools: %s" % tools, "읽기 전용 주장 vs 쓰기/Bash 도구")
            if re.search(r"\bBash\b", tools) and "Bash(" not in tools and not BASH_LIMIT_RE.search(text):
                rep.add("info", "W3", path, where.get("tools", 1), "tools: %s" % tools, "Bash 범위 제한 서술 없음 (정보)")

    # 스킬
    for path, kind, text, fm, where, start in docs:
        if kind != "skill":
            continue
        if not fm.get("description", "").strip():
            rep.add("warn", "W6", path, where.get("description", 1), "(description 비어 있음)", "")
        if not DONE_WHEN_RE.search(text):
            rep.add("info", "W5", path, 1, "Done When 절 없음", "FH 기준이다 — 생성기의 결함이 아니다")

    # W4 ─ 죽은 참조 (+ 입출력 경로 정보)
    basenames = set()
    for dp, dn, fns in os.walk(root):
        dn[:] = [d for d in dn if d != ".git"]
        basenames.update(fns)
    for path, kind, text, fm, where, start in docs:
        fdir = os.path.dirname(os.path.join(root, path))
        for i, line in enumerate(text.splitlines(), 1):
            for tok in re.findall(r"`([^`\n]+)`", line):
                tok = tok.strip()
                if (not tok or re.search(r"[\s$=(),;|\"']", tok) or tok.startswith(("http", "-", "/", "~"))):
                    continue
                is_pathlike = "/" in tok or re.search(r"\.%s$" % FILE_EXT, tok)
                if is_pathlike:
                    if (tok.endswith("/") and not PLACEHOLDER_RE.search(tok) and not tok.startswith("_workspace")
                            and (os.path.isdir(os.path.join(root, tok)) or os.path.isdir(os.path.join(fdir, tok)))):
                        continue                      # 실재하는 디렉터리 — 말할 것 없음
                    if tok.startswith("_workspace") or PLACEHOLDER_RE.search(tok) or tok.endswith("/"):
                        rep.add("info", "IO", path, i, tok, "아직 없는 입출력 경로(런타임/자리표시자/디렉터리) — 죽은 참조로 세지 않음")
                        continue
                    if "/" not in tok:
                        if tok not in basenames:
                            rep.add("info", "IO", path, i, tok, "슬래시 없는 파일명이 트리에 없음 — 런타임 산출일 수 있어 판정하지 않음")
                        continue
                    cand = tok[2:] if tok.startswith("./") else tok
                    # 해석 기준 셋: 대상 루트 · 그 파일이 있는 디렉터리 · .claude/ (스킬 문서가 `skills/x/skill.md` 처럼 쓴다)
                    if not (os.path.exists(os.path.join(root, cand)) or os.path.exists(os.path.join(fdir, cand))
                            or os.path.exists(os.path.join(cl, cand))):
                        rep.add("warn", "W4", path, i, tok, "죽은 참조: 대상 루트·파일 디렉터리 어느 쪽에도 없음")
                elif re.match(r"^[a-z][a-z0-9]*(-[a-z0-9]+)+$", tok) and tok not in all_names:
                    first = tok.split("-")[0]
                    family = any(n.split("-")[0] == first for n in all_names)
                    if family or ROLE_SUFFIX_RE.search(tok):
                        rep.add("warn", "W4", path, i, tok, "죽은 참조: 같은 계열 이름의 스킬/에이전트가 실재하지 않음")
    # 같은 (파일,줄,토큰) 중복 제거
    for bucket in ("warn", "info", "human"):
        seen, uniq = set(), []
        for it in getattr(rep, bucket):
            k = (it["id"], it["file"], it["line"], it["text"])
            if k not in seen:
                seen.add(k)
                uniq.append(it)
        setattr(rep, bucket, uniq)
    return rep


# ── 출력 ─────────────────────────────────────────────────────────────────
def render_text(rep):
    v, rc = rep.verdict()
    lines = ["판정: %s (rc=%d) — 사람 확인 %d · 경고 %d · 정보 %d%s" % (
        v, rc, len(rep.human), len(rep.warn), len(rep.info), " · 오류 %d" % len(rep.errors) if rep.errors else "")]
    lines.append("대상: %s" % rep.target)
    secs = [("오류(HARNESS_ERROR)", rep.errors), ("사람 확인(HUMAN_REVIEW) — 비가역 권한", rep.human),
            ("경고(WARN)", rep.warn), ("정보(INFO)", rep.info)]
    for title, items in secs:
        if not items:
            continue
        lines.append("")
        lines.append("[%s]" % title)
        for it in items:
            tag = it["id"]
            if tag == "W5":
                tag = "W5/FH 기준"
            lines.append("  %s %s:%s — %s%s" % (tag, it["file"], it["line"], it["text"],
                                               ("  (%s)" % it["detail"]) if it["detail"] else ""))
    lines.append("")
    lines.append("※ 이 검사는 기록의 형태만 본다(정규식). PASS 는 안전 보증이 아니고, 비가역 권한의 결론은 사람 몫이다.")
    return "\n".join(lines)


def render_json(rep):
    v, rc = rep.verdict()
    return json.dumps({"verdict": v, "rc": rc, "target": rep.target, "human_review": rep.human,
                       "warnings": rep.warn, "info": rep.info, "errors": rep.errors},
                      ensure_ascii=False, indent=2)


# ── selftest (known-pair) ───────────────────────────────────────────────
def selftest():
    bad = []

    def expect(name, cond):
        if not cond:
            bad.append(name)
    expect("H1+ git push", h1_match("Bash(git push origin:*)") is not None)
    expect("H1+ rm", h1_match("Bash(rm -f todo.json)") is not None)
    expect("H1+ Bash 단독", h1_match("Bash") is not None and h1_match("Bash(*)") is not None)
    expect("H1+ reset --hard", h1_match("Bash(git reset --hard:*)") is not None)
    expect("H1- pytest", h1_match("Bash(python -m pytest:*)") is None)
    expect("H1- git add", h1_match("Bash(git add:*)") is None)
    expect("H1- Read", h1_match("Read(./src/**)") is None)
    expect("H1+ sh:*", h1_match("Bash(sh:*)") is not None)
    expect("H1+ python3 -c:*", h1_match("Bash(python3 -c:*)") is not None)
    expect("H1- python3 fixed script", h1_match("Bash(python3 scripts/x.py:*)") is None)
    expect("H1+ timeout 5 *", h1_match("Bash(timeout 5 *)") is not None)
    expect("H1+ env -i *", h1_match("Bash(env -i *)") is not None)
    expect("H1+ git alias", h1_match("Bash(git -c alias.s=!x s)") is not None)
    expect("glob 후보 ⊇ 모든 머리 집합", (_WRAP_HEADS | _PROGTEXT_HEADS | _PKG_MGR_HEADS | _PKG_EXEC_HEADS
                                     | set(_INTERP_BASE)) <= set(_GLOB_CANDIDATES))
    expect("H2+ ko", len(h2_scan("git push 는 확인 없이 해도 된다.")) == 1)
    expect("H2- ko", len(h2_scan("git push 는 확인 없이 하지 않는다.")) == 0)
    expect("H2+ en", len(h2_scan("The agent may push to main without asking.")) == 1)
    expect("H2- en", len(h2_scan("Never push to main without asking the user.")) == 0)
    if bad:
        print("selftest FAIL: " + ", ".join(bad))
        return 1
    print("selftest ok (known-pair 18)")
    return 0


def main(argv):
    args = argv[1:]
    if "--selftest" in args:
        return selftest()
    want_json = "--json" in args
    excl, target, i = [], None, 0
    while i < len(args):
        a = args[i]
        if a == "--json":
            pass
        elif a == "--exclude-skill" and i + 1 < len(args):
            i += 1
            excl.append(args[i])
        elif a.startswith("-"):
            sys.stderr.write("알 수 없는 옵션: %s\n" % a)
            return RC_ERROR
        elif target is None:
            target = a
        else:
            sys.stderr.write("대상은 하나만 받는다\n")
            return RC_ERROR
        i += 1
    if target is None:
        sys.stderr.write("사용법: generated_harness_check.py <대상 디렉터리> [--json] [--exclude-skill NAME] | --selftest\n")
        return RC_ERROR
    try:
        rep = check(target, excl)
    except Exception as e:  # 계기 자신의 오류도 PASS 로 새지 않게
        sys.stderr.write("HARNESS_ERROR: %s\n" % e)
        return RC_ERROR
    print(render_json(rep) if want_json else render_text(rep))
    return rep.verdict()[1]


if __name__ == "__main__":
    sys.exit(main(sys.argv))
