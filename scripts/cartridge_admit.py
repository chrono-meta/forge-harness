#!/usr/bin/env python3
# cartridge_admit.py — v1 cartridge admission check (spec: tracks/_meta/design_cartridge_spec_v0_2026-10-11.md §4).
#
# usage: python3 scripts/cartridge_admit.py <plugin dir> [--json] [--keep-snapshot DIR]
#
# Order: immutable snapshot (copy to temp, content hash) -> v1 inventory allowlist (regular files only:
# plugin.json, cartridge.yaml, README.md, LICENSE, *.example.yaml, skills/<dir>/**, scripts/**, fixtures/**) -> cartridge.yaml schema -> scripts/generated_harness_check.py on every declared load target
# -> strictest-wins constraint merge report.
#
# Exit code is the verdict:
#   0 ADMIT         every step passed
#   1 HUMAN_REVIEW  the checker returned 1 (irreversible permission open), or the cartridge needs a
#                   required service this script cannot verify (it has no service registry)
#   2 REFUSE        outside v1 scope, schema violation, or a reserved generator skill name
#   3 HARNESS_ERROR missing / unreadable / unparsable input, or the checker could not run
#
# The verdict is preliminary. The verified snapshot is deleted unless --keep-snapshot DIR is given;
# on ADMIT it is then copied read-only to DIR/snapshot-<digest12>, and that copy is what an installer
# may consume. PyYAML is required (cartridge.yaml and frontmatter). No network.
import hashlib
import json
import os
import re
import shutil
import stat
import subprocess
import sys
import tempfile

try:
    import yaml
except ImportError:
    yaml = None

ADMIT, HUMAN_REVIEW, REFUSE, HARNESS_ERROR = 0, 1, 2, 3
NAMES = {ADMIT: "ADMIT", HUMAN_REVIEW: "HUMAN_REVIEW", REFUSE: "REFUSE", HARNESS_ERROR: "HARNESS_ERROR"}

HERE = os.path.dirname(os.path.abspath(__file__))
CHECKER = os.path.join(HERE, "generated_harness_check.py")

ORDERS = {
    "approval": ["auto", "notify", "ask", "ask-per-item", "forbidden"],
    "reversibility": ["reversible", "unknown", "irreversible"],
    "residency": ["public", "operator-private", "company"],
    "writes": ["read-only", "write-local", "write-remote"],
}
HOST_BASELINE = {"approval": "auto", "reversibility": "reversible", "residency": "public", "writes": "read-only"}

TOP_KEYS = {"schema_version", "plugin", "load", "constraints", "services", "done_when",
            "capabilities", "purpose", "intents", "kind", "applies_when"}
# kind (optional): activity = the request names the activity and the plugin's skill routes itself once installed;
# method = changes how work is done; installed as a plugin it was never self-invoked on ordinary coding requests (0 Skill
# calls in 93 sessions where it was installed, Haiku and Sonnet, 2026-10-24), so a loader must put it into the session.
# A method must say when it applies: loaded where its failure is absent, a method cartridge measured no effect.
# Reported kind: the declared value, UNDECLARED when absent (still admitted), INVALID when present but outside the enum.
# These two keys were unknown (REFUSE) before 2026-10-24; a manifest using them validly now ADMITs - the intended widening.
# Residual, not checked: kind is self-declared (a method can call itself activity), and applies_when is untrusted
# description - a loader must not treat it as routing authority or as instructions.
KINDS = ("activity", "method")
PLACEHOLDER_RE = re.compile(r"^\s*(tbd|todo|n/?a|none|-+|\.\.\.|\?)\s*$", re.I)
REQUIRED_KEYS = {"schema_version", "plugin", "load", "constraints"}
DONE_CLASSES = {"measured", "declared"}
WRITE_TOOLS = {"Write", "Edit", "MultiEdit", "NotebookEdit"}   # MultiEdit added 2026-10-23 (codex, pre-v3.29.0 Area B)
# Admission is an ALLOWLIST (2026-10-19, codex final round: 4 A where a blocklist let mcp__*, `git rebase`, `find -delete`
# and a bundled script through as ADMIT). Only grants that are plainly reversible ADMIT; every other grant is HUMAN_REVIEW.
# Same lesson as the static shell-string checks that never converged: name what is safe, not what is dangerous.
REVERSIBLE_TOOLS = {"Read", "Grep", "Glob", "LS", "NotebookRead", "TodoWrite", "WebSearch", "WebFetch",
                    "Write", "Edit", "MultiEdit", "NotebookEdit"}   # writes are cross-checked against declared `writes`
