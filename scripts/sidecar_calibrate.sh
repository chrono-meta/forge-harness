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

probe_ollama() {
  command -v curl >/dev/null 2>&1 || { echo "ollama ABSENT — curl missing (absence measured)"; return 0; }
  curl -sf --max-time 10 "$OLLAMA_HOST_URL/api/version" >/dev/null 2>&1 || {
    printf 'ollama ABSENT — no server at the configured host (absence measured, not assumed)\n'
    printf '       set FH_OLLAMA_HOST to probe a remote node; default is loopback\n'
    return 0
  }

  local models="${FH_OLLAMA_MODELS:-}"
  if [ -z "$models" ]; then
    models=$(curl -sf --max-time 15 "$OLLAMA_HOST_URL/api/tags" 2>/dev/null \
      | python3 -c 'import json,sys
try: d=json.load(sys.stdin)
except Exception: raise SystemExit
print(",".join(m["name"] for m in d.get("models",[])[:6]))' 2>/dev/null)
  fi
  [ -n "$models" ] || { echo "ollama REACHABLE but no models listed"; return 0; }

  # Control runs ONCE per host, not per model: it is a property of the server, and repeating it per
  # model would just multiply the cost of a fact that cannot differ.
  local ctl ctl_state
  ctl=$(curl -s --max-time 20 "$OLLAMA_HOST_URL/api/generate" \
        -d '{"model":"fh-calib-nonexistent:99b","prompt":"hi","stream":false}' 2>&1)
  if printf '%s' "$ctl" | grep -qiE '"error"|not found'; then ctl_state="rejects-bogus"; else ctl_state="accepts-bogus"; fi

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
    out=$(curl -sf --max-time 240 "$OLLAMA_HOST_URL/api/generate" -d "$body" 2>/dev/null)
    if [ -z "$out" ]; then
      printf 'ollama %-22s UNREACHABLE-THIS-RUN (measured, not inferred)\n' "$m"; continue
    fi
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
