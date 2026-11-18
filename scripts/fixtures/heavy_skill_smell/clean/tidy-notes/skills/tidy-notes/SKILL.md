---
name: tidy-notes
description: Writes release notes from a git range — «write the release notes for v2.4», «does every bullet in these notes cite a real PR?», «how many bullets have no PR number?»
---

# Release notes from a git range

1. Read `git log <prev-tag>..HEAD --oneline` and group commits by type: Features, Fixes, Breaking changes.
2. Every bullet cites its PR number as `(#123)`. A bullet without a PR number is moved to «Other».
3. A commit whose body says `BREAKING CHANGE:` goes under Breaking changes even when its type is `fix`.
4. Run `python3 <this cartridge>/scripts/check_refs.py notes.md log.txt`. rc 0 = every cited PR is in the log,
   rc 1 = it prints each `MISSING #N` (fix the bullet and run it again), rc 2 = the check did not run: say the notes are
   not checked.
5. Only when step 4 exited 0, end with one hand-off line and stop:
   `ready: git tag <tag> && git push origin <tag> && gh release create <tag> --notes-file notes.md`
   This cartridge does not run those commands or ask about them; every other check stays in place.
