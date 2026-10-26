#!/usr/bin/env python3
"""abstract_consult_check.py — 바깥 모델에 보낼 «가린 질문» 의 송신 전 검사 + 로컬 원장 (거주 원칙의 세 번째 길, D1).

왜 있나 (2026-10-26, 운영자 «ㅇㅇ 설치하고 설계해보자» · «d1시작하면좋은데»):
  회사 거주 원칙은 지금 «금지» 와 «폐포가 깨끗하면 송신»(residency_closure_scan.py) 두 칸뿐이다. 비공개 맥락이 섞인
  코드에 대해 바깥 의견이 필요할 때 제3안 = 비공개 이름을 역할 · 유형으로 바꾼 질문만 보낸다(arXiv:2610.24824).
  설계 = tracks/_meta/design_2026-10-26_residency-verified-abstraction.md (gitignored). 이 파일은 그 §3 ② 와 ⑥ 이다.

🟥 이 스크립트는 **보내지 않는다.** 송신기는 없다 — 검사 판정과 원장만 낸다. 기본으로 켜지는 곳도 없다(호출자 0).
🟥 보안 경계가 아니라 **위생 린트**다(outbound_query_guard.sh 와 같은 등급). 협조적인 로컬 모델이 실수로 넣는 이름을
   잡는다. 의도적 우회(인코딩 · 쪼개 보내기 · 여러 질문에 나눠 모으기)와 의미 유출(역할만 남아도 회사가 드러나는 조합)은
   못 막는다 — 그래서 송신은 사람 확인을 거친다(설계 §2-2). 자동 판정 혼자로 이 표면을 못 지나간다.

🟥 막기와 강조를 가른다 (2026-10-26 D2A 결과 — tracks/_meta/residency_d2/RESULTS_D2A.md):
   «레포에 있는 사전 밖 낱말 = 비공개» 로 전부 막았더니 공개 라이브러리 위에서도 깨끗한 가린 질문 0/12 가 통과했다(STOP).
   그래서 rc 1 은 **확실한 비공개 신호**에만 낸다 — 운영자 리터럴 · 불투명 이름(어느 공개 어휘에도 없는 조각) · 호스트 ·
   작성자 · 메일 · 원문 조각. 공개 낱말로만 된 레포 식별자(processPayment)는 막지 않고 **flags** 로 올린다 — 사람 확인 화면이
   강조할 자리다. 판정(rc)은 flags 에 안 묶인다.

검사 세 층 (전부 보내기 전 · 막는 신호가 하나라도 있으면 rc 1 · 하나라도 못 재면 rc 3):
  L1 운영자 리터럴 — scripts/outbound_query_guard.sh 를 그대로 부른다(override 층 · 카나리 · fail-closed 는 그쪽 소유).
     🟥 OUTBOUND_QUERY_OK 는 지우고 부른다 — 그 가드의 «봤고 괜찮다» 우회가 이 검사를 대신 통과시키면 안 된다.
  L2 레포 식별자 — `git ls-files` 의 경로와 본문, `git log` 작성자에서 뽑는다. 낱말을 사전(+기술 어휘 · 언어 예약어)과 대조해
     ⓐ 불투명(공개 어휘에 없는 조각이 있음: zqpayGw · pg-settle-01) → 대소문자 · 구분자 · 띄어쓰기 · 낱말 12개까지 이어 붙이기,
        질문 쪽 낱말도 camel 조각으로 쪼개 대조(ZqpayClient · «z q p a y»)
        공개 어휘 = 사전 + 굴절형 + 기술 낱말 + **파이썬 표준 라이브러리 본문 낱말**(기본 켜짐 · 캐시) + --public-corpus
     ⓑ 낱말 합성(processPayment) → 코드 토큰 하나로 쓰였을 때 **flags**(막지 않음). 정규형 6자 미만 합성(bE · iT)은 안 본다
        — 레포 시험 문자열의 대소문자 섞인 짧은 낱말이 질문의 be · it 을 막았다(D2A)
     ⓒ 작성자 이름 · 메일 → 대소문자 무시 구절 일치
  L3 원문 조각 — 레포 본문과 연속 토큰 8개(식별자 ≥ 3)가 겹치면 걸린다.

종료 코드: 0 = 깨끗함(보낼 수 있다 — 사람 확인 뒤) · 1 = 걸림 · 3 = 미측정(계기 불완전 → 막음) · 2 = 사용법 오류.

원장 (로컬 전용 · 기본 ${XDG_STATE_HOME:-~/.local/state}/fh-abstract-consult/ledger.jsonl):
  🟥 tracks/_meta 를 기본값으로 두지 않는다 — 그 트리는 컴패니언 스토어로 동기화된다(비공개 유래 질문이 머신을 떠난다).
  깨끗한 질문은 본문을 남긴다(감사 대상이 «무엇을 보냈나» 다). 걸린 질문은 sha256 만 남기고, 걸린 이름은 종류 · 층 · sha256 만.
  decide <id> sent|edited|dropped — 사람 판정. 🟥 걸림 · 미측정 판정의 id 에 sent 를 기록하려 하면 거부한다(rc 1).
  replay <id> <rc> — 같은 실행 상태에서 답을 적용한 숨긴 테스트 rc(쓸모 기록, 안전 장치 아님 — 설계 §2-3).

명명된 잔여(D2 측정 전 — 이름으로 남긴다):
  · 레포에 없는 비공개 이름은 L1 override 층에 운영자가 넣은 것만 본다.
  · 4자 미만 불투명 조각(pg · db1)은 단독으로 대조하지 않는다 — 과차단이 크다. 그것이 든 더 긴 식별자 · 호스트는 잡힌다.
  · 사전이 고유명사를 담으면(/usr/share/dict/words 는 사람 이름 일부를 담는다) 그 낱말로만 된 식별자는 «합성» 으로 분류돼
    산문 언급을 놓친다. 작성자는 ⓒ 가 따로 본다.
  · 과차단(사전에 없는 공개 라이브러리 이름 등)은 --allow 파일 · --public-corpus 로 푼다. 과차단 비율은 D2 에서 잰다.
  · 이진 파일 속 이름은 못 본다(통계 binary_skipped 에 수). 호스트는 끝 조각이 HOST_SUFFIX 에 있을 때만 호스트로 친다.
  · 작성자는 이름 낱말이 다 나올 때만 — 성씨만 쓴 언급은 못 잡는다.
  · 표준 라이브러리 어휘에서 못 읽은 파일은 건너뛴다 — 공개 어휘가 줄어 «더 막는» 쪽으로만 틀어진다(통과 쪽 아님, codex R2 기각 근거).
"""
import argparse
import hashlib
import json
import keyword
import os
import re
import subprocess
import sys
import time
import uuid

