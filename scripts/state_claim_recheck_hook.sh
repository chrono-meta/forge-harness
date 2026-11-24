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
# ARCHIVE. Expired lease lines are moved verbatim into a gitignored archive (2026-11-20: 225 lines of
# 2026-11-06..11-19). Its «utterance» lines are searched too and labelled «보관 · 만료» — an expired
# record, not a live grant. Resident-file hits come first and their wording is unchanged; the archive
# only adds lines under the same 8-line cap. Archive missing (general users have none) → silent.
#
# ONCE PER CONTEXT (2026-11-23, AQ-20261107-29 ⓐ). First live use re-sent the same #1048 note two turns
# running. A lease line is now shown at most once per session *between compactions*: after a note is printed,
# the keys of the lines it showed (#N + the line text, not its line number) go to <sid>.c<K>.seen, where K is
# the number of compact_boundary entries in the transcript (a compaction drops the earlier note from the
# model's context, so it starts a new seen file). A later stop drops hits whose key is there; a new or edited
# lease line for the same #N has a new key and fires. Only shown lines are marked (lines past the 8-line cap
# stay unseen), and only after the print. The note and its keys are one file written by rename.
# Fails open: seen file unreadable → empty; transcript unreadable → K=0. Named limits: a line removed and
# re-added verbatim stays seen until the next compaction; the header names only the not-yet-seen numbers;
# seen files are small and left in FH_STATE_CLAIM_DIR; an edit past the 160-char display cut re-fires a line
# that looks unchanged.
#
# Env: FH_LEASE_FILE (default $HUB/CLAUDE.local.md) ·
#      FH_LEASE_ARCHIVE (default $HUB/tracks/_meta/claude_local_lease_archive.md) · FH_STATE_CLAIM_DIR (pending notes; default
#      ${TMPDIR:-/tmp}/fh_state_claim). Tests: scripts/test_state_claim_recheck_lanes.sh
set -uo pipefail

MODE="${1:-}"
case "$MODE" in stop|prompt) ;; *) exit 0 ;; esac
command -v python3 >/dev/null 2>&1 || exit 0

