#!/usr/bin/env bash
# test_fh_gate_defaults_lanes.sh — what fh-gate does when the caller opts into nothing (3.45.0).
#
# WHY. #1147 made /code-review the default review on the claude backend, added an «elephant» pass at level full and
# an execution layer (E1 runs the repository's own lanes) — all on by default. Whether a headless `/code-review` (or
# the absorbed FH pass) returns the structured object the gate needs was never measured, and the GitHub Action always
# passed FH_TIMEOUT=120. Published as is, a consumer who changed nothing could get exit 10 on every run, and E1 would
# start executing their repository's code. So until those paths are measured, the default is the 3.44.0 review:
#   D1  claude backend, nothing set, level full → fh-legacy · no elephant call · E0/E1 «NOT RUN (off by default …)»
#   D2  codex backend, nothing set → fh-legacy (not the absorbed pass, not labelled fallback)
#   D3  FH_REVIEWER=code-review (opt-in) → the /code-review call is made
#   D4  FH_REVIEWER=fh (opt-in) → the absorbed pass is made
#   D5  FH_GATE_ELEPHANT=auto at level full (opt-in) → the elephant pass is made
#   D6  FH_GATE_EXEC=on (opt-in) → E1 is not «NOT RUN (off by default …)»
#   D8  cross with nothing set → the legs say the execution layer is off by default (cross-family R1)
#   D9  --help names fh-legacy as the default reviewer
#   D10 FH_REVIEWER=fh and the elephant pass get exactly Read/Glob/Grep — no shell, no MCP, no skill (D10b: control)
#   D11 FH_REVIEWER=code-review keeps git but runs without the five GITHUB_* command-file variables
#   D12 run from a copy with no action.yml (package shape): D7 is SKIPPED by name — not a pass, not a fail
#   D14 FH_REVIEWER=code-review loads user settings only, and its prompt comes after `--` (the real CLI reads it then)
#   D15 every codex review call (default, goldfish, elephant) has --ignore-user-config before its prompt marker
#   D17 codex with no FH_MODEL passes no -m (codex picks a model its login accepts); FH_MODEL=x passes -m x
#   D16 a codex user config that names where requests go (model_provider other than openai, model_providers,
#       openai_base_url, chatgpt_base_url) or cannot be read → exit 10, no codex call; a plain or absent config proceeds
#   D7  action.yml does not put FH_TIMEOUT in the step env; it exports it only when the `timeout` input (default '') is non-empty
#       (known pair: the shipped file passes; a planted «FH_TIMEOUT: ${{ inputs.timeout }}» env line is caught)
# Token-free: claude and codex are stubs that answer by request kind and log what they were asked.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/fixture_guard_lib.sh"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE="$HERE/fh-gate.sh"; ACTION="$HERE/../action.yml"
TMPROOT=$(mktemp -d "${TMPDIR:-/tmp}/fh_gate_defaults_XXXXXX")
trap 'rm -rf "$TMPROOT"' EXIT
export FH_RECORD_BASE="$TMPROOT/records"; mkdir -p "$FH_RECORD_BASE"
unset FH_REVIEWER FH_GATE_ELEPHANT FH_GATE_EXEC FH_TIMEOUT FH_GATE_LEVEL
pass=0; fail=0; skipped=0
ok()  { printf 'PASS  %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf 'FAIL  %s — %s\n' "$1" "$2"; fail=$((fail + 1)); }
g() { git -c user.name=t -c user.email=t@t -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@"; }

FAKEBIN="$TMPROOT/bin"; mkdir -p "$FAKEBIN"
cat > "$FAKEBIN/claude" <<'FAKE'
#!/usr/bin/env bash
in=$(cat); args=" $* "; kind=legacy
case "$args" in *"/code-review "*) kind=cr ;; esac
case "$in" in *"FH ELEPHANT PASS"*) kind=ele ;; *"FH REVIEW PASS"*) kind=abs ;; esac
: > "${LOGDIR:-/tmp}/claude_${kind}.called"
printf '%s\n' "$@" > "${LOGDIR:-/tmp}/claude_${kind}.args"; env > "${LOGDIR:-/tmp}/claude_${kind}.env"
pwd -P > "${LOGDIR:-/tmp}/claude_${kind}.cwd"
empty='{"status":"SUCCESS","findings":[]}'
case "$kind" in legacy) p="$FAKE_PAYLOAD" ;; *) p="$empty" ;; esac
printf '{"is_error":false,"subtype":"success","structured_output":%s}\n' "$p"
FAKE
cat > "$FAKEBIN/codex" <<'FAKE'
#!/usr/bin/env bash
all=$(printf '%s\n' "$@")
out=""; while [ $# -gt 0 ]; do case "$1" in -o) out="$2"; shift 2 ;; *) shift ;; esac; done
in=$(cat); kind=legacy
case "$in" in *"FH ELEPHANT PASS"*) kind=ele ;; *"FH REVIEW PASS"*) kind=abs ;; esac
: > "${LOGDIR:-/tmp}/codex_${kind}.called"
bn="${FAKE_CODEX_BANNER:-}"; [ "$kind" = ele ] && [ -n "${FAKE_CODEX_BANNER_ELE:-}" ] && bn="$FAKE_CODEX_BANNER_ELE"
if [ -n "$bn" ]; then printf 'OpenAI Codex (stub)\n--------\nmodel: %s\n--------\nuser\nmodel: echoed-from-prompt\n' "$bn" >&2; fi
if [ -n "${FAKE_CODEX_ECHO_ONLY:-}" ]; then printf 'OpenAI Codex (stub)\n--------\nuser\nmodel: echoed-from-prompt\n' >&2; fi
printf '%s\n' "$all" > "${LOGDIR:-/tmp}/codex_${kind}.args"; pwd -P > "${LOGDIR:-/tmp}/codex_${kind}.cwd"
empty='{"status":"SUCCESS","findings":[]}'
case "$kind" in legacy) p="$FAKE_PAYLOAD" ;; *) p="$empty" ;; esac
[ -n "$out" ] && printf '%s' "$p" > "$out"
exit 0
FAKE
chmod +x "$FAKEBIN/claude" "$FAKEBIN/codex"
export PATH="$FAKEBIN:$PATH"
# The codex calls read the runner's codex user config (the provider guard does); pin it to an empty home so the lane
# does not depend on whose machine runs it. D16 points CODEX_HOME at its own fixtures.
export CODEX_HOME="$TMPROOT/codexhome-none"
export FAKE_PAYLOAD='{"status":"SUCCESS","verdict":"PASS","findings_count":0,"findings_a":0,"findings_b":0,"findings":[]}'