HERE = os.path.dirname(os.path.abspath(__file__))
VERSION = "d1b-2026-10-26"

MAX_FILES = 20000
MAX_FILE_BYTES = 1 << 20
MAX_TOTAL_BYTES = 200 << 20
OPAQUE_MIN = 4          # 정규화 뒤 길이 — 이보다 짧은 불투명 조각은 단독 대조 안 함(잔여)
PROBE_MIN = 6           # 생사 탐침에 쓸 이름의 최소 길이
JOIN_WORDS = 12         # 질문의 이웃 낱말을 몇 개까지 이어 붙여 대조하나(«pg settle 01 shop internal» · 글자마다 띄어 쓴 이름, D2A)
JOIN_CHARS = 64
SHINGLE = 8
SHINGLE_MIN_IDENT = 3
COMPOUND_MIN = 6        # 정규형 길이 — 이보다 짧은 합성(bE · iT · tHe)은 flags 로도 안 올린다(D2A 과차단)

# 사전에 없지만 공개 기술 어휘인 것 — 이것만으로 된 식별자는 불투명으로 안 친다. 늘리는 것은 과차단 실측(D2) 뒤.
TECH_WORDS = frozenset("""
api apis app args argv async auth bool boolean buf bytes cfg cli cmd config const css csv ctx db dict dir dirs dns
enum env eof err errno fd fn func get gid git gpu html http https id ids impl init int io ip json jsx kwargs len lib
libs log md mkdir msg npm num obj os param params pid pkg ptr py regex repo req res rpc sdk sha sql src stderr stdin
stdout str sync tcp tmp toml ts tsx txt uid ui uri url urls utf utf8 uuid var vars xml yaml yml
makefile heredoc dockerfile gitignore readme changelog shebang localhost jsonl pytest
javascript typescript ipv4 ipv6 html5 utf16 utf32 ascii unicode
""".split())

