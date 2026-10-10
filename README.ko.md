<p align="center">
  <img src="https://raw.githubusercontent.com/chrono-meta/forge-harness/main/docs/banner.png" alt="forge-harness — Forge your projects, pass them through, faster. Quality is the lever — speed is the result." width="680">
</p>

<p align="center">
  <a href="https://github.com/walkinglabs/awesome-harness-engineering#coding-agent-harnesses"><img src="https://awesome.re/mentioned-badge.svg" alt="Mentioned in Awesome Harness Engineering"></a>
  <a href="https://github.com/VoltAgent/awesome-agent-skills#community-skills"><img src="https://img.shields.io/badge/listed_in-awesome--agent--skills-0ea5e9.svg" alt="Listed in awesome-agent-skills"></a>
  <a href="https://github.com/anthropics/claude-code"><img src="https://img.shields.io/badge/Claude_Code-compatible-a855f7.svg" alt="Claude Code compatible — official Claude Code repository"></a>
  <a href="https://chrono-meta.github.io/forge-harness/"><img src="https://img.shields.io/badge/whole_map-interactive-6366f1.svg" alt="FH whole map — interactive diagrams on GitHub Pages"></a>
  <a href="https://github.com/marketplace/actions/fh-gate-typed-ai-code-review-verdict"><img src="https://img.shields.io/badge/GitHub_Action-marketplace-2088FF.svg" alt="GitHub Actions Marketplace — fh-gate"></a>
  <a href="https://www.npmjs.com/package/@chrono-meta/fh-gate"><img src="https://img.shields.io/npm/v/@chrono-meta/fh-gate.svg?color=cb3837" alt="npm"></a>
  <a href="https://github.com/chrono-meta/homebrew-forge-harness"><img src="https://img.shields.io/badge/homebrew-tap-FBB040.svg" alt="Homebrew tap"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-22c55e.svg" alt="MIT License"></a>
</p>

<p align="center">
  <a href="README.md">English</a> · <b>한국어</b> · <a href="README.zh.md">中文</a> · <a href="README.ja.md">日本語</a>
</p>

# forge-harness (FH)