REPO="$TMPROOT/repo"; mkdir -p "$REPO/scripts"
g -C "$REPO" init -q -b main
printf '#!/usr/bin/env bash\necho ok\n' > "$REPO/scripts/foo.sh"; g -C "$REPO" add -A; g -C "$REPO" commit -qm "add foo"
g -C "$REPO" checkout -qb feat
printf '#!/usr/bin/env bash\necho ok two\n' > "$REPO/scripts/foo.sh"; g -C "$REPO" commit -qam "change foo"

gate() {   # gate <name> [env...]
  local name="$1"; shift
  mkdir -p "$TMPROOT/$name"
  ( cd "$REPO" && env LOGDIR="$TMPROOT/$name" "$@" bash "$GATE" ) > "$TMPROOT/$name.out" 2> "$TMPROOT/$name.err" < /dev/null
  RC=$?
}
has()    { grep -qF -- "$2" "$TMPROOT/$1.out"; }
called() { [ -e "$TMPROOT/$1/$2.called" ]; }

gate d1 FH_GATE_LEVEL=full
if [ "$RC" -eq 0 ] && has d1 'FH_GATE_REVIEWER: fh-legacy' && called d1 claude_legacy && ! called d1 claude_cr \
   && ! called d1 claude_abs && ! called d1 claude_ele && has d1 'FH_GATE_E1: not-run — NOT RUN (off by default' \
   && has d1 'FH_GATE_ELEPHANT: not-run — NOT RUN (off by default'; then
  ok "D1 claude, nothing set, level full → fh-legacy · no /code-review · no elephant · E1 off by default"
else bad "D1 claude defaults" "rc=$RC $(grep -E 'REVIEWER|ELEPHANT|E1' "$TMPROOT/d1.out" | tr '\n' '|') calls=$(ls "$TMPROOT/d1" | tr '\n' ' ')"; fi

gate d2 FH_BACKEND=codex
if [ "$RC" -eq 0 ] && has d2 'FH_GATE_REVIEWER: fh-legacy' && ! has d2 'fallback' && called d2 codex_legacy && ! called d2 codex_abs; then
  ok "D2 codex, nothing set → fh-legacy, not the absorbed pass, not labelled fallback"
else bad "D2 codex default" "rc=$RC $(grep REVIEWER "$TMPROOT/d2.out") calls=$(ls "$TMPROOT/d2" | tr '\n' ' ')"; fi

gate d3 FH_REVIEWER=code-review
if [ "$RC" -eq 0 ] && called d3 claude_cr && has d3 'FH_GATE_REVIEWER: /code-review'; then ok "D3 FH_REVIEWER=code-review (opt-in) → the /code-review call is made"
else bad "D3 code-review opt-in" "rc=$RC $(grep REVIEWER "$TMPROOT/d3.out") calls=$(ls "$TMPROOT/d3" | tr '\n' ' ')"; fi

gate d4 FH_REVIEWER=fh
if [ "$RC" -eq 0 ] && called d4 claude_abs && has d4 'FH_GATE_REVIEWER: fh — goldfish pass'; then ok "D4 FH_REVIEWER=fh (opt-in) → the absorbed pass is made"
else bad "D4 fh opt-in" "rc=$RC $(grep REVIEWER "$TMPROOT/d4.out") calls=$(ls "$TMPROOT/d4" | tr '\n' ' ')"; fi

