---
name: persona-cast
description: One-line doorway that lets a field harness review an artifact (a screen, a spec, a PR, a page) through a pre-built cast of review-shaped personas — web-review cast by default (designer, ux-writer, fe-dev, be-dev, qa, a11y) — dispatched in isolation, merged with a marginal-coverage stop so a lens that finds nothing unique is reported as decorative, not padded. Triggers: "이 화면 리뷰해줘", "페르소나로 봐줘", "디자이너·QA 눈으로 봐줘", "review this screen with the cast", "persona cast", "persona-cast".
version: 0.1
---

# persona-cast — a pre-built review cast a field harness can use without knowing the container

**Why this exists (operator decision 2026-09-12)**: FH can synthesize personas on demand through
`persona_container_schema.md`, but a field harness cannot — it would have to fill seven slots, pick a
tiering rule and run a marginal-coverage stop every time. What a field harness can use is the
container's *output*, pre-baked: a cast of review-shaped lenses plus one doorway. This skill is that
doorway, the same shape as `harness-pr-reviewer` (a standalone way in to one FH capability).

> Role split: `sim-conductor` synthesizes personas for a *simulation* and owns the parallax shape.
> `persona-roster-expander` turns a *named seed* into a tiered cast. `persona-cast` dispatches an
> *already-built* cast at an artifact. It builds nothing; a missing lens is a request to the two
> skills above, never inline improvisation.

## Casts (shipped in `plugins/fh-commons/agents/*-lens.md`)

| cast | lenses | for |
|---|---|---|
| `web-review` (default) | designer-lens · ux-writer-lens · fe-dev-lens · be-dev-lens · qa-lens · a11y-lens | a screen, a flow, a web/mobile spec, a page (review mode) **or a live app (explore mode)** |

A cast is a list, not a promise: every run measures which lenses earned their seat (Step 4).

## Steps

### Step 0.5 — Trigger probe (routing skill obligation · measured 2026-09-13)

This skill *routes* — it decides which agents run — so the FH New-Skill bar owes it a trigger
probe: **does a floor-tier session that was never told about this skill actually reach it from the
trigger phrases in the frontmatter?** Reading the description is not evidence; a reader who wrote it
is the one reader guaranteed to route correctly.

**Measured** — blind, floor tier (sonnet), isolated install (this skill + the six lenses only),
reps=3 per arm:

| arm | utterance | persona-cast reached |
|---|---|---|
| positive | `screen.html 이 화면 리뷰해줘` | **3/3** (seat names appeared 13–20× per run — the cast actually ran) |
| negative (control) | `README.md 의 오타를 고쳐줘` | **0/3** |

🟥 **The first probe fixture was wrong and measured nothing.** It ran the trigger with **no artifact
in the directory**, so the session correctly asked *which* screen — and whether it happened to name
the skill inside that question is incidental, not routing. It scored 1/3 and that number is void.
Give the probe a real artifact, or you are measuring the question, not the route.

Re-probe whenever the frontmatter trigger phrases change.

### Step 1 — Take the artifact and freeze it
Input = one or more **paths** (screenshot text dump, HTML→text capture, spec markdown, PR diff, page
snapshot). Record `sha256` of each file in the run header. A lens reads files; it never receives the
operator's summary of the files (that is the design-aware contamination the container's isolation
invariant forbids).

🟥 **The freeze is lossless.** Hand the lens the raw capture (the HTML, the full screenshot, the
unabridged spec) and, only *in addition*, any extracted view. Measured on the first run
(2026-09-12): an element extract that truncated attributes at 120 chars produced three
«unclosed href» Criticals from the qa lens — the page was fine, the *instrument* was broken, and the
lens had read the artifact faithfully. An extracted view is a convenience, never the artifact.

### Step 2 — Pick the cast (mechanical)
`--cast web-review` (default). `--lenses a,b,c` narrows. `--stance friendly|neutral|hostile` sets the
delivery layer for all lenses (recorded explicitly — an omitted stance is written as `neutral`).

### Step 3 — Dispatch each lens in isolation
One `Agent` per lens, `subagent_type` = the lens file's `name` (fh-commons:designer-lens …), prompt =
artifact paths + the stance + *nothing else*. Lenses run in parallel; none sees another's output.
Each returns the parallax block including its `Unique-to-this-seat` self-tag.

### Step 4 — Merge with the marginal-coverage stop (anti-decorative)
Normalize Concerns by `[location]` + first noun phrase. For each lens compute
`unique = concerns raised by this lens and no other`. Report per lens: `total / unique / self-tagged
unique that were actually unique`. **A lens with `unique = 0` is reported as `decorative on this
artifact`** — not deleted from the cast, but named, so the next run (or the cast maintainer) can drop
or merge it. Self-tag accuracy is the lens's own calibration score.

### Step 5 — Output
```
persona-cast · cast=web-review · stance=neutral · artifact=<path> sha256=<12>
lens          total  unique  self-tag-hit   verdict
designer        4      2        2/3          earned
ux-writer       3      3        3/3          earned
a11y            2      0        0/1          decorative on this artifact
...
Critical (merged, deduped, with the seats that raised each) …
Important …
Open questions (routed to the seat that may answer) …
```

## Explore mode (`--mode explore`) — 살아 있는 앱에서 탐색적 테스팅을 페르소나의 눈으로

Review mode 는 얼어붙은 아티팩트를 한 번 본다. Explore mode 는 **좌석마다 «다음 한 수» 를 고르는
항법**을 돌린다. 체크리스트 기반 탐색적 테스팅에 좌석을 얹는 형태다(운영자 실사용 2026-09: qasp 가
TE 처럼 세팅을 요청하고 사람이 적용하면 알아서 돌아보는 협업이 이미 성립).

