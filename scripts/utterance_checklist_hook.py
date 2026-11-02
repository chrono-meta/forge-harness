#!/usr/bin/env python3
"""utterance_checklist_hook.py — body of scripts/utterance_checklist_hook.sh (UserPromptSubmit). See the .sh header for WHY.

Reads the hook JSON on STDIN (never through the environment: a multi-MB prompt hit E2BIG and silently disabled the hook —
codex R1 B7). Contract: exit 0 always, output only JSON hookSpecificOutput.additionalContext on stdout, never write outside
<hub>/tracks/_meta/utterances/, never follow a symlink there, never block on a FIFO or a held lock.

codex R1 (2026-10-18, 12 findings) fixed here: symlink escape (A1) · FIFO/lock stall (A2) · unlocked read-modify-write (B3) ·
counter advanced on a failed append (B4) · «<…» / short real requests dropped (B5) · silent truncation (B6) · env E2BIG (B7) ·
HOME unbound (B8, in the .sh) · Japanese/Chinese read as Korean, pasted code counted (B9) · unquoted path in the suggested
command (B10) · a status label the checker rejects (B12).
"""
import errno, fcntl, json, os, re, shlex, stat, sys, time

ACK = re.compile(r"^(?:ㅇ+|ㄱ+|ㅇㅋ+|ㅇㅇㄱㄱ|ㄴㄴ|ok(?:ay)?|ㅇㅋㅇㅋ|넵|네+|응+|좋아|굿|확인(?:완료)?|ㄱㄱ+|go|yes|y|no|n|ㅋ+|ㅎ+)[\s.!~?ㅋㅎ]*$", re.I)
INJECTED = re.compile(r"^\s*(?:<(?:task-notification|system-reminder|command-name|command-message|command-args|local-command-stdout|local-command-stderr|bash-input|bash-stdout|bash-stderr|agent-message)\b|\[SYSTEM NOTIFICATION|\[Cross-session delivery notice\]|\[automated-run)", re.I)
MAX_KEEP = 20000          # chars kept per utterance; longer ones are marked truncated, never cut silently
MAX_SCAN = 20000          # chars scanned for language (bounded work on huge pastes)


def safe_dir(hub):
    """<hub>/tracks/_meta/utterances as a real directory inside the hub, or None. No symlink anywhere on the last two hops."""
    meta = os.path.join(hub, "tracks", "_meta")
    d = os.path.join(meta, "utterances")
    try:
        tracks = os.path.dirname(meta)
        for p in (tracks, meta):
            if os.path.islink(p):
                return None
            if not os.path.lexists(p):
                try: os.mkdir(p, 0o700)
                except FileExistsError: pass               # a parallel first prompt made it (Sonnet R2 #4)
            if not stat.S_ISDIR(os.lstat(p).st_mode):
                return None
        if not os.path.lexists(d):
            try: os.mkdir(d, 0o700)
            except FileExistsError: pass
        st = os.lstat(d)
        if not stat.S_ISDIR(st.st_mode):            # a symlink or anything else → refuse
            return None
        real_hub = os.path.realpath(hub)
        if not os.path.realpath(d).startswith(real_hub + os.sep):
            return None
        return d
    except OSError:
        return None


DFD = None   # directory fd of utterances/ — every file opens relative to it (codex R2: the folder can't be swapped after the check)


def open_regular(name, flags, mode=0o600):
    """open <name> inside utterances/ via its directory fd, without following a symlink and without blocking on a FIFO;
    refuse anything but a regular file with a single link (a hard link would write into a file elsewhere — codex R2)."""
    fd = os.open(name, flags | os.O_NOFOLLOW | os.O_NONBLOCK, mode, dir_fd=DFD)
    try:
        st = os.fstat(fd)
        if not stat.S_ISREG(st.st_mode) or st.st_nlink != 1:
            raise OSError(errno.EINVAL, "not a single-link regular file")
        fl = fcntl.fcntl(fd, fcntl.F_GETFL)
        fcntl.fcntl(fd, fcntl.F_SETFL, fl & ~os.O_NONBLOCK)
        return fd
    except Exception:
        os.close(fd)
        raise


def prose_only(text):
    t = re.sub(r"```.*?```", " ", text[:MAX_SCAN], flags=re.S)     # fenced code
    t = re.sub(r"`[^`\n]*`", " ", t)                                 # inline code
    t = re.sub(r"https?://\S+|(?:~|/)[\w.\-/]+", " ", t)            # urls and paths
    return t


