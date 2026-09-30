#!/usr/bin/env python3
# resident_cost.py — 세션 시작 «전» 상주 비용을 한 번에 재는 읽기 전용 계기 (2026-10-01 신설).
#
# 왜: 경량화를 논의하기 전에 «얼마인가» 를 같은 정의로 재야 한다. 2026-09-30 하루에 두 번 틀렸다 —
#   ① CLAUDE.md 를 `wc -c`(바이트)로 재서 «153k 자» 라고 말했다(실제 136,889자 — 한글 1자 = 3바이트)
#   ② 스킬 설명 합을 한 줄 파싱으로 재서 25,488 이라 적었다(YAML 파싱 = 19,473 — 접힌 블록 `>-` 를 못 읽음)
#   둘 다 계기가 없어서 생긴 오류다(tracks/_meta/research_2026-09-30_fh-lightweight-environment.md 부록).
#
# 무엇을 세나 — 줄마다 «이름 · 문자 · 바이트 · 출처».
#   문자 = UTF-8 디코드 후 len(). Claude Code 의 150.0k 경고와 MEMORY 절단이 문자 단위다(아래 보정).
#   1 레포 CLAUDE.md (tracked) — 150,000자 경고선까지 여유
#   2 CLAUDE.local.md (gitignored) — 없으면 «없음»(0 아님)
#   3 사용자 전역 ~/.claude/CLAUDE.md + 그 파일들이 `@경로` 로 import 하는 파일(재귀, 깊이 5, 순환 차단)
#   4 자동 메모리 MEMORY.md — 전체 · 공식 상한(첫 200줄 또는 25KB) · 이 머신 실측 상한(25,000자)
#   5 스킬 목록 — plugins/*/skills/*/SKILL.md frontmatter 의 name + description, YAML 파싱(접힌 블록 포함).
#     한 줄 파싱 값이 다르면 둘 다 낸다
#   6 .claude/rules/*.md 중 `paths:` 가 없는 것(세션 시작에 상주). paths: 가 있으면 조건부라 0 이 아니라 «조건부»
#   합계 — 측정 못 한 칸은 0 으로 접지 않고 «미측정 N칸» 을 옆에 적는다.
#
# MEMORY 상한 보정 (known-pair, 실물 1건 — 2026-10-01): 이 세션의 로더가 «147 of 285 lines were cut off,
#   starting at "[컨트롤 있음 ≠ 판별력 있음]"» 를 보고했다. 같은 파일에 규칙 셋을 대 보면
#   25,000 **문자** → 첫 절단 줄 = 바로 그 항목(147줄 절단, 일치) · 25,000 바이트 → 91번째 줄 · 25,600 바이트 → 94번째 줄.
#   ⇒ 이 머신의 실제 상한은 «줄 단위로 25,000자» 다. 공식 문서 문구(200줄/25KB)도 같이 계산해 보인다 — 어긋남 자체가 정보다.
#   🟥 N=1 이다. 로더가 바뀌면 이 상수부터 다시 재라(--memory-cap-chars).
#
# 범위 밖(이름으로 남긴다): 시스템 프롬프트 · 이 레포 밖 플러그인의 스킬 목록 · MCP 도구 설명 · 토큰 수.
#   그래서 «합계» 는 «FH 가 좌우하는 상주분» 이지 세션 전체 비용이 아니다.
# CLAUDE.md 크기 «가드» 는 scripts/test_claude_md_size_lanes.sh 가 따로 한다(한계 145,000). 이건 계기지 게이트가 아니다.
#
# 사용: python3 scripts/resident_cost.py [--json] [--repo DIR] [--user-claude FILE] [--memory-dir DIR]
#                                        [--memory-cap-chars N] [--no-user]
#   환경변수: RESIDENT_COST_REPO · RESIDENT_COST_USER_CLAUDE · RESIDENT_COST_MEMORY_DIR (레인이 픽스처로 돌린다)
# 종료 코드: 0 = 전 칸 측정 · 3 = 미측정 칸 있음(합계는 나오지만 «전부» 가 아니다) · 2 = 인자 오류
import argparse
import glob
import json
import os
import re
import sys