**FH 는 [Claude Code](https://github.com/anthropics/claude-code) 를 위한 메타 하네스입니다. 프로젝트에 필요한 규칙·게이트·기억으로 이루어진 하네스와 스킬을 만들도록 돕고, 출하하기 전에 그것들을 검증합니다.**

*하네스(harness)* 는 한 프로젝트에서 AI 에이전트를 감싸는 장치입니다. 세션마다 같은 지시를 반복하지
않아도 되도록, 에이전트가 따르는 규칙, 잘못된 변경을 막는 검사, 배운 것의 기록을 갖춰 둡니다.
*메타* 하네스는 그런 하네스를 프로젝트마다 짓고 검증하는 하네스입니다.

> **AI 에게 매번 설명하던 규칙을, 프로젝트마다 심어두세요.**

<p align="center"><b>당신의 에이전트도, 당신도 통과해야 하는 품질 게이트.</b></p>

## 누구를 위한 것이고, 무엇을 얻을 수 있나요

실제 프로젝트에서 Claude Code(또는 다른 코딩 에이전트)를 쓰면서, 같은 말을 반복하는 일이나 잘못된 변경을
너무 늦게 알게 되는 일에 지친 분들을 위한 것입니다. 얻는 것은 세 가지입니다.

| 얻는 것 | 실제로는 | 근거 |
|---|---|---|
| **머지 전 게이트** | 변경이 들어오기 *전에* diff 를 판정하고, 판정문은 그 변경이 무엇을 잃었는지 이름으로 짚어 줍니다. 판정은 grep 으로 뒤지는 글이 아니라 타입이 있는 값(`PASS · PENDING · BLOCKED · ESCALATE`)입니다. 에이전트가 쓴 코드뿐 아니라 직접 쓴 코드에도 동작합니다. | 아래 데모 GIF · 남이 쓴 코드에 돌린 실행과 구멍을 심은 시험(표본 크기 포함): [근거](#근거와-부족한-부분) |
| **이어지는 기억** | `tracks/` 에 세션마다 배운 것이 남아서, 두 번째 세션이 첫 번째 세션이 멈춘 자리에서 시작합니다. | 설계 의도입니다. 세션을 마칠 때 `tracks/_meta/` 의 카드가 갱신되고 다음 세션이 시작할 때 그 카드를 읽습니다([`CLAUDE.md`](CLAUDE.md) §Session Wrap-up). 이 페이지에는 측정된 효과가 링크돼 있지 않습니다. 두 번째 세션부터 나타나는 효과이기도 합니다. |
| **검사를 대신 골라 주는 상대** | "이 프로젝트 진단해줘" 또는 "이 프로젝트 가속화해줘"라고 하면 고치거나 설치할 것의 우선순위 목록을 받습니다. 항목마다 승인하기 전에는 아무것도 바뀌지 않습니다. | [`CLAUDE.md`](CLAUDE.md) 에 기술돼 있습니다(§Field-Harness Diagnostic). 얼마나 자주 맞는지에 대한 벤치마크는 없습니다 |

<p align="center">
  <img src="https://raw.githubusercontent.com/chrono-meta/forge-harness/main/docs/demo/gate-block.gif" alt="regression guard blocking a change that dropped a Done When section, then passing once it is restored" width="820">
</p>
<p align="center">
  <sub>연출이 아니라 실제 실행을 녹화한 것입니다(재생성 스크립트는 아래에 링크). 에이전트가 스킬 정의 파일(<code>SKILL.md</code>)을 '정리'하면서 <b>완료 조건(Done When)</b> 항목을 지웠습니다. 가드는 BLOCK 하고 빠진 항목을 이름으로 짚으며, 그 항목을 되살리면 PASS 가 되어 나머지 정리는 그대로 출하됩니다.<br>재생성: <code>brew install vhs &amp;&amp; vhs docs/demo/gate-block.tape</code></sub>
</p>

## 빠른 시작

문을 하나 고르세요. 설치 방식도, 얻는 것도 다릅니다.

**① 게이트만. 클론도, 플러그인도, Claude Code 세션도 필요 없습니다.**

```bash
cd your-repo && npx --package @chrono-meta/fh-gate fh-gate     # 현재 레포의 git diff 를 리뷰
```

`git diff` 로 바뀐 파일을 찾아 리뷰 백엔드에 보내고, 판정(`FH_GATE_VERDICT: PASS | PENDING | BLOCKED | ESCALATE`)과
종료 코드를 출력합니다. PASS 는 리뷰가 실제로 돌았을 때만 PASS 로 칩니다. 백엔드가 끝내 답하지 않았거나, dry run 이거나,
모르는 종료 코드가 나오면 PASS 가 아니며, GitHub Actions 스텝은 기본값에서 이 경우 실패합니다. Node ≥ 16 과, 설치하고 로그인해 둔
백엔드 CLI 하나가 필요합니다. `claude`(기본) 또는 `codex`(`FH_BACKEND=codex`)입니다. CI, pre-commit 훅,
다른 에이전트 옆에서 쓰면 됩니다. GitHub Actions 스텝과 Homebrew tap 도 있습니다 — [게이트 실행하기](docs/REFERENCE.md#run-it-outside-claude-code--the-fh-gate-cli)를 보세요.

**② 하네스 전체를 Claude Code 안에서.**

```bash
claude plugin marketplace add https://github.com/chrono-meta/forge-harness.git
claude plugin install -s user fh-meta@forge-harness
git clone https://github.com/chrono-meta/forge-harness.git ~/projects/forge-harness
cd ~/projects/forge-harness && claude          # 그다음 입력: hi   (또는 안녕 · こんにちは · 你好)
```

1. **클론한 폴더를 Claude Code 로 엽니다**(`cd … && claude` 줄).
2. **인사합니다.** 새로 클론한 상태라면 FH 가 체크아웃을 읽고, 세션 파일이 없는 것을 확인한 뒤 신규 사용자용 짧은
   메뉴를 엽니다: *첫 프로젝트 만들기 · 기존 프로젝트 연결하기 · 가이드 읽기*. 설치 마법사를 아직 돌리지 않았다면 그 사실도 알려 줍니다.

   <img src="https://raw.githubusercontent.com/chrono-meta/forge-harness/main/docs/demo/door2-menu.gif" alt="typing hi in a fresh forge-harness clone; FH reads the checkout, opens the new-user menu, and warns that the install wizard has not run yet" width="760">

3. **같은 세션에서 성과 하나를 가져가세요.** **"프로젝트 연결해줘"**라고 하면(FH 가 `../` 에서 git 레포를 찾아
   `tracks/{project}/` 를 만듭니다) 이어서 **"이 프로젝트 가속화해줘"**(우선순위가 매겨진, 승인을 거치는 계획) 또는
   **"/context-doctor 돌려줘"**(토큰 낭비 점검)라고 하세요. 전체 설정은 **`/install-wizard`** 를 실행합니다.
   항목마다 하나씩 승인하고, 거절한 것은 기록됩니다.

**요구 사항.** ② 는 Claude Code CLI 가 필요합니다(`claude --version`). ① 은 Node 와 `claude` 또는
`codex` CLI 가 필요하고, Claude Code 세션은 필요 없습니다. FH 자체 게이트 중 하나(클론의 테스트 스위트)는 추가로
Python + PyYAML 이 필요하며(`python3 -m pip install --user pyyaml`), 없으면 fail-closed 로 막힙니다.
**어느 문인지 모르겠다면** ① 부터 시작하세요. 명령 하나이고 전역 설치도 없습니다. ② 는 더 큰 설치이며 `fh-gate` CLI 도 함께 들어
있습니다([`CHEATSHEET.md`](CHEATSHEET.md)). ① 에서 배운 것은 하나도 버려지지 않습니다.

플러그인만 설치하고(클론 없이) 써도 되지만 부분적입니다. 스킬과 에이전트는 받지만 `CLAUDE.md` 의 거버넌스나 `tracks/` 기억은
받지 못합니다. 처음 쓰는 분을 위한 한국어 안내: [`docs/USER_GUIDE.md`](docs/USER_GUIDE.md).

## 한 장으로 보는 동작 방식

의도한 흐름입니다. 어느 단계가 코드로 강제되고 어느 단계가 AI 에게 따르라고 한 규칙인지는 아래의 '할 수 있는 것과 할 수 없는 것' 표와
[`docs/map/FH_MAP.md`](docs/map/FH_MAP.md) 에 있습니다.

```
   하고 싶은 것을 말한다  ──►  FH 가 의도를 읽는다  ──►  두 형태 중 하나로 벼린다
   (평범한 말로)                                         ├─ AI 가 따르는 규칙   (CLAUDE.md, 스킬)
                                                         └─ AI 가 필요 없는 코드 (훅, 게이트, 스크립트)
                                                                   │
        하네스에 가하는 모든 변경이 지나는 길 ◄───────────────────┘
        ┌──────────────────────────────────────────────────────────┐
        │ 1. 설계하기 *전에* "무엇이 성공이고 무엇을 절대 안 하는가"를 적는다
        │ 2. 서로 독립된 여러 각도로 시도한다 (다른 모델 계열, 다른 레포의 시점)
        │ 3. 남는 것이 튼튼해질 때까지 공격한다 — 그다음에 출하
        └──────────────────────────────────────────────────────────┘
                                   │
   되돌릴 수 없는 단계(발행 · 삭제 · 이력 재작성)는 멈춰서 사람에게 묻는다
   검사가 재지 못한 것은 "측정 안 됨"으로 보고한다 — 0 으로 보고하지 않는다
   세션이 배운 것은 tracks/ 에 기록된다  ──►  다음 세션이 거기서 시작한다
```

허브(이 레포)에는 공유 `knowledge/` 와 프로젝트별 `tracks/` 가 있고, 연결한 각 프로젝트가 허브를 가리킵니다.
전체 지도(모든 노드가 실제 경로): [`docs/map/FH_MAP.md`](docs/map/FH_MAP.md)
(인터랙티브: [chrono-meta.github.io/forge-harness](https://chrono-meta.github.io/forge-harness/)).

## 세 가지 믿음

1. **품질이 지렛대이고, 속도는 그 결과입니다.** 작업 가설입니다: 사전 맥락 없는 검토를 한 번 견뎌 낸 작업은 나중에 손볼 일이 적습니다. 이 페이지에서 벤치마크한 것은 아닙니다.
2. **저자는 가장 나쁜 리뷰어입니다.** AI 와 함께 만들고 나면 당신은 그 결과물의 변호인이 됩니다. 그래서 의미 있는 검사는 당신의
   추론을 본 적 없는 리뷰어가 하는 검사입니다 — [`docs/WHY.md`](docs/WHY.md).
3. **되돌릴 수 없는 경계에는 기계를, 판단은 열어 둡니다.** 되돌릴 수 없는 곳에서 막고, 측정하지 못한 것은 측정하지 못했다고 인정합니다 —
   [`docs/ETHOS.md`](docs/ETHOS.md).

## 할 수 있는 것과 할 수 없는 것

| 할 수 있는 것 | 할 수 없는 것 (레포 스스로 밝힌 한계) |
|---|---|
| 머지 전에 diff 를 판정하고 그 변경이 잃은 것을 짚어 줍니다 | **사후 리뷰를 대체하지 못합니다.** 사람에게 닿는 양을 줄일 뿐 없애지는 않습니다. 실제 화면과 실제 상태에서 돌려야만 드러나는 것은 계속 사람의 몫입니다 |
| git 훅으로 커밋과 푸시를 막습니다(규칙, 스크립트, 삭제, 강제 푸시) | **막는다고 보장하지 못합니다.** 훅은 클라이언트 쪽이라 `--no-verify` 로 우회됩니다. 서버 쪽 바닥은 "main 은 PR 로만"과 필수 CI 검사입니다. pre-commit 훅은 FH 자체를 개발하는 용도입니다 — 자기 레포에 설치하지 말고 거기서는 ① 을 쓰세요 |
| 한 프로젝트의 교훈을 다음 세션으로 전달합니다 | **어디서나 똑같이 동작하지 않습니다.** 인사에서 언어를 맞추는 것은 코드로 강제하는 최소 보장이 없는 산문 규칙입니다. 2026-08-21 블라인드 테스트에서 인사 변형 하나는 메뉴를 내지 않았습니다 |
| 다른 모델 계열(Codex, Gemini, 로컬)로 리뷰를 돌려 한 계열이 놓치는 것을 잡습니다 | **Claude Code 밖에서 완전하게 쓸 수 없습니다.** 다른 런타임은 방법론과 `fh-gate`/`fh-run` 은 얻지만 자동 운전은 얻지 못합니다([`docs/codex-compat.md`](docs/codex-compat.md)) |
| 짧은 요청으로 프로젝트용 하네스를 짓습니다 | **완성된 하네스를 주문대로 내놓지 못합니다.** 그 일을 할 인큐베이터는 한 번 산출했고 그마저 전체 흐름을 건너뛰었습니다 — 나아가는 방향이지 출하된 기능이 아닙니다 |

## 근거와 부족한 부분

- **실제 제3자 diff (2026-05-31).** OpenCode 의 AI 가 쓴 `permission/arity.ts`(163줄, CI 초록)에 `fh-gate` 를 돌렸습니다.
  CI 가 놓친 A등급 지적 사항 두 건으로 판정은 BLOCKED 였습니다.
- **구멍을 심은 시험, 모델 고정 (2026-07-14).** 다른 두 모델이 쓴 fail-open 구멍 여덟 개. 일반 리뷰 5/8(그중 2건은 엉뚱한 버그) ·
  + FH 의 degrade-direction 렌즈 6/8 · + 두 번째 모델 계열 8/8, 오탐 0. **단일 시행, 작은 표본입니다.** 핵심은 단일 모델 실행 둘이
  *같은* 구멍 두 개를 놓쳤다는 점입니다. 방법은 [`ship_readiness_gate.md`](knowledge/shared/harness-core/ship_readiness_gate.md),
  더 많은 실행은 [`docs/OUTPUT_EVIDENCE.md`](docs/OUTPUT_EVIDENCE.md).
- **성숙도는 주장이 아니라 등급입니다.** 아래에 이름을 적은 다섯 정체성은
  [`ship_readiness_gate.md`](knowledge/shared/harness-core/ship_readiness_gate.md) 에 날짜가 붙은 등급이 있습니다. 하나를 믿기 전에 그 등급을 읽으세요.
- 이 페이지의 수(**스킬 46개 · 에이전트 14개**)는 `plugins/`(`fh-meta`, `fh-commons`, `fh-qp`, `fh-preprep`) 아래의 스킬 폴더와
  에이전트 파일을 2026-10-10 에 센 것입니다. 말 모음: [`CHEATSHEET.md` §12](CHEATSHEET.md#12-skills--agents--what-each-does-and-what-to-say).

## 쓰다 보면 만나는 말

시작하는 데는 필요 없습니다. FH 가 어떻게 지어졌는지를 이름 붙인 것이어서, 인사나 게이트에서 하나를 마주쳤을 때 찾아보면 됩니다.
여기 정의는 한 줄입니다. 정본은 [`fh_three_layer_canon.md`](knowledge/shared/harness-core/fh_three_layer_canon.md) 입니다.

| 용어 | 한 줄 | 더 읽기 |
|---|---|---|
| **3단 공정** | FH 작업이 밟는 순서: 먼저 성공을 정의 → 병렬로, 상관성을 낮춘 독립적인 시도 → 여섯 축으로 태우기. 속도는 끝에서 나옵니다. | [`ETHOS.md`](docs/ETHOS.md#the-forge) |
| **4대 엔진** | 산출이 나오는 핵심: `judgment-circuit` · `ship-gate` · `context-continuity` · `external-grounding`. | 위 정본 |
| **5대 정체성** | 스킬이 모여 이루는 모양: 하네스 클러스터 · 프로젝트 인큐베이터 · 거버넌스 게이트 · 프런티어 답습 · 증폭기. 정체성별로 등급이 매겨집니다. | [`docs/IDENTITIES.md`](docs/IDENTITIES.md) · [`ship_readiness_gate.md`](knowledge/shared/harness-core/ship_readiness_gate.md) |
| **6축 검증** | 리뷰어가 *무엇을 받았는가*로 나뉘는 여섯 가지 리뷰 방식: 다른 모델 계열 · 대상의 자체 정본 · 격리 그라운딩 · 제3자 레포 · 첫 실사용 · 되돌려 관찰. 여섯을 다 돌리는 게 아니라 고릅니다. | 위 정본 |
| **탈상관(decorrelation)** | 두 검사가 *다르게* 실패하게 만들어서, 하나가 못 보는 것을 다른 하나가 보게 하는 것. | [`docs/REFERENCE.md`](docs/REFERENCE.md) |

그 밖의 용어: [`GLOSSARY.md`](knowledge/shared/GLOSSARY.md).

## 다음으로 읽을 것

| 원하는 것 | 갈 곳 |
|---|---|
| 첫 세션을 단계별로 (한국어) | [`docs/USER_GUIDE.md`](docs/USER_GUIDE.md) |
| 명령과 트리거 문구 | [`CHEATSHEET.md`](CHEATSHEET.md) |
| 예전 README 전체 (엔진, 모델 설정, `fh-gate` 플래그, 스킬 목록, 논문) | [`docs/REFERENCE.md`](docs/REFERENCE.md) |
| 사용 사례와 모델 티어별 기대치 | [`docs/USE_CASES.md`](docs/USE_CASES.md) · [`docs/model_tier_expectations.md`](docs/model_tier_expectations.md) |
| 왜 존재하는가 / 무엇을 믿는가 / 근거 | [`docs/WHY.md`](docs/WHY.md) · [`docs/ETHOS.md`](docs/ETHOS.md) · [`docs/OUTPUT_EVIDENCE.md`](docs/OUTPUT_EVIDENCE.md) |
| 기여하기 | [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md) |
| AI 운영 규칙 / 런타임 진입점 | [`CLAUDE.md`](CLAUDE.md) · [`AGENTS.md`](AGENTS.md) |

> **이 문서는 사람을 위한 것입니다.** 도움이 되었다면 스타 하나가 다른 분들이 찾는 데 도움이 됩니다.