# Bash grants that ADMIT, exact text. `git log/diff/show` are left out on purpose: `--output=<file>` writes.
# Frontmatter keys that carry no executable behaviour. Anything else (above all `hooks:`, which Claude Code runs from
# a skill's or agent's frontmatter) goes to a human — codex final round R2, 2026-10-19.
INERT_FRONTMATTER = {"name", "description", "allowed-tools", "tools", "model", "argument-hint", "user-invocable",
                     "disable-model-invocation", "origin", "license", "version", "when_to_use", "metadata"}
READONLY_BASH = {"Bash(git status)", "Bash(git status:*)", "Bash(ls)", "Bash(ls:*)", "Bash(pwd)"}
PLUGIN_JSON_KEYS = {"name", "version", "description", "author", "homepage", "repository", "license",
                    "keywords", "engines"}
PLUGIN_JSON = os.path.join(".claude-plugin", "plugin.json")
ROOT_FILES = {"cartridge.yaml", "README.md", "LICENSE"}
INVENTORY_DIRS = {".claude-plugin", "skills", "scripts", "fixtures"}
RESERVED_SKILLS = {"harness", "harness-evolve"}


class Stop(Exception):
    def __init__(self, rc, msg):
        Exception.__init__(self, msg)
        self.rc = rc


def entries(root):
    out = []
    for base, dirs, files in os.walk(root):
        for n in dirs + files:
            p = os.path.join(base, n)
            if os.path.islink(p):
                kind = "l"
            elif os.path.isdir(p):
                kind = "d"
            elif os.path.isfile(p):
                kind = "f"
            else:
                kind = "o"
            out.append((os.path.relpath(p, root), kind))
    return sorted(out)


def tree_hash(root):
    h = hashlib.sha256()
    for rel, kind in entries(root):
        p = os.path.join(root, rel)
        if kind == "l":
            content = os.readlink(p).encode("utf-8", "surrogateescape")
        elif kind == "f":
            with open(p, "rb") as f:
                content = f.read()
        else:
            content = b""
        name = rel.encode("utf-8", "surrogateescape")
        h.update(kind.encode() + len(name).to_bytes(8, "big") + name + len(content).to_bytes(8, "big") + content)
    return h.hexdigest()


def snapshot(src, tmp):
    if not os.path.isdir(src):
        raise Stop(HARNESS_ERROR, "plugin dir not found: %s" % src)
    dst = os.path.join(tmp, "snapshot")
    try:
        shutil.copytree(src, dst, symlinks=True)
    except (OSError, shutil.Error) as e:
        raise Stop(HARNESS_ERROR, "snapshot copy failed: %s" % e)
    digest = tree_hash(dst)
    if tree_hash(src) != digest:
        raise Stop(HARNESS_ERROR, "source changed during snapshot")
    lock(dst)
    return dst, digest


def lock(root):
    for base, dirs, files in os.walk(root):
        for n in files:
            p = os.path.join(base, n)
            if not os.path.islink(p):
                os.chmod(p, stat.S_IRUSR)
        os.chmod(base, stat.S_IRUSR | stat.S_IXUSR)


def unlock(root):
    for base, dirs, files in os.walk(root):
        os.chmod(base, stat.S_IRWXU)
        for n in files:
            p = os.path.join(base, n)
            if not os.path.islink(p):
                os.chmod(p, stat.S_IRUSR | stat.S_IWUSR)


def read_json(path, what):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError) as e:
        raise Stop(HARNESS_ERROR, "%s unreadable: %s" % (what, e))


def load_manifest(path):
    if not os.path.isfile(path):
        raise Stop(HARNESS_ERROR, "cartridge.yaml missing")
    try:
        with open(path, encoding="utf-8") as f:
            text = f.read()
    except (OSError, UnicodeDecodeError) as e:
        raise Stop(HARNESS_ERROR, "cartridge.yaml unreadable: %s" % e)
    if yaml is None:
        raise Stop(HARNESS_ERROR, "PyYAML is required")
    try:
        data = yaml.safe_load(text)
    except yaml.YAMLError as e:
        raise Stop(HARNESS_ERROR, "cartridge.yaml unparsable: %s" % e)
    if not isinstance(data, dict):
        raise Stop(HARNESS_ERROR, "cartridge.yaml top level is not a mapping")
    return data