IDENT_RE = re.compile(r"[A-Za-z_][A-Za-z0-9_]*(?:[-.][A-Za-z0-9_]+)*")
PART_RE = re.compile(r"[A-Z]+(?![a-z])|[A-Z]?[a-z]+|\d+")
TOKEN_RE = re.compile(r"[A-Za-z_][A-Za-z0-9_]*|\d+|[^\sA-Za-z0-9_]")
WORD_RE = re.compile(r"[A-Za-z0-9]+")


class NotScanned(Exception):
    """계기 불완전 — 깨끗함이 아니라 미측정."""


def _sha(s):
    return hashlib.sha256(s.encode("utf-8", "surrogatepass")).hexdigest()


def _norm(s):
    return re.sub(r"[^a-z0-9]", "", s.lower())


def load_vocab(dict_path, allow_path, use_stdlib=True):
    if not dict_path or not os.path.isfile(dict_path):
        raise NotScanned("사전 없음: %s" % dict_path)
    words = set()
    with open(dict_path, encoding="utf-8", errors="replace") as f:
        for line in f:
            w = line.strip().lower()
            if w.isalpha():
                words.add(w)
    if len(words) < 3:
        raise NotScanned("사전이 비었다(%d 낱말): %s" % (len(words), dict_path))
    words |= TECH_WORDS
    if use_stdlib:
        words |= stdlib_words()
    words |= {k.lower() for k in keyword.kwlist}
    import builtins
    words |= {b.lower() for b in dir(builtins) if b.isalpha()}
    allow = set()
    if allow_path:
        if not os.path.isfile(allow_path):
            raise NotScanned("허용 목록 파일 없음: %s" % allow_path)
        with open(allow_path, encoding="utf-8") as f:
            allow = {_norm(l) for l in f if l.strip() and not l.lstrip().startswith("#")}
    return words, allow


def _parts(ident):
    out = []
    for chunk in re.split(r"[_\-.]+", ident):
        out += [p.lower() for p in PART_RE.findall(chunk)]
    return [p for p in out if p]


_SUFFIXES = (("ies", "y"), ("es", ""), ("s", ""), ("ed", ""), ("ed", "e"), ("ing", ""), ("ing", "e"),
             ("er", ""), ("er", "e"), ("ers", ""), ("ers", "e"))
# 파생 접미(-ly · -ally · -ness)는 안 뗀다 — 지어낸 이름(mapness)이 공개 낱말로 둔갑했다(codex R1). 굴절형만 본다


def _is_word(p, words):
    if p.isdigit() or len(p) <= 2 or p in words:
        return True
    # 사전(/usr/share/dict/words)은 굴절형을 거의 안 담는다 — requests · returns 를 비공개 이름으로 치면 과차단이 폭발한다.
    # 어간 2자(using → use)와 자음 겹침(mapped → map)은 D2A 가 막은 낱말이다
    for suf, add in _SUFFIXES:
        if not p.endswith(suf):
            continue
        stem = p[:-len(suf)]
        if len(stem) >= 2 and (stem + add) in words:
            return True
        # 자음 겹침은 -ed · -ing · -er(s) 에서만(mapped · mapping · mapper) — 다른 접미에 쓰면 지어낸 mappes 가 공개 낱말이 된다(codex R2)
        if suf in ("ed", "ing", "er", "ers") and len(stem) >= 3 and stem[-1] == stem[-2] and stem[:-1] in words:
            return True
    return False


def _stdlib_cache_path(std):
    base = os.environ.get("XDG_CACHE_HOME") or os.path.join(os.path.expanduser("~"), ".cache")
    return os.path.join(base, "fh-abstract-consult", "stdlib-%s.json" % _sha(std + sys.version)[:16])