CC_WARN_CHARS = 150000          # Claude Code: «CLAUDE.md is over the 150.0k-char limit»
MEM_CAP_CHARS_MEASURED = 25000  # 이 머신 실측(위 보정)
MEM_CAP_LINES_OFFICIAL = 200    # 공식 문서: 첫 200줄
MEM_CAP_BYTES_OFFICIAL = 25 * 1024  # 공식 문서: 25KB (KiB 로 읽음 — 문서가 단위를 안 밝힌다)
IMPORT_MAX_DEPTH = 5


def nchars(s):
    return len(s)


def nbytes(s):
    return len(s.encode("utf-8"))


HOME = os.path.expanduser("~")
_OTHER_HOME = re.compile(r"^(/Users/|/home/)[^/]+")


def show(path, mangled=None):
    """출력용 경로 — 홈은 ~ 로, 메모리 디렉터리의 cwd 변환 이름은 <project> 로 가린다(residency)."""
    p = os.path.abspath(path)
    if mangled and mangled in p:
        p = p.replace(mangled, "<project>")
    if p == HOME or p.startswith(HOME + os.sep):
        return "~" + p[len(HOME):]
    # 남의 홈 경로(인자로 넘어온 것)도 사용자명을 가린다(cross-family R1 #3)
    return _OTHER_HOME.sub(r"\1<user>", p)


def read_text(path):
    """(status, text, err). status ∈ ok · absent · unmeasured."""
    if not os.path.exists(path):
        return "absent", None, None
    try:
        with open(path, encoding="utf-8") as f:
            return "ok", f.read(), None
    except (OSError, UnicodeDecodeError) as e:
        return "unmeasured", None, f"{type(e).__name__}: {e}"


def row(name, path, status, text=None, err=None, mangled=None, **extra):
    r = {"name": name, "source": show(path, mangled), "status": status,
         "chars": None, "bytes": None}
    if status == "ok":
        r["chars"] = nchars(text)
        r["bytes"] = nbytes(text)
    if err:
        r["error"] = err
    r.update(extra)
    return r


# ── @import ────────────────────────────────────────────────────────────────────────────────────────
_FENCE = re.compile(r"^\s*(```|~~~)")
_INLINE_CODE = re.compile(r"`[^`]*`")
_IMPORT = re.compile(r"(?:(?<=\s)|^)@((?:~|\.{1,2})?/?[A-Za-z0-9_.\-/]+)")


def import_tokens(text):
    out, fenced = [], False
    for line in text.splitlines():
        if _FENCE.match(line):
            fenced = not fenced
            continue
        if fenced:
            continue
        for m in _IMPORT.finditer(_INLINE_CODE.sub("", line)):
            tok = m.group(1).rstrip(".,;:)")
            if tok:
                out.append(tok)
    return out


def path_shaped(tok):
    """대상이 없을 때 «해석 실패» 로 보고할 만큼 경로처럼 생겼나. `@me` 같은 맨 낱말은 대상이 없으면 조용히 무시한다.
    대상이 «있으면» 모양과 무관하게 import 로 센다 — 확장자 없는 `@LICENSE` 도 import 다(cross-family R1 #1)."""
    return "/" in tok or "." in tok


def resolve_import(tok, base_dir):
    if tok.startswith("~"):
        return os.path.expanduser(tok)
    if os.path.isabs(tok):
        return tok
    return os.path.normpath(os.path.join(base_dir, tok))


def follow_imports(path, text, label, rows, unresolved, seen, depth=1):
    if depth > IMPORT_MAX_DEPTH:
        return
    for tok in import_tokens(text):
        target = resolve_import(tok, os.path.dirname(os.path.abspath(path)))
        key = os.path.realpath(target)
        if key in seen:
            continue
        st, t, err = read_text(target)
        if st == "absent":
            if path_shaped(tok):
                unresolved.append({"from": show(path), "token": "@" + tok})
            continue
        seen.add(key)
        rows.append(row(f"{label} → @{tok}", target, st, t, err, depth=depth))
        if st == "ok":
            follow_imports(target, t, label, rows, unresolved, seen, depth + 1)


