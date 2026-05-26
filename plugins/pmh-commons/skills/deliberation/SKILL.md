---
name: deliberation
description: 다관점 합성 구조 — Innovator(제안) → Devil-Advocate(공격) → Mediator(종합) 3레이어 실행. 이진 승패 없이 조건부 판단 출력. "배틀해줘", "찬반 따져봐", "여러 관점에서 검토해줘", "어느 쪽이 맞아?", "deliberation" 발화 시 발현. Optional deep-insight persona jurors for domain-specific views. Designed for design decisions, skill proposals, and architectural choices.
user-invocable: true
allowed-tools: ["Read", "Bash", "Agent"]
model: opus
origin: fh-meta
---

# deliberation — 용광로 스킬

Innovator(제안) → Devil(반박) → Mediator(합성) 3-layer 기본 구조.
배틀의 승자를 선택하는 것이 아니라, **패배한 논거에서 살릴 파편을 건져 조건부 판정을 생성**한다.
도전하기 어려운 사람도 이 구조를 밧줄 삼아 더 나은 결정에 도달할 수 있다.

> **sim-conductor와 역할 구분**
> - sim-conductor: 완성된 자산의 품질·정합성 **검증**
> - deliberation: 설계 결정 과정의 관점 충돌 → **합성** (검증 이전 단계)

---

## 트리거

- `/deliberation`
- "배틀해줘", "논쟁시켜봐", "충돌시켜서 합성해줘"
- "이 결정, 다양한 관점에서 검토해줘"
- agent-composer Step 4-b `Wave next-D` 자동 제안 시

### 자연어 트리거 (일반 사용자 발화 — 내부 어휘 없이도 발현)

설계 결정·관점 충돌 상황을 자연어로 표현할 때도 발현:

| 발화 예시 | 의도 |
|---|---|
| "이걸 해야 할지 말지 모르겠어" | 결정 불확실성 → 다관점 합성 |
| "찬반이 나뉘는 것 같아" | 관점 충돌 → 합성 레이어 필요 |
| "어느 쪽이 맞는지 판단해줘" | 단순 승자 선택이 아닌 조건부 합성 |
| "누군가는 반대할 것 같은데" | devil 관점 포함 검토 요청 |
| "이 방향 계속 가도 될까?" | 설계 결정 재검증 |
| "여러 관점에서 검토해줘" | 다관점 합성 → 3-layer 기본 |
| "다각도로 분석해줘" | 다관점 합성 → 3-layer 기본 |
| "찬반 따져봐줘" | 관점 충돌 → devil + innovator 구동 |
| "장단점 분석해줘" | 찬반 구조 → Innovator(장) + Devil(단) |
| "의사결정 도와줘" | 결정 지원 → 조건부 판정 생성 |
| "pros and cons", "pros cons" | 장단점 비교 → 합성 레이어 필요 |

---

## Step 0. 주제 수신 + 레이어 선택

입력이 없으면 묻는다:
```
deliberation 주제를 알려주세요.
  - 주제: 무엇을 결정하거나 설계하려 하나요?
  - 레이어: [3-layer 기본(권장)] / [5-layer — 배심 포함]
  - 배심 주제 (5-layer 선택 시): 사용자 경험 / 기술 타당성 / 사업·정책
```

**기본값: 3-layer** (Innovator → Devil → Mediator). 배심이 필요한 경우만 5-layer.

**실행 기록 (workers_approved 패턴)**:
Step 0 완료 시 아래를 출력에 포함한다:
```
[DELIBERATION START] 주제: {topic} | 레이어: {layer} | {timestamp}
  → WORKER_CALL: Innovator (격리 인스턴스)
  → WORKER_CALL: Devil-Advocate (격리 인스턴스)
  → WORKER_CALL: Mediator (격리 인스턴스 — Cost of Consensus 방지)
```

배심 자동 판단 기준:
| 주제 성격 | 권장 배심 페르소나 |
|---|---|
| 신규 사용자 경험 관련 | `newcomer` + `power-user` |
| 기술 구현 타당성 | `persona-be` + `persona-fe` |
| 사업성·정책·법무 | `persona-pm` + `persona-business` |
| 설계 결정 일반 | 배심 없음 (3-layer 충분) |

---

## Step 1. Innovator Layer — 제안

`deep-insight:persona-innovator`를 호출한다.

> **fallback (deep-insight 미설치 시)**: CC 인라인 Innovator 역할 수행. 지시문 템플릿 동일 적용, 출력 형식 동일. deep-insight 설치 없이도 deliberation 파이프라인 동작 보장.

