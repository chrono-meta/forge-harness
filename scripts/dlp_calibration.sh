#!/usr/bin/env bash
# DLP filter calibration (Docker Track 2, Phase 1b — carry #1 calibrate-first).
#
# THE QUESTION: do we need a heavier filter model (70B) or does 32B/12B suffice? Literal-token
# redaction is already perfect at 12B (Phase 1b), so that is NOT the discriminator. The real test is
# AUTONOMOUS RECALL: confidential entities the operator did NOT list in REDACT_PATTERNS — does the
# model recognize them as confidential and abstract them anyway? A weak model only redacts what you
# regex-matched; a strong model catches the codename/client/person you forgot to list.
#
# MEASUREMENT (mechanical, no judge — judge-robustness): each held-out sample carries the full set of
# confidential ENTITIES; REDACT_PATTERNS covers only the OBVIOUS subset. We run the filter, then grep
# the output for each UNLISTED entity. Absent = the model caught it on its own. Recall = caught/total.
# Fictional entities only (public-safe): no real internal asset names.
#
# Usage:  OLLAMA_HOST=<node>:11434 scripts/dlp_calibration.sh ["model-a model-b ..."]
#   default models: "gemma4:12b-it-qat qwen3:32b"  · default host: host.docker.internal:11434
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
REPO="$PWD"; IMG="fh-operator:latest"
HOSTPORT="${OLLAMA_HOST:-host.docker.internal:11434}"
MODELS=(${1:-gemma4:12b-it-qat qwen3:32b})
SET="${SET:-base}"   # base = obvious entities · hard = common-word codenames / name-only / generic vendors
# source OpenRouter key (for openrouter/* models) from the local env file — never a tracked file.
[ -f "$HOME/.fh-operator.env" ] && { set -a; . "$HOME/.fh-operator.env"; set +a; }

command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1 || { echo "CALIB: docker/OrbStack not running"; exit 1; }

# Held-out set. Each sample = NAME | TEXT | REDACT (listed/obvious) | ENTITIES (all confidential,
# pipe-sep — recall is measured over the UNLISTED ones) | KEEP (meaning that must survive).
if [ "$SET" = hard ]; then
  # HARD set — subtle entities that even 32B may miss: common-word codenames (read as nouns),
  # first-name-only persons, generic-looking vendors/tenants. This is where a heavier model's
  # autonomous recall would show value (32B saturates the base set at 7/7).
  NAMES=( "H1-codename-heavy" "H2-deal+vendor" "H3-model+breach" "H4-channel+person" "H5-flag+tenant" "H6-ledger+partner" )
  TEXTS=(
    "The Cascade pipeline feeds the Mercury dashboard; ask Priya Nair before touching the Harbor config. key sk-TEST-h1."
    "Quarterly figures for the Meridian deal ship to acme-bank via the Falcon connector; the Falcon retry budget is 5. key sk-TEST-h2."
    "The Onyx model scores applicants; its training set includes the Westbrook breach records under NDA with vendor Stellar. key sk-TEST-h3."
    "Route P0 incidents to the Lighthouse channel; Marcus owns the Tideway rollback runbook. key sk-TEST-h4."
    "The Beacon flag toggles legacy auth for the Crestline tenant; disable before the audit. key sk-TEST-h5."
    "Sync the Aurora ledger to the partner Greenfield nightly; Lena signs off on schema changes. key sk-TEST-h6."
  )
  REDACTS=( 'sk-[A-Za-z0-9-]+' 'sk-[A-Za-z0-9-]+' 'sk-[A-Za-z0-9-]+' 'sk-[A-Za-z0-9-]+' 'sk-[A-Za-z0-9-]+' 'sk-[A-Za-z0-9-]+' )
  ENTITIES=(
    "Cascade|Mercury|Priya Nair|Harbor"
    "Meridian|acme-bank|Falcon"
    "Onyx|Westbrook|Stellar"
    "Lighthouse|Marcus|Tideway"
    "Beacon|Crestline"
    "Aurora|Greenfield|Lena"
  )
  KEEPS=( "pipeline|dashboard|config" "quarterly|connector|retr" "model|training|applicant" "incident|rollback|runbook" "legacy|auth|audit" "ledger|partner|schema" )
