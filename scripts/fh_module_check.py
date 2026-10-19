#!/usr/bin/env python3
"""fh_module_check.py - FH module contract v0 checker (spec: knowledge/shared/harness-core/fh_module_contract.md).

Subcommands
  check  <manifest> [--repo DIR] [--installed DIR]   install-time check
  merge  <manifest> <manifest>...                    strictest-wins merge of constraints
  remove <id> --installed DIR                        removal plan (refused while a dependant exists)
  export <manifest> --out DIR [--repo DIR]           copy only what the module declares into DIR, then run its
                                                     calibration THERE: rc 0 = it runs standalone (no FH around it)

Exit codes: 0 OK . 1 BLOCK . 2 UNMEASURED (unreadable / tooling down / empty core list) .
3 OK-but-UNCALIBRATED (valid, no verdict entry points, calibration declared UNCALIBRATED; never a clean pass).
Fail closed: nothing unreadable, unknown or empty ever exits 0.
"""
import argparse, glob, hashlib, json, os, re, shutil, subprocess, sys

OK, BLOCK, UNMEASURED, UNCAL = 0, 1, 2, 3

# ---- closed enums (spec section 2) ------------------------------------------------------------
IRREVERSIBLE = ["none", "publish", "delete", "history"]
DATA_CLASS = ["public", "private", "company"]            # permissive -> strictest (residency axis)
# permission axes of capability_composition_contract.md, permissive -> strictest
AXES = {
    "approval": ["auto", "notify", "ask", "ask-per-item", "forbidden"],
    "reversibility": ["reversible", "unknown", "irreversible"],
    "residency": ["public", "operator-private", "company"],
    "degrade": ["advisory", "fail-closed"],
}
HOOK_EVENTS = ["PreToolUse", "PermissionRequest", "PostToolUse", "SessionStart", "SessionEnd", "Stop",
               "SubagentStop", "UserPromptSubmit", "PreCompact", "git-pre-commit", "git-pre-push"]
# Added hooks may only OBSERVE. v0 opens only events whose output cannot steer the session: a text scan of the
# hook body cannot prove a PreToolUse/PermissionRequest hook never emits a decision (decision.behavior, a key built
# from pieces) nor that a PostToolUse hook never injects additionalContext — so those are closed, not scanned.
GATING_EVENTS = {"PreToolUse", "PermissionRequest"}
OBSERVE_ONLY_EVENTS = {"SessionEnd"}
INTERPRETERS = {"bash", "sh", "python3", "node"}
CMD_FORBID = re.compile(r"[$`;&|<>\\\n\r(){}*?!\"'~]")
CMD_ARG = re.compile(r"^[A-Za-z0-9_./=:,@%+-]+$")
CORE_DISABLING = [r"hooksPath", r"core\.hooks", r"GIT_CONFIG_\w+", r"GIT_DIR[^\n]*hooks",
                  r"\.git/hooks", r"\bhooks?/(pre|post)-", r"settings[\w.-]*\.json",
                  r"permissionDecision", r"updatedInput", r"\bbehavior\b", r"additionalContext", r"\bchmod\b[^\n]*hook", r"\brm\b[^\n]*hook"]
IRREVERSIBLE_VERBS = [r"\bgit\b[^\n]*\bpush\b", r"\brm\b[^\n]*(\s-\w*r|--recursive)",
                      r"\bgit\b[^\n]*\bbranch\b[^\n]*\s-D", r"\bgit\b[^\n]*\breset\b[^\n]*--hard",
                      r"\bnpm\b[^\n]*\bpublish\b", r"\btwine\b[^\n]*\bupload\b",
                      r"\bgh\b[^\n]*\b(repo|release)\b", r"--visibility",
                      r"\bgit\b[^\n]*\b(filter-branch|filter-repo|rebase)\b",
                      r"\brm\b[^\n]*\s-\w*f", r"\b(rmtree|rmSync|rmdirSync|unlinkSync|os\.remove|os\.unlink)\b", r"\bgit\b[^\n]*\bclean\b[^\n]*-\w*f",
                      r"\bfind\b[^\n]*-delete", r"\bgit\b[^\n]*\btag\b[^\n]*\s-d", r"\bgh\b[^\n]*\bapi\b[^\n]*(DELETE|PATCH|PUT|POST)",
                      r"--amend", r"\breflog\b[^\n]*expire", r"\bupdate-ref\b[^\n]*-d"]
