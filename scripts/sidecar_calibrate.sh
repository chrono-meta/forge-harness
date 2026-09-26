#!/usr/bin/env bash
# sidecar_calibrate.sh — measure the cross-family sidecar panel before trusting it.
#
# WHY: `auto-decorrelation` and the load-bearing cross-family gate both ask "is a different-family
# auditor reachable?" — and until now that question was answered from memory. Two measured failures
# on 2026-07-30, one in each direction:
#   · A marker was written claiming `cross-family unavailable this session`. Probed later in the same
#     session, codex ran fine. Unavailability was DECLARED, never measured.
#   · agy pinned with the slug `gemini-3.1-pro-high` answered as **Gemini 3.6 Flash** — silently, with
#     no error. "The sidecar ran" and "the model I pinned answered" are different propositions, and
#     only the second one licenses a claim about model-family diversity.
# A panel you have not probed is not a panel; it is an assumption with a hostname.
#
# WHAT IT MEASURES, per runtime — four legs, because each catches a different lie:
#   REACHABLE          the binary exists and runs at all
#   PIN-OK / UNTRUSTED-PIN
#                      a discriminating identity probe: does the answer NAME the model that was
#                      pinned? A generic "OK" proves nothing — any model returns it. This is the only
#                      anchor for a runtime that falls back silently.
#   control: rejects-bogus / accepts-bogus
#                      pin a model that cannot exist. This measures ONE thing only: whether unknown
#                      names are validated. It does NOT mean known names are served faithfully, and
#                      the gap between those is where the real trap lives — agy REJECTS nonsense yet
#                      silently served Flash for `gemini-3.1-pro-high`, a slug from its own
#                      catalogue (measured 2026-07-30). So `rejects-bogus` must never be read as
#                      "the pin is safe": the identity probe still decides. `accepts-bogus` is the
#                      stronger warning — there, the identity probe is the ONLY evidence at all.
#   VERDICT-OK / VERDICT-UNPARSEABLE
#                      ask for one bare token. A runtime that answers with agentic prose cannot carry
#                      a machine-read verdict. Measured for agy at 1.0.14 (2026-07-04) and NOT
#                      inherited here: the version has moved, and this file re-measures rather than
#                      quoting. Fitness is a per-run measurement, not a property.
#
# Detector, never a gate: ALWAYS exits 0. It reports; the caller decides. A calibration run that
# could block would make callers stop running it, which is the failure this exists to prevent.
#
# Cost: real API calls (3 short probes per runtime). Use --only to scope. `--stub-model` exists for
# the lane harness so it can drive stub CLIs without touching a real catalogue.
#
# Usage:  bash scripts/sidecar_calibrate.sh [--only codex|agy] [--stub-model NAME] [--quiet]
# Output: one block per runtime, then a PANEL line — the line a marker's `crossfamily:` leg quotes.

set -uo pipefail

ONLY=""; STUB_MODEL=""; QUIET=""; CLASSIFY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --classify) CLASSIFY="${2:-}"; shift 2 ;;
    --only) ONLY="${2:-}"; shift 2 ;;
    --stub-model) STUB_MODEL="${2:-}"; shift 2 ;;
    --quiet) QUIET=1; shift ;;
    *) shift ;;
  esac
done

TIMEOUT_BIN=""
command -v timeout >/dev/null 2>&1 && TIMEOUT_BIN="timeout"
command -v gtimeout >/dev/null 2>&1 && TIMEOUT_BIN="gtimeout"
# No coreutils timeout on stock macOS. perl's alarm is the portable watchdog; if perl is missing too,
# run WITHOUT a deadline rather than skipping the probe — a missing watchdog must never become a
# silently skipped measurement reported as absence (the same rule fh_session_load.sh applies).
_run() {
  local secs="$1"; shift
  if [ -n "$TIMEOUT_BIN" ]; then "$TIMEOUT_BIN" "$secs" "$@"
  elif command -v perl >/dev/null 2>&1; then perl -e 'alarm shift @ARGV; exec @ARGV' "$secs" "$@"
  else "$@"; fi
}

