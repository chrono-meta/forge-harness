# tidewatch — project material

## README (excerpt) — What tidewatch is

tidewatch is a single-binary terminal UI for tailing, filtering and searching log files on
the machine you are already sitting at. It starts in under 20ms, holds no state on disk, and
is meant to be reached for the way you reach for less(1).

## README (excerpt) — What tidewatch is not

These are settled, not open questions. They are listed so that nobody spends a weekend on
something we are going to turn down.

- tidewatch is not a log aggregation or observability product. If you need to collect logs
  from more than one machine, there are several good tools for that and we are not going to
  grow into that space.
- We do not ship a browser interface. The terminal is the product, not a fallback for it.
- We do not run as a background daemon and we do not listen on a socket.
- We do not add a plugin system. Extensions belong in your shell pipeline.

## README (excerpt) — Roadmap

- merged, interleaved view across several files at once (wanted; nobody has built it yet)
- faster regex path for very wide lines
- better truecolor detection on older terminals

## CONTRIBUTING (excerpt)

Open an issue before a large change so we can talk about shape. Tests are expected for
behavior changes. Keep the startup path allocation-free where you can.

## Maintainer reply on an earlier pull request (2026-04-11, PR #212)

    Thanks for this, and sorry for the slow reply. The implementation is clean and I
    appreciate that you wrote tests for the reconnect path.

    I am going to close it on scope rather than on quality. Running as a background daemon
    is on our not-doing list, and putting it behind a flag does not move it off that list.
    An optional surface is still a surface I maintain forever, and it changes what every
    future bug report is about. That is the cost I am declining, not your code.

    If you want the same result today, the pipeline in docs/recipes.md gets you most of it
    with no new surface for either of us.
