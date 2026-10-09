#!/usr/bin/env bash
# test_mutation_probe_lanes.sh — known-pair lanes for scripts/mutation_probe.py (2026-10-07).
#
# WHAT IS PINNED
#   F  the boundary case the tool exists for: `-ge 19` tested only with 20 and 5 → the `-ge→-gt`
#      mutant SURVIVES (known-positive survivor); add the 19 case → it is KILLED (known-negative).
#   C  calibration of the mutant GENERATOR itself — the prototype mutated a redirect
#      (`2>/dev/null` → `2>=/dev/null`) and wrote a stray file named `=`. C1 = lines that must yield
#      ZERO mutants (redirects · here-string · quoted operators · comments); C2 = lines that must
#      yield exactly the listed mutants.
#   P  python operator set.
#   E  every «cannot judge» path exits 2, never 0: baseline red · no mutants · missing lane.
#   R  the subject is byte-identical after a run, including a run whose lane times out.
#   RV revert probe: force the tool's kill decision to «always killed» → the F survivor vanishes,
#      so lane F1 would turn red. If it ever stops vanishing, F1 is not measuring the tool.
#
#   S7 the v7 safety contract (symlink/inode replacement · crossed locks · positive control · final run on
#      the original · setsid escapees · --json only when measured · kernel shebang · mode bits · future
#      mtime · inode-keyed leftovers) — each lane red on v6.
#   G7 the v6 generator defect classes, pinned — fail-closed: an uncertain region yields no mutant.
#   K0 the /proc process counter used by N6/S7-5, on a known pair, before either trusts it.
#
# Exit 0 = all lanes behave · 1 = regression (or an UNMEASURED lane — never folded into PASS).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROBE="$SCRIPT_DIR/mutation_probe.py"
FAILED=0; PASS=0; UNMEASURED=0
chk() { if [ "$1" -eq 0 ]; then PASS=$((PASS+1)); echo "  ✅ $2"; else FAILED=1; echo "  ❌ $2"; fi; }
[ -f "$PROBE" ] || { echo "FAIL  subject $PROBE missing"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "FAIL  python3 absent — the probe cannot run, so nothing here was verified"; exit 1; }

T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
cd "$T" || exit 1

# ── fixtures ──────────────────────────────────────────────────────────────────
cat > age.sh <<'EOF'
#!/usr/bin/env bash
is_adult() { [ "$1" -ge 19 ]; }
EOF
cat > lane_weak.sh <<'EOF'
. ./age.sh
is_adult 20 || exit 1
is_adult 5 && exit 1
exit 0
EOF
cat > lane_strong.sh <<'EOF'
. ./age.sh
is_adult 20 || exit 1
is_adult 19 || exit 1
is_adult 5 && exit 1
exit 0
EOF

echo "── F: the boundary survivor (known-positive) and its kill (known-negative)"
out_w=$(python3 "$PROBE" age.sh lane_weak.sh --timeout 30 2>&1); rc_w=$?
[ "$rc_w" -eq 0 ] ; chk $? "weak lane: measured → rc 0 (survivors are reported, not failed)"
grep -q 'SURVIVED L2 \[-ge→-gt\]' <<<"$out_w" ; chk $? "F1 weak lane: -ge→-gt SURVIVES (only 20 and 5 tested — the field report's <→<= case)"
out_s=$(python3 "$PROBE" age.sh lane_strong.sh --timeout 30 2>&1)
grep -qE 'mutants=1 killed=1 survived=0( |$)' <<<"$out_s" ; chk $? "F2 strong lane (adds 19): the one mutant is KILLED (not merely «no survivor»)"
grep -qE 'mutants=1 killed=0 survived=1( |$)' <<<"$out_w" ; chk $? "F3 and the count is exact: one operator on the line → one mutant, survived"

echo "── C: generator calibration"
cat > neg.sh <<'EOF'
#!/usr/bin/env bash
echo hi 2>/dev/null
cmd > out.txt
cat >> log.txt
grep x <<< "$y"
echo "a == b and c -eq d"
echo 'exit 1 inside quotes'
# if [ "$a" -eq 1 ]; then exit 1; fi
x=$(( a >> 2 ))
EOF
out=$(python3 "$PROBE" neg.sh --list 2>&1); rc=$?
grep -qE 'mutants=0( |$)' <<<"$out" ; chk $? "C1 known-negative: redirects · here-string · quoted · commented · shift → ZERO mutants"
grep -qE 'mutants=0( |$)' <<<"$out" && [ "$rc" -eq 2 ] ; chk $? "C1 and --list over zero mutants exits 2 (nothing measured), not 0"
cat > pos.sh <<'EOF'
#!/usr/bin/env bash
[ "$a" -eq 1 ] && echo one
(( n >= 3 )) && echo many
FAILED=1
exit 1
EOF
out=$(python3 "$PROBE" pos.sh --list 2>&1)
grep -qE 'mutants=4( |$)' <<<"$out" ; chk $? "C2 known-positive: exactly 4 mutants"
grep -q '\[-eq→-ne\]' <<<"$out" && grep -q '\[>=→>\]' <<<"$out" && grep -q '\[FAILED=1→FAILED=0\]' <<<"$out" && grep -q '\[exit 1→exit 0\]' <<<"$out"
chk $? "C2 and they are -eq→-ne · >=→> (inside (( ))) · FAILED=1→0 · exit 1→0"

echo "── P: python operator set"
cat > v.py <<'EOF'
import sys
def ok(x):
    return x >= 19
if not ok(int(sys.argv[1])):
    sys.exit(1)
flag = True
EOF
out=$(python3 "$PROBE" v.py --list 2>&1)
grep -qE 'lang=python mutants=3( |$)' <<<"$out" ; chk $? "P1 python: >= · sys.exit(1) · = True → 3 mutants"

