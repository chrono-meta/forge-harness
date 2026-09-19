#!/usr/bin/env bash
# test_sim_isolated_run_lanes.sh — behavioural known-pair lanes for scripts/sim_isolated_run.sh
#
# WHY THESE LANES AND NOT OTHERS. The runner exists because a sim became an agent fleet
# (2026-08-29: corpus self-contamination + a launchd agent written to the operator's machine +
# a false positive pointing at the desired conclusion). So the lanes pin the properties that
# failure would have needed, not the ones that are easy to assert:
#   L1–L3  usage guards            — a runner that silently accepts a bad mode runs the wrong thing
#   L4     ABSENT, never empty     — a missing surface and an empty one must not collapse
#   L5     THREE-valued verdict    — the first runner's `timeout 300` killed exactly the heavy arms
#                                    and left 0-byte files that read as "the identity did not fire".
#                                    A false RED manufactured by the instrument. `UNMEASURED` and
#                                    `EMPTY` must stay distinguishable from each other AND from a no.
#   L6     observe-mode VOID       — if the read-only tool set leaks, the run is void, not "clean"
#   L7     machine-surface diff    — the launchd class. Detector, not gate — but it must FIRE.
#   L8     --no-harness is opt-in  — `--restricted` drops the project CLAUDE.md, i.e. it measures
#                                    the BASE MODEL. If it ever became the default again, every
#                                    salience measurement would silently be of the wrong thing.
#   L9     always exit 0           — a detector that can block gets skipped; then it detects nothing
#
# The `claude` CLI is STUBBED. That is deliberate and it is the only way these lanes can carry a
# known pair: a real call is nondeterministic and costs money, so its output could never be a
# fixture. What is under test here is the runner's OWN logic — verdict classification, isolation
# bookkeeping, flag plumbing — never the model's answer.
#
# Usage: bash scripts/test_sim_isolated_run_lanes.sh

set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUT="${FH_SIM_RUNNER_BIN:-$ROOT/scripts/sim_isolated_run.sh}"
pass=0; fail=0
ok()  { printf '  ✅ %s\n' "$1"; pass=$((pass+1)); }
no()  { printf '  ❌ %s\n' "$1"; fail=$((fail+1)); }

if [ ! -f "$SUT" ]; then
  echo "FAIL  test_sim_isolated_run_lanes.sh: subject absent ($SUT) — skipped is not passed"
  exit 1
fi

WORKROOT="$(mktemp -d "${TMPDIR:-/tmp}/simlane-XXXXXX")"
trap 'rm -rf "$WORKROOT"' EXIT

# ── stub `claude` — behaviour selected by FH_STUB_MODE, read at call time ─────────────────────
STUBBIN="$WORKROOT/bin"; mkdir -p "$STUBBIN"
cat > "$STUBBIN/claude" <<'STUB'
#!/usr/bin/env bash
# Records the argv it was handed so a lane can assert on flag plumbing.
printf '%s\n' "$*" >> "${FH_STUB_ARGV_LOG:-/dev/null}"
case "${FH_STUB_MODE:-say}" in
  say)      echo "stub answer" ;;
  silent)   : ;;                                   # rc 0, no output  → EMPTY
  die)      exit 7 ;;                              # rc!=0, no output → UNMEASURED
  write)    echo "wrote"; : > "./LANE_SIDE_EFFECT.txt" ;;   # dirties its own clone
  machine)  echo "ok"; mkdir -p "$HOME/Library/LaunchAgents"
            : > "$HOME/Library/LaunchAgents/com.lane.probe.plist" ;;
  # 🟥 stdin 을 그대로 받아 적는다 — 실물 `claude -p` 가 하는 짓을 재현한다.
  #    진짜 CLI 는 stdin 이 TTY 가 아니면 그것을 «읽어 프롬프트 뒤에 붙인다».
  stdin)    echo "stub answer"; cat >> "${FH_STUB_STDIN_LOG:-/dev/null}" ;;
  # L26 (2026-09-05) — a command that runs long past any sane --timeout, default SIGTERM
  # disposition (no trap): dies as soon as the watchdog signals it, so a lane can tell "the
  # deadline was enforced" from "we just waited for it to finish on its own".
  # L28 — multi-turn. Emits the shape `--output-format json` produces and echoes back whichever
  # session id it was resumed with, so a lane can tell "the runner plumbed --resume" apart from
  # "it did not". A fresh call mints a NEW id from a counter file, which is what makes the
  # ARM/CTRL pair discriminate: same id across turns = carried, different ids = cold sessions.
  turns)    _sid=""; _prev=""; _res=0
            for _a in "$@"; do [ "$_prev" = "--resume" ] && _sid="$_a"; _prev="$_a"; done
            if [ -n "$_sid" ]; then _res=1; else
              _c=$(cat "${FH_STUB_SID_COUNTER:-/dev/null}" 2>/dev/null); [ -n "$_c" ] || _c=0
              _n=$((_c+1)); echo "$_n" > "${FH_STUB_SID_COUNTER:-/dev/null}" 2>/dev/null || true
              _sid="SID-$_n"
            fi
            printf '{"session_id":"%s","result":"resumed=%s sid=%s"}\n' "$_sid" "$_res" "$_sid" ;;
  # L28k/l/m — the three ways a multi-turn run can fail while looking clean.
  turns_badjson) echo "not json at all {" ;;
  turns_nosid)   printf '{"result":"answer with no session id"}\n' ;;
  turns_die2)    _c=$(cat "${FH_STUB_SID_COUNTER:-/dev/null}" 2>/dev/null); [ -n "$_c" ] || _c=0
                 _n=$((_c+1)); echo "$_n" > "${FH_STUB_SID_COUNTER:-/dev/null}" 2>/dev/null || true
                 if [ "$_n" -eq 2 ]; then exit 7; fi
                 printf '{"session_id":"SID-fixed","result":"turn %s ok"}\n' "$_n" ;;
  hang)     sleep 30 ;;
