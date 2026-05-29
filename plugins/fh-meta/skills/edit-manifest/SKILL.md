---
name: edit-manifest
description: Implements a predict-verify loop for harness edits. Every SKILL.md, rules/*.md, or CLAUDE.md change is paired with a predicted impact stored in a manifest. The next session verifies predictions against actual outcomes, and a validation gate accepts edits only when improvement is measurable. Runs automatically on harvest-loop Step 0-c and on explicit invocation.
user-invocable: true
allowed-tools: ["Read", "Write", "Edit", "Grep", "Glob", "Bash"]
model: sonnet
---

# edit-manifest — Predict-Verify Loop for Harness Edits

> Implements two mechanisms from frontier harness research:
> - **Change Manifest** (AHE, arXiv:2604.25850): every edit declares a falsifiable prediction;
>   the next iteration verifies it against actual outcomes.
> - **Validation Gate** (SkillOpt, arXiv:2605.23904): candidate edits are accepted only when
>   the selection-split score strictly improves. Rejected edits are retained as negative
>   feedback for future proposals — not silently discarded.

FH's regression_guard.sh catches backward regressions. edit-manifest closes the forward
loop: did the edit actually improve what it claimed to improve?

## Manifest File Location

```
tracks/_meta/edit_manifest.yaml
```

Single append-only file. Entries are never deleted — they accumulate as the harness's
edit history and negative-feedback buffer.

## Manifest Entry Format

```yaml
- id: em-{YYYY-MM-DD}-{slug}
  date: YYYY-MM-DD
  file: plugins/fh-meta/skills/{skill}/SKILL.md   # relative to repo root
  edit_summary: "added 'trigger phrase X' to natural language triggers"
  predicted_impact: "users entering via phrase X will increase — estimate +1 session/week"
  predicted_measurable_by: "session start logs or user utterance pattern in next 2 sessions"
  validation_status: pending   # pending | verified | falsified | untestable
  verified_at: null
  verification_note: null
  gate_decision: null   # accepted | rejected
```

## Trigger Conditions

### Automatic — Record Phase (on every FH asset edit)

Whenever the **3-axis auto-gate** in CLAUDE.md fires (any SKILL.md / rules / CLAUDE.md edit),
append a manifest entry **before** committing. The 3-axis auto-gate orchestrator calls this
skill's Record step as Step 0 of its flow.

### Automatic — Verify Phase (harvest-loop Step 0-c)

At session start (via harvest-loop), read all `pending` entries and attempt verification.

### Manual

| Phrase | Action |
|---|---|
| "check edit manifest", "did our edits work?" | Full verify pass on pending entries |
| "show rejected edits", "what didn't work?" | Display rejected-edits buffer |
| "add to manifest", "record this edit" | Manual Record step |

## Execution Steps

### RECORD mode (called on each FH asset edit)

**Step R1 — Draft Entry**

Prompt the AI (or the user, for high-stakes edits) to fill:
- `edit_summary`: one line, what changed
- `predicted_impact`: what observable improvement is expected
- `predicted_measurable_by`: how and when this can be checked

**Step R2 — Append to Manifest**

```bash
# Append YAML block to tracks/_meta/edit_manifest.yaml
```

Output confirmation: `edit-manifest: entry em-{date}-{slug} recorded`

**Step R3 — Flag Untestable Predictions**

If `predicted_measurable_by` is vague ("generally better", "feels cleaner") → mark
`validation_status: untestable` immediately. These are tracked separately as a signal
that the edit rationale needs sharpening.

---

### VERIFY mode (harvest-loop Step 0-c or manual)

**Step V1 — Load Pending Entries**

```bash
grep -A20 "validation_status: pending" tracks/_meta/edit_manifest.yaml
```

Skip entries where `predicted_measurable_by` date has not yet passed.

**Step V2 — Verify Each Entry**

For each pending entry, check the evidence source specified in `predicted_measurable_by`:

| Evidence Source | Check Method |
|---|---|
| Session utterance patterns | Grep `tracks/_meta/` for trigger phrases |
| Skill invocation count | Read `knowledge/shared/learnings/subagent_invocations_log.yaml` |
| User friction signals | Grep `tracks/_meta/fh_signal_*.md` for related friction |
| Git commit frequency | `git log --oneline --since={date} -- {file}` |

**Step V3 — Apply Validation Gate**

| Outcome | Gate Decision | Next Action |
|---|---|---|
| Evidence confirms prediction | `verified` → `accepted` | No action needed |
| Evidence contradicts prediction | `falsified` → `rejected` | Add to rejected-edits buffer; propose revert if regression |
| No evidence yet | Keep `pending` | Re-check next session |
| Untestable | `untestable` | Flag for human judgment |

**Step V4 — Rejected-Edits Buffer Report**

After verification pass, output rejected entries as a learning signal:

```
edit-manifest: verification complete
  Verified (accepted): N
  Falsified (rejected): N
  Still pending: N
  Untestable: N

Rejected edits (negative feedback buffer):
  em-2026-05-28-trigger-phrase: predicted "+1 session/week via phrase X"
    → falsified: no utterance evidence in 7 sessions
    → proposed revert: [y/N]
```

**Step V5 — Update Manifest**

Apply `verified_at`, `verification_note`, `gate_decision` to each resolved entry via Edit.

## Validation Gate Logic

Mirrors SkillOpt's selection-split gate:

```
IF verified evidence shows improvement:
    gate_decision = accepted (edit stays)
ELSE IF falsified (no improvement or regression):
    gate_decision = rejected
    → retained in manifest as negative feedback
    → future edit proposals for same file grep rejected entries first
    → propose revert to human
ELSE:
    stay pending
```

**Rejected-Edit Reuse**: When proposing a new edit for a file, the AI must grep
`edit_manifest.yaml` for prior `rejected` entries on that file and explicitly
state why the new proposal avoids the same failure mode.

## Constraints

- **Append-only**: Never delete manifest entries. Rejected edits are the most valuable
  learning signal — they prevent the same mistake twice.
- **Human gate on revert**: Gate decision `rejected` proposes revert; human confirms.
- **Simplification guard**: If no pending entries exist, output one line
  "edit-manifest: no pending entries" and exit.
- **Untestable rate alarm**: If `untestable` entries exceed 30% of total, flag:
  "edit rationale quality degrading — predictions are not falsifiable."

## Done When

```
RECORD mode:
  Entry appended to edit_manifest.yaml
  + Untestable flag applied if vague prediction

VERIFY mode:
  All pending entries checked
  + Gate decisions applied (accepted / rejected / pending)
  + Rejected-edits buffer reported
  + Manifest file updated via Edit
  + Human gate presented for any proposed reverts
```

## References

- Theoretical basis: AHE (arXiv:2604.25850) §4 change manifest + prediction falsifiability
- Validation gate: SkillOpt (arXiv:2605.23904) §3.3 selection-split gate + rejected-edit buffer
- Integrates with: `harvest-loop` Step 0-c · `verify-bidirectional` · 3-axis auto-gate (CLAUDE.md)
- Manifest file: `tracks/_meta/edit_manifest.yaml`
