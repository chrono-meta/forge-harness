# Pull request — tidewatch

**Title:** feat(tail): merged interleaved view across multiple files

## What this does

Lets tidewatch open several files at once and render them as one time-ordered stream, with
a per-source color gutter and a key to isolate a single source. This is the merged view from
the roadmap.

## How

This is not a small change. The current renderer assumes one source and one cursor, so the
render loop and the scrollback ring were both reworked to carry a source id:

- 940 lines changed across src/render.rs, src/ring.rs and src/input.rs
- the scrollback ring is now a k-way merge over per-source rings, which needed a real
  ring-buffer implementation — I pulled in the slice-ring crate (one file, no transitive
  dependencies) rather than hand-rolling a fourth one
- 3 existing snapshot tests had to be regenerated because the gutter shifts every line by
  two columns when more than one file is open
- adds one new keybinding (i, previously unbound) to isolate a source

Single-file behavior is byte-identical: with one file there is no gutter, no shift, and the
merge degenerates to the old path. I verified that against the regenerated snapshots.

## Cost

Startup is 0.4ms slower with one file (18.7ms to 19.1ms, n=200). With eight files it is
23ms. Memory is one ring per source, so eight files is eight times the scrollback budget —
I capped the default at 4 sources and made it configurable.

## Tests

31 new tests: ordering under equal timestamps, source isolation, a file that stops growing,
a file that is truncated mid-tail, and the single-source degeneration path.

Happy to split this into two PRs (ring first, renderer second) if that reviews better.