echo "── X: the two calibration gaps the first real run found (2026-10-07)"
cat > emb.sh <<'SH'
#!/usr/bin/env bash
[ "$CLS" = internal ] && echo skip
x=foo
echo a = b
r=$(python3 -c '
import sys
ok = len(sys.argv) >= 2
if a < b: pass
')
python3 - <<'PY'
flag = True
PY
echo done > out.txt
SH
out=$(python3 "$PROBE" emb.sh --list 2>&1)
grep -qF '[=→!=] [ "$CLS" != internal ] && echo skip' <<<"$out" ; chk $? "X1 bash single-= string test inside [ ] is mutated"
grep -qE 'mutants=4( |$)' <<<"$out" && ! grep -qF 'echo a != b' <<<"$out" ; chk $? "X1b a spaced \` = \` OUTSIDE [ ] (echo a = b) is not mutated — the in_test guard is load-bearing"
grep -qF '[>=→>] ok = len(sys.argv) > 2' <<<"$out" ; chk $? "X2 python inside an open python3 -c ' block gets the python set"
grep -qF '[<→<=] if a <= b: pass' <<<"$out" ; chk $? "X2b a bare < inside the -c block is mutated — only the python set does that (bash leaves < alone outside (( )))"
grep -qF '[True→False] flag = False' <<<"$out" ; chk $? "X3 python inside a python3 - <<'PY' heredoc gets the python set"
grep -qE 'mutants=4( |$)' <<<"$out" && ! grep -qF 'out.txt' <<<"$out" ; chk $? "X4 bash after both blocks close is bash again (its redirect untouched)"
grep -qE 'mutants=4( |$)' <<<"$out" ; chk $? "X5 exact count: = · >= · < · True → 4"
printf '#!/usr/bin/env bash\nn=$#  # if [ a -eq b ] < c\n[ "$n" -eq 0 ] && echo none   # trailing: -ge > ==\n' > cmt.sh
out=$(python3 "$PROBE" cmt.sh --list 2>&1)
grep -qE 'mutants=1( |$)' <<<"$out" && grep -qF '[-eq→-ne]' <<<"$out" ; chk $? "X6 operators inside a trailing comment are not mutated; \$# is not a comment start"


echo "── E: every «cannot judge» exits 2"
printf 'exit 1\n' > lane_red.sh
out=$(python3 "$PROBE" age.sh lane_red.sh --timeout 30 2>&1) ; [ $? -eq 2 ] && grep -q "baseline lane is not green" <<<"$out" ; chk $? "E1 baseline lane red → 2 (else every mutant reads as killed)"
printf 'echo nothing to mutate\n' > flat.sh
out=$(python3 "$PROBE" flat.sh lane_weak.sh --timeout 30 2>&1) ; [ $? -eq 2 ] && grep -q "no mutants generated" <<<"$out" ; chk $? "E2 no mutants → 2, not «0 survivors»"
out=$(python3 "$PROBE" age.sh no_such_lane.sh 2>&1) ; [ $? -eq 2 ] && grep -q "lane suite not found" <<<"$out" ; chk $? "E3 missing lane → 2"
out=$(python3 "$PROBE" age.sh lane_weak.sh --json /nonexistent_dir/x.json 2>&1) ; [ $? -eq 2 ] && grep -q -- "--json not writable" <<<"$out" ; chk $? "E4 unwritable --json → 2, never a traceback rc 1"

echo "── R: the subject is restored byte-for-byte"
h0=$(python3 -c 'import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' age.sh)
out_r1=$(python3 "$PROBE" age.sh lane_weak.sh --timeout 30 2>&1)
h1=$(python3 -c 'import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' age.sh)
grep -qE 'mutants=1 killed=0 survived=1( |$)' <<<"$out_r1" && [ "$h0" = "$h1" ] ; chk $? "R1 after a normal run that measured"
cat > lane_hang.sh <<'EOF'
. ./age.sh
if is_adult 19; then exit 0; fi
sleep 30
EOF
out=$(python3 "$PROBE" age.sh lane_hang.sh --timeout 2 2>&1)
h2=$(python3 -c 'import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' age.sh)
grep -q 'TIMEOUT  L2' <<<"$out" && [ "$h0" = "$h2" ] ; chk $? "R2 after a run whose lane hangs on the mutant"
grep -q 'TIMEOUT  L2' <<<"$out" ; chk $? "R3 a hang is reported as TIMEOUT, its own class — not folded into KILLED"

echo "── S: in-place safety — each lane is a blocking repro from the 2026-10-07 blind review"
bkpath() { python3 -c 'import hashlib,os,sys;print("/tmp/mutation_probe-%d/path-%s.backup"%(os.getuid(),hashlib.sha256(os.path.realpath(sys.argv[1]).encode()).hexdigest()[:16]))' "$1"; }
sha_of() { python3 -c 'import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$1"; }
procs_matching() {  # count live processes whose WHOLE cmdline is $1 — /proc, not pgrep (pgrep absent → vacuous);
  local n=0 c                # exact match, so the counter never counts itself (a substring grep did)
  for c in /proc/[0-9]*/cmdline; do [ -e "$c" ] || continue; [ "$(tr '\0' ' ' < "$c" 2>/dev/null)" = "$1 " ] && n=$((n+1)); done
  echo "$n"
}
if [ -d /proc/self ]; then HAVE_PROC=1; else HAVE_PROC=0; fi

# B4 — the baseline lane writes its own subject: refuse, and leave the ORIGINAL bytes
cp age.sh b4.sh; h0=$(sha_of b4.sh)
printf '. ./b4.sh\nis_adult 20 || exit 1\necho "# stamp" >> b4.sh\nexit 0\n' > lane_b4.sh
out=$(python3 "$PROBE" b4.sh lane_b4.sh --timeout 30 2>&1); rc=$?
[ "$rc" -eq 2 ] && grep -q 'baseline lane WROTE the subject' <<<"$out" ; chk $? "B4 a lane that writes its subject → 2 with that reason (v1: rc 0, «restored» to the stamped bytes)"
grep -q 'baseline lane WROTE the subject' <<<"$out" && [ "$(sha_of b4.sh)" = "$h0" ] ; chk $? "B4b and the subject is back to the ORIGINAL bytes, not the post-baseline ones"

# B3 — a second probe on the same subject while the first runs
cp age.sh b3.sh; h0=$(sha_of b3.sh)
printf '. ./b3.sh\ntouch b3.started\nsleep 2\nis_adult 20 || exit 1\nis_adult 5 && exit 1\nexit 0\n' > lane_b3.sh
rm -f b3.started
python3 "$PROBE" b3.sh lane_b3.sh --timeout 30 > b3_a.out 2>&1 & pa=$!
for _ in $(seq 1 100); do [ -e b3.started ] && break; sleep 0.1; done   # the first probe is past its locks
out=$(python3 "$PROBE" b3.sh lane_b3.sh --timeout 30 2>&1); rc_b=$?
wait $pa; rc_a=$?
[ "$rc_b" -eq 2 ] && grep -q 'another mutation_probe holds' <<<"$out" ; chk $? "B3 the second probe refuses (2) instead of backing up the first one's mutant (v1: both rc 0)"
[ "$rc_a" -eq 0 ] && [ "$(sha_of b3.sh)" = "$h0" ] ; chk $? "B3b the first probe completes and the subject ends byte-identical"

# B2 — SIGHUP mid-run restores; a leftover backup blocks the next run
cp age.sh b2.sh; h0=$(sha_of b2.sh)
printf '. ./b2.sh\nif grep -q -- "-gt" b2.sh; then touch b2.live; fi\nsleep 5\nexit 0\n' > lane_b2.sh
rm -f b2.live
python3 "$PROBE" b2.sh lane_b2.sh --timeout 30 >/dev/null 2>&1 & pb=$!
for _ in $(seq 1 150); do [ -e b2.live ] && break; sleep 0.1; done   # the lane itself says the mutant is live
kill -HUP "$pb" 2>/dev/null; wait "$pb"; rc=$?
[ -e b2.live ] && [ "$rc" -eq 129 ] && [ "$(sha_of b2.sh)" = "$h0" ] ; chk $? "B2 SIGHUP while a mutant is live → restored, exit 129 (v1: left the mutant in place)"
bk=$(bkpath b2.sh)
[ -e b2.live ] && [ "$rc" -eq 129 ] && [ ! -e "$bk" ] ; chk $? "B2b a clean signal exit removes its fixed-path backup"
cp b2.sh "$bk"
out=$(python3 "$PROBE" b2.sh lane_weak.sh --timeout 30 2>&1); rc=$?
rm -f "$bk"
[ "$rc" -eq 2 ] && grep -q 'previous run left a backup' <<<"$out" ; chk $? "B2c a leftover backup (SIGKILL case) blocks the next run and names the path"

# B1 — python subject, same-size mutants, the stale-bytecode trap
cat > gate.py <<'EOF'
def a(x):
    return x == 1
def b(x):
    return x == 2
def c(x):
    return x == 3
EOF
printf 'import sys\nsys.path.insert(0, ".")\nimport gate\nassert gate.a(1) and not gate.a(5)\nassert gate.c(3) and not gate.c(5)\n' > lane_b1.py
touch -d 2020-01-01 gate.py 2>/dev/null || touch -t 202001010000 gate.py
python3 -c 'import sys;sys.path.insert(0,".");import gate' 2>/dev/null   # leave a real __pycache__ behind
out=$(python3 "$PROBE" gate.py lane_b1.py --timeout 30 2>&1)
grep -qE 'mutants=3 killed=2 survived=1( |$)' <<<"$out" && grep -q 'SURVIVED L4' <<<"$out" ; chk $? "B1 python: the untested b() survives and only it (v1: killed=3 — stale bytecode)"

# N1 — nothing measured is not «measured»
printf '#!/usr/bin/env bash\nis_adult() { [ "$1" -ge 19 ]; }\n' > n1.sh
printf '. ./n1.sh\nis_adult 20 && is_adult 19 && exit 0\nsleep 30\n' > lane_n1.sh
out=$(python3 "$PROBE" n1.sh lane_n1.sh --timeout 2 2>&1); rc=$?
[ "$rc" -eq 2 ] && grep -q 'nothing was measured' <<<"$out" ; chk $? "N1 only TIMEOUT results → 2, not 0"
printf 'if (a == b) { process.exit(1) }\n' > n1.js
out=$(python3 "$PROBE" n1.js lane_weak.sh 2>&1) ; [ $? -eq 2 ] && grep -q 'unsupported language' <<<"$out" ; chk $? "N1b an unsupported language (.js) → 2, never read as bash"

# N4 · N5 — bytes in, bytes out
printf 'import sys\r\nif len(sys.argv) >= 2:\r\n    pass\r\n' > crlf.py
printf 'import sys,subprocess\nd=open("crlf.py","rb").read()\nsys.exit(0 if d.count(b"\\r\\n")==3 else 1)\n' > lane_crlf.py
out=$(python3 "$PROBE" crlf.py lane_crlf.py --timeout 30 2>&1)
grep -qE 'mutants=1 killed=0 survived=1( |$)' <<<"$out" ; chk $? "N4 a CRLF subject keeps its line endings in the mutant (v1: the endings, not the operator, were «killed»)"
printf '#!/usr/bin/env bash\n# caf\xe9\n[ "$a" -eq 1 ]\n' > lat.sh
out=$(python3 "$PROBE" lat.sh lane_weak.sh 2>&1); rc=$?
[ "$rc" -eq 2 ] && grep -q 'not UTF-8' <<<"$out" ; chk $? "N5 non-UTF-8 subject → 2 with the reason (v1: traceback rc 1)"

# N6 — no orphan keeps running a mutant after a timeout
printf '. ./n1.sh\nis_adult 19 && exit 0\n( touch n6.started; exec sleep 4747 ) &\nwait\n' > lane_n6.sh
rm -f n6.started
out=$(python3 "$PROBE" n1.sh lane_n6.sh --timeout 2 2>&1)
sleep 0.5
if [ "$HAVE_PROC" -eq 1 ]; then
  [ -e n6.started ] && grep -q 'TIMEOUT' <<<"$out" && [ "$(procs_matching 'sleep 4747')" -eq 0 ] ; chk $? "N6 the timed-out lane's grandchildren are killed with its process group (counted via /proc — v6 used pgrep, vacuous when absent)"
else
  echo "  ⚠️  N6 UNMEASURED — no /proc"; UNMEASURED=$((UNMEASURED+1))
fi

# N2 · N3 · N7 — generator noise
cat > noise.sh <<'EOF'
#!/usr/bin/env bash
(( $(sort in.txt > sorted.txt; wc -l < sorted.txt) > 0 )) && echo some
echo -ne "progress\r"
ls -lt "$d"
cat <<DOC
exit 1 when x == 2
DOC
test "$x" -eq 0 && echo zero
EOF
out=$(python3 "$PROBE" noise.sh --list 2>&1)
grep -qE 'mutants=2( |$)' <<<"$out" && grep -qF '[>→>=] (( $(sort in.txt > sorted.txt; wc -l < sorted.txt) >= 0 ))' <<<"$out" && grep -qF '[-eq→-ne] test "$x" -ne 0' <<<"$out"
chk $? "N2·N3·N7 only the real (( )) comparison and the test -eq: not the redirects inside \$( ), echo -ne, ls -lt, or the heredoc body"
cat > noise.py <<'EOF'
def f(x):
    """exit code x == 0 means ok"""
    y = x == True
    s = """
    a <= b
    """
    return x >= 1  # a <= b
EOF
out=$(python3 "$PROBE" noise.py --list 2>&1)
grep -qE 'mutants=2( |$)' <<<"$out" && grep -qF '[==→!=] y = x != True' <<<"$out" && grep -qF '[>=→>] return x > 1' <<<"$out"
chk $? "N7 python: docstring · triple-quoted body · trailing comment untouched, and x == True yields ONE mutant (v1: two)"

# R1 must prove a mutant was actually written
printf '. ./age.sh\nsha256sum age.sh >> seen.log 2>/dev/null || shasum -a 256 age.sh >> seen.log\nis_adult 20 || exit 1\nis_adult 5 && exit 1\nexit 0\n' > lane_seen.sh
rm -f seen.log
python3 "$PROBE" age.sh lane_seen.sh --timeout 30 >/dev/null 2>&1
[ "$(cut -d' ' -f1 seen.log | sort -u | wc -l | tr -d ' ')" -eq 2 ] ; chk $? "R0 the lane saw two different subjects (baseline + mutant) — R1's «unchanged» is not vacuous"

echo "── V: second-round blind review (2026-10-07) — each lane red on v2"

# ① a `python3 -I` lane ignores the env guards — the mtime must carry the protection, and the
#    restored subject must behave as the ORIGINAL after the probe exits
mkdir -p v1b && cat > v1b/gate.py <<'EOF'
def a(x):
    return x == 1
def b(x):
    return x == 2
def c(x):
    return x == 3
EOF
printf 'import sys\nsys.path.insert(0, "v1b")\nimport gate\nassert gate.a(1) and not gate.a(5)\nassert gate.c(3) and not gate.c(5)\n' > v1b/lane.py
printf 'exec python3 -I -c "exec(open(\\"v1b/lane.py\\").read())"\n' > v1b/lane.sh
out=$(python3 "$PROBE" v1b/gate.py v1b/lane.sh --timeout 30 2>&1)
grep -qE 'mutants=3 killed=2 survived=1( |$)' <<<"$out" && grep -q 'SURVIVED L4' <<<"$out" ; chk $? "V1 a python3 -I lane (env guards ignored) still sees each mutant: b() survives alone"
r=$(python3 -I -c 'import sys;sys.path.insert(0,"v1b");import gate;print(gate.a(1),gate.c(3),gate.b(2))' 2>&1)
grep -qE 'mutants=3 killed=2 survived=1( |$)' <<<"$out" && [ "$r" = "True True True" ] ; chk $? "V1b after the probe exits, a plain import runs the ORIGINAL code (v2: the last mutant's bytecode, a(1)/c(3) False)"

# ② two probes with DIFFERENT TMPDIRs on the same subject
mkdir -p v2t/t1 v2t/t2 && cp age.sh v2t/age.sh; h0=$(sha_of v2t/age.sh)
printf '. ./v2t/age.sh\nsleep 2\nis_adult 20 || exit 1\nis_adult 5 && exit 1\nexit 0\n' > v2t/lane.sh
TMPDIR="$PWD/v2t/t1" python3 "$PROBE" v2t/age.sh v2t/lane.sh --timeout 30 > v2t/a.out 2>&1 & pa=$!
sleep 0.5
out=$(TMPDIR="$PWD/v2t/t2" python3 "$PROBE" v2t/age.sh v2t/lane.sh --timeout 30 2>&1); rc_b=$?
wait $pa
[ "$rc_b" -eq 2 ] && grep -q 'another mutation_probe holds' <<<"$out" ; chk $? "V2 a second probe under ANOTHER TMPDIR still sees the lock (it is on the subject's inode)"
grep -qE 'mutants=1 ' v2t/a.out && [ "$(sha_of v2t/age.sh)" = "$h0" ] ; chk $? "V2b and the subject ends byte-identical (v2: left mutated)"

# ③ here-string · shift · python triple-quote lookalikes must not swallow the rest of the file
cat > v3.sh <<'EOF'
#!/usr/bin/env bash
read -r a b <<< 'x y'
[ "$a" -eq 1 ] && echo one
mask=$(( 1 << 3 ))
[ "$b" -gt 50 ] && echo big
cat <<\EOT
exit 1 when x == 2
EOT
[ "$c" = z ] && echo zed
EOF
out=$(python3 "$PROBE" v3.sh --list 2>&1)
grep -qE 'mutants=3( |$)' <<<"$out" && grep -qF '[-eq→-ne]' <<<"$out" && grep -qF '[-gt→-ge]' <<<"$out" && grep -qF '[=→!=]' <<<"$out"
chk $? "V3 the lines after a here-string, a (( << )) shift and a <<\\EOT body are still mutated — and that body is not (v2: mutants=0)"
cat > v3.py <<'EOF'
SEP = "'''"
y = """one-liner"""
def f(v):
    return v >= 1
EOF
out=$(python3 "$PROBE" v3.py --list 2>&1)
grep -qE 'mutants=1( |$)' <<<"$out" && grep -qF '[>=→>] return v > 1' <<<"$out" ; chk $? "V3b python: a triple quote inside a string, a comment, or a closed one-liner does not open a string (v2: mutants=0)"

printf "x = 1  # docs use ''' quotes\ndef f(v):\n    return v >= 1\n" > v3c.py
out=$(python3 "$PROBE" v3c.py --list 2>&1)
grep -qE 'mutants=1( |$)' <<<"$out" ; chk $? "V3c a triple quote inside a trailing comment does not open a string (v2: mutants=0)"

# non-blocking: test chain · baseline deletes the subject
printf '#!/usr/bin/env bash\ntest -d "$d" && ls -lt "$d"\n[ "$n" -eq 0 ] && echo z\n' > v4.sh
out=$(python3 "$PROBE" v4.sh --list 2>&1)
grep -qE 'mutants=1( |$)' <<<"$out" && ! grep -qF 'ls -le' <<<"$out" ; chk $? "V4 \`test … && ls -lt\` — the test ends at &&, ls -lt is not a comparison"
cp age.sh v5.sh; h0=$(sha_of v5.sh)
bk5=$(bkpath v5.sh)
printf '. ./v5.sh\nrm -f v5.sh\nexit 0\n' > lane_v5.sh
out=$(python3 "$PROBE" v5.sh lane_v5.sh --timeout 30 2>&1); rc=$?
[ "$rc" -eq 2 ] && grep -q 'WROTE the subject' <<<"$out" && [ -f v5.sh ] && [ "$(sha_of v5.sh)" = "$h0" ] ; chk $? "V5 a baseline lane that DELETES the subject → restored, 2 (v2: traceback rc 1, no restore)"
grep -q 'WROTE the subject' <<<"$out" && [ ! -e "$bk5" ] ; chk $? "V5b and no backup is left behind (at the original inode's path) to block the next run"

echo "── W: third-round blind review (2026-10-07) — mtime-comparing build steps, self-locking subjects"
# a make-style step: rebuild dist/ only when the subject is NEWER (bash -nt compares mtimes)
mkw() {  # $1 = dir
  mkdir -p "$1/dist"
  cp age.sh "$1/age.sh"
  printf 'cd "%s"\nif [ ! -e dist/age.sh ] || [ age.sh -nt dist/age.sh ]; then cp age.sh dist/age.sh; fi\n. ./dist/age.sh\nis_adult 20 || exit 1\nis_adult 19 || exit 1\nis_adult 5 && exit 1\nexit 0\n' "$PWD/$1" > "$1/lane.sh"
}
# direction a — an OLD subject with a fresh build dir: the mutant must reach dist/ and be killed
mkw wa; touch -d 2020-01-01 wa/age.sh 2>/dev/null || touch -t 202001010000 wa/age.sh
out=$(python3 "$PROBE" wa/age.sh wa/lane.sh --timeout 30 2>&1)
grep -qE 'mutants=1 killed=1 survived=0( |$)' <<<"$out" ; chk $? "W1 old subject + mtime-gated build: the mutant is rebuilt into dist/ and KILLED (v3: survived — orig+8s was still older than dist)"
# direction b — a just-edited subject: after the probe, dist/ must not keep a mutant while looking current
mkw wb
out=$(python3 "$PROBE" wb/age.sh wb/lane.sh --timeout 30 2>&1)
if [ -e wb/dist/age.sh ] && grep -qE 'mutants=1 killed=1 ' <<<"$out" && { cmp -s wb/age.sh wb/dist/age.sh || [ wb/age.sh -nt wb/dist/age.sh ]; }; then r=0; else r=1; fi
chk $r "W2 after the probe, dist/ is either the original or visibly stale — never a mutant that looks up to date (v3: restored the old mtime under a mutant build)"
# the subject's own pyc does not outlive the probe
mkdir -p wc && cp v1b/gate.py wc/gate.py && sed 's#v1b#wc#' v1b/lane.py > wc/lane.py
printf 'exec python3 -I -c "exec(open(\\"wc/lane.py\\").read())"\n' > wc/lane.sh
out_wc=$(python3 "$PROBE" wc/gate.py wc/lane.sh --timeout 30 2>&1)
pyc=$(python3 -c 'import importlib.util,os,sys;print(importlib.util.cache_from_source(os.path.abspath(sys.argv[1])))' wc/gate.py)
grep -qE 'mutants=3 killed=2 survived=1( |$)' <<<"$out_wc" && [ ! -e "$pyc" ] ; chk $? "W3 the subject's __pycache__ entry is deleted at the end (a -I lane writes it; v3 left the last mutant's)"
# a subject that flocks its own path must not read the probe as «already running»
cat > self.py <<'EOF'
import fcntl, sys
fh = open(__file__)
try:
    fcntl.flock(fh, fcntl.LOCK_EX | fcntl.LOCK_NB)
except OSError:
    print("already running"); sys.exit(0)
def ok(x):
    return x >= 19
sys.exit(0 if ok(int(sys.argv[1])) else 1)
EOF
printf 'python3 self.py 20 || exit 1\npython3 self.py 19 || exit 1\npython3 self.py 5 && exit 1\nexit 0\n' > lane_self.sh
out=$(python3 "$PROBE" self.py lane_self.sh --timeout 30 2>&1)
grep -qE 'mutants=1 killed=1 survived=0( |$)' <<<"$out" ; chk $? "W4 a self-flocking subject runs normally under the probe (v3: the probe's lock on the subject made it exit «already running»)"
W5D=$(mktemp -d /tmp/mp_w5.XXXXXX); chmod 755 "$W5D"
cp "$PROBE" "$W5D/mp.py"; cp age.sh "$W5D/ro.sh"; cp lane_weak.sh "$W5D/lane.sh"; chmod 444 "$W5D/ro.sh"; chmod 644 "$W5D/mp.py" "$W5D/lane.sh"
if [ "$(id -u)" -ne 0 ]; then AS=""; elif command -v setpriv >/dev/null 2>&1; then AS="setpriv --reuid=65534 --regid=65534 --clear-groups"; else AS=NONE; fi
if [ "$AS" = NONE ]; then
  echo "  ⚠️  W5 UNMEASURED — root and no setpriv to drop privileges"; UNMEASURED=$((UNMEASURED+1))
else
  out=$(cd "$W5D" && $AS python3 mp.py ro.sh lane.sh --timeout 30 2>&1); rc=$?
  [ "$rc" -eq 2 ] && grep -q 'not writable' <<<"$out" && [ -z "$(ls "$W5D" | grep -v -e '^mp.py$' -e '^ro.sh$' -e '^lane.sh$')" ] ; chk $? "W5 a read-only subject → 2 before anything is written (measured as an unprivileged user when run as root)"
fi
rm -rf "$W5D"

echo "── Y: defects the capture-recapture detectors found that v4 still had (2026-10-07)"
cp age.sh y.sh; h0=$(sha_of y.sh)
out=$(python3 "$PROBE" y.sh lane_weak.sh --timeout 30 --json y.sh 2>&1); rc=$?
[ "$rc" -eq 2 ] && grep -q 'points at the subject' <<<"$out" && [ "$(sha_of y.sh)" = "$h0" ] ; chk $? "Y1 --json pointing at the subject → 2 and the subject untouched (v4: overwritten with JSON, rc 0)"
cat > yq.py <<'PY'
s = 'it\'s'; ok = a < b
PY
out=$(python3 "$PROBE" yq.py --list 2>&1)
grep -qE 'mutants=1( |$)' <<<"$out" && grep -qF '[<→<=]' <<<"$out" ; chk $? "Y2 python \\' inside '…' does not hide the < after it (v4: mutants=0)"
printf '#!/usr/bin/env bash\nr=$(python3 -u -c '"'"'\nimport sys\nok = len(sys.argv) >= 2\n'"'"')\npython3 - "$1" <<PY\nflag = True\nPY\necho please exit 1\n[ -n "$x" ] || exit 1\n' > yu.sh
out=$(python3 "$PROBE" yu.sh --list 2>&1)
grep -qF '[>=→>] ok = len(sys.argv) > 2' <<<"$out" ; chk $? "Y3 python3 -u -c ' body gets the python set (v4: only -I was recognised)"
grep -qF '[True→False] flag = False' <<<"$out" ; chk $? "Y3b python3 - \"\$1\" <<PY (an argument before <<) is still a python heredoc"
! grep -qF 'echo please exit 0' <<<"$out" && grep -qF '[exit 1→exit 0] [ -n "$x" ] || exit 0' <<<"$out" ; chk $? "Y4 exit N is mutated at command position only — echo's argument is data"
python3 "$PROBE" --help >/dev/null 2>&1 ; [ $? -eq 0 ] ; chk $? "Y5 --help → 0 (v4: 2, «cannot judge»)"
printf '. ./age.sh\nif read -r line; then exit 1; fi\nis_adult 20 || exit 1\nis_adult 19 || exit 1\nis_adult 5 && exit 1\nexit 0\n' > lane_stdin.sh
out=$(printf 'fed\n' | python3 "$PROBE" age.sh lane_stdin.sh --timeout 30 2>&1)
grep -qE 'mutants=1 killed=1 survived=0( |$)' <<<"$out" ; chk $? "Y6 the lane does not inherit the probe's stdin (v4: the lane read it and the baseline went red)"

echo "── Z: the reps=3 detectors' findings on v5 (2026-10-07) — generator rebuilt in v6"
# Z1 · Z2 — embedded-python openers inside a comment / a string must not switch modes (6/6 detectors)
mkdir -p z1 && cd z1
printf '#!/usr/bin/env bash\n# usage: python3 - <<'"'"'EOF'"'"'\necho hi > out.txt\n[ "$1" -ge 19 ]\n' > z.sh
printf '. ./z.sh 20 || exit 1\n. ./z.sh 19 || exit 1\n. ./z.sh 5 && exit 1\nexit 0\n' > lane.sh
out=$(python3 "$PROBE" z.sh lane.sh --timeout 30 2>&1)
grep -qE 'mutants=1 killed=1 survived=0( |$)' <<<"$out" && [ ! -e '=' ] ; chk $? "Z1 a commented 'python3 - <<EOF' opens nothing: only -ge is mutated, no stray «=» file (v5: redirect mutated, file created)"
cd ..
printf '#!/usr/bin/env bash\necho "tip: python3 -c '"'"'"\ncmd > log.txt\n[ "$x" -eq 1 ]\n' > z2.sh
out=$(python3 "$PROBE" z2.sh --list 2>&1)
grep -qE 'mutants=1( |$)' <<<"$out" && grep -qF '[-eq→-ne]' <<<"$out" ; chk $? "Z2 a quoted 'python3 -c' opens nothing"
# Z3 — python stdin DATA and another command's heredoc are data
printf '#!/usr/bin/env bash\npython3 tool.py <<EOF\nthreshold == 3\nEOF\npython3 setup.py && cat <<EOF\nx >= 3\nEOF\n[ "$y" -eq 1 ]\n' > z3.sh
out=$(python3 "$PROBE" z3.sh --list 2>&1)
grep -qE 'mutants=1( |$)' <<<"$out" ; chk $? "Z3 'python3 tool.py <<EOF' and '… && cat <<EOF' bodies are data, not code"
# Z4 · Z5 — comments after ; and glued python comments
printf '#!/usr/bin/env bash\ntrue;# [ "$a" -ne 1 ]\n[ "$b" -eq 2 ]\n' > z4.sh
out=$(python3 "$PROBE" z4.sh --list 2>&1)
grep -qE 'mutants=1( |$)' <<<"$out" && grep -qF '[ "$b" -ne 2 ]' <<<"$out" ; chk $? "Z4 ';#' starts a comment"
printf 'x = 1#a < b\ny = 2 >= 1\n' > z5.py
out=$(python3 "$PROBE" z5.py --list 2>&1)
grep -qE 'mutants=1( |$)' <<<"$out" ; chk $? "Z5 a python comment glued to code ('1#a < b') is not mutated"
# Z6 — command position by WORD, not by suffix; and the positions v5 missed
cat > z6.sh <<'EOF'
#!/usr/bin/env bash
echo todo exit 1
echo strengthen exit 2
echo wow! exit 3
foo & exit 4
case "$x" in bad) exit 5 ;; esac
f() { local rc=1; export FAILED=1; return 6; }
EOF
out=$(python3 "$PROBE" z6.sh --list 2>&1)
grep -qE 'mutants=5( |$)' <<<"$out" && ! grep -qE 'echo (todo|strengthen|wow!) exit 0' <<<"$out" ; chk $? "Z6 todo/strengthen/wow! are data; '& exit', 'bad) exit', 'local rc=1', 'export FAILED=1', 'return 6' are mutated (5)"
# Z7 — the word 'test' as an argument
printf '#!/usr/bin/env bash\necho test = foo\necho unit test -ne done\ntest "$a" = b\n' > z7.sh
out=$(python3 "$PROBE" z7.sh --list 2>&1)
grep -qE 'mutants=1( |$)' <<<"$out" && grep -qF 'test "$a" != b' <<<"$out" ; chk $? "Z7 'echo test = foo' is data; only the real test command is mutated"
# Z8 — line numbers by \n only; U+2028 / \x0c inside strings are not line breaks
printf 'import sys\n\x0c\ns = "a\xe2\x80\xa8 x >= y"\ndef f(a, b):\n    return a < b\n' > z8.py
out=$(python3 "$PROBE" z8.py --list 2>&1)
grep -qE 'mutants=1( |$)' <<<"$out" && grep -qF 'L5 [<→<=]' <<<"$out" ; chk $? "Z8 a form feed does not shift line numbers and U+2028 does not split a string"
# Z9 — multi-line strings and another language's program are data
printf '#!/usr/bin/env bash\nmsg="usage:\n  then exit 1 on error\n"\nawk '"'"'\n  END { exit 1 }\n'"'"' /dev/null\n[ "$z" -eq 0 ]\n' > z9.sh
out=$(python3 "$PROBE" z9.sh --list 2>&1)
grep -qE 'mutants=1( |$)' <<<"$out" ; chk $? "Z9 a multi-line \"…\" string and a multi-line awk '…' body are not mutated"
# Z10 — triple quotes inside embedded python; code after a closing docstring
printf '#!/usr/bin/env bash\npython3 - <<'"'"'EOF'"'"'\nDOC = """\n a < b means\n"""\nok = 1 < 2\nEOF\n' > z10.sh
out=$(python3 "$PROBE" z10.sh --list 2>&1)
grep -qE 'mutants=1( |$)' <<<"$out" && grep -qF 'ok = 1 <= 2' <<<"$out" ; chk $? "Z10 a triple-quoted string inside embedded python is data"
printf 'x = """\ndoc\n"""; y = a < b\n' > z10.py
out=$(python3 "$PROBE" z10.py --list 2>&1)
grep -qF 'y = a <= b' <<<"$out" ; chk $? "Z10b code after a closing docstring on the same line is mutated (v5: skipped)"
# Z11 · Z12 · Z13 — (( in quotes · $[ ] · two heredocs on one line
printf '#!/usr/bin/env bash\necho "((" > out.txt ; echo "))"\nx=$[1 << 2]\n[ "$x" -eq 4 ]\ncat <<A <<B\nA body exit 1\nA\nB body -eq\nB\n' > z11.sh
out=$(python3 "$PROBE" z11.sh --list 2>&1)
grep -qE 'mutants=1( |$)' <<<"$out" && grep -qF '[ "$x" -ne 4 ]' <<<"$out" ; chk $? "Z11 quoted '((' is not arithmetic · \$[1 << 2] is not a heredoc · the 2nd of two heredocs is data"
# Z14 — versioned interpreter names, python operator coverage
printf '#!/usr/bin/env bash\npython3.11 -c '"'"'\nimport sys\nif len(sys.argv) > 1: sys.exit(1)\n'"'"'\n' > z14.sh
out=$(python3 "$PROBE" z14.sh --list 2>&1)
grep -qE 'mutants=2( |$)' <<<"$out" ; chk $? "Z14 'python3.11 -c' is embedded python (> and sys.exit(1))"
printf 'def f(a, b, rc):\n    if a is not None and a<b:\n        return 1\n    raise SystemExit(2)\n' > z14.py
out=$(python3 "$PROBE" z14.py --list 2>&1)
grep -qF '[is not→is]' <<<"$out" && grep -qF '[<→<=] if a is not None and a<=b:' <<<"$out" && grep -qF '[return 1→return 0]' <<<"$out" && grep -qF '[SystemExit(2)→SystemExit(0)]' <<<"$out" ; chk $? "Z14b python: 'is not', unspaced 'a<b', 'return 1', 'SystemExit(2)' are mutated"
# Z15 — the baseline lane turns the subject into a directory → restore failed, said as such (3)
cp age.sh z15.sh
printf 'rm -f z15.sh; mkdir z15.sh\nexit 0\n' > lane_z15.sh
out=$(python3 "$PROBE" z15.sh lane_z15.sh --timeout 30 2>&1); rc=$?
[ "$rc" -eq 3 ] && grep -q 'RESTORE FAILED' <<<"$out" ; chk $? "Z15 a baseline that replaces the subject with a directory → 3 «restore failed», not a traceback rc 1"
rmdir z15.sh 2>/dev/null; bk=$(bkpath z15.sh); [ -f "$bk" ] && cp "$bk" z15.sh && rm -f "$bk"
# Z16 — the lane cannot start (interpreter missing) → 2, subject untouched, no leftover
cp age.sh z16.sh; h0=$(sha_of z16.sh)
printf '#!/nonexistent/interp\nexit 0\n' > lane_z16.sh
out=$(python3 "$PROBE" z16.sh lane_z16.sh --timeout 30 2>&1); rc=$?
[ "$rc" -eq 2 ] && grep -q 'could not be started' <<<"$out" && [ "$(sha_of z16.sh)" = "$h0" ] && [ ! -e "$(bkpath z16.sh)" ] ; chk $? "Z16 a lane that cannot start → 2 with that reason, no backup left behind (v5: traceback rc 1 + blocking leftover)"
# Z17 — a closed stdout does not lose the run
cp age.sh z17.sh; h0=$(sha_of z17.sh)
sed 's#age\.sh#z17.sh#' lane_strong.sh > lane_z17.sh   # v6 ran lane_strong here, which never sources z17.sh — the v7 control caught it
python3 "$PROBE" z17.sh lane_z17.sh --timeout 30 2>z17.err | head -c 1 >/dev/null; rc=${PIPESTATUS[0]}; [ "$rc" -eq 0 ] || { echo "  (Z17 rc=$rc)"; sed 's/^/    /' z17.err; }
[ "$rc" -eq 0 ] && [ "$(sha_of z17.sh)" = "$h0" ] ; chk $? "Z17 stdout closed mid-run → still rc 0 and restored (v5: BrokenPipe traceback rc 1)"
# Z18 — --json through a hard link to the subject
cp age.sh z18.sh; ln -f z18.sh z18.json; h0=$(sha_of z18.sh)
out=$(python3 "$PROBE" z18.sh lane_weak.sh --timeout 30 --json z18.json 2>&1); rc=$?
[ "$rc" -eq 2 ] && grep -q 'points at the subject' <<<"$out" && [ "$(sha_of z18.sh)" = "$h0" ] ; chk $? "Z18 --json via a hard link to the subject → 2, subject untouched (v5: overwritten, rc 0)"
# Z19 — a signal v5 did not handle
cp age.sh z19.sh; h0=$(sha_of z19.sh)
printf '. ./z19.sh\nif grep -q -- "-gt" z19.sh; then touch z19.live; fi\nsleep 5\nexit 0\n' > lane_z19.sh
rm -f z19.live
python3 "$PROBE" z19.sh lane_z19.sh --timeout 30 >/dev/null 2>&1 & pz=$!
for _ in $(seq 1 100); do [ -e z19.live ] && break; sleep 0.1; done
kill -USR1 "$pz" 2>/dev/null; wait "$pz"; rc=$?
[ -e z19.live ] && [ "$rc" -eq "$((128 + $(kill -l USR1)))" ] && [ "$(sha_of z19.sh)" = "$h0" ] && [ ! -e "$(bkpath z19.sh)" ] ; chk $? "Z19 SIGUSR1 while the mutant is live (proved by the lane) → restored, platform signal exit, no leftover (v5: mutant left)"
# Z20 · Z21 — mode restored · mtime never in the future
cp age.sh z20.sh; chmod 755 z20.sh
printf '. ./z20.sh\nchmod 600 z20.sh\nis_adult 20 || exit 1\nis_adult 19 || exit 1\nexit 0\n' > lane_z20.sh
out=$(python3 "$PROBE" z20.sh lane_z20.sh --timeout 30 2>&1)
grep -qE 'mutants=1 killed=1 survived=0( |$)' <<<"$out" && [ "$(stat -c %a z20.sh 2>/dev/null || stat -f %Lp z20.sh)" = "755" ] ; chk $? "Z20 the file mode is restored too (v5: a lane's chmod / a re-created file stayed)"
printf '#!/usr/bin/env bash\n[ "$1" -ge 1 ]\n[ "$1" -ge 2 ]\n[ "$1" -ge 3 ]\n[ "$1" -ge 4 ]\n[ "$1" -ge 5 ]\n[ "$1" -ge 6 ]\n' > z21.sh
printf '. ./z21.sh 9\nexit 0\n' > lane_z21.sh   # runs the subject (v7 control) but checks nothing
out=$(python3 "$PROBE" z21.sh lane_z21.sh --timeout 30 2>&1)
python3 -c 'import os,sys,time;sys.exit(0 if os.stat(sys.argv[1]).st_mtime <= time.time() + 0.5 else 1)' z21.sh && grep -qE 'mutants=6 killed=0 survived=6( |$)' <<<"$out" ; chk $? "Z21 six fast mutants later, the subject's mtime is not in the future (v5: +1 s per write accumulated)"
# Z22 — an unchecked-hash pyc left from before must not hide the mutants
mkdir -p z22 && cp v1b/gate.py z22/gate.py && sed 's#v1b#z22#' v1b/lane.py > z22/lane.py
printf 'exec python3 -I -c "exec(open(\\"z22/lane.py\\").read())"\n' > z22/lane.sh
python3 -c 'import py_compile;py_compile.compile("z22/gate.py",invalidation_mode=py_compile.PycInvalidationMode.UNCHECKED_HASH)'
out=$(python3 "$PROBE" z22/gate.py z22/lane.sh --timeout 30 2>&1)
grep -qE 'mutants=3 killed=2 survived=1( |$)' <<<"$out" ; chk $? "Z22 a pre-existing unchecked-hash pyc is dropped before the baseline (v5: every mutant invisible → «survived», rc 0)"
# Z23 · Z24 · Z25 — lane shebang · --timeout · subject == lane
printf '#!/usr/bin/env python3\nimport subprocess,sys\nok=lambda n: subprocess.run(["bash","-c",". ./age.sh; is_adult %%d" %% n]).returncode==0\nsys.exit(0 if ok(20) and ok(19) and not ok(5) else 1)\n' > lanepy
out=$(python3 "$PROBE" age.sh lanepy --timeout 30 2>&1)
grep -qE 'mutants=1 killed=1 survived=0( |$)' <<<"$out" ; chk $? "Z23 an extension-less lane runs by its python shebang (v5: run with bash → baseline red)"
out=$(python3 "$PROBE" age.sh lane_weak.sh --timeout 0 2>&1); rc=$?
[ "$rc" -eq 2 ] && grep -q 'timeout must be > 0' <<<"$out" ; chk $? "Z24 --timeout 0 → 2 with that reason (v5: reported as «baseline not green»)"
out=$(python3 "$PROBE" age.sh age.sh 2>&1); rc=$?
[ "$rc" -eq 2 ] && grep -q 'same file' <<<"$out" ; chk $? "Z25 subject == lane → 2"
# Z26 — the lane writes the subject only while a mutant is live
cp age.sh z26.sh
printf '. ./z26.sh\nif grep -q -- "-gt" z26.sh; then echo "# junk" >> z26.sh; fi\nis_adult 20 || exit 1\nexit 0\n' > lane_z26.sh
out=$(python3 "$PROBE" z26.sh lane_z26.sh --timeout 30 2>&1); rc=$?
[ "$rc" -eq 2 ] && grep -q 'while a mutant was live' <<<"$out" ; chk $? "Z26 a lane that writes the subject during a mutant → 2 (v5: silently overwritten, its verdict counted)"
# Z27 — two subjects sharing one lane, concurrently
cp age.sh z27a.sh; cp age.sh z27b.sh
printf 'sleep 2\nexit 0\n' > lane_z27.sh
python3 "$PROBE" z27a.sh lane_z27.sh --timeout 30 >/dev/null 2>&1 & pa=$!
sleep 0.5
out=$(python3 "$PROBE" z27b.sh lane_z27.sh --timeout 30 2>&1); rc=$?
wait $pa
[ "$rc" -eq 2 ] && grep -q 'holds the lane' <<<"$out" ; chk $? "Z27 a second probe on the same lane is refused (v5: both measured, verdicts cross-contaminated)"
# Z28 — a POSIX sh subject never gets '=='
printf '#!/bin/sh\n[ "$a" != b ] && echo d\n[ "$c" = d ] && echo e\n' > z28.sh
out=$(python3 "$PROBE" z28.sh --list 2>&1)
! grep -qF '==' <<<"$out" && grep -qF '[=→!=]' <<<"$out" ; chk $? "Z28 #!/bin/sh: '!=' is not flipped to the non-POSIX '==' (= → != still is)"

if [ "$HAVE_PROC" -eq 1 ]; then   # the process counter itself, on a known pair, before any lane trusts it
  sleep 4646 & kp=$!; sleep 0.1; k1=$(procs_matching 'sleep 4646'); kill "$kp"; wait "$kp" 2>/dev/null; k0=$(procs_matching 'sleep 4646')
  [ "$k1" -eq 1 ] && [ "$k0" -eq 0 ] ; chk $? "K0 the /proc process counter sees a live sleep (1) and not a dead one (0) — and not itself"
fi
echo "── S7: v7 safety contract — each lane red on v6 (2026-10-08, from the v6 capture-recapture detectors)"

# S7-1 — the lane swaps the subject for a symlink while a mutant is live → 3, and the link target is NOT written
cp age.sh s71.sh; printf 'VICTIM\n' > victim71.txt
bk71i=$(python3 -c 'import os,sys;s=os.stat(sys.argv[1]);print("/tmp/mutation_probe-%d/inode-%d-%d.backup"%(os.getuid(),s.st_dev,s.st_ino))' s71.sh)
printf '. ./s71.sh\nif grep -q -- "-gt" s71.sh; then rm -f s71.sh; ln -s victim71.txt s71.sh; fi\nis_adult 20 || exit 1\nexit 0\n' > lane_s71.sh
out=$(python3 "$PROBE" s71.sh lane_s71.sh --timeout 30 2>&1); rc=$?
[ "$rc" -eq 3 ] && grep -q 'RESTORE FAILED' <<<"$out" && [ "$(cat victim71.txt)" = "VICTIM" ] ; chk $? "S7-1 subject swapped for a symlink → RESTORE FAILED 3, the link target untouched (v6: rc 2 and the victim overwritten)"
rm -f s71.sh "$(bkpath s71.sh)" "$bk71i" 2>/dev/null   # this lane's own backups only — never a wildcard (rev7 #12)

# S7-2 — same bytes, new inode (cp+mv) while a mutant is live → 2, and the other hard link is restored
cp age.sh s72.sh; ln -f s72.sh s72_alias.sh; h0=$(sha_of s72.sh)
printf '. ./s72.sh\nif grep -q -- "-gt" s72.sh; then cat s72.sh > s72.tmp; mv s72.tmp s72.sh; fi\nis_adult 20 || exit 1\nis_adult 19 || exit 1\nexit 0\n' > lane_s72.sh
out=$(python3 "$PROBE" s72.sh lane_s72.sh --timeout 30 2>&1); rc=$?
[ "$rc" -eq 2 ] && grep -q 'REPLACED' <<<"$out" && [ "$(sha_of s72_alias.sh)" = "$h0" ] && [ "$(sha_of s72.sh)" = "$h0" ] ; chk $? "S7-2 inode replaced with the same bytes → 2, both names end original (v6: rc 0, the hard link kept the mutant)"

# S7-3 — crossed probes: A mutates x with lane y, B mutates y with lane x → one of them refuses
printf '#!/usr/bin/env bash\nis_a() { [ "$1" -ge 19 ]; }\n' > x73.sh
printf '#!/usr/bin/env bash\nis_b() { [ "$1" -ge 19 ]; }\n. ./x73.sh\ntouch s73.started\nsleep 2\nis_a 20 || exit 1\nis_a 19 || exit 1\nis_b 19 >/dev/null; exit 0\n' > y73.sh
rm -f s73.started
python3 "$PROBE" x73.sh y73.sh --timeout 30 > s73_a.out 2>&1 & pa=$!
for _ in $(seq 1 100); do [ -e s73.started ] && break; sleep 0.1; done
out=$(python3 "$PROBE" y73.sh x73.sh --timeout 30 2>&1); rc_b=$?
wait $pa
[ -e s73.started ] && [ "$rc_b" -eq 2 ] && grep -q 'another mutation_probe holds' <<<"$out" ; chk $? "S7-3 a probe whose subject is another probe's lane refuses (v6: both rc 0, each mutating the other's lane)"

# S7-4 — whatever the lane builds from the last mutant is rebuilt from the original
cp age.sh s74.sh
printf 'cp s74.sh installed74.sh\n. ./installed74.sh\nis_adult 20 || exit 1\nis_adult 19 || exit 1\nexit 0\n' > lane_s74.sh
out=$(python3 "$PROBE" s74.sh lane_s74.sh --timeout 30 2>&1); rc=$?
[ "$rc" -eq 0 ] && grep -qE 'mutants=1 killed=1 ' <<<"$out" && cmp -s s74.sh installed74.sh ; chk $? "S7-4 a derived copy ends as the ORIGINAL — the final lane run rebuilds it (v6: installed copy kept -gt)"

# S7-5 — a setsid escapee is killed (Linux subreaper); unmeasurable without /proc → UNMEASURED, never PASS
if [ "$HAVE_PROC" -eq 1 ] && command -v setsid >/dev/null 2>&1; then
  cp age.sh s75.sh; rm -f s75.started
  printf '. ./s75.sh\nsetsid sh -c "touch s75.started; exec sleep 4848" </dev/null >/dev/null 2>&1 &\nsleep 0.3\nis_adult 20 || exit 1\nis_adult 19 || exit 1\nexit 0\n' > lane_s75.sh
  out=$(python3 "$PROBE" s75.sh lane_s75.sh --timeout 30 2>&1)
  sleep 0.3
  [ -e s75.started ] && grep -qE 'mutants=1 ' <<<"$out" && [ "$(procs_matching 'sleep 4848')" -eq 0 ] ; chk $? "S7-5 a setsid descendant of the lane does not outlive the probe (v6: it kept running with the mutant)"
else
  echo "  ⚠️  S7-5 UNMEASURED — no /proc or no setsid"; UNMEASURED=$((UNMEASURED+1))
fi

# S7-6 — a «cannot judge» run writes no --json
cp age.sh s76.sh; rm -f s76.json
printf '. ./s76.sh\nif grep -q -- "-gt" s76.sh; then echo "# x" >> s76.sh; fi\nexit 0\n' > lane_s76.sh
out=$(python3 "$PROBE" s76.sh lane_s76.sh --timeout 30 --json s76.json 2>&1); rc=$?
[ "$rc" -eq 2 ] && grep -q 'while a mutant was live' <<<"$out" && [ ! -e s76.json ] ; chk $? "S7-6 --json is not written for a «cannot judge» run (v6: wrote counts that read as a measurement)"
out=$(python3 "$PROBE" age.sh lane_strong.sh --timeout 30 --json s76ok.json 2>&1)
python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));sys.exit(0 if d.get("measured") is True and d["counts"]["KILLED"]==1 else 1)' s76ok.json ; chk $? "S7-6b and a measured run does write it, marked measured"

