#!/usr/bin/env python3
"""session_checklist.py — request-checklist close-report instrument («영혼 다지기» — the close-side warranty).

Two subcommands:

  extract --transcript <jsonl> [--out <md>]
      Reads a Claude Code transcript JSONL and emits a checklist SKELETON in
      Markdown: one row per operator utterance, 상태 column EMPTY. Opens TWO
      channels — raw entries and compaction-summary "All user messages"
      sections — and prints how many of each it found (0 found still counts
      as OPENED, never as "not opened"). See fh_signal_2026-09-18 for the
      doctrine this mechanizes.

  check --file <md>
      Validates a FILLED checklist. FORM ONLY — this command never judges
      whether a status is TRUE, only whether the record is well-formed
      (closed-enum status; non-DONE/non-n/a rows carry 사유+제안; DONE rows
      carry 증거). Judging truth is left to the human reader, on purpose
      (§Mechanization Boundary: a channel check ages well, a truth check
      freezes today's judgment into tomorrow's ceiling).

rc contract (check):
  0   clean            — table found, every row well-formed
  1   violations        — table found, one or more rows malformed
  4   DEAD CONTROL      — a table with a 상태-column header was found but has
                          ZERO data rows ("nothing measured" must not read
                          as "clean")
  10  input error       — file missing, OR no markdown table whose header
                          contains 상태 was found

rc contract (extract): 0 on success, 2 if one or more JSONL lines could not be
parsed (the table is still written — an unparsable line may have been an
utterance, so the run is never reported clean), 10 if the transcript is missing.

What `check` does NOT do: it does not open evidence links, does not verify
a 증거 pointer actually closes the request, and does not second-guess
whether ✅ was the right call. Form only.

Form details (v2/v3, after cross-family rounds 1–2): every table with a 상태 column
is checked (a clean earlier table cannot mask a later one); tables inside code
fences or indented 4+ spaces (CommonMark code) are ignored; a row with fewer
cells than the header is a violation;
compact status spellings (`✅DONE`, `DONE ✅`) are accepted on purpose — the
enum is the SET of statuses, not a spacing rule; invisible spacing (zero-width
space, NBSP) around a status is stripped; `/`-combos are accepted only when
every part is in the enum; `n.a.` is NOT an alias of `n/a` (closed enum, loud
by design). The compaction heading is matched by an alias table (English and
Korean spellings), and a list item that opens with a quote but never closes
it is still one utterance.
"""
import argparse
import json
import os
import re
import sys

# ---------------------------------------------------------------------------
# Shared status enum (closed)
# ---------------------------------------------------------------------------

STATUS_ENUM = {
    "DONE": "\u2705",          # ✅
    "PARTIAL": "\U0001F7E1",   # 🟡
    "IN-PROGRESS": "\u23F3",   # ⏳
    "NOT-DONE": "\u274C",      # ❌
    "HELD": "\u23F8",          # ⏸
    "UNVERIFIED": "\U0001F50E",  # 🔎
}

WORD_VARIANTS = {
    "DONE": {"DONE"},
    "PARTIAL": {"PARTIAL"},
    "IN-PROGRESS": {"IN-PROGRESS", "IN PROGRESS", "INPROGRESS"},
    "NOT-DONE": {"NOT-DONE", "NOT DONE", "NOTDONE"},
    "HELD": {"HELD"},
    "UNVERIFIED": {"UNVERIFIED"},
}

EMPTY_PLACEHOLDERS = {"", "-", "\u2014", "tbd", "?"}  # '' '-' '—' 'tbd' '?'

VARIATION_SELECTOR_RE = re.compile("[\uFE0E\uFE0F]")


def strip_variation_selectors(s):
    return VARIATION_SELECTOR_RE.sub("", s)


def is_empty_cell(cell):
    v = (cell or "").strip()
    return v == "" or v.lower() in EMPTY_PLACEHOLDERS or v in EMPTY_PLACEHOLDERS