esac
exit 0
STUB
chmod +x "$STUBBIN/claude"

# A throwaway git repo for the runner to clone. `--local` needs a real repo with a commit.
SRC="$WORKROOT/src"; mkdir -p "$SRC"
( cd "$SRC" && git init -q . && git config user.email l@l && git config user.name l \
  && echo hi > f.txt && git add f.txt && git commit -qm init ) >/dev/null 2>&1

run_sut() {  # env is set by the caller; echoes combined output, sets RC
  OUT="$( cd "$SRC" && PATH="$STUBBIN:$PATH" bash "$SUT" "$@" 2>&1 )"; RC=$?
}

echo "── sim_isolated_run known-pair lanes ─────────────────────────────────"

# L1/L2/L3 — usage guards (known-negative: a bad invocation must NOT proceed)
run_sut --reps 1 --prompt p
[ "$RC" -eq 2 ] && ok "L1 missing --arm → exit 2" || no "L1 missing --arm: rc=$RC"
run_sut --arm a --reps 1
[ "$RC" -eq 2 ] && ok "L2 missing --prompt → exit 2" || no "L2 missing --prompt: rc=$RC"
run_sut --arm a --prompt p --mode bogus
[ "$RC" -eq 2 ] && ok "L3 bogus --mode → exit 2" || no "L3 bogus --mode: rc=$RC"

# L4 — ABSENT, never an empty line, for a surface that does not exist
FAKEHOME="$WORKROOT/home"; mkdir -p "$FAKEHOME"
OUTDIR="$WORKROOT/o4"
( cd "$SRC" && PATH="$STUBBIN:$PATH" HOME="$FAKEHOME" FH_STUB_MODE=say \
   bash "$SUT" --arm a --reps 1 --prompt p --out "$OUTDIR" ) >/dev/null 2>&1
if grep -q '^ABSENT$' "$OUTDIR/_machine_before.txt" 2>/dev/null; then
  ok "L4 missing surface recorded as ABSENT (not an empty line)"
else no "L4 ABSENT token missing from snapshot"; fi

# L5 — THREE-valued verdict. This is the lane the false-RED incident bought.
OUTDIR="$WORKROOT/o5a"
OUT=$( cd "$SRC" && PATH="$STUBBIN:$PATH" HOME="$FAKEHOME" FH_STUB_MODE=die \
   bash "$SUT" --arm a --reps 1 --prompt p --out "$OUTDIR" 2>&1 )
printf '%s' "$OUT" | grep -q "UNMEASURED" \
  && ok "L5a rc!=0 + 0 bytes → UNMEASURED (not a negative result)" \
  || no "L5a expected UNMEASURED, got: $(printf '%s' "$OUT" | grep -E 'r1' | head -1)"
OUTDIR="$WORKROOT/o5b"
OUT=$( cd "$SRC" && PATH="$STUBBIN:$PATH" HOME="$FAKEHOME" FH_STUB_MODE=silent \
   bash "$SUT" --arm a --reps 1 --prompt p --out "$OUTDIR" 2>&1 )
printf '%s' "$OUT" | grep -q "EMPTY" \
  && ok "L5b rc=0 + 0 bytes → EMPTY (distinct from UNMEASURED)" \
  || no "L5b expected EMPTY"
# known-POSITIVE for the pair: a normal answer must be neither
OUTDIR="$WORKROOT/o5c"
OUT=$( cd "$SRC" && PATH="$STUBBIN:$PATH" HOME="$FAKEHOME" FH_STUB_MODE=say \
   bash "$SUT" --arm a --reps 1 --prompt p --out "$OUTDIR" 2>&1 )
if printf '%s' "$OUT" | grep -q "captured" && ! printf '%s' "$OUT" | grep -qE "EMPTY|UNMEASURED"; then
  ok "L5c control — a real answer is captured, not classified as empty/unmeasured"
else no "L5c control failed (the three-way split does not discriminate)"; fi

# L6 — observe mode must call a write VOID, not clean
OUTDIR="$WORKROOT/o6"
OUT=$( cd "$SRC" && PATH="$STUBBIN:$PATH" HOME="$FAKEHOME" FH_STUB_MODE=write \
   bash "$SUT" --arm a --reps 1 --prompt p --mode observe --out "$OUTDIR" 2>&1 )
printf '%s' "$OUT" | grep -q "VOID" && printf '%s' "$OUT" | grep -q "CONTAMINATED" \
  && ok "L6 observe-mode write → VOID + CONTAMINATED" || no "L6 write in observe not caught"
# control: the same write in act mode is CONTAINED, not VOID
OUTDIR="$WORKROOT/o6b"
OUT=$( cd "$SRC" && PATH="$STUBBIN:$PATH" HOME="$FAKEHOME" FH_STUB_MODE=write \
   bash "$SUT" --arm a --reps 1 --prompt p --mode act --out "$OUTDIR" 2>&1 )
printf '%s' "$OUT" | grep -q "VOID" \
  && no "L6b control — act mode wrongly called VOID (the two modes are not separated)" \
  || ok "L6b control — same write in act mode is contained, not VOID"