# _answer — reduce a runtime's stdout to THE MODEL'S ANSWER.
# Measured on the first real run (2026-07-30): matching against whole stdout is unsound, because a
# real CLI prints a session banner that REPEATS the pinned model back (`codex exec` emits its
# version, workdir and model config before the reply). Under a whole-stdout match, a runtime that
# merely echoes its own configuration passes the identity probe — the transport layer supplying the
# very evidence the probe exists to obtain from the model. So: take the last non-empty line, skipping
# trailing telemetry (`tokens used`, bare numbers, rule lines).
# RESIDUAL, named: this is a heuristic on line position. A runtime that prints its answer and then
# unrecognised trailing chatter would be mis-read. It is checked by the banner-echo lane, not proven
# in general; a structured output mode (JSON) would replace the heuristic and none is used here yet.
_answer() {
  awk 'BEGIN{last=""}
       {line=$0
        gsub(/\r/,"",line)
        gsub(/^[[:space:]]+|[[:space:]]+$/,"",line)
        if (line=="") next
        if (line ~ /^[-=_]{3,}$/) next
        if (tolower(line) ~ /^tokens? used/) next
        if (line ~ /^[0-9,.]+$/) next
        last=line}
       END{print last}'
}

IDENTITY_PROMPT="Answer with one line only: your exact model name and version."
VERDICT_PROMPT="Reply with exactly one word, PASS or FAIL, and nothing else. The word is PASS."
BOGUS_MODEL="zzz-nonexistent-model-9.9"

PANEL=""

# build_cmd <runtime> <model> <prompt> — fills CMD as an argv array.
# NOT a shell function passed to the watchdog: `timeout`/`gtimeout` exec a BINARY and cannot see
# shell functions, so an earlier revision fed them a function name and every probe came back as the
# runtime failing to run (caught by lane 3/4b/5b, not by reading).
build_cmd() {
  case "$1" in
    codex) CMD=(codex exec -m "$2" -c model_reasoning_effort=high --skip-git-repo-check "$3") ;;
    agy)   CMD=(agy -p "$3" --model "$2" --print-timeout 170s) ;;
    *)     CMD=("$1" "$3") ;;
  esac
}

