#!/usr/bin/env bash
# test_fh_module_check_lanes.sh - known-pair lanes for scripts/fh_module_check.py.
# Each lane asserts the exact exit code (0 OK / 1 BLOCK / 2 UNMEASURED) on a known input.
# Lane 1 is the known-positive (valid module passes); every other lane is a distinct way to be refused.
#
# Revert probe: FH_MODULE_PROBE=<name> neuters one check in a TEMP COPY of the checker (never the real
# one) and the matching lane must go red:
#   hook-action | enum | route | strictest | dependants | unreadable | gating | corepat | irrverb |
#   case | shape | filescan | events | uncalmerge | uncal | dupkey | mergefloor | mergevalid | emptyinst
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(dirname "$HERE")"
SRC="$HERE/fh_module_check.py"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
CHK="$SRC"
PASS=0; FAIL=0

if [ -n "${FH_MODULE_PROBE:-}" ]; then
  CHK="$W/fh_module_check.py"; cp "$SRC" "$CHK"
  case "$FH_MODULE_PROBE" in
    gating)      needle='if mt not in NARROW_MATCHERS:'; repl='if False:' ;;
    corepat)     needle='        if re.search(pat, text, re.I | re.M):\n            vd.block("%s matches core-disabling'; repl='        if False:\n            vd.block("%s matches core-disabling' ;;
    irrverb)     needle='    if irrev:'; repl='    if False:' ;;
    case)        needle='re.search(pat, text, re.I | re.M):\n            vd.block("%s matches core-disabling'; repl='re.search(pat, text, re.M):\n            vd.block("%s matches core-disabling' ;;
    shape)       needle='    if CMD_FORBID.search(cmd):@@CMD_ARG = re.compile(r"^[A-Za-z0-9_./=:,@%+-]+$")'; repl='    if False:@@CMD_ARG = re.compile(r"^.*$")' ;;
    filescan)    needle='    scan_text(raw.decode("utf-8", "replace")'; repl='    (lambda *a: None)(raw.decode("utf-8", "replace")' ;;
    events)      needle='h["event"] not in GATING_EVENTS | OBSERVE_ONLY_EVENTS:'; repl='h["event"] not in HOOK_EVENTS:' ;;
    uncalmerge)  needle='        if sub.uncal: vd.uncal = True'; repl='        pass' ;;
    uncal)       needle='            if verdicts:'; repl='            if False:' ;;
    dupkey)      needle='if kk in seen:'; repl='if False:' ;;
    mergefloor)  needle='merged = {ax: AXES[ax].index(v) for ax, v in CORE_FLOOR.items()}'; repl='merged = {}' ;;
    mergevalid)  needle='        for x in sub.blocks: vd.block("%s: %s" % (p, x))'; repl='        pass' ;;
    emptyinst)   needle='    if not files:'; repl='    if False:' ;;
    hook-action) needle='elif act not in HOOK_ACTIONS:'; repl='elif False:' ;;
    enum)        needle='if h.get("event") not in HOOK_EVENTS:'; repl='if False:' ;;
    route)       needle='if route not in gates:'; repl='if False:' ;;
    strictest)   needle='max(merged.get(c["axis"], 0), idx)'; repl='idx' ;;
    dependants)  needle='    if deps:'; repl='    if False:' ;;
    unreadable)  needle='return None, "cannot read'; repl='return {"id": "x"}, None  #' ;;
    *) echo "unknown probe: $FH_MODULE_PROBE"; exit 2 ;;
  esac
  python3 - "$CHK" "$needle" "$repl" <<'PY' || exit 2
import sys
p, n, r = sys.argv[1:4]
s = open(p).read()
if "@@" in n:
    for nn, rr in zip(n.split("@@"), r.split("@@")):
        if nn not in s:
            print("probe needle not found - probe NOT applied"); sys.exit(1)
        s = s.replace(nn, rr, 1)
    open(p, "w").write(s); print("PROBE applied (multi):", n[:40]); sys.exit(0)
n = n.replace('\\n', '\n'); r = r.replace('\\n', '\n')
if n not in s:
    print("probe needle not found - probe NOT applied"); sys.exit(1)
open(p, "w").write(s.replace(n, r, 1)); print("PROBE applied:", n, "->", r)
PY
fi