🟥 **역할 분리 — 렌즈는 손이 없다.** 렌즈는 ⓐ 다음에 건드릴 곳 ⓑ 무엇으로 판정할지 ⓒ 정지 조건을
낸다. 조작은 **호출한 하네스의 실행기**가 한다(qasp 2막 러너 · Playwright · adb). 이 분리가 없으면
렌즈가 «눌렀다» 고 쓰면서 아무것도 실행하지 않는다 — 이 저장소가 이름 붙인 실행하지 않은 주장이다.

### 루프 (한 회전 = 관측 → 귀속 → 다음 수 → 정지 검사)
```
E1 개시   대상(앱·화면·계정) · 기획서 경로 · 소스 경로 · 체크리스트(있으면) · 좌석 목록
          🟥 기획서·소스가 없으면 MTM 이 아니다 → 회차를 «블랙박스 탐색» 으로 표기하고 진행
E2 회전   실행기가 준 관측(스크린샷·DOM·로그)을 좌석이 읽는다
          → 이상한 지점마다 MTM 3갈래 귀속(① 기획 의도 ② 기획과 다름 ③ 코드가 다름 · 못 가르면 미귀속)
          → 🟥 통과한 케이스에도 3갈래를 묻는다(MTM 정본 §2 — 사후 탐침과의 차이)
          → 좌석의 항법 규칙으로 «다음 한 수» 한 개를 낸다(이유 한 줄 필수)
          → 좌석의 정지 규칙 검사 · 회전 로그 한 줄(봤다/시켰다/왜)
E3 세팅   도달 못 하는 상태는 `세팅요청: <상태> · 왜 · 없으면 못 보는 케이스` 로 큐에 올린다.
          사람이 적용하면 그 지점부터 재개. **요청 목록은 산출물의 일부다**(자동화 경계의 실측)
E4 승격   판정 기준이 있는 발견만 케이스로 승격 → 다음 회차 «회귀» 가 상속.
          기준이 없으면 «관찰» 로 남겨 다음 회차 «탐색» 이 다시 본다
E5 마감   좌석별: 회전 수 · 고유 발견 · MTM 귀속 분포(①/②/③/미귀속) · 세팅 요청 · 승격 케이스 · 정지 사유
```

### 회차 판정 — 발견 수로 재지 마라
```
좌석 고유 발견 수        (좌석을 더 넣을수록 총 발견은 늘어난다 — 고유만 값이다)
세팅 요청 목록의 변화     (줄어들면 자동화 경계가 밀린 것)
승격된 케이스 수          (다음 회귀가 상속하는 자산)
MTM 미귀속 비율           (높으면 소스·기획서 접근이 부족한 것 — 좌석 탓이 아니다)
```
**대조군 필수**: 같은 회차에서 «좌석 없이 체크리스트만» 을 한 번 돌려 위 넷을 같이 적는다. 대조군이
없으면 좌석의 값이 회차 난이도와 구분되지 않는다.

### Residency
실앱·조직 내부 화면을 보는 회차에서 좌석은 **로컬 Claude 서브에이전트로만** 돈다. 관측물(스크린샷·DOM·
로그)을 외부 계열로 보내지 않는다. cross-family 가 필요하면 `auto-decorrelation` 의 자기 스크린을
탄다(그쪽이 residency 검사를 쥔다).

## Done When
```
+ artifact frozen (sha256 in header)                                    — mandatory-pass
+ every lens in the chosen cast dispatched in isolation (no shared
  context, no operator summary)                                          — mandatory-pass
+ per-lens total/unique/self-tag table emitted; unique=0 lenses are
  labelled decorative, never padded                                      — measured (unique count)
+ merged Concerns carry [location] and the raising seats                 — mandatory-pass

explore mode adds:
+ every seat's stop rule evaluated; an unfinished seat says 미완주 with
  what is left                                                            — mandatory-pass
+ MTM attribution present on every anomaly AND on the passing cases the
  seat looked at, with 미귀속 counted, not hidden                          — measured (①/②/③/미귀속)
+ 세팅요청 queue emitted even when empty (empty = «이 회차는 사람 세팅
  없이 도달했다», a result, not a blank)                                    — mandatory-pass
+ findings split into 승격(판정 기준 있음) vs 관찰(없음)                    — measured (two counts)
+ control arm run in the same 회차 (checklist without seats) or the run
  records why there is none                                               — mandatory-pass
```
**First-use gate (graduation)**: a cast graduates from *synthesized* to *validated* only when, on a
real artifact, every lens has `unique ≥ 1` at least once across runs. Until then the cast row above
says `synthesized`. Measured, not asserted.

## Constraints
- Review-shaped only. A lens that starts redesigning or rewriting has left its cap — drop that part.
- Residency: the artifact is read locally by Claude subagents. Do not route a company artifact to an
  external family through this skill; cross-family is `auto-decorrelation`'s job with its own screen.
- No new lens inline. Missing seat → `persona-roster-expander` (seed → tiered cast) → new file here.

## Provenance (Sister Asset)
Seed vocabulary for five of the six lenses: [wshobson/agents](https://github.com/wshobson/agents)
(MIT; ui-designer · frontend-developer · backend-architect · test-automator · accessibility-expert) —
those are **builder** agents, so only the role vocabulary and state checklists were taken; the review
frame is FH's (challenger / beginner / expert). No UX-writer exists in that pack; ux-writer-lens
derives from FH `ko-tech-writer`'s copy axis. What FH could offer back: the review-shaped container
(tier cap · stance invariant · marginal-coverage stop) — proposal only, operator decides.