# L7 — the launchd class. The detector must FIRE on a machine-surface delta.
OUTDIR="$WORKROOT/o7"
OUT=$( cd "$SRC" && PATH="$STUBBIN:$PATH" HOME="$FAKEHOME" FH_STUB_MODE=machine \
   bash "$SUT" --arm a --reps 1 --prompt p --mode act --out "$OUTDIR" 2>&1 )
printf '%s' "$OUT" | grep -q "MACHINE SURFACE CHANGED" \
  && ok "L7 machine-surface delta → detected + CONTAMINATED" \
  || no "L7 launchd-class side effect NOT detected"
rm -f "$FAKEHOME/Library/LaunchAgents/com.lane.probe.plist"

# L8 — --restricted is opt-in only. Both directions, because only the pair proves the plumbing.
OUTDIR="$WORKROOT/o8"; LOG="$WORKROOT/argv8.log"; : > "$LOG"
( cd "$SRC" && PATH="$STUBBIN:$PATH" HOME="$FAKEHOME" FH_STUB_MODE=say FH_STUB_ARGV_LOG="$LOG" \
   bash "$SUT" --arm a --reps 1 --prompt p --out "$OUTDIR" ) >/dev/null 2>&1
grep -q -- "--restricted" "$LOG" \
  && no "L8a DEFAULT passed --restricted — the harness under test would not be loaded" \
  || ok "L8a default does NOT pass --restricted (project CLAUDE.md stays resident)"
OUTDIR="$WORKROOT/o8b"; LOG2="$WORKROOT/argv8b.log"; : > "$LOG2"
( cd "$SRC" && PATH="$STUBBIN:$PATH" HOME="$FAKEHOME" FH_STUB_MODE=say FH_STUB_ARGV_LOG="$LOG2" \
   bash "$SUT" --arm a --reps 1 --prompt p --no-harness --out "$OUTDIR" ) >/dev/null 2>&1
grep -q -- "--restricted" "$LOG2" \
  && ok "L8b --no-harness DOES pass --restricted (control-arm generator works)" \
  || no "L8b --no-harness did not reach the CLI"

# L9 — detector, never a gate: even a contaminated run exits 0
OUTDIR="$WORKROOT/o9"
( cd "$SRC" && PATH="$STUBBIN:$PATH" HOME="$FAKEHOME" FH_STUB_MODE=write \
   bash "$SUT" --arm a --reps 1 --prompt p --mode observe --out "$OUTDIR" ) >/dev/null 2>&1
[ $? -eq 0 ] && ok "L9 always exit 0 (a detector that can block gets skipped)" \
             || no "L9 non-zero exit — callers will learn to skip it"

# L10 — the clone's PARENT must not expose sibling arms. Measured leak: an arm scanning `../`
# for mappable projects reported the other reps' work dirs by name.
OUTDIR="$WORKROOT/o10"
( cd "$SRC" && PATH="$STUBBIN:$PATH" HOME="$FAKEHOME" FH_STUB_MODE=say \
   bash "$SUT" --arm a --reps 2 --prompt p --out "$OUTDIR" ) >/dev/null 2>&1
# 🟥 PROPERTY-BASED ON PURPOSE. A first draft asserted on the literal path
# `<out>/w_a_r1/...`; a revert probe then "failed" it for the wrong reason — the path simply no
# longer existed, so the lane detected a rename rather than the leak. Locate the clones by what
# they ARE (directories containing .git under the out dir) and ask the actual question:
# does any clone's PARENT contain another clone?
CLONES=$(find "$OUTDIR" -maxdepth 3 -type d -name .git 2>/dev/null | sed 's|/.git$||' | sort)
nclone=$(printf '%s\n' "$CLONES" | grep -c . )
leak=0
for c in $CLONES; do
  par=$(dirname "$c")
  # count OTHER clones that share this parent
  others=$(printf '%s\n' "$CLONES" | grep -v "^$c$" | while read -r o; do
             [ "$(dirname "$o")" = "$par" ] && echo x; done | grep -c x)
  [ "$others" -gt 0 ] && leak=$((leak+1))
done
if [ "$nclone" -ge 2 ] && [ "$leak" -eq 0 ]; then
  ok "L10 no clone shares a parent with another ($nclone clones, 0 co-parented)"
else no "L10 sibling clones share a parent (clones=$nclone co-parented=$leak)"; fi
# control: the lane must be able to SEE two clones, else L10 passes on an empty set
[ "$nclone" -ge 2 ] \
  && ok "L10b control — $nclone clones found (L10 did not pass on an empty set)" \
  || no "L10b control — found $nclone clone(s); L10 proves nothing"

# L11 — --setup builds the precondition INSIDE the clone, and a failing setup VOIDs the arm
# rather than letting the sim run in a state it was not meant to observe.
OUTDIR="$WORKROOT/o11"
( cd "$SRC" && PATH="$STUBBIN:$PATH" HOME="$FAKEHOME" FH_STUB_MODE=say \
   bash "$SUT" --arm a --reps 1 --prompt p --out "$OUTDIR" \
   --setup 'mkdir -p tracks/demoproj' ) >/dev/null 2>&1
[ -d "$OUTDIR/w_a_r1/repo/tracks/demoproj" ] \
  && ok "L11 --setup ran inside the clone (precondition built)" \
  || no "L11 --setup did not take effect in the clone"
