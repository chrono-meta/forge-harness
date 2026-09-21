#!/usr/bin/env bash
# outbound_pr_gate.sh — PreToolUse(Bash): a PR about to be OPENED on a repo we do not own.
#
# THE DEFECT (measured, outbound corpus to non-owned repos, 2026-06-20..09-18)
#   Counted by outcome: 4 merged · 1 declined-on-SCOPE (we were right — no defect to fix) ·
#   1 closed-on-DEFECT · 2 CHANGES_REQUESTED · 1 awaiting. THREE carry a technical-defect
#   finding, and all three are ONE shape: our guard and our test ran on OUR MODEL of the target,
#   and the maintainer's evidence was an execution we had never run.
#     tt-a1i/archify#328          a pre-write source-hash check "cannot catch damage caused by
#                                 the write itself" (destination symlinked to the input).
#     clawd-on-desk#1025          the test asserted attribute removal and then called the
#                                 next-stage handler SYNCHRONOUSLY, so the IPC round-trip that IS
#                                 the regression window did not exist in the test at all.
#     clawd-on-desk#1021          "every exception fixture contains only one effective
#                                 destructive decision, so they cannot detect this composition
#                                 failure" — the maintainer's own words for why our suite was
#                                 green while 13 of 16 composed commands auto-allowed.
#   All three were submitted after a STATIC read of the target.
#   `[[feedback_fixture_shape_from_artifact_not_mental_model]]` (N>=6 across repos/languages).
#
# WHY A HOOK AND NOT PROSE
#   CLAUDE.md §Skeleton-Not-Muscle already scopes "code contributed upstream to someone else's
#   repo", and §7's `standpoint:` enum already has the rung that separates the two outcomes
#   (#888 merged exactly-as-submitted ran the consumer path; #1025 read it). The rule exists and
#   was NOT wired. Measured precedent for why prose is not the fix: the same rule as a CLAUDE.md
#   table row fired 1/15 at floor tier; as a PreToolUse hook, 9/9 (proposal_hook r3/r4).
#
# WHY *THIS* SURFACE AND NOT pre-commit
#   An outbound PR is authored in the TARGET's clone and committed under the TARGET's hooks.
#   forge-harness' pre-commit/pre-push are structurally not on that path — no FH commit occurs.
#   `gh pr create` IS the outbound executor, and PreToolUse is the only place that sits on it
#   ([[feedback_instrument_not_on_the_path]], same reasoning as outbound_query_hook's).
#
# DEGRADE DIRECTION — split by what we could ESTABLISH, and the split is the design
#   target positively NON-OWNED  -> DENY (exit 2). Opening a PR on a stranger's repo is
#                                  publish-class: CLAUDE.md §Autonomous-Initiative already lists
#                                  "opening/updating a PR" as publish intent, and
#                                  §Irreversibility Gates says that surface fails CLOSED.
#   target positively OWNED      -> silent. FH's own PRs must never be touched; a gate that
#                                  blocks every internal PR is a bypass trainer.
#   applicability UNDETERMINED   -> ADVISORY, never deny. We have not established that we are on
#                                  the protected surface at all, and denying here would block
#                                  every bare `gh pr create`. NAMED RECALL RESIDUAL: an external
#                                  PR opened from an already-`cd`-ed shell with no -R and no cwd
#                                  in the payload gets an advisory that arrives on the next turn,
#                                  i.e. after the PR is open. That residue is swept post-hoc by
#                                  session_close_check.sh ①-b (cross-repo + reviewDecision).
#   instrument incomplete on a
#   NON-OWNED target             -> DENY. NOT SCANNED is not clean.
#   not an FH checkout           -> silent (mechanical: is the tracked anchor file here?).
#
# WHAT IT CHECKS — the RECORD's shape, never the claim's truth (§Mechanization Boundary)
#   A record file  tracks/_meta/outbound_pr_<TODAY>_<slug>.md  carrying three typed lines:
#     standpoint: tier2(<repo>) — ran `<cmd>` there, output: <what you saw>
#     generated-path: none-found(<the generator grep you ran>)   | found(<path> -> <generator>)
#     fixture-carries: asserted(<cmd>, <what you saw>)  | not-applicable(<grounds>)
#   `standpoint:` is the EXISTING closed enum (CLAUDE.md §7). This gate applies an ALLOW-LIST of
#   its strong rungs — tier2 / tier2b / tier3 — so tier1, tier1b, not-applicable, UNKNOWN, every
#   DEGRADED_*, and ANY FUTURE MEMBER block by default. Default-deny on an unknown value is the
#   same contract validate_standpoint_leg() uses; lane L8 fails if a new enum member is added
#   without being classified here.
#   `generated-path:` closes archify#328②  (editing a build OUTPUT: the canon is the generator's
#   input). NONE FOUND is printed as UNPROVEN, never as safe.
#   `fixture-carries:` closes archify#328①, clawd#1025③④ AND clawd#1021 — all three are ONE
#   proposition: "the fixture never put the system into the state where the defect is
#   OBSERVABLE." Three spellings measured so far, all from our own closed/blocked PRs:
#     A  the destination was never a symlink to the input, so a pre-write hash check could not
#        see the damage the write itself caused                                  (archify#328①)
#     B  the IPC round-trip never existed in the test, because the next-stage handler was called
#        synchronously, so the transition window was not in the fixture at all  (clawd#1025③④)
#     C  every exception fixture carried exactly ONE effective destructive decision, so a
#        first-match-only evaluator could not be told from an all-match one     (clawd#1021 —
#        maintainer's own words, and reproduced by the governor: 13 of 16 composed commands
#        AUTO-ALLOW, e.g. `npm publish --dry-run && rm -rf /`, with live controls `ls -la`→null
#        and `rm -rf /`→HOLD)
#   ONE FIELD, NOT ONE PER DEFECT. A fourth spelling lands as a fourth bullet in the deny text —
#   zero enum change, zero lane change. Growing the FIELD set one-per-defect is how a gate turns
#   into a form: with `not-applicable` available, a field that is almost always not-applicable
#   trains rubber-stamping (measured in this repo's own standpoint corpus: 6 bare
#   `not-applicable`). 🟥 NAMED RESIDUAL of folding: a session can answer spelling A and never
#   consider C, and the gate is satisfied. Closing that would need a grounds-vocabulary grep,
#   i.e. a frozen judgment about what an adequate answer sounds like — deliberately not built.
#   It is a FIELD and not a detector on purpose: a grep for "next-stage handler called on the
#   following line" asserts a CONCLUSION about test adequacy.
#
# 🟥 SELF-ATTESTED, AND THAT IS THE INTENDED RESIDUE. This blocks the record's FORM (present,
#   typed, attributable, non-vacuous), never whether the run was real — the same boundary the
#   crossfamily/standpoint/thirdparty commit lanes already live on.
#
# Override, recorded by construction: put FH_OUTBOUND_PR_OK=1 in the command itself. The hook
#   reads the COMMAND STRING (an env var exported in the session is not in the hook's env), so
#   the override lands in the transcript, and the PR it lets out is itself swept by ①-b.
#
# Ownership discriminator — CALIBRATED, offline, zero network (2026-09-18, this machine):
#   a clone of a repo we do not own carries an `upstream` remote under a foreign owner.
#     ~/projects/archify        upstream tt-a1i/archify              -> NON-OWNED  (known-pos)
#     ~/projects/clawd-on-desk  upstream rullerzhou-afk/clawd-on-desk-> NON-OWNED  (known-pos)
#     ~/projects/forge-harness  no upstream                          -> OWNED      (known-neg)
#     ~/projects/qasp-dev       no upstream (has ghe/tst)            -> OWNED      (known-neg)
#   Both directions separate, so the discriminator measures rather than generates.
#
# Usage:  hook:  PreToolUse matcher "Bash" -> bash scripts/outbound_pr_gate.sh
#         test:  printf '%s' '<json>' | bash scripts/outbound_pr_gate.sh
# Lanes:  bash scripts/test_outbound_pr_gate_lanes.sh
set -uo pipefail

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
FH="${CLAUDE_PROJECT_DIR:-}"
[ -n "$FH" ] || FH="$(cd "$SELF_DIR/.." && pwd)"
# Applicability of the whole hook: only inside an FH checkout. Mechanical, never self-judged —
# same test shape as outbound_query_hook's (a tracked anchor that only this repo ships).
ANCHOR="${FH_OUTBOUND_ANCHOR:-$FH/scripts/session_close_check.sh}"
[ -f "$ANCHOR" ] || exit 0