def claude_file(name, path, rows, unresolved, seen):
    st, t, err = read_text(path)
    r = row(name, path, st, t, err)
    rows.append(r)
    if st == "ok":
        seen.add(os.path.realpath(path))
        follow_imports(path, t, name, rows, unresolved, seen)
    return r


# ── MEMORY.md ──────────────────────────────────────────────────────────────────────────────────────
def prefix_lines(lines, limit, measure):
    """상한 안에 «통째로» 들어가는 줄 수. 줄 단위로 자른다(로더가 줄을 반으로 자르지 않는다 — 보정 실측)."""
    acc = 0
    for i, ln in enumerate(lines):
        n = measure(ln)
        if acc + n > limit:
            return i
        acc += n
    return len(lines)


def memory_row(mem_dir, cap_chars, mangled):
    path = os.path.join(mem_dir, "MEMORY.md")
    st, t, err = read_text(path)
    r = row("MEMORY.md (자동 메모리)", path, st, t, err, mangled=mangled)
    if st != "ok":
        return r
    lines = t.splitlines(keepends=True)
    n_meas = prefix_lines(lines, cap_chars, nchars)
    loaded = "".join(lines[:n_meas])
    n_line_cap = min(len(lines), MEM_CAP_LINES_OFFICIAL)
    n_byte_cap = prefix_lines(lines, MEM_CAP_BYTES_OFFICIAL, nbytes)
    n_off = min(n_line_cap, n_byte_cap)
    official_binds = ("없음(전체 적재)" if n_off == len(lines)
                      else "200줄" if n_line_cap < n_byte_cap
                      else "25KB" if n_byte_cap < n_line_cap else "200줄=25KB 동시")
    off = "".join(lines[:n_off])
    r.update({
        "lines": len(lines),
        "loaded_chars": nchars(loaded), "loaded_bytes": nbytes(loaded),
        "loaded_lines": n_meas, "cut_lines": len(lines) - n_meas,
        "cap_rule": f"줄 단위 {cap_chars:,}자 (이 머신 실측)",
        "official": {"lines": n_off, "chars": nchars(off), "bytes": nbytes(off),
                     "binds_first": official_binds,
                     "rule": f"첫 {MEM_CAP_LINES_OFFICIAL}줄 또는 25KB({MEM_CAP_BYTES_OFFICIAL:,} bytes)"},
    })
    return r


# ── skills ─────────────────────────────────────────────────────────────────────────────────────────
_FM = re.compile(r"\A---\r?\n(.*?)\r?\n---\r?\n", re.S)


def oneline_value(fm_text, key):
    for line in fm_text.splitlines():
        if line.startswith(key + ":"):
            return line[len(key) + 1:].strip()
    return ""