# and it must NOT have touched the source tree — the whole point of doing it in the clone
[ -d "$SRC/tracks/demoproj" ] \
  && no "L11b --setup leaked into the SOURCE tree" \
  || ok "L11b control — source tree untouched by --setup"
OUTDIR="$WORKROOT/o11c"
OUT=$( cd "$SRC" && PATH="$STUBBIN:$PATH" HOME="$FAKEHOME" FH_STUB_MODE=say \
   bash "$SUT" --arm a --reps 1 --prompt p --out "$OUTDIR" --setup 'exit 3' 2>&1 )
printf '%s' "$OUT" | grep -q "SETUP FAILED" && printf '%s' "$OUT" | grep -q "CONTAMINATED" \
  && ok "L11c failing --setup → arm VOID, not a silent negative result" \
  || no "L11c failing setup did not void the arm"

# L12 — --extra-tools must reach the CLI, and must NOT be there by default. Both directions,
# because this flag decides what the arm can SEE, and a silently-dropped tool turns an
# enumeration failure into what looks like a session misjudging.
OUTDIR="$WORKROOT/o12"; LOG12="$WORKROOT/argv12.log"; : > "$LOG12"
( cd "$SRC" && PATH="$STUBBIN:$PATH" HOME="$FAKEHOME" FH_STUB_MODE=say FH_STUB_ARGV_LOG="$LOG12" \
   bash "$SUT" --arm a --reps 1 --prompt p --out "$OUTDIR" --extra-tools Bash ) >/dev/null 2>&1
grep -q "Read,Grep,Glob,Bash" "$LOG12" \
  && ok "L12 --extra-tools appended to the tool set" \
  || no "L12 --extra-tools did not reach the CLI ($(head -1 "$LOG12" 2>/dev/null))"
OUTDIR="$WORKROOT/o12b"; LOG12B="$WORKROOT/argv12b.log"; : > "$LOG12B"
( cd "$SRC" && PATH="$STUBBIN:$PATH" HOME="$FAKEHOME" FH_STUB_MODE=say FH_STUB_ARGV_LOG="$LOG12B" \
   bash "$SUT" --arm a --reps 1 --prompt p --out "$OUTDIR" ) >/dev/null 2>&1
grep -q "Read,Grep,Glob,Bash" "$LOG12B" \
  && no "L12b control — Bash present WITHOUT --extra-tools (observe mode is not read-only)" \
  || ok "L12b control — no Bash without --extra-tools"

# ── L13 stdin 격리 (2026-08-31) — 🟥 이 레인이 없으면 근인이 조용히 재발한다 ────────────
#    실측: `claude -p` 는 **stdin 이 TTY 가 아니면 그것을 읽어 프롬프트 뒤에 붙인다.**
#    호출부(`context_continuity_score.sh`)가 `while … done < "$QSET"` 루프 «안»에서 이 러너를
#    부르므로, 러너도 claude 도 **stdin = 채점용 qset(정답 열 포함)** 을 상속했다.
#    ⇒ 회차 1~3 과 probe1~4 의 모든 팔이 정답키 전체를 받았다. ARM 도 CTRL 도.
#    🟥 경로 deny·코퍼스 마스킹은 **원리적으로 못 막는다** — 도구 읽기가 아니라 프롬프트 조립이다.
#    🟥 그리고 «팔에게 물어보면» 안 잡힌다: 팔은 그것을 「프롬프트 인젝션」이라 부르며 정직하게
#    거부하면서 **거부문 안에서 정답을 말하고**, 채점기는 그 문장을 토큰으로 센다.
#    라이브 확인은 이미 났다(같은 문항 q2, 변수는 stdin 하나: 수리 전 3/3 → 수리 후 0/3).
#    여기서는 **모델 없이 결함 자체**를 잰다 — 스텁이 자기가 받은 stdin 을 적는다.
BAIT="ZZSTDINBAIT$(printf '%s' 7731)"
OUTDIR="$WORKROOT/o13"; SLOG="$WORKROOT/stdin13.log"; : > "$SLOG"
printf 'q1\tpositive\t질문\t%s\n' "$BAIT" > "$WORKROOT/bait.tsv"
( cd "$SRC" && PATH="$STUBBIN:$PATH" HOME="$FAKEHOME" FH_STUB_MODE=stdin FH_STUB_STDIN_LOG="$SLOG"    bash "$SUT" --arm a --reps 1 --prompt p --out "$OUTDIR" < "$WORKROOT/bait.tsv" ) >/dev/null 2>&1
# 🟥 컨트롤 먼저 — 스텁이 실제로 돌았나. 안 돌았으면 「미끼 0」은 통과가 아니라 계기 사망이다
#    ([[feedback_absence_measurement_needs_control]] · 부재를 0 으로 렌더하지 않는다).
if [ ! -s "$OUTDIR/a_r1.txt" ]; then
  no "L13-CTRL 팔이 산출을 냈나 (미끼 0 이 계기 사망이 아님을 보증)"
else
  ok "L13-CTRL 팔이 산출을 냈다 ($(wc -c < "$OUTDIR/a_r1.txt" | tr -d ' ')B)"
fi
grep -qF "$BAIT" "$SLOG" 2>/dev/null \
  && no "L13 stdin 이 claude 까지 샜다 — 미끼가 프롬프트 채널에 도달했다" \
  || ok "L13 stdin 격리 — 미끼가 claude 에 도달하지 않는다"