# S7-7 — a lane that never runs the subject: the positive control survives → 2
cp age.sh s77.sh; printf 'exit 0\n' > lane_s77.sh
out=$(python3 "$PROBE" s77.sh lane_s77.sh --timeout 30 2>&1); rc=$?
[ "$rc" -eq 2 ] && grep -q 'positive control SURVIVED' <<<"$out" ; chk $? "S7-7 a lane that never runs the subject → 2 via the positive control (v6: rc 0, «survived» everything)"

# S7-8 — the lane's shebang is read by the kernel (one argument), not shlex
cp age.sh s78.sh; printf '#!/bin/bash -e -u\n. ./s78.sh\nis_adult 20 || exit 1\nexit 0\n' > lane_s78.sh; chmod +x lane_s78.sh
out=$(python3 "$PROBE" s78.sh lane_s78.sh --timeout 30 2>&1); rc=$?
direct=$(./lane_s78.sh >/dev/null 2>&1; echo $?)
if [ "$direct" -ne 0 ]; then
  [ "$rc" -eq 2 ] && grep -q 'not green' <<<"$out"; result=$?
else
  [ "$rc" -eq 0 ] && grep -qE 'mutants=1 killed=0 survived=1 ' <<<"$out"; result=$?
fi
chk "$result" "S7-8 executable lane follows this kernel: direct=$direct, probe=$rc (Linux and Darwin shebang parsing differ)"

