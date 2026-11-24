# fh-guard

Install it, and every Bash call your Claude Code agent makes goes through the FH destructive-op gate
first. Works in any git repo. The repo does not need FH; you keep using whatever agent setup you already
have.

There are no skills, agents or characters. The plugin makes no network calls. Its only write is one line in the session's env file (below). It
ships two hooks: the gate, and a check at session start.

## Install

```
/plugin marketplace add chrono-meta/forge-harness
/plugin install fh-guard@forge-harness
```

**Turn on auto-update.** Third-party marketplaces do not auto-update by default, so a fix to the gate
does not reach you on its own. Turn it on under `/plugin` → Marketplaces → forge-harness, or run
`claude plugin update fh-guard@forge-harness` from time to time.

Requirements:
- Claude Code 2.1.295 or later (`onFailure` on hooks).
- `bash` and `python3`. On Windows you need Git for Windows (it provides Git Bash).

## What it does

The gate is a byte-for-byte copy of FH's `scripts/destructive_pre_gate.sh`. A lane in the FH repo
fails the moment the two differ.

**`bypassPermissions` and `auto` mode.** In these modes no human approves the call, so the gate
**blocks** these commands:
- `git push --force` and its other spellings
- remote branch and tag deletes (`--delete`, `-d`, `:ref`, `--mirror`, `--prune`)
- `git reset --hard`, `git clean -f`, `git checkout .`, `git stash drop` / `clear`, `git branch -D`
- `rm -rf` on `/`, `~` or `.`
- the agent switching the next layer off: `git push --no-verify`, writing `core.hooksPath`, or
  `DESTRUCTIVE_OP_OK=` set inside the command

In these modes an opt-out written into the command (`# noqa: destructive-op`) is ignored. That is on
purpose: the agent that writes the command must not be the one that grants the exception. The block
text tells the agent to stop and ask you. If you decide it should happen, you run the command from your
own terminal.

**Every other mode** (`default`, `acceptEdits`, `plan`, `dontAsk`). The gate only warns. In `default`
mode you still see Claude Code's own permission prompt before the call runs.

Set `FH_DESTRUCTIVE_BLOCK=1` in the shell you launch Claude from to block in every mode. Set
`FH_DESTRUCTIVE_BLOCK=0` to only warn, even in bypass and auto. The agent cannot change this from
inside a command: hooks read Claude Code's own environment, not the command's.

## When the gate is not really there

| State | What happens |
|---|---|
| The hook cannot start (no `bash`), times out (10 s), exits with a code other than 0 or 2, or prints broken output | **The Bash call is blocked** (`onFailure: block`). |
| `python3` is missing, or is a stub that does not run (the Windows Store `python3` alias) | The gate cannot read the call and lets it through. At session start you see one line: **"fh-guard is NOT active in this session"**. |

The python3 check runs once, at session start. If python3 stops working later in the same session (removed,
or a changed PATH), the gate goes quiet again and nothing says so until the next session. Checking python3 on
every Bash call would close that, but it would also block every Bash call on a machine without python3. That
is a different trade from the one above, so it is left open and named here.

🟥 **Windows without Git for Windows (no Git Bash): every Bash tool call is blocked.** Claude Code falls
back to PowerShell, which cannot run the `bash` command the hook uses, and `onFailure: block` turns that
into a block. This is a deliberate trade. A gate that is silently off looks exactly like a guarded
session. Install Git for Windows, or disable the plugin.

## What it does not stop

These are named on purpose, not overlooked:
- **Indirection.** A force push inside a script (`bash deploy.sh`), a Makefile target, or an alias. The
  gate reads the command string, not what it runs.
- **Non-git data leaks**, for example `curl --data-binary @.env`. This gate is not an outbound-content
  filter.
- **Deletes through the GitHub API** (`gh api -X DELETE …/git/refs/…`).
- **The agent editing settings** to disable the plugin for the next session.
- **Anything in `default` mode** beyond a warning. There you are the approver.

The hard floor for your remote is server-side branch protection: restrict force pushes and deletions
in your Git host's settings. No client-side hook replaces it.

Some of the gate's text is written for an FH checkout, not for your repo:
- The warning text points at `templates/predelete_check.sh`. That path exists in the FH repo, not in yours.
- The rows for `--no-verify`, `git -c core.hooksPath=…` / `GIT_CONFIG_*`, and `DESTRUCTIVE_OP_OK=` speak of
  «the pre-push layer». fh-guard ships no pre-push hook (a plugin cannot install one), so in your repo
  this hook is the only layer.

The copy is kept byte-identical to the FH gate, so the text changes only when the FH gate changes.

## If you also use FH itself

In an FH checkout whose `.claude/settings.json` already registers the same gate, the gate runs twice.
Claude Code runs a plugin's copy of a hook separately from settings hooks. The verdicts are the same,
so in block mode you see the same message twice. That is noise, not a gap.

## Turn it off

- `/plugin disable fh-guard@forge-harness`, or uninstall it. If you change this outside the `/plugin`
  panel, run `/reload-plugins` or start a new session.
- `disableAllHooks: true`, or a managed `allowManagedHooksOnly`, also turns it off. With either set,
  fh-guard is not running.

## Bash calls do not inherit the session's message channel

Claude Code puts two variables into a session's environment, `CLAUDE_CODE_MESSAGING_SOCKET` and
`CLAUDE_CODE_MESSAGING_TOKEN`. Without fh-guard, every Bash call and every child it starts (a script, a
`make` target) inherits both: a script the agent runs holds the channel the session uses to message
other sessions. At session start, fh-guard appends one line to the file Claude Code runs before each Bash
command (`$CLAUDE_ENV_FILE`):

```
unset CLAUDE_CODE_MESSAGING_SOCKET CLAUDE_CODE_MESSAGING_TOKEN
```

The session's own tools (sending a message to another session) are not Bash calls and keep working. A
`claude -p` started from Bash sets its own channel. Measured on macOS with bash, Claude Code 2.1.330: the names
seen by a Bash call and by a `make` child went from 2 to 0, in 3 of 3 runs; with the plugin loaded
through `--plugin-dir`, a Bash call and its child saw 0 in 3 of 3 runs, against 2 in 3 of 3 without it.

Not covered:
- **Windows, Git Bash included.** PowerShell never runs that file. On Windows the plugin writes nothing,
  because an `unset` line would stop PowerShell commands receiving other hooks' plain `export` lines, and
  the hook cannot tell whether PowerShell commands also run in the session. The channel stays inherited
  there.
- **No env file, or a failed write.** An older Claude Code that gives the hook no `$CLAUDE_ENV_FILE`, or a
  file that cannot be written: the hook stays silent and the channel stays inherited.
- Finding the channel by another route than these two variables. This was not measured.

The line is appended at every session start (resume and compact included). If the same file is reused,
the line repeats; `unset` twice does the same as once.

## What it writes

One line, appended to `$CLAUDE_ENV_FILE` (above), when Claude Code provides that file and the system is
not Windows. Claude Code stores the plugin itself under `~/.claude/plugins/cache/`. The gate and the
preflight create no logs, ledgers or other files. A lane in the FH repo checks this.