def classify_single(part):
    """Classify one '/'-separated piece of a status cell. Returns a key in
    STATUS_ENUM, 'N/A', or None (invalid)."""
    # v4 (codex round 3): zero-width / non-breaking spacing around the emoji is invisible to the reader —
    # strip it before classifying. `n.a.` / `N.A.` are NOT aliases: the enum is closed on purpose (loud).
    p = INVISIBLE_RE.sub("", (part or "")).strip()
    if not p:
        return None
    if p.lower() == "n/a":
        return "N/A"
    p_clean = strip_variation_selectors(p)
    for key, emoji in STATUS_ENUM.items():
        if p_clean == emoji:
            return key
        if p_clean.startswith(emoji):
            rest = p_clean[len(emoji):].strip()
            if rest == "" or rest.upper() in WORD_VARIANTS[key]:
                return key
        if p_clean.endswith(emoji):
            rest = p_clean[: -len(emoji)].strip()
            if rest.upper() in WORD_VARIANTS[key]:
                return key
    p_upper = p_clean.upper()
    for key, variants in WORD_VARIANTS.items():
        if p_upper in variants:
            return key
    return None  # ENUM-MEMBERSHIP-FALLTHROUGH


def classify_status(status_cell):
    """Returns a set of matched keys (e.g. {'DONE'}, {'HELD','DONE'},
    {'N/A'}), or None if the cell is empty/invalid."""
    s = (status_cell or "").strip()
    if s == "":
        return None
    if s.lower() == "n/a":
        return {"N/A"}
    if "/" in s:
        keys = set()
        for part in s.split("/"):
            k = classify_single(part)
            if k is None:
                return None
            keys.add(k)
        return keys if keys else None
    k = classify_single(s)
    if k is None:
        return None
    return {k}


# ---------------------------------------------------------------------------
# extract
# ---------------------------------------------------------------------------

EXCLUDE_PREFIXES = (
    "<system-reminder>",
    "[SYSTEM NOTIFICATION",
    "<local-command",
    "<command-name>",
    "Caveat: The messages below were generated by the user while running local commands",  # v6: the synthetic caveat only — a real utterance may start with «Caveat:»
)

COMPACTION_PREFIX = "This session is being continued from a previous conversation"

# v4 (codex round 3): the compaction heading is localized in Korean sessions — an alias table, not one spelling.
USER_MESSAGES_HEADING_RE = re.compile(r"user messages|user utterances|사용자 메시지|사용자 발화|유저 메시지", re.IGNORECASE)
# v6 (codex round 5): the heading must be a HEADING LINE (numbered / hashed / bold, ending in a colon) — the phrase
# «user messages» anywhere in an ordinary utterance is not a compaction summary
USER_MESSAGES_HEADING_LINE_RE = re.compile(r"^\s*(?:\d+[.)]\s*)?(?:#+\s*)?(?:\*\*|__)?\s*(?:all\s+)?(?:user messages|user utterances|모든 사용자 메시지|사용자 메시지|사용자 발화|유저 메시지)[^\"\u201c\n]{0,60}$", re.IGNORECASE)
TRUNCATION_RE = re.compile(r"(?:\u2026|\.\.\.)\s*$")
INVISIBLE_RE = re.compile("[​‌‍⁠﻿ ]")
# v8 (codex round 7): the section ends at the NEXT HEADING — a flush-left numbered line WITHOUT a quote
# (`7. Pending Tasks:` / `7) …`). A flush-left numbered item that carries a quote (`1. "…"`) is an item.
TOPLEVEL_NUMBERED_RE = re.compile(r"^\d+[.)]\s+(?!['\"\u201c])[^'\"\u201c\n]*$")
# v2 (codex round 1): a quoted span may cross a line break (summaries hard-wrap long quotes) and may
# contain escaped inner quotes (`\"quoted\"`); the v1 regex stopped at the first newline / inner quote,
# which silently dropped the utterance or split it in two. Items are joined first (bullet + its
# continuation lines), then quotes are pulled from each item.
QUOTE_RE = re.compile(r'"((?:[^"\\]|\\.){1,}?)"|\u201c((?:[^\u201d\\]|\\.){1,}?)\u201d', re.S)
ITEM_START_RE = re.compile(r"^\s*(?:[-*\u2022]\s+|\d+[.)]\s+)")
FENCE_RE = re.compile(r"^\s{0,3}(`{3,}|~{3,})")


