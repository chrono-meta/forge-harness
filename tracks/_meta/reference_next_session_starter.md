---
name: reference-next-session-starter
description: Next session context — 2026-06-01. Issue #47 PMH sidecar 검증 완결. 어댑터 구현은 PMH 세션 대기. v2 논문/npm publish 대기 지속.
date: 2026-06-01
tags: [session-starter, issue-47, sidecar, pmh-adapter, v2-paper, arxiv, npm-publish]
---

# Next Session Starter — 2026-06-01 (Issue #47 세션 마감)

## 현재 상태

- **작업 브랜치**: `claude/fh-issue-review-5JpBg` (이번 세션 커밋 2건 푸시됨: `cc93abc`, `c678ced`) — **main 미머지**
- **forge-harness** — `chrono-meta/forge-harness` 공개 레포
- **main 최신**: `f15bb2a` + worktree `8ffa4f5` (미머지)
- **논문 v1.0**: Zenodo 10.5281/zenodo.20397566 ✅ · arXiv submit/7657304 **번호 배정 대기 중**
- **논문 v2**: `knowledge/shared/harness-core/v2_paper_draft.md` — **Draft 1.1 완성** (steel-quench 자기 심사 통과)
- **스킬**: 33개 (29 fh-meta + 4 fh-commons)
- **워크트리**: `witty-juggling-crab` — PR #43·#44 머지 완료, PR #44 worktree 미머지 상태

---

## ⭐ 다음 세션 최우선

### 0-a. README 리뉴얼 (OpenHuman급 퀄리티)

- OpenHuman/Hermes/OpenCode README 수준으로 재구성
- 이미지 소스: 데스크탑 'fh 이미지' 폴더 기반
- 구성 요소: hero 이미지 + 아키텍처 다이어그램 + 빠른 시작 + badge
- fh-gate 바이너리 등장으로 "설치 한 줄" 섹션 추가 가능

### 0-b. npm publish @chrono-meta/fh-gate (새 최우선)

1. npmjs.com에서 `@chrono-meta` org 생성 (GitHub org 변환과 무관 — 독립적)
2. `npm login && npm publish --access public`
3. 확인: `npx @chrono-meta/fh-gate "src/foo.ts" quick ci`

**GitHub org 변환**: arXiv v1+v2 링크 고정 후 여유있게. 지금 불필요.

### 1. arXiv v1.0 번호 수신 → v2 arXiv 제출 → Awesome Lists PR (순서)

1. arXiv v1.0 번호 수신 (~2026-06-02)
2. **v2 논문 arXiv 제출** — draft 1.1 기반, 제출 전 최종 확인:
   - `knowledge/shared/harness-core/v2_paper_draft.md` (draft 1.1, steel-quench 완료)
   - Limitations §10.3 L1-L5 포함 ✅
   - 레퍼런스 전수 실존 확인 ✅ (arXiv 2603~2605 전부 실재)
3. **Awesome Lists PR** — v1+v2 + 이슈 증거 묶어서

### 2. Ablation Study (v2 논문 가장 중요한 Future Work)

steel-quench Wave 1 S-grade 지적: "harness vs. 동일 토큰+비구조화 프롬프트" control arm 미비.
- 동일 아티팩트 × 동일 토큰 예산 × 비구조화 "find all design/security defects" 프롬프트 vs. harness 구조화 프롬프트
- 독립 전문가 ground truth (유지관리자 이슈 확인) 사용
- v2 논문 최강 보강 증거 — 이것이 있으면 CS 컨퍼런스 제출 가능

### 3. Worktree 머지 (worktree-witty-juggling-crab → main)

```bash
gh pr create --base main --head worktree-witty-juggling-crab \
  --title "feat(session3): Multi-Team Panel + Exp3+5 + v2 paper draft 1.1"
gh pr merge --squash --admin
```

### 4. GitHub 이슈 3개 응답 추적

```bash
gh issue view 30057 --repo anomalyco/opencode
gh issue view 35709 --repo NousResearch/hermes-agent
gh issue view 3069 --repo tinyhumansai/openhuman
```