> **격리 없음 (의도적)**: Innovator는 제안 생성자 — 자기 결과를 평가하지 않으므로 Agent 도구 격리 불필요. Cost of Consensus는 자기 생성물을 **평가**하는 Mediator에만 적용된다 (arXiv 2605.00914). Mediator(Step 3)만 Agent 도구로 격리.

지시문 템플릿 (meta-prompt-builder 구조):
```
Goal: {주제}에 대해 가장 창의적이고 확장 가능한 제안을 생성
Context: PMH 현재 상태 + 관련 자산 목록
Constraints: 기존 자산 중복 금지 / 단순화 가드 위반 금지
Done When: 구체적 제안 1~3개 + 각 제안의 근거 1줄
Brief 제한: Agent에 전달하는 Context 총량 1200자(한글) 이하 유지
```

출력 형식:
```
[Innovator]
  제안 1: {내용} — 근거: {1줄}
  제안 2: {내용} — 근거: {1줄}
  (선택) 제안 3: {내용} — 근거: {1줄}
```

---

## Step 2. Devil-Advocate Layer — 반박

`deep-insight:persona-devil-advocate`를 호출한다. Step 1 출력을 입력으로 받는다.

> **fallback (deep-insight 미설치 시)**: `fh-commons:quench-challenger` (Devil DNA 포함) 또는 CC 인라인 Devil-Advocate 역할 수행. 출력 형식 동일. Step 1과 마찬가지로 인스턴스 격리 불필요.

지시문 템플릿:
```
Goal: Innovator 제안 {N}개 각각에 대해 가장 날카로운 반박 1개씩 생성
Context: Innovator 출력 + PMH 단순화 가드 + 기존 실패 패턴
Constraints: 감정적 반박 금지 / 근거 없는 부정 금지 / 개선 방향 힌트 포함 의무
Done When: 제안별 반박 1개 + 핵심 위험 1줄 + 유효한 부분 인정 1줄
Brief 제한: Agent에 전달하는 Context 총량 1200자(한글) 이하 유지
```

출력 형식:
```
[Devil-Advocate]
  제안 1 반박: {내용}
    위험: {1줄}
    인정: {1줄}  ← 이 줄이 Mediator의 원료
  제안 2 반박: ...
```

> **인정 줄 의무**: Devil이 "이 부분만큼은 유효하다"를 반드시 남겨야 합성이 가능하다.
> 인정 없는 반박은 `[WARN: 합성 불가 반박]`으로 자동 표시.

---

## Step 3. Mediator Layer — 합성 (핵심)

**[격리 원칙 — Cost of Consensus 대응]**
Mediator는 `Agent` 도구로 별도 인스턴스를 호출한다.
같은 인스턴스가 자기 생성물을 평가하면 확증 편향이 발생한다 (arXiv 2605.00914 실증).
Innovator/Devil 생성 컨텍스트와 물리적으로 분리해야 편향 없는 합성이 가능하다.

> **격리의 의미**: 동일 인스턴스가 자신의 생성물을 평가하는 자기편향(Self-Evaluation Bias)을 차단.
> Mediator는 Innovator·Devil 출력 결과를 읽지만, 그 출력을 **생성하는 추론 과정**을 공유하지 않는다.
> 정보 공유가 아닌 추론 경로 독립이 Cost of Consensus 해소의 핵심이다.

Agent 호출 지시문 (Context Card 포함):
```
Goal: Innovator와 Devil-Advocate 출력을 합성해 조건부 판정 생성
Context: {Step 1 출력 전문} + {Step 2 출력 전문}
Constraints: 이긴 쪽 논거 단순 선택 금지 / 패배 논거에서 파편 추출 의무 / 회피 표현("균형 있게 고려") 금지 / 1200자(한글) 이하 출력
Done When: 채택 / 경보 흡수 / 판정 / 조건 / 폐기 5섹션 모두 출력됨
```

**합성 공식**:
```
Innovator 제안의 핵심 가치
  + Devil 반박 중 유효 경보 (인정 줄에서 추출)
  → 조건부 판정: "{제안} OK, 단 {조건} 의무"
```

**Mediator가 해서는 안 되는 것**:
- 이긴 쪽 논거를 그대로 선택하는 것 (단순 판정 = deliberation 실패)
- 패배한 논거를 버리는 것 (파편 추출 의무)
- "두 의견을 균형 있게 고려해야 합니다" 식 회피 표현

출력 형식:
```
[Mediator — 합성 판정]
  채택: {Innovator 제안 N}의 핵심 — {가치 1줄}
  경보 흡수: {Devil 반박}의 "{인정 줄}" → 조건 {X}로 전환
  ─────────────────────────────────────────
  판정: {제안} 진행 OK
  조건: {필수 조건 1~3개}
  폐기: {완전히 기각된 부분 — 근거 포함}
```

