---
name: hub-cc-pr-reviewer
description: Automatically checks baseline consistency when a PR is submitted and generates review comments. Handles diff reading, consistency checks, comment attachment, and merge recommendations. Automates hub gate operations.
user-invocable: true
allowed-tools: ["Bash", "Read", "Grep", "Glob"]
model: sonnet
complexity_routing:
  base: sonnet
  high: opus
  escalate_when:
    - adversarial
    - cross_project
    - high_stakes
---

> **Note:** The original developer is the forge-harness original developer (development source + meta-monitoring home). In external user install environments, the install environment user themselves is the baseline integrity gate operator (following path B generalization baseline / `## External User Environment Adaptation Path` §).

# hub-cc-pr-reviewer — Hub Gate Operation Rule Automation

When a PR is submitted, checks consistency against the user environment's baseline assets (CLAUDE.md · memory · naming · asset classification) and attaches a review comment. 5-step: diff read → 8-matrix check → self-catch → comment attachment → merge recommendation.

## Activation Triggers

1. **PR #N input**: *"Review PR #N"* / *"Check PR #N"* / *"hub review"* / *"baseline consistency check"*
2. **Action leader cc → hub sync point**: Large decision area PR catch (following Option C Hybrid policy — memory creation / CLAUDE.md change / CATALOG round / skill v0.x evolution / policy change / asset synergy branch judgment)
3. **Hub cc session entry**: Layer A auto-read recent external commit catch (auto-discover new PRs)

### Natural Language Triggers (General user phrasing — activates without internal vocabulary)

| Example phrasing | Intent |
|---|---|
| "Is it okay to submit this PR?" | PR review request |
| "This change seems inconsistent with existing rules" | Baseline consistency check |
| "Please review before merging" | PR review gate |
| "Does this change affect other parts?" | Consistency check |

**Activation criteria**: "Review PR #N" / "Add review comment" / "Baseline check" → Run this skill directly  
*(pr-review-watcher deprecated as of v0.2.0 — recommend using `gh pr view --json reviews` directly)*

**Exceptions** (this skill does NOT apply):
- **Small patches** (typo / 1-line cross-ref addition / sync / minor adjustments) → Follow Option C Hybrid policy (direct push allowed area / review skip)
- **Original developer simple correction commands** ("This is wrong, redo it") → Immediate correction (no review / direct handling)

## Processing Steps (5-step)

### Step 1. PR Diff Read

```bash
gh pr diff "$PR_NUMBER"                                             # Read changes directly
gh pr view "$PR_NUMBER" --json files,additions,deletions,baseRefName,headRefName,title,body  # Metadata
```

If this cc authored the change, `gh pr diff` can be skipped (directly state changed areas in PR body).

### Step 2. Baseline Consistency Check — 8-Matrix Auto-Generation

