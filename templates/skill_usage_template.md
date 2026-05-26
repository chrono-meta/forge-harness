---
name: skill_usage_leaderboard
description: PMH 스킬 호출 빈도 추적 — 4주 미호출 시 폐기 후보 플래그
updated: 2026-05-26
---

# PMH Skill Usage Leaderboard

> **업데이트**: harvest-loop 실행 시 수동 기입 또는 세션 노트에서 집계
> **폐기 기준**: `last_used` 기준 28일(4주) 초과 시 → `⚠️ 폐기 후보` 플래그
> **부활 기준**: 폐기 후보라도 외부 사용자 요청 1건 이상이면 유지

## Leaderboard

| 스킬 | 마지막 사용 | 30일 호출 추정 | 상태 |
|---|---|:---:|---|
| harness-doctor | 2026-05-26 | 12+ | ✅ 핵심 활성 |
| context-doctor | 2026-05-26 | 8+ | ✅ 활성 |
| sim-conductor | 2026-05-26 | 6+ | ✅ 활성 |
| source-grounding-audit | 2026-05-26 | 3 | 🆕 신설 |
| agent-composer | 2026-05-24 | 5+ | ✅ 활성 |
| steel-quench | 2026-05-26 | 4+ | ✅ 활성 |
| harvest-loop | 2026-05-25 | 6+ | ✅ 활성 |
| field-harvest | 2026-05-25 | 4+ | ✅ 활성 |
| install-wizard | 2026-05-15 | 2 | 🟡 저빈도 |
| install-doctor | 2026-05-15 | 2 | 🟡 저빈도 |
| plugin-recommender | 2026-05-12 | 2 | 🟡 저빈도 |
| verify-bidirectional | 2026-05-20 | 3 | 🟡 저빈도 |
| sim-conductor | 2026-05-26 | 6+ | ✅ 활성 |
| hub-cc-pr-reviewer | 2026-05-18 | 3 | 🟡 저빈도 |
| apex-review | 2026-05-10 | 1 | ⚠️ 관찰 중 |
| deep-clarify | 2026-05-26 | 0 | 🆕 신설 |
| frontier-digest | 2026-05-24 | 3 | 🟡 저빈도 |
| cross-ecosystem-synergy-detection | 2026-05-08 | 1 | ⚠️ 관찰 중 |
| self-marketing-lint | 2026-05-09 | 1 | ⚠️ 관찰 중 |
| meta-prompt-builder | 2026-05-10 | 1 | ⚠️ 관찰 중 |
| asset-placement-gate | 2026-05-10 | 1 | ⚠️ 관찰 중 |
| marketplace-gate | 2026-05-10 | 1 | ⚠️ 관찰 중 |
| contention-layer | 2026-05-15 | 2 | 🟡 저빈도 |
| context-bridge-dispatch | 2026-05-15 | 2 | 🟡 저빈도 |

## 상태 기준

| 상태 | 조건 |
|---|---|
| ✅ 핵심 활성 | 30일 8회+ 또는 Three-Doctor Loop 구성 |
| ✅ 활성 | 30일 3회+ |
| 🆕 신설 | 생성 후 4주 미만 |
| 🟡 저빈도 | 30일 1-2회 — 모니터링 |
| ⚠️ 관찰 중 | 30일 1회 이하 — 폐기 후보 검토 필요 |
| ❌ 폐기 후보 | 28일 미호출 + 외부 사용 없음 |

## 갱신 방법

harvest-loop 종료 시 이 파일에 이번 세션에서 호출된 스킬을 기입:

```
세션 날짜: YYYY-MM-DD
사용 스킬: harness-doctor, context-doctor, steel-quench, ...
```

### 최근 세션 기록

| 날짜 | 사용 스킬 |
|---|---|
| 2026-05-26 | harness-doctor, context-doctor, sim-conductor, source-grounding-audit, steel-quench, agent-composer, harvest-loop, deep-clarify(신설), plan(신설) |
| 2026-05-25 | harvest-loop, field-harvest, harness-doctor, verify-bidirectional |
| 2026-05-22 | steel-quench, sim-conductor, source-grounding-audit(신설) |
