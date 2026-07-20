---
paths:
  - "plugins/**/SKILL.md"
  - "knowledge/**/*.md"
  - "templates/**"
  - "AGENTS.md"
  - ".claude/rules/**"
  - ".claude/agents/**/*.md"
---

<!-- ⚠️ CLAUDE.md 를 glob 에서 **의도적으로 제외**했다 (2026-07-20, cross-family 지적).
     루트 CLAUDE.md 는 세션 시작에 무조건 읽히므로, glob 에 넣으면 이 규칙이 매 세션
     즉시 로드된다 = 절감 0 이고 총량은 오히려 늘어난다(67.6k + 12.5k > 76.7k).
     즉 "상주 파일을 조건부 규칙의 트리거로 넣는 것"은 pointer-illusion 의 부활 경로다.
     CLAUDE.md 편집은 pre-commit 훅이 계속 커버한다. docs/** · plugins/**/*.md(전체) ·
     scripts/** 도 과매칭(읽기만 해도 로드)이라 좁혔다. -->

<!--
  FH 4-Axis Auto-Gate — 경로 스코핑된 규칙 (2026-07-20 이전)

  왜 여기 있나: CLAUDE.md **파일** 76,706자 중 이 섹션이 10,331자(13.5%)로 단일 최대였다.
  요약으로 대체한 뒤 순감 9,124자(11.9%) — 전부 **파일 char 실측**이지 `/context` 상주
  실측이 아니다(상주는 톱레벨 새 세션 `/context` 로만 잰다 — 이번엔 미측정).
  이 게이트는 **FH 자산 파일을 건드릴 때만** 필요하므로 `paths:` 로 조건부 로드한다.
  (`paths:` 없는 rules 파일은 세션 시작 시 항상 로드된다 — 반드시 유지할 것.)
  ⚠️ 공식 트리거는 **read** 다("Path-scoped rules trigger when Claude reads files matching
  the pattern" — code.claude.com/docs/en/memory.md). 즉 매칭 파일을 안 읽고 Write 로 신규
  생성하는 경로엔 이 규칙이 안 실린다. 그 구멍의 floor 는 pre-commit 훅이다.

  왜 이 섹션이 이동 후보 1순위였나 — 2축 판정:
    ① 트리거가 **파일**이다 (FH 자산 수정). 의도·발화 트리거가 아니다.
    ② **기계 백스톱이 있다** — `templates/.git-hooks/pre-commit` 이 커밋을 하드 차단한다.
       즉 이 산문이 안 떠도 훅이 막는다. 산문은 훅 위의 살리언스 층이다.

  ⚠️ 같은 이유로 **옮기면 안 되는 것들**: Pre-Publish Gate · Destructive-Op Gate ·
  Irreversibility 공통 척추. 그것들은 **파일이 아니라 의도로 발동한다**
  (`gh repo create --public` 은 파일을 건드리지 않는다). 경로 스코핑하면
  정확히 그 경로에서 안 뜬다 = fail-open.

  과거 실패 참조: FH 가 detail 포인터 뒤로 ~50k 를 옮겼으나 대상이 여전히 auto-load 라
  절감이 0 이었다(pointer-illusion). `paths:` 는 플랫폼 레벨 강제라 그 함정이 없다.
-->

## FH Improvement 4-Axis Auto-Gate (Self-Verification Orchestrator)

**Whenever the AI modifies FH assets** (SKILL.md · `.claude/rules/*.md` · `knowledge/shared/rules/*.md` (relocated protocol rules — always full-gate, NOT under the knowledge carve-out) · `templates/` · `CLAUDE.md` · substantive `knowledge/` docs · substantive `docs/*.md` · `AGENTS.md` — see Substantive carve-out below),
the 4-axis verification chain runs **automatically before the first commit** of that session.
No user request is needed — this is a mandatory autonomous step, not a proposal.

**Commit gate**: `git commit` on FH asset changes is hard-blocked by `templates/.git-hooks/pre-commit` until all required axes PASS. Hook installation (one-time): `git config core.hooksPath templates/.git-hooks && chmod +x templates/.git-hooks/pre-commit templates/.git-hooks/pre-push` (the same `core.hooksPath` also activates the **pre-push** Destructive-Op gate — see that section below).

```
FH asset modified → Axis 1 (templates/regression_guard.sh --pr {BRANCH})
  → Axis 2 (/steel-quench) → Axis 3 (/phantom-quench)
  → marker: tracks/_meta/.axes_23_passed_{branch}_{date}.marker
     (required fields: axis2-engine / axis2-model / floor-status / axis2-evidence;
      hook validates mechanically: below-floor blocks without below-floor-ack, and axis2-evidence
      must be non-vacuous — a recorded verdict/count, not "it ran". Marker scope is form +
      non-vacuity + auditability, NOT provenance — a fabricated marker is the weekly-audit + operator
      residual by design, do NOT fake-close it.
      → **Detail**: See `knowledge/shared/harness-core/claude_md_gate_details.md §Marker-Irreducibility`
        — why the below-floor-ack is structurally irreducible for an autonomous runner + the
        operator-present GPG hard-close option — read when auditing or attempting to harden the marker.)
  → Axis 4 (/edit-manifest RECORD, today's entry in edit_manifest.yaml)
  → All 4 PASS → git commit allowed   |   Any FAIL → fix inline, re-run
```

**Why automatic**: Each axis catches a different defect class; asking separately means slip-through. **Why hook**: CLAUDE.md rules are advisory — the hook physically blocks commit until marker + manifest exist. **Scope**: active from the moment any FH file is modified in the session.

**Lightweight exception** (Axis 1 + 4 only, skip Axes 2–3): Sessions where **zero SKILL.md / rules / templates files changed** (e.g., CATALOG.md entry, tracks/ update). The hook detects this automatically — no Axes 2+3 marker required for light-only commits. Judgment is file-based, not subjective.

**Substantive carve-out — `knowledge/` · `docs/*.md` · `AGENTS.md`** (Axes 2–3 DO run, despite these not being SKILL/rules/templates): a change to any of these is **not** light if its diff adds a fenced code block (```` ``` ````) or a citation/version claim (`arXiv:` / `DOI` / `http` / a versioned dependency like `x.y.z`). Executable patterns and factual claims need phantom-detection + adversarial review *wherever they live* — `knowledge/` Implementation-Patterns sections carry runnable commands, `docs/` holds published guides, and `AGENTS.md` is the Codex-user entry point, so a phantom skill name or wrong version there is an external-facing error the gate must catch. Prose-only edits (typos, rewording, link fixes) stay light. Detection is mechanical: `git diff` adds a ```` ``` ```` fence or a citation token → run Axes 2–3.

**Unavailable axis**: If steel-quench or phantom-quench are not installed, note `Axis N: skipped (skill unavailable)` and proceed. Axis 1 PASS alone is sufficient to unblock a PR when Axes 2–3 are unavailable. Axis 4 (edit-manifest): if the skill is not installed, substitute a manual one-line prediction appended to `tracks/_meta/edit_manifest.yaml` — the record is what matters, not the skill.

**Target-tier sim gate (Mode D supplement — all change classes: fix, improvement, new asset)**: the
discriminator is not the change class but the **enforcement column**: does the asset's effect depend on
a session *following prose instructions* (salience-dependent — rules, onboarding scaffolds, SKILL.md
trigger behavior), or is it mechanically enforced (hooks, scripts — tier-independent, normal 4-axis
path, exempt)? For salience-dependent changes, verify with a **blind simulation in an isolated Agent**
(no main-session reasoning inherited — isolation is the FH mechanism that keeps the sim honest) with
`model:` pinned to the tier the change must survive on — **default sim tier = Sonnet** (the base
floor every FH behavior must survive on, `sonnet_floor_doctrine.md`). Application strength scales
with context:
- **Mode D (FH self-dev) — near-mandatory**: any salience-dependent FH asset change runs the sim
  before Done, at Sonnet by default. Mandatory without exception when the change fixes a behavioral
  miss *observed* on a specific tier — sim at that same tier, even below Sonnet (the verification
  tier must match the failure tier; fixing on a stronger model and verifying by review alone leaves
  "does it fire on the weaker tier?" unanswered).
- **Field harness assets (templates/ propagated via Full-Harness Mode) — conditional**: sim at the
  default field tier (Sonnet) when the behavior is load-bearing (gates, onboarding, destructive/publish
  paths); skip with a one-line note for low-stakes prose.
- **Light mapping (tracks/ registration, CATALOG entries) — exempt**, alongside mechanical changes
  (hook logic, scripts, file moves — tier-independent by construction).

**Autonomy floor**: the skip/run *judgment* on conditional cases is itself depth-sensitive — trust it
only at opus-tier or above. A below-floor orchestrator does not silently skip — and does not stall:
its default is to RUN the sim (the conservative branch needs no trust); it asks the operator only when
no runnable path exists (run-first, ask-last — sonnet_floor_doctrine.md §Autonomy at Sonnet).

Record sim results in the Axes 2–3 marker + sub-agent invocation log.

> **Detail**: See `knowledge/shared/harness-core/claude_md_gate_details.md §Sim-Dispatch-Fallback` — the
> headless `claude -p --model` fallback when in-session model-pin is unavailable, the saturation-disguise
> retry (compact-then-retry once), and the credit-pool caveat — read when a model-pinned dispatch fails.

**Measurement-integrity pre-flight**: when the sim/dispatch is a *cross-model measurement* (pinned to a
tier, comparing model behaviors, or feeding a published claim), **the instrument must be verified before
the measurement is trusted**.

> **Detail**: See `knowledge/shared/harness-core/measurement-integrity-checklist.md` — pin the display
> name not a slug (silent fallback to a weaker model is a measured failure) · reps ≥ 3 on any
> borderline/contested verdict (single draw = noise) · use a discriminating identity probe (a generic
> "OK" proves nothing about which model answered) — read **before** running any cross-model measurement.

**Floor-tier canary (optional pre-screen — token-free, *below* the Sonnet sim)**: a local model ≤ Sonnet
can blind-pre-screen a salience-dependent edit before the Sonnet dispatch is spent. **Canary, NOT gate**:
a PASS adds cheap floor confidence and you still run the Sonnet sim; a FAIL never blocks alone. The
terminal verdict stays with the **Sonnet-or-higher governor bound to a mechanical anchor** — **no
judge-only path**, no weak-local-judge regression of the judge-robustness principle.

> **Detail**: See `knowledge/shared/harness-core/claude_md_gate_details.md §Floor-Tier-Canary` — the local
> model/panel options, the blind-probe procedure, dogfood evidence, and the FAIL-triage (real salience gap
> vs floor-model quirk) — read when running a floor canary.

**Axis ownership** (each skill is already complete — orchestrator only coordinates):

| Axis | Skill | What it catches |
|---|---|---|
| Backward | `templates/regression_guard.sh` | Critical section loss, broken refs, syntax errors, line reduction |
| Adversarial | `steel-quench` | Trigger phrase collisions, design attack surface, over-engineered steps |
| Forward | `phantom-quench` | Phantom references, paths that don't exist, stale external links |
| Record | `edit-manifest` RECORD | Logs predicted impact — closes the predict-verify loop for future harvest-loop |

**Cross-family complement (Axis 2, autonomous when consented)**: `steel-quench` dispatches in-session at the
session tier — **same family** as the governor, so it shares the governor's blind spots. For a **load-bearing**
change (gates · irreversible-surface code · doctrine), `auto-decorrelation` is the standing cross-family
verifier: it recruits ≥1 **different-family** auditor when the sidecar panel is discoverable, and degrades
honestly to single-session when none is. **Autonomous once the operator has consented** (one-time, in the
UAP — `[[user_adaptation_profile]]`); the governor keeps the terminal verdict and **source-grounds** every
sidecar finding before acting on it (`[[feedback_judge_robustness_mechanical_anchor]]`).

> **Detail**: See `knowledge/shared/harness-core/claude_md_gate_details.md §Cross-Family-Complement` — the
> UAP sidecar mapping (which family for which task class) and the 2026-06-27 dogfood evidence — read when
> recruiting or configuring a cross-family auditor.

### Mode D Model Notice (fires once, at the same trigger as this gate)

When FH self-dev begins (an FH asset is about to change), check the **session model** and surface **one
line**, then proceed — never block, **never switch the model** (human override inviolable): opus-tier+ →
no notice · below-opus → **dispatch-first recommend** (keep Sonnet + route depth turns to sidecar/opus
dispatch; `/model opus` pin = secondary — `sonnet_floor_doctrine.md`) · unknown → static fallback recommend. Once per session;
field-project (non-FH-asset) sessions never see it. Whether a session actually *escalates* (not just this
advisory) is governed separately by `capability_escalation_consent.md`.

> **Detail**: See `knowledge/shared/harness-core/claude_md_gate_details.md §Mode-D-Model-Notice` — the
> exact 3-branch wording (한글), the full guards, and the capability-escalation-consent cross-ref — read
> when surfacing the notice.
