#!/usr/bin/env python3
"""heavy_skill_smell.py — advisory: does this skill folder carry its own mini-harness?

usage: python3 scripts/heavy_skill_smell.py <skill or plugin folder> [--json]

A «heavy skill» is a skill that embeds its own gates, rules and checks. In FH that work is split three ways
(knowledge/shared/harness-core/heavy_skill_to_cartridge.md):
  craft  — the skill body: how to do the job
  checks — the cartridge's own lanes and observe-only hooks; they may only make the result stricter
  floor  — what the FH core already enforces; delete it from the cartridge, and route the cartridge's
           irreversible actions to a core gate with `touches_irreversible` + `core_route` in fh-module.yaml

This script reads every text file under the folder and flags lines that look like embedded harness:
  P1 permission-decision  the skill decides permissions itself (permissionDecision, updatedInput, permissions.allow …)
  P2 hook-config          hook wiring (a "hooks" block, PreToolUse/SessionStart/… event names)
  P3 settings-write       writes settings*.json, core.hooksPath, .git/hooks, GIT_CONFIG_*
  P4 irreversible-action  push / release / publish / delete / history rewrite (patterns from fh_module_check.py)
  P5 own-confirm          the skill asks / confirms / approves before an irreversible step on its own
  P6 floor-restatement    restates a core floor rule (fail-closed, company data stays in, UNMEASURED is not PASS)
  P7 final-verdict-claim  claims the last word, or skips / bypasses another gate (--no-verify, «verdict is final»)
For each hit it prints where the line should go, and at the end a proposed split.

ADVISORY ONLY. Exit 0 = the folder was read (with or without smells). Exit 2 = it could not be read (missing
folder, no readable text file, or ANY file or folder under it unreadable — the counts are then partial) — UNMEASURED,
never «0 smells». Any internal error is also exit 2. It never exits 1 and never blocks anything.
Zero smells means NOT-DETECTED by these seven pattern families, not «no embedded harness»: these are lexical
tripwires (they miss other spellings and other languages, and comments that mention a pattern are flagged).
An irreversible line (P4) in a folder whose fh-module.yaml declares touches_irreversible + core_route is printed as
ROUTED, not as a smell — that is the refactored shape. A line that names the core gate it defers to (core_route, pre-publish, destructive-op, «the core») is a pointer,
not a duplicate, and is not flagged as P5/P6/P7. Standard library only.
"""
import json
import os
import re
import sys

try:
    sys.stdout.reconfigure(errors="backslashreplace")   # an ascii terminal must not turn a report into a traceback
except (AttributeError, ValueError):
    pass
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
try:  # single source for the irreversible-verb and core-disabling patterns
    from fh_module_check import IRREVERSIBLE_VERBS, CORE_DISABLING
except Exception as e:  # noqa: BLE001 — any failure to load the shared lists is UNMEASURED, not a fallback copy
    print("UNMEASURED: could not load pattern lists from fh_module_check.py (%s)" % e)
    sys.exit(2)

TEXT_EXT = {".md", ".txt", ".sh", ".bash", ".zsh", ".py", ".js", ".mjs", ".cjs", ".ts", ".json", ".yaml", ".yml",
            ".toml", ".ini", ".cfg", ""}
SKIP_DIRS = {".git", "node_modules", "__pycache__", ".venv", "venv"}

HOOK_EVENTS = r"PreToolUse|PermissionRequest|PostToolUse|SessionStart|SessionEnd|UserPromptSubmit|SubagentStop|PreCompact|\"Stop\""
POINTER = re.compile(r"core_route|pre-publish|public-surface-audit|destructive-op|\bthe core\b|\bFH core\b|코어", re.I)
IRREV_WORD = r"(push|publish|release|deploy|delete|remove|force|rm -|tag|배포|발행|삭제|푸시)"

