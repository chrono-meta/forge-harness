#!/usr/bin/env python3
"""fh_detach.py — undo what /install-wizard wrote, and nothing else.

Usage:
  python3 scripts/fh_detach.py [--project DIR] [--fh-dir DIR] [--home DIR] [--apply] [--plugin]

Default is a dry run: it prints the plan and changes nothing. `--apply` carries it out.

What counts as FH's (each is removed only on an EXACT match with what the wizard writes today):
  ① ~/.zshrc            the wizard's block (marked `# >>> forge-harness >>>` … or the older unmarked 4 lines)
  ② <dir>/.claude/settings.json · settings.local.json
                        hook entries equal in every field (key order ignored) to an entry in a shipped
                        templates/settings.*.snippet.json, or to the Mode-D companion hook form. A file the wizard created is deleted when
                        nothing else is left in it; if a .prewizard backup equals the stripped file, its bytes are
                        put back (so the user's own formatting returns).
  ③ <dir>/CLAUDE.local.md  the «Companion-store session-start read» section the wizard appended
  ④ git core.hooksPath  only when it is `templates/.git-hooks` (the wizard's value) in the FH clone
  ⑤ ~/.cc_sentinels/<project>_wizard_*  (and the folder, when that leaves it empty)
  ⑥ .claude/rules/local_fh_context.md · fh_env_context.jsonc  only when byte-equal to the shipped template,
                        plus their exact lines in .git/info/exclude
  ⑦ --plugin            also runs `claude plugin uninstall` / `marketplace remove` for fh-meta@forge-harness

What it never does: delete a user's own hook (even one sharing a group or a script name with FH — a hook identical
to FH's shipped entry cannot be told apart and is treated as FH's), edit a line it did not write, or touch a file
it cannot parse (that is exit 10, file untouched). Scope: ① and ④ are machine/clone-wide, so this takes FH off the
whole setup, not one project.

Exit: 0 = no recognised FH trace left · 1 = something FH-like is left that needs a human look (listed) ·
      10 = could not read something it needed (nothing changed past that point) · 11 = bad arguments.
"""
import argparse
import glob
import json
import os
import re
import shutil
import subprocess
import sys

ZSH_BEGIN = "# >>> forge-harness (install-wizard) >>>"
ZSH_END = "# <<< forge-harness (install-wizard) <<<"
LEGACY_ZSH = [
    re.compile(r'^export FH_DIR=".*"$'),
    re.compile(r'^export CC_HUB_DIR=".*"$'),
    re.compile(r'^export CC_SENTINELS_DIR="\$HOME/\.cc_sentinels"$'),
    re.compile(r'^source "\$FH_DIR/templates/fh_audit_check\.zsh"$'),
]
COMPANION_HEAD = "## Companion-store session-start read"
COMPANION_WIRING = ("At session start: read $BE_DIR/INDEX.md first; then ls -t paper-signals/ handoff/ digests/ and "
                    "open anything newer than the session card (card=pointer, store commit=truth) — not only handoffs.")
# Mode-D companion hooks (install-wizard SKILL_detail §Mode-D-Companion-Setup): BE_DIR is baked in at write time.
MODE_D_CMD = re.compile(r'^BE_DIR="[^"]*" bash "\$CLAUDE_PROJECT_DIR/scripts/(fh_session_load|fh_env_delta_scan)\.sh"$')
COPIED_TEMPLATES = (("local_fh_context.md", ".claude/rules/local_fh_context.md"),
                    ("fh_env_context.jsonc", ".claude/rules/fh_env_context.jsonc"))
SCRIPT_KEY = re.compile(r'scripts/([A-Za-z0-9_\-]+\.sh)')
FH_HINT = re.compile(r'CLAUDE_PROJECT_DIR|forge-harness|FH_DIR')


class HarnessError(Exception):
    pass


def read(p):
    with open(p, encoding="utf-8") as f:
        return f.read()


def read_bytes(p):
    with open(p, "rb") as f:
        return f.read()


