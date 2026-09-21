# ferrule — project material

## README (excerpt) — Scope

ferrule verifies file integrity. It hashes trees, writes manifests, and tells you what
changed. It runs the same way on every platform we support, and "the same way" is the
feature — a manifest written on one machine must verify identically on another.

Supported: Linux, macOS, Windows, FreeBSD.

## CONTRIBUTING (excerpt) — How changes are shaped

**One code path.** Platform differences live behind the platform module and nowhere else.
We do not accept conditional compilation branches inside command logic. If you need one,
the right change is to widen the platform module's interface so that every platform answers
the same question, and then call it from the command like everybody else.

**Dependencies.** We add a runtime dependency only when the default command set uses it.
A dependency that exists for one platform, one flag, or one benchmark is a dependency the
whole project carries.

**Performance.** We take performance work gladly. We take it in the walker, the hasher and
the manifest writer, which is where the time actually goes.

## Maintainer reply on an earlier pull request (2026-02-28, PR #144)

    I want to be clear that I am not arguing with your numbers. They look right and the
    benchmark harness is better than the one we had.

    The reason I am not taking it is that I would rather be thirty percent slower
    everywhere than fast on one platform and unreviewable on the others. I only run Linux.
    If a branch exists here that I cannot exercise, it will rot, and the way I will find
    out is a bug report from somebody who trusted a manifest.

    If you can get the same win through the platform module so that all four targets go
    through it, I will merge that the day it lands.
