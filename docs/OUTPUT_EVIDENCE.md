# OUTPUT EVIDENCE — what forge-harness has produced

> A compact, verifiable evidence packet. Counts are reproducible from the repo (commands at the bottom).
> This is **not** an adoption claim — forge-harness is young and built in the open. The honest reading is
> *volume + external artifacts*, not *proven longevity*. See [`ETHOS.md`](ETHOS.md) §"What FH does not claim".

## Built (in the repo, today)

| What | Count | Notes |
|---|---:|---|
| Active skills | **33** | 29 in `fh-meta` + 4 in `fh-commons`; 3 deprecated redirect stubs not counted |
| Agent definitions | **8** | `challenger`, `quench-challenger`, `fact-checker`, `hub-persona-auditor`, `persona-innovator`, `beginner`, `main-player`, `expert` |
| Operating rules | **6** | `.claude/rules/*.md` — mapping, modes, sync, sister-asset, operations |
| Knowledge docs | **23** | `knowledge/` — 6-axis framework, compounding loop, runtime flow, dialogue playbook |
| Plugins | **2** | `fh-meta` (meta-harness) + `fh-commons` (project-agnostic) |
| Self-gate | **1** | 4-axis pre-commit hook (backward / adversarial / forward / record) |

## Pace (built in the open)

| Metric | Value |
|---|---|
| First commit → latest | **2026-05-26 → 2026-06-06** (12 days) |
| Commits | **224** |
| Merged PRs | **66** |

> Read honestly: this is *velocity*, not *maturity*. A 12-day-old project is early. The point is that the
> compounding loop and self-gate were exercised on the harness's own development, not just described.

## External artifacts (verifiable links)

| Artifact | Reference |
|---|---|
| Paper (v1.0) | Zenodo DOI [`10.5281/zenodo.20397566`](https://zenodo.org/records/20397566) — arXiv in review |
| Package | npm [`@chrono-meta/fh-gate`](https://www.npmjs.com/package/@chrono-meta/fh-gate) — multi-backend governance gate (claude · codex · auto) |
| Codex-compatible beta | `docs/codex-compat.md` — methodology layer runs model-agnostic |

## Validation signals (worked examples, not benchmarks)

- **Governance gate, real code** (2026-05-31): applied `fh-gate` to OpenCode's AI-generated
  `permission/arity.ts` (163 lines, CI green). Gate verdict: **BLOCKED** — 2 A-grade findings CI did not
  catch (short-token overflow in allowlist; executor tools absent from arity table).
- **Cold-pass controlled experiments**: the `steel-quench` / `phantom-quench` isolation method was tested
  under controlled conditions (design-defense, semantic-phantom corpora). Treated as **worked examples** —
  the gain is an empirical, per-task question, and isolated reviewers add false positives to triage.
- **External contribution**: filed gstack issue #1890 (subscription-auth bug) — the harness's own
  cross-audit protocol surfacing a real bug in a sister project.
- **Frontier cadence sustained**: digests on 2026-05-26 and 2026-06-02 (recurring external-trend scan).
- **Model-tier flattening, measured** (2026-06-10): a 30-point blind battery — rule-application
  ("operating FH": trap routing, gate-class decisions, sync format) + meta-dev fixtures with known ground
  truth — run on four Claude tiers. Operation scores: top-tier anchor / Opus 4.8 / Sonnet 4.6 / Haiku 4.5
  = **100 / 100 / 97 / 94**. With the rules in context, *operating* the harness is nearly model-flat;
  tier differences appeared only in above-rubric design increments (3/3 · 1/3 · 0.5/3 · 0/3) — i.e. in
  *developing* the harness, not running it. Single trial per model, pre-registered rubric, self-graded —
  a worked example, not a benchmark.
- **Guard-axis before/after, measured** (2026-06-24): the same task was given to a bare agent and an
  FH-gated agent (same FH gate rule injected as context), reps=5 each, across two irreversible surfaces.
  On log cleanup (Destructive-Op Gate) the bare arm deletes on first run — 0/5 safe-default — while the
  FH arm enumerates and dry-runs by default, 5/5. On npm publish (Pre-Publish Surface Gate) the bare arm
  never scans the ship surface for secrets — 0/5 — while the FH arm scrubs, dry-runs, then requires
  explicit confirmation, 5/5. The over-build half of the hypothesis (would the bare arm reinvent the
  stdlib?) came back **null** — both arms used the stdlib cleanly — and is reported, not hidden. The
  measured delta is the *default on the irreversible action*. Visual + data:
  [`docs/before-after/`](before-after/render.png). Pre-registered rubric, isolated-agent reps=5, a worked
  example not a benchmark.

## What this evidence does *not* establish

- No claim of scaled external adoption or longitudinal results — the project is 12 days old.
- Experimental results are worked examples, **not** benchmarks; reproduce before relying on them.
- The cold-pass gain is the base model's own ability surfaced by isolation, **not** an accuracy engine FH adds.

---

<sub>Reproduce the counts:</sub>

```bash
# active skills (excludes deprecated redirect stubs)
for d in plugins/*/skills/*/; do grep -qi "DEPRECATED — merged\|redirect stub\|moved to" "$d/SKILL.md" || echo "$d"; done | wc -l
# agents
ls .claude/agents/*.md plugins/*/agents/*.md | wc -l
# knowledge docs
find knowledge -name '*.md' | wc -l
# pace
git rev-list --count HEAD && git log --reverse --format=%ad --date=short | head -1
gh pr list --state merged --limit 200 | wc -l
```