def stdlib_words():
    """파이썬 표준 라이브러리의 .py · .txt · .rst 본문 낱말(소문자 · 알파벳만, test 디렉터리 제외) — 공개 기술 어휘.
    한 번 지어 ${XDG_CACHE_HOME:-~/.cache}/fh-abstract-consult/ 에 둔다(경로 · 버전이 같으면 다시 읽는다). 못 지으면 미측정."""
    import sysconfig
    std = sysconfig.get_paths().get("stdlib") or ""
    if not os.path.isdir(std):
        raise NotScanned("표준 라이브러리 경로 없음: %s" % std)
    cache = _stdlib_cache_path(std)
    try:
        with open(cache, encoding="utf-8") as f:
            got = json.load(f)
        ws = got.get("words") if isinstance(got, dict) else None
        # 출처 · 내용 해시 · 서로 다른 낱말 수를 같이 본다 — 중복으로 부풀린 목록 · 다른 인터프리터의 캐시를 믿지 않는다(codex R1)
        if (isinstance(ws, list) and got.get("std") == std and got.get("version") == sys.version
                and len(set(ws)) == len(ws) > 1000 and got.get("sha") == _sha("\n".join(ws))):
            return set(ws)
    except (OSError, ValueError, AttributeError, TypeError):
        pass
    out = set()
    for root, dirs, fnames in os.walk(std):
        dirs[:] = [d for d in dirs if d not in ("site-packages", "test", "tests", "idlelib")]
        for fn in fnames:
            if not fn.endswith((".py", ".txt", ".rst")):
                continue
            try:
                with open(os.path.join(root, fn), encoding="utf-8", errors="replace") as f:
                    out.update(w.lower() for w in re.findall(r"[A-Za-z]{3,}", f.read()))
            except OSError:
                continue
    if len(out) < 1000:
        raise NotScanned("표준 라이브러리 어휘가 너무 적다(%d) — 미측정" % len(out))
    try:
        ws = sorted(out)
        os.makedirs(os.path.dirname(cache), exist_ok=True)
        with open(cache, "w", encoding="utf-8") as f:
            json.dump({"std": std, "version": sys.version, "sha": _sha("\n".join(ws)), "words": ws}, f)
    except OSError:
        pass                      # 캐시는 속도용 — 못 써도 판정은 같다
    return out


HOST_RE = re.compile(r"[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+")
# 호스트로 칠 마지막 조각. 라벨 수가 아니라 끝으로 가른다 — 두 조각 호스트(settle.internal)를 놓치지 않고(codex R1),
# 파일 이름(jquery.min.js · settings.json)을 호스트로 치지 않는다. 목록 밖 끝은 잔여(이름으로).
HOST_SUFFIX = frozenset("""
com net org io ai dev app cloud co biz info me kr jp cn tw hk sg us uk de fr eu
internal intra intranet local localdomain lan corp home private svc cluster example test invalid
""".split())


def _is_host(ident):
    return bool(HOST_RE.fullmatch(ident)) and ident.rsplit(".", 1)[-1].lower() in HOST_SUFFIX


def classify(ident, words, allow):
    """'opaque' · 'compound' · None(공개 낱말 하나 — 대조 안 함)."""
    n = _norm(ident)
    if not n or n in allow:
        return None
    if _is_host(ident):
        return "opaque"          # 호스트명은 낱말이 다 사전에 있어도(pg-settle-01.shop.internal) 이름 자체가 비공개 실체다
    parts = _parts(ident)
    if not parts:
        return None
    if all(_is_word(p, words) for p in parts):
        return "compound" if len(parts) >= 2 else None
    if len(n) < OPAQUE_MIN:
        return None
    return "opaque"


def _git(repo, *args):
    r = subprocess.run(["git", "-C", repo, *args], capture_output=True, timeout=120)
    if r.returncode != 0:
        raise NotScanned("git %s 실패(rc=%d): %s" % (args[0], r.returncode, r.stderr.decode("utf-8", "replace")[:200]))
    return r.stdout