def canon(h):
    return json.dumps(h, sort_keys=True, ensure_ascii=False)


def snippet_commands(fh_dir):
    """Every hook entry the shipped snippets register — the exact objects the wizard writes (command AND every other
    field: a hook whose timeout or message the user changed is theirs now, codex R1)."""
    cmds, keys = set(), set()
    snippets = sorted(glob.glob(os.path.join(fh_dir, "templates", "settings.*.snippet.json")))
    if not snippets:
        raise HarnessError("no templates/settings.*.snippet.json under %s — cannot tell FH hooks from yours" % fh_dir)
    for s in snippets:
        try:
            blob = json.loads(read(s))
        except (OSError, ValueError) as e:
            raise HarnessError("unreadable snippet %s: %s" % (s, e))
        for groups in ((blob.get("project_settings_json") or {}).get("hooks") or {}).values():
            for g in groups if isinstance(groups, list) else []:
                for h in g.get("hooks", []) if isinstance(g, dict) else []:
                    c = h.get("command") if isinstance(h, dict) else None
                    if isinstance(c, str):
                        cmds.add(canon(h))
                        keys.update(SCRIPT_KEY.findall(c))
    keys.update({"fh_session_load.sh", "fh_env_delta_scan.sh"})
    keys.update(os.path.basename(x) for x in glob.glob(os.path.join(fh_dir, "scripts", "*.sh")))
    return cmds, keys


def is_fh_hook(h, cmds):
    if canon(h) in cmds:
        return True
    # Mode-D companion form: exactly {type, command, timeout 20} as the wizard writes it
    return (set(h) == {"type", "command", "timeout"} and h.get("type") == "command" and h.get("timeout") == 20
            and bool(MODE_D_CMD.match(h.get("command", ""))))


def looks_fh(cmd, keys):
    """FH-like but not byte-equal (an older snippet version, a hand edit): reported, never removed."""
    return bool(FH_HINT.search(cmd)) and any(k in SCRIPT_KEY.findall(cmd) for k in keys)


def strip_settings(d, cmds):
    """Return (stripped copy, removed commands). Keeps every non-FH hook, in order."""
    out = json.loads(json.dumps(d))
    removed = []
    hooks = out.get("hooks")
    if not isinstance(hooks, dict):
        return out, removed
    for ev in list(hooks):
        groups = hooks[ev]
        if not isinstance(groups, list):
            continue
        kept = []
        for g in groups:
            if not isinstance(g, dict) or not isinstance(g.get("hooks"), list):
                kept.append(g)
                continue
            hs, took = [], False
            for h in g["hooks"]:
                c = h.get("command") if isinstance(h, dict) else None
                if isinstance(c, str) and is_fh_hook(h, cmds):
                    removed.append(c)
                    took = True
                else:
                    hs.append(h)
            if hs or not took:          # a group that was empty before is the user's — kept (codex R2)
                g = dict(g)
                g["hooks"] = hs
                kept.append(g)
        if kept:
            hooks[ev] = kept
        else:
            del hooks[ev]
    if not hooks:
        del out["hooks"]
    return out, removed


def suspects_in(d, keys):
    out = []
    for groups in (d.get("hooks") or {}).values() if isinstance(d.get("hooks"), dict) else []:
        for g in groups if isinstance(groups, list) else []:
            for h in g.get("hooks", []) if isinstance(g, dict) else []:
                c = h.get("command") if isinstance(h, dict) else None
                if isinstance(c, str) and looks_fh(c, keys):
                    out.append(c)
    return out


class Plan:
    def __init__(self, apply):
        self.apply = apply
        self.actions = []   # (label, fn)
        self.left = []      # FH-like traces left for a human
        self.notes = []

    def act(self, label, fn):
        self.actions.append((label, fn))


