**English** · [한국어](HOW_FH_DIFFERS.md)

# How FH differs from the usual idea of a harness

## The usual idea

"Harness" today usually means the execution environment and control devices around an agent. Its design elements are listed as context, tools, execution, state and memory, guardrails, evaluation and recovery, and its maturity is drawn as a ladder: configure the environment, control execution, operate autonomously, improve itself. The headline question is how complex a job the agent can finish reliably with the least human intervention.

A well-known statement of this view is OpenAI's [Harness engineering: leveraging Codex in an agent-first world](https://openai.com/index/harness-engineering/) (2026-02-11). There the engineer's job moves from writing code to designing the environment, stating intent and building feedback loops, and pull-request review moves increasingly to agent-to-agent. It is a good description, and FH sits on top of that layer. What follows is what FH adds or changes.

## What differs

| Usual element or rung | What FH adds or changes | Where to see it |
|---|---|---|
| Guardrails | Publish, delete and history-rewrite are a separate class. No accuracy figure clears them, and a check whose tooling is down blocks rather than passes. | [`CLAUDE.md`](../CLAUDE.md), Irreversibility Gates · [`templates/.git-hooks/pre-push`](../templates/.git-hooks/pre-push) · [`templates/predelete_check.sh`](../templates/predelete_check.sh) |
| Evaluation | Treated not as one element of seven but as what makes the others trustworthy. Instruments are calibrated on a known pair (one that must pass, one that must block) before a number is trusted; an uncalibrated result is written `UNCALIBRATED`. Not measured is not zero. | [`measurement-integrity-checklist.md`](../knowledge/shared/harness-core/measurement-integrity-checklist.md) · [`docs/ABLATION_CYCLE.md`](ABLATION_CYCLE.md) |
| Evaluation (who does it) | A reviewer who shared the author's context shares the author's blind spots. FH adds reviewers from another model vendor or with different information, and checks that a check works by reverting its target and watching it go red. | [`auto-decorrelation`](../plugins/fh-meta/skills/auto-decorrelation/SKILL.md) · [`scripts/revert_probe.sh`](../scripts/revert_probe.sh) · [`docs/ETHOS.md`](ETHOS.md), principle 2 |
| Maturity: self-improving | The easiest rung to fake. FH grades readiness only from records of real runs, not from documents that describe them, and cuts a rule only after measuring that removing it loses nothing. | [`ship_readiness_gate.md`](../knowledge/shared/harness-core/ship_readiness_gate.md) · [`docs/ABLATION_CYCLE.md`](ABLATION_CYCLE.md) |
| Execution control | Machinery only at irreversible edges and channels. Judgment stays judgment; a check asserts properties of the record (present, well-formed), not conclusions. | [`CLAUDE.md`](../CLAUDE.md), Judgment rules · [`.claude/rules/fh_4axis_gate.md`](../.claude/rules/fh_4axis_gate.md) |
| Model capability | A harness guards the ceiling as well as the floor: a structural check run by a weaker model has been observed catching a stronger model's defect. Behaviour rules are tested for whether they fire at Sonnet tier (a mid-sized Claude model, used as the floor). | [`sonnet_floor_doctrine.md`](../knowledge/shared/harness-core/sonnet_floor_doctrine.md) · [`docs/ETHOS.md`](ETHOS.md), principle 7 (floor and ceiling) |

## Where the two views really part

The usual aim is to reduce human intervention. FH's aim is to relocate the human. Per-item approval goes to machinery and to review by other models; the person keeps the frame (what counts as success), the criteria, and the irreversible decisions. So in FH the count of interventions can fall while the human check before publish and delete stays ([`templates/PRE-PUBLISH-CHECKLIST.md`](../templates/PRE-PUBLISH-CHECKLIST.md), and the Irreversibility Gates in [`CLAUDE.md`](../CLAUDE.md)). A count of interventions alone will not show this difference.

## What this costs

- Friction. The commit hook ([`templates/.git-hooks/pre-commit`](../templates/.git-hooks/pre-commit)) blocks changes without a verification record, including the author's own. One day of blocks is in [`docs/GATE_DAY.md`](GATE_DAY.md).
- Slower merges. Load-bearing changes get a review from another vendor's model, and merges go through [`scripts/pr_merge_verified.sh`](../scripts/pr_merge_verified.sh), which re-runs the tests that exercise the change.
- False blocks. Built to fail closed, it also blocks on broken tooling or a malformed record, and a person has to clear it. Isolated reviewers add false positives too ([`docs/ETHOS.md`](ETHOS.md), "What FH does not claim").

## What FH does not claim

- That it is better than other harnesses. This page says what it does differently and what that costs.
- That it is a detection engine or accuracy multiplier. An isolated review surfaces the base model's own ability ([`docs/ETHOS.md`](ETHOS.md), "What FH does not claim").
- Large evidence. Its measured evidence is modest and specific, in [`docs/OUTPUT_EVIDENCE.md`](OUTPUT_EVIDENCE.md) with sample sizes — worked examples, not benchmarks.
- That it is a security scanner. FH's gates are quality gates: does the work hold up.