# 🟥 known-positive: 같은 스텁·같은 미끼가 «막지 않으면» 실제로 잡히는가.
#    이게 없으면 위 레인은 「미끼가 원래 안 새는 것」과 구분되지 않는다
#    ([[feedback_control_presence_is_not_discrimination]]).
SLOG2="$WORKROOT/stdin13b.log"; : > "$SLOG2"
( cd "$SRC" && PATH="$STUBBIN:$PATH" FH_STUB_MODE=stdin FH_STUB_STDIN_LOG="$SLOG2" \
   claude -p p < "$WORKROOT/bait.tsv" ) >/dev/null 2>&1
grep -qF "$BAIT" "$SLOG2" 2>/dev/null \
  && ok "L13b known-positive — 차단 없이 부르면 미끼가 실제로 도달한다 (레인이 판별한다)" \
  || no "L13b known-positive 실패 — 스텁이 stdin 을 못 읽는다. L13 의 초록은 무의미하다"

# ── L24 🟥 «팔 눈가림» 자산이 클론에서 실제로 사라지나 ─────────────────────────────
#    얼린 정답지가 tracked 가 되면서 모든 팔의 클론에 들어갔다(실측: negative 명사구 히트 6~7).
#    deny 가 아니라 «제거»인 이유 — 없는 파일은 어떤 도구로도 못 읽는다.
if [ -x "$ROOT/scripts/round/arm_blind_probe.sh" ]; then
  bash "$ROOT/scripts/round/arm_blind_probe.sh" >/dev/null 2>&1 \
    && ok "L24 팔 눈가림 자산이 클론에서 제거된다 (히트 >0 → 0)" \
    || no "L24 눈가림 실패 — 팔이 정답지를 읽을 수 있다"
else no "L24 프로브 없음 — 검사 못 함(스킵 아님)"; fi

# ── L25 ⓒ 날짜 오염 통제 필드 (six_axis_review_2026-09-04 강화 #3) — 존재만 본다, 값은 안 본다.
#    이 러너가 판정을 안 낸다는 것이 헤더의 약속이라, 레인도 «필드가 있나»만 잰다.
OUTDIR="$WORKROOT/o25"
( cd "$SRC" && PATH="$STUBBIN:$PATH" HOME="$FAKEHOME" FH_STUB_MODE=say \
   bash "$SUT" --arm a --reps 1 --prompt p --out "$OUTDIR" ) >/dev/null 2>&1
META="$OUTDIR/a_r1.meta.tsv"
if [ -f "$META" ]; then
  grep -q '^corpus_head_date	' "$META" && ok "L25a corpus_head_date field recorded" \
    || no "L25a corpus_head_date field missing"
  grep -q '^sim_model	' "$META" && ok "L25b sim_model field recorded" \
    || no "L25b sim_model field missing"
  grep -q '^sim_model_cutoff	' "$META" && ok "L25c sim_model_cutoff field recorded" \
    || no "L25c sim_model_cutoff field missing"
else
  no "L25 meta.tsv not written at all ($META)"
fi

# ── L26 timeout(1) resolution (2026-09-05) — the launchd-PATH incident this exists for ──────────
#    WHY: launchd's PATH ($HOME/.local/bin:/usr/local/bin:/usr/bin:/bin, per this repo's own plist
#    templates prior to this patch) has neither `timeout` nor `gtimeout` on it — both live under
#    Homebrew's prefix. The first real launchd live-eval run (2026-09-05 02:30) hit exactly this:
#    every rep of every arm died at `timeout: command not found` and the run scored 12/12
#    FAILED-TO-RUN with no clue why. This lane shadows whichever CURRENT PATH dir(s) actually hold
#    `timeout`/`gtimeout` (symlinks to everything else in them) — computed, not hardcoded to
#    /opt/homebrew/bin, so the same lane works on Intel, Homebrew or a Linux /usr/bin — and proves
#    two things a prose comment cannot: the bash-native fallback
#    actually answers (not just "doesn't crash"), and it actually enforces the deadline rather than
#    silently never firing.
_shadow_timeout_dirs() {  # prints $PATH with every dir holding timeout/gtimeout replaced by a symlink shadow of it MINUS those two
  # 🟥 Measured 2026-09-05 on CI (ubuntu): `timeout` lives in /usr/bin next to bash and git, so
  # DROPPING that directory (the previous form of this fixture) also dropped bash/git, and the
  # potency check below scored the lane red on every Linux box while macOS (Homebrew prefix,
  # separate dir) stayed green. A shadow directory keeps every other name resolvable and removes
  # only the two — the same fixture on both layouts.
  local IFS=':' d out="" shadow n=0 f b
  for d in $PATH; do
    if [ -x "$d/timeout" ] || [ -x "$d/gtimeout" ]; then
      n=$((n+1)); shadow="$WORKROOT/notimeout_shadow_$n"; rm -rf "$shadow"; mkdir -p "$shadow"
      for f in "$d"/*; do
        [ -x "$f" ] && [ ! -d "$f" ] || continue
        b="${f##*/}"
        case "$b" in timeout|gtimeout) continue ;; esac
        ln -s "$f" "$shadow/$b"
      done
      d="$shadow"
    fi
    out="${out:+$out:}$d"
  done
  printf '%s' "$out"
}
NOTIMEOUT_PATH="$(_shadow_timeout_dirs)"

echo ""
echo "── L26 timeout(1) resolution ───────────────────────────────────────"