def skills_row(repo):
    pattern = os.path.join(repo, "plugins", "*", "skills", "*", "SKILL.md")
    files = sorted(glob.glob(pattern))
    src = os.path.join(repo, "plugins", "*", "skills", "*", "SKILL.md")
    if not files:
        return row("스킬 목록 (name+description)", src, "absent", files=0)
    try:
        import yaml  # noqa: WPS433 — 없으면 YAML 칸만 미측정, 한 줄 값은 그대로 낸다
    except ImportError:
        yaml = None
    y_name = y_desc = o_name = o_desc = 0
    y_bytes = 0
    bad = []
    for p in files:
        st, t, err = read_text(p)
        m = _FM.match(t or "") if st == "ok" else None
        if not m:
            bad.append(show(p) + (f" ({err})" if err else " (frontmatter 없음)"))
            continue
        fm = m.group(1)
        o_name += nchars(oneline_value(fm, "name"))
        o_desc += nchars(oneline_value(fm, "description"))
        if yaml is not None:
            try:
                d = yaml.safe_load(fm) or {}
            except yaml.YAMLError as e:
                bad.append(f"{show(p)} (YAML: {str(e).splitlines()[0]})")
                continue
            nm, ds = str(d.get("name", "") or ""), str(d.get("description", "") or "")
            y_name += nchars(nm)
            y_desc += nchars(ds)
            y_bytes += nbytes(nm) + nbytes(ds)
    r = {"name": "스킬 목록 (name+description)", "source": show(src), "files": len(files),
         "oneline": {"chars": o_name + o_desc, "desc_chars": o_desc}}
    if yaml is None:
        r.update(status="unmeasured", chars=None, bytes=None,
                 error="PyYAML 없음 — YAML 파싱 칸 미측정(한 줄 파싱 값은 접힌 블록을 못 읽으니 대신 쓰지 않는다)")
    elif bad:
        r.update(status="unmeasured", chars=None, bytes=None, error="파싱 실패: " + "; ".join(bad))
    else:
        r.update(status="ok", chars=y_name + y_desc, bytes=y_bytes, desc_chars=y_desc)
        r["oneline_differs"] = (o_name + o_desc) != (y_name + y_desc)
    return r


# ── rules ──────────────────────────────────────────────────────────────────────────────────────────
def rules_rows(repo):
    out = []
    for p in sorted(glob.glob(os.path.join(repo, ".claude", "rules", "*.md"))):
        st, t, err = read_text(p)
        r = row(".claude/rules/" + os.path.basename(p), p, st, t, err)
        if st == "ok":
            m = _FM.match(t)
            if m and re.search(r"^paths\s*:", m.group(1), re.M):
                r["status"] = "conditional"  # 그 경로를 읽을 때만 실린다 — 시작 상주 아님
        out.append(r)
    return out


def mangle(cwd):
    return re.sub(r"[^A-Za-z0-9]", "-", os.path.abspath(cwd))


def main(argv):
    ap = argparse.ArgumentParser(description="세션 시작 상주 비용 계기(읽기 전용)")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--repo", default=os.environ.get("RESIDENT_COST_REPO"))
    ap.add_argument("--user-claude", default=os.environ.get("RESIDENT_COST_USER_CLAUDE"))
    ap.add_argument("--memory-dir", default=os.environ.get("RESIDENT_COST_MEMORY_DIR"))
    ap.add_argument("--memory-cap-chars", type=int, default=MEM_CAP_CHARS_MEASURED)
    ap.add_argument("--no-user", action="store_true", help="사용자 전역 CLAUDE.md 줄을 뺀다")
    a = ap.parse_args(argv)

    repo = a.repo or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    if not os.path.isdir(repo):
        print(f"resident_cost: --repo 가 디렉터리가 아니다: {repo}", file=sys.stderr)
        return 2
    repo = os.path.abspath(repo)
    mangled = mangle(repo)
    mem_dir = a.memory_dir or os.path.join(HOME, ".claude", "projects", mangled, "memory")
    user_claude = a.user_claude or os.path.join(HOME, ".claude", "CLAUDE.md")

    rows, unresolved, seen = [], [], set()
    main_row = claude_file("CLAUDE.md (레포, tracked)", os.path.join(repo, "CLAUDE.md"), rows, unresolved, seen)
    claude_file("CLAUDE.local.md (gitignored)", os.path.join(repo, "CLAUDE.local.md"), rows, unresolved, seen)
    if not a.no_user:
        claude_file("~/.claude/CLAUDE.md (사용자 전역)", user_claude, rows, unresolved, seen)
    mem = memory_row(mem_dir, a.memory_cap_chars, mangled)
    rows.append(mem)
    rows.append(skills_row(repo))
    rows.extend(rules_rows(repo))

    total_c = total_b = 0
    unmeasured = []
    for r in rows:
        if r["status"] == "unmeasured":
            unmeasured.append(r["name"])
        elif r["status"] == "ok":
            c = r.get("loaded_chars", r["chars"])
            b = r.get("loaded_bytes", r["bytes"])
            total_c += c
            total_b += b
    headroom = (CC_WARN_CHARS - main_row["chars"]) if main_row["status"] == "ok" else None
    result = {
        "rows": rows, "unresolved_imports": unresolved,
        "claude_md_warn_line": CC_WARN_CHARS, "claude_md_headroom": headroom,
        "total": {"chars": total_c, "bytes": total_b, "unmeasured_cells": len(unmeasured),
                  "unmeasured": unmeasured,
                  "note": "MEMORY 는 적재분만 · rules 는 paths 없는 것만 · 스킬은 이 레포 것만"},
        "scope_excluded": ["시스템 프롬프트", "이 레포 밖 플러그인 스킬 목록", "MCP 도구 설명", "토큰 수"],
    }
    if a.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        render(result)
    return 3 if unmeasured else 0