run() { # name expected_rc cmd...
  local name="$1" want="$2" out rc; shift 2
  out="$("$@" 2>&1)"; rc=$?
  if [ "$rc" = "$want" ]; then PASS=$((PASS+1)); echo "PASS  $name (rc=$rc)"
  else FAIL=$((FAIL+1)); echo "FAIL  $name want=$want got=$rc"; echo "$out" | sed 's/^/      /'; fi
}
# temp repo: real templates (core hook list) by symlink, plus the module files fixtures reference
R="$W/repo"; mkdir -p "$R/mod" "$R/scripts"
ln -s "$REPO/templates" "$R/templates"
for f in log a x chk ok; do echo 'echo observe' > "$R/mod/$f.sh"; done
echo 'echo cal' > "$R/scripts/cal.sh"
echo 'echo hi' > "$R/scripts/destructive_pre_gate.sh"
echo 'git push --force origin main' > "$R/mod/push.sh"
echo 'git -C somewhere push origin main' > "$R/mod/gitC.sh"
echo 'rm -f -r somedir' > "$R/mod/rmfr.sh"
echo 'git config core.hookspath /dev/null' > "$R/mod/hp.sh"
echo 'git config CORE.HOOKSPATH /dev/null' > "$R/mod/hpu.sh"
echo 'GIT_CONFIG_COUNT=1 git status' > "$R/mod/gcc.sh"
c() { python3 "$CHK" "$@" --repo "$R"; }
mk() { mkdir -p "$W/$1"; cat > "$W/$1/fh-module.yaml"; }

TAIL='data_class: public
requires: {modules: [], core_min: 3.0.0}
calibration: {command: "bash scripts/cal.sh"}'

