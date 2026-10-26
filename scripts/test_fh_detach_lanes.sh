#!/usr/bin/env bash
# test_fh_detach_lanes.sh — install-wizard writes, fh_detach.py undoes them, byte for byte.
#
# The install side is NOT re-typed here: the lane extracts the wizard's own bash blocks
# (SKILL_detail.md §Step4-Baseline-Bash and §Mode-D-Companion-Setup) and runs them, so a change to what the
# wizard writes is exercised by the next run of this lane. Everything happens under a temp HOME and a temp hub.
#
#   D*  detach (known-positive: install changes the tree · known-negative: detach restores it exactly)
#   G*  the wizard's 4-axis gate block needs FH_WIZARD_GATE_CONSENT=Y
#   P1  --plugin calls the Claude Code uninstall (a fake `claude` records the argv)
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
DETACH="$HERE/fh_detach.py"
DETAIL="$ROOT/plugins/fh-meta/skills/install-wizard/SKILL_detail.md"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
pass=0; fail=0
chk() { # chk <name> <got> <want>
  if [ "$2" = "$3" ]; then pass=$((pass+1)); printf '  ✅ %-58s %s\n' "$1" "$2"
  else fail=$((fail+1)); printf '  ❌ %-58s got=%s want=%s\n' "$1" "$2" "$3"; fi
}

block() { # block <section heading> → the first ```bash fence after it
  python3 - "$DETAIL" "$1" <<'PY'
import sys
s = open(sys.argv[1], encoding="utf-8").read().split("\n")
i = s.index("## " + sys.argv[2])
while not s[i].startswith("```bash"):
    i += 1
j = i + 1
while s[j] != "```":
    j += 1
print("\n".join(s[i + 1:j]))
PY
}
block "§Step4-Baseline-Bash" > "$T/step4.sh" || { echo "HARNESS-ERROR: cannot extract §Step4-Baseline-Bash"; exit 10; }
block "§Mode-D-Companion-Setup" > "$T/moded.sh" || { echo "HARNESS-ERROR: cannot extract §Mode-D-Companion-Setup"; exit 10; }
grep -q 'core.hooksPath templates/.git-hooks' "$T/step4.sh" || { echo "HARNESS-ERROR: step4 block has no gate install"; exit 10; }
grep -q 'settings.local.json' "$T/moded.sh" || { echo "HARNESS-ERROR: Mode-D block has no settings.local.json write"; exit 10; }
cat > "$T/edit_json.py" <<'PY'
import json, sys
# edit_json.py <settings.json> <hooks-to-merge JSON> <indent>
p = sys.argv[1]; d = json.load(open(p)); d.setdefault("hooks", {}).update(json.loads(sys.argv[2]))
open(p, "w").write(json.dumps(d, indent=int(sys.argv[3])) + "\n")
PY
cat > "$T/race.py" <<'PY'
import importlib.util, json, os, sys
# race.py <fh_detach.py> <world>: plan, then another writer changes settings.json, then apply
spec = importlib.util.spec_from_file_location("d", sys.argv[1]); d = importlib.util.module_from_spec(spec); spec.loader.exec_module(d)
hub = os.path.join(sys.argv[2], "hub"); S = os.path.join(hub, ".claude", "settings.json")
plan = d.Plan(True); cmds, keys = d.snippet_commands(hub)
d.plan_settings(plan, S, cmds, keys)
x = json.load(open(S)); x["hooks"].setdefault("Stop", []).append({"hooks": [{"type": "command", "command": "bash late.sh"}]})
open(S, "w").write(json.dumps(x, indent=2) + "\n")
for _, fn in plan.actions:
    fn()
print("late=%d left=%d" % (open(S).read().count("late.sh"), sum("changed after the plan" in l for l in plan.left)))
PY