gate d5 FH_GATE_LEVEL=full FH_GATE_ELEPHANT=auto
if [ "$RC" -eq 0 ] && called d5 claude_ele && has d5 'FH_GATE_ELEPHANT: ran'; then ok "D5 FH_GATE_ELEPHANT=auto at full (opt-in) → the elephant pass is made"
else bad "D5 elephant opt-in" "rc=$RC $(grep ELEPHANT "$TMPROOT/d5.out") calls=$(ls "$TMPROOT/d5" | tr '\n' ' ')"; fi

gate d6 FH_GATE_EXEC=on
grep '^FH_GATE_E1: ' "$TMPROOT/d6.out" > "$TMPROOT/d6.e1" 2>/dev/null
# the layer ran: E0 says «ran» (the fixture has no target lane, so E1 legitimately says «no target lane found»)
if [ "$RC" -eq 0 ] && has d6 'FH_GATE_E0: ran' && [ -s "$TMPROOT/d6.e1" ] && ! grep -qF 'off by default' "$TMPROOT/d6.e1" && ! grep -qF 'FH_GATE_EXEC=off' "$TMPROOT/d6.e1"; then ok "D6 FH_GATE_EXEC=on (opt-in) → E1 is not «off by default»"
else bad "D6 exec opt-in" "rc=$RC $(grep -E '^FH_GATE_E[01]' "$TMPROOT/d6.out" | tr '\n' '|')"; fi

# D8 — cross with nothing set: the legs report the execution layer «off by default», not «FH_GATE_EXEC=off»
gate d8 FH_BACKEND=cross FH_GATE_CROSS_ALLOW_SINGLE=1
if grep -qF '# FH_GATE_E1: not-run — NOT RUN (off by default' "$TMPROOT/d8.out" && ! grep -qF 'NOT RUN (FH_GATE_EXEC=off)' "$TMPROOT/d8.out"; then
  ok "D8 cross, nothing set → the legs say the execution layer is off by default"
else bad "D8 cross defaults" "rc=$RC $(grep -E 'E1' "$TMPROOT/d8.out" | tr '\n' '|')"; fi

# D9 — --help states the default reviewer the code applies (Area B 3.45.0: --help still said /code-review)
bash "$GATE" --help > "$TMPROOT/help.out" 2>&1
if grep -qF 'FH_REVIEWER=fh-legacy|code-review|fh review stage (default: fh-legacy' "$TMPROOT/help.out" && ! grep -qF 'default on claude: built-in /code-review' "$TMPROOT/help.out"; then
  ok "D9 --help names fh-legacy as the default reviewer"
else bad "D9 --help default reviewer" "$(grep -m2 -F 'FH_REVIEWER' "$TMPROOT/help.out" | tr '\n' '|')"; fi

# D10 — the goldfish (FH_REVIEWER=fh) and elephant passes get exactly Read/Glob/Grep: the built-in set limited by
#       --tools, no MCP server (--strict-mcp-config), no skill or command (--disable-slash-commands), and shells and
#       writers denied. An allow list alone is additive (settings, MCP write tools, skills, PowerShell stay reachable),
#       and git's read commands write files through --output=. The whole policy is asserted, not one token of it.
#       Known pair: on the 3.45.0 merge (7c5a6b7) both calls allow Bash(git diff:*) and carry none of the three flags.
argv_after() { awk -v f="$2" 'p{print; exit} $0==f{p=1}' "$1"; }
has_pair()   { awk -v f="$2" -v v="$3" 'p&&$0==v{ok=1} {p=($0==f)} END{exit !ok}' "$1"; }   # «f v» adjacent in argv
has_flag()   { grep -qxF -- "$2" "$1"; }
policy_ok() {   # policy_ok <args file> — prints what is wrong, nothing when the policy holds
  local a="$1" t al d need
  [ -s "$a" ] || { echo "no call recorded"; return; }
  t=$(argv_after "$a" --tools); al=$(argv_after "$a" --allowedTools); d=$(argv_after "$a" --disallowedTools)
  [ "$t" = "Read,Glob,Grep" ] || echo "tools=[$t]"
  [ "$al" = "Read,Glob,Grep" ] || echo "allow=[$al]"
  for need in Bash PowerShell Write Edit NotebookEdit WebFetch WebSearch; do [[ ",$d," == *",$need,"* ]] || echo "deny lacks $need"; done
  has_flag "$a" --strict-mcp-config || echo "no --strict-mcp-config"
  has_flag "$a" --disable-slash-commands || echo "no --disable-slash-commands"
  ! has_flag "$a" --mcp-config || echo "an --mcp-config was passed"
  # the reviewed checkout is untrusted: its project/local settings and hooks must not load (2026-11-22)
  [ "$(argv_after "$a" --setting-sources)" = "user" ] || echo "setting-sources=[$(argv_after "$a" --setting-sources)]"
}
gate d10 FH_REVIEWER=fh FH_GATE_ELEPHANT=on
p_abs=$(policy_ok "$TMPROOT/d10/claude_abs.args" | tr '\n' ' '); p_ele=$(policy_ok "$TMPROOT/d10/claude_ele.args" | tr '\n' ' ')
if [ "$RC" -eq 0 ] && [ -z "$p_abs" ] && [ -z "$p_ele" ]; then ok "D10 goldfish and elephant passes: exactly Read/Glob/Grep — no shell, no MCP, no skill"
else bad "D10 reviewer tool policy" "rc=$RC goldfish: ${p_abs:-ok} · elephant: ${p_ele:-ok}"; fi
# D10b — the checker itself sees a planted widening (control: one extra allowed tool on an otherwise good call)
printf '%s\n' --tools Read,Glob,Grep --strict-mcp-config --disable-slash-commands --allowedTools Read,Glob,Grep,Write \
  --disallowedTools Bash,PowerShell,Write,Edit,NotebookEdit,WebFetch,WebSearch > "$TMPROOT/planted.args"