# S7-9 — mode bits, not access(): a 0444 subject is refused even for root
cp age.sh s79.sh; chmod 444 s79.sh; h0=$(sha_of s79.sh)
out=$(python3 "$PROBE" s79.sh lane_weak.sh --timeout 30 2>&1); rc=$?
[ "$rc" -eq 2 ] && grep -q 'not writable' <<<"$out" && [ "$(sha_of s79.sh)" = "$h0" ] ; chk $? "S7-9 a read-only subject is refused by its mode bits (v6 as root: mutated in place, rc 0)"
chmod 644 s79.sh

# S7-10 — a subject whose mtime is in the future is refused, not pushed further
cp age.sh s710.sh; python3 -c 'import os,sys,time;t=time.time()+300;os.utime(sys.argv[1],(t,t))' s710.sh
m0=$(python3 -c 'import os,sys;print(int(os.stat(sys.argv[1]).st_mtime))' s710.sh)
out=$(python3 "$PROBE" s710.sh lane_weak.sh --timeout 30 2>&1); rc=$?
m1=$(python3 -c 'import os,sys;print(int(os.stat(sys.argv[1]).st_mtime))' s710.sh)
[ "$rc" -eq 2 ] && grep -q 'in the future' <<<"$out" && [ "$m0" = "$m1" ] ; chk $? "S7-10 a future mtime → 2 and left as is (v6: +1 s per write, 105 s in the future after a run)"