DATA_TO_RESIDENCY = {"public": "public", "private": "operator-private", "company": "company"}
# merge never lands below the core floor
# approval=ask is a FLOOR here, not a default: merge never emits less than ask, because the core
# irreversible gates are ask-level. reversibility=irreversible is seeded too (assume the worst).
CORE_FLOOR = {"approval": "ask", "degrade": "fail-closed", "reversibility": "irreversible"}
HOOK_ACTIONS = ["add"]            # override / disable / reorder are known words, never allowed
HOOK_ACTIONS_KNOWN = ["add", "override", "disable", "reorder"]
HOOK_ORDER = ["append"]           # prepend is a reorder
HOOK_ORDER_KNOWN = ["append", "prepend"]
# irreversible class -> (core gate name, repo-relative file that must exist)
CORE_GATES = {
    "publish": {"pre-publish": "templates/PRE-PUBLISH-CHECKLIST.md",
                "public-surface-audit": "templates/PRE-PUBLISH-CHECKLIST.md"},
    "delete": {"destructive-op": "templates/predelete_check.sh"},
    "history": {"destructive-op": "templates/predelete_check.sh"},
}
TOP_KEYS = {"id", "version", "provides", "adds_constraints", "touches_irreversible", "core_route",
            "data_class", "requires", "calibration", "records", "files"}
PROVIDES_KEYS = {"skills", "agents", "hooks", "verdicts"}
HOOK_KEYS = {"event", "matcher", "command", "action", "order", "target"}
VERDICT_KEYS = {"entry", "command", "exit_codes"}
EXIT_KEYS = {"pass", "block", "unmeasured"}
REQ_KEYS = {"modules", "core_min"}
SEMVER = re.compile(r"^\d+\.\d+\.\d+$")
SLUG = re.compile(r"^[a-z][a-z0-9-]{0,62}$")


class Verdict:
    def __init__(self):
        self.blocks, self.unmeasured, self.notes = [], [], []
        self.uncal = False
    def block(self, m): self.blocks.append(m)
    def unm(self, m): self.unmeasured.append(m)
    def code(self):
        if self.blocks: return BLOCK
        if self.unmeasured: return UNMEASURED
        return UNCAL if self.uncal else OK
    def report(self):
        for m in self.blocks: print("BLOCK: " + m)
        for m in self.unmeasured: print("UNMEASURED: " + m)
        for m in self.notes: print("NOTE: " + m)
        print({OK: "RESULT: OK", UNCAL: "RESULT: OK (UNCALIBRATED)", BLOCK: "RESULT: BLOCK", UNMEASURED: "RESULT: UNMEASURED"}[self.code()])


def load_yaml(path):
    """Return (data, err). err set on any unreadable / unparsable / non-mapping input."""
    try:
        import yaml
    except Exception as e:
        return None, "PyYAML unavailable (%s)" % e
    class Strict(yaml.SafeLoader):
        pass
    def cm(loader, node, deep=False):
        seen = set()
        for k, _ in node.value:
            kk = loader.construct_object(k, deep=True)
            if kk in seen:
                raise ValueError("duplicate key %r" % (kk,))
            seen.add(kk)
        return yaml.SafeLoader.construct_mapping(loader, node, deep)
    Strict.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, cm)
    try:
        with open(path, encoding="utf-8") as f:
            data = yaml.load(f, Loader=Strict)
    except UnicodeDecodeError as e:
        return None, "cannot read %s (not UTF-8)" % path
    except ValueError as e:
        return None, "duplicate key in %s (%s)" % (path, e)
    except Exception as e:
        return None, "cannot read %s (%s)" % (path, type(e).__name__)
    if not isinstance(data, dict) or not data:
        return None, "%s is empty or not a mapping" % path
    return data, None


def default_repo():
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def core_hooks(repo):
    """Core hook identifiers = script basenames wired in tracked settings snippets + git hook names."""
    names = set()
    for f in sorted(glob.glob(os.path.join(repo, "templates", "settings.*.snippet.json"))):
        try:
            d = json.load(open(f, encoding="utf-8"))
        except Exception:
            return None, "unreadable core hook config %s" % f
        stack = [d.get("project_settings_json", {})]
        while stack:
            x = stack.pop()
            if isinstance(x, dict):
                if isinstance(x.get("command"), str):
                    for tok in re.findall(r"[\w./$\"{}-]+\.(?:sh|py)", x["command"]):
                        names.add(os.path.basename(tok.strip('"')))
                stack.extend(x.values())
            elif isinstance(x, list):
                stack.extend(x)
    for f in glob.glob(os.path.join(repo, "templates", ".git-hooks", "*")):
        names.add(os.path.basename(f))
    if not names:
        return None, "core hook list is empty (a gate list that is empty passes everything)"
    return names, None