[ -n "$(policy_ok "$TMPROOT/planted.args")" ] && ok "D10b the policy check catches a planted extra allowed tool (control alive)" || bad "D10b policy check blind" "planted Write in the allow list passed"

# D13 — the DEFAULT review call (fh-legacy, run_backend) gets the same read-only policy as the goldfish and
#       elephant passes, and runs at the repository root like them. Before 2026-11-22 run_backend passed none of
#       --tools / --strict-mcp-config / --disable-slash-commands / -s read-only (found by a codex review of a README
#       claim). Run from a subfolder so «runs at the repo root» is distinguishable from «runs where it was called».
mkdir -p "$TMPROOT/d13c" "$TMPROOT/d13x"
( cd "$REPO/scripts" && env LOGDIR="$TMPROOT/d13c" bash "$GATE" ) > "$TMPROOT/d13c.out" 2>&1 < /dev/null; rc_c=$?
( cd "$REPO/scripts" && env LOGDIR="$TMPROOT/d13x" FH_BACKEND=codex bash "$GATE" ) > "$TMPROOT/d13x.out" 2>&1 < /dev/null; rc_x=$?
root_p=$(cd "$REPO" && pwd -P)
p_leg=$(policy_ok "$TMPROOT/d13c/claude_legacy.args" | tr '\n' ' ')
[ "$(cat "$TMPROOT/d13c/claude_legacy.cwd" 2>/dev/null)" = "$root_p" ] || p_leg="${p_leg}cwd=[$(cat "$TMPROOT/d13c/claude_legacy.cwd" 2>/dev/null)] "
if [ "$rc_c" -eq 0 ] && [ -z "$p_leg" ]; then ok "D13a default claude review: exactly Read/Glob/Grep, no MCP, no skill, at the repo root"
else bad "D13a default claude review policy" "rc=$rc_c ${p_leg:-ok}"; fi
x_bad=""
grep -qxF -- "-s" "$TMPROOT/d13x/codex_legacy.args" 2>/dev/null && [ "$(argv_after "$TMPROOT/d13x/codex_legacy.args" -s)" = "read-only" ] || x_bad="no -s read-only "
[ "$(cat "$TMPROOT/d13x/codex_legacy.cwd" 2>/dev/null)" = "$root_p" ] || x_bad="${x_bad}cwd=[$(cat "$TMPROOT/d13x/codex_legacy.cwd" 2>/dev/null)]"
has_pair "$TMPROOT/d13x/codex_legacy.args" -c "project_doc_max_bytes=0" 2>/dev/null || x_bad="${x_bad}reads the checkout AGENTS.md (no -c project_doc_max_bytes=0) "
if [ "$rc_x" -eq 0 ] && [ -z "$x_bad" ]; then ok "D13b default codex review: -s read-only, no checkout AGENTS.md, at the repo root"
else bad "D13b default codex review policy" "rc=$rc_x ${x_bad:-ok}"; fi

# D13c — the opt-in codex goldfish and elephant passes do not read the reviewed checkout's AGENTS.md either.
#        Measured 2026-11-22 (real codex 0.164.0, local fake API, planted fixture): without the flag the request
#        carries the checkout's AGENTS.md; with `-c project_doc_max_bytes=0` it does not.
gate d13y FH_BACKEND=codex FH_REVIEWER=fh FH_GATE_ELEPHANT=on
y_bad=""
for k in abs ele; do
  f="$TMPROOT/d13y/codex_${k}.args"
  [ -s "$f" ] || { y_bad="${y_bad}${k}: no call recorded "; continue; }
  has_pair "$f" -c "project_doc_max_bytes=0" || y_bad="${y_bad}${k}: no -c project_doc_max_bytes=0 "
  [ "$(argv_after "$f" -s)" = "read-only" ] || y_bad="${y_bad}${k}: no -s read-only "
done
if [ "$RC" -eq 0 ] && [ -z "$y_bad" ]; then ok "D13c codex goldfish and elephant passes: -s read-only, no checkout AGENTS.md"
else bad "D13c codex opt-in passes" "rc=$RC ${y_bad:-ok}"; fi