TODAY="${FH_OUTBOUND_TODAY:-$(date +%Y-%m-%d)}"
RECDIR="${FH_OUTBOUND_RECDIR:-$FH/tracks/_meta}"

# ── read the payload ──────────────────────────────────────────────────────────────────────────
# python3 is used ONLY to parse. The DENY path below needs no interpreter (exit 2 + stderr), so a
# dead python3 cannot silently unblock this surface — it makes us read nothing and exit 0, which
# is the one documented fail-open and is identical to the hook not being wired at all.
RAW=$(cat)
PARSED=$(printf '%s' "$RAW" | python3 -c '
import json,sys
try: d=json.load(sys.stdin)
except Exception: sys.exit(0)
if not isinstance(d,dict) or d.get("tool_name")!="Bash": sys.exit(0)
ti=d.get("tool_input") or {}
cmd=(ti.get("command") if isinstance(ti,dict) else str(ti)) or ""
cwd=str(d.get("cwd") or "")
sys.stdout.buffer.write(("CWD\t"+cwd.replace("\t"," ").replace("\n"," ")+"\n").encode("utf-8"))
sys.stdout.buffer.write(("CMD\t"+cmd.replace("\t"," ").replace("\n","; ")+"\n").encode("utf-8"))
' 2>/dev/null) || exit 0
[ -n "$PARSED" ] || exit 0
PAY_CWD=$(printf '%s\n' "$PARSED" | sed -n 's/^CWD\t//p' | head -1)
CMD=$(printf '%s\n' "$PARSED" | sed -n 's/^CMD\t//p' | head -1)
[ -n "$CMD" ] || exit 0

# ── is this the outbound act? ─────────────────────────────────────────────────────────────────
# create / reopen / ready: the three ways a PR is put in front of a stranger. `gh pr edit --body`
# is publish per CLAUDE.md too and is a NAMED GAP here, not a claimed coverage.
# 🟥 cross-family (codex, 2026-09-18) 이 트리거를 공격했고, **주장 7건 중 5건은 실측에서 틀렸다** —
# `command gh` · `env X=1 gh` · `time gh` · `noglob gh` · `gh pr create --repo 'o/r'` 는 종전 식으로도
# 전부 잡힌다(선행 문자가 공백이므로). 실제로 안 잡히던 것은 셋이고, 그중 둘을 여기서 닫는다:
#   ⓐ 경로 형태  `/opt/homebrew/bin/gh pr create` · `./gh pr create`  → `([^ ;&|]*/)?` 추가
#   ⓑ 인용 안쪽  `sh -c 'gh pr create …'`                              → 선행 문자류에 ' " ` 추가
# 🟥 셋째는 **정규식으로 닫히지 않는다**: 변수 간접(`GH_CMD=gh; $GH_CMD pr create`) · 셸 alias ·
#    gh 를 감싼 스크립트. 이름으로 남긴 잔여이고, 이 훅은 그래서 «상기시키는 층» 이지 floor 가 아니다.
# ⚠️ 알려진 과차단 하나: `echo gh pr create` 도 잡힌다. 과차단 방향이라 그대로 둔다
#    (막는 쪽으로 틀리는 것이 이 표면에서 옳다).
printf '%s' "$CMD" | LC_ALL=C grep -qE '(^|[ ;&|('"'"'"`])([^ ;&|]*/)?gh +([^ ;&|]+ +)*pr +(create|reopen|ready)([ ;&|]|$)' || exit 0

# ── owned-owner set ───────────────────────────────────────────────────────────────────────────
OWNERS=""
_origin=$(git -C "$FH" remote get-url origin 2>/dev/null || true)
_o=$(printf '%s' "$_origin" | sed -E 's#^.*[/:]([^/:]+)/[^/]+$#\1#')
[ -n "$_o" ] && [ "$_o" != "$_origin" ] && OWNERS="$_o"
# Optional operator layer; absent by construction in a consumer install.
OWNFILE="${FH_OWNED_OWNERS_FILE:-$FH/.claude/rules/.owned-owners}"
[ -f "$OWNFILE" ] && OWNERS="$OWNERS
$(grep -vE '^[[:space:]]*(#|$)' "$OWNFILE" 2>/dev/null || true)"

_is_owned() { # $1 = owner login
  [ -n "${1:-}" ] || return 1
  printf '%s\n' "$OWNERS" | grep -qxF "$1"
}

# A clone's BASE repo, as `gh pr create` resolves it: the fork parent (`upstream`) when the clone
# is a fork, otherwise `origin` itself. Reading only `upstream` would call a DIRECT clone of a
# foreign repo "ours" — that is the same not-found-is-not-zero face this repo keeps meeting.
_base_repo_of() { # $1 = a directory; echoes "owner/repo", or nothing
  local d="$1" u r
  [ -n "$d" ] && [ -d "$d" ] || return 1
  git -C "$d" rev-parse --git-dir >/dev/null 2>&1 || return 1
  u=$(git -C "$d" remote get-url upstream 2>/dev/null)
  [ -n "$u" ] || u=$(git -C "$d" remote get-url origin 2>/dev/null)
  [ -n "$u" ] || return 1
  r=$(printf '%s' "$u" | sed -E 's#\.git$##; s#^.*[/:]([^/:]+/[^/:]+)$#\1#')
  case "$r" in */*) printf '%s' "$r" ;; *) return 1 ;; esac
}

# ── resolve the target, first hit wins ────────────────────────────────────────────────────────
TARGET=""; OWNER=""; HOW=""
_spec=$(printf '%s' "$CMD" | LC_ALL=C grep -oE '(^|[ ;&|])(-R|--repo)[= ]+[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+' | head -1 \
        | sed -E 's#.*[= ]([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)$#\1#')
if [ -n "$_spec" ]; then
  TARGET="$_spec"; OWNER="${_spec%%/*}"; HOW="-R/--repo in the command"
else
  _cd=$(printf '%s' "$CMD" | LC_ALL=C grep -oE '(^|[ ;&|])cd +[^ ;&|]+' | head -1 | sed -E 's#.*cd +##')
  for _d in "$_cd" "$PAY_CWD"; do
    [ -n "$_d" ] || continue
    if _b=$(_base_repo_of "$_d"); then
      TARGET="$_b"; OWNER="${_b%%/*}"; HOW="base repo of $_d (upstream, else origin)"; break
    fi
  done
fi

if [ -z "$OWNER" ]; then
  VERDICT="UNDETERMINED"
elif _is_owned "$OWNER"; then
  exit 0   # positively ours — silent, always
else
  VERDICT="NON-OWNED"
fi

# ── record check (only reached on NON-OWNED / UNDETERMINED) ───────────────────────────────────
# Grounds bar is 20 chars, deliberately the SAME number validate_standpoint_leg() uses — one bar,
# not a second one that drifts.
STRONG_RUNGS="tier2 tier2b tier3"
WEAK_RUNGS="tier1 tier1b not-applicable UNKNOWN DEGRADED_NO_TARGET_ACCESS DEGRADED_NOT_RUN"
REASONS=""
_add() { REASONS="${REASONS}  - $1
"; }

_field() { # $1 = field name; echoes the value line or nothing
  ls -1 "$RECDIR"/outbound_pr_"$TODAY"_*.md 2>/dev/null | while read -r f; do
    grep -m1 -E "^[[:space:]]*$1:" "$f" 2>/dev/null
  done | head -1
}
_records=$(ls -1 "$RECDIR"/outbound_pr_"$TODAY"_*.md 2>/dev/null | wc -l | tr -d ' ')

if [ "${_records:-0}" -eq 0 ]; then
  _add "no record: expected $RECDIR/outbound_pr_${TODAY}_<slug>.md — none exists."
  # COLD START. The three field syntaxes live in the per-field "line absent" branches below, and
  # those are unreachable when there is no file at all — so the very first session to hit this gate
  # was told a path and nothing else, and had to read this script to learn the form. Print the
  # skeleton here. Not a bullet: it is the continuation of the one bullet above, not a fourth
  # reason. Deliberately a SKELETON and not an example with plausible values — a fillable example
  # is a form to copy, and this gate exists because a record can be true in form and false in fact.
  REASONS="${REASONS}      Write those three lines; each value owes >=20 chars of grounds naming a real run:
        standpoint: tier2(<repo>) — ran <cmd> there, output: <what you saw>
        generated-path: none-found(<the generator grep you ran>)  |  found(<path> -> <generator>)
        fixture-carries: asserted(<cmd>, <what you saw>)  |  not-applicable(<grounds>)
      Write it and re-run — any line that still does not pass is then explained in full.
"
else
  _sp=$(_field standpoint); _sp=${_sp#*:}
  _spv=$(printf '%s' "$_sp" | sed -E 's/^[[:space:]]*//; s/[[:space:]]*(—|--).*$//; s/[[:space:]]+$//; s/^["'"'"']//')
  _spg=$(printf '%s' "$_sp" | sed -E 's/^[^—-]*((—|--)[[:space:]]*)?//')
  case "$_spv" in
    tier2\(*\)|tier2b\(*\)|tier3\(*\))
      [ "${#_spg}" -lt 20 ] && _add "standpoint: $_spv — grounds do not name the command you ran and the output you saw." ;;
    "") _add "standpoint: line absent from the record. The enum is CLAUDE.md §7; only $STRONG_RUNGS clear this gate." ;;
    *)  _add "standpoint: '$_spv' is not a strong rung. tier1b means you READ the target and ran nothing — that is the signal that it is NOT time to submit (clawd#1025 was exactly this). Strong rungs: $STRONG_RUNGS." ;;
  esac
  _gp=$(_field generated-path); _gp=${_gp#*:}
  _gpv=$(printf '%s' "$_gp" | sed -E 's/^[[:space:]]*//; s/\(.*$//; s/[[:space:]]+$//')
  _gpg=$(printf '%s' "$_gp" | sed -E 's/^[^(]*\(//; s/\)[[:space:]]*$//')
  case "$_gpv" in
    found|none-found) [ "${#_gpg}" -lt 20 ] && _add "generated-path: $_gpv() carries no grounds — name the generator grep you ran over the target repo." ;;
    "") _add "generated-path: line absent. For every path this patch touches, grep the target's own generators (package.json scripts, *.mjs|*.js|*.sh that WRITE that path). A hit means the edit is in the wrong place — the canon is the generator's input (archify#328②). Absence is 'none-found', i.e. UNPROVEN, never 'safe'." ;;
    *) _add "generated-path: '$_gpv' is not one of: found(...) | none-found(...)." ;;
  esac
  _ar=$(_field fixture-carries); _ar=${_ar#*:}
  _arv=$(printf '%s' "$_ar" | sed -E 's/^[[:space:]]*//; s/\(.*$//; s/[[:space:]]+$//')
  _arg=$(printf '%s' "$_ar" | sed -E 's/^[^(]*\(//; s/\)[[:space:]]*$//')
  case "$_arv" in
    asserted|not-applicable) [ "${#_arg}" -lt 20 ] && _add "fixture-carries: $_arv() carries no grounds." ;;
    "") _add "fixture-carries: line absent. The fixture must put the system into the state where the defect is OBSERVABLE; three spellings measured in our own closed PRs — (A) destination pre-made as a symlink to the input, assert the INPUT's post-state [archify#328]; (B) assert INSIDE the async window, do not call the next-stage handler synchronously [clawd#1025]; (C) the input carries >=2 effective decisions with the FIRST one excepted, so a first-match-only evaluator is distinguishable [clawd#1021]. Answer whichever applies, and name the run. Values: asserted(<cmd>, <what you saw>) | not-applicable(<grounds>)." ;;
    DEGRADED_NOT_RUN) _add "fixture-carries: DEGRADED_NOT_RUN — 'did not run it' is an honest record and it is also the answer 'not yet ready to submit'. Run it, or record not-applicable(<grounds>)." ;;
    *) _add "fixture-carries: '$_arv' is not one of: asserted(...) | not-applicable(...) | DEGRADED_NOT_RUN(...)." ;;
  esac
