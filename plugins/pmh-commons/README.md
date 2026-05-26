# pmh-commons — 경합 출산 스킬 서식지

**pmh-meta와 다른 층위의 플러그인.**

pmh-meta = 하네스 자체를 운영·진단·고도화하는 메타 엔지니어링 스킬들  
pmh-commons = 경합 레이어에서 탄생한, 어느 프로젝트에나 이식 가능한 공용 유틸리티 스킬들

## 배치 기준

`contention-layer` 스킬이 경합을 수확해 신규 스킬 후보를 생성할 때:

| 판정 | 경로 |
|---|---|
| 하네스 엔지니어링 성격 | `pmh-meta` |
| 프로젝트 공용 · 도메인 무관 | **`pmh-commons`** (이 플러그인) |
| 도메인/팀 특화 | field harvest (현장팀 결정) |

## 스킬 목록

| 스킬 | 설명 | contention 부모 |
|---|---|---|
| `convergence-loop` | 단회 통과 구조를 최대 N라운드 수렴 루프로 교체하는 범용 게이트 강화 | mcp-spec-to-tc P3 gate + harvest-loop (동일 패턴 2회 독립 발생) |
| `deliberation` | Innovator → Devil-Advocate → Mediator 3-layer 다관점 합성. 이진 승패 없이 조건부 판정 생성 | pmh-meta 이관 (2026-05-23 — 도메인 무관 범용 의사결정 구조) |

## origin 필드

commons 스킬들은 SKILL.md frontmatter에 아래 필드를 포함한다:

```yaml
# 경합 출산 (contention-layer 추출)
origin: contention-layer
contention-parents: [스킬 A, 스킬 B]

# pmh-meta 이관 (범용성 재분류)
origin: pmh-meta
migration: "YYYY-MM-DD — 이관 사유"
```