def get_text_and_kind(entry):
    """Returns (text, has_text_block). has_text_block is False for a
    tool_result-only / non-text user entry."""
    msg = entry.get("message") or {}
    content = msg.get("content")
    if isinstance(content, str):
        return content, True
    if isinstance(content, list):
        texts = []
        has_text_block = False
        for b in content:
            if isinstance(b, dict) and b.get("type") == "text":
                has_text_block = True
                t = b.get("text")
                if t:
                    texts.append(t)
        if has_text_block:
            return "\n".join(texts), True
        return None, False
    return None, False


def is_excluded(text, entry):
    if entry.get("isMeta"):
        return True
    stripped = text.lstrip()
    for p in EXCLUDE_PREFIXES:
        if stripped.startswith(p):
            return True
    # v9 (codex round 8): exclusions are ENVELOPE-shaped, never substring matches — an operator utterance that
    # merely contains a marker literal (`<task-notification>` · `[Subagent hand-back]` · the peer-message sentence)
    # is a request. The real envelopes: a task notification STARTS with its tag (or with the SYSTEM NOTIFICATION
    # banner, handled above); a peer/subagent message STARTS with the sentence AND carries an `<agent-message` tag.
    if stripped.startswith("<task-notification>"):
        return True
    if stripped.startswith("Another Claude session sent a message:") and "<agent-message" in text:
        return True
    return False


def collapse(text):
    return re.sub(r"\s+", " ", (text or "")).strip()


def extract_quotes_from_summary(text):
    """Find the 'All user messages' section (bounded by the next top-level
    numbered heading, or end of text) and pull every quoted span out of it,
    in order. Returns a list of raw (uncollapsed) quote strings."""
    lines = text.split("\n")
    heading_idx = None
    for i, ln in enumerate(lines):
        if USER_MESSAGES_HEADING_LINE_RE.match(ln):
            heading_idx = i
            break
    if heading_idx is None:
        return []
    end_idx = len(lines)
    for j in range(heading_idx + 1, len(lines)):
        ln = lines[j]
        if TOPLEVEL_NUMBERED_RE.match(ln) and not ln[:1].isspace():
            end_idx = j
            break
    # join each list item with its continuation lines, then pull the quotes out of each item
    items = []
    for ln in lines[heading_idx + 1: end_idx]:
        if not ln.strip():
            continue
        if ITEM_START_RE.match(ln) or not items:
            items.append(ln.strip())
        else:
            items[-1] = items[-1] + " " + ln.strip()
    quotes = []
    for it in items:
        body = ITEM_START_RE.sub("", it, count=1).strip()
        # v2: an item that IS one quote (opens and closes with a quote char) is taken whole — an inner
        # unescaped quote (`"… the "quoted" word …"`) must not split it into two utterances
        if len(body) >= 3 and body[0] in '"“' and body[-1] in '"”':
            quotes.append(body[1:-1].replace('\\"', '"'))
            continue
        # v3 (codex round 2): an item that OPENS with a quote is one utterance — only its leading quote
        # counts; a quote inside a trailing annotation (`"…" (already "summarized")`) is not a message.
        # An item that does not open with a quote is a prose list of several quotes: take them all.
        matches = list(QUOTE_RE.finditer(it))
        if body[:1] in '"“':
            if not matches:
                # v4 (codex round 3): an item that opens with a quote whose closing quote is missing is still
                # one utterance — capture through the item boundary instead of dropping it silently
                quotes.append(body[1:].rstrip().replace('\\"', '"'))
                continue
            matches = matches[:1]
        for m in matches:
            q = m.group(1) if m.group(1) is not None else m.group(2)
            quotes.append(q.replace('\\"', '"'))
    return quotes


