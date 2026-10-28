# The conditional dispatch prohibition — what it actually is

> Detail file for `CLAUDE.md §Agent Dispatch Operation`. The resident summary carries the
> **behavioural rule**; this file carries the **measurement** behind it. Read this before citing any
> number here, before claiming the line is absent from a surface, and before re-running the probe.

## The two lines

Some runtimes ship these as a default addition to the session prompt:

```
Do not call the AgentTool unless the user requested it
Do not use workflows or deep-research unless the user requested it
```

## What was measured

**Scope of the measurement — state it before the numbers.** n=1 machine · macOS · install path
`~/.local/share/claude/versions/` · CLI versions 2.1.223–226, all four identical. Nothing here is a
claim about other platforms, other install paths, or later versions. Re-run before citing elsewhere.

```
occurrences of each line          3
CONTROL     "AgentTool"          37     ← instrument alive on this target
NEG-CONTROL "zzz_known_negative" 0      ← instrument not hallucinating hits
```

An unqualified `grep -c` (without `-a`) returns **empty** on this binary — it dies silently. That is
exactly the instrument death the control pair exists to catch; a bare `0` from it would have read as
a measurement.

### Resolution order — it is a fallback, not a constant

```js
function JWb(e){
  let t = wk()?.tengu_heron_brook;        // ① client-data string  → returned if non-empty
  if (typeof t === "string" && t.trim() !== "") return t.trim();
  let r = nt("tengu_heron_brook","");     // ② remote flag string  → returned if non-empty
  if (r.trim() !== "") return r.trim();
  if (Hbo(e)) return H3p;                 // ③ the two lines — only if the gate below passes
  return null;
}
function Hbo(e){
  if (e === void 0) return false;
  if (lB(Eo(e), "opus_5_prompt_bundle") !== true) return false;   // model-bundle gate
  return !nt(VE_, false);                                          // VE_ = "tengu_fennel_godwit"
}
```

Three consequences:

1. **Not hard-coded.** It is the third branch of a three-tier resolution — ① and ② replace it
   wholesale, and a remote kill-switch disables it.
2. **Not global — model-scoped.** It attaches only under `opus_5_prompt_bundle`. A session on another
   bundle never receives it. **Do not reason about this line without knowing which bundle you are on.**
3. **Genuinely conditional.** All 3 occurrences of each prefix carry `unless the user requested it`;
   no unconditional variant exists (checked with a live negative control on the phrasing regex).

### Where the text is *not* — two rows, kept apart on purpose

Merging these is the `not-found ≠ zero` defect this repo keeps naming
([[feedback_not_found_is_not_zero_family]]).

| Row | Targets |
|---|---|
| **MEASURED ZERO** — target exists, grep calibrated on that target | user + project `settings.json` · project `settings.local.json` · `~/.claude.json` · `~/.claude/plugins/**` · both launcher app bundles |
| **LAYER ABSENT** — nothing to search; silence, not a zero | user `settings.local.json` · `.claude/agents/**` (user and project) · output-styles (user and project) |

**INFERENCE, not measurement**: *"so it cannot be turned off from config."* Only the
**operator-facing** config layers were searched **for the text**. Branch ② above shows a *remote*
flag does control it. The honest statement is: the text is not in operator config, and no
operator-config key is known to gate it.

## Reproduction

```bash
cd ~/.local/share/claude/versions
V=2.1.226            # 실제 설치 버전으로 교체
grep -a -o "Do not call the AgentTool unless the user requested it" "$V" | wc -l   # 3
grep -a -o "AgentTool"               "$V" | wc -l                                  # 37  CONTROL
grep -a -o "zzz_known_negative_zzz"  "$V" | wc -l                                  # 0   NEG-CONTROL
off=$(grep -abo 'if(Hbo(e))return' "$V" | head -1 | cut -d: -f1)
dd if="$V" bs=1 skip=$((off-900)) count=1500 2>/dev/null | tr -d '\0'               # JWb
off=$(grep -abo 'function Hbo(' "$V" | head -1 | cut -d: -f1)
dd if="$V" bs=1 skip=$off count=420 2>/dev/null | tr -d '\0'                        # Hbo
```

## Two retractions this file exists to record

