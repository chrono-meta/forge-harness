#!/usr/bin/env bash
# test_memory_gc_report_lanes.sh — known-pair lanes for scripts/memory_gc_report.py
# Every lane asserts an EXACT value or an exact collection (codex R1 2026-10-15: prefix / presence
# checks stayed green under 4 mutants). Fixtures carry their own negative next to each positive.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY="${PYTHON:-python3}"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
eq(){ if [ "$2" = "$3" ]; then echo "PASS $1"; pass=$((pass+1)); else echo "FAIL $1 — got [$2] want [$3]"; fail=$((fail+1)); fi; }

M="$T/m"; mkdir -p "$M"
w(){ printf '%s\n' "$2" > "$M/$1"; }
hdr='---
name: x
description: fixture
metadata:'
w user_z.md "$hdr
  type: user
---
body"
w user_a.md "$hdr
  type: user
  hits:
    - 2026-01-01 | old founding, user entries never go cold
---
body"
w fb_promote.md "$hdr
  type: feedback
  hits:
    - 2026-10-01 | first

    # a comment inside the list must not end it
    - 2026-10-01 | same day again
    - 2026-10-05 | other day
---
body — fixed in 4cab596 (an evidence anchor, so this one may be promoted)"
w fb_two_two.md "$hdr
  type: feedback
  hits:
    - 2026-10-03 | a
    - 2026-10-04 | b
---
body"
w fb_sameday.md "$hdr
  type: feedback
  hits:
    - 2026-10-02 | a
    - 2026-10-02 | b
    - 2026-10-02 | c
---
body"
w fb_cold.md "$hdr
  type: feedback
  hits:
    - 2026-09-15 | exactly 30 days before today
---
body"
w fb_fresh.md "$hdr
  type: feedback
  hits:
    - 2026-09-16 | 29 days, not cold yet
---
body"
w fb_unmeasured.md "$hdr
  type: feedback
---
body"
w fb_unlisted.md "$hdr
  type: feedback
---
body"
w fb_baddate.md "$hdr
  type: feedback
  hits:
    - 2026-99-99 | impossible
    - 2026-99-98 | impossible
    - 2026-99-97 | impossible
---
body"
w fb_future.md "$hdr
  type: feedback
  hits:
    - 2027-01-01 | future
---
body"
w fb_inline.md "$hdr
  type: feedback
  hits: [bad]
---
body"
w fb_foreign.md "---
name: x
other:
  hits:
    - 2026-10-01 | not under metadata
metadata:
  type: feedback
---
body"
w fb_unterm.md "---
name: x
metadata:
  type: feedback
  hits:
    - 2026-10-01 | never closed"