# Fixture-potency check FIRST — a stripped PATH that still resolves timeout/gtimeout proves
# nothing ([[feedback_fixture_must_use_the_breaking_spelling]]), and a strip that ALSO removed
# bash/git would confound every assertion below with an unrelated clone failure. Both are named
# distinctly rather than let a downstream lane fail for the wrong reason. Per this file's own
# convention (see L24's "검사 못 함(스킵 아님)"), an unusable fixture on this machine is scored
# as a failure, not silently skipped — it is loud precisely because CI does not gate this file
# (verified: no .github/workflows/*.yml references it), so a quiet skip would never be noticed.
if PATH="$NOTIMEOUT_PATH" command -v timeout >/dev/null 2>&1 || PATH="$NOTIMEOUT_PATH" command -v gtimeout >/dev/null 2>&1; then
  no "L26-FIXTURE stripped PATH still resolves timeout/gtimeout — cannot run L26 on this machine"
elif ! PATH="$NOTIMEOUT_PATH" command -v bash >/dev/null 2>&1 || ! PATH="$NOTIMEOUT_PATH" command -v git >/dev/null 2>&1; then
  no "L26-FIXTURE stripping timeout/gtimeout also removed bash or git — cannot run L26 on this machine"
else
  ok "L26-FIXTURE stripped PATH lacks timeout+gtimeout; bash/git still resolve"

  # L26a — no timeout/gtimeout at all: the runner must still answer (via the bash fallback) and
  # must NAME which control it used in its own header, rather than leaving that to be inferred.
  OUTDIR="$WORKROOT/o26a"
  OUT=$( cd "$SRC" && PATH="$STUBBIN:$NOTIMEOUT_PATH" HOME="$FAKEHOME" FH_STUB_MODE=say \
     bash "$SUT" --arm a --reps 1 --prompt p --out "$OUTDIR" 2>&1 )
  if printf '%s' "$OUT" | grep -q "timeout_tool=bash-fallback" && printf '%s' "$OUT" | grep -q "captured"; then
    ok "L26a no timeout/gtimeout on PATH -> bash-fallback answers and names itself in the header"
  else
    no "L26a bash-fallback did not fire/name itself: $(printf '%s' "$OUT" | grep -E 'timeout_tool|captured|UNMEASURED|EMPTY' | head -3 | tr '\n' ';')"
  fi

  # L26b — the fallback must actually ENFORCE the deadline, not just silently never fire. A stub
  # that would otherwise run 30s under --timeout 2 must come back UNMEASURED well under 30s.
  OUTDIR="$WORKROOT/o26b"
  _t0=$(date +%s)
  OUT=$( cd "$SRC" && PATH="$STUBBIN:$NOTIMEOUT_PATH" HOME="$FAKEHOME" FH_STUB_MODE=hang \
     bash "$SUT" --arm a --reps 1 --prompt p --timeout 2 --out "$OUTDIR" 2>&1 )
  _t1=$(date +%s); _elapsed=$(( _t1 - _t0 ))
  if printf '%s' "$OUT" | grep -q "UNMEASURED" && [ "$_elapsed" -le 10 ]; then
    ok "L26b bash-fallback enforces the deadline (UNMEASURED in ${_elapsed}s of a 30s hang, timeout=2s)"
  else
    no "L26b fallback did not enforce the timeout (elapsed=${_elapsed}s): $(printf '%s' "$OUT" | grep -E 'UNMEASURED|captured' | head -1)"
  fi

  # L26c control — SAME hang stub, DEFAULT (unstripped) PATH: real timeout/gtimeout must still be
  # preferred over the fallback (header says gnu/gtimeout, not bash-fallback), AND must enforce
  # the same deadline. Without this, L26a/L26b could be passing because the fallback is used
  # unconditionally, not because resolution correctly prefers the real tool when it is present
  # ([[feedback_control_presence_is_not_discrimination]]).
  OUTDIR="$WORKROOT/o26c"
  OUT=$( cd "$SRC" && PATH="$STUBBIN:$PATH" HOME="$FAKEHOME" FH_STUB_MODE=hang \
     bash "$SUT" --arm a --reps 1 --prompt p --timeout 2 --out "$OUTDIR" 2>&1 )
  case "$OUT" in
    *"timeout_tool=bash-fallback"*)
      no "L26c control — default PATH used bash-fallback instead of a real timeout/gtimeout" ;;
    *"timeout_tool=gnu"*|*"timeout_tool=gtimeout"*)
      printf '%s' "$OUT" | grep -q "UNMEASURED" \
        && ok "L26c control — default PATH prefers the real timeout tool and still enforces the deadline" \
        || no "L26c control — real timeout tool resolved but did not enforce the deadline"
      ;;
    *) no "L26c control — no timeout_tool= line in header at all: $(printf '%s' "$OUT" | grep timeout_tool)" ;;
  esac
fi

# ── L27 MCP isolation (2026-09-05) — the QP chamber floor sim saw the operator's user-scope MCP servers ─
#    in a headless arm's tool list. The runner must pass --strict-mcp-config ALWAYS (no --mcp-config ⇒
#    no servers), and pass through --mcp-config only when the caller names a file. Both directions.
OUTDIR="$WORKROOT/o27"; LOG="$WORKROOT/argv27.log"; : > "$LOG"
( cd "$SRC" && PATH="$STUBBIN:$PATH" HOME="$FAKEHOME" FH_STUB_MODE=say FH_STUB_ARGV_LOG="$LOG" \
   bash "$SUT" --arm a --reps 1 --prompt p --out "$OUTDIR" ) >/dev/null 2>&1