# probe_runtime <name> <real-model-pin>
probe_runtime() {
  local rt="$1" model="$2"
  [ -n "$ONLY" ] && [ "$ONLY" != "$rt" ] && return 0
  [ -n "$STUB_MODEL" ] && model="$STUB_MODEL"

  if ! command -v "$rt" >/dev/null 2>&1; then
    printf '%-6s ABSENT — not installed on this machine (absence measured, not assumed)\n' "$rt"
    return 0
  fi

  local id_out id_raw id_rc pin_state ctl_out ctl_state v_out v_state
  build_cmd "$rt" "$model" "$IDENTITY_PROMPT"
  # 🟥 파이프로 넘기지 않고 먼저 **원문과 종료코드**를 잡는다. `_run … | _answer` 는 런타임의
  #    rc 를 버리므로 «타임아웃» 과 «답했는데 다른 모델» 이 같은 빈 문자열로 접힌다.
  #    (`${PIPESTATUS[0]}` 는 bash 전용이고, 정본은 «파이프를 쓰지 않는 것» 이다.)
  id_raw="$(_run 200 "${CMD[@]}" 2>&1)"; id_rc=$?
  id_out="$(printf '%s\n' "$id_raw" | _answer)"

  # Discriminating check — the answer must be the MODEL's self-report naming the model that was
  # pinned. What counts as "naming it" is the VERSION token, not every token of the pin slug:
  # vendors answer with a product name (`gpt-5.6-sol` → "GPT-5.6 Codex"), and demanding the suffix
  # made this report UNTRUSTED-PIN for a pin that had actually held (measured 2026-07-30). The
  # version is also exactly where the real failures differ — 3.1 asked, 3.6 answered. If a pin
  # carries no version token at all, fall back to requiring the name words, since then there is
  # nothing sharper to test.
  local ver name_words hit=0
  ver="$(printf '%s' "$model" | grep -oE '[0-9]+\.[0-9]+' | head -1)"
  name_words="$(printf '%s' "$model" | tr 'A-Z' 'a-z' | sed -E 's/[^a-z]+/ /g' \
        | tr ' ' '\n' | grep -E '^[a-z]{3,}$' \
        | grep -vE '^(high|low|medium|thinking|the|exec)$' | head -1)"
  if [ -n "$id_out" ]; then
    if [ -n "$ver" ]; then
      printf '%s' "$id_out" | grep -qF "$ver" && hit=1
    elif [ -n "$name_words" ]; then
      printf '%s' "$id_out" | tr 'A-Z' 'a-z' | grep -qF "$name_words" && hit=1
    fi
  fi
  # ── 🟥 네 값으로 가른다 — «못 쟀다» 와 «못 믿는다» 는 다른 사건이다 ────────────────
  #
  #    종전에는 둘 다 UNTRUSTED-PIN 이었다. 그래서 agy 가 **2m50s 타임아웃**으로 못 잰
  #    2026-09-14 기록과, 실제로 답을 받아 핀이 맞았던 2026-09-17 기록이 서로 모순처럼
  #    보였고 «어느 쪽이 참인지» 를 판별할 수 없었다(sidecar_panel_2026-09-18.txt 가
  #    그 갈림을 미해결로 남겼다). 같은 축의 다른 얼굴: 쿼터 소진이 «핀 불신» 으로 렌더돼
  #    런타임 전체를 못 쓰는 것처럼 보였다(Gemini 그룹만 0 % 였는데).
  #
  #    PIN-OK          신원이 핀과 맞다
  #    UNTRUSTED-PIN   **답은 왔는데** 신원이 핀과 다르다 — 바꿔치기. 이게 이 도구의 표적이다
  #    PIN-BLOCKED     런타임이 한도/쿼터/인증을 말했다 — **채널이 막힌 것**이지 모델 문제가 아니다
  #    PIN-UNMEASURED  답이 아예 안 왔다(타임아웃·빈 응답) — 측정 실패. 0 이 아니다
  #
  #    🟥 패널 편입 규칙은 **안 바꾼다**: PIN-OK 만 든다. 미측정이 패널에 끼면 그게 fail-open 이다.
  #       바뀌는 것은 «왜 빠졌나» 를 읽을 수 있게 되는 것뿐이다.
  local blocked=0
  printf '%s' "$id_raw" | grep -qiE 'quota|rate.?limit|too many requests|429|exceeded|insufficient|unauthor|forbidden|401|403' && blocked=1
  if [ "$hit" -eq 1 ]; then
    pin_state="PIN-OK"
  elif [ "$blocked" -eq 1 ]; then
    pin_state="PIN-BLOCKED"
  elif [ -z "$id_out" ] || [ "$id_rc" -ne 0 ]; then
    pin_state="PIN-UNMEASURED"
  else
    pin_state="UNTRUSTED-PIN"
  fi

  build_cmd "$rt" "$BOGUS_MODEL" "$IDENTITY_PROMPT"
  ctl_out="$(_run 120 "${CMD[@]}" 2>&1)"
  if [ $? -ne 0 ] || printf '%s' "$ctl_out" | grep -qiE 'not supported|invalid|unknown model|error'; then
    ctl_state="rejects-bogus"
  else
    ctl_state="accepts-bogus"
  fi

  build_cmd "$rt" "$model" "$VERDICT_PROMPT"
  v_out="$(_run 200 "${CMD[@]}" 2>&1 | _answer)"
  # Parseable = a bare verdict token is recoverable from a short answer. Prose that merely CONTAINS
  # the word does not qualify: a verdict channel must be readable without a human deciding what the
  # runtime meant.
  local v_compact
  v_compact="$(printf '%s' "$v_out" | tr -s '[:space:]' ' ' | sed 's/^ *//; s/ *$//')"
  if [ "${#v_compact}" -le 12 ] && printf '%s' "$v_compact" | grep -qiE '^(pass|fail)[.!]?$'; then
    v_state="VERDICT-OK"
  else
    v_state="VERDICT-UNPARSEABLE"
  fi

  printf '%-6s REACHABLE · %s · control: %s · %s\n' "$rt" "$pin_state" "$ctl_state" "$v_state"
  [ -z "$QUIET" ] && printf '       pinned: %s\n       identity said: %s\n' "$model" "$(printf '%s' "$id_out" | cut -c1-100)"
  if [ "$ctl_state" = "accepts-bogus" ]; then
    printf '       ⚠️  this runtime does not validate the pin at all, so the identity probe is the ONLY\n'
    printf '           evidence that the intended model answered — a clean run proves nothing here.\n'
  elif [ "$pin_state" = "UNTRUSTED-PIN" ]; then
    printf '       ⚠️  it rejects UNKNOWN names, which says nothing about serving KNOWN ones faithfully.\n'
    printf '           The identity probe disagreed with the pin — treat this runtime as substituting.\n'
  elif [ "$pin_state" = "PIN-BLOCKED" ]; then
    printf '       ⚠️  the runtime reported a QUOTA / AUTH problem (rc=%s). This is the CHANNEL being\n' "$id_rc"
    printf '           shut, NOT evidence that a different model answered. Do not read it as substitution;\n'
    printf '           re-run when the window reopens. It stays out of the panel because nothing was measured.\n'
  elif [ "$pin_state" = "PIN-UNMEASURED" ]; then
    printf '       ⚠️  NO ANSWER came back (rc=%s, answer empty) — the pin was **not measured**.\n' "$id_rc"
    printf '           «unmeasured» is not «untrusted» and it is not zero. Re-run before concluding anything;\n'
    printf '           a single timeout is the cheapest way to manufacture a false substitution report.\n'
  fi
  # Only a runtime whose pin is trustworthy counts toward the panel. A reachable runtime answering as
  # some other model contributes no family diversity, which is the entire point of the panel.
  [ "$pin_state" = "PIN-OK" ] && PANEL="${PANEL:+$PANEL, }$rt"
  return 0
}

