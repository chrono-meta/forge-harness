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

## 5-b. 🟥 이 문서의 상주 포인터는 측정에서 분리되지 않았다

2026-09-21, 플로어 티어 블라인드, act 모드, reps=3/팔, 사전등록 봉인
(`tracks/_meta/prereg_2026-09-21_drift-pointer-sim.md` · 결과
`tracks/_meta/sim_2026-09-21_drift-pointer-result.md`):

| 팔 | FIRES |
|---|---|
| ARM (CLAUDE.md 포인터 있음) | **3/3** |
| CONTROL (`main`, 포인터 없음) | **3/3** |

사전등록한 반증 조건 «CONTROL ≥ ARM 이면 기여 0» 이 **그대로 충족됐다.**

⚠️ 동시에 **계기가 오염됐다** — CONTROL 팔이 자기 근거로 *«메모리에 적어둔 …»* 을 적었다.
`sim_isolated_run.sh` 는 레포 트리와 settings 는 격리하지만 **사용자/팀 메모리는 격리하지
않고**, 거기에 이 사실이 이미 적혀 있었다. 즉 잰 것은 «포인터가 뜨는가» 가 아니라 «답을
이미 아는 세션이 그걸 말하는가» 다.

🟥 **그래도 판정은 안 되돌린다.** 오염은 왜 분리가 불가능했는지를 설명할 뿐 포인터를 구제하지
않는다. 라벨은 둘 다다: **① 기여 측정 0 · ② 재측정 필요.** 재측정에는 «메모리만 비우고
프로젝트 CLAUDE.md 는 살리는» 팔이 필요한데 러너에 그 팔이 없다(`--no-harness` 는 CLAUDE.md
까지 떨어뜨려서 다른 질문의 컨트롤이다) — `sim_isolated_run.sh` 의 명시된 잔여로 남긴다.

🟢 **이 절이 무효화하지 않는 것**: §3 의 두 체크아웃 실측 15행과 §4 의 커밋 차단 실험은
sim 과 **독립된 측정**이고 그대로 선다. 분리 안 된 것은 «그 사실을 상주 문단에 적으면 세션이
더 잘 알아차리는가» 하나다.

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

## 8. 휘발 클론에서 게이트가 **어디까지 도나** — 축별 실측 (2026-09-21)

§3 은 「층이 있나」를 잰다. 이 절은 그 **다음 칸**이다: 없는 층 중 **무엇이 여기서 세울 수 있고
무엇이 구조적으로 못 서는가.** 둘은 다른 물음이고, 앞의 것만 읽으면 ABSENT 열한 줄을 보고
「여긴 게이트가 안 돈다」로 접게 된다. **실측은 그 반대였다.**

**대상**: 클라우드 컨테이너의 `git clone` (훅 미배선 · `tracks/` 비어 있음 · 패턴 파일 없음 ·
`LC_CTYPE=POSIX` · codex/gemini 계열 CLI 없음). **조작한 변수는 하나** — `git config --local
core.hooksPath templates/.git-hooks` 한 줄.

### 8-a. 컨트롤이 살아 있다

| 팔 | 같은 스테이징 | 결과 |
|---|---|---|
| A (컨트롤) | 훅 **미**배선 · FH 자산 1개 | `rc=0`, 게이트 출력 **한 줄도 없음** — 무음 성공 |
| B | 훅 배선 | `🚫 BLOCKED` — Axis 4 가 매니페스트 부재로 차단 |

즉 「통과했다」와 「안 돌았다」는 터미널에서 구분되지 않는다는 §4-ⓐ 가 이 클론에서 그대로
재현됐다. 그리고 컨트롤이 갈렸으므로 아래 표는 계기가 살아 있는 상태에서 나온 값이다.

### 8-b. 축별 판정 — 배선한 뒤 하나씩 채워 가며

| 축 / 레인 | 이 클론에서 | 통과에 필요한 것 |
|---|---|---|
| Axis 1 회귀 가드 | ✅ **완전히 돈다** | 없음 — 가드는 git 으로 온다 |
| Axis 2+3 마커 | ✅ 통과 가능 | 마커 파일(gitignored) **+ UTF-8 로케일** ← 8-c |
| Axis 4 매니페스트 | ✅ 통과 가능 | `tracks/_meta/edit_manifest.yaml` 에 오늘자 엔트리 |
| Privacy (tracks 허용목록 · gitlink) | ✅ PASS | 없음 |
| 상주 유입 게이트 | ✅ PASS | 없음 |
| 기밀성 스캔 | 🟥 **구조적으로 PARTIAL** | 못 닫는다 ← 8-d |
| 이식성 린트 | advisory | — |

**세 가지를 갖추면 `✅ ALL AXES PASSED` 가 이 컨테이너에서 실제로 뜬다** — 실측했다. 훅을
한 줄도 고치지 않았고, 느슨하게 만든 곳도 없다.

### 8-c. 🟥 로케일이 통과를 막는다 — 그리고 방향이 **과차단**이다