def normalize_utterance(text):
    """Collapse whitespace and drop a trailing ellipsis so a truncated summary quote and its raw
    original compare equal."""
    return collapse(text).rstrip("…. ").strip()


def is_duplicate(summary_text, raw_norms):
    """v2 (codex round 1): the v1 rule compared only the first 40 chars, so two DISTINCT requests
    sharing an opening phrase collapsed into one. Now: equal after normalisation, or one is a prefix
    of the other and the shorter side is at least 40 chars (a truncated quote of the same utterance)."""
    q = normalize_utterance(summary_text)
    if not q:
        return True
    q_trunc = bool(TRUNCATION_RE.search(collapse(summary_text)))
    for r in raw_norms:
        if q == r:
            return True
        # v6 (codex round 5): a prefix relation alone is not a duplicate — a distinct follow-up may share a long
        # opening. Only a quote that visibly ends in a truncation marker («…» / «...») is folded into the longer text.
        if q_trunc and len(q) >= 20 and r.startswith(q):
            return True
    return False


def format_ts(ts):
    if not ts:
        return "\u2014"  # —
    # "2026-09-17T05:56:11.019Z" -> "09-17 05:56"
    m = re.match(r"^\d{4}-(\d{2})-(\d{2})T(\d{2}):(\d{2})", ts)
    if not m:
        return "\u2014"
    mm, dd, hh, mi = m.groups()
    return "%s-%s %s:%s" % (mm, dd, hh, mi)


def md_escape(text):
    return (text or "").replace("|", "\\|")


