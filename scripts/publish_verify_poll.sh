#!/usr/bin/env bash
# publish_verify_poll.sh — poll the npm registry for a just-published version to become visible,
# WITHOUT ever conflating "not yet visible" with "publish failed".
#
# 🟥 Why this exists (2026-09-18): `npm publish` in the previous CI step already returned 0 —
# the publish is DONE by the time this script runs. This script only OBSERVES registry
# read-replica propagation; a timeout here means "could not confirm visibility yet", never
# "publish failed". Collapsing those two into one exit code turned a successful publish
# (@chrono-meta/fh-gate@3.12.0, shasum 9284d86c…, provenance attached) into a red job, and a red
# job is exactly what has trained hand-publish before (v3.2.0/v3.4.0 both broke the OIDC path
# that way: "cannot publish over the previously published versions").
#
# Contract (safe under bash 3.2 + set -u — no arrays, no `((expr))` statement form):
#   Required:  PKG_VERSION           — version string to look for (e.g. from package.json)
#   Optional:  PKG_NAME              — default @chrono-meta/fh-gate
#              POLL_ATTEMPTS         — default 30
#              POLL_INTERVAL_S       — default 10   (30*10 = 300s / 5min budget)
#              PUBLISH_VERIFY_OUTPUT — GITHUB_OUTPUT-style file to append outcome/got/want to.
#                                      Falls back to $GITHUB_OUTPUT. Neither set -> stdout only
#                                      (this is what makes the script runnable standalone in a
#                                      test lane, mirrors scripts/ratchet_base_resolve.sh's
#                                      RATCHET_OUTPUT override convention).
#              NPM_VIEW_BIN          — override the binary used to query the registry version,
#                                      default `npm`. A test lane points this at a stub
#                                      executable so the real network/registry is never touched.
#
# Exit code contract — this is the actual fix, not the budget number:
#   0  — ALWAYS, for both "visible" and "not yet visible after budget". Verdict travels on the
#        `outcome=` output key (`visible` | `not_yet_visible`). The CALLER (next CI step) is what
#        turns `not_yet_visible` into a non-blocking ::warning::, never this script.
#   2  — usage/instrument error only (PKG_VERSION unset, POLL_ATTEMPTS/POLL_INTERVAL_S not a
#        positive integer). This is the one case that SHOULD be red: the checker itself is
#        broken, not that registry propagation is slow. (Same doctrine as
#        .github/workflows/caller-zero-ratchet.yml: "an instrument error is as red as exit 1" —
#        kept as a distinct exit 2 here so it is never mistaken for POLL_ATTEMPTS exhaustion.)
set -euo pipefail

PKG_NAME="${PKG_NAME:-@chrono-meta/fh-gate}"
POLL_ATTEMPTS="${POLL_ATTEMPTS:-30}"
POLL_INTERVAL_S="${POLL_INTERVAL_S:-10}"
NPM_VIEW_BIN="${NPM_VIEW_BIN:-npm}"
OUT="${PUBLISH_VERIFY_OUTPUT:-${GITHUB_OUTPUT:-}}"

# 🟥 cross-family (codex, 2026-09-18) S급 2: «출력 채널이 없으면 not_yet_visible 이 조용한 초록이 된다».
# 호출부의 `if: steps.verify.outputs.outcome == 'not_yet_visible'` 는 outcome 이 비어도 false 로
# 평가되므로, 채널이 없으면 경고 단계가 아예 안 뜬다 — 「미측정」이 「통과」로 렌더되는 정확한 형태다.
# 채널 부재 자체는 정당한 사용(레인·standalone)이므로 차단하지 않는다. 대신 ⓐ stderr 로 시끄럽게 알리고
# ⓑ **stdout 에 기계가독 한 줄을 항상** 낸다 — 채널이 하나뿐인 상태를 없애는 것이 처방이다.
if [ -z "$OUT" ]; then
  echo "⚠️  publish_verify_poll.sh: no output channel (PUBLISH_VERIFY_OUTPUT / GITHUB_OUTPUT both unset)." >&2
  echo "    The verdict travels on stdout ONLY. A caller reading just the exit code CANNOT tell" >&2
  echo "    'visible' from 'not yet visible' — both are exit 0 by contract." >&2