훅의 비공허성 다리들(`soul:` · `soul-check:` 의 `reflected(...)` 근거 · `defeater:` ·
`affected:`)은 낱말 수로 공허를 판정하는데, `wc -w` 는 **POSIX 로케일에서 순한글 줄을 0~1
낱말로 센다.** 이 레포의 기록 언어가 한국어이므로, 정직하게 쓴 마커가 「공허하다」로 차단된다.

실측 — 같은 마커 파일, 같은 훅(`main`), 로케일만 바꿈:

```
LC_CTYPE=POSIX     → soul ❌(3낱말) · reflected ❌ · defeater ❌(2낱말) · affected ❌(2낱말)
LC_ALL=C.UTF-8     → 넷 다 ✅ , 그리고 ALL AXES PASSED
```

ASCII 컨트롤 문자열은 두 로케일에서 **같은 수**를 냈으므로 계기는 살아 있고, 갈리는 것은
한글뿐이다. 🟥 **이건 이 절이 처음 찾은 결함이 아니다** — 주간 클린룸 감사 갈래가 같은 날
PR #780 으로 훅 6곳의 셈법을 로케일 불변으로 고쳤고, 여기서는 **다른 경로로 독립 재현**됐다
(그쪽은 감사, 이쪽은 클론에서 실제로 커밋을 시도하다가). #780 의 훅을 그대로 가져다 POSIX
로케일에서 돌리면 네 다리가 전부 ✅ 로 뒤집힌다 — 즉 이 재현은 그 PR 의 **두 번째 실행 근거**다.

`export LC_ALL=C.utf8` 은 **절차상 우회이지 수리가 아니다.** 수리는 #780 이고, 머지되면 이
항목은 환경과 무관해진다.

### 8-d. 여기서 **구조적으로 못 닫는** 것 — 이름으로

1. **기밀성 패턴 층** (`.claude/rules/.public-surface-patterns`). 회사명·실명 같은 실제
   리터럴을 담기 때문에 gitignored 이고, 그래서 **클론에는 올 수 없다.** 스캔은 돌지만
   defaults-only 로 돌고 **초록을 낸다** — 훅은 🟧 배너로 「커버리지 축소」라고 말하지만
   차단하지는 않는다(하드 차단하면 모든 새 클론의 첫 커밋이 막혀 `PUBLIC_SURFACE_OK` 를
   반사행동으로 훈련시킨다). ⇒ **여기의 PASS 를 전체 통과로 읽으면 안 된다.**
2. **마커·매니페스트의 존속과 provenance.** `tracks/**` 는 gitignored 이고 컨테이너는
   회수된다. 여기서 쓴 기록은 주간 감사도 `below_floor_scan.sh` 도 다시 읽지 못한다 —
   **재검증 큐에 안 들어간다.** 살아남는 채널은 커밋 메시지뿐이고, 그 자리는
   `scripts/remote_marker_gate.sh` 가 `claude/*` 채널에 한해 이미 막고 있다(실측: 이
   클론에서 커밋 메시지에 세 필드를 싣자 `PASS`).
3. **ⓐ 다른 계열 축.** codex/gemini 계열 CLI 가 없으므로 `crossfamily:` 의 정직한 최대값은
   `DEGRADED_SINGLE_FAMILY` 다. 게이트는 근거만 있으면 통과시키지만, **가장 강한 값은 여기서
   도달 불가**다.

### 8-e. 한계 — 이 절이 주장하지 않는 것

- **n=1 컨테이너, 하루.** 다른 클라우드 노드가 같은 로케일·같은 CLI 부재를 갖는지는 미측정.
- **「게이트가 돈다」이지 「검증됐다」가 아니다.** 마커는 여전히 자기가 쓴 것이고, 옮긴 마커와
  지어낸 마커는 바이트가 같다 — §Mechanization Boundary 가 사람에게 남긴 잔여는 그대로다.
- **pre-push 는 이 절에서 안 쟀다.** 커밋 표면만 봤다.

### 8-f. 기계층

`bash scripts/gate_bootstrap_ephemeral.sh --check`(안 바꾼다) / `--apply`(레포-로컬
`core.hooksPath` 한 줄만 잡는다 · 전역 설정 불가침). ENFORCE 미배선과 LOCALE 파손을 각각
이름으로 찍고 **둘 중 하나라도 남으면 `rc=1`** 이다 — 두 고장은 방향이 반대(전자는 무음 통과,
후자는 과차단)지만 둘 다 커밋 시점이 아니라 여기서 끝낼 일이다.

🟥 **증거는 만들지 않는다.** 마커도 매니페스트도 주소만 찍고 생성하지 않는다 — 자동 생성은
게이트를 통과시키는 게 아니라 **가짜로 닫는** 것이고, `fh_4axis_gate.md` 가 이름으로 금지한다
(*a fabricated marker is … by design, do NOT fake-close it*). 레인
`scripts/test_gate_bootstrap_ephemeral_lanes.sh` 의 L8 이 그 부작용 부재를 직접 관측하고,
L10 되돌림 프로브가 로케일 차단 줄을 지운 사본에서 판정이 뒤집히는 것을 보인다.