mk valid <<YAML
id: readonly-demo
version: 1.0.0
provides: {skills: [demo], hooks: [{event: SessionEnd, command: "bash mod/log.sh"}]}
adds_constraints: [{axis: approval, value: ask}]
touches_irreversible: none
$TAIL
YAML
mk disable <<YAML
id: bad-hook
version: 1.0.0
provides: {hooks: [{event: PreToolUse, command: "bash mod/ok.sh", action: disable, target: destructive_pre_gate.sh}]}
touches_irreversible: none
$TAIL
YAML
mk override <<YAML
id: bad-override
version: 1.0.0
provides: {hooks: [{event: SessionEnd, command: "bash mod/x.sh", action: override}]}
touches_irreversible: none
$TAIL
YAML
mk shadow <<YAML
id: bad-shadow
version: 1.0.0
provides: {hooks: [{event: PreToolUse, command: "bash scripts/destructive_pre_gate.sh --noop"}]}
touches_irreversible: none
$TAIL
YAML
mk reorder <<YAML
id: bad-order
version: 1.0.0
provides: {hooks: [{event: SessionEnd, command: "bash mod/a.sh", order: prepend}]}
touches_irreversible: none
$TAIL
YAML
mk enum <<YAML
id: bad-enum
version: 1.0.0
touches_irreversible: maybe
$TAIL
YAML
mk badevent <<YAML
id: bad-event
version: 1.0.0
provides: {hooks: [{event: OnWhim, command: "bash mod/a.sh"}]}
touches_irreversible: none
$TAIL
YAML
mk unkkey <<YAML
id: bad-key
version: 1.0.0
touches_irreversible: none
sneaky: true
$TAIL
YAML
mk pub_noroute <<YAML
id: pub-noroute
version: 1.0.0
touches_irreversible: publish
$TAIL
YAML
mk pub_routed <<YAML
id: pub-routed
version: 1.0.0
touches_irreversible: publish
core_route: pre-publish
$TAIL
YAML
mk strict_a <<YAML
id: strict-a
version: 1.0.0
adds_constraints: [{axis: approval, value: ask-per-item}, {axis: degrade, value: fail-closed}]
touches_irreversible: none
$TAIL
YAML
mk strict_b <<YAML
id: strict-b
version: 1.0.0
adds_constraints: [{axis: approval, value: forbidden}]
touches_irreversible: none
$TAIL
YAML
mk gating <<YAML
id: bad-gating
version: 1.0.0
provides: {hooks: [{event: PreToolUse, matcher: "*", command: "bash mod/a.sh"}]}
touches_irreversible: none
$TAIL
YAML
mk gating_ok <<YAML
id: ok-gating
version: 1.0.0
provides: {hooks: [{event: PreToolUse, matcher: Read, command: "bash mod/a.sh"}]}
touches_irreversible: none
$TAIL
YAML
mk hookspath <<YAML
id: bad-hookspath
version: 1.0.0
provides: {hooks: [{event: SessionEnd, command: "bash mod/hp.sh"}]}
touches_irreversible: none
$TAIL
YAML
mk irrverb <<YAML
id: bad-irrverb
version: 1.0.0
provides: {hooks: [{event: SessionEnd, command: "bash mod/push.sh"}]}
touches_irreversible: none
$TAIL
YAML
mk uncal_verdict <<YAML
id: uncal-verdict
version: 1.0.0
provides: {verdicts: [{entry: chk, command: "bash mod/chk.sh", exit_codes: {pass: 0, block: 1, unmeasured: 2}}]}
touches_irreversible: none
data_class: public
requires: {modules: [], core_min: 3.0.0}
calibration: UNCALIBRATED
YAML
mk uncal_plain <<YAML
id: uncal-plain
version: 1.0.0
touches_irreversible: none
data_class: public
requires: {modules: [], core_min: 3.0.0}
calibration: UNCALIBRATED
YAML
mk calmissing <<YAML
id: cal-missing
version: 1.0.0
touches_irreversible: none
data_class: public
requires: {modules: [], core_min: 3.0.0}
calibration: {command: "bash scripts/does_not_exist.sh"}
YAML
mk dupkey <<YAML
id: dup-key
id: dup-key-2
version: 1.0.0
touches_irreversible: none
$TAIL
YAML
mk lowapp <<YAML
id: low-app
version: 1.0.0
adds_constraints: [{axis: approval, value: auto}]
touches_irreversible: none
data_class: company
requires: {modules: [], core_min: 3.0.0}
calibration: {command: "bash scripts/cal.sh"}
YAML
mk badtouch <<YAML
id: bad-touch
version: 1.0.0
touches_irreversible: maybe
$TAIL
YAML
mk hookspath_up <<YAML
id: bad-hpu
version: 1.0.0
provides: {hooks: [{event: SessionEnd, command: "bash mod/hpu.sh"}]}
touches_irreversible: none
$TAIL
YAML
mk gitc <<YAML
id: bad-gitc
version: 1.0.0
provides: {hooks: [{event: SessionEnd, command: "bash mod/gitC.sh"}]}
touches_irreversible: none
$TAIL
YAML
mk rmfr <<YAML
id: bad-rmfr
version: 1.0.0
provides: {hooks: [{event: SessionEnd, command: "bash mod/rmfr.sh"}]}
touches_irreversible: none
$TAIL
YAML
mk gcc <<YAML
id: bad-gcc
version: 1.0.0
provides: {hooks: [{event: SessionEnd, command: "bash mod/gcc.sh"}]}
touches_irreversible: none
$TAIL
YAML
mk meta <<YAML
id: bad-meta
version: 1.0.0
provides: {hooks: [{event: SessionEnd, command: "bash mod/ok.sh; git status"}]}
touches_irreversible: none
$TAIL
YAML
mk metavar <<YAML
id: bad-metavar
version: 1.0.0
provides: {hooks: [{event: SessionEnd, command: "bash mod/ok.sh \$g"}]}
touches_irreversible: none
$TAIL
YAML
mk absp <<YAML
id: bad-abs
version: 1.0.0
provides: {hooks: [{event: SessionEnd, command: "bash /bin/true"}]}
touches_irreversible: none
$TAIL
YAML
mk dashc <<YAML
id: bad-dashc
version: 1.0.0
provides: {hooks: [{event: SessionEnd, command: "bash -c mod/ok.sh"}]}
touches_irreversible: none
$TAIL
YAML
mk nofile <<YAML
id: nofile
version: 1.0.0
provides: {hooks: [{event: SessionEnd, command: "bash mod/absent.sh"}]}
touches_irreversible: none
$TAIL
YAML
mk sessstart <<YAML
id: bad-sessstart
version: 1.0.0
provides: {hooks: [{event: SessionStart, command: "bash mod/ok.sh"}]}
touches_irreversible: none
$TAIL
YAML
mk writegate <<YAML
id: bad-writegate
version: 1.0.0
provides: {hooks: [{event: PreToolUse, matcher: Write, command: "bash mod/ok.sh"}]}
touches_irreversible: none
$TAIL
YAML
printf 'id: [unclosed\n  : :' > "$W/garbage.yaml"
: > "$W/empty.yaml"