def resolve_cmd(cmd, repo):
    """Command-shape allowlist: exactly `bash|sh|python3|node <repo-relative file> [simple args]`.
    Returns (abs_path, kind, msg); kind in (None, 'block', 'unm')."""
    if not isinstance(cmd, str) or not cmd.strip():
        return None, "block", "command missing"
    if CMD_FORBID.search(cmd):
        return None, "block", "command contains a shell metacharacter"
    if re.search(r"\b(eval|base64)\b", cmd, re.I):
        return None, "block", "command mentions eval/base64"
    t = cmd.split()
    if t[0] not in INTERPRETERS or len(t) < 2:
        return None, "block", "command must be `%s <repo-relative file> [args]`" % "|".join(sorted(INTERPRETERS))
    if "-c" in t:
        return None, "block", "command uses -c"
    f = t[1]
    if f.startswith("/") or f.startswith("-") or ".." in f.split("/") or not CMD_ARG.match(f):
        return None, "block", "command file must be a plain repo-relative path (got %r)" % f
    if not all(CMD_ARG.match(x) for x in t[2:]):
        return None, "block", "command args must be simple tokens"
    for x in t[2:]:
        v = x.split("=", 1)[1] if x.startswith("-") and "=" in x else x
        if v.startswith("/") or ".." in v.split("/"):
            return None, "block", "command args must not name absolute paths or .. (got %r)" % x
    full = os.path.join(repo, f)
    rr = os.path.realpath(repo)
    if os.path.commonpath([rr, os.path.realpath(full)]) != rr:
        return None, "block", "command file resolves outside the repo"
    if not os.path.isfile(full):
        return None, "unm", "referenced file %s does not exist" % f
    return full, None, ""


def scan_text(text, where, vd, irrev):
    text = re.sub(r"\\\r?\n", " ", text)   # a line continuation (git \ ⏎ push) is one command
    for pat in CORE_DISABLING:
        if re.search(pat, text, re.I | re.M):
            vd.block("%s matches core-disabling pattern /%s/ (added hooks may only observe)" % (where, pat))
    if irrev:
        for pat in IRREVERSIBLE_VERBS:
            if re.search(pat, text, re.I | re.M):
                vd.block("%s contains an irreversible verb /%s/ but touches_irreversible=none" % (where, pat))


def check_command(cmd, where, vd, repo, irrev):
    """Shape allowlist, then open the one referenced file and run the same lexical scans (case-insensitive)."""
    full, kind, msg = resolve_cmd(cmd, repo)
    if kind == "block":
        vd.block("%s: %s" % (where, msg)); return
    if kind == "unm":
        vd.unm("%s: %s" % (where, msg)); return
    try:
        raw = open(full, "rb").read()
    except Exception as e:
        vd.unm("%s: cannot read %s (%s)" % (where, full, type(e).__name__)); return
    vd.notes.append("sha256 %s %s" % (os.path.relpath(full, repo), hashlib.sha256(raw).hexdigest()))
    scan_text(cmd, where + ".command", vd, irrev)
    scan_text(raw.decode("utf-8", "replace"), where + " file " + os.path.relpath(full, repo), vd, irrev)


def is_list_of_str(v):
    return isinstance(v, list) and all(isinstance(i, str) and i for i in v)


def unknown_keys(d, allowed, where, vd):
    for k in d:
        if k not in allowed:
            vd.block("unknown key '%s' in %s" % (k, where))


