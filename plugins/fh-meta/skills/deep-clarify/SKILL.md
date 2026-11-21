---
name: deep-clarify
description: Clarifies ambiguous requests through Socratic dialogue, drawing out goals, completion criteria, and constraints to produce a structured spec document. Pre-dispatch requirement clarification step for agent dispatch. Triggered by "I don't know what to build", "how should I approach this", "organize this for me", "clarify this", "deep-clarify".
user-invocable: true
allowed-tools: ["Read", "Write", "Bash", "Glob"]
model: sonnet
complexity_routing:
  base: sonnet
  high: opus
  escalate_when:
    - cross_project
    - high_stakes
---

# deep-clarify — Socratic Requirement Clarification

A skill that clarifies vague or open-ended requests through conversation to produce **actionable spec documents**.
An independent extension of the "direction confirmation" protocol from agent-composer Step 0-a.

## Triggers

- `/deep-clarify`
- "I don't know what to build", "How should I approach this?"
- "Organize the requirements", "Write a spec document"
- "What should I do with this?", "The direction is unclear"
- When agent-composer detects pre-dispatch clarification is needed and delegates automatically

## Core Principles

**Criteria for asking vs inferring**:
- Things only the human can know (goal, priorities, constraints, completion criteria) → ask
- Things AI can infer (implementation method, file location, technology choices) → infer and present as `(inferred: X)`
- Questions: **maximum 3 rounds, maximum 2 questions per round** — do not overuse

---

## Step 1. Request Analysis

Quickly identify the following from the user's request.

```
Clarity check:
□ Upper goal — Why (why this is wanted, what is better once it is done) — ask if unclear
□ Final state (what will be different when done?) — ask if unclear
□ Completion criteria (how will it be verified?) — ask if unclear
□ Constraints (what must not be done, what must not be touched) — ask if unclear
□ Priority (fast vs thorough, now vs later) — ask if unclear
□ Textbook phrases in the request (see below)
```

The Why is asked on its own, not folded into the Goal: when it is missing, the gaps get filled with the AI's
own defaults, and every later choice inherits them.

### Textbook phrases

A phrase that sounds like a requirement but does not say what to do — "make it scalable", "standard
architecture", "clean code", "best practice", "production-ready", "user-friendly" (examples, not a closed
list) — is **not recorded as a requirement**. Ask once what is actually needed behind it, with a concrete
guess: *"'Scalable' — for how many users or how much data, and what must not get slower? (inferred: one team,
a few hundred records)"*. This question uses one of the round's two slots. If the answer is the phrase again,
record your guess as `(inferred: …)` in the spec and list it under Open questions — do not ask a second time.