mkdir "$M/fb_dir.md"
w MEMORY.md "# Memory Index
- [Z](user_z.md) — user listed first
- [A](user_a.md) — user listed second
- [S](fb_sameday.md \"titled\") — titled link
- [P](./fb_promote.md) — dot-slash link
- [T](fb_two_two.md#part) — fragment link
- [C](fb_cold.md)
- [F](fb_fresh.md)
- [N](fb_unmeasured.md)
- [B](fb_baddate.md)
- [U](fb_future.md)
- [I](fb_inline.md)
- [O](fb_foreign.md)
- [X](fb_unterm.md)
- [web](https://example.com/page.md) — external, not a local file
- [P again](fb_promote.md) — duplicate
- [gone](fb_missing.md#sec) — dangling with fragment"

J="$(python3 "$HERE/memory_gc_report.py" "$M" --today 2026-10-15 --json)"; rc=$?
q(){ printf '%s' "$J" | "$PY" -c "import json,sys;d=json.load(sys.stdin);E={e['file']:e for e in d['entries']};print($1)"; }

eq "L0 report runs" "$rc" 0
eq "L1 promote = exactly age≥3 over ≥2 days (2-hit/2-day and same-day x3 excluded)" "$(q "d['promote']")" "[['fb_promote.md', 3, 2]]"
eq "L2 blank line + comment inside hits do not truncate the list" "$(q "E['fb_promote.md']['age']")" 3
eq "L3 cold = non-user age 1 at ≥30 days (29 days and old user entry stay)" "$(q "d['cold']")" "['fb_cold.md']"
eq "L4 no hits = UNMEASURED (age None), not age 1" "$(q "E['fb_unmeasured.md']['age']")" None
eq "L5 hits outside metadata are ignored" "$(q "E['fb_foreign.md']['age']")" None
eq "L6 impossible dates never measure or promote" "$(q "(E['fb_baddate.md']['age'], E['fb_baddate.md']['status'], len(E['fb_baddate.md']['bad']))")" "(None, 'HITS_MALFORMED', 3)"
eq "L7 future date rejected" "$(q "(E['fb_future.md']['age'], E['fb_future.md']['status'])")" "(None, 'HITS_MALFORMED')"
eq "L8 inline hits flagged" "$(q "E['fb_inline.md']['status']")" HITS_MALFORMED
eq "L9 unterminated frontmatter flagged" "$(q "E['fb_unterm.md']['status']")" UNTERMINATED_FRONTMATTER
eq "L10 unreadable topic flagged, not folded into no-hits" "$(q "E['fb_dir.md']['status']")" READ_ERROR
eq "L11 errors list is exact" "$(q "sorted(x[0] for x in d['errors'])")" "['fb_baddate.md', 'fb_dir.md', 'fb_future.md', 'fb_inline.md', 'fb_unterm.md']"
eq "L12 ./ , titled and #fragment links resolve; only the real orphan is unlisted" "$(q "sorted(d['unlisted'])")" "['fb_dir.md', 'fb_unlisted.md']"
eq "L13 duplicate reported with both line numbers" "$(q "d['duplicates']")" "[['fb_promote.md', 5, 16]]"
eq "L14 dangling local link (fragment stripped); external https ignored" "$(q "d['dangling']")" "[['fb_missing.md', 17]]"
eq "L15 full order: users in index order, measured by age (ties index order), rest in index order, cold out" \
  "$(q "d['order']")" \
  "['user_z.md', 'user_a.md', 'fb_sameday.md', 'fb_promote.md', 'fb_two_two.md', 'fb_fresh.md', 'fb_unmeasured.md', 'fb_baddate.md', 'fb_future.md', 'fb_inline.md', 'fb_foreign.md', 'fb_unterm.md']"
eq "L16 every topic file has an entry" "$(q "len(d['entries'])")" 15

# cap boundary: an index that fits exactly is within cap; one char over names the line and the loaded prefix
C="$T/c"; mkdir -p "$C"; printf '[a](a.md)' > "$C/MEMORY.md"; printf -- '---\nmetadata:\n  type: feedback\n---\n' > "$C/a.md"
eq "L17 exact-fit index is within cap" "$(python3 "$HERE/memory_gc_report.py" "$C" --cap 9 --json | "$PY" -c "import json,sys;print(json.load(sys.stdin)['cut'])")" None
printf 'line one\n[a](a.md)\n' > "$C/MEMORY.md"
eq "L18 cut names line 2 with 3 chars loaded" "$(python3 "$HERE/memory_gc_report.py" "$C" --cap 12 --json | "$PY" -c "import json,sys;c=json.load(sys.stdin)['cut'];print(c['line'],c['chars_loaded_in_line'])")" "2 3"

python3 "$HERE/memory_gc_report.py" "$T/nope" >/dev/null 2>&1; eq "L19 missing dir = HARNESS-ERROR rc=2, not an empty report" "$?" 2
before="$(cd "$M" && find . -type f -exec cksum {} + | sort)"; python3 "$HERE/memory_gc_report.py" "$M" >/dev/null 2>&1; after="$(cd "$M" && find . -type f -exec cksum {} + | sort)"
eq "L20 read-only: fixture bytes unchanged" "$before" "$after"

# R2 fixtures (codex R2): mixed validity never drives lifecycle · indentless list flagged ·
# <...> / %20 / balanced-paren destinations · past_cap by the link's own offset
R="$T/r"; mkdir -p "$R"
rw(){ printf '%s\n' "$2" > "$R/$1"; }
rw mix_cold.md "$hdr
  type: feedback
  hits:
    - 2026-08-01 | valid old
    - 2027-01-01 | future
---"
rw mix_prom.md "$hdr
  type: feedback
  hits:
    - 2026-10-01 | a
    - 2026-10-02 | b
    - 2026-10-03 | c
    - nonsense line
---"
rw flat.md "$hdr
  type: feedback
  hits:
  - 2026-10-01 | indentless
---"
rw "my note.md" "$hdr
  type: feedback
---"
rw "sp name.md" "$hdr
  type: feedback
---"
rw "note(v2).md" "$hdr
  type: feedback
---"
rw MEMORY.md "- [m](mix_cold.md) [p](mix_prom.md) [f](flat.md)
- [a](<my note.md>) [b](sp%20name.md) [c](note(v2).md) [x](<gone note.md>) [y](gone(v2).md)"
JR="$(python3 "$HERE/memory_gc_report.py" "$R" --today 2026-10-15 --json)"
qr(){ printf '%s' "$JR" | "$PY" -c "import json,sys;d=json.load(sys.stdin);E={e['file']:e for e in d['entries']};print($1)"; }
eq "L21 valid-old + future hit: flagged, not cold" "$(qr "(E['mix_cold.md']['status'], d['cold'])")" "('HITS_MALFORMED', [])"
eq "L22 three valid + one malformed: no promotion" "$(qr "d['promote']")" "[]"
eq "L23 indentless hits item flagged, not silently dropped" "$(qr "(E['flat.md']['status'], E['flat.md']['age'])")" "('HITS_MALFORMED', None)"
eq "L24 <...>, %20 and balanced-paren destinations resolve" "$(qr "sorted(d['unlisted'])")" "[]"
eq "L25 their missing twins are dangling" "$(qr "sorted(x[0] for x in d['dangling'])")" "['gone note.md', 'gone(v2).md']"
JP="$(python3 "$HERE/memory_gc_report.py" "$R" --today 2026-10-15 --cap 22 --json)"
eq "L26 past_cap follows the link's own offset on a shared line" \
  "$(printf '%s' "$JP" | "$PY" -c "import json,sys;E={e['file']:e for e in json.load(sys.stdin)['entries']};print(E['mix_cold.md']['past_cap'],E['mix_prom.md']['past_cap'])")" "False True"

# R3 (codex): two links on ONE line keep their link order, not filename order
Q="$T/q"; mkdir -p "$Q"; for f in z a; do printf -- '---\nmetadata:\n  type: user\n---\n' > "$Q/$f.md"; done
printf -- '- [z](z.md) [a](a.md)\n' > "$Q/MEMORY.md"
eq "L27 same-line links keep link order" "$(python3 "$HERE/memory_gc_report.py" "$Q" --json | "$PY" -c "import json,sys;print(json.load(sys.stdin)['order'])")" "['z.md', 'a.md']"


# 🟥 residual edges NOT chased (round cap 2, static matcher does not converge): '#123456 ' CSS colours without ';' · repo#N inside
#    URLs counted twice (presence only, harmless) · sha-looking words in prose with mixed letters/digits (e.g. 'b2c3d4e') count.
# ── evidence anchors (harness2: a lesson is stored/promoted only with a cited contrast) — own fixture dir ──
M2="$T/m2"; mkdir -p "$M2"
w2(){ printf '%s\n' "$2" > "$M2/$1"; }
w2 fb_anchored.md "$hdr
  type: feedback
  hits:
    - 2026-10-01 | a
    - 2026-10-02 | b
    - 2026-10-03 | c
---
fixed in 4cab596 — measured with scripts/test_x.sh"
w2 fb_held.md "$hdr
  type: feedback
  hits:
    - 2026-10-01 | a
    - 2026-10-02 | b
    - 2026-10-03 | c
---
happened on 2026-10-03, three times (a date is not an evidence anchor)"
pos(){ w2 "$1" "$hdr
  type: project
---
$2"; }
pos a_sha.md "fixed in 4cab596"
pos a_sha_ctx.md "landed as commit 1234567"
pos a_pr.md "see #1"
pos a_repo_pr.md "see chrono-meta/forge-harness#938"
pos a_path.md "the bug was in src/main.rs"
pos a_upper.md "documented in README.MD"
pos a_docker.md "the Dockerfile pins it"
pos a_arxiv.md "per arXiv:2610.29609"
pos a_url.md "see https://example.org/x"
w2 a_hitline.md "$hdr
  type: feedback
  hits:
    - 2026-10-01 | fixed in 4cab596
---
the rule, stated without citing anything"
pos n_noise.md "color #fff, version 3.29, the word deadbeef, abcdefg, C# and &#39; are not anchors"
pos n_css.md "color: #123456;"
pos n_uuid.md "request 3f2a9c1e-8b7d-4e21-9a3b-0c5d6e7f8a9b failed"
pos n_slug.md "see [intro](#2-intro)"
pos n_wiki.md "see [[feedback_x]] for the relation"
pos n_wiki_ext.md "see [[feedback_x.md]] for the relation"
pos n_frag.md "see [step](#2)"
pos n_uuid_ctx.md "commit 1234567-dead-beef-1234-123456789abc"
pos a_arxiv_old.md "per arXiv:hep-th/9901001"
pos n_date.md "happened on 2026-10-03, three times"
w2 n_fm.md "---
name: x
description: |
  quoted
  ---
  see https://example.org/frontmatter
metadata:
  type: project
---
plain body"
w2 MEMORY.md "# Memory Index
- [A](fb_anchored.md)
- [H](fb_held.md)
- [U](user_plain.md)
- [a1](a_sha.md)
- [a2](a_sha_ctx.md)
- [a3](a_pr.md)
- [a4](a_repo_pr.md)
- [a5](a_path.md)
- [a6](a_upper.md)
- [a7](a_docker.md)
- [a8](a_arxiv.md)
- [a9](a_url.md)
- [a10](a_hitline.md)
- [n1](n_noise.md)
- [n2](n_css.md)
- [n3](n_uuid.md)
- [n4](n_slug.md)
- [n5](n_wiki.md)
- [n6](n_date.md)
- [n7](n_fm.md)
- [n8](n_wiki_ext.md)
- [n9](n_frag.md)
- [n10](n_uuid_ctx.md)
- [a11](a_arxiv_old.md)"
q2(){ "$PY" "$HERE/memory_gc_report.py" "$M2" --today 2026-10-15 --json | "$PY" -c "import json,sys; d=json.load(sys.stdin); print($1)"; }
eq "L30 promote needs an evidence anchor; a recurring entry citing only dates is held, not promoted" "$(q2 "(d['promote'], d['promote_held'])")" "([['fb_anchored.md', 3, 3]], [['fb_held.md', 3, 3]])"
eq "L31 each anchor class counts on its own (sha · named sha · #N · owner/repo#N · path · upper-case ext · Dockerfile · arXiv · URL · hit line); every non-anchor stays unanchored (#fff · CSS · UUID · #slug · [[wiki]] · date · frontmatter URL)" "$(q2 "sorted(d['unanchored'])")" "['fb_held.md', 'n_css.md', 'n_date.md', 'n_fm.md', 'n_frag.md', 'n_noise.md', 'n_slug.md', 'n_uuid.md', 'n_uuid_ctx.md', 'n_wiki.md', 'n_wiki_ext.md']"
eq "L32 user entries are never listed as unanchored (and the list is not empty, so this is not vacuous)" "$(q2 "('user_plain.md' in d['unanchored'], len(d['unanchored']) > 0)")" "(False, True)"
echo "memory_gc_report lanes: $pass pass · $fail fail"
[ $fail -eq 0 ]