def validate(m, vd, repo_core, repo):
    if not isinstance(m, dict):
        vd.block("manifest is not a mapping"); return
    unknown_keys(m, TOP_KEYS, "manifest", vd)
    for req in ("id", "version", "touches_irreversible", "data_class", "requires", "calibration"):
        if req not in m:
            vd.block("missing required field '%s'" % req)
    if "id" in m and not (isinstance(m["id"], str) and SLUG.fullmatch(m["id"])):
        vd.block("id must be a lowercase slug")
    if "version" in m and not (isinstance(m["version"], str) and SEMVER.fullmatch(m["version"])):
        vd.block("version must be a MAJOR.MINOR.PATCH string")
    ti = m.get("touches_irreversible")
    if "touches_irreversible" in m and ti not in IRREVERSIBLE:
        vd.block("touches_irreversible=%r not in %s" % (ti, IRREVERSIBLE))
    if "data_class" in m and m["data_class"] not in DATA_CLASS:
        vd.block("data_class=%r not in %s" % (m["data_class"], DATA_CLASS))

    # provides
    pv = m.get("provides", {})
    if pv is None: pv = {}
    if not isinstance(pv, dict):
        vd.block("provides must be a mapping"); pv = {}
    unknown_keys(pv, PROVIDES_KEYS, "provides", vd)
    for k in ("skills", "agents"):
        if k in pv and not is_list_of_str(pv[k]):
            vd.block("provides.%s must be a list of non-empty strings" % k)
        elif k in pv and any(not SLUG.fullmatch(x) for x in pv[k]):
            vd.block("provides.%s names must be plain slugs (no paths, no globs)" % k)
    hooks = pv.get("hooks", [])
    if hooks is None: hooks = []
    if not isinstance(hooks, list):
        vd.block("provides.hooks must be a list"); hooks = []
    for i, h in enumerate(hooks):
        w = "provides.hooks[%d]" % i
        if not isinstance(h, dict):
            vd.block(w + " is not a mapping"); continue
        unknown_keys(h, HOOK_KEYS, w, vd)
        if not isinstance(h.get("event"), str) or h.get("event") not in HOOK_EVENTS:
            vd.block("%s.event=%r not in enum" % (w, h.get("event")))
        if not (isinstance(h.get("command"), str) and h["command"]):
            vd.block(w + ".command missing")
        if "matcher" in h and not isinstance(h["matcher"], str):
            vd.block("%s.matcher must be a string" % w)
        act = h.get("action", "add")
        if not isinstance(act, str) or act not in HOOK_ACTIONS_KNOWN:
            vd.block("%s.action=%r not in enum" % (w, act))
        elif act not in HOOK_ACTIONS:
            vd.block("%s.action=%s: a module may add hooks, never %s a core hook" % (w, act, act))
        order = h.get("order", "append")
        if not isinstance(order, str) or order not in HOOK_ORDER_KNOWN:
            vd.block("%s.order=%r not in enum" % (w, order))
        elif order not in HOOK_ORDER:
            vd.block("%s.order=%s reorders core hooks" % (w, order))
        if "target" in h:
            vd.block("%s.target: a hook that names a core hook as its target is an override" % w)
        if repo_core is not None and isinstance(h.get("command"), str):
            for b in repo_core:
                if re.search(r"(?<![\w.-])" + re.escape(b) + r"(?![\w.-])", h["command"]):
                    vd.block("%s.command shadows core hook %s" % (w, b))
    verdicts = pv.get("verdicts", [])
    if verdicts is None: verdicts = []
    if not isinstance(verdicts, list):
        vd.block("provides.verdicts must be a list"); verdicts = []
    for i, v in enumerate(verdicts):
        w = "provides.verdicts[%d]" % i
        if not isinstance(v, dict):
            vd.block(w + " is not a mapping"); continue
        unknown_keys(v, VERDICT_KEYS, w, vd)
        if not (isinstance(v.get("entry"), str) and isinstance(v.get("command"), str)):
            vd.block(w + " needs entry and command")
        ec = v.get("exit_codes")
        if not isinstance(ec, dict) or set(ec) != EXIT_KEYS or not all(isinstance(x, int) and not isinstance(x, bool) for x in ec.values()):
            vd.block(w + ".exit_codes must map exactly pass/block/unmeasured to ints")
        elif (ec["pass"], ec["block"], ec["unmeasured"]) != (0, 1, 2):
            vd.block(w + ".exit_codes must be pass 0 · block 1 · unmeasured 2 (the caller reads 0 as proceed; any other mapping can turn a block into a pass)")

    # A1/A2: command scans over hook + verdict command strings
    cmds = [("provides.hooks[%d]" % i, h.get("command")) for i, h in enumerate(hooks) if isinstance(h, dict)]
    cmds += [("provides.verdicts[%d]" % i, v.get("command")) for i, v in enumerate(verdicts) if isinstance(v, dict)]
    for w, cmd in cmds:
        check_command(cmd, w, vd, repo, ti == "none")
    for i, h in enumerate(hooks):
        ev = h.get("event") if isinstance(h, dict) else None
        if isinstance(ev, str) and ev in HOOK_EVENTS and ev not in OBSERVE_ONLY_EVENTS:
            why = "can return a permission decision" if ev in GATING_EVENTS else "can inject context or block"
            vd.block("provides.hooks[%d]: event %s %s; closed to modules in v0 (open: %s)" % (i, ev, why, sorted(OBSERVE_ONLY_EVENTS)))

    # constraints
    for i, c in enumerate(m.get("adds_constraints", []) or []):
        w = "adds_constraints[%d]" % i
        if not isinstance(c, dict) or set(c) != {"axis", "value"}:
            vd.block(w + " must be {axis, value}"); continue
        if not isinstance(c["axis"], str) or c["axis"] not in AXES:
            vd.block("%s.axis=%r not in %s" % (w, c["axis"], sorted(AXES)))
        elif not isinstance(c["value"], str) or c["value"] not in AXES[c["axis"]]:
            vd.block("%s.value=%r not in %s" % (w, c["value"], AXES[c["axis"]]))
        elif c["axis"] in CORE_FLOOR and AXES[c["axis"]].index(c["value"]) < AXES[c["axis"]].index(CORE_FLOOR[c["axis"]]):
            vd.block("%s: %s=%s is below the core floor %s (a module can only add constraints, never weaken them)" % (w, c["axis"], c["value"], CORE_FLOOR[c["axis"]]))
    if "adds_constraints" in m and not isinstance(m["adds_constraints"], list):
        vd.block("adds_constraints must be a list")

    # irreversible routing
    route = m.get("core_route")
    if ti in ("publish", "delete", "history"):
        gates = CORE_GATES[ti]
        if route not in gates:
            vd.block("touches_irreversible=%s requires core_route in %s (got %r)" % (ti, sorted(gates), route))
        else:
            p = os.path.join(repo, gates[route])
            if not os.path.isfile(p):
                vd.unm("core gate file %s missing: routing cannot be verified" % gates[route])
    elif ti == "none" and "core_route" in m:
        vd.block("core_route set while touches_irreversible=none")

    # requires
    rq = m.get("requires")
    if "requires" in m:
        if not isinstance(rq, dict):
            vd.block("requires must be a mapping")
        else:
            unknown_keys(rq, REQ_KEYS, "requires", vd)
            if not (isinstance(rq.get("core_min"), str) and SEMVER.fullmatch(rq["core_min"])):
                vd.block("requires.core_min must be MAJOR.MINOR.PATCH")
            mods = rq.get("modules", [])
            if mods is None: mods = []
            if not is_list_of_str(mods):
                vd.block("requires.modules must be a list of module ids")
            elif m.get("id") in mods:
                vd.block("module requires itself")

    # calibration
    cal = m.get("calibration")
    if "calibration" in m:
        if cal == "UNCALIBRATED":
            if verdicts:
                vd.block("calibration=UNCALIBRATED but provides.verdicts is non-empty: a verdict needs a known-pair test")
            else:
                vd.uncal = True
                vd.notes.append("calibration=UNCALIBRATED: no verdict from this module may be trusted as a number")
        elif isinstance(cal, dict) and set(cal) == {"command"} and isinstance(cal["command"], str) and cal["command"].strip():
            check_command(cal["command"], "calibration", vd, repo, False)   # irreversible-verb scan skipped: test code
        else:
            vd.block("calibration must be {command: <known-pair test>} or the literal UNCALIBRATED")

    rec = m.get("records")
    if rec is not None and not is_list_of_str(rec):
        vd.block("records must be a list of paths")

    # files the module ships beyond its skill/agent folders and command files (export copies exactly these)
    if "files" in m:
        fl = m["files"]
        if not is_list_of_str(fl):
            vd.block("files must be a list of repo-relative paths")
        else:
            rr = os.path.realpath(repo)
            for f in fl:
                if f.startswith("/") or ".." in f.split("/") or not CMD_ARG.match(f):
                    vd.block("files: %r must be a plain repo-relative path" % f)
                elif not os.path.exists(os.path.join(repo, f)):
                    vd.unm("files: %s does not exist" % f)
                elif os.path.commonpath([rr, os.path.realpath(os.path.join(repo, f))]) != rr:
                    vd.block("files: %s resolves outside the repo" % f)


