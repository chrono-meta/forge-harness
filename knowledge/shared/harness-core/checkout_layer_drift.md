# 체크아웃 층 드리프트 — 같은 커밋이 두 곳에서 다른 판정을 내는 이유

> **계기**: `scripts/env_layer_fingerprint.sh` · **레인**: `scripts/test_env_layer_fingerprint_lanes.sh`
> **읽어야 할 때**: 이 저장소를 두 번째 머신에 클론했을 때 · 클라우드/원격 세션이 FH 자산을 고칠 때 ·
> 「게이트가 통과했다」를 근거로 무언가를 주장하기 직전.

## 1. 한 문장

FH 는 **읽는 층**과 **막는 층**이 서로 다른 수송로로 다니고, git 은 그중 앞의 것만 나른다 —
그래서 새 클론은 **규율을 전부 읽고 게이트는 하나도 못 돌리는 상태**가 기본값이며, 그 상태가
**무음**이다.

## 2. 네 층과 각자의 수송로

| 층 | 무엇 | 수송로 | 새 클론에 |
|---|---|---|---|
| **READ** | `CLAUDE.md` · `knowledge/` · `scripts/` · `templates/.git-hooks/` 의 **소스** | git | 온다 |
| **ENFORCE** | `core.hooksPath` 배선 · 실행 가능한 훅 · `settings*.json` 의 SessionStart 등록 | 없음 (설정은 gitignored, 배선은 파일이 아니다) | **안 온다** |
| **EVIDENCE** | `tracks/_meta` 의 4축 마커 · `edit_manifest.yaml` · 세션 카드 | gitignored | **안 온다** |
| **PATTERN** | `.public-surface-patterns` · `.residency-patterns` · `LOCAL_SKILL_REGISTRY.md` · `CLAUDE.local.md` | gitignored | **안 온다** |

🟥 **훅이 «와 있는 것»과 «배선된 것»은 다르다.** `templates/.git-hooks/pre-commit` 은 tracked 라
어느 클론에나 온다. 하지만 `core.hooksPath` 는 git 이 나르는 값이 아니라 **로컬 설정**이라,
그 한 줄을 안 잡으면 실물은 있는데 아무것도 안 돈다. 새 클론이 읽는 문서는 전부 「훅이 하드
차단한다」고 적고 있고, 그 문장은 그 클론에서 **거짓**이다.

## 3. 실측 — 2026-09-21, 같은 커밋 `a9e9b29`, 두 체크아웃

양쪽에서 같은 경로들을 읽었다. 클라우드 쪽은 `env_layer_fingerprint.sh` 로, 맥 쪽은 같은 경로를
겨눈 읽기 전용 프로브로 쟀다(⚠️ §5 의 한계 참조).

| 층 | 항목 | 클라우드 클론 | 운영자 맥 |
|---|---|---|---|
| READ | `read.doctrine` · `read.gatespec` · `read.hooksrc` · `read.scripts` | ✅ ✅ ✅ ✅ | ✅ ✅ ✅ ✅ |
| ENFORCE | `hook.pre-commit` | ❌ ABSENT | ✅ `EXEC_FH` |
| ENFORCE | `hook.pre-push` | ❌ ABSENT | ✅ `EXEC_FH` |
| ENFORCE | `hook.sessionstart` | ❌ ABSENT | ✅ 등록 1건 |
| EVIDENCE | `evidence.manifest` | ❌ ABSENT | ✅ PRESENT |
| EVIDENCE | `evidence.marker` | ❌ ABSENT | ✅ 마커 **491** |
| EVIDENCE | `evidence.card` | ❌ ABSENT | ✅ PRESENT |
| EVIDENCE | `evidence.tracks` | ❌ ABSENT | ✅ **17,387** 파일 (`_meta` 17,106 · 세션 896 · 매핑 트랙 12) |
| PATTERN | `pattern.psa` | ❌ ABSENT | ✅ PRESENT |
| PATTERN | `pattern.residency` | ❌ ABSENT | ✅ PRESENT |
| PATTERN | `pattern.registry` | ❌ ABSENT | ✅ PRESENT |
| PATTERN | `pattern.localmd` | ❌ ABSENT | ✅ PRESENT |

**15 칸 중 READ 4 칸만 같고, 나머지 11 칸이 전부 반대다. 커밋은 같다.**

## 4. 그래서 무엇이 갈리나 — 방향이 둘이다

### ⓐ 여기서 초록 · 저기서 빨강 (**이쪽이 위험한 방향**)

클라우드 클론에서 FH 자산을 고치고 커밋하면 **그냥 성공한다.** 4축 게이트가 통과한 것이 아니라
**안 돈 것**인데, 터미널 출력은 둘 다 무음이라 **구분이 안 간다.** 같은 커밋을 맥에서 하면
Axis 2+3(마커 부재)과 Axis 4(`edit_manifest.yaml` 부재)로 차단된다.

**직접 재봤다(2026-09-21).** 이 클론에서 `scripts/` 파일 하나를 스테이징하고 커밋 → 무음 성공.
그다음 `git config core.hooksPath templates/.git-hooks` **한 줄만** 잡고 같은 커밋 →

