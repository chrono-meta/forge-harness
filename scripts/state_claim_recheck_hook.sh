#!/usr/bin/env bash
# state_claim_recheck_hook.sh — the READ half of context continuity, at the moment it is needed.
#
#   stop    (Stop hook)             : the answer just given names «#N» next to a merge / permission /
#                                     «morning» word, and the lease file (CLAUDE.local.md) has a line
#                                     for that number → write one pending note for this session.
#   prompt  (UserPromptSubmit hook) : a pending note exists for this session → inject it once as
#                                     additionalContext, then remove it.
#
# WHY. Measured 2026-11-07 (tracks/_meta/measure_reread_before_state_claim_2026-11-07.md, isolated
# 3rd round, 15 Sonnet runs): with the lease line present and no instruction, 5/5 relays repeated the
# stale state («merge is for the morning») and opened the file 0 times; with an in-the-moment
# instruction, 5/5 quoted the newer «머지해» line. The same rule sitting in the memory index had no
# effect. So the fix sits at the moment, not in resident memory: after the claim, before the next turn.
#
# WHAT IT CLAIMS. A record property only — «a line naming #N exists in the lease file, here».
# It does not judge whether the claim was wrong, and it never blocks (exit 0 always). Number
# collisions across repos (FH #203 vs FoD #203) are reported as-is; the reader decides.
#
# DEGRADE: silent. No python3, no lease file, no matching line, unreadable input → nothing, exit 0.
# Named residual: an answer that states a PR's status without the «#N» form, or without one of the
# words below, is not seen (word recall is the instrument's limit).
#
# Env: FH_LEASE_FILE (default $HUB/CLAUDE.local.md) · FH_STATE_CLAIM_DIR (pending notes; default
#      ${TMPDIR:-/tmp}/fh_state_claim). Tests: scripts/test_state_claim_recheck_lanes.sh
set -uo pipefail

MODE="${1:-}"
case "$MODE" in stop|prompt) ;; *) exit 0 ;; esac
command -v python3 >/dev/null 2>&1 || exit 0

HUB="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || echo "$HOME/projects/forge-harness")}"
export FH_SC_MODE="$MODE"
export FH_SC_LEASE="${FH_LEASE_FILE:-$HUB/CLAUDE.local.md}"
export FH_SC_DIR="${FH_STATE_CLAIM_DIR:-${TMPDIR:-/tmp}/fh_state_claim}"

# The hook payload arrives on stdin; the program goes in by -c so the two never compete for stdin.
python3 -c '
import hashlib, json, os, re, sys

def main():

    mode, lease, pdir = os.environ["FH_SC_MODE"], os.environ["FH_SC_LEASE"], os.environ["FH_SC_DIR"]
    try:
        ev = json.load(sys.stdin)
    except Exception:
        sys.exit(0)
    if not isinstance(ev, dict) or not isinstance(ev.get("session_id"), str) or not ev["session_id"]:
        sys.exit(0)   # no session id → no safe pending file (sessions must not share one)
    sid = hashlib.sha256(ev["session_id"].encode("utf-8")).hexdigest()[:32]
    pending = os.path.join(pdir, sid + ".txt")

    if mode == "prompt":
        try:
            with open(pending, encoding="utf-8") as f:
                note = f.read().strip()
            os.remove(pending)
        except Exception:
            sys.exit(0)
        if note:
            print(json.dumps({"hookSpecificOutput": {"hookEventName": "UserPromptSubmit",
                                                     "additionalContext": note}}, ensure_ascii=False))
        sys.exit(0)

    # mode == stop
    if ev.get("stop_hook_active"):
        sys.exit(0)
    text = ev.get("last_assistant_message")
    if not isinstance(text, str):
        text = ""
    if not text:
        # The LAST assistant message only (entries sharing its message id are its blocks). If that message
        # carries no text (tool calls only), stay silent rather than report an older answer as «just given».
        tp = ev.get("transcript_path") or ""
        try:
            last_id, chunks = None, []
            with open(tp, encoding="utf-8") as f:
                for line in f:
                    try:
                        o = json.loads(line)
                    except Exception:
                        continue
                    if not isinstance(o, dict) or o.get("type") != "assistant":
                        continue
                    m = o.get("message") if isinstance(o.get("message"), dict) else {}
                    mid = m.get("id") or o.get("uuid")
                    if mid is None or mid != last_id:   # unidentified entry = its own message
                        last_id, chunks = mid, []
                    c = m.get("content")
                    if isinstance(c, list):
                        chunks += [b.get("text", "") for b in c if isinstance(b, dict) and b.get("type") == "text"]
                    elif isinstance(c, str):
                        chunks.append(c)
            text = "\n".join(t for t in chunks if isinstance(t, str) and t)
        except Exception:
            sys.exit(0)
    if not text.strip():
        sys.exit(0)

    WORDS = re.compile(r"머지|병합|허락|승인|아침|발행|다시 묻|묻는다|리스|merge|approv|publish|morning|lease", re.I)
    # A number counts only when it shares a clause with a state word («Merge #123 tomorrow. Read the #456
    # diff.» → #123 only). Clauses split on . ! ? ; and line breaks; the clause just before a state word also counts.
    nums = set()
    clauses = re.split(r"[.!?。;；]+|\n+", text)
    for k, clause in enumerate(clauses):
        if WORDS.search(clause):
            # this clause, and the one right before it («#387 은 CI 초록. 머지는 아침에.» is one claim)
            for c in clauses[max(0, k - 1):k + 1]:
                nums.update(re.findall(r"#(\d{1,6})(?!\d)", c))
    nums = sorted(nums, key=int)
    if not nums:
        sys.exit(0)
    try:
        with open(lease, encoding="utf-8") as f:
            lines = f.read().splitlines()
    except Exception:
        sys.exit(0)

    hits, matched = [], []
    for n in nums:
        pat = re.compile(r"#" + n + r"(?!\d)")
        for i, ln in enumerate(lines, 1):
            if "utterance" in ln and pat.search(ln):
                s = ln.strip()
                hits.append("  #%s · L%d: %s" % (n, i, s[:160] + ("…" if len(s) > 160 else "")))
                if n not in matched:
                    matched.append(n)
    if not hits:
        sys.exit(0)
    shown = hits[:8]
    more = len(hits) - len(shown)
    note = ("\U0001f50e [state-claim] 직전 답이 " + ", ".join("#" + n for n in matched) +
            " 의 머지·허락·아침류 상태를 말했다. 리스 파일에 그 번호 «utterance» 줄이 있다 — "
            "상태를 다시 말하기 전에 그 줄을 열어라(" + lease + "):\n" + "\n".join(shown) +
            ("\n  … 그 밖 %d줄" % more if more > 0 else "") +
            "\n기계는 «줄이 있다» 만 말한다. 직전 주장이 틀렸는지는 판단하지 않는다(번호가 다른 레포 것일 수 있다).")
    try:
        os.makedirs(pdir, exist_ok=True)
        with open(pending, "w", encoding="utf-8") as f:
            f.write(note + "\n")
    except Exception:
        pass
    sys.exit(0)

try:
    main()
except SystemExit:
    raise
except Exception:
    pass   # degrade is silent: a hook traceback is noise on every stop
sys.exit(0)
'
exit 0