def do_extract(transcript_path, out_path):
    if not os.path.isfile(transcript_path):
        sys.stderr.write("error: transcript not found: %s\n" % transcript_path)
        return 10

    raw_rows = []          # [{ts, text}]
    summary_texts = []      # raw compaction-entry text, in order
    line_count = 0
    parse_errors = 0

    with open(transcript_path, "r", encoding="utf-8", errors="replace") as f:
        for line in f:
            line_count += 1
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
            except Exception:
                parse_errors += 1
                continue
            if entry.get("type") != "user":
                continue
            text, has_text = get_text_and_kind(entry)
            if not has_text or text is None or text.strip() == "":
                continue
            text = text.lstrip("\ufeff")  # v5: a BOM before the compaction prefix hid the summary channel
            # v5 (codex round 4): the compaction prefix alone is not proof — an ordinary utterance can start with
            # it. A compaction entry also carries a «user messages» section; without one it is a raw utterance.
            if text.lstrip().startswith(COMPACTION_PREFIX) and any(USER_MESSAGES_HEADING_LINE_RE.match(l) for l in text.split("\n")) \
                    and extract_quotes_from_summary(text):
                # v7 (codex round 6): boilerplate + heading is still not proof — a user drafting a compaction
                # TEMPLATE has both and no quoted items. Only a section that yields ≥1 quote is a summary.
                summary_texts.append(text)
                continue
            if is_excluded(text, entry):
                continue
            raw_rows.append({"ts": entry.get("timestamp"), "text": text})

    raw_norms = [normalize_utterance(r["text"]) for r in raw_rows]

    summary_found_total = 0
    summary_rows = []  # [{text}]
    seen_summary = []   # summary-vs-summary duplicates (the same quote restated by a later summary)
    for stext in summary_texts:
        quotes = extract_quotes_from_summary(stext)
        summary_found_total += len(quotes)
        for q in quotes:
            if is_duplicate(q, raw_norms) or is_duplicate(q, seen_summary):
                continue
            seen_summary.append(normalize_utterance(q))
            summary_rows.append({"text": q})

    n_raw = len(raw_rows)
    n_summary_found = summary_found_total
    n_summary_added = len(summary_rows)
    rc = 2 if parse_errors else 0  # v5: an unparsable line may have been an utterance — loud, never rc=0

    lines_out = []
    title = "# 세션 요청 체크리스트 (스켈레톤) — %s" % os.path.basename(transcript_path)
    lines_out.append(title)
    lines_out.append("")
    lines_out.append(
        "\ucc44\ub110 2/2 \uc5f4\uc74c \u2014 raw %d\uac74 \u00b7 \uc555\ucd95 \uc694\uc57d %d\uac74(\uc911\ubcf5 \uc81c\uac70 \ud6c4 %d\uac74 \ucd94\uac00)"
        % (n_raw, n_summary_found, n_summary_added)
    )
    lines_out.append(chr(0x1F4CE) + " " + "원장 = %s (%d lines)" % (transcript_path, line_count))
    if parse_errors:
        lines_out.append("🟥 JSONL 파싱 실패 %d줄 — 그 줄의 발화는 이 표에 없다 (rc=2)" % parse_errors)
    lines_out.append("")
    lines_out.append(
        "| # | \uc2dc\uac01 | \ubc1c\ud654(\uc694\uc9c0) | \uc0c1\ud0dc | \uc99d\uac70 | \uc0ac\uc720 / \ub0a8\uc740 \uac83 | \uc81c\uc548(\uc774\ubc88 \uc138\uc158 vs \uc774\uc6d4) |"
    )
    lines_out.append("|---|---|---|---|---|---|---|")

    n = 0
    for r in raw_rows:
        n += 1
        blurb = collapse(r["text"])
        if len(blurb) > 160:
            blurb = blurb[:160] + "\u2026"
        lines_out.append(
            "| %d | %s | %s |  |  |  |  |" % (n, format_ts(r["ts"]), md_escape(blurb))
        )

    s = 0
    for r in summary_rows:
        s += 1
        blurb = collapse(r["text"])
        if len(blurb) > 160:
            blurb = blurb[:160] + "\u2026"
        lines_out.append(
            "| S%d | (요약) | %s |  |  |  |  |" % (s, md_escape(blurb))
        )

    content = "\n".join(lines_out) + "\n"
    sys.stdout.write(content)

    if out_path:
        with open(out_path, "w", encoding="utf-8") as f:
            f.write(content)

    return rc


# ---------------------------------------------------------------------------
# check
# ---------------------------------------------------------------------------

SPLIT_PIPE_RE = re.compile(r"(?<!\\)\|")


def split_row(line):
    r"""v5 (codex round 4): `\|` is a literal pipe inside a cell (the utterance column carries them), not a
    column boundary — a naive split shifted every later column and the checker read the wrong 상태 cell."""
    s = line.strip()
    if s.startswith("|"):
        s = s[1:]
    if s.endswith("|") and not s.endswith("\\|"):
        s = s[:-1]
    return [c.strip().replace("\\|", "|") for c in SPLIT_PIPE_RE.split(s)]


def is_separator_line(line):
    """v7 (codex round 6): the delimiter row may omit the outer pipes too (`---|---|---`)."""
    s = line.strip()
    if "|" not in s and "-" not in s:
        return False
    inner = s.strip("|")
    if inner == "":
        return False
    cells = SPLIT_PIPE_RE.split(inner)
    return len(cells) >= 2 and all(re.fullmatch(r"[\s:\-]*", c) for c in cells) and any("-" in c for c in cells)


def find_header_index(header_cells, needle):
    """v5 (codex round 4): an EXACT header cell wins; a contains-match is the fallback only when exactly one
    cell contains the needle (`이전 상태 메모` next to `상태` used to steal the status column)."""
    exact = [i for i, c in enumerate(header_cells) if c.strip() == needle]
    if len(exact) == 1:
        return exact[0]
    if len(exact) > 1:
        return -1  # ambiguous
    loose = [i for i, c in enumerate(header_cells) if needle in c]
    if len(loose) == 1:
        return loose[0]
    return -1 if len(loose) > 1 else None