def public_vocab(dirs):
    """--public-corpus 디렉터리(공개 소스 — 예: 파이썬 표준 라이브러리)의 식별자 → 공개 어휘. 여기 있는 이름은 비공개 실체가 아니다."""
    pub = set()
    n = 0
    for d in dirs or ():
        if not os.path.isdir(d):
            raise NotScanned("공개 말뭉치 디렉터리 없음: %s" % d)
        for root, _dirs, fnames in os.walk(d):
            for fn in fnames:
                p = os.path.join(root, fn)
                try:
                    if os.path.islink(p) or os.path.getsize(p) > MAX_FILE_BYTES:
                        continue
                    with open(p, "rb") as f:
                        raw = f.read()
                except OSError:
                    continue
                if b"\0" in raw[:8192]:
                    continue
                n += 1
                if n > MAX_FILES * 5:
                    raise NotScanned("공개 말뭉치가 상한을 넘었다 — 좁혀서 다시")
                for ident in IDENT_RE.findall(raw.decode("utf-8", "replace")):
                    for cand in {ident, *re.split(r"[-.]", ident)}:
                        pub.add(cand)
                        pub.add(_norm(cand))
                        pub.update(x for x in _parts(cand) if len(x) >= OPAQUE_MIN)
    return pub


def inventory(repo, words, allow, public=frozenset()):
    """레포 → (불투명 정규형 집합, 합성 표기 집합, 작성자 구절 집합, 원문 조각 해시 집합, 통계)."""
    if not os.path.isdir(repo):
        raise NotScanned("레포 아님: %s" % repo)
    files = [f for f in _git(repo, "ls-files", "-z").decode("utf-8", "surrogateescape").split("\0") if f]
    if not files:
        raise NotScanned("추적 파일 0 — 목록이 비면 «이름 없음» 을 말할 수 없다")
    if len(files) > MAX_FILES:
        raise NotScanned("파일 %d > 상한 %d — 일부만 읽은 목록은 미측정이다" % (len(files), MAX_FILES))
    opaque, compound, shingles = set(), set(), set()
    total = truncated = from_head = binary = 0
    texts = ["\n".join(files)]
    for rel in files:
        p = os.path.join(repo, rel)
        try:
            if os.path.islink(p):
                texts.append(os.readlink(p))   # 링크가 가리키는 경로 문자열에도 이름이 있다(codex R2) — 대상 파일은 따라가지 않는다
                continue
            if os.path.isfile(p):
                with open(p, "rb") as f:
                    raw = f.read(MAX_FILE_BYTES + 1)
            else:
                # 작업 트리에서 지운 추적 파일 — 건너뛰면 그 안의 이름이 조용히 빠진다(codex R1). 마지막 커밋본을 읽는다
                raw = _git(repo, "cat-file", "blob", "HEAD:" + rel)[:MAX_FILE_BYTES + 1]
                from_head += 1
        except OSError as e:
            raise NotScanned("읽기 실패 %s: %s" % (rel, e))
        if len(raw) > MAX_FILE_BYTES:
            raw = raw[:MAX_FILE_BYTES]      # 큰 파일은 앞부분만 — 건너뛰지 않는다(codex R1). 잘린 수는 통계에
            truncated += 1
        if b"\0" in raw[:8192]:
            binary += 1                     # 이진 파일 안 이름은 못 본다 — 잔여(통계에 수로 남긴다)
            continue
        total += len(raw)
        if total > MAX_TOTAL_BYTES:
            raise NotScanned("본문 합계 상한 %d 초과 — 일부만 읽은 목록은 미측정이다" % MAX_TOTAL_BYTES)
        texts.append(raw.decode("utf-8", "replace"))
    for t in texts:
        for ident in IDENT_RE.findall(t):
            for cand in {ident, *re.split(r"[-.]", ident)}:
                if "." in cand and not _is_host(cand):
                    continue      # 점 붙은 파일 이름(config.json)은 통째로 안 담는다 — 조각은 위 split 이 따로 본다(과차단 억제)
                k = classify(cand, words, allow)
                if k == "opaque":
                    opaque.add(_norm(cand))
                    # 사전에 없는 조각 자체도 이름이다(ZQPAY_HOST → zqpay). 질문이 조각만 쓰면 합친 형태로는 못 잡는다
                    for part in _parts(cand):
                        if len(part) >= OPAQUE_MIN and not _is_word(part, words) and part not in allow:
                            opaque.add(part)
                elif k == "compound":
                    compound.add(cand)
        toks = TOKEN_RE.findall(t)
        for i in range(len(toks) - SHINGLE + 1):
            win = toks[i:i + SHINGLE]
            if sum(1 for x in win if IDENT_RE.fullmatch(x)) >= SHINGLE_MIN_IDENT:
                shingles.add(_sha("\x1f".join(win)))
    authors = set()
    for line in _git(repo, "log", "--format=%an%n%ae", "--all").decode("utf-8", "replace").splitlines():
        line = line.strip()
        if "@" in line:
            authors.add(line.lower())                       # 메일 전체
            local = line.split("@", 1)[0]
            if classify(local, words, allow) == "opaque":
                opaque.add(_norm(local))
        elif len(line.split()) >= 2:
            authors.add(" ".join(line.lower().split()))     # 여러 낱말 이름 = 구절
        elif classify(line, words, allow) == "opaque":
            opaque.add(_norm(line))                         # 한 낱말 이름은 사전에 없을 때만(«t» · «test» 는 과차단)
    for pub in public:
        opaque.discard(pub)
        compound.discard(pub)
    if not opaque and not compound:
        raise NotScanned("레포에서 비공개 후보 이름을 하나도 못 뽑았다 — 0 은 «없음» 이 아니라 미측정이다")
    stats = {"files": len(files), "opaque": len(opaque), "compound": len(compound),
             "authors": len(authors), "shingles": len(shingles),
             "truncated": truncated, "from_head": from_head, "binary_skipped": binary}
    return opaque, compound, authors, shingles, stats