```
[Axis 1] Regression Guard...      ✅ PASS
[Axis 2+3] Adversarial ...        ❌ NOT CONFIRMED
[Axis 4] Edit Manifest...         ❌ FAIL — tracks/_meta/edit_manifest.yaml not found
🚫 BLOCKED — resolve failing axes, then retry
```

바뀐 것은 코드가 아니라 **배선 한 줄**이다. 이것이 드리프트의 실물이다.

🟢 **이 방향의 절반은 이미 닫혀 있다** — `scripts/remote_marker_gate.sh` 가 `claude/*` 브랜치에
한해 「마커 3필드가 커밋 기록에 실려 왔나」를 `validate` 에서 막는다. 🟥 **닫은 것은 «조용한
부재» 하나다**: 형식만 보고 진위는 안 본다. 그리고 그 게이트는 **FH 자산 경로 패턴에 걸린 것만**
본다 — 그 밖의 변경은 여전히 무음으로 통과한다.

### ⓑ 여기서 빨강 · 저기서 초록

훅을 배선하고 나면 이번엔 **EVIDENCE 층이 없어서** 막힌다. 마커도 매니페스트도 이 체크아웃에
없고, 컨테이너는 회수되므로 **만들어도 안 남는다.** 맥에서는 491개가 이미 있어서 같은 자리가
초록이다. 이쪽은 시끄러워서(차단) 상대적으로 안전하다 — 위험한 것은 언제나 ⓐ 쪽이다.

### ⓒ 양쪽 다 초록인데 **커버리지가 다르다** (제일 조용하다)

`PATTERN` 층이 비면 기밀성 스캔은 **돌긴 돈다** — `defaults` 만 싣고. 회사명·실명 토큰 클래스가
통째로 UNSCANNED 인 채 초록이 난다. 훅이 그걸 🟧 배너로 크게 찍긴 하지만(2026-08-16 에
«조용한 두 줄»에서 승격됐다) **차단은 안 한다** — 그 판단은 옳다. 오버라이드가 gitignored 라
하드 차단하면 모든 새 클론의 첫 커밋이 막히고, 그건 `PUBLIC_SURFACE_OK` 를 반사행동으로
훈련시킨다. 그러나 **이 클론에서 난 초록은 맥에서 난 초록과 같은 초록이 아니다.**

## 5. 한계 — 이 표가 주장하지 않는 것

- 🟥 **맥 쪽은 `env_layer_fingerprint.sh` 를 돌린 것이 아니다.** 같은 경로를 겨눈 읽기 전용
  프로브의 출력을 이 표의 행에 1:1 로 옮긴 것이다. 판정은 옮겨지지만 **digest 는 아직 대조
  불가**다 — 맥에서 계기를 직접 한 번 돌려야 지문이 비교 가능해진다.
- 맥 쪽 프로브는 **홈 절대경로 · 호스트명 · 매핑 트랙 이름 12개**를 치환한 채 회신했다. 이름이
  필요한 판정은 이 표에 없다.
- `behind_origin_main=0` 은 **마지막 fetch 시점** 기준이지 「지금 동기」가 아니다. 그 세션은
  fetch 를 따로 돌리지 않았다.
- **n=2 체크아웃, 1 회.** 「원격 노드 일반」이 아니라 「이 두 곳, 이 날」이다.

## 6. 무엇을 하라는 말인가

1. **새 체크아웃에서 FH 자산을 고치기 전에 `bash scripts/env_layer_fingerprint.sh` 를 돌려라.**
   ENFORCE 가 비어 있으면, 그 세션이 읽고 있는 「훅이 막는다」는 문장들은 **그 세션에서 거짓**이다.
2. **`--digest` 를 두 쪽에서 찍어 비교하라.** 한 줄이고 값이 안 실린다 — 스레드·PR·이슈에 그대로
   붙일 수 있게 만든 형태다.
3. **초록을 근거로 쓰기 전에 어느 층이 깔려 있었는지 말하라.** 「게이트 통과」는 게이트가 돌았을
   때만 뜻이 있는 문장이다.

🟥 **이 계기는 게이트가 아니다.** 어떤 훅도 부르지 않는다 — 부르게 만들면 새 클론의 첫 커밋이
전부 막히고, 그건 §Mechanization Boundary 가 «오늘의 판단을 내일의 천장으로 굳히는」 자리라고
부르는 것이다. 여기서 기계화한 것은 **채널**(층이 있나 없나가 typed 값으로 남나)이지
**결론**(그래서 커밋해도 되나)이 아니다.

## 7. `fh_node_check.sh` 와의 관계

겹치지만 대체하지 않는다. 저쪽은 **한 머신의 바닥이 깔렸나**를 세션 시작에 알리는 탐지기고
(산문 권고 · 항상 exit 0 · 상태는 머신-로컬 gitignored), 이쪽은 **두 체크아웃을 나란히 놓을 수
있는 형태**를 낸다. 저쪽은 알리고, 이쪽은 **diff 가 되게** 한다.

⚠️ 그리고 저쪽은 이 환경에서 **뜨지도 않는다** — SessionStart 등록이 `settings*.json` 에 사는데
그 경로가 전부 gitignored 라, 새 클론에는 등록이 없다. 자기 헤더가 그 닭-달걀을 «줄었지만
없어지지 않았다»고 이미 적고 있다. 즉 **바닥이 없다고 알려 줄 탐지기 자신이 바닥과 같은
수송로를 탄다.**
