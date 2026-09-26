---
title: Hook channel visibility — which hook output reaches whom, and when
tags: [hooks, permissions, auto-approve, visibility, measured]
status: measured (partial — unmeasured cells are named, not filled)
created: 2026-09-26
---

# Hook channel visibility — 훅 출력은 «누구에게, 언제» 닿는가

> **한 줄**: 훅이 무언가를 «냈다» 와 사람이 그것을 «고르기 전에 봤다» 는 다른 명제다. 그리고
> 훅이 **ask** 를 냈다고 호출이 멈추는 것도 아니다 — 누군가 권한 프롬프트에 대신 답하면 ask 는
> 삼켜진다. 멈추는 것은 **deny / exit 2** 다.

출처: 필드 하네스(데스크톱 펫 게이트 — 권한 요청을 사람 대신 자동승인하는 앱에 FH 게이트를 싣는
프로젝트)를 만들며 2026-09-25~26 에 잰 대화형 pty 실측 세 건. 원장은 로컬(`tracks/_meta/result_2026-09-25_gate-vs-autoapprove_INTERACTIVE.md`
· `result_2026-09-25_hook-answers-questions.md` · `result_2026-09-26_boost-visibility-2.1.283.md`,
gitignored)이고, 이 문서는 그 판정만 옮긴다. 모델은 전부 sonnet, 격리는
`--setting-sources project,local --strict-mcp-config`.

## 1. 가장 먼저 — ask 는 자동승인 앞에서 fail-closed 가 아니다

| 팔 (대화형, CLI 2.1.282, 명령 `git push origin main`) | reps | 착지 |
|---|---|---|
| 게이트 PreToolUse **ask** + PermissionRequest 훅 **allow** (auto 3 · acceptEdits 2) | 5 | **5/5 실행됨** — ask 가 삼켜졌다 |
| 게이트 PreToolUse **deny** + PermissionRequest 훅 allow (acceptEdits) | 2 | **0/2** — 멈췄다, PermissionRequest 미호출 |
| 게이트 ask, 자동승인 훅 없음 (대조, auto 1 · acceptEdits 1) | 2 | 0/2 |

- ⇒ 자동승인(PermissionRequest allow 훅, 그런 훅을 쓰는 데스크톱 승인 앱, «예» 를 대신 누르는
  래퍼) 아래에서 비가역 호출을 멈추려면 게이트는 **deny** 를 내야 한다.
- 🟥 **표면마다 다르다**: 헤드리스(`-p`)에서는 ask 뒤에 PermissionRequest 가 안 불렸다. 헤드리스
  초록을 대화형으로 옮겨 적지 마라.
- **미측정**: ⓐ 자동승인 훅 없이 auto 모드 **단독**이 ask 를 삼키는가(대조 1판은 안 삼킴 — 바 미달)
  ⓑ `permissions.ask` **규칙**(훅이 아니라 설정 규칙)이 같은 부류인가 ⓒ `exit 2` 는 deny 와 같은
  방향이라고 문서가 말하지만 이 조합에서 직접 재지 않았다 ⓓ deny 팔은 reps 2 로 바 미달.
- 이 사실이 고친 문서: `templates/.claude/rules/mcp_tool_gating.md` §2 주석 · CLAUDE.md
  §Irreversibility Gates · goal-quench rung ②.

## 2. 채널 × 표면 × 시점

«앞» = 사람이 고르기(답·승인) **전**에 화면/알림에 나타남 · «뒤» = 고른 **뒤**에만 · «없음» = 끝까지 안 그려짐.
각 칸: 결과 · reps · CLI 버전.