grep -q -- "--strict-mcp-config" "$LOG" \
  && ok "L27a default passes --strict-mcp-config (user-scope MCP cannot reach a blind arm)" \
  || no "L27a default did NOT pass --strict-mcp-config — operator MCP servers leak into headless arms"
grep -q -- "--mcp-config" "$LOG" \
  && no "L27b default passed --mcp-config without a file (would point at nothing)" \
  || ok "L27b default passes no --mcp-config (strict + none = no servers)"
OUTDIR="$WORKROOT/o27c"; LOG2="$WORKROOT/argv27c.log"; : > "$LOG2"; printf '{"mcpServers":{}}\n' > "$WORKROOT/mcp27.json"
( cd "$SRC" && PATH="$STUBBIN:$PATH" HOME="$FAKEHOME" FH_STUB_MODE=say FH_STUB_ARGV_LOG="$LOG2" \
   bash "$SUT" --arm a --reps 1 --prompt p --mcp-config "$WORKROOT/mcp27.json" --out "$OUTDIR" ) >/dev/null 2>&1
grep -q -- "--mcp-config $WORKROOT/mcp27.json" "$LOG2" && grep -q -- "--strict-mcp-config" "$LOG2" \
  && ok "L27c --mcp-config <file> reaches the CLI together with --strict-mcp-config (explicit allow, still strict)" \
  || no "L27c --mcp-config not plumbed (or strict dropped when a file is given)"

echo "── L28 multi-turn — --turns plumbing + --no-resume CONTROL ─────────"
# 🟥 These lanes measure the RUNNER'S WIRING (is --resume passed, is session_id parsed, are
#    turns counted), not whether a real session carries context. The live known-pair for THAT
#    is recorded in the marker: ARM answered the turn-1 fact at turn 2 with one session id;
#    --no-resume answered "you never told me" with two. A stub cannot establish that, and
#    pretending it does would be the muscle-not-skeleton defect.

printf 'turn one\n# a comment turn that must be skipped\n\nturn two\nturn three\n' > "$WORKROOT/t3.txt"

# ── usage guards (known-negative: a bad invocation must NOT proceed) ──
# 🟥 rc=2 ALONE IS NOT THE ASSERTION. Before --turns existed, an unknown flag ALSO exits 2 —
#    so a bare rc check is green for the wrong reason (lane-green reason ②: the input never
#    reached the code under test). Each guard therefore asserts the REASON in the message.
run_sut --arm a --reps 1 --turns "$WORKROOT/does_not_exist.txt" --out "$WORKROOT/o28a"
{ [ "$RC" -eq 2 ] && printf '%s' "$OUT" | grep -q -- "--turns file not found"; } \
  && ok "L28a missing --turns file → rc=2 AND the message names the file (not 'unknown flag')" \
  || no "L28a rc=$RC / message did not name a missing --turns file"

printf '# only a comment\n\n\n' > "$WORKROOT/t_empty.txt"
run_sut --arm a --reps 1 --turns "$WORKROOT/t_empty.txt" --out "$WORKROOT/o28b"
{ [ "$RC" -eq 2 ] && printf '%s' "$OUT" | grep -q "no turns"; } \
  && ok "L28b comment/blank-only turns file → rc=2 naming 'no turns' (a zero-turn run must not read as clean)" \
  || no "L28b rc=$RC / message did not name a zero-turn file — an empty conversation would score as a run"

run_sut --arm a --reps 1 --prompt p --turns "$WORKROOT/t3.txt" --out "$WORKROOT/o28c"
{ [ "$RC" -eq 2 ] && printf '%s' "$OUT" | grep -q "mutually exclusive"; } \
  && ok "L28c --prompt + --turns → rc=2 naming the conflict (which one ran must never be ambiguous)" \
  || no "L28c rc=$RC / message did not name the conflict"

# ── ARM: resume ON ──
OUTDIR="$WORKROOT/o28arm"; LOGA="$WORKROOT/argv28arm.log"; : > "$LOGA"; : > "$WORKROOT/sid_arm"
( cd "$SRC" && PATH="$STUBBIN:$PATH" HOME="$FAKEHOME" FH_STUB_MODE=turns \
   FH_STUB_ARGV_LOG="$LOGA" FH_STUB_SID_COUNTER="$WORKROOT/sid_arm" \
   bash "$SUT" --arm mt --reps 1 --turns "$WORKROOT/t3.txt" --out "$OUTDIR" ) >/dev/null 2>&1
TSV="$OUTDIR/mt_r1.turns.tsv"
NROW=$( [ -f "$TSV" ] && awk 'NR>1' "$TSV" | grep -c . || echo 0 )
[ "$NROW" -eq 3 ] && ok "L28d 5-line file → 3 turns (blank + # skipped)" \
                  || no "L28d turn count is $NROW, expected 3 — comment/blank skipping is off"
NSID=$( [ -f "$TSV" ] && awk 'NR>1{print $3}' "$TSV" | sort -u | grep -c . || echo 0 )
[ "$NSID" -eq 1 ] && ok "L28e ARM — all 3 turns share ONE session id (the conversation was carried)" \
                  || no "L28e ARM produced $NSID distinct session ids, expected 1"
NRES=$(grep -c -- "--resume" "$LOGA" || true)
[ "$NRES" -eq 2 ] && ok "L28f ARM — --resume reached the CLI on turns 2..N exactly (2 of 3)" \
                  || no "L28f ARM passed --resume $NRES times, expected 2"
NMARK=$(grep -c '^===== turn ' "$OUTDIR/mt_r1.txt" 2>/dev/null || true)
[ "$NMARK" -eq 3 ] && ok "L28g concatenated transcript carries all 3 turns (existing scorers read this file)" \
                   || no "L28g transcript has $NMARK turn markers, expected 3"