def plan_zshrc(plan, home):
    p = os.path.join(home, ".zshrc")
    if not os.path.isfile(p):
        return
    lines = read(p).split("\n")
    out, i, hit = [], 0, 0
    while i < len(lines):
        if (lines[i] == ZSH_BEGIN and i + 5 < len(lines) and lines[i + 5] == ZSH_END
                and all(LEGACY_ZSH[k].match(lines[i + 1 + k]) for k in range(4))):
            i += 6      # markers bind only the wizard's exact four lines — anything added inside is the user's (codex R1)
            hit += 1
            continue
        if lines[i] == ZSH_BEGIN and ZSH_END in lines[i:]:
            j = lines.index(ZSH_END, i) + 1      # an edited block is the user's now — copied verbatim, never mined for
            out.extend(lines[i:j])               # the four legacy lines (codex R2: that deleted them from inside the block)
            i = j
            continue
        if i + 4 <= len(lines) and all(LEGACY_ZSH[k].match(lines[i + k]) for k in range(4)):
            i += 4
            hit += 1
            continue
        out.append(lines[i])
        i += 1
    if hit:
        new = "\n".join(out)
        seen = "\n".join(lines)

        def do():
            if read(p) != seen:
                plan.left.append("~/.zshrc changed after the plan was made — not written; run detach again")
                return
            with open(p, "w", encoding="utf-8") as f:
                f.write(new)
        plan.act("~/.zshrc: remove the wizard block (%d)" % hit, do)
    if any("fh_audit_check.zsh" in l or l in (ZSH_BEGIN, ZSH_END) for l in out):
        plan.left.append("~/.zshrc: a line still sources fh_audit_check.zsh but is not the wizard's exact block")


def plan_settings(plan, path, cmds, keys):
    if not os.path.isfile(path):
        return
    try:
        cur = json.loads(read(path))
    except ValueError as e:
        raise HarnessError("cannot parse %s (%s) — left untouched" % (path, e))
    if not isinstance(cur, dict):
        raise HarnessError("%s is not a JSON object — left untouched" % path)
    stripped, removed = strip_settings(cur, cmds)
    for c in suspects_in(stripped, keys):
        plan.left.append("%s: FH-like hook that is not byte-equal to a shipped snippet (older version?) — %s"
                         % (path, c[:120]))
    bak = path + ".prewizard"
    restore = drop_bak = None
    if os.path.isfile(bak):
        try:
            prev_stripped, prev_fh = strip_settings(json.loads(read(bak)), cmds)
            if prev_stripped == stripped:
                if prev_fh:
                    drop_bak = bak     # a re-run's backup: it holds only FH hooks beyond what stays (codex R2)
                else:
                    restore = bak
        except ValueError:
            pass
    seen = read(path)
    if not removed and restore is None and drop_bak is None:
        if os.path.isfile(bak):
            plan.notes.append("%s: kept (it differs from your current settings — open it, delete it when done)" % bak)
        return

    def do():
        if read(path) != seen:      # another session wrote it after the plan (codex R2) — never overwrite their change
            plan.left.append("%s changed after the plan was made — not written; run detach again" % path)
            return
        if drop_bak:
            os.remove(drop_bak)
        if restore:
            shutil.copy2(restore, path)
            os.remove(restore)
        elif not stripped:
            os.remove(path)
        else:
            with open(path, "w", encoding="utf-8") as f:
                json.dump(stripped, f, indent=2, ensure_ascii=False)
                f.write("\n")
    how = ("restore your pre-wizard bytes from .prewizard" if restore
           else "delete the file (only FH hooks were in it)" if not stripped
           else "remove %d FH hook(s), keep the rest" % len(removed))
    plan.act("%s: %s" % (path, how), do)
    if os.path.isfile(bak) and not restore and not drop_bak:
        plan.notes.append("%s: kept (it differs from your current settings — open it, delete it when done)" % bak)


def plan_claude_local(plan, d):
    p = os.path.join(d, "CLAUDE.local.md")
    if not os.path.isfile(p):
        return
    s = read(p)
    block = "\n%s\n%s\n" % (COMPANION_HEAD, COMPANION_WIRING)
    if block in s:
        new = s.replace(block, "", 1)

        def do():
            if new:
                with open(p, "w", encoding="utf-8") as f:
                    f.write(new)
            else:
                os.remove(p)
        plan.act("%s: remove the wizard's companion-store section" % p, do)
    elif COMPANION_HEAD in s:
        plan.left.append("%s: a «%s» section that is not the wizard's exact text" % (p, COMPANION_HEAD))