def _variants(n):
    out = [n]
    for suf in ("ies", "es", "s"):
        if n.endswith(suf) and len(n) - len(suf) >= OPAQUE_MIN:
            out.append(n[:-len(suf)] + ("y" if suf == "ies" else ""))
    return out


def scan_repo_layers(q, inv):
    opaque, compound, authors, shingles, _ = inv
    hits = []
    raw_words = WORD_RE.findall(q)
    split_words = []
    for w in raw_words:
        ps = PART_RE.findall(w)
        split_words.extend(ps if len(ps) > 1 else [w])   # 붙여 쓴 이름(ZqpayClient)은 조각으로
    seen = set()
    # 낱말 경계에 맞춘 이어 붙이기만 본다 — 임의 부분 문자열(«parser splits» 속 rsplit)은 과차단이었다(FoD 실측).
    # 원래 낱말열과 camel 조각 낱말열 둘 다 본다 — 조각만 보면 긴 camel 호스트가 JOIN_WORDS 를 넘어 빠진다(codex R1)
    for words in (raw_words, split_words):
        for i in range(len(words)):
            j = ""
            for k in range(i, min(i + JOIN_WORDS, len(words))):
                j += _norm(words[k])
                if len(j) > JOIN_CHARS:
                    break
                for v in _variants(j):           # 굴절형(zqpays)도 같은 이름이다(codex R1)
                    if v in opaque and v not in seen:
                        seen.add(v)
                        hits.append(("L2", "opaque" if k == i else "opaque-split", v))
    # 합성 식별자는 «코드 토큰 하나» 로 쓰였을 때만 — 대소문자 · 구분자는 정규화한다(PROCESSPAYMENT · process_payment, codex R1).
    # 띄어 쓴 산문(«process payment»)은 역할 서술이라 통과시킨다
    cnorm = {_norm(c): c for c in compound if len(_norm(c)) >= COMPOUND_MIN}
    for tok in set(IDENT_RE.findall(q)):
        for cand in {tok, *re.split(r"[-.]", tok)}:
            for v in _variants(_norm(cand)):
                if v in cnorm:
                    hits.append(("L2f", "compound", cnorm[v]))     # 막지 않는다 — flags(사람 확인 화면이 강조)
                    break
    ql = " ".join(q.lower().split())
    qwords = set(w.lower() for w in WORD_RE.findall(q))
    for a in authors:
        if re.search(r"(?<![\w@.])" + re.escape(a) + r"(?![\w@])", ql):
            hits.append(("L2", "author", a))
        elif "@" not in a and {w for w in WORD_RE.findall(a) if len(w) >= 2} <= qwords:   # 이니셜 · 가운데 글자는 빼고(codex R2)
            hits.append(("L2", "author", a))     # 순서를 바꿔 쓴 이름(«Parkova, Jimin», codex R1)
    toks = TOKEN_RE.findall(q)
    for i in range(len(toks) - SHINGLE + 1):
        if _sha("\x1f".join(toks[i:i + SHINGLE])) in shingles:
            hits.append(("L3", "verbatim", " ".join(toks[i:i + SHINGLE])))
            break
    return hits