def in_inventory(rel, kind):
    parts = rel.split(os.sep)
    if kind == "f" and len(parts) == 1:
        return parts[0] in ROOT_FILES or parts[0].endswith(".example.yaml")
    if kind == "d" and len(parts) == 1:
        return parts[0] in INVENTORY_DIRS
    if kind not in ("f", "d") or parts[0] not in INVENTORY_DIRS:
        return False
    if parts[0] == ".claude-plugin":
        return rel == PLUGIN_JSON or (kind == "d" and len(parts) == 1)
    if parts[0] == "skills":
        return kind == "d" or len(parts) >= 3
    return True


def scope_violations(root, plugin_json):
    found = []
    seen = {}
    for rel, kind in entries(root):
        if seen.setdefault(rel.lower(), rel) != rel:
            found.append("paths differing only by case: %s / %s" % (seen[rel.lower()], rel))
        if not in_inventory(rel, kind):
            found.append("outside v1 inventory: %s (%s)" % (rel, {"l": "symlink", "o": "special file"}.get(kind, "not allowed")))
    for key in sorted(set(plugin_json) - PLUGIN_JSON_KEYS):
        found.append("outside v1 scope: plugin.json declares %s" % key)
    sdir = os.path.join(root, "skills")
    if os.path.isdir(sdir):
        for n in sorted(os.listdir(sdir)):
            if n in RESERVED_SKILLS:
                found.append("reserved skill name (the checker skips it): skills/%s" % n)
    return found


def inside(root, rel):
    if not isinstance(rel, str) or not rel or os.path.isabs(rel):
        return False
    p = os.path.realpath(os.path.join(root, rel))
    return p == os.path.realpath(root) or p.startswith(os.path.realpath(root) + os.sep)


def is_str_list(v):
    return isinstance(v, list) and all(isinstance(x, str) for x in v)


def validate(root, m, plugin_json):
    errs = []
    for k in sorted(set(m) - TOP_KEYS):
        errs.append("unknown key: %s" % k)
    for k in sorted(REQUIRED_KEYS - set(m)):
        errs.append("missing key: %s" % k)
    if type(m.get("schema_version")) is not int or m["schema_version"] != 1:
        errs.append("schema_version must be the integer 1")
    for what, v in (("cartridge.yaml plugin", m.get("plugin")), ("plugin.json name", plugin_json.get("name"))):
        if not isinstance(v, str) or not v:
            errs.append("%s must be a nonempty string" % what)
    if m.get("plugin") != plugin_json.get("name"):
        errs.append("plugin %r != plugin.json name %r" % (m.get("plugin"), plugin_json.get("name")))

    load = m.get("load")
    if not isinstance(load, dict) or not is_str_list(load.get("entry")) or not load.get("entry"):
        errs.append("load.entry must be a non-empty list of paths")
    else:
        for k in sorted(set(load) - {"entry", "extra"}):
            errs.append("unknown load key: %s" % k)
        if "extra" in load and not is_str_list(load["extra"]):
            errs.append("load.extra must be a list of paths")
        else:
            for rel in load["entry"] + load.get("extra", []):
                if not inside(root, rel):
                    errs.append("load path escapes plugin root: %r" % (rel,))
                elif not os.path.isfile(os.path.join(root, rel)):
                    errs.append("load path not found: %s" % rel)

    cons = m.get("constraints")
    if not isinstance(cons, dict):
        errs.append("constraints must be a mapping")
    else:
        for axis, order in ORDERS.items():
            if not isinstance(cons.get(axis), str) or cons[axis] not in order:
                errs.append("constraints.%s must be one of %s" % (axis, order))
        for k in sorted(set(cons) - set(ORDERS)):
            errs.append("unknown constraints key: %s" % k)

    if "services" in m and not isinstance(m["services"], list):
        errs.append("services must be a list")
    else:
        for i, s in enumerate(m.get("services", [])):
            if not isinstance(s, dict) or not isinstance(s.get("id"), str) or not s["id"] \
                    or s.get("need") not in ("required", "optional") \
                    or s.get("on_absent") not in ("refuse-load", "proceed-marked"):
                errs.append("services[%d] needs id, need(required|optional), on_absent(refuse-load|proceed-marked)" % i)
            elif s["need"] == "required" and s["on_absent"] != "refuse-load":
                errs.append("services[%d]: required service must use on_absent refuse-load" % i)

    if "done_when" in m and not isinstance(m["done_when"], list):
        errs.append("done_when must be a list")
    else:
        for i, d in enumerate(m.get("done_when", [])):
            if not isinstance(d, dict) or not isinstance(d.get("text"), str) or not d["text"] \
                    or d.get("class") not in DONE_CLASSES:
                errs.append("done_when[%d] needs text and class(measured|declared)" % i)
            elif d["class"] == "measured":
                for k in ("checker", "input", "pass"):
                    if not isinstance(d.get(k), str) or not d[k]:
                        errs.append("done_when[%d] measured needs string %s" % (i, k))
                if isinstance(d.get("checker"), str) and not (inside(root, d["checker"]) and os.path.isfile(os.path.join(root, d["checker"]))):
                    errs.append("done_when[%d] checker not found inside plugin: %s" % (i, d["checker"]))
            elif "checker" in d:
                errs.append("done_when[%d] declared must not carry a checker" % i)

    if "capabilities" in m and not is_str_list(m["capabilities"]):
        errs.append("capabilities must be a list of ids")
    if "purpose" in m and not isinstance(m["purpose"], str):
        errs.append("purpose must be a string")
    if "intents" in m and not is_str_list(m["intents"]):
        errs.append("intents must be a list of strings")
    if "kind" in m and (not isinstance(m["kind"], str) or m["kind"] not in KINDS):
        errs.append("kind must be one of %s" % (KINDS,))
    if "applies_when" in m:
        aw = m["applies_when"]
        if not isinstance(aw, str) or len(aw.split()) < 3 or all(PLACEHOLDER_RE.match(w) for w in aw.split()):
            errs.append("applies_when must say, in at least three words, which failure the cartridge fixes")
    elif m.get("kind") == "method":
        errs.append("kind method needs applies_when (where its failure occurs)")
    return errs