fi

if [ -z "${PKG_VERSION:-}" ]; then
  echo "🟥 publish_verify_poll.sh: PKG_VERSION is required and was empty — instrument error, not a propagation delay" >&2
  exit 2
fi
case "$POLL_ATTEMPTS" in ''|*[!0-9]*) echo "🟥 POLL_ATTEMPTS must be a positive integer, got '$POLL_ATTEMPTS'" >&2; exit 2 ;; esac
case "$POLL_INTERVAL_S" in ''|*[!0-9]*) echo "🟥 POLL_INTERVAL_S must be a positive integer, got '$POLL_INTERVAL_S'" >&2; exit 2 ;; esac
if [ "$POLL_ATTEMPTS" -lt 1 ]; then
  echo "🟥 POLL_ATTEMPTS must be >= 1, got '$POLL_ATTEMPTS'" >&2
  exit 2
fi

v="$PKG_VERSION"
pkg_at_v="${PKG_NAME}@${v}"
got=""
i=1
while [ "$i" -le "$POLL_ATTEMPTS" ]; do
  # 🟥 cross-family (codex, 2026-09-18) S급 1: 종전 `|| true` 는 **계기 오류를 삼켰다** —
  # `NPM_VIEW_BIN` 이 없으면 got 이 비고 그대로 `not_yet_visible`(비차단 경고)로 나갔다.
  # 「레지스트리에 아직 없다」(rc=1, E404 — 정당한 대기)와 「조회기가 죽었다」(127 등)는 다른 상태다.
  # rc 를 갈라서, 후자는 **exit 2(계기 오류)** 로 보낸다. 미측정은 0 이 아니다.
  if got=$("$NPM_VIEW_BIN" view "$pkg_at_v" version 2>/dev/null); then _vrc=0; else _vrc=$?; fi
  if [ "$_vrc" -ne 0 ] && [ "$_vrc" -ne 1 ]; then
    echo "🟥 '$NPM_VIEW_BIN view' exited $_vrc (neither 0=found nor 1=absent) — instrument error, not propagation lag" >&2
    exit 2
  fi
  if [ "$got" = "$v" ]; then
    break
  fi
  echo "  … attempt $i/$POLL_ATTEMPTS: registry has '${got:-<none>}', want '$v' — waiting ${POLL_INTERVAL_S}s (read-replica lag)"
  if [ "$i" -lt "$POLL_ATTEMPTS" ]; then
    sleep "$POLL_INTERVAL_S"
  fi
  i=$((i + 1))
done

if [ -n "$OUT" ]; then
  {
    echo "want=$v"
    echo "got=${got:-<none>}"
  } >> "$OUT"
fi

if [ "$got" = "$v" ]; then
  echo "✅ $pkg_at_v on registry"
  [ -n "$OUT" ] && echo "outcome=visible" >> "$OUT"
  echo "PUBLISH_VERIFY_OUTCOME=visible"
  exit 0
fi

budget_s=$((POLL_ATTEMPTS * POLL_INTERVAL_S))
echo "⏳ PUBLISHED, NOT YET VISIBLE — $pkg_at_v still shows '${got:-<none>}' after ${POLL_ATTEMPTS} attempts (~${budget_s}s)."
echo "   npm publish already returned success in the earlier step — this is registry read-replica lag, not a publish failure."
echo "   Re-check by hand: npm view $pkg_at_v version"
echo "   Do NOT hand-publish — see .github/workflows/publish.yml history (v3.2.0/v3.4.0 both broke this way)."
[ -n "$OUT" ] && echo "outcome=not_yet_visible" >> "$OUT"
echo "PUBLISH_VERIFY_OUTCOME=not_yet_visible"
exit 0