# nongenerative_reason <model> — adversarial review needs a model that ANSWERS IN PROSE. Embedding /
# reranker / OCR / safeguard models accept any prompt with rc=0 and contribute nothing — counting one
# as a panel member fakes family diversity (pmh-dev@cbe3932 crossfamily_probe 델타 흡수, 2026-08-10).
# Unfit patterns are checked BEFORE family patterns on purpose: Qwen3-Embedding matches both.
nongenerative_reason() {
  local m
  m="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  case "$m" in
    *embed*)              echo "embedding" ;;
    *rerank*)             echo "reranker" ;;
    *-ocr*|*ocr-*|*ocr:*) echo "OCR" ;;
    *guard*|*shield*)     echo "safeguard" ;;
    *) return 1 ;;
  esac
}

# --classify <model-id> — query surface for the unfit filter (pmh --check-model 흡수). NOTE: this
# subcommand DOES use exit semantics (0=FIT, 1=UNFIT, 2=usage) — the always-exit-0 contract (lane 7)
# applies to CALIBRATION runs, not to this explicit query mode.
if [ -n "$CLASSIFY" ]; then
  if r=$(nongenerative_reason "$CLASSIFY"); then echo "UNFIT ($r — non-generative; not a reviewer)"; exit 1
  else echo "FIT (generative-shaped id — still needs a live pin probe)"; exit 0; fi
fi


probe_runtime codex "gpt-5.6-sol"
probe_runtime agy   "Gemini 3.1 Pro (High)"