# ── CTRL: --no-resume. 🟥 Without this arm L28e/L28f measure nothing ──
OUTDIR="$WORKROOT/o28ctrl"; LOGC="$WORKROOT/argv28ctrl.log"; : > "$LOGC"; : > "$WORKROOT/sid_ctrl"
( cd "$SRC" && PATH="$STUBBIN:$PATH" HOME="$FAKEHOME" FH_STUB_MODE=turns \
   FH_STUB_ARGV_LOG="$LOGC" FH_STUB_SID_COUNTER="$WORKROOT/sid_ctrl" \
   bash "$SUT" --arm mt --reps 1 --no-resume --turns "$WORKROOT/t3.txt" --out "$OUTDIR" ) >/dev/null 2>&1
TSVC="$OUTDIR/mt_r1.turns.tsv"
NSIDC=$( [ -f "$TSVC" ] && awk 'NR>1{print $3}' "$TSVC" | sort -u | grep -c . || echo 0 )
[ "$NSIDC" -eq 3 ] && ok "L28h CTRL — 3 turns, 3 DISTINCT session ids (cold sessions, as designed)" \
                   || no "L28h CTRL produced $NSIDC distinct session ids, expected 3 — the control is dead"
NRESC=$(grep -c -- "--resume" "$LOGC" || true)
[ "$NRESC" -eq 0 ] && ok "L28i CTRL — --resume never reached the CLI" \
                   || no "L28i CTRL passed --resume $NRESC times, expected 0"

# ── L28j 기존 단발 경로 무변경 (회귀) ──
OUTDIR="$WORKROOT/o28j"; LOGJ="$WORKROOT/argv28j.log"; : > "$LOGJ"
( cd "$SRC" && PATH="$STUBBIN:$PATH" HOME="$FAKEHOME" FH_STUB_MODE=say FH_STUB_ARGV_LOG="$LOGJ" \
   bash "$SUT" --arm a --reps 1 --prompt p --out "$OUTDIR" ) >/dev/null 2>&1
{ ! grep -q -- "--resume" "$LOGJ"; } && { ! grep -q -- "--output-format" "$LOGJ"; } \
  && [ -s "$OUTDIR/a_r1.txt" ] && [ ! -f "$OUTDIR/a_r1.turns.tsv" ] \
  && ok "L28j single-shot path untouched — no --resume, no --output-format, no turns.tsv" \
  || no "L28j single-shot path changed — --turns leaked into the path every existing probe runs on"

# ── 🟥 L28k/l/m — known-NEGATIVES. cross-family (codex) named these: without them the suite
#    reported "44 passed, 0 failed" over three S/A-tier folds. A lane set that only walks the
#    happy path measures that the happy path works, which nobody doubted.
mt_run() {  # $1=stub mode  $2=outdir tag ; sets RC and OUTDIR
  OUTDIR="$WORKROOT/$2"; : > "$WORKROOT/sid_$2"
  ( cd "$SRC" && PATH="$STUBBIN:$PATH" HOME="$FAKEHOME" FH_STUB_MODE="$1" \
     FH_STUB_SID_COUNTER="$WORKROOT/sid_$2" \
     bash "$SUT" --arm mt --reps 1 --turns "$WORKROOT/t3.txt" --out "$OUTDIR" ) >"$WORKROOT/o_$2.log" 2>&1
  RC=$?
}

mt_run turns_badjson b28k
# 🟥 The assertion is CONTAMINATED, not rc — this script ends in a deliberate `exit 0`.
{ grep -q "RESULT: CONTAMINATED" "$WORKROOT/o_b28k.log" \
  && grep -q "PARSE_FAILED" "$OUTDIR/mt_r1.turns.tsv" 2>/dev/null; } \
  && ok "L28k unparseable turn output → CONTAMINATED AND note=PARSE_FAILED (not folded into 'said nothing')" \
  || no "L28k not CONTAMINATED / PARSE_FAILED not recorded — a dead parser reads as an empty answer"

mt_run turns_die2 b28l
{ grep -q "RESULT: CONTAMINATED" "$WORKROOT/o_b28l.log" \
  && grep -q "MULTI-TURN INCOMPLETE — first failing turn: 2" "$WORKROOT/o_b28l.log"; } \
  && ok "L28l turn 2 dies, turn 3 succeeds → CONTAMINATED and names turn 2 (not last-turn rc only)" \
  || no "L28l a conversation that broke mid-way still scored as clean"

mt_run turns_nosid b28m
{ grep -q "RESULT: CONTAMINATED" "$WORKROOT/o_b28m.log" \
  && grep -q "did not demonstrably run" "$WORKROOT/o_b28m.log"; } \
  && ok "L28m no session_id on a resume turn → CONTAMINATED (the evidence IS the claim)" \
  || no "L28m a turn that cannot be shown to share the session passed silently"

# 🟥 CONTROL for the three above: the SAME harness on a healthy stub must pass. Without this,
#    an rc!=0 caused by something unrelated would read as three successful known-negatives.
mt_run turns b28n
grep -q "RESULT: CLEAN" "$WORKROOT/o_b28n.log" \
  && ok "L28n CONTROL — healthy multi-turn run is CLEAN (k/l/m are not firing on everything)" \
  || no "L28n CONTROL was not CLEAN — L28k/l/m prove nothing"

echo "sim_isolated_run lanes: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