def load_installed(d):
    mods, errs, dups = {}, [], []
    if not os.path.isdir(d):
        return mods, ["installed dir %s missing or not a directory" % d], dups
    files = []
    for pat in ("*/fh-module.yaml", "*/fh-module.yml", "*.yaml", "*.yml"):
        files += glob.glob(os.path.join(d, pat))
    for f in sorted(files):
        data, err = load_yaml(f)
        if err or not isinstance(data.get("id"), str):
            errs.append("%s: %s" % (f, err or "no id")); continue
        rq = data.get("requires")
        if rq is not None and not (isinstance(rq, dict) and (rq.get("modules") is None or is_list_of_str(rq.get("modules")))):
            errs.append("%s: malformed requires" % f); continue
        if data["id"] in mods:
            dups.append(data["id"])
        mods[data["id"]] = data
    if not files:
        errs.append("no installed manifests found in %s (an empty registry cannot clear anything)" % d)
    return mods, errs, dups


def cmd_check(a):
    vd = Verdict()
    repo = os.path.abspath(a.repo) if a.repo else default_repo()
    m, err = load_yaml(a.manifest)
    if err:
        (vd.block if err.startswith("duplicate key") else vd.unm)(err); vd.report(); return vd.code()
    core, cerr = core_hooks(repo)
    if cerr:
        vd.unm(cerr)
    validate(m, vd, core, repo)
    if a.installed:
        inst, errs, dups = load_installed(a.installed)
        for e in errs: vd.unm("installed registry unreadable: " + e)
        for d in dups: vd.block("duplicate installed module id %s" % d)
        if m.get("id") in inst:
            vd.block("module id %s already installed" % m.get("id"))
        rq = m.get("requires")
        if not errs and isinstance(rq, dict) and is_list_of_str(rq.get("modules", []) or []):   # an unreadable registry proves nothing either way
            for r in rq.get("modules", []) or []:
                if r not in inst:
                    vd.block("required module %s is not installed" % r)
    vd.report()
    return vd.code()