# ── Local OpenAI-compatible panel (Ollama) — a DIFFERENT anchor, on purpose. ──────────────────
# One host serves several model FAMILIES (measured 2026-07-31: an OpenAI-lineage open-weight, a
# Qwen, a Gemma, a Mistral on one endpoint), so the panel's unit here is the model, not the binary.
# Everything is local, so nothing leaves the machine — this is the only panel member a residency-
# constrained session may use on company-adjacent work.
#
# WHY THE IDENTITY PROBE IS REPLACED, NOT REUSED — the self-report anchor above is INVALID for this
# class. Measured: `gpt-oss:20b` asked which model it is answered "The underlying model is GPT-4
# (likely)". Open-weight models do not reliably know their own name, so a self-report anchor would
# mark every one of them UNTRUSTED-PIN and drop a genuinely exact pin from the panel. Applying an
# instrument that cannot separate a known-positive from a known-negative on this target is the
# calibration failure this whole file exists to prevent — so the anchor moves to the SERVER'S
# response envelope, which reports the model actually loaded. That is a server-side fact rather
# than a model's claim, i.e. strictly stronger than what codex/agy expose through their CLIs.
#
# HOST IS NEVER HARDCODED. A LAN/Tailscale address is an internal hostname, and this file is
# public-tracked; §Company residency keeps those out of committed content. Default is loopback;
# point FH_OLLAMA_HOST at a remote node from a local, gitignored place.
OLLAMA_HOST_URL="${FH_OLLAMA_HOST:-http://127.0.0.1:11434}"
# Measured floor, not a guess: at num_predict=64 a reasoning model spent the ENTIRE budget in its
# `thinking` field (780 chars) and returned an EMPTY response — which reads identically to "cannot
# carry a verdict". At 512 the same model answered `PASS`. Budget starvation and incapacity are
# different findings and must not be reported as one.
OLLAMA_NUM_PREDICT="${FH_OLLAMA_NUM_PREDICT:-512}"
# Per-model generate deadline (seconds). Overridable so the lanes can drive a mid-body stall without
# waiting four minutes; the default is unchanged.
OLLAMA_GEN_TIMEOUT="${FH_OLLAMA_GEN_TIMEOUT:-240}"

# _http <max-secs> <url> [json-body] — one request, and it KEEPS THE STATUS CODE.
# Sets HTTP_CODE (000 when no HTTP answer came back at all), HTTP_BODY, HTTP_RC (curl's own rc).
#
# 🟥 WHY NOT `curl -sf` (2026-09-24, Glimmer G1): `-f` throws the body away on ANY 4xx/5xx and prints
#    nothing, so «the node answered "invalid model name"» and «no node answered» both reached the
#    caller as the same empty string — and the empty string was rendered UNREACHABLE-THIS-RUN with
#    «(measured, not inferred)» after it. What had been measured was the empty string, not reachability.
#    Those two point the operator in opposite directions (network vs. name/inventory), so they must
#    never share a label. Body and code travel together through one capture; the code is split off
#    the LAST line — no pipe, so no rc is dropped on the way (pipefail class lock).
_http() {
  local secs="$1" url="$2" data="${3:-}" raw
  if [ -n "$data" ]; then
    raw="$(curl -s --max-time "$secs" -w '\n%{http_code}' "$url" -d "$data" 2>/dev/null)"; HTTP_RC=$?
  else
    raw="$(curl -s --max-time "$secs" -w '\n%{http_code}' "$url" 2>/dev/null)"; HTTP_RC=$?
  fi
  HTTP_CODE="${raw##*$'\n'}"
  case "$raw" in *$'\n'*) HTTP_BODY="${raw%$'\n'*}" ;; *) HTTP_BODY="" ;; esac
  case "$HTTP_CODE" in [0-9][0-9][0-9]) : ;; *) HTTP_CODE="000" ;; esac
}

# _http_why — human reason for HTTP_CODE=000, from curl's rc. Only the common three are named; any
# other rc is printed as a number rather than guessed at.
_http_why() {
  case "$HTTP_RC" in
    7)  echo "connection refused" ;;
    28) echo "timed out" ;;
    52) echo "empty reply — connection closed without an HTTP answer" ;;
    6)  echo "host not resolved" ;;
    *)  echo "curl rc=$HTTP_RC" ;;
  esac
}

# _err_summary — the server's own words for a non-200: the JSON `error` field when there is one,
# else the first 80 chars of the raw body. One line, no parentheses (they close the label).
_err_summary() {
  local s
  s="$(printf '%s' "$HTTP_BODY" | python3 -c 'import json,sys
try: d=json.load(sys.stdin); e=d.get("error","") if isinstance(d,dict) else ""
except Exception: e=""
print(e if isinstance(e,str) else json.dumps(e))' 2>/dev/null)"
  [ -n "$s" ] || s="$HTTP_BODY"
  s="$(printf '%s' "$s" | tr '\r\n()' '  []' | cut -c1-80)"
  [ -n "$s" ] || s="empty body"
  printf '%s' "$s"
}