# D11 — /code-review keeps git (it needs it), so its call runs without the runner's five command-file variables.
#       (This only removes the direct reference — the path stays labelled not read-only.)
gate d11 FH_REVIEWER=code-review GITHUB_ENV="$TMPROOT/gh1" GITHUB_PATH="$TMPROOT/gh2" GITHUB_OUTPUT="$TMPROOT/gh3" GITHUB_STATE="$TMPROOT/gh4" GITHUB_STEP_SUMMARY="$TMPROOT/gh5"
if [ "$RC" -eq 0 ] && [ -s "$TMPROOT/d11/claude_cr.env" ] && ! grep -qE '^GITHUB_(ENV|PATH|OUTPUT|STATE|STEP_SUMMARY)=' "$TMPROOT/d11/claude_cr.env" \
   && [[ "$(argv_after "$TMPROOT/d11/claude_cr.args" --allowedTools)" == *"Bash(git diff:*)"* ]]; then
  ok "D11 /code-review call: git kept, none of the five GITHUB_* command-file variables in its environment"
else bad "D11 code-review env" "rc=$RC $(grep -E '^GITHUB_(ENV|PATH|OUTPUT|STATE|STEP_SUMMARY)=' "$TMPROOT/d11/claude_cr.env" 2>/dev/null | cut -d= -f1 | tr '\n' ' ')"; fi

# D14 — the opt-in /code-review call. Measured 2026-11-22 with real claude 2.1.330 on a planted checkout:
#       ① without --setting-sources user, the checkout's project and local hooks ran, its .mcp.json server started and
#         its CLAUDE.md, CLAUDE.local.md and .claude/rules text reached the call (3/3); with the flag, none of them (3/3).
#       ② the CLI reads a word after --disallowedTools as that option's value («"/code-review low" was read as a value
#         of --disallowedTools, not as a prompt»), so the call failed before any review (exit 10). With `--` in front
#         the prompt is read as a prompt. This stub does not parse argv like the real CLI, so ② is asserted on the
#         argv shape: the line before the /code-review prompt must be `--`.
cr_ok() {   # cr_ok <args file> — prints what is wrong. Options count only before the first `--` (after it, everything
           # is positional); exactly one `--`, followed by the /code-review prompt and nothing else.
  [ -s "$1" ] || { echo "no call recorded"; return; }
  awk '
    !seen && $0=="--" { seen=NR; next }
    !seen && prev=="--setting-sources" && $0=="user" { src=1 }
    seen && NR==seen+1 { if ($0 ~ /^\/code-review /) pr=1 }
    seen && NR>seen+1 { extra=1 }
    seen && $0=="--" { dup=1 }
    { prev=$0 }
    END {
      if (!seen) print "no --"
      if (!src)  print "no --setting-sources user before --"
      if (!pr)   print "prompt not right after --"
      if (extra || dup) print "more after the prompt"
    }' "$1"
}
gate d14 FH_REVIEWER=code-review
z_bad=$(cr_ok "$TMPROOT/d14/claude_cr.args" | tr '\n' ' ')
if [ "$RC" -eq 0 ] && [ -z "$z_bad" ]; then ok "D14 /code-review call: user settings only, prompt after --"
else bad "D14 code-review call" "rc=$RC ${z_bad:-ok}"; fi
# D14b — the checker sees a planted evasion (cross-family R2): --setting-sources user moved after the first `--`
#        (positional there) with a second `--` before the prompt. Control: the shipped shape passes the same checker.
printf '%s\n' --print --allowedTools Read --disallowedTools Write -- --setting-sources user -- "/code-review low" > "$TMPROOT/cr_planted.args"
printf '%s\n' --print --setting-sources user --allowedTools Read --disallowedTools Write -- "/code-review low" > "$TMPROOT/cr_good.args"
if [ -n "$(cr_ok "$TMPROOT/cr_planted.args")" ] && [ -z "$(cr_ok "$TMPROOT/cr_good.args")" ]; then
  ok "D14b the /code-review check catches a flag moved after -- (and passes the good shape)"
else bad "D14b code-review checker" "planted=[$(cr_ok "$TMPROOT/cr_planted.args" | tr '\n' ' ')] good=[$(cr_ok "$TMPROOT/cr_good.args" | tr '\n' ' ')]"; fi

# D15 — every codex review call drops the user config layer. Measured 2026-11-22 (real codex 0.164.0, isolated
#       CODEX_HOME, local fake API): when the user config marks the checkout trusted, the checkout's .codex/config.toml
#       MCP server starts and writes outside -s read-only (3/3; untrusted 0/3); `-c mcp_servers={}`, `-c projects={}`
#       and a per-path trust override did not stop it; --ignore-user-config did (0/3). Reuses the D13b/D13c calls.
#       The flag must come before the `-` prompt marker and with no `--` before it (after `--` it is a positional).
cx_ok() {   # cx_ok <args file> — prints what is wrong
  [ -s "$1" ] || { echo "no call recorded"; return; }
  awk '$0=="--"{dd=1} $0=="--ignore-user-config" && !dd && !dash {f=1} $0=="-"{dash=1}
       END{ if(!f) print "no --ignore-user-config before the prompt marker" }' "$1"
}
w_bad=""
for k in d13x/codex_legacy d13y/codex_abs d13y/codex_ele; do
  r=$(cx_ok "$TMPROOT/$k.args" | tr '\n' ' '); [ -z "$r" ] || w_bad="${w_bad}${k##*/}: $r"