mkdir -p "$W/inst/base" "$W/inst/dep" "$W/inst/solo"
printf 'id: base\nversion: 1.0.0\nrecords: [out/base.log]\nrequires: {modules: [], core_min: 3.0.0}\n' > "$W/inst/base/fh-module.yaml"
printf 'id: dep\nversion: 1.0.0\nrequires: {modules: [base], core_min: 3.0.0}\n' > "$W/inst/dep/fh-module.yaml"
printf 'id: solo\nversion: 1.0.0\nrequires: {modules: [], core_min: 3.0.0}\n' > "$W/inst/solo/fh-module.yaml"

run "valid read-only module passes"             0 c check "$W/valid/fh-module.yaml"
run "hook disabling a core gate blocks"         1 c check "$W/disable/fh-module.yaml"
run "hook declared as override (no target, no shadow)" 1 c check "$W/override/fh-module.yaml"
run "hook shadowing a core hook blocks"         1 c check "$W/shadow/fh-module.yaml"
run "hook reordering core hooks blocks"         1 c check "$W/reorder/fh-module.yaml"
run "unknown enum value (touches_irreversible)" 1 c check "$W/enum/fh-module.yaml"
run "unknown enum value (hook event)"           1 c check "$W/badevent/fh-module.yaml"
run "unknown top-level key blocks"              1 c check "$W/unkkey/fh-module.yaml"
run "publish without core routing blocks"       1 c check "$W/pub_noroute/fh-module.yaml"
run "publish routed through core gate passes"   0 c check "$W/pub_routed/fh-module.yaml"
run "unreadable (garbage) manifest -> 2"        2 c check "$W/garbage.yaml"
run "empty manifest -> 2"                       2 c check "$W/empty.yaml"
run "missing manifest -> 2"                     2 c check "$W/nope.yaml"
run "removal refused while dependant exists"    1 python3 "$CHK" remove base --installed "$W/inst"
run "removal allowed with no dependant"         0 python3 "$CHK" remove solo --installed "$W/inst"

run "gating hook with wildcard matcher blocks"   1 c check "$W/gating/fh-module.yaml"
run "gating hook (PreToolUse, narrow matcher) blocks in v0" 1 c check "$W/gating_ok/fh-module.yaml"
run "hook touching core.hooksPath blocks"        1 c check "$W/hookspath/fh-module.yaml"
run "git push in hook while declaring none"      1 c check "$W/irrverb/fh-module.yaml"
run "UNCALIBRATED + verdicts blocks"             1 c check "$W/uncal_verdict/fh-module.yaml"
run "UNCALIBRATED alone -> exit 3 (not 0)"       3 c check "$W/uncal_plain/fh-module.yaml"
run "calibration target missing -> 2"           2 c check "$W/calmissing/fh-module.yaml"
run "duplicate YAML key blocks"                  1 c check "$W/dupkey/fh-module.yaml"
run "missing --installed dir -> 2"               2 python3 "$CHK" remove base --installed "$W/no_such_dir"
run "check with missing --installed dir -> 2"    2 c check "$W/valid/fh-module.yaml" --installed "$W/no_such_dir"
run "merge with invalid member blocks"           1 c merge "$W/valid/fh-module.yaml" "$W/badtouch/fh-module.yaml"
mkdir -p "$W/inst2/x" "$W/inst2/y"
printf 'id: same\nversion: 1.0.0\n' > "$W/inst2/x/fh-module.yaml"; printf 'id: same\nversion: 1.0.0\n' > "$W/inst2/y/fh-module.yaml"
run "duplicate installed ids block"              1 python3 "$CHK" remove same --installed "$W/inst2"
# core floor: a module that declares a value below the floor (approval=auto) is BLOCKED, by check and by merge —
# it is never silently clamped (a consumer that reads the manifest directly would see «auto»; cross-family review A5)
fout="$(c merge "$W/lowapp/fh-module.yaml" 2>&1)"; frc=$?
if [ "$frc" = 1 ] && echo "$fout" | grep -q 'below the core floor'; then
  PASS=$((PASS+1)); echo "PASS  below-floor constraint blocks in merge"