def fmt(n):
    return "—" if n is None else f"{n:,}"


def render(res):
    label = {"absent": "없음", "unmeasured": "미측정", "conditional": "조건부(paths)"}
    print(f"{'이름':<44} {'문자':>9} {'바이트':>9}  출처")
    for r in res["rows"]:
        st = r["status"]
        if st == "ok":
            c, b = fmt(r["chars"]), fmt(r["bytes"])
        else:
            c, b = label[st], ""
        print(f"{r['name']:<44} {c:>9} {b:>9}  {r['source']}")
        if "loaded_chars" in r:
            o = r["official"]
            print(f"{'  └ 적재분 (' + r['cap_rule'] + ')':<44} {fmt(r['loaded_chars']):>9} {fmt(r['loaded_bytes']):>9}"
                  f"  {r['loaded_lines']}/{r['lines']}줄 · 절단 {r['cut_lines']}줄")
            print(f"{'  └ 공식 문구 (' + o['rule'] + ')':<44} {fmt(o['chars']):>9} {fmt(o['bytes']):>9}"
                  f"  {o['lines']}/{r['lines']}줄 · 먼저 걸리는 쪽 = {o['binds_first']}")
        if "oneline" in r:
            ol = r["oneline"]
            if st == "ok" and r.get("oneline_differs"):
                print(f"{'  └ 한 줄 파싱 (접힌 블록 못 읽음)':<44} {fmt(ol['chars']):>9} {'':>9}"
                      f"  {r['files']}파일 · YAML 설명만 {fmt(r['desc_chars'])} / 한 줄 설명만 {fmt(ol['desc_chars'])}")
            elif st == "ok":
                print(f"{'  └ 한 줄 파싱 = YAML 파싱 (일치)':<44} {'':>9} {'':>9}  {r['files']}파일")
            else:
                print(f"{'  └ 한 줄 파싱 (참고용)':<44} {fmt(ol['chars']):>9}")
        if r.get("error"):
            print(f"    ! {r['error']}")
    for u in res["unresolved_imports"]:
        print(f"  (import 해석 실패 — 적재 안 됨: {u['token']} in {u['from']})")
    if res["claude_md_headroom"] is not None:
        print(f"CLAUDE.md 150,000자 경고선까지 여유: {res['claude_md_headroom']:,}자")
    t = res["total"]
    tail = f"  · 미측정 {t['unmeasured_cells']}칸 ({', '.join(t['unmeasured'])})" if t["unmeasured_cells"] else "  · 미측정 0칸"
    if res["unresolved_imports"]:
        tail += f"  · 대상 없는 import 후보 {len(res['unresolved_imports'])}개(적재 안 됨 — CC 파서와 대조 안 함)"
    print(f"합계 (FH 가 좌우하는 상주분): {t['chars']:,}자 / {t['bytes']:,} bytes{tail}")
    print(f"  ({t['note']} · 범위 밖: {', '.join(res['scope_excluded'])})")


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
