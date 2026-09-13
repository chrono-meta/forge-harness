#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""사용 원장 — 하네스가 «누구에게 얼마나 쓰이는가» 를 남긴다. 표준 라이브러리만 쓴다.

## 🟥 옵트인이다 — `FH_USAGE_LEDGER` 가 없으면 **완전 무동작**이다.

이 파일은 npm 으로 배포되는 하네스 안에 들어간다. 기본값으로 켜 두면 소비자가 동의한 적 없는
계측이 남의 머신에서 돌게 되고, 그건 이 저장소가 §Operational Adaptation Loop 에서 금지하는
형태다(동의는 «부재 ≠ 승인»). 그래서 스위치는 **경로를 직접 주는 것**이고, 경로를 주는 행위
자체가 동의의 표시다.

```
export FH_USAGE_LEDGER="$HOME/.local/state/fh-usage"   # 이 줄이 없으면 아무 일도 안 난다
export FH_USAGE_AUTHOR=1                               # 저자 본인 머신에서만
```

## 무엇을 적고 무엇을 안 적나 — residency 가 여기서 정해진다

적는다 : 시각(분 단위) · 하네스 이름 · 진입점 이름(화이트리스트 형태) · **actor 해시** ·
         벽시계 ms · CPU ms · 반환 코드 · 결과 부류
🟥 안 적는다 : **인자 · 경로 · 파일명 · 티켓 id · URL · 사용자 이름 · 호스트 이름.**
   접근이 제한된 환경에서도 돌 수 있는 하네스라 이건 취향이 아니라 경계다. 인자 한 칸을
   열어두면 그 칸으로 조직 내부 식별자가 흘러나간다 — 그래서 인자를 받는 필드가 **아예 없다**.

`actor` = sha256(salt + 사용자 + 호스트)[:12]. salt 는 원장 디렉터리 안 `.salt`(0600)에만 있고
어디로도 안 나간다. ⚠️ **한계를 이름으로 남긴다**: 같은 사람이 머신 둘을 쓰면 **2 명**으로 세고,
공용 머신을 여럿이 쓰면 **1 명**으로 센다. 그래서 이 값은 «사람 수»가 아니라 «머신-사용자 수»다.

## degrade 방향 — 호스트를 절대 안 죽인다, 그러나 조용히 죽지도 않는다