CLASSES = [
    ("P1", "permission-decision",
     [r"permissionDecision", r"updatedInput", r"\"decision\"\s*:\s*\"(block|approve|allow|deny)\"",
      r"permissions\.(allow|deny)", r"\"(allow|deny)\"\s*:\s*\[", r"\"behavior\"\s*:"],
     "floor", "delete — permission decisions belong to the core; a cartridge hook may only observe (SessionEnd in v0)"),
    ("P2", "hook-config",
     [r"\"hooks\"\s*:", r"hookEventName", r"\b(%s)\b" % HOOK_EVENTS.replace('\\"Stop\\"', 'Stop')],  # event names: see FENCE_ONLY
     "checks", "move the check into a lane the cartridge ships (calibration command); only a SessionEnd observe-only hook may stay, declared in fh-module.yaml provides.hooks"),
    ("P3", "settings-write",
     [p for p in CORE_DISABLING if p not in (r"permissionDecision", r"updatedInput", r"\bbehavior\b", r"additionalContext")],
     "floor", "delete — the core installs hooks and settings; a cartridge never writes them"),
    ("P4", "irreversible-action", list(IRREVERSIBLE_VERBS),
     "floor", "declare touches_irreversible (publish|delete|history) + core_route in fh-module.yaml; keep the craft, drop the skill's own gate around it"),
    ("P5", "own-confirm",
     [r"\b(always |must |first )?(ask|confirm with|check with)\s+(the\s+)?(user|operator|human|owner)\b[^\n]*\b(before|prior to)\b",
      r"\b(always|must)\s+(ask|confirm|get approval)\b", r"\b(ask|confirm|prompt)\w*\s+before\b[^\n]*\b%s" % IRREV_WORD,
      r"\b(before|prior to)\b[^\n]*\b(ask|confirm|check)\w*\s+(with\s+)?(the\s+)?(user|operator|human|owner)\b",
      r"\basks?\s+for\s+(confirmation|approval)\b", r"\bread\s+-p\b", r"\[y/N\]",
      r"(확인|승인)[^\n]*(받|묻)[^\n]*(푸시|배포|발행|삭제|push|publish|release)",
      r"(푸시|배포|발행|삭제)[^\n]*(전에|before)[^\n]*(확인|승인)"],
     "floor", "delete — the core gate named in core_route asks; two askers on one action is the «two floors» problem"),
    ("P6", "floor-restatement",
     [r"(tool|tooling|check|gate)\w*[^\n]*(missing|down|unavailable)[^\n]*\bfail[- ]closed", r"(tool|tooling)[^\n]*(missing|down|unavailable)[^\n]*\b(stop|block|abort)",
      r"\b(customer|company|internal)\b[^\n]*\bdata\b[^\n]*\b(outside|leave|external|never send)",
      r"never send[^\n]*\b(customer|company|internal)\b", r"UNMEASURED[^\n]*\b(never|not|isn't|is not)\b[^\n]*\bPASS\b",
      r"(회사|고객)[^\n]*(데이터|자료)[^\n]*(외부|밖|반출)"],
     "floor", "delete, or replace with one line that defers to the core floor; keep only a stricter domain rule (e.g. «a missing engine is not agreement»)"),
    ("P7", "final-verdict-claim",
     [r"--no-verify", r"\b(verdict|decision|result)\b[^\n]*\b(is )?final\b", r"\b(skip|bypass|ignore|override|disable)\s+(the\s+|any\s+|all\s+)?(global|core|other|pre-commit|pre-push)\s+([\w-]+\s+)?(hook|gate|check)s?\b",
      r"(최종 판정|판정이 최종|게이트 (무시|우회|건너))"],
     "floor", "delete — a cartridge may add or tighten, never take the last word or skip another gate"),
]
# hook event names are matched case-sensitively («Stop» the event, not «stop» the verb); everything else ignores case
COMPILED = [(cid, name, [re.compile(p, 0 if cid == "P2" else re.I) for p in pats], part, move)
            for cid, name, pats, part, move in CLASSES]