snap() { # snap <home> <hub> → one sha per file (+ hooksPath + exclude), hub/.git internals skipped
  python3 - "$1" "$2" <<'PY'
import hashlib, os, subprocess, sys
out = []
for root in sys.argv[1:]:
    for dp, dn, fn in os.walk(root):
        dn[:] = sorted(d for d in dn if d != ".git")
        out.append("D " + os.path.relpath(dp, root))
        for f in sorted(fn):
            p = os.path.join(dp, f)
            out.append("F %s %s" % (os.path.relpath(p, root), hashlib.sha256(open(p, "rb").read()).hexdigest()[:16]))
hub = sys.argv[2]
r = subprocess.run(["git", "-C", hub, "config", "--local", "--get", "core.hooksPath"], capture_output=True, text=True)
out.append("hooksPath=" + r.stdout.strip())
ex = os.path.join(hub, ".git", "info", "exclude")
out.append("exclude=" + (hashlib.sha256(open(ex, "rb").read()).hexdigest()[:16] if os.path.exists(ex) else "-"))
print("\n".join(out))
PY
}

mkworld() { # mkworld <dir> → fresh HOME + hub with the user's own config already in place
  local W="$1"; mkdir -p "$W/home" "$W/hub/templates" "$W/hub/scripts" "$W/store" "$W/hub/.claude"
  git -C "$W/hub" init -q
  cp "$ROOT"/templates/settings.*.snippet.json "$ROOT/templates/fh_audit_check.zsh" \
     "$ROOT/templates/local_fh_context.md" "$ROOT/templates/fh_env_context.jsonc" "$W/hub/templates/"
  mkdir -p "$W/hub/templates/.git-hooks" && echo '#!/bin/sh' > "$W/hub/templates/.git-hooks/pre-commit"
  cp "$ROOT/scripts/fh_node_check.sh" "$W/hub/scripts/"
  printf '#!/bin/sh\necho "companion-store freshness (stub)"\n' > "$W/hub/scripts/fh_session_load.sh"
  printf 'export PATH=/opt/x:$PATH\nalias ll="ls -l"\n' > "$W/home/.zshrc"
  printf '# mine\nkeep this line\n' > "$W/hub/CLAUDE.local.md"
  # the user's own hooks — one shares a script NAME with FH but not its path; formatting is not indent=2
  python3 - "$W/hub/.claude/settings.json" <<'PY'
import json, sys
d = {"model": "x", "hooks": {
  "SessionStart": [{"hooks": [{"type": "command", "command": "bash ~/tools/scripts/fh_node_check.sh"}]}],
  "PreToolUse": [{"matcher": "Bash", "hooks": [{"type": "command", "command": "bash my_guard.sh"}]}]}}
open(sys.argv[1], "w").write(json.dumps(d, indent=4) + "\n")
PY
}

