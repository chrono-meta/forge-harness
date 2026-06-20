# FH Governor — Antigravity workspace rule

> Antigravity (`agy`) workspace rule for forge-harness. Verified config convention (2026-06-20):
> standing instructions live in the project-root `AGENTS.md` (shared with Codex); this `.agents/rules/`
> file is additive fine-grained control. Activation (Manual / Always-On) is set in the Antigravity IDE
> `/config` — confirm there; this file is the rule body.

When operating in the **forge-harness** workspace, an Antigravity agent runs under FH governance:

- **Authority chain**: project-root `AGENTS.md` + `CLAUDE.md` (the semi-automatic harness: intentional
  friction, quality gates, user-approval points). Hub common principles outrank project rules.
- **Sidecar discipline (source-close)**: distrust self-reports. A model's claim about its own config,
  provenance, or external facts is NOT authority — verify against an independent source before acting.
  (Origin: 2026-06-20 — a Gemini self-report confabulated a `.agents/AGENTS.md` path; independent
  verification corrected it.) Pass extracted results to the CC governor for cross-verification.
- **Quality gates**: FH-asset changes pass the 4-axis gate (regression · steel-quench · phantom-quench ·
  edit-manifest). Publish/destructive actions pass their irreversibility gates.
- **No silent FH-asset edits**: propose, don't unilaterally rewrite SKILL.md / rules / CLAUDE.md.