원장 쓰기가 실패해도 예외를 호스트로 올리지 않는다(관측이 대상을 죽이면 안 된다). 대신
같은 디렉터리의 `.errors` 를 1 증가시키고, 리포터가 그 수를 **커버리지 옆에 같이 찍는다** —
「미측정을 0 으로 렌더하는」 부류를 안 만들기 위해서다.
"""
import hashlib
import json
import os
import time

_SCHEMA = 1
_ENV_DIR = "FH_USAGE_LEDGER"
_ENV_AUTHOR = "FH_USAGE_AUTHOR"
_ENV_SALT = "FH_USAGE_SALT"


_OFF = ("off", "no", "none", "0", "false", "decline", "거절")


def _dir():
    d = os.environ.get(_ENV_DIR, "").strip()
    if not d or d.lower() in _OFF:
        return None
    return d


def notice(stream=None):
    """미설정이면 «아직 안 정했다» 로 보고 안내를 낸다. 정하면 조용해진다.

    🟥 **세 상태를 가른다** — 이 저장소의 동의 규율 그대로다(부재 ≠ 승인, 그리고 거절도 기록이다):
      · 미설정        아직 안 정함  → 매 실행 안내 (정할 때까지 계속 뜬다)
      · 경로 지정     동의          → 조용, 기록 시작
      · `off`         명시적 거절   → 조용, 기록 안 함

    🟥 **안내는 stderr 로만 간다.** stdout 은 이 도구의 판정 출력이고 기계가 읽는다 —
       거기에 한 줄이라도 끼면 부르는 쪽의 파싱이 깨진다(관측이 대상을 바꾸는 것과 같은 부류).
    🟥 **문구는 참인 이유만 쓴다.** 이 변수가 없어도 도구는 **완전히 같게** 동작하고 종료코드도
       같다(레인이 직접 잰다). 그러니 «제대로 안 돈다» 는 거짓이다 — 못 보는 것은 **우리 관측**이지
       그 사람의 도구가 아니다. 거짓으로 받은 동의는 그 동의로 얻은 숫자의 값도 같이 떨어뜨린다.
    """
    import sys as _sys
    raw = os.environ.get(_ENV_DIR, "").strip()
    if raw:                       # 경로든 off 든 — 정했으면 조용
        return False
    out = stream if stream is not None else _sys.stderr
    try:
        out.write(
            "\n[usage] 이 도구가 얼마나 쓰이는지 아직 못 재고 있습니다 — 기본값이 꺼짐이라 그렇습니다.\n"
            "        켜기:  export FH_USAGE_LEDGER=\"$HOME/.fh-usage\"\n"
            "        끄기:  export FH_USAGE_LEDGER=off      (그러면 이 안내가 사라집니다)\n"
            "        기록되는 것: 시각(분)·도구명·진입점·실행시간·종료코드·익명 ID.\n"
            "        기록 안 되는 것: 인자·경로·파일명·티켓번호·URL·사용자명·호스트명.\n"
            "        ⚠️ 켜든 끄든 도구 동작과 종료코드는 **완전히 같습니다**. 못 보는 것은\n"
            "           여러분의 도구가 아니라 «여러분이 어디서 막히는지» 입니다.\n\n")
        out.flush()
    except Exception:
        return False
    return True


def _salt(d):
    """salt 는 env 우선, 없으면 원장 디렉터리 안 파일. 없으면 만든다(0600)."""
    s = os.environ.get(_ENV_SALT, "").strip()
    if s:
        return s
    p = os.path.join(d, ".salt")
    try:
        # 🟥 cross-family codex 지목(2026-09-13, B-3): `.salt` 가 FIFO 면 열기가 **블록**한다.
        #    이 함수는 `observe()` 의 finally 에서 불리므로, 그 순간 관측이 호스트를 멈춰 세운다.
        #    관측은 대상의 타이밍 계약도 바꾸면 안 된다 → 정규 파일이 아니면 읽지 않는다.
        #    (O_NONBLOCK 은 FIFO 열기가 막히는 것까지 같이 막는 두 번째 자물쇠다.)
        import stat as _stat
        st = os.lstat(p)
        if not _stat.S_ISREG(st.st_mode):
            raise OSError("salt path is not a regular file")
        fd = os.open(p, os.O_RDONLY | getattr(os, "O_NONBLOCK", 0))
        try:
            v = os.read(fd, 4096).decode("utf-8", "replace").strip()
        finally:
            os.close(fd)
        if v:
            return v
    except FileNotFoundError:
        pass
    except Exception:
        # 정규 파일이 아니거나 읽을 수 없다 → 아래 O_EXCL 생성이 실패하고 record() 가
        # 그 예외를 잡아 `.errors` 를 올린다. 행은 안 남고 호스트는 안 멈춘다(fail-closed).
        pass
    import secrets
    v = secrets.token_hex(16)
    fd = os.open(p, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    try:
        os.write(fd, v.encode())
    finally:
        os.close(fd)
    return v


def _actor(d):
    raw = "%s|%s" % (os.environ.get("USER") or os.environ.get("LOGNAME") or "?",
                     os.uname().nodename if hasattr(os, "uname") else "?")
    return hashlib.sha256((_salt(d) + "|" + raw).encode()).hexdigest()[:12]


def _entry_name(name):
    """진입점 이름만 받는다. 형태를 벗어나면 «other» — 인자가 이름에 섞여 들어오는 것 차단."""
    ok = name and len(name) <= 40 and all(c.isalnum() or c in "_.-" for c in name)
    return name if ok else "other"


def _bump_errors(d):
    try:
        p = os.path.join(d, ".errors")
        n = 0
        try:
            with open(p) as f:
                n = int((f.read() or "0").strip() or 0)
        except Exception:
            n = 0
        with open(p, "w") as f:
            f.write(str(n + 1))
    except Exception:
        pass


def record(harness, entry, wall_ms, cpu_ms, rc, outcome, counts=None):
    """원장에 한 줄. 실패해도 예외를 밖으로 안 낸다."""
    d = _dir()
    if not d:
        return False
    try:
        os.makedirs(d, exist_ok=True)
        row = {
            "v": _SCHEMA,
            # 🟥 분 단위로 자른다 — 초 단위 타임스탬프는 개인 행동 패턴을 더 세밀히 남긴다.
            "ts": time.strftime("%Y-%m-%dT%H:%MZ", time.gmtime()),
            "h": _entry_name(harness),
            "e": _entry_name(entry),
            "actor": _actor(d),
            "author": 1 if os.environ.get(_ENV_AUTHOR, "").strip() in ("1", "true", "yes") else 0,
            "wall_ms": int(wall_ms),
            "cpu_ms": int(cpu_ms),
            "rc": rc if isinstance(rc, int) else None,
            "out": outcome if outcome in ("DONE", "EXIT", "ERROR") else "ERROR",
            # LLM 호출이 있는 경로만 채운다. 없으면 null — 🟥 0 이 아니다.
            "llm": None,
        }
        if isinstance(counts, dict):
            row["n"] = {k: v for k, v in counts.items()
                        if isinstance(k, str) and isinstance(v, int) and len(k) <= 16}
        path = os.path.join(d, "%s-%s.jsonl" % (row["h"], time.strftime("%Y-%m", time.gmtime())))
        # append 는 O_APPEND 라 한 줄이 4 KiB 미만이면 동시 실행에서도 안 섞인다(POSIX).
        # 🟥 0600 으로 만든다 — 행에 actor 해시와 사용 시각이 남으므로 기본 umask(0644)로
        #    두면 같은 머신의 다른 계정이 읽는다. `.salt` 만 잠그고 원장을 열어두면 반쪽이다.
        # 같은 이유로 원장 파일도 정규 파일일 때만 쓴다(FIFO 로 바꿔치기하면 append 가 막힌다).
        if os.path.exists(path):
            import stat as _stat
            if not _stat.S_ISREG(os.lstat(path).st_mode):
                raise OSError("ledger path is not a regular file")
        fd = os.open(path, os.O_WRONLY | os.O_APPEND | os.O_CREAT
                     | getattr(os, "O_NONBLOCK", 0), 0o600)
        try:
            os.write(fd, (json.dumps(row, ensure_ascii=False, sort_keys=True) + "\n").encode("utf-8"))
        finally:
            os.close(fd)
        return True
    except Exception:
        # 🟥 여기서 예외를 올리지 않는 것은 «관측이 대상을 죽이면 안 되기» 때문이고, 그래서
        #    default-toward-PASS 로 보인다. 정당화는 **조용하지 않다**는 것이다 — 실패는
        #    `.errors` 로 세어지고 리포터가 커버리지 옆에 같이 찍는다(안 막는 것과 안 보이는 것은 다르다).
        # ⚠️ 닫히지 않은 잔여를 이름으로 남긴다: 디렉터리가 통째로 못 쓰이면 `_bump_errors` 도
        #    같이 실패해서 **카운터조차 안 남는다**. 그 경우는 리포터가 쓰기 권한을 직접 보고 잡는다
        #    (usage_report.py `--dir` 쓰기 가능 검사). 원장 혼자서는 못 닫는다.
        _bump_errors(d)
        return False


def observe(harness, entry, fn, *args, **kwargs):
    """`fn` 을 그대로 실행하고 반환값·예외를 **건드리지 않고** 통과시킨다.

    🟥 이 함수는 판정을 만들지도 바꾸지도 않는다. 종료코드는 `fn` 이 정하고 여기는 읽기만 한다.
    그래서 게이트 코드가 아니다 — 관측이 판정을 바꾸는 순간 그 숫자는 아무 의미가 없다.
    """
    notice()
    t0, c0 = time.monotonic(), time.process_time()
    rc, outcome = None, "ERROR"
    try:
        rc = fn(*args, **kwargs)
        outcome = "DONE"
        return rc
    except SystemExit as e:
        rc = e.code if isinstance(e.code, int) else None
        outcome = "EXIT"
        raise
    except BaseException:
        outcome = "ERROR"
        raise
    finally:
        record(harness, entry,
               (time.monotonic() - t0) * 1000.0,
               (time.process_time() - c0) * 1000.0,
               rc, outcome)
