#!/usr/bin/env bash
# test_deep_clarify_interview_lanes.sh — the shape of deep-clarify's interview after the four 2026-11-21 additions.
#
# WHY. A public «interview me» talk (2026-11-21, used as an idea source only — its numbers are unverified) and
# deep-clarify differed in four places: deep-clarify folded the upper goal (Why) into the one-line Goal, wrote
# textbook phrases («make it scalable») straight into the spec, never tested whether it had understood, and
# offered «start implementation directly» in the same window as an equal next step.
#
# WHAT IS CHECKED (structure of SKILL.md — the round templates are what a session copies):
#   I1  Round 1 asks the Why as its own question, separate from the completion-criteria question
#   I2  a textbook-phrase rule: such a phrase is not recorded as a requirement; ask once what is needed
#   I3  the last round tests understanding with an option the user has not mentioned, checks the pick
#       against the Why, re-asks once on a contradiction, then records an open question
#   I4  Step 4's first (default) row is a new session that reads only the saved spec; «Start
#       implementation directly» is still there and marked not the default
#   I5  the spec format carries `## Why` and `## Understanding check`
#   I6  (2026-11-23) Round 2 has the money · personal-data binding question: when the request touches payments,
#       accounts or personal data, ask which unique key they are bound to and whether anything is matched on a
#       changeable value such as email; a request that touches none of these never gets it
#   K1  kept: «maximum 3 rounds, maximum 2 questions per round», `(inferred:`, `Excluded:`, `specs/{slug}.md`
#   K2  no round template holds more than 2 numbered questions (the cap holds after adding the Why)
#   C   controls: a copy with each of I1–I4 and I6 removed goes red on that case alone
# NOT CHECKED: whether a real session asks these questions — that is the blind Sonnet sim recorded in the
# PR, not this lane. A green run here means the template says it, not that a model does it.
#
# Usage: bash scripts/test_deep_clarify_interview_lanes.sh [<skill file>]      Exit: 0 all pass · 1 any fail
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL="${1:-$HERE/../plugins/fh-meta/skills/deep-clarify/SKILL.md}"
TMPROOT=$(mktemp -d "${TMPDIR:-/tmp}/deep_clarify_iv_XXXXXX")
trap 'rm -rf "$TMPROOT"' EXIT
pass=0; fail=0
ok()  { printf 'PASS  %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf 'FAIL  %s — %s\n' "$1" "$2"; fail=$((fail + 1)); }

# probe <skill file> — prints one line per case: «<id> ok» or «<id> <problem>»
probe() {
  python3 - "$1" <<'PY'
import re, sys
t = open(sys.argv[1], encoding="utf-8").read()
def sec(start, end):
    a = t.find(start)
    if a < 0: return ""
    b = t.find(end, a + len(start)) if end else -1
    return t[a:b] if b > a else t[a:]
def say(i, ok, why): print(f"{i} ok" if ok else f"{i} {why}")
r1 = sec("### Round 1", "### Round 2")
blk = re.findall(r"```\n(.*?)```", r1, re.S)
qs = re.findall(r"^\s*(\d+)\.\s+(.*)$", blk[0], re.M) if blk else []
why_q = [n for n, q in qs if re.search(r"\bWhy\b", q)]
cc_q = [n for n, q in qs if re.search(r"[Cc]ompletion criteria", q)]
say("I1", why_q and cc_q and set(why_q).isdisjoint(cc_q),
    f"Round 1 template: Why question {why_q or 'missing'}, completion-criteria question {cc_q or 'missing'} (must be separate)")
tb = sec("### Textbook phrases", "\n## ") or sec("Textbook phrase", "\n### ")
say("I2", bool(tb) and re.search(r"not (be )?record", tb) and re.search(r"[Aa]sk once", tb),
    "no textbook-phrase rule that says «not recorded as a requirement» and «ask once»")
r3 = sec("### Round 3", "\n## ")
say("I3", bool(r3) and re.search(r"not (yet )?(mentioned|discussed)", r3) and re.search(r"\bWhy\b", r3)
    and re.search(r"[Oo]pen question", r3),
    "Round 3 lacks the unmentioned-option test against the Why with an open-question fallback")
s4 = sec("## Step 4.", "\n## Done When")
rows = [l for l in s4.splitlines() if l.startswith("|") and not re.match(r"\|\s*-", l)][1:]
first = rows[0] if rows else ""
direct = [l for l in rows if "Start implementation directly" in l]
say("I4", re.search(r"new session", first, re.I) and re.search(r"only the saved spec", first, re.I)
    and direct and re.search(r"not the default", direct[0], re.I),
    f"Step 4 first row «{first[:60]}» is not the new-session default, or «Start implementation directly» is gone / not marked")
fmt = sec("### Spec Document Format", "\n## Step 4")
r2 = sec("### Round 2", "\n### Round 3")
say("I6", bool(r2) and re.search(r"[Pp]ayment", r2) and re.search(r"personal data", r2) and re.search(r"unique key", r2)
    and re.search(r"email", r2) and re.search(r"none of these", r2),
    "Round 2 lacks the money · personal-data binding question (payments · personal data · unique key · email · not asked otherwise)")
say("I5", "## Why" in fmt and "## Understanding check" in fmt, "spec format lacks ## Why or ## Understanding check")
keep = ["maximum 3 rounds, maximum 2 questions per round", "(inferred:", "Excluded:", "specs/{slug}.md"]
miss = [k for k in keep if k not in t]
say("K1", not miss, f"missing kept text: {miss}")
over = []
for name in ("### Round 1", "### Round 2", "### Round 3"):
    s = sec(name, "\n### ") if name != "### Round 3" else r3
    for b in re.findall(r"```\n(.*?)```", s, re.S):
        n = len(re.findall(r"^\s*\d+\.\s", b, re.M))
        if n > 2: over.append(f"{name.strip('# ')}={n}")
say("K2", not over, f"round template over 2 questions: {over}")
PY
}

[ -r "$SKILL" ] || { echo "HARNESS: $SKILL not readable — not measured"; exit 1; }
out=$(probe "$SKILL") || { echo "HARNESS: probe failed"; exit 1; }
while read -r id rest; do
  [ "$rest" = ok ] && ok "$id" || bad "$id" "$rest"
done <<< "$out"

# C — controls: remove one addition at a time from a copy; exactly that case must go red
control() {  # control <id> <python that edits text t>
  local f="$TMPROOT/ctl_$1.md" got
  python3 - "$SKILL" "$f" "$2" <<'PY'
import re, sys
t = open(sys.argv[1], encoding="utf-8").read()
exec(sys.argv[3])
open(sys.argv[2], "w", encoding="utf-8").write(t)
PY
  got=$(probe "$f" | awk '$2 != "ok" {print $1}' | tr '\n' ' ')
  [ "$got" = "$1 " ] && ok "C-$1 control: removing it turns only $1 red" || bad "C-$1 control" "red cases «${got}», expected «$1 »"
}
if [ "$fail" -eq 0 ]; then
  control I1 't = re.sub(r"(### Round 1.*?```\n)(.*?)(```)", lambda m: m.group(1) + re.sub(r"^.*\bWhy\b.*\n(?:\s+\(.*\n)?", "", m.group(2), flags=re.M) + m.group(3), t, count=1, flags=re.S)'
  control I2 't = t.replace("### Textbook phrases", "### Plain phrases").replace("Textbook phrase", "Plain phrase")'
  control I3 't = re.sub(r"(### Round 3)(.*?)(\n## )", lambda m: m.group(1) + "\n\nDraft the spec, then confirm once.\n" + m.group(3), t, count=1, flags=re.S)'
  control I4 't = re.sub(r"(## Step 4\..*?\|---\|---\|\n)\|[^\n]*\n", r"\1", t, count=1, flags=re.S)'
  control I6 't = re.sub(r"\*\*Money · personal data.*?(?=\n### Round 3)", "", t, count=1, flags=re.S)'
else
  echo "SKIP  controls — the shipped skill is already red (a control on a red subject proves nothing)"
fi

echo "PASS $pass · FAIL $fail"
[ "$fail" -eq 0 ]