# S7-11 — a leftover backup is found under another name of the same inode (hard link)
cp age.sh s711.sh; ln -f s711.sh s711_alias.sh
ino_bk=$(python3 -c 'import os,sys;s=os.stat(sys.argv[1]);print("/tmp/mutation_probe-%d/inode-%d-%d.backup"%(os.getuid(),s.st_dev,s.st_ino))' s711.sh)
mkdir -p "/tmp/mutation_probe-$(id -u)"; chmod 700 "/tmp/mutation_probe-$(id -u)"; cp s711.sh "$ino_bk"
out=$(python3 "$PROBE" s711_alias.sh lane_weak.sh --timeout 30 2>&1); rc=$?
rm -f "$ino_bk"
[ "$rc" -eq 2 ] && grep -q 'previous run left a backup' <<<"$out" ; chk $? "S7-11 a SIGKILL leftover blocks a run through a hard-linked name too (v6: keyed by path only — the mutant was backed up as «original»)"

echo "── G7: v6 generator classes, pinned (fail-closed: uncertain → no mutant)"
g7() {  # $1 file, $2 content, $3 expected exact --list count
  printf '%b' "$2" > "$1"; python3 "$PROBE" "$1" --list 2>&1
}
out=$(g7 g71.sh '#!/bin/bash\n((cd /tmp && ls) > out.txt)\necho hi 2>/dev/null\n[ "$1" -ge 1 ] || exit 3\n')
grep -qE 'mutants=2( |$)' <<<"$out" && ! grep -qE '\[(>|<)→' <<<"$out" ; chk $? "G7-1 «((cmd) …)» is a subshell: no redirect mutant, and the test + exit after it are still found (v6: >→>= and a file named =)"
out=$(g7 g72.sh '#!/bin/bash\nx="$(echo "it'"'"'s")"\n[ "$a" -eq 1 ] && exit 1\ny=${x:-"}"}\necho "if x; then exit 1; fi"\n')
grep -qE 'mutants=2( |$)' <<<"$out" && grep -q 'L3 \[-eq' <<<"$out" && ! grep -q 'L5 ' <<<"$out" ; chk $? "G7-2 nested quotes in \"\$( )\" and \${x:-\"}\"} keep quote polarity (v6: everything after vanished or became code)"
out=$(g7 g73.sh '#!/bin/bash\npython3 check.py - <<EOF\nthreshold == 3\nEOF\npython3 -m mod -c '"'"'x <= y'"'"'\npython3 run.py -c '"'"'a >= 3'"'"'\npython3 -Sc '"'"'import sys; sys.exit(1 if 2 > 1 else 0)'"'"'\n')
grep -qE 'mutants=1( |$)' <<<"$out" && grep -q 'L7 \[>→' <<<"$out" ; chk $? "G7-3 python only when -c/stdin are INTERPRETER options (-Sc yes; script.py -, -m … -c, run.py -c no)"
out=$(g7 g74.sh '#!/bin/bash\ncat <<END-X\nEND\n[ 1 -eq 1 ] && exit 1\nEND-X\necho retry then exit 1\ncase "$x" in\n  rc=1) echo hi ;;\nesac\nfalse || exit 1>&2\n(true)# note; exit 1\nfunction m { return 2; }\n')
grep -qE 'mutants=1( |$)' <<<"$out" && grep -q 'L12 \[return 2' <<<"$out" ; chk $? "G7-4 heredoc «END-X» · keyword as argument · case pattern · exit 1>&2 · )# comment → data; function body → code"
out=$(g7 g75.py '#!/usr/bin/env python3\nimport subprocess, sys\ndef f(a=True):\n    subprocess.run(["x"], shell=True, check=True)\n    ok = True\n    return 0x0\ndef g():\n    return -1\nsys.exit(-2)\n')
grep -qE 'mutants=3( |$)' <<<"$out" && grep -q 'L5 \[True' <<<"$out" && grep -q 'L8 \[return -1' <<<"$out" && grep -q 'L9 \[sys.exit(-2)' <<<"$out" ; chk $? "G7-5 python: keyword/default True and zero-equivalents are not mutated; negative exit codes are"
printf '#!/bin/bash\nx=1\npython3 - <<EOF\nprint($x)\nEOF\n[ "$x" -eq 1 ] || exit 1\n' > g76.sh
printf 'bash ./g76.sh >/dev/null 2>&1 || exit 1\nexit 0\n' > lane_g76.sh
out=$(python3 "$PROBE" g76.sh lane_g76.sh --timeout 30 2>&1)
grep -qE 'invalid=0' <<<"$out" && grep -qE 'mutants=2 killed=1 survived=1 ' <<<"$out" ; chk $? "G7-6 a shell-expanded python heredoc does not make every mutant INVALID (v6: invalid=2, nothing measured)"