def cmd_merge(a):
    vd = Verdict()
    repo = os.path.abspath(a.repo) if a.repo else default_repo()
    core, cerr = core_hooks(repo)
    if cerr:
        vd.unm(cerr)
    # seed with the core-floor pseudo-manifest: nothing merges below it
    merged = {ax: AXES[ax].index(v) for ax, v in CORE_FLOOR.items()}
    srcs, dclass, irr = [], 0, 0
    irr_rank = {k: i for i, k in enumerate(IRREVERSIBLE)}
    for p in a.manifests:
        m, err = load_yaml(p)
        if err:
            (vd.block if err.startswith("duplicate key") else vd.unm)(err); continue
        sub = Verdict()
        validate(m, sub, core, repo)
        for x in sub.blocks: vd.block("%s: %s" % (p, x))
        for x in sub.unmeasured: vd.unm("%s: %s" % (p, x))
        vd.notes += sub.notes
        if sub.uncal: vd.uncal = True
        if sub.blocks or sub.unmeasured:
            continue                      # an invalid member contributes nothing and the merge is refused
        for c in m.get("adds_constraints", []) or []:
            idx = AXES[c["axis"]].index(c["value"])
            merged[c["axis"]] = max(merged.get(c["axis"], 0), idx)   # permission axes: strictest wins
        dc = DATA_CLASS.index(m["data_class"])
        dclass = max(dclass, dc)
        # residency floor derived from data_class
        res = AXES["residency"].index(DATA_TO_RESIDENCY[m["data_class"]])
        merged["residency"] = max(merged.get("residency", 0), res)
        irr = max(irr, irr_rank[m["touches_irreversible"]])          # any irreversible member taints the set
        srcs.append(p)
    if not srcs and not vd.blocks and not vd.unmeasured:
        vd.unm("nothing merged")
    code = vd.code()
    if code in (OK, UNCAL):
        out = {ax: AXES[ax][i] for ax, i in sorted(merged.items())}
        print(json.dumps({"verdict": "OK" if code == OK else "OK-UNCALIBRATED", "constraints": out,
                          "data_class": DATA_CLASS[dclass],
                          "touches_irreversible": "none" if irr == 0 else "irreversible-present",
                          "members": len(srcs)}, sort_keys=True))
    else:
        print(json.dumps({"verdict": "BLOCK" if code == BLOCK else "UNMEASURED"}))
    vd.report()
    return code


def cmd_remove(a):
    vd = Verdict()
    inst, errs, dups = load_installed(a.installed)
    for e in errs: vd.unm("installed registry unreadable: " + e)
    for d in dups: vd.block("duplicate installed module id %s" % d)
    if vd.unmeasured or vd.blocks:
        vd.report(); return vd.code()      # cannot see all dependants -> cannot clear removal
    if a.id not in inst:
        vd.block("module %s is not installed" % a.id); vd.report(); return vd.code()
    deps = sorted(i for i, m in inst.items() if i != a.id and isinstance(m.get("requires"), dict)
                  and a.id in (m["requires"].get("modules") or []))
    if deps:
        vd.block("removal of %s refused: required by %s" % (a.id, ", ".join(deps)))
    else:
        recs = inst[a.id].get("records") or []
        print("PLAN: unregister %s; ARCHIVE (not delete) %d record path(s): %s" % (a.id, len(recs), ", ".join(recs) or "-"))
    vd.report()
    return vd.code()


RESERVED_EXPORT = {"fh-module.yaml", "MODULE.md", ".fh-export"}


def tracked(repo):
    """Repo-relative paths git tracks (None if not a git checkout). Export copies only these: an untracked or ignored
    local file would make STANDALONE true on this machine and false for everyone else."""
    try:
        r = subprocess.run(["git", "-C", repo, "ls-files", "-z"], capture_output=True, timeout=60)
    except Exception:
        return None
    if r.returncode != 0:
        return None
    return set(x for x in r.stdout.decode("utf-8", "replace").split("\0") if x)