| 채널 | 질문 창 (AskUserQuestion) | 계획 승인 (ExitPlanMode) | 권한 프롬프트 (Bash 등) | 대화 / 모델 |
|---|---|---|---|---|
| PreToolUse `systemMessage` | **뒤** 9/9 (5초 창 6 · 25초 창 3) · 2.1.283 | 화면 표시 0/3 · 2.1.283 | 컨트롤로 쓴 Bash 쪽은 질문 창 **앞**에 18/18 · 2.1.283 | 미측정 |
| PermissionRequest `systemMessage` | **없음** 3/3 · 2.1.283 | 미측정 | 미측정 | 미측정 |
| PreToolUse `additionalContext` | **없음** 3/3 (모델도 되풀이 안 함) · 2.1.283 | 미측정 | 미측정 | 모델 쪽 도달 미측정 |
| PreToolUse ask + `permissionDecisionReason` | **없음** 3/3 — 권한 창도 안 뜨고 질문 창이 그대로 · 2.1.283 | 미측정 | ask 는 자동승인에 삼켜짐 5/5 (§1) · 2.1.282 | 미측정 |
| PreToolUse deny + 사유 | 모델이 사유의 값을 답으로 따름 3/3 (`hook error` 로 표시) · 2.1.282 | 계획 **수정 요구**로 쓰면 **0/6** 착지 — 모델이 «훅 주입» 으로 의심하고 되물음 · 2.1.282 | deny 는 멈춤 0/2 착지 (§1) · 2.1.282 | 사유는 모델에게 보인다 |
| `updatedInput` (+ allow) | `answers` 주입 = **답이 된다** 3/3 (PreToolUse) · 3/3 (PermissionRequest), «User answered» 로 렌더 · allow **단독**은 0/2 · 2.1.282 | 원 입력 echo = 승인 UI 없이 진행 3/3 (PreToolUse) · 3/3 (PermissionRequest) · allow 단독 0/2 · 2.1.282 | 미측정 | 사람이 답한 것처럼 보인다 — 출처 표시 없음 |
| PermissionRequest deny + `message` | 미측정 | 수정 요구 착지 1/3 (1 수용 · 1 확인 요청 · 1 «suspicious» 무시) · 2.1.282 | 미측정 | 미측정 |
| `terminalSequence` (OSC 777 알림) | **미측정** (같은 필드라 같을 가능성은 높다 — 선언 전 3판 필요) | 승인 화면 **앞** 3/3 (설치본 증폭기 사본) · 합성 양성 3/3 · known-negative 0/3 · 2.1.283 | 미측정 | 해당 없음 (터미널 알림) |
| `exit 2` + stderr | 미측정 | 미측정 | 미측정 | 미측정 |

## 3. 계기 함정 — CLI 도 자기 OSC 777 을 낸다

- 계획 승인 화면 **뒤**: `Claude Code needs your approval for the plan` (9/9, 2.1.283).
- 질문 창을 25초 열어 두면: `Claude needs your permission` (3/3). 5초 창에서는 0/15 — 5~25초 사이에 나온다.
- ⇒ «OSC 777 이 몇 개 나왔나» 로 세는 계기는 known-negative 에서도 1 을 센다(거짓 양성). **판정은
  본문 접두(예: `FH 게이트;`)로** 한다. 개수는 맞는데 지시 대상이 틀리는 부류다 —
  `measurement-integrity-checklist.md` 표의 같은 줄.
- 알림이 사람의 터미널에 **착지**하는지는 pty 바이트까지만 쟀다(터미널마다 다르다 — 받는 터미널에서만 뜬다).

## 4. 설계 함의

1. **비가역을 멈추는 채널은 deny / exit 2 뿐이다.** ask 는 «사람이 프롬프트 앞에 있을 때» 의 채널이다.
2. **질문 창에서 사람을 돕는 부스트는 지금 없다.** systemMessage 는 고른 뒤에 그려지고, 나머지는
   안 그려진다. 후보: OSC 777(질문 쪽 미측정) · `updatedInput` 으로 선택지 설명에 싣기(질문을
   «바꾸는» 것이라 경계를 넘는다 — 운영자 결정) · 바깥 표면(펫 말풍선·상태표시줄).
3. **`updatedInput.answers` 는 훅이 사람 대신 답하게 한다** — 그리고 화면은 «사람이 답했다» 고
   말한다. 가역 질문에 한해 규칙으로 답하고, 선택지에 비가역이 섞이면 사람에게 남겨라(실측: 그렇게
   짠 훅이 3회 연속 질문 루프를 사람 입력 0 으로 완주 3/3, 비가역 선택지에서 멈춤 3/3).
4. **계획 수정 요구는 PreToolUse deny 사유로는 안 먹는다(0/6).** 모델이 그것을 주입으로 읽는다 —
   그 판단은 옳은 방어이고, 우회하려 하지 마라.

## 5. 이 문서가 주장하지 않는 것

- sonnet 한 모델, 팔당 2~3판(부록 포함 최대 9). 한 머신·한 터미널.
- CLI 버전이 바뀌면 칸이 바뀔 수 있다 — 각 칸의 버전을 같이 인용해라.
- 미측정 칸을 «없다» 로 읽지 마라. 비어 있는 것은 결과가 아니라 측정이다.
