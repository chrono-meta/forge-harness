#!/usr/bin/env bash
# test_persona_cast_merge_lanes.sh — known-pair calibration for scripts/persona_cast_merge.py (persona-cast Step 4).
# Fixture: three lens outputs in parallax shape. designer raises A (unique) and B (shared with qa); qa raises B and C (unique);
# a11y raises only B → decorative. Each lane checks one promise of Step 4; M1 is the positive control that the same fixture
# can produce «earned».
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
M="$HERE/persona_cast_merge.py"
[ -f "$M" ] || { echo "HARNESS-ERROR: $M missing"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
pass=0; fail=0
ok()  { pass=$((pass+1)); echo "  ✅ $1"; }
bad() { fail=$((fail+1)); echo "  ❌ $1"; }
echo '<html>screen</html>' > "$W/screen.html"
cat > "$W/designer.md" <<'EOF'
### Strengths
- clear headline
### Concerns
**Critical** — a person in this seat would stop the release
  - [button.pay "결제하기"] primary action is below the fold · move it up
**Important** — would file it
  - [`header .logo`] logo overlaps the menu · add spacing
  - the colours feel off somewhere
### Absence check
- no empty state shown
### Open questions
### Unique-to-this-seat
- [button.pay "결제하기"]
- [header .logo]
EOF
cat > "$W/qa.md" <<'EOF'
### Strengths
### Concerns
**Important**
  - [Header  .LOGO] logo covers the menu so the menu cannot be tested · fix overlap
**Suggestion**
  - [form#card input[name=cvc]] no reachable error state · add validation message
### Absence check
- no test account named
### Open questions
### Unique-to-this-seat
- [form#card input[name=cvc]]
- [header .logo]
EOF
cat > "$W/a11y.md" <<'EOF'
### Strengths
### Concerns
**Critical**
  - [header .logo] logo covers the menu for keyboard users · fix
### Absence check
- no focus order shown
### Open questions
### Unique-to-this-seat
- [header .logo]
EOF
run() { OUT=$(python3 "$M" --artifact "$W/screen.html" "$@" 2>&1); RC=$?; }
row() { printf '%s\n' "$OUT" | awk -v l="$1" '$1==l'; }
run --lens designer="$W/designer.md" --lens qa="$W/qa.md" --lens a11y="$W/a11y.md"
[ "$RC" = 0 ] && row designer | grep -q 'earned$' && row designer | awk '{exit !($2==2 && $3==1 && $4==1)}' \
  && ok "M1 control: designer total 2 · no-loc 1 · unique 1 → earned" || { bad "M1 (rc=$RC)"; printf '%s\n' "$OUT" | sed 's/^/       /'; }
row a11y | grep -q 'decorative on this artifact$' && row a11y | awk '{exit !($4==0)}' \
  && ok "M2 a lens whose only concern another lens also raised → unique 0 → decorative" || bad "M2 $(row a11y)"
row designer | awk '{exit !($3==1)}' && ! printf '%s\n' "$OUT" | grep -q 'colours feel off' \
  && ok "M3 a concern without [location] is counted in no-loc and never merged" || bad "M3"
printf '%s\n' "$OUT" | grep -qF -- '- [header .logo] seats=a11y,designer,qa' \
  && ok "M4 location keys normalize case, whitespace and backticks (\`header .logo\` = Header  .LOGO)" || bad "M4"
printf '%s\n' "$OUT" | awk '/^Critical/{c=1} /^Important/{c=0} c && /header \.logo/{f=1} END{exit !f}' \
  && ok "M5 merged severity = the highest any seat gave (a11y Critical beats designer/qa Important)" || bad "M5"
row designer | awk '{exit !($5=="1/2")}' && row qa | awk '{exit !($5=="1/2")}' \
  && ok "M6 self-tag-hit counts only self-tags that were really unique (designer 1/2, qa 1/2)" || bad "M6 $(row designer) | $(row qa)"
printf '### Strengths\n- fine\n' > "$W/broken.md"
run --lens designer="$W/designer.md" --lens broken="$W/broken.md"
[ "$RC" = 2 ] && printf '%s\n' "$OUT" | grep -q 'UNMEASURED: lens broken' && [ -z "$(row broken)" ] \
  && ok "M7 a lens output with no Concerns section is UNMEASURED (rc 2), never «decorative»" || bad "M7 (rc=$RC)"
run --lens designer="$W/designer.md" --lens gone="$W/nope.md"
[ "$RC" = 2 ] && printf '%s\n' "$OUT" | grep -q 'UNMEASURED: lens gone' && ok "M8 a missing lens file is UNMEASURED (rc 2)" || bad "M8 (rc=$RC)"
OUT=$(python3 "$M" --lens designer="$W/designer.md" 2>&1); RC=$?
[ "$RC" = 2 ] && ok "M9 no --artifact (no sha256 for the header) is UNMEASURED (rc 2)" || bad "M9 (rc=$RC)"
run --lens designer="$W/designer.md"
[ "$RC" = 0 ] && row designer | awk '{exit !($4==2)}' && ok "M10 a lens alone: every kept concern is unique (control for M2)" || bad "M10 $(row designer)"
# M11 (2026-11-06 blind sim, 3/3 runs saw it): a location with a nested «]» or an inner quoted label is kept whole
run --lens designer="$W/designer.md" --lens qa="$W/qa.md"
printf '%s\n' "$OUT" | grep -qF -- '- [form#card input[name=cvc]] seats=qa' && printf '%s\n' "$OUT" | grep -qF -- '- [button.pay "결제하기"] seats=designer' \
  && ! printf '%s\n' "$OUT" | grep -qF 'qa: ]' && ok "M11 nested brackets and an inner quoted label stay inside the location" || { bad "M11"; printf '%s\n' "$OUT" | grep '^- \[' | sed 's/^/       /'; }
# M12–M16 (codex R1, 2026-11-06): each would let a decorative lens read «earned». Base: a lens «x» raising only [shared].
mk() { printf '### Concerns\n%s\n### Absence check\n- none\n' "$2" > "$W/$1.md"; }
mk base '- [shared] the defect'
mk sevitem '- **Critical** — [shared] the defect'
run --lens base="$W/base.md" --lens x="$W/sevitem.md"
row base | grep -q 'decorative' && row x | awk '{exit !($2==1)}' && ok "M12 «- **Critical** — [loc] text» keeps its location (base stays decorative)" || bad "M12 base=$(row base) x=$(row x)"
printf '### Concerns\n- [shared] the defect\n## Appendix\n- [padding] example only\n### Absence check\n- none\n' > "$W/appx.md"
run --lens base="$W/base.md" --lens x="$W/appx.md"; row x | awk '{exit !($4==0 && $2==1)}' && ok "M13 a «## Appendix» ends Concerns — its [padding] does not earn a seat" || bad "M13 $(row x)"
printf '### Strengths\n### Concerns\n' > "$W/trunc.md"
run --lens base="$W/base.md" --lens x="$W/trunc.md"; [ "$RC" = 2 ] && printf '%s\n' "$OUT" | grep -q 'UNMEASURED: lens x' \
  && ok "M14 a reply cut off after «### Concerns» (no Absence check) is UNMEASURED, not «0 concerns → decorative»" || bad "M14 (rc=$RC)"
mk empty '- [``] made up
- [padding]'
run --lens base="$W/base.md" --lens x="$W/empty.md"; row x | awk '{exit !($2==0 && $3==2 && $4==0)}' && ok "M15 an empty location and a concern with no text are dropped to no-loc, never unique" || bad "M15 $(row x)"
mk quoted '- [button "Save ] now"] the defect'
run --lens x="$W/quoted.md"; printf '%s\n' "$OUT" | grep -qF -- '- [button "Save ] now"] seats=x' && ok "M16 a «]» inside a quoted label stays in the location" || bad "M16 $(printf '%s\n' "$OUT" | grep '^- \[')"
# M17–M18 (codex R2)
printf '### Concerns\n- [shared] the defect\n```\n- [padding] example only\n```\n### Absence check\n- none\n' > "$W/fenced.md"
run --lens base="$W/base.md" --lens x="$W/fenced.md"; row x | awk '{exit !($2==1 && $4==0)}' && ok "M17 a fenced example inside Concerns is not a finding" || bad "M17 $(row x)"
run --lens base="$W/base.md" --lens x="$W/trunc.md"; row base | grep -q 'UNMEASURED (a peer lens was unreadable)' && ! row base | grep -q 'earned' \
  && ok "M18 an unreadable peer leaves no seat verdict (base alone would read «earned»)" || bad "M18 $(row base)"
[ $((pass+fail)) -eq 18 ] || { echo "HARNESS-ERROR: counted $((pass+fail)) lanes, expected 18"; exit 2; }
echo "persona_cast_merge lanes: $pass passed · $fail failed"
[ "$fail" -eq 0 ]