fi

# ── verdict ───────────────────────────────────────────────────────────────────────────────────
HDR="OUTBOUND-PR GATE — target $TARGET ($HOW)"
if [ "$VERDICT" = "UNDETERMINED" ]; then
  [ -n "$REASONS" ] || exit 0
  BODY="  ⚠️  OUTBOUND-PR GATE — could not establish whether this PR's base repo is ours.
      Advisory only (denying here would block every bare \`gh pr create\`), and it reaches you on
      the NEXT turn — the PR may already be open. If the base repo is NOT ours, the record is owed:
${REASONS}      Re-run with -R <owner>/<repo> to get a decided verdict instead of this one."
  if json=$(printf '%s' "$BODY" | PYTHONIOENCODING=utf-8 python3 -c '
import json,sys
h=sys.stdin.read()
print(json.dumps({"systemMessage":h,"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":h}}))
' 2>/dev/null) && [ -n "$json" ]; then printf '%s\n' "$json"; exit 0; fi
  printf '%s\n' "$BODY" >&2
  exit 0
fi

# NON-OWNED from here down.
if printf '%s' "$CMD" | LC_ALL=C grep -qE 'FH_OUTBOUND_PR_OK=1'; then
  printf '%s\n' "  ⚠️  $HDR — FH_OUTBOUND_PR_OK=1 in the command: gate acknowledged, not satisfied." >&2
  exit 0
fi
[ -n "$REASONS" ] || exit 0
printf '%s\n' "  ❌ $HDR
      A PR on a repo we do not own is publish-class and this gate fails CLOSED.
      Owed, in $RECDIR/outbound_pr_${TODAY}_<slug>.md:
${REASONS}      Three of our outbound PRs carry a technical-defect finding (#1025 closed, #328 and #1021
      changes-requested) and all three were submitted after a STATIC read of the target. This gate
      blocks the RECORD's shape, never the truth of the run.
      Deliberate and reviewed -> prefix the command with FH_OUTBOUND_PR_OK=1." >&2
exit 2