probe_ollama() {
  command -v curl >/dev/null 2>&1 || { echo "ollama ABSENT — curl missing (absence measured)"; return 0; }
  _http 10 "$OLLAMA_HOST_URL/api/version"
  if [ "$HTTP_CODE" = "000" ]; then
    printf 'ollama ABSENT — no server at the configured host (%s; absence measured, not assumed)\n' "$(_http_why)"
    printf '       set FH_OLLAMA_HOST to probe a remote node; default is loopback\n'
    return 0
  fi
  if [ "$HTTP_RC" -ne 0 ]; then
    # An answer started (http code present) but did not finish — nothing about the host was measured.
    printf 'ollama UNMEASURED — /api/version answered http %s but the transfer did not complete (%s)\n' "$HTTP_CODE" "$(_http_why)"
    return 0
  fi
  if [ "$HTTP_CODE" != "200" ]; then
    # Something IS listening — it just is not answering as an Ollama server. Not ABSENT.
    printf 'ollama HOST-ERROR — something answered at the configured host, but /api/version returned http %s: %s\n' \
      "$HTTP_CODE" "$(_err_summary)"
    printf '       a server was reached, so this is not absence; check that FH_OLLAMA_HOST points at Ollama\n'
    return 0
  fi
  # 🟥 «Any 200» is not «an Ollama server» (cross-family review, 2026-09-26). A host that answers
  #    200 to everything and echoes the pinned name back in a generate envelope would otherwise reach
  #    PIN-OK(envelope) and JOIN THE PANEL — the envelope anchor is only a server-side fact if the
  #    server is the one we think it is. Require the Ollama shape: a JSON object with a string
  #    `version`. Anything else is HOST-ERROR and the leg stops.
  if ! printf '%s' "$HTTP_BODY" | python3 -c 'import json,sys
d=json.load(sys.stdin)
raise SystemExit(0 if isinstance(d,dict) and isinstance(d.get("version"),str) and d["version"] else 1)' >/dev/null 2>&1; then
    printf 'ollama HOST-ERROR — /api/version returned http 200 but not the Ollama shape {"version": "..."}: %s\n' "$(_err_summary)"
    printf '       something answered, but it is not recognisably Ollama — nothing from this host enters the panel\n'
    return 0
  fi

  # ── FH_OLLAMA_MODELS: comma-separated. Whitespace around an item is trimmed; whitespace INSIDE an
  #    item is REJECTED, not normalised. Chosen deliberately (2026-09-24 G1):
  #    · Ollama model names cannot contain whitespace, so an inner space means the caller used a
  #      different separator contract. Normalising would mean the calibrator GUESSING the input it
  #      was given — and a marker quotes this run's output, so "a b" and "a,b" would become
  #      indistinguishable in the record, hiding the contract drift that caused the incident.
  #    · Trimming "a, b" is not a guess — the commas are there, only padding is removed.
  #    · The cost of rejecting is one loud, cheap rephrase (the message prints the corrected value);
  #      the cost of guessing is silent. Exit stays 0 — detector, not gate.
  local models="${FH_OLLAMA_MODELS:-}"
  if [ -n "$models" ]; then
    local cleaned="" item bad="" IFS=,
    for item in $models; do
      item="$(printf '%s' "$item" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
      [ -n "$item" ] || continue
      case "$item" in *[[:space:]]*) bad="$item" ;; esac
      cleaned="${cleaned:+$cleaned,}$item"
    done
    if [ -z "$cleaned" ]; then
      # Explicitly set, but nothing survives trimming. Falling through to /api/tags would probe
      # models the caller never named; staying silent would read as "no models".
      printf 'ollama INPUT-ERROR — FH_OLLAMA_MODELS is set but has no model names after trimming: "%s"\n' "$models"
      printf '       unset it to probe the listed models, or give a comma-separated list. Nothing was probed.\n'
      return 0
    fi
    if [ -n "$bad" ]; then
      printf 'ollama INPUT-ERROR — FH_OLLAMA_MODELS item contains whitespace: "%s"\n' "$bad"
      printf '       the separator is a COMMA; model names cannot contain spaces. Nothing was probed.\n'
      printf '       did you mean: FH_OLLAMA_MODELS="%s"\n' "$(printf '%s' "$cleaned" | tr -s '[:space:]' ',')"
      return 0
    fi
    models="$cleaned"
  else
    _http 15 "$OLLAMA_HOST_URL/api/tags"
    if [ "$HTTP_CODE" != "200" ] || [ "$HTTP_RC" -ne 0 ]; then
      # A failed listing is not an empty listing. And a tags call that got no HTTP answer did not
      # measure reachability either — say only what was measured.
      if [ "$HTTP_CODE" = "000" ]; then
        printf 'ollama model list UNMEASURED (tags call got no HTTP answer: %s) — not empty\n' "$(_http_why)"
      elif [ "$HTTP_RC" -ne 0 ]; then
        printf 'ollama model list UNMEASURED (tags call answered http %s but did not complete: %s) — not empty\n' "$HTTP_CODE" "$(_http_why)"
      else
        printf 'ollama REACHABLE but /api/tags returned http %s: %s — model list UNMEASURED, not empty\n' "$HTTP_CODE" "$(_err_summary)"
      fi
      return 0
    fi
    models=$(printf '%s' "$HTTP_BODY" | python3 -c 'import json,sys
try: d=json.load(sys.stdin)
except Exception: raise SystemExit
print(",".join(m["name"] for m in d.get("models",[])[:6]))' 2>/dev/null)
  fi
  [ -n "$models" ] || { echo "ollama REACHABLE but no models listed"; return 0; }

  # Control runs ONCE per host, not per model: it is a property of the server, and repeating it per
  # model would just multiply the cost of a fact that cannot differ.
  # 🟥 A control that got NO answer is unmeasured — it was previously read as "accepts-bogus"
  #    because an empty body contains no "error". Silence is not acceptance.
  local ctl_state
  _http 20 "$OLLAMA_HOST_URL/api/generate" '{"model":"fh-calib-nonexistent:99b","prompt":"hi","stream":false}'
  # 🟥 Only a 4xx is evidence of rejection. A 5xx is the server FAILING, which says nothing about
  #    whether it would have validated the name; 000 and an incomplete transfer measured nothing.
  #    All three are `unmeasured` (cross-family review, 2026-09-26: 5xx was read as rejects-bogus).
  case "$HTTP_CODE" in
    4[0-9][0-9]) ctl_state="rejects-bogus" ;;
    200)
      if printf '%s' "$HTTP_BODY" | grep -qiE '"error"|not found'; then ctl_state="rejects-bogus"
      else ctl_state="accepts-bogus"; fi ;;
    *) ctl_state="unmeasured" ;;
  esac
  [ "$HTTP_RC" -ne 0 ] && ctl_state="unmeasured"

  local IFS=,
  for m in $models; do
    [ -n "$m" ] || continue
    local unfit
    if unfit=$(nongenerative_reason "$m"); then
      echo "ollama/$m UNFIT ($unfit — non-generative) — excluded from panel; a prompt it rc=0-accepts is not a review"
      continue
    fi
    local body out env_model resp compact pin v
    body=$(python3 -c 'import json,sys; print(json.dumps({"model":sys.argv[1],"prompt":sys.argv[2],"stream":False,"options":{"num_predict":int(sys.argv[3]),"temperature":0}}))' \
           "$m" "$VERDICT_PROMPT" "$OLLAMA_NUM_PREDICT")
    _http "$OLLAMA_GEN_TIMEOUT" "$OLLAMA_HOST_URL/api/generate" "$body"
    # 🟥 A status line is not a completed answer. If curl failed AFTER the headers (timeout mid-body,
    #    connection reset), HTTP_CODE can read 200 while HTTP_BODY is whatever arrived — possibly a
    #    complete-looking JSON that would parse to PIN-OK and join the panel. rc≠0 wins over the code.
    if [ "$HTTP_RC" -ne 0 ] && [ "$HTTP_CODE" != "000" ]; then
      printf 'ollama %-22s UNMEASURED-THIS-RUN (http %s but the transfer did not complete: %s) — not in the panel\n' "$m" "$HTTP_CODE" "$(_http_why)"
      continue
    fi
    # Three different events, three different labels — never collapse them again:
    #   000  → no HTTP answer at all          → UNREACHABLE-THIS-RUN (this one IS about the network)
    #   4xx  → the server answered and refused → MODEL-ERROR(<its words>) — name / inventory problem
    #   5xx  → the server answered and failed  → SERVER-ERROR(<its words>) — load / OOM / runtime
    # None of them joins the panel, and none of them is PIN-OK or UNTRUSTED-PIN: nothing was served.
    case "$HTTP_CODE" in
      000)
        printf 'ollama %-22s UNREACHABLE-THIS-RUN (%s — no HTTP answer to the generate call)\n' "$m" "$(_http_why)"
        continue ;;
      4[0-9][0-9])
        printf 'ollama %-22s MODEL-ERROR(%s) · control: %s\n' "$m" "$(_err_summary)" "$ctl_state"
        printf '       the server WAS reached and answered http %s — check the model name and this node'"'"'s\n' "$HTTP_CODE"
        printf '       inventory, not the network. Not in the panel: no model was served.\n'
        continue ;;
      200) : ;;
      *)
        printf 'ollama %-22s SERVER-ERROR(http %s: %s) · control: %s\n' "$m" "$HTTP_CODE" "$(_err_summary)" "$ctl_state"
        printf '       the server WAS reached but failed to serve (load / memory / runtime). Not in the panel.\n'
        continue ;;
    esac
    out="$HTTP_BODY"
    env_model=$(printf '%s' "$out" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("model",""))' 2>/dev/null)
    resp=$(printf '%s' "$out" | python3 -c 'import json,sys; print((json.load(sys.stdin).get("response") or "").strip())' 2>/dev/null)
    compact=$(printf '%s' "$resp" | tr -s '[:space:]' ' ' | sed 's/^ *//; s/ *$//')
    if [ "$env_model" = "$m" ]; then pin="PIN-OK(envelope)"; else pin="UNTRUSTED-PIN"; fi
    if [ "${#compact}" -le 12 ] && printf '%s' "$compact" | grep -qiE '^(pass|fail)[.!]?$'; then v="VERDICT-OK"; else v="VERDICT-UNPARSEABLE"; fi
    printf 'ollama %-22s REACHABLE · %s · control: %s · %s\n' "$m" "$pin" "$ctl_state" "$v"
    [ -z "$QUIET" ] && printf '       answered: %s\n' "$(printf '%s' "$compact" | cut -c1-60)"
    if [ "$v" = "VERDICT-UNPARSEABLE" ] && [ -z "$compact" ]; then
      printf '       ⚠️  EMPTY answer. Before recording this as "cannot carry a verdict", re-run with a\n'
      printf '           larger FH_OLLAMA_NUM_PREDICT — a reasoning model can spend the whole budget\n'
      printf '           thinking and return nothing, which looks identical from out here.\n'
    fi
    [ "$pin" = "PIN-OK(envelope)" ] && [ "$v" = "VERDICT-OK" ] && PANEL="${PANEL:+$PANEL, }ollama:$m"
  done
}
# `--stub-model` means the caller is the hermetic CLI lane harness, which drives stub BINARIES and
# asserts on an empty panel. This leg talks to a SERVER, so on a developer machine with a local
# Ollama running it would populate the panel and break those lanes — which is exactly what happened
# when this was first wired (test_sidecar_calibrate_lanes lane6, "empty panel not stated", caught by
# the existing suite rather than by review). Skipping under --stub-model keeps each harness hermetic
# in its own way; this leg's own lanes drive a stub SERVER via FH_OLLAMA_HOST instead.
if [ -z "$STUB_MODEL" ] && { [ -z "$ONLY" ] || [ "$ONLY" = "ollama" ]; }; then
  probe_ollama
fi

if [ -n "$PANEL" ]; then
  echo "PANEL: $PANEL — usable different-family auditor(s), pin verified this run"
else
  echo "PANEL: none — no runtime passed the identity probe on this machine, this run"
  echo "       State this, do not infer it: a marker's crossfamily leg may say 'none' but never stay silent."
fi
exit 0