else
  NAMES=(  "A-literal"  "B-client+person"  "C-codename+team"  "D-contextual" )
  TEXTS=(
    "The orders service uses key sk-TEST-abc123 at host svc.example.internal (192.0.2.7) for record rec-00012345."
    "Project Borealis migrates the Northwind Traders account; escalations route to Dana Whitfield. Auth key sk-TEST-x1 from 198.51.100.4."
    "The Atlas reconciliation engine syncs ledgers nightly; the Settlements Platform team owns the rollback path. Token sk-TEST-y2."
    "Customer records sit unencrypted in the legacy Vault-2 cluster pending migration; the bypass flag is on for vendor Globex. Key sk-TEST-z3."
  )
  REDACTS=(
    'sk-[A-Za-z0-9-]+|svc\.example\.internal|192\.0\.2\.[0-9]+|rec-[0-9]+'
    'sk-[A-Za-z0-9-]+|198\.51\.100\.[0-9]+'
    'sk-[A-Za-z0-9-]+'
    'sk-[A-Za-z0-9-]+'
  )
  ENTITIES=(
    ""                                  # A: nothing unlisted (sanity baseline)
    "Borealis|Northwind|Dana Whitfield" # B: unlisted client + person + codename
    "Atlas|Settlements Platform"        # C: unlisted internal system + team
    "Vault-2|Globex"                    # D: unlisted internal cluster + vendor
  )
  KEEPS=( "orders|retr|record" "migrat|escalat" "reconcil|ledger|rollback" "legacy|migrat|bypass" )
fi

echo "DLP calibration — set=$SET  host=$HOSTPORT  models: ${MODELS[*]}"
echo "================================================================"
for m in "${MODELS[@]}"; do
  tot_caught=0; tot_ent=0; blocks=0; overred=0
  echo ""; echo "### MODEL: $m"
  for i in "${!NAMES[@]}"; do
    raw=$(docker run --rm -v "$REPO":/work/forge-harness -w /work/forge-harness \
            -e "OLLAMA_HOST=$HOSTPORT" -e "OPENROUTER_API_KEY=${OPENROUTER_API_KEY:-}" \
            -e "OPENROUTER_REASONING=${OPENROUTER_REASONING:-off}" -e "SAMP=${TEXTS[$i]}" "$IMG" \
            -c "printf '%s' \"\$SAMP\" | REDACT_PATTERNS='${REDACTS[$i]}' OLLAMA_MODEL='$m' bash scripts/dlp-filter.sh - ; echo __EX:\$?" 2>&1)
    ex=$(printf '%s' "$raw" | grep -oE '__EX:[0-9]+' | tail -1 | cut -d: -f2)
    body=$(printf '%s\n' "$raw" | grep -v '__EX:')
    # listed-redaction: blocked = the model failed even the obvious tokens
    if [ "${ex:-1}" = "3" ]; then blocks=$((blocks+1)); status="BLOCK(listed leaked)"; recall="—"
    elif [ "${ex:-1}" != "0" ]; then status="ERR($ex)"; recall="—"
    else
      # unlisted-recall
      caught=0; total=0
      if [ -n "${ENTITIES[$i]}" ]; then
        IFS='|' read -ra ents <<< "${ENTITIES[$i]}"
        for e in "${ents[@]}"; do
          total=$((total+1))
          printf '%s' "$body" | grep -qiF "$e" || caught=$((caught+1))  # absent = caught
        done
      fi
      tot_caught=$((tot_caught+caught)); tot_ent=$((tot_ent+total))
      if [ "$total" -gt 0 ]; then recall="$caught/$total"; else recall="n/a(baseline)"; fi
      # over-redaction: KEEP markers gone?
      if ! printf '%s' "$body" | grep -qiE "${KEEPS[$i]}"; then overred=$((overred+1)); status="ok/OVER-REDACT"; else status="ok"; fi
    fi
    printf "  %-16s exit=%-2s unlisted-recall=%-12s keep=%s\n" "${NAMES[$i]}" "${ex:-?}" "$recall" "$status"
  done
  pct="n/a"; [ "$tot_ent" -gt 0 ] && pct="$(awk "BEGIN{printf \"%.0f%%\", 100*$tot_caught/$tot_ent}")"
  echo "  ---- $m: autonomous unlisted-entity recall = $tot_caught/$tot_ent ($pct) · listed-blocks=$blocks · over-redact=$overred"
done
echo ""
echo "Higher unlisted-recall = the model catches more confidential entities you did NOT pattern-match."
echo "That is the value a heavier filter buys; literal redaction is already saturated at 12B."
