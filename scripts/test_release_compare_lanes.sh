#!/usr/bin/env bash
# test_release_compare_lanes.sh — known pairs for scripts/release_compare.sh, stage 1 (artifact fingerprint).
# A throwaway repo with two tags, a fake `npm` that answers `npm view` from knob files, and tarballs on local disk
# fetched through a fake `curl`. Nothing here touches the registry.
#   F1 both versions: tarball sha512 = dist.integrity and gitHead = the tag commit → VERIFIED ×2, rc 0
#   F2 the target's integrity is wrong (a tarball that is not the published one) → ARTIFACT-UNVERIFIED, rc 1
#   F3 gitHead is not the tag commit → ARTIFACT-UNVERIFIED (provenance), rc 1
#   F4 no local tag for the version → ARTIFACT-UNVERIFIED (cannot pair the bundle with a commit), rc 1
#   F5 npm cannot answer (on a reused --out) → rc 2, report says UNMEASURED, never the earlier VERIFIED
#   F6 the download fails → ARTIFACT-UNVERIFIED (nothing to fingerprint), rc 1
#   F7 --previous absent → the highest published version below the target is chosen and named
#   F8 the report names what stage 1 does NOT do (cases NOT BUILT) — a fingerprint is not a comparison
#   F9 a bad version argument → rc 2 before any network call
#   F10 previous not below target · F11 newline / leading zero · F12 E404 → UNVERIFIED not UNMEASURED · F13 hash tool dies
. "$(dirname "${BASH_SOURCE[0]}")/fixture_guard_lib.sh"   # scrub inherited GIT_* env first (#1088)
set -u
SC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/release_compare.sh"
[ -f "$SC" ] || { echo "HARNESS-ERROR: $SC missing"; exit 2; }
W=$(mktemp -d) || { echo "HARNESS-ERROR: mktemp"; exit 2; }
trap 'rm -rf "$W"' EXIT
pass=0; fail=0
ok()  { pass=$((pass+1)); echo "  ✅ $1"; }
bad() { fail=$((fail+1)); echo "  ❌ $1"; }
G() { git -c user.name=lane -c user.email=lane@localhost -c commit.gpgsign=false "$@"; }

R="$W/repo"; K="$W/knobs"; mkdir -p "$K" "$W/bin" "$W/tgz"
{ G init -q "$R" && echo a > "$R/a" && G -C "$R" add a && G -C "$R" commit -qm one && G -C "$R" tag v1.1.0 \
  && echo b >> "$R/a" && G -C "$R" commit -qam two && G -C "$R" tag v1.2.0; } > /dev/null 2>&1 || { echo "HARNESS-ERROR: fixture repo"; exit 2; }