done
printf '%s\n' exec -m x -s read-only -c project_doc_max_bytes=0 -- --ignore-user-config > "$TMPROOT/cx_planted.args"
printf '%s\n' exec -m x -s read-only --ignore-user-config -c project_doc_max_bytes=0 - > "$TMPROOT/cx_good.args"
[ -n "$(cx_ok "$TMPROOT/cx_planted.args")" ] && [ -z "$(cx_ok "$TMPROOT/cx_good.args")" ] || w_bad="${w_bad}checker control dead "
if [ -z "$w_bad" ]; then ok "D15 codex review calls (default, goldfish, elephant): --ignore-user-config (checker control alive)"
else bad "D15 codex user config" "$w_bad"; fi

# D16 — with the user config dropped (D15), a config that names where requests go would silently send the review to
#       codex's default provider instead. fh-gate reads that config first and fails closed (exit 10, no codex call)
#       when it sets model_provider (other than "openai"), model_providers, openai_base_url or chatgpt_base_url
#       (codex 0.164.0 config reference), or when it cannot be read. A plain or absent config proceeds.
d16() {   # d16 <name> <config text|-absent|-unreadable> → sets RC, CALLED
  local n="$1" t="$2" h="$TMPROOT/d16_$1"; mkdir -p "$h"
  case "$t" in -absent) ;; -unreadable) printf 'model = "x"\n' > "$h/config.toml"; chmod 000 "$h/config.toml" ;; *) printf '%s\n' "$t" > "$h/config.toml" ;; esac
  gate "d16$n" FH_BACKEND=codex CODEX_HOME="$h"
  CALLED=no; called "d16$n" codex_legacy && CALLED=yes
  chmod 600 "$h/config.toml" 2>/dev/null || true
}
v_bad=""
for c in 'mp|model_provider = "corp-proxy"' 'mpq|"model_provider"="corp"' 'tbl|[model_providers.corp]' 'dot|model_providers.corp.base_url = "https://x"' \
         'obu|openai_base_url = "https://proxy.example/v1"' 'cbu|chatgpt_base_url = "https://x"' \
         'prof|[profiles.work]
model_provider = "corp"' 'inl|profiles = { work = { model_provider = "corp" } }'; do
  n="${c%%|*}"; d16 "$n" "${c#*|}"
  { [ "$RC" -eq 10 ] && [ "$CALLED" = no ] && grep -qE 'model_provider|model_providers|openai_base_url|chatgpt_base_url' "$TMPROOT/d16$n.err"; } \
    || v_bad="${v_bad}${n}: rc=$RC called=$CALLED "
done
if [ "$(id -u)" = 0 ]; then
  printf '  SKIP  D16 unreadable config — NOT-APPLICABLE as root (chmod 000 is still readable; not measured, not a pass)\n'; skipped=$((skipped + 1))
else
  # exit 10 alone would not tell the named refusal from fh-gate's generic ERR trap (a failed `cat` trips that too),
  # so the message that names the reason is asserted as well
  d16 unr -unreadable
  { [ "$RC" -eq 10 ] && [ "$CALLED" = no ] && grep -qF 'cannot read the codex user config' "$TMPROOT/d16unr.err"; } \
    || v_bad="${v_bad}unreadable: rc=$RC called=$CALLED named=$(grep -cF 'cannot read the codex user config' "$TMPROOT/d16unr.err") "
  # cross-family R1 B: absence counts only when confirmed — a CODEX_HOME that cannot be searched is not «no config»
  h="$TMPROOT/d16_lockedhome"; mkdir -p "$h"; printf 'model_provider = "corp"\n' > "$h/config.toml"; chmod 000 "$h"
  gate d16lock FH_BACKEND=codex CODEX_HOME="$h"; chmod 700 "$h"
  { [ "$RC" -eq 10 ] && ! called d16lock codex_legacy && grep -qF 'cannot read the codex user config' "$TMPROOT/d16lock.err"; } \
    || v_bad="${v_bad}locked-home: rc=$RC "
fi
# a dangling config.toml link is not «no config» either
h="$TMPROOT/d16_dangling"; mkdir -p "$h"; ln -s "$TMPROOT/nowhere.toml" "$h/config.toml"
gate d16dang FH_BACKEND=codex CODEX_HOME="$h"
{ [ "$RC" -eq 10 ] && ! called d16dang codex_legacy && grep -qF 'cannot read the codex user config' "$TMPROOT/d16dang.err"; } \
  || v_bad="${v_bad}dangling-link: rc=$RC "
# cross-family R1 A: a quoted key may spell a routing key with an escape (all three are valid TOML for the real key)
for c in 'esc1|"openai\u005fbase_url" = "https://corp.example/v1"' 'esc2|"model\u005fprovider" = "azure"' \
         'esc3|"model\U0000005Fproviders".corp.base_url = "https://x"' 'esc4|"chatgpt\x5fbase_url" = "https://x"'; do
  n="${c%%|*}"; d16 "$n" "${c#*|}"
  { [ "$RC" -eq 10 ] && [ "$CALLED" = no ] && grep -qF 'escape' "$TMPROOT/d16$n.err"; } || v_bad="${v_bad}${n}: rc=$RC called=$CALLED "