install() { # install <world> [gate-consent | unset]
  local W="$1" G="${2:-Y}"
  if [ "$G" = unset ]; then
    ( cd "$W/hub" && env -u FH_WIZARD_GATE_CONSENT HOME="$W/home" FH_DIR="$W/hub" CC_HUB_DIR="$W/hub" FH_WIZARD_ZSHRC_CONSENT=Y \
        bash "$T/step4.sh" ) > "$W/step4.out" 2>&1
  else
    ( cd "$W/hub" && env HOME="$W/home" FH_DIR="$W/hub" CC_HUB_DIR="$W/hub" FH_WIZARD_ZSHRC_CONSENT=Y \
        FH_WIZARD_GATE_CONSENT="$G" bash "$T/step4.sh" ) > "$W/step4.out" 2>&1
  fi
  ( cd "$W/hub" && env HOME="$W/home" HUB_DIR="$W/hub" BE_DIR="$W/store" bash "$T/moded.sh" ) > "$W/moded.out" 2>&1
  # §Step3 «Copy: templates/local_fh_context.md → .claude/rules/ · add pattern to .git/info/exclude»
  mkdir -p "$W/hub/.claude/rules" && cp "$W/hub/templates/local_fh_context.md" "$W/hub/.claude/rules/"
  echo ".claude/rules/local_fh_context.md" >> "$W/hub/.git/info/exclude"
}
detach() { # detach <world> [args…] → rc
  local W="$1"; shift
  ( cd "$W/hub" && python3 "$DETACH" --project "$W/hub" --fh-dir "$W/hub" --home "$W/home" "$@" ) > "$W/detach.out" 2>&1
  echo $?
}
fhhooks() { python3 -c '
import json,sys,re
d=json.load(open(sys.argv[1])); n=0
for gs in d.get("hooks",{}).values():
  for g in gs:
    for h in g["hooks"]: n+=bool(re.search(r"CLAUDE_PROJECT_DIR|forge-harness", h["command"]))
print(n)' "$1"; }

echo "── D: install → detach restores the tree ──"
W="$T/w1"; mkworld "$W"
PRE="$(snap "$W/home" "$W/hub")"
install "$W"
POST="$(snap "$W/home" "$W/hub")"
chk "D1 install changed the tree (known-positive)"  "$([ "$PRE" != "$POST" ] && echo changed)" changed
chk "D1b zshrc block carries begin/end markers"  "$(grep -c 'forge-harness (install-wizard)' "$W/home/.zshrc")" 2
chk "D1c FH hooks registered in settings.json"  "$([ "$(fhhooks "$W/hub/.claude/settings.json")" -gt 3 ] && echo yes)" yes
chk "D1d hooksPath set by the gate block"  "$(git -C "$W/hub" config --get core.hooksPath)" "templates/.git-hooks"
chk "D2 dry run: rc 0"  "$(detach "$W")" 0
chk "D2b dry run changed nothing"  "$([ "$(snap "$W/home" "$W/hub")" = "$POST" ] && echo same)" same
chk "D2c dry run lists the steps (≥ 6)"  "$([ "$(grep -c '^  - ' "$W/detach.out")" -ge 6 ] && echo yes)" yes
chk "D3 --apply: rc 0"  "$(detach "$W" --apply)" 0
AFTER="$(snap "$W/home" "$W/hub")"
chk "D3b tree is byte-equal to before install"  "$([ "$AFTER" = "$PRE" ] && echo equal)" equal
[ "$AFTER" = "$PRE" ] || diff <(echo "$PRE") <(echo "$AFTER") | head -10
chk "D4 second --apply is a no-op (0 steps, rc 0)"  "$(detach "$W" --apply)/$(grep -c '^  - ' "$W/detach.out")" "0/0"

echo "── D: what must NOT be removed ──"
W="$T/w2"; mkworld "$W"; install "$W"
python3 - "$W/hub/.claude/settings.json" <<'PY'
import json, sys
p = sys.argv[1]; d = json.load(open(p))
d["hooks"].setdefault("Stop", []).append({"hooks": [{"type": "command", "command": "bash after_install.sh"}]})
d["hooks"]["PreToolUse"].append({"hooks": [{"type": "command", "command": 'bash "$CLAUDE_PROJECT_DIR/scripts/pipe_verdict_guard.sh" --old-flag'}]})
open(p, "w").write(json.dumps(d, indent=2) + "\n")
PY
echo "user note" >> "$W/hub/.claude/rules/local_fh_context.md"
rc=$(detach "$W" --apply)
S="$W/hub/.claude/settings.json"
chk "D5 user's hook added after install survives"  "$(grep -c 'after_install.sh' "$S")" 1
chk "D5b user's own fh_node_check.sh (not FH's path) survives"  "$(grep -c '~/tools/scripts/fh_node_check.sh' "$S")" 1
chk "D5c non-hook keys survive"  "$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["model"])' "$S")" x
chk "D7 FH-like hook that is not byte-equal → kept + LEFT + rc 1"  "$rc/$(grep -c 'pipe_verdict_guard.sh\\" --old-flag' "$S")/$(grep -c 'LEFT (look at it).*older version' "$W/detach.out")" "1/1/1"
chk "D9 edited template copy kept + LEFT"  "$([ -f "$W/hub/.claude/rules/local_fh_context.md" ] && echo kept)/$(grep -c 'you edited this copy' "$W/detach.out")" "kept/1"
chk "D9b … and its .git/info/exclude line stays"  "$(grep -c '^.claude/rules/local_fh_context.md$' "$W/hub/.git/info/exclude")" 1
chk "D5d .prewizard that no longer matches is kept and named"  "$([ -f "$S.prewizard" ] && echo kept)/$(grep -c 'note: .*settings.json.prewizard' "$W/detach.out")" "kept/1"
chk "D5e every byte-equal FH hook is gone"  "$(fhhooks "$S")" 1

echo "── D: legacy zshrc · foreign hooksPath · unreadable config ──"
W="$T/w3"; mkworld "$W"
printf 'export FH_DIR="/x/fh"\nexport CC_HUB_DIR="/x/fh"\nexport CC_SENTINELS_DIR="$HOME/.cc_sentinels"\nsource "$FH_DIR/templates/fh_audit_check.zsh"\n' >> "$W/home/.zshrc"
git -C "$W/hub" config core.hooksPath custom/hooks
rc=$(detach "$W" --apply)
chk "D6 legacy unmarked 4-line block removed, user lines kept"  "$(grep -c fh_audit_check "$W/home/.zshrc")/$(grep -c 'alias ll' "$W/home/.zshrc")" "0/1"
chk "D11 a hooksPath that is not the wizard's is left alone"  "$(git -C "$W/hub" config --get core.hooksPath)" custom/hooks
W="$T/w4"; mkworld "$W"; install "$W"
printf '{ "hooks": ' > "$W/hub/.claude/settings.json"; B="$(shasum "$W/hub/.claude/settings.json")"
chk "D10 unparsable settings.json → rc 10"  "$(detach "$W" --apply)" 10
chk "D10b … and the file is untouched"  "$([ "$(shasum "$W/hub/.claude/settings.json")" = "$B" ] && echo same)" same

echo "── codex R1 (2026-10-26) ──"
W="$T/w7"; mkworld "$W"; install "$W"
python3 - "$W/home/.zshrc" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
s = s.replace('source "$FH_DIR/templates/fh_audit_check.zsh"\n', 'source "$FH_DIR/templates/fh_audit_check.zsh"\nexport MY_SETTING=1\n')
open(p, "w").write(s)
PY
python3 - "$W/hub/.claude/settings.json" <<'PY'
import json, sys
p = sys.argv[1]; d = json.load(open(p))
for g in d["hooks"]["PreToolUse"]:
    for h in g["hooks"]:
        if "backtick_guard.sh" in h["command"]:
            h["timeout"] = 99
open(p, "w").write(json.dumps(d, indent=2) + "\n")
PY
printf 'x\r\n' > "$T/crlf" && python3 -c 'import sys;b=open(sys.argv[1],"rb").read().replace(b"\n",b"\r\n");open(sys.argv[1],"wb").write(b)' "$W/hub/.claude/rules/local_fh_context.md"
rc=$(detach "$W" --apply)
chk "K1 a user line inside the marked zshrc block keeps the whole block + LEFT"  "$(grep -c MY_SETTING "$W/home/.zshrc")/$(grep -cE 'forge-harness \(install-wizard\)|^export (FH_DIR|CC_HUB_DIR|CC_SENTINELS_DIR)=|fh_audit_check' "$W/home/.zshrc")/$(grep -c 'LEFT.*zshrc' "$W/detach.out")" "1/6/1"
chk "K2 FH hook whose timeout the user changed is kept + LEFT"  "$(grep -c '"timeout": 99' "$W/hub/.claude/settings.json")/$(grep -c 'LEFT.*backtick_guard' "$W/detach.out")" "1/1"
chk "K3 CRLF-converted template copy counts as edited (kept)"  "$([ -f "$W/hub/.claude/rules/local_fh_context.md" ] && echo kept)" kept
chk "K3b rc 1 while those are left"  "$rc" 1
W="$T/w8"; mkworld "$W"
git -C "$W/hub" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
git -C "$W/hub" worktree add -q "$W/wt" 2>/dev/null
mkdir -p "$W/wt/.claude/rules" && cp "$W/hub/templates/local_fh_context.md" "$W/wt/.claude/rules/"
EX="$(git -C "$W/wt" rev-parse --path-format=absolute --git-path info/exclude)"; mkdir -p "$(dirname "$EX")"
echo ".claude/rules/local_fh_context.md" >> "$EX"
( cd "$W/wt" && python3 "$DETACH" --project "$W/wt" --fh-dir "$W/hub" --home "$W/home" --apply ) > "$W/detach.out" 2>&1
chk "K4 git worktree (.git is a file): copy and its exclude line both go"  "$([ -f "$W/wt/.claude/rules/local_fh_context.md" ] && echo kept || echo gone)/$(grep -c 'local_fh_context' "$EX")" "gone/0"
W="$T/w9"; mkworld "$W"; mkdir -p "$T/bin2"
printf '#!/bin/sh
exit 1
' > "$T/bin2/claude"; chmod +x "$T/bin2/claude"
chk "K5 a failed plugin uninstall → rc 1 + LEFT"  "$(PATH="$T/bin2:$PATH" detach "$W" --apply --plugin)/$(grep -c 'LEFT.*plugin' "$W/detach.out")" "1/2"

echo "── codex R2 (2026-10-26) ──"
W="$T/w10"; mkworld "$W"
python3 "$T/edit_json.py" "$W/hub/.claude/settings.json" '{"Notification": [{"matcher": "mine", "hooks": []}]}' 4
install "$W"; install "$W"            # the wizard run twice: .prewizard now holds the first run's FH hooks
detach "$W" --apply >/dev/null
chk "Q1 a user group with an empty hook list survives"  "$(grep -c '"matcher": "mine"' "$W/hub/.claude/settings.json")" 1
chk "Q2 after two installs no .prewizard is left behind"  "$(ls "$W/hub/.claude/" | grep -c prewizard)" 0
W="$T/w11"; mkworld "$W"; install "$W"
rm "$W/hub/.claude/rules/local_fh_context.md"      # a partial apply removed the copy but not its exclude line
detach "$W" --apply >/dev/null
chk "Q3 rerun after a partial apply still drops the exclude line"  "$(grep -c local_fh_context "$W/hub/.git/info/exclude")" 0
W="$T/w12"; mkworld "$W"; mv "$W/hub" "$W/my hub"
( cd "$W/my hub" && env HOME="$W/home" FH_DIR="$W/my hub" CC_HUB_DIR="$W/my hub" FH_WIZARD_ZSHRC_CONSENT=Y FH_WIZARD_GATE_CONSENT=Y bash "$T/step4.sh" ) > "$W/step4.out" 2>&1
chk "Q4 a project name with a space gets one sentinel, named whole"  "$(ls "$W/home/.cc_sentinels" | tr '\n' '|')/$(ls "$W/my hub" | grep -c _wizard_done)" "my hub_wizard_done|/0"
( cd "$W/my hub" && python3 "$DETACH" --project "$W/my hub" --fh-dir "$W/my hub" --home "$W/home" --apply ) > "$W/detach.out" 2>&1
chk "Q4b … and detach removes it"  "$([ -d "$W/home/.cc_sentinels" ] && echo present || echo gone)" gone
W="$T/w13"; mkworld "$W"; install "$W"
chk "Q5 a write between plan and apply is not overwritten (LEFT instead)"  "$(python3 "$T/race.py" "$DETACH" "$W")" "late=1 left=1"

echo "── G: the wizard's 4-axis gate block needs explicit consent ──"
W="$T/w5"; mkworld "$W"; install "$W" unset
chk "G1 FH_WIZARD_GATE_CONSENT unset → hooksPath not set"  "$(git -C "$W/hub" config --get core.hooksPath || echo unset)" unset
chk "G1b … and it says SKIPPED"  "$(grep -c '4-axis pre-commit gate: SKIPPED' "$W/step4.out")" 1

echo "── P: plugin uninstall ──"
W="$T/w6"; mkworld "$W"; mkdir -p "$T/bin"
printf '#!/bin/sh\necho "$@" >> "%s/claude.argv"\n' "$T" > "$T/bin/claude"; chmod +x "$T/bin/claude"
PATH="$T/bin:$PATH" detach "$W" --apply --plugin >/dev/null
chk "P1 --plugin uninstalls fh-meta and removes the marketplace"  "$(cat "$T/claude.argv" 2>/dev/null | tr '\n' '|')" "plugin uninstall fh-meta@forge-harness|plugin marketplace remove forge-harness|"

echo "── W: wiring ──"
chk "W1 package.json ships fh_detach.py"  "$(grep -c '"scripts/fh_detach.py"' "$ROOT/package.json")" 1
chk "W2 install-wizard SKILL.md points at the detach command"  "$(grep -q 'scripts/fh_detach.py" --project . --apply' "$ROOT/plugins/fh-meta/skills/install-wizard/SKILL.md" && echo yes)" yes

echo
echo "fh_detach lanes: $pass passed · $fail failed"
[ "$fail" -eq 0 ]
