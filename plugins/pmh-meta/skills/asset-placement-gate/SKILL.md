---
name: asset-placement-gate
description: Routes a proposed skill, plugin, or agent to its correct home — forge-harness (FH) meta-skill, project-local agent, or drop — by applying a 4-criteria meta-skill bar followed by a project-local value test.
user-invocable: true
allowed-tools: ["Read", "Grep", "Glob"]
model: sonnet
---

# asset-placement-gate

Routes new skills, agents, and plugins to the correct location when proposed.

## Triggers
- "Should I make this an FH skill?"
- "Where should I put this agent?"
- When a new FH asset creation is proposed
- `/asset-placement-gate {asset name or description}`

### Natural Language Triggers (example user phrases)

When unsure where to place a new asset or skill:

| Example phrase | Intent |
|---|---|
| "Should I put this in a separate file?" | Asset necessity + placement decision |
| "Can this pattern be shared across projects?" | FH cross-project value assessment |
| "Is this only for our project, or can others use it too?" | cross-project vs local routing |
| "What if I turn this into a skill and use it across projects?" | FH 4-criteria trigger |
| "Where should I put this agent if I want to share it?" | Placement routing needed |
| "Should I extract this to a separate file, or leave it?" | Asset necessity + placement decision |
| "I'd like to manage this as a shared resource" | Cross-project shared management review |
| "Decide whether this stays local or is available to other teams too" | cross-project vs local routing |
| "I don't know where to save this" | Placement routing needed |
| "Should this become a shared asset?" | FH 4-criteria trigger |

### Execution Order (summary)

1. Request full file path from user (or accept natural language description)
2. Load asset content via `Read` (if path provided)
3. Evaluate Step 1 4-criteria in order (LLM makes the judgment directly)
4. ① + ④ both pass + at least one of ②③ passes → output **"FH suitable"**
   Otherwise, proceed to Step 2 local assessment → if fails, output **"Project-local agent or no asset needed"**

---

## Step 0. Parse Input + Fetch Asset

Immediately after trigger, acquire asset content in the following order.

1. **Path provided** (contains `.md` or starts with `/`): Read the file.
   - If read fails: "File not found. Please verify the path or provide a direct description." — then stop.
2. **Description provided** (natural language): Check whether all 3 fields can be identified:
   - **Purpose**: What this asset does (1 line)
   - **Trigger**: In what situation is it invoked?
   - **Expected callers**: Which project / which users will use it?

   All 3 identifiable → use as asset description.
   Any 1 unclear → stop with this question:
   > **The asset description is insufficient. Please provide:**
   > 1. Purpose of this asset (one line)
   > 2. In what situation is it invoked?
   > 3. Which project/users will primarily use it?
3. **No input**: Stop with the question below.
   > **Which asset should I evaluate?**
   > Enter a file path (e.g., `.claude/agents/jira-create.md`) or a description.

After acquiring the asset content, **Claude directly** applies Step 1 4-criteria (no external calls).

## Done When

```
All steps 0–3 completed
+ Step 3 routing result output (location: FH meta-skill / local agent / drop)
+ Next action specified (write SKILL.md / create .claude/agents/ / none)
```

---

## Step 1. FH Meta-Skill 4-Criteria Evaluation

| # | Criterion | Evaluation Question |
|:-:|---|---|
| ① | Cross-project value | Is this asset equally useful in other projects without depending on a specific project? |
| ② | Orchestration / judgment layer | Is it just a list of MCP/Bash calls, or a judgment layer that synthesizes multiple signals? |
| ③ | Not replaceable by built-ins | Can this be equally achieved with direct MCP calls or basic bash? (If yes, fails this criterion) |
| ④ | No overlap with existing FH skills | Does it not overlap 90%+ with existing FH skills? |

**FH suitable** → ① + ④ both pass + at least one of ②③ passes.
**Fail** → ① or ④ fails → immediate fail. Or both ②③ fail → proceed to Step 2.

---

## Step 2. Project-Local Agent Value Assessment

For assets that failed Step 1:

| # | Criterion | Evaluation Question |
|:-:|---|---|
| A | Project-specific knowledge | Does it encode paths, conventions, or domain rules specific to a project? |
| B | Repeated workflow pattern | Is it a workflow performed repeatedly within that project? |
| C | Differentiation from built-ins | Does it provide local-context-based convenience such as automatic convention application or step integration? |

**Local agent suitable** → A satisfied + at least one of B·C.
→ Recommend creating `{project}/.claude/agents/{name}.md`.

**Drop** → A not satisfied or both B·C not satisfied.
→ Equivalent to built-in capability. No asset needed.

---

## Step 3. Routing Result Output

```
[asset-placement-gate verdict]

Asset: {asset name}
Description: {one-line summary}

── FH 4-criteria ──────────────────
① Cross-project value     : O / X
② Orchestration/judgment  : O / X
③ Not replaceable         : O / X
④ No overlap with existing : O / X  ← required gate with ① (immediate fail if either fails)
→ FH suitable: Pass / Fail  (① + ④ required + at least one of ②③)

── Project-local assessment ──────  (if FH failed)
A. Project-specific knowledge : O / X
B. Repeated workflow pattern  : O / X
C. Differentiation from built-ins : O / X
→ Local agent: Suitable / Drop

── Conclusion ────────────────────
Location: [FH meta-skill | {project} local agent | Drop]
Next action: [Write SKILL.md | Create .claude/agents/ | None]
```