**Direct entry conditions** (skip Rounds 1–2 and go straight to Round 3):
- Request is specific and completion criteria are clear → draft the spec (Step 3's format), then run Round 3's
  understanding check; Step 3 saves the result
- Clarity at the level of "add Y feature to file X"

---

## Step 2. Socratic Dialogue

### Round 1 — Why / Completion Criteria (core 2 questions)

```
Clarification needed.

1. Why: What is this for — what will be better once it is done?
   (inferred: [inferred upper goal] — confirm if correct)

2. Completion criteria: What does a completed [task name] look like?
   (inferred: [inferred completion criteria] — confirm if correct)
```

Skip a question the request already answers. A textbook phrase (Step 1) takes the free slot here or in Round 2.

### Round 2 — Scope / Constraints / Priority (only if needed)

Skip if Round 1 resolves everything. Ask at most two of the items still open — scope, what must not be done,
priority, a textbook phrase — and infer the rest as `(inferred: X)`.

```
1. Scope: Which of [A / B / C] takes priority?
   (inferred: [inferred choice] — reason: [rationale])
2. Is there anything this task must absolutely not do?
   (or, if that is already clear: Which takes priority — fast completion vs solid design?)
```

### Round 3 — Understanding Check (always — one question, a second only on a contradiction)

Draft the spec first and show its summary, Excluded scope included. Then test understanding instead of asking
"is this right?" — agreement proves little, a choice proves more. Pick **one design option the user has not
mentioned**, one whose answer follows from the Why (for example: save to a local file vs a server database;
one shared page vs a page per user).

```
1. One choice we have not discussed: for [decision], [option A] or [option B]?
   (I expect [A], because your Why is "[Why in their words]")
2. (only if the pick contradicts the Why) You picked [B], but [B] means [consequence], and your Why was
   "[Why]". Which matters more here?
```

- Judge the fit against the Why **as the user stated it**. The reason the user gives for the pick ("less
  hassle") is not part of the Why unless they say so; if the pick's consequence works against the stated Why
  (it may miss what they said they need to find), that is a contradiction even when the reason sounds fair.
- The pick fits the Why → understanding confirmed; record it in `## Understanding check`.
- It contradicts the Why → ask question 2 (the same round, so the 3-round · 2-question cap holds). Update the
  Why or the spec from the answer.
- Still contradictory after question 2 → stop asking: write the conflict under Open questions in the spec and
  end. Do not open a fourth round.

---

## Step 3. Generate Spec Document

Structure and save the results of the conversation. **This step writes a file** — outputting the
path is not saving it.

1. Derive the slug: `slug = kebab-case(spec title) + "-" + YYYYMMDD`
   (lowercase, non-alphanumerics → `-`, collapse repeats, strip leading/trailing `-`).
   Example: "Rewrite the login flow" on 2026-08-11 → `rewrite-the-login-flow-20260811`.
2. If `specs/{slug}.md` **already exists → ABORT** and report the existing path.
   Never overwrite and never silently suffix — an existing spec is a prior decision to extend or
   supersede, and that is the user's call.
3. Create the directory, then write the file with the **Write** tool (not a shell redirect):

```bash
mkdir -p specs
```

Then `Write` → `specs/{slug}.md` with the format below, and verify:

```bash
test -f specs/{slug}.md && echo "SPEC SAVED: specs/{slug}.md"
```

**Where**: `specs/` in the work folder, not under `.claude/` — Claude Code asks before writing there, so a
headless run is refused and an interactive user gets a «modify sensitive file» prompt. A spec an earlier
version saved under `.claude/specs/` stays where it is.

**Residency**: the spec records the user's goals, constraints, and "must not touch" list.
`specs/` is gitignored in this repo; **in a company project, confirm the path is gitignored
there too before writing** — if it is not, write to a gitignored location instead.

### Spec Document Format

```markdown
# Spec: {task title}
Created: {date} | Status: draft

## Goal
{One sentence — what is being built}

## Why
{The upper goal in the user's words — why it is wanted, what is better once it is done}

## Completion Criteria
- [ ] {verifiable condition 1}
- [ ] {verifiable condition 2}

## Scope
Included: {what is explicitly included}
Excluded: {what is explicitly excluded}

## Constraints
- {technical constraint}
- {what must not be done}

## Priority
{Fast completion / Solid design / Balanced} — {reason}

## Understanding check
Option offered: {the choice not discussed before} · Picked: {answer} · Fits the Why: {yes / re-asked → yes / no — see Open questions}

## Open questions
{conflicts left after Round 3, textbook phrases the user did not unpack — or "none"}

## References
{related files / existing skills / prerequisite work}
```

---

## Step 4. Follow-up Connections

After generating the spec document, suggest the appropriate next path. The first row is the default:

| Situation | Connected skill |
|---|---|
| **Default** — implementation | Open a new session that reads only the saved spec (`specs/{slug}.md`) and implement there. The guesses this interview corrected stay in this window and would otherwise pull the implementation back toward them |
| Agent orchestration needed for implementation | `agent-composer` — pass spec document path (it, too, should read the spec, not this conversation) |
| Plan / design review needed | built-in `Plan` agent — build plan based on spec |
| Single task is now clear and the user wants to stay here | Start implementation directly (not the default — offer it when the user asks) |
| Audit needed before external sharing | `hub-persona-auditor` |

---

## Done When

| Condition | Completion verdict | Check class |
|---|---|---|
| Socratic dialogue complete (≤3 rounds, ≤2 questions/round) | ✅ Clarification complete | **mandatory-pass** |
| `test -f specs/{slug}.md` exits 0 — the file **exists on disk** | ✅ Save complete | **mandatory-pass** (a printed path is not a saved file) |
| The spec's `## Why` and `## Understanding check` are filled — the option offered, the pick, and whether it fits the Why (a contradiction left open is listed under Open questions) | ✅ Understanding tested | **mandatory-pass** (an empty or "n/a" Understanding check fails) |
| The spec's Completion Criteria are independently verifiable — someone other than the author could tell whether each is met | ✅ Spec actionable | **judged** — adversarial pairing: `fh-meta:beginner` cold-reads the spec and attempts to state, per criterion, how they would check it; a criterion they cannot operationalize fails |
| Follow-up skill connection suggestion output | ✅ Handoff complete | **mandatory-pass** |

**This skill's Done When = "actionable spec document saved".** Implementation itself is the domain of follow-up agents/skills.