- **"A system prompt outranks both, by construction, so opening is impossible."** Right rule, wrong
  sentence. An *absolute* prohibition cannot be reopened from a lower layer; a *conditional* one is
  opened by its condition becoming true. Check whether the sentence is unconditional **before**
  reaching for the precedence rule.
- **"Reading the call site needs binary inspection, which was blocked."** False. Three plain `grep`
  calls resolved it; an adversarial reviewer demonstrated that by simply running them. One earlier
  attempt using a different tool had been denied, and that denial was generalised into *"this is
  unmeasurable"* — the same shape as [[feedback_impossible_verdict_may_be_unread_half]]. **A blocked
  tool is not a blocked question.** The honest label is *"not yet measured."*

## Named residuals

- The measurement is n=1 machine. Platform and install-path variance unmeasured.
- Whether any **operator-config** key gates the constant is unmeasured; only text-absence was checked.
- What ① (client-data) actually carries in this environment was not inspected — only that it takes
  precedence.

---

## §Hook-Floor-Unverified — 「어느 방향도 훅으로 안 막힌다」의 실측 근거

> CLAUDE.md §Agent Dispatch 는 결론 한 줄만 상주로 갖는다. 아래가 그 근거·미검증 항목이다.
> salience-split 2026-08-21.

⚠️ **Neither direction has a confirmed hook-level floor. Say that plainly rather than implying one.**
```
opening    salience only for the POSTURE. The prohibition met in the field is CONDITIONAL,
           which changes what "override" even means — see the measured block below.
blocking   ALSO not hook-enforced. `SubagentStart` fires on spawn but is **context-only** —
           it cannot block, exit 2 only surfaces stderr, and it has no decision field
           (official hooks reference, read 2026-08-08). It can INJECT context at the moment
           of dispatch, which is better-placed salience than this file, but still salience.
UNVERIFIED whether a `permissions` deny entry or a `PreToolUse` matcher can target subagent
           spawning at all — the reference does not name a tool for it, and this repo has no
           precedent. **Do not cite a blocking mechanism until someone runs the known pair**
           (configure the deny, attempt a dispatch, observe). Until then: unverified, not absent.
```

## §Retraction-SubagentStart — 이 블록이 두 번 틀렸던 기록

An earlier draft of this very block asserted "a `SubagentStart` hook can deny, and a denial there is a
real floor." That was false, taken on trust from an adjacent session and written here before the
reference was read. A second draft, on 2026-08-09, then wrote that the constant's call site "needs
binary inspection, which was blocked" — **also false**: three plain `grep` calls resolved it, and an
adversarial reviewer demonstrated that by doing it. Declaring something unmeasurable before trying the
cheap tool is [[feedback_impossible_verdict_may_be_unread_half]]; the honest label is *"not yet
measured,"* never *"blocked."* A blind target-tier sim then read it back correctly — which shows a sim measures
whether text is *followable*, never whether it is *true*. Both checks are needed; neither substitutes.


## §Worktree-Gate-Integrity — `core.hooksPath` 양팔 실측 (2026-08-05)

> 🟥 **운영 규칙은 CLAUDE.md 에 있다**: *워크트리에서 FH 자산을 커밋하지 않는다.*
> 아래는 그 규칙이 왜 조건부 사실 위에 서 있는지의 근거이고, **규칙을 실행하는 데는 필요 없다** —
> 「내 설치가 어느 팔인가」를 따져야 할 때만 읽어라. salience-split 2026-08-21.

**Fourth reason — gate-integrity in a worktree, and the answer is CONDITIONAL on how `core.hooksPath`
was set (measured 2026-08-05, both arms).** Do not carry a single verdict here; the two installs
behave differently:

| `core.hooksPath` | Which hook actually runs in a worktree | Consequence |
|---|---|---|
| **relative** — `templates/.git-hooks`, the form every FH doc installs (`CHEATSHEET.md`, `.claude/rules/fh_4axis_gate.md`, `install-wizard`, `self_evolution_routine.md`) | the **worktree's own copy** | Editing that copy *inside the worktree* disables the gate for that worktree — measured: neutralized hook → FH-asset commit with no marker succeeded (`rc=0`). The verifier becomes the verified, and the edit is invisible to `git status` in the main tree. |
| **absolute** — a hand-set full path (this operator's machine; **not** what any doc tells you to run) | the **main tree's copy** | A worktree-local edit has no effect; a known-positive is blocked there exactly as in the main tree (`rc=1`). |

An earlier draft of this section reported only the absolute-path arm and declared the
"worktree bypasses the gates" hypothesis *refuted* — from **n=1 on a non-canonical setting**, with a
do-not-revisit label attached. The relative-path arm, which is what everyone else runs, reproduces
the bypass. Freezing a conclusion is a defect when the measurement did not cover the shipped
configuration.

🟥 **RETRACTED 2026-08-22.** This said the marker and manifest are *structurally absent* in a
worktree. They are not: `templates/.git-hooks/pre-commit` resolves evidence through
`git rev-parse --git-common-dir`, which returns the **main tree's** `.git` from inside a worktree.
Measured in a clean worktree with the known-negative established first (its own `tracks/` = skeleton
only; `$REPO_ROOT/tracks/_meta/edit_manifest.yaml` NOT FOUND, `$EVIDENCE_ROOT/...` FOUND — the two
roots disagree, so the probe discriminates).
**The operating rule is UNCHANGED: do not commit FH assets from a worktree.** Its remaining **open risk areas** — not
established grounds — are marker provenance, concurrent manifest append, and a copy of `tracks/` that
appears in a worktree from an unattributed source. They are **deliberately not enumerated as reasons
here**; an earlier draft enumerated
them and adversarial review found a defect in nearly every added claim. ⚠️ **Reachable is not automatic**: the hook *reads* `$EVIDENCE_ROOT`, but a
worktree session writing by relative path lands in the worktree's own `tracks/`, not the main tree's.
The gate is satisfiable — its failure message prints the absolute `MARKER_DIR` to write to — but the
routing is the author's job, not the tool's.
⚠️ The `core.hooksPath` two-arm table above is a separate axis (hook substitution) and is untouched.
One observation from the retracted paragraph survives on its own: note the
hook itself prints `mkdir -p …/tracks/_meta` on that failure, i.e. the actor's own error message
teaches the marker-creation path — so "just don't fabricate it" is prose sitting under a machine
instruction pointing the other way.

---

## §CM-Posture-Not-Guarantee — «Default-active» is a posture — the 2026-08-08 case (moved from CLAUDE.md)

> Relocated **verbatim** from `CLAUDE.md` (§Agent Dispatch Operation) on 2026-09-26 — resident-size diet. The resident text kept the rule and a pointer here; this section keeps the why / evidence layer. Nothing was reworded.

So "default-active" is a **posture, not a guarantee**. Measured 2026-08-08: a session running under
exactly that system-prompt instruction worked alone for a full session and dispatched only at the two
points where the operator named it — while this file said dispatch was available. A session that
*cannot* dispatch must **say so** rather than quietly doing everything inline; the silent version is
what made that case invisible until the operator asked. Writing "default is active" into a remote
canon without this paragraph produces the next session that reads it and still cannot comply.

This is why the answer
belongs at setup — that is the one moment where the
choice is cheap to make, and a durable record is the whole point: a *yes* left in a transcript expires
with the transcript, while the conditional line above is re-evaluated by every cold session.


---

## §CM-Lease-Unwired — The lease check is built but unwired (moved from CLAUDE.md)

> Relocated **verbatim** from `CLAUDE.md` (§Agent Dispatch Operation) on 2026-09-26 — resident-size diet. The resident text kept the rule and a pointer here; this section keeps the why / evidence layer. Nothing was reworded.

The lease is the
only part that decays on its own — **and nothing reads it**. Correcting a wrong reason given earlier
in this branch: that gap is *not* "below the mechanization threshold, so don't build it."
`scripts/consent_registry_check.sh` already enforces leases (requires `expires`, rejects past dates,
caps at 365 days) and is lane-tested. It is **unwired here**, which is a different defect with a
different fix, and "don't build" was covering for it. Wiring it is a real decision, not a chore:
the registry's own floor forbids `promotion_eligible: true` for a class whose effects feed
irreversible sinks, and a dispatched subagent does — so registering this grant would either be
rejected by that floor or require declaring it something the registry does not govern. That is the
operator's call, and until it is made the lease is **honoured by reading, not by machinery**.

### ➕ 추가 (2026-09-30) — 배선을 미루는 비용에 외부 수치가 붙었다 (append-only — 위 이관 원문은 안 고친다)

위 문단은 리스가 «읽혀서 지켜지지, 기계로 지켜지지 않는다» 고 적는다. 그 미룸이 무엇을 열어
두는지에 대해 외부 수치가 하나 생겼다.

- 출처: `arXiv:2609.33910` *Residual Authority Replay* (`tracks/_meta/frontier_digest_2026_09_30.md`
  하이라이트 2 — 로컬 다이제스트, gitignored). 오래 사는 에이전트는 과제·세션을 넘어 승인을 이어 쓴다. 공격자는 무해한
  상호작용으로 권한을 정당하게 얻게 만든 뒤, 나중에 그 **잔여 권한을 재생**한다. 실제 코딩
  에이전트 3종의 Terminal-Bench 55 사례에서 공격 성공률이 평균 **+24.9%p** 올랐다(AgentDojo 508
  사례에서는 최대 +35.1%p).
- 🟥 **인용 경계**: ① **초록만 읽었다** — 본문·표·위협 모형은 확인하지 않았다. ② 이 수치는 **그
  논문의 공격 설정**에서의 상승폭이다 — FH 의 리스가 재생 공격을 받는다는 측정이 아니고 FH 에서
  잰 값도 아니다. ③ +24.9%p(실제 코딩 에이전트 · 평균)와 +35.1%p(AgentDojo · 최대)는 **다른
  벤치·다른 집계**다 — 섞거나 한쪽을 다른 쪽 이름으로 인용하지 마라.
- **어디에 맞닿나**: FH 의 동의 기록은 이미 좁다 — 로컬 바인딩의 위임 기록들은 «이번 야간 1회
  한정» · «이 PR 한정» 처럼 리스를 과제에 건다. 이 논문은 그 규율이 **옳은 방향**이라는 외부
  신호다. 남은 틈은 규율이 아니라 기계다: 리스가 끝나도 그걸 읽는 것은 세션의 독해뿐이라,
  «정당화한 맥락은 끝났는데 권한은 남는» 논문의 실패 모양을 **FH 에서 기계로 막는 자리가 없다**
  (디스패치 리스에 대해 — `consent_registry_check.sh` 자체는 `fh_node_check.sh` 가 다른 한 부류
  `repo-freshness-autopull` 에 대해 부른다. «아무 데도 안 불린다» 로 읽지 마라).
- **그 스크립트가 이미 가진 것과 안 가진 것**(헤더 직독, 2026-09-30): R5 가 `expires` 부재·경과를
  거절하고, R6 이 grant 마다 `owner`·`mode`·`effects`·`target`·`sinks` 지문을 기록하게 한다 —
  논문의 «맥락 결박» 에 가장 가까운 칸이다. 🟥 그러나 헤더가 스스로 적듯 **실시간 행동을 그
  지문과 대조하지는 않는다**(«this script never sees the live action»). 즉 배선해도 닫히는 것은
  «만료된 리스» 까지이고, «기한 안에서 다른 과제로 재생된 권한» 은 여전히 런타임 의무(산문)다.
  리스의 «기한» 은 시간으로 자르고 논문의 결박은 **과제**로 자른다 — 같은 축이 아니다.
- 🟥 **배선 여부는 여전히 운영자 결정이다.** 이 추가는 결정을 바꾸지 않는다 — 위 문단이 적은
  막힘(레지스트리 바닥이 비가역 싱크를 먹이는 부류의 승격을 금한다)은 그대로다. 바뀐 것은 «미루면
  무엇이 열려 있나» 의 서술이 외부 수치 하나를 갖게 된 것뿐이다.


---

## §CM-Worktree-Retraction — Worktree evidence is reachable — the 2026-08-22 retraction (moved from CLAUDE.md)

> Relocated **verbatim** from `CLAUDE.md` (§Agent Dispatch Operation) on 2026-09-26 — resident-size diet. The resident text kept the rule and a pointer here; this section keeps the why / evidence layer. Nothing was reworded.

🟥 **RETRACTED 2026-08-22.** This said the marker and manifest are *structurally absent* in a
worktree. They are not: `templates/.git-hooks/pre-commit` resolves evidence through
`git rev-parse --git-common-dir`, which returns the **main tree's** `.git` from inside a worktree.
Measured in a clean worktree with the known-negative established first (its own `tracks/` = skeleton
only; `$REPO_ROOT/tracks/_meta/edit_manifest.yaml` NOT FOUND, `$EVIDENCE_ROOT/...` FOUND — the two
roots disagree, so the probe discriminates).
**The operating rule is UNCHANGED: do not commit FH assets from a worktree.** Its remaining **open risk areas** — not
established grounds — are marker provenance, concurrent manifest append, and a copy of `tracks/` that
appears in a worktree from an unattributed source. They are **deliberately not enumerated as reasons
here**; an earlier draft enumerated
them and adversarial review found a defect in nearly every added claim. ⚠️ **Reachable is not automatic**: the hook *reads* `$EVIDENCE_ROOT`, but a
worktree session writing by relative path lands in the worktree's own `tracks/`, not the main tree's.
The gate is satisfiable — its failure message prints the absolute `MARKER_DIR` to write to — but the
routing is the author's job, not the tool's.

(measured 2026-08-05: marker-less FH-asset commit
succeeded)


---

## §CM-Worktree-Detection — Worktree location is detectable — why it is not yet mechanized (moved from CLAUDE.md)

> Relocated **verbatim** from `CLAUDE.md` (§Agent Dispatch Operation) on 2026-09-26 — resident-size diet. The resident text kept the rule and a pointer here; this section keeps the why / evidence layer. Nothing was reworded.

**Do not let that unenforceability launder the enforceable part** (caught by an adversarial round on
the paragraph above, which had used it to do exactly that): *being in a worktree* is trivially
detectable — `git rev-parse --git-common-dir` differs from `--git-dir` there and matches in the main
tree — and `templates/.git-hooks/pre-commit` currently has **zero** lines of worktree detection. A
true statement about one thing (provenance) was standing in for an untested claim about another
(location). It is left un-mechanized for a *scope* reason, not an impossibility one: measured
recurrence is 1, below this repo's own N≥3 mechanization threshold. If it recurs, the check is a
two-line hook addition, not a research problem.


---

## §CM-Invocation-Log-Origin — Why the invocation log needed a floor (moved from CLAUDE.md)

> Relocated **verbatim** from `CLAUDE.md` (§Agent Dispatch Operation) on 2026-09-26 — resident-size diet. The resident text kept the rule and a pointer here; this section keeps the why / evidence layer. Nothing was reworded.

**Why it needed a floor**: this line was prose-only and a single
session dispatched 20+ subagents and logged none of them, in the same session that recovered this very
log file from a branch queued for deletion. The hook only tallies; it never writes an entry, because a
fabricated `outcome`/`evidence` would poison the promotion gate worse than a missing one.


## §Edit-Handback-Receipt — an agent's «I changed X» is closed by the governor's own receipt (2026-10-20)

CLAUDE.md §Agent Dispatch says a sidecar's findings stay evidence until the governor closes each against a mechanical anchor.
For **edit work** (an agent that commits on a branch or in a worktree) there was no anchor, so the close step read the agent's
own summary («committed 7f2acd2, 11 files, tests green»). Before calling dispatched edit work done, run
`python3 scripts/dispatch_receipt.py <worktree> <base> --claimed <the files the agent named>` from the governor's shell and
quote its output: head sha, branch, commits, `diff --stat`, uncommitted count and a hash per changed file are what the
repository says. rc=1 means the claim and the change differ (named both ways) or the work is not committed — read it as
«not closed», never as a small discrepancy. «0 files» with a non-empty claim is rc=1, not a pass. The receipt says what
changed, not whether it is right: tests and review still decide that. Outside anchors: `arXiv:2610.15459`, «report ≠
change» (frontier digest 2026-10-20). Lanes: `scripts/test_dispatch_receipt_lanes.sh` (wired in selfcheck).

## §Two-Purposes — a dispatch serves independence, permission or context, and only context can be folded (2026-10-27)

Anthropic's «Building agents: When to fold subagents into your main agent loop» (claude.com, 2026-10-22,
https://claude.com/blog/building-agents-when-to-fold-subagents-into-your-main-agent-loop) reports that a
single loop with skills and progressive disclosure often beat a subagent design on quality, cost and
latency across customer deployments, and keeps subagents for three cases: measured context bloat,
fresh-context parallel or throwaway work, and tool-selection failure or conflicting instructions. It warns
against one subagent per team (the org chart as architecture), and reports a fold that cut latency but
flipped a passing task in one of two runs — so it asks for repeated runs and a per-task flip check.
No scores are published; it is a vendor's account of customer cases and the balance may move with the model.

The article also says subagents are effective at «verification, parallel work, and modular permissioning»,
and names black-box verification and a generator-verifier pattern as split candidates — work that needs
little information from the rest of the system. What it does not explicitly establish is FH's stronger
requirement: **the reader must not be the author.** That requirement is why FH dispatches most often, so it
is written down here rather than inferred. FH sends work out for three purposes, and the fold advice
applies to only one:

| purpose | examples here | fold into the main loop? |
|---|---|---|
| **independence** — evidence from a reader who is not the author | blind evaluation · cross-review · a known-pair sim · a verifier that must not see the governor's conclusion | **never** |
| **permission** — a narrower authority boundary than the governor's | a read-only auditor · a sidecar that must not write the target tree | **never while the boundary matters** — folding hands the work the governor's write access |
| **context** — keep the main window small or run work in parallel | context-flooding search · parallel builders · throwaway exploration | **only after a measured fold** — repeated runs with a per-task flip check show no loss, and no independence or permission need applies |

How to apply:
- **The test is functional, not the label.** If the dispatch is asked to *judge* work the governor (or an
  agent it directed) produced — a review, a second opinion, a pass/fail verdict, a blind score — it is
  **independence**, whatever else it also does and whatever the card calls it. Calling a second-pass checker
  «fresh-context exploration» does not make it foldable. Not independence: fetching facts the governor will
  judge with (docs, a grep sweep, a list of call sites), and a builder running its own tests — those report,
  they do not judge, and stay **context**.
- **Purposes can coexist; the strictest wins.** A blind evaluator that also reads a large corpus serves
  independence and context at once — keep it one dispatch and do not fold it. Precedence:
  independence > permission > context.
- Name the purpose(s) in the Context Card's first line («purpose: independence — …»).
- Do not cite the article as grounds to fold a reviewer, a blind sim or a cross-family check. Its fold
  advice compares task quality, cost and latency; its own text keeps verification as a split candidate.
- Tool-count side note from the same article: «once you exceed 30-50 tool definitions in the system
  prompt, tool choice tends to degrade», with grouping by user intent as the remedy. The quantity is tool
  definitions **loaded into the prompt** (deferred tools not yet loaded do not count) — not installed skills
  or MCP inventory. FH's loaded count per session is `UNMEASURED`, not «fine».
  **Measured 2026-10-28** (one headless session in the hub, the `init` event's lists; one machine, one config —
  a reading, not a distribution): tools **available** 112 = 29 built-in + 83 MCP (two desktop/browser
  automation servers alone carry 64), skills 82 (FH plugins 41), agents 19 (FH 14). FH itself adds **0 tool
  definitions** — its weight is skill and agent descriptions, which the quote does not count. How many of the
  112 are **loaded** depends on the runtime's deferred-tool loading and is still not read from this event —
  so whether any session crosses the quoted threshold stays `UNMEASURED`; what is measured is that the extra
  *available* definitions come from the operator's MCP servers, not from FH. Re-measure with
  `claude -p … --output-format stream-json --verbose` and read the `init` line.
  **The cost FH does add is resident text, not tools — measured 2026-10-28** (same one-word task, haiku, 3 runs per
  arm, first assistant message `usage` = input + cache-create + cache-read): an empty folder 35,770–37,675 tokens, the
  FH hub as the author's checkout 100,307–100,563 — **+62,600 to +64,800 tokens (2.7–2.8×) on the first call in these six runs**, before any
  work. The contrast is the whole project configuration, not separate components; what differs is CLAUDE.md (16.5k chars), CLAUDE.local.md (47.3k chars, mostly expired one-time lease blocks),
  the project memory index (19.4k chars) and the session-start hook output — an npm install carries neither CLAUDE.local.md nor this memory index, so read this as the author's configuration, not an install's cost. User-level plugins and MCP load in both
  arms, so their share is `UNMEASURED` here. Related outside evidence: fixed context at the first call was where a
  cost spread of up to 3× between harnesses began, with no consistent accuracy advantage (arXiv:2610.04433 — digest summary, paper not opened). Tokens
  are not cost (cache reads and writes bill differently). Shrinking resident text is a candidate lever; its saving is
  established only by the same two-arm run after a diet.
