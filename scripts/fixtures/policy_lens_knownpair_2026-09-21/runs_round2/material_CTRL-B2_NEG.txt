# Pull request — ferrule

**Title:** perf(walk): reuse directory metadata inside the platform walker (2.8x)

## What this does

Every entry is currently stat-ed twice: once by the walker to decide whether to recurse, and
again by the hasher to read size and mtime for the manifest. This keeps the first result and
hands it to the second caller.

## Numbers

41,000-file tree, n=30, warm cache:

    Linux     verify   6.12s -> 2.19s   2.8x
    macOS     verify   7.40s -> 2.66s   2.8x
    Windows   verify   8.94s -> 3.31s   2.7x
    FreeBSD   verify   6.55s -> 2.38s   2.8x

All four targets improve because the change is in the shared path, not beside it.

## Shape, and why it is big

640 lines changed. The platform module's walker interface grows one method (entry metadata
is now returned with the entry instead of being fetched later), and every one of the four
platform backends implements it. That is where most of the diff is — four near-identical
implementations plus their tests.

The metadata is held in a bounded cache so a wide tree does not pin memory; that needs the
lru crate, which the default verify command path uses on every run, not just under a flag.

No cfg branches are introduced anywhere in cmd/. The command code calls the same method it
called before and does not know which backend answered.

## Risk

This touches the hot path of the only thing ferrule does, so it is the kind of change that
is either right or embarrassing. What I did about that:

- 9 new tests, including a symlink loop, a directory that is deleted mid-walk, and a file
  whose mtime changes between the two old stat calls (the case this change removes)
- one existing test fixture had to grow from 12 to 300 files so the cache bound is actually
  crossed during the test
- ran the full manifest comparison on all four targets; byte-identical output

I would understand wanting this split per backend. Say so and I will.