echo "── R7: blind review of v7 (2026-10-08) — each lane red on fbfe773"
# R7-1 — a probe that READ the subject while another probe's mutant was live, and locked it only after that
#        probe had restored it, must not adopt the mutant. Deterministic: the subject is large enough that
#        reading + enumerating it outlasts the 0.4 s after which «the other probe» puts the original back.
printf '#!/usr/bin/env bash\n[ "$a" -ne 1 ] && echo x1\n' > r71.orig
for k in $(seq 2 6000); do printf '[ "$a" -eq %d ] && echo x%d\n' "$k" "$k"; done >> r71.orig
sed '2s/-ne 1/-eq 1/' r71.orig > r71.sh            # the other probe's mutant is live
printf 'grep -q "exit 113" r71.sh && exit 1\nexit 0\n' > lane_r71.sh
s71=$(date +%s%N)
python3 "$PROBE" r71.sh lane_r71.sh --max 1 --timeout 30 > r71.out 2>&1 & pb=$!
sleep 0.4; cat r71.orig > r71.sh; t71=$(date +%s%N)   # … and now it restores (same inode)
wait "$pb"; rc=$?
grep -q 'changed between reading it and locking it' r71.out && [ "$rc" -eq 2 ] && cmp -s r71.sh r71.orig && [ ! -e "$(bkpath r71.sh)" ] ; chk $? "R7-1 a subject that changed between read and lock → 2, the original stays (fbfe773: the stale mutant was backed up as «original» and written back)"
cp r71.orig r71.sh