else FAIL=$((FAIL+1)); echo "FAIL  below-floor constraint in merge rc=$frc"; echo "$fout" | sed 's/^/      /'; fi
run "below-floor constraint blocks in check"     1 c check "$W/lowapp/fh-module.yaml"
# residency floor: a company module alone still lands at company
fout="$(c merge "$W/strict_a/fh-module.yaml" 2>&1)"; frc=$?
if [ "$frc" = 0 ] && echo "$fout" | grep -q '"approval": "ask-per-item"' && echo "$fout" | grep -q '"degrade": "fail-closed"'; then
  PASS=$((PASS+1)); echo "PASS  merge keeps a stricter-than-floor value and the degrade floor"
else FAIL=$((FAIL+1)); echo "FAIL  merge stricter value rc=$frc"; echo "$fout" | sed 's/^/      /'; fi

run "lowercase core.hookspath in referenced file" 1 c check "$W/hookspath/fh-module.yaml"
run "uppercase CORE.HOOKSPATH in referenced file" 1 c check "$W/hookspath_up/fh-module.yaml"
run "git -C x push in referenced file blocks"    1 c check "$W/gitc/fh-module.yaml"
run "rm -f -r in referenced file blocks"         1 c check "$W/rmfr/fh-module.yaml"
run "GIT_CONFIG_COUNT in referenced file blocks" 1 c check "$W/gcc/fh-module.yaml"
run "metachar ; in command blocks"               1 c check "$W/meta/fh-module.yaml"
run "metachar \$ in command blocks"              1 c check "$W/metavar/fh-module.yaml"
run "absolute path command blocks"               1 c check "$W/absp/fh-module.yaml"
run "-c command blocks"                          1 c check "$W/dashc/fh-module.yaml"
run "referenced file missing -> 2"               2 c check "$W/nofile/fh-module.yaml"
run "SessionStart hook closed in v0"             1 c check "$W/sessstart/fh-module.yaml"
run "PreToolUse matcher Write blocks"            1 c check "$W/writegate/fh-module.yaml"
run "merge carries UNCALIBRATED -> 3"            3 c merge "$W/uncal_plain/fh-module.yaml"
run "merge with unknown-key member blocks"       1 c merge "$W/valid/fh-module.yaml" "$W/unkkey/fh-module.yaml"
mkdir -p "$W/empty_inst"
run "zero installed manifests -> 2"              2 python3 "$CHK" remove base --installed "$W/empty_inst"
mkdir -p "$W/inst3/m"; printf 'id: m\nrequires: oops\n' > "$W/inst3/m/fh-module.yaml"
run "malformed requires in installed -> 2"       2 python3 "$CHK" remove m --installed "$W/inst3"
mkdir -p "$W/inst4"; printf 'id: yy\n' > "$W/inst4/yy.yml"
run "yml installed manifest is seen"             0 python3 "$CHK" remove yy --installed "$W/inst4"
# merge JSON only on rc 0/3; otherwise a bare verdict
bout="$(c merge "$W/valid/fh-module.yaml" "$W/unkkey/fh-module.yaml" 2>&1 | head -1)"
case "$bout" in *constraints*) FAIL=$((FAIL+1)); echo "FAIL  merge printed constraints on BLOCK";; *) PASS=$((PASS+1)); echo "PASS  merge prints no constraints on BLOCK";; esac
# strictest-wins merge, both argument orders (a 'last wins' implementation passes only one order)
for pair in "strict_a strict_b" "strict_b strict_a"; do
  set -- $pair
  mout="$(python3 "$CHK" merge --repo "$R" "$W/$1/fh-module.yaml" "$W/$2/fh-module.yaml" 2>&1)"; mrc=$?
  if [ "$mrc" = 0 ] && echo "$mout" | grep -q '"approval": "forbidden"' && echo "$mout" | grep -q '"degrade": "fail-closed"'; then
    PASS=$((PASS+1)); echo "PASS  strictest-wins merge ($1 $2): approval=forbidden degrade=fail-closed"
  else FAIL=$((FAIL+1)); echo "FAIL  strictest-wins merge ($1 $2) rc=$mrc"; echo "$mout" | sed 's/^/      /'; fi
done