def plan_hookspath(plan, fh_dir):
    if not os.path.isdir(os.path.join(fh_dir, ".git")) and not os.path.isfile(os.path.join(fh_dir, ".git")):
        return
    r = subprocess.run(["git", "-C", fh_dir, "config", "--local", "--get", "core.hooksPath"],
                       capture_output=True, text=True)
    v = r.stdout.strip()
    if r.returncode not in (0, 1):
        raise HarnessError("git config read failed in %s: %s" % (fh_dir, r.stderr.strip()))
    if v == "templates/.git-hooks":
        plan.act("%s: unset core.hooksPath (templates/.git-hooks)" % fh_dir,
                 lambda: subprocess.run(["git", "-C", fh_dir, "config", "--local", "--unset", "core.hooksPath"],
                                        check=True))
    elif v and "templates/.git-hooks" in v:
        plan.left.append("%s: core.hooksPath=%s (not the wizard's value — left alone)" % (fh_dir, v))


def plan_sentinels(plan, home, project):
    d = os.path.join(home, ".cc_sentinels")
    if not os.path.isdir(d):
        return
    mine = sorted(glob.glob(os.path.join(d, glob.escape(project) + "_wizard_*")))
    rest = sorted(set(os.listdir(d)) - {os.path.basename(m) for m in mine})

    def do():
        for m in mine:
            os.remove(m)
        if not os.listdir(d):
            os.rmdir(d)
    if mine:
        plan.act("~/.cc_sentinels: remove %s" % ", ".join(os.path.basename(m) for m in mine), do)
    if rest:
        plan.notes.append("~/.cc_sentinels: %d other file(s) kept (other projects or audit stamps): %s"
                          % (len(rest), ", ".join(rest[:6])))


def _exclude_path(proj):
    """.git/info/exclude through git itself — in a worktree .git is a file and the exclude lives in the common dir."""
    r = subprocess.run(["git", "-C", proj, "rev-parse", "--path-format=absolute", "--git-path", "info/exclude"],
                       capture_output=True, text=True)
    return r.stdout.strip() if r.returncode == 0 and r.stdout.strip() else None


def plan_copies(plan, fh_dir, proj):
    excl = _exclude_path(proj)
    removed = set()
    for src, rel in COPIED_TEMPLATES:
        dst = os.path.join(proj, rel)
        tpl = os.path.join(fh_dir, "templates", src)
        if os.path.isfile(dst):
            # bytes, not text: universal-newline reading called a CRLF-converted copy «unchanged» (codex R1)
            if os.path.isfile(tpl) and read_bytes(dst) == read_bytes(tpl):
                plan.act("%s: remove (unchanged copy of templates/%s)" % (dst, src),
                         lambda dst=dst: os.remove(dst))
                removed.add(rel)
            else:
                plan.left.append("%s: you edited this copy of templates/%s — kept" % (dst, src))
        elif not os.path.lexists(dst):
            removed.add(rel)            # copy already gone (a rerun after a partial apply, codex R2) — its exclude goes too
    if excl and os.path.isfile(excl) and removed:
        lines = read(excl).split("\n")
        # only the lines of copies removed above — a kept copy keeps its exclude, or git would start staging it (codex R1)
        drop = removed | {"/" + rel for rel in removed}
        new = [l for l in lines if l.strip() not in drop]
        if new != lines:
            def do():
                with open(excl, "w", encoding="utf-8") as f:
                    f.write("\n".join(new))
            plan.act("%s: remove the wizard's exclude line(s)" % excl, do)


def plan_rules_dir(plan, proj):
    """Remove .claude/rules and .claude when the steps above leave them empty (checked at apply time)."""
    def do():
        for d in (os.path.join(proj, ".claude", "rules"), os.path.join(proj, ".claude")):
            if os.path.isdir(d) and not os.listdir(d):
                os.rmdir(d)
    plan.actions.append((None, do))