# R7-2 — the lane hard-links an unrelated file to the subject's path: that file is never written
cp age.sh r72.sh; printf 'VICTIM\n' > victim72.txt
printf '. ./r72.sh\nif grep -q -- "-gt" r72.sh; then ln -f victim72.txt r72.sh; fi\nis_adult 20 || exit 1\nexit 0\n' > lane_r72.sh
out=$(python3 "$PROBE" r72.sh lane_r72.sh --timeout 30 2>&1); rc=$?
[ "$rc" -eq 2 ] && [ "$(cat victim72.txt)" = "VICTIM" ] && cmp -s r72.sh age.sh ; chk $? "R7-2 a hard link to another file at the path is replaced, not written into (fbfe773: victim overwritten)"

# R7-3 — a --json path the lane turns into a symlink to the subject
cp age.sh r73.sh; rm -f r73.json
sed 's#age\.sh#r73.sh#' lane_strong.sh > lane_r73.sh; printf '[ -e r73.json ] || ln -s r73.sh r73.json\n' | cat - lane_r73.sh > lane_r73b.sh
out=$(python3 "$PROBE" r73.sh lane_r73b.sh --timeout 30 --json r73.json 2>&1); rc=$?
[ "$rc" -eq 2 ] && cmp -s r73.sh age.sh ; chk $? "R7-3 --json through a link the lane planted → 2, subject intact (fbfe773: subject overwritten with JSON, rc 0)"