def main():
    try:
        raw = sys.stdin.buffer.read(32 * 1024 * 1024).decode("utf-8", "replace")
        ev = json.loads(raw)
    except Exception:
        return
    if not isinstance(ev, dict):
        return
    prompt = ev.get("prompt") if isinstance(ev.get("prompt"), str) else ""
    sid = ev.get("session_id") if isinstance(ev.get("session_id"), str) else ""
    if not prompt.strip() or not re.fullmatch(r"[A-Za-z0-9-]{8,80}", sid):
        return
    if INJECTED.match(prompt):
        return                                          # notices relayed by the runtime, not the operator
    text = prompt.strip()
    substantive = not (len(text) <= 40 and ACK.match(text))      # acks are short; never run the pattern on long text (codex R2)
    hub = os.environ.get("FH_HUB") or ""
    if not hub:
        return
    notes = []

    global DFD
    d = safe_dir(hub)
    if d:
        try:
            DFD = os.open(d, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
        except OSError:
            d = None
    if d:
        lock_p = sid + ".lock"
        lfd = None
        for _ in range(50):                                  # concurrent O_CREAT of one name fails transiently (ENOENT, measured on macOS) — a single try dropped the row
            try:
                lfd = open_regular(lock_p, os.O_RDWR | os.O_CREAT); break
            except OSError as e:
                if e.errno not in (errno.ENOENT, errno.EEXIST):
                    break
                time.sleep(0.01)
        if lfd is not None:
            locked = False
            # 3.0 s, not 0.3 s (operator decision 2026-11-02): a lock timeout skips the row in silence, and losing what
            # the operator asked for is worse than a pause under contention. codex R2's «never hold the prompt long»
            # still bounds it: the lock is held for milliseconds, so the wait only grows when many prompts land at once.
            # The intended waits (0.5 s of open retries + 3.0 s) sit under the 5 s hook timeout in .claude/settings.json;
            # scheduling and I/O are outside that sum. Residual: a holder past 3.0 s still skips the row in silence.
            deadline = time.monotonic() + 3.0
            while time.monotonic() < deadline:
                try:
                    fcntl.flock(lfd, fcntl.LOCK_EX | fcntl.LOCK_NB); locked = True; break
                except OSError:
                    time.sleep(0.02)
            if locked:
                try:
                    state_p = sid + ".state.json"
                    try:
                        sfd = open_regular(state_p, os.O_RDONLY)
                        if os.fstat(sfd).st_size > 65536:                # bounded: a state file is a few dozen bytes
                            os.close(sfd); raise ValueError
                        with os.fdopen(sfd, "r") as f:
                            st = json.load(f)
                        if not isinstance(st, dict):
                            raise ValueError
                    except Exception:
                        st = {"rows": 0, "acks": 0, "last_nudge": 0}
                    if substantive:
                        n_prev = int(st.get("rows", 0))
                        try:                                              # the record is the source of n — a failed state write must not repeat numbers (codex R2)
                            rfd = open_regular(sid + ".jsonl", os.O_RDONLY)
                            with os.fdopen(rfd, "rb") as f:
                                n_prev = max(n_prev, f.read(16 * 1024 * 1024).count(b"\n"))
                        except OSError:
                            pass
                        row = {"ts": time.strftime("%Y-%m-%dT%H:%M:%S"), "n": n_prev + 1, "text": text[:MAX_KEEP]}
                        if len(text) > MAX_KEEP:
                            row["truncated"] = True; row["chars"] = len(text)
                        try:
                            afd = open_regular(sid + ".jsonl", os.O_WRONLY | os.O_APPEND | os.O_CREAT)
                            with os.fdopen(afd, "a", encoding="utf-8") as f:
                                f.write(json.dumps(row, ensure_ascii=False) + "\n")
                            st["rows"] = row["n"]                 # count only what was really written down
                        except OSError:
                            pass
                    else:
                        st["acks"] = int(st.get("acks", 0)) + 1
                    try:
                        cadence = max(3, int(os.environ.get("FH_CHECKLIST_CADENCE", "15")))
                    except Exception:
                        cadence = 15
                    if substantive and int(st.get("rows", 0)) - int(st.get("last_nudge", 0)) >= cadence:
                        st["last_nudge"] = st["rows"]
                        tp = ev.get("transcript_path") if isinstance(ev.get("transcript_path"), str) and ev.get("transcript_path") else ""
                        out = f"tracks/_meta/session_checklist_{time.strftime('%Y-%m-%d')}_{sid[:8]}.md"
                        cmd = (f"python3 scripts/session_checklist.py extract --transcript {shlex.quote(tp)} --out {shlex.quote(out)}"
                               if tp else "python3 scripts/session_checklist.py extract --transcript (이 세션 전사본 경로) --out " + shlex.quote(out))
                        notes.append(
                            f"📋 [FH 체크리스트 점검 시점] 이 세션에서 받아 적은 운영자 발화가 {st['rows']}건이다(지난 점검 뒤 {cadence}건 이상). "
                            f"이번 답을 마치기 전에 체크리스트를 갱신하라: {cmd} → 상태 칸을 ✅DONE·🟡PARTIAL·⏳IN-PROGRESS·❌NOT-DONE·⏸HELD·🔎UNVERIFIED 중 하나로, "
                            f"완료는 증거·미완은 사유+제안과 함께 채우고 → 표를 운영자에게 보여라(열린 줄이 위로). 받아 적은 원문: tracks/_meta/utterances/{sid}.jsonl")
                    fd, tmp = None, f"{sid}.state.{os.getpid()}.tmp"
                    try:
                        fd = open_regular(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_EXCL)
                        with os.fdopen(fd, "w") as f:
                            json.dump(st, f)
                        os.replace(tmp, state_p, src_dir_fd=DFD, dst_dir_fd=DFD)
                    except OSError:
                        try: os.unlink(tmp, dir_fd=DFD)
                        except OSError: pass
                finally:
                    try: fcntl.flock(lfd, fcntl.LOCK_UN)
                    except OSError: pass
            os.close(lfd)

    p = prose_only(text)
    hangul = len(re.findall(r"[가-힣]", p))
    other_cjk = len(re.findall(r"[぀-ヿ一-鿿]", p))          # kana + Han
    latin = len(re.findall(r"[A-Za-z]", p))
    if hangul >= 2 and hangul >= other_cjk and hangul * 2 >= latin:
        notes.append("🗣️ 운영자는 이번 메시지를 한글로 썼다 — 이 턴에 운영자에게 보이는 글은 전부 한글로(도구 호출 사이 진행 메모 포함). 영어는 커밋 메시지·코드·서브에이전트 지시문에만.")
    if notes:
        print(json.dumps({"hookSpecificOutput": {"hookEventName": "UserPromptSubmit", "additionalContext": "\n".join(notes)}}, ensure_ascii=False))


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass
    sys.exit(0)