def load_targets(m):
    return m["load"]["entry"] + m["load"].get("extra", [])


def frontmatter(text, rel):
    text = text.lstrip("\ufeff")
    if not text.startswith("---"):
        return {}
    mt = re.match(r"---[ \t]*\r?\n(.*?)\r?\n---[ \t]*(?:\r?\n|$)", text, re.S)
    if not mt:
        raise Stop(HARNESS_ERROR, "%s: frontmatter is not terminated" % rel)
    try:
        fm = yaml.safe_load(mt.group(1))
    except yaml.YAMLError as e:
        raise Stop(HARNESS_ERROR, "%s: frontmatter unparsable: %s" % (rel, e))
    if fm is None:
        return {}
    if not isinstance(fm, dict):
        raise Stop(HARNESS_ERROR, "%s: frontmatter is not a mapping" % rel)
    return fm


def read_text(root, rel):
    try:
        with open(os.path.join(root, rel), encoding="utf-8") as f:
            return f.read()
    except (OSError, UnicodeDecodeError) as e:
        raise Stop(HARNESS_ERROR, "unreadable %s: %s" % (rel, e))


def skill_tools(root, targets):
    rels = set(targets)
    for rel, kind in entries(root):
        if kind == "f" and rel.split(os.sep)[0] == "skills" and rel.lower().endswith(".md"):
            rels.add(rel)
    tools, grants = set(), []
    for rel in sorted(rels):
        fm = frontmatter(read_text(root, rel), rel)
        for key in sorted(k for k in fm if str(k) not in INERT_FRONTMATTER):
            grants.append("%s: frontmatter key %r (outside the inert-key allowlist)" % (rel, key))
        for key in ("allowed-tools", "tools"):
            v = fm.get(key)
            if v is None:
                continue
            if isinstance(v, str):
                items = re.findall(r"[^\s,()]+(?:\([^)]*\))?", v)
            elif is_str_list(v):
                items = v
            else:
                raise Stop(HARNESS_ERROR, "%s: %s must be a string or a list of strings" % (rel, key))
            for item in items:
                item = item.strip()
                name = re.split(r"[(\s]", item, maxsplit=1)[0]
                tools.add(name)
                label = checker_h1(item)
                if label:
                    grants.append("%s: %s (%s)" % (rel, item, label))
                elif name == "Bash" or item.startswith("Bash"):
                    if re.sub(r"\s+", " ", item) not in READONLY_BASH:
                        grants.append("%s: %s (Bash outside the read-only allowlist)" % (rel, item))
                elif name not in REVERSIBLE_TOOLS:
                    grants.append("%s: %s (tool outside the reversible allowlist)" % (rel, item))
    tools.discard("")
    return tools, grants