# R7-4 — a positive control that hangs is not «noticed»
cp age.sh r74.sh
printf 'if grep -q "exit 113" r74.sh; then sleep 30; fi\n. ./r74.sh\nis_adult 20 || exit 1\nexit 0\n' > lane_r74.sh
out=$(python3 "$PROBE" r74.sh lane_r74.sh --timeout 2 2>&1); rc=$?
[ "$rc" -eq 2 ] && grep -q 'positive control did not finish' <<<"$out" ; chk $? "R7-4 a control that times out → 2 (fbfe773: counted as the lane noticing)"

# R7-5 … R7-10 — generator: data that sat in code position
out=$(g7 r75.sh '#!/bin/bash\n[ "$1" = -eq ]\n[ "$a" -eq 1 ] && [ ! "$b" = c ]\n[[ $a == b && $c -gt 2 ]]\n')
grep -qE 'mutants=5( |$)' <<<"$out" && ! grep -q '\[-eq→-ne\] \[ "$1"' <<<"$out" ; chk $? "R7-5 only the OPERATOR of a test is mutated — an operand spelled -eq is not; ! and && reset the position"
out=$(g7 r76.sh '#!/bin/bash\ncodes=(exit 1)\nopts=(rc=1 other)\ndiff <(sort a) FAILED=1\nexit 2\n')
grep -qE 'mutants=1( |$)' <<<"$out" && grep -q 'L5 \[exit 2' <<<"$out" ; chk $? "R7-6 array literals and <( ) leave their arguments as data"
out=$(g7 r77.sh '#!/bin/bash\ncase $x in\n a) case $n in b) echo ;; esac ;;\n rc=1) echo matched ;;\nesac\nrc=1\n')
grep -qE 'mutants=1( |$)' <<<"$out" && grep -q 'L6 \[rc=1' <<<"$out" ; chk $? "R7-7 a nested case restores the outer case's pattern state"
out=$(g7 r78.sh '#!/bin/bash\n[ "$x" = y]|| echo bad\necho a = b c == d\nx="$(python3 - <<PY\nok = 1 < 2\nPY\n)"\n[ "$x" = y ] || exit 3\n')
grep -qE 'mutants=2( |$)' <<<"$out" && grep -q 'L8 \[=' <<<"$out" && grep -q 'L8 \[exit 3' <<<"$out" ; chk $? "R7-8 an unclosed [ does not leak test mode into later lines; a python heredoc inside \"\$( )\" stays quiet"

echo "── R8: Codex review regressions — bounded output, lane identity, signals and redirect operands"
python3 - "$PROBE" <<'R8PY'
import os, pathlib, signal, subprocess, sys, tempfile, time, unittest
PROBE = os.path.abspath(sys.argv[1])
ORIGINAL = '#!/bin/bash\nis_adult() { [ "$1" -ge 19 ]; }\n'
LANE = '. ./age.sh\nis_adult 20 || exit 1\nis_adult 19 || exit 1\nis_adult 5 && exit 1\nexit 0\n'

class ReviewRegressions(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.tmp.name)
        (self.root / 'age.sh').write_text(ORIGINAL)
        (self.root / 'lane.sh').write_text(LANE)

    def tearDown(self):
        self.tmp.cleanup()

    def run_probe(self, *args):
        return subprocess.run([sys.executable, PROBE, *args], cwd=self.root,
                              capture_output=True, text=True, timeout=15)

    def test_fifo_output_is_bounded(self):
        os.mkfifo(self.root / 'out.json')
        result = self.run_probe('age.sh', 'lane.sh', '--json', 'out.json')
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.assertEqual((self.root / 'age.sh').read_text(), ORIGINAL)

    def test_regular_output_control(self):
        import json
        result = self.run_probe('age.sh', 'lane.sh', '--json', 'out.json')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(json.loads((self.root / 'out.json').read_text())['measured'])

    def test_replaced_lane_is_not_overwritten(self):
        body = ('if [ ! -e replaced ]; then cp lane.sh new.sh; mv new.sh lane.sh; '
                'ln lane.sh out.json; touch replaced; fi\n' + LANE)
        (self.root / 'lane.sh').write_text(body)
        result = self.run_probe('age.sh', 'lane.sh', '--json', 'out.json')
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.assertEqual((self.root / 'lane.sh').read_text(), body)
        self.assertEqual((self.root / 'age.sh').read_text(), ORIGINAL)

    def test_sigabrt_restores_live_mutant(self):
        (self.root / 'lane.sh').write_text(
            '. ./age.sh\nif grep -q -- "-gt" age.sh; then touch live; sleep 30; fi\n' + LANE)
        proc = subprocess.Popen([sys.executable, PROBE, 'age.sh', 'lane.sh', '--timeout', '40'],
                                cwd=self.root, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            deadline = time.monotonic() + 12
            while not (self.root / 'live').exists() and proc.poll() is None and time.monotonic() < deadline:
                time.sleep(0.05)
            self.assertTrue((self.root / 'live').exists(), 'no live-mutant control: UNMEASURED')
            proc.send_signal(signal.SIGABRT)
            self.assertEqual(proc.wait(timeout=5), 128 + signal.SIGABRT)
            self.assertEqual((self.root / 'age.sh').read_text(), ORIGINAL)
        finally:
            if proc.poll() is None:
                proc.terminate()
                proc.wait(timeout=5)

    def test_redirect_targets_are_data_but_following_command_is_code(self):
        (self.root / 'clean.sh').write_text(
            '#!/bin/bash\n>rc=1 printf hi\n2>FAIL=1 printf hi\n'
            '>>failed=1 printf hi\n<>rc=1 printf hi\n&>rc=1 printf hi\n'
            "python3 -c >'exit(1)' 'exit(0)'\n")
        result = self.run_probe('clean.sh', '--list')
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.assertIn('mutants=0', result.stdout)
        (self.root / 'positive.sh').write_text('#!/bin/bash\n2>rc=1 exit 2\n')
        result = self.run_probe('positive.sh', '--list')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('mutants=1', result.stdout)
        self.assertIn('[exit 2→exit 0]', result.stdout)

unittest.main(argv=[sys.argv[0]], verbosity=2)
R8PY
chk $? "R8 five review regressions and normal-output/generator controls"

echo "── RV: revert probe — neuter the kill decision"
sed "s/'KILLED' if rc != 0 else 'SURVIVED'/'KILLED'/" "$PROBE" > neutered.py
grep -q "else ('KILLED')" neutered.py ; chk $? "RV0 the neutering edit actually applied (else this lane measures nothing)"
out=$(python3 neutered.py age.sh lane_weak.sh --timeout 30 2>&1)
grep -qE 'mutants=1 killed=1 survived=0( |$)' <<<"$out" ; chk $? "RV1 with kill forced, the F1 survivor is counted killed (mutants=1 ran) — F1 would turn red; a run that produced no mutants cannot pass this"

sed "s/^ARITH_ONLY = True/ARITH_ONLY = False/" "$PROBE" > noarith.py
grep -q '^ARITH_ONLY = False' noarith.py ; chk $? "RV2-0 the redirect-guard neutering applied"
out=$(python3 noarith.py neg.sh --list 2>&1)
grep -q '\[>→>=\] cmd >= out.txt' <<<"$out" ; chk $? "RV2 without the (( )) restriction, \`cmd > out.txt\` becomes a mutant — C1 would turn red (the prototype's redirect bug, reproduced)"

echo ""
if [ "$FAILED" -eq 0 ] && [ "$UNMEASURED" -gt 0 ]; then echo "INCOMPLETE  mutation probe: $PASS lanes passed, $UNMEASURED UNMEASURED — not a pass"; exit 1; fi
if [ "$FAILED" -eq 0 ]; then echo "PASS  mutation probe: $PASS lanes"; exit 0; fi
echo "FAIL  mutation probe"; exit 1