HUB="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || echo "$HOME/projects/forge-harness")}"
export FH_SC_MODE="$MODE"
export FH_SC_LEASE="${FH_LEASE_FILE:-$HUB/CLAUDE.local.md}"
export FH_SC_ARCHIVE="${FH_LEASE_ARCHIVE:-$HUB/tracks/_meta/claude_local_lease_archive.md}"
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
    SEP = "\n\x1f"   # pending file = note + SEP + seen-file name + TAB + keys (comma-joined)

    if mode == "prompt":
        try:
            with open(pending, encoding="utf-8") as f:
                raw = f.read()
            os.remove(pending)
        except Exception:
            sys.exit(0)
        note, _, tail = raw.partition(SEP)
        note = note.strip()
        if note:
            print(json.dumps({"hookSpecificOutput": {"hookEventName": "UserPromptSubmit",
                                                     "additionalContext": note}}, ensure_ascii=False))
            sys.stdout.flush()
            # mark only after the note went out; any failure leaves the lines unseen (fail open)
            try:
                name, _, keys = tail.strip().partition("\t")
                keys = [k for k in keys.split(",") if re.fullmatch(r"[0-9a-f]{24}", k)]
                if keys and re.fullmatch(re.escape(sid) + r"\.c\d+\.seen", name):
                    with open(os.path.join(pdir, name), "a", encoding="utf-8") as f:
                        f.write("\n".join(keys) + "\n")
            except Exception:
                pass
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
    # Quoted or code spans that carry a #N are examples, citations or this hook own echoed note, not the
    # answer stating a status (measured 2026-11-07: both first live firings were an example in «…»). Only the
    # spans holding a #N are dropped, so a state word quoted elsewhere still counts. Named limit: a real
    # status claim written inside quotes is no longer seen.
    # A span that is one token («#387», `#387`) is a name, not an example — it stays, so «`#387` merged.»
    # still counts. Quotes may span lines (up to 400 chars); an unclosed code fence runs to the end.
    # Named limit: nested quotes of the same kind end at the first closer.
    QUOTED = re.compile(r"```.*?(?:```|\Z)|`[^`\n]*`|«[^»]{0,400}»|“[^”]{0,400}”|\"[^\"]{0,400}\"|「[^」]{0,400}」", re.S)
    def _drop(m):
        s = m.group(0)
        return " " if re.search(r"#\d", s) and re.search(r"\s", s.strip("`«»“”\"「」")) else s
    text = QUOTED.sub(_drop, text)
    NOTE = re.compile(r"\[state-claim\]|^\s*(?:\[보관 · 만료\] )?#\d+ · L\d+: |^\s*… 그 밖 \d+줄|기계는 «줄이 있다»")
    text = "\n".join(l for l in text.split("\n") if not NOTE.search(l))
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
    ARCHIVE_ON = True
    archive = os.environ.get("FH_SC_ARCHIVE", "")
    sources = [(lease, "")]
    if ARCHIVE_ON and archive and os.path.isfile(archive) and os.path.realpath(archive) != os.path.realpath(lease):
        sources.append((archive, "[보관 · 만료] "))

    # compaction count: a compact_boundary entry means the earlier notes left the model context
    ncomp = 0
    try:
        with open(ev.get("transcript_path") or "", "rb") as f:
            for bl in f:
                if b"compact_boundary" in bl:
                    try:
                        o = json.loads(bl)
                    except Exception:
                        continue
                    if isinstance(o, dict) and o.get("type") == "system" and o.get("subtype") == "compact_boundary":
                        ncomp += 1
    except Exception:
        ncomp = 0
    seenname = "%s.c%d.seen" % (sid, ncomp)
    seenf = os.path.join(pdir, seenname)
    SEEN_ON = True
    seen = set()
    if SEEN_ON:
        try:
            with open(seenf, encoding="utf-8") as f:
                seen = set(l.strip() for l in f if l.strip())
        except Exception:
            seen = set()   # unreadable or absent → nothing is suppressed
    hits, matched, read_from, keys = [], [], [], []
    for path, tag in sources:
        try:
            with open(path, encoding="utf-8", errors=("replace" if tag else "strict")) as f:
                lines = f.read().splitlines()
        except Exception:
            continue   # either file may be absent; a missing one is silent
        found = False
        for n in nums:
            pat = re.compile(r"#" + n + r"(?!\d)")
            for i, ln in enumerate(lines, 1):
                if "utterance" in ln and pat.search(ln):
                    s = ln.strip()
                    key = hashlib.sha256(("%s\x00%s\x00%s" % (tag, n, s)).encode("utf-8")).hexdigest()[:24]
                    if key in seen:
                        continue   # this line was already shown in this session
                    keys.append(key)
                    hits.append("  %s#%s · L%d: %s" % (tag, n, i, s[:160] + ("…" if len(s) > 160 else "")))
                    found = True
                    if n not in matched:
                        matched.append(n)
        if found:
            read_from.append(path + (" (보관 파일 — 만료된 기록, 지금 유효한 허락 아님)" if tag else ""))
    if not hits:
        sys.exit(0)
    shown = hits[:8]
    shown_keys = keys[:8]
    more = len(hits) - len(shown)
    note = ("\U0001f50e [state-claim] 직전 답이 " + ", ".join("#" + n for n in matched) +
            " 의 머지·허락·아침류 상태를 말했다. " + ("리스·보관 파일" if len(read_from) > 1 or (read_from and "보관 파일" in read_from[0]) else "리스 파일") + "에 그 번호 «utterance» 줄이 있다 — "
            "상태를 다시 말하기 전에 그 줄을 열어라(" + " · ".join(read_from) + "):\n" + "\n".join(shown) +
            ("\n  … 그 밖 %d줄" % more if more > 0 else "") +
            ("\n[보관 · 만료] 줄은 이미 만료된 기록이다 — 지금 유효한 허락으로 읽지 마라." if any(r.endswith("허락 아님)") for r in read_from) else "") +
            "\n기계는 «줄이 있다» 만 말한다. 직전 주장이 틀렸는지는 판단하지 않는다(번호가 다른 레포 것일 수 있다).")
    try:
        os.makedirs(pdir, exist_ok=True)
        tmp = pending + ".tmp%d" % os.getpid()
        with open(tmp, "w", encoding="utf-8") as f:
            f.write(note + SEP + seenname + "\t" + ",".join(shown_keys) + "\n")
        os.replace(tmp, pending)
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
