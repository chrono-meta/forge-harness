#!/usr/bin/env python3
"""correction_moments.py — find the operator's correction moments in the utterance ledgers and group
the ones that recur on different days. Input for harvest-loop / memory: a correction that came back on
a second day is a rule the harness has not learned yet.

Borrowed from pstack automate-me (2026-11-03, tracks/_meta/research_2026-11-03_pstack_video.md) without
its cost: pstack sends every conversation slice to a subagent; this is a local regex + word-overlap pass
over the ledgers the UserPromptSubmit hook already writes (tracks/_meta/utterances/*.jsonl). Nothing
leaves the machine — the ledgers can hold in-house context, so do not hand the output to another model.

What it claims and what it does not:
  · a "correction moment" = an utterance matching CUE (Korean/English correction words). Cue-word
    recall is the instrument's limit: a correction phrased without any cue word is not seen.
  · "recurring" = two cue hits on different days that share >= --min-shared content words. Word
    overlap is a candidate filter, not a topic judgment — the reader decides whether a group is one rule.
  · every exclusion is counted and printed (malformed rows, short rows), never dropped silently.

usage: python3 scripts/correction_moments.py [ledger_dir] [--since YYYY-MM-DD] [--min-shared N] [--all]
exit:  0 = ran · 2 = ledger dir missing or holds no rows (NOT a "no corrections" result)
"""
import glob, json, os, re, sys

CUE = re.compile(
    r"(?:^|\s)아니(?=[\s,.]|$)|아니(?:야|라|지|고|잖)|아냐|틀렸|틀린|잘못|말고|정정|하지\s?마|쓰지\s?마|왜\s|다시\s?(?:해|봐|확인)|그게 아니|"
    r"\bno,|\bwrong\b|\bdon'?t\b|\bstop\b|\bnot what\b", re.I)
STOP = set("그리고 그런데 그러면 이거 이건 그거 그건 저거 지금 여기 거기 이제 근데 그냥 하는 하고 해서 했어 했는데 "
           "있어 있는 없어 없는 아니 아냐 아니야 아니라 말고 다시 정정 해줘 해봐 한번 모두 전부 같은 같아 "
           "this that with from have what when which there would could about into than then also only does your will".split())
MIN_CHARS = 6
MAX_CHARS = 600   # longer rows are almost always pasted reports or documents, not a correction in the operator's words


def words(t):
    ws = set(re.findall(r"[가-힣]{2,}|[A-Za-z][A-Za-z0-9_.\-]{2,}", t.lower()))
    return {w for w in ws if w not in STOP and not CUE.fullmatch(w)}


def cue_window(t):
    """The sentence holding the first cue word, plus its neighbours — long messages otherwise match on
    unrelated words elsewhere in the text."""
    parts = re.split(r"(?<=[.!?。])\s+|\n+", t)
    for k, p in enumerate(parts):
        if CUE.search(p):
            return " ".join(parts[max(0, k - 1):k + 2])
    return t


def main(argv):
    args = [a for a in argv if not a.startswith("--")]
    opt = dict(zip(argv[::1], argv[1::1]))
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    d = args[0] if args and not args[0][:4].isdigit() else os.path.join(root, "tracks", "_meta", "utterances")
    since = opt.get("--since", "")
    min_shared = int(opt.get("--min-shared", "2"))
    files = sorted(glob.glob(os.path.join(d, "*.jsonl")))
    rows, bad, short, envelope, long_ = [], 0, 0, 0, 0
    for f in files:
        sess = os.path.basename(f)[:8]
        for line in open(f, encoding="utf-8", errors="replace"):
            try:
                x = json.loads(line)
            except Exception:
                bad += 1; continue
            t, ts = x.get("text"), x.get("ts")
            if not isinstance(t, str) or not isinstance(ts, str):
                bad += 1; continue
            if ts[:10] < since:
                continue
            if t.lstrip().startswith("<"):
                # subagent hand-backs, peer messages, pasted blocks: the ledger keeps them, they are not the operator's words
                envelope += 1; continue
            if len(t.strip()) < MIN_CHARS:
                short += 1; continue
            if len(t) > MAX_CHARS:
                long_ += 1; continue
            rows.append((ts, sess, t))
    if not rows:
        print("⬜ no ledger rows under %s (files=%d) — NOT MEASURED, not «no corrections»" % (d, len(files)))
        return 2
    hits = [(ts, s, t, words(cue_window(t))) for ts, s, t in rows if CUE.search(t)]
    # PAIRS, not union-find: chaining long messages through one shared word each merged 29 hits into one
    # «group» on the first run (2026-11-03). A pair is two hits on different days whose cue sentences share
    # >= min_shared content words.
    recurring, repaste = [], 0
    for i in range(len(hits)):
        for j in range(i + 1, len(hits)):
            if hits[i][0][:10] != hits[j][0][:10]:
                sh = hits[i][3] & hits[j][3]
                union = hits[i][3] | hits[j][3]
                if len(sh) >= min_shared and union and len(sh) / len(union) < 0.8:
                    recurring.append((i, j, sh))
                elif len(sh) >= min_shared:
                    repaste += 1   # the same text pasted on two days is not a correction coming back
    recurring.sort(key=lambda p: -len(p[2]))
    days = sorted({r[0][:10] for r in rows})
    print("# correction moments — %s .. %s (%d days)" % (days[0], days[-1], len(days)))
    print("ledgers=%d · utterances=%d · excluded: envelope=%d short(<%d chars)=%d long(>%d chars)=%d malformed=%d · cue hits=%d · "
          "recurring pairs (different days, >=%d shared words)=%d · re-pasted pairs dropped=%d" % (len(files), len(rows), envelope, MIN_CHARS, short, MAX_CHARS, long_, bad,
                                                                len(hits), min_shared, len(recurring), repaste))
    print("limits: cue-word recall only (a correction with no cue word is invisible — e.g. «영어로 써졌네», 2026-10-18) · word overlap is a candidate filter\n")
    for k, (i, j, sh) in enumerate(recurring, 1):
        print("## R%d — shared: %s" % (k, " ".join(sorted(sh)[:8])))
        for x in (i, j):
            print("- %s %s · %s" % (hits[x][0][:16], hits[x][1], cue_window(hits[x][2]).replace("\n", " ")[:160]))
        print()
    if "--all" in argv:
        print("## hits not in a pair")
        grouped = {x for p in recurring for x in p[:2]}
        for i, h in enumerate(hits):
            if i not in grouped:
                print("- %s %s · %s" % (h[0][:16], h[1], h[2].replace("\n", " ")[:160]))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