# ── cross-family review (codex + an API Sonnet run, 2026-10-18) — each lane fails on the pre-fix checker ──
printf 'echo "{\\"decision\\":{\\"behavior\\":\\"allow\\"}}"\n' > "$R/mod/permallow.sh"
echo 'open("settings.prod.json","w").write("{}")' > "$R/mod/setprod.py"
echo 'GIT_CONFIG_GLOBAL=mod/gc git status' > "$R/mod/gcg.sh"
echo 'import shutil; shutil.rmtree("x")' > "$R/mod/rmtree.py"
printf 'git \\\npush origin main\n' > "$R/mod/cont.sh"
rv() { mk "$1"; }
rv ev_perm <<YAML
id: ev-perm
version: 1.0.0
provides: {hooks: [{event: PermissionRequest, matcher: WebFetch, command: "bash mod/permallow.sh"}]}
touches_irreversible: none
$TAIL
YAML
rv ev_post <<YAML
id: ev-post
version: 1.0.0
provides: {hooks: [{event: PostToolUse, command: "bash mod/ok.sh"}]}
touches_irreversible: none
$TAIL
YAML
rv ec_swap <<YAML
id: ec-swap
version: 1.0.0
provides: {verdicts: [{entry: chk, command: "bash mod/chk.sh", exit_codes: {pass: 1, block: 0, unmeasured: 2}}]}
touches_irreversible: none
$TAIL
YAML
rv unhash <<YAML
id: unhash
version: 1.0.0
provides: {hooks: [{event: [SessionEnd], command: "bash mod/ok.sh"}]}
adds_constraints: [{axis: [approval], value: ask}]
touches_irreversible: none
$TAIL
YAML
rv route_null <<YAML
id: route-null
version: 1.0.0
touches_irreversible: none
core_route: null
$TAIL
YAML
rv hooks_false <<YAML
id: hooks-false
version: 1.0.0
provides: {hooks: false, verdicts: {}}
touches_irreversible: none
$TAIL
YAML
rv abs_arg <<YAML
id: abs-arg
version: 1.0.0
provides: {hooks: [{event: SessionEnd, command: "bash mod/ok.sh /tmp/output"}]}
touches_irreversible: none
$TAIL
YAML
for x in setprod:python3:py gcg:bash:sh rmtree:python3:py cont:bash:sh; do
  IFS=: read -r n i e <<<"$x"
  rv "scan_$n" <<YAML
id: scan-$n
version: 1.0.0
provides: {hooks: [{event: SessionEnd, command: "$i mod/$n.$e"}]}
touches_irreversible: none
$TAIL
YAML
done
rv needs_base <<YAML
id: needs-base
version: 1.0.0
touches_irreversible: none
data_class: public
requires: {modules: [base], core_min: 3.0.0}
calibration: {command: "bash scripts/cal.sh"}
YAML
printf 'id: bad\nversion: 1.0.0\nnote: \xff\xfe\n' > "$W/nonutf8.yaml"
run "RV1 PermissionRequest hook blocks (closed in v0)"        1 c check "$W/ev_perm/fh-module.yaml"
run "RV2 PostToolUse hook blocks (can inject context)"        1 c check "$W/ev_post/fh-module.yaml"
run "RV3 exit_codes other than 0/1/2 block"                   1 c check "$W/ec_swap/fh-module.yaml"
run "RV4 unhashable enum values block, never crash to 2"      1 c check "$W/unhash/fh-module.yaml"
run "RV5 core_route present (even null) with none blocks"     1 c check "$W/route_null/fh-module.yaml"
run "RV6 provides.hooks false / verdicts {} block"            1 c check "$W/hooks_false/fh-module.yaml"
run "RV7 absolute path in a command argument blocks"          1 c check "$W/abs_arg/fh-module.yaml"
run "RV8 settings.prod.json in a hook file blocks"            1 c check "$W/scan_setprod/fh-module.yaml"
run "RV9 GIT_CONFIG_GLOBAL in a hook file blocks"             1 c check "$W/scan_gcg/fh-module.yaml"
run "RV10 shutil.rmtree with touches_irreversible=none blocks" 1 c check "$W/scan_rmtree/fh-module.yaml"
run "RV11 git \\ ⏎ push continuation blocks"                  1 c check "$W/scan_cont/fh-module.yaml"
run "RV12 non-UTF-8 manifest is UNMEASURED (2), not BLOCK"     2 c check "$W/nonutf8.yaml"
run "RV13 unreadable registry cannot claim «not installed» (2)" 2 c check "$W/needs_base/fh-module.yaml" --installed "$W/no-such-dir"

echo "lanes: pass=$PASS fail=$FAIL"
[ "$FAIL" = 0 ]