POINTER_EXEMPT = {"P5", "P6"}          # never P7: «ignore the core gate» names the core too
P7_RX = next(c[2] for c in COMPILED if c[0] == "P7")
# In markdown, hook event names are prose («not included: the SessionStart hook», «Stop.») unless inside a code fence.
# Markdown frontmatter `description:` lines describe what users ask; they are not the skill confirming anything.
MD_EXT = {".md", ".txt"}
# Removal verbs inside a test lane's own scratch cleanup (trap … rm, mktemp dirs, test_* files) act on fixtures,
# not on user data; push / publish / release / history verbs are still flagged there.
# Shape (b) of the guide: the cartridge stops before an irreversible step and ends with a markdown line starting
# «ready:» (the push then runs in the session, under the core gate). Reported as HANDOFF, not as P4. A heavy skill can
# also write «ready: git push» — so the line is printed, never hidden.
HANDOFF = re.compile(r"^[\s>*`«-]*ready:", re.I)
# The split table the guide asks for («| old piece | deleted — … |») quotes the very rules it removed. A markdown table
# row whose LAST cell starts with «deleted» or «routed» is that record, not the rule. Residual: a heavy skill could
# park a live rule in such a row — the row is still printed under NOTE so a reader sees it.
SPLIT_ROW = re.compile(r"^\s*\|.*\|\s*(deleted|routed)\b[^|]*\|\s*$", re.I)
PROSE_HOOK_INSTALL = re.compile(r"\b(install|register|add|wire|set up|enable)\w*\b[^\n]*\b(%s)\b" % HOOK_EVENTS.replace('\\"Stop\\"', 'Stop'), re.I)
# scratch cleanup = an rm whose target is a shell variable («rm -rf "$W"», «rm -r "$R/x"»), never an absolute or ~ path
RM_CMD = re.compile(r"\brm\s+((?:-\w+\s+)*)([^;&|'\n]*)")


def scratch_only(line):
    """True when every rm on the line removes only $VARIABLE paths («rm -rf "$W"», «rm -r "$R/x"»)."""
    cmds = RM_CMD.findall(line)
    if not cmds:
        return False
    for _flags, targets in cmds:
        toks = targets.split()
        if not toks or not all(re.match(r"^[\"]?\$\{?\w+", tk) for tk in toks):
            return False
    return True
RM_FAMILY = re.compile(r"\brm\b|rmtree|rmSync|rmdirSync|unlinkSync|os\.remove|os\.unlink|-delete|\bclean\b", re.I)


ROUTE_RE = re.compile(r"^touches_irreversible:\s*(publish|delete|history)\s*(#.*)?$")
CORE_ROUTE_RE = re.compile(r"^core_route:\s*(pre-publish|public-surface-audit|destructive-op)\s*(#.*)?$")
VALID_ROUTES = {"publish": {"pre-publish", "public-surface-audit"}, "delete": {"destructive-op"}, "history": {"destructive-op"}}


def read_route(path, root):
    """(class, route, file) when this fh-module.yaml declares an irreversible class AND a matching core_route, else None.
    Line-level read: enough to tell «declared» from «not declared»; fh_module_check.py check is what validates it."""
    try:
        lines = open(path, encoding="utf-8").read().splitlines()
    except (OSError, UnicodeDecodeError):
        return None
    cls = [m.group(1) for m in map(ROUTE_RE.match, lines) if m]
    rt = [m.group(1) for m in map(CORE_ROUTE_RE.match, lines) if m]
    if cls and rt and rt[0] in VALID_ROUTES[cls[0]]:   # a mismatched pair routes nothing
        return cls[0], rt[0], os.path.relpath(path, root)
    return None


def manifests(root):
    out = []
    for d, dirs, files in os.walk(root):
        dirs[:] = [x for x in dirs if x not in SKIP_DIRS]
        out += [os.path.join(d, f) for f in files if f in ("fh-module.yaml", "fh-module.yml")]
    return out


def owning_route(path, root, all_manifests):
    """The route of the module that owns this file: the nearest manifest in the file's folder or an ancestor (up to
    root); if none, the only manifest under root when there is exactly one. Several manifests and no ancestor = none."""
    d = os.path.dirname(os.path.abspath(path)); top = os.path.abspath(root)
    while True:
        for f in ("fh-module.yaml", "fh-module.yml"):
            if os.path.isfile(os.path.join(d, f)):
                return read_route(os.path.join(d, f), root)
        if d == top or not d.startswith(top):
            break
        d = os.path.dirname(d)
    # the single-manifest fallback is for plugin-level files (README, docs); a file inside another skill folder that
    # has no manifest of its own does not inherit a sibling's route
    rel_parts = os.path.relpath(os.path.abspath(path), top).split(os.sep)
    if any(part == "skills" for part in rel_parts[:-2]):   # skills/<name>/… — not skills/README.md
        return None
    return read_route(all_manifests[0], root) if len(all_manifests) == 1 else None