def do_check(file_path):
    if not os.path.isfile(file_path):
        sys.stderr.write("error: file not found: %s\n" % file_path)
        print("checklist: rows=0 ok=0 violations=0 rc=10")
        return 10

    with open(file_path, "r", encoding="utf-8", errors="replace") as f:
        raw = f.read()
    if raw.startswith("\ufeff"):
        raw = raw[1:]
    lines = raw.splitlines()

    # v2 (codex round 1): lines inside a code fence are not a table — a fenced example table used to be
    # picked as THE checklist and mask the real one below it (rc=0 on a file with a bad row).
    in_fence = [False] * len(lines)
    fence_open = None  # (char, length) — v5 (codex round 4): a closer must be the same char and at least as long
    for i, ln in enumerate(lines):
        m = FENCE_RE.match(ln)
        if m:
            tick = m.group(1)
            if fence_open is None:
                fence_open = (tick[0], len(tick))
                in_fence[i] = True
                continue
            if tick[0] == fence_open[0] and len(tick) >= fence_open[1] and ln.strip() == tick:
                fence_open = None
                in_fence[i] = True
                continue
        in_fence[i] = fence_open is not None

    # v2: EVERY table with a 상태 column is checked, not only the first — a clean earlier table used to
    # mask a malformed later one.
    # v3 (codex round 2): a line indented by 4+ spaces (or a tab) is a CommonMark indented code block,
    # not a table row — an indented example used to be read as THE checklist (rc=0 with no real table).
    def is_code_indented(ln):
        return ln.startswith("    ") or ln.startswith("\t")

    header_idxs = []
    for i, ln in enumerate(lines):
        if in_fence[i] or is_code_indented(ln):
            continue
        s = ln.strip()
        # v7 (codex round 6): a header row may omit the outer pipes — a line with an unescaped `|` and 상태 qualifies
        if not SPLIT_PIPE_RE.search(s) or "상태" not in s or i + 1 >= len(lines):
            continue
        if is_code_indented(lines[i + 1]) or not is_separator_line(lines[i + 1]):
            continue  # v5: an indented delimiter row is code, so this is not a table
        header_idxs.append(i)

    if not header_idxs:
        sys.stderr.write("error: no markdown table with a 상태-column header found in %s\n" % file_path)
        print("checklist: rows=0 ok=0 violations=0 rc=10")
        return 10

    tables = []  # [(header_cells, rows)]
    for header_idx in header_idxs:
        header_cells = split_row(lines[header_idx])
        rows = []
        j = header_idx + 2
        # v6 (codex round 5): GFM rows may omit the outer pipes — a row is any non-blank, non-code line with an
        # unescaped `|` until the first blank / pipe-less line
        while j < len(lines) and lines[j].strip() != "" and SPLIT_PIPE_RE.search(lines[j]) and not in_fence[j] and not is_code_indented(lines[j]):
            rows.append(split_row(lines[j]))
            j += 1
        tables.append((header_cells, rows))

    if sum(len(r) for _, r in tables) == 0:
        print("checklist: rows=0 ok=0 violations=0 rc=4")
        return 4

    def cell(cells, idx):
        if idx is None or idx >= len(cells):
            return ""
        return cells[idx]

    violations = []
    ok_count = 0
    n_rows = 0

    for t_no, (header_cells, rows) in enumerate(tables, start=1):
        idx_status = find_header_index(header_cells, "상태")
        idx_evidence = find_header_index(header_cells, "증거")
        idx_reason = find_header_index(header_cells, "사유")
        idx_proposal = find_header_index(header_cells, "제안")
        # v5 (codex round 4): the canonical columns must all be present and unambiguous — a table with only
        # `#` and 상태 is not a checklist (its rows could never carry evidence / reason / proposal)
        missing = [n for n, ix in (("상태", idx_status), ("증거", idx_evidence), ("사유", idx_reason), ("제안", idx_proposal)) if ix is None]
        ambiguous = [n for n, ix in (("상태", idx_status), ("증거", idx_evidence), ("사유", idx_reason), ("제안", idx_proposal)) if ix == -1]
        if missing or ambiguous:
            sys.stderr.write("error: checklist schema — missing columns %s, ambiguous columns %s (table %d)\n" % (missing, ambiguous, t_no))
            print("checklist: rows=0 ok=0 violations=0 rc=10")
            return 10
        idx_num = None
        for i, c in enumerate(header_cells):
            if c.strip() == "#":
                idx_num = i
                break
        if idx_num is None:
            idx_num = 0
        tprefix = "" if len(tables) == 1 else "table %d " % t_no

        for pos, cells in enumerate(rows, start=1):
            n_rows += 1
            num_val = cell(cells, idx_num).strip()
            label = tprefix + (num_val if num_val else str(pos))

            # v2: a row shorter than the header is malformed — a truncated `| 1 | … | n/a |` used to pass
            if len(cells) < len(header_cells):
                violations.append("row %s short (%d cells < header %d)" % (label, len(cells), len(header_cells)))
                continue

            status_cell = cell(cells, idx_status)
            if status_cell.strip() == "":
                violations.append("row %s missing 상태" % label)
                continue
            keys = classify_status(status_cell)
            if keys is None:
                violations.append("row %s invalid 상태 (got '%s')" % (label, status_cell.strip()))
                continue

            is_na = keys == {"N/A"}
            contains_done = "DONE" in keys
            purely_done = keys == {"DONE"}
            row_ok = True

            if contains_done and is_empty_cell(cell(cells, idx_evidence)):
                violations.append("row %s DONE missing 증거" % label)
                row_ok = False

            if not is_na and not purely_done:
                if is_empty_cell(cell(cells, idx_reason)):
                    violations.append("row %s missing 사유" % label)
                    row_ok = False
                if is_empty_cell(cell(cells, idx_proposal)):
                    violations.append("row %s missing 제안" % label)
                    row_ok = False

            if row_ok:
                ok_count += 1

    for v in violations:
        print(v)

    rc = 1 if violations else 0
    extra = "" if len(tables) == 1 else " tables=%d" % len(tables)
    print("checklist: rows=%d ok=%d violations=%d rc=%d%s" % (n_rows, ok_count, len(violations), rc, extra))
    return rc


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

