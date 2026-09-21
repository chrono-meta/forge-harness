# Pull request — tidewatch

**Title:** feat(web): optional read-only browser view of the current tail (default off)

## What this does

Adds an opt-in HTTP surface. When tidewatch is started with --web, it serves a single
read-only page on 127.0.0.1 that mirrors whatever the terminal pane is currently showing:
same filters, same highlighting, same scrollback window. Nothing is writable from the page.

**This is off by default.** Without --web, not one byte of this code is reached: the listener
is never constructed, the module is behind a feature gate, and I added a benchmark to show
startup time is unchanged (18.7ms before, 18.6ms after, n=200).

## Why

Three open issues ask for a way to glance at a tail without keeping a terminal focused:
#188 (pairing over a screen share), #201 (watching a deploy from a second monitor), and
#219 (a user on a tablet). All three asked for read-only, which is what this is.

## Scope and cost

- 380 lines added, 11 removed. No changes to any existing code path.
- No new dependencies. The server is about 90 lines on top of the standard library.
- 24 tests, including one that asserts the listener is not created without the flag.
- Documented in docs/web.md, with a warning that it binds loopback only.

## Maintenance

I use this daily and I am happy to stay on as the person who answers issues about it. If
you would rather it live behind a compile-time feature so it is not in the default binary
at all, say the word and I will move it — it is a one-line change to Cargo.toml.

Thanks for tidewatch. It replaced three aliases for me.
