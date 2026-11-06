#!/usr/bin/env python3
"""lane_gap_hint.py — UserPromptSubmit hook: «last turn changed code but ran no test/lane» → one line of context.

Operator 2026-11-06 («추천대로», from the stop-hook video review `tracks/_meta/video_stophook_review_2026-11-06.md`):
FH does NOT block at Stop. Blocking stays at the irreversible edge (pre-push / session close). This hook only RECORDS:
when the previous assistant turn edited code files and ran no test or lane command, the next prompt gets one line saying so.
It is a property of the record (edits seen · runs seen), never a verdict on whether the change is correct.

What counts (deliberately simple — named, not hidden):
  edit = an Edit / Write / MultiEdit / NotebookEdit tool call on a code path (*.sh *.py *.js *.mjs *.cjs *.ts *.tsx *.go *.rs *.rb *.java)
  run  = a Bash command naming a test/lane: test_* · *_lanes.sh · selfcheck · pytest · «node --test» · «npm test» · «go test» ·
         «cargo test» · «make test» · unittest
  the previous turn = tool calls after the last real user prompt in the transcript (the current prompt is not in it yet).
Silent when: nothing edited · something ran · the transcript is unreadable (an unreadable transcript is not «no gap» — it
is no statement at all, and saying nothing is the honest output for an advisory hook). Never blocks: exit 0 on every path.
Opt out: FH_LANE_GAP_HINT=0.
"""
import json
import os
import re
import sys

CODE = re.compile(r"\.(sh|py|js|mjs|cjs|ts|tsx|go|rs|rb|java|ipynb)$")
# a statement that RUNS a test/lane — anchored at the statement's start (after env assignments and an interpreter), so that
# «git diff scripts/test_x_lanes.sh» · «echo pytest» · «rg test_x» do not count (codex R1: mentions silenced the hint)
RUN_STMT = re.compile(r"^(?:\w+=\S*\s+)*(?:(?:bash|sh|zsh|python3?|node|timeout\s+\S+)\s+(?:-\S+\s+)*)?"
                      r"(?:\S*/)?(?:test_[\w.-]+|[\w.-]*_lanes\.sh|selfcheck(?:\.sh)?)\b"
                      r"|^(?:\w+=\S*\s+)*(?:python3?\s+-m\s+)?(?:pytest|unittest)\b"
                      r"|^(?:\w+=\S*\s+)*(?:node\s+--test|npm\s+(?:run\s+)?test|go\s+test|cargo\s+test|make\s+test)\b")


def _strip_noise(cmd):
    """drop heredoc bodies and «# …» comments outside quotes — text, not commands (codex R2). Named residual: conditional
    execution («false && pytest») still counts as a run; this is an advisory hook and shell semantics do not converge."""
    lines, out, end = cmd.split("\n"), [], None
    for ln in lines:
        if end is not None:
            if ln.strip() == end:
                end = None
            continue
        m = re.search(r"<<-?\s*['\"]?(\w+)['\"]?", ln)
        q, keep = None, ""
        for ch in ln:
            if q:
                q = None if ch == q else q
            elif ch in "'\"":
                q = ch
            elif ch == "#" and (not keep or keep[-1].isspace()):
                break
            keep += ch
        out.append(keep)
        if m:
            end = m.group(1)
    return "\n".join(out)


def _statements(cmd):
    cmd = _strip_noise(cmd)
    out, cur, q = [], "", None
    i = 0
    while i < len(cmd):
        c = cmd[i]
        if q:
            cur += c
            q = None if c == q else q
        elif c in "'\"":
            q = c; cur += c
        elif cmd.startswith("&&", i) or cmd.startswith("||", i):
            out.append(cur); cur = ""; i += 1
        elif c in ";|\n":
            out.append(cur); cur = ""
        else:
            cur += c
        i += 1
    out.append(cur)
    # quotes around the program name do not hide a run («"pytest" -q»)
    return [" ".join(x.replace('"', "").replace("'", "").split()) for x in out if x.strip()]


def _runs_tests(cmd):
    return any(RUN_STMT.search(st) for st in _statements(cmd))
EDIT_TOOLS = {"Edit", "Write", "MultiEdit", "NotebookEdit"}
TAIL = 4 * 1024 * 1024


def _is_real_prompt(d):
    """a user line typed by the person — not a tool_result, not a meta/hook line"""
    if d.get("type") != "user" or d.get("isMeta") or d.get("isSidechain"):
        return False
    c = (d.get("message") or {}).get("content")
    if isinstance(c, str):
        return bool(c.strip())
    if isinstance(c, list):   # text or image typed by the person; a line carrying a tool_result is the tool talking back
        return any(isinstance(x, dict) and x.get("type") in ("text", "image") for x in c) and not any(
            isinstance(x, dict) and x.get("type") == "tool_result" for x in c)
    return False


def last_turn(path):
    """→ (edited code paths, test/lane commands) of the tool calls after the last real user prompt, or None if unreadable."""
    try:
        with open(path, "rb") as f:
            f.seek(0, 2)
            n = f.tell()
            f.seek(max(0, n - TAIL))
            lines = f.read().decode("utf-8", "replace").splitlines()
    except OSError:
        return None
    rows = []
    for l in lines:
        try:
            rows.append(json.loads(l))
        except ValueError:
            continue
    start = max((i for i, d in enumerate(rows) if isinstance(d, dict) and _is_real_prompt(d)), default=None)
    if start is None:
        return None   # the tail cut off the turn's start — a partial turn is no statement (codex R1)
    edits, runs, pending = [], [], {}
    for d in rows[start + 1:]:
        if not isinstance(d, dict) or d.get("isSidechain"):
            continue   # a subagent's prompts and tools are not this session's turn
        c = (d.get("message") or {}).get("content")
        if not isinstance(c, list):
            continue
        for x in c:
            if not isinstance(x, dict):
                continue
            if x.get("type") == "tool_use":
                inp = x.get("input") or {}
                if x.get("name") in EDIT_TOOLS:
                    p = inp.get("file_path") or inp.get("notebook_path") or ""
                    if isinstance(p, str) and CODE.search(p):
                        pending[x.get("id")] = p
                elif x.get("name") == "Bash" and isinstance(inp.get("command"), str) and _runs_tests(inp["command"]):
                    runs.append(inp["command"])
            elif x.get("type") == "tool_result" and x.get("tool_use_id") in pending:
                p = pending.pop(x.get("tool_use_id"))
                if x.get("is_error") is not True:
                    edits.append(p)   # only an edit that went through counts (a failed Edit changed nothing)
    return edits, runs


def main():
    try:
        if os.environ.get("FH_LANE_GAP_HINT") == "0":
            return 0
        ev = json.load(sys.stdin)
        tp = ev.get("transcript_path")
        if not (isinstance(tp, str) and os.path.isabs(tp)):
            return 0
        r = last_turn(tp)
        if r is None:
            return 0
        edits, runs = r
        if edits and not runs:
            uniq = sorted(set(os.path.basename(p) for p in edits))
            shown = ", ".join(uniq[:4]) + (f" 외 {len(uniq) - 4}" if len(uniq) > 4 else "")
            print(f"[lane-gap] 지난 턴에 코드 파일 {len(uniq)}개({shown})를 바꿨는데 테스트·레인 실행 기록이 0이다 — "
                  f"확인을 안 했으면 이번 턴에 돌려라. (기록일 뿐 판정·차단 아님 · 끄기 FH_LANE_GAP_HINT=0)")
    except Exception:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
