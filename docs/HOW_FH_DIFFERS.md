<!-- ko-tech-writer 이력: 매체 = 이 저장소의 GitHub 렌더 문서. 표본 = README.ko.md(습니다체, 낫표·§ 없음). 레지스터 = 독자용 문서. -->

[English](HOW_FH_DIFFERS.en.md) · **한국어**

# FH는 흔히 말하는 하네스와 어디가 다른가

## 흔히 말하는 하네스

요즘 '하네스'는 대개 에이전트를 둘러싼 실행 환경과 제어 장치를 가리킵니다. 설계 요소는 맥락, 도구, 실행, 상태와 기억, 가드레일, 평가, 복구의 일곱 가지로 나누고, 성숙도는 환경 구성에서 실행 제어, 자율 운영, 자기 개선으로 올라가는 사다리로 설명합니다. 핵심 질문은 '사람이 최소한으로 개입하면서 에이전트가 얼마나 복잡한 일을 안정적으로 끝내는가'입니다.

이 관점의 대표 사례는 OpenAI의 글 [Harness engineering: leveraging Codex in an agent-first world](https://openai.com/index/harness-engineering/)(2026-02-11)입니다. 이 글은 엔지니어의 일이 코드 작성에서 환경 설계, 의도 명시, 피드백 루프 구축으로 바뀐다고 보고, PR 검토도 점차 에이전트끼리 처리하는 방향으로 옮겨 갔다고 적습니다. 좋은 설명이고, FH도 이런 실행 환경을 바탕으로 합니다. 아래는 FH가 그 위에 무엇을 더하거나 바꾸는지입니다.

## 무엇이 다른가

| 흔한 요소·단계 | FH가 더하거나 바꾸는 것 | 직접 확인할 곳 |
|---|---|---|
| 가드레일 | 공개, 삭제, 이력 재작성은 별도 등급으로 둡니다. 자동 판정의 정확도가 아무리 높아도 이 세 표면은 통과시키지 않고, 검사 도구가 죽어 있으면 막는 쪽으로 닫힙니다. | [`CLAUDE.md`](../CLAUDE.md)의 Irreversibility Gates 항 · [`templates/.git-hooks/pre-push`](../templates/.git-hooks/pre-push) · [`templates/predelete_check.sh`](../templates/predelete_check.sh) |
| 평가 | 평가를 일곱 요소 중 하나로 두지 않고, 나머지 요소를 믿을 수 있게 하는 바탕으로 봅니다. 숫자를 믿기 전에 측정 도구를 '알려진 쌍'(통과해야 할 것 하나, 막혀야 할 것 하나)으로 보정하고, 보정하지 못한 결과는 `UNCALIBRATED`로 적습니다. 재지 않은 것은 0이 아닙니다. | [`measurement-integrity-checklist.md`](../knowledge/shared/harness-core/measurement-integrity-checklist.md) · [`docs/ABLATION_CYCLE.md`](ABLATION_CYCLE.md) |
| 평가 (누가 하는가) | 작성자와 같은 맥락을 공유한 검토자는 같은 사각지대를 공유합니다. 그래서 다른 회사의 모델이나 작성자와 다른 정보를 받은 검토자를 붙이고, 검사가 정말 일하는지는 검사 대상을 되돌려 빨간색이 나오는지로 확인합니다. | [`auto-decorrelation`](../plugins/fh-meta/skills/auto-decorrelation/SKILL.md) · [`scripts/revert_probe.sh`](../scripts/revert_probe.sh) · [`docs/ETHOS.md`](ETHOS.md)의 2번 원칙 |
| 성숙도: 자기 개선 | FH는 이 단계를 사다리에서 가장 흉내 내기 쉬운 단계로 봅니다. 출하 등급은 그것을 설명하는 문서가 아니라 실제로 돌아간 기록으로만 매기고, 규칙을 덜어낼 때도 빼서 잃는 것이 없음을 측정한 뒤에 뺍니다. | [`ship_readiness_gate.md`](../knowledge/shared/harness-core/ship_readiness_gate.md) · [`docs/ABLATION_CYCLE.md`](ABLATION_CYCLE.md) |
| 실행 제어 | 기계 장치는 되돌릴 수 없는 경계와 채널에만 둡니다. 판단은 판단으로 남기고, 검사는 기록의 속성(있는가, 형식이 맞는가)만 확인합니다. | [`CLAUDE.md`](../CLAUDE.md)의 Judgment rules 항 · [`.claude/rules/fh_4axis_gate.md`](../.claude/rules/fh_4axis_gate.md) |
| 모델 능력 | 하네스는 바닥만이 아니라 천장도 지킵니다. 약한 모델이 돌린 구조 검사가 강한 모델의 결함을 잡은 사례가 있습니다. 그래서 행동 규칙은 중간 크기 Claude 모델인 Sonnet 급에서 실제로 발화하는지 시험합니다. | [`sonnet_floor_doctrine.md`](../knowledge/shared/harness-core/sonnet_floor_doctrine.md) · [`docs/ETHOS.md`](ETHOS.md)의 7번 원칙 |

## 두 관점이 정말로 갈리는 곳

흔한 관점의 목표는 사람의 개입을 줄이는 것입니다. FH의 목표는 사람을 다른 자리로 옮기는 것입니다. 건마다 승인하는 일은 기계와 다른 모델의 검토에 넘기고, 사람은 무엇을 성공으로 볼지 정하는 틀, 판정 기준, 되돌릴 수 없는 결정을 맡습니다. 그래서 FH에서는 개입 횟수가 줄어도 공개와 삭제 앞의 사람 확인은 남습니다([`templates/PRE-PUBLISH-CHECKLIST.md`](../templates/PRE-PUBLISH-CHECKLIST.md), [`CLAUDE.md`](../CLAUDE.md)의 Irreversibility Gates 항). 개입 횟수만 세서는 이 차이가 드러나지 않습니다.

## 이렇게 하는 비용

- 마찰이 생깁니다. 커밋 훅([`templates/.git-hooks/pre-commit`](../templates/.git-hooks/pre-commit))이 검증 기록 없는 변경을 막고, 작성자 자신도 막힙니다. 하루 동안 막힌 기록은 [`docs/GATE_DAY.md`](GATE_DAY.md)에 있습니다.
- 머지가 느립니다. 무게가 실린 변경은 다른 회사 모델의 검토를 거치고, 머지는 변경을 실제로 건드리는 테스트를 다시 돌리는 [`scripts/pr_merge_verified.sh`](../scripts/pr_merge_verified.sh)로 합니다.
- 잘못 막기도 합니다. 문제가 생기면 막는 쪽으로 동작하도록 만들었기 때문에 도구 고장이나 형식 실수에도 막히고, 사람이 풀어야 합니다. 격리된 검토자는 오탐도 더합니다([`docs/ETHOS.md`](ETHOS.md)의 What FH does not claim).

## FH가 주장하지 않는 것

- 다른 하네스보다 낫다고 주장하지 않습니다. 다르게 하는 것과 그 비용을 적었을 뿐입니다.
- 탐지 엔진이나 정확도를 끌어올리는 장치가 아닙니다. 격리된 검토가 찾는 것은 바탕 모델 자신의 능력입니다([`docs/ETHOS.md`](ETHOS.md)의 'What FH does not claim').
- 실측 근거는 규모가 작지만 구체적입니다. 근거 문서는 [`docs/OUTPUT_EVIDENCE.md`](OUTPUT_EVIDENCE.md)이고, 표본 크기를 함께 적어 두었습니다. 벤치마크가 아니라 실제로 돌린 사례입니다.
- 보안 검사기가 아닙니다. FH의 게이트는 작업이 버티는가를 보는 품질 게이트입니다(같은 문서).