def live_probe(inv):
    """계기 생사 — 목록에서 고른 불투명 이름 하나를 대소문자 · 구분자를 바꿔 넣은 문장이 실제로 걸리는가."""
    opaque = inv[0]
    long_ = sorted(o for o in opaque if len(o) >= PROBE_MIN)
    pick = (long_ or sorted(opaque) or [None])[0]
    if pick is None:
        return True, None       # 합성만 있는 레포 — 합성 표기 그대로 탐침
    mid = len(pick) // 2
    probe = "how should the %s_%s handle retries" % (pick[:mid].upper(), pick[mid:])
    ok = any(h[0] == "L2" and h[2] == pick for h in scan_repo_layers(probe, inv))
    return ok, pick


def run_guard(guard, q):
    if not guard or not os.path.isfile(guard):
        raise NotScanned("L1 가드 없음: %s" % guard)
    env = {k: v for k, v in os.environ.items() if k != "OUTBOUND_QUERY_OK"}
    r = subprocess.run(["bash", guard], input=q.encode("utf-8"), capture_output=True, env=env, timeout=120)
    if r.returncode == 0:
        # rc 0 만으로는 «봤다» 가 아니다 — 빈 파일 · 고장 난 가드도 0 을 낸다(codex R2). 가드의 깨끗함 선언을 같이 본다
        if b"outbound clean" not in r.stderr:
            raise NotScanned("L1 가드가 rc 0 인데 깨끗함 선언이 없다 — 가드가 돌았는지 모른다")
        return []
    if r.returncode == 1:
        return [("L1", "operator-literal", None)]
    raise NotScanned("L1 가드가 측정값을 안 냈다(rc=%d)" % r.returncode)


def ledger_path(arg):
    if arg:
        return arg
    base = os.environ.get("XDG_STATE_HOME") or os.path.join(os.path.expanduser("~"), ".local", "state")
    return os.path.join(base, "fh-abstract-consult", "ledger.jsonl")


def ledger_append(path, rec):
    d = os.path.dirname(path)
    if d:
        os.makedirs(d, mode=0o700, exist_ok=True)
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o600)
    with os.fdopen(fd, "a", encoding="utf-8") as f:
        f.write(json.dumps(rec, ensure_ascii=False) + "\n")


def ledger_read(path):
    if not os.path.isfile(path):
        return []
    out = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                out.append(json.loads(line))
    return out


def cmd_check(a):
    q = open(a.question_file, encoding="utf-8").read() if a.question_file else sys.stdin.read()
    rec = {"ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "id": uuid.uuid4().hex[:12], "event": "check",
           "version": VERSION, "q_sha256": _sha(q), "repo_sha256": _sha(os.path.abspath(a.repo))}   # 경로 자체가 이름일 수 있다(codex R1)
    try:
        if not q.strip():
            raise NotScanned("빈 질문")
        words, allow = load_vocab(a.dict, a.allow, use_stdlib=not a.no_stdlib_vocab)
        inv = inventory(a.repo, words, allow, public_vocab(a.public_corpus))
        alive, pick = live_probe(inv)
        if not alive:
            raise NotScanned("계기 생사 실패 — 목록의 이름을 바꿔 넣은 탐침이 안 걸렸다")
        try:
            head = _git(a.repo, "rev-parse", "HEAD").decode().strip()
        except NotScanned:
            head = None
        found = run_guard(a.guard, q) + scan_repo_layers(q, inv)
        hits = [h for h in found if h[0] != "L2f"]
        flags = [h for h in found if h[0] == "L2f"]
        rc = 1 if hits else 0
        rec.update({"verdict": "hit" if hits else "clean", "repo_head": head, "inventory": inv[4],
                    "control": {"probe_hit": alive, "probe_sha256": _sha(pick) if pick else None}})
    except NotScanned as e:
        hits, flags, rc = [], [], 3
        rec.update({"verdict": "not-scanned", "reason": str(e)})
    rec["hits"] = [{"layer": l, "kind": k, "sha256": _sha(t) if t else None} for l, k, t in hits]
    rec["flags"] = [{"layer": l, "kind": k, "sha256": _sha(t)} for l, k, t in flags]
    if rc == 0:
        rec["question"] = q              # 깨끗한 것만 본문을 남긴다
    if not a.no_ledger:
        try:
            ledger_append(ledger_path(a.ledger), rec)
        except OSError as e:
            print("🚫 원장 기록 실패: %s — 기록 없는 판정은 내지 않는다" % e, file=sys.stderr)
            return 3
    shown = {k: v for k, v in rec.items() if k != "question"}
    shown["hits"] = [{"layer": l, "kind": k, "token": t} for l, k, t in hits]   # 로컬 터미널에만 — 원장엔 안 쓴다
    shown["flags"] = [{"layer": l, "kind": k, "token": t} for l, k, t in flags]
    print(json.dumps(shown, ensure_ascii=False, indent=1))
    if rc == 3:
        print("🚫 NOT SCANNED — %s. 미측정은 깨끗함이 아니다." % rec.get("reason"), file=sys.stderr)
    elif rc == 1:
        print("🚫 걸림 %d건 — 이름을 역할 · 유형으로 바꿔 다시 검사하라." % len(hits), file=sys.stderr)
    else:
        print("✅ clean — 보내기 전 사람 확인이 남았다(자동 판정 혼자로는 못 지나간다)%s"
              % (" · 강조할 레포 식별자 %d건(flags)" % len(flags) if flags else ""), file=sys.stderr)
    return rc