def plan_plugin(plan):
    def do():
        for argv in (["claude", "plugin", "uninstall", "fh-meta@forge-harness"],
                     ["claude", "plugin", "marketplace", "remove", "forge-harness"]):
            try:
                r = subprocess.run(argv, capture_output=True, text=True)
                rc, msg = r.returncode, (r.stdout + r.stderr).strip()
            except OSError as e:
                rc, msg = 127, str(e)
            print("   $ %s → rc=%d %s" % (" ".join(argv), rc, msg[:160]))
            if rc != 0:      # a failed uninstall is a trace left, not a success (codex R1)
                plan.left.append("plugin: `%s` failed (rc=%d) — run it yourself" % (" ".join(argv), rc))
    plan.act("claude plugin: uninstall fh-meta@forge-harness · remove the forge-harness marketplace", do)


def main(argv=None):
    ap = argparse.ArgumentParser(
        description="Undo what /install-wizard wrote (dry run unless --apply). Machine-wide: the ~/.zshrc block and "
                    "the FH clone's hooks and core.hooksPath go too, not only --project.",
        epilog="exit: 0 no recognised FH trace left · 1 something FH-like is LEFT (listed) for a human look · "
               "10 could not read something it needed · 11 bad arguments")
    ap.add_argument("--project", default=os.getcwd(), help="project the wizard ran in (default: cwd)")
    ap.add_argument("--fh-dir", default=os.environ.get("FH_DIR") or os.path.dirname(os.path.dirname(
        os.path.abspath(__file__))), help="FH clone/package (default: $FH_DIR, else this script's repo)")
    ap.add_argument("--home", default=os.path.expanduser("~"), help="home directory to clean (default: ~)")
    ap.add_argument("--apply", action="store_true", help="carry out the plan (default: print it, change nothing)")
    ap.add_argument("--plugin", action="store_true",
                    help="also uninstall fh-meta@forge-harness and remove the forge-harness marketplace entry")
    try:
        a = ap.parse_args(argv)
    except SystemExit as e:
        return 11 if e.code else 0
    proj = os.path.abspath(a.project)
    fh = os.path.abspath(a.fh_dir)
    plan = Plan(a.apply)
    try:
        cmds, keys = snippet_commands(fh)
        plan_zshrc(plan, a.home)
        seen = set()
        for d in (proj, fh):
            if d in seen:
                continue
            seen.add(d)
            for name in ("settings.json", "settings.local.json"):
                plan_settings(plan, os.path.join(d, ".claude", name), cmds, keys)
            plan_claude_local(plan, d)
        plan_hookspath(plan, fh)
        plan_sentinels(plan, a.home, os.path.basename(proj))
        plan_copies(plan, fh, proj)
        plan_rules_dir(plan, proj)
        if a.plugin:
            plan_plugin(plan)
    except HarnessError as e:
        print("fh-detach: HARNESS-ERROR — %s" % e, file=sys.stderr)
        return 10
    steps = [l for l, _ in plan.actions if l]
    print("fh-detach %s — %d step(s)" % ("APPLY" if a.apply else "DRY RUN (nothing changed; add --apply)", len(steps)))
    for l in steps:
        print("  - " + l)
    if a.apply:
        for label, fn in plan.actions:
            try:
                fn()
            except (OSError, subprocess.CalledProcessError) as e:
                print("fh-detach: HARNESS-ERROR at «%s»: %s" % (label, e), file=sys.stderr)
                return 10
    for n in plan.notes:
        print("  note: " + n)
    for l in plan.left:
        print("  LEFT (look at it): " + l)
    if not a.plugin:
        print("  plugin: if you installed it, run `claude plugin uninstall fh-meta@forge-harness` (or pass --plugin)")
    if plan.left:
        return 1
    if not a.apply and steps:
        return 0
    return 0


if __name__ == "__main__":
    sys.exit(main())