def checker_h1(entry):
    try:
        sys.path.insert(0, HERE)
        import generated_harness_check
    except ImportError as e:
        raise Stop(HARNESS_ERROR, "cannot import the checker's H1 judgment: %s" % e)
    finally:
        sys.path.pop(0)
    return generated_harness_check.h1_match(entry)


def merge(declared, tools):
    rows = []
    merged = {}
    for axis, order in ORDERS.items():
        a, b = HOST_BASELINE[axis], declared[axis]
        pick = a if order.index(a) >= order.index(b) else b
        merged[axis] = pick
        rows.append("%s: host=%s cartridge=%s -> %s" % (axis, a, b, pick))
    conflicts = []
    if tools & WRITE_TOOLS and ORDERS["writes"].index(declared["writes"]) < 1:
        conflicts.append("declared writes=read-only but tools include %s" % sorted(tools & WRITE_TOOLS))
    return merged, rows, conflicts


def stage_for_checker(root, tmp, targets):
    stage = os.path.join(tmp, "stage")
    claude = os.path.join(stage, ".claude")
    os.makedirs(claude)
    if os.path.isdir(os.path.join(root, "skills")):
        shutil.copytree(os.path.join(root, "skills"), os.path.join(claude, "skills"))
    unlock(stage)
    parts = []
    for i, rel in enumerate(targets):
        n = os.path.normpath(rel).split(os.sep)
        native = len(n) == 3 and n[0] == "skills" and n[2] == "SKILL.md"
        if native:
            continue
        text = read_text(root, rel)
        if frontmatter(text, rel):
            d = os.path.join(claude, "skills", "load-target-%d" % i)
            os.makedirs(d)
            with open(os.path.join(d, "SKILL.md"), "w", encoding="utf-8") as f:
                f.write(text)
        else:
            parts.append("<!-- load target: %s -->\n%s\n" % (rel, text))
    if parts:
        with open(os.path.join(stage, "CLAUDE.md"), "w", encoding="utf-8") as f:
            f.write("\n".join(parts))
    return stage


def run_checker(stage):
    if not os.path.isfile(CHECKER):
        raise Stop(HARNESS_ERROR, "generated_harness_check.py not found")
    try:
        p = subprocess.run([sys.executable, CHECKER, stage, "--json"], capture_output=True, text=True, timeout=120)
    except (OSError, subprocess.TimeoutExpired) as e:
        raise Stop(HARNESS_ERROR, "checker did not run: %s" % e)
    if p.returncode not in (0, 1):
        raise Stop(HARNESS_ERROR, "checker rc=%d: %s" % (p.returncode, p.stdout.strip()[:300] or p.stderr.strip()[:300]))
    try:
        out = json.loads(p.stdout)
    except ValueError:
        raise Stop(HARNESS_ERROR, "checker output is not JSON: %s" % p.stdout.strip()[:200])
    want = {0: "PASS", 1: "HUMAN_REVIEW"}[p.returncode]
    if not isinstance(out, dict) or type(out.get("rc")) is not int or out["rc"] != p.returncode \
            or out.get("verdict") != want or out.get("errors") != [] \
            or not isinstance(out.get("human_review"), list) or bool(out["human_review"]) != (p.returncode == 1):
        raise Stop(HARNESS_ERROR, "checker output disagrees with its exit code %d: %s" % (p.returncode, p.stdout.strip()[:200]))
    return p.returncode


def keep(root, digest, keep_dir):
    dest = os.path.join(keep_dir, "snapshot-" + digest[:12])
    if os.path.lexists(dest):
        raise Stop(HARNESS_ERROR, "keep-snapshot target exists: %s" % dest)
    try:
        os.makedirs(keep_dir, exist_ok=True)
        shutil.copytree(root, dest, symlinks=True)
    except (OSError, shutil.Error) as e:
        raise Stop(HARNESS_ERROR, "keep-snapshot copy failed: %s" % e)
    lock(dest)
    if tree_hash(dest) != digest:
        unlock(dest)
        shutil.rmtree(dest, ignore_errors=True)
        raise Stop(HARNESS_ERROR, "kept snapshot differs from the verified one")
    return dest