C110=$(G -C "$R" rev-parse v1.1.0); C120=$(G -C "$R" rev-parse v1.2.0)
printf 'pkg 1.0.0\n' > "$W/tgz/p-1.0.0.tgz"; printf 'pkg 1.1.0\n' > "$W/tgz/p-1.1.0.tgz"; printf 'pkg 1.2.0\n' > "$W/tgz/p-1.2.0.tgz"
integ() { printf 'sha512-%s' "$(openssl dgst -sha512 -binary "$1" | base64 | tr -d '\n')"; }
reset_knobs() {
  rm -f "$K"/*
  for v in 1.0.0 1.1.0 1.2.0; do
    integ "$W/tgz/p-$v.tgz" > "$K/integ_$v"; echo "file://$W/tgz/p-$v.tgz" > "$K/url_$v"
  done
  echo "$C110" > "$K/head_1.0.0"; echo "$C110" > "$K/head_1.1.0"; echo "$C120" > "$K/head_1.2.0"
  printf '["1.0.0","1.1.0","1.2.0"]\n' > "$K/versions"
}
cat > "$W/bin/npm" <<NPM
#!/usr/bin/env bash
K="$K"
echo "\$*" >> "\$K/npm_calls"
[ -f "\$K/npm_fail" ] && exit 1
[ "\$1" = view ] || exit 3
spec="\$2"; v="\${spec##*@}"
case "\$3" in
  versions) cat "\$K/versions" ;;
  dist.integrity) [ -f "\$K/integ_\$v" ] || { echo "npm error code E404" >&2; exit 1; }; cat "\$K/integ_\$v" ;;
  dist.tarball) cat "\$K/url_\$v" ;;
  gitHead) cat "\$K/head_\$v" ;;
  *) exit 3 ;;
esac
NPM
cat > "$W/bin/curl" <<CURL
#!/usr/bin/env bash
out=""; url=""; prev=""
for a in "\$@"; do [ "\$prev" = "-o" ] && out="\$a"; case "\$a" in file://*) url="\${a#file://}" ;; esac; prev="\$a"; done
[ -f "$K/curl_fail" ] && exit 22
cp "\$url" "\$out"
CURL
chmod +x "$W/bin/npm" "$W/bin/curl"
run_keep() { OUT=$(cd "$R" && PATH="$W/bin:$PATH" RC_PACKAGE=@x/p bash "$SC" "$@" --out "$W/out" 2>&1); RC=$?; REP=$(cat "$W/out/release_compare_$1.md" 2>/dev/null); }
run() { rm -rf "$W/out"; OUT=$(cd "$R" && PATH="$W/bin:$PATH" RC_PACKAGE=@x/p bash "$SC" "$@" --out "$W/out" 2>&1); RC=$?; REP=$(cat "$W/out/release_compare_$1.md" 2>/dev/null); }

echo "release_compare lanes (stage 1: artifact fingerprint)"
reset_knobs; run 1.2.0 --previous 1.1.0
{ [ "$RC" -eq 0 ] && [ "$(printf '%s\n' "$REP" | grep -c '| VERIFIED |')" -eq 2 ]; } \
  && ok "F1 integrity and gitHead match for both → VERIFIED ×2, rc 0" || bad "F1 rc=$RC rep=[$REP] out=[$OUT]"

reset_knobs; integ "$W/tgz/p-1.1.0.tgz" > "$K/integ_1.2.0"; run 1.2.0 --previous 1.1.0
{ [ "$RC" -eq 1 ] && printf '%s\n' "$REP" | grep -q '1.2.0 .*ARTIFACT-UNVERIFIED.*integrity'; } \
  && ok "F2 tarball sha512 ≠ dist.integrity → ARTIFACT-UNVERIFIED (integrity), rc 1" || bad "F2 rc=$RC rep=[$REP]"

reset_knobs; echo "$C110" > "$K/head_1.2.0"; run 1.2.0 --previous 1.1.0
{ [ "$RC" -eq 1 ] && printf '%s\n' "$REP" | grep -q '1.2.0 .*ARTIFACT-UNVERIFIED.*gitHead'; } \
  && ok "F3 gitHead ≠ tag commit → ARTIFACT-UNVERIFIED (provenance), rc 1" || bad "F3 rc=$RC rep=[$REP]"

reset_knobs; run 1.2.0 --previous 1.0.0
{ [ "$RC" -eq 1 ] && printf '%s\n' "$REP" | grep -q '1.0.0 .*ARTIFACT-UNVERIFIED.*no tag'; } \
  && ok "F4 no local tag for the version → ARTIFACT-UNVERIFIED, rc 1" || bad "F4 rc=$RC rep=[$REP] out=[$OUT]"

reset_knobs; run 1.2.0 --previous 1.1.0; : > "$K/npm_fail"; run_keep 1.2.0 --previous 1.1.0
{ [ "$RC" -eq 2 ] && ! printf '%s\n' "$REP$OUT" | grep -q '| VERIFIED |' && printf '%s\n' "$REP" | grep -q UNMEASURED; } \
  && ok "F5 npm unreachable on a reused --out → rc 2, the earlier VERIFIED report is replaced by UNMEASURED" || bad "F5 rc=$RC rep=[$REP]"

reset_knobs; : > "$K/curl_fail"; run 1.2.0 --previous 1.1.0
{ [ "$RC" -eq 1 ] && printf '%s\n' "$REP" | grep -q 'ARTIFACT-UNVERIFIED.*download'; } \
  && ok "F6 download fails → ARTIFACT-UNVERIFIED (download), rc 1" || bad "F6 rc=$RC rep=[$REP]"

reset_knobs; run 1.2.0
{ [ "$RC" -eq 0 ] && printf '%s\n' "$REP" | grep -qF 'previous: 1.1.0 (highest published below 1.2.0)'; } \
  && ok "F7 no --previous → 1.1.0 chosen and named" || bad "F7 rc=$RC rep=[$REP] out=[$OUT]"

printf '%s\n' "$REP" | grep -q 'NOT BUILT' && ok "F8 the report says the case runs are NOT BUILT (a fingerprint is not a comparison)" || bad "F8 rep=[$REP]"

reset_knobs; run '1.2;rm' --previous 1.1.0
{ [ "$RC" -eq 2 ] && [ ! -s "$K/npm_calls" ]; } && ok "F9 bad version argument → rc 2 before any npm call" || bad "F9 rc=$RC"

# F10 --previous not below the target → rc 2 (equal and newer)
reset_knobs; run 1.2.0 --previous 1.2.0; r1=$RC; run 1.1.0 --previous 1.2.0
{ [ "$r1" -eq 2 ] && [ "$RC" -eq 2 ]; } && ok "F10 --previous equal to or newer than the target → rc 2" || bad "F10 rc=$r1/$RC"
# F11 version strings: embedded newline and a leading zero are refused
reset_knobs; run $'1.2.0\nx' --previous 1.1.0; r1=$RC; run 1.2.0 --previous 01.1.0
{ [ "$r1" -eq 2 ] && [ "$RC" -eq 2 ] && [ ! -s "$K/npm_calls" ]; } && ok "F11 «1.2.0⏎x» and «01.1.0» → rc 2, no npm call" || bad "F11 rc=$r1/$RC"
# F12 a version the registry has never published (E404) is an artifact failure, not UNMEASURED
reset_knobs; rm -f "$K/integ_1.1.0"; run 1.2.0 --previous 1.1.0
{ [ "$RC" -eq 1 ] && printf '%s\n' "$REP" | grep -q '1.1.0 .*ARTIFACT-UNVERIFIED.*not published'; } \
  && ok "F12 E404 for the previous version → ARTIFACT-UNVERIFIED, rc 1 (not 2)" || bad "F12 rc=$RC rep=[$REP]"
# F13 the hash tool dies → never VERIFIED, even with registry metadata that matches its (empty) output
reset_knobs; printf '#!/usr/bin/env bash\nexit 1\n' > "$W/bin/openssl"; chmod +x "$W/bin/openssl"
printf 'sha512-%s' "$(printf '' | base64)" > "$K/integ_1.2.0"; run 1.2.0 --previous 1.1.0; rm -f "$W/bin/openssl"
{ [ "$RC" -eq 1 ] && ! printf '%s\n' "$REP" | grep -q '| VERIFIED |'; } && ok "F13 openssl fails → no VERIFIED, rc 1" || bad "F13 rc=$RC rep=[$REP]"

echo "release_compare lanes: $pass passed · $fail failed"
[ "$fail" -eq 0 ]