done
for c in 'plain|model = "gpt-x"' 'oai|model_provider = "openai"' 'cmt|# model_provider = "corp"' \
         "oaisq|'model_provider' = 'openai'" 'oaitq|model_provider = """openai"""'; do
  n="${c%%|*}"; d16 "$n" "${c#*|}"
  { [ "$RC" -eq 0 ] && [ "$CALLED" = yes ]; } || v_bad="${v_bad}${n}(should proceed): rc=$RC called=$CALLED "
done
d16 abs -absent; { [ "$RC" -eq 0 ] && [ "$CALLED" = yes ]; } || v_bad="${v_bad}absent(should proceed): rc=$RC called=$CALLED "
if [ -z "$v_bad" ]; then ok "D16 codex provider guard: 8 route-changing configs, 4 escaped keys, unreadable/locked/dangling → exit 10, no call; plain/openai(3 spellings)/comment/absent proceed"
else bad "D16 codex provider guard" "$v_bad"; fi

# D17 — the codex default model. Measured 2026-11-22 on codex 0.164.0 with a ChatGPT-account login: `-m gpt-5.5`
#       (the old default) → 400 «The 'gpt-5.5' model is not supported when using Codex with a ChatGPT account»; no -m
#       → codex picked gpt-6.1-terra from its own catalog and answered. So with FH_MODEL unset fh-gate passes no -m;
#       an explicit FH_MODEL is still passed as -m. The governance record names the model codex resolved, read from the
#       banner line above `user` only (cross-family R1: «not pinned» alone hides which model gave the verdict).
d17gate() { local n="$1"; shift; mkdir -p "$TMPROOT/rec_$n"; gate "$n" FH_RECORD_BASE="$TMPROOT/rec_$n" "$@"; eval "RC_$n=$RC"; }
d17rec() { awk '/^  model: /{print; exit}' "$TMPROOT/rec_$1"/governance_log_*.yaml 2>/dev/null || true; }
d17gate d17  FH_BACKEND=codex FH_MODEL=
d17gate d17b FH_BACKEND=codex FH_MODEL= FAKE_CODEX_BANNER=gpt-banner-x
d17gate d17e FH_BACKEND=codex FH_MODEL= "FAKE_CODEX_BANNER=evil; touch /tmp/x"
d17gate d17n FH_BACKEND=codex FH_MODEL= FAKE_CODEX_ECHO_ONLY=1   # a «model:» only below `user` (prompt echo) must not count
d17gate d17x FH_BACKEND=codex FH_MODEL=gpt-pinned-x
d17gate d17y FH_BACKEND=codex FH_REVIEWER=fh FH_GATE_ELEPHANT=on FH_MODEL=
d17gate d17z FH_BACKEND=codex FH_REVIEWER=fh FH_GATE_ELEPHANT=on FH_MODEL=gpt-pinned-y
d17gate d17p FH_BACKEND=codex FH_REVIEWER=fh FH_GATE_ELEPHANT=on FH_MODEL= FAKE_CODEX_BANNER=gpt-rev-a FAKE_CODEX_BANNER_ELE=gpt-ele-b
u_bad=""
for n in d17 d17b d17e d17n d17x d17y d17z d17p; do eval "r=\$RC_$n"; [ "$r" -eq 0 ] || u_bad="${u_bad}$n rc=$r "; done
[ -s "$TMPROOT/d17/codex_legacy.args" ] || u_bad="${u_bad}no codex call "
has_flag "$TMPROOT/d17/codex_legacy.args" -m 2>/dev/null && u_bad="${u_bad}unset FH_MODEL still passes -m "
for k in abs ele; do
  [ -s "$TMPROOT/d17y/codex_${k}.args" ] || u_bad="${u_bad}${k}: no call "
  has_flag "$TMPROOT/d17y/codex_${k}.args" -m 2>/dev/null && u_bad="${u_bad}${k}: unset FH_MODEL still passes -m "
  has_pair "$TMPROOT/d17z/codex_${k}.args" -m gpt-pinned-y 2>/dev/null || u_bad="${u_bad}${k}: explicit FH_MODEL not passed as -m "
done
has_pair "$TMPROOT/d17x/codex_legacy.args" -m gpt-pinned-x 2>/dev/null || u_bad="${u_bad}legacy: explicit FH_MODEL not passed as -m "
[ "$(d17rec d17)"  = "  model: codex default (not pinned, resolved review unknown)" ]     || u_bad="${u_bad}record(no banner)=[$(d17rec d17)] "
[ "$(d17rec d17b)" = "  model: codex default (not pinned, resolved review gpt-banner-x)" ] || u_bad="${u_bad}record(banner)=[$(d17rec d17b)] "
[ "$(d17rec d17e)" = "  model: codex default (not pinned, resolved review unknown)" ]     || u_bad="${u_bad}record(bad banner)=[$(d17rec d17e)] "
[ "$(d17rec d17n)" = "  model: codex default (not pinned, resolved review unknown)" ]     || u_bad="${u_bad}record(echo only)=[$(d17rec d17n)] "
[ "$(d17rec d17p)" = "  model: codex default (not pinned, resolved review gpt-rev-a, elephant gpt-ele-b)" ] || u_bad="${u_bad}record(per pass)=[$(d17rec d17p)] "
# the record stays valid YAML (cross-family R2: «resolved: x» inside a plain scalar broke it): no «: » in any value,
# and where PyYAML is present the files parse and give the model back as a string
for n in d17 d17p d17x; do
  v=$(d17rec "$n"); v="${v#  model: }"; [[ "$v" != *": "* ]] || u_bad="${u_bad}$n model value has «: » "
  if python3 -c 'import yaml' 2>/dev/null; then
    python3 - "$TMPROOT/rec_$n" <<'PYY' || u_bad="${u_bad}$n record does not parse as YAML "