---

## 이번 세션 완료 ✅ (2026-06-01 Issue #47)

| 항목 | 결과 |
|---|---|
| **Issue #47 PMH sidecar 검증 회신** | 문서 완성도=부분수정(어댑터는 PMH 보유) / 존재이유=검증완료. CATALOG 기록 갭 보강 (`cc93abc`) |
| **steel-quench (sidecar 존재 이유)** | Wave1 S2/A2/B1. 첫 회신 정정 — agent-in-agent 재귀: 구조적 무효·**epistemic(Claude→Claude diversity 붕괴) 부분 유효** |
| **sidecar 문서 패치** | `validated`→`internally-validated` + Boundaries provider-identity 가드 + Wave5 경계 섹션 (`c678ced`) |
| **goal-quench --verify 완주** | Step2 CONDITIONAL_PASS + Step3 PASS(0 phantom) → Overall PENDING |
| **세션 산출물 자기검증** | 팬텀 0. 자기모순 A 1건 정정 — "Cross-Team Synthesis"(두 Claude) 과장 → "동일 provider 내 zero-history 교차검증" |
| **PMH 어댑터 체크리스트 핸드오프** | 5항목 이슈 게시 (gh copilot 우선·KP-SASE·경로·ollama·Claude→Claude 가드) |

## 이전 세션 완료 ✅ (2026-05-31 세션 4)

| 항목 | 결과 |
|---|---|
| **PR #45 main 머지** | worktree-witty-juggling-crab → main squash 머지 완료 |
| **v2 논문 draft 1.2** | §1 steel-quench — S1(novelty) + A2/A3/A5 전부 즉각 수정 |
| **v2 논문 draft 1.3** | B4(tier-snapshot) L4 확장 — 전 등급 소진, steel-quench Complete |
| **fh-gate.sh v1.0 바이너리** | claude --print 실행 + exit code 0/1/2/3/10/11 + governance log |
| **npm 패키지 @chrono-meta/fh-gate@1.0.0** | package.json + .npmignore + 72KB 4파일 구성 완료 |
| **자기심사 테스트** | fh-gate가 자기 자신 리뷰 → A-grade 발견(audit trail 소실) → 수정 → 거버넌스 루프 완결 |
| **방향 전환 인식** | "하네스를 만드는 것" → "하네스를 제공하는 것" (governance API 방향) |

## 이전 세션 완료 ✅ (2026-05-31 세션 3)