def module_paths(m, repo):
    """Everything export copies, repo-relative: skill and agent folders, every command file, the declared files.
    -> (paths, problems). Names are literal slugs; a skill/agent that does not resolve to exactly one place is a problem."""
    out, prob = [], []
    pv = m.get("provides") or {}
    for s_ in pv.get("skills") or []:
        if not SLUG.fullmatch(str(s_)):
            prob.append("skill name %r is not a plain slug" % s_); continue
        hits = sorted(glob.glob(os.path.join(repo, "plugins", "*", "skills", glob.escape(s_))))
        if len(hits) != 1: prob.append("skill %s resolves to %d folders" % (s_, len(hits)))
        else: out.append(os.path.relpath(hits[0], repo))
    for ag in pv.get("agents") or []:
        if not SLUG.fullmatch(str(ag)):
            prob.append("agent name %r is not a plain slug" % ag); continue
        hits = sorted(glob.glob(os.path.join(repo, "plugins", "*", "agents", glob.escape(ag) + ".md")))
        if len(hits) != 1: prob.append("agent %s resolves to %d files" % (ag, len(hits)))
        else: out.append(os.path.relpath(hits[0], repo))
    cmds = [h.get("command") for h in pv.get("hooks") or [] if isinstance(h, dict)]
    cmds += [v.get("command") for v in pv.get("verdicts") or [] if isinstance(v, dict)]
    cal = m.get("calibration")
    if isinstance(cal, dict): cmds.append(cal.get("command"))
    for c in cmds:
        full, kind, msg = resolve_cmd(c, repo)
        if kind: prob.append(msg)
        else: out.append(os.path.relpath(full, repo))
    out += list(m.get("files") or [])
    return sorted(set(out)), prob


def expand_tracked(rels, repo, trk):
    """Declared paths -> the tracked files under them. Symlinks anywhere are refused (a link can point outside the repo
    or at an undeclared file and turn a non-standalone module into STANDALONE)."""
    files, prob = [], []
    rr = os.path.realpath(repo)
    for rel in rels:
        top = rel.split("/")[0]
        if rel in (".", "") or ".git" in rel.split("/") or rel in RESERVED_EXPORT:
            prob.append("export: %s cannot be exported" % rel); continue
        src = os.path.join(repo, rel)
        if os.path.islink(src):
            prob.append("export: %s is a symlink" % rel); continue
        if os.path.isdir(src):
            for d, dirs, fs in os.walk(src):
                for n in dirs + fs:
                    if os.path.islink(os.path.join(d, n)):
                        prob.append("export: %s is a symlink" % os.path.relpath(os.path.join(d, n), repo))
                for n in fs:
                    r_ = os.path.relpath(os.path.join(d, n), repo)
                    if trk is None or r_ in trk: files.append(r_)
        elif trk is None or rel in trk:
            files.append(rel)
        else:
            prob.append("export: %s is not tracked by git (it would not exist for anyone else)" % rel)
        if os.path.commonpath([rr, os.path.realpath(src)]) != rr:
            prob.append("export: %s resolves outside the repo" % rel)
    return sorted(set(files)), prob


def trusted_path(repo):
    """PATH for the calibration run: the system dirs plus where the allowed interpreters live, never a dir inside the repo."""
    rr = os.path.realpath(repo)
    dirs = ["/usr/bin", "/bin", "/usr/sbin", "/sbin"]
    for it in sorted(INTERPRETERS):
        w = shutil.which(it)
        if w:
            d = os.path.dirname(os.path.realpath(w))
            if os.path.commonpath([rr, d]) != rr and d not in dirs: dirs.append(d)
    return ":".join(dirs)