---

## Step 4 (선택). 배심 Layer — 도메인 관점

5-layer 선택 시만 실행. `Agent` 도구로 선택된 deep-insight 페르소나 2~3개를 **병렬** dispatch.

배심원 수 제한: **최대 3명**. 4명 이상이면 `[WARN: 배심 과다 — 소음 위험]` 발화 후 사용자 결정 위임.

각 배심원 지시문:
```
Goal: Mediator 합성 판정을 {페르소나} 관점에서 검토
Context: Step 1~3 전체 출력
Constraints: 이미 합성된 판정을 재뒤집는 것 금지 / 추가 조건 제안만
Done When: 동의/부분 동의/반대 + 추가 조건 또는 위험 1줄
```

출력 형식:
```
[배심: {페르소나명}]
  판정: 동의 / 부분 동의 / 반대
  의견: {1~2줄}
  추가 조건: {있으면 1줄}
```

---

## Step 5 (선택). Mediator 최종 합성

배심 의견을 반영해 Step 3 판정을 보완한다.

```
[최종 판정]
  기반: Step 3 합성 판정
  배심 반영: {동의 N명 / 부분 동의 N명 / 반대 N명}
  조건 추가: {배심에서 나온 추가 조건}
  최종 결론: {1~2줄}
```

---

## WARN 자동 탐지 패턴

| 상황 | WARN 내용 |
|---|---|
| Devil 반박에 "인정" 줄 없음 | `[WARN: 합성 불가 반박 — Mediator 재료 부족]` |
| Mediator가 한쪽 논거만 채택 | `[WARN: 합성 아닌 단순 판정 — deliberation 실패]` |
| Innovator와 Devil이 같은 전제 공유 | `[WARN: 진짜 충돌 아님 — 주제 재정의 권장]` |
| 배심원 4명 이상 선택 | `[WARN: 배심 과다 — 3명 이하로 줄이면?]` |
| Done When 모호 표현 포함 | `[WARN: Done When 측정 불가 — meta-prompt-builder WARN 기준 공유]` |

---

## agent-composer 연동 — Wave next-D

agent-composer Step 4-b 상태 전이 게이트에 아래 조건 추가:

```
| ⑤ 설계 결정 충돌 또는 "배틀이 필요한" 판단 시 | Wave next-D | deliberation (S) |
```

`Wave next-D` 발동 기준:
- M/S/R 결과 중 "서로 상충하는 제안이 2건 이상"
- 사용자 발화에 "어느 쪽이 맞아?", "충돌한다", "둘 다 타당한 것 같은데" 포함
- agent-composer가 fan-in 결과를 합성하지 못하고 사용자에게 결정을 위임하는 상황

---

## 설계 원칙 — 왜 이 스킬이 존재하는가

도전하지 않은 사람도 도전하기 위한 **밧줄**이다.

혼자 생각하면 한 관점에 갇힌다. 용기 있는 사람만이 스스로 반론을 만든다.
deliberation은 그 반론을 구조로 제공한다 — 충돌이 두려운 사람도 Mediator가 합성해주기 때문에 배틀을 시작할 수 있다.

Mediator의 조건부 판정은 "이렇게 하면 괜찮다"는 안전한 진입로를 만든다.
배심은 혼자서는 볼 수 없는 도메인 사각지대를 채워준다.

**용광로가 창조하는 것은 승자가 아니라 새로운 합금이다.**

---

## Done When

```
Step 0~3 전 단계 실행 완료 (5-layer 선택 시 Step 4~5 추가)
+ [Mediator — 합성 판정] 출력됨 (채택 / 경보 흡수 / 판정 / 조건 / 폐기)
+ 사용자 최종 결정 확인됨 (deliberation 결과 자동 실행 금지)
```

## 단순화 가드

- 단순한 정보 질의 → deliberation 불필요. 직접 답변 권장.
- 이미 답이 명확한 사안 → sim-conductor(검증) 또는 harness-doctor(진단)로 라우팅.
- 배심 없이도 해결 가능하면 3-layer 기본으로 충분.
- deliberation 결과는 항상 사용자 최종 결정으로 완료. 자동 실행 금지.

---

## 연계 스킬

| 상황 | 연계 스킬 |
|---|---|
| 설계 결정 충돌 시 자동 발동 (Wave next-D) | `fh-meta:agent-composer` Step 4-b |
| 완성된 자산 품질·정합성 검증 | `fh-meta:sim-conductor` |
| deliberation 이후 후보 스킬 검증 | `fh-meta:harness-doctor` |
| 결정 이후 구현 수렴 루프 | `fh-commons:convergence-loop` |