def _find(recs, cid):
    for r in recs:
        if r.get("event") == "check" and r.get("id") == cid:
            return r
    return None


def cmd_decide(a):
    path = ledger_path(a.ledger)
    chk = _find(ledger_read(path), a.id)
    if chk is None:
        print("🚫 원장에 없는 id: %s" % a.id, file=sys.stderr)
        return 1
    if a.decision == "sent" and chk.get("verdict") != "clean":
        print("🚫 판정이 %s 인 질문은 «보냄» 으로 기록할 수 없다 — 고쳐서 다시 검사하라" % chk.get("verdict"), file=sys.stderr)
        return 1
    ledger_append(path, {"ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "event": "decide",
                         "id": a.id, "decision": a.decision, "by": a.by})
    return 0


def cmd_replay(a):
    path = ledger_path(a.ledger)
    recs = ledger_read(path)
    if _find(recs, a.id) is None:
        print("🚫 원장에 없는 id: %s" % a.id, file=sys.stderr)
        return 1
    if not any(r.get("event") == "decide" and r.get("id") == a.id and r.get("decision") == "sent" for r in recs):
        print("🚫 «보냄» 기록이 없는 질문에는 재현 결과를 붙이지 않는다", file=sys.stderr)
        return 1
    ledger_append(path, {"ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "event": "replay",
                         "id": a.id, "test_rc": a.rc})
    return 0


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    c = sub.add_parser("check")
    c.add_argument("--repo", required=True)
    c.add_argument("--question-file")
    c.add_argument("--dict", default="/usr/share/dict/words")
    c.add_argument("--allow")
    c.add_argument("--no-stdlib-vocab", action="store_true",
                   help="표준 라이브러리 본문 낱말을 공개 어휘에 넣지 않는다(레인 · 재현용)")
    c.add_argument("--public-corpus", action="append", default=[],
                   help="공개 소스 디렉터리(반복 가능) — 여기 나오는 이름은 비공개 실체로 안 친다")
    c.add_argument("--guard", default=os.path.join(HERE, "outbound_query_guard.sh"))
    c.add_argument("--ledger")
    c.add_argument("--no-ledger", action="store_true")
    d = sub.add_parser("decide")
    d.add_argument("--ledger")
    d.add_argument("--id", required=True)
    d.add_argument("--decision", required=True, choices=["sent", "edited", "dropped"])
    d.add_argument("--by", default="operator")
    r = sub.add_parser("replay")
    r.add_argument("--ledger")
    r.add_argument("--id", required=True)
    r.add_argument("--rc", required=True, type=int)
    a = ap.parse_args(argv)
    return {"check": cmd_check, "decide": cmd_decide, "replay": cmd_replay}[a.cmd](a)


if __name__ == "__main__":
    sys.exit(main())