import glob, sys, yaml
for f in glob.glob(sys.argv[1] + "/governance_log_*.yaml"):
    d = yaml.safe_load(open(f))
    assert isinstance(d, list) and all(isinstance(x.get("model"), str) for x in d), f
PYY
  fi
done
[ "$(d17rec d17x)" = "  model: gpt-pinned-x" ]                                       || u_bad="${u_bad}record(pinned)=[$(d17rec d17x)] "
if [ -z "$u_bad" ]; then ok "D17 codex: no FH_MODEL → no -m on all three calls, record names the resolved model per pass (unknown if not shown or not an id) and parses as YAML; FH_MODEL=x → -m x everywhere"
else bad "D17 codex default model" "${u_bad}"; fi

# D7 — action.yml's step env must not carry FH_TIMEOUT; the run block exports it only from a non-empty input.
envblock() { awk '/^ *env: *$/{e=1; next} e && /^ *run: *\|/{exit} e{print}' "$1"; }
if [ -r "$ACTION" ]; then
  envblock "$ACTION" > "$TMPROOT/env_shipped"
  sed 's/^\( *\)FH_CALLER: github-action$/\1FH_CALLER: github-action\n\1FH_TIMEOUT: ${{ inputs.timeout }}/' "$ACTION" > "$TMPROOT/action_planted.yml"
  envblock "$TMPROOT/action_planted.yml" > "$TMPROOT/env_planted"
  n_ship=$(grep -cE '^ *FH_TIMEOUT:' "$TMPROOT/env_shipped"); n_plant=$(grep -cE '^ *FH_TIMEOUT:' "$TMPROOT/env_planted")
  if [ -s "$TMPROOT/env_shipped" ] && [ "$n_ship" = 0 ] && [ "$n_plant" = 1 ] \
     && grep -qF 'if [ -n "${FH_ACTION_TIMEOUT:-}" ]; then export FH_TIMEOUT="$FH_ACTION_TIMEOUT"; fi' "$ACTION" \
     && grep -qE "^ *default: ''" <<<"$(awk '/^  timeout:/{f=1} f&&/default:/{print; exit}' "$ACTION")"; then
    ok "D7 action.yml: FH_TIMEOUT only from a non-empty timeout input (a planted env line is caught)"
  else bad "D7 action timeout pass-through" "env lines with FH_TIMEOUT: shipped=$n_ship planted=$n_plant"; fi
else
  # No action.yml here: the npm package does not ship it, and a field harness that syncs FH's lanes has none.
  # Not a pass and not a fail — named. In an FH checkout its absence is caught by test_action_yml_lanes.sh (exit 10).
  printf '  SKIP  D7 action timeout pass-through — NOT-APPLICABLE: no action.yml at %s (not measured, not a pass)\n' "$ACTION"
  skipped=$((skipped + 1))
fi

# D12 — the same lane file run from a copy with no action.yml (an installed package's shape) must SKIP D7 by name,
#       exit 0 and print no PASS for it (3.45.0 shipped this lane failing there: pmh-dev intake 2026-11-21).
if [ -z "${FHGD_INNER:-}" ]; then
  mkdir -p "$TMPROOT/pkg"; cp -R "$HERE" "$TMPROOT/pkg/scripts"
  if [ -e "$TMPROOT/pkg/action.yml" ]; then bad "D12 package-shape copy" "action.yml present in the copy — the fixture is not package-shaped"
  else
    ( cd "$TMPROOT/pkg" && FHGD_INNER=1 bash scripts/test_fh_gate_defaults_lanes.sh ) > "$TMPROOT/d12.out" 2>&1 < /dev/null; d12rc=$?
    if [ "$d12rc" -eq 0 ] && grep -q '^  SKIP  D7 .*NOT-APPLICABLE' "$TMPROOT/d12.out" && ! grep -q '^PASS  D7' "$TMPROOT/d12.out" \
       && grep -q '1 skipped (not a pass)' "$TMPROOT/d12.out"; then ok "D12 without action.yml: D7 is skipped by name, exit 0, not counted as passed"
    else bad "D12 package-shape run" "rc=$d12rc $(grep -E 'D7|lanes:' "$TMPROOT/d12.out" | tr '\n' '|')"; fi
  fi
fi

echo "fh-gate defaults lanes: $pass passed, $fail failed$( [ "$skipped" -gt 0 ] && printf ', %s skipped (not a pass)' "$skipped")"
[ "$fail" -eq 0 ]