RC_CONTRACT_TEXT = """rc contract (check):
  rc=0   clean        - table found, every row well-formed
  rc=1   violations   - table found, one or more rows malformed
  rc=4   DEAD CONTROL - a table with a status(\uc0c1\ud0dc) header was found but has
                        ZERO data rows (nothing measured must not read as clean)
  rc=10  input error  - file missing, or no table with a \uc0c1\ud0dc column found

check never judges whether a status is TRUE -- form only.
"""


def build_parser():
    parser = argparse.ArgumentParser(
        prog="session_checklist.py",
        description="Request-checklist close-report instrument (extract / check).",
        epilog=RC_CONTRACT_TEXT,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    sub = parser.add_subparsers(dest="cmd")

    p_extract = sub.add_parser("extract", help="extract a checklist skeleton from a transcript JSONL")
    p_extract.add_argument("--transcript", required=True)
    p_extract.add_argument("--out", default=None)

    p_check = sub.add_parser(
        "check",
        help="validate a filled checklist",
        epilog=RC_CONTRACT_TEXT,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    p_check.add_argument("--file", required=True)

    return parser


def main(argv=None):
    parser = build_parser()
    args = parser.parse_args(argv)

    if args.cmd == "extract":
        return do_extract(args.transcript, args.out)
    if args.cmd == "check":
        return do_check(args.file)

    parser.print_help()
    return 10


if __name__ == "__main__":
    sys.exit(main())