def cmd_export(a):
    """Copy only what the module declares (git-tracked, no symlinks) into an empty folder outside the repo, run its
    calibration in a scratch copy of that folder. rc 0 = STANDALONE. The calibration's own rc 2 (or a missing
    interpreter, or a signal) is UNMEASURED, not a dependency failure."""
    import tempfile, signal
    vd = Verdict()
    repo = os.path.abspath(a.repo) if a.repo else default_repo()
    m, err = load_yaml(a.manifest)
    if err:
        (vd.block if err.startswith("duplicate key") else vd.unm)(err); vd.report(); return vd.code()
    core, cerr = core_hooks(repo)
    if cerr: vd.unm(cerr)
    validate(m, vd, core, repo)
    if vd.blocks or vd.unmeasured:
        print("export refused: the manifest does not pass check"); vd.report(); return vd.code()
    cal = m.get("calibration")
    if not isinstance(cal, dict):
        vd.unm("calibration is UNCALIBRATED: a standalone run cannot be proven"); vd.report(); return vd.code()
    out = os.path.realpath(os.path.abspath(a.out))
    rr = os.path.realpath(repo)
    if os.path.commonpath([rr, out]) == rr:
        vd.unm("--out %s is inside the repo: the run could reach the repo it is meant to stand without" % out); vd.report(); return vd.code()
    if os.path.exists(out) and (not os.path.isdir(out) or os.listdir(out)):
        vd.unm("--out %s exists and is not an empty folder" % out); vd.report(); return vd.code()
    rels, prob = module_paths(m, repo)
    trk = tracked(repo)
    files, prob2 = expand_tracked(rels, repo, trk)
    for p_ in prob + prob2:
        (vd.block if ("symlink" in p_ or "outside" in p_ or "cannot be exported" in p_ or "slug" in p_) else vd.unm)(p_)
    if vd.blocks or vd.unmeasured:
        vd.report(); return vd.code()
    parent = os.path.dirname(out) or "."
    os.makedirs(parent, exist_ok=True)
    stage = tempfile.mkdtemp(prefix=".fh-export-", dir=parent)
    scratch = tempfile.mkdtemp(prefix="fh-export-run-")
    try:
        for rel in files:
            dst = os.path.join(stage, rel)
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.copy2(os.path.join(repo, rel), dst, follow_symlinks=False)
        os.makedirs(os.path.join(stage, ".fh-export"))
        shutil.copy2(a.manifest, os.path.join(stage, ".fh-export", "fh-module.yaml"))
        with open(os.path.join(stage, ".fh-export", "MODULE.md"), "w", encoding="utf-8") as fh:
            fh.write("# %s %s (standalone export)\n\nFiles: %d git-tracked files.\nRun its known-pair test from this folder: `%s`\n"
                     % (m.get("id"), m.get("version"), len(files), cal["command"]))
        run_dir = os.path.join(scratch, "m")
        shutil.copytree(stage, run_dir, symlinks=True)
        home = os.path.join(scratch, "home"); tmp = os.path.join(scratch, "tmp")
        os.makedirs(home); os.makedirs(tmp)
        env = {"PATH": trusted_path(repo), "HOME": home, "TMPDIR": tmp, "LANG": os.environ.get("LANG", "C.UTF-8"),
               "XDG_CONFIG_HOME": os.path.join(home, ".config"), "XDG_CACHE_HOME": os.path.join(home, ".cache")}
        pr = subprocess.Popen(cal["command"].split(), cwd=run_dir, env=env, stdin=subprocess.DEVNULL,
                              stdout=subprocess.PIPE, stderr=subprocess.STDOUT, start_new_session=True)
        try:
            outb, _ = pr.communicate(timeout=int(getattr(a, "timeout", 600) or 600))
        except subprocess.TimeoutExpired:
            try: os.killpg(pr.pid, signal.SIGKILL)
            except Exception: pass
            pr.communicate()
            vd.unm("calibration timed out inside the export (process group killed)"); vd.report(); return vd.code()
        rc = pr.returncode
        tail = "\n".join(outb.decode("utf-8", "replace").strip().splitlines()[-8:])
        print("calibration rc=%d inside a scratch copy of the export (%d files)" % (rc, len(files)))
        if rc == 0:
            os.rename(stage, out) if not os.path.exists(out) else (os.rmdir(out), os.rename(stage, out))
            stage = None
            print("STANDALONE: the module's own known-pair test passes with only its declared, git-tracked files -> %s" % out)
        elif re.search(r"No such file|can't open file|cannot find module|Cannot find module|ModuleNotFoundError|missing .*\.(py|sh|js|md)", tail):
            # a file the run reached for is not in the export — an undeclared dependency, whatever the rc (python exits 2 here)
            vd.block("not standalone: the calibration reached for a file the export does not have:\n" + tail)
        elif rc == 2 or rc in (126, 127) or rc < 0:
            vd.unm("calibration could not measure inside the export (rc=%d: its own UNMEASURED, a missing interpreter or a signal):\n%s" % (rc, tail))
        else:
            vd.block("not standalone: calibration fails inside the export (an undeclared dependency?):\n" + tail)
    finally:
        if stage and os.path.isdir(stage): shutil.rmtree(stage, ignore_errors=True)
        shutil.rmtree(scratch, ignore_errors=True)
    vd.report()
    return vd.code()


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd")
    c = sub.add_parser("check"); c.add_argument("manifest"); c.add_argument("--repo"); c.add_argument("--installed")
    g = sub.add_parser("merge"); g.add_argument("manifests", nargs="+"); g.add_argument("--repo")
    r = sub.add_parser("remove"); r.add_argument("id"); r.add_argument("--installed", required=True)
    x = sub.add_parser("export"); x.add_argument("manifest"); x.add_argument("--out", required=True); x.add_argument("--repo"); x.add_argument("--timeout", type=int, default=600)
    try:
        a = ap.parse_args(argv)
    except SystemExit:
        return UNMEASURED
    try:
        return {"check": cmd_check, "merge": cmd_merge, "remove": cmd_remove, "export": cmd_export}[a.cmd](a)
    except Exception as e:                      # fail closed: an internal error is never a pass
        print("UNMEASURED: checker error %s: %s" % (type(e).__name__, e))
        return UNMEASURED


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