| 항목 | 결과 |
|---|---|
| **Multi-Team Adversarial Panel** | 5개 메타스킬 반영 (steel-quench/sim-conductor/source-grounding-audit/harness-doctor/harvest-loop) + PR #43 머지 |
| **Experiment 5 N=5 복제** | 4개 추가 아티팩트 실측. C1 평균 57%/C2 84%/C3 100% 전 아티팩트 확인 |
| **Experiment 3 tier 비교** | Haiku/Sonnet/Opus 실측. S-grade 3개 전 티어 동일. coverage-ceiling/path-length 구분 정립 |
| **v2 논문 draft 1.0** | 10섹션, 4실험 전부 실측 데이터 포함 (`v2_paper_draft.md`) |
| **Steel-quench 자기 심사** | Wave 1 3S+2A 발견. Wave 2: 2개 즉각 수정(GT 순환, 레퍼런스 오류), 2개 Limitations 명시 |
| **레퍼런스 전수 검증** | arXiv 2603~2605 5개 + harness-evolver URL 모두 실존 확인 (WebFetch) |
| **v2 draft 1.1** | Limitations L1-L5 추가, 레퍼런스 저자 교정(Sylph.AI→Seong et al.), 모델 버전 ID 추가, Data Availability |
| **pre-commit hook S-tier fix** | S-tier = 경고(commit 허용), M-tier만 차단 (PR #43) |

---

## 진행 중 🔄

| 항목 | 상태 |
|---|---|
| **arXiv v1.0 번호 배정** | submit/7657304 처리 대기 (~2026-06-02 예상) |
| **v2 arXiv 제출** | draft 1.1 준비 완료, v1.0 번호 수신 후 |
| **Awesome Lists PR** | v1+v2 묶어서, 번호 수신 후 |
| **Ablation study** | 미실행 — 다음 세션 최우선 실험 |
| **Worktree → main 머지** | PR #45 머지 완료 ✅ |
| **GitHub 이슈 응답** | 3개 오픈 — 유지관리자 확인 대기 |
| **fh-gate npm publish** | `@chrono-meta/fh-gate@1.0.0` — npmjs.com org 생성 후 publish 대기 |
| **GitHub org 변환** | arXiv 링크 고정 후 여유있게 |
| **PMH 환원 어댑터 구현** | 🆕 체크리스트 5항목 이슈 #47 게시 완료 → **PMH 세션에서 구현** (이 세션은 repo-add 도구 없어 불가) |
| **cross-provider grader 재실행** | 🆕 sidecar 검증 PENDING 잔존 — codex가 네트워크 `403 allowlist` 차단. 네트워크 허용 환경에서 재실행해야 single-provider 회로 완전 차단 |
| **claude/fh-issue-review-5JpBg → main 머지** | 🆕 이번 세션 커밋 2건, main 미머지 |

---

## 핵심 인사이트 (2026-06-01 Issue #47 확정)

**검증의 자기참조 함정 — 검증자의 provider 다양성을 검증하라**:
- 두 same-provider reviewer(Claude subagent + cross-session Claude)의 수렴은 **상관된 blind spot**이라 cross-provider 교차검증보다 약한 증거. "Cross-Team"으로 부르면 과장.
- 담금질이 이걸 잡은 건 자기검증을 자기검증했기 때문 — 내가 같은 세션에 쓴 규칙(Claude→Claude≠diversity)을 내 프레이밍이 위반.

**이슈 = 결정 레이어, 어댑터 = 구현 레이어 (분리)**:
- cross-team 이슈는 검증/결정을 닫지만, 어댑터 코드는 sister repo(PMH) 소유. Sister Asset Protocol clone-and-own 금지 → FH는 spec 핸드오프까지, 구현은 PMH.

---

## 핵심 인사이트 (세션 3 확정)

**Coverage-ceiling independence, path-length dependence**:
- 하네스 프로토콜 = 커버리지 상한 결정 (S-grade 탐지 티어 무관)
- 모델 티어 = 상한에 도달하는 경로 결정 (Opus는 자율 탐색으로 단축)
- "destination is harness-determined; journey is model-determined"

**C3 100% = 동어반복이지만 C2 84%는 실측값**:
- GT = C1∪C2∪C3 정의 → C3=100% 필연
- C2(3 cross-session 페르소나) = 84% 평균은 순환 아님 — 진짜 측정치
- 핵심 주장: C2가 비용 없이 단일 페르소나보다 27%p 더 포괄

**Multi-Team Panel의 의미**:
- Gemini는 Claude 3페르소나가 완전히 놓친 평균 4개/아티팩트 발견
- Claude-side 추가 토큰 = 0 (H3 validated N=5)
- 외부 CLI 사용 = Gemini quota 청구, Claude quota 불변

---

## 주요 컨텍스트

| 항목 | 내용 |
|---|---|
| **GitHub org** | chrono-meta |
| **워크트리** | witty-juggling-crab (push됨, main 미머지) |
| **Zenodo DOI** | 10.5281/zenodo.20397566 |
| **arXiv 계정** | akaa1941@gmail.com |
| **v2 논문** | `knowledge/shared/harness-core/v2_paper_draft.md` (draft 1.1) |
| **v2 framework** | `knowledge/shared/harness-core/v2_paper_framework.md` (모든 실험 데이터) |
| **Gemini CLI** | 0.41.2 설치됨 (사이드카 사용 가능) |
| **모델 ID** | haiku=claude-haiku-4-5-20251001 / sonnet=claude-sonnet-4-6 / opus=claude-opus-4-8 |
| **CATALOG.md 원칙** | 공개파일 = 영어 필수. tracks/·memory/ = 한글 OK |