| # | Area | Check path |
|:---:|---|---|
| 1 | CLAUDE.md (hub identity + asset ownership + sync policy) | Grep PR diff vs CLAUDE.md baseline areas |
| 2 | Memory accumulation (accumulated naming/decision baseline + asset synergy branch judgment + active onboarding + bidirectional self-validation, etc.) | Grep PR diff vs `memory feedback_*.md` key areas (**External environment**: skip this item if memory files absent → `## External User Environment Adaptation Path` §) |
| 3 | Naming baseline (accumulated naming baseline + new naming candidate area) | Catch new naming candidates from PR diff / check adherence to existing naming |
| 4 | Asset synergy branch judgment (meta/hub seed vs action leader persistent location) | Check PR changed asset location consistency |
| 5 | Simplification guard (P15 asymmetry catch + R7 over-engineering) | New asset creation vs existing asset reinforcement judgment / body length check |
| 6 | Dimension separation baseline (## Plugins / ## Skills / ## Agents) | Check dimension separation consistency on CATALOG changes |
| 7 | Branch criteria (large decision PR mandatory vs small patch direct push) | Check if PR is a large decision area (Option C Hybrid) |
| 8 | Hub gate operation consistency | Check if PR itself is a hub gate operation proof path |

Matrix result = Consistent ✅ / Partially Consistent ⚠️ / Inconsistent ❌.

### Step 3. Layer 5 Self-Catch Matrix

Self-precision catch areas after first cc review (following previous PR self-catch patterns):
- Check adherence to frontmatter description plain text only baseline (project baseline)
- Check honest documentation of generalization effect weakening areas
- Check explicit statement of gap between accumulated history (original developer environment) vs external user starting point (0 instances)
- Check explicit statement that audience-specific guides are limited to original developer environment
- Check explicit statement of organization-specific areas

Self-catch areas 0 items = skip this entire catch matrix (no token-filling / following `feedback_simplification_evidence`).

### Step 4. Review Comment Attachment

```bash
gh pr comment "$PR_NUMBER" --body "$(cat <<'EOF'
## Hub CC Review (Hub Gate — Accumulated Operation Proof)

### Baseline Consistency Check 8-Matrix
{Step 2 results}

### Layer 5 Self-Catch Matrix
{Step 3 results / omit if 0 items}

### Refinement Suggestions (following simplification guard / areas for subsequent rounds outside this PR)
{Subsequent round areas / omit if 0 items}

### Admin Override Merge Recommendation
{User decision delegation / beta stage policy adherence}
EOF
)"
```

### Step 5. Admin Override Merge Recommendation

**User decision delegation** (this skill = review/recording automation / no merge authority):
- Beta stage policy (`enforce_admins: false`) adherence → admin override possible
- Self-approve blocked (GHE policy) → admin override path adherence
- When this cc authored the change, admin override path is mandatory
- N+1th operation proof = baseline stabilization acceleration path

```bash
# Execute after user decision (this skill does NOT execute)
gh pr merge "$PR_NUMBER" --squash --admin --delete-branch
```

## Sister Asset Utilization Path (cross-ecosystem-synergy-detection v0.2 baseline consistency)

| Cluster | Utilization path | Acceleration to 5+ instances |
|---|---|:---:|
| **QA cluster** (project QA repos) | Domain-specific consistency check auto-activation on action leader cc PR submission | ★★★ |
| **Meta cluster** (forge-harness · related plugins) | FH-meta area new skill consistency / meta/rule baseline consistency check | ★★ |
| **Automation cluster** (CI/CD automation tools) | Compare roles with external review tools and decide whether to apply as supplementary axis | ★★ |

## External User Environment Adaptation Path (path B generalization baseline)

This skill = original developer hub environment baseline. External user (mode C install) environment adaptation path — following forge-harness core proposition *"Beta + public release = obligation to have practical capabilities"*.

### External User Environment Assumptions

External users in 2 tiers:

| Type | Internal GHE access | Applicable path |
|---|---|---|
| **Internal non-hub** (org employee, not owner) | Yes | Replace matrix with user's own baseline assets — can use internal GHE PR workflow as-is |
| **External** (outside org) | No | Apply entire Fallback Matrix below — fully replace with user's own environment assets |

Common: In external user install environments, **the install environment user** is the baseline integrity gate operator.

This skill's core essence = "PR input → baseline consistency check + self-catch + review comment + merge recommendation" — cross-applicable to both types.

### Own PRS Priority Environment Catch (following Scenario 3 devil-advocate)

In external user environments where **own PRS (pr-reviewer-self)** is already established (environments with own PR review skill/rules/hooks/own conventions) — risk of conflict when this skill and own PRS activate simultaneously. Lack of activation trigger priority resolution catch.

**Common conflict examples**: `code-review` skills · PR review hooks (`.claude/hooks/post-tool-use`) · review skills from other plugins — duplicate activation on same triggers ("PR", "review").

→ **Disable path** adherence mandatory (see § below). Disable this skill baseline in environments where own PRS takes priority.

### Fallback Matrix (Original Developer Environment → External Environment Replacement)

| Original developer environment dependency | External user environment fallback |
|---|---|
| `memory feedback_*.md` accumulated naming/decision baseline + asset synergy branch judgment etc. (Step 2 matrix #2) | User environment's own baseline assets (`memory/` · `notes/` · `docs/` · `CLAUDE.md`) |
| `CLAUDE.md` hub identity (Step 2 matrix #1) | User environment's own `CLAUDE.md` or project README rules § |
| Accumulated naming/decision baseline adherence (Step 2 matrix #3) | User environment's own naming/decision baseline |
| `CATALOG.md` ## Plugins / ## Skills / ## Agents (Step 2 matrix #6) | User environment's own catalog or asset classification (skip if absent) |
| Option C Hybrid sync policy (Step 2 matrix #7) | User environment's own PR/direct push policy (user environment baseline adherence) |
| PR lifecycle operation proof history + accumulated self-catch (Step 2 matrix #8) | User environment's own operation proof starting at 0 instances |

### External User Usage Scenarios

1. **General PR review automation**: On user PR submission → this skill auto-activates → 5-step processing + review comment attachment
2. **User's own baseline consistency check**: Generalize 8 Step 2 matrix items to user's own environment assets
3. **Accumulate user's own self-catch count**: Starting at 0 / operation proof baseline stabilizes as count grows
4. **Same user approval gate adherence**: Review comment attachment automatic / merge authority is user's own decision

### Limitations (Explicit)

- **Accumulated naming baseline adherence materials** = original developer environment accumulated baseline / external user environments should follow their own naming/decision baseline
- **PR lifecycle operation proof materials + accumulated self-catch** = original developer environment accumulated / external user environments start own PR lifecycle + self-catch accumulation at 0 instances
- **Hub gate core essence** = cross-applicable to all user environments (baseline integrity + self-monitoring + Layer 6 bidirectional evolution circuit consistency)
- This skill = original developer environment base + external user environment fallback path coexistence baseline

## Disable Path (Own PRS Priority Environment Baseline)

Baseline for disabling this skill in environments where own PRS (pr-reviewer-self) is established. Following Scenario 3 devil-advocate consolidated one-line conclusion — avoiding *"fh-meta risks becoming a circuit that reinjects owner baseline into heavy users via self-reference"*.

### 4 Deactivation Options

| Step | Path | Essence |
|:-:|---|---|
| 1 | Frontmatter `user-invocable: false` | Skill itself deactivated (manual call only) |
| 2 | `.claude/settings.json` plugin disable | fh-meta plugin level deactivation (affects other skills too — for this skill only, recommend step 1 or 3) |
| 3 | Per-skill deactivation | `.claude/settings.json` `skills.disabled` or `.claude/disabled-skills.json` |
| 4 | Trigger avoidance | Avoid description trigger vocabulary ("Review PR" / "hub review") — use own PRS triggers first |

### Priority Resolution Baseline

When own PRS + this skill both activate simultaneously:

| Environment | Default priority |
|---|---|
| Original developer environment (forge-harness original developer) | **This skill takes priority** (hub gate baseline) |
| External user environment (own PRS established) | **Own PRS takes priority** (user environment baseline / this skill = supplementary or disabled) |
| External user environment (own PRS not established) | This skill available (user's decision) |

### Heavy User Autonomy Non-Infringement Baseline

- This skill = NOT "a stronger tool" / obligation to avoid infringing user autonomy
- Catch "owner baseline self-reference reinjecton circuit" risk (following Scenario 3 consolidated conclusion)
- → Mandatory baseline to explicitly document disable path (ensures user decision space)

## Persona Synergy Catch (Scenario 2 adherence)

### deep-insight Multi-Perspective Review ↔ This Skill Simultaneous Activation Risk

Scenario 2 persona-newcomer catch — when this skill also activates during deep-insight multi-perspective review, risk of token cost/time explosion. Two skills unaware of each other / cross-ref absent area.

### Simultaneous Activation Resolution

When deep-insight + this skill simultaneously trigger → delegate priority decision to user:
- deep-insight first (full multi-perspective review, this skill supplementary)
- or this skill first (hub review, deep-insight supplementary)
- or incompatible (run only one / follow disable path §)

### Cascade Value Areas (Synergy ★★★)

- persona-be / persona-fe → plugin-recommender (Spring / Storybook recommendation cascade)
- harvest-loop → domain persona post-processing (★★ / format conflict catch mandatory)
- deep-insight multi-perspective review → this skill **sequential** activation (not simultaneous / avoid token cost)

## User Approval Gate

| Stage | Approval |
|---|---|
| Step 1~3 check auto-activation | **Automatic** (editable afterward) |
| Step 4 review comment attachment | **Automatic** (gh pr comment within this skill's execution authority) |
| Step 5 admin override merge execution | **User decision** (this skill = recommendation only / no merge authority) |

## Constraints

- **This skill = review/recording automation / no merge authority** — user admin override or other reviewer merge decision
- **No single-person decision application** — following `fact-checker` rule (narrow 1 / broad N+1 / this cc self-catch joins fact-checker count)
- **Simplification guard consistency** (`feedback_simplification_evidence`) — when creating/modifying this skill, update SKILL.md only. No new auxiliary files
- **Markdown editing discipline mandatory** (`feedback_markdown_edit_discipline`) — Edit first. No Write
- **Frontmatter description plain text only baseline** (`feedback_skill_frontmatter_description_plain_text`) — avoid markdown bold

## Done When

```
All 5 Steps completed
+ Baseline consistency check 8-matrix results output (✅/⚠️/❌ each item)
+ Review comment attached via gh pr comment command
+ Admin override merge recommendation output (merge execution is user's decision)
+ External verification path: harvest-loop Step 3.75 Critic isolation Agent can independently judge based on above criteria (skill_quality_rubric.md verifiable criteria)
```

## References

- Rule body: `memory feedback_command_tower_gate.md` (hub gate accumulated naming baseline) + `memory feedback_qasp_to_hub_sync_protocol.md` (Option C Hybrid sync policy)
- Consistency rules: `feedback_simplification_evidence` · `feedback_markdown_edit_discipline` · `feedback_skill_frontmatter_description_plain_text` · `feedback_bidirectional_self_validation` · `feedback_reference_own_hub_assets_first`
- Sister skills: `cross-ecosystem-synergy-detection` (sister asset cluster baseline) · `verify-bidirectional` (bidirectional self-validation automation / self-catch auxiliary axis) · `harvest-loop` (weekly audit automation / operation proof accumulation cross-link)
- Autonomous commit proposal §2.19 baseline: `memory feedback_autonomous_commit_proposal.md` (① development source automation + PR proposal under human approval)