# #1: which class an irreversible match belongs to; it is ROUTED only when that class is the declared one
def action_class(text):
    t = text.lower()
    if re.search(r"reset\b.*--hard|filter-branch|filter-repo|\brebase\b|--amend|reflog\b.*expire", t):
        return "history"
    if re.search(r"\brm\b|rmtree|rmsync|rmdirsync|unlinksync|os\.remove|os\.unlink|\bclean\b|-delete|branch\b.*-d|tag\b.*-d|update-ref\b.*-d|\bdelete\b", t):
        return "delete"
    return "publish"


def iter_files(root, walk_errors):
    for d, dirs, files in os.walk(root, onerror=lambda e: walk_errors.append((getattr(e, "filename", "?"), str(e)))):
        dirs[:] = sorted(x for x in dirs if x not in SKIP_DIRS)
        for f in sorted(files):
            p = os.path.join(d, f)
            if os.path.splitext(f)[1].lower() in TEXT_EXT and not os.path.islink(p):
                yield p


def scan(root):
    smells, read, unreadable, routed, split_rows = [], [], [], [], []
    all_manifests = manifests(root)
    walk_errors = []
    for p in iter_files(root, walk_errors):
        try:
            with open(p, encoding="utf-8") as fh:
                lines = fh.read().splitlines()
        except (OSError, UnicodeDecodeError) as e:
            unreadable.append((os.path.relpath(p, root), str(e)))
            continue
        rel = os.path.relpath(p, root)
        read.append(rel)
        is_md = os.path.splitext(p)[1].lower() in MD_EXT
        route = owning_route(p, root, all_manifests) if is_md else None
        is_test = os.path.basename(p).startswith("test_")
        in_fence = False
        # frontmatter = the block between a first line «---» and the next «---»; only there is «description:» metadata
        fm_end = 0
        if is_md and lines and lines[0].strip() == "---":
            fm_end = next((k + 1 for k in range(1, len(lines)) if lines[k].strip() == "---"), 0)
        for i, line in enumerate(lines, 1):
            if is_md and (line.lstrip().startswith("```") or line.lstrip().startswith("~~~")):
                in_fence = not in_fence
                continue
            if is_md and SPLIT_ROW.match(line):
                split_rows.append({"file": os.path.relpath(p, root), "line": i, "text": line.strip()[:160]})
                continue
            # #5: a line that names the core only counts as a pointer when it does not also bypass or claim the last word
            is_pointer = bool(POINTER.search(line)) and not any(rx.search(line) for rx in P7_RX)
            is_desc = is_md and 0 < i < fm_end and line.startswith("description:")
            for cid, name, pats, part, move in COMPILED:
                if cid in POINTER_EXEMPT and is_pointer:
                    continue
                if cid == "P5" and is_desc:
                    continue
                hits = [rx for rx in pats if rx.search(line)]
                if cid == "P2" and is_md and not in_fence:
                    # prose: an event name counts only with an install verb («install a PreToolUse hook»)
                    hits = [rx for rx in hits if "hooks" in rx.pattern or "hookEventName" in rx.pattern]
                    if not hits and PROSE_HOOK_INSTALL.search(line):
                        hits = [PROSE_HOOK_INSTALL]
                if cid == "P4" and (is_test or re.search(r"\btrap\b", line)) and scratch_only(line):
                    hits = [rx for rx in hits if not RM_FAMILY.match(rx.search(line).group(0))]
                if hits and cid == "P4" and is_md and HANDOFF.match(line):
                    routed.append({"file": rel, "line": i, "text": line.strip()[:160], "via": "HANDOFF (ready: line — the session runs it under the core gate)"})
                    continue
                if hits and cid == "P4" and route and is_md and \
                        all(action_class(rx.search(line).group(0)) == route[0] for rx in hits):
                    routed.append({"file": rel, "line": i, "text": line.strip()[:160], "via": "%s → %s (%s)" % route})
                    continue
                if hits:
                    smells.append({"class": cid, "name": name, "file": rel, "line": i,
                                   "text": line.strip()[:160], "part": part, "move": move})
    unreadable.extend((os.path.relpath(str(f), root), "folder not listable: " + e) for f, e in walk_errors)
    return smells, read, unreadable, routed, split_rows