def admit(src, keep_dir=None):
    report = {"plugin_dir": src, "steps": {}}
    tmp = tempfile.mkdtemp(prefix="cartridge_admit_")
    rc = ADMIT
    try:
        root, digest = snapshot(src, tmp)
        report["snapshot_sha256"] = digest
        plugin_json = read_json(os.path.join(root, ".claude-plugin", "plugin.json"), "plugin.json")
        manifest = load_manifest(os.path.join(root, "cartridge.yaml"))

        viol = scope_violations(root, plugin_json)
        report["steps"]["scope"] = viol or "ok"
        errs = validate(root, manifest, plugin_json)
        report["steps"]["schema"] = errs or "ok"
        if isinstance(manifest, dict):
            k = manifest.get("kind")
            report["kind"] = "UNDECLARED" if "kind" not in manifest else k if isinstance(k, str) and k in KINDS else "INVALID"
        if viol or errs:
            raise Stop(REFUSE, "; ".join(viol + errs))

        targets = load_targets(manifest)
        tools, grants = skill_tools(root, targets)
        report["steps"]["tool_grants"] = grants or "ok"
        merged, rows, conflicts = merge(manifest["constraints"], tools)
        report["steps"]["merge"] = {"merged": merged, "rows": rows, "conflicts": conflicts}
        if conflicts:
            raise Stop(REFUSE, "; ".join(conflicts))

        crc = run_checker(stage_for_checker(root, tmp, targets))
        report["steps"]["static_check"] = {"rc": crc, "verdict": "HUMAN_REVIEW" if crc == 1 else "PASS"}
        required = [s["id"] for s in manifest.get("services", []) if s["need"] == "required"]
        report["steps"]["services"] = {"required_unverified": required}
        # A cartridge that DECLARES it may be irreversible / unknown, or writes remotely, is never auto-admitted (codex A1).
        declared_risk = [a for a, bad in (("reversibility", ("unknown", "irreversible")), ("writes", ("write-remote",)))
                         if merged[a] in bad]
        report["steps"]["declared_risk"] = declared_risk or "ok"
        rc = HUMAN_REVIEW if crc == 1 or required or grants or declared_risk else ADMIT
        if rc == ADMIT and keep_dir:
            report["snapshot_kept"] = keep(root, digest, keep_dir)
    except Stop as s:
        rc = s.rc
        report["reason"] = str(s)
    except Exception as e:
        rc = HARNESS_ERROR
        report["reason"] = "unexpected: %r" % (e,)
    finally:
        unlock(tmp)
        shutil.rmtree(tmp, ignore_errors=True)
    if "snapshot_kept" not in report:
        report["snapshot_note"] = "snapshot discarded; this verdict is preliminary and not an install token"
    report["verdict"] = NAMES[rc]
    report["rc"] = rc
    return rc, report


def main(argv):
    args = argv[1:]
    want_json = "--json" in args
    args = [a for a in args if a != "--json"]
    keep_dir = None
    if "--keep-snapshot" in args:
        i = args.index("--keep-snapshot")
        if i + 1 >= len(args):
            args = []
        else:
            keep_dir = args[i + 1]
            del args[i:i + 2]
    if len(args) != 1:
        sys.stderr.write("usage: cartridge_admit.py <plugin dir> [--json] [--keep-snapshot DIR]\n")
        return HARNESS_ERROR
    rc, report = admit(args[0], keep_dir)
    if want_json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        print("verdict: %s (rc=%d)" % (report["verdict"], rc))
        if "reason" in report:
            print("reason: %s" % report["reason"])
        for row in report["steps"].get("merge", {}).get("rows", []):
            print("  " + row)
        grants = report["steps"].get("tool_grants")
        for g in grants if isinstance(grants, list) else []:
            print("  irreversible-capable tool grant: " + g)
        for sid in report["steps"].get("services", {}).get("required_unverified", []):
            print("  required service not verified (no service registry): %s" % sid)
        if "snapshot_sha256" in report:
            print("snapshot_sha256: %s" % report["snapshot_sha256"])
        print(report.get("snapshot_kept") and "snapshot kept: %s" % report["snapshot_kept"] or report["snapshot_note"])
    return rc


if __name__ == "__main__":
    sys.exit(main(sys.argv))