def split(smells, read):
    by_file = {}
    for s in smells:
        by_file.setdefault(s["file"], set()).add(s["part"])
    craft = [f for f in read if f not in by_file or f.endswith("SKILL.md")]
    checks = sorted({s["file"] for s in smells if s["part"] == "checks"})
    floor = sorted({"%s:%d %s" % (s["file"], s["line"], s["class"]) for s in smells if s["part"] == "floor"})
    return {"craft": craft, "checks": checks, "floor": floor}


def main(argv):
    args = [a for a in argv[1:] if a != "--json"]
    as_json = "--json" in argv[1:]
    if len(args) != 1:
        print("usage: python3 scripts/heavy_skill_smell.py <skill or plugin folder> [--json]"); return 2
    root = args[0]
    if not os.path.isdir(root):
        print("UNMEASURED: not a folder: %s" % root); return 2
    smells, read, unreadable, routed, split_rows = scan(root)
    if not read:
        print("UNMEASURED: no readable text file under %s%s" % (root, (" (unreadable: %d)" % len(unreadable)) if unreadable else ""))
        return 2
    incomplete = bool(unreadable)
    sp = split(smells, read)
    counts = {cid: sum(1 for s in smells if s["class"] == cid) for cid, *_ in CLASSES}
    if as_json:
        print(json.dumps({"folder": root, "files_read": len(read), "unreadable": unreadable, "smells": smells,
                          "counts": counts, "split": sp, "routed": routed, "split_rows": split_rows, "advisory": True,
                          "complete": not incomplete}, ensure_ascii=False, indent=1))
        return 2 if incomplete else 0
    print("heavy_skill_smell: %s — read %d file(s)%s" % (root, len(read), (", unreadable %d" % len(unreadable)) if unreadable else ""))
    for s in smells:
        print("SMELL %s %s %s:%d  %s" % (s["class"], s["name"], s["file"], s["line"], s["text"]))
        print("  → %s: %s" % (s["part"], s["move"]))
    for r in routed:
        kind = "HANDOFF" if r["via"].startswith("HANDOFF") else "ROUTED"
        print("%s %s:%d  %s  — %s" % (kind, r["file"], r["line"], r["text"], r["via"]))
    if split_rows:
        print("NOTE %d split-table row(s) (last cell «deleted»/«routed») not scanned — they record a removal; check none is a live rule" % len(split_rows))
    print("SUMMARY " + " ".join("%s=%d" % kv for kv in counts.items()) + "  (smells=%d)" % len(smells))
    if smells:
        print("SPLIT (proposed — the author decides)")
        print("  craft:  " + (", ".join(sp["craft"]) or "-") + "  (keep; SKILL.md minus the lines listed under floor)")
        print("  checks: " + (", ".join(sp["checks"]) or "-") + "  (turn into lanes the manifest's calibration runs)")
        print("  floor:  " + (", ".join(sp["floor"]) or "-") + "  (delete; route irreversible actions with core_route)")
    else:
        print("NOT-DETECTED by these 7 pattern families — not proof that no embedded harness is present")
    print("NOTE advisory: exit 0 means «read», not «clean». Guide: knowledge/shared/harness-core/heavy_skill_to_cartridge.md")
    if incomplete:
        for f, e in unreadable:
            print("UNREADABLE %s — %s" % (f, e))
        print("UNMEASURED: %d file(s)/folder(s) could not be read — the scan is incomplete, so no count above is a total" % len(unreadable))
        return 2
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv))
    except SystemExit:
        raise
    except BaseException as e:  # noqa: BLE001 — advisory tool: any failure is UNMEASURED (2), never 1
        print("UNMEASURED: heavy_skill_smell failed: %s: %s" % (type(e).__name__, e))
        sys.exit(2)
